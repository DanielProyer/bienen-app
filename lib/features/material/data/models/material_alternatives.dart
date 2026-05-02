class ProductAlternative {
  final String name;
  final String supplier;
  final String price;
  final String? url;
  final List<String> pros;
  final List<String> cons;
  final bool isRecommended;

  const ProductAlternative({
    required this.name,
    required this.supplier,
    required this.price,
    this.url,
    this.pros = const [],
    this.cons = const [],
    this.isRecommended = false,
  });
}

/// Extended product descriptions for key items
const materialProductInfo = <String, String>{
  'Komplettbeute DB Halbzargen Hochboden':
      'Dadant Blatt Komplettsystem: Blechdeckel, 1 Brutzarge (12er), 2 Honighalbzargen, '
      'Hochboden mit Varroagitter, Absperrgitter. Fichtenholz, zusammengebaut und gestrichen. '
      'Masse Brutraum: 513 x 513 x 318mm (Schweizer Standard).',
  'Imkerjacke mit Schleier':
      'Professionelle Imkerjacke mit abnehmbarem Rundschleier. '
      'Baumwolle/Mesh-Kombination für gute Belüftung. Elastische Bündchen an Ärmeln und Taille. '
      'Wichtig: Grösse passend wählen für Bewegungsfreiheit.',
  'Smoker Dadant gross':
      'Grosser Edelstahl-Smoker mit Lederblag. Durchmesser 10cm, Höhe 25cm. '
      'Innenlüfter für lange Brenndauer. Ideal für Dadant-Beuten. '
      'Brennmaterial: Jutesäcke, Holzpellets oder Eierkarton.',
  'Honigschleuder Logar 20/8 Radial':
      'Radialschleuder für 20 Halbrahmen oder 8 Dadant-Brutwaben. '
      'Edelstahl V2A, Motorantrieb mit Drehzahlregler. Deckel transparent (Plexiglas). '
      'Höhe ca. 85cm, Durchmesser 63cm. Auslaufhahn 6/4 Zoll.',
  'Stockwaage digital':
      'Digitale Stockwaage mit Fernübertragung für permanente Gewichtsüberwachung. '
      'Zeigt Trachtbeginn/-ende, Schwarmabgang, Futterverbrauch in Echtzeit. '
      'Für Arosa (1570m): 4G/LTE-M bevorzugt wegen garantierter Swisscom-Abdeckung.',
  'Nassenheider Professional Verdunster':
      'Langzeit-Verdunster für Ameisensäure-Behandlung gegen Varroa. '
      'Konstante Verdunstungsrate über 14 Tage. Dosierung über Docht-Fläche regulierbar. '
      'Anwendung: Juli-August nach Honigernte bei >15°C.',
  'Futtersirup Apiinvert 16 kg':
      'Fertig invertierter Zuckersirup (Glucose/Fructose/Saccharose). '
      'pH-Wert bienengerecht. Bag-in-Box Verpackung für einfache Dosierung. '
      'Dosierung: ca. 15-20 kg pro Volk für Wintervorrat in Arosa.',
  'Einlöttrafo BPS Basic':
      'Transformator zum Einlöten von Mittelwänden in Drahtrahmen. '
      '12-19V einstellbar, Timer-Funktion. Klemmen für sicheren Kontakt. '
      'Alternativ: Akku-Einlötgerät für mobilen Einsatz.',
  'Refraktometer':
      'Optisches Messgerät für den Wassergehalt von Honig. '
      'Skala: 12-27% Wassergehalt. Grenzwert Schweiz: max. 18.5% (Goldsiegel: 17.5%). '
      'Kalibrierung mit destilliertem Wasser, temperaturkompensiert.',
};

/// Alternatives with pros/cons for each material item
const materialAlternatives = <String, List<ProductAlternative>>{
  'Komplettbeute DB Halbzargen Hochboden': [
    ProductAlternative(
      name: 'Komplettbeute Wespi DB12 Halbzargen',
      supplier: 'Wespi Bienenzubehör',
      price: 'CHF 469.00',
      url: 'https://www.wespi-imkerei.ch',
      pros: ['Schweizer Hersteller, bewährt', 'Fichtenholz, fertig montiert & gestrichen', 'Passt zu allem Wespi-Zubehör'],
      cons: ['Nur Fichtenholz (kein Weymouthskiefer)', 'Relativ schwer'],
      isRecommended: true,
    ),
    ProductAlternative(
      name: 'Dadant Blatt Beute (Bausatz)',
      supplier: 'bienenbeuten.ch',
      price: 'CHF 320.00',
      url: 'https://www.bienenbeuten.ch',
      pros: ['Günstiger als Fertigbeute', 'Weymouthskiefer verfügbar (leichter)', 'Individuell anpassbar'],
      cons: ['Selbstmontage nötig (Zeitaufwand)', 'Anstrich separat', 'Erfahrung im Holzbau von Vorteil'],
    ),
    ProductAlternative(
      name: 'Nicot Dadant Kunststoffbeute',
      supplier: 'bienen-meier.ch',
      price: 'CHF 189.00',
      url: 'https://www.bienen-meier.ch',
      pros: ['Sehr leicht (Kunststoff)', 'Wetterfest ohne Anstrich', 'Günstigster Preis', 'Einfache Reinigung'],
      cons: ['Kunststoff (weniger natürlich)', 'Keine Feuchtigkeitsregulation', 'In Imkerkreisen umstritten', 'Weniger langlebig als Holz'],
    ),
    ProductAlternative(
      name: 'Dadant US Beute (Paradise Honey)',
      supplier: 'Amazon / Paradise Honey',
      price: 'CHF 180.00',
      url: 'https://www.amazon.de',
      pros: ['Günstig', 'Schnell lieferbar'],
      cons: ['US-Mass (nicht CH-kompatibel!)', 'Importware, fragliche Qualität', 'Keine Garantie/Service', 'Rähmchen passen nicht zu CH-Standard'],
    ),
  ],

  'Imkerjacke mit Schleier': [
    ProductAlternative(
      name: 'Imkerjacke Baumwolle/Mesh mit Rundschleier',
      supplier: 'Wespi',
      price: 'CHF 107.00',
      url: 'https://www.wespi-imkerei.ch',
      pros: ['Gute Belüftung durch Mesh', 'Abnehmbarer Schleier (waschbar)', 'Bewährte Qualität'],
      cons: ['Nicht der günstigste Preis'],
      isRecommended: true,
    ),
    ProductAlternative(
      name: 'Imkerjacke "Astronaut" Ventiliert',
      supplier: 'bienen-meier.ch',
      price: 'CHF 145.00',
      url: 'https://www.bienen-meier.ch',
      pros: ['Maximale Belüftung (3-Schicht-Mesh)', 'Stichsicher', 'Ideal für heisse Tage'],
      cons: ['Teurer', 'Etwas steifer/sperriger', 'Weniger warm bei kühlem Wetter (Arosa!)'],
    ),
    ProductAlternative(
      name: 'Imkerjacke Budget (Abeille Royale)',
      supplier: 'Amazon',
      price: 'CHF 45.00',
      url: 'https://www.amazon.de',
      pros: ['Sehr günstig', 'Für Gelegenheitsnutzung OK'],
      cons: ['Dünner Stoff', 'Schleier-Qualität mässig', 'Nähte reissen schneller', 'Bienen finden Zugang'],
    ),
  ],

  'Smoker Dadant gross': [
    ProductAlternative(
      name: 'Smoker Edelstahl gross (Ø10cm)',
      supplier: 'Wespi',
      price: 'CHF 85.00',
      url: 'https://www.wespi-imkerei.ch',
      pros: ['Grosse Brennkammer, lange Brenndauer', 'Edelstahl, rostfrei', 'Lederblag haltbar', 'Innenlüfter'],
      cons: ['Etwas schwerer'],
      isRecommended: true,
    ),
    ProductAlternative(
      name: 'Smoker Mini (Ø8cm)',
      supplier: 'beetec',
      price: 'CHF 35.00',
      url: 'https://www.beetec.ch',
      pros: ['Leicht & kompakt', 'Günstig', 'Gut für schnelle Kontrollen'],
      cons: ['Brennt schneller aus', 'Zu klein für längere Arbeiten', 'Nicht ideal für mehrere Völker'],
    ),
    ProductAlternative(
      name: 'Smoker Apicoltura Lega (Italien)',
      supplier: 'imkereiausruester.ch',
      price: 'CHF 65.00',
      url: 'https://www.imkereiausruester.ch',
      pros: ['Gutes Preis-Leistungs-Verhältnis', 'Kupfer-Variante verfügbar (schön)', 'Bewährt'],
      cons: ['Import (manchmal Lieferverzögerung)', 'Blag-Qualität variiert'],
    ),
  ],

  'Stockwaage digital': [
    ProductAlternative(
      name: 'HiveWatch StarterSet (4G/LTE-M)',
      supplier: 'Bienen Meier AG',
      price: 'CHF 694.00',
      url: 'https://www.bienen-meier.ch/de/produkt/digitale-stockwaagehivewatch-starterset',
      pros: ['Schweizer Produkt & Support', '4G funktioniert garantiert in Arosa', 'Plug & Play, keine Konfiguration', 'Temperaturbereich -35 bis +65 Grad C', 'App mit Push-Benachrichtigungen'],
      cons: ['Höherer Preis', 'Abo CHF 8.-/Monat nötig', 'Nur Gewicht + Temperatur'],
      isRecommended: true,
    ),
    ProductAlternative(
      name: 'BroodMinder W5 + Cell Hub 4G',
      supplier: 'BroodMinder (EU)',
      price: 'EUR 478.00 (Waage + Hub)',
      url: 'https://eu.broodminder.com',
      pros: ['5 Jahre Batterie (!)', 'Modulares System', 'Bis 5 Völker mit einem Hub', 'KI-Schwarmvorhersage', 'Kostenloser Basis-Tarif'],
      cons: ['Hub separat nötig', 'Genauigkeit +/-100g (weniger präzise)', 'Versand aus Frankreich'],
    ),
    ProductAlternative(
      name: 'Wolf Waagen ApiGraph 4.0',
      supplier: 'Wolf Waagen (DE)',
      price: 'EUR 899.00',
      url: 'https://www.shop.wolf-waagen.de',
      pros: ['Höchste Präzision (+/-10g!)', 'Erweiterbar bis 30 Waagen', 'Günstigstes Abo (EUR 60.70/Jahr)', 'Beste Datenvisualisierung'],
      cons: ['Teuerste Anschaffung', 'Import aus Deutschland (Zoll)', 'Kein Schweizer Support'],
    ),
    ProductAlternative(
      name: 'BeeScales BS01 (Solar, 2 Waagen)',
      supplier: 'Logar / honigschleudern.eu',
      price: 'EUR 520.00',
      url: 'https://www.honigschleudern.eu/de/beescales-bienenstockwaage-bs01/',
      pros: ['2 Waagen zum Preis von einer!', 'Solar-betrieben', 'Niedrigste 5-Jahres-Kosten (~EUR 670)', 'GSM/4G'],
      cons: ['Weniger bekannt', 'Support aus Slowenien', 'Weniger Features in der App'],
    ),
  ],

  'Honigschleuder Logar 20/8 Radial': [
    ProductAlternative(
      name: 'Logar 20/8 Radial Motorschleuder',
      supplier: 'Logar Trade',
      price: 'CHF 1\'900.00',
      url: 'https://www.logar-trade.com',
      pros: ['20 Halbrahmen gleichzeitig', 'Motor mit Drehzahlregler', 'Edelstahl V2A Qualität', 'Transparenter Deckel', 'Perfekt für 4-5 Völker'],
      cons: ['Hohe Investition', 'Schwer (Transport!)'],
      isRecommended: true,
    ),
    ProductAlternative(
      name: 'Swienty Radialschleuder 12 Rahmen',
      supplier: 'Swienty (DK)',
      price: 'EUR 1\'450.00',
      url: 'https://www.swienty.com',
      pros: ['Dänische Qualität', 'Etwas günstiger', 'Leichterer Korb'],
      cons: ['Nur 12 Halbrahmen (länger schleudern)', 'Import aus Dänemark'],
    ),
    ProductAlternative(
      name: 'Handschleuder 4-Waben Tangential',
      supplier: 'Wespi',
      price: 'CHF 650.00',
      url: 'https://www.wespi-imkerei.ch',
      pros: ['Viel günstiger', 'Kein Stromanschluss nötig', 'Kompakter, leichter'],
      cons: ['Nur 4 Waben, mühsam bei 4-5 Völkern', 'Handkurbel = Muskelarbeit', 'Waben wenden nötig (Bruchgefahr)'],
    ),
    ProductAlternative(
      name: 'Schleuder mieten / Gemeinschaft',
      supplier: 'Imkerverein Arosa',
      price: 'CHF 0-50.00/Nutzung',
      url: null,
      pros: ['Keine Investition', 'Kein Lagerplatz nötig', 'Erfahrungsaustausch'],
      cons: ['Verfügbarkeit unsicher', 'Terminabsprache nötig', 'Hygiene-Verantwortung unklar', 'Längerfristig teurer'],
    ),
  ],

  'Nassenheider Professional Verdunster': [
    ProductAlternative(
      name: 'Nassenheider Professional (Doppelpack)',
      supplier: 'Wespi',
      price: 'CHF 29.00',
      url: 'https://www.wespi-imkerei.ch',
      pros: ['Bewährt seit Jahrzehnten', 'Konstante Verdunstung', 'Einfache Handhabung', 'Günstig'],
      cons: ['Nur bei >15 Grad C einsetzbar', 'Temperaturabhängige Wirkung'],
      isRecommended: true,
    ),
    ProductAlternative(
      name: 'MAQS (Mite Away Quick Strips)',
      supplier: 'bienen-meier.ch',
      price: 'CHF 38.00 (2 Streifen)',
      url: 'https://www.bienen-meier.ch',
      pros: ['Einfachste Anwendung (Streifen einlegen)', 'Nur 7 Tage Behandlung', 'Wirkt auch in verdeckelte Brut'],
      cons: ['Teurer pro Behandlung', 'Kann bei Hitze Königinnenverlust verursachen', 'Nicht bei >29 Grad C anwenden'],
    ),
    ProductAlternative(
      name: 'Liebig Dispenser',
      supplier: 'imkereiausruester.ch',
      price: 'CHF 18.00',
      url: 'https://www.imkereiausruester.ch',
      pros: ['Sehr günstig', 'Einfach', 'Schnelle Verdunstung (Schockbehandlung)'],
      cons: ['Weniger kontrollierte Verdunstung', 'Grössere Temperaturschwankungen', 'Kann Bienen stressen'],
    ),
  ],

  'Futtersirup Apiinvert 16 kg': [
    ProductAlternative(
      name: 'Apiinvert 16 kg Bag-in-Box',
      supplier: 'imkereiausruester.ch',
      price: 'CHF 27.20',
      url: 'https://www.imkereiausruester.ch',
      pros: ['Fertig invertiert, sofort einsatzbereit', 'Bienengerechter pH-Wert', 'Bag-in-Box praktisch', 'Lange haltbar'],
      cons: ['Schwer zu transportieren (Arosa!)'],
      isRecommended: true,
    ),
    ProductAlternative(
      name: 'Zucker selbst mischen (3:2)',
      supplier: 'Migros/Coop',
      price: 'CHF ~15.00/16kg',
      url: null,
      pros: ['Am günstigsten', 'Überall erhältlich', 'Keine Lieferung nötig'],
      cons: ['Mischaufwand', 'Nicht invertiert (Bienen müssen mehr arbeiten)', 'Kann gären', 'Hygiene beachten'],
    ),
    ProductAlternative(
      name: 'BioSyrup (Bio-Futterlösung)',
      supplier: 'Andermatt BioVet',
      price: 'CHF 42.00/14kg',
      url: 'https://www.biovet.ch',
      pros: ['Bio-zertifiziert', 'Für Bio-Imkerei zugelassen', 'Enthält Spurenelemente'],
      cons: ['Deutlich teurer', 'Nur nötig bei Bio-Zertifizierung'],
    ),
  ],

  'Einlöttrafo BPS Basic': [
    ProductAlternative(
      name: 'BPS Basic Einlöttrafo',
      supplier: 'imkereiausruester.ch',
      price: 'CHF 59.80',
      url: 'https://www.imkereiausruester.ch',
      pros: ['Timer-Funktion', 'Spannung einstellbar 12-19V', 'Klemmen im Set', 'Bewährt'],
      cons: ['Braucht Steckdose'],
      isRecommended: true,
    ),
    ProductAlternative(
      name: 'Akku-Einlötgerät (12V)',
      supplier: 'beetec',
      price: 'CHF 89.00',
      url: 'https://www.beetec.ch',
      pros: ['Mobil einsetzbar (kein Strom nötig!)', 'Ideal für Arosa/Maiensäss', 'Kompakt'],
      cons: ['Teurer', 'Akku muss geladen werden', 'Weniger Leistung bei vielen Rähmchen'],
    ),
  ],

  'Refraktometer': [
    ProductAlternative(
      name: 'Refraktometer Honig (Imker-Standard)',
      supplier: 'Wespi',
      price: 'CHF 69.00',
      url: 'https://www.wespi-imkerei.ch',
      pros: ['Temperaturkompensiert', 'Skala 12-27%', 'Kalibrierflüssigkeit dabei', 'Einfache Ablesung'],
      cons: ['Manuelle Messung'],
      isRecommended: true,
    ),
    ProductAlternative(
      name: 'Digitales Refraktometer',
      supplier: 'bienen-meier.ch',
      price: 'CHF 280.00',
      url: 'https://www.bienen-meier.ch',
      pros: ['Digitale Anzeige (keine Ablesefehler)', 'Höhere Genauigkeit', 'Schneller'],
      cons: ['4x teurer', 'Batterie nötig', 'Für Hobby-Imker überdimensioniert'],
    ),
  ],

  'Beutenständer Metall': [
    ProductAlternative(
      name: 'Beutenständer Metall verzinkt',
      supplier: 'FAIE.ch',
      price: 'CHF 125.00',
      url: 'https://www.faie.ch',
      pros: ['Robust, wetterfest', 'Höhenverstellbar', 'Kippsicher'],
      cons: ['Schwer', 'Teurer als Holz'],
      isRecommended: true,
    ),
    ProductAlternative(
      name: 'Beutenständer Holz (Eigenbau)',
      supplier: 'Baumarkt',
      price: 'CHF 30-50.00',
      url: null,
      pros: ['Günstig', 'Individuell anpassbar', 'Natürlich'],
      cons: ['Verwittert (Arosa!)', 'Muss behandelt werden', 'Weniger stabil'],
    ),
    ProductAlternative(
      name: 'Betonblöcke / Europalette',
      supplier: 'Baumarkt',
      price: 'CHF 10-20.00',
      url: null,
      pros: ['Sehr günstig', 'Schnell aufgebaut', 'Stabil'],
      cons: ['Optisch weniger schön', 'Schwer transportierbar', 'Nicht höhenverstellbar'],
    ),
  ],

  'Imkerhandschuhe Leder': [
    ProductAlternative(
      name: 'Imkerhandschuhe Schafleder mit Stulpe',
      supplier: 'imkereiausruester.ch',
      price: 'CHF 17.60',
      url: 'https://www.imkereiausruester.ch',
      pros: ['Guter Stichschutz', 'Geschmeidig', 'Lange Stulpe schützt Unterarme'],
      cons: ['Eingeschränktes Tastgefühl', 'Werden steif wenn nass'],
      isRecommended: true,
    ),
    ProductAlternative(
      name: 'Nitril-Einmalhandschuhe',
      supplier: 'Apotheke/Migros',
      price: 'CHF 12.00 (100 Stk)',
      url: null,
      pros: ['Bestes Tastgefühl', 'Hygienisch (Einweg)', 'Sehr günstig', 'Profis arbeiten so'],
      cons: ['Kein Stichschutz (!)', 'Nur für erfahrene Imker', 'Nicht für Anfänger empfohlen'],
    ),
    ProductAlternative(
      name: 'Ziegenleder-Handschuhe (dünn)',
      supplier: 'bienen-meier.ch',
      price: 'CHF 28.00',
      url: 'https://www.bienen-meier.ch',
      pros: ['Besseres Tastgefühl als Schaf', 'Guter Kompromiss Schutz/Gefühl', 'Waschbar'],
      cons: ['Teurer', 'Etwas weniger stichsicher'],
    ),
  ],
};
