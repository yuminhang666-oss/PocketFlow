import { DatabaseSync } from 'node:sqlite';
import { createHash, createHmac, randomUUID, createSign } from 'node:crypto';
import { createServer } from 'node:http';
import { isIP } from 'node:net';
import { readFileSync } from 'node:fs';
import { pathToFileURL } from 'node:url';

export class FeedbackError extends Error {
  constructor(status, code) { super(code); this.status = status; this.code = code; }
}
const allowed = new Set(['feedbackId','type','content','steps','expected','actual','contact','appVersion','buildCode','androidApi','privacyNoticeVersion']);
export function validateFeedback(input) {
  if (!input || Array.isArray(input) || typeof input !== 'object' || Object.keys(input).some(k=>!allowed.has(k))) throw new FeedbackError(400,'INVALID_FIELDS');
  const text=(key,max,minimum=0)=>{const value=input[key]??'';if(typeof value!=='string')throw new FeedbackError(400,'INVALID_FIELDS');const result=value.trim();if([...result].length<minimum||[...result].length>max)throw new FeedbackError(400,'INVALID_LENGTH');return result;};
  if (!/^[a-f0-9]{8}-[a-f0-9]{4}-4[a-f0-9]{3}-[89ab][a-f0-9]{3}-[a-f0-9]{12}$/.test(input.feedbackId??'') || !['bug','suggestion'].includes(input.type) || input.privacyNoticeVersion!==1) throw new FeedbackError(400,'INVALID_FIELDS');
  const body={feedbackId:input.feedbackId,type:input.type,content:text('content',2000,10),steps:text('steps',2000),expected:text('expected',2000),actual:text('actual',2000),contact:text('contact',100),privacyNoticeVersion:1};
  if(input.appVersion!==undefined || input.buildCode!==undefined || input.androidApi!==undefined) {
    if(typeof input.appVersion!=='string'||!/^\d+\.\d+\.\d+(?:[+.-][A-Za-z0-9.-]+)?$/.test(input.appVersion)||input.appVersion.length>40 || !Number.isSafeInteger(input.buildCode)||input.buildCode<1 || input.androidApi!==undefined&&(!Number.isInteger(input.androidApi)||input.androidApi<1||input.androidApi>1000)) throw new FeedbackError(400,'INVALID_ENVIRONMENT');
    body.appVersion=input.appVersion;body.buildCode=input.buildCode;if(input.androidApi!==undefined)body.androidApi=input.androidApi;
  }
  return body;
}
const digest=value=>createHash('sha256').update(value).digest('hex');
const marker=(id,hash)=>`<!-- pocketflow-feedback:${id}:${hash} -->`;
export function issueBody(payload, hash, received) {
  // Plain fenced sections prevent user text from creating HTML or mentions.
  const escaped=value=>value.replaceAll('`','\u02cb').replaceAll('@','＠').replaceAll('<','＜').replaceAll('>','＞');
  const sections=[['内容',payload.content],['操作步骤',payload.steps],['期望结果',payload.expected],['实际结果',payload.actual],['联系方式（用户自填）',payload.contact]];
  return `${marker(payload.feedbackId,hash)}\n接收时间：${new Date(received).toISOString()}\n\n`+sections.filter(([,v])=>v).map(([k,v])=>`## ${k}\n\n\`\`\`text\n${escaped(v)}\n\`\`\``).join('\n\n')+(payload.appVersion?`\n\n环境（用户同意）：App ${payload.appVersion} / build ${payload.buildCode} / Android API ${payload.androidApi??'未附带'}`:'\n\n用户未附带环境信息。');
}

export class FeedbackService {
  constructor({databasePath, github, rateSalt, now=Date.now}) {
    if(!rateSalt||rateSalt.length<16)throw new Error('Configure a private rate-limit salt');
    this.db=new DatabaseSync(databasePath);this.github=github;this.now=now;this.rateSalt=rateSalt;
    this.db.exec(`PRAGMA journal_mode=WAL; PRAGMA busy_timeout=5000;
      CREATE TABLE IF NOT EXISTS feedback(id TEXT PRIMARY KEY, hash TEXT NOT NULL, payload TEXT NOT NULL,
        state TEXT NOT NULL CHECK(state IN ('creating','retryable','uncertain','accepted')), received INTEGER NOT NULL,
        receipt TEXT NOT NULL UNIQUE, accepted INTEGER, issue INTEGER, attempted INTEGER NOT NULL,
        CHECK(state!='accepted' OR (issue IS NOT NULL AND accepted IS NOT NULL)));
      CREATE TABLE IF NOT EXISTS rate_limit(peer TEXT NOT NULL,window INTEGER NOT NULL,count INTEGER NOT NULL,PRIMARY KEY(peer,window));`);
  }
  close(){this.db.close();}
  _transaction(fn){this.db.exec('BEGIN IMMEDIATE');try{const result=fn();this.db.exec('COMMIT');return result;}catch(e){this.db.exec('ROLLBACK');throw e;}}
  _receipt(row){return {receiptId:row.receipt,acceptedAtUtcMs:row.accepted};}
  _accepted(id,issue){
    this.db.prepare("UPDATE feedback SET state='accepted',issue=?,accepted=? WHERE id=? AND state!='accepted'").run(issue,this.now(),id);
    return this._receipt(this.db.prepare('SELECT * FROM feedback WHERE id=?').get(id));
  }
  async accept(input,peer='local') {
    const payload=validateFeedback(input),encoded=JSON.stringify(payload),hash=digest(encoded),id=payload.feedbackId;
    const row=this._transaction(()=>{
      const existing=this.db.prepare('SELECT * FROM feedback WHERE id=?').get(id);
      if(existing&&existing.hash!==hash)throw new FeedbackError(409,'IDEMPOTENCY_CONFLICT');
      if(existing&&existing.state==='accepted')return existing;
      const window=Math.floor(this.now()/3600000),key=createHmac('sha256',this.rateSalt).update(peer).digest('hex');
      this.db.prepare('DELETE FROM rate_limit WHERE window < ?').run(window-24);
      const count=this.db.prepare('SELECT count FROM rate_limit WHERE peer=? AND window=?').get(key,window)?.count??0;
      if(count>=10)throw new FeedbackError(429,'RATE_LIMITED');
      this.db.prepare('INSERT INTO rate_limit VALUES (?,?,1) ON CONFLICT(peer,window) DO UPDATE SET count=count+1').run(key,window);
      if(existing&&existing.state!=='retryable')return existing;
      if(existing){this.db.prepare("UPDATE feedback SET state='creating',attempted=? WHERE id=?").run(this.now(),id);}
      else this.db.prepare("INSERT INTO feedback(id,hash,payload,state,received,receipt,attempted) VALUES (?,?,?,'creating',?,?,?)").run(id,hash,encoded,this.now(),randomUUID(),this.now());
      return {...this.db.prepare('SELECT * FROM feedback WHERE id=?').get(id),claimed:true};
    });
    if(row.state==='accepted')return this._receipt(row);
    if(!row.claimed){
      // An interrupted request may have created an Issue. Never blindly POST a
      // second Issue, even after a process restart or on another server worker.
      let matches;try{matches=await this.github.find(marker(id,hash),row.attempted);}catch(_){throw new FeedbackError(503,'RECONCILIATION_REQUIRED');}
      if(matches.length===1)return this._accepted(id,matches[0]);
      throw new FeedbackError(503,'RECONCILIATION_REQUIRED');
    }
    let createAttempted=false;
    try {
      await this.github.ensurePrivate();
      createAttempted=true;
      const issue=await this.github.create({title:`[${payload.type}] PocketFlow ${payload.appVersion??'未附带版本'} ${id.slice(0,8)}`,body:issueBody(payload,hash,row.received),labels:[`type:${payload.type}`,'status:open',...(payload.appVersion?[`version:${payload.appVersion}`]:[])]});
      if(!Number.isSafeInteger(issue)||issue<1)throw new Error('Uncertain Issue result');
      return this._accepted(id,issue);
    } catch(error) {
      const definitelyNotCreated=!createAttempted||error.definitelyNotCreated;
      this.db.prepare('UPDATE feedback SET state=? WHERE id=? AND state!=?').run(definitelyNotCreated?'retryable':'uncertain',id,'accepted');
      throw new FeedbackError(503,definitelyNotCreated?'RETRY_LATER':'RECONCILIATION_REQUIRED');
    }
  }
  // Maintenance never deletes remote Issues implicitly. Retention needs the
  // documented operator process and a separate authorized maintenance action.
  retentionCandidates(days=90){return this.db.prepare('SELECT id,issue,received FROM feedback WHERE received < ?').all(this.now()-days*86400000);}
}

export class GithubAppIssues {
  constructor({owner,repo,appId,installationId,privateKeyPath,fetcher=fetch}){
    if(!/^[A-Za-z0-9_.-]+$/.test(owner)||!/^[A-Za-z0-9_.-]+$/.test(repo))throw new Error('Invalid feedback repository');
    this.owner=owner;this.repo=repo;this.appId=appId;this.installationId=installationId;this.privateKeyPath=privateKeyPath;this.fetcher=fetcher;this.token=null;this.expires=0;
  }
  async _request(path,{method='GET',body,app=false}={}){
    let credential;
    if(app){const issued=Math.floor(Date.now()/1000)-60;const head=Buffer.from(JSON.stringify({alg:'RS256',typ:'JWT'})).toString('base64url'),data=Buffer.from(JSON.stringify({iat:issued,exp:issued+540,iss:this.appId})).toString('base64url');const signing=createSign('RSA-SHA256');signing.update(`${head}.${data}`);credential=`${head}.${data}.${signing.sign(readFileSync(this.privateKeyPath)).toString('base64url')}`;}
    else{if(!this.token||this.expires<Date.now()+60000){const result=await this._request(`/app/installations/${this.installationId}/access_tokens`,{method:'POST',app:true,body:{repositories:[this.repo],permissions:{issues:'write',metadata:'read'}}});this.token=result.token;this.expires=Date.parse(result.expires_at);}credential=this.token;}
    const response=await this.fetcher(`https://api.github.com${path}`,{method,redirect:'error',signal:AbortSignal.timeout(15000),headers:{Authorization:`Bearer ${credential}`,Accept:'application/vnd.github+json','X-GitHub-Api-Version':'2022-11-28','User-Agent':'PocketFlow-Private-Feedback','Content-Type':'application/json'},...(body?{body:JSON.stringify(body)}:{})});
    if(!response.ok){const error=new Error('GitHub request unavailable');error.definitelyNotCreated=response.status>=400&&response.status<500;throw error;}
    return response.json();
  }
  async ensurePrivate(){const repo=await this._request(`/repos/${this.owner}/${this.repo}`);if(repo.private!==true||repo.full_name!==`${this.owner}/${this.repo}`){const error=new Error('Feedback repository must be private');error.definitelyNotCreated=true;throw error;}}
  async create(value){const result=await this._request(`/repos/${this.owner}/${this.repo}/issues`,{method:'POST',body:value});return result.number;}
  async find(needle,at){await this.ensurePrivate();const matches=[];for(let page=1;page<=10;page++){const issues=await this._request(`/repos/${this.owner}/${this.repo}/issues?state=all&per_page=100&page=${page}&since=${encodeURIComponent(new Date(at-60000).toISOString())}`);for(const issue of issues){if(!issue.pull_request&&typeof issue.body==='string'&&issue.body.includes(needle))matches.push(issue.number);}if(issues.length<100)break;}return matches;}
}

export function feedbackHttpHandler(service,{trustedTlsProxy=false}={}){
  return async(req,res)=>{
    const send=(status,value)=>{res.writeHead(status,{'Content-Type':'application/json; charset=utf-8','Cache-Control':'no-store','X-Content-Type-Options':'nosniff'});res.end(JSON.stringify(value));};
    if(req.method!=='POST'||req.url!=='/v1/feedback')return send(404,{error:'NOT_FOUND'});
    if(!req.socket.encrypted&&!(trustedTlsProxy&&req.headers['x-forwarded-proto']==='https'))return send(400,{error:'HTTPS_REQUIRED'});
    if(!/^application\/json(?:;|$)/i.test(req.headers['content-type']??''))return send(415,{error:'JSON_REQUIRED'});
    try{const chunks=[];let length=0;for await(const chunk of req){length+=chunk.length;if(length>32768)throw new FeedbackError(413,'BODY_TOO_LARGE');chunks.push(chunk);}let payload;try{payload=JSON.parse(Buffer.concat(chunks).toString('utf8'));}catch(_){throw new FeedbackError(400,'INVALID_JSON');}
      // The explicitly trusted local proxy must overwrite X-Real-IP.
      const forwarded=req.headers['x-real-ip'];
      const peer=trustedTlsProxy&&typeof forwarded==='string'&&isIP(forwarded)?forwarded:req.socket.remoteAddress??'unknown';
      const receipt=await service.accept(payload,peer);send(200,receipt);
    }catch(error){send(error instanceof FeedbackError?error.status:503,{error:error instanceof FeedbackError?error.code:'RETRY_LATER'});}
  };
}
if(process.argv[1]&&import.meta.url===pathToFileURL(process.argv[1]).href){
  for(const name of ['PF_FEEDBACK_DB','PF_RATE_SALT','PF_GITHUB_OWNER','PF_GITHUB_REPO','PF_GITHUB_APP_ID','PF_GITHUB_INSTALLATION_ID','PF_GITHUB_PRIVATE_KEY_PATH'])if(!process.env[name])throw new Error(`Missing ${name}`);
  const github=new GithubAppIssues({owner:process.env.PF_GITHUB_OWNER,repo:process.env.PF_GITHUB_REPO,appId:process.env.PF_GITHUB_APP_ID,installationId:process.env.PF_GITHUB_INSTALLATION_ID,privateKeyPath:process.env.PF_GITHUB_PRIVATE_KEY_PATH});
  const service=new FeedbackService({databasePath:process.env.PF_FEEDBACK_DB,github,rateSalt:process.env.PF_RATE_SALT});
  const server=createServer(feedbackHttpHandler(service,{trustedTlsProxy:process.env.PF_TRUSTED_TLS_PROXY==='1'}));server.requestTimeout=30000;server.headersTimeout=10000;server.listen(Number(process.env.PORT??8080),'127.0.0.1');
  // Only lifecycle metadata is logged. Never log bodies, contacts or credentials.
  server.on('error',()=>{process.stderr.write('Feedback service unavailable\n');process.exitCode=1;});
}
