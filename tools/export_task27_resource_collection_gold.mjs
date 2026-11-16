import fs from 'node:fs';
import crypto from 'node:crypto';
import assert from 'node:assert/strict';
import {createFrozenSourceRuntime} from './frozen_source_runtime.mjs';
const runtime=createFrozenSourceRuntime();
try {
 const engine=await runtime.load('engine'),content=await runtime.load('content');
 const resources=[...new Set(engine.createInitialState(240721,false).entities.filter(e=>e.kind==='vein').map(e=>e.resourceId))].sort();
 const cases=[];
 for(const item of resources)for(const count of [0,1,3])for(const current of [0,1,179,540])for(const free of [0,1,7,1000])for(const remote of [false,true]){
  let state=engine.createInitialState(240721,false),vein=state.entities.find(e=>e.kind==='vein'&&e.resourceId===item);
  const id=vein.id,planet=vein.planetId;
  state.exploration.colonizedPlanetIds=[...new Set([...state.exploration.colonizedPlanetIds,planet,'ashen'])];
  state.research.completedTechIds=Object.keys(content.TECHNOLOGIES);
  const extractor=content.getExtractorBuildingId(item);
  if(count){state.activePlanetId=planet;state.construction[extractor]=count;state=engine.installMiner(state,id,count);assert.equal(state.construction[extractor],0);}
  state.activePlanetId=remote?(planet==='home'?'ashen':'home'):planet;
  state.tray={...state.planetTrays[state.activePlanetId],[item]:1000-free};
  state.planetTrayItemLimits={[state.activePlanetId]:1000};
  state.entities.find(e=>e.id===id).outputs[item]=current;
  const snapshot=s=>{const entity=s.entities.find(e=>e.id===id);return structuredClone({outputs:entity.outputs,tray:s.tray,planet_trays:s.planetTrays,cargo:s.cargo,remaining:entity.resourceRemaining,remainder:entity.resourceDepletionRemainder??0,manual_mined:s.manualMined,total_produced:s.totalProduced});};
  const initial=snapshot(state),bytes=JSON.stringify(state),next=engine.moveEntityOutputToTray(state,id,item);
  assert.equal(JSON.stringify(state),bytes,'Collection must preserve source input');
  const expected=snapshot(next);
  const moved=(expected.tray[item]??0)-(initial.tray[item]??0);
  assert.equal(moved,Math.min(current,free));
  assert.equal(expected.outputs[item],current-moved);
  cases.push({id:[item,count,current,free,remote?'remote':'local'].join('-'),input:{item,planet,active_planet:state.activePlanetId,extractor,count,current,free,tray_limit:1000,remote},initial,returned_original:next===state,expected});
 }
 assert.equal(cases.length,1536);assert.equal(new Set(cases.map(r=>r.id)).size,cases.length);
 const result={source_commit:runtime.commit,source_files:runtime.files,cases,scope:'1536 actual public moveEntityOutputToTray calls, including zero/full/partial tray, count0/1/3, output0/1/179/540 and local/remote active tray. Input immutable; raw aliases recorded, active canonical tray is expected.tray. Controlled existing stock and installation funding; no native/key/UI/cargo-pick acceptance.'};
 const bytes=JSON.stringify(result,null,2)+'\n';
 fs.writeFileSync(process.argv[2]??new URL('../tests/fixtures/parity/behavior/task27-resource-collection.json',import.meta.url),bytes);
 console.log('MANUAL COLLECTION SOURCE:1536 actual calls;SHA256:'+crypto.createHash('sha256').update(bytes).digest('hex'));
}finally{runtime.close();}
