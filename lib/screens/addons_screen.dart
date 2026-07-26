import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/skins.dart';
import '../models/addon.dart';
import '../providers/addon_provider.dart';
import '../providers/catalog_provider.dart';
import '../providers/skin_provider.dart';
import '../widgets/common.dart';

/// Addon manager: list installed Stremio addons, add new ones by
/// manifest URL, and remove existing ones. Fully skin-aware.
class AddonsScreen extends StatelessWidget {
  const AddonsScreen({super.key});

  Future<void> _showAddDialog(BuildContext context) async {
    final controller = TextEditingController();
    final addonProvider = context.read<AddonProvider>();
    final catalogProvider = context.read<CatalogProvider>();
    final messenger = ScaffoldMessenger.of(context);
    final skin = context.skinOnce;

    await showDialog<void>(
      context: context,
      builder: (dialogContext) {
        var busy = false;
        String? error;
        return StatefulBuilder(
          builder: (dialogContext, setState) {
            return AlertDialog(
              title: const Text('Add addon'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Paste a Stremio addon manifest URL. stremio:// links are supported.',
                    style:
                        TextStyle(color: skin.textSecondary, fontSize: 13),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: controller,
                    autofocus: true,
                    keyboardType: TextInputType.url,
                    decoration: const InputDecoration(
                      hintText: 'https://.../manifest.json',
                    ),
                  ),
                  if (error != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 10),
                      child: Text(error!,
                          style:
                              TextStyle(color: skin.danger, fontSize: 12.5)),
                    ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed:
                      busy ? null : () => Navigator.of(dialogContext).pop(),
                  child: const Text('Cancel'),
                ),
                FilledButton(
                  style: FilledButton.styleFrom(backgroundColor: skin.accent),
                  onPressed: busy
                      ? null
                      : () async {
                          final url = controller.text.trim();
                          if (url.isEmpty) return;
                          setState(() {
                            busy = true;
                            error = null;
                          });
                          try {
                            final addon = await addonProvider.addAddon(url);
                            // Rebuild home rails with the new addon.
                            await catalogProvider
                                .loadHome(addonProvider.addons, force: true);
                            if (dialogContext.mounted) {
                              Navigator.of(dialogContext).pop();
                            }
                            messenger.showSnackBar(SnackBar(
                                content: Text(
                                    'Installed \u201c${addon.name}\u201d')));
                          } catch (e) {
                            setState(() {
                              busy = false;
                              error =
                                  'Could not install addon. Check the URL and try again.';
                            });
                          }
                        },
                  child: busy
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                              strokeWidth: 2, color: Colors.white))
                      : const Text('Install'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Future<void> _confirmRemove(BuildContext context, Addon addon) async {
    final skin = context.skinOnce;
    final addonProvider = context.read<AddonProvider>();
    final catalogProvider = context.read<CatalogProvider>();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text('Remove \u201c${addon.name}\u201d?'),
        content: Text(
          'Its catalogs and streams will no longer be available.',
          style: TextStyle(color: skin.textSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: skin.danger),
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Remove'),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      await addonProvider.removeAddon(addon);
      await catalogProvider.loadHome(addonProvider.addons, force: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final skin = context.skin;
    final addons = context.watch<AddonProvider>().addons;

    return Scaffold(
      appBar: AppBar(
        backgroundColor: skin.bg,
        title: const Text('Addons',
            style: TextStyle(fontWeight: FontWeight.w800)),
      ),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: skin.accent,
        foregroundColor: Colors.white,
        onPressed: () => _showAddDialog(context),
        icon: const Icon(Icons.add_rounded),
        label: const Text('Add addon'),
      ),
      body: addons.isEmpty
          ? Center(
              child: Padding(
                padding: const EdgeInsets.all(28),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.extension_off_outlined,
                        size: 48, color: skin.textSecondary),
                    const SizedBox(height: 14),
                    const Text('No addons installed',
                        style: TextStyle(
                            fontSize: 16, fontWeight: FontWeight.w700)),
                    const SizedBox(height: 6),
                    Text(
                      'Add a Stremio addon to load catalogs, metadata and streams.',
                      textAlign: TextAlign.center,
                      style:
                          TextStyle(color: skin.textSecondary, fontSize: 13),
                    ),
                    const SizedBox(height: 16),
                    GradientButton(
                      label: 'Add your first addon',
                      icon: Icons.add_rounded,
                      onPressed: () => _showAddDialog(context),
                    ),
                  ],
                ),
              ),
            )
          : ListView.separated(
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 110),
              itemCount: addons.length,
              separatorBuilder: (_, __) => const SizedBox(height: 10),
              itemBuilder: (context, index) {
                final addon = addons[index];
                return _AddonTile(
                  addon: addon,
                  onRemove: () => _confirmRemove(context, addon),
                );
              },
            ),
    );
  }
}

class _AddonTile extends StatelessWidget {
  final Addon addon;
  final VoidCallback onRemove;

  const _AddonTile({required this.addon, required this.onRemove});

  @override
  Widget build(BuildContext context) {
    final skin = context.skin;
    final manifest = addon.manifest;
    final capabilities = manifest.resources.map((r) => r.name).toSet().toList();

    return Container(
      decoration: BoxDecoration(
        color: skin.card,
        borderRadius: skin.cardBorderRadius,
      ),
      padding: const EdgeInsets.all(12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(skin.posterRadius),
            child: SizedBox(
              width: 46,
              height: 46,
              child: manifest.logo != null
                  ? CachedNetworkImage(
                      imageUrl: manifest.logo!,
                      fit: BoxFit.cover,
                      errorWidget: (_, __, ___) => _logoFallback(skin),
                    )
                  : _logoFallback(skin),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('${manifest.name}  v${manifest.version}',
                    style: const TextStyle(
                        fontWeight: FontWeight.w700, fontSize: 14.5)),
                if (manifest.description.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 3),
                    child: Text(
                      manifest.description,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                          color: skin.textSecondary,
                          fontSize: 12.5,
                          height: 1.35),
                    ),
                  ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: [
                    for (final cap in capabilities) _chip(skin, cap),
                    for (final type in manifest.types.take(4))
                      _chip(skin, type, outlined: true),
                  ],
                ),
              ],
            ),
          ),
          IconButton(
            tooltip: 'Remove addon',
            icon: Icon(Icons.delete_outline_rounded,
                color: skin.textSecondary),
            onPressed: onRemove,
          ),
        ],
      ),
    );
  }

  Widget _logoFallback(SkinData skin) {
    return Container(
      decoration: BoxDecoration(gradient: skin.brand),
      alignment: Alignment.center,
      child: Text(
        addon.name.isNotEmpty ? addon.name[0].toUpperCase() : '?',
        style: const TextStyle(
            color: Colors.white, fontWeight: FontWeight.w800, fontSize: 18),
      ),
    );
  }

  Widget _chip(SkinData skin, String label, {bool outlined = false}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: outlined ? Colors.transparent : skin.stroke,
        border: outlined ? Border.all(color: skin.stroke) : null,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(label,
          style: TextStyle(fontSize: 10.5, color: skin.textSecondary)),
    );
  }
}
