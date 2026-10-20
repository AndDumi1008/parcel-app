-- Row-level security and role views: the per-role data views from the Parcel Data Journey, enforced in the database.
alter table actor   enable row level security;
alter table party   enable row level security;
alter table parcel  enable row level security;
alter table courier enable row level security;
alter table stop    enable row level security;
alter table scan    enable row level security;
alter table pod     enable row level security;

-- Everyone may read their own actor row.
create policy actor_self on actor for select using (id = agl.actor_id());

-- CUSTOMER: own parcels (as sender or recipient), their parties, scans and POD; nothing else.
-- Helpers run as the owner (security definer) so policies do not recurse through each other.
create or replace function agl.my_party_ids() returns setof uuid language sql stable security definer set search_path = public as $$
  select id from party where actor_id = agl.actor_id() $$;
create or replace function agl.my_parcel_ids() returns setof uuid language sql stable security definer set search_path = public as $$
  select pc.id from parcel pc where pc.sender_id in (select agl.my_party_ids()) or pc.recipient_id in (select agl.my_party_ids()) $$;
create policy parcel_customer on parcel for select using (agl.actor_role() = 'customer' and id in (select agl.my_parcel_ids()));
create policy party_customer on party for select using (
  agl.actor_role() = 'customer' and exists (select 1 from parcel pc where pc.id in (select agl.my_parcel_ids()) and party.id in (pc.sender_id, pc.recipient_id)));
create policy scan_customer on scan for select using (agl.actor_role() = 'customer' and parcel_id in (select agl.my_parcel_ids()));
create policy pod_customer on pod for select using (agl.actor_role() = 'customer' and parcel_id in (select agl.my_parcel_ids()));
-- customers see the delivery window of their own parcels' stops (column grant below keeps courier, relay number and geo out)
create policy stop_customer on stop for select using (agl.actor_role() = 'customer' and parcel_id in (select agl.my_parcel_ids()));

-- COURIER: stops assigned to them and not yet completed; the ONE party of that stop; parcel ref/weight; may insert scans for those stops.
create or replace function agl.my_courier_id() returns uuid language sql stable security definer set search_path = public as $$
  select c.id from courier c where c.actor_id = agl.actor_id() $$;
create or replace function agl.my_open_stops() returns table (stop_id uuid, parcel_id uuid, party_id uuid) language sql stable security definer set search_path = public as $$
  select s.id, s.parcel_id, case s.kind when 'pickup' then pc.sender_id else pc.recipient_id end
  from stop s join parcel pc on pc.id = s.parcel_id where s.courier_id = agl.my_courier_id() and s.completed_at is null $$;
create policy stop_courier on stop for select using (
  agl.actor_role() = 'courier' and courier_id = agl.my_courier_id() and completed_at is null);
create policy parcel_courier on parcel for select using (agl.actor_role() = 'courier' and id in (select parcel_id from agl.my_open_stops()));
create policy party_courier on party for select using (agl.actor_role() = 'courier' and id in (select party_id from agl.my_open_stops()));
create policy scan_courier_insert on scan for insert with check (
  agl.actor_role() = 'courier' and exists (select 1 from stop s where s.id = scan.stop_id and s.courier_id = agl.my_courier_id() and s.completed_at is null));
create policy scan_courier_select on scan for select using (agl.actor_role() = 'courier' and by_actor = agl.actor_id());
create policy courier_self on courier for select using (actor_id = agl.actor_id());

-- SORTER: scans and parcel routing only; no party rows at all (no policy on party → zero rows).
create policy scan_sorter on scan for select using (agl.actor_role() = 'sorter');
create policy scan_sorter_insert on scan for insert with check (agl.actor_role() = 'sorter' and kind in ('hub_in','sorted','departed','arrived'));
create policy parcel_sorter on parcel for select using (agl.actor_role() = 'sorter');   -- columns restricted by the view below

-- SUPPORT and ANALYST see nothing on the base tables; they get masked / pseudonymous views (owner-privileged).
-- DISPATCHER: stops and parcels, pickup parties until the pickup scan.
create policy stop_dispatcher on stop for select using (agl.actor_role() = 'dispatcher');
create policy parcel_dispatcher on parcel for select using (agl.actor_role() = 'dispatcher');
create or replace function agl.open_pickup_senders() returns setof uuid language sql stable security definer set search_path = public as $$
  select pc.sender_id from parcel pc join stop s on s.parcel_id = pc.id where s.kind = 'pickup' and s.completed_at is null $$;
create policy party_dispatcher on party for select using (agl.actor_role() = 'dispatcher' and party.kind = 'sender' and id in (select agl.open_pickup_senders()));

-- ---- Views. Masked/pseudonymous views (support, sorter, analytics) run with the OWNER's privileges so they can read
-- tables the role may not, handing out only the allowed shape. Views that merely reshape what the role already sees
-- (customer, courier) run as the INVOKER so row-level security still applies. Grants decide who may select from them.
create or replace function agl.mask_phone(p text) returns text language sql immutable as $$
  select case when p is null then null else regexp_replace(p, '^(\+\d{2} \d)\d{2} \d{3} (\d{3})$', '\1•• ••• \2') end $$;
create or replace function agl.mask_email(e text) returns text language sql immutable as $$
  select case when e is null then null else left(e,1) || repeat('•', greatest(1, position('@' in e) - 2)) || substring(e from position('@' in e)) end $$;

create view support_parcel_v as                     -- SUPPORT: masked contacts, city only, status; unmask needs a case (not here)
  select pc.ref, pc.status, pc.routing_code, pc.weight_kg, pc.created_at,
         s.name as sender_name, agl.mask_phone(s.phone) as sender_phone, agl.mask_email(s.email) as sender_email, s.postal_code || ' ' || s.city as sender_area,
         r.name as recipient_name, agl.mask_phone(r.phone) as recipient_phone, r.postal_code || ' ' || r.city as recipient_area
  from parcel pc join party s on s.id = pc.sender_id join party r on r.id = pc.recipient_id;

create view sorter_parcel_v as                      -- SORTER: barcode in, bag out
  select ref, routing_code, weight_kg, dims_cm, status from parcel;

create view courier_stop_v with (security_invoker = true) as                       -- COURIER: assigned open stops with the one party and the relay number
  select st.id as stop_id, st.kind, pc.ref, pc.weight_kg, st.window_start, st.window_end,
         p.name, p.address_line, p.postal_code, p.city,
         case when st.relay_expires_at > now() then st.relay_phone end as relay_phone, st.relay_expires_at
  from stop st join parcel pc on pc.id = st.parcel_id
  join party p on p.id = case st.kind when 'pickup' then pc.sender_id else pc.recipient_id end
  where st.courier_id = agl.my_courier_id() and st.completed_at is null;

create view analytics_parcel_v as                   -- ANALYST: pseudonyms and postal areas, never names or contacts
  select pc.ref, pc.status, pc.weight_kg, pc.created_at, s.pseudonym as sender_pseudonym, left(s.postal_code,3) as sender_area, s.country as sender_country,
         r.pseudonym as recipient_pseudonym, left(r.postal_code,3) as recipient_area, r.country as recipient_country
  from parcel pc join party s on s.id = pc.sender_id join party r on r.id = pc.recipient_id;

create view customer_tracking_v with (security_invoker = true) as                  -- CUSTOMER chat/tracking: de-identified status object for the AI gateway (no party data)
  select pc.id, pc.ref, pc.status, pc.routing_code, (select max(ts) from scan sc where sc.parcel_id = pc.id) as last_scan_at,
         (select hub from scan sc where sc.parcel_id = pc.id order by ts desc limit 1) as last_hub,
         (select min(window_start) from stop st where st.parcel_id = pc.id and st.kind = 'delivery') as delivery_window_start,
         (select min(window_end) from stop st where st.parcel_id = pc.id and st.kind = 'delivery') as delivery_window_end
  from parcel pc;

-- Database roles (Supabase: authenticated/anon; locally: one role per app role for the tests) and grants.
do $$ declare role_ text; begin
  foreach role_ in array array['app_customer','app_courier','app_sorter','app_support','app_analyst','app_dispatcher'] loop
    if not exists (select 1 from pg_roles where rolname = role_) then execute format('create role %I nologin', role_); end if;
  end loop;
end $$;
grant usage on schema public, agl to app_customer, app_courier, app_sorter, app_support, app_analyst, app_dispatcher;
grant execute on all functions in schema agl to app_customer, app_courier, app_sorter, app_support, app_analyst, app_dispatcher;
grant select on actor to app_customer, app_courier, app_sorter, app_support, app_analyst, app_dispatcher;
grant select on parcel, party, scan, pod to app_customer;
grant select (id, parcel_id, kind, window_start, window_end, completed_at) on stop to app_customer;
grant select on parcel, party, stop, courier, scan to app_courier; grant insert on scan to app_courier;
grant select on scan to app_sorter; grant insert on scan to app_sorter; grant select on sorter_parcel_v to app_sorter;
grant select on support_parcel_v to app_support;
grant select on analytics_parcel_v to app_analyst;
grant select on parcel, party, stop to app_dispatcher;
grant select on courier_stop_v to app_courier;
grant select on customer_tracking_v to app_customer;
