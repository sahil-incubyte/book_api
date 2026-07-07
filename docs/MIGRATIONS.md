# Database Migration Best Practices

This project uses [strong_migrations](https://github.com/ankane/strong_migrations)
to catch unsafe migrations before they reach production. This document summarizes
the patterns we follow.

## Why safe migrations matter

On a busy production database, a migration can hold locks that block reads/writes
for the duration of a table rewrite or scan. What runs instantly on an empty dev
database can take a table offline for minutes in production. Safe migrations split
risky changes into steps that avoid long-held locks.

> **Note on this app:** strong_migrations only enforces its checks on PostgreSQL,
> MySQL, and MariaDB. `book_api` uses SQLite, where the checks are inert. The gem
> and config are in place so these patterns transfer directly to a production
> database. The guidance below describes the PostgreSQL behavior.

## Safe vs. unsafe operations

| Operation | Risk | Safe approach |
|---|---|---|
| Add a column with a volatile default | Rewrites the whole table (older PG) | Add column, then set default, then backfill in batches |
| Add a `NOT NULL` constraint | Full-table scan under a lock | Add a `CHECK (col IS NOT NULL)` constraint `NOT VALID`, `validate` it separately, then set `NOT NULL` |
| Add an index | Locks writes while building | `add_index ..., algorithm: :concurrently` (in a non-transactional migration) |
| Change a column type | Rewrites the table | Add a new column, backfill, swap, drop the old one |
| Rename a column/table | Breaks running app code mid-deploy | Add new, copy, deploy code reading both, then drop |
| Backfill data in a schema migration | Long transaction holds locks | Backfill in a separate migration/rake task, in batches |

## Adding a NOT NULL constraint (worked example)

See [`db/migrate/20260705123237_add_not_null_constraints_to_books.rb`](../db/migrate/20260705123237_add_not_null_constraints_to_books.rb).

The `Book` model validates presence of `title`/`author`/`price`, but the database
originally had no matching constraints, so data written outside the model (console,
raw SQL, bulk import) could violate the invariant. The migration adds DB-level
`NOT NULL` constraints to close that gap.

Because this table is effectively empty, we wrapped the change in `safety_assured`
(see below). On a **large** production table, the zero-downtime pattern is:

```ruby
# Migration 1 — add an unvalidated check constraint (fast, no full scan)
add_check_constraint :books, "title IS NOT NULL", name: "books_title_null", validate: false

# Migration 2 — validate it (scans without an exclusive lock)
validate_check_constraint :books, name: "books_title_null"

# Migration 3 — Postgres 12+ can then set NOT NULL cheaply, using the constraint
change_column_null :books, :title, false
remove_check_constraint :books, name: "books_title_null"
```

## The `safety_assured` escape hatch

When you are certain a flagged operation is safe (small/empty table, maintenance
window, etc.), wrap it and document *why*:

```ruby
safety_assured do
  change_column_null :books, :title, false
end
```

Use it deliberately — it silences the guardrail, so the justification belongs in
a comment right next to it.

## Grandfathering existing migrations

`config/initializers/strong_migrations.rb` sets `StrongMigrations.start_after` to
the timestamp of the initial `create_books` migration, so pre-existing migrations
aren't retroactively flagged. Every migration created after that point is checked.

## Workflow checklist

1. Write the migration.
2. Run it locally; if strong_migrations raises, read the suggested safe pattern.
3. Rewrite using the safe approach (or `safety_assured` with a justification).
4. Keep data backfills out of schema migrations.
5. Never edit a migration that has already run in production — add a new one.
