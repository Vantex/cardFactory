import {createFrozenSourceRuntime,writeFrozenFixture} from './frozen_source_runtime.mjs';

const runtime=createFrozenSourceRuntime();
try {
  const engine=await runtime.load('engine');
  const content=await runtime.load('content');
  const campaign=await runtime.load('campaign');
  const endgame=await runtime.load('endgame');
  const math=await runtime.load('infiniteResearch');
  const storage=await runtime.load('storage');
  const snapshot=state=>({
    finite:state.research,
    active:state.endgame.activeInfiniteResearchId,
    automatic:state.endgame.autoResearch,
    progress:state.endgame.infiniteResearch,
    score:state.endgame.galacticScore,
    credits:state.endgame.galacticCredits,
    labs:state.entities.filter(entity=>entity.buildingId==='matrix_lab'),
    construction:state.construction,
  });
  const prepare=(id,windCount=4)=>{
    let state=engine.createInitialState(240721,false);
    state.research.completedTechIds=Object.keys(content.TECHNOLOGIES).filter(id=>!['basic_logistics','thermal_power'].includes(id));
    state.campaign.completedTaskIds=campaign.CAMPAIGN_TASKS.map(task=>task.id);
    state.campaign.rewardedTaskIds=[...state.campaign.completedTaskIds];
    state.campaign.activeTaskId=null;
    state.construction.wind_turbine=4;
    state=engine.placeBuilding(state,'wind_turbine',{x:0,y:-200},windCount);
    state.construction.matrix_lab=2;
    state=engine.placeBuilding(state,'matrix_lab',{x:200,y:0});
    state=engine.placeBuilding(state,'matrix_lab',{x:400,y:0});
    for(const lab of state.entities.filter(entity=>entity.buildingId==='matrix_lab'))state=engine.setEntityRecipe(state,lab.id,'matrix_research');
    return state;
  };
  const cases=[];
  for(const definition of endgame.INFINITE_RESEARCH_DEFINITIONS) {
    const id=definition.id;
    for(const stage of ['half_cycle','first_payment','last_payment','last_payment_automatic','maximum_payment','starved','unpowered','locked','completed','funded_two_seconds','funded_three_seconds','funded_seventeen_seconds','automatic_funded','high_level_batch','two_funded_labs','fixed_tick_funded','fixed_tick_high_level','sprayed_funded','sprayed_partial_high_level','epsilon_boundary','sprayed_low_power_high_level','rounded_epsilon_boundary','epsilon_idle']) {
      let state=prepare(id,stage==='sprayed_low_power_high_level'?1:4);
      if(stage==='locked')state.research.completedTechIds=state.research.completedTechIds.filter(id=>id!=='universe_matrix');
      if(stage==='maximum_payment')state.endgame.infiniteResearch[id].level=math.getInfiniteResearchMaximumLevel(id)-1;
      if(stage==='completed')state.endgame.infiniteResearch[id].level=math.getInfiniteResearchMaximumLevel(id);
      if(stage.includes('high_level')||stage==='high_level_batch')state.endgame.infiniteResearch[id].level=math.getInfiniteResearchMaximumLevel(id)-1;
      const level=state.endgame.infiniteResearch[id].level;
      if(stage.includes('last_payment')||stage==='maximum_payment')state.endgame.infiniteResearch[id].progress=String(math.getInfiniteResearchCostBigInt(id,level)-1n);
      if(stage==='automatic_funded')state.endgame.infiniteResearch[id].progress=String(math.getInfiniteResearchCostBigInt(id,level)-2n);
      if(stage.includes('high_level')||stage==='high_level_batch')state.endgame.infiniteResearch[id].progress=String(math.getInfiniteResearchCostBigInt(id,level)-1000n);
      state=engine.setInfiniteResearchAutomation(state,['last_payment_automatic','automatic_funded'].includes(stage));
      const selected=engine.selectInfiniteResearch(state,id);
      const selection_changed=selected!==state;
      state=selected;
      if(stage.startsWith('sprayed')) {
        state.construction.spray_coater=1;
        const lab=state.entities.find(entity=>entity.buildingId==='matrix_lab');
        state=engine.installSprayCoater(state,lab.id);
        state=engine.setProliferatorConfiguration(state,lab.id,3,'speed');
      }
      const labs=state.entities.filter(entity=>entity.buildingId==='matrix_lab');
      labs[0].inputs={universe_matrix:stage==='starved'?0:stage.includes('high_level')||stage==='high_level_batch'?50:stage.includes('funded')?10:1};
      if(stage.startsWith('sprayed')) {
        labs[0].inputs.proliferator_mk3=stage==='sprayed_funded'?1:0;
        labs[0].proliferatorPoints=stage==='sprayed_partial_high_level'||stage==='sprayed_low_power_high_level'?1:0;
      }
      labs[1].inputs={universe_matrix:stage==='two_funded_labs'?10:0};
      labs[1].progress=0.5;
      if(stage==='epsilon_boundary')labs[0].progress=0.9998;
      if(stage==='rounded_epsilon_boundary')labs[0].progress=0.9996;
      if(stage==='epsilon_idle')labs[0].progress=0.9999;
      if(stage==='unpowered')state.entities=state.entities.filter(entity=>entity.buildingId!=='wind_turbine');
      const input=structuredClone({view:snapshot(state),campaign:state.campaign,wind_count:stage==='unpowered'?0:stage==='sprayed_low_power_high_level'?1:4});
      const seconds=({half_cycle:0.25,funded_two_seconds:2,funded_three_seconds:3,funded_seventeen_seconds:17,automatic_funded:20,epsilon_boundary:0.0002,sprayed_low_power_high_level:1,rounded_epsilon_boundary:0.0005136,epsilon_idle:0.00015})[stage]??6;
      const simulation_step=stage.startsWith('fixed_tick')?1/60:1;
      const session=engine.createSimulationAdvanceSession(state,seconds);
      session.stepSize=simulation_step;
      engine.advanceSimulationSession(session,Number.MAX_SAFE_INTEGER);
      const after=engine.completeSimulationAdvanceSession(session);
      cases.push({id,stage,input,selection_changed,seconds,simulation_step,phase_rounding_bound:Math.ceil(seconds/simulation_step)*0.0000005+0.000000001,expected:snapshot(after),loaded_after:snapshot(storage.migrateGame(structuredClone(after)))});
    }
  }
  const commands={
    finite:(state,id)=>engine.selectTechnology(state,id),
    infinite:(state,id)=>engine.selectInfiniteResearch(state,id),
    pause:state=>engine.pauseCurrentResearch(state),
    resume:state=>engine.resumePausedResearch(state),
    cancel:state=>engine.cancelCurrentResearch(state),
    automatic:(state,value)=>engine.setInfiniteResearchAutomation(state,value),
  };
  const scenarios=[
    {id:'select_infinite_idle',setup:[],action:['infinite','matrix_compression']},
    {id:'repeat_infinite_preserves_phase',setup:[['infinite','matrix_compression']],action:['infinite','matrix_compression']},
    {id:'infinite_alongside_finite',setup:[['finite','basic_logistics']],action:['infinite','matrix_compression']},
    {id:'finite_alongside_infinite',setup:[['infinite','matrix_compression']],action:['finite','basic_logistics']},
    {id:'queue_alongside_infinite',setup:[['finite','basic_logistics'],['infinite','matrix_compression']],action:['finite','thermal_power']},
    {id:'pause_infinite',setup:[['infinite','matrix_compression']],action:['pause']},
    {id:'cancel_infinite',setup:[['infinite','matrix_compression']],action:['cancel']},
    {id:'pause_both',setup:[['finite','basic_logistics'],['infinite','matrix_compression']],action:['pause']},
    {id:'cancel_both',setup:[['finite','basic_logistics'],['infinite','matrix_compression']],action:['cancel']},
    {id:'resume_finite_alongside_infinite',setup:[['finite','basic_logistics'],['pause'],['infinite','matrix_compression']],action:['resume']},
    {id:'switch_infinite_resets_phases',setup:[['infinite','matrix_compression']],action:['infinite','vein_utilization']},
    {id:'automatic_repeat_is_noop',setup:[],action:['automatic',true]},
    {id:'automatic_change',setup:[],action:['automatic',false]},
    {id:'select_infinite_unknown',setup:[],action:['infinite','unknown']},
    {id:'automatic_enable',setup:[['automatic',false]],action:['automatic',true]},
  ];
  const command_cases=[];
  for(const scenario of scenarios) {
    let state=prepare('matrix_compression');
    for(const action of scenario.setup)state=commands[action[0]](state,action[1]);
    for(const [index,lab] of state.entities.filter(entity=>entity.buildingId==='matrix_lab').entries())lab.progress=index===0?0.4:0.7;
    const input=structuredClone({view:snapshot(state),campaign:state.campaign,wind_count:4});
    const after=commands[scenario.action[0]](state,scenario.action[1]);
    command_cases.push({...scenario,input,changed:after!==state,expected:snapshot(after),loaded_after:snapshot(storage.migrateGame(structuredClone(after)))});
  }
  const budgets=[];
  for(const definition of endgame.INFINITE_RESEARCH_DEFINITIONS) {
    const id=definition.id;
    const maximum=math.getInfiniteResearchMaximumLevel(id);
    const first=math.getInfiniteResearchCostBigInt(id,0);
    const last=math.getInfiniteResearchCostBigInt(id,maximum-1);
    const cumulative=Array.from({length:maximum},(_,level)=>math.getInfiniteResearchCostBigInt(id,level)).reduce((sum,value)=>sum+value,0n);
    const third=first+math.getInfiniteResearchCostBigInt(id,1)+math.getInfiniteResearchCostBigInt(id,2);
    const stages=[
      {stage:'zero',requested:0n},
      {stage:'negative',requested:-5n},
      {stage:'first',requested:1n},
      {stage:'exact',requested:first},
      {stage:'excess_manual',requested:first+5n},
      {stage:'three_levels_automatic',requested:third+5n,automatic:true},
      {stage:'exact_boundary_zero',progress:first,requested:0n},
      {stage:'excess_boundary_zero',progress:first+5n,requested:0n,automatic:true},
      {stage:'tenth_level',level:9,progress:math.getInfiniteResearchCostBigInt(id,9)-1n,requested:1n},
      {stage:'last_manual',level:maximum-1,progress:last-1n,requested:2n},
      {stage:'last_automatic',level:maximum-1,progress:last-1n,requested:2n,automatic:true},
      {stage:'maximum',level:maximum,requested:5n,automatic:true},
      {stage:'entire_curve',requested:cumulative+5n,automatic:true},
    ];
    for(const row of stages) {
      let state=prepare(id);
      state.endgame.infiniteResearch[id]={level:row.level??0,progress:String(row.progress??0n)};
      state.endgame.activeInfiniteResearchId=id;
      state.endgame.autoResearch=row.automatic??false;
      const input=structuredClone({view:snapshot(state),campaign:state.campaign,wind_count:4});
      const consumed=engine.investInfiniteResearchBudgetInPlace(state,id,row.requested);
      budgets.push({id,stage:row.stage,input,requested:String(row.requested),consumed:String(consumed),expected:snapshot(state),loaded_after:snapshot(storage.migrateGame(structuredClone(state)))});
    }
  }
  writeFrozenFixture(runtime,'task27-infinite-research.json',{
    scope:'Actual frozen engine for five infinite research definitions: funded finite prerequisites/rewards, first and final matrix payments, exact maximum-level decimal costs, automation and power/starvation/unlock gates; command coexistence and all real lab phases. Controlled evidence, not a full growth journey.',
    source_initial_automatic:engine.createInitialState(240721,false).endgame.autoResearch,
    cases,commands:command_cases,budgets,
  });
  console.log('TASK27 INFINITE RESEARCH GOLD: '+cases.length+' actual simulations; '+command_cases.length+' command transitions; '+budgets.length+' actual budget settlements');
}finally{runtime.close();}
