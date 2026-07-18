/// Physische Futterform (DB-CHECK-Whitelist). Bio-Status separat via `bio_zertifiziert`.
class Futterart {
  static const werte = <String>[
    'zuckersirup', 'zuckerwasser', 'futterteig', 'futterwaben', 'honig', 'sonstige',
  ];
  static const labels = <String, String>{
    'zuckersirup': 'Zuckersirup',
    'zuckerwasser': 'Zuckerwasser (Sirup selbst)',
    'futterteig': 'Futterteig',
    'futterwaben': 'Futterwaben',
    'honig': 'Honig',
    'sonstige': 'Sonstige',
  };
}

/// Fütterungszweck. Nur `auffuetterung` zählt fürs Winterfutter-Ziel.
class Zweck {
  static const werte = <String>['auffuetterung', 'reizfuetterung', 'notfuetterung'];
  static const labels = <String, String>{
    'auffuetterung': 'Auffütterung',
    'reizfuetterung': 'Reizfütterung',
    'notfuetterung': 'Notfütterung',
  };
}
