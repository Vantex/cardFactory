import fs from 'node:fs';
import crypto from 'node:crypto';
import assert from 'node:assert/strict';
import {createFrozenSourceRuntime} from './frozen_source_runtime.mjs';
const runtime=createFrozenSourceRuntime();
try{
 const engine=await runtime.load('engine'),content=await runtime.load('content');
 const resources=[...new Set(engine.createInitialState(240721,false).entities.filter(entity=>entity.kind==='vein').map(entity=>entity.resourceId))].sort();
 assert.equal(resources.length,16);
 const cases=[];
 const exercise=(item,count,current,mode,level)=>{
  let state=engine.createInitialState(240721,false),vein=state.entities.find(entity=>entity.kind==='vein'&&entity.resourceId===item);
  assert.ok(vein);const id=vein.id,extractor=content.getExtractorBuildingId(item);
  state.activePlanetId=vein.planetId;state.exploration.colonizedPlanetIds=[...new Set([...state.exploration.colonizedPlanetIds,vein.planetId])];
  state.research.completedTechIds=Object.keys(content.TECHNOLOGIES);state.settings.resourceMode=mode;
  state.endgame.infiniteResearch.vein_utilization={level,progress:'0'};
  if(count){state.construction[extractor]=count;state=engine.installMiner(state,id,count);assert.equal(state.construction[extractor],0);assert.equal(state.entities.find(entity=>entity.id===id).minerCount,count);}
  state.construction.solar_panel=100;state=engine.placeBuilding(state,'solar_panel',{x:1000,y:1000},100);assert.equal(state.construction.solar_panel,0);
  vein=state.entities.find(entity=>entity.id===id);vein.resourceCapacity=1000;vein.resourceRemaining=1000;vein.resourceDepletionRemainder=0;vein.outputs[item]=current;
  const snapshot=()=>{
   const subject=state.entities.find(entity=>entity.id===id);
   return structuredClone({entity:id,planet:subject.planetId,item,outputs:subject.outputs,miner_count:subject.minerCount,remaining:subject.resourceRemaining,remainder:subject.resourceDepletionRemainder??0,progress:subject.progress,power_factor:subject.powerFactor??null,total_produced:state.totalProduced,manual_mined:state.manualMined,tray:state.tray,planet_trays:state.planetTrays,cargo:state.cargo,reserve:engine.getResourceReserveSnapshot(state,subject)});
  };
  const initial=snapshot(),stages=[];
  const command=(label,operation)=>{const input=state,before=JSON.stringify(input);state=operation(input);assert.equal(JSON.stringify(input),before,'Actual ownership command preserves complete source input: '+label);stages.push({label,returned_original:state===input,expected:snapshot()});};
  const advance=input=>{const session=engine.createSimulationAdvanceSession(input,2);session.stepSize=1/60;assert.equal(engine.advanceSimulationSession(session,60),60);return session.state;};
  command('manual-one',input=>engine.manualMine(input,id,1));
  command('automatic-60ticks',advance);
  command('output-to-tray',input=>engine.moveEntityOutputToTray(input,id,item));
  command('manual-64',input=>engine.manualMine(input,id,64));
  command('automatic-after-collection-60ticks',advance);
  cases.push({id:[item,count,current,mode,level].join('-'),input:{item,planet:vein.planetId,source_entity:id,extractor,count,current,mode,level,capacity:1000,remaining:1000,remainder:0,step_seconds:1/60,automatic_ticks_per_stage:60},initial,stages});
 };
 for(const item of resources)for(const current of [0,179])for(const mode of ['finite','infinite'])for(const level of [0,1])exercise(item,1,current,mode,level);
 for(const count of [0,3])for(const current of [0,179,180])for(const mode of ['finite','infinite'])for(const level of [0,1,9,10])exercise('iron_ore',count,current,mode,level);
 assert.equal(cases.length,176);assert.equal(new Set(cases.map(row=>row.id)).size,cases.length);
 assert.ok(cases.every(row=>row.stages.length===5));
 const result={source_commit:runtime.commit,source_files:runtime.files,source_environment:{DEV:false,PROD:true,MODE:'production'},cases,scope:'Read-only research:176 actual source ownership flows/880 recorded stages. Each performs manual1, actual60tick public simulation, public moveEntityOutputToTray,manual64,actual60tick simulation;352 real fixed60tick sessions.16resources count1 and iron count0/3/cache boundaries,finite/infinite/research0/1/9/10. Source input immutable at every stage;full output owner/all tray views/cargo/cumulative facts and reserve/carry recorded. Source kit/solar payments actually consumed, funding/technology/colonization/reserve/cache controlled. No native implementation/grouping/key/save/UI/earnedgrowth/release acceptance.'};
 const bytes=JSON.stringify(result,null,2)+'\n';fs.writeFileSync(process.argv[2]??new URL('../tests/fixtures/parity/behavior/task27-resource-ownership.json',import.meta.url),bytes);
 console.log('MANUAL OWNERSHIP SOURCE RESEARCH:176flows/880stages/352actual60tick sessions/'+Object.keys(runtime.files).length+'modules/SHA256:'+crypto.createHash('sha256').update(bytes).digest('hex'));
}finally{runtime.close();}
