-- A04_profil_trigger.sql | Beim Supabase-Signup automatisch profiles-Zeile.
-- BEWUSST minimal: kein Invitation-Claim hier (entkoppelt, A06 einladung_annehmen),
-- damit ein Fehler NIE den Signup blockiert ("Database error saving new user").
create or replace function public.handle_new_auth_user() returns trigger
  language plpgsql security definer set search_path = '' as $$
begin
  insert into public.profiles (id, email, display_name)
  values (new.id, new.email,
          coalesce(new.raw_user_meta_data ->> 'display_name', new.email))
  on conflict (id) do nothing;
  return new;
end;
$$;

drop trigger if exists on_auth_user_created on auth.users;
create trigger on_auth_user_created
  after insert on auth.users
  for each row execute function public.handle_new_auth_user();
