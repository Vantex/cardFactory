import assert from 'node:assert/strict';
import {createFrozenSourceRuntime,writeFrozenFixture} from './frozen_source_runtime.mjs';

const runtime=createFrozenSourceRuntime();
try {
  const engine=await runtime.load('engine');
  const content=await runtime.load('content');
  const effects=['research_speed_1','research_speed_2','research_speed_3','mining_speed_1','mining_speed_2','mining_speed_3','logistics_engine_1','logistics_engine_2','ray_transmission_1','ray_transmission_2','dyson_absorption_1','solar_sail_life_1','solar_sail_life_2'];
  const infinite=['matrix_compression','vein_utilization','galactic_logistics','stellar_harnessing'];
    const functions=['getSolarSailLifetimeSeconds'];
  const stages=[{id:'none',completed:[],levels:{}},{id:'all_finite',completed:Object.keys(content.TECHNOLOGIES),levels:{}}];
  for(const id of effects)stages.push({id:'finite-'+id,completed:[id],levels:{}});
  stages.push({id:'noncontiguous_finite',completed:['research_speed_1','research_speed_3','mining_speed_1','mining_speed_3','ray_transmission_2','logistics_engine_2'],levels:{}});
  for(const id of infinite)for(const level of [1,2,9,10,11,99,999,1000])stages.push({id:`infinite-${id}-${level}`,completed:[],levels:{[id]:level}});
  for(const [index,levels] of [{matrix_compression:1,vein_utilization:9,galactic_logistics:11,stellar_harnessing:99},{matrix_compression:999,vein_utilization:10,galactic_logistics:2,stellar_harnessing:1000},{matrix_compression:1000,vein_utilization:1000,galactic_logistics:1000,stellar_harnessing:1000}].entries())stages.push({id:'combined-'+index,completed:Object.keys(content.TECHNOLOGIES),levels});
  const cases=[];
  for(const difficulty of ['relaxed','standard','hard'])for(const stage of stages){
    const state=engine.createInitialState(240721,false);
    state.settings.difficulty=difficulty;
    state.research.completedTechIds=[...stage.completed];
    for(const id of infinite)state.endgame.infiniteResearch[id]={level:stage.levels[id]??0,progress:'0'};
    const before=JSON.stringify(state);
    const expected=Object.fromEntries(functions.map(name=>[name,engine[name](state)]));
    assert.equal(JSON.stringify(state),before,'Actual source queries must preserve raw input: '+stage.id);
    cases.push({id:difficulty+'-'+stage.id,input:{difficulty,completed:stage.completed,levels:Object.fromEntries(infinite.map(id=>[id,stage.levels[id]??0]))},expected});
  }
  writeFrozenFixture(runtime,'task27-sail-lifetime.json',{
    scope:'Only getSolarSailLifetimeSeconds: three difficulties, finite solar lifetime technologies alone and together, unrelated finite and independent infinite controls. Actual frozen source return values and immutable input. Controlled query scope; no earned growth, decay or saving claim.',
    functions,finite:effects,infinite,cases,
  });
  console.log(`TASK27 SAIL LIFETIME GOLD: ${cases.length} states; one actual source endpoint; ${Object.keys(runtime.files).length} loaded modules`);
}finally{runtime.close();}
