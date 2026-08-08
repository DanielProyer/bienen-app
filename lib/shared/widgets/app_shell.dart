import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:bienen_app/core/app_version.dart';
import 'package:bienen_app/core/theme/app_tokens.dart';

class AppShell extends StatelessWidget {
  final Widget child;

  const AppShell({super.key, required this.child});

  int _selectedIndex(BuildContext context) {
    final location = GoRouterState.of(context).uri.toString();
    if (location.startsWith('/voelker') ||
        location.startsWith('/koeniginnen') ||
        location.startsWith('/standorte')) {
      return 1;
    }
    if (location.startsWith('/aufgaben')) return 2;
    if (location.startsWith('/projekt') ||
        location.startsWith('/material') ||
        location.startsWith('/construction') ||
        location.startsWith('/monitoring') ||
        location.startsWith('/recherche') ||
        location.startsWith('/wissen') ||
        location.startsWith('/entscheidungen') ||
        location.startsWith('/einstellungen') ||
        location.startsWith('/backup') ||
        location.startsWith('/konto') ||
        location.startsWith('/benachrichtigungen') ||
        location.startsWith('/spracheingabe') ||
        location.startsWith('/mehr')) {
      return 3;
    }
    return 0;
  }

  void _onDestinationSelected(BuildContext context, int index) {
    switch (index) {
      case 0:
        context.go('/dashboard');
      case 1:
        context.go('/voelker');
      case 2:
        context.go('/aufgaben');
      case 3:
        context.go('/projekt');
    }
  }

  @override
  Widget build(BuildContext context) {
    final selectedIndex = _selectedIndex(context);
    final isWide = MediaQuery.sizeOf(context).width >= 800;

    if (isWide) {
      return Scaffold(
        body: Row(
          children: [
            // Helles Schema wie die Bottom-Navigation: weisse Leiste mit
            // Hairline-Kante, Honig als Auswahl-Akzent.
            DecoratedBox(
              decoration: const BoxDecoration(
                color: BeeTokens.karte,
                border: Border(
                    right: BorderSide(color: BeeTokens.rand, width: 0.5)),
              ),
              child: NavigationRail(
                selectedIndex: selectedIndex,
                onDestinationSelected: (i) =>
                    _onDestinationSelected(context, i),
                labelType: NavigationRailLabelType.all,
                backgroundColor: BeeTokens.karte,
                indicatorColor: BeeTokens.honigTint,
                leading: const Padding(
                  padding: EdgeInsets.symmetric(vertical: BeeTokens.lg),
                  child: Column(
                    children: [
                      Text(
                        '🐝',
                        style: TextStyle(fontSize: 32),
                      ),
                      SizedBox(height: BeeTokens.xs),
                      Text(
                        'Bienen\nArosa',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: BeeTokens.textSekundaer,
                          fontSize: 11,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
                destinations: const [
                  NavigationRailDestination(
                    icon: Icon(Icons.home_outlined),
                    selectedIcon: Icon(Icons.home),
                    label: Text('Cockpit'),
                  ),
                  NavigationRailDestination(
                    icon: Icon(Icons.hive_outlined),
                    selectedIcon: Icon(Icons.hive),
                    label: Text('Völker'),
                  ),
                  NavigationRailDestination(
                    icon: Icon(Icons.task_alt_outlined),
                    selectedIcon: Icon(Icons.task_alt),
                    label: Text('Aufgaben'),
                  ),
                  NavigationRailDestination(
                    icon: Icon(Icons.folder_open_outlined),
                    selectedIcon: Icon(Icons.folder_open),
                    label: Text('Projekt'),
                  ),
                ],
              ),
            ),
            Expanded(
              child: Stack(children: [child, const VersionsEtikett()]),
            ),
          ],
        ),
      );
    }

    return Scaffold(
      body: Stack(children: [child, const VersionsEtikett()]),
      bottomNavigationBar: NavigationBar(
        selectedIndex: selectedIndex,
        onDestinationSelected: (i) => _onDestinationSelected(context, i),
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.home_outlined),
            selectedIcon: Icon(Icons.home),
            label: 'Cockpit',
          ),
          NavigationDestination(
            icon: Icon(Icons.hive_outlined),
            selectedIcon: Icon(Icons.hive),
            label: 'Völker',
          ),
          NavigationDestination(
            icon: Icon(Icons.task_alt_outlined),
            selectedIcon: Icon(Icons.task_alt),
            label: 'Aufgaben',
          ),
          NavigationDestination(
            icon: Icon(Icons.folder_open_outlined),
            selectedIcon: Icon(Icons.folder_open),
            label: 'Projekt',
          ),
        ],
      ),
    );
  }
}
