import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

/// The five-tab chrome around the main sections.
class AppShell extends StatelessWidget {
  const AppShell({super.key, required this.navigationShell});

  final StatefulNavigationShell navigationShell;

  static const List<_Destination> _destinations = <_Destination>[
    _Destination('Home', Icons.home_outlined, Icons.home),
    _Destination('Wardrobe', Icons.grid_view_outlined, Icons.grid_view),
    _Destination('Style', Icons.auto_awesome_outlined, Icons.auto_awesome),
    _Destination(
      'Planner',
      Icons.calendar_today_outlined,
      Icons.calendar_today,
    ),
    _Destination('Profile', Icons.person_outline, Icons.person),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: navigationShell,
      bottomNavigationBar: NavigationBar(
        selectedIndex: navigationShell.currentIndex,
        onDestinationSelected: (int index) {
          // initialLocation: true means tapping the current tab pops back to
          // that branch's root, which is what people expect from a tab bar.
          navigationShell.goBranch(
            index,
            initialLocation: index == navigationShell.currentIndex,
          );
        },
        destinations: _destinations
            .map(
              (_Destination d) => NavigationDestination(
                icon: Icon(d.icon),
                selectedIcon: Icon(d.selectedIcon),
                label: d.label,
              ),
            )
            .toList(),
      ),
    );
  }
}

class _Destination {
  const _Destination(this.label, this.icon, this.selectedIcon);

  final String label;
  final IconData icon;
  final IconData selectedIcon;
}
