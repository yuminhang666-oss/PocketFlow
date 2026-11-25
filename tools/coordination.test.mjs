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

test('planning, reports and feedback respect the documented ownership', () => {
  const reportUi = 'lib/features/reports/presentation/report_content.dart';
  const reportLogic = 'lib/features/reports/domain/range_report_service.dart';
  const statsUi = 'lib/features/statistics/presentation/statistics_page.dart';
  const planningData = 'lib/features/planning/data/planning_repository.dart';
  const planningUi = 'lib/features/planning/presentation/planning_page.dart';
  const reminder = 'lib/features/reminders/domain/reminder_policy.dart';
  const feedbackData = 'lib/features/feedback/data/android_feedback_mail_port.dart';
  const feedbackUi = 'lib/features/feedback/presentation/feedback_page.dart';
  assert.deepEqual(checkOwnership('feat/a-v050-ui',
    [reportUi, planningUi, feedbackUi, reportLogic, planningData, statsUi]),
    [reportLogic, planningData, statsUi]);
  assert.deepEqual(checkOwnership('feat/b-v050-ledger',
    [planningData, reminder, planningUi, reportUi]), [planningUi, reportUi]);
  assert.deepEqual(checkOwnership('feat/c-v050-report',
    [reportLogic, feedbackData, statsUi, feedbackUi, reportUi, planningData]),
    [feedbackUi, reportUi, planningData]);
});
