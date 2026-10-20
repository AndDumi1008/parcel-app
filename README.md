# parcel-app

Demo application governed by the [AI Governance Layer](https://github.com/AndDumi1008/AI-Gov-Layer): a parcel booking service with the per-role data views from the *Parcel Data Journey* enforced in the database. Synthetic data only; nobody here is real.

This repository is the subject of the quarantine proof (PR-1): it starts **quarantined** in the AGL registry and is opened for AI assistance only after its gate items are met and two people sign off.

| Path | Content |
|------|---------|
| `supabase/migrations/` | schema (`party`, `parcel`, `stop`, `scan`, `pod`, `courier`, `actor`) and row-level security with role views: customer, courier (open stops only, relay phone), sorter (no party rows), support (masked), analyst (pseudonyms), dispatcher |
| `supabase/seed/` | synthetic seed with fixed ids |
| `scripts/mask.sql` | masking for preview/staging stacks: deterministic fake names and contacts, pseudonyms and postal areas kept |
| `tests/rls_test.sql`, `tests/run.sh` | assertions of what each role can and cannot see; `make test` runs them in a throw-away PostgreSQL 16 |
| `.github/workflows/ci.yml` | Gate 1 for this repository |

Delivery path (AI-Gov-Layer docs/08, PaaS variant): preview, staging and production Supabase stacks on SERVER; frontend to follow.

```
make test
```
