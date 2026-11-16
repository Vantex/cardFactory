import fs from 'node:fs';
import assert from 'node:assert/strict';
import crypto from 'node:crypto';
import {createFrozenSourceRuntime,writeFrozenFixture} from './frozen_source_runtime.mjs';
const runtime=createFrozenSourceRuntime();
try {
  const engine=await runtime.load('engine'),content=await runtime.load('content');
  const base=engine.createInitialState(240721,false),resources=[...new Set(base.entities.filter(entity=>entity.kind==='vein').map(entity=>entity.resourceId))].sort();assert.equal(resources.length,16);
  const cases=[];
  for(const item of resources){
    const state=engine.createInitialState(240721,false),source=state.entities.find(entity=>entity.kind==='vein'&&entity.resourceId===item),extractor=content.getExtractorBuildingId(item);
    state.activePlanetId=source.planetId;state.construction[extractor]=1;
    const before=JSON.stringify(state),result=engine.installMiner(state,source.id,1),installed=result.entities.find(entity=>entity.id===source.id);
    assert.equal(JSON.stringify(state),before);assert.notEqual(result,state);assert.equal(installed.minerCount,1);assert.equal(result.construction[extractor],0);
    cases.push({id:'actual-funded-install-'+item,input:{item,planet:source.planetId,entity:source.id,extractor,funded_kits:1,count:1},expected:{resource:installed.resourceId,miner_count:installed.minerCount,extractor:installed.extractorBuildingId,remaining_kits:result.construction[extractor]}});
  }
  const output={source_commit:runtime.commit,source_files:runtime.files,source_environment:{DEV:false,PROD:true,MODE:'production'},scope:'Actual frozen installMiner16 real initial-state resource veins; controlled one funded extractor kit per case consumed by real public command; source input immutability verified. Does not prove earned construction, mining throughput or native card placement geometry.',cases};
  const bytes=JSON.stringify(output,null,2)+'\n';writeFrozenFixture(runtime,'task27-resource-placement.json',output);
  console.log(`RESOURCE INSTALL SOURCE GOLD:${cases.length}actual paid cases/${Object.keys(runtime.files).length}modules/SHA256:${crypto.createHash('sha256').update(bytes).digest('hex')}`);
}finally{runtime.close();}
