# Docker Setup

This project is fully containerized. You can run the Book API and its
PostgreSQL database with Docker — no need to install Ruby or Postgres on your
host.

## Contents

- [Files at a glance](#files-at-a-glance)
- [Prerequisites](#prerequisites)
- [Quick start (development)](#quick-start-development)
- [Environment variables](#environment-variables)
- [How it works: networking & volumes](#how-it-works-networking--volumes)
- [Development vs production images](#development-vs-production-images)
- [Image size optimization](#image-size-optimization)
- [Common commands](#common-commands)
- [Troubleshooting](#troubleshooting)

## Files at a glance

| File | Purpose |
|------|---------|
| `Dockerfile` | Production image. Multi-stage, slim, runs as a non-root user. |
| `Dockerfile.dev` | Development image. Multi-stage, includes all gem groups. |
| `docker-compose.yml` | Development stack: `web` (Rails) + `db` (PostgreSQL). |
| `docker-compose.prod.yml` | Production-like overlay using the production `Dockerfile`. |
| `.dockerignore` | Keeps the build context small (excludes `.git`, logs, coverage, etc.). |
| `.env.example` | Template for local dev env vars. Copy to `.env`. |
| `.env.production.example` | Template for production env vars. Copy to `.env.production`. |
| `bin/docker-entrypoint` | Prepares the database before the server starts (production). |

## Prerequisites

- [Docker Engine](https://docs.docker.com/engine/install/) 20.10+
- Docker Compose v2 (bundled with modern Docker as `docker compose`)

Verify:

```bash
docker --version
docker compose version
```

## Quick start (development)

```bash
# 1. Create your local env file (first time only)
cp .env.example .env

# 2. Build the images and start the stack
docker compose up --build

# 3. Open the app
#    GraphQL endpoint:  http://localhost:3000/graphql
#    Health check:      http://localhost:3000/up
#    GraphiQL IDE:       http://localhost:3000/graphiql (development)
```

The `web` service runs `rails db:prepare` on boot, so the database is created
and migrated automatically the first time.

Source code is bind-mounted into the container, so edits on your host are
picked up live — no rebuild needed for normal code changes. Rebuild only when
the `Gemfile` or a `Dockerfile` changes.

### Changing the host port

Port 3000 in the container can be mapped to any host port via `WEB_PORT`:

```bash
WEB_PORT=3001 docker compose up      # app at http://localhost:3001
```

Or set `WEB_PORT=3001` in `.env` to make it permanent. Defaults to 3000.

## Environment variables

All configuration comes from the environment; nothing sensitive is baked into
the images. Real `.env*` files are git-ignored — only the `*.example`
templates are committed.

| Variable | Used by | Description |
|----------|---------|-------------|
| `POSTGRES_USER` | db, Rails | Postgres role name |
| `POSTGRES_PASSWORD` | db, Rails | Postgres password |
| `POSTGRES_DB` | db, Rails | Development/production database name |
| `POSTGRES_TEST_DB` | Rails | Test database name |
| `DATABASE_HOST` | Rails | Postgres host — `db` inside Compose, `localhost` on host |
| `DATABASE_PORT` | Rails | Postgres port (default `5432`) |
| `RAILS_ENV` | Rails | `development` / `test` / `production` |
| `RAILS_MAX_THREADS` | Rails | Puma thread count / DB pool size |
| `RAILS_MASTER_KEY` | Rails (prod) | Decrypts `config/credentials.yml.enc` |
| `WEB_PORT` | Compose | Host port mapped to container port 3000 |

`config/database.yml` reads these with sensible localhost defaults, so
`bin/rails` still works without Docker if you have Postgres installed locally.

## How it works: networking & volumes

**Networking.** Compose puts every service on a shared private network where
they reach each other by **service name**. That's why Rails connects to
Postgres at host `db` (see `DATABASE_HOST=db` in `.env`), not `localhost`.
Only ports listed under `ports:` are exposed to your host machine.

**Volumes.** Containers are ephemeral — their filesystem is discarded when
removed. Named volumes persist data across restarts and rebuilds:

- `pg_data` → `/var/lib/postgresql/data` — the database survives `docker compose down`.
- `bundle_cache` → `/usr/local/bundle` — installed gems persist and aren't
  shadowed by the bind-mounted source.

The bind mount `.:/rails` maps your working directory into the container for
live code reload.

## Development vs production images

| | Development (`Dockerfile.dev`) | Production (`Dockerfile`) |
|---|---|---|
| Gem groups | all (incl. `development`, `test`) | runtime only (`BUNDLE_WITHOUT=development`) |
| Source code | bind-mounted (live reload) | copied into the image |
| User | root | non-root (`rails`, uid 1000) |
| Bootsnap precompile | no | yes (faster boot) |
| Optimized for | fast iteration | small size, security |

Run the production-like stack:

```bash
cp .env.production.example .env.production   # fill in real secrets
docker compose -f docker-compose.prod.yml --env-file .env.production up --build -d
```

## Image size optimization

Both images use **multi-stage builds**: a `build` stage installs the compiler
toolchain (`build-essential`, `libpq-dev`) to compile native gems like `pg`,
and the final stage keeps only the runtime libraries plus the already-compiled
bundle. The toolchain never ships in the final image.

For the development image this cut the size by ~32%:

| Stage | Dev image size |
|-------|----------------|
| Single-stage (toolchain shipped) | ~1.21 GB |
| Multi-stage (toolchain discarded) | ~818 MB |

Inspect any image's layers:

```bash
docker images
docker history book_api-web
```

## Common commands

```bash
# Start / stop
docker compose up -d              # start in background
docker compose down               # stop + remove containers (keeps DB data)
docker compose down -v            # also delete volumes (wipes the database)
docker compose stop / start       # pause / resume without removing

# Logs & status
docker compose ps                 # list services and their status
docker compose logs -f web        # follow the Rails logs

# Run commands inside the containers
docker compose exec web bash                    # shell in the web container
docker compose exec web bin/rails console       # Rails console
docker compose exec web bundle exec rspec       # run the test suite
docker compose exec db psql -U postgres         # psql into Postgres

# Rebuild after Gemfile / Dockerfile changes
docker compose build web
```

## Troubleshooting

**`address already in use` / port 3000 taken.**
Something on your host is using the port. Map to another one:
`WEB_PORT=3001 docker compose up`.

**`connection refused` to Postgres.**
The `web` service waits for the `db` healthcheck, but if you see this, check
`docker compose ps` — the `db` service should be `healthy`. Confirm
`DATABASE_HOST=db` in `.env` (inside Compose) and view logs with
`docker compose logs db`.

**Gem changes not taking effect.**
The bundle lives in the `bundle_cache` volume and is baked at build time.
After editing the `Gemfile`, rebuild: `docker compose build web`.

**Stale server PID (`A server is already running`).**
The start command removes `tmp/pids/server.pid` automatically. If it persists,
`docker compose down` and start again.

**Start completely fresh.**
`docker compose down -v` removes the database and gem volumes, then
`docker compose up --build` rebuilds from scratch.
