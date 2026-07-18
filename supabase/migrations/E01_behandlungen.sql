-- E01_behandlungen.sql | Varroa-Milbendiagnose + TAMV-Behandlungsjournal (amtliche Pflichtdaten).
-- varroa_kontrollen: normale CRUD (kein Pflichtjournal), Komposit-FK ON DELETE CASCADE.
-- behandlungen: revisionssicher -> FK volk_id ON DELETE RESTRICT (Volk mit Journal hart-loeschsicher,
--   TAMV Art. 29), material_id ON DELETE SET NULL (material_id) spaltenqualifiziert (unqualifiziert
--   wuerde auch betrieb_id nullen!), KEINE INSERT-Policy (Insert nur via RPC E02), KEINE DELETE-Policy,
--   BEFORE-UPDATE-Trigger friert Kernfelder ein + Einweg-Storno + server-seitiges storno_am.
-- Errcodes BA030-039 = Modul 4.5.

-- 4.0 materials: Komposit-FK-Ziel fuer behandlungen.material_id
alter table public.materials
  add constraint materials_betrieb_id_id_key unique (betrieb_id, id);

-- 4.1 varroa_kontrollen (Milbendiagnose)
create table if not exists public.varroa_kontrollen (
  id uuid primary key default gen_random_uuid(),
  volk_id uuid not null,
  durchgefuehrt_am date not null default current_date,
  methode text not null check (methode in ('gemuell','puderzucker','auswaschung')),
  messdauer_tage int check (messdauer_tage is null or messdauer_tage >= 1),
  milben_gesamt int not null check (milben_gesamt >= 0),
  bienen_probe int check (bienen_probe is null or bienen_probe >= 1),
  notiz text,
  betrieb_id uuid not null default private.aktive_betrieb_id()
    references public.betriebe(id) on delete cascade,
  created_by uuid, updated_by uuid,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (betrieb_id, id),
  constraint varroa_kontrollen_volk_fk
    foreign key (betrieb_id, volk_id) references public.voelker (betrieb_id, id) on delete cascade
);
alter table public.varroa_kontrollen enable row level security;
revoke all on public.varroa_kontrollen from anon, public;
grant select, insert, update, delete on public.varroa_kontrollen to authenticated;
create index if not exists idx_varroa_kontrollen_volk_datum
  on public.varroa_kontrollen (betrieb_id, volk_id, durchgefuehrt_am desc);
drop trigger if exists trg_varroa_kontrollen_actor on public.varroa_kontrollen;
create trigger trg_varroa_kontrollen_actor before insert or update
  on public.varroa_kontrollen for each row execute function private.set_row_actor();
drop trigger if exists trg_varroa_kontrollen_updated on public.varroa_kontrollen;
create trigger trg_varroa_kontrollen_updated before update
  on public.varroa_kontrollen for each row execute function private.set_updated_at();
drop policy if exists varroa_kontrollen_sel_member on public.varroa_kontrollen;
create policy varroa_kontrollen_sel_member on public.varroa_kontrollen
  for select to authenticated using (betrieb_id in (select private.meine_betrieb_ids()));
drop policy if exists varroa_kontrollen_ins_writer on public.varroa_kontrollen;
create policy varroa_kontrollen_ins_writer on public.varroa_kontrollen
  for insert to authenticated with check (private.kann_schreiben(betrieb_id));
drop policy if exists varroa_kontrollen_upd_writer on public.varroa_kontrollen;
create policy varroa_kontrollen_upd_writer on public.varroa_kontrollen
  for update to authenticated using (private.kann_schreiben(betrieb_id))
  with check (private.kann_schreiben(betrieb_id));
drop policy if exists varroa_kontrollen_del_writer on public.varroa_kontrollen;
create policy varroa_kontrollen_del_writer on public.varroa_kontrollen
  for delete to authenticated using (private.kann_schreiben(betrieb_id));

-- 4.2 behandlungen (amtliches Journal, revisionssicher)
create table if not exists public.behandlungen (
  id uuid primary key default gen_random_uuid(),
  volk_id uuid not null,
  datum_beginn date not null default current_date,
  datum_ende date,
  praeparat text,
  wirkstoff text not null
    check (wirkstoff in ('ameisensaeure','oxalsaeure','milchsaeure','thymol','kombi_os_as','sonstige')),
  menge_pro_volk numeric check (menge_pro_volk is null or menge_pro_volk >= 0),
  einheit text check (einheit in ('ml','g','stueck')),
  konzentration text,
  anwendungsart text not null
    check (anwendungsart in ('traeufeln','spruehen','verdampfen','dispenser_verdunster',
                             'streifen_langzeit','schwammtuch','biotechnik','waermebehandlung')),
  indikation text,
  aussentemperatur_c numeric,
  wartefrist_tage int check (wartefrist_tage is null or wartefrist_tage >= 0),
  charge text,
  verantwortliche_person text not null,
  material_id uuid,
  is_storniert boolean not null default false,
  storno_grund text,
  storno_am date,
  notiz text,
  betrieb_id uuid not null default private.aktive_betrieb_id()
    references public.betriebe(id) on delete cascade,
  created_by uuid, updated_by uuid,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (betrieb_id, id),
  constraint behandlungen_volk_fk
    foreign key (betrieb_id, volk_id) references public.voelker (betrieb_id, id) on delete restrict,
  constraint behandlungen_material_fk
    foreign key (betrieb_id, material_id) references public.materials (betrieb_id, id)
    on delete set null (material_id),
  constraint behandlungen_praeparat_chk
    check (anwendungsart in ('biotechnik','waermebehandlung')
           or (praeparat is not null and btrim(praeparat) <> '')),
  constraint behandlungen_menge_chk
    check (anwendungsart in ('biotechnik','waermebehandlung')
           or (menge_pro_volk is not null and menge_pro_volk > 0 and einheit is not null)),
  constraint behandlungen_datum_chk
    check (datum_ende is null or datum_ende >= datum_beginn),
  constraint behandlungen_storno_chk
    check (is_storniert = false or (storno_grund is not null and storno_am is not null)),
  constraint behandlungen_storno_datum_chk
    check (storno_am is null or storno_am >= datum_beginn)
);
alter table public.behandlungen enable row level security;
revoke all on public.behandlungen from anon, public;
-- KEIN insert (nur via security-definer-RPC), KEIN delete (kein Hard-Delete):
grant select, update on public.behandlungen to authenticated;
create index if not exists idx_behandlungen_volk_datum
  on public.behandlungen (betrieb_id, volk_id, datum_beginn desc);
create index if not exists idx_behandlungen_material
  on public.behandlungen (betrieb_id, material_id);

drop trigger if exists trg_behandlungen_actor on public.behandlungen;
create trigger trg_behandlungen_actor before insert or update
  on public.behandlungen for each row execute function private.set_row_actor();
drop trigger if exists trg_behandlungen_updated on public.behandlungen;
create trigger trg_behandlungen_updated before update
  on public.behandlungen for each row execute function private.set_updated_at();

-- Revisionssicherheit: Kernfelder unveraenderlich, Einweg-Storno, server-seitiges storno_am.
create or replace function private.behandlungen_schutz()
  returns trigger language plpgsql security definer set search_path = '' as $$
begin
  if old.is_storniert then
    raise exception 'Stornierter Journaleintrag ist unveraenderlich' using errcode='BA034';
  end if;
  if new.is_storniert is distinct from old.is_storniert and new.is_storniert = false then
    raise exception 'Storno kann nicht rueckgaengig gemacht werden' using errcode='BA034';
  end if;
  if new.volk_id is distinct from old.volk_id
     or new.datum_beginn is distinct from old.datum_beginn
     or new.datum_ende is distinct from old.datum_ende
     or new.praeparat is distinct from old.praeparat
     or new.wirkstoff is distinct from old.wirkstoff
     or new.menge_pro_volk is distinct from old.menge_pro_volk
     or new.einheit is distinct from old.einheit
     or new.konzentration is distinct from old.konzentration
     or new.anwendungsart is distinct from old.anwendungsart
     or new.indikation is distinct from old.indikation
     or new.aussentemperatur_c is distinct from old.aussentemperatur_c
     or new.wartefrist_tage is distinct from old.wartefrist_tage
     or new.charge is distinct from old.charge
     or new.verantwortliche_person is distinct from old.verantwortliche_person
     or new.material_id is distinct from old.material_id then
    raise exception 'Amtliche Kernfelder sind unveraenderlich (Korrektur = Storno + Neueintrag)'
      using errcode='BA034';
  end if;
  if new.is_storniert and not old.is_storniert then
    new.storno_am := current_date; -- server-seitig, Client-Wert ignorieren
  end if;
  return new;
end; $$;
drop trigger if exists trg_behandlungen_schutz on public.behandlungen;
create trigger trg_behandlungen_schutz before update on public.behandlungen
  for each row execute function private.behandlungen_schutz();

drop policy if exists behandlungen_sel_member on public.behandlungen;
create policy behandlungen_sel_member on public.behandlungen
  for select to authenticated using (betrieb_id in (select private.meine_betrieb_ids()));
drop policy if exists behandlungen_upd_writer on public.behandlungen;
create policy behandlungen_upd_writer on public.behandlungen
  for update to authenticated using (private.kann_schreiben(betrieb_id))
  with check (private.kann_schreiben(betrieb_id));
-- BEWUSST keine behandlungen_ins_* und keine behandlungen_del_* Policy.
