---
name: sql
description: >
  Working against a SQL database or warehouse — query-for-features discipline. Carries: push
  compute to the database (aggregate/filter/join there; pull results, not tables), window
  functions for leakage-safe historical features (frames ending at `1 PRECEDING`, never the
  current row's future), the join-explosion check (know the grain; validate row counts before and
  after), parametrized queries only (never f-string SQL), sampling strategies for EDA on big
  tables, snapshotting query results that training consumes (a live query is an unpinned
  dependency), queries as versioned `.sql` files, and read-only credentials for analysis. Load
  when data lives in Postgres/BigQuery/Snowflake/DuckDB/SQLite. Triggers: SQL, query, database,
  warehouse, Postgres, BigQuery, Snowflake, DuckDB, join, window function, GROUP BY, write a
  query, pull from the database, NL-to-SQL, table, schema, CTE.
---

# sql — the database as a feature engine, not a file server

> **Scope: analytics.** This skill is about answering questions from data at rest — warehouses,
> query engines, and the discipline that keeps a query honest. **The application's transactional
> database is `relational-stores`**: schema design, migrations, connection pooling, indexes and
> query plans, transactions and isolation. Both are SQL; the failure modes have almost nothing in
> common. Table formats and object storage are `object-and-lakehouse`.
>
> On-demand: load this when the project's data lives behind a query engine. The split/leakage
> canon is still `datasets`; feature hypotheses still land in the feature dictionary (P4); this
> skill is the *mechanics* of doing that work in SQL without the classic silent failures.

## Push compute down; pull results, not tables
`SELECT *` into pandas and aggregating there is the anti-pattern: slow, memory-bound, and it
duplicates logic the database does better. Aggregate, filter, join, and window **in the query**;
what crosses the wire is the modeling table. pandas (`wrangling`) starts where SQL stops being
readable — not before.

## Leakage-safe historical features (the window-frame rule)
The P4 rule "only information available at prediction time" has an exact SQL form — the frame
must end **before** the current row:
```sql
AVG(outcome) OVER (
  PARTITION BY entity_id ORDER BY event_time
  ROWS BETWEEN UNBOUNDED PRECEDING AND 1 PRECEDING   -- never CURRENT ROW for target-derived
) AS entity_history_rate
```
A frame that includes the current row leaks the label into its own feature; a plain
`GROUP BY entity` aggregate computed over all time leaks the future into every row. Time-order
matters for splits too — the temporal split (`datasets`/`timeseries`) is a `WHERE event_time`
boundary, applied in the query, same boundary everywhere.

## Joins: know the grain, prove it held
Every join has an expected cardinality — state it and check it:
- Row counts before and after; an unexplained growth is a many-to-many explosion silently
  duplicating (and up-weighting) rows.
- Anti-join the unmatched (`LEFT JOIN ... WHERE right.key IS NULL`) — unmatched rows are either
  a filter you're applying by accident or a data-quality finding for P2's notes.
- Deduplicate keys *deliberately* (`ROW_NUMBER() OVER (PARTITION BY key ORDER BY ...) = 1`),
  with the ORDER BY making the kept row a decision, not an accident.

## Mechanics that keep it safe and reproducible
- **Parametrize, never interpolate** — placeholders (`%s`, `:name`) not f-strings: injection
  (security canon) and query-plan reuse. Analysis work runs on a **read-only role**.
- **Queries are code:** versioned `.sql` files (or one query module), not strings scattered in
  notebooks — the feature dictionary references them by name.
- **Snapshot what training eats.** A model trained on `SELECT ... FROM live_table` is pinned to
  nothing. Materialize the training extract (table-as-of or exported file), version it
  (`data-dvc`), and record extract time + row count in the manifest.
- **EDA on big tables:** `TABLESAMPLE` / hash-sampling (`WHERE MOD(ABS(HASH(id)), 100) = 0`) for
  a stable sample — `LIMIT` without ORDER BY is whatever the engine felt like.
