// Controls only the disposable emulator for this version. Never selects a phone.
import {execFileSync} from 'node:child_process';
import {mkdirSync, writeFileSync, appendFileSync} from 'node:fs';
import {resolve} from 'node:path';
const serial = 'emulator-5584';
const out = process.env.PF041_EVIDENCE;
if (!out) throw Error('Set PF041_EVIDENCE to this version’s evidence folder.');
mkdirSync(out, {recursive:true});
const adb = (...args) => execFileSync('D:/Codex/PocketFlowTools/android-sdk/platform-tools/adb.exe', ['-s', serial, ...args], {maxBuffer:16*1024*1024});
const [action = 'capture', label = 'screen', extra] = process.argv.slice(2);
const decode = s => s.replace(/&quot;/g,'"').replace(/&amp;/g,'&').replace(/&#10;/g,'\n').replace(/&lt;/g,'<').replace(/&gt;/g,'>');
function nodes() {
  adb('shell','uiautomator','dump','/sdcard/pf041-qa.xml');
  const xml = adb('shell','cat','/sdcard/pf041-qa.xml').toString();
  return {xml, list:[...xml.matchAll(/<node\b([^>]+)>/g)].map(m=>Object.fromEntries([...m[1].matchAll(/([\w-]+)="([^"]*)"/g)].map(a=>[a[1],decode(a[2])])))};
}
if (action === 'capture') {
  if (!/^[a-zA-Z0-9_-]+$/.test(label)) throw Error('Unsafe evidence filename');
  const {xml,list} = nodes();
  writeFileSync(resolve(out, label+'.xml'), xml);
  writeFileSync(resolve(out, label+'.png'), adb('exec-out','screencap','-p'));
  console.log(list.filter(n=>n.text || n['content-desc']).map(n=>({text:n.text||n['content-desc'],bounds:n.bounds,click:n.clickable}))); 
} else if (action === 'tap') {
  const {list} = nodes();
  const clickable = list.filter(n=>n.clickable==='true' && n.enabled==='true');
  const matches = clickable.filter(n=>[n.text,n['content-desc'],n.hint].some(s=>s===label));
  const n = matches[Number(extra)||0] ?? clickable.find(n=>[n.text,n['content-desc'],n.hint].some(s=>s?.includes(label)));
  if (!n) throw Error('Visible enabled target missing: '+label);
  const [x1,y1,x2,y2] = n.bounds.match(/\d+/g).map(Number);
  adb('shell','input','tap',String(Math.round((x1+x2)/2)),String(Math.round((y1+y2)/2)));
} else if (action === 'back') adb('shell','input','keyevent','4');
else if (action === 'scroll') adb('shell','input','swipe','520','1600','520','620','350');
else if (action === 'start') adb('shell','am','start','-n','cn.pocketflow/.MainActivity');
else throw Error('Unknown action');
appendFileSync(resolve(out,'actions.jsonl'),JSON.stringify({at:new Date().toISOString(),action,label,extra})+'\n');
