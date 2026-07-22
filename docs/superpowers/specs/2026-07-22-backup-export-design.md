# F1 — Backup & Export (Offsite-Sicherung + „Jetzt exportieren")

**Datum:** 2026-07-22 · **Track:** App (+ neues Infrastruktur-Repo) · **Status:** Design freigegeben (Abschnitte 1–3), Spec zur Review
**Modell-Strategie:** Backup-Skript/Workflow (Datenvollständigkeit kritisch) → **Fable 5 hoch**; App-Export-UI → Opus 4.8.

---

## 1. Ziel & Kontext

Die App ist inzwischen **System of Record**: Volk 1 ist seit 2026-07-19 real, das **TAMV-Behandlungsjournal** (Aufbewahrungspflicht), der **Bio-Nachweis** (Fütterung), das **Gesundheits-/Diagnose-Journal** und alle Durchsichten liegen ausschließlich in Supabase — dazu Fotos in 6 Storage-Buckets. Es existiert **keine Offsite-Kopie und kein Export**. Bei Verlust oder Fehlbedienung des Supabase-Projekts wären amtlich aufbewahrungspflichtige Daten unwiederbringlich weg.

**Ziel:** (a) ein **automatisches tägliches Offsite-Backup** aller Daten und Fotos in ein **privates GitHub-Repo**, und (b) ein **manueller Export** in der App, der dasselbe Paket als ZIP herunterlädt. Nebeneffekt: der tägliche Zugriff hält Supabase wach (**Keep-alive**, ebenfalls ein Roadmap-Punkt).

### Zerlegung von F1 (Roadmap-Punkt war zu grob)
| Teil | Status |
|---|---|
| **F1a Export** (Knopf → ZIP) | **in dieser Spec** |
| **F1b Automatisches Offsite-Backup** | **in dieser Spec** |
| **F1c Restore & CSV/Alt-App-Import** | **später, eigene Spec** — braucht F1a als Grundlage |
| Keep-alive | fällt als Nebeneffekt von F1b ab |

### Grundhaltung
- **Mandantenfähig**, keine Arosa-Hardcodes: gesichert wird **je Betrieb** in einen eigenen Ordner; die App exportiert über die eigene Sitzung (RLS) automatisch nur den aktiven Betrieb.
- **Ein Backup, das still unvollständig wird, ist schlimmer als keins** — deshalb an mehreren Stellen aktive Gegenproben statt Vertrauen.

---

## 2. Architektur (Weg A: GitHub Actions)

Ein **separates, privates** Repo `bienen-backup` (lokal geklont nach `D:\Projekte\Bienen\bienen-backup`, neben `bienen_app/` und `imkerei/`) enthält **sowohl das Backup-Werkzeug als auch die Sicherungen** — es ist damit selbsttragend und hängt an keinem anderen Repo.

**Täglicher Ablauf** (GitHub-Actions-Workflow, `schedule: cron '15 3 * * *'` UTC, zusätzlich manuell auslösbar via `workflow_dispatch`):
1. **Schutzriegel:** bricht ab, wenn das Repo **nicht privat** ist (`github.event.repository.private`).
2. Checkout des Repos.
3. Node-Skript liest aus Supabase (Service-Role-Key aus GitHub-Secrets):
   - Tabellenliste **automatisch aus dem Schema** (PostgREST-Wurzel-Schema `GET /rest/v1/`, dessen `definitions` alle Tabellen samt Spalten führen — daran wird `betrieb_id` erkannt), nicht aus einer gepflegten Liste → neue Module fallen nie stillschweigend aus dem Backup. **Rückfallebene:** Sollte sich das Wurzel-Schema als unzuverlässig erweisen, wird eine explizite Tabellenliste im Skript geführt **plus ein Wächter, der den Lauf rot färbt, sobald die Datenbank eine Tabelle enthält, die nicht in der Liste steht** — die Eigenschaft „nichts fällt stillschweigend raus" bleibt so in jedem Fall erhalten.
   - Alle Betriebe; je Betrieb alle betrieb-bezogenen Tabellen **mit Blätterung** (siehe §6).
   - Alle Objekte der 6 Buckets unter dem Betriebs-Präfix.
4. Schreibt `daten/*.json` + `daten/*.csv`, `fotos/**`, `manifest.json`.
5. **Gegenprobe** (§6) — bei Abweichung Lauf rot.
6. `git commit` + `push` (kein Commit, wenn nichts geändert — Lauf bleibt grün, Keep-alive erfüllt).

**Warum GitHub Actions statt Supabase Edge Function:** kein schreibendes GitHub-Token nötig (der Workflow darf sein eigenes Repo beschreiben), eingebaute Zeitsteuerung, **sichtbare Lauf-Historie und automatische Fehler-E-Mail** — genau der Punkt, an dem Backups sonst still sterben.

### Repo-Layout
```
bienen-backup/                      (PRIVAT)
  .github/workflows/backup.yml      Zeitplan + Schutzriegel
  scripts/backup.mjs                Node-Skript (Lesen, Schreiben, Gegenprobe)
  README.md                         Was das ist + Wiederherstellungs-Anleitung
  backup/<betrieb_id>/
    daten/<tabelle>.json            originalgetreu, stabil sortiert
    daten/<tabelle>.csv             in Excel lesbar
    fotos/<bucket>/<originalpfad>
    manifest.json                   Zeitstempel, Zeilenzahlen, Fotos, Schema-Fingerabdruck, Warnungen
```

---

## 3. Sicherungsumfang

**Je Betrieb:**
- **Alle betrieb-bezogenen Tabellen** (aktuell 23; automatisch erkannt an der Spalte `betrieb_id`), gefiltert auf den Betrieb.
- **Mandanten-Wurzeln:** der `betriebe`-Datensatz, die `betrieb_mitglieder`-Zeilen und die `profiles` der Mitglieder — ohne sie fehlt beim Wiederaufbau der Rahmen.
- **Alle Dateien der 6 Buckets** unter `<betrieb_id>/`: `inspection-photos`, `health-photos`, `wissen-photos` (privat) sowie `material-media`, `material-receipts`, `construction-photos`.
- **`manifest.json`**: Zeitstempel (UTC), Format-Version, je Tabelle die Zeilenzahl, Foto-Anzahl + Gesamtgröße, **Schema-Fingerabdruck** (Tabellen + Spalten), Liste der `warnungen[]`.

**Bewusst mit im Paket:** die `einladungen`-Codes (Originaltreue). Im privaten Repo unbedenklich; verbrauchte Codes sind wertlos.

---

## 4. Format

- **JSON ist die Wahrheit** (typtreu, später zurückspielbar), **CSV die Beigabe** (lesbar in Excel; Komma-getrennt, UTF-8 mit BOM, Werte gequotet, Zeilenumbrüche escaped).
- **Diff-Freundlichkeit (wichtig):** JSON wird **stabil nach `id` sortiert**, mit **alphabetisch fester Schlüssel-Reihenfolge** und 2-Space-Einrückung geschrieben. Ohne das erzeugte jeder Lauf riesige Schein-Änderungen und die Git-Historie wäre wertlos.
- `manifest.json` trägt `format_version: 1`. Bei künftigen Formatänderungen wird sie erhöht.

**Bekannte Doppel-Implementierung:** Das Format wird zweimal erzeugt (Node im Workflow, Dart in der App). Gegenmaßnahme: das Format ist hier verbindlich beschrieben, die App-Seite hat Tests gegen genau diese Regeln (§7), und `format_version` macht Drift sichtbar.

---

## 5. Manueller Export in der App

- Neuer Abschnitt **„Daten & Backup"** auf der Einstellungen-Seite (`/einstellungen`) mit Knopf **„Jetzt exportieren"**.
- Läuft **client-seitig mit der Sitzung des Nutzers** → die RLS sorgt dafür, dass nur der aktive Betrieb im Paket landet (Mandantenfähigkeit ohne Sonderlogik).
- Erzeugt dasselbe Paket (`daten/` JSON+CSV, `fotos/`, `manifest.json`) als **ZIP-Download** im Browser.
- **Fortschrittsanzeige** (Tabellen bzw. Fotos), da die Fotos einige Sekunden brauchen; Fehler als Snackbar, Teil-Erfolg nicht als Erfolg melden.
- Neue Abhängigkeit: **`archive`** (reines Dart, web-tauglich).

**Struktur (testbar geschnitten):**
```
lib/features/backup/
  domain/export_format.dart     REIN: csvVon(zeilen), stabilesJson(zeilen), manifestVon(...)
  data/export_service.dart      I/O: Tabellen+Fotos holen, ZIP bauen
  presentation/backup_section.dart   UI-Abschnitt (Baukasten: AppCard/SectionHeader/AppButton)
```

---

## 6. Vollständigkeit & Verifikation

- ⚠️ **Blätterungs-Falle:** PostgREST liefert standardmäßig **max. 1000 Zeilen**. Ohne Blätterung würden wachsende Tabellen (allen voran `weight_readings` mit der Waage) **stillschweigend abgeschnitten** — ein Backup, das erfolgreich aussieht. Das Skript blättert daher konsequent (Range-Header, Seitengröße 1000, bis erschöpft). Gleiches gilt für die Storage-Auflistung (`list` ist ebenfalls limitiert und wird geblättert).
- **Gegenprobe je Lauf:** Für jede Tabelle wird die geschriebene Zeilenzahl gegen ein direktes `count` in der DB verglichen. **Abweichung → Lauf rot.** Damit kann ein unvollständiges Backup nicht als Erfolg durchgehen.
- **Foto-Gegenprobe:** Anzahl heruntergeladener Dateien gegen Anzahl gelisteter Objekte; Differenzen landen als `warnungen[]` im Manifest und als sichtbare Workflow-Warnung.
- **Einmalige Restore-Probe von Hand** nach dem ersten grünen Lauf: Repo ziehen, JSON auf Gültigkeit prüfen, eine bekannte Stichprobe (z. B. der TAMV-Behandlungseintrag) im Export wiederfinden, ein Foto öffnen. Ein echtes Zurückspielen kommt mit **F1c**.

### Fehlerverhalten
| Fall | Verhalten |
|---|---|
| Supabase nicht erreichbar | Lauf **rot** + GitHub-E-Mail |
| Einzelnes Foto nicht ladbar | Lauf läuft weiter, **Warnung** im Manifest + Workflow-Annotation |
| Ganze Tabelle schlägt fehl / Zeilenzahl weicht ab | Lauf **rot** |
| Nichts geändert | kein Commit, Lauf grün (Keep-alive erfüllt) |
| Abbruch mittendrin | Commit ist atomar → **nie ein halbes Backup** im Repo |

---

## 7. Tests

- **Rein (Dart, offline):** `export_format.dart` — CSV-Quoting (Kommas, Anführungszeichen, Zeilenumbrüche, `null`), stabile Sortierung + feste Schlüsselreihenfolge im JSON, Manifest-Aufbau (Zeilenzahlen, Warnungen).
- **Node-Skript:** eine Trockenlauf-Prüfung gegen die echte DB im ersten manuellen Workflow-Lauf (`workflow_dispatch`), inklusive der Gegenproben aus §6.
- **Nicht automatisiert (bewusst):** der Browser-Download selbst und das GitHub-Push-Verhalten — beides wird im ersten echten Lauf verifiziert.

---

## 8. Sicherheit

- Repo **privat** — enthält Gesundheits-/Betriebsdaten, Diagnosefotos, Mitglieder-E-Mails. **Workflow-Schutzriegel** bricht ab, falls das Repo je öffentlich gestellt wird.
- **Geheimnisse als GitHub-Secrets:** `SUPABASE_URL`, `SUPABASE_SERVICE_ROLE_KEY`. Der Service-Key umgeht bewusst die RLS (nötig für ein Voll-Backup) und liegt ausschließlich dort. Zum Schreiben braucht der Workflow **kein** eigenes Token (`GITHUB_TOKEN` genügt).
- **Schlüsselverlust:** Key in Supabase rotieren, Secret aktualisieren. Im Repo selbst liegen keine Zugangsdaten.

### Voraussetzungen, die Daniel selbst erledigt (Zugangsdaten werden nicht von Claude eingegeben)
1. Privates GitHub-Repo `bienen-backup` anlegen und lokal nach `D:\Projekte\Bienen\bienen-backup` klonen.
2. In den Repo-Settings zwei Secrets hinterlegen: `SUPABASE_URL`, `SUPABASE_SERVICE_ROLE_KEY`.
3. Nach dem ersten Push den Workflow einmal manuell starten (`workflow_dispatch`) und das Ergebnis prüfen.

---

## 9. Offen (spätere Zyklen)
- **F1c Restore & Import** (Zurückspielen, CSV/Alt-App-Import) — eigene Spec.
- **F2 Datenschutz** (EXIF-Stripping, Retention/Löschsperre) — angrenzend, eigener Baustein.
- `weight_readings` bei starkem Wachstum in Monatsdateien aufteilen (heute unnötig).
- Optional: Backup-Status (letzter erfolgreicher Lauf) in der App anzeigen — bräuchte Lesezugriff aufs private Repo; vorerst genügt die GitHub-Fehler-E-Mail.
