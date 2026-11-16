import {createFrozenSourceRuntime,writeFrozenFixture} from './frozen_source_runtime.mjs';

const runtime=createFrozenSourceRuntime();
try {
  const engine=await runtime.load('engine');
  const content=await runtime.load('content');
  const campaign=await runtime.load('campaign');
  const storage=await runtime.load('storage');
  const view=state=>({research:state.research,endgame:state.endgame,labs:state.entities.filter(entity=>entity.buildingId==='matrix_lab'),construction:state.construction,exploration:state.exploration});
  const prepare=(id)=>{
    let state=engine.createInitialState(240721,false);
    state.research.completedTechIds=Object.keys(content.TECHNOLOGIES).filter(item=>item!=='interstellar_logistics');
    state.campaign.completedTaskIds=campaign.CAMPAIGN_TASKS.map(task=>task.id);
    state.campaign.rewardedTaskIds=[...state.campaign.completedTaskIds];
    state.campaign.activeTaskId=null;
    if(id!=='interstellar_logistics') {
      state=engine.selectTechnology(state,'interstellar_logistics');
      state.research.progressByTech.interstellar_logistics=Object.fromEntries(content.getTechnology('interstellar_logistics').costs.map(cost=>[cost.itemId,cost.amount]));
      const completed=engine.settleCompletedResearchBoundariesInPlace(state);
      if(!completed.includes('interstellar_logistics'))throw new Error('Actual funded prerequisite settlement rejected');
    }
    state.construction.matrix_lab=2;
    state=engine.placeBuilding(state,'matrix_lab',{x:200,y:0});
    state=engine.placeBuilding(state,'matrix_lab',{x:400,y:0});
    for(const lab of state.entities.filter(entity=>entity.buildingId==='matrix_lab'))state=engine.setEntityRecipe(state,lab.id,'matrix_research');
    state.research.completedTechIds=state.research.completedTechIds.filter(item=>item!==id);
    state.research.selectedTechId=id;
    return state;
  };
  const rows=[];
  for(const definition of Object.values(content.TECHNOLOGIES)) {
    for(const stage of ['partial','exact','overshoot','fractional_below','fractional_paid','already_completed']) {
      const state=prepare(definition.id);
      const offset=({partial:-1,exact:0,overshoot:3,fractional_below:-0.25,fractional_paid:0.25,already_completed:0})[stage];
      state.research.progressByTech[definition.id]=Object.fromEntries(definition.costs.map(cost=>[cost.itemId,Math.max(0,cost.amount+offset)]));
      if(stage==='already_completed')state.research.completedTechIds.push(definition.id);
      rows.push({id:definition.id,stage,state});
    }
  }
  const scenarios=[
    {id:'idle',selected:null,queue:[]},
    {id:'unknown_current',selected:'unknown_research',queue:['thermal_power']},
    {id:'completed_current',selected:'electromagnetism',queue:['thermal_power']},
    {id:'blocked_queue',selected:'basic_logistics',queue:['mining_speed_2','thermal_power'],paid:['basic_logistics']},
    {id:'paid_chain',selected:'basic_logistics',queue:['thermal_power','mining_speed_1'],paid:['basic_logistics','thermal_power']},
    {id:'paid_three_chain',selected:'basic_logistics',queue:['thermal_power','mining_speed_1','mining_speed_2'],paid:['basic_logistics','thermal_power','mining_speed_1']},
    {id:'paused_paid',selected:null,paused:'basic_logistics',queue:['thermal_power'],paid:['basic_logistics']},
    {id:'finite_infinite_paid',selected:'basic_logistics',queue:['thermal_power'],paid:['basic_logistics'],infinite:true},
    {id:'infinite_only',selected:null,queue:[],infinite:true},
    {id:'missing_cost',selected:'basic_logistics',queue:['thermal_power']},
  ];
  for(const scenario of scenarios) {
    const state=prepare('basic_logistics');
    state.research.completedTechIds=Object.keys(content.TECHNOLOGIES).filter(id=>!['basic_logistics','thermal_power','mining_speed_1','mining_speed_2'].includes(id));
    state.research.selectedTechId=scenario.selected;
    state.research.pausedTechId=scenario.paused??null;
    state.research.queuedTechIds=scenario.queue;
    for(const id of scenario.paid??[])state.research.progressByTech[id]=Object.fromEntries(content.getTechnology(id).costs.map(cost=>[cost.itemId,cost.amount]));
    if(scenario.infinite)state.endgame.activeInfiniteResearchId='matrix_compression';
    rows.push({id:'command',stage:scenario.id,state});
  }
  const cases=[];
  for(const row of rows) {
    const labs=row.state.entities.filter(entity=>entity.buildingId==='matrix_lab');
    labs[0].progress=.4;
    labs[1].progress=.7;
    labs[0].inputs={electromagnetic_matrix:3,universe_matrix:2};
    labs[1].inputs={energy_matrix:4};
    const input=structuredClone({view:view(row.state),campaign:row.state.campaign});
    const before=JSON.stringify(row.state);
    const copied=engine.settleCompletedResearchBoundaries(row.state);
    if(JSON.stringify(row.state)!==before)throw new Error('Source pure settlement mutated input '+row.id+':'+row.stage);
    const inplace=structuredClone(row.state);
    const completed=engine.settleCompletedResearchBoundariesInPlace(inplace);
    const again=engine.settleCompletedResearchBoundariesInPlace(inplace);
    if(again.length)throw new Error('Source repeated boundary not idempotent');
    const pureAgain=engine.settleCompletedResearchBoundaries(copied);
    cases.push({id:row.id,stage:row.stage,input,pure_changed:copied!==row.state,pure_expected:view(copied),inplace_completed:completed,inplace_expected:view(inplace),pure_repeated_changed:pureAgain!==copied,pure_repeated_expected:view(pureAgain),loaded_after:view(storage.migrateGame(structuredClone(inplace)))});
  }
  writeFrozenFixture(runtime,'task27-research-boundaries.json',{
    scope:'Actual public pure/in-place finite boundary endpoints for 76 definitions (including deprecated raw endpoint states), full/partial/fractional/overshot and already-completed ledgers; queue chains, unknown/idle/paused and finite/infinite coexistence. Two real source labs, exact construction/exploration rewards and actual storage migration. Raw partial/fractional/unknown states are endpoint evidence only, not claims of valid local save inputs. Funded prerequisites/rewards are controlled input, not full growth.',
    stages:['partial','exact','overshoot','fractional_below','fractional_paid','already_completed'],command_stages:scenarios.map(row=>row.id),cases,
  });
  console.log('TASK27 RESEARCH BOUNDARY GOLD: '+cases.length+' actual pairs of pure/in-place endpoints; repeated settlement and source migration');
}finally{runtime.close();}
