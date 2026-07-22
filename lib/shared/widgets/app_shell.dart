import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:bienen_app/core/theme/app_theme.dart';

class AppShell extends StatelessWidget {
  final Widget child;

  const AppShell({super.key, required this.child});

  int _selectedIndex(BuildContext context) {
    final location = GoRouterState.of(context).uri.toString();
    if (location.startsWith('/voelker') || location.startsWith('/koeniginnen')) {
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
            NavigationRail(
              selectedIndex: selectedIndex,
              onDestinationSelected: (i) =>
                  _onDestinationSelected(context, i),
              labelType: NavigationRailLabelType.all,
              backgroundColor: AppColors.brown800,
              leading: Padding(
                padding: const EdgeInsets.symmetric(vertical: 16),
                child: Column(
                  children: [
                    const Text(
                      '🐝',
                      style: TextStyle(fontSize: 32),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Bienen\nArosa',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: Colors.white.withAlpha(220),
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
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
            Expanded(child: child),
          ],
        ),
      );
    }

    return Scaffold(
      body: child,
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
