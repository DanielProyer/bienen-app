# Durchsicht-Spracheingabe — hands-free Erfassung (Modul 4.3, Zyklus 2)

**Datum:** 2026-07-20 · **Track:** App · **Status:** Design freigegeben (Abschnitte 1–4), Spec zur Review
**Modell-Strategie:** Design/Spec Fable 5 hoch · Parser/Grammatik (Kern) Fable 5 hoch · UI/Kapsel Opus 4.8

---

## 1. Ziel & Kontext

Der geführte Durchsicht-Wizard (v1.20.0, `durchsicht_wizard_page.dart`) ist handschuh-optimiert (Tap-Stepper, große Chips), aber jede Eingabe braucht einen Tap. Ziel: **hands-free Erfassung per Spracherkennung** am Bienenstand — insbesondere der Wabe-für-Wabe-Durchgang, bei dem beide Hände die Wabe halten.

Bestehende Struktur (unverändert): 3-Schritt-Wizard **Kontext → optional Waben → Kennzahlen**; Felder = Tap-Stepper (Zahlen), Choice-Chips (Enums), Switches (bool), Slider (0–4), Freitext (Wetter/Massnahmen/Notiz), Multi-Filter-Chips (Auffälligkeiten); Waben-Schritt (`waben_schritt.dart`) mit Inhalt-Toggles + Flags + Trennschied je Wabe.

### Grundhaltung
- **Sprache ist rein additiv** — sie ersetzt nichts, blockiert nie; jedes Feld bleibt tippbar. Fällt Sprache aus (kein Netz, falscher Browser), funktioniert der Wizard unverändert.
- **Kein DB-/Migrations-Schritt, keine Mandanten-Berührung** — reine Client-Eingabehilfe.

---

## 2. Scope & Staffelung

**Gestaffelt, als eine Ausbaustufe geplant, in zwei Releases gebaut:**

- **v1** (erster Release): (a) **Diktat-Mikro** an den 3 Freitextfeldern; (b) **Kommando-Mikro je Formularseite** (Kontext + Kennzahlen), das per Grammatik Felder setzt.
- **v2** (zweiter Release, gleiche Engine): **sprachgeführter Waben-Durchgang** (Mehr-Token, „Brut Pollen Königin → nächste").

**Bewusst NICHT (YAGNI):** Sprach-Eingabe von Datum / Nächste Durchsicht / Foto (Datums-Diktat fehleranfällig → bleibt Tippen); echtes Weckwort („Hey Biene"); TTS-Rückansage in v1 (Option für später, s. §11).

---

## 3. Randbedingungen der Erkennung

- **Nur Web Speech API** (Flutter Web): `SpeechRecognition`/`webkitSpeechRecognition`. **Läuft nur in Chrome/Edge** (Firefox/Safari nicht/unzuverlässig). **Braucht Internet** (Audio geht an Google-Server; keine Offline-Erkennung). Am Zielstand ist laut Betreiber **zuverlässiges Netz** vorhanden → tragbar.
- **Sprache `de-CH` (Schweizer Hochdeutsch)** — der **zuverlässige Pfad** (Schweizer Akzent unproblematisch). **Echtes Schweizerdeutsch (Mundart) erkennt keine Cloud-ASR zuverlässig** → wird **best-effort** über eine **Alias-/Synonym-Tabelle** im Parser abgefangen (Hochdeutsch + häufige Mundartvarianten mappen auf denselben Wert), ohne Dialekt-Garantie.
- Datenschutz: Audio wird zur Erkennung an den Browser-Dienst gesendet (Standard Web Speech) — nur bei aktivem Mikro; kein Dauer-Streaming ohne Nutzeraktion.

---

## 4. Architektur — Erkenner (I/O-Kapsel)

Neues Sub-Feature `lib/features/durchsicht/sprache/`. Zwei entkoppelte Einheiten: **Erkenner** (austauschbare Browser-Kapsel) + **Parser** (§5, reine Fachlogik). Die UI verdrahtet nur beide.

### 4.1 Domain-Interface (`domain/sprache_erkenner.dart`)
```dart
abstract class SpracheErkenner {
  bool get verfuegbar;                       // Web Speech im Browser vorhanden?
  Stream<SprachErgebnis> get ergebnisse;     // Teil- (interim) + End-Transkripte
  Stream<ErkennerStatus> get status;
  Future<void> starten({String sprache = 'de-CH', bool kontinuierlich = true});
  Future<void> stoppen();
  void dispose();
}
class SprachErgebnis { final String text; final bool endgueltig; const SprachErgebnis(this.text, this.endgueltig); }
enum ErkennerStatus { idle, hoert, fehler }
enum ErkennerFehler { nichtVerfuegbar, keinMikro, keinNetz, abgebrochen }
```

### 4.2 Web-Impl (`data/web_sprache_erkenner.dart`)
- Dünne **`dart:js_interop`**-Kapsel um `SpeechRecognition` (Fallback `webkitSpeechRecognition`). Setzt `continuous`, `interimResults=true`, `lang`. Verdrahtet `onresult` (→ `SprachErgebnis`, `isFinal`), `onerror` (`no-speech`/`network`→`keinNetz`/`not-allowed`→`keinMikro`), `onend`.
- **Nahtloser Dauer-Modus:** Web Speech beendet `continuous`-Sessions periodisch selbst → bei `onend` im aktiven Zustand automatisch neu `start()` (bis der Nutzer stoppt), damit es durchgehend wirkt.
- `verfuegbar` = ob das Konstrukt im `window` existiert (sonst Firefox/Safari → false).

### 4.3 Fake (`data/fake_sprache_erkenner.dart`)
- Spielt Skript-`SprachErgebnis`e in `ergebnisse` ein → Flow-/Widget-Tests ohne Browser.

### 4.4 Provider (`data/sprache_providers.dart`)
- `spracheErkennerProvider` → Web-Impl in Prod (im Test via Override der Fake). `autoDispose`, `dispose()` schließt die Erkennung.

---

## 5. Architektur — Parser (reine Fachlogik, `domain/sprach_kommando.dart`)

Vollständig **offline testbar**, kein Browser.

### 5.1 v1-Parser
```dart
enum SprachKontext { kontext, kennzahlen, waben }
/// Ein erkanntes Feld-Kommando; null = kein Treffer (im Diktat-Modus → Freitext).
SprachKommando? parseKommando(String transkript, SprachKontext kontext);
sealed class SprachKommando { }                 // Zahl(feld,wert) | Enum(feld,wert) | Bool(feld,wert) | Auffaelligkeit(key,an)
```
- **Normalisierung:** lowercase, Umlaut-Folding (ä→ae…), trim, Mehrfach-Space.
- **Regel:** Feldwort + Wert. Bare Zahl ohne Feldwort → `null` (nicht raten).
- **Alias-Tabelle** (Konstante): mappt Feldwörter (inkl. Mundart) auf Feld-IDs und Enum-Wörter auf technische Keys (`drohnenbrütig→drohnenbruetig`, `zu gross→zu_gross`, `nachschaffung→nachschaffungszellen`, `spielnäpfchen→spielnaepfchen`).
- **Zahl-Helfer** `deutscheZahl(String)→num?`: Ziffern **und** Zahlwörter 0–99 („zweiundzwanzig"→22).

### 5.2 v2-Parser (Mehr-Token)
```dart
List<WabenAktion> parseWabenKommandos(String transkript);
sealed class WabenAktion { }  // Inhalt(key,an) | Flag(koenigin|weiselzelle|stifte, an) | Schied | Naechste | Zurueck
```
- Zerlegt das Transkript in Tokens, mappt jedes bekannte Token auf eine Aktion, **in Reihenfolge** (unbekannte Tokens ignoriert). „kein/ohne <inhalt/flag>" → Aktion mit `an=false`.

---

## 6. v1-Grammatik (Kontext- + Kennzahlen-Seite)

**Diktat (Freitext, wörtlich eingefügt):** Wetter (S1), Massnahmen (S3), Notiz (S3).

**Kommandos Schritt 1 (Kontext):**
| Beispiel | Feld |
|---|---|
| „Temperatur 22" | temperaturC = 22 |
| „Dauer 20" | dauerMin = 20 |
| „Weiselzustand weiselrichtig/weisellos/drohnenbrütig/unsicher" | weiselzustand |

**Kommandos Schritt 3 (Kennzahlen):**
| Beispiel | Feld |
|---|---|
| „Königin ja/nein" (auch „gesehen"/„keine Königin") | koeniginGesehen (bool) |
| „Stifte ja/nein" | stifteGesehen (bool) |
| „Weiselzellen keine/spielnäpfchen/schwarmzellen/nachschaffung" | weiselzellen (enum) |
| „Anzahl Weiselzellen 3" | weiselzellenAnzahl |
| „Brutbild geschlossen/lückig/bunt/kaum/kein" | brutbild (enum) |
| „Brutwaben 5" · „Wabengassen 8" · „Futter 3" | brutWaben · staerkeWabengassen · futterKg |
| „Pollen viel/mittel/wenig/kein" | pollen (enum) |
| „Platz ok/eng/Honigraum/zu gross" | platz (enum) |
| „Sanftmut 3" · „Wabensitz 3" | sanftmut · wabensitz (0–4) |
| „Auffälligkeit Varroa/Kalkbrut/…" | Auffälligkeits-Chip (mehrfach; gegen Whitelist) |

Feldwerte/-namen (Enums) exakt aus dem bestehenden Wizard (`weiselzustand`, `weiselzellen`, `brutbild`, `pollen`, `platz`, `Durchsicht.auffaelligkeitenWhitelist`).

---

## 7. v2 — sprachgeführter Waben-Durchgang

Kommando-Mikro im Waben-Schritt, **bleibt an** über den Durchgang. Mehr-Token je Satz:

| Gesprochen | Aktion auf aktive Wabe |
|---|---|
| „Brut/Pollen/Futter/Honig/Mittelwand/leer/Baurahmen" | Inhalt **setzen** (an) |
| „kein Brut" / „ohne Pollen" | Inhalt entfernen |
| „Königin/Weiselzelle/Stifte" | Flag an; „keine Königin" = aus |
| „Schied/Trennschied" | Wabe = Trennschied |
| „nächste/weiter" | +1 Wabe; **am Ende automatisch neue leere Wabe anhängen** |
| „zurück" | −1 Wabe |

- **Setzen statt Toggeln** (du sagst, was drauf ist) → mehrfaches „Brut" idempotent; entfernen nur explizit.
- Aktionen werden über den bestehenden `WabenSchritt.onChanged` in die Waben-Liste gespielt — **keine neue Datenhaltung** (Position, Schied-Truncation etc. bleiben wie gebaut).

---

## 8. Aktivierung & UI (`presentation/sprach_mikro.dart`)

- **Aktivierung = Toggle (A2):** ein großes Tap-Ziel; einmal an (Web Speech `continuous=true`), nochmal aus. Auto-Stop nach längerer Stille als Sicherheitsnetz.
- **`SprachMikro`-Widget** (wiederverwendbar), zwei Ausprägungen:
  - **Diktat** — klein, neben einem `TextEditingController`-Feld; End-Transkripte werden angehängt.
  - **Kommando** — prominent oben auf Seite/Waben-Schritt; End-Transkripte → `parseKommando`/`parseWabenKommandos` → Callback ins Formular.
- **Zustände:** idle (grau) · **hört zu…** (rot pulsierend + **Live-Transkript-Zeile** aus interim-Ergebnissen) · Fehler (Klartext).

---

## 9. Feedback (ohne Hinsehen)

- **Sichtbare Quittung** je angewandtem Kommando: kurzer Toast/Chip „Brutwaben → 5" bzw. „Wabe 3: Brut, Pollen, Königin"; die betroffenen Felder/Chips aktualisieren sichtbar.
- **Haptik:** kurze **Vibration** (`navigator.vibrate` via js_interop) bei erfolgreichem Kommando — glove-/eyes-free-tauglich.
- **Nicht verstanden** (Kommando-Modus): „nicht erkannt: ‚…'" mit dem rohen Transkript → wiederholen.
- (Gesprochene TTS-Rückansage = spätere Option, §11 — birgt Selbst-Auslösung des Mikros.)

---

## 10. Fehler-/Kein-Netz-Handling

- **`verfuegbar=false`** (Firefox/Safari): Mikros **ausgeblendet** + einmaliger Hinweis „Spracheingabe: Chrome/Edge". Wizard voll bedienbar.
- **`keinNetz`:** Status-Chip „kein Netz — Spracheingabe pausiert", Auto-Retry beim nächsten Start; Tippen unberührt.
- **`keinMikro`:** Hinweis „Mikro-Zugriff nötig".
- Sprache blockiert nie das Speichern; alle Felder bleiben manuell setzbar.

---

## 11. Datei-Architektur

```
lib/features/durchsicht/sprache/
  domain/  sprache_erkenner.dart (Interface + Modelle)
           sprach_kommando.dart  (parseKommando + parseWabenKommandos + Alias-Tabelle + deutscheZahl — REIN)
  data/    web_sprache_erkenner.dart (dart:js_interop-Kapsel)
           fake_sprache_erkenner.dart (Test-Double)
           sprache_providers.dart (Riverpod)
  presentation/ sprach_mikro.dart (Toggle + Status-Chip + Live-Transkript)

# geändert (v1):
lib/features/durchsicht/presentation/pages/durchsicht_wizard_page.dart
   # Diktat-Mikro an Wetter/Massnahmen/Notiz; Kommando-Mikro je Seite → parseKommando → setzt die vorhandenen State-Felder
# geändert (v2):
lib/features/durchsicht/presentation/widgets/waben_schritt.dart
   # Kommando-Mikro → parseWabenKommandos → onChanged
pubspec.yaml # keine neue Dependency (dart:js_interop im SDK)
```
**Spätere Option (v3):** TTS-Rückansage via `SpeechSynthesis` (Erkennung während des Sprechens kurz pausieren, um Selbst-Auslösung zu vermeiden).

---

## 12. Tests

- **`sprach_kommando_test.dart`** (Kern, umfangreich): jede Grammatik-Zeile (Feldwort+Wert → korrektes `SprachKommando`); Alias-Varianten (Hochdeutsch **und** Mundart); `deutscheZahl` (Ziffern + Zahlwörter); Enum-Key-Mapping; unbekannt → `null`; Normalisierung (Groß/Klein/Umlaut); je-Kontext-Grammatik (Feldwort der falschen Seite → null).
- **`parse_waben_test.dart`:** Mehr-Token-Zerlegung („Brut Pollen Königin nächste" → [Inhalt brut, Inhalt pollen, Flag königin, Naechste]); „kein/ohne"-Negation; Navigation. (Der Parser liefert nur die Aktionen; das „am Ende → neue Wabe anhängen" ist Anwendungslogik im Waben-Schritt und wird im Flow-Test geprüft.)
- **Flow-Test** mit `FakeSpracheErkenner`: Skript-Ergebnisse → Wizard-Felder bzw. Waben-Liste korrekt gesetzt (kein Browser).
- **Nicht getestet (bewusst):** die `dart:js_interop`-Web-Kapsel (dünn, manuell in Chrome verifiziert).

**Manuelle Verifikation:** Chrome (Mikro erlauben, Kommandos sprechen, Diktat + Kennzahlen + Waben-Durchgang); Firefox-Fallback (Mikros aus, Tippen geht); Kein-Netz simulieren.

---

## 13. Deploy & Versionierung

- **v1** = eigener Release (`flutter analyze`+`flutter test` grün → `bash deploy.sh`), Version-Bump (voraussichtlich `1.27.0`). **v2** danach (`1.28.0`). Kein Migrations-Schritt.

---

## 14. Offene Punkte (spätere Zyklen)

- v2 Waben-Durchgang (nach v1), TTS-Rückansage (v3), Feinschliff der Alias-Tabelle nach realem Feld-Test (welche Mundart-Varianten Lorena/Daniel tatsächlich sagen), evtl. „Wabe fünf"-Sprung.
