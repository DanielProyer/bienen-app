// Supabase Edge Function: taeglicher-ueberblick
// Zwei Eingaenge:
//   1) Cron  -> Header x-cron-secret == CRON_SHARED_SECRET -> Versand an ALLE faelligen Mitglieder
//   2) App   -> Authorization: Bearer <JWT des Nutzers>    -> NUR Testnachricht an die eigene Zeile
// Deploy: supabase functions deploy taeglicher-ueberblick
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2';
import { baueNachricht, istSendezeit, lokalDatumStunde, type Aufgabe } from './nachricht.ts';
import { corsKopf } from './cors.ts';

const SUPABASE_URL = Deno.env.get('SUPABASE_URL')!;
const SERVICE_KEY = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!;
const BOT_TOKEN = Deno.env.get('TELEGRAM_BOT_TOKEN')!;
const CRON_SECRET = Deno.env.get('CRON_SHARED_SECRET')!;
const APP_URL = 'https://danielproyer.github.io/bienen-app/';

const admin = createClient(SUPABASE_URL, SERVICE_KEY);

interface Einstellung {
  id: string; betrieb_id: string; user_id: string;
  telegram_chat_id: string | null; aktiv: boolean;
  sende_stunde: number; zeitzone: string; zuletzt_gesendet_am: string | null;
}

/** Telegram-Versand. Gibt 'ok' | 'blockiert' | 'fehler' zurueck. */
async function sendeTelegram(chatId: string, text: string): Promise<'ok' | 'blockiert' | 'fehler'> {
  const r = await fetch(`https://api.telegram.org/bot${BOT_TOKEN}/sendMessage`, {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify({ chat_id: chatId, text, disable_web_page_preview: true }),
  });
  if (r.ok) return 'ok';
  if (r.status === 403) return 'blockiert'; // Bot vom Nutzer blockiert
  console.error(`Telegram ${r.status}: ${await r.text()}`);
  return 'fehler';
}

/** Offene Aufgaben des Betriebs bis einschliesslich heute (lokales Datum). */
async function offeneAufgaben(betriebId: string, heute: string): Promise<Aufgabe[]> {
  const { data, error } = await admin
    .from('aufgaben')
    .select('titel, faellig_am, volk_id, voelker(name)')
    .eq('betrieb_id', betriebId)
    .eq('status', 'offen')          // verifiziert: offen|erledigt|uebersprungen
    .lte('faellig_am', heute)
    .order('faellig_am', { ascending: true });
  if (error) throw error;
  return (data ?? []).map((r: Record<string, unknown>) => ({
    titel: r.titel as string,
    faellig_am: r.faellig_am as string,
    volk_name: (r.voelker as { name?: string } | null)?.name ?? null,
  }));
}

/** Ein Mitglied bedienen. Wirft nicht — ein Fehler darf die anderen nicht stoppen. */
async function bediene(e: Einstellung, jetzt: Date, test: boolean): Promise<string> {
  if (!e.aktiv && !test) return 'inaktiv';
  if (!e.telegram_chat_id) return 'keine-chat-id';

  const { datum: heute } = lokalDatumStunde(jetzt, e.zeitzone);
  if (!test && !istSendezeit(jetzt, e.zeitzone, e.sende_stunde, e.zuletzt_gesendet_am)) {
    return 'nicht-faellig';
  }

  const aufgaben = await offeneAufgaben(e.betrieb_id, heute);
  const text = test
    ? `🐝 Testnachricht — die Verknüpfung funktioniert.\n\n` +
      (baueNachricht(heute, aufgaben) ?? 'Aktuell steht nichts an.')
    : baueNachricht(heute, aufgaben);

  if (text === null) {
    // Nichts zu tun: Tag trotzdem als erledigt markieren, sonst prueft
    // jede Stunde erneut. Stille IST die Aussage.
    await admin.from('benachrichtigungs_einstellungen')
      .update({ zuletzt_gesendet_am: heute }).eq('id', e.id);
    return 'nichts-zu-tun';
  }

  const ergebnis = await sendeTelegram(e.telegram_chat_id, `${text}\n\n→ ${APP_URL}`);
  if (ergebnis === 'blockiert') {
    await admin.from('benachrichtigungs_einstellungen')
      .update({ aktiv: false }).eq('id', e.id);
    return 'blockiert-deaktiviert';
  }
  if (ergebnis === 'fehler') return 'fehler'; // zuletzt_gesendet_am BLEIBT -> naechste Stunde erneut
  if (!test) {
    await admin.from('benachrichtigungs_einstellungen')
      .update({ zuletzt_gesendet_am: heute }).eq('id', e.id);
  }
  return 'gesendet';
}

Deno.serve(async (req) => {
  const jetzt = new Date();
  const cronSecret = req.headers.get('x-cron-secret');

  // CORS: der Browser verlangt die Freigabe auf JEDER Antwort, nicht nur auf
  // dem Preflight. Fehlt sie auf der echten Antwort, verwirft er sie ebenso.
  const cors = corsKopf(
    req.headers.get('Origin'),
    req.headers.get('Access-Control-Request-Headers'),
  );
  const text = (koerper: string, status: number) =>
    new Response(koerper, { status, headers: cors });
  const json = (koerper: unknown) =>
    new Response(JSON.stringify(koerper), {
      headers: { ...cors, 'Content-Type': 'application/json' },
    });

  // ── Preflight ──
  if (req.method === 'OPTIONS') return new Response(null, { status: 204, headers: cors });

  // ── Eingang 1: Cron (Massenversand) ──
  if (cronSecret && CRON_SECRET && cronSecret === CRON_SECRET) {
    const { data, error } = await admin
      .from('benachrichtigungs_einstellungen').select('*').eq('aktiv', true);
    if (error) return text(`DB-Fehler: ${error.message}`, 500);
    const bericht: Record<string, string> = {};
    for (const e of (data ?? []) as Einstellung[]) {
      try {
        bericht[e.user_id] = await bediene(e, jetzt, false);
      } catch (err) {
        bericht[e.user_id] = `fehler: ${err}`; // einer scheitert != Abbruch
      }
    }
    return json({ modus: 'cron', bericht });
  }

  // ── Eingang 2: Eingeloggter Nutzer (nur Testnachricht an sich selbst) ──
  const auth = req.headers.get('Authorization') ?? '';
  const jwt = auth.startsWith('Bearer ') ? auth.slice(7) : '';
  if (!jwt) return text('Nicht berechtigt', 401);
  const { data: userData, error: userErr } = await admin.auth.getUser(jwt);
  if (userErr || !userData.user) return text('Nicht berechtigt', 401);

  const { data, error } = await admin
    .from('benachrichtigungs_einstellungen').select('*')
    .eq('user_id', userData.user.id).maybeSingle();
  if (error) return text(`DB-Fehler: ${error.message}`, 500);
  if (!data) return text('Keine Einstellungen gefunden', 404);

  try {
    const status = await bediene(data as Einstellung, jetzt, true);
    if (status === 'gesendet') {
      await admin.from('benachrichtigungs_einstellungen')
        .update({ aktiv: true }).eq('id', (data as Einstellung).id);
    }
    return json({ modus: 'test', status });
  } catch (err) {
    return text(`Fehler: ${err}`, 500);
  }
});
