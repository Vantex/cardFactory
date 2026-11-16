import {createFrozenSourceRuntime,writeFrozenFixture} from './frozen_source_runtime.mjs';

const runtime=createFrozenSourceRuntime();
try {
  const engine=await runtime.load('engine');
  const content=await runtime.load('content');
  const storage=await runtime.load('storage');
  const campaign=await runtime.load('campaign');
  const commands={select:engine.selectTechnology,pause:engine.pauseCurrentResearch,resume:engine.resumePausedResearch,cancel:engine.cancelCurrentResearch,remove:engine.removeQueuedTechnology,tick:state=>engine.advanceSimulation(state,0.25)};
  const scenarios=[
    {id:'select_resets_all_labs',setup:[],action:['select','basic_logistics']},
    {id:'pause_resets_all_labs',setup:[['select','basic_logistics']],action:['pause']},
    {id:'resume_resets_all_labs',setup:[['select','basic_logistics'],['pause']],action:['resume']},
    {id:'cancel_activates_queue',setup:[['select','basic_logistics'],['select','thermal_power']],action:['cancel']},
    {id:'select_settles_paid_boundary',setup:[],paid:'basic_logistics',action:['select','basic_logistics']},
    {id:'cancel_settles_paid_boundary',setup:[['select','basic_logistics'],['select','thermal_power']],paid:'basic_logistics',action:['cancel']},
    {id:'queue_accepts_planned_parent',setup:[['select','mining_speed_1']],action:['select','mining_speed_2']},
    {id:'remove_cascades_dependents',setup:[['select','basic_logistics'],['select','mining_speed_1'],['select','mining_speed_2']],action:['remove','mining_speed_1']},
    {id:'select_alongside_paused',setup:[['select','basic_logistics'],['pause']],action:['select','thermal_power']},
    {id:'cancel_paused_is_noop',setup:[['select','basic_logistics'],['pause']],action:['cancel']},
    {id:'pause_idle_is_noop',setup:[],action:['pause']},
    {id:'resume_idle_is_noop',setup:[],action:['resume']},
    {id:'cancel_idle_is_noop',setup:[],action:['cancel']},
    {id:'select_current_is_noop',setup:[['select','basic_logistics']],action:['select','basic_logistics']},
    {id:'select_completed_is_noop',setup:[],action:['select','electromagnetism']},
    {id:'select_unknown_is_noop',setup:[],action:['select','unknown_research']},
    {id:'select_locked_is_noop',setup:[],action:['select','mining_speed_2']},
    {id:'select_queued_is_noop',setup:[['select','basic_logistics'],['select','thermal_power']],action:['select','thermal_power']},
    {id:'remove_missing_is_noop',setup:[['select','basic_logistics']],action:['remove','thermal_power']},
    {id:'resume_alongside_current_is_noop',setup:[['select','basic_logistics'],['pause'],['select','thermal_power']],action:['resume']},
    {id:'resume_with_waiting_queue',setup:[['select','mining_speed_1'],['select','mining_speed_2'],['pause']],action:['resume']},
    {id:'select_resumes_with_waiting_queue',setup:[['select','mining_speed_1'],['select','mining_speed_2'],['pause']],action:['select','mining_speed_1']},
    {id:'queue_uses_paused_parent',setup:[['select','mining_speed_1'],['pause'],['select','basic_logistics']],action:['select','mining_speed_2']},
    {id:'pause_replaces_previous_paused',setup:[['select','basic_logistics'],['pause'],['select','thermal_power']],action:['pause']},
    {id:'cancel_skips_blocked_queue_head',setup:[['select','mining_speed_1'],['select','mining_speed_2'],['select','thermal_power']],action:['cancel']},
    {id:'select_settles_active_paid_boundary',setup:[['select','basic_logistics']],paid:'basic_logistics',action:['select','thermal_power']},
    {id:'resume_settles_paid_boundary',setup:[['select','basic_logistics'],['pause']],paid:'basic_logistics',action:['resume']},
    {id:'tick_settles_paid_boundary',setup:[['select','basic_logistics']],paid:'basic_logistics',action:['tick']},
    {id:'cancel_settles_paid_queue_chain',setup:[['select','basic_logistics'],['select','thermal_power'],['select','mining_speed_1']],paid:['basic_logistics','thermal_power'],action:['cancel']},
    {id:'queued_paused_selection_waits',setup:[['select','basic_logistics'],['pause'],['select','thermal_power'],['select','basic_logistics']],action:['cancel']},
  ];
  const cases=[];
  for(const scenario of scenarios) {
    let state=engine.createInitialState(240721,false);
    state.research.completedTechIds=Object.keys(content.TECHNOLOGIES).filter(id=>!['basic_logistics','thermal_power','mining_speed_1','mining_speed_2'].includes(id));
    state.campaign.completedTaskIds=campaign.CAMPAIGN_TASKS.map(task=>task.id);
    state.campaign.rewardedTaskIds=[...state.campaign.completedTaskIds];
    state.campaign.activeTaskId=null;
    state.construction.matrix_lab=2;
    state=engine.placeBuilding(state,'matrix_lab',{x:200,y:0});
    state=engine.placeBuilding(state,'matrix_lab',{x:400,y:0});
    for(const entity of state.entities.filter(e=>e.buildingId==='matrix_lab')) state=engine.setEntityRecipe(state,entity.id,'matrix_research');
    for(const action of scenario.setup) state=commands[action[0]](state,action[1]);
    for(const id of scenario.paid?(Array.isArray(scenario.paid)?scenario.paid:[scenario.paid]):[]) state.research.progressByTech[id]=Object.fromEntries(content.getTechnology(id).costs.map(cost=>[cost.itemId,cost.amount]));
    const labs=state.entities.filter(e=>e.buildingId==='matrix_lab');
    labs[0].progress=0.4;
    labs[1].progress=0.7;
    const input=structuredClone({research:state.research,labs,construction:state.construction,campaign:state.campaign});
    const after=commands[scenario.action[0]](state,scenario.action[1]);
    const loadedBefore=storage.migrateGame(structuredClone(state));
    const loadedAfter=storage.migrateGame(structuredClone(after));
    if(!loadedBefore||!loadedAfter)throw new Error('Frozen research migration rejected '+scenario.id);
    const view=state=>({research:state.research,labs:state.entities.filter(e=>e.buildingId==='matrix_lab'),construction:state.construction});
    cases.push({...scenario,input,expected:view(after),loaded_before:view(loadedBefore),loaded_after:view(loadedAfter),changed:after!==state});
  }
  writeFrozenFixture(runtime,'task27-research-commands.json',{scope:'Actual frozen finite research commands with two real labs, phase reset, paid boundaries, queue dependency cascade and paused/current coexistence. Fixture-funded completed prerequisites and paid boundary. Local comparisons must account explicitly for preserved native teaching research.',cases});
  console.log('TASK27 RESEARCH COMMAND GOLD: '+cases.length+' actual command transitions');
} finally {runtime.close();}
