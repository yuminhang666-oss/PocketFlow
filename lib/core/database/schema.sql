-- Executable v2 schema design. Drift-generated parity must be verified by D.
-- v1 is the M0 three-table prototype; v2 strengthens constraints and adds recovery.
PRAGMA foreign_keys = ON;
CREATE TABLE categories (
  id TEXT NOT NULL PRIMARY KEY CHECK(length(id) BETWEEN 1 AND 64),
  name TEXT NOT NULL CHECK(length(name) BETWEEN 1 AND 30),
  sort_order INTEGER NOT NULL DEFAULT 0 CHECK(typeof(sort_order) = 'integer'),
  is_archived INTEGER NOT NULL DEFAULT 0 CHECK(typeof(is_archived) = 'integer' AND is_archived IN (0,1))
);
CREATE TABLE monthly_budgets (
  month TEXT NOT NULL PRIMARY KEY CHECK(length(month) = 7 AND month GLOB '[0-9][0-9][0-9][0-9]-[0-9][0-9]' AND substr(month, 1, 4) BETWEEN '1900' AND '9999' AND substr(month, 6, 2) BETWEEN '01' AND '12'),
  amount_fen INTEGER NOT NULL CHECK(typeof(amount_fen) = 'integer' AND amount_fen BETWEEN 0 AND 99999999999),
  updated_at_utc_ms INTEGER NOT NULL CHECK(typeof(updated_at_utc_ms) = 'integer' AND updated_at_utc_ms BETWEEN -8640000000000000 AND 8640000000000000)
);
CREATE TABLE ledger_entries (
  id TEXT NOT NULL PRIMARY KEY CHECK(length(id) BETWEEN 1 AND 64),
  amount_fen INTEGER NOT NULL CHECK(typeof(amount_fen) = 'integer' AND amount_fen BETWEEN 1 AND 99999999999),
  kind TEXT NOT NULL CHECK(kind IN ('expense','income')),
  occurred_local TEXT NOT NULL CHECK(length(occurred_local) = 10 AND occurred_local GLOB '[0-9][0-9][0-9][0-9]-[0-9][0-9]-[0-9][0-9]' AND substr(occurred_local, 1, 4) BETWEEN '1900' AND '9999' AND substr(occurred_local, 6, 2) BETWEEN '01' AND '12' AND CAST(substr(occurred_local, 9, 2) AS INTEGER) BETWEEN 1 AND CASE WHEN substr(occurred_local, 6, 2) = '02' THEN 28 + (CAST(substr(occurred_local, 1, 4) AS INTEGER) % 4 = 0 AND (CAST(substr(occurred_local, 1, 4) AS INTEGER) % 100 != 0 OR CAST(substr(occurred_local, 1, 4) AS INTEGER) % 400 = 0)) WHEN substr(occurred_local, 6, 2) IN ('04', '06', '09', '11') THEN 30 ELSE 31 END),
  occurred_at_utc_ms INTEGER NOT NULL CHECK(typeof(occurred_at_utc_ms) = 'integer' AND occurred_at_utc_ms BETWEEN -8640000000000000 AND 8640000000000000),
  category_id TEXT NOT NULL REFERENCES categories(id) CHECK(length(category_id) BETWEEN 1 AND 64),
  note TEXT NOT NULL DEFAULT '' CHECK(length(note) <= 500),
  created_at_utc_ms INTEGER NOT NULL CHECK(typeof(created_at_utc_ms) = 'integer' AND created_at_utc_ms BETWEEN -8640000000000000 AND 8640000000000000),
  updated_at_utc_ms INTEGER NOT NULL CHECK(typeof(updated_at_utc_ms) = 'integer' AND updated_at_utc_ms BETWEEN -8640000000000000 AND 8640000000000000 AND updated_at_utc_ms >= created_at_utc_ms)
);
CREATE INDEX ledger_entries_local_date
  ON ledger_entries(occurred_local, occurred_at_utc_ms, id);
CREATE TABLE recovery_snapshots (
  id TEXT NOT NULL PRIMARY KEY CHECK(length(id) BETWEEN 1 AND 64),
  created_at_utc_ms INTEGER NOT NULL CHECK(typeof(created_at_utc_ms) = 'integer' AND created_at_utc_ms BETWEEN -8640000000000000 AND 8640000000000000),
  payload TEXT NOT NULL
);
