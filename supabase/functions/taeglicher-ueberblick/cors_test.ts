import { assertEquals, assert } from 'https://deno.land/std@0.224.0/assert/mod.ts';
import { corsKopf, istErlaubteOrigin } from './cors.ts';

Deno.test('Produktions-Origin ist erlaubt', () => {
  assert(istErlaubteOrigin('https://danielproyer.github.io'));
});

Deno.test('localhost mit beliebigem Port ist erlaubt (flutter run waehlt den Port)', () => {
  assert(istErlaubteOrigin('http://localhost:8080'));
  assert(istErlaubteOrigin('http://localhost:52341'));
  assert(istErlaubteOrigin('http://127.0.0.1:3000'));
  assert(istErlaubteOrigin('http://localhost'));
});

Deno.test('fremde Origin ist nicht erlaubt', () => {
  assert(!istErlaubteOrigin('https://boese.example'));
  assert(!istErlaubteOrigin(null));
  assert(!istErlaubteOrigin(''));
  // Praefix-Trickserei darf nicht durchkommen
  assert(!istErlaubteOrigin('https://danielproyer.github.io.boese.example'));
  assert(!istErlaubteOrigin('http://localhost.boese.example'));
});

Deno.test('erlaubte Origin bekommt vollstaendige Kopfzeilen', () => {
  const k = corsKopf('https://danielproyer.github.io', 'authorization,apikey');
  assertEquals(k['Access-Control-Allow-Origin'], 'https://danielproyer.github.io');
  assertEquals(k['Access-Control-Allow-Headers'], 'authorization,apikey');
  assertEquals(k['Access-Control-Allow-Methods'], 'POST, OPTIONS');
  assertEquals(k['Vary'], 'Origin');
});

Deno.test('ohne angefragte Header greift der Rueckfall', () => {
  const k = corsKopf('https://danielproyer.github.io', null);
  assert(k['Access-Control-Allow-Headers'].includes('authorization'));
  assert(k['Access-Control-Allow-Headers'].includes('x-client-info'));
});

Deno.test('fremde Origin bekommt gar keine Freigabe', () => {
  assertEquals(corsKopf('https://boese.example', 'authorization'), {});
});

Deno.test('Cron ohne Origin braucht kein CORS', () => {
  assertEquals(corsKopf(null), {});
});
