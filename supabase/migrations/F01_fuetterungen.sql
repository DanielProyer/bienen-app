-- F01_fuetterungen.sql | Fütterungs-Log (Bio-Nachweis) + Winterfutter-Ziel.
-- fuetterungen: Soft-Delete/Storno (KEIN Immutable-Trigger, anders als 4.5), aber volk-FK RESTRICT
--   (M1: schützt die Audit-Spur auch übers Elternvolk) + keine INSERT/DELETE-Policy (Insert nur via RPC F02).
-- betriebs_einstellungen: winterfutter_ziel_kg (F4-Parameter, Default 22, CHECK > 0).
-- Errcodes BA040-049 = Modul 4.6.

alter table public.betriebs_einstellungen
  add column if not exists winterfutter_ziel_kg numeric not null default 22
    check (winterfutter_ziel_kg > 0);

create table if not exists public.fuetterungen (
  id uuid primary key default gen_random_uuid(),
  volk_id uuid not null,
  durchgefuehrt_am date not null default current_date,
  zweck text not null check (zweck in ('auffuetterung','reizfuetterung','notfuetterung')),
  futterart text not null
    check (futterart in ('zuckersirup','zuckerwasser','futterteig','futterwaben','honig','sonstige')),
  bio_zertifiziert boolean not null default false,
  menge_pro_volk_kg numeric not null check (menge_pro_volk_kg > 0),
  material_id uuid,
  verantwortliche_person text,
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
  constraint fuetterungen_volk_fk
    foreign key (betrieb_id, volk_id) references public.voelker (betrieb_id, id) on delete restrict,
  constraint fuetterungen_material_fk
    foreign key (betrieb_id, material_id) references public.materials (betrieb_id, id)
    on delete set null (material_id),
  constraint fuetterungen_storno_chk
    check (is_storniert = false or (storno_grund is not null and storno_am is not null)),
  constraint fuetterungen_storno_datum_chk
    check (storno_am is null or storno_am >= durchgefuehrt_am)
);
alter table public.fuetterungen enable row level security;
revoke all on public.fuetterungen from anon, public;
-- KEIN insert (nur via RPC F02), KEIN delete (Soft-Delete):
grant select, update on public.fuetterungen to authenticated;
create index if not exists idx_fuetterungen_volk_datum
  on public.fuetterungen (betrieb_id, volk_id, durchgefuehrt_am desc);
create index if not exists idx_fuetterungen_material
  on public.fuetterungen (betrieb_id, material_id);

drop trigger if exists trg_fuetterungen_actor on public.fuetterungen;
create trigger trg_fuetterungen_actor before insert or update
  on public.fuetterungen for each row execute function private.set_row_actor();
drop trigger if exists trg_fuetterungen_updated on public.fuetterungen;
create trigger trg_fuetterungen_updated before update
  on public.fuetterungen for each row execute function private.set_updated_at();

drop policy if exists fuetterungen_sel_member on public.fuetterungen;
create policy fuetterungen_sel_member on public.fuetterungen
  for select to authenticated using (betrieb_id in (select private.meine_betrieb_ids()));
drop policy if exists fuetterungen_upd_writer on public.fuetterungen;
create policy fuetterungen_upd_writer on public.fuetterungen
  for update to authenticated using (private.kann_schreiben(betrieb_id))
  with check (private.kann_schreiben(betrieb_id));
-- BEWUSST keine fuetterungen_ins_* und keine fuetterungen_del_* Policy.
