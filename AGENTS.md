# AGENTS.md

This file defines how coding agents should operate in this repository.

## Project scope

- Challenge: build a high-load accounting service with accounts and transactions.
- Runtime stack: Ruby 4.0.1, Rack, Grape, Sequel, PostgreSQL, Puma.
- App root: `app/`.

## Repository layout

- `app/controllers/` API endpoints.
- `app/config/` Rack, DB, and Puma config.
- `app/Gemfile` dependencies.
- `docker-compose.yml` local API + Postgres environment.

## Local run commands

- Start all services: `docker compose up --build`
- Start only API (if DB already running): `docker compose up api`
- App endpoint: `http://localhost:4321`
- Health check: `curl http://localhost:4321/health`

## Development rules

- Keep changes minimal and focused on requested behavior.
- Prefer deterministic DB logic and explicit transaction boundaries.
- Preserve monetary precision with decimal/numeric types (2 fractional digits).
- Enforce transaction state transitions:
  - `deposit`: one-step operation, persisted as `completed`.
  - `withdrawal`: two-step operation (`pending` -> `completed` or `cancelled`).
- Keep APIs idempotent where a `uuid` is provided.
- Validate currency consistency between account and transaction.
- Return clear 4xx for business rule violations and 5xx only for unexpected failures.

## Database expectations

- `accounts`: current balance and currency.
- `transactions`: account relation, currency, signed amount, status, uuid, transaction_type.
- Add DB constraints/indexes for correctness and load:
  - unique index on `transactions.uuid`
  - indexes on `account_id`, `status`, `created_at`

## Code style

- Follow existing Ruby style (`# frozen_string_literal: true` where used).
- Keep controllers thin; move non-trivial business logic to service objects.
- Use small methods with explicit names and guard clauses.

## Validation before finish

- Boot app successfully in Docker.
- Check `/health`.
- For behavior changes, exercise endpoints with sample requests and confirm DB state.
- If tests are added, run them and include results in the final update.
