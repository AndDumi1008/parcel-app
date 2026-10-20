-- Synthetic seed: nobody here is real. Fixed UUIDs so tests and the demo can refer to them.
insert into actor (id, role, display, email) values
 ('a0000000-0000-0000-0000-000000000001','customer','Ana Popescu','ana.popescu@example.ro'),
 ('a0000000-0000-0000-0000-000000000002','customer','Jonas Weber','jonas.weber@example.de'),
 ('a0000000-0000-0000-0000-000000000003','courier','Mihai (Cluj)',null),
 ('a0000000-0000-0000-0000-000000000004','courier','Lena (München)',null),
 ('a0000000-0000-0000-0000-000000000005','sorter','Hub scanner Cluj',null),
 ('a0000000-0000-0000-0000-000000000006','support','Support desk',null),
 ('a0000000-0000-0000-0000-000000000007','analyst','Analytics',null),
 ('a0000000-0000-0000-0000-000000000008','dispatcher','Dispatch Cluj',null);

insert into courier (id, actor_id, name, hub) values
 ('c0000000-0000-0000-0000-000000000001','a0000000-0000-0000-0000-000000000003','Mihai','HUB-CLJ-1'),
 ('c0000000-0000-0000-0000-000000000002','a0000000-0000-0000-0000-000000000004','Lena','HUB-MUC-2');

insert into party (id, kind, name, phone, email, address_line, postal_code, city, country, lat, lng, pseudonym, actor_id) values
 ('b0000000-0000-0000-0000-000000000001','sender','Ana Popescu','+40 721 334 512','ana.popescu@example.ro','Str. Memorandumului 12, ap. 4','400114','Cluj-Napoca','RO',46.77010,23.58940,'snd_7f3a91c2','a0000000-0000-0000-0000-000000000001'),
 ('b0000000-0000-0000-0000-000000000002','recipient','Jonas Weber','+49 171 556 2201','jonas.weber@example.de','Sendlinger Str. 8','80331','München','DE',48.13600,11.57100,'rcp_b84e02d7','a0000000-0000-0000-0000-000000000002'),
 ('b0000000-0000-0000-0000-000000000003','sender','Radu Ionescu','+40 744 120 998','radu.ionescu@example.ro','Bd. 21 Decembrie 1989 77','400604','Cluj-Napoca','RO',46.77320,23.60110,'snd_22c9d0ae',null),
 ('b0000000-0000-0000-0000-000000000004','recipient','Sofia Bianchi','+39 333 410 7788','sofia.bianchi@example.it','Via Torino 15','20123','Milano','IT',45.46420,9.18520,'rcp_9e1f55ab',null);

insert into parcel (id, ref, sender_id, recipient_id, contents, weight_kg, dims_cm, routing_code, status, payment_token) values
 ('d0000000-0000-0000-0000-000000000001','RO-CJ-2026-0048213','b0000000-0000-0000-0000-000000000001','b0000000-0000-0000-0000-000000000002','Books, 2 × hardcover',2.40,'32×24×9','DE-80331 · HUB-MUC-2 · R17','out_for_delivery','tok_9c1e'),
 ('d0000000-0000-0000-0000-000000000002','RO-CJ-2026-0048301','b0000000-0000-0000-0000-000000000003','b0000000-0000-0000-0000-000000000004','Ceramics, fragile',4.10,'40×30×30','IT-20123 · HUB-MIL-1 · R03','booked','tok_51aa');

insert into stop (id, parcel_id, kind, courier_id, window_start, window_end, relay_phone, relay_expires_at, completed_at) values
 ('e0000000-0000-0000-0000-000000000001','d0000000-0000-0000-0000-000000000001','pickup','c0000000-0000-0000-0000-000000000001', now() - interval '1 day', now() - interval '22 hours','+40 31 000 7781', now() - interval '12 hours', now() - interval '23 hours'),
 ('e0000000-0000-0000-0000-000000000002','d0000000-0000-0000-0000-000000000001','delivery','c0000000-0000-0000-0000-000000000002', now() + interval '1 hour', now() + interval '3 hours','+49 30 000 4410', now() + interval '20 hours', null),
 ('e0000000-0000-0000-0000-000000000003','d0000000-0000-0000-0000-000000000002','pickup','c0000000-0000-0000-0000-000000000001', now() + interval '2 hours', now() + interval '4 hours','+40 31 000 7782', now() + interval '22 hours', null);

insert into scan (parcel_id, stop_id, kind, hub, lat, lng, ts, by_actor) values
 ('d0000000-0000-0000-0000-000000000001','e0000000-0000-0000-0000-000000000001','picked_up',null,46.77010,23.58940, now() - interval '23 hours','a0000000-0000-0000-0000-000000000003'),
 ('d0000000-0000-0000-0000-000000000001',null,'hub_in','HUB-CLJ-1',null,null, now() - interval '20 hours','a0000000-0000-0000-0000-000000000005'),
 ('d0000000-0000-0000-0000-000000000001',null,'sorted','HUB-CLJ-1',null,null, now() - interval '19 hours','a0000000-0000-0000-0000-000000000005'),
 ('d0000000-0000-0000-0000-000000000001',null,'departed','HUB-CLJ-1',null,null, now() - interval '18 hours','a0000000-0000-0000-0000-000000000005'),
 ('d0000000-0000-0000-0000-000000000001',null,'arrived','HUB-MUC-2',null,null, now() - interval '3 hours',null),
 ('d0000000-0000-0000-0000-000000000001','e0000000-0000-0000-0000-000000000002','out_for_delivery','HUB-MUC-2',null,null, now() - interval '30 minutes','a0000000-0000-0000-0000-000000000004');
