#!/usr/bin/env python3
"""Mint a PostgREST/Supabase-style JWT for a seeded actor (PoC stand-in for Supabase Auth).
Usage: scripts/jwt.py <db-role> <actor-uuid> <app-role> [secret]
Claims: role (the DB role PostgREST switches to), sub (actor id), app_metadata.role, aud, exp."""
import sys, os, json, time, hmac, hashlib, base64
role, sub, approle = sys.argv[1:4]
secret = sys.argv[4] if len(sys.argv) > 4 else os.environ["JWT_SECRET"]
b64 = lambda b: base64.urlsafe_b64encode(b).rstrip(b"=").decode()
h = b64(json.dumps({"alg": "HS256", "typ": "JWT"}).encode())
p = b64(json.dumps({"role": role, "sub": sub, "aud": "parcel", "app_metadata": {"role": approle}, "exp": int(time.time()) + 8 * 3600}).encode())
sig = b64(hmac.new(secret.encode(), f"{h}.{p}".encode(), hashlib.sha256).digest())
print(f"{h}.{p}.{sig}")
