import assert from 'node:assert/strict';
import {createFrozenSourceRuntime,writeFrozenFixture} from './frozen_source_runtime.mjs';
const runtime=createFrozenSourceRuntime();
try {
  const engine=await runtime.load('engine');
  const finite=['logistics_engine_1','logistics_engine_2','logistics_capacity_1','logistics_capacity_2'];
  const levels=[0,1,2,9,10,11,99,999,1000];
  const functions=['getPlanetaryCargoCapacity','getInterstellarCargoCapacity','getPlanetaryTripSeconds'];
  const cases=[];
  for(const difficulty of ['relaxed','standard','hard'])for(let mask=0;mask<16;mask++)for(const level of levels){
    const state=engine.createInitialState(240721,false);
    state.settings.difficulty=difficulty;
    state.research.completedTechIds=finite.filter((_id,index)=>mask&(1<<index));
    state.endgame.infiniteResearch.galactic_logistics={level,progress:'0'};
    const before=JSON.stringify(state);
    const expected=Object.fromEntries(functions.map(name=>[name,engine[name](state)]));
    assert.equal(JSON.stringify(state),before,'Logistics scalar source query changed raw state');
    cases.push({id:`${difficulty}-${mask}-${level}`,input:{difficulty,completed:state.research.completedTechIds,level},expected});
  }
  writeFrozenFixture(runtime,'task27-logistics-scalars.json',{
    scope:'Actual read-only cargo/trip scalar queries for all 16 finite engine/capacity combinations, nine integer infinite galactic-logistics levels and three difficulties. Local comparison uses actual station logistics_snapshot after a separately funded paid station placement. This proves capacities/rounding/local-trip numbers and query immutability, not route economics, dispatched cargo, throughput, earned growth or save validity.',
    functions,finite,levels,cases,
  });
  console.log(`TASK27 LOGISTICS SCALAR GOLD: ${cases.length} controlled states; 3 actual public query endpoints`);
}finally{runtime.close();}
