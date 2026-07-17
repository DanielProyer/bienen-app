-- C05_rpc_volk_umweiseln.sql | Atomare Umweiselung mit Historien-Spur.
-- p_neue_koenigin_id NULL = Volk bewusst weisellos. Betriebs-Gleichheitspruefung Volk<->Koenigin.
-- Errcodes eigener Block BA020+ (BA001-BA013 sind vom Auth-Fundament belegt).

create or replace function public.volk_umweiseln(
  p_volk_id          uuid,
  p_neue_koenigin_id uuid  default null,
  p_alt_grund        text  default 'ersetzt',
  p_datum            date  default current_date
) returns void
  language plpgsql security definer set search_path = '' as $$
declare v_betrieb uuid; v_alt uuid; v_k_betrieb uuid;
begin
  if p_alt_grund not in ('ersetzt','tot','verschollen') then
    raise exception 'Ungueltiger Grund fuer die alte Koenigin' using errcode='BA023';
  end if;

  select betrieb_id, koenigin_id into v_betrieb, v_alt
    from public.voelker where id = p_volk_id for update;
  if v_betrieb is null or not private.kann_schreiben(v_betrieb) then
    raise exception 'Volk nicht gefunden oder gehoert nicht zu deinem Betrieb' using errcode='BA020';
  end if;

  if p_neue_koenigin_id is not null then
    select betrieb_id into v_k_betrieb from public.koeniginnen where id = p_neue_koenigin_id;
    if v_k_betrieb is null or v_k_betrieb <> v_betrieb then
      raise exception 'Koenigin nicht gefunden oder gehoert nicht zu deinem Betrieb' using errcode='BA021';
    end if;
  end if;

  if v_alt is not null then
    update public.koeniginnen set status = p_alt_grund, ersetzt_am = p_datum where id = v_alt;
  end if;

  if p_neue_koenigin_id is not null then
    update public.koeniginnen set volk_id = p_volk_id, zugeordnet_am = p_datum, status = 'aktiv'
      where id = p_neue_koenigin_id;
  end if;

  update public.voelker set koenigin_id = p_neue_koenigin_id where id = p_volk_id;
exception when unique_violation then
  raise exception 'Koenigin ist bereits einem anderen Volk zugeordnet' using errcode='BA022';
end; $$;

revoke execute on function public.volk_umweiseln(uuid, uuid, text, date) from anon, public;
grant execute on function public.volk_umweiseln(uuid, uuid, text, date) to authenticated;
