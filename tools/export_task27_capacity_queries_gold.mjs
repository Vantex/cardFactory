import assert from 'node:assert/strict';
import {createFrozenSourceRuntime,writeFrozenFixture} from './frozen_source_runtime.mjs';

const runtime=createFrozenSourceRuntime();
try {
  const engine=await runtime.load('engine'),content=await runtime.load('content'),galaxy=await runtime.load('galaxy');
  const functions=['getEntityBufferLimit','getEntityInputCapacity','getEntityOutputCapacity'];
  const counts=[1,2,3,0,-1,1.9,100000000,1000000000];
  const limits=[['default',1000000,1000000],['minimum',1000,1000],['maximum',100000000,100000000],['split-production',1000,100000000],['split-logistics',100000000,1000],['below',-1,999.9],['fractional',1234.9,2345.9],['above',1e12,1e12],['null',null,null],['boolean',false,true],['string','1000','2000']];
  const baseline=engine.createInitialState(240721,false);
  const resources=[...new Set(content.PLANET_LIST.flatMap(row=>galaxy.getPlanetIndustrialProfile(baseline,row.id).resourceIds))].sort();
  const buildings=Object.keys(content.BUILDINGS).sort();
  const cases=[];
  const add=(id,input,entity)=>{
    const state=engine.createInitialState(240721,false);
    state.settings.productionBufferLimit=input.production;state.settings.logisticsBufferLimit=input.logistics;
    const before=JSON.stringify({state,entity});
    const expected=Object.fromEntries(functions.map(name=>[name,engine[name](state,entity)]));
    assert.equal(JSON.stringify({state,entity}),before,'Actual queries preserve raw source state/entity');
    cases.push({id,input,expected});
  };
  for(const building of buildings)for(const [profile,production,logistics] of limits)for(const [index,count] of counts.entries()){
    const kind=content.BUILDINGS[building].kind;
    add(`building-${building}-${profile}-c${index}`,{entity_kind:'building',building,kind,count,profile,production,logistics},{id:'probe',kind,buildingId:building,machineCount:count});
  }
  for(const resource of resources)for(const [profile,production,logistics] of limits)for(const [index,count] of counts.entries()){
    const extractor=content.getExtractorBuildingId(resource);
    assert.ok(content.BUILDINGS[extractor],'Actual frozen default extractor exists');
    add(`vein-${resource}-${profile}-c${index}`,{entity_kind:'vein',resource,extractor,count,profile,production,logistics},{id:'site',kind:'vein',resourceId:resource,minerCount:count});
  }
  writeFrozenFixture(runtime,'task27-capacity-queries.json',{
    scope:'Only three entity buffer/capacity queries: all39 frozen buildings, all16 seed240721 resource IDs from22 actual planet profiles, eight raw numeric counts and11 raw settings profiles. Synthetic query states may contain inputs rejected by saved-state validation. No paid construction, production throughput or earned growth claim.',
    functions,buildings,resources,counts,limits,cases,
  });
  console.log(`TASK27 CAPACITY GOLD: ${buildings.length} buildings / ${resources.length} resources / ${cases.length} states / ${cases.length*3} actual source queries / ${Object.keys(runtime.files).length} loaded modules`);
} finally {runtime.close();}
