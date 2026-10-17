import { DatabaseSync } from 'node:sqlite';
import { readFileSync, mkdirSync, mkdtempSync } from 'node:fs';
import { fileURLToPath } from 'node:url';
import { join } from 'node:path';
import assert from 'node:assert/strict';
import test from 'node:test';

// Tests the executable SQL DESIGN, not generated Drift code or Android storage.
const schema = readFileSync(new URL('../lib/core/database/schema.sql', import.meta.url), 'utf8');
function createDatabase(path = ':memory:') {
  const db = new DatabaseSync(path);
  db.exec(schema);
  db.prepare('INSERT INTO categories(id,name) VALUES (?,?)').run('food', '餐饮');
  return db;
}
function insert(db, id, fen, date = '2026-10-17', category = 'food', kind = 'expense') {
  db.prepare(`INSERT INTO ledger_entries
    (id,amount_fen,kind,occurred_local,occurred_at_utc_ms,category_id,
     created_at_utc_ms,updated_at_utc_ms) VALUES (?,?,?,?,0,?,0,0)`)
    .run(id, fen, kind, date, category);
}
function spent(db, month) {
  return db.prepare(`SELECT COALESCE(SUM(amount_fen),0) AS total FROM ledger_entries
    WHERE kind='expense' AND substr(occurred_local,1,7)=?`).get(month).total;
}

test('integer fen aggregation is exact', () => {
  const db = createDatabase();
  try {
    insert(db, 'a', 10); insert(db, 'b', 20);
    assert.equal(spent(db, '2026-10'), 30);
    assert.equal(db.prepare('SELECT typeof(amount_fen) AS t FROM ledger_entries LIMIT 1').get().t, 'integer');
  } finally { db.close(); }
});

test('invalid amount, precision, type, kind and missing category are rejected', () => {
  const db = createDatabase();
  try {
    for (const value of [0, -1, 1.5, 'NaN', 100000000000]) {
      assert.throws(() => insert(db, 'bad', value), undefined, String(value));
    }
    assert.throws(() => insert(db, 'bad', 1, '2026-10-17', 'missing'));
    assert.throws(() => insert(db, 'bad', 1, '2026-10-17', 'food', 'transfer'));
    assert.equal(spent(db, '2026-10'), 0);
  } finally { db.close(); }
});

test('unset, zero and duplicate month budgets remain distinguishable', () => {
  const db = createDatabase();
  try {
    const query = db.prepare('SELECT amount_fen FROM monthly_budgets WHERE month=?');
    assert.equal(query.get('2026-10'), undefined);
    db.prepare('INSERT INTO monthly_budgets VALUES (?,0,0)').run('2026-10');
    assert.equal(query.get('2026-10').amount_fen, 0);
    assert.throws(() => db.prepare("INSERT INTO monthly_budgets VALUES ('2026-10',100,0)").run());
    assert.throws(() => db.prepare("INSERT INTO monthly_budgets VALUES ('2026-11',-1,0)").run());
  } finally { db.close(); }
});

test('edit, cross-month move and deletion recalculate aggregates', () => {
  const db = createDatabase();
  try {
    insert(db, 'a', 60000);
    db.prepare("UPDATE ledger_entries SET amount_fen=61000 WHERE id='a'").run();
    assert.equal(spent(db, '2026-10'), 61000);
    db.prepare("UPDATE ledger_entries SET occurred_local='2026-09-30' WHERE id='a'").run();
    assert.equal(spent(db, '2026-10'), 0);
    assert.equal(spent(db, '2026-09'), 61000);
    db.prepare("DELETE FROM ledger_entries WHERE id='a'").run();
    assert.equal(spent(db, '2026-09'), 0);
  } finally { db.close(); }
});

test('income and other months do not consume monthly expense budget', () => {
  const db = createDatabase();
  try {
    insert(db, 'a', 100);
    insert(db, 'b', 200, '2026-09-30');
    insert(db, 'c', 300, '2026-10-17', 'food', 'income');
    assert.equal(spent(db, '2026-10'), 100);
  } finally { db.close(); }
});

test('all-category and daily sums agree with monthly total', () => {
  const db = createDatabase();
  try {
    insert(db, 'a', 1800); insert(db, 'b', 1200, '2026-10-16');
    const byDay = db.prepare(`SELECT SUM(amount_fen) total FROM ledger_entries
      WHERE kind='expense' GROUP BY occurred_local`).all();
    const byCategory = db.prepare(`SELECT SUM(amount_fen) total FROM ledger_entries
      WHERE kind='expense' GROUP BY category_id`).all();
    assert.equal(byDay.reduce((sum, r) => sum + r.total, 0), 3000);
    assert.equal(byCategory.reduce((sum, r) => sum + r.total, 0), 3000);
  } finally { db.close(); }
});

test('a failed import-like transaction rolls back without changing old entries', () => {
  const db = createDatabase();
  try {
    insert(db, 'old', 1234);
    db.exec('BEGIN');
    try {
      db.exec('DELETE FROM ledger_entries');
      insert(db, 'new', 10); insert(db, 'broken', 0);
      assert.fail('invalid amount must fail');
    } catch { db.exec('ROLLBACK'); }
    assert.equal(spent(db, '2026-10'), 1234);
    assert.equal(db.prepare('SELECT id FROM ledger_entries').get().id, 'old');
  } finally { db.close(); }
});

test('foreign key prevents removing a category with existing entries', () => {
  const db = createDatabase();
  try {
    insert(db, 'a', 1);
    assert.throws(() => db.prepare("DELETE FROM categories WHERE id='food'").run());
  } finally { db.close(); }
});

test('SQL data survives file close/reopen', () => {
  const base = fileURLToPath(new URL('../.local/', import.meta.url));
  mkdirSync(base, { recursive: true });
  const dir = mkdtempSync(join(base, 'schema-validation-'));
  const path = join(dir, 'test.sqlite');
  const db = createDatabase(path);
  insert(db, 'persisted', 3800);
  db.close();
  const reopened = new DatabaseSync(path);
  try { assert.equal(spent(reopened, '2026-10'), 3800); }
  finally { reopened.close(); }
});
