import fs from 'node:fs';
import crypto from 'node:crypto';
import assert from 'node:assert/strict';
import {createFrozenSourceRuntime} from './frozen_source_runtime.mjs';
const runtime=createFrozenSourceRuntime();
const capacityInput=process.argv[3]?JSON.parse(fs.readFileSync(process.argv[3])):null;
if(capacityInput)assert.equal(capacityInput.seed,240721);
try{
 const engine=await runtime.load('engine'),content=await runtime.load('content');
 const base=engine.createInitialState(240721,false);
 const resources=[...new Set(base.entities.filter(e=>e.kind==='vein').map(e=>e.resourceId))].sort();
 assert.equal(resources.length,16);
 const cases=[];
 for(const item of resources)for(const profile of ['partial','depleted','last-tenth']){
  let state=engine.createInitialState(240721,false);
  const vein=state.entities.find(e=>e.kind==='vein'&&e.resourceId===item),extractor=content.getExtractorBuildingId(item);
  state.activePlanetId=vein.planetId;
  state.exploration.colonizedPlanetIds=[...new Set([...state.exploration.colonizedPlanetIds,vein.planetId])];
  state.research.completedTechIds=Object.keys(content.TECHNOLOGIES);
  state.endgame.infiniteResearch.vein_utilization={level:1,progress:'0'};
  state.settings.resourceMode='finite';
  state.construction[extractor]=1;state=engine.installMiner(state,vein.id,1);
  assert.equal(state.construction[extractor],0);
  state.construction.solar_panel=100;state=engine.placeBuilding(state,'solar_panel',{x:1000,y:1000},100);
  assert.equal(state.construction.solar_panel,0);
  const subject=state.entities.find(e=>e.id===vein.id),intrinsicInfinite=engine.getResourceReserveSnapshot(state,subject).infinite;
  const originalSourceCapacity=subject.resourceCapacity??0;
  if(capacityInput){
   const controlled=capacityInput.capacities[item];
   assert.equal(controlled.planet,vein.planetId);assert.equal(controlled.source_entity,vein.id);
   assert.equal(controlled.source_capacity,originalSourceCapacity);
   assert.ok(Number.isInteger(controlled.native_capacity)&&controlled.native_capacity>=0);
   subject.resourceCapacity=controlled.native_capacity;
  }
  if(!intrinsicInfinite){subject.resourceRemaining=profile==='depleted'?0:profile==='last-tenth'?1:100;subject.resourceDepletionRemainder=profile==='last-tenth'?9:0;}
  const input={item,planet:vein.planetId,entity:vein.id,extractor,level:1,profile,intrinsic_infinite:intrinsicInfinite,remaining:subject.resourceRemaining??0,capacity:subject.resourceCapacity??0,remainder:subject.resourceDepletionRemainder??0,original_source_capacity:originalSourceCapacity};
  const stages=[];
  for(const [mode,ticks] of [['finite',15],['infinite',profile==='partial'?15:60],['finite',profile==='partial'?30:60]]){
   const original=JSON.stringify(state);
   const scenario={...state,settings:{...state.settings,resourceMode:mode}};
   assert.equal(JSON.stringify(state),original,'Controlled mode change preserves previous source state');
   const before=JSON.stringify(scenario),session=engine.createSimulationAdvanceSession(scenario,ticks/60+1);
   session.stepSize=1/60;
   assert.equal(engine.advanceSimulationSession(session,ticks),ticks);
   assert.equal(JSON.stringify(scenario),before,'Public source simulation preserves input');
   state=session.state;
   const result=state.entities.find(e=>e.id===vein.id);
   assert.equal(result.powerFactor,1);
   const readBefore=JSON.stringify(state),reserve=engine.getResourceReserveSnapshot(state,result);
   assert.deepEqual(engine.getResourceReserveSnapshot(state,result),reserve);
   assert.equal(JSON.stringify(state),readBefore,'Source reserve query preserves actual simulated state');
   const ratioBytes=Buffer.alloc(8);ratioBytes.writeDoubleLE(reserve.remainingRatio);
   stages.push({mode,ticks,reserve_ratio_le_hex:ratioBytes.toString('hex'),expected:{output:result.outputs[item]??0,progress:result.progress??0,remaining:result.resourceRemaining??0,remainder:result.resourceDepletionRemainder??0,power_factor:result.powerFactor,utilization:result.utilization,production_rate:result.productionRate,total_produced:state.totalProduced[item]??0,reserve}});
  }
  cases.push({id:item+'-'+profile,input,stages});
 }
 const result={source_commit:runtime.commit,source_files:runtime.files,source_environment:{DEV:false,PROD:true,MODE:'production'},resources,cases,capacity_input_sha256:capacityInput?crypto.createHash('sha256').update(fs.readFileSync(process.argv[3])).digest('hex'):null,scope:'48 controlled finite/infinite/finite sequences on16 actual resource sites,actual paid count-one installMiner/100solar and144 public complete-tick simulation sessions+readonly reserve queries. Mode is controlled immutable settings input matching the inspected App updateSettings body;this does not execute the React confirmation callback. Completed technology/funded kits/level1 are controlled,not earned growth or save acceptance.'+(capacityInput?' Resource capacity is a controlled input captured from existing valid native sites;original source capacity retained per row. Expected results are computed only by frozen source. Existing initial capacity random-key mismatch remains uncorrected,not covered by this mode comparison.':' Actual original source capacities retained.')};
 const bytes=JSON.stringify(result,null,2)+'\n';
 fs.writeFileSync(process.argv[2]??new URL('mode-flow-source.json',import.meta.url),bytes);
 console.log('RESOURCE MODE FLOW SOURCE:'+cases.length+'sequences/'+cases.reduce((n,c)=>n+c.stages.length,0)+'actualsessions/'+Object.keys(runtime.files).length+'modules/SHA256:'+crypto.createHash('sha256').update(bytes).digest('hex'));
}finally{runtime.close();}
