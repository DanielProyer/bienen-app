import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:bienen_app/features/aufgaben/presentation/pages/aufgaben_page.dart';
import 'package:bienen_app/features/aufgaben/presentation/pages/aufgabe_form_page.dart';
import 'package:bienen_app/features/auth/presentation/auth_providers.dart';
import 'package:bienen_app/features/auth/presentation/auth_state.dart';
import 'package:bienen_app/features/auth/presentation/einladung_code_page.dart';
import 'package:bienen_app/features/auth/presentation/konto_page.dart';
import 'package:bienen_app/features/auth/presentation/login_page.dart';
import 'package:bienen_app/features/auth/presentation/mail_bestaetigen_page.dart';
import 'package:bienen_app/features/auth/presentation/onboarding_page.dart';
import 'package:bienen_app/features/auth/presentation/registrieren_page.dart';
import 'package:bienen_app/features/behandlung/presentation/pages/behandlung_form_page.dart';
import 'package:bienen_app/features/behandlung/presentation/pages/kontrolle_form_page.dart';
import 'package:bienen_app/features/dashboard/pages/dashboard_page.dart';
import 'package:bienen_app/features/recherche/pages/recherche_overview_page.dart';
import 'package:bienen_app/features/recherche/pages/imkerei_schweiz_page.dart';
import 'package:bienen_app/features/recherche/pages/jahresablauf_page.dart';
import 'package:bienen_app/features/recherche/pages/beutensystem_page.dart';
import 'package:bienen_app/features/recherche/pages/raumkonzept_page.dart';
import 'package:bienen_app/features/recherche/pages/bienenrassen_page.dart';
import 'package:bienen_app/features/recherche/pages/stockwaagen_page.dart';
import 'package:bienen_app/features/recherche/pages/honigschleudern_page.dart';
import 'package:bienen_app/features/recherche/pages/imkerei_apps_page.dart';
import 'package:bienen_app/features/recherche/pages/markdown_viewer_page.dart';
import 'package:bienen_app/features/entscheidungen/pages/entscheidungen_page.dart';
import 'package:bienen_app/features/material/presentation/pages/material_page.dart'
    as material;
import 'package:bienen_app/features/monitoring/presentation/pages/monitoring_page.dart';
import 'package:bienen_app/features/monitoring/presentation/pages/scale_settings_page.dart';
import 'package:bienen_app/features/projekt/pages/projekt_page.dart';
import 'package:bienen_app/features/construction/presentation/pages/construction_page.dart';
import 'package:bienen_app/features/durchsicht/presentation/pages/durchsicht_detail_page.dart';
import 'package:bienen_app/features/einstellungen/pages/einstellungen_page.dart';
import 'package:bienen_app/features/durchsicht/presentation/pages/durchsicht_form_page.dart';
import 'package:bienen_app/features/fuetterung/presentation/pages/fuetterung_form_page.dart';
import 'package:bienen_app/features/gesundheit/presentation/pages/gesundheit_form_page.dart';
import 'package:bienen_app/features/voelker/presentation/pages/voelker_page.dart';
import 'package:bienen_app/features/voelker/presentation/pages/volk_detail_page.dart';
import 'package:bienen_app/shared/widgets/app_shell.dart';

final _rootNavigatorKey = GlobalKey<NavigatorState>();
final _shellNavigatorKey = GlobalKey<NavigatorState>();

/// Routen, die ohne Session erreichbar sind.
const _offeneRouten = {'/login', '/registrieren', '/mail-bestaetigen'};

/// Routen fuer den Zustand `ohneBetrieb` (Konto da, keine Mitgliedschaft).
const _ohneBetriebRouten = {'/onboarding', '/einladung'};

final appRouterProvider = Provider<GoRouter>((ref) {
  final gate = ref.watch(authGateNotifierProvider);
  return GoRouter(
    navigatorKey: _rootNavigatorKey,
    initialLocation: '/dashboard',
    refreshListenable: gate,
    redirect: (context, state) {
      final status = ref.read(authControllerProvider).status;
      final ziel = state.matchedLocation;

      // `laden`: NICHT navigieren — sonst wuerde die URL umgeschrieben, bevor
      // die Session aufgeloest ist. main.dart zeigt solange den Splash.
      if (status == AuthStatus.laden) return null;

      if (status == AuthStatus.abgemeldet) {
        return _offeneRouten.contains(ziel) ? null : '/login';
      }
      if (status == AuthStatus.ohneBetrieb) {
        return _ohneBetriebRouten.contains(ziel) ? null : '/onboarding';
      }
      // angemeldet: Auth-/Onboarding-Routen sind erledigt.
      if (_offeneRouten.contains(ziel) || _ohneBetriebRouten.contains(ziel)) {
        return '/dashboard';
      }
      return null;
    },
    routes: [
      GoRoute(path: '/login', builder: (c, s) => const LoginPage()),
      GoRoute(path: '/registrieren', builder: (c, s) => const RegistrierenPage()),
      GoRoute(
        path: '/mail-bestaetigen',
        builder: (c, s) =>
            MailBestaetigenPage(email: s.uri.queryParameters['email'] ?? ''),
      ),
      GoRoute(path: '/onboarding', builder: (c, s) => const OnboardingPage()),
      GoRoute(path: '/einladung', builder: (c, s) => const EinladungCodePage()),
      ShellRoute(
      navigatorKey: _shellNavigatorKey,
      builder: (context, state, child) => AppShell(child: child),
      routes: [
        GoRoute(
          path: '/dashboard',
          builder: (context, state) => const DashboardPage(),
        ),
        GoRoute(
          path: '/aufgaben',
          builder: (context, state) => const AufgabenPage(),
          routes: [
            GoRoute(
              path: 'neu',
              builder: (c, s) => const AufgabeFormPage(),
            ),
            GoRoute(
              path: ':id/bearbeiten',
              builder: (c, s) => AufgabeFormPage(aufgabeId: s.pathParameters['id']),
            ),
          ],
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
              path: 'bienenrassen',
              builder: (context, state) => const BienenrassenPage(),
              routes: [
                GoRoute(
                  path: 'detail',
                  builder: (context, state) => const MarkdownViewerPage(
                    title: 'Bienenrassen (Detail)',
                    assetPath: 'assets/recherche/06_Bienenrassen_Entscheidung.md',
                  ),
                ),
              ],
            ),
            GoRoute(
              path: 'stockwaagen',
              builder: (context, state) => const StockwaagenPage(),
              routes: [
                GoRoute(
                  path: 'detail',
                  builder: (context, state) => const MarkdownViewerPage(
                    title: 'Stockwaagen (Detail)',
                    assetPath: 'assets/recherche/07_Stockwaagen_Monitoring.md',
                  ),
                ),
              ],
            ),
            GoRoute(
              path: 'honigschleudern',
              builder: (context, state) => const HonigschleuderunPage(),
              routes: [
                GoRoute(
                  path: 'detail',
                  builder: (context, state) => const MarkdownViewerPage(
                    title: 'Honigschleudern (Detail)',
                    assetPath: 'assets/recherche/08_Honigschleudern_Dadant_Blatt.md',
                  ),
                ),
              ],
            ),
            GoRoute(
              path: 'imkerei-apps',
              builder: (context, state) => const ImkereiAppsPage(),
              routes: [
                GoRoute(
                  path: 'detail',
                  builder: (context, state) => const MarkdownViewerPage(
                    title: 'Imkerei-Apps (Detail)',
                    assetPath: 'assets/recherche/09_Imkerei_Apps.md',
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
            // Fachwissen-Bibliothek (Recherchen 10-20 der Imkerei-Schiene)
            GoRoute(
              path: 'bienenbiologie',
              builder: (context, state) => const MarkdownViewerPage(
                title: 'Bienenbiologie: Das Bienenvolk',
                assetPath: 'assets/recherche/10_Bienenbiologie_Das_Bienenvolk.md',
              ),
            ),
            GoRoute(
              path: 'betriebsweisen',
              builder: (context, state) => const MarkdownViewerPage(
                title: 'Imkerei-Grundlagen & Betriebsweisen',
                assetPath: 'assets/recherche/11_Imkerei_Grundlagen_Betriebsweisen.md',
              ),
            ),
            GoRoute(
              path: 'koeniginnenzucht',
              builder: (context, state) => const MarkdownViewerPage(
                title: 'Königinnenzucht',
                assetPath: 'assets/recherche/12_Koeniginnenzucht.md',
              ),
            ),
            GoRoute(
              path: 'voelkervermehrung',
              builder: (context, state) => const MarkdownViewerPage(
                title: 'Völkervermehrung',
                assetPath: 'assets/recherche/13_Voelkervermehrung.md',
              ),
            ),
            GoRoute(
              path: 'bienengesundheit',
              builder: (context, state) => const MarkdownViewerPage(
                title: 'Bienengesundheit & Krankheiten CH',
                assetPath: 'assets/recherche/14_Bienengesundheit_Krankheiten_CH.md',
              ),
            ),
            GoRoute(
              path: 'varroa-konzept',
              builder: (context, state) => const MarkdownViewerPage(
                title: 'Varroa-Bekämpfungskonzept alpin',
                assetPath: 'assets/recherche/15_Varroa_Bekaempfungskonzept_alpin.md',
              ),
            ),
            GoRoute(
              path: 'honig',
              builder: (context, state) => const MarkdownViewerPage(
                title: 'Honig: Ernte, Qualität, Vermarktung',
                assetPath: 'assets/recherche/16_Honig_Ernte_Qualitaet_Vermarktung.md',
              ),
            ),
            GoRoute(
              path: 'wachs',
              builder: (context, state) => const MarkdownViewerPage(
                title: 'Wachs & Wabenmanagement',
                assetPath: 'assets/recherche/17_Wachs_Wabenmanagement.md',
              ),
            ),
            GoRoute(
              path: 'bio-knospe',
              builder: (context, state) => const MarkdownViewerPage(
                title: 'Bio-Imkerei & Knospe Schweiz',
                assetPath: 'assets/recherche/18_Bio_Imkerei_Knospe_Schweiz.md',
              ),
            ),
            GoRoute(
              path: 'recht',
              builder: (context, state) => const MarkdownViewerPage(
                title: 'Recht, Tierverkehr & Bestandeskontrolle CH/GR',
                assetPath: 'assets/recherche/19_Recht_Tierverkehr_Bestandeskontrolle_CH_GR.md',
              ),
            ),
            GoRoute(
              path: 'wirtschaftlichkeit',
              builder: (context, state) => const MarkdownViewerPage(
                title: 'Wirtschaftlichkeit & Betriebsführung',
                assetPath: 'assets/recherche/20_Wirtschaftlichkeit_Betriebsfuehrung.md',
              ),
            ),
            // Offizielle BGD-Merkblätter (BienenSchweiz), ausgewertet Juli 2026
            GoRoute(
              path: 'bgd-betriebskonzept',
              builder: (context, state) => const MarkdownViewerPage(
                title: 'Betriebskonzept & Jahresplanung (BGD)',
                assetPath: 'assets/recherche/21_Betriebskonzept_Jahresplanung_BGD.md',
              ),
            ),
            GoRoute(
              path: 'bgd-varroa',
              builder: (context, state) => const MarkdownViewerPage(
                title: 'Varroa-Behandlungskonzept (BGD)',
                assetPath: 'assets/recherche/22_Varroa_Behandlungskonzept_BGD.md',
              ),
            ),
            GoRoute(
              path: 'bgd-krankheiten',
              builder: (context, state) => const MarkdownViewerPage(
                title: 'Krankheiten & Schädlinge (BGD)',
                assetPath: 'assets/recherche/23_Krankheiten_Schaedlinge_BGD.md',
              ),
            ),
            GoRoute(
              path: 'bgd-vespa',
              builder: (context, state) => const MarkdownViewerPage(
                title: 'Asiatische Hornisse (Vespa velutina)',
                assetPath: 'assets/recherche/24_Asiatische_Hornisse_Vespa_velutina.md',
              ),
            ),
            GoRoute(
              path: 'bgd-vermehrung',
              builder: (context, state) => const MarkdownViewerPage(
                title: 'Vermehrung & Jungvolkbildung (BGD)',
                assetPath: 'assets/recherche/25_Vermehrung_Jungvolkbildung_BGD.md',
              ),
            ),
            GoRoute(
              path: 'bgd-zucht',
              builder: (context, state) => const MarkdownViewerPage(
                title: 'Zucht & Völkerbeurteilung (BGD)',
                assetPath: 'assets/recherche/26_Zucht_Voelkerbeurteilung_BGD.md',
              ),
            ),
            GoRoute(
              path: 'bgd-praxis',
              builder: (context, state) => const MarkdownViewerPage(
                title: 'Gute imkerliche Praxis (BGD)',
                assetPath: 'assets/recherche/27_Gute_imkerliche_Praxis_BGD.md',
              ),
            ),
            GoRoute(
              path: 'bgd-honig-recht',
              builder: (context, state) => const MarkdownViewerPage(
                title: 'Honig-Qualität & Recht/Pflichten (BGD)',
                assetPath: 'assets/recherche/28_Honig_Recht_Pflichten_BGD.md',
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
        GoRoute(
          path: '/monitoring',
          builder: (context, state) => const MonitoringPage(),
          routes: [
            GoRoute(
              path: 'settings',
              builder: (context, state) => const ScaleSettingsPage(),
            ),
          ],
        ),
        GoRoute(
          path: '/construction',
          builder: (context, state) => const ConstructionPage(),
        ),
        GoRoute(
          path: '/voelker',
          builder: (context, state) => const VoelkerPage(),
          routes: [
            GoRoute(
              path: ':id',
              builder: (context, state) =>
                  VolkDetailPage(volkId: state.pathParameters['id']!),
              routes: [
                GoRoute(
                  path: 'durchsicht',
                  builder: (c, s) => DurchsichtFormPage(volkId: s.pathParameters['id']!),
                ),
                GoRoute(
                  path: 'durchsicht/:did',
                  builder: (c, s) => DurchsichtDetailPage(
                    volkId: s.pathParameters['id']!, durchsichtId: s.pathParameters['did']!),
                ),
                GoRoute(
                  path: 'varroa',
                  builder: (c, s) => KontrolleFormPage(volkId: s.pathParameters['id']!),
                ),
                GoRoute(
                  path: 'behandlung',
                  builder: (c, s) => BehandlungFormPage(volkId: s.pathParameters['id']!),
                ),
                GoRoute(
                  path: 'fuetterung',
                  builder: (c, s) => FuetterungFormPage(volkId: s.pathParameters['id']!),
                ),
                GoRoute(
                  path: 'gesundheit',
                  builder: (c, s) => GesundheitFormPage(
                    volkId: s.pathParameters['id']!,
                    vorbefuelltKrankheit: s.uri.queryParameters['k'],
                  ),
                ),
              ],
            ),
          ],
        ),
        GoRoute(path: '/projekt', builder: (context, state) => const ProjektPage()),
        GoRoute(path: '/einstellungen', builder: (c, s) => const EinstellungenPage()),
        GoRoute(path: '/mehr', redirect: (context, state) => '/projekt'),
        GoRoute(
          path: '/konto',
          builder: (context, state) => const KontoPage(),
        ),
      ],
      ),
    ],
  );
});
