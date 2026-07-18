-- F02_rpc_fuetterung_erfassen.sql | Einziger Schreibpfad in den Fütterungs-Log.
-- distinct Voelker -> je 1 Zeile; Lager-Abbuchung menge_pro_volk_kg × ROW_COUNT; betrieb_id explizit.
-- BA040 Pflichtfeld/Enum (Enums IN der RPC geprueft -> kein roher 23514), BA041 Voelker, BA042 Material.

create or replace function public.fuetterung_erfassen(
  p_volk_ids uuid[],
  p_durchgefuehrt_am date,
  p_zweck text,
  p_futterart text,
  p_menge_pro_volk_kg numeric,
  p_bio_zertifiziert boolean,
  p_material_id uuid default null,
  p_verantwortliche_person text default null,
  p_notiz text default null
) returns int
  language plpgsql security definer set search_path = '' as $$
declare
  v_betrieb uuid; v_betriebe uuid[]; v_found int; v_n int;
begin
  if p_volk_ids is null or cardinality(p_volk_ids) = 0 then
    raise exception 'Keine Voelker angegeben' using errcode='BA041';
  end if;

  select array_agg(distinct betrieb_id), count(distinct id) into v_betriebe, v_found
    from public.voelker where id = any(p_volk_ids);
  if v_found is null
     or v_found <> cardinality(array(select distinct unnest(p_volk_ids)))
     or coalesce(array_length(v_betriebe,1),0) <> 1 then
    raise exception 'Volk nicht gefunden oder gehoert nicht zu deinem Betrieb' using errcode='BA041';
  end if;
  v_betrieb := v_betriebe[1];
  if not private.kann_schreiben(v_betrieb) then
    raise exception 'Keine Schreibberechtigung fuer diesen Betrieb' using errcode='BA041';
  end if;

  if p_durchgefuehrt_am is null
     or p_zweck not in ('auffuetterung','reizfuetterung','notfuetterung')
     or p_futterart not in ('zuckersirup','zuckerwasser','futterteig','futterwaben','honig','sonstige')
     or p_menge_pro_volk_kg is null or p_menge_pro_volk_kg <= 0 then
    raise exception 'Pflichtfeld fehlt oder ungueltig (Datum, Zweck, Futterart, Menge)' using errcode='BA040';
  end if;

  if p_material_id is not null
     and not exists (select 1 from public.materials where id = p_material_id and betrieb_id = v_betrieb) then
    raise exception 'Material gehoert nicht zu deinem Betrieb' using errcode='BA042';
  end if;

  insert into public.fuetterungen (
    betrieb_id, volk_id, durchgefuehrt_am, zweck, futterart, bio_zertifiziert,
    menge_pro_volk_kg, material_id, verantwortliche_person, notiz)
  select v_betrieb, x.volk_id, p_durchgefuehrt_am, p_zweck, p_futterart, p_bio_zertifiziert,
    p_menge_pro_volk_kg, p_material_id, p_verantwortliche_person, p_notiz
  from (select distinct unnest(p_volk_ids) as volk_id) x;

  get diagnostics v_n = row_count;

  if p_material_id is not null then
    update public.materials set stock_qty = stock_qty - coalesce(p_menge_pro_volk_kg, 0) * v_n
      where id = p_material_id and betrieb_id = v_betrieb;
  end if;

  return v_n;
end; $$;

revoke execute on function public.fuetterung_erfassen(
  uuid[], date, text, text, numeric, boolean, uuid, text, text) from anon, public;
grant execute on function public.fuetterung_erfassen(
  uuid[], date, text, text, numeric, boolean, uuid, text, text) to authenticated;
