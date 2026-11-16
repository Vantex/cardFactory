import fs from 'node:fs';
import {createFrozenSourceRuntime,writeFrozenFixture} from './frozen_source_runtime.mjs';

const runtime=createFrozenSourceRuntime();
try {
  const engine=await runtime.load('engine');
  const content=await runtime.load('content');
  const campaign=await runtime.load('campaign');
  const storage=await runtime.load('storage');
  const commands={select:engine.selectTechnology,finite:engine.selectTechnology,infinite:engine.selectInfiniteResearch,pause:engine.pauseCurrentResearch,resume:engine.resumePausedResearch,cancel:engine.cancelCurrentResearch,remove:engine.removeQueuedTechnology,automatic:engine.setInfiniteResearchAutomation,tick:state=>engine.advanceSimulation(state,.25)};
  const read=name=>JSON.parse(fs.readFileSync(new URL('../tests/fixtures/parity/behavior/'+name,import.meta.url),'utf8'));
  // Reuse only scenario inputs; every expectation is executed again below.
  const finite=read('task27-research-commands.json').cases.map(({id,setup,action,paid})=>({id:'finite:'+id,setup,action,paid}));
  const infinite=read('task27-infinite-research.json').commands.map(({id,setup,action})=>({id:'infinite:'+id,setup,action}));
  const deprecated=Object.values(content.TECHNOLOGIES).filter(row=>content.isDeprecatedTechnology(row.id)).flatMap(row=>[
    {id:'deprecated:'+row.id+':idle',uncompleted:[row.id],setup:[],action:['select',row.id]},
    {id:'deprecated:'+row.id+':queue',uncompleted:[row.id],setup:[['select','basic_logistics']],action:['select',row.id]},
  ]);
  if(deprecated.length!==14)throw new Error('Frozen deprecated technology inputs incomplete');
  const extra=[
    {id:'empty:idle',setup:[],action:['select','']},
    {id:'empty:queue',setup:[['select','basic_logistics']],action:['select','']},
    {id:'remove:paused_parent_preserved',setup:[['select','mining_speed_1'],['pause'],['select','basic_logistics'],['select','mining_speed_2'],['select','thermal_power']],action:['remove','thermal_power']},
    {id:'remove:dependent_only',setup:[['select','basic_logistics'],['select','mining_speed_1'],['select','mining_speed_2'],['select','thermal_power']],action:['remove','mining_speed_2']},
    {id:'remove:deep_cascade',uncompleted:['mining_speed_3'],setup:[['select','mining_speed_1'],['select','mining_speed_2'],['select','mining_speed_3'],['select','thermal_power']],action:['remove','mining_speed_2']},
  ];
  const scenarios=[...finite,...infinite,...deprecated,...extra];
  const view=state=>({research:state.research,endgame:state.endgame,labs:state.entities.filter(entity=>entity.buildingId==='matrix_lab'),construction:state.construction,exploration:state.exploration});
  const cases=[];
  for(const row of scenarios) {
    let state=engine.createInitialState(240721,false);
    const uncompleted=['basic_logistics','thermal_power','mining_speed_1','mining_speed_2',...(row.uncompleted??[])];
    state.research.completedTechIds=Object.keys(content.TECHNOLOGIES).filter(id=>id!=='interstellar_logistics');
    state.campaign.completedTaskIds=campaign.CAMPAIGN_TASKS.map(task=>task.id);
    state.campaign.rewardedTaskIds=[...state.campaign.completedTaskIds];
    state.campaign.activeTaskId=null;
    state=engine.selectTechnology(state,'interstellar_logistics');
    state.research.progressByTech.interstellar_logistics=Object.fromEntries(content.getTechnology('interstellar_logistics').costs.map(cost=>[cost.itemId,cost.amount]));
    if(!engine.settleCompletedResearchBoundariesInPlace(state).includes('interstellar_logistics'))throw new Error('Funded source prerequisite failed');
    state.research.completedTechIds=state.research.completedTechIds.filter(id=>!uncompleted.includes(id));
    state.construction.matrix_lab=2;
    state=engine.placeBuilding(state,'matrix_lab',{x:200,y:0});
    state=engine.placeBuilding(state,'matrix_lab',{x:400,y:0});
    for(const lab of state.entities.filter(entity=>entity.buildingId==='matrix_lab'))state=engine.setEntityRecipe(state,lab.id,'matrix_research');
    const baseline=structuredClone({view:view(state),campaign:state.campaign});
    for(const action of row.setup) {
      const next=commands[action[0]](state,action[1]);
      if(next===state)throw new Error('Actual source setup rejected '+row.id+' '+action);
      state=next;
    }
    for(const id of row.paid?(Array.isArray(row.paid)?row.paid:[row.paid]):[])state.research.progressByTech[id]=Object.fromEntries(content.getTechnology(id).costs.map(cost=>[cost.itemId,cost.amount]));
    const labs=state.entities.filter(entity=>entity.buildingId==='matrix_lab');
    labs[0].progress=.4;
    labs[1].progress=.7;
    labs[0].inputs={electromagnetic_matrix:3,universe_matrix:2};
    labs[1].inputs={energy_matrix:4};
    const input=structuredClone({view:view(state),campaign:state.campaign});
    const before=JSON.stringify(state);
    const after=commands[row.action[0]](state,row.action[1]);
    if(JSON.stringify(state)!==before)throw new Error('Immutable source control changed input '+row.id);
    cases.push({...row,baseline,input,changed:after!==state,expected:view(after),loaded_before:view(storage.migrateGame(structuredClone(state))),loaded_after:view(storage.migrateGame(structuredClone(after)))});
  }
  writeFrozenFixture(runtime,'task27-research-controls.json',{
    scope:'Actual complete source controls executed afresh from 30 finite and 15 infinite scenario inputs, all seven deprecated definitions idle/queued, empty IDs and extra remove cascades. Actual source prerequisite settlement establishes colony/construction rewards; fixture-funded other prerequisites, two actual labs, immutable command input and source storage before/after. Not a full growth journey.',
    case_ids:cases.map(row=>row.id),cases,
  });
  console.log('TASK27 RESEARCH CONTROL GOLD: '+cases.length+' actual immutable controls and before/after migrations');
}finally{runtime.close();}
