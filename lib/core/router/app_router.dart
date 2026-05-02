import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:bienen_app/features/dashboard/pages/dashboard_page.dart';
import 'package:bienen_app/features/recherche/pages/recherche_overview_page.dart';
import 'package:bienen_app/features/recherche/pages/imkerei_schweiz_page.dart';
import 'package:bienen_app/features/recherche/pages/jahresablauf_page.dart';
import 'package:bienen_app/features/recherche/pages/beutensystem_page.dart';
import 'package:bienen_app/features/recherche/pages/raumkonzept_page.dart';
import 'package:bienen_app/features/entscheidungen/pages/entscheidungen_page.dart';
import 'package:bienen_app/features/material/presentation/pages/material_page.dart'
    as material;
import 'package:bienen_app/shared/widgets/app_shell.dart';

final _rootNavigatorKey = GlobalKey<NavigatorState>();
final _shellNavigatorKey = GlobalKey<NavigatorState>();

final appRouter = GoRouter(
  navigatorKey: _rootNavigatorKey,
  initialLocation: '/dashboard',
  routes: [
    ShellRoute(
      navigatorKey: _shellNavigatorKey,
      builder: (context, state, child) => AppShell(child: child),
      routes: [
        GoRoute(
          path: '/dashboard',
          builder: (context, state) => const DashboardPage(),
        ),
        GoRoute(
          path: '/recherche',
          builder: (context, state) => const RechercheOverviewPage(),
          routes: [
            GoRoute(
              path: 'imkerei-schweiz',
              builder: (context, state) => const ImkereiSchweizPage(),
            ),
            GoRoute(
              path: 'jahresablauf',
              builder: (context, state) => const JahresablaufPage(),
            ),
            GoRoute(
              path: 'beutensystem',
              builder: (context, state) => const BeutensystemPage(),
            ),
            GoRoute(
              path: 'raumkonzept',
              builder: (context, state) => const RaumkonzeptPage(),
            ),
          ],
        ),
        GoRoute(
          path: '/entscheidungen',
          builder: (context, state) => const EntscheidungenPage(),
        ),
        GoRoute(
          path: '/material',
          builder: (context, state) => const material.MaterialPage(),
        ),
      ],
    ),
  ],
);
