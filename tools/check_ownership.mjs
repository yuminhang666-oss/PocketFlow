import { execFileSync } from 'node:child_process';

export function checkOwnership(branch, paths) {
  const root = /^(integration|contract)\//.test(branch)
    || /^codex\/v030-(s0|control|contract)-/.test(branch);
  const role = branch.startsWith('feat/a-') ? 'A'
    : branch.startsWith('feat/b-') ? 'B'
    : branch.startsWith('feat/c-') ? 'C'
    : branch.startsWith('chore/d-') ? 'D' : null;
  const allow = {
    A: /^(lib\/app\/(?!composition\/)|lib\/shared\/widgets\/|lib\/features\/(home|entry_editor|ledger_list|settings)\/presentation\/|design\/|docs\/module-notes\/A\.md$|docs\/ui-ux-proposal-v1\.md$)/,
    B: /^(lib\/core\/database\/|lib\/features\/budget\/(domain|application)\/|lib\/features\/transactions\/|docs\/module-notes\/B\.md$)/,
    C: /^(lib\/features\/(statistics|export|backup)\/|docs\/module-notes\/C\.md$)/,
    D: /^(test\/|integration_test\/|android\/|\.github\/workflows\/|tools\/(?!check_ownership\.mjs$)|docs\/module-notes\/D\.md$|docs\/qa-report\.md$)/,
  };
  if (root) return [];
  if (!role) throw new Error('Use a documented module or integration branch.');
  return paths.filter(path => !allow[role].test(path));
}

if (process.argv[1]?.endsWith('check_ownership.mjs')) {
  const [branch, base, head] = process.argv.slice(2);
  if (!branch || !/^[a-f0-9]{40}$/.test(base ?? '') || !/^[a-f0-9]{40}$/.test(head ?? '')) {
    throw new Error('Usage: node tools/check_ownership.mjs BRANCH BASE_SHA HEAD_SHA');
  }
  const paths = execFileSync('git', ['diff', '--name-only', '-z', `${base}...${head}`],
    { encoding: 'utf8' }).split('\0').filter(Boolean);
  const rejected = checkOwnership(branch, paths);
  if (rejected.length) {
    process.stderr.write(`Changes outside module ownership:\n${rejected.join('\n')}\n`);
    process.exitCode = 1;
  } else process.stdout.write(`Ownership accepted: ${paths.length} paths\n`);
}
