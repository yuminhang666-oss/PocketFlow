import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';
import test from 'node:test';
import { checkOwnership } from './check_ownership.mjs';

test('S0 controller can review integration while unknown roles stay rejected', () => {
  assert.deepEqual(checkOwnership('codex/v030-s0-review', ['lib/contracts/ledger_repository.dart']), []);
  assert.throws(() => checkOwnership('codex/v030-random', ['lib/contracts/ledger_repository.dart']));
});

test('module boundaries continue to reject cross-module changes', () => {
  assert.deepEqual(checkOwnership('feat/a-ui-mvp', ['lib/contracts/ledger_repository.dart']), ['lib/contracts/ledger_repository.dart']);
  assert.deepEqual(checkOwnership('feat/b-ledger-budget', ['lib/core/database/tables.dart']), []);
  assert.deepEqual(checkOwnership('feat/b-ledger-budget', ['lib/app/composition/pocketflow_root.dart']), ['lib/app/composition/pocketflow_root.dart']);
  assert.deepEqual(checkOwnership('chore/d-test-build', ['tools/check_ownership.mjs']), ['tools/check_ownership.mjs']);
});

test('both PR workflows include integration target branches', () => {
  for (const name of ['coordination.yml', 'flutter-qa.yml']) {
    const yaml = readFileSync(new URL(`../.github/workflows/${name}`, import.meta.url), 'utf8');
    assert.match(yaml, /pull_request:\s*\n\s*branches: \[main, 'integration\/\*\*', 'codex\/v030-control-\*', 'codex\/v030-s0-\*'\]/);
  }
});
