/// BGD-Minimum Winterfutter = 20 kg (Mittelland). Darunter → UI-Warnung.
const kBgdWinterfutterMinimumKg = 20;
bool unterBgdMinimum(num zielKg) => zielKg < kBgdWinterfutterMinimumKg;
