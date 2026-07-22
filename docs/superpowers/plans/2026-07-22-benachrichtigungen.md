# F3 Benachrichtigungen — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: superpowers:subagent-driven-development. Steps use `- [ ]` checkboxes.

**Goal:** Ein täglicher Telegram-Überblick am Morgen mit den heute fälligen und den überfälligen Aufgaben — je Mitglied konfigurierbar, zeitzonenfest, ohne Doppelversand.

**Architecture:** `pg_cron` weckt stündlich einen Job, der per `pg_net` die Edge Function `taeglicher-ueberblick` aufruft. Die Function entscheidet je Mitglied anhand von Zeitzone, Sendestunde und `zuletzt_gesendet_am`, ob jetzt gesendet wird, baut den Text und schickt ihn an die Telegram Bot API. Die App verwaltet die persönlichen Einstellungen und bietet eine Testnachricht.

**Tech Stack:** Postgres (pg_cron, pg_net, Vault), Supabase Edge Function (Deno/TypeScript), Flutter Web + Riverpod + Baukasten-Widgets.

**Spec:** `docs/superpowers/specs/2026-07-22-benachrichtigungen-design.md`

---

## Dateistruktur
**Neu:** `supabase/migrations/O01_benachrichtigungen.sql` · `supabase/functions/taeglicher-ueberblick/{index.ts,nachricht.ts,nachricht_test.ts}` · `lib/features/benachrichtigungen/{domain/benachrichtigungs_einstellungen.dart,data/benachrichtigungen_gateway.dart,presentation/{providers/benachrichtigungen_provider.dart,pages/benachrichtigungen_page.dart}}` · `test/benachrichtigungen/einstellungen_test.dart`
**Geändert:** `lib/core/router/app_router.dart` · `lib/features/auth/presentation/konto_page.dart` (Einstieg)

**Verifizierte Grundlagen** (nicht erneut annehmen): `aufgaben.status ∈ ('offen','erledigt','uebersprungen')` — der Filter ist `status='offen'`; Spalten `titel`, `faellig_am`, `volk_id`, `prioritaet ∈ ('hoch','normal','niedrig')`. RLS-Helfer `private.current_app_user()`, `private.ist_mitglied(uuid)` existieren. Edge-Function-Muster: `supabase/functions/sync-scale-data/index.ts` (Deno, `esm.sh/@supabase/supabase-js@2`, Env `SUPABASE_URL`/`SUPABASE_SERVICE_ROLE_KEY`).

---

## Task 1: Migration O01 (Produktion) — Controller, braucht Freigabe

**Files:** Create `supabase/migrations/O01_benachrichtigungen.sql`

- [ ] **Step 1: Trigger-Funktionsnamen verifizieren** (nicht raten):
```sql
select p.proname from pg_proc p join pg_namespace n on n.oid=p.pronamespace
where n.nspname='private' and p.proname like 'set_%';
```
Die gefundenen Namen in Step 2 einsetzen (erwartet `set_row_actor`, ggf. zusätzlich `set_updated_at`; existiert kein `set_updated_at`, den entsprechenden Trigger weglassen).

- [ ] **Step 2: File schreiben**
```sql
-- O01_benachrichtigungen.sql | F3: taeglicher Ueberblick via Telegram.
-- Aktiviert erstmals pg_cron + pg_net auf dieser DB.
create extension if not exists pg_cron;
create extension if not exists pg_net;

create table if not exists public.benachrichtigungs_einstellungen (
  id uuid primary key default gen_random_uuid(),
  betrieb_id uuid not null default private.aktive_betrieb_id()
    references public.betriebe(id) on delete cascade,
  user_id uuid not null,
  kanal text not null default 'telegram' check (kanal in ('telegram')),
  telegram_chat_id text,
  aktiv boolean not null default false,
  sende_stunde smallint not null default 6 check (sende_stunde between 0 and 23),
  zeitzone text not null default 'Europe/Zurich',
  zuletzt_gesendet_am date,
  created_by uuid,
  updated_by uuid,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (betrieb_id, user_id)
);

alter table public.benachrichtigungs_einstellungen enable row level security;

-- ABWEICHUNG vom Hausmuster ("Mitglied sieht alles"): eine Chat-ID ist
-- personenbezogen. Nur die EIGENE Zeile ist les- und schreibbar.
create policy ben_select_eigene on public.benachrichtigungs_einstellungen
  for select to authenticated
  using (user_id = private.current_app_user() and private.ist_mitglied(betrieb_id));
create policy ben_insert_eigene on public.benachrichtigungs_einstellungen
  for insert to authenticated
  with check (user_id = private.current_app_user() and private.ist_mitglied(betrieb_id));
create policy ben_update_eigene on public.benachrichtigungs_einstellungen
  for update to authenticated
  using (user_id = private.current_app_user() and private.ist_mitglied(betrieb_id))
  with check (user_id = private.current_app_user() and private.ist_mitglied(betrieb_id));
-- Bewusst KEINE delete-policy: Einstellungen werden deaktiviert, nicht geloescht.

create trigger benachrichtigungen_row_actor
  before insert or update on public.benachrichtigungs_einstellungen
  for each row execute function private.set_row_actor();

-- Stuendlicher Wecker. Die Function entscheidet, ob JETZT gesendet wird
-- (Zeitzone + sende_stunde + zuletzt_gesendet_am) — ein fester UTC-Termin
-- wuerde durch Sommer-/Winterzeit zweimal jaehrlich um eine Stunde verrutschen.
select cron.schedule('ueberblick-stuendlich', '5 * * * *', $cron$
  select net.http_post(
    url := 'https://dcdcohktxbhdxnxjvcyp.supabase.co/functions/v1/taeglicher-ueberblick',
    headers := jsonb_build_object(
      'Content-Type', 'application/json',
      'x-cron-secret', coalesce(
        (select decrypted_secret from vault.decrypted_secrets where name = 'cron_shared_secret'), '')
    ),
    body := '{}'::jsonb
  );
$cron$);

-- ROLLBACK: select cron.unschedule('ueberblick-stuendlich');
--           drop table public.benachrichtigungs_einstellungen;
--           (Extensions pg_cron/pg_net bewusst NICHT zurueckdrehen.)
```
- [ ] **Step 3: Anwenden** via Supabase-MCP `apply_migration` (Name `O01_benachrichtigungen`, Projekt `dcdcohktxbhdxnxjvcyp`) — **erst nach Daniels Freigabe**.
- [ ] **Step 4: Verifizieren** via `execute_sql`:
  - `select extname from pg_extension where extname in ('pg_cron','pg_net');` → beide da
  - `select jobname, schedule from cron.job;` → `ueberblick-stuendlich`, `5 * * * *`
  - `select count(*) from public.benachrichtigungs_einstellungen;` → 0
  - RLS-Probe: `select polname, cmd from pg_policies where tablename='benachrichtigungs_einstellungen';` → 3 Policies, **kein** DELETE
  - `get_advisors(security)` + `(performance)` → **0 neue** Findings
- [ ] **Step 5: Commit** `feat(benachrichtigungen): O01 Migration (pg_cron/pg_net, Einstellungen, RLS, Stunden-Job)`

---

## Task 2: Reine Funktionen der Edge Function (TDD)

**Files:** Create `supabase/functions/taeglicher-ueberblick/nachricht.ts` · Test `supabase/functions/taeglicher-ueberblick/nachricht_test.ts`

> Deno-Tests, offline, ohne Netz. Ausführen: `cd /d/Projekte/Bienen/bienen_app/supabase/functions/taeglicher-ueberblick && deno test`. Ist Deno nicht installiert, den Task als BLOCKED melden (nicht ungetestet weiterbauen).

- [ ] **Step 1: Failing test** `nachricht_test.ts`
```ts
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
```
- [ ] **Step 2:** `deno test` → FAIL (Modul fehlt).
- [ ] **Step 3: Implement** `nachricht.ts`
```ts
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
```
- [ ] **Step 4:** `deno test` → alle grün.
- [ ] **Step 5: Commit** `feat(benachrichtigungen): reine Textbau- und Zeitzonen-Logik (Deno-Tests)`

---

## Task 3: Edge Function `taeglicher-ueberblick`

**Files:** Create `supabase/functions/taeglicher-ueberblick/index.ts`

- [ ] **Step 1: Implement**
```ts
// Supabase Edge Function: taeglicher-ueberblick
// Zwei Eingaenge:
//   1) Cron  -> Header x-cron-secret == CRON_SHARED_SECRET -> Versand an ALLE faelligen Mitglieder
//   2) App   -> Authorization: Bearer <JWT des Nutzers>    -> NUR Testnachricht an die eigene Zeile
// Deploy: supabase functions deploy taeglicher-ueberblick
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2';
import { baueNachricht, istSendezeit, lokalDatumStunde, type Aufgabe } from './nachricht.ts';

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

  // ── Eingang 1: Cron (Massenversand) ──
  if (cronSecret && CRON_SECRET && cronSecret === CRON_SECRET) {
    const { data, error } = await admin
      .from('benachrichtigungs_einstellungen').select('*').eq('aktiv', true);
    if (error) return new Response(`DB-Fehler: ${error.message}`, { status: 500 });
    const bericht: Record<string, string> = {};
    for (const e of (data ?? []) as Einstellung[]) {
      try {
        bericht[e.user_id] = await bediene(e, jetzt, false);
      } catch (err) {
        bericht[e.user_id] = `fehler: ${err}`; // einer scheitert != Abbruch
      }
    }
    return Response.json({ modus: 'cron', bericht });
  }

  // ── Eingang 2: Eingeloggter Nutzer (nur Testnachricht an sich selbst) ──
  const auth = req.headers.get('Authorization') ?? '';
  const jwt = auth.startsWith('Bearer ') ? auth.slice(7) : '';
  if (!jwt) return new Response('Nicht berechtigt', { status: 401 });
  const { data: userData, error: userErr } = await admin.auth.getUser(jwt);
  if (userErr || !userData.user) return new Response('Nicht berechtigt', { status: 401 });

  const { data, error } = await admin
    .from('benachrichtigungs_einstellungen').select('*')
    .eq('user_id', userData.user.id).maybeSingle();
  if (error) return new Response(`DB-Fehler: ${error.message}`, { status: 500 });
  if (!data) return new Response('Keine Einstellungen gefunden', { status: 404 });

  try {
    const status = await bediene(data as Einstellung, jetzt, true);
    if (status === 'gesendet') {
      await admin.from('benachrichtigungs_einstellungen')
        .update({ aktiv: true }).eq('id', (data as Einstellung).id);
    }
    return Response.json({ modus: 'test', status });
  } catch (err) {
    return new Response(`Fehler: ${err}`, { status: 500 });
  }
});
```
- [ ] **Step 2: Deployen** — `supabase functions deploy taeglicher-ueberblick` (setzt eine verknüpfte Supabase-CLI voraus). Ist die CLI nicht eingerichtet, diesen Schritt als **offen an Daniel** melden und im Abschluss-Bericht nennen; der Code ist dann trotzdem committet.
- [ ] **Step 3: Commit** `feat(benachrichtigungen): Edge Function taeglicher-ueberblick (Cron + Testnachricht)`

---

## Task 4: App — Modell, Gateway, Provider (TDD)

**Files:** Create `lib/features/benachrichtigungen/domain/benachrichtigungs_einstellungen.dart`, `lib/features/benachrichtigungen/data/benachrichtigungen_gateway.dart`, `lib/features/benachrichtigungen/presentation/providers/benachrichtigungen_provider.dart` · Test `test/benachrichtigungen/einstellungen_test.dart`

- [ ] **Step 1: Failing test**
```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:bienen_app/features/benachrichtigungen/domain/benachrichtigungs_einstellungen.dart';

void main() {
  test('fromJson/toUpdateJson round-trip', () {
    final e = BenachrichtigungsEinstellungen.fromJson(const {
      'id': 'e1', 'betrieb_id': 'b1', 'user_id': 'u1', 'kanal': 'telegram',
      'telegram_chat_id': '12345', 'aktiv': true, 'sende_stunde': 7,
      'zeitzone': 'Europe/Zurich', 'zuletzt_gesendet_am': '2026-07-22',
    });
    expect(e.telegramChatId, '12345');
    expect(e.aktiv, isTrue);
    expect(e.sendeStunde, 7);
    expect(e.zuletztGesendetAm, DateTime.utc(2026, 7, 22));
    final j = e.toUpdateJson();
    expect(j['telegram_chat_id'], '12345');
    expect(j['sende_stunde'], 7);
    expect(j.containsKey('id'), isFalse, reason: 'id wird nie geschrieben');
    expect(j.containsKey('zuletzt_gesendet_am'), isFalse,
        reason: 'setzt ausschliesslich die Edge Function');
  });

  test('leer: fail-safe Defaults', () {
    const e = BenachrichtigungsEinstellungen.leer();
    expect(e.aktiv, isFalse, reason: 'erst nach erfolgreicher Verknuepfung an');
    expect(e.sendeStunde, 6);
    expect(e.zeitzone, 'Europe/Zurich');
    expect(e.telegramChatId, isNull);
  });
}
```
- [ ] **Step 2:** `cd /d/Projekte/Bienen/bienen_app && flutter test test/benachrichtigungen/einstellungen_test.dart` → FAIL.
- [ ] **Step 3: Implement** `benachrichtigungs_einstellungen.dart`
```dart
/// Persoenliche Benachrichtigungs-Einstellungen eines Mitglieds.
/// `zuletztGesendetAm` wird NUR von der Edge Function gesetzt und daher nie
/// mitgeschrieben — sonst wuerde die App den Doppelversand-Riegel ueberschreiben.
class BenachrichtigungsEinstellungen {
  final String id;
  final String? telegramChatId;
  final bool aktiv;
  final int sendeStunde;
  final String zeitzone;
  final DateTime? zuletztGesendetAm;

  const BenachrichtigungsEinstellungen({
    required this.id,
    this.telegramChatId,
    this.aktiv = false,
    this.sendeStunde = 6,
    this.zeitzone = 'Europe/Zurich',
    this.zuletztGesendetAm,
  });

  const BenachrichtigungsEinstellungen.leer()
      : id = '', telegramChatId = null, aktiv = false,
        sendeStunde = 6, zeitzone = 'Europe/Zurich', zuletztGesendetAm = null;

  factory BenachrichtigungsEinstellungen.fromJson(Map<String, dynamic> j) =>
      BenachrichtigungsEinstellungen(
        id: j['id'] as String,
        telegramChatId: j['telegram_chat_id'] as String?,
        aktiv: (j['aktiv'] as bool?) ?? false,
        sendeStunde: (j['sende_stunde'] as num?)?.toInt() ?? 6,
        zeitzone: (j['zeitzone'] as String?) ?? 'Europe/Zurich',
        zuletztGesendetAm: j['zuletzt_gesendet_am'] != null
            ? DateTime.parse(j['zuletzt_gesendet_am'] as String)
            : null,
      );

  Map<String, dynamic> toUpdateJson() => {
        'telegram_chat_id': telegramChatId,
        'aktiv': aktiv,
        'sende_stunde': sendeStunde,
        'zeitzone': zeitzone,
      };

  BenachrichtigungsEinstellungen copyWith({
    String? telegramChatId, bool? aktiv, int? sendeStunde, String? zeitzone,
  }) =>
      BenachrichtigungsEinstellungen(
        id: id,
        telegramChatId: telegramChatId ?? this.telegramChatId,
        aktiv: aktiv ?? this.aktiv,
        sendeStunde: sendeStunde ?? this.sendeStunde,
        zeitzone: zeitzone ?? this.zeitzone,
        zuletztGesendetAm: zuletztGesendetAm,
      );
}
```
- [ ] **Step 4:** Test → PASS.
- [ ] **Step 5: Gateway** `benachrichtigungen_gateway.dart` — nutzt `SupabaseConfig.client` (Muster: `lib/features/voelker/data/supabase_voelker_gateway.dart`):
  - `Future<BenachrichtigungsEinstellungen?> laden()` — `.from('benachrichtigungs_einstellungen').select().maybeSingle()` (RLS liefert automatisch nur die eigene Zeile).
  - `Future<BenachrichtigungsEinstellungen> speichern(BenachrichtigungsEinstellungen e, String userId)` — existiert keine Zeile (`e.id.isEmpty`), `insert({...toUpdateJson(), 'user_id': userId})`, sonst `update(toUpdateJson()).eq('id', e.id)`; beide mit `.select().single()` → Rückgabe **mit id** (Lehre aus D-76).
  - `Future<void> testnachricht()` — ruft die Edge Function: `SupabaseConfig.client.functions.invoke('taeglicher-ueberblick')` (schickt das Nutzer-JWT automatisch mit); bei Fehler `Exception` mit lesbarer Meldung.
- [ ] **Step 6: Provider** `benachrichtigungen_provider.dart` — `benachrichtigungenGatewayProvider` + `AsyncNotifierProvider<BenachrichtigungenNotifier, BenachrichtigungsEinstellungen?>` mit `speichern(...)` (invalidateSelf) und `testnachricht()` (danach invalidateSelf, damit ein von der Function gesetztes `aktiv` sichtbar wird). **Wichtig:** den Provider in `AuthController._datenNeuLaden()` eintragen (Projekt-Gotcha: sonst Fremd-Mandanten-Cache nach Login-Wechsel).
- [ ] **Step 7:** `flutter analyze lib/features/benachrichtigungen test/benachrichtigungen` → 0; `flutter test` → grün.
- [ ] **Step 8: Commit** `feat(benachrichtigungen): Modell, Gateway, Provider`

---

## Task 5: Seite `/benachrichtigungen` + Einstieg

**Files:** Create `lib/features/benachrichtigungen/presentation/pages/benachrichtigungen_page.dart` · Modify `lib/core/router/app_router.dart`, `lib/features/auth/presentation/konto_page.dart`

- [ ] **Step 1: Seite** (`ConsumerStatefulWidget`, `Scaffold` + `AppBar('Benachrichtigungen')`, Baukasten `AppCard`/`SectionHeader`/`AppButton`/`StatusPill`, Tokens `BeeTokens` — kein `AppColors`, keine rohen Hex/EdgeInsets):
  - **Karte „Täglicher Überblick"**: erklärt in zwei Sätzen, dass morgens eine Telegram-Nachricht mit heute fälligen und überfälligen Aufgaben kommt — und dass **nichts** kommt, wenn nichts ansteht.
  - **Felder:** `TextField` Chat-ID (Tastatur `TextInputType.text`, Hinweis „Schreib zuerst dem Bot, hol dir die ID z. B. über @userinfobot"), `SwitchListTile` „aktiv", Sendestunde als `DropdownButtonFormField<int>` (0–23, Anzeige „06:00"), Zeitzone als `TextField` mit Default `Europe/Zurich`.
  - **`StatusPill`**: `aktiv` → `BeeSignal.erfolg` „aktiv", sonst `BeeSignal.neutral` „aus".
  - **„zuletzt gesendet: TT.MM."** (oder „noch nie") — die Gegenmaßnahme gegen die zweideutige Stille aus der Spec §7. Fehlt der Wert, deutlich als „noch nie" ausweisen.
  - **Zwei Aktionen:** `AppButton('Speichern', full: true)` und `AppButton('Testnachricht senden', kind: sekundaer, full: true, busy: _sendet)`. Die Testnachricht **erst nach dem Speichern** anbieten (sonst testet man eine noch nicht gespeicherte Chat-ID) — ist der Chat-ID-Text verändert und ungespeichert, den Test-Knopf deaktivieren und darauf hinweisen.
  - Erfolg/Fehler als SnackBar, **erst nach `await`**; `_sendet` im `finally` zurücksetzen.
- [ ] **Step 2: Route** in `app_router.dart` neben `/konto`: `GoRoute(path: '/benachrichtigungen', builder: (c, s) => const BenachrichtigungenPage()),` (Import ergänzen). In `lib/shared/widgets/app_shell.dart` `location.startsWith('/benachrichtigungen')` zur **Projekt-Gruppe (Index 3)** ergänzen — dort liegt auch `/konto`.
- [ ] **Step 3: Einstieg** in `konto_page.dart`: eine `AppCard` mit `AppListTile(titel: 'Benachrichtigungen', untertitel: 'Täglicher Überblick per Telegram', onTap: () => context.go('/benachrichtigungen'))`. Konto ist der richtige Ort — die Einstellungen sind **persönlich**, nicht betrieblich.
- [ ] **Step 4:** `flutter analyze lib test` → 0; `flutter test` → grün.
- [ ] **Step 5: Commit** `feat(benachrichtigungen): Seite /benachrichtigungen + Einstieg im Konto`

---

## Task 6: Abschluss — Version, Deploy, Übergabe

- [ ] **Step 1:** `pubspec.yaml` Version → `1.37.0+59`.
- [ ] **Step 2:** `cd /d/Projekte/Bienen/bienen_app && flutter analyze` (0) und `flutter test` (alle grün).
- [ ] **Step 3: Deploy** `bash deploy.sh` (bei DNS-Fehler erneut).
- [ ] **Step 4: Commit** `chore(benachrichtigungen): v1.37.0 täglicher Überblick`
- [ ] **Step 5: Übergabe an Daniel** (wortgleich weitergeben):
  1. **@BotFather** → `/revoke` für den im Chat geteilten Token → **neuen** Token holen.
  2. Supabase → Edge Functions → Secrets: `TELEGRAM_BOT_TOKEN` (neuer Token) und `CRON_SHARED_SECRET` (selbst erzeugt, z. B. `openssl rand -hex 32`).
  3. Denselben Wert als Vault-Secret ablegen, damit der Cron ihn mitschickt:
     `select vault.create_secret('<DEIN_SECRET>', 'cron_shared_secret');`
  4. Falls die Edge Function noch nicht deployt ist: `supabase functions deploy taeglicher-ueberblick`.
  5. Dem Bot in Telegram **einmal schreiben**, Chat-ID besorgen, in der App unter Konto → Benachrichtigungen eintragen, speichern, **Testnachricht** senden.
- [ ] **Step 6: Ersten echten Lauf verifizieren** (am Folgetag): kam die Morgen-Nachricht? Ist `zuletzt_gesendet_am` gesetzt? `select jobname, status, return_message from cron.job_run_details order by start_time desc limit 5;` → Läufe ohne Fehler.

---

## Self-Review-Notizen
- **Spec-Abdeckung:** Architektur/Stunden-Cron (T1), Datenmodell + persönliche RLS (T1), Textbau + Zeitzonen-/Doppelversand-Logik (T2), zwei Eingänge + Fehlerverhalten (T3), Verknüpfung + Testnachricht + „zuletzt gesendet" (T4/T5), Daniels Schritte (T6).
- **Reihenfolge:** Migration zuerst (die Function schreibt in die Tabelle), dann reine Logik, dann Function, dann App.
- **Verifizierte Annahmen statt Raten:** `status='offen'`, Spaltennamen, RLS-Helfer, Edge-Function-Muster — alle vorab gegen die echte DB bzw. den Code geprüft und oben notiert.
- **Bewusst nicht in der App:** `zuletzt_gesendet_am` wird nie mitgeschrieben (`toUpdateJson` lässt es weg) — sonst könnte die App den Doppelversand-Riegel aushebeln. Ein Test hält das fest.
- **Zwei Abhängigkeiten außerhalb meiner Reichweite:** die Supabase-CLI für den Function-Deploy und die drei Secrets. Beide sind im Plan explizit als Daniels Schritte markiert, damit sie nicht stillschweigend fehlen.
