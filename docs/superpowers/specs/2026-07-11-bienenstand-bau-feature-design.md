# Design-Spec: App-Feature „Bienenstand-Bau"

*Stand: 2026-07-11 · Projekt Bienen Arosa · bienen_app (Flutter Web)*

## 1. Ziel

Alle Bauinformationen des Bienenstands (Variante 2, Bauplan v4) direkt in der App verfügbar machen **und** den Bauablauf aus der App heraus dokumentieren können (Fortschritt abhaken, Fotos hochladen, Notizen). Geräteübergreifend synchron (Daniel + Lorena) über Supabase.

**Verbindliche Grundlage:** `Projektwissen_Bienenstand.md`, `bienenstand_bauanleitung_detail_1.md`, `bienenstand_variante2_bauplan.pdf` (alle v4, inhaltlich deckungsgleich) sowie die neue `bienenstand_bau_checkliste.md`. Masse verbindlich – nichts neu erfinden.

## 2. Umfang (entschieden)

- **Bauinfos:** voller v4-Bauplan in der App (Referenzansicht).
- **Dokumentation:** Supabase-Sync mit Foto-Upload.
- **Navigation:** neuer 6. Tab „Bau".
- **Gewählter Ansatz:** A – ein „Bau"-Tab mit zwei Bereichen (Bauplan / Dokumentation).

Nicht im Umfang (YAGNI): Bearbeiten des Bauplan-Textes in der App; mehrere Fotos pro Schritt (erweiterbar); Auth/Nutzer-Zuordnung (App ist bewusst public-RLS wie der Rest).

## 3. Architektur

Neues Feature `lib/features/construction/`, strikt nach dem bestehenden `material/`-Muster (Clean-Architecture-Trennung, manuelle Riverpod-Provider, kein Codegen).

```
lib/features/construction/
  data/models/
    construction_step.dart        # Model (immutable, copyWith, fromJson/toJson snake_case)
  presentation/
    pages/
      construction_page.dart      # Tab-Umschalter Bauplan / Dokumentation
      bauplan_view.dart           # Referenz: Markdown + ISO-Bild + PDF-Button
    providers/
      construction_provider.dart  # AsyncNotifier + abgeleitete Provider
    widgets/
      construction_step_tile.dart # Abhaken + Foto-Thumbnail + Notiz + Upload
```

Wiederverwendung: Bauplan-Text rendert über das Muster von `MarkdownViewerPage` (`flutter_markdown`, bereits im Projekt). Farben ausschliesslich aus `AppColors`; Karten via `Card(...)`.

## 4. Datenmodell

### 4.1 Model `ConstructionStep`

| Feld | Typ | DB-Key | Bemerkung |
|---|---|---|---|
| id | String | id | uuid |
| phase | String | phase | Gruppierung: `vorbereitung`, `einkauf`, `bau`, `abnahme`, `nachkontrolle` |
| fotoCode | String | foto_code | z. B. `F06` |
| title | String | title | Was tun / fotografieren |
| soll | String? | soll | Kontrollmass (nullable) |
| sortOrder | int | sort_order | Reihenfolge |
| isDone | bool | is_done | abgehakt |
| note | String? | note | Freitext-Notiz |
| photoUrl | String? | photo_url | Public-URL im Storage |
| photoTakenAt | DateTime? | photo_taken_at | Zeitstempel Foto |
| updatedAt | DateTime? | updated_at | Trigger-gepflegt |

`copyWith`, `fromJson`, `toJson` analog `material_item.dart`.

### 4.2 Supabase-Tabelle `construction_steps`

- Spalten wie oben; `id uuid default gen_random_uuid()`, `is_done boolean default false`, `sort_order int`, `updated_at timestamptz default now()`.
- RLS aktiviert, Policies „Allow public read/insert/update" (wie `materials`).
- `updated_at`-Trigger (bestehende Trigger-Funktion wiederverwenden).
- **Seed:** die 19 F-Punkte (F00–F18) aus `bienenstand_bau_checkliste.md`, mit `phase`, `foto_code`, `title`, `soll`, `sort_order`. Eine Quelle der Wahrheit.

### 4.3 Storage-Bucket `construction-photos`

- Public read/write (passend zum bestehenden public-Ansatz der App).
- Dateiname deterministisch: `<step_id>.jpg` (upsert überschreibt bei Neuaufnahme).
- Anlage per Supabase-MCP (Migration inkl. `storage.buckets`-Insert + Object-Policies).

## 5. Providers (`construction_provider.dart`)

```dart
final constructionStepsProvider =
    AsyncNotifierProvider<ConstructionStepsNotifier, List<ConstructionStep>>(
        ConstructionStepsNotifier.new);
```

- `build()` → `.from('construction_steps').select().order('sort_order')`, Fallback auf lokale Seed-Liste bei Exception (wie material).
- `toggleDone(id, done)` – Optimistic-Update + `.update({'is_done': done}).eq('id', id)`, Revert bei Fehler.
- `updateNote(id, note)` – analog.
- `attachPhoto(id, bytes)` – Upload nach Storage → `getPublicUrl` → `.update({'photo_url':…, 'photo_taken_at':…})`; Optimistic mit Revert; Upload-Fehler → SnackBar + Retry, Status bleibt erhalten.
- Abgeleitet: `constructionProgressProvider` (Provider) → `(done, total)` für Fortschrittsbalken; optional `stepsByPhaseProvider` für Gruppierung.

## 6. Foto-Upload (neuer Baustein)

- Package: `image_picker` (Web-tauglich) in `pubspec.yaml`.
- Ablauf: `ImagePicker().pickImage(source: gallery|camera)` → `XFile.readAsBytes()` → `client.storage.from('construction-photos').uploadBinary('<id>.jpg', bytes, fileOptions: FileOptions(upsert: true))` → `getPublicUrl` → Model aktualisieren.
- Thumbnail im Tile via `Image.network(photoUrl)`; Tap → Vollbild-Vorschau (einfacher Dialog).

## 7. Navigation

- `app_router.dart`: neue `GoRoute(path: '/construction', builder: … ConstructionPage())` als ShellRoute-Kind.
- `app_shell.dart`: 6. Tab „Bau" (`Icons.construction`) an **drei** Stellen ergänzen: `_selectedIndex()` (Prefix `/construction` → 5), `_onDestinationSelected()` (case 5 → `/construction`), **beide** Destination-Listen (NavigationRail + NavigationBar).
- Auf `bauplan_view.dart` ein Button „Zur Einkaufsliste" → `context.go('/material')` (bestehende Materialliste, keine Duplizierung).

## 8. Bauplan-Referenzansicht

- `bauplan_view.dart` zeigt: `bienenstand_iso.png` (Übersichtsbild), den vollen v4-Text als Markdown (`assets/bauplan/bienenstand_bauplan.md`), Button „Bauplan als PDF öffnen" (`url_launcher` auf das gebündelte Asset).
- Assets neu registrieren in `pubspec.yaml`: Verzeichnis `assets/bauplan/` mit `bienenstand_bauplan.md`, `bienenstand_variante2_bauplan.pdf`, `bienenstand_iso.png`.

## 9. Vorarbeiten (Repo & Doku-Aufräumen)

- Git-Repo ist `bienen_app/`. Bau-Dokumente liegen unter `D:\Projekte\Bienen\03_Bienenstand` (ausserhalb Repo).
- Kopieren nach `bienen_app/assets/bauplan/`: `bienenstand_variante2_bauplan.pdf`, `bienenstand_iso.png`; den v4-Volltext als `bienenstand_bauplan.md` (aus `bienenstand_bauanleitung_detail_1.md`).
- Ordner `03_Bienenstand/fotos/` anlegen (externe Foto-Ablage des Nutzers bleibt bestehen; App-Fotos gehen in Storage).
- Da alle Dokumente v4-konsistent sind: kein Inhaltskonflikt, nur Ablage ordnen.

## 10. Fehlerbehandlung & Tests

- Alle async States via `.when(loading/error/data)` (Muster vorhanden); Offline-Fallback lokale Seed-Liste.
- Upload-/Update-Fehler: Optimistic-Revert + SnackBar mit Retry.
- Tests: Unit für `ConstructionStep.fromJson/toJson` und `toggleDone` (Optimistic/Revert). Manueller Web-Durchlauf für Kamera/Upload (Storage ist nicht sinnvoll unit-testbar ohne Mock-Layer, der im Projekt nicht existiert).

## 11. Offene Git-Frage (vor Umsetzung klären)

Das Repo hat bereits uncommittete Änderungen (Monitoring-Feature untracked; `app_router.dart`, `app_shell.dart`, `pubspec.yaml`, `pubspec.lock` modifiziert). Vor der Umsetzung entscheiden: auf Feature-Branch arbeiten, und wie mit den bestehenden uncommitteten Änderungen verfahren wird.
