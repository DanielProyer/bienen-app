import { assertEquals } from 'https://deno.land/std@0.224.0/assert/mod.ts';
import { baueNachricht, lokalDatumStunde, istSendezeit } from './nachricht.ts';

Deno.test('lokalDatumStunde: Sommerzeit Zuerich = UTC+2', () => {
  const r = lokalDatumStunde(new Date('2026-07-23T04:30:00Z'), 'Europe/Zurich');
  assertEquals(r, { datum: '2026-07-23', stunde: 6 });
});

Deno.test('lokalDatumStunde: Winterzeit Zuerich = UTC+1', () => {
  const r = lokalDatumStunde(new Date('2026-01-15T05:30:00Z'), 'Europe/Zurich');
  assertEquals(r, { datum: '2026-01-15', stunde: 6 });
});

Deno.test('istSendezeit: nur zur eingestellten Stunde', () => {
  const jetzt = new Date('2026-07-23T04:30:00Z'); // 06:xx lokal
  assertEquals(istSendezeit(jetzt, 'Europe/Zurich', 6, null), true);
  assertEquals(istSendezeit(jetzt, 'Europe/Zurich', 7, null), false);
});

Deno.test('istSendezeit: heute schon gesendet -> nein', () => {
  const jetzt = new Date('2026-07-23T04:30:00Z');
  assertEquals(istSendezeit(jetzt, 'Europe/Zurich', 6, '2026-07-23'), false);
  assertEquals(istSendezeit(jetzt, 'Europe/Zurich', 6, '2026-07-22'), true);
});

Deno.test('baueNachricht: heute + ueberfaellig getrennt', () => {
  const txt = baueNachricht('2026-07-23', [
    { titel: 'Schwarmkontrolle', faellig_am: '2026-07-23', volk_name: 'Volk 1' },
    { titel: 'Drohnenschnitt', faellig_am: '2026-07-20', volk_name: 'Volk 1' },
  ]);
  if (txt === null) throw new Error('erwartet: Nachricht');
  assertEquals(txt.includes('Heute fällig'), true);
  assertEquals(txt.includes('Überfällig'), true);
  assertEquals(txt.includes('Schwarmkontrolle · Volk 1'), true);
  assertEquals(txt.includes('seit 3 Tagen'), true);
});

Deno.test('baueNachricht: nichts zu tun -> null', () => {
  assertEquals(baueNachricht('2026-07-23', []), null);
});

Deno.test('baueNachricht: kuerzt ab 10 Eintraegen', () => {
  const viele = Array.from({ length: 14 }, (_, i) => ({
    titel: `Aufgabe ${i}`, faellig_am: '2026-07-23', volk_name: null,
  }));
  const txt = baueNachricht('2026-07-23', viele)!;
  assertEquals(txt.includes('…und 4 weitere'), true);
});
