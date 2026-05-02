import 'package:flutter/material.dart';
import 'package:bienen_app/core/theme/app_theme.dart';

class TodoPage extends StatelessWidget {
  const TodoPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Projekt-Aufgaben')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildPhaseSection(context, 'Sofort / Nächste Schritte', AppColors.amber600, [
              _Todo('Grundkurs Imkerei besuchen', 'Beim Bündner Imkerverband anmelden (Frühling)', priority: _Priority.high),
              _Todo('BienenSchweiz Mitglied werden', 'Inkl. Versicherung, Zeitung, Vergünstigungen', priority: _Priority.high),
              _Todo('Kontakt Miel du Ciel', 'Ernst "Aschi" Iten → Erfahrungsaustausch, ev. Ableger', priority: _Priority.high),
              _Todo('Kontakt Imkerverein Schanfigg', 'Nachbar-Imker kennenlernen, Rassen im Gebiet', priority: _Priority.medium),
              _Todo('Apps installieren', 'BeeSmart, BeeTraffic, Varroa-App', priority: _Priority.medium),
              _Todo('Materialliste finalisieren', 'Alle Produkte in App auswählen und bestellen', priority: _Priority.medium),
            ]),
            _buildPhaseSection(context, 'Phase 1: Erstausstattung (2026)', AppColors.green600, [
              _Todo('Beuten bestellen', '2x Komplettbeute DB Halbzargen bei Wespi'),
              _Todo('Schutzausrüstung kaufen', '2x Jacke, 2x Handschuhe'),
              _Todo('Werkzeug besorgen', 'Stockmeissel, Smoker, Abkehrbesen, Wabenzange'),
              _Todo('Stockwaage bestellen', 'HiveWatch StarterSet bei Bienen Meier AG'),
              _Todo('Varroa-Material', 'Nassenheider, Ameisensäure, Oxalsäure'),
              _Todo('Futter einlagern', 'Apiinvert + Apifonda für Herbst/Notfütterung'),
              _Todo('Beutenständer aufstellen', 'Standort am Maiensäss vorbereiten'),
              _Todo('Bienenvölker kaufen', '2 Ableger Buckfast (ev. von Miel du Ciel)'),
            ]),
            _buildPhaseSection(context, 'Phase 2: Honigverarbeitung (2027)', AppColors.honeyDark, [
              _Todo('Honigschleuder kaufen', 'Logar 20/8 Radial oder Lega TUCANO via apimat.ch'),
              _Todo('Schleuderraum einrichten', 'Im Maiensäss, Hygiene-Anforderungen beachten'),
              _Todo('Verarbeitungsgeräte', 'Entdeckelungsgabel, Doppelsieb, Abfüllbehälter, Refraktometer'),
              _Todo('Honiggläser & Etiketten', 'Design, Goldsiegel-Anforderungen prüfen'),
              _Todo('Erste Honigernte', 'Nur wenn Volk stark genug + genug Vorrat'),
            ]),
            _buildPhaseSection(context, 'Phase 3: Erweiterung (2028-2030)', AppColors.brown600, [
              _Todo('3. + 4. Volk aufbauen', 'Eigene Ableger bilden oder zukaufen'),
              _Todo('5. Volk (Maximum Phase 1-4)', 'Nur bei guter Entwicklung'),
              _Todo('Unterstand/Bienenhaus', 'Planung und Bau am Maiensäss'),
              _Todo('Ev. 2. Stockwaage', 'Für Vergleichsdaten zweites Volk'),
            ]),
            _buildPhaseSection(context, 'Phase 4: Optimierung (2030-2035)', AppColors.brown300, [
              _Todo('Königinnenzucht', 'Eigene Nachzucht für Unabhängigkeit'),
              _Todo('Wachskreislauf aufbauen', 'Eigene Mittelwände giessen'),
              _Todo('Vermarktung', 'Direktverkauf, ev. Label/Marke'),
              _Todo('Weiterbildung', 'Spezialkurse (Zucht, Bienengesundheit)'),
            ]),
            _buildPhaseSection(context, 'Phase 5: Vollausbau ab 2036', Colors.purple.shade400, [
              _Todo('Erweiterung auf 6-8 Völker', 'Nach Pensionierung Lorena'),
              _Todo('Ev. Wanderimkerei', 'Saisonale Standorte (Alp-Tracht)'),
              _Todo('Lehrbienenstand', 'Wissen weitergeben'),
            ]),
            const SizedBox(height: 24),
            _buildAdminSection(context),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  Widget _buildPhaseSection(BuildContext context, String title, Color color, List<_Todo> todos) {
    final done = todos.where((t) => t.done).length;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 16),
        Row(
          children: [
            Container(width: 4, height: 24, decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(2))),
            const SizedBox(width: 12),
            Expanded(child: Text(title, style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: color))),
            Text('$done/${todos.length}', style: TextStyle(fontSize: 13, color: AppColors.brown300)),
          ],
        ),
        const SizedBox(height: 12),
        ...todos.map((todo) => _buildTodoItem(context, todo, color)),
        const SizedBox(height: 8),
      ],
    );
  }

  Widget _buildTodoItem(BuildContext context, _Todo todo, Color color) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8, left: 16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            todo.done ? Icons.check_circle : Icons.radio_button_unchecked,
            size: 20,
            color: todo.done ? AppColors.green600 : (todo.priority == _Priority.high ? AppColors.amber600 : AppColors.brown300),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  todo.title,
                  style: TextStyle(
                    fontWeight: FontWeight.w500,
                    decoration: todo.done ? TextDecoration.lineThrough : null,
                    color: todo.done ? AppColors.brown300 : null,
                  ),
                ),
                if (todo.subtitle != null)
                  Text(todo.subtitle!, style: const TextStyle(fontSize: 12, color: AppColors.brown300)),
              ],
            ),
          ),
          if (todo.priority == _Priority.high && !todo.done)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(color: AppColors.amber600.withAlpha(20), borderRadius: BorderRadius.circular(4)),
              child: const Text('PRIO', style: TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: AppColors.amber600)),
            ),
        ],
      ),
    );
  }

  Widget _buildAdminSection(BuildContext context) {
    return Card(
      color: AppColors.brown50,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              const Icon(Icons.folder, size: 20, color: AppColors.brown600),
              const SizedBox(width: 8),
              const Text('Admin & Organisation', style: TextStyle(fontWeight: FontWeight.bold, color: AppColors.brown600)),
            ]),
            const SizedBox(height: 12),
            _adminRow('Imkerverband GR', 'Beitritt + Grundkurs'),
            _adminRow('Standmeldung', 'Bienenstand bei Kanton GR melden'),
            _adminRow('Betriebsnummer', 'Bei Identitas registrieren (Tierverkehr)'),
            _adminRow('Versicherung', 'Über BienenSchweiz (Elementar/Vergiftung)'),
            _adminRow('Honig-Deklaration', 'Lebensmittelgesetz, Goldsiegel-Anforderungen'),
          ],
        ),
      ),
    );
  }

  Widget _adminRow(String title, String desc) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Icon(Icons.arrow_right, size: 16, color: AppColors.brown300),
        const SizedBox(width: 4),
        SizedBox(width: 130, child: Text(title, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500))),
        Expanded(child: Text(desc, style: const TextStyle(fontSize: 13, color: AppColors.brown600))),
      ]),
    );
  }
}

enum _Priority { high, medium, normal }

class _Todo {
  final String title;
  final String? subtitle;
  final bool done;
  final _Priority priority;

  const _Todo(this.title, this.subtitle, {this.done = false, this.priority = _Priority.normal});
}
