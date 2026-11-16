import fs from 'node:fs';
import crypto from 'node:crypto';
import assert from 'node:assert/strict';
import {createFrozenSourceRuntime} from './frozen_source_runtime.mjs';
const runtime=createFrozenSourceRuntime();
try{
 const engine=await runtime.load('engine');
 const base=engine.createInitialState(240721,false),resources=[...new Set(base.entities.filter(e=>e.kind==='vein').map(e=>e.resourceId))].sort(),cases=[];
 const exercise=(id,item,count,current,amount,mode,level)=>{
  const state=engine.createInitialState(240721,false),vein=state.entities.find(e=>e.kind==='vein'&&e.resourceId===item);assert.ok(vein);
  state.activePlanetId=vein.planetId;state.settings.resourceMode=mode;state.endgame.infiniteResearch.vein_utilization={level,progress:'0'};
  vein.minerCount=count;vein.outputs[item]=current;vein.resourceRemaining=1000;vein.resourceDepletionRemainder=0;
  const before=JSON.stringify(state),next=engine.manualMine(state,vein.id,amount),result=next.entities.find(e=>e.id===vein.id);
  assert.equal(JSON.stringify(state),before,'Public manualMine preserves the complete source input');
  cases.push({id,input:{item,planet:vein.planetId,source_entity:vein.id,count,current,amount,mode,level,remaining:1000,remainder:0,tray:state.tray,planet_trays:state.planetTrays},expected:{outputs:result.outputs,tray:next.tray,planet_trays:next.planetTrays,remaining:result.resourceRemaining,remainder:result.resourceDepletionRemainder??0,total_produced:next.totalProduced[item]??0,manual_mined:next.manualMined,returned_original:next===state}});
 };
 for(const item of resources)exercise('default-'+item,item,0,0,1,'finite',0);
 for(const count of [0,3])for(const current of [0,179,180])for(const amount of [0,0.5,1,64])for(const mode of ['finite','infinite'])for(const level of [0,1,9,10])exercise(['iron',count,current,amount,mode,level].join('-'),'iron_ore',count,current,amount,mode,level);
 assert.equal(cases.length,208);assert.equal(new Set(cases.map(row=>row.id)).size,cases.length);
 const value={source_commit:runtime.commit,source_files:runtime.files,cases,scope:'Read-only research:208actual frozen public manualMine calls;16resources and192iron output-cache/amount/mode/research controlled cases. Actual complete input read-only;output destination,all tray views,reserve/carry andfacts recorded. minerCount andtechnology/cache/prerequisites are controlled,not paid installation/earnedgrowth. Not native/manualMine key/save/UI/auto-mining integration acceptance.'};
 const bytes=JSON.stringify(value,null,2)+'\n';fs.writeFileSync(process.argv[2]??new URL('../tests/fixtures/parity/behavior/task27-resource-manual.json',import.meta.url),bytes);
 console.log('MANUAL OUTPUT SOURCE RESEARCH:208actualcalls/'+Object.keys(runtime.files).length+'modules/SHA256:'+crypto.createHash('sha256').update(bytes).digest('hex'));
}finally{runtime.close();}
