// Reine Funktionen des taeglichen Ueberblicks — ohne Netz, ohne Supabase,
// damit Zeitzonen- und Textlogik offline testbar bleibt.

export interface Aufgabe {
  titel: string;
  faellig_am: string; // YYYY-MM-DD
  volk_name?: string | null;
}

/** Lokales Datum + Stunde in der gegebenen Zeitzone (DST-fest). */
export function lokalDatumStunde(
  jetzt: Date,
  zeitzone: string,
): { datum: string; stunde: number } {
  const teile = new Intl.DateTimeFormat('en-CA', {
    timeZone: zeitzone,
    year: 'numeric', month: '2-digit', day: '2-digit',
    hour: '2-digit', hour12: false,
  }).formatToParts(jetzt);
  const hol = (t: string) => teile.find((p) => p.type === t)!.value;
  return {
    datum: `${hol('year')}-${hol('month')}-${hol('day')}`,
    stunde: Number(hol('hour')) % 24, // manche Runtimes liefern "24" statt "00"
  };
}

/** Jetzt senden? Nur zur eingestellten Stunde und hoechstens einmal je lokalem Tag. */
export function istSendezeit(
  jetzt: Date,
  zeitzone: string,
  sendeStunde: number,
  zuletztGesendetAm: string | null,
): boolean {
  const { datum, stunde } = lokalDatumStunde(jetzt, zeitzone);
  if (stunde !== sendeStunde) return false;
  return zuletztGesendetAm !== datum;
}

function tageDifferenz(vonIso: string, bisIso: string): number {
  const a = Date.UTC(...(vonIso.split('-').map(Number) as [number, number, number]));
  const b = Date.UTC(...(bisIso.split('-').map(Number) as [number, number, number]));
  return Math.round((b - a) / 86400000);
}

/** Baut die Nachricht. Nichts zu tun -> null (dann wird nicht gesendet). */
export function baueNachricht(
  heute: string,
  aufgaben: Aufgabe[],
  max = 10,
): string | null {
  if (aufgaben.length === 0) return null;
  const heutige = aufgaben.filter((a) => a.faellig_am === heute);
  const ueberfaellig = aufgaben.filter((a) => a.faellig_am < heute);
  if (heutige.length === 0 && ueberfaellig.length === 0) return null;

  const gesamt = heutige.length + ueberfaellig.length;
  let rest = max;
  const zeile = (a: Aufgabe, tage?: number) =>
    `• ${a.titel}${a.volk_name ? ` · ${a.volk_name}` : ''}` +
    (tage ? ` (seit ${tage} Tag${tage === 1 ? '' : 'en'})` : '');

  const teile: string[] = [`🐝 ${heute}`];
  if (heutige.length > 0) {
    const zeigen = heutige.slice(0, rest);
    rest -= zeigen.length;
    teile.push('', 'Heute fällig', ...zeigen.map((a) => zeile(a)));
  }
  if (ueberfaellig.length > 0 && rest > 0) {
    const zeigen = ueberfaellig.slice(0, rest);
    rest -= zeigen.length;
    teile.push('', 'Überfällig',
      ...zeigen.map((a) => zeile(a, tageDifferenz(a.faellig_am, heute))));
  }
  const gezeigt = Math.min(gesamt, max);
  if (gesamt > gezeigt) teile.push('', `…und ${gesamt - gezeigt} weitere`);
  return teile.join('\n');
}
