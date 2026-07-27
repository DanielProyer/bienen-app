import { assertEquals } from 'https://deno.land/std@0.224.0/assert/mod.ts';
import { waehleServiceKey } from './schluessel.ts';

Deno.test('moderner Key aus SUPABASE_SECRET_KEYS wird bevorzugt', () => {
  assertEquals(
    waehleServiceKey('{"default":"sb_secret_neu"}', 'eyJ_legacy'),
    'sb_secret_neu',
  );
});

Deno.test('ohne modernen Key greift der Legacy-Fallback', () => {
  assertEquals(waehleServiceKey(undefined, 'eyJ_legacy'), 'eyJ_legacy');
  assertEquals(waehleServiceKey(null, 'eyJ_legacy'), 'eyJ_legacy');
  assertEquals(waehleServiceKey('', 'eyJ_legacy'), 'eyJ_legacy');
  assertEquals(waehleServiceKey('   ', 'eyJ_legacy'), 'eyJ_legacy');
});

Deno.test('kaputtes JSON darf nicht zum Totalausfall fuehren', () => {
  assertEquals(waehleServiceKey('{nicht json', 'eyJ_legacy'), 'eyJ_legacy');
});

Deno.test('abweichend benannter Eintrag wird genutzt, wenn default fehlt', () => {
  assertEquals(waehleServiceKey('{"backup":"sb_secret_x"}', null), 'sb_secret_x');
});

Deno.test('default gewinnt gegen andere Eintraege', () => {
  assertEquals(
    waehleServiceKey('{"anderer":"sb_secret_x","default":"sb_secret_d"}', null),
    'sb_secret_d',
  );
});

Deno.test('leeres JSON-Objekt faellt auf Legacy zurueck', () => {
  assertEquals(waehleServiceKey('{}', 'eyJ_legacy'), 'eyJ_legacy');
});

Deno.test('gar kein Key -> leerer String (Aufrufer kann pruefen)', () => {
  assertEquals(waehleServiceKey(undefined, undefined), '');
  assertEquals(waehleServiceKey('{}', ''), '');
});
