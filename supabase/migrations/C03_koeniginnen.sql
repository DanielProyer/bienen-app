-- C03_koeniginnen.sql | Koeniginnen-Register + Zuordnungs-Spur (volk_id/zugeordnet_am/ersetzt_am).
-- volk_id-FK folgt in C04 (braucht voelker.unique(betrieb_id,id)). Self-FK mutter_koenigin_id
-- komposit gegen Cross-Tenant.

create table if not exists public.koeniginnen (
  id            uuid primary key default gen_random_uuid(),
  kennung       text,
  schlupfjahr   int,
  rasse         text,
  linie         text,
  herkunft      text,
  begattungsart text not null default 'unbekannt'
                  check (begattungsart in ('standbegattung','belegstelle','instrumentell','unbekannt')),
  status        text not null default 'aktiv'
                  check (status in ('aktiv','ersetzt','tot','verschollen')),
  volk_id       uuid,            -- Historien-Spur; FK in C04
  zugeordnet_am date,
  ersetzt_am    date,
  mutter_koenigin_id uuid,
  notes         text,
  betrieb_id    uuid not null default private.aktive_betrieb_id()
                  references public.betriebe(id) on delete cascade,
  created_by uuid, updated_by uuid,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (betrieb_id, id),
  constraint koeniginnen_mutter_fk
    foreign key (betrieb_id, mutter_koenigin_id)
    references public.koeniginnen (betrieb_id, id) on delete set null (mutter_koenigin_id)
);

alter table public.koeniginnen enable row level security;
revoke all on public.koeniginnen from anon, public;
grant select, insert, update, delete on public.koeniginnen to authenticated;
create index if not exists idx_koeniginnen_betrieb_status on public.koeniginnen (betrieb_id, status);
create index if not exists idx_koeniginnen_volk on public.koeniginnen (volk_id);
create index if not exists idx_koeniginnen_mutter on public.koeniginnen (mutter_koenigin_id);

drop trigger if exists trg_koeniginnen_actor on public.koeniginnen;
create trigger trg_koeniginnen_actor before insert or update
  on public.koeniginnen for each row execute function private.set_row_actor();
drop trigger if exists trg_koeniginnen_updated on public.koeniginnen;
create trigger trg_koeniginnen_updated before update
  on public.koeniginnen for each row execute function private.set_updated_at();

drop policy if exists koeniginnen_sel_member on public.koeniginnen;
create policy koeniginnen_sel_member on public.koeniginnen
  for select to authenticated using (betrieb_id in (select private.meine_betrieb_ids()));
drop policy if exists koeniginnen_ins_writer on public.koeniginnen;
create policy koeniginnen_ins_writer on public.koeniginnen
  for insert to authenticated with check (private.kann_schreiben(betrieb_id));
drop policy if exists koeniginnen_upd_writer on public.koeniginnen;
create policy koeniginnen_upd_writer on public.koeniginnen
  for update to authenticated using (private.kann_schreiben(betrieb_id))
  with check (private.kann_schreiben(betrieb_id));
drop policy if exists koeniginnen_del_writer on public.koeniginnen;
create policy koeniginnen_del_writer on public.koeniginnen
  for delete to authenticated using (private.kann_schreiben(betrieb_id));
