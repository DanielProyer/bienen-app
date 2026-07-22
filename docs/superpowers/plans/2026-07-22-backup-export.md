# F1 Backup & Export — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: superpowers:subagent-driven-development. Steps use `- [ ]` checkboxes.

**Goal:** Tägliches automatisches Offsite-Backup aller Daten + Fotos in ein privates GitHub-Repo, plus ein „Jetzt exportieren"-Knopf in der App, der dasselbe Paket als ZIP herunterlädt.

**Architecture:** Zwei getrennte Einheiten. **(A)** Neues, selbsttragendes Repo `bienen-backup` (lokal `D:\Projekte\Bienen\bienen-backup`) mit GitHub-Actions-Workflow + Node-Skript, das über die Supabase-REST-/Storage-API liest und ins eigene Repo committet. **(B)** Im App-Repo ein neues Feature `lib/features/backup/` mit **reinen, getesteten Format-Funktionen** (identisches Format wie das Node-Skript), einem Export-Service (Fetch + ZIP + Browser-Download) und einer eigenen Seite `/backup`.

**Tech Stack:** Node 20 (ESM, nur `fetch` — keine Abhängigkeiten), GitHub Actions; Flutter Web + `archive`, Riverpod, Baukasten-Widgets.

**Spec:** `docs/superpowers/specs/2026-07-22-backup-export-design.md`

> **Bewusste Abweichung von der Spec (§5):** Die Spec sah einen Abschnitt in `/einstellungen` vor. Diese Seite ist seit dem Design-Umbau ein `FormScaffold` mit Speichern-Bodenleiste — ein unabhängiger Export-Knopf darin würde die Speichern-Semantik verwässern. Stattdessen: **eigene Seite `/backup`**, erreichbar über eine neue Kachel auf der Projekt-Seite (die dafür bereits eine saubere Kachel-Liste hat). Inhalt und Format bleiben exakt wie in der Spec.

---

## Dateistruktur

**(A) Neues Repo `D:\Projekte\Bienen\bienen-backup`** (NICHT im App-Repo!)
```
.gitignore
README.md                     Was das ist + Wiederherstellungs-Anleitung
scripts/backup.mjs            Kern: lesen, schreiben, Gegenproben
.github/workflows/backup.yml  Zeitplan + Schutzriegel (privat?)
backup/<betrieb_id>/…         wird vom Lauf erzeugt
```

**(B) App-Repo `bienen_app`**
- Create: `lib/features/backup/domain/export_format.dart` (REIN) · `lib/features/backup/data/export_service.dart` · `lib/features/backup/presentation/backup_page.dart`
- Test: `test/backup/export_format_test.dart`
- Modify: `pubspec.yaml` (+`archive`) · `lib/core/router/app_router.dart` (Route `/backup`) · `lib/features/projekt/pages/projekt_page.dart` (9. Kachel)

**Format-Vertrag (gilt für BEIDE Implementierungen):**
- **CSV:** beginnt mit BOM `﻿`; Kopfzeile = Spalten alphabetisch sortiert; **jeder** Wert in `"` gequotet, enthaltene `"` verdoppelt; `null` → leerer String; Werte, die Objekte/Arrays sind, als kompaktes JSON.
- **JSON:** Zeilen **stabil sortiert** (nach `id`, sonst nach dem kompakten JSON der Zeile), **Schlüssel alphabetisch**, 2 Space Einrückung, endet mit `\n`.
- **manifest.json:** `{format_version: 1, erstellt_am, betrieb_id, tabellen: {name: zeilen}, fotos: {anzahl, bytes}, schema: [tabelle: [spalten]], warnungen: []}` — Schlüssel ebenfalls alphabetisch, 2 Space.

---

# TEIL A — Backup-Repo

## Task 1: Repo scaffolden

**Files:** Create `D:\Projekte\Bienen\bienen-backup\{.gitignore,README.md}`

- [ ] **Step 1: Ordner + git init**
```bash
mkdir -p /d/Projekte/Bienen/bienen-backup/scripts /d/Projekte/Bienen/bienen-backup/.github/workflows
cd /d/Projekte/Bienen/bienen-backup && git init -b main && git config user.name "DanielProyer" && git config user.email "DanielProyer@users.noreply.github.com"
```
- [ ] **Step 2: `.gitignore`**
```
node_modules/
*.log
.env
```
- [ ] **Step 3: `README.md`**
```markdown
# bienen-backup (PRIVAT)

Automatische Offsite-Sicherung der Bienen-App (Supabase-Projekt `dcdcohktxbhdxnxjvcyp`).

⚠️ **Dieses Repo muss PRIVAT bleiben.** Es enthält Betriebs- und Gesundheitsdaten,
Diagnosefotos und Mitglieder-E-Mails. Der Workflow bricht ab, wenn das Repo öffentlich ist.

## Was hier liegt
`backup/<betrieb_id>/`
- `daten/<tabelle>.json` — originalgetreu (die Wahrheit für eine Wiederherstellung)
- `daten/<tabelle>.csv`  — dieselben Daten in Excel lesbar
- `fotos/<bucket>/<pfad>` — alle Dateien aus den Storage-Buckets
- `manifest.json` — Zeitstempel, Zeilenzahlen, Fotoanzahl, Schema, Warnungen

## Wie es läuft
`.github/workflows/backup.yml` startet täglich 03:15 UTC (und manuell über
„Run workflow"). Das Skript `scripts/backup.mjs` liest über die Supabase-REST-
und Storage-API, schreibt die Dateien und committet nur bei echten Änderungen.
Der tägliche Zugriff hält das Supabase-Projekt zugleich wach.

Benötigte Repo-Secrets: `SUPABASE_URL`, `SUPABASE_SERVICE_ROLE_KEY`.

## Wiederherstellung (Kurzfassung)
1. Gewünschten Stand auswählen — entweder den aktuellen, oder per
   `git log` / `git checkout <commit>` einen früheren Tag.
2. `manifest.json` prüfen: Zeitstempel plausibel? Zeilenzahlen > 0? `warnungen` leer?
3. Daten: die `daten/*.json` je Tabelle in eine leere Datenbank einspielen
   (Reihenfolge nach Fremdschlüsseln: `betriebe`, `profiles`, `betrieb_mitglieder`,
   `standorte`, `koeniginnen`, `voelker`, danach der Rest).
4. Fotos: den Inhalt von `fotos/<bucket>/` in den jeweiligen Storage-Bucket laden,
   Pfade unverändert lassen (die Datenbank verweist auf genau diese Pfade).

Ein Werkzeug für das automatische Zurückspielen kommt mit F1c.
```
- [ ] **Step 4: Commit**
```bash
cd /d/Projekte/Bienen/bienen-backup && git add -A && git commit -m "chore: Repo-Gerüst + README"
```

---

## Task 2: Backup-Skript `scripts/backup.mjs`

**Files:** Create `D:\Projekte\Bienen\bienen-backup\scripts\backup.mjs`

> Kern des Ganzen. Node 20, ESM, **ohne Abhängigkeiten** (nur eingebautes `fetch`/`fs`).

- [ ] **Step 1: Skript schreiben**
```js
// Offsite-Backup der Bienen-App: liest Supabase (REST + Storage) und schreibt
// daten/*.json, daten/*.csv, fotos/** und manifest.json je Betrieb.
// Grundsatz: lieber ein roter Lauf als ein stillschweigend unvollstaendiges Backup.
import { mkdir, writeFile, rm } from 'node:fs/promises';
import { join } from 'node:path';

const URL_BASIS = process.env.SUPABASE_URL;
const KEY = process.env.SUPABASE_SERVICE_ROLE_KEY;
if (!URL_BASIS || !KEY) { console.error('SUPABASE_URL / SUPABASE_SERVICE_ROLE_KEY fehlen'); process.exit(1); }

const KOPF = { apikey: KEY, Authorization: `Bearer ${KEY}` };
const SEITE = 1000;
const warnungen = [];

// ── Hilfen: Format (identisch zur Dart-Seite) ────────────────────────────────
const sortSchluessel = (o) => Object.fromEntries(Object.keys(o).sort().map((k) => [k, o[k]]));
const zeilenSchluessel = (z) => (z.id !== undefined && z.id !== null ? String(z.id) : JSON.stringify(z));

function stabilesJson(zeilen) {
  const sortiert = [...zeilen].sort((a, b) => zeilenSchluessel(a).localeCompare(zeilenSchluessel(b)));
  return JSON.stringify(sortiert.map(sortSchluessel), null, 2) + '\n';
}

function csvVon(zeilen) {
  if (zeilen.length === 0) return '﻿';
  const spalten = [...new Set(zeilen.flatMap((z) => Object.keys(z)))].sort();
  const feld = (w) => {
    if (w === null || w === undefined) return '""';
    const s = typeof w === 'object' ? JSON.stringify(w) : String(w);
    return '"' + s.replaceAll('"', '""') + '"';
  };
  const sortiert = [...zeilen].sort((a, b) => zeilenSchluessel(a).localeCompare(zeilenSchluessel(b)));
  const zeilenTxt = sortiert.map((z) => spalten.map((s) => feld(z[s])).join(','));
  return '﻿' + [spalten.map(feld).join(','), ...zeilenTxt].join('\n') + '\n';
}

// ── Supabase lesen ───────────────────────────────────────────────────────────
async function hole(pfad, extraKopf = {}) {
  const r = await fetch(`${URL_BASIS}${pfad}`, { headers: { ...KOPF, ...extraKopf } });
  if (!r.ok) throw new Error(`GET ${pfad} → ${r.status} ${await r.text()}`);
  return r;
}

/** Tabellen + Spalten aus dem PostgREST-Wurzelschema. Faellt das aus, bricht der Lauf ab. */
async function schemaLesen() {
  const r = await hole('/rest/v1/');
  const spec = await r.json();
  const defs = spec.definitions ?? spec.components?.schemas ?? {};
  const tabellen = {};
  for (const [name, def] of Object.entries(defs)) {
    const spalten = Object.keys(def.properties ?? {});
    if (spalten.length) tabellen[name] = spalten.sort();
  }
  if (Object.keys(tabellen).length < 5) {
    throw new Error(`Schema unplausibel: nur ${Object.keys(tabellen).length} Tabellen erkannt`);
  }
  return tabellen;
}

/** Alle Zeilen einer Tabelle, geblaettert. Prueft am Ende gegen die exakte Anzahl. */
async function tabelleLesen(tabelle, filter = '') {
  const zeilen = [];
  let von = 0, gesamt = null;
  for (;;) {
    const r = await hole(`/rest/v1/${tabelle}?select=*${filter}`, {
      Range: `${von}-${von + SEITE - 1}`, Prefer: 'count=exact',
    });
    const teil = await r.json();
    zeilen.push(...teil);
    const cr = r.headers.get('content-range') || '';
    gesamt = Number(cr.split('/')[1]);
    if (teil.length < SEITE) break;
    von += SEITE;
    if (von > 5_000_000) throw new Error(`${tabelle}: Blaetter-Notbremse`);
  }
  if (Number.isFinite(gesamt) && gesamt !== zeilen.length) {
    throw new Error(`${tabelle}: unvollstaendig — ${zeilen.length} gelesen, ${gesamt} erwartet`);
  }
  return zeilen;
}

async function bucketsLesen() {
  const r = await hole('/storage/v1/bucket');
  return (await r.json()).map((b) => b.name);
}

/** Rekursive, geblaetterte Auflistung eines Bucket-Praefix. */
async function objekteListen(bucket, praefix) {
  const gefunden = [];
  let offset = 0;
  for (;;) {
    const r = await fetch(`${URL_BASIS}/storage/v1/object/list/${bucket}`, {
      method: 'POST', headers: { ...KOPF, 'Content-Type': 'application/json' },
      body: JSON.stringify({ prefix: praefix, limit: SEITE, offset }),
    });
    if (!r.ok) throw new Error(`list ${bucket}/${praefix} → ${r.status}`);
    const teil = await r.json();
    for (const o of teil) {
      const pfad = praefix + o.name;
      if (o.id === null) gefunden.push(...(await objekteListen(bucket, pfad + '/')));
      else gefunden.push({ pfad, bytes: o.metadata?.size ?? 0 });
    }
    if (teil.length < SEITE) break;
    offset += SEITE;
  }
  return gefunden;
}

// ── Hauptlauf ────────────────────────────────────────────────────────────────
const schema = await schemaLesen();
const betriebTabellen = Object.entries(schema)
  .filter(([, sp]) => sp.includes('betrieb_id')).map(([n]) => n).sort();
console.log(`Schema: ${Object.keys(schema).length} Tabellen, davon ${betriebTabellen.length} betriebsbezogen`);

const buckets = await bucketsLesen();
const betriebe = await tabelleLesen('betriebe');
if (betriebe.length === 0) throw new Error('Keine Betriebe gefunden — das ist nie richtig');

await rm('backup', { recursive: true, force: true });

for (const betrieb of betriebe) {
  const bid = betrieb.id;
  const wurzel = join('backup', bid);
  await mkdir(join(wurzel, 'daten'), { recursive: true });
  const tabellenZahl = {};

  const schreibe = async (name, zeilen) => {
    await writeFile(join(wurzel, 'daten', `${name}.json`), stabilesJson(zeilen), 'utf8');
    await writeFile(join(wurzel, 'daten', `${name}.csv`), csvVon(zeilen), 'utf8');
    tabellenZahl[name] = zeilen.length;
  };

  // Mandanten-Wurzeln
  await schreibe('betriebe', [betrieb]);
  const mitglieder = await tabelleLesen('betrieb_mitglieder', `&betrieb_id=eq.${bid}`);
  await schreibe('betrieb_mitglieder', mitglieder);
  const uids = [...new Set(mitglieder.map((m) => m.user_id).filter(Boolean))];
  const profile = uids.length
    ? await tabelleLesen('profiles', `&id=in.(${uids.join(',')})`) : [];
  await schreibe('profiles', profile);

  // Betriebsbezogene Tabellen
  for (const t of betriebTabellen) {
    if (t === 'betrieb_mitglieder') continue;
    await schreibe(t, await tabelleLesen(t, `&betrieb_id=eq.${bid}`));
  }

  // Fotos
  let fotoAnzahl = 0, fotoBytes = 0;
  for (const bucket of buckets) {
    const objekte = await objekteListen(bucket, `${bid}/`);
    for (const o of objekte) {
      const r = await fetch(`${URL_BASIS}/storage/v1/object/${bucket}/${o.pfad}`, { headers: KOPF });
      if (!r.ok) { warnungen.push(`Foto nicht ladbar: ${bucket}/${o.pfad} (${r.status})`); continue; }
      const daten = Buffer.from(await r.arrayBuffer());
      const ziel = join(wurzel, 'fotos', bucket, o.pfad);
      await mkdir(join(ziel, '..'), { recursive: true });
      await writeFile(ziel, daten);
      fotoAnzahl++; fotoBytes += daten.length;
    }
    if (objekte.length !== 0) console.log(`${bucket}: ${objekte.length} Objekte`);
  }

  const manifest = {
    betrieb_id: bid,
    erstellt_am: new Date().toISOString(),
    format_version: 1,
    fotos: { anzahl: fotoAnzahl, bytes: fotoBytes },
    schema: sortSchluessel(schema),
    tabellen: sortSchluessel(tabellenZahl),
    warnungen,
  };
  await writeFile(join(wurzel, 'manifest.json'),
    JSON.stringify(sortSchluessel(manifest), null, 2) + '\n', 'utf8');
  console.log(`Betrieb ${bid}: ${Object.keys(tabellenZahl).length} Tabellen, ${fotoAnzahl} Fotos`);
}

for (const w of warnungen) console.log(`::warning::${w}`);
console.log(`Fertig. ${warnungen.length} Warnung(en).`);
```
- [ ] **Step 2: Syntax prüfen** — `cd /d/Projekte/Bienen/bienen-backup && node --check scripts/backup.mjs`
Erwartet: keine Ausgabe (Datei ist syntaktisch gültig).
- [ ] **Step 3: Commit**
```bash
cd /d/Projekte/Bienen/bienen-backup && git add scripts/backup.mjs && git commit -m "feat: Backup-Skript (Schema-Erkennung, Blaetterung, Gegenproben, Fotos)"
```

---

## Task 3: Workflow `.github/workflows/backup.yml`

**Files:** Create `D:\Projekte\Bienen\bienen-backup\.github\workflows\backup.yml`

- [ ] **Step 1: Workflow schreiben**
```yaml
name: Backup

on:
  schedule:
    - cron: '15 3 * * *'
  workflow_dispatch:

permissions:
  contents: write

jobs:
  backup:
    runs-on: ubuntu-latest
    steps:
      - name: Schutzriegel — Repo muss privat sein
        run: |
          if [ "${{ github.event.repository.private }}" != "true" ]; then
            echo "::error::Repo ist NICHT privat — Backup abgebrochen (Datenschutz)."
            exit 1
          fi

      - uses: actions/checkout@v4

      - uses: actions/setup-node@v4
        with:
          node-version: '20'

      - name: Backup erzeugen
        env:
          SUPABASE_URL: ${{ secrets.SUPABASE_URL }}
          SUPABASE_SERVICE_ROLE_KEY: ${{ secrets.SUPABASE_SERVICE_ROLE_KEY }}
        run: node scripts/backup.mjs

      - name: Committen (nur bei Änderungen)
        run: |
          git config user.name "backup-bot"
          git config user.email "backup-bot@users.noreply.github.com"
          git add -A backup
          if git diff --cached --quiet; then
            echo "Keine Änderungen — kein Commit (Keep-alive trotzdem erfüllt)."
          else
            git commit -m "backup: $(date -u +%Y-%m-%dT%H:%MZ)"
            git push
          fi
```
- [ ] **Step 2: Commit**
```bash
cd /d/Projekte/Bienen/bienen-backup && git add .github/workflows/backup.yml && git commit -m "feat: taeglicher Workflow + Schutzriegel"
```

---

## Task 4: Übergabe an Daniel (Anleitung, keine Zugangsdaten durch Claude)

**Files:** keine — dieser Task erzeugt nur die Anleitung in der Abschluss-Meldung.

- [ ] **Step 1: Anleitung ausgeben** (wortgleich an Daniel weitergeben):
  1. Auf GitHub ein **privates** Repo `bienen-backup` anlegen (ohne README/gitignore-Vorlage).
  2. Lokal verbinden und pushen:
     ```bash
     cd /d/Projekte/Bienen/bienen-backup
     git remote add origin https://github.com/DanielProyer/bienen-backup.git
     git push -u origin main
     ```
  3. Im Repo → Settings → Secrets and variables → Actions → **New repository secret**, zweimal:
     - `SUPABASE_URL` = `https://dcdcohktxbhdxnxjvcyp.supabase.co`
     - `SUPABASE_SERVICE_ROLE_KEY` = der Service-Role-Key aus dem Supabase-Dashboard (Settings → API)
  4. Actions → „Backup" → **Run workflow** (manueller Start).
- [ ] **Step 2: Ersten Lauf verifizieren** (nachdem Daniel gestartet hat): Lauf grün? `manifest.json` im Repo — `tabellen`-Zahlen plausibel (`materials` 52, `weight_readings` 151, `voelker` ≥ 1)? `warnungen` leer? Fotos vorhanden? Bei rotem Lauf: Log lesen, Ursache beheben, erneut starten.

---

# TEIL B — App-Export

## Task 5: Reine Format-Funktionen (TDD)

**Files:** Create `lib/features/backup/domain/export_format.dart` · Test `test/backup/export_format_test.dart` · Modify `pubspec.yaml`

- [ ] **Step 1: `archive` ergänzen** — in `pubspec.yaml` unter `dependencies:` nach `flutter_svg`:
```yaml
  archive: ^3.6.1
```
Dann `cd /d/Projekte/Bienen/bienen_app && flutter pub get`.
- [ ] **Step 2: Failing test** `test/backup/export_format_test.dart`
```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:bienen_app/features/backup/domain/export_format.dart';

void main() {
  test('csvVon: BOM, sortierte Spalten, alles gequotet', () {
    final csv = csvVon([
      {'b': 2, 'a': 'x'},
      {'b': 1, 'a': 'y'},
    ]);
    expect(csv.startsWith('﻿'), isTrue);
    final zeilen = csv.substring(1).trim().split('\n');
    expect(zeilen.first, '"a","b"');
    expect(zeilen.length, 3);
  });

  test('csvVon: Anfuehrungszeichen verdoppelt, null leer', () {
    final csv = csvVon([{'a': 'sagt "hallo"', 'b': null}]);
    expect(csv.contains('"sagt ""hallo"""'), isTrue);
    expect(csv.trim().endsWith(',""'), isTrue);
  });

  test('csvVon: leere Liste ergibt nur BOM', () {
    expect(csvVon(const []), '﻿');
  });

  test('stabilesJson: nach id sortiert, Schluessel alphabetisch', () {
    final json = stabilesJson([
      {'name': 'zweit', 'id': '2'},
      {'name': 'erst', 'id': '1'},
    ]);
    expect(json.indexOf('"id": "1"') < json.indexOf('"id": "2"'), isTrue);
    expect(json.indexOf('"id"') < json.indexOf('"name"'), isTrue);
    expect(json.endsWith('\n'), isTrue);
  });

  test('manifestVon: Pflichtfelder + Warnungen', () {
    final m = manifestVon(
      betriebId: 'b1',
      erstelltAm: DateTime.utc(2026, 7, 22, 10),
      tabellen: {'voelker': 1},
      fotoAnzahl: 3,
      fotoBytes: 99,
      schema: {'voelker': ['id']},
      warnungen: ['x'],
    );
    expect(m.contains('"format_version": 1'), isTrue);
    expect(m.contains('"betrieb_id": "b1"'), isTrue);
    expect(m.contains('2026-07-22T10:00:00.000Z'), isTrue);
    expect(m.contains('"warnungen"'), isTrue);
    expect(m.endsWith('\n'), isTrue);
  });
}
```
- [ ] **Step 3:** `flutter test test/backup/export_format_test.dart` → FAIL.
- [ ] **Step 4: Implement** `lib/features/backup/domain/export_format.dart`
```dart
import 'dart:convert';

/// Format-Vertrag des Backups — identisch zur Node-Seite (scripts/backup.mjs im
/// Repo bienen-backup). Aenderungen hier MUESSEN dort mitgezogen werden;
/// `format_version` im Manifest macht Drift sichtbar.

String _zeilenSchluessel(Map<String, dynamic> z) {
  final id = z['id'];
  return (id == null) ? jsonEncode(z) : id.toString();
}

List<Map<String, dynamic>> _sortiert(List<Map<String, dynamic>> zeilen) {
  final kopie = [...zeilen];
  kopie.sort((a, b) => _zeilenSchluessel(a).compareTo(_zeilenSchluessel(b)));
  return kopie;
}

Map<String, dynamic> _schluesselSortiert(Map<String, dynamic> m) {
  final keys = m.keys.toList()..sort();
  return {for (final k in keys) k: m[k]};
}

/// CSV mit BOM; Spalten alphabetisch, jeder Wert gequotet, `"` verdoppelt,
/// null → leer, Objekte/Listen als kompaktes JSON.
String csvVon(List<Map<String, dynamic>> zeilen) {
  if (zeilen.isEmpty) return '﻿';
  final spalten = <String>{for (final z in zeilen) ...z.keys}.toList()..sort();
  String feld(dynamic w) {
    if (w == null) return '""';
    final s = (w is Map || w is List) ? jsonEncode(w) : w.toString();
    return '"${s.replaceAll('"', '""')}"';
  }
  final kopf = spalten.map(feld).join(',');
  final leib = _sortiert(zeilen)
      .map((z) => spalten.map((s) => feld(z[s])).join(','))
      .join('\n');
  return '﻿$kopf\n$leib\n';
}

/// JSON: stabil sortiert, Schluessel alphabetisch, 2 Space, Zeilenumbruch am Ende.
String stabilesJson(List<Map<String, dynamic>> zeilen) {
  final daten = _sortiert(zeilen).map(_schluesselSortiert).toList();
  return '${const JsonEncoder.withIndent('  ').convert(daten)}\n';
}

/// manifest.json als Text.
String manifestVon({
  required String betriebId,
  required DateTime erstelltAm,
  required Map<String, int> tabellen,
  required int fotoAnzahl,
  required int fotoBytes,
  required Map<String, List<String>> schema,
  required List<String> warnungen,
}) {
  final m = _schluesselSortiert({
    'betrieb_id': betriebId,
    'erstellt_am': erstelltAm.toUtc().toIso8601String(),
    'format_version': 1,
    'fotos': {'anzahl': fotoAnzahl, 'bytes': fotoBytes},
    'schema': _schluesselSortiert(schema),
    'tabellen': _schluesselSortiert(tabellen),
    'warnungen': warnungen,
  });
  return '${const JsonEncoder.withIndent('  ').convert(m)}\n';
}
```
- [ ] **Step 5:** Test → PASS. `flutter analyze lib/features/backup test/backup` → 0.
- [ ] **Step 6: Commit** `feat(backup): reine Export-Format-Funktionen (CSV/JSON/Manifest)`

---

## Task 6: Export-Service (Daten + Fotos → ZIP → Download)

**Files:** Create `lib/features/backup/data/export_service.dart`

> Kein Unit-Test (reines I/O gegen Supabase + Browser-Download); die Formatlogik ist in Task 5 getestet. Verifikation im Browser (Task 8).

- [ ] **Step 1: Implement**
```dart
import 'dart:convert';
import 'dart:typed_data';
import 'package:archive/archive.dart';
import 'package:flutter/foundation.dart';
import 'package:bienen_app/core/supabase/supabase_config.dart';
import 'package:bienen_app/features/backup/domain/export_format.dart';

/// Fortschritts-Meldung waehrend des Exports.
typedef ExportFortschritt = void Function(String schritt, int erledigt, int gesamt);

/// Baut das Export-Paket AUS DER SICHT DES ANGEMELDETEN NUTZERS:
/// alle Abfragen laufen ueber dessen Sitzung, die RLS liefert automatisch nur
/// den aktiven Betrieb. Keine Service-Keys im Client.
class ExportService {
  static const _tabellen = <String>[
    'betriebe', 'betrieb_mitglieder', 'profiles',
    'standorte', 'koeniginnen', 'voelker', 'inspections',
    'behandlungen', 'varroa_kontrollen', 'fuetterungen', 'gesundheitsereignisse',
    'aufgaben', 'vermehrungs_ereignisse', 'volk_bewertungen',
    'materials', 'material_purchases', 'construction_steps',
    'betriebs_einstellungen', 'phaenologie_beobachtungen', 'wissen_fotos',
    'scales', 'scale_alerts', 'weight_readings', 'funkstationen', 'einladungen',
  ];
  static const _buckets = <String>[
    'inspection-photos', 'health-photos', 'wissen-photos',
    'material-media', 'material-receipts', 'construction-photos',
  ];
  static const _seite = 1000;

  /// Liefert das fertige ZIP UND die Warnungen — der Aufrufer darf einen
  /// Teil-Erfolg nicht als vollen Erfolg melden.
  static Future<({Uint8List bytes, List<String> warnungen})> paketBauen({
    required String betriebId,
    ExportFortschritt? fortschritt,
  }) async {
    final client = SupabaseConfig.client;
    final archiv = Archive();
    final warnungen = <String>[];
    final zahlen = <String, int>{};
    final schema = <String, List<String>>{};

    for (var i = 0; i < _tabellen.length; i++) {
      final t = _tabellen[i];
      fortschritt?.call('Tabelle $t', i, _tabellen.length + _buckets.length);
      final zeilen = <Map<String, dynamic>>[];
      try {
        var von = 0;
        for (;;) {
          final teil = await client.from(t).select().range(von, von + _seite - 1);
          zeilen.addAll((teil as List).cast<Map<String, dynamic>>());
          if (teil.length < _seite) break;
          von += _seite;
        }
      } catch (e) {
        warnungen.add('Tabelle $t nicht lesbar: $e');
        continue;
      }
      zahlen[t] = zeilen.length;
      if (zeilen.isNotEmpty) schema[t] = (zeilen.first.keys.toList()..sort());
      _dateiZu(archiv, 'daten/$t.json', utf8.encode(stabilesJson(zeilen)));
      _dateiZu(archiv, 'daten/$t.csv', utf8.encode(csvVon(zeilen)));
    }

    var fotoAnzahl = 0, fotoBytes = 0;
    for (var i = 0; i < _buckets.length; i++) {
      final b = _buckets[i];
      fortschritt?.call('Fotos $b', _tabellen.length + i, _tabellen.length + _buckets.length);
      try {
        for (final pfad in await _pfadeIn(b, '$betriebId/')) {
          try {
            final bytes = await client.storage.from(b).download(pfad);
            _dateiZu(archiv, 'fotos/$b/$pfad', bytes);
            fotoAnzahl++; fotoBytes += bytes.length;
          } catch (e) {
            warnungen.add('Foto nicht ladbar: $b/$pfad');
          }
        }
      } catch (e) {
        warnungen.add('Bucket $b nicht auflistbar: $e');
      }
    }

    _dateiZu(archiv, 'manifest.json', utf8.encode(manifestVon(
      betriebId: betriebId,
      erstelltAm: DateTime.now().toUtc(),
      tabellen: zahlen,
      fotoAnzahl: fotoAnzahl,
      fotoBytes: fotoBytes,
      schema: schema,
      warnungen: warnungen,
    )));

    fortschritt?.call('Paket schnüren', _tabellen.length + _buckets.length,
        _tabellen.length + _buckets.length);
    final roh = ZipEncoder().encode(archiv);
    if (roh == null) throw StateError('ZIP konnte nicht erzeugt werden');
    return (bytes: Uint8List.fromList(roh), warnungen: warnungen);
  }

  /// Rekursive Auflistung eines Bucket-Praefix.
  static Future<List<String>> _pfadeIn(String bucket, String praefix) async {
    final ergebnis = <String>[];
    final eintraege = await SupabaseConfig.client.storage.from(bucket).list(path: praefix);
    for (final e in eintraege) {
      final pfad = '$praefix${e.name}';
      if (e.id == null) {
        ergebnis.addAll(await _pfadeIn(bucket, '$pfad/'));
      } else {
        ergebnis.add(pfad);
      }
    }
    return ergebnis;
  }

  static void _dateiZu(Archive a, String name, List<int> bytes) {
    a.addFile(ArchiveFile(name, bytes.length, bytes));
  }

  /// Loest den Browser-Download aus.
  static void herunterladen(Uint8List bytes, String dateiname) {
    if (!kIsWeb) return;
    downloadImBrowser(bytes, dateiname);
  }
}
```
- [ ] **Step 2: Browser-Download-Helfer** — `lib/features/backup/data/download_web.dart`:
```dart
import 'dart:js_interop';
import 'dart:typed_data';
import 'package:web/web.dart' as web;

void downloadImBrowser(Uint8List bytes, String dateiname) {
  final blob = web.Blob([bytes.toJS].toJS);
  final url = web.URL.createObjectURL(blob);
  final a = web.document.createElement('a') as web.HTMLAnchorElement
    ..href = url
    ..download = dateiname;
  a.click();
  web.URL.revokeObjectURL(url);
}
```
Und in `export_service.dart` oben ergänzen:
```dart
import 'package:bienen_app/features/backup/data/download_web.dart'
    if (dart.library.io) 'package:bienen_app/features/backup/data/download_stub.dart';
```
Plus `lib/features/backup/data/download_stub.dart`:
```dart
import 'dart:typed_data';
void downloadImBrowser(Uint8List bytes, String dateiname) {}
```
**Hinweis:** `package:web` muss ggf. als Dependency ergänzt werden (`web: ^1.1.0`). Falls `dart:html` im Projekt bereits genutzt wird, stattdessen dem dortigen Muster folgen — prüfe mit `grep -rn "dart:html\|package:web" lib`.
- [ ] **Step 3:** `flutter analyze lib/features/backup` → 0 (bei Fehlern in der Web-Interop-Schicht das im Projekt vorhandene Muster aus `lib/features/durchsicht/sprache/web_sprache_erkenner.dart` übernehmen — dort wird `dart:js_interop` bereits erfolgreich eingesetzt).
- [ ] **Step 4: Commit** `feat(backup): Export-Service (Tabellen+Fotos → ZIP → Download)`

---

## Task 7: Seite `/backup` + Projekt-Kachel

**Files:** Create `lib/features/backup/presentation/backup_page.dart` · Modify `lib/core/router/app_router.dart`, `lib/features/projekt/pages/projekt_page.dart`

- [ ] **Step 1: Seite** `backup_page.dart` — `ConsumerStatefulWidget`, `Scaffold(appBar: AppBar(title: Text('Daten & Backup')))`, Inhalt in `AppCard`s mit `SectionHeader`:
  - Karte „Automatisches Backup": erklärender Text — täglich um 03:15 in ein privates GitHub-Repo, Historie aller früheren Stände, Fehlermeldung per E-Mail. (Statischer Text; der Status wird bewusst nicht ausgelesen — siehe Spec §9.)
  - Karte „Jetzt exportieren": kurzer Text („Lädt alle Daten und Fotos deines Betriebs als ZIP herunter."), darunter `AppButton(label: 'Jetzt exportieren', icon: Icons.download, full: true, busy: _laeuft, onPressed: _export)`.
  - Während des Laufs: `LinearProgressIndicator` + der aktuelle Schritt-Text aus dem `ExportFortschritt`-Callback.
  - `_export()`: `betriebId` aus `currentBetriebIdProvider`; `final ergebnis = await ExportService.paketBauen(betriebId: …, fortschritt: (s, e, g) => setState(...))`; danach `ExportService.herunterladen(ergebnis.bytes, 'bienen-export-<yyyy-MM-dd>.zip')`; Erfolgs-Snackbar **nur nach** erfolgreichem `await`. Fehler → Fehler-Snackbar, `_laeuft = false` im `finally`.
  - **Teil-Erfolg nicht als Erfolg melden:** ist `ergebnis.warnungen` nicht leer, lautet die Snackbar „Export erstellt — mit ${ergebnis.warnungen.length} Warnung(en)" (Warnfarbe) statt einer reinen Erfolgsmeldung.
- [ ] **Step 2: Route** in `app_router.dart` neben `/einstellungen` ergänzen:
```dart
GoRoute(path: '/backup', builder: (context, state) => const BackupPage()),
```
(Import ergänzen. Die Route gehört in denselben Zweig wie `/einstellungen`, damit die Shell/der Tab-Highlight stimmt — `app_shell._selectedIndex` zählt `/backup` bereits nicht auf, also **dort `location.startsWith('/backup')` zur Projekt-Gruppe (Index 3) ergänzen**.)
- [ ] **Step 3: Kachel** in `projekt_page.dart` an die Kachel-Liste anhängen:
```dart
    (icon: Icons.cloud_download, titel: 'Daten & Backup', sub: 'Export · Offsite-Sicherung', route: '/backup'),
```
- [ ] **Step 4:** `flutter analyze lib` → 0; `flutter test` → grün.
- [ ] **Step 5: Commit** `feat(backup): Seite /backup + Projekt-Kachel`

---

## Task 8: Abschluss — Voll-Check, Version, Browser, Deploy

- [ ] **Step 1:** `pubspec.yaml` Version → `1.34.0+56`.
- [ ] **Step 2:** `cd /d/Projekte/Bienen/bienen_app && flutter analyze` (0) und `flutter test` (alle grün, inkl. `test/backup/`).
- [ ] **Step 3: Deploy** `bash deploy.sh` (bei DNS-Fehler erneut).
- [ ] **Step 4: Browser-Boot-Check** der Live-Seite: lädt ohne Konsolenfehler.
- [ ] **Step 5: Commit** `chore(backup): v1.34.0 Backup & Export`
- [ ] **Step 6: Daniel-Schritte anstoßen** (Task 4) und den ersten Workflow-Lauf gemeinsam verifizieren.

---

## Self-Review-Notizen
- **Spec-Abdeckung:** Architektur+Workflow (T2/T3), Sicherungsumfang inkl. Mandanten-Wurzeln und Buckets (T2), Format-Vertrag doppelt implementiert und in T5 getestet (T2/T5), manueller Export (T6/T7), Schutzriegel + Secrets + Daniels Schritte (T3/T4), Blätterung + Zeilenzahl-Gegenprobe (T2), Foto-Warnungen (T2/T6), Restore-Anleitung (T1-README).
- **Bewusste Abweichung:** Export-UI als eigene Seite `/backup` statt Abschnitt in `/einstellungen` (dort ist inzwischen ein Speichern-Formular) — oben begründet.
- **Bekannte Doppel-Implementierung** des Formats (Node + Dart) ist Absicht; `format_version` + die Dart-Tests halten sie zusammen.
- **Client-Export nutzt eine feste Tabellenliste** (kein Schemazugriff im Browser). Das ist der eine Punkt, an dem ein neues Modul manuell nachgetragen werden muss — das **automatische** Backup erkennt Tabellen dagegen selbst, und nur dieses ist die Sicherungsgarantie.
- **Web-Interop** (Download) ist der einzige riskante Baustein; T6 verweist auf das im Projekt bereits bewährte `dart:js_interop`-Muster.
