-- Parcel app — core schema. Portable Postgres; on Supabase the actor comes from the JWT, locally from a session setting.
create extension if not exists pgcrypto;
create schema if not exists agl;

-- Who is asking? Supabase/PostgREST sets request.jwt.claims; local tests set app.actor (uuid) and app.role.
create or replace function agl.actor_id() returns uuid language sql stable as $$
  select coalesce(nullif(current_setting('request.jwt.claims', true), '')::jsonb ->> 'sub',
                  nullif(current_setting('app.actor', true), ''))::uuid
$$;
create or replace function agl.actor_role() returns text language sql stable as $$
  select coalesce(nullif(current_setting('request.jwt.claims', true), '')::jsonb -> 'app_metadata' ->> 'role',
                  nullif(current_setting('app.role', true), ''), 'anon')
$$;

create table actor (                       -- application users: customers, couriers, support, sorters, analysts
  id          uuid primary key default gen_random_uuid(),
  role        text not null check (role in ('customer','courier','sorter','support','analyst','dispatcher')),
  display     text not null,
  email       text unique                  -- customers log in with it; personal data
);

create table party (                       -- a sender or recipient on one parcel; personal data lives here only
  id            uuid primary key default gen_random_uuid(),
  kind          text not null check (kind in ('sender','recipient')),
  name          text not null,
  phone         text,
  email         text,
  address_line  text not null,
  postal_code   text not null,
  city          text not null,
  country       char(2) not null,
  lat           numeric(8,5), lng numeric(8,5),
  pseudonym     text not null,             -- salted hash, stable per person; what analytics sees
  actor_id      uuid references actor(id)  -- set when the party is a registered customer
);

create table parcel (
  id            uuid primary key default gen_random_uuid(),
  ref           text not null unique,      -- RO-CJ-2026-0048213
  sender_id     uuid not null references party(id),
  recipient_id  uuid not null references party(id),
  contents      text not null,
  weight_kg     numeric(6,2) not null,
  dims_cm       text,
  routing_code  text,                      -- DE-80331 · HUB-MUC-2 · R17
  status        text not null default 'booked' check (status in ('booked','picked_up','in_hub','in_transit','out_for_delivery','delivered','exception')),
  payment_token text,                      -- PSP token only, never a card number
  created_at    timestamptz not null default now(),
  pii_erased_at timestamptz
);

create table courier (
  id        uuid primary key default gen_random_uuid(),
  actor_id  uuid not null unique references actor(id),
  name      text not null,
  hub       text not null
);

create table stop (                        -- pickup or delivery assignment; courier access is scoped to these
  id               uuid primary key default gen_random_uuid(),
  parcel_id        uuid not null references parcel(id),
  kind             text not null check (kind in ('pickup','delivery')),
  courier_id       uuid references courier(id),
  window_start     timestamptz, window_end timestamptz,
  relay_phone      text,                   -- generated number that forwards to the party for 24 h
  relay_expires_at timestamptz,
  completed_at     timestamptz
);

create table scan (                        -- hub and courier scans; no party data
  id         uuid primary key default gen_random_uuid(),
  parcel_id  uuid not null references parcel(id),
  stop_id    uuid references stop(id),
  kind       text not null check (kind in ('picked_up','hub_in','sorted','departed','arrived','out_for_delivery','delivered')),
  hub        text,
  lat        numeric(8,5), lng numeric(8,5),
  ts         timestamptz not null default now(),
  by_actor   uuid references actor(id)
);

create table pod (                         -- proof of delivery: encrypted blob references, 12 months
  id             uuid primary key default gen_random_uuid(),
  parcel_id      uuid not null unique references parcel(id),
  signature_ref  text not null,
  photo_ref      text,
  ts             timestamptz not null default now()
);

create index on stop (courier_id) where completed_at is null;
create index on scan (parcel_id, ts);
