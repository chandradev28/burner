import 'package:flutter/material.dart';

import '../core/skins.dart';
import '../providers/skin_provider.dart';
import '../widgets/glass_nav_bar.dart';
import 'home_screen.dart';
import 'library_screen.dart';
import 'profile_screen.dart';
import 'search_screen.dart';

/// Footer navigation shell. Both the labels and the icons come from the active
/// skin, so Netflix shows "My List / Me" while Apple TV shows
/// "Watch Now / Library / Settings".
class MainShell extends StatefulWidget {
  const MainShell({super.key});

  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> {
  int _index = 0;

  static const _screens = <Widget>[
    HomeScreen(),
    SearchScreen(),
    LibraryScreen(),
    ProfileScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    final skin = context.skin;
    final labels = skin.navLabels;

    final items = <GlassNavItem>[
      GlassNavItem(
        icon: skin.isAppleTv
            ? Icons.play_circle_outline_rounded
            : Icons.home_outlined,
        activeIcon: skin.isAppleTv
            ? Icons.play_circle_filled_rounded
            : Icons.home_rounded,
        label: labels[0],
      ),
      GlassNavItem(
        icon: Icons.search_rounded,
        activeIcon: skin.isHbo
            ? Icons.saved_search_rounded
            : Icons.search_rounded,
        label: labels[1],
      ),
      GlassNavItem(
        icon: skin.isNetflix
            ? Icons.bookmark_border_rounded
            : Icons.video_library_outlined,
        activeIcon: skin.isNetflix
            ? Icons.bookmark_rounded
            : Icons.video_library_rounded,
        label: labels[2],
      ),
      GlassNavItem(
        icon: skin.isAppleTv
            ? Icons.settings_outlined
            : Icons.person_outline_rounded,
        activeIcon: skin.isAppleTv
            ? Icons.settings_rounded
            : Icons.person_rounded,
        label: labels[3],
      ),
    ];

    return Scaffold(
      // extendBody lets content scroll behind the HBO glass bar and the
      // Apple TV frosted bar so the blur has something to refract.
      extendBody: skin.navStyle != NavStyle.flatBar,
      body: IndexedStack(index: _index, children: _screens),
      bottomNavigationBar: GlassNavBar(
        currentIndex: _index,
        onTap: (i) => setState(() => _index = i),
        items: items,
      ),
    );
  }
}
