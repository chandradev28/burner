import 'package:flutter/material.dart';

import '../widgets/glass_nav_bar.dart';
import 'home_screen.dart';
import 'library_screen.dart';
import 'profile_screen.dart';
import 'search_screen.dart';

/// Bottom-navigation shell (Home / Search / My Stuff / Profile),
/// mirroring the HBO Max tab layout, with a global liquid-glass footer.
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

  static const _items = <GlassNavItem>[
    GlassNavItem(
      icon: Icons.home_outlined,
      activeIcon: Icons.home_rounded,
      label: 'Home',
    ),
    GlassNavItem(
      icon: Icons.search_rounded,
      activeIcon: Icons.saved_search_rounded,
      label: 'Search',
    ),
    GlassNavItem(
      icon: Icons.video_library_outlined,
      activeIcon: Icons.video_library_rounded,
      label: 'My Stuff',
    ),
    GlassNavItem(
      icon: Icons.person_outline_rounded,
      activeIcon: Icons.person_rounded,
      label: 'Profile',
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // extendBody lets content scroll *behind* the glass so the blur has
      // something to refract \u2014 this is what makes the effect read correctly.
      extendBody: true,
      body: IndexedStack(index: _index, children: _screens),
      bottomNavigationBar: GlassNavBar(
        currentIndex: _index,
        onTap: (i) => setState(() => _index = i),
        items: _items,
      ),
    );
  }
}
