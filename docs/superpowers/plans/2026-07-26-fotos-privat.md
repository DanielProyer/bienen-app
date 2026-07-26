# F2 Teil 1 — Fotos absichern: Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: superpowers:subagent-driven-development. Steps use `- [ ]` checkboxes.

**Goal:** Kein Foto mehr ohne Login erreichbar, und kein Foto mit Standortdaten im Storage.

**Architecture:** Migration P01 schaltet die drei öffentlichen Buckets auf privat (Alt-Objekte über eine Join-Policy weiter lesbar, DB-URLs → Pfade). In der App wird `FotoSpeicher` der **einzige** Upload-Weg; er entfernt vor dem Upload alle Bildmetadaten (Canvas-Re-Encode) und liefert einen Pfad. Die Anzeige läuft über Signed-URLs.

**Tech Stack:** Postgres/Supabase Storage-RLS, Flutter Web, `dart:js_interop` (kein `package:web`), Riverpod.

**Spec:** `docs/superpowers/specs/2026-07-26-datenschutz-fotos-design.md`

---

## Verifizierte Grundlagen (nicht erneut annehmen)

- **`FotoSpeicher`** (`lib/core/storage/foto_speicher.dart`) hat: `hochladen({required betriebId, required gruppeId, required bytes}) → Future<String>` (Pfad `<betrieb_id>/<gruppeId>/foto_<microsec>.jpg`, `upsert: true`, `image/jpeg`), **`signedUrl(pfad, {ablaufSekunden = 3600})`** (⚠️ so heißt sie — *nicht* `signierteUrl`), `entfernen(List<String>)`.
- **Upload-Pfade heute** (alle schon mandanten-korrekt): `material-media` → `$betriebId/${item.id}/photo_<ms>.jpg`; `material-receipts` → `$betriebId/${item.id}_<ms>.jpg`; `construction-photos` → `$betriebId/$stepKey.jpg` **deterministisch mit `upsert: true`** (pro Bauschritt genau ein Objekt — das muss erhalten bleiben, sonst sammeln sich Waisen).
- **DB-Ist:** `materials.photo_urls` = 26 Zeilen mit **vollen** öffentlichen URLs; `materials.pdf_urls`, `material_purchases.beleg_foto`, `construction_steps.photo_url` = **alle leer**. 28 Alt-Objekte in `material-media` unter `<material_id>/…` (ohne `betrieb_id`-Präfix).
- **Interop-Muster im Projekt:** `lib/features/durchsicht/sprache/data/{web_sprache_erkenner.dart, erkenner_plattform_stub.dart, sprach_controller.dart}` — `dart:js_interop` (+ `dart:js_interop_unsafe`) mit bedingtem Import. **Gotcha:** `flutter analyze` prüft js_interop nicht vollständig gegen das Web-Ziel → nach Interop-Arbeit `flutter build web --release` als Beweis.

---

## Dateistruktur

**Neu:** `supabase/migrations/P01_fotos_privat.sql` · `lib/core/storage/ohne_metadaten.dart` (+ `ohne_metadaten_web.dart`, `ohne_metadaten_stub.dart`) · `lib/core/storage/foto_quelle.dart` (REIN) · Tests `test/storage/foto_quelle_test.dart`
**Geändert:** `lib/core/storage/foto_speicher.dart` · `lib/features/material/presentation/pages/material_detail_page.dart` · `lib/features/construction/presentation/providers/construction_provider.dart`

---

## Task 1: Migration P01 (Produktion) — Controller, braucht Freigabe

**Files:** Create `supabase/migrations/P01_fotos_privat.sql`

- [ ] **Step 1: File schreiben**
```sql
-- P01_fotos_privat.sql | F2 Teil 1: keine Fotos ohne Login.
-- Die drei Buckets waren public=true; damit liefert /storage/v1/object/public/...
-- OHNE Login aus und umgeht die RLS-Policies vollstaendig.
update storage.buckets set public = false
 where name in ('material-media','material-receipts','construction-photos');

-- ALT-LAST: 28 Objekte in material-media liegen unter <material_id>/… statt
-- <betrieb_id>/… (Befuellung vor der Praefix-Haertung). Ein Umzug per SQL ist
-- NICHT sicher (storage.objects.name ist der Backend-Schluessel; Umbenennen
-- wuerde die Dateien ins Leere zeigen lassen). Diese Policy erreicht dasselbe
-- Schutzziel ohne Datenbewegung: Lesen nur fuer Mitglieder des Betriebs, dem
-- das Material gehoert. Darf entfallen, sobald die Alt-Objekte umgezogen sind.
create policy auth_sel_material_media_altpfad on storage.objects
  for select to authenticated
  using (
    bucket_id = 'material-media'
    and exists (
      select 1 from public.materials m
       where m.id::text = (storage.foldername(name))[1]
         and private.ist_mitglied(m.betrieb_id)
    )
  );

-- Signed-URLs entstehen zur Laufzeit -> gespeichert wird der PFAD (konsistent
-- zu inspections.foto_urls und wissen_fotos.storage_path).
update public.materials
   set photo_urls = (
     select array_agg(regexp_replace(u,
       '^https?://[^/]+/storage/v1/object/public/material-media/', ''))
       from unnest(photo_urls) u)
 where photo_urls is not null and array_length(photo_urls, 1) > 0;

-- ROLLBACK: update storage.buckets set public = true where name in (...);
--           drop policy auth_sel_material_media_altpfad on storage.objects;
--           update public.materials set photo_urls = (select array_agg(
--             'https://dcdcohktxbhdxnxjvcyp.supabase.co/storage/v1/object/public/material-media/' || u)
--             from unnest(photo_urls) u) where ...;
```
- [ ] **Step 2: Vor-Zustand für den Beweis festhalten** — eine echte öffentliche URL besorgen und prüfen, dass sie **jetzt noch** funktioniert:
```bash
cd /d/Projekte/Bienen/bienen_app
curl -s -o /dev/null -w "VORHER: %{http_code}\n" \
 "https://dcdcohktxbhdxnxjvcyp.supabase.co/storage/v1/object/public/material-media/e6287d8c-0f9d-4901-a0bb-73ce0359de1c/photo_web.jpg"
```
Erwartet: `VORHER: 200`. (Falls 404: per `execute_sql` `select name from storage.objects where bucket_id='material-media' limit 3;` einen gültigen Pfad holen und diesen verwenden.)
- [ ] **Step 3: Anwenden** via Supabase-MCP `apply_migration` (Name `P01_fotos_privat`, Projekt `dcdcohktxbhdxnxjvcyp`) — **erst nach Daniels Freigabe**.
- [ ] **Step 4: Nachweis + Verifikation**
```bash
curl -s -o /dev/null -w "NACHHER: %{http_code}\n" \
 "https://dcdcohktxbhdxnxjvcyp.supabase.co/storage/v1/object/public/material-media/e6287d8c-0f9d-4901-a0bb-73ce0359de1c/photo_web.jpg"
```
Erwartet: **400 oder 404** — das ist der eigentliche Beweis, dass die Lücke zu ist. Zusätzlich per `execute_sql`:
```sql
select (select count(*) from storage.buckets where public) as noch_public,          -- erwartet 0
       (select count(*) from public.materials
         where exists (select 1 from unnest(photo_urls) u where u like 'http%')) as noch_urls, -- erwartet 0
       (select count(*) from pg_policies
         where tablename='objects' and policyname='auth_sel_material_media_altpfad') as policy; -- erwartet 1
```
Dann `get_advisors(security)` + `(performance)` → **0 neue** Findings.
- [ ] **Step 5: Commit** `feat(datenschutz): P01 Migration — Buckets privat, Alt-Pfad-Policy, URLs zu Pfaden`

---

## Task 2: Reine Foto-Quelle-Unterscheidung (TDD)

**Files:** Create `lib/core/storage/foto_quelle.dart` · Test `test/storage/foto_quelle_test.dart`

> Warum eigene Datei: Nach der Migration stehen in der DB **Pfade**, aber ein übersehener Altwert (oder ein künftiger Import) könnte eine volle URL sein. Diese Entscheidung wird an drei Anzeigestellen gebraucht — also einmal rein und getestet, statt dreimal `startsWith('http')` im Widget.

- [ ] **Step 1: Failing test**
```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:bienen_app/core/storage/foto_quelle.dart';

void main() {
  test('volle URL wird direkt verwendet', () {
    expect(istVolleUrl('https://x.supabase.co/storage/v1/object/public/b/p.jpg'), isTrue);
    expect(istVolleUrl('http://x/p.jpg'), isTrue);
  });

  test('Pfad muss signiert werden', () {
    expect(istVolleUrl('1c84d5dd-aaaa/abc/foto_1.jpg'), isFalse);
    expect(istVolleUrl('e6287d8c/photo_web.jpg'), isFalse);
  });

  test('leer/Unsinn gilt nicht als URL', () {
    expect(istVolleUrl(''), isFalse);
    expect(istVolleUrl('   '), isFalse);
    expect(istVolleUrl('httpsohneschema/p.jpg'), isFalse);
  });
}
```
- [ ] **Step 2:** `cd /d/Projekte/Bienen/bienen_app && flutter test test/storage/foto_quelle_test.dart` → FAIL.
- [ ] **Step 3: Implement** `lib/core/storage/foto_quelle.dart`
```dart
/// Unterscheidet gespeicherte Foto-Werte: Nach P01 stehen in der DB PFADE
/// (die zur Laufzeit signiert werden). Ein Wert, der noch eine volle URL ist
/// (uebersehener Altbestand, kuenftiger Import), wird direkt verwendet — so
/// bleibt die Galerie in jedem Fall sichtbar statt leer.
bool istVolleUrl(String wert) {
  final w = wert.trim();
  return w.startsWith('http://') || w.startsWith('https://');
}
```
- [ ] **Step 4:** Test → PASS.
- [ ] **Step 5: Commit** `feat(datenschutz): reine Unterscheidung Pfad vs. volle URL`

---

## Task 3: Metadaten-Strip (Canvas, mit VM-Stub)

**Files:** Create `lib/core/storage/ohne_metadaten.dart`, `ohne_metadaten_web.dart`, `ohne_metadaten_stub.dart`

> **Zuerst lesen:** `lib/features/durchsicht/sprache/data/web_sprache_erkenner.dart` und `erkenner_plattform_stub.dart` + wie `sprach_controller.dart` den bedingten Import schreibt. Genau dieses Muster übernehmen (`dart:js_interop`, **kein** `package:web` — das Paket ist nicht in `pubspec.yaml` und soll es nicht werden).

- [ ] **Step 1: Fassade** `lib/core/storage/ohne_metadaten.dart`
```dart
import 'dart:typed_data';
import 'ohne_metadaten_stub.dart'
    if (dart.library.js_interop) 'ohne_metadaten_web.dart' as impl;

/// Entfernt ALLE Bildmetadaten (GPS, Aufnahmezeit, Geraet) durch Neu-Encodieren
/// in ein Canvas — ein Canvas kennt kein EXIF. Verkleinert gleich mit, weil der
/// „Dokumente"-Upload-Pfad kein vorheriges Resize hat.
///
/// WIRFT bei Dekodier-Fehlern (z. B. HEIC vom iPhone) statt das Original
/// zurueckzugeben: ein abgelehnter Upload ist sichtbar und behebbar, ein
/// stillschweigend mit GPS hochgeladenes Foto ist es nicht.
Future<Uint8List> ohneMetadaten(
  Uint8List bytes, {
  int maxBreite = 2000,
  double qualitaet = 0.85,
}) =>
    impl.ohneMetadaten(bytes, maxBreite: maxBreite, qualitaet: qualitaet);
```
- [ ] **Step 2: VM-/Test-Stub** `lib/core/storage/ohne_metadaten_stub.dart`
```dart
import 'dart:typed_data';

/// Nicht-Web-Ziele (VM/Tests): Canvas gibt es hier nicht, die Bytes gehen
/// unveraendert durch. ACHTUNG: Der Stub ist KEINE Zusage — der echte Strip
/// passiert ausschliesslich im Browser (ohne_metadaten_web.dart) und wird dort
/// verifiziert (Plan-Task 7).
Future<Uint8List> ohneMetadaten(
  Uint8List bytes, {
  int maxBreite = 2000,
  double qualitaet = 0.85,
}) async =>
    bytes;
```
- [ ] **Step 3: Web-Implementierung** `lib/core/storage/ohne_metadaten_web.dart`
```dart
import 'dart:async';
import 'dart:js_interop';
import 'dart:typed_data';

@JS('Blob')
external JSFunction get _blobCtor;
@JS('URL')
external JSObject get _url;
@JS('Image')
external JSFunction get _imageCtor;
@JS('document')
external JSObject get _document;

/// Canvas-Re-Encode: laedt die Bytes als Blob-URL in ein Image, zeichnet es in
/// ein Canvas und liest es als JPEG zurueck. Metadaten existieren danach nicht
/// mehr. Die EXIF-Drehung wenden Browser beim Zeichnen selbst an, das Bild
/// kippt also nicht.
Future<Uint8List> ohneMetadaten(
  Uint8List bytes, {
  int maxBreite = 2000,
  double qualitaet = 0.85,
}) async {
  final blob = _blobCtor.callAsConstructor<JSObject>(
    [bytes.toJS].toJS,
    {'type': 'image/jpeg'}.jsify(),
  );
  final blobUrl = (_url as JSObject)
      .callMethod<JSString>('createObjectURL'.toJS, blob)
      .toDart;
  try {
    final img = _imageCtor.callAsConstructor<JSObject>();
    final fertig = Completer<void>();
    img.setProperty('onload'.toJS, (() => fertig.complete()).toJS);
    img.setProperty(
        'onerror'.toJS,
        (() => fertig.completeError(
            StateError('Bild konnte nicht dekodiert werden'))).toJS);
    img.setProperty('src'.toJS, blobUrl.toJS);
    await fertig.future;

    final breiteOrig = (img.getProperty('naturalWidth'.toJS) as JSNumber).toDartInt;
    final hoeheOrig = (img.getProperty('naturalHeight'.toJS) as JSNumber).toDartInt;
    if (breiteOrig == 0 || hoeheOrig == 0) {
      throw StateError('Bild hat keine Groesse');
    }
    final skala = breiteOrig > maxBreite ? maxBreite / breiteOrig : 1.0;
    final breite = (breiteOrig * skala).round();
    final hoehe = (hoeheOrig * skala).round();

    final canvas = _document.callMethod<JSObject>(
        'createElement'.toJS, 'canvas'.toJS);
    canvas.setProperty('width'.toJS, breite.toJS);
    canvas.setProperty('height'.toJS, hoehe.toJS);
    final ctx = canvas.callMethod<JSObject>('getContext'.toJS, '2d'.toJS);
    ctx.callMethod('drawImage'.toJS, img, 0.toJS, 0.toJS, breite.toJS, hoehe.toJS);

    // toDataURL ist synchron und in allen Ziel-Browsern verfuegbar.
    final dataUrl = canvas
        .callMethod<JSString>('toDataURL'.toJS, 'image/jpeg'.toJS, qualitaet.toJS)
        .toDart;
    final komma = dataUrl.indexOf(',');
    if (komma < 0) throw StateError('Canvas lieferte kein JPEG');
    return _base64ZuBytes(dataUrl.substring(komma + 1));
  } finally {
    (_url as JSObject).callMethod('revokeObjectURL'.toJS, blobUrl.toJS);
  }
}

Uint8List _base64ZuBytes(String b64) {
  // Dart-Basis genuegt; kein zusaetzliches Paket noetig.
  return Uint8List.fromList(const _B64().decode(b64));
}

class _B64 {
  const _B64();
  List<int> decode(String s) => base64Decode(s);
}
```
**Hinweis für die Umsetzung:** `base64Decode` kommt aus `dart:convert` — den Import ergänzen und die `_B64`-Hilfsklasse **entfernen**, sie ist nur ein Platzhalter für die Import-Reihenfolge. Ziel ist schlicht `Uint8List.fromList(base64Decode(b64))`. Falls `toDataURL` in der Interop-Form Probleme macht, alternativ `toBlob` mit Callback + `FileReader.readAsArrayBuffer` verwenden — dann bitte im Bericht vermerken.
- [ ] **Step 4:** `flutter analyze lib/core/storage` → 0 Issues.
- [ ] **Step 5: Web-Build als echter Beweis** — `flutter build web --release` muss durchlaufen (analyze prüft js_interop nicht vollständig).
- [ ] **Step 6: Commit** `feat(datenschutz): Metadaten-Strip per Canvas-Re-Encode (+ VM-Stub)`

---

## Task 4: `FotoSpeicher` — Strip + flexibler Pfad

**Files:** Modify `lib/core/storage/foto_speicher.dart`

> Zwei Änderungen: (a) der Strip läuft **hier**, damit ihn kein Aufrufer vergessen kann; (b) `hochladen` muss auch den **deterministischen** Bau-Pfad `<betrieb_id>/<stepKey>.jpg` erzeugen können — sonst würde jedes ersetzte Bau-Foto ein neues Objekt anlegen und Waisen hinterlassen.

- [ ] **Step 1: Implement** — Datei ersetzen:
```dart
import 'dart:typed_data';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:bienen_app/core/storage/ohne_metadaten.dart';

/// Storage-Helfer fuer PRIVATE Buckets: laedt hoch (gibt den PFAD zurueck,
/// nicht die URL), erzeugt Signed-URLs, entfernt Objekte.
/// Pfadkonvention: `<betrieb_id>[/<gruppe>]/<datei>` (mandanten-scoped fuer die
/// Storage-Policies).
///
/// **Einziger Upload-Weg der App.** Der Metadaten-Strip laeuft hier, damit ihn
/// kein Aufrufer vergessen kann (Lehre aus D-76: eine Stelle statt sechs).
class FotoSpeicher {
  final SupabaseClient _c;
  final String bucket;

  /// Nur fuer Tests injizierbar; Produktion nutzt [ohneMetadaten].
  final Future<Uint8List> Function(Uint8List)? strip;

  const FotoSpeicher(this._c, this.bucket, {this.strip});

  /// [gruppeId] optional (Zwischenebene, z. B. volk_id/material_id).
  /// [dateiname] optional: gesetzt = deterministischer Pfad (ersetzt das
  /// bestehende Objekt via upsert, z. B. `<stepKey>.jpg` pro Bauschritt);
  /// weggelassen = `foto_<microsec>.jpg`.
  ///
  /// Wirft, wenn die Bytes nicht als Bild verarbeitbar sind (z. B. HEIC) —
  /// bewusst, statt ein Original mit GPS hochzuladen.
  Future<String> hochladen({
    required String betriebId,
    required Uint8List bytes,
    String? gruppeId,
    String? dateiname,
  }) async {
    final sauber = await (strip ?? ohneMetadaten)(bytes);
    final datei = dateiname ?? 'foto_${DateTime.now().microsecondsSinceEpoch}.jpg';
    final pfad = [betriebId, if (gruppeId != null) gruppeId, datei].join('/');
    await _c.storage.from(bucket).uploadBinary(
          pfad,
          sauber,
          fileOptions: const FileOptions(upsert: true, contentType: 'image/jpeg'),
        );
    return pfad;
  }

  Future<String> signedUrl(String pfad, {int ablaufSekunden = 3600}) =>
      _c.storage.from(bucket).createSignedUrl(pfad, ablaufSekunden);

  Future<void> entfernen(List<String> pfade) async {
    if (pfade.isEmpty) return;
    await _c.storage.from(bucket).remove(pfade);
  }
}
```
- [ ] **Step 2: Bestandsaufrufe prüfen** — `grep -rn "\.hochladen(" lib/` : `gruppeId` war vorher `required` und ist jetzt optional; alle bestehenden Aufrufe (Durchsicht, Gesundheit, Wissen) bleiben unverändert gültig. Falls ein Aufruf positional statt benannt war, hier anpassen.
- [ ] **Step 3:** `flutter analyze lib` → 0; `flutter test` → grün (die 281 bestehenden dürfen nicht brechen).
- [ ] **Step 4: Commit** `feat(datenschutz): FotoSpeicher strippt Metadaten + flexibler Pfad`

---

## Task 5: Material — Foto + Beleg über `FotoSpeicher`, Anzeige signiert

**Files:** Modify `lib/features/material/presentation/pages/material_detail_page.dart`

> Zuerst die Datei lesen (v. a. um Zeile 507–650 der Foto-/PDF-Bereich und um 1330–1380 der Beleg-Upload). Provider/Speicherfluss/`updatePhotoUrls` bleiben; nur Upload-Weg und Anzeige wechseln.

- [ ] **Step 1: Foto-Upload umstellen** — statt `storage.from('material-media').uploadBinary(...)` + `getPublicUrl`:
```dart
final speicher = FotoSpeicher(SupabaseConfig.client, 'material-media');
final pfad = await speicher.hochladen(
  betriebId: betriebId,
  gruppeId: item.id,
  bytes: bytes,
);
await ref.read(materialListProvider.notifier)
    .updatePhotoUrls(item.id, [...item.photoUrls, pfad]);   // PFAD, nicht URL
```
Der `catch`-Zweig meldet weiterhin per `_snack`; ergänze für den Strip-Fehler eine verständliche Meldung: `'Format nicht unterstützt — bitte als JPEG aufnehmen.'` (bei `StateError`).
- [ ] **Step 2: Beleg-Upload umstellen** — statt `storage.from('material-receipts').uploadBinary(...)` + `getPublicUrl`:
```dart
final belegSpeicher = FotoSpeicher(SupabaseConfig.client, 'material-receipts');
photoUrl = await belegSpeicher.hochladen(
  betriebId: betriebId,
  gruppeId: item.id,
  bytes: _photoBytes!,
);   // Feld heisst weiterhin beleg_foto, enthaelt jetzt den Pfad
```
- [ ] **Step 3: Anzeige signieren** — überall, wo bisher `Image.network(<wert>)` einen `photo_urls`-Wert bzw. `beleg_foto` rendert, ein `FutureBuilder` mit der Unterscheidung aus Task 2:
```dart
Widget fotoBild(String wert, String bucket) {
  if (istVolleUrl(wert)) return Image.network(wert, fit: BoxFit.cover);
  return FutureBuilder<String>(
    future: FotoSpeicher(SupabaseConfig.client, bucket).signedUrl(wert),
    builder: (context, snap) {
      if (snap.hasError) {
        return const Center(
            child: Icon(Icons.broken_image_outlined, color: BeeTokens.textGedaempft));
      }
      if (!snap.hasData) {
        return const Center(child: CircularProgressIndicator());
      }
      return Image.network(snap.data!, fit: BoxFit.cover);
    },
  );
}
```
(Als private Hilfsfunktion/Widget in der Datei; Farben aus `BeeTokens`, keine rohen Hex-Werte.)
- [ ] **Step 4:** `flutter analyze lib/features/material` → 0; `flutter test` → grün.
- [ ] **Step 5: Commit** `feat(datenschutz): Material-Fotos und Belege über FotoSpeicher + Signed-URLs`

---

## Task 6: Bau-Fotos über `FotoSpeicher`, Anzeige signiert

**Files:** Modify `lib/features/construction/presentation/providers/construction_provider.dart`

- [ ] **Step 1: Upload umstellen** — der deterministische Pfad bleibt erhalten (`dateiname`, kein `gruppeId`), damit pro Bauschritt weiter genau ein Objekt existiert:
```dart
final speicher = FotoSpeicher(SupabaseConfig.client, _bucket);
final pfad = await speicher.hochladen(
  betriebId: betriebId,
  dateiname: '$stepKey.jpg',
  bytes: bytes,
);
```
Der bisherige `?v=<ts>`-Cache-Buster **entfällt**: gespeichert wird der Pfad, und Signed-URLs sind je Abruf neu. In `construction_steps.photo_url` landet damit der Pfad.
- [ ] **Step 2: Anzeige signieren** — wo das Bau-Foto gerendert wird, dieselbe Unterscheidung wie in Task 5 (`istVolleUrl` → direkt, sonst `signedUrl` per `FutureBuilder`). Die Datei mit der Anzeige per `grep -rn "photoUrl" lib/features/construction/` finden (vermutlich `widgets/build_step_card.dart`).
- [ ] **Step 3:** `flutter analyze lib/features/construction` → 0; `flutter test` → grün.
- [ ] **Step 4: Export prüfen** — `lib/features/backup/data/export_service.dart` listet/lädt die Buckets über den **authentifizierten** Weg. Nach P01 müssen die 28 Alt-Objekte weiterhin im Export landen (die Alt-Pfad-Policy deckt das). Kein Code-Änderungsbedarf erwartet; falls doch, hier anpassen und im Bericht nennen.
- [ ] **Step 5: Commit** `feat(datenschutz): Bau-Fotos über FotoSpeicher + Signed-URLs`

---

## Task 7: Abschluss — Version, Deploy, Nachweise

- [ ] **Step 1:** `pubspec.yaml` Version → `1.38.0+60`.
  ⚠️ **Wichtig:** Die F3-Benachrichtigungen sind bereits für **v1.38.0** vorgemerkt (ToDo/Roadmap). Wenn dieser Task **vor** dem F3-Deploy läuft, hier `1.38.0` nehmen und **F3 in ToDo + Roadmap auf `1.39.0` korrigieren** (sonst dieselbe Doppelbelegung wie zuletzt bei 1.37.0).
- [ ] **Step 2:** `cd /d/Projekte/Bienen/bienen_app && flutter analyze` (0) und `flutter test` (alle grün).
- [ ] **Step 3: Deploy** `bash deploy.sh` (bei DNS-Fehler erneut).
- [ ] **Step 4: Funktions-Nachweis im Browser** — die Live-Seite laden: keine Konsolenfehler; **die 26 Produktfotos im Material müssen weiterhin sichtbar sein** (das ist der Test, ob wir Sicherheit gegen Funktion getauscht haben). Ist die Galerie leer: `photo_urls`-Wert und Signed-URL-Aufruf prüfen, **nicht** die Migration zurückdrehen.
- [ ] **Step 5: Sicherheits-Nachweis wiederholen** — der `curl` aus Task 1 Step 4 muss weiterhin **400/404** liefern.
- [ ] **Step 6: Commit** `chore(datenschutz): v1.38.0 Fotos privat + Metadaten-Strip`
- [ ] **Step 7: Übergabe an Daniel** (wortgleich weitergeben):
  1. In der App ein **Handyfoto mit Standortdaten** hochladen (Material-Detailseite → Foto), am besten über **alle drei** Wege, wo verfügbar (Kamera, Galerie, Dokumente).
  2. Sag Bescheid — dann lade ich die Datei aus dem Storage und prüfe, dass **keine GPS-Daten** mehr enthalten sind. **Erst danach gilt der Strip als bewiesen**, vorher nur als plausibel.
  3. Falls ein **iPhone-HEIC** abgelehnt wird („Format nicht unterstützt"): das ist beabsichtigt — melde es trotzdem, dann entscheiden wir, ob HEIC-Unterstützung nachgezogen wird.

---

## Self-Review-Notizen
- **Spec-Abdeckung:** Buckets privat + Alt-Policy + URL→Pfad (T1), Strip mit Fail-safe + Stub (T3), ein Upload-Weg (T4), Material/Beleg (T5), Bau + Export (T6), Rückwärtskompatibilität (T2 rein + T5/T6 Anzeige), Nachweise curl/Browser/EXIF (T1, T7).
- **Zwei Fallen aus dem Ist-Code sind adressiert:** die Methode heißt `signedUrl` (nicht `signierteUrl`, wie in der Spec-Prosa formuliert), und `hochladen` kann jetzt den **deterministischen** Bau-Pfad erzeugen — ohne `dateiname` hätte jedes ersetzte Bau-Foto ein neues Objekt angelegt und Waisen hinterlassen.
- **`gruppeId` wird von `required` zu optional** — abwärtskompatibel für die drei bestehenden Aufrufer (benannte Parameter).
- **Ehrlich zum Test-Umfang:** Der Canvas-Strip ist offline nicht testbar. Getestet wird die reine Pfad/URL-Unterscheidung (T2); der Strip wird per Web-Build (T3) und Daniels GPS-Foto (T7) verifiziert. Der Stub ist ausdrücklich als „keine Zusage" kommentiert, damit er nicht mit dem echten Schutz verwechselt wird.
- **Versionskollision aktiv verhindert** (T7 Step 1) — genau der Fehler, der zuletzt bei 1.37.0 passiert ist.
