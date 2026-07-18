-- E02_rpc_behandlung_erfassen.sql | Einziger Schreibpfad ins Behandlungsjournal.
-- Sammelbehandlung: distinct Voelker -> je EINE Zeile; Lager-Abbuchung aus real eingefuegter
-- Zeilenzahl (ROW_COUNT), nie aus array_length. betrieb_id EXPLIZIT aus den Voelkern (nicht JWT-Default).
-- BA030 Pflichtfeld, BA031 Voelker, BA032 Material-Tenancy, BA033 Dosierung.

create or replace function public.behandlung_erfassen(
  p_volk_ids uuid[],
  p_datum_beginn date,
  p_wirkstoff text,
  p_anwendungsart text,
  p_verantwortliche_person text,
  p_datum_ende date default null,
  p_praeparat text default null,
  p_menge_pro_volk numeric default null,
  p_einheit text default null,
  p_konzentration text default null,
  p_indikation text default null,
  p_aussentemperatur_c numeric default null,
  p_wartefrist_tage int default null,
  p_charge text default null,
  p_material_id uuid default null,
  p_notiz text default null
) returns int
  language plpgsql security definer set search_path = '' as $$
declare
  v_betrieb uuid;
  v_betriebe uuid[];
  v_found int;
  v_n int;
  v_biotech boolean := p_anwendungsart in ('biotechnik','waermebehandlung');
begin
  -- Guard zuerst: leeres/NULL-Array (robust gegen array_length-NULL).
  if p_volk_ids is null or cardinality(p_volk_ids) = 0 then
    raise exception 'Keine Voelker angegeben' using errcode='BA031';
  end if;

  -- Voelker: alle gefunden, genau EIN Betrieb (einheitliche BA031-Meldung -> kein Existenz-Orakel).
  select array_agg(distinct betrieb_id), count(distinct id)
    into v_betriebe, v_found
    from public.voelker where id = any(p_volk_ids);
  if v_found is null
     or v_found <> cardinality(array(select distinct unnest(p_volk_ids)))
     or coalesce(array_length(v_betriebe, 1), 0) <> 1 then
    raise exception 'Volk nicht gefunden oder gehoert nicht zu deinem Betrieb' using errcode='BA031';
  end if;
  v_betrieb := v_betriebe[1];
  if not private.kann_schreiben(v_betrieb) then
    raise exception 'Keine Schreibberechtigung fuer diesen Betrieb' using errcode='BA031';
  end if;

  -- Pflichtfelder (BA030).
  if p_datum_beginn is null
     or p_wirkstoff is null
     or p_anwendungsart is null
     or btrim(coalesce(p_verantwortliche_person, '')) = ''
     or (not v_biotech and btrim(coalesce(p_praeparat, '')) = '') then
    raise exception 'Pflichtfeld fehlt (Datum, Wirkstoff, Anwendungsart, verantwortliche Person, Praeparat)'
      using errcode='BA030';
  end if;

  -- Dosierung bei chemischer Anwendung (BA033).
  if not v_biotech and (p_menge_pro_volk is null or p_menge_pro_volk <= 0 or p_einheit is null) then
    raise exception 'Menge und Einheit sind bei chemischer Anwendung Pflicht' using errcode='BA033';
  end if;

  -- Material-Tenancy (BA032).
  if p_material_id is not null
     and not exists (select 1 from public.materials where id = p_material_id and betrieb_id = v_betrieb) then
    raise exception 'Material gehoert nicht zu deinem Betrieb' using errcode='BA032';
  end if;

  -- Insert: distinct Voelker, betrieb_id EXPLIZIT (nicht JWT-Default).
  insert into public.behandlungen (
    betrieb_id, volk_id, datum_beginn, datum_ende, praeparat, wirkstoff, menge_pro_volk, einheit,
    konzentration, anwendungsart, indikation, aussentemperatur_c, wartefrist_tage, charge,
    verantwortliche_person, material_id, notiz)
  select v_betrieb, x.volk_id, p_datum_beginn, p_datum_ende, p_praeparat, p_wirkstoff, p_menge_pro_volk,
    p_einheit, p_konzentration, p_anwendungsart, coalesce(p_indikation, 'Varroabekaempfung'),
    p_aussentemperatur_c, p_wartefrist_tage, p_charge, p_verantwortliche_person, p_material_id, p_notiz
  from (select distinct unnest(p_volk_ids) as volk_id) x;

  get diagnostics v_n = row_count;

  -- Lager-Abbuchung aus real eingefuegter Zeilenzahl (nie array_length), betrieb_id-gefiltert (Defense-in-Depth).
  if p_material_id is not null then
    update public.materials
      set stock_qty = stock_qty - coalesce(p_menge_pro_volk, 0) * v_n
      where id = p_material_id and betrieb_id = v_betrieb;
  end if;

  return v_n;
end; $$;

revoke execute on function public.behandlung_erfassen(
  uuid[], date, text, text, text, date, text, numeric, text, text, text, numeric, int, text, uuid, text)
  from anon, public;
grant execute on function public.behandlung_erfassen(
  uuid[], date, text, text, text, date, text, numeric, text, text, text, numeric, int, text, uuid, text)
  to authenticated;
