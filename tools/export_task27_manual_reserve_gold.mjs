import fs from 'node:fs';
import assert from 'node:assert/strict';
import crypto from 'node:crypto';
import {createFrozenSourceRuntime} from './frozen_source_runtime.mjs';
const runtime=createFrozenSourceRuntime();
try{
 const engine=await runtime.load('engine'),content=await runtime.load('content');
 const base=engine.createInitialState(240721,false);
 const resources=[...new Set(base.entities.filter(e=>e.kind==='vein'&&content.ITEMS[e.resourceId].kind==='solid').map(e=>e.resourceId))].sort();
 assert.equal(resources.length,13);
 const cases=[];
 for(const item of resources)for(const level of [0,1,9,10])for(const mode of ['finite','infinite'])for(const profile of ['partial','depleted','last-tenth']){
  const state=engine.createInitialState(240721,false),vein=state.entities.find(e=>e.kind==='vein'&&e.resourceId===item);
  state.activePlanetId=vein.planetId;state.settings.resourceMode=mode;
  state.endgame.infiniteResearch.vein_utilization={level,progress:'0'};
  vein.resourceRemaining=profile==='depleted'?0:profile==='last-tenth'?1:100;
  vein.resourceDepletionRemainder=profile==='last-tenth'?9:0;
  const before=JSON.stringify(state),next=engine.manualMine(state,vein.id,1),result=next.entities.find(e=>e.id===vein.id);
  assert.equal(JSON.stringify(state),before);
  cases.push({id:[item,level,mode,profile].join('-'),input:{item,planet:vein.planetId,level,mode,remaining:vein.resourceRemaining,remainder:vein.resourceDepletionRemainder},expected:{produced:result.outputs[item]??0,remaining:result.resourceRemaining,remainder:result.resourceDepletionRemainder,total_produced:next.totalProduced[item]??0,manual_mined:next.manualMined}});
 }
 const bytes=JSON.stringify({source_commit:runtime.commit,source_files:runtime.files,resources,cases,scope:'312 actual frozen public manualMine amount-one calls/13solid resources/levels0,1,9,10/two modes/three controlled reserve profiles. Source deposits into vein.outputs;native existing manual action deposits into tray. Compare produced quantity,resource reserve/debt and produced/manual facts only;not full manualMine endpoint,output-capacity/target ownership/UI parity or earned growth.'},null,2)+'\n';
 fs.writeFileSync(process.argv[2],bytes);
 console.log('MANUAL RESERVE SOURCE:312actualcalls/'+Object.keys(runtime.files).length+'modules/SHA256:'+crypto.createHash('sha256').update(bytes).digest('hex'));
}finally{runtime.close();}
