-- Executable schema DESIGN prototype. Generated Drift schema is validated later.
PRAGMA foreign_keys = ON;
CREATE TABLE categories (
  id TEXT NOT NULL PRIMARY KEY,
  name TEXT NOT NULL CHECK(length(name) BETWEEN 1 AND 30),
  sort_order INTEGER NOT NULL DEFAULT 0,
  is_archived INTEGER NOT NULL DEFAULT 0 CHECK(is_archived IN (0,1))
);
CREATE TABLE monthly_budgets (
  month TEXT NOT NULL PRIMARY KEY CHECK(length(month) = 7),
  amount_fen INTEGER NOT NULL CHECK(typeof(amount_fen) = 'integer' AND amount_fen BETWEEN 0 AND 99999999999),
  updated_at_utc_ms INTEGER NOT NULL
);
CREATE TABLE ledger_entries (
  id TEXT NOT NULL PRIMARY KEY,
  amount_fen INTEGER NOT NULL CHECK(typeof(amount_fen) = 'integer' AND amount_fen BETWEEN 1 AND 99999999999),
  kind TEXT NOT NULL CHECK(kind IN ('expense','income')),
  occurred_local TEXT NOT NULL CHECK(length(occurred_local) = 10),
  occurred_at_utc_ms INTEGER NOT NULL,
  category_id TEXT NOT NULL REFERENCES categories(id),
  note TEXT NOT NULL DEFAULT '' CHECK(length(note) <= 500),
  created_at_utc_ms INTEGER NOT NULL,
  updated_at_utc_ms INTEGER NOT NULL
);
CREATE INDEX ledger_entries_local_date
  ON ledger_entries(occurred_local, occurred_at_utc_ms);
