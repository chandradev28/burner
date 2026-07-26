import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/responsive.dart';
import '../core/skins.dart';
import '../providers/skin_provider.dart';

/// Lets the user pick the app-wide UI. Selecting a skin applies instantly to
/// every screen (home, rails, hero, footer, settings, dialogs, players).
class AppearanceScreen extends StatelessWidget {
  const AppearanceScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final current = context.watch<SkinProvider>().skin;
    final r = Responsive.of(context);

    return Scaffold(
      appBar: AppBar(title: const Text('App style')),
      body: ListView(
        padding: EdgeInsets.fromLTRB(r.gutter, 8, r.gutter, r.bottomSafePadding),
        children: [
          Text(
            'Choose how the whole app looks. This changes colors, typography, '
            'corner radius, the hero layout and the footer navigation everywhere.',
            style: TextStyle(
              color: current.textSecondary,
              fontSize: 13,
              height: 1.45,
            ),
          ),
          const SizedBox(height: 18),
          for (final skin in SkinData.all) ...[
            _SkinOption(
              skin: skin,
              selected: skin.id == current.id,
              onTap: () => context.read<SkinProvider>().setSkin(skin),
            ),
            const SizedBox(height: 14),
          ],
        ],
      ),
    );
  }
}

class _SkinOption extends StatelessWidget {
  final SkinData skin;
  final bool selected;
  final VoidCallback onTap;

  const _SkinOption({
    required this.skin,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final active = context.skin;
    return Material(
      color: active.card,
      borderRadius: active.cardBorderRadius,
      child: InkWell(
        borderRadius: active.cardBorderRadius,
        onTap: onTap,
        child: Container(
          decoration: BoxDecoration(
            borderRadius: active.cardBorderRadius,
            border: Border.all(
              color: selected ? active.accent : active.stroke,
              width: selected ? 1.6 : 1,
            ),
          ),
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 34,
                    height: 34,
                    decoration: BoxDecoration(
                      gradient: skin.brand,
                      borderRadius: BorderRadius.circular(skin.posterRadius),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      skin.name,
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                        color: active.textPrimary,
                      ),
                    ),
                  ),
                  if (selected)
                    Icon(Icons.check_circle_rounded,
                        color: active.accent, size: 22)
                  else
                    Icon(Icons.circle_outlined,
                        color: active.textSecondary, size: 22),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                skin.description,
                style: TextStyle(
                  color: active.textSecondary,
                  fontSize: 12.5,
                  height: 1.4,
                ),
              ),
              const SizedBox(height: 14),
              _SkinPreview(skin: skin),
            ],
          ),
        ),
      ),
    );
  }
}

/// A live miniature of the skin, drawn entirely from that skin's own tokens
/// (background, accent, radii, hero layout, nav bar shape).
class _SkinPreview extends StatelessWidget {
  final SkinData skin;

  const _SkinPreview({required this.skin});

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(10),
      child: Container(
        height: 168,
        color: skin.bg,
        child: Column(
          children: [
            _header(),
            Expanded(child: _hero()),
            _rail(),
            const SizedBox(height: 8),
            _nav(),
            const SizedBox(height: 6),
          ],
        ),
      ),
    );
  }

  Widget _header() {
    switch (skin.headerStyle) {
      case HomeHeaderStyle.minimal:
        return const SizedBox(height: 8);
      case HomeHeaderStyle.netflixChips:
        return Padding(
          padding: const EdgeInsets.fromLTRB(8, 8, 8, 4),
          child: Row(
            children: [
              for (var i = 0; i < 3; i++)
                Container(
                  margin: const EdgeInsets.only(right: 5),
                  width: 26,
                  height: 10,
                  decoration: BoxDecoration(
                    color: i == 0 ? Colors.white : Colors.transparent,
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(
                      color: i == 0
                          ? Colors.white
                          : skin.textSecondary.withOpacity(0.7),
                    ),
                  ),
                ),
            ],
          ),
        );
      case HomeHeaderStyle.appleLargeTitle:
        return Padding(
          padding: const EdgeInsets.fromLTRB(8, 8, 8, 4),
          child: Row(
            children: [
              Container(
                width: 52,
                height: 11,
                decoration: BoxDecoration(
                  color: skin.textPrimary,
                  borderRadius: BorderRadius.circular(3),
                ),
              ),
            ],
          ),
        );
    }
  }

  Widget _hero() {
    final art = DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [skin.card, skin.bg],
        ),
      ),
      child: Align(
        alignment: skin.isNetflix ? Alignment.center : Alignment.bottomLeft,
        child: Padding(
          padding: const EdgeInsets.all(10),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: skin.isNetflix
                ? CrossAxisAlignment.center
                : CrossAxisAlignment.start,
            children: [
              Container(
                width: 74,
                height: 12,
                decoration: BoxDecoration(
                  color: skin.textPrimary.withOpacity(0.92),
                  borderRadius: BorderRadius.circular(3),
                ),
              ),
              const SizedBox(height: 7),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 34,
                    height: 13,
                    decoration: BoxDecoration(
                      gradient:
                          skin.gradientPrimaryButton ? skin.brand : null,
                      color: skin.gradientPrimaryButton
                          ? null
                          : skin.primaryButtonColor,
                      borderRadius: BorderRadius.circular(
                        skin.buttonRadius.clamp(2.0, 8.0),
                      ),
                    ),
                  ),
                  const SizedBox(width: 5),
                  Container(
                    width: 34,
                    height: 13,
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.16),
                      borderRadius: BorderRadius.circular(
                        skin.buttonRadius.clamp(2.0, 8.0),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );

    if (skin.heroStyle == HeroStyle.appleWideCard) {
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(10),
          child: art,
        ),
      );
    }
    return art;
  }

  Widget _rail() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 6, 8, 0),
      child: Row(
        children: [
          for (var i = 0; i < 4; i++)
            Container(
              margin: const EdgeInsets.only(right: 6),
              width: 26,
              height: 34,
              decoration: BoxDecoration(
                color: skin.card,
                borderRadius:
                    BorderRadius.circular(skin.posterRadius.clamp(2.0, 10.0)),
              ),
            ),
        ],
      ),
    );
  }

  Widget _nav() {
    final dots = Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: [
        for (var i = 0; i < 4; i++)
          Container(
            width: 14,
            height: 5,
            decoration: BoxDecoration(
              color: i == 0
                  ? (skin.isAppleTv ? skin.accent : Colors.white)
                  : skin.textSecondary.withOpacity(0.55),
              borderRadius: BorderRadius.circular(3),
            ),
          ),
      ],
    );

    switch (skin.navStyle) {
      case NavStyle.glassPill:
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14),
          child: Container(
            height: 22,
            padding: const EdgeInsets.symmetric(horizontal: 6),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.10),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: Colors.white.withOpacity(0.18)),
            ),
            child: Center(child: dots),
          ),
        );
      case NavStyle.flatBar:
        return Container(
          height: 22,
          decoration: BoxDecoration(
            color: skin.bg,
            border: Border(top: BorderSide(color: skin.stroke)),
          ),
          child: Center(child: dots),
        );
      case NavStyle.frostedTab:
        return Container(
          height: 22,
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.06),
            border: Border(
              top: BorderSide(color: Colors.white.withOpacity(0.12)),
            ),
          ),
          child: Center(child: dots),
        );
    }
  }
}
