# Bienenkrankheiten & Schädlinge (BGD-Merkblätter Gruppe 2.x)

> **Quelle:** BienenSchweiz / Bienengesundheitsdienst (BGD · apiservice), bienen.ch — BGD-Merkblätter 2.1–2.12 + Bestimmungshilfen. Ausgewertet 2026-07-19 im Rahmen der bienen.ch-Wissenserschliessung (96 Merkblätter/PDFs, Textextraktion + visuelle Grafik-Auswertung).
> **Charakter:** Offizielles Schweizer BGD-Fachwissen (frei zugänglich). Zahlen sind BGD-Richtwerte — vor amtlicher Nutzung Fachstellen-Check. Hotline Bienengesundheit 0800 274 274.
> **Zusammenhang:** Ergänzt [14_Bienengesundheit_Krankheiten_CH.md] um Krankheitsbilder, Diagnose-Details und Rechtsstatus je Erreger. App-Verbesserungsvorschläge aus dieser Quelle: siehe App-Schiene `bienen_app/docs/bienen-ch-findings.md`.

---

# G2 — Bienenkrankheiten & Schädlinge (BGD-Merkblätter, ohne Varroa, ohne Vespa)

**Quelle:** BGD/apiservice Merkblätter `www.bienen.ch/merkblatt` · Hotline **0800 274 274** · Textextrakte aus `scratchpad/bienen_ch/txt/`
**Erfasst:** 2026-07-19 · **AFA BI** = Amtlicher Fachassistent / Bieneninspektor · **BLV** = Bundesamt für Lebensmittelsicherheit und Veterinärwesen

> **Rechtsstatus-Legende (CH-Tierseuchenrecht, Terminologie der Merkblätter):**
> - **„zu bekämpfen" / meldepflichtige Tierseuche** → Verdacht schon **unverzüglich** dem Bieneninspektor (AFA BI) melden; amtliche Sanierung.
> - **„zu überwachen" / zu überwachende Tierseuche** → Meldung empfohlen; Monitoring; keine amtliche Zwangssanierung ab Verdacht.
> - **nicht meldepflichtig** → rein imkerliche Bewirtschaftung, kein Amt.

> **Wichtiger Hinweis Sperrbezirk:** Die ausgewerteten Merkblätter nennen **KEINE konkreten Sperrbezirks-Radien (km)** für Faul-/Sauerbrut. Faulbrut-MB sagt nur „Keine Völker in die Nähe von Sperrgebieten bringen". Radien/Sperrkreise ergeben sich aus der **Tierseuchenverordnung (TSV)** bzw. der Anweisung des Bieneninspektors — nicht aus diesen Quellen. → In der App nicht aus diesen Merkblättern hart codieren.

---

## Übersichtstabelle

| Krankheit / Schädling | Erreger / Typ | Leitsymptom | Rechtsstatus | Meldeweg |
|---|---|---|---|---|
| **Amerikanische Faulbrut (AFB)** | Bakterium (sporenbildend) | Zündholztest ≥ 1 cm fadenziehend; braune Masse in verdeckelten Zellen; eingesunkene, durchlöcherte Deckel | **zu bekämpfen** (meldepflichtig) | **Unverzüglich** AFA BI beiziehen; Verdacht sofort melden |
| **Sauerbrut / Europ. Faulbrut (EFB)** | Bakterium | Maden sterben **vor** Verdeckelung, verdreht, gelb→braun/schwarz; Zündholztest **< 1 cm**; Geruch Käse/Fussschweiss | **zu bekämpfen** (meldepflichtig) | **Unverzüglich** AFA BI beiziehen |
| **Kleiner Beutenkäfer** (*Aethina tumida*) | Käfer (Nitidulidae) | Eigelege in Ritzen, Larven mit 2 Dornenreihen, adulte Käfer, gärender Honig | **zu bekämpfen** (meldepflichtig) | **Unverzüglich** AFA BI beiziehen; Diagnosefalle |
| **Tropilaelaps** (*T. clareae/mercedesae*) | Milbe (aus Asien) | Milben in Brutzellen (länger als breit, ~1×0,8 mm); verkrüppelte Bienen bei **geringem** Varroabefall | **zu überwachen** | Meldung an AFA BI **empfohlen**; in CH bisher nicht nachgewiesen |
| **Kalkbrut** | Pilz | Weiss→grau→schwarze Mumien, rasseln in Zellen; morgens auf Flugbrett | nicht meldepflichtig | — (imkerlich) |
| **Nosema** (Durchfall) | Pilz (*N. apis / N. ceranae*) | Kotflecken; Mitteldarm trüb/milchig/aufgetrieben; Laborbestätigung nötig | nicht meldepflichtig | — (imkerlich) |
| **Ruhr** (Durchfall) | Verdauung/Stress (Amöben-Ruhr = ansteckend) | Kotflecken im Winter/Frühling; primär Überwinterungsproblem | nicht meldepflichtig | — (imkerlich) |
| **Wachsmotte (gross/klein)** | Falter (Zünsler, Pyralidae) | Gespinste, schwarzer Kot, Röhrchenbrut | nicht meldepflichtig | — (imkerlich) |
| **Maikrankheit** | nicht ansteckend (Wassermangel; ev. *Spiroplasma apis* / Pollen) | Junge Bienen krabbeln/zittern vor der Beute; dicker gelb-brauner Kot bei Druck | nicht meldepflichtig | — (imkerlich) |
| **Chron. Bienen-Paralyse-Virus (CBPV)** | Virus | Schwarze, haarlose, glänzende, kleiner wirkende Bienen; Zittern/Lähmung; aufgetriebener Hinterleib | nicht meldepflichtig | — (imkerlich) |
| **Sackbrut-Virus (SBV)** | Virus | Streckmade nimmt **Sackform** an; Flüssigkeitsansammlung; schiffchenförmige, schwarze Brut | nicht meldepflichtig | — (imkerlich) |
| *(aus Übersicht)* **Flügeldeformationsvirus (DWV)** | Virus (Varroa-übertragen) | Stummelflügel, verkürzter Hinterleib | nicht meldepflichtig | — (Varroa unter Kontrolle halten) |
| *(aus Übersicht)* **Schwarzes Königinnenzellen-Virus (BQCV)** | Virus (Varroa-übertragen) | Königin schlüpft nicht; schwarze eingetrocknete Königin/Brut | nicht meldepflichtig | — (Varroa unter Kontrolle halten) |

---

## 2.1 Amerikanische Faulbrut (AFB) — MB V2208

- **Erreger:** Bakterium (Bakterienkrankheit, sporenbildend). Sporen **bis 60 Jahre keimfähig**; eine zu Schorf eingetrocknete Made kann **> 2 Milliarden Sporen** enthalten. Ansteckung der Larven über den **Futtersaft in den ersten 48 Stunden**. Erwachsene Bienen erkranken nicht, sind aber Träger.
- **Symptome/Diagnose:** Lückenhaftes Brutnest; Maden sterben **in den verdeckelten Zellen**, zerfallen zu brauner Masse; eingefallene, dunkle Zelldeckel mit Löchern; **Zündholztest: mind. 1 cm lange Fäden** (hell- bis kaffeebraune, fadenziehende Masse); frische Infektion riecht **nach frischem Quark**, fortgeschritten **faulig nach Knochenleim**; im Endstadium zungenförmiger, dunkelbrauner-schwarzer Schorf am Zellboden; schwache Völker.
- **Verwechslung:** Sauerbrut (Hauptunterschied: AFB **≥1 cm** Fäden & Tod **nach** Verdeckelung; EFB **<1 cm** & Tod **vor** Verdeckelung).
- **Rechtsstatus:** **Meldepflichtige Tierseuche — zu bekämpfen.** Abnormale Erscheinungen **sofort** dem Bieneninspektor melden; **unverzüglich AFA BI beiziehen.**
- **Übertragungswege:** Bienen (Räuberei, Verflug, Drohnen); Imker (Rähmchentausch, Volksvereinigung, kranke Schwärme, verseuchtes Material, Verfüttern von infiziertem Honig/Importhonig, ungenügend sterilisiertes Wachs, unsaubere Entsorgung, Kauf kranker Völker).
- **Vorbeugung:** genügend Futter; regelm. Brutbildkontrolle; Unterkühlung der Brut vermeiden; vitale Völker mit jungen Königinnen & gutem Putztrieb; schwache Völker auflösen; Varroa nach Konzept; kein betriebsfremder Honig; Räuberei vermeiden; regelm. Wabenerneuerung; **Gesundheitsbestätigung** beim Zukauf verlangen; keine Völker nahe Sperrgebiete; Occasionsmaterial reinigen/desinfizieren.
- **Bekämpfung/Sanierung:** **Kein Heilmittel.** Völker mit Symptomen werden vom Bieneninspektor **abgeschwefelt**. Abgetötete Bienen, Brut- und Futterwaben **bienendicht verpackt** zur **Kehrrichtverbrennungsanlage** (direkte Verbrennung). Nicht zuordenbare Honigwaben einschmelzen und mit Hitze behandeln. Sanierung strikt nach Vorgaben AFA BI / **Technische Weisungen BLV**.

## 2.2 Sauerbrut / Europäische Faulbrut (EFB) — MB V2402

- **Erreger:** Bakterium; kann Monate–Jahre aktiv bleiben; Erreger **noch Monate keimfähig**. Ansteckung über die Nahrung der jungen Larven. Erwachsene Bienen erkranken nicht, sind Träger. Larven sterben **meist vor der Verdeckelung**.
- **Symptome/Diagnose:** Lückenhaftes Brutnest; Larven werden schlaff, **verfärben sich gelblich→braun/schwarz**, liegen **verdreht in allen Stellungen**; trocknen zu **Schuppen**; **Zündholztest < 1 cm** (schleimig, wenig fadenziehend); Geruch **Käse/Fussschweiss bis säuerlich**, nach Fäkalien; selten verdeckelte Zellen (flache/eingesunkene, durchlöcherte, feuchte Deckel).
- **Verwechslung:** Amerik. Faulbrut, Kalkbrut, Sackbrut, Varroatose, Tropilaelaps.
- **Rechtsstatus:** **Meldepflichtige Tierseuche — zu bekämpfen.** **Unverzüglich AFA BI beiziehen.**
- **Bekämpfung/Sanierung:** Kein Heilmittel. Völker mit Symptomen **abgeschwefelt**. Entsorgung wie AFB (bienendicht → KVA). **Auf Anordnung des Kantonstierarztes** können Völker **ohne klinische Symptome** per **Kunstschwarmverfahren** (offen/geschlossen) teilsaniert werden:
  - **Offenes KS-Verfahren:** Bienen des symptomfreien Volks in **desinfizierte Beute mit Wachsleitstreifen**; alle bisherigen Waben entsorgen; Material/Beuten mit zugelassenem Desinfektionsmittel reinigen. Nach **2–5 Tagen** neu ausgebaute Waben entfernen → durch Mittelwände ersetzen; Bienen **1:1** füttern; ausgebaute Wachsleitstreifen entsorgen.
  - **Geschlossenes KS-Verfahren:** Bienen in **Schwarmkiste** → **Kellerhaft ohne Futter, max. 14 °C**; wenn **erste Bienen von der Traube fallen** → in desinfizierte Beute mit Mittelwänden einlogieren; **1:1** (Zucker:Wasser) füttern.
  - Geregelt in den **Technischen Weisungen BLV**.

## 2.3 Kleiner Beutenkäfer — *Aethina tumida* — MB V2208 (+ Bestimmungshilfe)

- **Erreger/Typ:** Käfer, Ordnung Coleoptera, Familie Glanzkäfer (Nitidulidae). **Adult 5–7 mm lang, 2,5–3,5 mm breit**, Deckflügel kürzer als Hinterleib, **Fühler keulenförmig**. **Larve bis 10 mm**, **6 Beine**, **2 Dornen-/Stachelborstenreihen** auf dem Rücken. **Eigelege 1,5 × 0,25 mm** (massige Gelege in Ritzen unter Zelldeckeln).
- **Vermehrung:** pflanzt sich **3–4×/Jahr** fort; Weibchen legt **bis 1'000 Eier/Saison**. Frisst Brut (bevorzugt), Waben, Honig, Pollen, tote Bienen.
- **Symptome/Diagnose:** Eigelege in Ritzen; Käferlarven im Kasten; **Schleimspuren** von Wanderlarven; adulte Käfer im/um Kasten; **zerfressenes Wabenmaterial ohne Gespinst** (Abgrenzung zur Wachsmotte); **übelriechender, gärender Honig**.
- **Verwechslung:** Larven vs. **Wachsmotte** (Schmetterling, Bauchfüsse, Nachschieber, keine Rückendornen) und **Schmeiss-/Fleischfliege** (kein Kopf/Beine, vorne spitz). → Larven-Unterscheidung nur mit Lupe.
- **Rechtsstatus:** **Meldepflichtige Tierseuche — zu bekämpfen. Unverzüglich AFA BI beiziehen.** Jeder Verdacht umgehend melden.
- **Früherkennung:** **Schäfer-Diagnosefalle** durch Flugloch auf sauberen, gemüll-/propolisfreien Beutenboden (offene Böden mit Varroa-Schieber schliessen); **nach 48 h** Falle rasch ziehen, im Ausschlagbeutel ausklopfen; gefangene Käfer **> 10 h im Tiefkühler abtöten**.
- **Sanierung:** **Ganzer Bienenstand** wird saniert — **keine Teilsanierung.** Völker **innert max. 2 Tagen abgeschwefelt**, bienendicht verpackt, verbrannt. Wabenhonig & Imkereinebenprodukte (Futterhonig, Wachs, Gelée royale, Propolis, Pollen) vernichtet. Imkereimaterial vernichtet/entsorgt — **Alternative: Tiefgefrieren** (Kantonsentscheid). Bienenhaus reinigen, **umliegender Boden behandelt oder abgetragen**. Imker sanierungspflichtig unter Aufsicht AFA BI. **Technische Weisungen BLV.**

## 2.4 Kalkbrut — MB V1708

- **Erreger:** **Pilzkrankheit**; befällt Arbeiterinnen- und Drohnenbrut. Ansteckung über Futteraufnahme der Larven; Pilz durchwächst die Larve. **Sporen jahrzehntelang keimfähig.** Begünstigt durch **schwache Völker, Temperaturstürze, hohe Feuchtigkeit** — kann seuchenartig ganze Stände befallen.
- **Symptome/Diagnose:** Maden sterben & verfärben **weiss→grau→schwarz** (Mumien); morgens **Mumien auf Flugbrett/Kastenboden**; **beim Schütteln der Wabe rasseln** die Mumien in den Zellen; lückenhaftes Brutnest; oft **Randwaben** betroffen (temperaturbedingt), v.a. **Frühjahr**.
- **Verwechslung:** Sauerbrut.
- **Rechtsstatus:** **Nicht meldepflichtig** (rein imkerlich).
- **Vorbeugung:** genügend Futter; schwache Völker auflösen; Völker bei tiefen Temp. nicht öffnen; keine mumienhaltigen Waben tauschen; Zucht auf vitale/resistente Völker; anfällige Völker umweiseln; regelm. Wabenerneuerung; guter Wärmehaushalt/einengen; **trockener, warmer Standort**.
- **Bekämpfung leicht:** befallene Waben entfernen/einschmelzen; Volk einengen (im Schweizerkasten ev. Kissen); Futter sichern; **Putztrieb anregen** (Waben mit verdünntem Zuckerwasser besprühen).
- **Bekämpfung stark:** Volk auf **Neubau** in saubere Beute (alles Wabenmaterial einschmelzen); **Königin auswechseln** (besserer Putztrieb); schwache Völker **abschwefeln**; besserer Standort.

## 2.5 Durchfallerkrankungen — Nosema / Ruhr — MB V1906

- **Erreger:** **Nosema = Pilzkrankheit** mit zwei Erregern ***Nosema apis* & *Nosema ceranae*** (Ansteckung als Sporen über Nahrung/Wasser/Oberflächen; Vermehrung im Mitteldarm; Weitergabe über Kot; stark saisonal, v.a. Frühling; ganzjährig symptomlos nachweisbar). **Ruhr = primär winterliche, nicht ansteckende Darmerkrankung** (Ursache: Überwinterungsprobleme, hoher Waldhonig-Anteil, Stress/Luftmangel/Störung der Winterruhe). **Amöben-verursachte Ruhr ist ansteckend.** In Mitteleuropa selten Ursache für Völkerverluste.
- **Symptome/Diagnose:** **Kotflecken** auf Flugbrett/Waben (v.a. Frühling); flugunfähige, hüpfende, krabbelnde Bienen; Völker schwächeln/sterben; bei **starkem Nosema-Befall Mitteldarm trüb, milchig/weiss, aufgetrieben** (gesund: gelb/bräunlich). **Nur Laboranalyse** bestätigt sicher.
- **Rechtsstatus:** **Nicht meldepflichtig.**
- **Vorbeugung:** schwache Völker auflösen; eng halten; kleine gesunde Völker vereinen; Wabenerneuerung; **saubere Tränke** (nicht im Anflugfeld); Zucht auf Vitalität; **trockener/windgeschützter/warmer Standort** + Pollenversorgung; grosse Honigtau-Reserven beim Überwintern meiden; Winterruhe sichern.
- **Bekämpfung:** **kein zugelassenes Tierarzneimittel** — Vorbeugung ist beste Bekämpfung. Leichter Befall: **Kunstschwarm** in sauberem Kasten auf Neubau (ab Blüte Löwenzahn; s. Notbehandlung 1.7.1/1.7.2). Starker Befall: **Vernichtung** von Volk und Waben.

## 2.6 Wachsmotte (gross/klein) — MB V2310

- **Erreger/Typ:** **Falter** (Zünsler/Pyralidae), Grosse & Kleine Wachsmotte. Larve frisst Bienenlarvenkot, Nymphenhäutchen, Pollen, Gemüll — **zerstört Wabenmaterial**. In der Natur nützlich (räumt Altwaben/Erregerquellen ab).
- **Symptome/Diagnose:** **Gespinste**; **schwarzer Kot** auf Boden/Varroa-Unterlage; im Volk **Röhrchenbrut** (erhöhte, nicht geschlossene Brut → Frassgang darunter); beim Klopfen an den Wabenschenkel verlassen die Larven die Waben.
- **Schwelle:** **Keine Schäden bei Temperaturen < 12 °C.**
- **Rechtsstatus:** **Nicht meldepflichtig.**
- **Vorbeugung/Bekämpfung:** **Keine Biozide/Mittel mehr zugelassen.** Nur helle, unbebrütete, pollenfreie Honigwaben lagern; Futter-/Honigwaben getrennt; **Brutwaben einschmelzen** statt lagern; **Wabenlager kühl (< +12 °C), belüftet, hell**; Altwaben laufend einschmelzen; keine schwachen Völker; im Volk **keine Bekämpfung**, nur starke Völker + Wabenerneuerung + Varroaunterlage/Leerräume reinigen. **Futterwaben bei −18 °C für 2 Tage einfrieren**, dann dicht lagern; Gespinstballen sofort einschmelzen/entsorgen. Varroazid-kontaminierte Brutwaben entsorgen oder zu Kerzen.

## 2.9 Maikrankheit — MB V1804

- **Erreger/Ursache:** **Nicht ansteckend** (nach heutigem Wissen). Hauptauslöser **Wassermangel** der Ammenbienen bei der Pollenverdauung; ev. auch Bakterium ***Spiroplasma apis*** oder gewisse Pollen; vermutlich Zusammenspiel mehrerer Faktoren. Betroffen: **Ammenbienen/junge Bienen**. Begünstigt durch kaltes Wetter mit **„Bise"** (Nordwind); auch Völker mit viel Brut nach Flugbienen-Verlust (z. B. Flugling). Tritt **im Mai** (Ende April – Juni) auf.
- **Symptome/Diagnose:** Junge Bienen **krabbeln aus dem Stock**, sammeln sich **zitternd** davor; kleinere/grössere **Anhäufungen junger Bienen ausserhalb der Beuten**; bei Druck auf den prall gefüllten Hinterleib tritt **gelber bis brauner, dicker Kot** aus. Junge Bienen erkennbar an vollständigem Haarkleid & glatten Flügelrändern.
- **Verwechslung:** **Bienenvergiftung** (MB 3.1.2) — aber nur **junge** Bienen betroffen (keine Sammelflüge → Pestizidkontakt unwahrscheinlich); auch Durchfallerkrankungen (MB 2.5).
- **Rechtsstatus:** **Nicht meldepflichtig.**
- **Bekämpfung/Vorbeugung:** Bienen in den Wabengassen **besprühen** oder mit Futtergeschirr tränken (**warmes, verdünntes Zuckerwasser oder reines Wasser**); permanente **Bienentränke** an windgeschützter, sonniger Stelle nahe Stand, **ausserhalb der Flugschneise**. **Bei Honigaufsatz nur reines Wasser** (Gefahr der Honigverfälschung).

## 2.10 Chronisches Bienen-Paralyse-Virus (CBPV) — MB V2403

- **Erreger:** **Virus** — ansteckend; Übertragung durch **Körperkontakt, Nahrung/Futteraustausch, Kot**. Begünstigt durch dichtgedrängte Bienen, Schlechtwetterperioden, lange Transporte, **starke Waldtracht**, hohe Völkerdichte/knappe Nahrung, **hohe Varroabelastung**. Für befallene erwachsene Bienen tödlich; meist nur einzelne Völker.
- **Symptome/Diagnose:** **Aufgetriebener Hinterleib**; Bienen **komplett schwarz, haarlos, glänzend, wirken kleiner**; **krabbelnde, flugunfähige** Bienen; **Zittern/Lähmung**; starker Totenfall; abgespreizte Flügel; Zutritt ins Volk wird verwehrt (wie bei Räuberei). Auftreten **April–September**.
- **Verwechslung:** **abgearbeitete Bienen**; **Bienenvergiftung** (MB 3.1.2).
- **Rechtsstatus:** **Nicht meldepflichtig.** Eher gutartig — Volk heilt sich meist selbst; zu stark geschwächt → abschwefeln.
- **Vorbeugung:** im Frühling zügig mit Mittelwänden erweitern; Jungvölker bilden; keine Wabentausche; Varroa überwachen; abwechslungsreiches Nahrungsangebot; Bienendichte an Ressourcen anpassen; nur starke Völker.
- **Bekämpfung leicht:** Jungvölker bilden; Varroa überwachen/behandeln; Verlauf beobachten. **Stark:** Honigraum abräumen; **auf Neubau setzen** (nicht zu spät) + füttern (Sirup 1:1 / eigener Honig); Brutfreiheit für Varroabehandlung nutzen; **Königin wechseln**; gesunde/kranke Völker separieren; notfalls abschwefeln. **Aus Waldtracht abwandern.** (Detail-Verfahren: Volk ~20 m verstellen, kranke Bienen + Königin abwischen & töten, gesunde fliegen zurück.)

## 2.11 Sackbrut-Virus (SBV) — MB V2204

- **Erreger:** **Virus**; vermehrt sich in erwachsenen Bienen und Brut. **Übertragung über Futtersaft** (Ammenbienen → Larven) und **durch Varroa**. Larven scheitern an der Metamorphose (Virus blockiert die Häutung) und sterben in der verdeckelten Zelle. Meist nur kleiner Brutteil betroffen; bricht bei ungünstigen Bedingungen (Pollenmangel, zu grosse Brutfläche) aus.
- **Symptome/Diagnose:** Lückenhafte Brut; **Streckmade nimmt beim Herausnehmen Sackform an**; charakteristische **Flüssigkeitsansammlung** unter der Aussenhaut; tote Brut wird braun→schwarz, **schiffchenförmig** (klebt nicht am Zellboden); eingesunkene/zerrissene/löchrige Zelldeckel.
- **Verwechslung:** **Sauer- oder Faulbrut** (v.a. entdeckelte Zellen).
- **Rechtsstatus:** **Nicht meldepflichtig.** Heilung meist von selbst; häufig kein sichtbarer Einfluss auf Volksstärke — in Kombination mit anderen Krankheiten aber gefährlich.
- **Vorbeugung:** nur gesunde/starke Völker; **Varroa niedrig halten**; gutes Putzverhalten bevorzugen; Nahrung/Pollen sichern; Verflug/Räuberei vermeiden, Flugloch anpassen; Brutraumgrösse anpassen; Verstellen beschränken; Material reinigen; Wabenerneuerung; Jungvölker nicht vor Löwenzahn-/Apfel-/Raps-/Bergahorn-Blüte bilden.
- **Bekämpfung:** leicht = keine Massnahmen (nur beobachten); mittel = Flüssigfutter (beschleunigt Ausräumen) + **Königin mit gutem Hygieneverhalten**; hoch = **Varroabehandlung**, auf Neubau setzen + Flüssigfutter, befallene Waben vernichten, Material desinfizieren, stark betroffene Völker beseitigen.

## 2.12 Tropilaelaps — MB V2603

- **Erreger:** **Milbe** — *Tropilaelaps clareae* & *T. mercedesae*, aus Asien; braun-rot, **länger als breit** (mit Beinen ca. **1 × 0,8 mm**), **bewegt sich schneller als Varroa**. Vermehrt sich in Brutzellen; **Brutfreiheit reduziert Population stark**. Auswirkungen wie Varroa (geringeres Schlupfgewicht, kürzere Lebensdauer, Missbildungen, **Virusübertragung, v.a. DWV**).
- **Status Verbreitung:** in **Osteuropa** (u. a. Russland, Georgien) gefunden; **in der Schweiz bisher nicht nachgewiesen**. Keine zugelassenen Tierarzneimittel, kein erprobtes Behandlungskonzept.
- **Symptome/Diagnose:** Lückenhaftes Brutnest; Milben **in Brutzellen** (selten auf erwachsenen Bienen, auf Unterlagen schwer sichtbar); Löcher in Brut-Zelldeckeln; **verkrüppelte Bienen (zu kurzer Hinterleib, deformierte Flügel) bei geringem Varroabefall** = Warnsignal. Am ehesten **ab Sommer** in verdeckelter Brut; Okt–März wenig Milben (Brutunterbruch). Methoden: Brutzellen öffnen (Pinzette/Klebeband), **Puderzuckermethode**, Unterlagenkontrolle.
- **Verwechslung:** Sauerbrut, Varroatose; **Pollenmilben**.
- **Rechtsstatus:** **Zu überwachende Tierseuche.** **Meldung an AFA BI empfohlen** (bei Verdacht: Brutprobe fürs Referenzlabor). ⚠️ *Zu bekämpfen* vs. *zu überwachen* — die aktuelle Formulierung des Merkblatts (V2603) ist „zu überwachen"; TSV-Einstufung in der App gegenprüfen (siehe App-Relevanz).
- **Vorbeugung:** **Verzicht auf Importe ist entscheidend**; konsequente Völkerbeurteilung/-auslese (4.7); nur starke, gesunde Völker; Verflug/Räuberei minimieren; regelm. Kontrolle (z. B. bei Varroadiagnose auf ungewöhnliche Milben achten). Gewisse Varroazide wirken auch gegen Tropilaelaps — in CH aber nicht zugelassen.

## Zusatz aus Übersichts-Merkblatt (2) — Virosen ohne eigenes MB

- **Flügeldeformationsvirus (DWV):** Stummelflügel, verkürzter Hinterleib; **von Varroa übertragen**; Massnahme = **Varroa unter Kontrolle**; bei starkem Befall unverzüglich behandeln; nur starke Völker. Nicht meldepflichtig.
- **Schwarzes Königinnenzellen-Virus (BQCV):** Königin schlüpft nicht / schwarze eingetrocknete Königin; Brut kann befallen werden & wird schwarz; gelegentlich Drohnenbrut; **von Varroa übertragen**; kann mit **Nosema** zusammen auftreten; v.a. Frühling. Nicht meldepflichtig.

---

## [GRAFIK]-Verzeichnis (Bestimmungshilfen / Symptombilder / Ablaufdiagramme)

- [GRAFIK: Übersichtstabelle „Aussehen | Diagnose | Vorgehen | Wichtiges" für alle Krankheiten mit Symptomfotos — Quelle 2_uebersicht_krankheiten_schaedlinge]
- [GRAFIK: Zündholz-/Streichholzprobe AFB — fadenziehende Masse ≥ 1 cm, Foto Guido Eich — Quelle 2.1_faulbrut]
- [GRAFIK: AFB-Zelldeckel eingesunken/durchlöchert + zungenförmiger Schorf — Quelle 2.1_faulbrut / 2_uebersicht]
- [GRAFIK: Sauerbrut — verdrehte, gelb-braune Maden & Schuppen, Zündholzprobe < 1 cm — Quelle 2.2_sauerbrut]
- [GRAFIK: Ablaufdiagramm **offenes** Kunstschwarm-Sanierungsverfahren (symptomfrei → Wachsleitstreifen → nach 2–5 Tagen Mittelwände → 1:1 füttern) — Quelle 2.2_sauerbrut]
- [GRAFIK: Ablaufdiagramm **geschlossenes** Kunstschwarmverfahren (Schwarmkiste → Kellerhaft ≤ 14 °C ohne Futter → einlogieren) — Quelle 2.2_sauerbrut]
- [GRAFIK: Larven-Unterscheidungstabelle Kleiner Beutenkäfer vs. Wachsmotte vs. Schmeiss-/Fleischfliege (Beine, Kopf, Rückendornen, Grösse) — Quelle 2.3_kleiner_beutenkaefer]
- [GRAFIK: Bestimmungshilfe Aethina tumida mit Massen — Eigelege 1,5×0,25 mm, Wanderlarve ~10 mm mit 2 Stachelborstenreihen, Käfer 5–7 mm, keulenförmige Fühler — Quelle Bestimmungshilfe_aide_a_la_determination…]
- [GRAFIK: Anwendung Schäfer-Diagnosefalle (durch Flugloch, 48 h, Tiefkühler > 10 h) — Quelle Bestimmungshilfe… / 2.3_kleiner_beutenkaefer]
- [GRAFIK: Kalkbrutmumien weiss/grau/schwarz + Wabe mit Kalkbrut — Quelle 2.4_kalkbrut]
- [GRAFIK: Flugbrett mit hell-/dunkelbraunen Kotflecken (Nosema/Ruhr) — Quelle 2.5_durchfallerkrankungen]
- [GRAFIK: Röhrchenbrut der Wachsmotte + schwarzer Kot auf Unterlage — Quelle 2.6_wachsmotte]
- [GRAFIK: Maikrankheit — Anhäufungen junger Bienen vor der Beute, Kotaustritt bei Druck — Quelle 2.9_maikrankheit]
- [GRAFIK: CBPV — schwarze, haarlose, glänzende Bienen — Quelle 2.10_bienenparalyse]
- [GRAFIK: Sackbrut — Streckmade in Sackform, tote Vorpuppe mit Flüssigkeitsansammlung, Pfeilmarkierung befallener Zellen (rot/blau) — Quelle 2.11_sackbrut]
- [GRAFIK: Direktvergleich Varroamilbe (links) vs. Tropilaelaps (rechts, länger als breit), © Dan Etheridge — Quelle 2.12_tropilaelaps]
