/// Physische Futterform (DB-CHECK-Whitelist, Sync mit I02 + RPC F02). Bio-Status separat.
class Futterart {
  static const werte = <String>[
    'zuckerwasser_1_1', 'zuckerwasser_3_2', 'invertsirup', 'futterteig', 'futterwaben', 'honig', 'sonstige',
  ];
  static const labels = <String, String>{
    'zuckerwasser_1_1': 'Zuckerwasser 1:1 (anfüttern)',
    'zuckerwasser_3_2': 'Zuckerwasser 3:2 (Winterfutter)',
    'invertsirup': 'Invertsirup (Apiinvert)',
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
