-- API roles for PostgREST / Supabase: the authenticator logs in and switches to the role named in the JWT.
-- The password is set by the deployment (deploy/*/init/020_authenticator.sh), never stored here.
do $$ begin
  if not exists (select 1 from pg_roles where rolname = 'anon') then create role anon nologin; end if;
  if not exists (select 1 from pg_roles where rolname = 'authenticator') then create role authenticator noinherit login; end if;
end $$;
grant anon, app_customer, app_courier, app_sorter, app_support, app_analyst, app_dispatcher to authenticator;
-- anon gets nothing: no grants, so an unauthenticated request sees no table at all.
