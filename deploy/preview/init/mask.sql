-- Masking for preview/staging stacks (A.8.11, A.8.33): run against a copy of a production-shaped database.
-- Names, contacts and street addresses become deterministic fakes; pseudonyms, postal areas, geo ±100 m, weights and timings stay.
update party set
  name         = initcap(substr(md5(pseudonym || 'n'), 1, 6)) || ' ' || initcap(substr(md5(pseudonym || 'f'), 1, 7)),
  phone        = case when phone is null then null else '+' || left(regexp_replace(phone, '\D', '', 'g'), 2) || ' 700 000 ' || lpad((abs(hashtext(pseudonym)) % 1000)::text, 3, '0') end,
  email        = case when email is null then null else lower(substr(md5(pseudonym || 'e'), 1, 8)) || '@example.test' end,
  address_line = 'Masked street ' || (abs(hashtext(pseudonym)) % 200 + 1),
  lat          = round(lat, 3), lng = round(lng, 3);
-- actor_id is kept: a masked customer account must still reach its own (masked) parcels in preview/staging.
update actor set email = case when email is null then null else lower(substr(md5(id::text), 1, 8)) || '@example.test' end, display = role || ' ' || substr(md5(id::text), 1, 4);
update parcel set payment_token = 'tok_masked_' || substr(md5(id::text), 1, 6);
update stop set relay_phone = null;
update pod set signature_ref = 'masked', photo_ref = null;
-- record provenance so the dataset catalog can tag it "masked"
create table if not exists agl_masking_report (ran_at timestamptz default now(), parties int, parcels int);
insert into agl_masking_report (parties, parcels) select (select count(*) from party), (select count(*) from parcel);
