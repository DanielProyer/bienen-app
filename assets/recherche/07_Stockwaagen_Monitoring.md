# Stockwaagen & Bienenmonitoring

## Warum eine Stockwaage?

Eine digitale Stockwaage ermöglicht die Fernüberwachung der Bienenvölker ohne direkte Kontrolle. Besonders wertvoll für:
- **Trachtbeobachtung**: Gewichtszunahme zeigt Nektareintrag in Echtzeit
- **Schwarmkontrolle**: Plötzlicher Gewichtsverlust = Schwarm abgegangen
- **Futterkontrolle**: Wintervorräte überwachen ohne Störung
- **Wetterkorrelation**: Zusammenhang Wetter/Tracht erkennen
- **Standortbewertung**: Trachtpotenzial von Arosa quantifizieren

## Anforderungen Standort Arosa (1570m)

- **Konnektivität**: 4G/LTE-M bevorzugt (gute Swisscom-Abdeckung in Arosa)
- **Temperaturbereich**: -25°C bis +45°C (Bergwinter!)
- **Wetterfest**: Schnee, Regen, UV-Strahlung
- **Stromversorgung**: Solar + Akku oder Langzeit-Batterie (>2 Jahre)
- **LoRa**: Nur möglich wenn Helium-Gateway in Reichweite (nicht garantiert!)

## Systemvergleich

### 1. HiveWatch (Schweiz) - EMPFEHLUNG

| Merkmal | Details |
|---------|---------|
| **Hersteller** | HiveWatch AG, Schweiz |
| **Konnektivität** | 4G/LTE-M (Swisscom) |
| **Sensoren** | Gewicht (±50g), Temperatur, Luftfeuchtigkeit |
| **Temperaturbereich** | -35°C bis +65°C |
| **Batterie** | Lithium, ~2 Jahre |
| **Preis StarterSet** | CHF 694.- |
| **Abo** | CHF 8.-/Monat (96.-/Jahr) |
| **5-Jahres-Kosten** | ~CHF 1'174.- |
| **Kaufen** | [Bienen Meier AG](https://www.bienen-meier.ch/de/produkt/digitale-stockwaagehivewatch-starterset) |
| **Website** | [hivewatch.ch](https://hivewatch.ch) |

**Vorteile:**
- Schweizer Produkt, Schweizer Support
- Entwickelt für Schweizer Bienenhaus-Konfiguration
- 4G funktioniert garantiert in Arosa
- Einfache Installation, keine Konfiguration nötig
- Gute App mit Benachrichtigungen

**Nachteile:**
- Höherer Preis als DIY-Lösungen
- Proprietäres System (Vendor Lock-in)
- Nur Gewicht als primärer Sensor

---

### 2. BroodMinder (USA/EU)

| Merkmal | Details |
|---------|---------|
| **Hersteller** | BroodMinder Inc. (EU-Vertrieb aus Frankreich) |
| **Modelle** | W5 (Waage), T2 (Temperatur), TH (Temp+Humidity) |
| **Konnektivität** | Bluetooth → Cell Hub 4G oder WiFi Hub |
| **Sensoren** | Gewicht (±100g), Temperatur, Luftfeuchtigkeit, Sound (optional) |
| **Batterie** | CR2032, 5 Jahre (!) |
| **Preis W5 Waage** | EUR 129.- |
| **Preis Cell Hub 4G** | EUR 349.- + ~EUR 90.-/Jahr Daten |
| **5-Jahres-Kosten** | ~EUR 930.- (1 Waage + Hub) |
| **Kaufen** | [eu.broodminder.com](https://eu.broodminder.com) |
| **App** | Bees App (iOS/Android) + Web-Dashboard |

**Vorteile:**
- 5 Jahre Batterie (kein Laden/Wechseln im Winter!)
- Modulares System (Waage, Temperatur, Sound einzeln kaufbar)
- Bis 5 Völker mit einem Hub überwachen
- Kostenloser Basis-Tarif ("Citizen Scientist")
- Offene API, Daten gehören dem Nutzer
- KI-Schwarmvorhersage ("Bees AI")

**Nachteile:**
- Hub separat nötig (Kosten!)
- Genauigkeit ±100g (weniger präzise als HiveWatch)
- Support/Versand aus Frankreich
- Etwas komplexere Ersteinrichtung

---

### 3. Wolf Waagen ApiGraph 4.0 (Deutschland)

| Merkmal | Details |
|---------|---------|
| **Hersteller** | Wolf Waagen, Bayern |
| **Konnektivität** | 4G/LTE-M |
| **Sensoren** | Gewicht (±10g!), Temperatur, Luftfeuchtigkeit |
| **Kapazität** | Bis 200kg |
| **Batterie** | Lithium-Akku + Solar-Option |
| **Preis Basisstation** | EUR 899.- |
| **Preis Erweiterungswaage** | EUR 299.- |
| **Abo** | EUR 60.70/Jahr (günstigstes!) |
| **5-Jahres-Kosten** | ~EUR 1'200.- (inkl. Zoll CH) |
| **Kaufen** | [shop.wolf-waagen.de](https://www.shop.wolf-waagen.de) |
| **Alternative** | [Imkado Starter-Set](https://imkado.de/products/wolf-set-deluxe) |

**Vorteile:**
- Höchste Präzision (10g Auflösung!)
- Erweiterbar bis 30 Waagen pro Station
- Günstigstes Abo (EUR 60.70/Jahr)
- Bewährte deutsche Ingenieursqualität
- Beste Datenvisualisierung im Web-Portal

**Nachteile:**
- Höchster Anschaffungspreis
- Import aus Deutschland (Zoll ~7.7% + MwSt)
- Grösseres/schwereres Gerät
- Keine Schweizer Vertretung

---

### 4. beenli (Schweiz)

| Merkmal | Details |
|---------|---------|
| **Hersteller** | beenli, Schweiz |
| **Konnektivität** | LoRaWAN (Helium/TTN) |
| **Sensoren** | Gewicht, Temperatur, Luftfeuchtigkeit |
| **Batterie** | Solar + Akku |
| **Preis** | ab CHF 390.- |
| **Abo** | CHF 0.- (LoRa = kostenlos!) |
| **Kaufen** | [beenli.ch](https://beenli.ch) |

**Vorteile:**
- Günstiger Einstiegspreis
- Kein Abo nötig (LoRa-Netzwerk kostenlos)
- Schweizer Produkt
- Solar = kein Batteriewechsel

**Nachteile:**
- ⚠️ LoRa-Abdeckung in Arosa NICHT GESICHERT
- Abhängig von Helium/TTN Gateway in Nähe
- Weniger bewährt als Marktführer

---

### 5. BeeScales BS01 (Slowenien)

| Merkmal | Details |
|---------|---------|
| **Hersteller** | BeeScales / Logar |
| **Konnektivität** | GSM/4G |
| **Sensoren** | 2x Gewicht, Temperatur, Luftfeuchtigkeit |
| **Batterie** | Solar + Akku |
| **Preis** | EUR 520.- (2 Waagen!) |
| **Abo** | ~EUR 30.-/Jahr |
| **5-Jahres-Kosten** | ~EUR 670.- |
| **Kaufen** | [honigschleudern.eu](https://www.honigschleudern.eu/de/beescales-bienenstockwaage-bs01/) |

**Vorteile:**
- 2 Waagen zum Preis von einer!
- Solar-betrieben
- Sehr gutes Preis-Leistungs-Verhältnis
- Niedrige laufende Kosten

**Nachteile:**
- Weniger bekannt in der Schweiz
- Support aus Slowenien
- Etwas weniger Features in der App

---

### 6. DIY: HoneyPi / Beelogger

| Merkmal | Details |
|---------|---------|
| **Basis** | Raspberry Pi / ESP32 |
| **Konnektivität** | WiFi (!) |
| **Sensoren** | Frei wählbar |
| **Preis** | EUR 80-150.- (Bauteile) |
| **Abo** | EUR 0.- |
| **Websites** | [honey-pi.de](https://honey-pi.de) / [beelogger.de](https://beelogger.de) |

**Vorteile:**
- Extrem günstig
- Volle Kontrolle, Open Source
- Beliebig erweiterbar

**Nachteile:**
- ⚠️ Benötigt WiFi am Bienenstand (unrealistisch in Arosa!)
- Hoher Zeitaufwand für Aufbau + Wartung
- Keine Garantie, kein Support
- Wetterfestigkeit selbst sicherstellen

---

## Entscheidung: HiveWatch StarterSet

### Begründung:
1. **4G-Konnektivität** funktioniert garantiert in Arosa (Swisscom LTE)
2. **Schweizer Produkt** mit lokalem Support
3. **Plug & Play** - keine technische Konfiguration nötig
4. **Temperaturbereich** -35°C ideal für Bergwinter
5. **Alles-in-Einem** - keine separaten Hubs/Gateways
6. Preis-Leistung OK für professionellen Einsatz

### Geplante Konfiguration:
- 1x HiveWatch StarterSet (CHF 694.-) für Referenzvolk
- Später ggf. Erweiterung auf 2. Waage
- Abo: CHF 8.-/Monat

### Alternativen im Auge behalten:
- **BroodMinder** falls mehr Sensoren gewünscht (Sound, mehrere Temp-Punkte)
- **Wolf Waagen** falls höchste Präzision benötigt wird
- **BeeScales BS01** als günstige Option für 2. Waage

## Liveübertragung & Datennutzung

### Was eine Stockwaage zeigt:
- **Tägliche Gewichtskurve**: Zunahme = Tracht, Abnahme = Verbrauch/Schwarm
- **Temperatur**: Bruttemperatur (35°C), Wintertraube-Aktivität
- **Alerts**: Schwarm (>2kg Verlust plötzlich), Diebstahl, Umkippen

### Integration in Bienen-App:
- Dashboard-Widget mit aktuellem Gewicht + Trend
- Historische Diagramme (Tag/Woche/Monat/Jahr)
- Push-Notifications bei Anomalien
- Vergleich mit Wetterdaten

### Datenbeispiel Jahresverlauf Arosa:
```
Frühling (Mai-Juni): +0.5 bis 2 kg/Tag bei Alpenblüte
Sommer (Juli-Aug):   +0.2 bis 1 kg/Tag, Abnahme bei Schlechtwetter
Herbst (Sept-Okt):   Stagnation, Auffütterung sichtbar
Winter (Nov-April):   -20 bis -50g/Tag (Futterverbrauch)
```

## Links & Ressourcen

- [Waagen.blog - Marktübersicht](https://waagen.blog/bienenstockwaagen-marktuebersicht/)
- [Swisscom Netzabdeckung prüfen](https://scmplc.begasoft.ch)
- [Helium Coverage Map](https://mappers.helium.com) (für LoRa-Prüfung)
- [BienenSchweiz - Digitale Imkerei](https://www.bienen.ch)
