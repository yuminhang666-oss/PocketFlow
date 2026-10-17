// Static UI boundary/asset inspection. This is NOT a Dart/Flutter test runner.
import fs from 'node:fs';
import path from 'node:path';
import { execFileSync } from 'node:child_process';
import { fileURLToPath } from 'node:url';
import { checkOwnership } from '../../tools/check_ownership.mjs';

const root = path.resolve(path.dirname(fileURLToPath(import.meta.url)), '../..');
const git = args => execFileSync('git', args, { cwd: root, encoding: 'utf8' });
const baseline = process.argv[2] ?? '26d8e4b47eef5d17fe2ca8385da3ddb58adce95e';
if (!/^[a-f0-9]{40}$/.test(baseline)) throw new Error('Expected a baseline commit SHA');
const changed = [...new Set([
  ...git(['diff', '--name-only', '-z', baseline]).split('\0'),
  ...git(['ls-files', '--others', '--exclude-standard', '-z']).split('\0'),
].filter(Boolean))];
const rejected = checkOwnership('feat/a-ui-mvp', changed);
const missingImports = [];
const forbiddenImports = [];
const uiFiles = changed.filter(name => name.endsWith('.dart'));
for (const name of uiFiles) {
  const source = fs.readFileSync(path.join(root, name), 'utf8');
  for (const [, target] of source.matchAll(/^import '([^']+)';/gm)) {
    const resolved = target.startsWith('package:pocketflow/')
      ? path.join(root, 'lib', target.slice('package:pocketflow/'.length))
      : !target.includes(':') ? path.resolve(root, path.dirname(name), target) : null;
    if (resolved && !fs.existsSync(resolved)) missingImports.push(`${name}: ${target}`);
    if (name.startsWith('lib/') && /core\/database|budget_calculator|design\/ui-ux/.test(target)) {
      forbiddenImports.push(`${name}: ${target}`);
    }
  }
}
const doc = fs.readFileSync(path.join(root, 'docs/ui-ux-proposal-v1.md'), 'utf8');
const palette = Object.fromEntries([...doc.matchAll(/^\| (\w+) \| (#\w{6}) \| (#\w{6}) \|$/gm)]
  .map(([, name, light, dark]) => [name, [light, dark]]));
function luminance(hex) {
  const [r,g,b] = hex.slice(1).match(/../g).map(n => parseInt(n,16)/255)
    .map(n => n <= .04045 ? n/12.92 : ((n+.055)/1.055)**2.4);
  return .2126*r + .7152*g + .0722*b;
}
const contrast = [];
for (const [foreground, background] of [['ink','canvas'],['ink','surface'],['muted','canvas'],
  ['muted','surface'],['primary','surface'],['onPrimary','primary'],['onHero','hero'],
  ['danger','canvas'],['danger','surface']]) {
  for (const [index, mode] of ['light','dark'].entries()) {
    const a = luminance(palette[foreground][index]), b = luminance(palette[background][index]);
    const ratio = (Math.max(a,b)+.05)/(Math.min(a,b)+.05);
    contrast.push({ mode, pair: `${foreground}/${background}`, ratio: Number(ratio.toFixed(2)), pass: ratio >= 4.5 });
  }
}
const png = fs.readFileSync(path.join(root, 'design/ui-ux/design-board.png'));
const pngValid = png.subarray(0,8).equals(Buffer.from([137,80,78,71,13,10,26,10]));
const codes = fs.readFileSync(path.join(root,'lib/contracts/pocketflow_exception.dart'),'utf8')
  .match(/enum PocketFlowErrorCode\s*\{([^}]+)\}/s)[1].split(',').map(s=>s.trim()).filter(Boolean);
const errorUi = fs.readFileSync(path.join(root,'lib/shared/widgets/presentation_errors.dart'),'utf8');
const unmappedErrors = codes.filter(code => !errorUi.includes(`PocketFlowErrorCode.${code} =>`));
const report = {
  type: 'static inspection only; not Dart analysis, widget tests or device verification',
  changedPaths: changed.length,
  dartFilesInspected: uiFiles.length,
  ownershipRejected: rejected,
  missingImports,
  forbiddenImports,
  unmappedErrors,
  contrast,
  designPng: { valid: pngValid, width: png.readUInt32BE(16), height: png.readUInt32BE(20) },
};
console.log(JSON.stringify(report, null, 2));
if (rejected.length || missingImports.length || forbiddenImports.length || unmappedErrors.length ||
    contrast.some(check => !check.pass) || !pngValid) process.exitCode = 1;
