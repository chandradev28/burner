import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../core/theme.dart';
import '../models/meta.dart';
import '../models/stream_item.dart';
import '../providers/addon_provider.dart';
import '../screens/player_screen.dart';
import '../services/addon_client.dart';

/// Opens the stream picker bottom sheet for a movie ([videoId] == meta.id)
/// or an episode ([videoId] == "ttXXXX:season:episode").
Future<void> showStreamSheet(
  BuildContext context, {
  required MetaItem meta,
  required String videoId,
  String? videoLabel,
}) {
  return showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: BurnerColors.surface,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
    ),
    builder: (_) => StreamSheet(
      meta: meta,
      videoId: videoId,
      videoLabel: videoLabel,
    ),
  );
}

class StreamSheet extends StatefulWidget {
  final MetaItem meta;
  final String videoId;
  final String? videoLabel;

  const StreamSheet({
    super.key,
    required this.meta,
    required this.videoId,
    this.videoLabel,
  });

  @override
  State<StreamSheet> createState() => _StreamSheetState();
}

class _StreamSheetState extends State<StreamSheet> {
  late Future<List<StreamItem>> _future;

  @override
  void initState() {
    super.initState();
    final addons = context.read<AddonProvider>().addons;
    _future = AddonClient.resolveStreams(
      addons,
      widget.meta.type,
      widget.videoId,
    );
  }

  void _play(StreamItem stream) {
    Navigator.of(context).pop();
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => PlayerScreen(
          streamUrl: stream.url!,
          title: widget.videoLabel != null
              ? '${widget.meta.name} \u2022 ${widget.videoLabel}'
              : widget.meta.name,
          meta: widget.meta,
          videoId: widget.videoId == widget.meta.id ? null : widget.videoId,
          videoLabel: widget.videoLabel,
        ),
      ),
    );
  }

  Future<void> _openExternal(StreamItem stream) async {
    final url = Uri.tryParse(stream.externalUrl ??
        (stream.ytId != null
            ? 'https://www.youtube.com/watch?v=${stream.ytId}'
            : ''));
    if (url == null) return;
    await launchUrl(url, mode: LaunchMode.externalApplication);
  }

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.6,
      maxChildSize: 0.92,
      minChildSize: 0.35,
      builder: (context, scrollController) {
        return Column(
          children: [
            const SizedBox(height: 10),
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: BurnerColors.stroke,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 14, 20, 6),
              child: Row(
                children: [
                  const Icon(Icons.play_circle_fill_rounded,
                      color: BurnerColors.purple),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      widget.videoLabel != null
                          ? 'Streams \u2022 ${widget.videoLabel}'
                          : 'Streams \u2022 ${widget.meta.name}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                          fontSize: 16, fontWeight: FontWeight.w700),
                    ),
                  ),
                ],
              ),
            ),
            const Divider(height: 16),
            Expanded(
              child: FutureBuilder<List<StreamItem>>(
                future: _future,
                builder: (context, snapshot) {
                  if (snapshot.connectionState != ConnectionState.done) {
                    return const Center(
                        child: CircularProgressIndicator(
                            color: BurnerColors.purple));
                  }
                  final streams = snapshot.data ?? const <StreamItem>[];
                  if (streams.isEmpty) {
                    return _EmptyStreams(error: snapshot.hasError);
                  }
                  return ListView.separated(
                    controller: scrollController,
                    padding: const EdgeInsets.fromLTRB(12, 4, 12, 24),
                    itemCount: streams.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 6),
                    itemBuilder: (context, index) {
                      final stream = streams[index];
                      return _StreamTile(
                        stream: stream,
                        onTap: () {
                          if (stream.isPlayable) {
                            _play(stream);
                          } else if (stream.isExternal || stream.isYouTube) {
                            _openExternal(stream);
                          } else {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text(
                                    'This is a torrent-only stream. Install a debrid/resolver addon to make it playable.'),
                              ),
                            );
                          }
                        },
                      );
                    },
                  );
                },
              ),
            ),
          ],
        );
      },
    );
  }
}

class _StreamTile extends StatelessWidget {
  final StreamItem stream;
  final VoidCallback onTap;

  const _StreamTile({required this.stream, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final IconData icon;
    final String hint;
    if (stream.isPlayable) {
      icon = Icons.play_arrow_rounded;
      hint = 'Play in Burner';
    } else if (stream.isExternal || stream.isYouTube) {
      icon = Icons.open_in_new_rounded;
      hint = 'Opens externally';
    } else {
      icon = Icons.link_off_rounded;
      hint = 'Torrent \u2014 needs resolver addon';
    }

    return Material(
      color: BurnerColors.card,
      borderRadius: BorderRadius.circular(10),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          child: Row(
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  gradient: stream.isPlayable ? BurnerColors.brand : null,
                  color: stream.isPlayable ? null : BurnerColors.stroke,
                  borderRadius: BorderRadius.circular(19),
                ),
                child: Icon(icon, color: Colors.white, size: 22),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      stream.primaryLabel,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                          fontSize: 13.5, fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      [
                        if (stream.badge.isNotEmpty) stream.badge,
                        hint,
                      ].join('  \u2022  '),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                          fontSize: 11.5, color: BurnerColors.textSecondary),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _EmptyStreams extends StatelessWidget {
  final bool error;
  const _EmptyStreams({required this.error});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.cloud_off_rounded,
                size: 44, color: BurnerColors.textSecondary),
            const SizedBox(height: 12),
            Text(
              error ? 'Could not load streams.' : 'No streams found.',
              style: const TextStyle(
                  fontSize: 15, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 6),
            const Text(
              'Install a streaming addon in Profile \u2192 Manage addons to get playable sources for this title.',
              textAlign: TextAlign.center,
              style: TextStyle(
                  color: BurnerColors.textSecondary, fontSize: 13),
            ),
          ],
        ),
      ),
    );
  }
}
