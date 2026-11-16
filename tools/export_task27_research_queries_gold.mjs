import {createFrozenSourceRuntime,writeFrozenFixture} from './frozen_source_runtime.mjs';

const runtime=createFrozenSourceRuntime();
try {
  const engine=await runtime.load('engine');
  const content=await runtime.load('content');
  const ids=[...Object.keys(content.TECHNOLOGIES),'unknown_research',''];
  const commands={select:engine.selectTechnology,pause:engine.pauseCurrentResearch,resume:engine.resumePausedResearch,cancel:engine.cancelCurrentResearch,infinite:engine.selectInfiniteResearch};
  const stages=[
    {id:'fresh',fresh:true},
    {id:'eligible_idle'},
    {id:'finite_current',setup:[['select','basic_logistics']]},
    {id:'finite_current_queue',setup:[['select','basic_logistics'],['select','thermal_power']]},
    {id:'finite_paused',setup:[['select','basic_logistics'],['pause']]},
    {id:'paused_with_current',setup:[['select','basic_logistics'],['pause'],['select','thermal_power']]},
    {id:'paused_parent_waiting_child',setup:[['select','mining_speed_1'],['select','mining_speed_2'],['pause']]},
    {id:'paused_parent_queueable_child',setup:[['select','mining_speed_1'],['pause']]},
    {id:'blocked_queue_after_cancel',setup:[['select','mining_speed_1'],['select','mining_speed_2'],['cancel']]},
    {id:'infinite_current',setup:[['infinite','matrix_compression']]},
    {id:'finite_and_infinite',setup:[['select','basic_logistics'],['infinite','matrix_compression']]},
    {id:'finite_paused_and_infinite',setup:[['select','basic_logistics'],['pause'],['infinite','matrix_compression']]},
    {id:'all_completed',complete:true},
    {id:'infinite_raw_locked',fresh:true,rawInfinite:'matrix_compression'},
    {id:'infinite_raw_maximum',setup:[['infinite','matrix_compression']],maximum:true},
  ];
  const cases=[];
  for(const row of stages) {
    let state=engine.createInitialState(240721,false);
    if(!row.fresh)state.research.completedTechIds=Object.keys(content.TECHNOLOGIES).filter(id=>row.complete||!['basic_logistics','thermal_power','mining_speed_1','mining_speed_2'].includes(id));
    for(const action of row.setup??[]) {
      const next=commands[action[0]](state,action[1]);
      if(next===state)throw new Error('Actual source setup rejected: '+row.id+' '+action);
      state=next;
    }
    if(row.rawInfinite)state.endgame.activeInfiniteResearchId=row.rawInfinite;
    if(row.maximum)state.endgame.infiniteResearch.matrix_compression.level=1000;
    const input=structuredClone({research:state.research,endgame:state.endgame});
    const before=JSON.stringify(state);
    const expected={active:engine.hasActiveResearch(state),technologies:ids.map(id=>({id,select:engine.canSelectTechnology(state,id),queue:engine.canQueueTechnology(state,id),completed:engine.isTechnologyCompleted(state,id)}))};
    if(JSON.stringify(state)!==before)throw new Error('Source query changed ownership: '+row.id);
    cases.push({...row,input,expected});
  }
  writeFrozenFixture(runtime,'task27-research-queries.json',{
    scope:'Actual source read-only queries for all 76 finite definitions plus unknown/empty IDs, 15 current/paused/queue/infinite ownership states. Raw locked/maximum infinite states test query semantics only; not valid save or simulation evidence. Funded prerequisites are explicit controlled inputs.',
    cases,
  });
  console.log('TASK27 RESEARCH QUERY GOLD: '+cases.length+' actual states; '+cases.length*ids.length+' finite eligibility/completion rows');
}finally{runtime.close();}
