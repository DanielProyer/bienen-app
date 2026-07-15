-- A06_rpcs.sql | Selbst-Gruendung + code-basierte Einladungen (Muster KMU 0012/0013).
-- Stabile errcodes BA0xx (Client matcht Codes, nie Prosa). DEFINER umgeht das RLS-Henne-Ei.

-- Owner-Guard: Betrieb des Aufrufers + Owner-Pruefung.
create or replace function public.eigener_betrieb_als_owner() returns uuid
  language plpgsql stable set search_path = '' as $$
declare v_betrieb uuid; v_rolle public.betrieb_rolle;
begin
  select bm.betrieb_id, bm.rolle into v_betrieb, v_rolle
    from public.betrieb_mitglieder bm
   where bm.user_id = auth.uid() and bm.is_deleted = false
   order by bm.created_at limit 1;
  if v_betrieb is null then raise exception 'Kein Betrieb zugeordnet' using errcode='BA004'; end if;
  if v_rolle <> 'owner' then
    raise exception 'Nur Owner duerfen Mitglieder verwalten' using errcode='BA010';
  end if;
  return v_betrieb;
end; $$;
revoke execute on function public.eigener_betrieb_als_owner() from anon, public;
grant execute on function public.eigener_betrieb_als_owner() to authenticated;

-- Selbst-Gruendung: atomar Betrieb + owner-Mitgliedschaft.
create or replace function public.betrieb_gruenden(p_name text) returns uuid
  language plpgsql security definer set search_path = '' as $$
declare v_user uuid := auth.uid(); v_betrieb uuid;
begin
  if v_user is null then raise exception 'Nicht angemeldet' using errcode='BA001'; end if;
  if coalesce(trim(p_name),'') = '' then raise exception 'Name darf nicht leer sein' using errcode='BA002'; end if;
  perform pg_advisory_xact_lock(hashtextextended('betrieb_gruenden:'||v_user::text, 0));
  if exists (select 1 from public.betrieb_mitglieder where user_id=v_user and is_deleted=false) then
    raise exception 'Du gehoerst bereits zu einem Betrieb' using errcode='BA003';
  end if;
  insert into public.betriebe (name) values (trim(p_name)) returning id into v_betrieb;
  insert into public.betrieb_mitglieder (betrieb_id,user_id,rolle) values (v_betrieb,v_user,'owner');
  return v_betrieb;
end; $$;
revoke execute on function public.betrieb_gruenden(text) from anon, public;
grant execute on function public.betrieb_gruenden(text) to authenticated;

-- Einladen: erzeugt 12-Zeichen-Code (Crockford-Base32), speichert NUR den Hash,
-- gibt Klartext EINMALIG zurueck. Owner kann editor/viewer einladen.
create or replace function public.mitglied_einladen(p_email text, p_rolle public.betrieb_rolle)
  returns text language plpgsql security definer set search_path = '' as $$
declare
  v_betrieb uuid; v_email text := lower(trim(p_email));
  v_code text := ''; v_alphabet constant text := '0123456789ABCDEFGHJKMNPQRSTVWXYZ';
  v_bytes bytea; i int;
begin
  v_betrieb := public.eigener_betrieb_als_owner();  -- BA004/BA010
  if v_email = '' or position('@' in v_email) = 0 then
    raise exception 'E-Mail fehlt oder ist ungueltig' using errcode='BA012';
  end if;
  if p_rolle is null or p_rolle not in ('editor'::public.betrieb_rolle,'viewer'::public.betrieb_rolle) then
    raise exception 'Diese Rolle kann nicht eingeladen werden' using errcode='BA010';
  end if;
  update public.einladungen set status='widerrufen'
    where betrieb_id=v_betrieb and lower(email)=v_email and status='offen';
  v_bytes := extensions.gen_random_bytes(12);
  for i in 0..11 loop
    v_code := v_code || substr(v_alphabet, (get_byte(v_bytes,i) % 32) + 1, 1);
  end loop;
  insert into public.einladungen (betrieb_id,email,rolle,code_hash,eingeladen_von)
    values (v_betrieb, v_email, p_rolle,
            encode(extensions.digest(v_code,'sha256'),'hex'), auth.uid());
  return substr(v_code,1,4)||'-'||substr(v_code,5,4)||'-'||substr(v_code,9,4);
end; $$;
revoke execute on function public.mitglied_einladen(text, public.betrieb_rolle) from anon, public;
grant execute on function public.mitglied_einladen(text, public.betrieb_rolle) to authenticated;

-- Annehmen: DEFINER (Aufrufer ist noch membership-los). Eigentumsnachweis via auth.email().
create or replace function public.einladung_annehmen(p_code text)
  returns void language plpgsql security definer set search_path = '' as $$
declare
  v_user uuid := auth.uid(); v_email text := lower(coalesce(auth.email(),''));
  v_norm text := upper(replace(replace(trim(p_code),'-',''),' ',''));
  v_einladung public.einladungen%rowtype;
begin
  if v_user is null then raise exception 'Nicht angemeldet' using errcode='BA001'; end if;
  select * into v_einladung from public.einladungen
    where code_hash = encode(extensions.digest(v_norm,'sha256'),'hex');
  if v_einladung.id is null or v_einladung.status <> 'offen' or v_einladung.ablauf_am < now() then
    raise exception 'Einladungs-Code ungueltig oder abgelaufen' using errcode='BA007';
  end if;
  if lower(v_einladung.email) <> v_email then
    raise exception 'Dieses Konto gehoert nicht zur eingeladenen E-Mail' using errcode='BA008';
  end if;
  perform pg_advisory_xact_lock(hashtextextended('betrieb_gruenden:'||v_user::text, 0));
  if exists (select 1 from public.betrieb_mitglieder where user_id=v_user and is_deleted=false) then
    raise exception 'Du gehoerst bereits zu einem Betrieb' using errcode='BA009';
  end if;
  update public.einladungen set status='angenommen', angenommen_von=v_user
    where id=v_einladung.id and status='offen';
  if not found then raise exception 'Einladungs-Code ungueltig oder abgelaufen' using errcode='BA007'; end if;
  insert into public.betrieb_mitglieder (betrieb_id,user_id,rolle)
    values (v_einladung.betrieb_id, v_user, v_einladung.rolle);
end; $$;
revoke execute on function public.einladung_annehmen(text) from anon, public;
grant execute on function public.einladung_annehmen(text) to authenticated;

create or replace function public.einladung_widerrufen(p_id uuid)
  returns void language plpgsql security definer set search_path = '' as $$
declare v_betrieb uuid;
begin
  v_betrieb := public.eigener_betrieb_als_owner();
  update public.einladungen set status='widerrufen'
    where id=p_id and betrieb_id=v_betrieb and status='offen';
  if not found then raise exception 'Einladung nicht gefunden oder nicht mehr offen' using errcode='BA007'; end if;
end; $$;
revoke execute on function public.einladung_widerrufen(uuid) from anon, public;
grant execute on function public.einladung_widerrufen(uuid) to authenticated;

-- Team-Liste inkl. E-Mail (jedes Mitglied sieht sein Team).
create or replace function public.team_mitglieder()
  returns table (user_id uuid, email text, rolle public.betrieb_rolle, created_at timestamptz)
  language plpgsql stable security definer set search_path = '' as $$
declare v_betrieb uuid;
begin
  select bm.betrieb_id into v_betrieb from public.betrieb_mitglieder bm
    where bm.user_id = auth.uid() and bm.is_deleted = false
    order by bm.created_at limit 1;
  if v_betrieb is null then raise exception 'Kein Betrieb zugeordnet' using errcode='BA004'; end if;
  return query
    select bm.user_id, p.email, bm.rolle, bm.created_at
      from public.betrieb_mitglieder bm
      join public.profiles p on p.id = bm.user_id
     where bm.betrieb_id = v_betrieb and bm.is_deleted = false
     order by bm.created_at;
end; $$;
revoke execute on function public.team_mitglieder() from anon, public;
grant execute on function public.team_mitglieder() to authenticated;

-- Schutz gegen verwaisten Betrieb: letzter owner nicht entfernbar/degradierbar.
create or replace function private.enforce_last_owner() returns trigger
  language plpgsql security definer set search_path = '' as $$
declare v_betrieb uuid; v_owner_count int;
begin
  if tg_op = 'DELETE' then
    if old.rolle <> 'owner' then return old; end if;
    if not exists (select 1 from public.betriebe b where b.id = old.betrieb_id) then
      return old;  -- Cascade-Loeschung des Betriebs: durchlassen
    end if;
    v_betrieb := old.betrieb_id;
  else -- UPDATE
    -- Guard greift, wenn eine AKTIVE owner-Zeile ihren Aktiv-owner-Status verliert —
    -- egal ob durch Rollen-Degradierung ODER Soft-Delete (is_deleted false->true).
    if not (old.rolle = 'owner' and old.is_deleted = false) then return new; end if;  -- war kein aktiver Owner
    if new.rolle = 'owner' and new.is_deleted = false then return new; end if;         -- bleibt aktiver Owner
    v_betrieb := old.betrieb_id;
  end if;
  select count(*) into v_owner_count from public.betrieb_mitglieder m
    where m.betrieb_id = v_betrieb and m.rolle = 'owner' and m.is_deleted = false
      and not (m.betrieb_id = old.betrieb_id and m.user_id = old.user_id);
  if v_owner_count = 0 then
    raise exception 'Letzter Owner des Betriebs kann nicht entfernt/degradiert werden'
      using errcode = 'BA013';
  end if;
  return case when tg_op='DELETE' then old else new end;
end; $$;
create trigger trg_enforce_last_owner
  before update or delete on public.betrieb_mitglieder
  for each row execute function private.enforce_last_owner();
