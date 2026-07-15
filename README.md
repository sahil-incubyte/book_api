# Book API

A Rails 7.2 API-only application exposing a GraphQL endpoint for managing books.

## Tech stack

- Ruby 3.3.0, Rails 7.2 (API-only)
- PostgreSQL
- GraphQL (`graphql-ruby`)
- RSpec, FactoryBot, SimpleCov
- Docker + Docker Compose

## Running with Docker (recommended)

No local Ruby or Postgres needed.

```bash
cp .env.example .env          # first time only
docker compose up --build
```

- GraphQL endpoint: <http://localhost:3000/graphql>
- GraphiQL IDE (development): <http://localhost:3000/graphiql>
- Health check: <http://localhost:3000/up>

The database is created and migrated automatically on boot. To use a different
host port: `WEB_PORT=3001 docker compose up`.

See **[docs/docker.md](docs/docker.md)** for the full guide — environment
variables, networking & volumes, dev vs production images, image size
optimization, common commands, and troubleshooting.

## Running without Docker

Requires Ruby 3.3.0 and a local PostgreSQL server.

```bash
bundle install
bin/rails db:prepare
bin/rails server
```

Connection settings are read from the environment (`DATABASE_HOST`,
`POSTGRES_USER`, `POSTGRES_PASSWORD`, `POSTGRES_DB`) with localhost defaults —
see `config/database.yml`.

## Running the test suite

```bash
# With Docker
docker compose exec web bundle exec rspec

# Locally
bundle exec rspec
```
