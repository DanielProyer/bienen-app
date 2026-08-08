// Auswahl des Service-Keys — reine Funktion, damit ohne Netz testbar.
//
// WARUM: Supabase stellt Edge Functions den privilegierten Key je nach
// Projekt-Zustand unter ZWEI verschiedenen Namen bereit:
//   - Legacy-Keys aktiv  -> `SUPABASE_SERVICE_ROLE_KEY` (der JWT)
//   - moderne Keys       -> `SUPABASE_SECRET_KEYS` als JSON-OBJEKT,
//                           der uebliche Eintrag heisst "default"
// Werden die Legacy-Keys deaktiviert (weil ein service_role-JWT exponiert
// wurde), verschwindet die erste Variable bzw. wird wertlos. Diese Funktion
// bevorzugt deshalb den modernen Key und faellt auf den Legacy zurueck —
// damit laeuft die Function VOR und NACH der Umstellung, ohne zweiten Deploy
// im heiklen Moment.

/**
 * Waehlt den Service-Key.
 * @param secretKeysJson Inhalt von SUPABASE_SECRET_KEYS (JSON-Objekt) oder undefined
 * @param legacy Inhalt von SUPABASE_SERVICE_ROLE_KEY oder undefined
 * @returns der zu verwendende Key, oder '' wenn keiner brauchbar ist
 */
export function waehleServiceKey(
  secretKeysJson: string | undefined | null,
  legacy: string | undefined | null,
): string {
  if (secretKeysJson && secretKeysJson.trim().length > 0) {
    try {
      const o = JSON.parse(secretKeysJson) as Record<string, unknown>;
      // "default" ist der Regelfall; sonst der erste brauchbare Eintrag,
      // damit ein abweichend benannter Key nicht zum Totalausfall fuehrt.
      const kandidat = o['default'] ?? Object.values(o).find((v) => typeof v === 'string' && v);
      if (typeof kandidat === 'string' && kandidat.length > 0) return kandidat;
    } catch {
      // Kein JSON -> Legacy versuchen. Lieber der alte Weg als gar keiner.
    }
  }
  return legacy && legacy.trim().length > 0 ? legacy : '';
}
