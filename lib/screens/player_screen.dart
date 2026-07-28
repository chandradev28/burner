import 'dart:async';

import 'package:chewie/chewie.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:video_player/video_player.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

import '../models/meta.dart';
import '../providers/library_provider.dart';
import '../providers/skin_provider.dart';

/// Default browser-ish identity. A lot of scraped hosts reject the stock
/// ExoPlayer user agent outright, which surfaced as a generic "unsupported
/// format" error before.
const String _kBrowserUserAgent =
    'Mozilla/5.0 (Linux; Android 13; Pixel 7) AppleWebKit/537.36 (KHTML, like Gecko) '
    'Chrome/122.0.0.0 Mobile Safari/537.36';

/// Full-screen video player (video_player + chewie) with resume-from-position
/// and automatic Continue Watching progress saving. The scrubber is tinted
/// with the active skin's accent color.
///
/// Playback is attempted in several passes because addon/scraper links are
/// unreliable: the URL is first resolved through redirects and probed, then
/// tried with the caller's headers, then with browser-like headers, then with
/// an explicit HLS format hint.
class PlayerScreen extends StatefulWidget {
  final String streamUrl;
  final String title;
  final MetaItem? meta;
  final String? videoId; // episode id, null for movies
  final String? videoLabel; // e.g. "S1 E2 \u2022 Pilot"
  final Map<String, String>? headers; // required by scraped providers

  const PlayerScreen({
    super.key,
    required this.streamUrl,
    required this.title,
    this.meta,
    this.videoId,
    this.videoLabel,
    this.headers,
  });

  @override
  State<PlayerScreen> createState() => _PlayerScreenState();
}

class _PlayerScreenState extends State<PlayerScreen> {
  VideoPlayerController? _videoController;
  ChewieController? _chewieController;
  Timer? _progressTimer;

  String? _error; // user-facing reason
  String? _details; // technical detail, shown small
  bool _loading = true;
  String _stage = 'Connecting\u2026';

  /// URL actually handed to the player (after following redirects).
  late String _playUrl;

  @override
  void initState() {
    super.initState();
    _playUrl = widget.streamUrl;
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);
    WakelockPlus.enable();
    _init();
  }

  // ---------------------------------------------------------------- helpers

  /// Headers to send. Anything the caller supplied wins; the rest is filled
  /// with a browser identity plus a same-origin Referer, which is what most
  /// hotlink-protected hosts check.
  Map<String, String> _headersFor(String url, {required bool browserFallback}) {
    final out = <String, String>{};
    final supplied = widget.headers ?? const <String, String>{};
    out.addAll(supplied);

    final hasUa = supplied.keys.any((k) => k.toLowerCase() == 'user-agent');
    if (!hasUa && browserFallback) out['User-Agent'] = _kBrowserUserAgent;

    final hasReferer = supplied.keys.any((k) => k.toLowerCase() == 'referer');
    if (!hasReferer && browserFallback) {
      final uri = Uri.tryParse(url);
      if (uri != null && uri.hasAuthority) {
        out['Referer'] = '${uri.scheme}://${uri.authority}/';
        out['Origin'] = '${uri.scheme}://${uri.authority}';
      }
    }
    return out;
  }

  bool get _looksHls {
    final lower = _playUrl.toLowerCase();
    return lower.contains('.m3u8') || lower.contains('m3u');
  }

  /// Follows redirects manually and sanity-checks what is on the other end.
  ///
  /// Returns a human-readable problem string when the link clearly is not a
  /// playable video (dead link, expired token, HTML page, etc), or null when it
  /// looks fine. Never throws.
  Future<String?> _resolveAndProbe() async {
    var url = widget.streamUrl;
    final client = http.Client();
    try {
      for (var hop = 0; hop < 5; hop++) {
        final uri = Uri.tryParse(url);
        if (uri == null || !uri.hasScheme) return 'That link is not a valid URL.';
        if (uri.scheme != 'http' && uri.scheme != 'https') {
          _playUrl = url;
          return null; // local/loopback or custom scheme, let the player try
        }

        // Range request: cheap, and many CDNs reject bare HEAD.
        final request = http.Request('GET', uri)
          ..followRedirects = false
          ..headers.addAll(_headersFor(url, browserFallback: true))
          ..headers['Range'] = 'bytes=0-1';

        final response = await client
            .send(request)
            .timeout(const Duration(seconds: 15));
        // Drain so the socket is released.
        response.stream.listen((_) {}, onError: (_) {}).cancel();

        final code = response.statusCode;
        if (code >= 300 && code < 400) {
          final location = response.headers['location'];
          if (location == null || location.isEmpty) {
            return 'The host redirected without giving a destination (HTTP $code).';
          }
          url = uri.resolve(location).toString();
          continue;
        }

        _playUrl = url;

        if (code == 403) {
          return 'The host refused this link (HTTP 403). Scraped links usually '
              'expire within minutes \u2014 go back and pick the source again.';
        }
        if (code == 404 || code == 410) {
          return 'This file is gone from the host (HTTP $code). Try another source.';
        }
        if (code == 401) {
          return 'This source needs authentication (HTTP 401).';
        }
        if (code >= 500) {
          return 'The host is having problems right now (HTTP $code). Try again '
              'or pick another source.';
        }
        if (code != 200 && code != 206) {
          return 'The host answered HTTP $code instead of sending video.';
        }

        final type = (response.headers['content-type'] ?? '').toLowerCase();
        if (type.contains('text/html')) {
          return 'That source handed back a web page, not a video file. It is '
              'probably a streaming site that needs to be scraped rather than '
              'played directly.';
        }
        if (type.contains('application/json')) {
          return 'That source returned data, not a video stream.';
        }
        return null; // looks like video (or an m3u8 playlist)
      }
      return 'Too many redirects while opening this link.';
    } on TimeoutException {
      return 'The host did not respond in time. It may be down, or blocked on '
          'your connection.';
    } catch (e) {
      // Network-level failure: DNS, TLS, refused, no internet.
      return 'Could not reach the host. ${_shortError(e)}';
    } finally {
      client.close();
    }
  }

  static String _shortError(Object e) {
    var text = e.toString().replaceAll('\n', ' ').trim();
    if (text.length > 220) text = '${text.substring(0, 220)}\u2026';
    return text;
  }

  // ------------------------------------------------------------------- init

  Future<void> _init() async {
    // skinOnce: this runs outside build, so it must not subscribe.
    final skin = context.skinOnce;

    setState(() {
      _loading = true;
      _error = null;
      _details = null;
      _stage = 'Checking the source\u2026';
    });

    final problem = await _resolveAndProbe();
    if (!mounted) return;
    if (problem != null) {
      setState(() {
        _loading = false;
        _error = problem;
      });
      return;
    }

    setState(() => _stage = 'Opening stream\u2026');

    // Attempt matrix: caller headers -> browser headers -> HLS hint.
    final attempts = <_Attempt>[
      _Attempt(
        headers: _headersFor(_playUrl, browserFallback: false),
        formatHint: _looksHls ? VideoFormat.hls : null,
      ),
      _Attempt(
        headers: _headersFor(_playUrl, browserFallback: true),
        formatHint: _looksHls ? VideoFormat.hls : null,
      ),
      _Attempt(
        headers: _headersFor(_playUrl, browserFallback: true),
        formatHint: _looksHls ? VideoFormat.other : VideoFormat.hls,
      ),
    ];

    Object? lastError;
    for (final attempt in attempts) {
      VideoPlayerController? controller;
      try {
        controller = VideoPlayerController.networkUrl(
          Uri.parse(_playUrl),
          httpHeaders: attempt.headers,
          formatHint: attempt.formatHint,
        );
        await controller.initialize().timeout(const Duration(seconds: 30));

        if (!mounted) {
          await controller.dispose();
          return;
        }
        _videoController = controller;
        _attachPlaybackWatchdog(controller);
        _startChewie(controller, skin);
        return;
      } catch (e) {
        lastError = e;
        try {
          await controller?.dispose();
        } catch (_) {}
      }
    }

    if (!mounted) return;
    setState(() {
      _loading = false;
      _error = _looksHls
          ? 'This stream would not open. The playlist may be encrypted or '
              'region-locked \u2014 try a different source.'
          : 'This stream would not open. The format may not be supported on '
              'Android (for example MKV with unusual codecs), or the link is '
              'dead \u2014 try a different source.';
      _details = lastError == null ? null : _shortError(lastError);
    });
  }

  void _startChewie(VideoPlayerController controller, dynamic skin) {
    // Resume from saved position for this exact title/episode.
    Duration startAt = Duration.zero;
    final meta = widget.meta;
    if (meta != null) {
      final saved =
          context.read<LibraryProvider>().progressFor(meta.type, meta.id);
      final sameVideo = saved != null &&
          (widget.videoId == null || saved.videoId == widget.videoId);
      if (sameVideo && !saved.isFinished) {
        startAt = Duration(milliseconds: saved.positionMs);
      }
    }

    _chewieController = ChewieController(
      videoPlayerController: controller,
      autoPlay: true,
      startAt: startAt,
      allowedScreenSleep: false,
      allowPlaybackSpeedChanging: true,
      materialProgressColors: ChewieProgressColors(
        playedColor: skin.accent,
        handleColor: skin.accent,
        bufferedColor: Colors.white24,
        backgroundColor: Colors.white12,
      ),
    );

    _progressTimer =
        Timer.periodic(const Duration(seconds: 10), (_) => _saveProgress());

    setState(() {
      _loading = false;
      _error = null;
      _details = null;
    });
  }

  /// Surfaces mid-playback failures (host cuts the connection, token expires)
  /// instead of freezing on a black screen.
  void _attachPlaybackWatchdog(VideoPlayerController controller) {
    controller.addListener(() {
      final value = controller.value;
      if (value.hasError && mounted && _error == null) {
        setState(() {
          _loading = false;
          _error = 'Playback stopped. The host closed the connection or the '
              'link expired.';
          _details = value.errorDescription;
        });
      }
    });
  }

  Future<void> _retry() async {
    _progressTimer?.cancel();
    final chewie = _chewieController;
    final video = _videoController;
    _chewieController = null;
    _videoController = null;
    chewie?.dispose();
    await video?.dispose();
    _playUrl = widget.streamUrl;
    await _init();
  }

  Future<void> _openExternally() async {
    final uri = Uri.tryParse(_playUrl);
    if (uri == null) return;
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  Future<void> _copyLink() async {
    await Clipboard.setData(ClipboardData(text: _playUrl));
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Stream link copied')),
    );
  }

  void _saveProgress() {
    final controller = _videoController;
    final meta = widget.meta;
    if (controller == null || meta == null) return;
    final value = controller.value;
    if (!value.isInitialized || value.duration == Duration.zero) return;
    context.read<LibraryProvider>().saveProgress(
          meta: meta,
          videoId: widget.videoId,
          videoLabel: widget.videoLabel,
          streamUrl: widget.streamUrl,
          position: value.position,
          duration: value.duration,
        );
  }

  @override
  void dispose() {
    _saveProgress();
    _progressTimer?.cancel();
    _chewieController?.dispose();
    _videoController?.dispose();
    WakelockPlus.disable();
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    SystemChrome.setPreferredOrientations(DeviceOrientation.values);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          Center(child: _buildPlayer()),
          SafeArea(
            child: Align(
              alignment: Alignment.topLeft,
              child: Padding(
                padding: const EdgeInsets.all(8),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      icon: const Icon(Icons.arrow_back_rounded,
                          color: Colors.white),
                      onPressed: () => Navigator.of(context).pop(),
                    ),
                    ConstrainedBox(
                      constraints: BoxConstraints(
                          maxWidth: MediaQuery.of(context).size.width * 0.6),
                      child: Text(
                        widget.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w600,
                            shadows: [
                              Shadow(color: Colors.black, blurRadius: 8)
                            ]),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPlayer() {
    final skin = context.skin;

    if (_error != null) {
      return SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 40),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.error_outline_rounded, color: skin.danger, size: 42),
            const SizedBox(height: 12),
            Text(
              _error!,
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.white70, height: 1.35),
            ),
            if (_details != null) ...[
              const SizedBox(height: 10),
              Text(
                _details!,
                textAlign: TextAlign.center,
                maxLines: 4,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                    color: skin.textSecondary,
                    fontSize: 11,
                    fontFamily: 'monospace'),
              ),
            ],
            const SizedBox(height: 20),
            Wrap(
              alignment: WrapAlignment.center,
              spacing: 10,
              runSpacing: 8,
              children: [
                FilledButton.icon(
                  onPressed: _retry,
                  icon: const Icon(Icons.refresh_rounded, size: 18),
                  label: const Text('Retry'),
                ),
                OutlinedButton.icon(
                  onPressed: () => Navigator.of(context).pop(),
                  icon: const Icon(Icons.list_alt_rounded, size: 18),
                  label: const Text('Pick another source'),
                ),
                TextButton.icon(
                  onPressed: _openExternally,
                  icon: const Icon(Icons.open_in_new_rounded, size: 18),
                  label: const Text('Open in another app'),
                ),
                TextButton.icon(
                  onPressed: _copyLink,
                  icon: const Icon(Icons.copy_rounded, size: 18),
                  label: const Text('Copy link'),
                ),
              ],
            ),
          ],
        ),
      );
    }

    final chewie = _chewieController;
    if (chewie == null || _loading) {
      return Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          CircularProgressIndicator(color: skin.accent),
          const SizedBox(height: 14),
          Text(_stage,
              style: TextStyle(color: skin.textSecondary, fontSize: 12)),
        ],
      );
    }
    return Chewie(controller: chewie);
  }
}

class _Attempt {
  final Map<String, String> headers;
  final VideoFormat? formatHint;

  const _Attempt({required this.headers, this.formatHint});
}
