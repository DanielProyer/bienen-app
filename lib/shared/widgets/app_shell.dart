import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:bienen_app/core/theme/app_theme.dart';

class AppShell extends StatelessWidget {
  final Widget child;

  const AppShell({super.key, required this.child});

  int _selectedIndex(BuildContext context) {
    final location = GoRouterState.of(context).uri.toString();
    if (location.startsWith('/voelker')) return 1;
    if (location.startsWith('/aufgaben')) return 2;
    if (location.startsWith('/monitoring')) return 3;
    if (location.startsWith('/material')) return 4;
    if (location.startsWith('/construction')) return 5;
    if (location.startsWith('/mehr') ||
        location.startsWith('/recherche') ||
        location.startsWith('/entscheidungen')) {
      return 6;
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
        context.go('/monitoring');
      case 4:
        context.go('/material');
      case 5:
        context.go('/construction');
      case 6:
        context.go('/mehr');
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
                  icon: Icon(Icons.dashboard_outlined),
                  selectedIcon: Icon(Icons.dashboard),
                  label: Text('Dashboard'),
                ),
                NavigationRailDestination(
                  icon: Icon(Icons.hive_outlined),
                  selectedIcon: Icon(Icons.hive),
                  label: Text('Voelker'),
                ),
                NavigationRailDestination(
                  icon: Icon(Icons.task_alt_outlined),
                  selectedIcon: Icon(Icons.task_alt),
                  label: Text('Aufgaben'),
                ),
                NavigationRailDestination(
                  icon: Icon(Icons.monitor_weight_outlined),
                  selectedIcon: Icon(Icons.monitor_weight),
                  label: Text('Waage'),
                ),
                NavigationRailDestination(
                  icon: Icon(Icons.shopping_cart_outlined),
                  selectedIcon: Icon(Icons.shopping_cart),
                  label: Text('Material'),
                ),
                NavigationRailDestination(
                  icon: Icon(Icons.construction_outlined),
                  selectedIcon: Icon(Icons.construction),
                  label: Text('Bau'),
                ),
                NavigationRailDestination(
                  icon: Icon(Icons.more_horiz),
                  selectedIcon: Icon(Icons.more_horiz),
                  label: Text('Mehr'),
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
            icon: Icon(Icons.dashboard_outlined),
            selectedIcon: Icon(Icons.dashboard),
            label: 'Dashboard',
          ),
          NavigationDestination(
            icon: Icon(Icons.hive_outlined),
            selectedIcon: Icon(Icons.hive),
            label: 'Voelker',
          ),
          NavigationDestination(
            icon: Icon(Icons.task_alt_outlined),
            selectedIcon: Icon(Icons.task_alt),
            label: 'Aufgaben',
          ),
          NavigationDestination(
            icon: Icon(Icons.monitor_weight_outlined),
            selectedIcon: Icon(Icons.monitor_weight),
            label: 'Waage',
          ),
          NavigationDestination(
            icon: Icon(Icons.shopping_cart_outlined),
            selectedIcon: Icon(Icons.shopping_cart),
            label: 'Material',
          ),
          NavigationDestination(
            icon: Icon(Icons.construction_outlined),
            selectedIcon: Icon(Icons.construction),
            label: 'Bau',
          ),
          NavigationDestination(
            icon: Icon(Icons.more_horiz),
            selectedIcon: Icon(Icons.more_horiz),
            label: 'Mehr',
          ),
        ],
      ),
    );
  }
}
