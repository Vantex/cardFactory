import fs from 'node:fs';
import {createFrozenSourceRuntime,writeFrozenFixture} from './frozen_source_runtime.mjs';

const runtime=createFrozenSourceRuntime();
try{
  const engine=await runtime.load('engine');
  const campaign=await runtime.load('campaign');
  const storage=await runtime.load('storage');
  const sourceInputs=JSON.parse(fs.readFileSync(new URL('../tests/fixtures/parity/behavior/task27-progression.json',import.meta.url),'utf8'));
  if(sourceInputs.source_commit!==runtime.commit)throw new Error('Progression input revision changed');
  const stages=['zero','exact','locked','completed_rewarded'];
  const cases=[];
  const view=state=>({
    campaign:state.campaign,
    achievements:state.achievements,
    snapshot:campaign.getCampaignSnapshot(state),
    deficits:campaign.CAMPAIGN_TASKS.map(task=>({id:task.id,items:campaign.getCampaignTaskDeficits(state,task)})),
  });
  const record=(id,targetId,input)=>{
    const state=Object.assign(engine.createInitialState(240721,false),structuredClone(input));
    const original=JSON.stringify(state);
    const before=view(state);
    const next=campaign.selectCampaignTask(state,targetId);
    const again=campaign.selectCampaignTask(next,targetId);
    if(JSON.stringify(state)!==original)throw new Error('Immutable source campaign selection mutated input '+id);
    cases.push({id,targetId,input:structuredClone(input),before,changed:next!==state,expected:view(next),repeat_changed:again!==next,repeated:view(again),loaded_after:view(storage.migrateGame(structuredClone(next)))});
  };
  for(const task of campaign.CAMPAIGN_TASKS){
    for(const stage of stages){
      const input=sourceInputs.cases.find(row=>row.category==='campaign'&&row.id===task.id&&row.stage===stage)?.input;
      if(!input)throw new Error('Actual campaign input missing '+task.id+':'+stage);
      const prepared=structuredClone(input);
      if(stage==='zero'){prepared.campaign.activeTaskId=null;prepared.campaign.activeChapterId=null;}
      record(task.id+':'+stage,task.id,prepared);
    }
  }
  const baseline=sourceInputs.cases.find(row=>row.category==='campaign'&&row.id==='mine_first_ore'&&row.stage==='zero').input;
  record('unknown','unknown_campaign_task',baseline);
  record('empty','',baseline);
  const unsettled=sourceInputs.cases.find(row=>row.category==='achievements'&&row.id==='multi_system_industry'&&row.stage==='exact').input;
  record('unsettled_achievement','unknown_campaign_task',unsettled);
  const fresh=engine.createInitialState(240721,false);
  const freshInput=Object.fromEntries(Object.keys(baseline).map(key=>{
    if(fresh[key]===undefined)throw new Error('Initial source projection missing '+key);
    return [key,structuredClone(fresh[key])];
  }));
  record('initial','unknown_campaign_task',freshInput);
  const noSelection=structuredClone(freshInput);
  noSelection.campaign.activeTaskId=null;
  noSelection.campaign.activeChapterId=null;
  record('initial_no_selection','unknown_campaign_task',noSelection);
  const blockedSelection=structuredClone(freshInput);
  blockedSelection.campaign.activeTaskId='produce_universe_matrix';
  blockedSelection.campaign.activeChapterId='matrix_mastery';
  record('initial_blocked_selection','unknown_campaign_task',blockedSelection);
  record('initial_select_side','side_storage',freshInput);
  record('initial_select_miner','deploy_miner',freshInput);
  for(const [id,remoteAmount] of [['network_split_short',0],['network_split_exact',1]]){
    let stocked=Object.assign(engine.createInitialState(240721,false),structuredClone(baseline));
    engine.completeTechnology(stocked,'interstellar_logistics');
    stocked.tray.iron_ore=1;
    stocked.planetTrays[stocked.activePlanetId]=structuredClone(stocked.tray);
    stocked=engine.pickFromTray(stocked,'iron_ore',1);
    if(stocked.cargo?.amount!==1)throw new Error('Actual source cargo pickup failed');
    stocked.construction.arc_smelter=Math.max(1,stocked.construction.arc_smelter??0);
    stocked=engine.placeBuilding(stocked,'arc_smelter',{x:10000,y:10000});
    const machine=stocked.entities.findLast(row=>row.buildingId==='arc_smelter');
    if(!machine)throw new Error('Actual source placed machine missing');
    machine.inputs.iron_ore=1;
    machine.outputs.iron_ore=1;
    for(const planet of Object.keys(stocked.planetTrays))stocked.planetTrays[planet].iron_ore=0;
    stocked.tray.iron_ore=0;
    const remote=stocked.exploration.colonizedPlanetIds.find(planet=>planet!==stocked.activePlanetId);
    if(!remote)throw new Error('Source funded remote colony missing');
    stocked.planetTrays[remote].iron_ore=remoteAmount;
    const input=Object.fromEntries([...Object.keys(baseline),'cargo'].map(key=>[key,structuredClone(stocked[key])]));
    record(id,'unknown_campaign_task',input);
  }
  writeFrozenFixture(runtime,'task27-campaign-controls.json',{
    scope:'Actual frozen selectCampaignTask, getCampaignSnapshot, getCampaignTaskDeficits and storage.migrateGame for all 32 tasks in four controlled states, unknown/empty IDs, unsettled achievement, complete initial state and two split network-stock states with actual source placed machine and cargo pickup. Other completion records, building buffers and resources are fixture-funded. All selection, repeated selection, chapter/status/progress/requirements/deficits and loaded results are freshly executed. These are controlled query/selection boundaries, not browser navigation, complete campaign growth or human desktop evidence.',
    stages,cases,chapters:campaign.CAMPAIGN_CHAPTERS,task_order:campaign.CAMPAIGN_TASKS.map(task=>task.id),
  });
  console.log('TASK27 CAMPAIGN CONTROL GOLD: '+cases.length+' actual query/selection cases');
}finally{runtime.close();}
