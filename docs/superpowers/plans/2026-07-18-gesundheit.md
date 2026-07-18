# Gesundheit/Schädlinge — Modul 4.14 — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Krankheits-/Schädlings-Katalog (Dart) + Diagnose-/Gesundheits-Journal je Volk + Meldepflicht-Hinweis, angedockt an die Volk-Detailseite.

**Architecture:** Blend aus 4.3 (Fotos, privater Bucket) und 4.6 (Soft-Delete/Storno/Section/Form), **ohne RPC** (normaler Insert via Policy, eine Diagnose je Volk). `gesundheitsereignisse`-Tabelle (volk-FK `RESTRICT`, keine DELETE-Policy, CHECKs inkl. `status=gemeldet⇒gemeldet_am`). Katalog als Dart-Fachkonstante (kanton-neutral).

**Tech Stack:** Supabase (Postgres 15, RLS), Flutter Web, Riverpod AsyncNotifier (ohne Codegen), go_router (Hash), image_picker.

**Grundlage:** Spec v2 `docs/superpowers/specs/2026-07-18-gesundheit-design.md` (18 Review-Funde eingearbeitet: M1 kein GR-Hardcode, M2 gemeldet_am-CHECK, M8 Rechtskategorie=national, M4 Vergiftung/Tracheenmilbe u.a.). Fachwissen: `../imkerei/02_Recherche/14`.

**Errcodes:** **keine neuen** (reines CRUD + Soft-Delete, kein RPC — wie 4.3). Nächster freier RPC-Block bleibt BA050.

**Muster-Referenzen:** `supabase/migrations/D01_inspections.sql` + `D02_storage_inspection_photos.sql` (Tabelle+privater Bucket), `supabase/migrations/F01_fuetterungen.sql` (Soft-Delete/RESTRICT/CHECKs), `lib/core/storage/foto_speicher.dart` (`FotoSpeicher(client, bucket)`), `lib/features/durchsicht/presentation/pages/durchsicht_form_page.dart` (Foto-Aufnahme) + `…/durchsicht_detail_page.dart` (Foto-Anzeige via Signed-URL), `lib/features/fuetterung/` (Section/Form/Provider-Muster), `lib/features/auth/presentation/auth_providers.dart` (`_datenNeuLaden`, `currentBetriebIdProvider`, `darfSchreibenProvider`).

> **Migrationen G01/G02 wendet der Controller (nicht ein Subagent) via `apply_migration` auf die Produktion an** — nach Freigabe für die 4.14-DB. Dart-Tasks (3+) subagent-getrieben.

---

## Dateistruktur

| Datei | Verantwortung |
|---|---|
| `supabase/migrations/G01_gesundheitsereignisse.sql` | Diagnose-Journal-Tabelle |
| `supabase/migrations/G02_storage_health_photos.sql` | privater Bucket `health-photos` |
| `lib/features/gesundheit/domain/krankheit.dart` | Katalog (Dart-const) + Enums + Helper |
| `lib/features/gesundheit/domain/gesundheitsereignis.dart` | Modell |
| `lib/features/gesundheit/domain/gesundheit_gateway.dart` | abstraktes Gateway + `GesundheitFehler` |
| `lib/features/gesundheit/data/fake_gesundheit_gateway.dart` | In-Memory-Fake |
| `lib/features/gesundheit/data/supabase_gesundheit_gateway.dart` | Supabase-Impl (CRUD + Foto) |
| `lib/features/gesundheit/presentation/providers/gesundheit_provider.dart` | Family + `aktiveMeldepflichtProvider` |
| `lib/features/gesundheit/presentation/widgets/meldepflicht_banner.dart` | roter Banner + Disclaimer |
| `lib/features/gesundheit/presentation/widgets/gesundheit_section.dart` | Andock-Card (Banner + 4.3-Nudge + Liste) |
| `lib/features/gesundheit/presentation/pages/gesundheit_form_page.dart` | Diagnose-Formular |
| `lib/features/voelker/presentation/pages/volk_detail_page.dart` | (modify) `GesundheitSection` andocken |
| `lib/core/router/app_router.dart` | (modify) Route `gesundheit` |
| `lib/features/auth/presentation/auth_providers.dart` | (modify) Provider in `_datenNeuLaden` |
| `pubspec.yaml` | (modify) `version: 1.13.0+31` |

---

## Task 1: Migration G01 — Diagnose-Journal (Controller-Task, Produktion)

**Files:**
- Create: `supabase/migrations/G01_gesundheitsereignisse.sql`

- [ ] **Step 1: Datei schreiben**

```sql
-- G01_gesundheitsereignisse.sql | Diagnose-/Gesundheits-Journal je Volk (Bestandeskontroll-Spur).
-- Soft-Delete/Storno (KEIN Immutable-Trigger, KEIN RPC), volk-FK ON DELETE RESTRICT, keine DELETE-Policy.
-- krankheit-CHECK = 17 Katalog-Keys (Dart-Parität via Test, M3). status=gemeldet erzwingt gemeldet_am
-- (M2: einzige DB-Invariante, da kein RPC-Gatekeeper). Keine neuen Errcodes.

create table if not exists public.gesundheitsereignisse (
  id uuid primary key default gen_random_uuid(),
  volk_id uuid not null,
  festgestellt_am date not null default current_date,
  krankheit text not null check (krankheit in (
    'afb','efb','kleiner_beutenkaefer','tropilaelaps','varroa','kalkbrut','steinbrut','sackbrut',
    'nosema','ruhr','viren','wachsmotte','braula','tracheenmilbe','vergiftung','vespa_velutina','sonstige')),
  schweregrad text check (schweregrad in ('leicht','mittel','schwer')),
  status text not null default 'verdacht'
    check (status in ('verdacht','bestaetigt','gemeldet','in_behandlung','saniert','ausgeheilt','erloschen')),
  gemeldet_am date,
  labor_eingesandt boolean not null default false,
  foto_urls text[] not null default '{}',
  massnahme text,
  verantwortliche_person text,
  notiz text,
  is_storniert boolean not null default false,
  storno_grund text,
  storno_am date,
  betrieb_id uuid not null default private.aktive_betrieb_id()
    references public.betriebe(id) on delete cascade,
  created_by uuid, updated_by uuid,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (betrieb_id, id),
  constraint gesundheitsereignisse_volk_fk
    foreign key (betrieb_id, volk_id) references public.voelker (betrieb_id, id) on delete restrict,
  constraint gesundheitsereignisse_storno_chk
    check (is_storniert = false or (storno_grund is not null and storno_am is not null)),
  constraint gesundheitsereignisse_gemeldet_chk
    check (status <> 'gemeldet' or gemeldet_am is not null),
  constraint gesundheitsereignisse_storno_datum_chk
    check (storno_am is null or storno_am >= festgestellt_am),
  constraint gesundheitsereignisse_gemeldet_datum_chk
    check (gemeldet_am is null or gemeldet_am >= festgestellt_am),
  constraint gesundheitsereignisse_zukunft_chk
    check (festgestellt_am <= current_date and (gemeldet_am is null or gemeldet_am <= current_date))
);
alter table public.gesundheitsereignisse enable row level security;
revoke all on public.gesundheitsereignisse from anon, public;
grant select, insert, update on public.gesundheitsereignisse to authenticated;
create index if not exists idx_gesundheitsereignisse_volk_datum
  on public.gesundheitsereignisse (betrieb_id, volk_id, festgestellt_am desc);

drop trigger if exists trg_gesundheitsereignisse_actor on public.gesundheitsereignisse;
create trigger trg_gesundheitsereignisse_actor before insert or update
  on public.gesundheitsereignisse for each row execute function private.set_row_actor();
drop trigger if exists trg_gesundheitsereignisse_updated on public.gesundheitsereignisse;
create trigger trg_gesundheitsereignisse_updated before update
  on public.gesundheitsereignisse for each row execute function private.set_updated_at();

drop policy if exists gesundheitsereignisse_sel_member on public.gesundheitsereignisse;
create policy gesundheitsereignisse_sel_member on public.gesundheitsereignisse
  for select to authenticated using (betrieb_id in (select private.meine_betrieb_ids()));
drop policy if exists gesundheitsereignisse_ins_writer on public.gesundheitsereignisse;
create policy gesundheitsereignisse_ins_writer on public.gesundheitsereignisse
  for insert to authenticated with check (private.kann_schreiben(betrieb_id));
drop policy if exists gesundheitsereignisse_upd_writer on public.gesundheitsereignisse;
create policy gesundheitsereignisse_upd_writer on public.gesundheitsereignisse
  for update to authenticated using (private.kann_schreiben(betrieb_id))
  with check (private.kann_schreiben(betrieb_id));
-- BEWUSST keine DELETE-Policy (Soft-Delete).
```

- [ ] **Step 2: Migration anwenden**

Controller ruft `apply_migration` mit `name: "G01_gesundheitsereignisse"` auf `dcdcohktxbhdxnxjvcyp`.
Erwartet: Erfolg. *(Falls Postgres den `current_date`-Zukunfts-CHECK ablehnt — Immutabilität —, diesen einen CHECK entfernen und in Spec §10 als akzeptiert vermerken, wie 4.3/4.6; alle anderen CHECKs bleiben.)*

- [ ] **Step 3: Rollback-DO-Test — RESTRICT, CHECKs (gemeldet/Datum/Zukunft), kein Hard-Delete**

```sql
do $$
declare v_b uuid := '1c84d5dd-d22e-4bce-bba9-5e861b2f4aa4'; v_volk uuid; v_e uuid;
begin
  insert into public.voelker (betrieb_id, name, status) values (v_b, 'G01-TEST-VOLK', 'aktiv') returning id into v_volk;
  insert into public.gesundheitsereignisse (betrieb_id, volk_id, festgestellt_am, krankheit, status)
    values (v_b, v_volk, current_date, 'kalkbrut', 'verdacht') returning id into v_e;

  -- RESTRICT: Volk mit Ereignis nicht hart löschbar
  begin delete from public.voelker where id = v_volk;
    raise exception 'FEHLER: voelker-Delete trotz Ereignis erlaubt';
  exception when foreign_key_violation then null; end;

  -- CHECK: status=gemeldet ohne gemeldet_am (M2)
  begin update public.gesundheitsereignisse set status = 'gemeldet' where id = v_e;
    raise exception 'FEHLER: status=gemeldet ohne gemeldet_am erlaubt';
  exception when check_violation then null; end;

  -- gemeldet MIT Datum ok
  update public.gesundheitsereignisse set status = 'gemeldet', gemeldet_am = current_date where id = v_e;

  -- CHECK: ungültiges krankheit-Enum
  begin insert into public.gesundheitsereignisse (betrieb_id, volk_id, krankheit) values (v_b, v_volk, 'quatsch');
    raise exception 'FEHLER: ungültiges krankheit erlaubt';
  exception when check_violation then null; end;

  -- CHECK: Zukunftsdatum
  begin insert into public.gesundheitsereignisse (betrieb_id, volk_id, festgestellt_am, krankheit)
    values (v_b, v_volk, current_date + 1, 'kalkbrut');
    raise exception 'FEHLER: Zukunfts-festgestellt_am erlaubt';
  exception when check_violation then null; end;

  -- kein Hard-DELETE (keine Policy) — als Admin via execute_sql geht DELETE zwar, aber die Policy fehlt;
  -- der App-Pfad ist Soft-Delete. Prüfen: Storno-UPDATE funktioniert:
  update public.gesundheitsereignisse set is_storniert = true, storno_grund = 'Test', storno_am = current_date where id = v_e;

  raise exception 'ROLLBACK_OK';
exception when others then
  if sqlerrm = 'ROLLBACK_OK' then return; end if;
  raise;
end $$;
```
Erwartet: kein Fehler.

- [ ] **Step 4: Advisor-Gate** — `get_advisors(type: "security")` → 0 neue Findings (kein RPC, keine Definer-Funktion; FK-Index deckt die FK).

- [ ] **Step 5: Commit**

```bash
git add supabase/migrations/G01_gesundheitsereignisse.sql
git commit -m "feat(4.14): G01 gesundheitsereignisse (Diagnose-Journal, RESTRICT, Soft-Delete, gemeldet-CHECK)"
```

---

## Task 2: Migration G02 — privater Bucket `health-photos` (Controller-Task, Produktion)

**Files:**
- Create: `supabase/migrations/G02_storage_health_photos.sql`

- [ ] **Step 1: Datei schreiben** (exakt D02-Muster mit `health-photos`)

```sql
-- G02_storage_health_photos.sql | PRIVATER Bucket (Krankheitsfotos = Gesundheitsdaten).
-- SELECT nur Mitglied (private.ist_mitglied); Write nur kann_schreiben. Anzeige via createSignedUrl.

insert into storage.buckets (id, name, public)
  values ('health-photos', 'health-photos', false)
  on conflict (id) do nothing;

drop policy if exists auth_sel_health_photos on storage.objects;
create policy auth_sel_health_photos on storage.objects for select to authenticated
  using (bucket_id = 'health-photos'
    and (storage.foldername(name))[1] ~ '^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$'
    and private.ist_mitglied(((storage.foldername(name))[1])::uuid));

drop policy if exists auth_ins_health_photos on storage.objects;
create policy auth_ins_health_photos on storage.objects for insert to authenticated
  with check (bucket_id = 'health-photos'
    and (storage.foldername(name))[1] ~ '^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$'
    and private.kann_schreiben(((storage.foldername(name))[1])::uuid));

drop policy if exists auth_upd_health_photos on storage.objects;
create policy auth_upd_health_photos on storage.objects for update to authenticated
  using (bucket_id = 'health-photos'
    and (storage.foldername(name))[1] ~ '^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$'
    and private.kann_schreiben(((storage.foldername(name))[1])::uuid))
  with check (bucket_id = 'health-photos'
    and (storage.foldername(name))[1] ~ '^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$'
    and private.kann_schreiben(((storage.foldername(name))[1])::uuid));

drop policy if exists auth_del_health_photos on storage.objects;
create policy auth_del_health_photos on storage.objects for delete to authenticated
  using (bucket_id = 'health-photos'
    and (storage.foldername(name))[1] ~ '^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$'
    and private.kann_schreiben(((storage.foldername(name))[1])::uuid));
```

- [ ] **Step 2: Migration anwenden** — `apply_migration` `name: "G02_storage_health_photos"`. Erwartet: Erfolg.

- [ ] **Step 3: Verifikation** — via `execute_sql`: `select id, public from storage.buckets where id = 'health-photos';` → eine Zeile, `public = false`.

- [ ] **Step 4: Advisor-Gate** — `get_advisors(type: "security")` → 0 neue Findings.

- [ ] **Step 5: Commit**

```bash
git add supabase/migrations/G02_storage_health_photos.sql
git commit -m "feat(4.14): G02 privater Bucket health-photos (D02-Muster)"
```

---

## Task 3: Domain — `krankheit.dart` (Katalog + Enums + Helper)

**Files:**
- Create: `lib/features/gesundheit/domain/krankheit.dart`
- Test: `test/features/gesundheit/krankheit_test.dart`

- [ ] **Step 1: Test schreiben**

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:bienen_app/features/gesundheit/domain/krankheit.dart';

// Spiegel der G01 krankheit-CHECK-Whitelist. MUSS mit kKrankheiten UND der Migration synchron bleiben (M3).
const _dbCheckKeys = <String>{
  'afb', 'efb', 'kleiner_beutenkaefer', 'tropilaelaps', 'varroa', 'kalkbrut', 'steinbrut', 'sackbrut',
  'nosema', 'ruhr', 'viren', 'wachsmotte', 'braula', 'tracheenmilbe', 'vergiftung', 'vespa_velutina', 'sonstige',
};

void main() {
  test('Katalog-Keys == DB-CHECK-Whitelist (Parität, M3)', () {
    expect(krankheitKeys, _dbCheckKeys);
  });
  test('Rechtskategorie je Krankheit (verifiziert Recherche 14)', () {
    for (final k in ['afb', 'efb', 'kleiner_beutenkaefer', 'tropilaelaps']) {
      expect(rechtskategorieVon(k), Rechtskategorie.zuBekaempfen, reason: k);
      expect(istMeldepflichtig(k), isTrue, reason: k);
    }
    expect(rechtskategorieVon('varroa'), Rechtskategorie.zuUeberwachen);
    expect(istMeldepflichtig('varroa'), isFalse);
    for (final k in ['kalkbrut', 'sackbrut', 'nosema', 'tracheenmilbe', 'vergiftung']) {
      expect(rechtskategorieVon(k), Rechtskategorie.nichtMeldepflichtig, reason: k);
    }
    expect(rechtskategorieVon('vespa_velutina'), Rechtskategorie.neobiotaMeldung);
    expect(istMeldepflichtig('vespa_velutina'), isTrue);
  });
  test('kein GR-Hardcode im Melde-Text (M1)', () {
    for (final k in kKrankheiten) {
      expect(k.meldehinweis ?? '', isNot(contains('GR')), reason: k.key);
    }
  });
  test('durchsichtFlagZuKrankheit-Mapping', () {
    expect(durchsichtFlagZuKrankheit('faulbrut_verdacht'), 'afb');
    expect(durchsichtFlagZuKrankheit('sauerbrut_verdacht'), 'efb');
    expect(durchsichtFlagZuKrankheit('varroa_sichtbar'), 'varroa');
    expect(durchsichtFlagZuKrankheit('raeuberei'), isNull);
    expect(durchsichtFlagZuKrankheit('kahlflug'), isNull);
  });
}
```

- [ ] **Step 2: Test ausführen (rot)** — `flutter test test/features/gesundheit/krankheit_test.dart` → FAIL (URI fehlt).

- [ ] **Step 3: Implementierung schreiben**

```dart
enum Rechtskategorie { zuBekaempfen, zuUeberwachen, nichtMeldepflichtig, neobiotaMeldung }

enum Stadium { offeneBrut, verdeckelteBrut, adulteBienen, wabenLager, mehrere }

class Krankheit {
  final String key;
  final String label;
  final Rechtskategorie rechtskategorie;
  final Stadium stadium;
  final String leitsymptome;
  final String sofortmassnahme;
  final String? meldehinweis;
  const Krankheit(this.key, this.label, this.rechtskategorie, this.stadium, this.leitsymptome,
      this.sofortmassnahme, [this.meldehinweis]);
}

/// Kanton-neutraler Melde-Text (kein GR-Hardcode, M1). Der konkrete Inspektor-Kontakt kommt via 4.23/F4.
const _meldeInspektor =
    'Meldepflichtig schon bei Verdacht: zuständigen kantonalen Bieneninspektor / kant. Veterinärdienst '
    'kontaktieren. Fachliche Begleitung: BGD 0800 274 274 (ersetzt die amtliche Meldung nicht).';

const kKrankheiten = <Krankheit>[
  Krankheit('afb', 'Amerikanische Faulbrut', Rechtskategorie.zuBekaempfen, Stadium.verdeckelteBrut,
      'Eingesunkene/durchlöcherte, feuchte Zelldeckel; braune fadenziehende Masse (Streichholzprobe); modriger Geruch.',
      'Volk geschlossen halten, NICHTS umhängen, keine Eigen-Probe einsenden — der Inspektor nimmt amtlich Probe.',
      _meldeInspektor),
  Krankheit('efb', 'Europäische Sauerbrut', Rechtskategorie.zuBekaempfen, Stadium.offeneBrut,
      'Verkrümmte, vergilbte, verrutschte offene Larven; säuerlicher Geruch; lückiges Brutbild.',
      'Volk geschlossen halten, keine Eigen-Probe — Inspektor melden.', _meldeInspektor),
  Krankheit('kleiner_beutenkaefer', 'Kleiner Beutenkäfer (Aethina tumida)', Rechtskategorie.zuBekaempfen, Stadium.mehrere,
      'Kleine dunkle Käfer/Larven im Volk, schleimig gärende Waben. CH bislang frei (APINELLA-Monitoring).',
      'Verdacht sofort melden; Käfer/Probe sichern.', _meldeInspektor),
  Krankheit('tropilaelaps', 'Tropilaelaps-Milben', Rechtskategorie.zuBekaempfen, Stadium.verdeckelteBrut,
      'Kleine, schnell laufende Milben in der Brut; geschädigte Brut. CH bislang frei.',
      'Verdacht sofort melden.', _meldeInspektor),
  Krankheit('varroa', 'Varroose', Rechtskategorie.zuUeberwachen, Stadium.mehrere,
      'Milben auf Bienen/Brut, verkrüppelte Flügel (DWV), Gemüll-Milbenfall. Flächendeckend.',
      'Kein Einzelfall-Melden. Monitoring + Behandlung — siehe Behandlungen.', null),
  Krankheit('kalkbrut', 'Kalkbrut', Rechtskategorie.nichtMeldepflichtig, Stadium.verdeckelteBrut,
      'Mumifizierte, kreideweiße/graue harte Larven; „Klappern" am Bodenbrett.',
      'Volk stärken, junge Königin, Wabenerneuerung, trockener/warmer Stand.', null),
  Krankheit('steinbrut', 'Steinbrut (Aspergillus)', Rechtskategorie.nichtMeldepflichtig, Stadium.mehrere,
      'Harte, grün-gelblich verpilzte Larven. Selten; Aspergillus ist humanpathogen (Atemwege).',
      'ARBEITSSCHUTZ: Handschuhe + FFP2/FFP3-Maske, Sporen nicht einatmen, befallene Waben entsorgen.', null),
  Krankheit('sackbrut', 'Sackbrut', Rechtskategorie.nichtMeldepflichtig, Stadium.verdeckelteBrut,
      'Gestreckte, sackförmige (flüssigkeitsgefüllte) Larven, hochgezogene Köpfchen. AFB-VERWECHSLUNGSGEFAHR.',
      'Streichholz-/Fadenzugprobe machen; bei Unsicherheit wie AFB behandeln = melden. Volk stärken.', null),
  Krankheit('nosema', 'Nosemose', Rechtskategorie.nichtMeldepflichtig, Stadium.adulteBienen,
      'Durchfall/Ruhr, geschwächte Völker, Kotspritzer; Nachweis nur mikroskopisch.',
      'Hygiene, Wabenerneuerung, starke Völker; ggf. Probe an Agroscope/BGD.', null),
  Krankheit('ruhr', 'Ruhr / Durchfall', Rechtskategorie.nichtMeldepflichtig, Stadium.adulteBienen,
      'Kotspritzer an Beute/Waben; oft Folge schlechten Winterfutters oder Nosema.',
      'Futterqualität prüfen, Reinigungsflug abwarten, Nosema abklären.', null),
  Krankheit('viren', 'Viruserkrankungen (DWV/ABPV/CBPV)', Rechtskategorie.nichtMeldepflichtig, Stadium.mehrere,
      'Verkrüppelte Flügel (DWV, varroagekoppelt), zitternde/haarlose schwarze Bienen (CBPV).',
      'Varroa senken (Hauptursache DWV), Volk stärken, junge Königin.', null),
  Krankheit('wachsmotte', 'Wachsmotte', Rechtskategorie.nichtMeldepflichtig, Stadium.wabenLager,
      'Gespinste/Fraßgänge in Waben (v. a. Lager & schwache Völker).',
      'Nur starke Völker; Waben kühl/luftig lagern; Lagerhygiene.', null),
  Krankheit('braula', 'Bienenlaus (Braula coeca)', Rechtskategorie.nichtMeldepflichtig, Stadium.adulteBienen,
      'Kleine flügellose „Läuse" auf Bienen/Königin. Harmlos; nicht mit Varroa verwechseln.',
      'Keine spezifische Behandlung nötig.', null),
  Krankheit('tracheenmilbe', 'Tracheenmilbe (Acarapis woodi)', Rechtskategorie.nichtMeldepflichtig, Stadium.adulteBienen,
      'Krabbelnde, flugunfähige Bienen; Nachweis nur mikroskopisch. In CH nachrangig.',
      'Meist keine spezifische Behandlung; die Ameisensäure gegen Varroa wirkt mit.', null),
  Krankheit('vergiftung', 'Vergiftung (Pflanzenschutzmittel)', Rechtskategorie.nichtMeldepflichtig, Stadium.adulteBienen,
      'Schlagartiges Massensterben vor der Beute bei GESUNDER Brut; volle Kröpfe/Pollen.',
      'SOFORT Proben (tote Bienen + verdächtige Pflanze/Feld) VOR Regen ziehen — kurzes Nachweisfenster.',
      'Verdacht Bienenvergiftung → BGD 0800 274 274 / Agroscope informieren (NICHT primär der Inspektor); '
      'ggf. kantonale Stelle. Nachweis-/versicherungsrelevant.'),
  Krankheit('vespa_velutina', 'Asiatische Hornisse (Vespa velutina)', Rechtskategorie.neobiotaMeldung, Stadium.adulteBienen,
      'Vor dem Flugloch rüttelnd jagende dunkle Hornissen; Nest hoch in Bäumen.',
      'Nester NICHT selbst entfernen (Spezialisten). Fund mit Foto + Standort melden.',
      'Fund (Tier oder Nest) über asiatischehornisse.ch melden (geht an infofauna/Agroscope + kantonale Kontaktperson).'),
  Krankheit('sonstige', 'Sonstige / unklar', Rechtskategorie.nichtMeldepflichtig, Stadium.mehrere,
      'Unklarer Befund.', 'Beobachten, dokumentieren; im Zweifel BGD 0800 274 274 fragen.', null),
];

Krankheit? katalogEintrag(String key) {
  for (final k in kKrankheiten) {
    if (k.key == key) return k;
  }
  return null;
}

Rechtskategorie? rechtskategorieVon(String key) => katalogEintrag(key)?.rechtskategorie;

/// Löst einen Melde-Hinweis aus (rote Banner-/Neobiota-Meldung).
bool istMeldepflichtig(String key) {
  final r = rechtskategorieVon(key);
  return r == Rechtskategorie.zuBekaempfen || r == Rechtskategorie.neobiotaMeldung;
}

/// Single-Source der Katalog-Keys (für den DB-CHECK-Paritätstest, M3).
final Set<String> krankheitKeys = kKrankheiten.map((k) => k.key).toSet();

/// 4.3-Durchsichts-Flag → Krankheit-Key (null = keine Krankheit).
String? durchsichtFlagZuKrankheit(String flag) => switch (flag) {
      'faulbrut_verdacht' => 'afb',
      'sauerbrut_verdacht' => 'efb',
      'kalkbrut' => 'kalkbrut',
      'sackbrut' => 'sackbrut',
      'varroa_sichtbar' => 'varroa',
      'ruhr' => 'ruhr',
      'wachsmotte' => 'wachsmotte',
      _ => null,
    };
```

- [ ] **Step 4: Test ausführen (grün) + Commit** — `flutter test test/features/gesundheit/krankheit_test.dart` → PASS (4 Tests).

```bash
git add lib/features/gesundheit/domain/krankheit.dart test/features/gesundheit/krankheit_test.dart
git commit -m "feat(4.14): Krankheits-Katalog (Dart-const, kanton-neutral, 17 Keys) + Helper"
```

---

## Task 4: Domain — Modell `Gesundheitsereignis`

**Files:**
- Create: `lib/features/gesundheit/domain/gesundheitsereignis.dart`
- Test: `test/features/gesundheit/gesundheitsereignis_test.dart`

- [ ] **Step 1: Test schreiben**

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:bienen_app/features/gesundheit/domain/gesundheitsereignis.dart';

void main() {
  test('Roundtrip + istAktiv', () {
    final e = Gesundheitsereignis.fromJson({
      'id': 'g1', 'volk_id': 'v1', 'festgestellt_am': '2026-07-19', 'krankheit': 'afb',
      'schweregrad': 'schwer', 'status': 'gemeldet', 'gemeldet_am': '2026-07-19',
      'labor_eingesandt': false, 'foto_urls': ['b/v1/f.jpg'], 'massnahme': 'gesperrt',
      'verantwortliche_person': 'Dani', 'notiz': null,
      'is_storniert': false, 'storno_grund': null, 'storno_am': null,
    });
    expect(e.krankheit, 'afb');
    expect(e.status, 'gemeldet');
    expect(e.gemeldetAm, isNotNull);
    expect(e.fotoUrls, ['b/v1/f.jpg']);
    expect(e.istAktiv, isTrue);
    final j = e.toInsertJson();
    expect(j['volk_id'], 'v1');
    expect(j['krankheit'], 'afb');
    expect(j.containsKey('id'), isFalse);
  });
  test('istAktiv false bei storniert/abgeschlossen', () {
    Gesundheitsereignis mk(String status, {bool storno = false}) => Gesundheitsereignis(
        id: 'x', volkId: 'v1', festgestelltAm: DateTime(2026, 7, 19), krankheit: 'kalkbrut',
        status: status, isStorniert: storno);
    expect(mk('verdacht').istAktiv, isTrue);
    expect(mk('ausgeheilt').istAktiv, isFalse);
    expect(mk('saniert').istAktiv, isFalse);
    expect(mk('erloschen').istAktiv, isFalse);
    expect(mk('verdacht', storno: true).istAktiv, isFalse);
  });
}
```

- [ ] **Step 2: Test ausführen (rot)** — FAIL (URI fehlt).

- [ ] **Step 3: Implementierung schreiben**

```dart
class Gesundheitsereignis {
  final String id;
  final String volkId;
  final DateTime festgestelltAm;
  final String krankheit;
  final String? schweregrad;
  final String status;
  final DateTime? gemeldetAm;
  final bool laborEingesandt;
  final List<String> fotoUrls;
  final String? massnahme;
  final String? verantwortlichePerson;
  final String? notiz;
  final bool isStorniert;
  final String? stornoGrund;
  final DateTime? stornoAm;

  const Gesundheitsereignis({
    required this.id,
    required this.volkId,
    required this.festgestelltAm,
    required this.krankheit,
    this.schweregrad,
    this.status = 'verdacht',
    this.gemeldetAm,
    this.laborEingesandt = false,
    this.fotoUrls = const [],
    this.massnahme,
    this.verantwortlichePerson,
    this.notiz,
    this.isStorniert = false,
    this.stornoGrund,
    this.stornoAm,
  });

  static const _abgeschlossen = {'saniert', 'ausgeheilt', 'erloschen'};
  bool get istAktiv => !isStorniert && !_abgeschlossen.contains(status);

  static DateTime _d(Object? v) => DateTime.parse(v as String);
  String _iso(DateTime d) => d.toIso8601String().substring(0, 10);

  factory Gesundheitsereignis.fromJson(Map<String, dynamic> j) => Gesundheitsereignis(
        id: j['id'] as String,
        volkId: j['volk_id'] as String,
        festgestelltAm: _d(j['festgestellt_am']),
        krankheit: j['krankheit'] as String,
        schweregrad: j['schweregrad'] as String?,
        status: (j['status'] as String?) ?? 'verdacht',
        gemeldetAm: j['gemeldet_am'] != null ? _d(j['gemeldet_am']) : null,
        laborEingesandt: (j['labor_eingesandt'] as bool?) ?? false,
        fotoUrls: ((j['foto_urls'] as List?)?.cast<String>() ?? const []),
        massnahme: j['massnahme'] as String?,
        verantwortlichePerson: j['verantwortliche_person'] as String?,
        notiz: j['notiz'] as String?,
        isStorniert: (j['is_storniert'] as bool?) ?? false,
        stornoGrund: j['storno_grund'] as String?,
        stornoAm: j['storno_am'] != null ? _d(j['storno_am']) : null,
      );

  Map<String, dynamic> toInsertJson() => {
        'volk_id': volkId,
        'festgestellt_am': _iso(festgestelltAm),
        'krankheit': krankheit,
        'schweregrad': schweregrad,
        'status': status,
        'gemeldet_am': gemeldetAm != null ? _iso(gemeldetAm!) : null,
        'labor_eingesandt': laborEingesandt,
        'foto_urls': fotoUrls,
        'massnahme': massnahme,
        'verantwortliche_person': verantwortlichePerson,
        'notiz': notiz,
      };
}
```

- [ ] **Step 4: Test ausführen (grün) + Commit** — PASS (2 Tests).

```bash
git add lib/features/gesundheit/domain/gesundheitsereignis.dart test/features/gesundheit/gesundheitsereignis_test.dart
git commit -m "feat(4.14): Modell Gesundheitsereignis (istAktiv)"
```

---

## Task 5: Domain — abstraktes Gateway

**Files:**
- Create: `lib/features/gesundheit/domain/gesundheit_gateway.dart`

- [ ] **Step 1: Gateway schreiben** (in Task 6 über den Fake getestet)

```dart
import 'dart:typed_data';
import 'package:bienen_app/features/gesundheit/domain/gesundheitsereignis.dart';

class GesundheitFehler implements Exception {
  final String code;
  final String message;
  const GesundheitFehler(this.code, this.message);
  @override
  String toString() => message;
}

abstract class GesundheitGateway {
  Future<List<Gesundheitsereignis>> ereignisseFuerVolk(String volkId); // inkl. stornierte, absteigend
  Future<void> speichern(Gesundheitsereignis e); // insert wenn id leer, sonst update
  Future<void> stornieren(String id, String grund);
  Future<String> fotoHochladen({required String betriebId, required String gruppeId, required Uint8List bytes});
  Future<String> fotoSignedUrl(String pfad);
  Future<void> fotoEntfernen(List<String> pfade);
}
```

- [ ] **Step 2: Commit**

```bash
git add lib/features/gesundheit/domain/gesundheit_gateway.dart
git commit -m "feat(4.14): abstraktes GesundheitGateway + GesundheitFehler"
```

---

## Task 6: Data — `FakeGesundheitGateway`

**Files:**
- Create: `lib/features/gesundheit/data/fake_gesundheit_gateway.dart`
- Test: `test/features/gesundheit/fake_gesundheit_gateway_test.dart`

- [ ] **Step 1: Test schreiben**

```dart
import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:bienen_app/features/gesundheit/data/fake_gesundheit_gateway.dart';
import 'package:bienen_app/features/gesundheit/domain/gesundheitsereignis.dart';

void main() {
  test('speichern/stornieren; Storno erhält foto_urls', () async {
    final g = FakeGesundheitGateway();
    await g.speichern(Gesundheitsereignis(
        id: '', volkId: 'v1', festgestelltAm: DateTime(2026, 7, 19), krankheit: 'afb',
        status: 'verdacht', fotoUrls: const ['b/v1/f.jpg']));
    var list = await g.ereignisseFuerVolk('v1');
    expect(list.length, 1);
    expect(list.first.istAktiv, isTrue);

    await g.stornieren(list.first.id, 'Fehleingabe');
    list = await g.ereignisseFuerVolk('v1');
    expect(list.first.isStorniert, isTrue);
    expect(list.first.fotoUrls, const ['b/v1/f.jpg']); // Foto-Spur bleibt
    expect(list.first.istAktiv, isFalse);
  });
  test('Foto-Helfer als No-Op nutzbar', () async {
    final g = FakeGesundheitGateway();
    final pfad = await g.fotoHochladen(betriebId: 'b', gruppeId: 'v1', bytes: Uint8List(0));
    expect(pfad, contains('b/v1/'));
    expect(await g.fotoSignedUrl(pfad), startsWith('https://signed.test/'));
    await g.fotoEntfernen([pfad]); // wirft nicht
  });
}
```

- [ ] **Step 2: Test ausführen (rot)** — FAIL (Fake fehlt).

- [ ] **Step 3: Fake schreiben**

```dart
import 'dart:typed_data';
import 'package:bienen_app/features/gesundheit/domain/gesundheitsereignis.dart';
import 'package:bienen_app/features/gesundheit/domain/gesundheit_gateway.dart';

class FakeGesundheitGateway implements GesundheitGateway {
  final _map = <String, Gesundheitsereignis>{};
  final entfernteFotos = <String>[];
  int _seq = 0;

  List<Gesundheitsereignis> get _sort {
    final l = _map.values.toList();
    l.sort((a, b) => b.festgestelltAm.compareTo(a.festgestelltAm));
    return l;
  }

  @override
  Future<List<Gesundheitsereignis>> ereignisseFuerVolk(String volkId) async =>
      _sort.where((e) => e.volkId == volkId).toList();

  @override
  Future<void> speichern(Gesundheitsereignis e) async {
    final id = e.id.isEmpty ? 'g${++_seq}' : e.id;
    _map[id] = Gesundheitsereignis(
      id: id, volkId: e.volkId, festgestelltAm: e.festgestelltAm, krankheit: e.krankheit,
      schweregrad: e.schweregrad, status: e.status, gemeldetAm: e.gemeldetAm,
      laborEingesandt: e.laborEingesandt, fotoUrls: e.fotoUrls, massnahme: e.massnahme,
      verantwortlichePerson: e.verantwortlichePerson, notiz: e.notiz,
      isStorniert: e.isStorniert, stornoGrund: e.stornoGrund, stornoAm: e.stornoAm,
    );
  }

  @override
  Future<void> stornieren(String id, String grund) async {
    final e = _map[id];
    if (e == null) return;
    _map[id] = Gesundheitsereignis(
      id: e.id, volkId: e.volkId, festgestelltAm: e.festgestelltAm, krankheit: e.krankheit,
      schweregrad: e.schweregrad, status: e.status, gemeldetAm: e.gemeldetAm,
      laborEingesandt: e.laborEingesandt, fotoUrls: e.fotoUrls, massnahme: e.massnahme,
      verantwortlichePerson: e.verantwortlichePerson, notiz: e.notiz,
      isStorniert: true, stornoGrund: grund, stornoAm: e.festgestelltAm,
    );
  }

  @override
  Future<String> fotoHochladen({required String betriebId, required String gruppeId, required Uint8List bytes}) async =>
      '$betriebId/$gruppeId/foto_${++_seq}.jpg';

  @override
  Future<String> fotoSignedUrl(String pfad) async => 'https://signed.test/$pfad';

  @override
  Future<void> fotoEntfernen(List<String> pfade) async => entfernteFotos.addAll(pfade);
}
```

- [ ] **Step 4: Test ausführen (grün) + Commit** — PASS (2 Tests).

```bash
git add lib/features/gesundheit/data/fake_gesundheit_gateway.dart test/features/gesundheit/fake_gesundheit_gateway_test.dart
git commit -m "feat(4.14): FakeGesundheitGateway (CRUD/Storno + Foto-No-Op)"
```

---

## Task 7: Data — `SupabaseGesundheitGateway`

**Files:**
- Create: `lib/features/gesundheit/data/supabase_gesundheit_gateway.dart`

- [ ] **Step 1: Implementierung schreiben** (kein Unit-Test; Muster wie `supabase_durchsicht_gateway.dart`)

```dart
import 'dart:typed_data';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:bienen_app/core/storage/foto_speicher.dart';
import 'package:bienen_app/features/gesundheit/domain/gesundheitsereignis.dart';
import 'package:bienen_app/features/gesundheit/domain/gesundheit_gateway.dart';

class SupabaseGesundheitGateway implements GesundheitGateway {
  final SupabaseClient _c;
  late final FotoSpeicher _fotos = FotoSpeicher(_c, 'health-photos');
  SupabaseGesundheitGateway(this._c);

  Never _rethrow(Object e) {
    if (e is PostgrestException && e.code != null) {
      throw GesundheitFehler(e.code!, e.message);
    }
    throw e;
  }

  @override
  Future<List<Gesundheitsereignis>> ereignisseFuerVolk(String volkId) async {
    try {
      final res = await _c
          .from('gesundheitsereignisse')
          .select()
          .eq('volk_id', volkId)
          .order('festgestellt_am', ascending: false);
      return (res as List).map((j) => Gesundheitsereignis.fromJson(j as Map<String, dynamic>)).toList();
    } catch (e) {
      _rethrow(e);
    }
  }

  @override
  Future<void> speichern(Gesundheitsereignis e) async {
    try {
      final json = e.toInsertJson();
      if (e.id.isEmpty) {
        await _c.from('gesundheitsereignisse').insert(json);
      } else {
        await _c.from('gesundheitsereignisse').update(json).eq('id', e.id);
      }
    } catch (err) {
      _rethrow(err);
    }
  }

  @override
  Future<void> stornieren(String id, String grund) async {
    try {
      await _c.from('gesundheitsereignisse').update({
        'is_storniert': true,
        'storno_grund': grund,
        'storno_am': DateTime.now().toIso8601String().substring(0, 10),
      }).eq('id', id);
    } catch (e) {
      _rethrow(e);
    }
  }

  @override
  Future<String> fotoHochladen({required String betriebId, required String gruppeId, required Uint8List bytes}) =>
      _fotos.hochladen(betriebId: betriebId, gruppeId: gruppeId, bytes: bytes);

  @override
  Future<String> fotoSignedUrl(String pfad) => _fotos.signedUrl(pfad);

  @override
  Future<void> fotoEntfernen(List<String> pfade) async {
    try {
      await _fotos.entfernen(pfade);
    } catch (_) {
      // best-effort
    }
  }
}
```

- [ ] **Step 2: Analyze + Commit** — `flutter analyze lib/features/gesundheit/data/supabase_gesundheit_gateway.dart` → No issues.

```bash
git add lib/features/gesundheit/data/supabase_gesundheit_gateway.dart
git commit -m "feat(4.14): SupabaseGesundheitGateway (CRUD + Foto)"
```

---

## Task 8: Presentation — Provider + `aktiveMeldepflichtProvider`

**Files:**
- Create: `lib/features/gesundheit/presentation/providers/gesundheit_provider.dart`
- Test: `test/features/gesundheit/gesundheit_provider_test.dart`

- [ ] **Step 1: Test schreiben**

```dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:bienen_app/features/gesundheit/data/fake_gesundheit_gateway.dart';
import 'package:bienen_app/features/gesundheit/domain/gesundheitsereignis.dart';
import 'package:bienen_app/features/gesundheit/presentation/providers/gesundheit_provider.dart';

void main() {
  test('aktiveMeldepflichtProvider liefert nur aktive zu_bekaempfen-Ereignisse', () async {
    final fake = FakeGesundheitGateway();
    await fake.speichern(Gesundheitsereignis(id: '', volkId: 'v1', festgestelltAm: DateTime(2026, 7, 19), krankheit: 'afb'));
    await fake.speichern(Gesundheitsereignis(id: '', volkId: 'v1', festgestelltAm: DateTime(2026, 7, 19), krankheit: 'kalkbrut'));
    await fake.speichern(Gesundheitsereignis(id: '', volkId: 'v1', festgestelltAm: DateTime(2026, 7, 19), krankheit: 'efb', status: 'ausgeheilt'));

    final c = ProviderContainer(overrides: [gesundheitGatewayProvider.overrideWithValue(fake)]);
    addTearDown(c.dispose);
    await c.read(gesundheitFuerVolkProvider('v1').future);
    final aktiv = c.read(aktiveMeldepflichtProvider('v1'));
    expect(aktiv.map((e) => e.krankheit), ['afb']); // kalkbrut=nicht meldepflichtig, efb=abgeschlossen
  });
}
```

- [ ] **Step 2: Test ausführen (rot)** — FAIL (Provider fehlen).

- [ ] **Step 3: Provider schreiben**

```dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:bienen_app/core/supabase/supabase_config.dart';
import 'package:bienen_app/features/gesundheit/data/supabase_gesundheit_gateway.dart';
import 'package:bienen_app/features/gesundheit/domain/gesundheitsereignis.dart';
import 'package:bienen_app/features/gesundheit/domain/gesundheit_gateway.dart';
import 'package:bienen_app/features/gesundheit/domain/krankheit.dart';

final gesundheitGatewayProvider =
    Provider<GesundheitGateway>((ref) => SupabaseGesundheitGateway(SupabaseConfig.client));

final gesundheitFuerVolkProvider =
    AsyncNotifierProvider.family<GesundheitNotifier, List<Gesundheitsereignis>, String>(
        GesundheitNotifier.new);

class GesundheitNotifier extends FamilyAsyncNotifier<List<Gesundheitsereignis>, String> {
  GesundheitGateway get _gw => ref.read(gesundheitGatewayProvider);
  @override
  Future<List<Gesundheitsereignis>> build(String volkId) => _gw.ereignisseFuerVolk(volkId);

  Future<void> speichern(Gesundheitsereignis e) async {
    await _gw.speichern(e);
    ref.invalidateSelf();
  }

  Future<void> stornieren(String id, String grund) async {
    await _gw.stornieren(id, grund);
    ref.invalidateSelf();
  }
}

/// Aktive zu_bekaempfen-Ereignisse fürs Meldepflicht-Banner (reine Ableitung — refresht nach Storno/Status).
final aktiveMeldepflichtProvider = Provider.family<List<Gesundheitsereignis>, String>((ref, volkId) {
  final list = ref.watch(gesundheitFuerVolkProvider(volkId)).valueOrNull ?? const [];
  return list
      .where((e) => e.istAktiv && rechtskategorieVon(e.krankheit) == Rechtskategorie.zuBekaempfen)
      .toList();
});
```

- [ ] **Step 4: Test ausführen (grün) + Commit** — PASS (1 Test).

```bash
git add lib/features/gesundheit/presentation/providers/gesundheit_provider.dart test/features/gesundheit/gesundheit_provider_test.dart
git commit -m "feat(4.14): Family-Provider + aktiveMeldepflichtProvider"
```

---

## Task 9: Auth-Reload-Verdrahtung

**Files:**
- Modify: `lib/features/auth/presentation/auth_providers.dart`
- Test: `test/features/gesundheit/gesundheit_provider_reset_test.dart`

- [ ] **Step 1: Test schreiben**

```dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:bienen_app/features/auth/data/fake_auth_gateway.dart';
import 'package:bienen_app/features/auth/presentation/auth_providers.dart';
import 'package:bienen_app/features/gesundheit/data/fake_gesundheit_gateway.dart';
import 'package:bienen_app/features/gesundheit/domain/gesundheitsereignis.dart';
import 'package:bienen_app/features/gesundheit/presentation/providers/gesundheit_provider.dart';

void main() {
  test('signOut invalidiert den Gesundheits-Cache', () async {
    final fake = FakeGesundheitGateway();
    await fake.speichern(Gesundheitsereignis(id: '', volkId: 'v1', festgestelltAm: DateTime(2026, 7, 19), krankheit: 'afb'));
    final c = ProviderContainer(overrides: [
      authGatewayProvider.overrideWithValue(FakeAuthGateway()),
      gesundheitGatewayProvider.overrideWithValue(fake),
    ]);
    addTearDown(c.dispose);

    final e0 = (await c.read(gesundheitFuerVolkProvider('v1').future)).single;
    expect(e0.isStorniert, isFalse);
    await fake.stornieren(e0.id, 'weg');
    expect(c.read(gesundheitFuerVolkProvider('v1')).valueOrNull?.single.isStorniert, isFalse); // stale

    await c.read(authControllerProvider.notifier).signOut();
    expect((await c.read(gesundheitFuerVolkProvider('v1').future)).single.isStorniert, isTrue,
        reason: 'gesundheitFuerVolkProvider nach signOut nicht invalidiert');
  });
}
```

- [ ] **Step 2: `_datenNeuLaden` erweitern**

Import ergänzen:

```dart
import 'package:bienen_app/features/gesundheit/presentation/providers/gesundheit_provider.dart';
```

In `_datenNeuLaden()` (nach den Fütterungs-/Behandlungs-Zeilen) ergänzen:

```dart
    ref.invalidate(gesundheitFuerVolkProvider);
```

- [ ] **Step 3: Test ausführen (grün) + Commit** — PASS.

```bash
git add lib/features/auth/presentation/auth_providers.dart test/features/gesundheit/gesundheit_provider_reset_test.dart
git commit -m "feat(4.14): Gesundheits-Provider in _datenNeuLaden"
```

---

## Task 10: UI — `MeldepflichtBanner`

**Files:**
- Create: `lib/features/gesundheit/presentation/widgets/meldepflicht_banner.dart`

- [ ] **Step 1: Widget schreiben** (rot + Rechtsauskunft-Disclaimer, M9; wird in Section + Form genutzt)

```dart
import 'package:flutter/material.dart';
import 'package:bienen_app/features/gesundheit/domain/krankheit.dart';

/// Roter Meldepflicht-Banner für eine zu_bekaempfen- oder neobiota-Krankheit (mit Rechtsauskunft-Disclaimer).
/// Zeigt nichts an, wenn die Krankheit nicht meldepflichtig ist.
class MeldepflichtBanner extends StatelessWidget {
  final String krankheitKey;
  const MeldepflichtBanner({super.key, required this.krankheitKey});

  @override
  Widget build(BuildContext context) {
    if (!istMeldepflichtig(krankheitKey)) return const SizedBox.shrink();
    final k = katalogEintrag(krankheitKey);
    if (k == null) return const SizedBox.shrink();
    final neobiota = k.rechtskategorie == Rechtskategorie.neobiotaMeldung;
    final color = neobiota ? Colors.purple : Colors.red;
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withAlpha(28),
        border: Border.all(color: color.withAlpha(120)),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Icon(neobiota ? Icons.report_gmailerrorred : Icons.warning_amber, color: color),
          const SizedBox(width: 8),
          Expanded(child: Text(neobiota ? 'Neobiota-Meldung: ${k.label}' : 'Meldepflicht aktiv: ${k.label}',
              style: TextStyle(fontWeight: FontWeight.bold, color: color))),
        ]),
        if (k.meldehinweis != null) Padding(
          padding: const EdgeInsets.only(top: 6),
          child: Text(k.meldehinweis!),
        ),
        Padding(padding: const EdgeInsets.only(top: 6),
          child: Text('Sofort: ${k.sofortmassnahme}', style: const TextStyle(fontWeight: FontWeight.w500))),
        const Padding(padding: EdgeInsets.only(top: 6),
          child: Text('Rechtshinweis ohne Gewähr — verbindlich ist die zuständige Fachstelle / BLV.',
              style: TextStyle(fontSize: 11, fontStyle: FontStyle.italic, color: Colors.grey))),
      ]),
    );
  }
}
```

- [ ] **Step 2: Analyze + Commit** — `flutter analyze lib/features/gesundheit/presentation/widgets/meldepflicht_banner.dart` → No issues.

```bash
git add lib/features/gesundheit/presentation/widgets/meldepflicht_banner.dart
git commit -m "feat(4.14): MeldepflichtBanner (rot + neobiota + Disclaimer)"
```

---

## Task 11: UI — `GesundheitSection` (Andock-Card)

**Files:**
- Create: `lib/features/gesundheit/presentation/widgets/gesundheit_section.dart`

- [ ] **Step 1: Widget schreiben** (Banner + 4.3-Nudge krankheitsscharf + Liste)

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:bienen_app/features/auth/presentation/auth_providers.dart';
import 'package:bienen_app/features/durchsicht/presentation/providers/durchsicht_provider.dart';
import 'package:bienen_app/features/gesundheit/domain/gesundheitsereignis.dart';
import 'package:bienen_app/features/gesundheit/domain/krankheit.dart';
import 'package:bienen_app/features/gesundheit/presentation/providers/gesundheit_provider.dart';
import 'package:bienen_app/features/gesundheit/presentation/widgets/meldepflicht_banner.dart';

class GesundheitSection extends ConsumerWidget {
  final String volkId;
  const GesundheitSection({super.key, required this.volkId});

  static Color _katColor(Rechtskategorie? r) => switch (r) {
        Rechtskategorie.zuBekaempfen => Colors.red,
        Rechtskategorie.zuUeberwachen => Colors.orange,
        Rechtskategorie.neobiotaMeldung => Colors.purple,
        _ => Colors.grey,
      };

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(gesundheitFuerVolkProvider(volkId));
    final aktivMelde = ref.watch(aktiveMeldepflichtProvider(volkId));
    final darf = ref.watch(darfSchreibenProvider);
    final letzte = ref.watch(letzteDurchsichtMapProvider)[volkId];

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            const Text('Gesundheit', style: TextStyle(fontWeight: FontWeight.bold)),
            const Spacer(),
            if (darf)
              TextButton.icon(
                onPressed: () => context.go('/voelker/$volkId/gesundheit'),
                icon: const Icon(Icons.medical_information_outlined, size: 18),
                label: const Text('Diagnose erfassen')),
          ]),
          // Meldepflicht-Banner (aktive zu_bekaempfen-Ereignisse)
          for (final e in aktivMelde) MeldepflichtBanner(krankheitKey: e.krankheit),
          // 4.3-Nudge: je gesundheitsrelevantem Flag der letzten Durchsicht ohne aktives Ereignis gleicher Krankheit
          if (darf && letzte != null)
            ..._nudges(context, async.valueOrNull ?? const [], letzte.auffaelligkeiten),
          async.when(
            loading: () => const Padding(padding: EdgeInsets.all(8), child: LinearProgressIndicator()),
            error: (e, _) => Padding(padding: const EdgeInsets.all(8), child: Text('Fehler: $e')),
            data: (list) => list.isEmpty
                ? const Padding(padding: EdgeInsets.all(8), child: Text('Keine Gesundheitsereignisse.'))
                : Column(children: [
                    for (final e in list.take(6))
                      ListTile(
                        dense: true,
                        leading: Icon(Icons.circle, size: 12,
                            color: e.isStorniert ? Colors.grey : _katColor(rechtskategorieVon(e.krankheit))),
                        title: Text('${katalogEintrag(e.krankheit)?.label ?? e.krankheit} · ${e.status}',
                            style: e.isStorniert
                                ? const TextStyle(decoration: TextDecoration.lineThrough, color: Colors.grey)
                                : null),
                        subtitle: Text('${e.festgestelltAm.day}.${e.festgestelltAm.month}.${e.festgestelltAm.year}'
                            '${e.isStorniert ? ' · storniert: ${e.stornoGrund ?? ''}' : ''}'),
                        trailing: (darf && !e.isStorniert)
                            ? IconButton(icon: const Icon(Icons.cancel_outlined, size: 20), tooltip: 'Stornieren',
                                onPressed: () => _storno(context, ref, e.id))
                            : null,
                      ),
                  ]),
          ),
        ]),
      ),
    );
  }

  List<Widget> _nudges(BuildContext context, List<Gesundheitsereignis> ereignisse, List<String> flags) {
    final aktiveKrankheiten =
        ereignisse.where((e) => e.istAktiv).map((e) => e.krankheit).toSet();
    final out = <Widget>[];
    final gesehen = <String>{};
    for (final flag in flags) {
      final key = durchsichtFlagZuKrankheit(flag);
      if (key == null || aktiveKrankheiten.contains(key) || !gesehen.add(key)) continue;
      final label = katalogEintrag(key)?.label ?? key;
      out.add(Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(children: [
          const Icon(Icons.info_outline, size: 16, color: Colors.blueGrey),
          const SizedBox(width: 6),
          Expanded(child: Text('Durchsicht meldete: $label', style: const TextStyle(fontSize: 13))),
          TextButton(
            onPressed: () => context.go('/voelker/$volkId/gesundheit?k=$key'),
            child: const Text('als Diagnose erfassen')),
        ]),
      ));
    }
    return out;
  }

  Future<void> _storno(BuildContext context, WidgetRef ref, String id) async {
    final ctrl = TextEditingController();
    final grund = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Diagnose stornieren'),
        content: TextField(controller: ctrl, decoration: const InputDecoration(labelText: 'Grund')),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Abbrechen')),
          FilledButton(onPressed: () => Navigator.pop(ctx, ctrl.text.trim()), child: const Text('Stornieren')),
        ],
      ),
    );
    ctrl.dispose();
    if (grund == null || grund.isEmpty || !context.mounted) return;
    try {
      await ref.read(gesundheitFuerVolkProvider(volkId).notifier).stornieren(id, grund);
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Storno fehlgeschlagen: $e')));
      }
    }
  }
}
```

- [ ] **Step 2: Analyze + Commit** — `flutter analyze lib/features/gesundheit/presentation/widgets/gesundheit_section.dart` → No issues.

```bash
git add lib/features/gesundheit/presentation/widgets/gesundheit_section.dart
git commit -m "feat(4.14): GesundheitSection (Banner + 4.3-Nudge krankheitsscharf + Storno-Liste)"
```

---

## Task 12: UI — `GesundheitFormPage`

**Files:**
- Create: `lib/features/gesundheit/presentation/pages/gesundheit_form_page.dart`

- [ ] **Step 1: Seite schreiben** (Krankheit gruppiert, Status/gemeldet_am, Fotos wie 4.3, Live-Banner)

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:bienen_app/features/auth/presentation/auth_providers.dart';
import 'package:bienen_app/features/gesundheit/domain/gesundheitsereignis.dart';
import 'package:bienen_app/features/gesundheit/domain/krankheit.dart';
import 'package:bienen_app/features/gesundheit/presentation/providers/gesundheit_provider.dart';
import 'package:bienen_app/features/gesundheit/presentation/widgets/meldepflicht_banner.dart';

class GesundheitFormPage extends ConsumerStatefulWidget {
  final String volkId;
  final String? vorbefuelltKrankheit;
  const GesundheitFormPage({super.key, required this.volkId, this.vorbefuelltKrankheit});
  @override
  ConsumerState<GesundheitFormPage> createState() => _GesundheitFormPageState();
}

const _statusWerte = ['verdacht', 'bestaetigt', 'gemeldet', 'in_behandlung', 'saniert', 'ausgeheilt', 'erloschen'];
const _statusLabels = {
  'verdacht': 'Verdacht', 'bestaetigt': 'Bestätigt', 'gemeldet': 'Gemeldet', 'in_behandlung': 'In Behandlung',
  'saniert': 'Saniert', 'ausgeheilt': 'Ausgeheilt', 'erloschen': 'Erloschen',
};

class _GesundheitFormPageState extends ConsumerState<GesundheitFormPage> {
  late String _krankheit = widget.vorbefuelltKrankheit ?? 'afb';
  DateTime _datum = DateTime.now();
  String? _schweregrad;
  String _status = 'verdacht';
  DateTime? _gemeldetAm;
  bool _labor = false;
  final _massnahme = TextEditingController();
  final _person = TextEditingController();
  final _notiz = TextEditingController();
  final _fotoPfade = <String>[];
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _person.text = Supabase.instance.client.auth.currentUser?.email ?? '';
  }

  @override
  void dispose() {
    _massnahme.dispose();
    _person.dispose();
    _notiz.dispose();
    super.dispose();
  }

  Future<void> _fotoAufnehmen() async {
    final betriebId = ref.read(currentBetriebIdProvider);
    if (betriebId == null) return;
    final file = await ImagePicker().pickImage(source: ImageSource.camera, imageQuality: 75, maxWidth: 2000);
    if (file == null || !mounted) return;
    setState(() => _busy = true);
    try {
      final bytes = await file.readAsBytes();
      final pfad = await ref.read(gesundheitGatewayProvider)
          .fotoHochladen(betriebId: betriebId, gruppeId: widget.volkId, bytes: bytes);
      if (mounted) setState(() => _fotoPfade.add(pfad));
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Foto fehlgeschlagen: $e')));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!ref.watch(darfSchreibenProvider)) {
      return Scaffold(appBar: AppBar(title: const Text('Diagnose')), body: const Center(child: Text('Nur Lesezugriff.')));
    }
    // Katalog gruppiert nach Rechtskategorie
    final gruppen = <Rechtskategorie, List<Krankheit>>{};
    for (final k in kKrankheiten) {
      gruppen.putIfAbsent(k.rechtskategorie, () => []).add(k);
    }
    const gruppenLabel = {
      Rechtskategorie.zuBekaempfen: '⚠ Meldepflichtig (zu bekämpfen)',
      Rechtskategorie.zuUeberwachen: 'Zu überwachen',
      Rechtskategorie.neobiotaMeldung: 'Neobiota (Meldung)',
      Rechtskategorie.nichtMeldepflichtig: 'Nicht meldepflichtig',
    };
    final k = katalogEintrag(_krankheit);

    return Scaffold(
      appBar: AppBar(title: const Text('Diagnose erfassen')),
      body: ListView(padding: const EdgeInsets.all(16), children: [
        DropdownButtonFormField<String>(
          initialValue: _krankheit,
          decoration: const InputDecoration(labelText: 'Krankheit / Schädling'),
          items: [
            for (final r in [Rechtskategorie.zuBekaempfen, Rechtskategorie.zuUeberwachen,
                             Rechtskategorie.neobiotaMeldung, Rechtskategorie.nichtMeldepflichtig])
              if (gruppen[r] != null) ...[
                DropdownMenuItem<String>(enabled: false, child: Text(gruppenLabel[r]!,
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Colors.grey))),
                for (final e in gruppen[r]!) DropdownMenuItem(value: e.key, child: Text('   ${e.label}')),
              ],
          ],
          onChanged: (v) => setState(() => _krankheit = v!),
        ),
        MeldepflichtBanner(krankheitKey: _krankheit),
        if (k != null && !istMeldepflichtig(_krankheit)) Padding(
          padding: const EdgeInsets.symmetric(vertical: 6),
          child: Text('${k.leitsymptome}\nMaßnahme: ${k.sofortmassnahme}',
              style: const TextStyle(fontSize: 12, color: Colors.grey)),
        ),
        ListTile(
          contentPadding: EdgeInsets.zero,
          title: Text('Festgestellt: ${_datum.day}.${_datum.month}.${_datum.year}'),
          trailing: const Icon(Icons.calendar_today),
          onTap: () async {
            final d = await showDatePicker(context: context, initialDate: _datum,
                firstDate: DateTime(2020), lastDate: DateTime.now());
            if (d != null) setState(() => _datum = d);
          },
        ),
        DropdownButtonFormField<String?>(
          initialValue: _schweregrad,
          decoration: const InputDecoration(labelText: 'Schweregrad (optional)'),
          items: const [
            DropdownMenuItem(value: null, child: Text('—')),
            DropdownMenuItem(value: 'leicht', child: Text('leicht')),
            DropdownMenuItem(value: 'mittel', child: Text('mittel')),
            DropdownMenuItem(value: 'schwer', child: Text('schwer')),
          ],
          onChanged: (v) => setState(() => _schweregrad = v),
        ),
        DropdownButtonFormField<String>(
          initialValue: _status,
          decoration: const InputDecoration(labelText: 'Status'),
          items: [for (final s in _statusWerte) DropdownMenuItem(value: s, child: Text(_statusLabels[s]!))],
          onChanged: (v) => setState(() {
            _status = v!;
            if (_status == 'gemeldet' && _gemeldetAm == null) _gemeldetAm = DateTime.now();
          }),
        ),
        if (_status == 'gemeldet')
          ListTile(
            contentPadding: EdgeInsets.zero,
            title: Text('Gemeldet am: ${_gemeldetAm == null ? '—' : '${_gemeldetAm!.day}.${_gemeldetAm!.month}.${_gemeldetAm!.year}'}'),
            trailing: const Icon(Icons.calendar_today),
            onTap: () async {
              final d = await showDatePicker(context: context, initialDate: _gemeldetAm ?? _datum,
                  firstDate: _datum, lastDate: DateTime.now());
              if (d != null) setState(() => _gemeldetAm = d);
            },
          ),
        SwitchListTile(contentPadding: EdgeInsets.zero, title: const Text('Probe ans Labor eingesandt'),
            value: _labor, onChanged: (v) => setState(() => _labor = v)),
        TextField(controller: _massnahme, decoration: const InputDecoration(labelText: 'Maßnahme')),
        TextField(controller: _person, decoration: const InputDecoration(labelText: 'Verantwortliche Person')),
        TextField(controller: _notiz, decoration: const InputDecoration(labelText: 'Notiz')),
        const SizedBox(height: 12),
        Row(children: [
          OutlinedButton.icon(onPressed: _busy ? null : _fotoAufnehmen,
              icon: const Icon(Icons.add_a_photo), label: const Text('Foto')),
          const SizedBox(width: 12),
          Text('${_fotoPfade.length} Foto(s)'),
        ]),
        const SizedBox(height: 16),
        FilledButton.icon(
          onPressed: _busy ? null : _speichern,
          icon: const Icon(Icons.save),
          label: Text(_busy ? 'Speichert…' : 'Diagnose speichern'),
        ),
      ]),
    );
  }

  Future<void> _speichern() async {
    if (_status == 'gemeldet' && _gemeldetAm == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Bei Status „gemeldet" bitte das Melde-Datum setzen.')));
      return;
    }
    setState(() => _busy = true);
    try {
      await ref.read(gesundheitFuerVolkProvider(widget.volkId).notifier).speichern(Gesundheitsereignis(
            id: '', volkId: widget.volkId, festgestelltAm: _datum, krankheit: _krankheit,
            schweregrad: _schweregrad, status: _status, gemeldetAm: _status == 'gemeldet' ? _gemeldetAm : null,
            laborEingesandt: _labor, fotoUrls: _fotoPfade,
            massnahme: _massnahme.text.trim().isEmpty ? null : _massnahme.text.trim(),
            verantwortlichePerson: _person.text.trim().isEmpty ? null : _person.text.trim(),
            notiz: _notiz.text.trim().isEmpty ? null : _notiz.text.trim(),
          ));
      if (mounted) context.pop();
    } catch (e) {
      if (mounted) {
        setState(() => _busy = false);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Fehler: $e')));
      }
    }
  }
}
```

- [ ] **Step 2: Analyze + Commit** — `flutter analyze lib/features/gesundheit/presentation/pages/gesundheit_form_page.dart` → No issues.

```bash
git add lib/features/gesundheit/presentation/pages/gesundheit_form_page.dart
git commit -m "feat(4.14): GesundheitFormPage (Katalog gruppiert, Status/gemeldet_am, Fotos, Live-Banner)"
```

---

## Task 13: Verdrahtung — Detailseite andocken + Route

**Files:**
- Modify: `lib/features/voelker/presentation/pages/volk_detail_page.dart`
- Modify: `lib/core/router/app_router.dart`

- [ ] **Step 1: `GesundheitSection` in die Detailseite einfügen**

Import ergänzen:

```dart
import 'package:bienen_app/features/gesundheit/presentation/widgets/gesundheit_section.dart';
```

Im `ListView` direkt nach `FuetterungSection(volkId: volk.id),` einfügen:

```dart
              GesundheitSection(volkId: volk.id),
```

- [ ] **Step 2: Route registrieren** (mit optionalem `?k=<krankheit>`-Query fürs Vorbefüllen)

Import ergänzen:

```dart
import 'package:bienen_app/features/gesundheit/presentation/pages/gesundheit_form_page.dart';
```

Unter `/voelker/:id` (nach der `fuetterung`-Route) einfügen:

```dart
                GoRoute(
                  path: 'gesundheit',
                  builder: (c, s) => GesundheitFormPage(
                    volkId: s.pathParameters['id']!,
                    vorbefuelltKrankheit: s.uri.queryParameters['k'],
                  ),
                ),
```

- [ ] **Step 3: Build-Check + Commit** — `flutter analyze lib/features/voelker/presentation/pages/volk_detail_page.dart lib/core/router/app_router.dart` → No issues.

```bash
git add lib/features/voelker/presentation/pages/volk_detail_page.dart lib/core/router/app_router.dart
git commit -m "feat(4.14): GesundheitSection andocken + Route /gesundheit (?k=vorbefuellen)"
```

---

## Task 14: Abschluss — Analyze, Tests, Deploy 1.13.0

**Files:**
- Modify: `pubspec.yaml`

- [ ] **Step 1: Voller Analyze** — `flutter analyze` → `No issues found!`
- [ ] **Step 2: Volle Testsuite** — `flutter test` → alle grün.
- [ ] **Step 3: Version bumpen** — `pubspec.yaml`: `version: 1.13.0+31`.
- [ ] **Step 4: Commit + Deploy** (stehende Freigabe)

```bash
git add pubspec.yaml
git commit -m "chore(4.14): Version 1.13.0+31"
git checkout master
git merge --no-ff feat/gesundheit -m "feat: Modul 4.14 Gesundheit/Schädlinge v1.13.0"
git push origin master
bash deploy.sh
```

- [ ] **Step 5: Live-Verifikation** — App laden, Volk öffnen, „Gesundheit"-Sektion: Diagnose `afb` → roter Meldepflicht-Banner + Disclaimer; Foto; Storno → durchgestrichen; Nudge aus einer Durchsicht mit `faulbrut_verdacht`. `deploy.sh` verifiziert den Live-Flip selbst (version.json).

---

## Self-Review-Notizen (Plan ↔ Spec)

- **Spec-Abdeckung:** §4.1 Katalog → Task 3. §4.2 Tabelle (RESTRICT/CHECKs/gemeldet/Zukunft/keine DELETE) → Task 1. §4.3 Bucket → Task 2. §5 Ableitungen (istMeldepflichtig/durchsichtFlag/istAktiv/aktiveMeldepflicht/Nudge) → Tasks 3,4,8,11. §6 Gateway/State/UI → Tasks 5,6,7,8,10,11,12. §6 Andocken → Task 13. §7 Deploy → Task 14. §8 Tests (Parität M3, SQL-CHECKs, Fake-Foto-No-Op, signOut) → Tasks 1,3,4,6,8,9. Alle abgedeckt.
- **M-Abdeckung:** M1 (kanton-neutral + `_meldeInspektor`-Konstante + kein-GR-Test) Task 3. M2 (gemeldet-CHECK + SQL-Test) Task 1. M3 (Paritätstest) Task 3. M4 (vergiftung/tracheenmilbe) Task 3. M5 (Steinbrut/Sackbrut-Texte) Task 3. M6 (Nudge krankheitsscharf, gruppeId=volkId, FotoSpeicher 2-arg) Tasks 11/7/12. M7 (Zukunfts-CHECK) Task 1. M9 (Disclaimer) Task 10. M11 (Fake-Foto-No-Op) Task 6.
- **Typkonsistenz:** `Gesundheitsereignis`-Felder (`festgestelltAm`, `gemeldetAm`, `fotoUrls`, `istAktiv`) konsistent Modell (4) ↔ Fake (6) ↔ Provider (8) ↔ UI (11/12). Gateway-Signatur (`speichern`/`stornieren`/`foto*`) identisch Gateway (5) ↔ Fake (6) ↔ Supabase (7). `rechtskategorieVon`/`istMeldepflichtig`/`katalogEintrag`/`durchsichtFlagZuKrankheit`/`krankheitKeys` konsistent Task 3 ↔ 8/11/12.
- **Verifiziert gegen Codebasis:** `FotoSpeicher(client, bucket)` + `hochladen({betriebId, gruppeId, bytes})`; `currentBetriebIdProvider`, `darfSchreibenProvider`, `letzteDurchsichtMapProvider`; `ImagePicker().pickImage(...)`; `.withAlpha(int)`; `initialValue:`; `DropdownMenuItem(enabled: false, …)` für Gruppen-Header.
```
