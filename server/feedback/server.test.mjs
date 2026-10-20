import test from 'node:test';
import assert from 'node:assert/strict';
import {mkdtempSync,rmSync} from 'node:fs';
import {tmpdir} from 'node:os';
import {join} from 'node:path';
import {randomUUID} from 'node:crypto';
import {FeedbackService,validateFeedback,issueBody,feedbackHttpHandler} from './server.mjs';
import {createServer} from 'node:http';
const payload=()=>({feedbackId:randomUUID(),type:'bug',content:'SYNTHETIC feedback for local tests only',privacyNoticeVersion:1});
const salt='SYNTHETIC-RATE-SALT-LOCAL-ONLY';
test('persistent receipt is returned only after Issue creation; same ID conflicts on edits',async()=>{
  let count=0;const github={ensurePrivate:async()=>{},create:async()=>++count,find:async()=>[]};
  const dir=mkdtempSync(join(tmpdir(),'pf-feedback-test-')),path=join(dir,'test.sqlite'),body=payload();
  let service=new FeedbackService({databasePath:path,github,rateSalt:salt});
  try{const first=await service.accept(body);assert.equal(count,1);assert.ok(first.receiptId);service.close();service=new FeedbackService({databasePath:path,github,rateSalt:salt});assert.deepEqual(await service.accept(body),first);assert.equal(count,1);await assert.rejects(service.accept({...body,content:'SYNTHETIC edited feedback'}),e=>e.status===409);}finally{service.close();rmSync(dir,{recursive:true});}
});
test('Issue success then timeout reconciles after restart without a second POST',async()=>{
  const dir=mkdtempSync(join(tmpdir(),'pf-feedback-test-')),path=join(dir,'test.sqlite'),body=payload();let posted=0;
  const github={ensurePrivate:async()=>{},create:async()=>{posted++;throw new Error('SYNTHETIC response lost');},find:async()=>[42]};
  let service=new FeedbackService({databasePath:path,github,rateSalt:salt});
  try{await assert.rejects(service.accept(body),e=>e.code==='RECONCILIATION_REQUIRED');service.close();service=new FeedbackService({databasePath:path,github,rateSalt:salt});assert.ok((await service.accept(body)).receiptId);assert.equal(posted,1);}finally{service.close();rmSync(dir,{recursive:true});}
});
test('uncertain absence never blindly creates again; definite 429 can retry',async()=>{
  let posts=0;const github={ensurePrivate:async()=>{},create:async()=>{posts++;throw new Error('SYNTHETIC unknown');},find:async()=>[]};const service=new FeedbackService({databasePath:':memory:',github,rateSalt:salt});
  try{const body=payload();await assert.rejects(service.accept(body));await assert.rejects(service.accept(body));assert.equal(posts,1);
    github.create=async()=>{const e=new Error('SYNTHETIC 429');e.definitelyNotCreated=true;throw e;};const other=payload();await assert.rejects(service.accept(other));github.create=async()=>73;assert.ok((await service.accept(other)).receiptId);
  }finally{service.close();}
});
test('validation rejects unexpected financial data, boundaries and invalid types',()=>{
  assert.throws(()=>validateFeedback({...payload(),entries:[]}));assert.throws(()=>validateFeedback({...payload(),content:'short'}));assert.throws(()=>validateFeedback({...payload(),contact:'a'.repeat(101)}));assert.throws(()=>validateFeedback({...payload(),androidApi:36}));
  assert.equal([...validateFeedback({...payload(),content:'中'.repeat(2000)}).content].length,2000);
});
test('concurrent duplicate calls claim one Issue; rate limit is persistent',async()=>{
  let release,posts=0;const gate=new Promise(r=>release=r),github={ensurePrivate:async()=>{},create:async()=>{posts++;await gate;return 8;},find:async()=>[]};const service=new FeedbackService({databasePath:':memory:',github,rateSalt:salt});
  try{const body=payload(),first=service.accept(body);await assert.rejects(service.accept(body));release();await first;assert.equal(posts,1);github.create=async()=>9;for(let i=0;i<8;i++)await service.accept(payload());await assert.rejects(service.accept(payload()),e=>e.status===429);}finally{service.close();}
});
test('private destination check fails closed and does not issue a public POST',async()=>{
  let posts=0;const github={ensurePrivate:async()=>{const e=new Error('public');e.definitelyNotCreated=true;throw e;},create:async()=>++posts,find:async()=>[]},service=new FeedbackService({databasePath:':memory:',github,rateSalt:salt});try{await assert.rejects(service.accept(payload()));assert.equal(posts,0);}finally{service.close();}
});
test('issue body avoids active mentions and embedded HTML',()=>{const p=validateFeedback({...payload(),content:'SYNTHETIC @all <img> `code`'}),body=issueBody(p,'hash',0);assert.equal(body.includes('@all'),false);assert.equal(body.includes('<img>'),false);assert.ok(body.includes('pocketflow-feedback:'));});

test('loopback HTTP boundary requires TLS proxy, validates bodies and returns only persisted receipts',async()=>{
  let posts=0;
  const service=new FeedbackService({databasePath:':memory:',github:{ensurePrivate:async()=>{},create:async()=>++posts,find:async()=>[]},rateSalt:salt});
  const server=createServer(feedbackHttpHandler(service,{trustedTlsProxy:true}));
  await new Promise(resolve=>server.listen(0,'127.0.0.1',resolve));
  const url=`http://127.0.0.1:${server.address().port}/v1/feedback`,body=payload();
  const send=(value,headers={})=>fetch(url,{method:'POST',headers:{'Content-Type':'application/json',...headers},body:typeof value==='string'?value:JSON.stringify(value)});
  try{
    assert.equal((await send(body)).status,400);
    const headers={'X-Forwarded-Proto':'https','X-Real-IP':'192.0.2.1'};
    assert.equal((await send('{',headers)).status,400);
    assert.equal((await send('x'.repeat(33000),headers)).status,413);
    assert.equal((await send(body,{...headers,'Content-Type':'text/plain'})).status,415);
    const a=await send(body,headers);assert.equal(a.status,200);const receipt=await a.json();
    assert.ok(receipt.receiptId);assert.deepEqual(await (await send(body,headers)).json(),receipt);assert.equal(posts,1);
  }finally{server.closeAllConnections();await new Promise(resolve=>server.close(resolve));service.close();}
});
