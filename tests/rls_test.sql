-- Role view assertions: what each role sees, as rows and columns. Fails loudly on any deviation.
\set ON_ERROR_STOP on
create or replace function agl.assert(cond boolean, msg text) returns void language plpgsql as $$
begin if not cond then raise exception 'ASSERTION FAILED: %', msg; end if; end $$;

-- helper to run as an app role with an actor
create or replace procedure agl.become(role_ text, actor_ uuid, approle text) language plpgsql as $$
begin
  perform set_config('app.role', role_, false); perform set_config('app.actor', actor_::text, false);
  execute format('set role %I', approle);
end $$;

-- CUSTOMER Ana: sees her parcel and both parties of it, not the other parcel.
call agl.become('customer', 'a0000000-0000-0000-0000-000000000001', 'app_customer');
select agl.assert((select count(*) from parcel) = 1, 'customer sees exactly her parcel');
select agl.assert((select count(*) from party) = 2, 'customer sees both parties of her parcel');
select agl.assert((select count(*) from customer_tracking_v) = 1, 'customer tracking view: one row');
select agl.assert((select status from customer_tracking_v) = 'out_for_delivery', 'customer tracking status');
select agl.assert((select delivery_window_start from customer_tracking_v) is not null and (select last_hub from customer_tracking_v) = 'HUB-MUC-2', 'customer tracking: full row incl. window and hub');
do $$ begin perform relay_phone from stop; raise exception 'customer could read stop.relay_phone'; exception when insufficient_privilege then null; end $$;
reset role;

-- COURIER Lena (delivery of parcel 1, open): sees that stop, the recipient only, relay phone; not the sender, not parcel 2.
call agl.become('courier', 'a0000000-0000-0000-0000-000000000004', 'app_courier');
select agl.assert((select count(*) from stop) = 1, 'courier sees exactly one open stop');
select agl.assert((select count(*) from party) = 1 and (select name from party) = 'Jonas Weber', 'courier sees only the recipient of the open delivery');
select agl.assert((select relay_phone from courier_stop_v) = '+49 30 000 4410', 'courier gets the relay number, valid');
select agl.assert((select count(*) from parcel) = 1, 'courier sees only the parcel of the open stop');
reset role;

-- COURIER Mihai: pickup 1 completed → no longer visible; pickup of parcel 2 open → sender Radu visible, not Ana.
call agl.become('courier', 'a0000000-0000-0000-0000-000000000003', 'app_courier');
select agl.assert((select count(*) from stop) = 1, 'completed stop revoked for courier');
select agl.assert((select string_agg(name, ',') from party) = 'Radu Ionescu', 'courier sees the open pickup sender only');
reset role;

-- SORTER: scans and routing, zero party rows, no party columns via view.
call agl.become('sorter', 'a0000000-0000-0000-0000-000000000005', 'app_sorter');
select agl.assert((select count(*) from scan) >= 6, 'sorter sees scans');
select agl.assert((select count(*) from sorter_parcel_v) = 2, 'sorter sees routing for all parcels');
do $$ begin perform count(*) from party; raise exception 'sorter could read party'; exception when insufficient_privilege then null; end $$;
reset role;

-- SUPPORT: masked view only; base tables denied.
call agl.become('support', 'a0000000-0000-0000-0000-000000000006', 'app_support');
select agl.assert((select sender_phone from support_parcel_v where ref = 'RO-CJ-2026-0048213') = '+40 7•• ••• 512', 'support phone masked');
select agl.assert((select sender_email from support_parcel_v where ref = 'RO-CJ-2026-0048213') like 'a%@example.ro' and (select sender_email from support_parcel_v where ref = 'RO-CJ-2026-0048213') not like '%popescu%', 'support email masked');
do $$ begin perform count(*) from party; raise exception 'support could read party'; exception when insufficient_privilege then null; end $$;
reset role;

-- ANALYST: pseudonyms and areas only.
call agl.become('analyst', 'a0000000-0000-0000-0000-000000000007', 'app_analyst');
select agl.assert((select sender_pseudonym from analytics_parcel_v where ref = 'RO-CJ-2026-0048213') = 'snd_7f3a91c2', 'analyst sees pseudonym');
select agl.assert((select sender_area from analytics_parcel_v where ref = 'RO-CJ-2026-0048213') = '400', 'analyst sees postal area only');
do $$ begin perform count(*) from party; raise exception 'analyst could read party'; exception when insufficient_privilege then null; end $$;
reset role;

-- DISPATCHER: senders of open pickups only (Radu), not Ana (pickup done), never recipients.
call agl.become('dispatcher', 'a0000000-0000-0000-0000-000000000008', 'app_dispatcher');
select agl.assert((select string_agg(name, ',') from party) = 'Radu Ionescu', 'dispatcher sees open-pickup senders only');
reset role;

select 'RLS assertions passed' as result;
