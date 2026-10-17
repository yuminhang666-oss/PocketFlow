// Independent SQLite + artifact reference checks. These DO NOT execute Dart.
// node --test lib/features/export/verification/reference_checks.mjs
import { test } from 'node:test';
import assert from 'node:assert/strict';
import { readFileSync, readdirSync, existsSync } from 'node:fs';
import { fileURLToPath } from 'node:url';
import { resolve, dirname, join } from 'node:path';
import { DatabaseSync } from 'node:sqlite';

const root = fileURLToPath(new URL('../../../../', import.meta.url));
const schemaPath = process.env.POCKETFLOW_VALIDATION_SCHEMA ??
  join(root, 'lib/core/database/schema.sql');
const schema = readFileSync(schemaPath, 'utf8');
const backup = JSON.parse(readFileSync(join(root,
  'lib/features/backup/examples/fixture-backup-v1.json'), 'utf8'));
const markdown = readFileSync(join(root,
  'lib/features/export/examples/fixture-report-2026-10.md'), 'utf8');
const start = '2026-10-01';
const cutoff = '2026-10-17';
function database() {
  const db = new DatabaseSync(':memory:');
  db.exec(schema);
  for (const c of backup.categories) db.prepare(
    'INSERT INTO categories(id,name,sort_order,is_archived) VALUES(?,?,?,?)'
  ).run(c.id, c.name, c.sortOrder, +c.isArchived);
  for (const b of backup.budgets) db.prepare(
    'INSERT INTO monthly_budgets(month,amount_fen,updated_at_utc_ms) VALUES(?,?,?)'
  ).run(b.month, b.amountFen, b.updatedAtUtcMs);
  for (const e of backup.entries) db.prepare(
    'INSERT INTO ledger_entries(id,amount_fen,kind,occurred_local,' +
    'occurred_at_utc_ms,category_id,note,created_at_utc_ms,updated_at_utc_ms)' +
    ' VALUES(?,?,?,?,?,?,?,?,?)'
  ).run(e.id, e.amountFen, e.kind, e.localDate, e.occurredAtUtcMs,
    e.categoryId, e.note, e.createdAtUtcMs, e.updatedAtUtcMs);
  return db;
}
function withDatabase(action) {
  const db = database();
  try { action(db); } finally { db.close(); }
}
function total(db) {
  return db.prepare("SELECT COALESCE(SUM(amount_fen),0) AS fen FROM ledger_entries " +
    "WHERE kind='expense' AND occurred_local BETWEEN ? AND ?").get(start, cutoff).fen;
}
function money(fen) { return `${Math.trunc(fen / 100)}.${String(fen % 100).padStart(2, '0')}`; }

test('reference fixture is explicit v1 integer-fen backup, includes income and future', () => {
  assert.equal(backup.appId, 'pocketflow');
  assert.equal(backup.formatVersion, 1);
  assert.equal(backup.currency, 'CNY');
  assert.equal(new Set(backup.entries.map(e => e.id)).size, backup.entries.length);
  assert.ok(backup.entries.every(e => Number.isSafeInteger(e.amountFen) && e.amountFen > 0));
  assert.equal(backup.entries.filter(e => e.kind === 'income').length, 1);
  assert.equal(backup.entries.filter(e => e.localDate > cutoff).length, 1);
  assert.ok(markdown.startsWith('> 虚构验证夹具，不是用户账单。'));
});

test('SQL expense/income/cutoff calculation agrees with expected Markdown budget', () => withDatabase(db => {
  assert.equal(total(db), 61800);
  assert.ok(markdown.includes(`| 截止日累计支出 | ${money(total(db))} |`));
  const budget = db.prepare('SELECT amount_fen AS fen FROM monthly_budgets').get().fen;
  assert.ok(markdown.includes(`| 剩余预算 | ${money(budget - total(db))} |`));
  assert.ok(markdown.includes('| 预算使用率 | 41.20% |'));
}));

test('SQL category totals and independently rounded ratios agree with reference', () => withDatabase(db => {
  const rows = db.prepare("SELECT category_id AS id,SUM(amount_fen) AS fen " +
    "FROM ledger_entries WHERE kind='expense' AND occurred_local BETWEEN ? AND ? " +
    'GROUP BY category_id ORDER BY category_id').all(start, cutoff);
  assert.equal(rows.reduce((s, r) => s + r.fen, 0), total(db));
  for (const row of rows) {
    const percentage = (row.fen / total(db) * 100).toFixed(2);
    const category = backup.categories.find(c => c.id === row.id);
    assert.ok(markdown.includes(`| ${row.id} | ${category.name} | ${money(row.fen)} | ${percentage}% |`));
  }
}));

test('SQL recursive calendar fills zero days and matches all reference daily rows', () => withDatabase(db => {
  const rows = db.prepare(`WITH RECURSIVE dates(day) AS (
    SELECT ? UNION ALL SELECT date(day,'+1 day') FROM dates WHERE day < ?
  ) SELECT dates.day,COALESCE(SUM(e.amount_fen),0) AS fen FROM dates
    LEFT JOIN ledger_entries e ON e.occurred_local=dates.day AND e.kind='expense'
    GROUP BY dates.day ORDER BY dates.day`).all(start, cutoff);
  assert.equal(rows.length, 17);
  assert.equal(rows.reduce((s, r) => s + r.fen, 0), total(db));
  for (const row of rows) assert.ok(markdown.includes(`| ${row.day} | ${money(row.fen)} |`));
  assert.equal(Math.round(total(db) / rows.length), 3635);
  assert.ok(markdown.includes('| 日均支出（元） | 36.35 |'));
  assert.equal(Math.max(...rows.map(r => r.fen)), 60000);
}));

test('deletion/editing/month move recomputes reference sums without cached totals', () => withDatabase(db => {
  db.prepare("UPDATE ledger_entries SET amount_fen=61000 WHERE id='a'").run();
  assert.equal(total(db), 62800);
  db.prepare("UPDATE ledger_entries SET occurred_local='2026-09-30' WHERE id='a'").run();
  assert.equal(total(db), 1800);
  db.prepare("DELETE FROM ledger_entries WHERE id='b'").run();
  assert.equal(total(db), 0);
}));

test('integer reference line ends at zero; overspend and zero-budget are distinct', () => {
  const reference = day => 150000n - 150000n * BigInt(day) / 31n;
  assert.equal(reference(17), 67742n);
  assert.equal(reference(31), 0n);
  assert.equal(150000 - 61800, 88200);
  assert.equal(0 - 61800, -61800);
  assert.equal(10000 - 61800, -51800);
});

test('reference transaction rows retain UTC, income, notes, valid table structure', () => {
  const section = markdown.split('## 完整逐笔交易记录')[1].split('## 关键统计指标')[0];
  const rows = section.split('\n').filter(line => /^\| [abc] \|/.test(line));
  assert.equal(rows.length, 3);
  assert.ok(rows.every(row => row.split('|').length === 9));
  assert.ok(rows[0].includes('&#124;') && rows[0].includes('&lt;script&gt;') && rows[0].includes('<br>'));
  assert.ok(rows[1].includes('收入') && rows[1].includes('200.00'));
  assert.ok(rows.every(row => !row.includes('future')));
});

test('C sources and example files decode strictly as UTF-8; relative imports exist', () => {
  function visit(directory) {
    for (const entry of readdirSync(directory, { withFileTypes: true })) {
      const path = join(directory, entry.name);
      if (entry.isDirectory()) { visit(path); continue; }
      const content = new TextDecoder('utf-8', {fatal:true}).decode(readFileSync(path));
      if (!entry.name.endsWith('.dart') && !entry.name.endsWith('.dart.txt')) continue;
      for (const match of content.matchAll(/(?:import|export)\s+'(\.[^']+)'/g)) {
        assert.ok(existsSync(resolve(dirname(path), match[1])), `Missing import ${path}: ${match[1]}`);
      }
    }
  }
  for (const module of ['statistics', 'export', 'backup']) visit(join(root, 'lib/features', module));
});

test('pure production aggregation/serialization contains no platform or network import', () => {
  for (const module of ['statistics', 'export', 'backup']) {
    for (const name of readdirSync(join(root, 'lib/features', module, 'domain'))) {
      const content = readFileSync(join(root, 'lib/features', module, 'domain', name), 'utf8');
      assert.ok(!/import\s+['"](?:dart:io|package:|.*core\/database)/.test(content));
    }
  }
});
