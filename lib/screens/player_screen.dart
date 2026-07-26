import 'dart:async';

import 'package:chewie/chewie.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:video_player/video_player.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

import '../core/theme.dart';
import '../models/meta.dart';
import '../providers/library_provider.dart';

/// Full-screen video player (video_player + chewie) with resume-from-position
/// and automatic Continue Watching progress saving.
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
  String? _error;

  @override
  void initState() {
    super.initState();
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);
    WakelockPlus.enable();
    _init();
  }

  Future<void> _init() async {
    try {
      final controller = VideoPlayerController.networkUrl(
        Uri.parse(widget.streamUrl),
        httpHeaders: widget.headers ?? const {},
      );
      _videoController = controller;
      await controller.initialize();

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
          playedColor: BurnerColors.purple,
          handleColor: BurnerColors.purple,
          bufferedColor: Colors.white24,
          backgroundColor: Colors.white12,
        ),
      );

      _progressTimer = Timer.periodic(
          const Duration(seconds: 10), (_) => _saveProgress());

      if (mounted) setState(() {});
    } catch (e) {
      if (mounted) {
        setState(() => _error =
            'Could not play this stream. It may be offline or in an unsupported format.');
      }
    }
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
                          maxWidth:
                              MediaQuery.of(context).size.width * 0.6),
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
    if (_error != null) {
      return Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline_rounded,
                color: BurnerColors.danger, size: 44),
            const SizedBox(height: 12),
            Text(_error!,
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.white70)),
          ],
        ),
      );
    }
    final chewie = _chewieController;
    if (chewie == null) {
      return const CircularProgressIndicator(color: BurnerColors.purple);
    }
    return Chewie(controller: chewie);
  }
}
