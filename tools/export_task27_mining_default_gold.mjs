import fs from 'node:fs';
import assert from 'node:assert/strict';
import crypto from 'node:crypto';
import {createFrozenSourceRuntime} from './frozen_source_runtime.mjs';
const runtime=createFrozenSourceRuntime();
try {
  const engine=await runtime.load('engine'),content=await runtime.load('content');
  const base=engine.createInitialState(240721,false);
  const resources=[...new Set(base.entities.filter(entity=>entity.kind==='vein').map(entity=>entity.resourceId))].sort();
  assert.equal(resources.length,16);
  const counts=[1,2,3],levels=[0,1,9,10],modes=['finite','infinite'],seconds=[0.25,1,3],stages=['powered','unpowered','full-output','last-tenth','depleted'];
  const cases=[];
  for(const item of resources)for(const count of counts)for(const level of levels)for(const mode of modes){
    let state=engine.createInitialState(240721,false);
    const vein=state.entities.find(entity=>entity.kind==='vein'&&entity.resourceId===item),extractor=content.getExtractorBuildingId(item);
    state.activePlanetId=vein.planetId;state.exploration.colonizedPlanetIds=[...new Set([...state.exploration.colonizedPlanetIds,vein.planetId])];
    state.research.completedTechIds=Object.keys(content.TECHNOLOGIES);
    state.endgame.infiniteResearch.vein_utilization={level,progress:'0'};
    state.settings.resourceMode=mode;
    state.construction[extractor]=count;
    state=engine.installMiner(state,vein.id,count);
    assert.equal(state.entities.find(entity=>entity.id===vein.id).minerCount,count);assert.equal(state.construction[extractor],0);
    state.construction.solar_panel=100;
    const unpowered=structuredClone(state);
    state=engine.placeBuilding(state,'solar_panel',{x:1000,y:1000},100);
    assert.equal(state.construction.solar_panel,0);
    assert.equal(state.entities.find(entity=>entity.buildingId==='solar_panel').machineCount,100);
    for(const stage of stages)for(const duration of seconds){
      const scenario=structuredClone(stage==='unpowered'?unpowered:state);
      const subject=scenario.entities.find(entity=>entity.id===vein.id);
      subject.resourceRemaining=stage==='depleted'?0:stage==='last-tenth'?1:100;
      subject.resourceCapacity=100;subject.resourceDepletionRemainder=stage==='last-tenth'?9:0;
      if(stage==='full-output')subject.outputs[item]=engine.getEntityOutputCapacity(scenario,subject);
      const input={item,planet:vein.planetId,entity:vein.id,extractor,count,level,mode,stage,seconds:duration,remaining:subject.resourceRemaining,capacity:subject.resourceCapacity,remainder:subject.resourceDepletionRemainder,output:subject.outputs[item]??0,progress:subject.progress??0};
      const before=JSON.stringify(scenario),after=engine.advanceSimulation(scenario,duration),result=after.entities.find(entity=>entity.id===vein.id);
      assert.equal(JSON.stringify(scenario),before,'Source advance preserves input');
      if(stage!=='unpowered')assert.equal(result.powerFactor,1,'Actual paid solar power supplies the actual extractor');
      cases.push({id:[item,'c'+count,'l'+level,mode,stage,duration].join('-'),input,expected:{output:result.outputs[item]??0,progress:result.progress??0,remaining:result.resourceRemaining,remainder:result.resourceDepletionRemainder,power_factor:result.powerFactor,utilization:result.utilization,production_rate:result.productionRate,total_produced:after.totalProduced[item]??0,reserve:engine.getResourceReserveSnapshot(after,result)}});
    }
  }
  const output={source_commit:runtime.commit,source_files:runtime.files,source_environment:{DEV:false,PROD:true,MODE:'production'},scope:'Actual frozen installMiner count1/2/3 consuming funded kits,100 paid solar panels or actual disconnected extractor,and full advanceSimulation for16 actual initial resource sites; controlled finite/infinite reserve profiles, completed source technology,levels0/1/9/10,5power/output/depletion stages,3horizons. Source input immutable. Not earned research/construction,native grouping,manual UI or save acceptance.',resources,counts,levels,modes,seconds,stages,cases};
  const bytes=JSON.stringify(output,null,2)+'\n';
  const outputPath=process.argv[2]??new URL('../tests/fixtures/parity/behavior/task27-mining-default.json',import.meta.url);
  fs.writeFileSync(outputPath,bytes);
  console.log('RESOURCE THROUGHPUT SOURCE GOLD:'+cases.length+'actual advances/'+Object.keys(runtime.files).length+'modules/SHA256:'+crypto.createHash('sha256').update(bytes).digest('hex'));
}finally{runtime.close();}
