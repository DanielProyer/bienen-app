import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:bienen_app/features/dashboard/pages/dashboard_page.dart';
import 'package:bienen_app/features/recherche/pages/recherche_overview_page.dart';
import 'package:bienen_app/features/recherche/pages/imkerei_schweiz_page.dart';
import 'package:bienen_app/features/recherche/pages/jahresablauf_page.dart';
import 'package:bienen_app/features/recherche/pages/beutensystem_page.dart';
import 'package:bienen_app/features/recherche/pages/raumkonzept_page.dart';
import 'package:bienen_app/features/recherche/pages/markdown_viewer_page.dart';
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
              routes: [
                GoRoute(
                  path: 'detail',
                  builder: (context, state) => const MarkdownViewerPage(
                    title: 'Imkerei Schweiz (Detail)',
                    assetPath: 'assets/recherche/01_Imkerei_Schweiz_Recherche.md',
                  ),
                ),
              ],
            ),
            GoRoute(
              path: 'jahresablauf',
              builder: (context, state) => const JahresablaufPage(),
              routes: [
                GoRoute(
                  path: 'detail',
                  builder: (context, state) => const MarkdownViewerPage(
                    title: 'Jahresablauf (Detail)',
                    assetPath: 'assets/recherche/02_Jahresablauf_Imker_Arosa_1570m.md',
                  ),
                ),
              ],
            ),
            GoRoute(
              path: 'beutensystem',
              builder: (context, state) => const BeutensystemPage(),
              routes: [
                GoRoute(
                  path: 'detail',
                  builder: (context, state) => const MarkdownViewerPage(
                    title: 'Dadant Blatt (Detail)',
                    assetPath: 'assets/recherche/03_Dadant_Blatt_Beutensystem.md',
                  ),
                ),
              ],
            ),
            GoRoute(
              path: 'raumkonzept',
              builder: (context, state) => const RaumkonzeptPage(),
              routes: [
                GoRoute(
                  path: 'detail',
                  builder: (context, state) => const MarkdownViewerPage(
                    title: 'Raumkonzept (Detail)',
                    assetPath: 'assets/recherche/05_Raumkonzept_Maiensaess.md',
                  ),
                ),
              ],
            ),
            GoRoute(
              path: 'bienenstand',
              builder: (context, state) => const MarkdownViewerPage(
                title: 'Bienenstand & Unterstand',
                assetPath: 'assets/recherche/04_Bienenstand_Unterstand_Recherche.md',
              ),
            ),
            GoRoute(
              path: 'schleuderraum',
              builder: (context, state) => const MarkdownViewerPage(
                title: 'Honigverarbeitungsraum',
                assetPath: 'assets/recherche/04_Honigverarbeitungsraum_Schleuderraum.md',
              ),
            ),
            GoRoute(
              path: 'einkaufsliste',
              builder: (context, state) => const MarkdownViewerPage(
                title: 'Erstausstattung Einkaufsliste',
                assetPath: 'assets/recherche/03_Erstausstattung_Einkaufsliste.md',
              ),
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
