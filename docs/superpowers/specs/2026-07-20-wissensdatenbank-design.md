# Wissensdatenbank — Kontext-Wissen mit Skizzen & eigenen Fotos (Modul 4.21, Zyklus 1)

**Datum:** 2026-07-20
**Status:** Design freigegeben (Abschnitte 1–4); adversariale Multi-Lens-Review (5 Lenses × Skeptiker, Fable 5) eingearbeitet — 19 bestätigte Befunde behoben. Spec zur User-Review.
**Track:** App (`bienen_app/`)
**Modell-Strategie:** Design/Spec Fable 5 hoch · DB-Migration M01 Fable 5 hoch/ultracode · Routine-UI Opus 4.8

---

## 1. Ziel & Kontext

Die App soll Imkerei-Wissen **schnell und im richtigen Moment** liefern: kurze „schnelle Infos" mit Skizze direkt dort, wo man sie braucht (in der Durchsicht bei Brut/Pollen/Futter/Stiften/Weiselzelle), plus einen Link auf die tiefere Recherche. Besonders für Einsteiger: die **richtigen Zeichen erkennen**.

Heute ist Modul 4.21 eine statische Bibliothek (31 gebündelte Markdown-Recherchen unter `assets/recherche/`, inkl. offizieller BGD-Merkblätter). Diese Tiefe bleibt **unverändert** und wird zur „Mehr"-Ebene. Neu kommt eine **schnelle Häppchen-Schicht davor** plus **kontextuelle Deep-Links aus den Modulen**.

Erster Andockpunkt: der **Durchsicht-Wizard** (v1.20.0) mit Waben-Toggles `brut/pollen/futter/honig/mittelwand/leer/baurahmen` und Flags `koenigin/weiselzelle/stifte`.

### Grundprinzipien
- **Mandantenfähig, keine Arosa-Hardcodes.** Der Wissenskatalog ist universelles Imkerei-Fachwissen (nicht standortspezifisch); eigene Fotos sind pro Betrieb isoliert.
- **Generischer Deep-Link:** Module verweisen nur über einen stabilen `key` — nichts modul-spezifisches. Das v1 dockt an der Durchsicht an; die Mechanik ist sofort überall nutzbar.
- **Zwei Bild-Ebenen je Eintrag:** universelle SVG-Skizze (const, offline) + eigene Fotos je Betrieb (DB/Storage, ab v1).
- **Nichts doppelt bauen:** die schnelle Schicht verlinkt in die bestehende Recherche-Bibliothek, ersetzt sie nicht.

---

## 2. Scope (Zyklus 1) & YAGNI-Abgrenzung

**In Scope (v1):**
1. Const-Fachkatalog `kWissensKatalog` mit dem generischen `key`-Deep-Link.
2. Generisches `WissenInfoButton(wissenKey)` + Wissens-Panel (BottomSheet).
3. Foto-Ebene je Betrieb: Tabelle `wissen_fotos` + privater Bucket `wissen-photos` + Upload aus **Kamera / Galerie / Dokumente**.
4. Wissens-Übersicht (Kategorie-Kacheln, Suche, Einstieg zur Recherche-Bibliothek).
5. Erste Inhalts-Scheibe: **7 Durchsicht-Zeichen-Einträge** mit Skizzen, angedockt im Wizard.
6. SVG-Vollbild mit Zoom.

**Bewusst NICHT in v1 (spätere Zyklen):**
- Inhalts-Scheiben für andere Kategorien (Varroa, Fütterung, Recht …) — Kacheln erscheinen erst, sobald sie ≥1 Eintrag haben.
- Foto-Andocken aus der Durchsicht heraus (Inspektionsfoto direkt einem Wissens-Eintrag zuordnen).
- Community-/betriebsübergreifende Foto-Pools (bleibt privat pro Betrieb).
- Foto-Moderation, Tags, Sortierung, Bild-Bearbeitung.
- Redaktion des Katalogs über eine DB (bleibt const/code-gepflegt).

---

## 3. Datenmodell — Ebene A: der const-Fachkatalog

Neues Feature `lib/features/wissen/`. Muster wie `krankheit.dart`/`saison_regeln.dart`: reine `const`-Daten, offline, type-sicher, keine DB, keine RLS.

### 3.1 Modelle (`domain/wissen_eintrag.dart`)
```dart
/// Ein weiterführender Link eines Wissens-Eintrags — GENAU eine Quelle.
class WissensLink {
  final String label;
  final String? rechercheAsset; // z.B. 'assets/recherche/10_Bienenbiologie_Das_Bienenvolk.md'
  final String? url;            // externe Quelle (z.B. offizielles BGD-Merkblatt)
  const WissensLink({required this.label, this.rechercheAsset, this.url})
      : assert((rechercheAsset == null) != (url == null),
            'Genau eine Quelle: rechercheAsset ODER url');
}

/// Ein Wissens-Eintrag = eine „schnelle Info" mit Skizze + Weiterführung.
class WissensEintrag {
  final String key;            // STABIL — der Deep-Link-Anker (kebab/snake, eindeutig)
  final String titel;
  final String kurzinfo;       // 1–3 Sätze, worauf achten
  final String kategorie;      // WissensKategorie.key (Gruppierung/Übersicht)
  final String? skizze;        // Asset-Pfad SVG, z.B. 'assets/wissen/stifte.svg'
  final List<WissensLink> mehr;
  final List<String> verwandte; // keys verwandter Einträge (Quer-Navigation)
  final List<String> stichworte; // zusätzliche Suchbegriffe (Kurzinfo/Titel werden ohnehin durchsucht)
  const WissensEintrag({
    required this.key, required this.titel, required this.kurzinfo, required this.kategorie,
    this.skizze, this.mehr = const [], this.verwandte = const [], this.stichworte = const [],
  });
}

/// Kategorie = ein Schritt im Imkerei-Prozess (für die Übersicht-Kacheln).
class WissensKategorie {
  final String key;      // z.B. 'durchsicht'
  final String titel;    // 'Durchsicht'
  final String icon;     // Material-Icon-Name-Mapping erfolgt in der UI
  const WissensKategorie({required this.key, required this.titel, required this.icon});
}
```

### 3.2 Katalog (`domain/wissen_katalog.dart`)
```dart
const kWissensKategorien = <WissensKategorie>[
  WissensKategorie(key: 'durchsicht', titel: 'Durchsicht', icon: 'eye'),
  // weitere Kategorien erscheinen, sobald sie Einträge haben
];

const kWissensKatalog = <WissensEintrag>[ /* die 7 Einträge aus §10 */ ];

WissensEintrag? wissenVon(String? key) {
  if (key == null) return null;
  for (final e in kWissensKatalog) { if (e.key == key) return e; }
  return null; // KEIN firstWhere ohne orElse — der Null-Kontrakt trägt §5.1 (kein dangling ⓘ)
}

// Reine Funktionen mit optional injizierbaren Daten (Default = globale consts) → mit Fixtures testbar.
Iterable<WissensKategorie> belegteKategorien({
  List<WissensKategorie> kategorien = kWissensKategorien,
  List<WissensEintrag> katalog = kWissensKatalog,
}) => kategorien.where((k) => katalog.any((e) => e.kategorie == k.key));

List<WissensEintrag> eintraegeDerKategorie(String kategorieKey,
        {List<WissensEintrag> katalog = kWissensKatalog}) =>
    katalog.where((e) => e.kategorie == kategorieKey).toList();

/// Volltext-Suche über Titel, Kurzinfo, Stichworte — case-insensitive UND diakritik-normalisiert
/// (ä→ae, ö→oe, ü→ue, ß→ss) auf Query UND Feldern (Details/Implementierung §9).
List<WissensEintrag> sucheWissen(String query, {List<WissensEintrag> katalog = kWissensKatalog}) { /* §9 */ }
```

**Integritäts-Invarianten (durch Tests abgesichert, §14):**
- `key` eindeutig und nicht leer über den ganzen Katalog.
- jeder `verwandte`-key löst via `wissenVon` auf einen existierenden Eintrag auf.
- jeder `WissensLink` erfüllt „genau eine Quelle" (Assert + Test).
- jede `skizze` existiert physisch unter `assets/wissen/` **und** ist von einer `pubspec.yaml`-Asset-Deklaration abgedeckt (§14).
- jede `kategorie` eines Eintrags existiert in `kWissensKategorien`.

---

## 4. Datenmodell — Ebene B: eigene Fotos je Betrieb (DB + Storage)

Etablierte privat-Bucket-Mechanik wie `inspection-photos`/`health-photos`. **Braucht Produktions-Migration M01 (separat freigeben).**

### 4.1 Tabelle `public.wissen_fotos` (Migration `M01_wissen_fotos.sql`)
Muster exakt wie `L01_volk_bewertungen.sql`:
```sql
create table if not exists public.wissen_fotos (
  id uuid primary key default gen_random_uuid(),
  wissen_key text not null check (length(btrim(wissen_key)) > 0),
  storage_path text not null check (storage_path like (betrieb_id::text || '/%')), -- Defense-in-Depth: Pfad im eigenen Betriebs-Ordner
  beschriftung text,
  betrieb_id uuid not null default private.aktive_betrieb_id()
    references public.betriebe(id) on delete cascade,
  created_by uuid, updated_by uuid,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (betrieb_id, id)
);
alter table public.wissen_fotos enable row level security;
revoke all on public.wissen_fotos from anon, public;
grant select, insert, update, delete on public.wissen_fotos to authenticated;
create index if not exists idx_wissen_fotos_key on public.wissen_fotos (betrieb_id, wissen_key);

drop trigger if exists trg_wissen_fotos_actor on public.wissen_fotos;
create trigger trg_wissen_fotos_actor before insert or update
  on public.wissen_fotos for each row execute function private.set_row_actor();
drop trigger if exists trg_wissen_fotos_updated on public.wissen_fotos;
create trigger trg_wissen_fotos_updated before update
  on public.wissen_fotos for each row execute function private.set_updated_at();

drop policy if exists wissen_fotos_sel_member on public.wissen_fotos;
create policy wissen_fotos_sel_member on public.wissen_fotos
  for select to authenticated using (betrieb_id in (select private.meine_betrieb_ids()));
drop policy if exists wissen_fotos_ins_writer on public.wissen_fotos;
create policy wissen_fotos_ins_writer on public.wissen_fotos
  for insert to authenticated with check (private.kann_schreiben(betrieb_id));
drop policy if exists wissen_fotos_upd_writer on public.wissen_fotos;
create policy wissen_fotos_upd_writer on public.wissen_fotos
  for update to authenticated using (private.kann_schreiben(betrieb_id)) with check (private.kann_schreiben(betrieb_id));
drop policy if exists wissen_fotos_del_writer on public.wissen_fotos;
create policy wissen_fotos_del_writer on public.wissen_fotos
  for delete to authenticated using (private.kann_schreiben(betrieb_id));
-- ROLLBACK (vollständig, Bucket + Policies gehören zu M01):
--   drop policy if exists auth_sel_wissen_photos on storage.objects; (analog ins/upd/del — 4×)
--   delete from storage.objects where bucket_id = 'wissen-photos';
--   delete from storage.buckets where id = 'wissen-photos';
--   drop table if exists public.wissen_fotos;
```
`wissen_key` ist **bewusst ohne FK** (der Katalog lebt in Dart-const; die DB kann ihn nicht validieren). Die App steuert Gültigkeit; verwaiste Fotos (falls ein Katalog-key je entfernt wird) sind harmlos (nur unerreichbar) — als bekannter Trade-off notiert.

### 4.2 Bucket `wissen-photos` (im selben Migrationsfile M01)
Muster exakt wie `G02_storage_health_photos.sql`, nur `bucket_id = 'wissen-photos'`, privat (`public=false`), 4 Policies (sel=`ist_mitglied`, ins/upd/del=`kann_schreiben`), Ordner-Regex `foldername[1]` = betrieb_id.

**Storage-Pfad-Konvention:** wir verwenden den **bestehenden `FotoSpeicher`** (`lib/core/storage/foto_speicher.dart`, §8.2) — Pfad `{betrieb_id}/{wissen_key}/foto_{ts}.jpg` (erster Ordner = betrieb_id → RLS-Regex greift; `contentType: 'image/jpeg'`). **Kein eigener Pfad-Builder** (Befund: „nichts doppelt bauen"). Der `storage_path`-CHECK oben (§4.1) verankert die betrieb_id-Präfix-Invariante zusätzlich in der DB.

Optional (serverseitige Härtung, kann in M01 mit): `allowed_mime_types = '{image/jpeg,image/png,image/webp}'` + `file_size_limit` am Bucket setzen.

### 4.3 Advisor-Check
Nach Migration `get_advisors(security)` + `get_advisors(performance)` → **0 neue Findings** (FK-Index auf `betrieb_id` ist über den zusammengesetzten Index abgedeckt; ggf. zusätzlicher Index auf `betrieb_id` prüfen wie in Vorgänger-Migrationen).

---

## 5. Generischer Deep-Link + Andock

### 5.1 `WissenInfoButton` (`presentation/widgets/wissen_info_button.dart`)
Kleines ⓘ (`Icons.info_outline`), das **jedes** Modul neben ein Merkmal setzt:
```dart
WissenInfoButton(wissenKey: 'stifte')
// onPressed → openWissenPanel(context, 'stifte')
```
Rendert nichts, wenn `wissenVon(key) == null` (kein dangling ⓘ zur Laufzeit). Öffnet das Panel via `showModalBottomSheet`.

### 5.2 Andock-Map Durchsicht (`domain/durchsicht_wissen.dart` im wissen-Feature oder im durchsicht-Feature)
```dart
/// Merkmal (Toggle-key bzw. 'flag_*') → Wissens-key. Nur belegte Merkmale bekommen ein ⓘ.
const kDurchsichtWissen = <String, String>{
  'brut': 'brut_offen_verdeckelt',
  'pollen': 'pollen',
  'futter': 'futter_nektar',
  'honig': 'futter_nektar',
  'baurahmen': 'baurahmen_drohnen',
  'flag_koenigin': 'koenigin_finden',
  'flag_weiselzelle': 'weiselzelle',
  'flag_stifte': 'stifte',
};
// 'mittelwand' und 'leer' haben (v1) keinen Eintrag → kein ⓘ.
```
**Test:** jeder Wert in `kDurchsichtWissen` löst via `wissenVon` auf; jeder Schlüssel ist ein bekanntes Merkmal (`kWabenInhalte` bzw. `flag_koenigin/weiselzelle/stifte`).

### 5.3 Einbau in `waben_schritt.dart`
Die Inhalt-`FilterChip`s und die Flag-`FilterChip`s bekommen — wenn das Merkmal in `kDurchsichtWissen` steht — ein nachgestelltes `WissenInfoButton`. Layout: statt eines nackten `FilterChip` im `Wrap` ein `Row(mainAxisSize: min, [FilterChip, WissenInfoButton])`. Merkmale ohne Eintrag bleiben nackte Chips. Keine Änderung an der Waben-Logik/-Datenhaltung.

---

## 6. Das Wissens-Panel (`presentation/widgets/wissen_panel.dart`)

`openWissenPanel(BuildContext, String key)` → `showModalBottomSheet` (scrollbar, `isScrollControlled: true`, ~70 % Höhe, Drag-Handle). Der Sheet-Inhalt ist ein **StatefulWidget mit aktuellem `wissenKey` im State** (nötig für den Verwandte-Wechsel, Punkt 6). Aufbau oben→unten:
1. **Titel** (+ Kategorie-Hinweis klein).
2. **Kurzinfo** (schnelle Info).
3. **SVG-Skizze** (falls vorhanden): `SvgPicture.asset(...)` in fixer, einheitlicher Höhe; antippen → Skizze-Vollbild (§7, via `Navigator.push`). Bildunterschrift „Skizze · antippen für Vollbild".
4. **Meine Beispiele** — `WissenFotoStrip(wissenKey)` (§8): Thumbnails der eigenen Fotos + „+ Foto".
5. **Mehr-Links** — Liste aus `eintrag.mehr`:
   - `rechercheAsset` → **direkter Widget-Push** `Navigator.of(context, rootNavigator: true).push(MaterialPageRoute(builder: (_) => MarkdownViewerPage(title: link.label, assetPath: link.rechercheAsset!)))`. **Keine Route**, kein Asset→Pfad-Mapping (es gibt keine generische `/recherche`-Route); das BottomSheet bleibt darunter erhalten und ist beim Zurück wieder sichtbar. `MarkdownViewerPage` nimmt `(title, assetPath)` bereits als Konstruktor-Parameter.
   - `url` → `url_launcher` (extern; Öffnen ist explizite Nutzeraktion, kein Auto-Open).
6. **Verwandte** — Chips aus `eintrag.verwandte`; Antippen **wechselt den Eintrag IM Panel** (internes State-Switch): `setState(neuerKey)`, Scroll-Position auf 0, `WissenFotoStrip` mit `ValueKey(wissenKey)` neu aufgebaut (der `.family`-Provider aus §8.3 liefert die Fotos pro Key). **Kein `Navigator.pop` + erneutes `showModalBottomSheet`** — der Sheet-Context ist nach pop unmounted (Laufzeit-Crash). `openWissenPanel` ist nur ein dünner Wrapper, der den Start-Key übergibt.

Das Panel kennt **kein Modul** — nur den `key`. Wird 1:1 aus Durchsicht und aus der Übersicht verwendet.

---

## 7. Skizze-Vollbild (`presentation/pages/wissen_skizze_page.dart`)

Vollbild-Widget mit `InteractiveViewer` (min 1×, max ~5×) um `SvgPicture.asset`. Da SVG vektorbasiert ist, ist das die „höher aufgelöste Version" — beliebig scharf. Schließen via AppBar-Back.

**Keine Route** (`/wissen/skizze` mit `extra` bricht bei Flutter-Web-Hash-Routing: bei Reload/Deep-Link/Vor-Zurück ist `state.extra` null → Crash/leere Seite; der Router nutzt bewusst nirgends `extra`). Stattdessen wird das Vollbild **direkt aus dem Panel** geöffnet: `Navigator.of(context, rootNavigator: true).push(MaterialPageRoute(fullscreenDialog: true, builder: (_) => WissenSkizzePage(assetPfad: eintrag.skizze!)))`. `WissenSkizzePage` nimmt den Asset-Pfad als normalen Konstruktor-Parameter (keine URL-Serialisierung nötig); das Panel bleibt darunter, Back kehrt dorthin zurück.

---

## 8. Foto-Erfassung & Daten-Schicht

### 8.1 Modell (`domain/wissen_foto.dart`)
```dart
class WissenFoto {
  final String id;
  final String wissenKey;
  final String storagePath;
  final String? beschriftung;
  final DateTime createdAt;
  const WissenFoto({required this.id, required this.wissenKey, required this.storagePath,
      this.beschriftung, required this.createdAt});
  factory WissenFoto.fromJson(Map<String, dynamic> j) => WissenFoto(
      id: j['id'] as String, wissenKey: j['wissen_key'] as String,
      storagePath: j['storage_path'] as String, beschriftung: j['beschriftung'] as String?,
      createdAt: DateTime.parse(j['created_at'] as String));
}
```
**Read-only-Modell** (kein `toJson`): Rows werden nur gelesen; das Schreiben läuft über den Repository-Upload (§8.2). Der Test in §14 prüft daher `fromJson`-Parsing, keinen Round-Trip.

### 8.2 Repository (`data/wissen_foto_repository.dart`)
Storage läuft über den **bestehenden** `FotoSpeicher(SupabaseConfig.client, 'wissen-photos')` (`lib/core/storage/foto_speicher.dart`) — kein neuer Upload-/SignedUrl-/Remove-Code, keine zweite Pfadkonvention.
- `Future<List<WissenFoto>> ladeFotos(String wissenKey)` — `select … where wissen_key = … and betrieb_id = <aktiv> order by created_at desc`.
  **`.eq('betrieb_id', aktiveBetriebId)` ist PFLICHT**, weil `wissen_key` betriebsübergreifend identisch ist (universeller Katalog-Key): ohne den Filter sähe ein Nutzer mit Mehrfach-Mitgliedschaft die Fotos **aller** seiner Betriebe gemischt (und könnte via `loescheFoto` fremde löschen). RLS bleibt zweite Verteidigungslinie. `aktiveBetriebId` bezieht das Repository ohnehin für den Upload (gleiche Quelle wie inspection/health-Fotos).
- `Future<String> signierteUrl(String storagePath)` — `FotoSpeicher.signedUrl(storagePath)`.
- `Future<WissenFoto> ergaenzeFoto({required String wissenKey, required Uint8List jpegBytes, String? beschriftung})` — `FotoSpeicher.hochladen(betriebId: aktiv, gruppeId: wissenKey, bytes: jpegBytes)` liefert Pfad `{betrieb}/{wissenKey}/foto_{ts}.jpg` → Insert-Row (betrieb_id via Default). Bytes sind bereits JPEG (§8.4).
- `Future<void> loescheFoto(WissenFoto)` — `FotoSpeicher.entfernen([storagePath])` + Row-delete.

### 8.3 Provider (`data/wissen_foto_providers.dart`)
Riverpod `AsyncNotifierProvider.family` **by `wissenKey`** (Muster wie bestehende Foto-Provider). Reload bei Auth-/Betriebswechsel wie in bestehenden Features.

### 8.4 Upload-Quellen (`presentation/widgets/wissen_foto_strip.dart`)
Drei Quellen (Dependencies vorhanden). **Alle drei liefern JPEG-Bytes** an `ergaenzeFoto` (der Bucket speichert `.jpg`/`image/jpeg`):
| Quelle | Paket | Aufruf |
|---|---|---|
| 📷 Kamera | `image_picker` | `ImageSource.camera`, `imageQuality: 75`, `maxWidth: 2000` (App-Standard, erzwingt JPEG-Re-Encode) |
| 🖼️ Galerie | `image_picker` | `ImageSource.gallery`, `imageQuality: 75`, `maxWidth: 2000` (JPEG-Re-Encode) |
| 📄 Dokumente | `file_picker` | `FileType.image` (nur Bilder wählbar); Bytes werden as-is hochgeladen |

Auswahl über ein kleines Aktionsblatt beim Tippen auf „+ Foto". Nach Auswahl → optionale Beschriftung → `ergaenzeFoto`. Thumbnails via `signierteUrl` + `Image.network`. Löschen mit Bestätigungsdialog.

**Format-Hinweis (Dokumente-Quelle):** `image_picker` re-encodet Kamera/Galerie garantiert nach JPEG. `file_picker` liefert die Original-Bytes; wählt jemand ein PNG/WebP, wird es unter `.jpg` gespeichert — Browser rendern das per Content-Sniffing korrekt (kein funktionaler Bruch). **HEIC** rendert im Web nicht; das clientseitige Re-Encoding beliebiger Formate nach JPEG ist eine bewusste v1-Auslassung (spätere Verfeinerung; Kamera/Galerie decken den Haupt-Pfad ab).

**Web-Verhalten (einzige Zielplattform):** `ImageSource.camera` öffnet nur in Mobil-Browsern die Kamera (capture-Attribut); auf Desktop fällt es auf den Dateidialog zurück. Galerie und Dokumente sind auf Web funktional derselbe Browser-Dateidialog (verschiedene Filter) — bewusst als redundante Einstiege akzeptiert, konsistent mit den bestehenden Foto-Features (Durchsicht, Gesundheit, Material, Bau).

**Sicherheit/Datenschutz:** privater Bucket, signierte URLs, RLS pro Betrieb. Kein Autofill, kein Upload ohne Nutzeraktion.

---

## 9. Wissens-Übersicht (`presentation/pages/wissen_overview_page.dart`)

Einstieg (Route `/wissen`), Aufbau:
1. **Suchzeile** — filtert live via `sucheWissen(query)` über Titel + Kurzinfo + Stichworte (case-insensitive). Bei nicht-leerer Query: flache Trefferliste statt Kategorien.
2. **Kategorie-Kacheln** — nur `belegteKategorien()` (kein leeres Gerüst). Tap → Liste `eintraegeDerKategorie` (kann als Sektion in derselben Seite oder eigener Seite `wissen_kategorie_page.dart`; v1: aufklappbare Sektion in der Übersicht, um Seiten zu sparen).
3. **Eintrags-Zeilen** — Skizzen-Thumb + Titel + Kurzinfo-Einzeiler → öffnet das Panel (§6).
4. **„Alle Recherchen & Merkblätter"** — Link auf die bestehende `/recherche`-Bibliothek (unverändert).

`sucheWissen` (rein, diakritik-normalisiert — sonst findet „koenigin" den Eintrag „Königin finden" nicht):
```dart
String _normalisiere(String s) => s.toLowerCase()
    .replaceAll('ä', 'ae').replaceAll('ö', 'oe').replaceAll('ü', 'ue').replaceAll('ß', 'ss');

List<WissensEintrag> sucheWissen(String query, {List<WissensEintrag> katalog = kWissensKatalog}) {
  final q = _normalisiere(query.trim());
  if (q.isEmpty) return const [];
  return katalog.where((e) =>
    _normalisiere(e.titel).contains(q) ||
    _normalisiere(e.kurzinfo).contains(q) ||
    e.stichworte.any((s) => _normalisiere(s).contains(q))).toList();
}
```

**Navigation:** neuer Menüeintrag „Wissen" (bzw. Umbenennung/Ergänzung des bestehenden Recherche-Einstiegs). Der bestehende `/recherche`-Baum bleibt erhalten und erreichbar.

---

## 10. Erste Inhalts-Scheibe: die 7 Durchsicht-Zeichen-Einträge

Alle Kategorie `durchsicht`. Kurzinfos fachlich aus den Recherchen (§Quellen). „Mehr"-Links auf existierende Assets (verifizierte Dateinamen).

| key | Titel | Kurzinfo (Kern) | Skizze zeigt | mehr → |
|---|---|---|---|---|
| `stifte` | Stifte erkennen | Frische Eier: schlanke ~1,5 mm „Reiskörner", **senkrecht** am Zellboden. Sichtbar = Königin hat vor ≤3 Tagen gelegt. | Ei senkrecht (Tag 1) → schräg → liegend (Tag 3) | `10_Bienenbiologie_Das_Bienenvolk.md` |
| `brut_offen_verdeckelt` | Brutbild deuten | Gesund: **flach, geschlossen, lückenlos** verdeckelt. Löcher/„Schrotschuss" = mögliche Störung. **Buckelbrut** (einzeln **hochgewölbte** Deckel auf Arbeiterzellen, verstreut, mehrere Eier/Zelle) = drohnenbrütig/**weisellos** → rasch handeln. (Abgrenzung: gewollte Drohnen-Buckelzellen stehen im **Baurahmen** → `baurahmen_drohnen`.) | Wabe: flach-lückenlose Brut vs. löchrig vs. buckelig-hochgewölbt auf Arbeiterzellen | `10_Bienenbiologie_Das_Bienenvolk.md`, `13_Voelkervermehrung.md`, `14_Bienengesundheit_Krankheiten_CH.md` |
| `pollen` | Pollen & Bienenbrot | Bunte, matt-glänzende, fest eingestampfte Zellen — meist im **Kranz um das Brutnest**. Zeichen für Sammeltätigkeit & Ernährung. | Wabenausschnitt: farbige Pollenzellen im Kranz um Brut | `10_Bienenbiologie_Das_Bienenvolk.md` |
| `futter_nektar` | Futter & Nektar | Offener Nektar: **glänzend, flüssig**, oben in der Wabe. Reifer Honig: **weiß verdeckelt**. Menge grob = Anzahl gefüllter Waben. | Zelle offen-glänzend → verdeckelt weiß | `10_Bienenbiologie_Das_Bienenvolk.md`, `16_Honig_Ernte_Qualitaet_Vermarktung.md` |
| `weiselzelle` | Weiselzelle deuten | **Schwarmzellen**: am Wabenrand/-unterkante, oft mehrere → Schwarmstimmung. **Nachschaffungszellen**: in der Wabenfläche → Volk zieht Ersatz-Königin (Weisellosigkeit). | Wabe: Zellen am Rand (Schwarm) vs. Zellen in der Fläche (Nachschaffung) | `13_Voelkervermehrung.md`, `25_Vermehrung_Jungvolkbildung_BGD.md` |
| `koenigin_finden` | Königin finden | Länger, glänzender Hinterleib, ruhige Bewegung im **Bienenpulk auf offener Brut**. Systematisch Wabe für Wabe, dort suchen, wo Stifte/junge Brut sind. | Wabe mit hervorgehobener Königin im Pulk | `10_Bienenbiologie_Das_Bienenvolk.md`, `12_Koeniginnenzucht.md` |
| `baurahmen_drohnen` | Baurahmen lesen | Im Baurahmen bauen Bienen Drohnenzellen. Verdeckelte Drohnenbrut ausschneiden = **biotechnische Varroa-Reduktion** (Varroa bevorzugt Drohnenbrut). | Baurahmen mit Drohnenbrut-Buckelzellen, Schnittlinie | `15_Varroa_Bekaempfungskonzept_alpin.md`, `22_Varroa_Behandlungskonzept_BGD.md` |

`verwandte`-Verknüpfungen (Beispiele): `stifte↔koenigin_finden↔weiselzelle`, `brut_offen_verdeckelt↔stifte`, `brut_offen_verdeckelt↔weiselzelle` (Weisellosigkeit), `brut_offen_verdeckelt↔baurahmen_drohnen` (Buckel-Abgrenzung), `baurahmen_drohnen↔weiselzelle`, `pollen↔futter_nektar`.

Externe BGD-URL je Eintrag **optional** und nur, wenn eine stabile offizielle Adresse bekannt ist; sonst nur die internen Recherche-Links (kein Raten von URLs).

---

## 11. SVG-Skizzen — Konvention

- Ablage `assets/wissen/*.svg`, in `pubspec.yaml` unter `flutter/assets` deklariert.
- **Einheitliche `viewBox`** (z.B. `0 0 240 160`, Querformat) → gleiche Proportion überall, keine „Auflösungs"-Frage (Vektor ist scharf in jeder Größe).
- **Stil:** flache, klare Linien; sparsame Farbfläche in Honig/Braun-Palette (passend zur App-`AppColors`); Beschriftungen knapp und auf Deutsch. Selbst erstellt → urheberrechtlich sauber (keine BGD-/Web-Grafiken).
- **Theme:** die App ist hell-thematisiert; Skizzen auf hellem Panel-Grund. Linien in kräftigem Braun (`#633806`/`#854F0B`-Bereich), damit sie auf hellem Grund sicher lesbar sind.
- Rendering via `flutter_svg` (`SvgPicture.asset`).
- **Erstellung:** die 7 Skizzen werden im Umsetzungszyklus als Inhalt produziert (klare, beschriftete Prinzip-Skizzen — nicht fotorealistisch). Fotorealismus liefern später die eigenen Fotos.

---

## 12. Datei-Architektur

```
lib/features/wissen/
  domain/
    wissen_eintrag.dart        # WissensEintrag, WissensLink, WissensKategorie
    wissen_katalog.dart        # kWissensKategorien, kWissensKatalog, wissenVon, belegteKategorien,
                               #   eintraegeDerKategorie, sucheWissen
    durchsicht_wissen.dart     # kDurchsichtWissen (Andock-Map)
    wissen_foto.dart           # WissenFoto (read-only Modell, nur fromJson)
  data/
    wissen_foto_repository.dart # ladeFotos (betrieb_id-Filter!) + FotoSpeicher('wissen-photos') wiederverwenden
    wissen_foto_providers.dart  # Riverpod AsyncNotifier.family (by wissenKey), Reload bei Betriebswechsel
  presentation/
    pages/
      wissen_overview_page.dart # Kategorien + Suche + Recherche-Einstieg
      wissen_skizze_page.dart   # Vollbild-Zoom (InteractiveViewer), per Navigator.push geöffnet (KEINE Route)
    widgets/
      wissen_info_button.dart   # generisches ⓘ (nimmt wissenKey)
      wissen_panel.dart         # das BottomSheet (openWissenPanel, StatefulWidget mit aktivem key)
      wissen_foto_strip.dart    # „Meine Beispiele" + Upload-Quellen

assets/wissen/                  # 7 SVG-Skizzen
supabase/migrations/
  M01_wissen_fotos.sql          # Tabelle + Bucket + RLS + Trigger

# geändert:
lib/features/durchsicht/presentation/widgets/waben_schritt.dart  # ⓘ neben belegten Merkmalen
lib/.../app_router.dart         # nur EINE neue Route: /wissen (Skizze-Vollbild + Recherche-Detail laufen per Navigator.push)
(Navigation/Cockpit)            # Menüeintrag „Wissen"
pubspec.yaml                    # flutter_svg + assets/wissen/
```

---

## 13. Routing
- **Einzige neue Route:** `/wissen` → `WissenOverviewPage`.
- Panel ist **keine** Route (BottomSheet), damit es kontextnah über jedem Screen liegt.
- **Skizze-Vollbild und Recherche-Detail aus dem Panel per direktem `Navigator.push`** (`rootNavigator`), **keine neue Route** — das vermeidet das `extra`-Problem des Web-Hash-Routings (siehe §7) und hält das BottomSheet darunter erhalten.
- Bestehende `/recherche`-Routen **unverändert** (die Recherche-Bibliothek bleibt, wie sie ist; der Wissens-Link öffnet `MarkdownViewerPage` direkt als gepushtes Widget).

---

## 14. Tests

**Rein/Domain (Kern-Absicherung, kein DB-Zugriff):**
- `wissen_katalog_test.dart`:
  - alle `key` eindeutig & nicht leer.
  - jeder `verwandte`-key löst via `wissenVon` auf.
  - jede `kategorie` existiert in `kWissensKategorien`.
  - jeder `WissensLink`: genau eine Quelle (rechercheAsset XOR url).
  - jede `skizze`: **Datei existiert** unter `assets/wissen/` (`File.existsSync`) **und** der Pfad ist von einer `pubspec.yaml`-Deklaration abgedeckt (deklariertes Verzeichnis-Präfix `assets/wissen/` **oder** exakter Eintrag — Präfix-Match, nicht String-Gleichheit).
  - jedes `rechercheAsset` existiert unter `assets/recherche/` (`File.existsSync`).
  - **Null-Kontrakt (trägt §5.1):** `wissenVon(null)` und `wissenVon('gibt_es_nicht')` liefern `null` (kein Throw).
  - **`belegteKategorien` Filterlogik:** gegen den echten Katalog enthält sie `durchsicht`; die Ausblendung leerer Kategorien wird gegen ein **injiziertes Fixture** geprüft (`belegteKategorien(kategorien: [durchsicht, leere], katalog: […nur durchsicht…])` → `leere` fehlt).
- `durchsicht_wissen_test.dart`: jeder Wert in `kDurchsichtWissen` löst via `wissenVon` auf; jeder Schlüssel ist bekanntes Merkmal (`kWabenInhalte ∪ {flag_koenigin,flag_weiselzelle,flag_stifte}`).
- `wissen_suche_test.dart`: `sucheWissen('')` und `sucheWissen('   ')` (nur Whitespace) → leer; Treffer bei Titel/Kurzinfo/Stichwort; **case-insensitive UND diakritik-normalisiert**: `sucheWissen('koenigin')` findet „Königin finden" und `sucheWissen('königin')` ebenso.
- `wissen_foto_test.dart`: `WissenFoto.fromJson` parst eine Beispiel-Row (mit `beschriftung` = null **und** gesetzt) korrekt in alle Felder (id, wissenKey, storagePath, beschriftung, createdAt). *(Kein Round-Trip — read-only Modell, kein toJson.)*

**Migration/Repository (manuell im Zuge M01):**
- Rollback-Test **vollständig**: create → insert als Mitglied → cross-tenant-select liefert 0 → dann Policies/Objekte/Bucket-Row **und** Tabelle entfernen; danach prüfen, dass keine `wissen-photos`-Artefakte in `storage.buckets`/`storage.objects`/`pg_policies` und keine `wissen_fotos`-Tabelle zurückbleiben.
- `storage_path`-CHECK: Insert mit Pfad unter fremder betrieb_id → Check-Violation erwartet.
- **Mandanten-Isolation `ladeFotos`:** Verifikation, dass ein Nutzer mit Mehrfach-Mitgliedschaft bei `ladeFotos('stifte')` nur die Fotos des **aktiven** Betriebs sieht (der `.eq('betrieb_id', …)`-Filter greift, nicht nur RLS).
- `get_advisors(security)` + `get_advisors(performance)` → **0 neue** Findings.

**Nicht getestet (bewusst):** Widget-/Golden-Tests des Panels und der Foto-Strip-UI (v1 manuell im Browser verifiziert); echte Supabase-Foto-Uploads (Repository dünn, im Live-Test geprüft).

---

## 15. Migrations-, Deploy- & Sicherheits-Notes
- **M01** ist die einzige Produktions-Migration; **separat freigeben** (Bucket + Tabelle + RLS + Trigger). Nummeriertes File **und** via Supabase-MCP `apply_migration`. Kopf-Kommentar, `revoke … from anon, public`, `grant … to authenticated`, ROLLBACK-Kommentar. `get_advisors(security+performance)` → 0 neue.
- **flutter_svg** als neue Dependency (bekannt, breit genutzt). `flutter analyze` muss sauber bleiben.
- Deploy nach grünen Tests via `bash deploy.sh` (Version-Bump, cache-bust) — Standard-Freigabe.
- Keine Arosa-Hardcodes; Katalog ist universell; Fotos betrieb-isoliert.

---

## 16. Spätere Zyklen (Backlog, nicht v1)
- Weitere Inhalts-Scheiben: Varroa, Fütterung, Königin-Zucht, Recht/Meldewesen, Honig-Ernte, Krankheiten (je mit Skizzen).
- Inspektionsfoto direkt aus der Durchsicht einem Wissens-key zuordnen.
- Andocken weiterer Module (Behandlung → Varroa-Einträge, Fütterung → Futter-Einträge, Gesundheit → Krankheits-Einträge).
- Ggf. Foto-Sortierung/Tags/Beschriftung-Bearbeitung.
- Sprach-Eingabe der Durchsicht (eigener Modul-Zyklus 2).

---

## Quellen (Fachwissen)
`imkerei/02_Recherche/` bzw. gebündelt `assets/recherche/`: `10_Bienenbiologie_Das_Bienenvolk`, `12_Koeniginnenzucht`, `13_Voelkervermehrung`, `14_Bienengesundheit_Krankheiten_CH`, `15_Varroa_Bekaempfungskonzept_alpin`, `16_Honig_Ernte_Qualitaet_Vermarktung`, `17_Wachs_Wabenmanagement`, `22_Varroa_Behandlungskonzept_BGD`, `25_Vermehrung_Jungvolkbildung_BGD`.
