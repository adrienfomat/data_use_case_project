# CLAUDE.md — Market data platform

Shared by both team members' Claude Code sessions. Keep it short and true.

## Context
- School project (EFREI, Bloc 1). The brief is `Projet_final_Market.docx`; it is the source of truth
  for scope, the RBAC matrix, and what the jury checks.
- Progress lives in `planification.md` — read it first, tick boxes in the same PR as the work.
- Two people work in parallel: one branch per task, PR into `main`, never push to `main` directly.
- Docs (README, ADRs, planification) are in French; code and comments in English.

## Architecture rules (do not break)
- One PostgreSQL server, one schema + one login role per service (`orders`, `inventory`,
  `payments`, `auth`). A service never reads another service's schema — no cross-schema joins or FKs.
- Cross-service links (`product_id`, `order_id`) are checked in code via the other service's API.
- Catalog is MongoDB (`market.catalog`); prices are integer cents everywhere.
- Writes that may be retried carry an `idempotency_key` with a UNIQUE constraint.
- Nothing displayed on a screen may be hard-coded: it must come from a DB, an API or Kafka.
- No secrets in the repo: new variables go in `.env.example` with a placeholder value.

## Running
- `docker-compose up -d` starts the infra; `db/postgres/*` and `db/mongo/*` run only on an
  empty volume — after a schema change: `docker-compose down -v && docker-compose up -d`.
- Load env before Python scripts: `set -a; . ./.env; set +a`.
- Images: `bitnami/*` and `minio/*` were withdrawn from Docker Hub. Use `apache/kafka` and
  `bitnamilegacy/minio` (already pinned in compose). Always pin image tags.
