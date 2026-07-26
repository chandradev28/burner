import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/addon_provider.dart';
import '../providers/library_provider.dart';
import '../providers/skin_provider.dart';
import '../providers/sources_provider.dart';
import 'main_shell.dart';

/// Boot screen. Deliberately wordmark-free: it shows a skin-tinted mark
/// while providers (including the saved UI skin) initialize.
class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 900),
  )..forward();

  @override
  void initState() {
    super.initState();
    _boot();
  }

  Future<void> _boot() async {
    final addons = context.read<AddonProvider>();
    final library = context.read<LibraryProvider>();
    final sources = context.read<SourcesProvider>();
    final skins = context.read<SkinProvider>();
    await Future.wait([
      // Load the saved skin first so the app never flashes the wrong UI.
      skins.init(),
      addons.init(),
      library.init(),
      sources.init(),
      Future.delayed(const Duration(milliseconds: 1100)),
    ]);
    if (!mounted) return;
    Navigator.of(context).pushReplacement(
      PageRouteBuilder(
        pageBuilder: (_, __, ___) => const MainShell(),
        transitionsBuilder: (_, animation, __, child) =>
            FadeTransition(opacity: animation, child: child),
        transitionDuration: const Duration(milliseconds: 350),
      ),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final skin = context.skin;
    return Scaffold(
      body: Center(
        child: FadeTransition(
          opacity:
              CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic),
          child: ScaleTransition(
            scale: Tween(begin: 0.85, end: 1.0).animate(
              CurvedAnimation(parent: _controller, curve: Curves.easeOutBack),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 84,
                  height: 84,
                  decoration: BoxDecoration(
                    gradient: skin.brand,
                    borderRadius: BorderRadius.circular(
                      skin.isNetflix ? 10 : (skin.isAppleTv ? 22 : 16),
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: skin.accent.withOpacity(0.35),
                        blurRadius: 34,
                        spreadRadius: -6,
                      ),
                    ],
                  ),
                  child: const Icon(
                    Icons.play_arrow_rounded,
                    size: 46,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 26),
                SizedBox(
                  width: 22,
                  height: 22,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: skin.accent,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
