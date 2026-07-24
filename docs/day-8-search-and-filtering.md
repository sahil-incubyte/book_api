# Day 8 — Book Search, Filtering & Sorting (Backend)

Extends the `books` GraphQL query with **search**, **price-range filtering**,
and **sorting**. All three controls combine with AND into a single query. Built
spec-first with Bee across four vertical slices (search → price → sort → UX
polish; the polish slice was frontend-only, see the `book-frontend` companion
doc).

Final state: **77 examples, 0 failures** (line coverage 87.55%).

## Why

The `books` query returned the entire table with no way to narrow or order it.
As the catalog grows, clients need to find books by title/author, bound results
to a price range, and control ordering — without the API leaking a way to run
arbitrary SQL, and without breaking the Day 7 Redis cache invariant.

The hard part isn't the filtering — it's doing it while keeping two things true:
1. **The single-key cache stays correct** (`books/all` is the only cached list,
   and `Book#invalidate_cache` only knows how to clear that key).
2. **No user input ever reaches `.order`** — sorting is a classic SQL-injection
   surface.

## What changed

### 1. Model scopes (query logic lives here, cache-agnostic)

All query logic lives in `Book` scopes so the resolver stays thin and each
scope is independently unit-testable. Scopes know nothing about caching or
GraphQL.

- **`Book.search(term)`** — case-insensitive partial match on **title OR
  author** via Postgres `ILIKE`.
  - Blank/whitespace `term` is treated as *no search* (returns `all`).
  - User-typed `%`, `_`, and `\` are escaped with `sanitize_sql_like` so they
    match **literally**, not as ILIKE wildcards.
  - Parameterized bind (`where("title ILIKE :pattern OR author ILIKE :pattern",
    pattern:)`) — never string interpolation.
- **`Book.price_at_least(min)` / `Book.price_at_most(max)`** — inclusive,
  independently optional bounds using endless/beginless ranges
  (`where(price: min..)` / `where(price: ..max)`). `min > max` naturally yields
  an empty result — no special-casing, no error.
- **`Book.sorted_by(field, direction)`** — maps the GraphQL enum values through
  **frozen whitelists** (`SORT_COLUMNS`, `SORT_DIRECTIONS`) to safe column and
  direction literals via `.fetch`, then `order(column => direction)`.
  `sorted_by(nil, nil)` returns `created_at DESC` (newest first) — the single
  source of truth for the default order.

### 2. Resolver (owns the cache boundary)

`BooksResolver` gains optional `search`, `minPrice`, `maxPrice`, `sortBy`, and
`sortDirection` arguments, and composes the scopes:

- **`queried_books`** chains scopes conditionally — `search` always, price
  scopes only when their arg is present, then `sorted_by` — so all active
  filters combine with **AND**.
- **`filters_present?`** is `true` when a trimmed search OR any price bound is
  present. **Sort is deliberately excluded** (see decision C below).
- **`serve_from_cache?` = `!filters_present? && default_sort?`** — the cache is
  served only for the true default view. Any active filter, or a non-default
  sort, runs the query directly and **never touches the cache**.
- The cached default path now uses `Book.sorted_by(nil, nil).to_a` (was
  `Book.all.to_a` in Day 7), so the cached list is ordered `created_at DESC`.

### 3. GraphQL enums (the security boundary)

Two new `Types::BaseEnum` subclasses — the first enums in the schema:

- **`BookSortField`** — `TITLE`, `PRICE`, `CREATED_AT` (→ `:title`, `:price`,
  `:created_at`).
- **`SortDirection`** — `ASC`, `DESC` (→ `:asc`, `:desc`).

Invalid values are rejected by GraphQL **schema validation** before resolver
code runs — the first of two independent gates keeping user input out of SQL.

## New GraphQL API surface

```graphql
enum BookSortField { TITLE PRICE CREATED_AT }
enum SortDirection { ASC DESC }

type Query {
  books(
    search: String          # matches title OR author, ILIKE, blank = no filter
    minPrice: Int           # inclusive lower bound (omit for no bound)
    maxPrice: Int           # inclusive upper bound (omit for no bound)
    sortBy: BookSortField   # default: CREATED_AT
    sortDirection: SortDirection  # default: DESC
  ): [Book!]!
}
```

All arguments are optional. With none supplied, `books` returns the full list
ordered newest-first, served from the `books/all` cache.

## Key design decisions

**A. Why filtered queries bypass the cache instead of caching per-filter.**
The cache is a single fixed key `books/all`, and `Book#invalidate_cache` (from
Day 7) only deletes `books/all` and `books/{id}`. A per-filter key like
`books/search=ruby&min=200` would **never be invalidated** — the next book edit
would leave it stale forever. So the rule is: any active filter bypasses the
cache entirely. Filtered reads hit Postgres every time, but they are never
wrong. *You may only cache what you can invalidate.*

**B. Whitelisted enums + parameterized values = no injection.** User input
never touches `.order`. The enum rejects bad `sortBy`/`sortDirection` at the
schema layer; `SORT_COLUMNS.fetch`/`SORT_DIRECTIONS.fetch` then map to
hard-coded literals — two independent gates. Free-text search values get the
other treatment: `sanitize_sql_like` + parameterized ILIKE. **Rule of thumb:
whitelist columns/directions, parameterize values, interpolate neither.**

**C. Why sort is excluded from `filters_present?`.** Because the cached list is
itself `created_at DESC` (`sorted_by(nil, nil)`), a request that explicitly asks
for "newest first" has the *same ordering* as the cache and can be served from
it — that's what `default_sort?` checks. But `TITLE:ASC` (or even
`CREATED_AT:ASC`) produces a different order, so it bypasses. Keeping the
default in one place (`DEFAULT_SORT_FIELD` / `DEFAULT_SORT_DIRECTION`)
guarantees the cached order and an explicit default-sort request can't drift
apart.

**D. Thin resolver, fat model.** Query logic is in scopes (testable, reusable,
cache-agnostic); the resolver only composes them and owns the one thing scopes
shouldn't know about — caching. Dependency direction is strict: resolver →
scopes → ActiveRecord, never backward.

## Files

- `app/models/book.rb` — `search`, `price_at_least`, `price_at_most`,
  `sorted_by` scopes; `SORT_COLUMNS`/`SORT_DIRECTIONS` whitelists; default-sort
  constants. (`after_commit :invalidate_cache` unchanged from Day 7.)
- `app/graphql/resolvers/books_resolver.rb` — arguments; `queried_books`;
  `filters_present?`; `default_sort?`; `serve_from_cache?`.
- `app/graphql/types/book_sort_field_enum.rb`, `sort_direction_enum.rb` — new
  enums.
- `spec/models/book_spec.rb`, `spec/graphql/resolvers/books_resolver_spec.rb` —
  tests.

## Tests

`bundle exec rspec` → 77 examples, 0 failures. Coverage includes:

- ILIKE matching on title and author, case-insensitivity, no-match → empty.
- Blank/whitespace search → full list; wildcard escaping (`%`, `_`, `\` each
  with a decoy row that would false-match if unescaped).
- Inclusive price bounds (boundary at exactly min/max included); min-only,
  max-only, both; `min > max` → empty.
- Enum ordering for all three columns in both directions; default →
  `created_at DESC`; invalid enum literal rejected by schema (errors present,
  data nil).
- AND composition (a book matching search but out of price range is excluded).
- **Cache behavior** — active search/price bypasses `books/all` (neither read
  nor written); a non-default sort with no filter bypasses too; the true
  default is served from cache and the cached list is `created_at DESC`.
  (Uses a `MemoryStore` around-hook, since the test env cache is `:null_store`.)

## Slice-by-slice

| Slice | Backend delta | Tests added |
|-------|---------------|-------------|
| 1 — Search | `search` scope + arg; cache bypass when search active | +17 |
| 2 — Price | `price_at_least`/`price_at_most` scopes + args; AND with search | +9 |
| 3 — Sort | `BookSortField`/`SortDirection` enums + `sorted_by`; default `created_at DESC`; cached default made order-consistent | +18 |
| 4 — Polish | *(frontend-only; no backend change)* | — |

## Try it yourself

Boot Postgres + Redis (`docker compose up db redis`) and the server
(`bin/rails server -p 3002`), open `/graphiql`, and run:

```graphql
query {
  books(search: "ruby", minPrice: 200, sortBy: PRICE, sortDirection: ASC) {
    title
    author
    price
  }
}
```

## Follow-up / evolution triggers

- **A `Book.filter(params)` query object** — extract the resolver's conditional
  scope-chaining if it grows past ~3–4 args or gains a second caller.
- **Pagination** (`limit`/`offset` or cursors, plus `totalCount`) — will stress
  the single-key cache design.
- **Full-text search** — swap ILIKE for a Postgres `tsvector` column when
  substring matching stops being enough.
