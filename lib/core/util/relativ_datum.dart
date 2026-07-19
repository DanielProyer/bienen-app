/// Relative Tages-Angabe fürs Cockpit („gesehen: heute/gestern/vor N Tagen").
/// DST-sicher via UTC-Tagesdifferenz (Gotcha 14). Zukunftsdaten → 'heute'.
String relativGesehen(DateTime? datum, DateTime stichtag) {
  if (datum == null) return 'noch nie';
  final diff = DateTime.utc(stichtag.year, stichtag.month, stichtag.day)
      .difference(DateTime.utc(datum.year, datum.month, datum.day))
      .inDays;
  if (diff <= 0) return 'heute';
  if (diff == 1) return 'gestern';
  return 'vor $diff Tagen';
}
