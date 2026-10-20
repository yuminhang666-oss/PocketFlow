// Read-only verification of an explicitly SYNTHETIC Android fixture.
import {DatabaseSync} from 'node:sqlite';
import {readFileSync} from 'node:fs';
import {createHash} from 'node:crypto';
import assert from 'node:assert/strict';
const [beforePath,afterPath,beforeInstall,afterInstall]=process.argv.slice(2);
if(!beforePath||!afterPath||!beforeInstall||!afterInstall)throw new Error('Expected two synthetic DBs and two installation metadata files');
const before=new DatabaseSync(beforePath,{readOnly:true}),after=new DatabaseSync(afterPath,{readOnly:true});
try{
  const rows=(db,table,order)=>db.prepare(`SELECT * FROM ${table} ORDER BY ${order}`).all();
  const preserved={};
  for(const [table,order] of [['ledger_entries','id'],['monthly_budgets','month'],['personal_state','key'],['recovery_snapshots','id']]){
    const a=rows(before,table,order),b=rows(after,table,order);
    assert.deepEqual(b,a,`${table} changed during upgrade`);
    preserved[table]={count:a.length,sha256:createHash('sha256').update(JSON.stringify(a)).digest('hex')};
  }
  const oldCategories=rows(before,'categories','id'),newCategories=rows(after,'categories','id'),byId=new Map(newCategories.map(c=>[c.id,c]));
  const changes=[];
  for(const c of oldCategories){
    const updated=byId.get(c.id);assert.ok(updated,`Historical category ${c.id} removed`);
    assert.equal(updated.parent_id,c.parent_id);assert.equal(updated.category_kind,c.category_kind);
    if(JSON.stringify(c)!==JSON.stringify(updated))changes.push({before:c,after:updated});
  }
  assert.equal(before.prepare('PRAGMA user_version').get().user_version,3);
  assert.equal(after.prepare('PRAGMA user_version').get().user_version,4);
  assert.deepEqual(after.prepare('PRAGMA foreign_key_check').all(),[]);
  assert.equal(after.prepare('PRAGMA integrity_check').get().integrity_check,'ok');
  const firstTime=path=>readFileSync(path,'utf8').split(/\r?\n/).find(s=>s.includes('firstInstallTime='))?.trim();
  assert.ok(firstTime(beforeInstall));assert.equal(firstTime(afterInstall),firstTime(beforeInstall));
  console.log(JSON.stringify({fixture:'SYNTHETIC 0.2.1 documented Android fixture; no real ledger',schemaBefore:3,schemaAfter:4,firstInstallTime:firstTime(beforeInstall),preserved,categoriesBefore:oldCategories.length,categoriesAfter:newCategories.length,allOldIdsRetained:true,categoryMetadataChanges:changes,foreignKeyCheck:[],integrity:'ok'},null,2));
}finally{before.close();after.close();}
