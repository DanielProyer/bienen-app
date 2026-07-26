# F2 (Teil 1) — Fotos absichern: private Buckets + Metadaten-Strip

**Datum:** 2026-07-26 · **Track:** App + Produktions-Migration · **Status:** Design freigegeben (Abschnitte 1–3), Spec zur Review
**Modell-Strategie:** Migration P01 (Storage-RLS, Mandanten-Isolation) → **Fable 5 hoch** · App-Umbau → Opus 4.8.

---

## 1. Ziel & Befunde

F2 („Datenschutz & Aufbewahrung") umfasst laut Roadmap vier Dinge: Löschsperre/Soft-Delete amtlicher Daten, EXIF-Stripping, Bearbeitungsverzeichnis, Retention. Diese Spec nimmt **nur den Teil mit echtem Risiko**, der heute lösbar ist: **kein Foto ohne Login, keine Standortdaten in Fotos.** Retention und Bearbeitungsverzeichnis folgen später (§8).

Drei Befunde aus der Code-/DB-Prüfung — sie haben den Zuschnitt bestimmt:

### 1.1 Drei Buckets umgehen die RLS
Die Storage-Policies sind sauber gebaut (`authenticated` + `betrieb_id`-Präfix-Regex + `private.ist_mitglied`/`kann_schreiben`). **Aber** `construction-photos`, `material-media` und `material-receipts` haben `public = true`. Damit existiert zusätzlich der Endpunkt `/storage/v1/object/public/<bucket>/<pfad>`, der **ohne Login** ausliefert und die Policies **nicht** auswertet. Der einzige verbleibende Schutz ist die Unerratbarkeit der UUID-Pfade — also Verschleierung, keine Zugangskontrolle. `material-receipts` sind **Belege/Rechnungen** (Name, Adresse, Beträge), somit personenbezogen.

**Günstiger Zeitpunkt:** `material-receipts` und `construction-photos` sind **leer** (0 Objekte), `materials.pdf_urls`, `material_purchases.beleg_foto` und `construction_steps.photo_url` ebenfalls. Nur `material-media` ist mit 28 Objekten / 26 betroffenen `materials`-Zeilen befüllt.

### 1.2 Der Metadaten-Schutz greift nirgends garantiert
Ursprüngliche Annahme war: Kamera/Galerie strippen EXIF (weil `ImagePicker(imageQuality: 75, maxWidth: 2000)` re-encodiert), nur der Dokumente-Pfad nicht. Nach Lesen des Plugin-Quellcodes (`image_picker_for_web` 3.1.1) ist das **zu optimistisch**:
- `imageQuality` wird auf Web tatsächlich umgesetzt (Canvas-Resize in `src/image_resizer.dart`) → im Normalfall fällt EXIF weg.
- **Aber** `resizeImageIfNeeded` fällt in zwei Fällen **stillschweigend auf die Originaldatei** zurück: bei `mimeType == 'image/gif'` und im `catch (e) { return file; }`. Letzteres greift, wenn der Browser das Bild nicht dekodieren kann — der Klassiker ist **HEIC vom iPhone**. Dann wird das Original **inklusive GPS** hochgeladen, ohne Fehlermeldung.
- Der `FilePicker`-Pfad („Dokumente") in `wissen_foto_strip.dart` (`withData: true` → Original-Bytes) strippt **nie**.

Die Lücke ist also nicht „ein Pfad von drei", sondern: **kein Pfad garantiert es** — und der Ausfall passiert unsichtbar.

### 1.3 Der App-Code ist beim Pfad längst korrekt
Alle drei Upload-Stellen schreiben bereits `$betriebId/…` (mit begründenden Kommentaren, Härtung „A10"). Die 28 Alt-Objekte in `material-media` liegen unter `<material_id>/photo_web.jpg` — sie stammen aus einer **Befüllung vor dieser Härtung** und sind über den *authentifizierten* Weg heute gar nicht lesbar (die Policy verlangt ein `betrieb_id`-Präfix); sie funktionieren nur, weil der Bucket öffentlich ist. **Wer den Bucket ohne Weiteres auf privat stellt, macht alle 28 Produktfotos unsichtbar.**

### Grundhaltung
- **Mandantenfähig**, keine Arosa-Hardcodes.
- **Fail-safe:** Ein abgelehnter Upload ist sichtbar und behebbar; ein stillschweigend mit GPS hochgeladenes Foto ist es nicht.
- **Eine Stelle statt sechs** (Lehre aus D-76 und dem Materialbestand): Schutz gehört in den gemeinsamen Pfad, nicht in jeden Aufrufer.

---

## 2. Scope & YAGNI

**In Scope:** (1) alle drei öffentlichen Buckets auf privat, inkl. Behandlung der 28 Alt-Objekte; (2) Anzeige auf Signed-URLs; (3) garantierter Metadaten-Strip in **einem** Upload-Weg; (4) aktiver Nachweis, dass die öffentliche Lücke zu ist.

**Bewusst NICHT:**
- **Retention** („amtliche Daten nach 3 Jahren nur owner hart löschbar") — bei **0** Behandlungen/Durchsichten/Gesundheitsereignissen ohne praktischen Nutzen; die Löschsperren (keine DELETE-Policy, Immutable-Trigger, FK `RESTRICT`) sind ohnehin bereits scharf.
- **Bearbeitungsverzeichnis** (wer hat wann was geändert) — eigener Baustein; `created_by`/`updated_by` + `set_row_actor` liefern heute die Grundspur.
- **Storage-Umzug der 28 Alt-Objekte** (Begründung §4.2).
- **HEIC-Unterstützung** — HEIC wird künftig *abgelehnt* statt unsicher durchgelassen (§5).
- **EXIF-Strip für PDFs** — PDFs (`pdf_urls`) tragen keine GPS-Bilddaten in relevanter Form; der Strip gilt für Bilder.

---

## 3. Architektur

```
Upload (Kamera | Galerie | Dokumente)
   → FotoSpeicher.hochladen()            ← EINZIGER Upload-Weg
        ├─ ohneMetadaten(bytes)          ← Canvas-Re-Encode, wirft bei Misserfolg
        └─ storage.uploadBinary('<betrieb_id>/…')
   → gibt PFAD zurück (nicht URL)        ← in die DB wandert der Pfad

Anzeige
   → FotoSpeicher.signierteUrl(pfad)     ← createSignedUrl, zeitlich begrenzt
```

Die drei Direkt-Uploads (`material_detail_page` ×2, `construction_provider`) werden auf `FotoSpeicher` umgestellt. Das fällt mit der Signed-URL-Umstellung zusammen (auch dort wechseln wir von URL auf Pfad), kostet also kaum extra — und verhindert, dass ein künftiger Upload-Pfad den Schutz wieder umgeht.

---

## 4. Migration P01 (Produktion — separat freizugeben)

`P01_fotos_privat.sql`:

### 4.1 Buckets privat
```sql
update storage.buckets set public = false
 where name in ('material-media','material-receipts','construction-photos');
```

### 4.2 Die 28 Alt-Objekte: Join-Policy statt Umzug
Ein Umzug (`<material_id>/…` → `<betrieb_id>/<material_id>/…`) ist über SQL **nicht sicher** machbar: `storage.objects.name` ist der Schlüssel im Storage-Backend; ein reines `update … set name` würde die Metadaten ändern, während die Dateien unter dem alten Schlüssel liegenbleiben → toter Verweis. Ein sauberer Umzug bräuchte die Storage-API (`move`) und damit einen weiteren Rechner-Schritt.

Stattdessen eine zusätzliche **Lese**-Policy, die das Schutzziel ohne Datenbewegung erreicht — der erste Pfadteil ist eine `material_id`, über die der Betrieb ermittelt wird:
```sql
-- ALT-LAST (Befüllung vor der betrieb_id-Praefix-Haertung): 28 Objekte liegen
-- unter <material_id>/… statt <betrieb_id>/…. Lesen nur fuer Mitglieder des
-- Betriebs, dem das Material gehoert. Neue Uploads treffen die regulaere
-- betrieb_id-Policy; diese hier darf entfallen, sobald die Alt-Objekte weg sind.
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
```

### 4.3 DB: volle URLs → Pfade
`materials.photo_urls` enthält 26× volle öffentliche URLs. Signed-URLs entstehen zur Laufzeit, gespeichert wird deshalb der Pfad (konsistent zu `inspections.foto_urls`, `wissen_fotos.storage_path`):
```sql
update public.materials
   set photo_urls = (
     select array_agg(regexp_replace(u,
       '^https?://[^/]+/storage/v1/object/public/material-media/', ''))
       from unnest(photo_urls) u)
 where photo_urls is not null and array_length(photo_urls, 1) > 0;
```
`pdf_urls`, `material_purchases.beleg_foto` und `construction_steps.photo_url` sind **leer** → nichts zu tun.

**Verifikation:** Buckets `public=false`; Policy vorhanden; kein `photo_urls`-Eintrag beginnt mehr mit `http`; `get_advisors(security)` + `(performance)` → **0 neue** Findings. Rollback-Kommentar im File (Buckets zurück auf `public=true`, Policy droppen, URLs aus Pfaden rekonstruierbar).

---

## 5. Metadaten-Strip

Neue Datei `lib/core/storage/ohne_metadaten.dart` mit bedingtem Import (Muster: `durchsicht/sprache/data/`, `dart:js_interop` — **kein** `package:web`):

```
Future<Uint8List> ohneMetadaten(Uint8List bytes, {int maxBreite = 2000, double qualitaet = 0.85})
```
- Bild aus einem Blob laden, in ein `canvas` zeichnen, per `toBlob`/`toDataURL` als **JPEG** ausgeben. Ein Canvas kennt kein EXIF → **alle** Metadaten sind weg (GPS, Aufnahmezeit, Gerät, Seriennummer).
- **Verkleinert gleich mit** (`maxBreite = 2000`, proportional, nur nach unten): Der Dokumente-Pfad hat kein vorheriges Resize — ohne diese Grenze landete ein 12-MP-Foto in Originalgröße im Storage. Die Werte entsprechen den bestehenden `ImagePicker`-Aufrufen (`maxWidth: 2000`, Qualität ~0.75–0.85), damit alle Wege vergleichbare Dateien liefern.
- **Orientierung bleibt korrekt:** Browser wenden die EXIF-Drehung beim Zeichnen an, das Bild kippt also nicht.
- **Wirft** bei Dekodier-Fehler (HEIC, defekte Datei) statt das Original zurückzugeben. `FotoSpeicher.hochladen` lässt die Ausnahme durch; die Aufrufer zeigen „Format nicht unterstützt — bitte als JPEG aufnehmen/speichern."
- **VM/Test-Stub:** gibt die Bytes unverändert zurück (Tests laufen nicht im Browser) — dokumentiert, damit niemand den Stub für die echte Zusage hält.

Der Strip läuft **zusätzlich** zum `ImagePicker`-Resize (der bleibt für die Verkleinerung). Doppelt re-encodiert wird bewusst in Kauf genommen: Verlässlichkeit vor letztem Prozent Bildqualität.

---

## 6. App-Umbau

| Datei | Änderung |
|---|---|
| `lib/core/storage/foto_speicher.dart` | `hochladen` ruft `ohneMetadaten` vor dem Upload; gibt weiterhin den **Pfad** zurück |
| `lib/features/material/presentation/pages/material_detail_page.dart` | Foto- **und** Beleg-Upload über `FotoSpeicher`; Anzeige über `signierteUrl` (`FutureBuilder`); `getPublicUrl` entfällt |
| `lib/features/construction/presentation/providers/construction_provider.dart` | Upload über `FotoSpeicher`, Anzeige über `signierteUrl`; `?v=`-Cache-Buster entfällt (Signed-URLs sind je Abruf neu) |
| `lib/features/wissen/presentation/widgets/wissen_foto_strip.dart` | unverändert im Ablauf — profitiert automatisch, weil `FotoSpeicher` jetzt strippt |
| `lib/features/backup/data/export_service.dart` | prüfen: lädt Bucket-Inhalte über den authentifizierten Weg — nach der Umstellung müssen die 28 Alt-Objekte weiter im Export landen (Policy aus §4.2 deckt das) |

**Rückwärtskompatibilität:** `materials.photo_urls` enthält nach der Migration Pfade. Die Anzeige muss beides überleben — ein Wert, der mit `http` beginnt, wird direkt verwendet (Altbestand/Notfall), sonst als Pfad signiert. Das verhindert eine leere Galerie, falls ein Wert übersehen wurde.

---

## 7. Verifikation

- **Der eigentliche Beweis:** `curl` auf eine bisherige öffentliche Foto-URL → **muss fehlschlagen** (400/404). Vorher/nachher dokumentieren.
- **Kein Funktionsverlust:** die 26 Produktfotos müssen in der App weiterhin sichtbar sein (Browser-Check).
- **Advisors:** 0 neue Findings.
- **Tests:** `flutter analyze` + volle Suite grün. Der Canvas-Strip ist offline nicht testbar (Browser-API) — deshalb ein Test, der festhält, dass der **Stub** die Bytes durchlässt und `FotoSpeicher` den Strip **aufruft** (Fake-Injektion), statt echtes Re-Encoding zu behaupten.
- **EXIF-Endnachweis (braucht Daniel):** ein Handyfoto **mit** Standortdaten hochladen, danach aus dem Storage laden und prüfen, dass keine GPS-Daten mehr enthalten sind. Ohne diesen Schritt gilt der Strip als *plausibel*, nicht als *bewiesen*.

---

## 8. Offen (spätere Zyklen)
- **Retention:** amtliche Daten nach Ablauf der Aufbewahrungsfrist nur durch owner hart löschbar (sinnvoll, sobald Journal-Einträge existieren).
- **Bearbeitungsverzeichnis:** Änderungshistorie über `created_by`/`updated_by` hinaus.
- **28 Alt-Objekte** per Storage-API umziehen und die Alt-Policy aus §4.2 entfernen (Aufräum-Arbeit, kein Schutzgewinn).
- **HEIC-Unterstützung** (Re-Encode serverseitig oder per WASM-Decoder).
- **EXIF-Strip für den Export** (F1): das ZIP enthält die Fotos wie gespeichert — nach dieser Änderung also bereits metadatenfrei.
