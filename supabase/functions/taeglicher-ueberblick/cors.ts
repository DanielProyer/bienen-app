// CORS-Kopfzeilen — reine Funktion, damit ohne Netz testbar.
//
// WARUM: Die App ruft die Function per `supabase.functions.invoke()` auf. Der
// Client schickt dabei `authorization`, `apikey`, `x-client-info` und
// `content-type`. Sobald ein Request eigene Header traegt, stellt der Browser
// ihm einen **Preflight** (OPTIONS) voran und verlangt CORS-Freigaben — auf
// die eigentliche Antwort UND auf den Preflight. Fehlen sie, bricht der
// Browser ab, bevor die Function ueberhaupt antwortet; in Flutter Web
// erscheint das als `ClientException: Failed to fetch`.
//
// Ein Test mit Node/curl faellt darauf NICHT herein — CORS ist eine reine
// Browser-Regel. Deshalb hier ein eigener Test statt eines Smoke-Tests.
//
// Whitelist statt `*`: Fuer eine reine Bearer-Token-API waere `*` vertretbar
// (eine fremde Seite kaeme nicht an das JWT im localStorage der App-Origin),
// aber eine Freigabe, die niemand braucht, wird nicht erteilt. Lokale
// Entwicklung laeuft auf wechselnden Ports, daher ein Muster fuer localhost.

const PROD_ORIGIN = 'https://danielproyer.github.io';
const LOKAL = /^http:\/\/(localhost|127\.0\.0\.1)(:\d+)?$/;

export function istErlaubteOrigin(origin: string | null): boolean {
  if (!origin) return false;
  return origin === PROD_ORIGIN || LOKAL.test(origin);
}

/**
 * CORS-Kopfzeilen fuer eine Anfrage. Leeres Objekt = keine Freigabe
 * (unbekannte Origin, oder serverseitiger Aufruf ohne Origin wie der Cron —
 * der braucht kein CORS).
 */
export function corsKopf(
  origin: string | null,
  angefragteHeader?: string | null,
): Record<string, string> {
  if (!istErlaubteOrigin(origin)) return {};
  return {
    'Access-Control-Allow-Origin': origin!,
    // Die angefragten Header spiegeln, damit ein zusaetzlicher Client-Header
    // nicht wieder alles blockiert; Rueckfall auf die bekannten Namen.
    'Access-Control-Allow-Headers':
      angefragteHeader && angefragteHeader.trim().length > 0
        ? angefragteHeader
        : 'authorization, apikey, content-type, x-client-info',
    'Access-Control-Allow-Methods': 'POST, OPTIONS',
    'Access-Control-Max-Age': '86400',
    // Ohne Vary koennte ein Cache die Freigabe einer Origin an eine andere
    // ausliefern.
    Vary: 'Origin',
  };
}
