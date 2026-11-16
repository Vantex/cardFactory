import {createFrozenSourceRuntime,writeFrozenFixture} from './frozen_source_runtime.mjs';

const runtime=createFrozenSourceRuntime();
try {
  const engine=await runtime.load('engine');
  const content=await runtime.load('content');
  const campaign=await runtime.load('campaign');
  const achievements=await runtime.load('progression');
  const storage=await runtime.load('storage');
  const matrices=['electromagnetic_matrix','energy_matrix','structure_matrix','information_matrix','gravity_matrix','universe_matrix'];
  const achievementMetrics={
    first_manual_mine:{kind:'manual-mined'},automated_mining:{kind:'miner'},first_logistics_line:{kind:'belt'},
    stable_power_grid:{kind:'power',requireGeneration:true},electromagnetic_matrix_online:{kind:'produced',itemId:'electromagnetic_matrix'},
    energy_matrix_online:{kind:'produced',itemId:'energy_matrix'},six_matrix_mastery:{kind:'matrix-spectrum'},
    planetary_logistics_online:{kind:'building',buildingId:'planetary_logistics_station'},
    interstellar_delivery:{kind:'station-trips',buildingId:'interstellar_logistics_station'},
    rare_resource_harvest:{kind:'rare-resource',excludeOrganic:true},dyson_swarm_online:{kind:'dyson',measure:'sails'},
    permanent_dyson_structure:{kind:'dyson',measure:'structure'},multi_system_industry:{kind:'industrial-systems'},
  };
  const taskStages=['zero','below','exact','overshoot','locked','completed_unrewarded','completed_rewarded','reward_capacity','reward_retry'];
  const achievementStages=['zero','below','exact','overshoot','already_unlocked'];
  const projection=state=>({
    manualMined:state.manualMined,totalProduced:state.totalProduced,
    entities:state.entities,belts:state.belts,planetMetrics:state.planetMetrics,
    research:state.research,exploration:state.exploration,blueprints:state.blueprints,
    dysonSwarm:state.dysonSwarm,dysonSphere:state.dysonSphere,dysonEngineering:state.dysonEngineering,endgame:state.endgame,
    campaign:state.campaign,achievements:state.achievements,
    activePlanetId:state.activePlanetId,tray:state.tray,planetTrays:state.planetTrays,
    planetTrayItemLimits:state.planetTrayItemLimits,construction:state.construction,
  });
  const outcome=state=>({
    campaign:state.campaign,achievements:state.achievements,tray:state.tray,
    construction:state.construction,progress:campaign.CAMPAIGN_TASKS.map(task=>({id:task.id,...campaign.getCampaignTaskProgress(state,task)})),
    achievementProgress:achievements.ACHIEVEMENTS.map(row=>({id:row.id,current:achievements.getAchievementProgress(state,row)})),
  });
  const empty=()=>{
    const state=engine.createInitialState(240721,false);
    state.manualMined=0;state.totalProduced={};state.belts=[];
    state.entities=state.entities.filter(entity=>entity.kind==='vein');
    state.tray={};state.planetTrays.home={};state.construction={};
    return state;
  };
  const placed=(state,buildingId,count=1,planetId='home')=>{
    const saved=state.research.completedTechIds;
    state.research.completedTechIds=Object.keys(content.TECHNOLOGIES);
    state.construction[buildingId]=count;
    state.activePlanetId=planetId;
    state.exploration.colonizedPlanetIds=[...new Set([...state.exploration.colonizedPlanetIds,planetId])];
    state.exploration.unlockedSystemIds=[...new Set([...state.exploration.unlockedSystemIds,content.getPlanet(planetId).systemId])];
    state.exploration.surveyProgressBySystem[content.getPlanet(planetId).systemId]=1;
    const next=engine.placeBuilding(state,buildingId,{x:200+state.nextId*180,y:0},count);
    if(next===state)throw new Error('Actual source placement rejected '+buildingId+' '+planetId);
    next.research.completedTechIds=saved;
    next.construction={};
    next.activePlanetId='home';
    next.tray=next.planetTrays.home;
    return next;
  };
  const metricInput=(original,metric,amount)=>{
    let state=original;
    const integer=Math.max(0,Math.floor(amount));
    switch(metric.kind){
      case 'manual-mined':state.manualMined=integer;break;
      case 'produced':state.totalProduced[metric.itemId]=amount;break;
      case 'building':if(integer)state=placed(state,metric.buildingId,integer);break;
      case 'miner':{
        if(!integer)break;
        const vein=state.entities.find(entity=>entity.resourceId==='iron_ore');
        state.construction.mining_machine=integer;
        const next=engine.installMiner(state,vein.id,integer);
        if(next===state)throw new Error('Actual source miner rejected');
        state=next;state.construction={};break;
      }
      case 'belt':{
        for(let index=0;index<integer;index++){
          state=placed(state,'arc_smelter');
          const from=state.entities.findLast(entity=>entity.buildingId==='arc_smelter');
          state=placed(state,'assembling_machine_mk1');
          const to=state.entities.findLast(entity=>entity.buildingId==='assembling_machine_mk1');
          const tier=metric.minimumTier??1;
          if(tier===2)engine.completeTechnology(state,'basic_logistics');
          state.construction['conveyor_belt_mk'+tier]=1;
          const next=engine.connectBelt(state,from.id,to.id,'iron_ingot',tier);
          if(next===state)throw new Error('Actual source belt rejected');
          state=next;state.construction={};
        }
        break;
      }
      case 'research':if(integer)state.research.completedTechIds.push(metric.techId);break;
      case 'exploration':if(integer){state.exploration.unlockedSystemIds.push(metric.systemId);state.exploration.surveyProgressBySystem[metric.systemId]=1;}break;
      case 'station-trips':{
        if(!integer)break;
        state=placed(state,metric.buildingId);
        state.entities.find(entity=>entity.buildingId===metric.buildingId).stationTrips=integer;
        break;
      }
      case 'dyson':{
        if(metric.measure==='sails'){state.dysonSwarm.totalLaunched=integer;state.dysonSwarm.sailsInOrbit=integer;}
        if(metric.measure==='rockets'||metric.measure==='structure'){state.dysonSphere.totalRocketsLaunched=integer;state.dysonSphere.structurePoints=integer;}
        if(metric.measure==='shell'&&integer){state.dysonSphere.totalRocketsLaunched=1;state.dysonSphere.structurePoints=1;state.dysonSwarm.totalLaunched=integer;state.dysonSphere.shellSails=integer;state.dysonSphere.totalSailsAbsorbed=integer;}
        const orbit=state.dysonEngineering.orbitsBySystem.helios[0];
        orbit.sailsInOrbit=state.dysonSwarm.sailsInOrbit;
        orbit.totalLaunched=state.dysonSwarm.totalLaunched;
        orbit.totalExpired=state.dysonSwarm.totalExpired;
        break;
      }
      case 'power':{
        if(integer)state=placed(state,'wind_turbine');
        state.planetMetrics.home={...state.planetMetrics.home,demandKw:integer?10:0,generationKw:integer?10:0,powerFactor:integer?1:0};
        break;
      }
      case 'rare-resource':state.totalProduced.fire_ice=amount;break;
      case 'spray-coater':if(integer){
        state=placed(state,'assembling_machine_mk1');
        engine.completeTechnology(state,'proliferator_1');
        state.construction.spray_coater=1;
        const entity=state.entities.find(row=>row.buildingId==='assembling_machine_mk1');
        const next=engine.installSprayCoater(state,entity.id);
        if(next===state)throw new Error('Actual source spray installation rejected');
        state=next;state.construction={};
      }break;
      case 'blueprint':{
        if(!integer)break;
        state=placed(state,'wind_turbine');
        const entity=state.entities.find(entity=>entity.buildingId==='wind_turbine');
        for(let index=0;index<integer;index++){
          const next=engine.createBlueprint(state,[entity.id],'Metric blueprint '+index);
          if(next===state)throw new Error('Actual source blueprint rejected');
          state=next;
        }
        break;
      }
      case 'infinite-research':state.endgame.infiniteResearch.matrix_compression.level=integer;break;
      case 'exported':state.endgame.totalExported=amount;break;
      case 'galactic-score':state.endgame.galacticScore=amount;break;
      case 'endgame-mastery':for(const project of Object.values(state.endgame.exportProjects))project.level=integer?1:0;break;
      case 'matrix-spectrum':for(const item of matrices.slice(0,integer))state.totalProduced[item]=1;break;
      case 'industrial-systems':{
        if(integer)state=placed(state,'wind_turbine');
        if(integer>=2)state=placed(state,'wind_turbine',1,'frost');
        break;
      }
      default:throw new Error('Unhandled actual source metric '+metric.kind);
    }
    return state;
  };
  const cases=[];
  const rewardStates=new Map();
  const record=(category,row,stage,metric,state)=>{
    const input=structuredClone(projection(state));
    const before=JSON.stringify(state);
    const progress=category==='campaign'?campaign.getCampaignTaskProgress(state,row):{current:achievements.getAchievementProgress(state,row),target:row.target,complete:achievements.getAchievementProgress(state,row)>=row.target};
    const synchronized=campaign.syncCampaignProgress(state);
    const unlocked=achievements.unlockAchievements(synchronized);
    if(JSON.stringify(state)!==before)throw new Error('Actual immutable progression changed input');
    const repeated=achievements.unlockAchievements(campaign.syncCampaignProgress(unlocked.state));
    cases.push({category,id:row.id,stage,metric,input,progress,expected:outcome(unlocked.state),new_achievements:unlocked.unlockedIds,repeated:outcome(repeated.state),repeated_new_achievements:repeated.unlockedIds,loaded_after:outcome(storage.migrateGame(structuredClone(unlocked.state)))});
  };
  for(const row of campaign.CAMPAIGN_TASKS){
    const target=Math.max(1,row.metric.target??1);
    for(const stage of taskStages){
      let state=empty();
      state.campaign.completedTaskIds=campaign.CAMPAIGN_TASKS.filter(task=>task.id!==row.id).map(task=>task.id);
      state.campaign.rewardedTaskIds=[...state.campaign.completedTaskIds];
      state.campaign.activeTaskId=row.id;state.campaign.activeChapterId=row.chapterId;
      state.achievements.unlockedIds=achievements.ACHIEVEMENTS.map(item=>item.id);
      const amount=stage==='zero'||stage==='completed_unrewarded'?0:stage==='below'?Math.max(0,target-.25):stage==='overshoot'?target+2:target;
      state=metricInput(state,row.metric,amount);
      if(stage==='locked'){
        state.campaign.completedTaskIds=state.campaign.completedTaskIds.filter(id=>!(row.prerequisites??[]).includes(id));
        state.campaign.rewardedTaskIds=state.campaign.rewardedTaskIds.filter(id=>!(row.prerequisites??[]).includes(id));
      }
      if(stage==='completed_unrewarded'||stage==='completed_rewarded')state.campaign.completedTaskIds.push(row.id);
      if(stage==='completed_rewarded')state.campaign.rewardedTaskIds.push(row.id);
      if(stage==='reward_capacity'||stage==='reward_retry'){
        for(const reward of row.rewards??[]){
          if(reward.itemId){state.planetTrayItemLimits.home=1000;state.tray[reward.itemId]=1000-(stage==='reward_retry'?reward.amount:0);}
          if(reward.constructionId)state.construction[reward.constructionId]=engine.getConstructionAutomationStockLimit(state)-(stage==='reward_retry'?reward.amount:0);
        }
        state.planetTrays.home={...state.tray};
      }
      if(stage==='reward_capacity'&&(row.rewards??[]).some(reward=>reward.itemId))rewardStates.set(row.id,structuredClone(state));
      record('campaign',row,stage,row.metric,state);
    }
  }
  for(const row of achievements.ACHIEVEMENTS){
    for(const stage of achievementStages){
      let state=empty();
      state.campaign.completedTaskIds=campaign.CAMPAIGN_TASKS.map(task=>task.id);
      state.campaign.rewardedTaskIds=[...state.campaign.completedTaskIds];
      state.campaign.activeTaskId=null;
      state.achievements.unlockedIds=achievements.ACHIEVEMENTS.filter(item=>item.id!==row.id).map(item=>item.id);
      const amount=stage==='zero'?0:stage==='below'?Math.max(0,row.target-.25):stage==='overshoot'?row.target+2:row.target;
      state=metricInput(state,achievementMetrics[row.id],amount);
      if(stage==='already_unlocked')state.achievements.unlockedIds.push(row.id);
      record('achievements',row,stage,achievementMetrics[row.id],state);
    }
  }
  const reward_resume_cases=[];
  for(const row of campaign.CAMPAIGN_TASKS.filter(task=>rewardStates.has(task.id))){
    const state=rewardStates.get(row.id);
    const input=structuredClone(projection(state));
    const original=JSON.stringify(state);
    const blocked=achievements.unlockAchievements(campaign.syncCampaignProgress(state));
    if(JSON.stringify(state)!==original||!blocked.state.campaign.completedTaskIds.includes(row.id)||blocked.state.campaign.rewardedTaskIds.includes(row.id))throw new Error('Actual blocked reward precondition failed '+row.id);
    const loaded=storage.migrateGame(structuredClone(blocked.state));
    const release_requests=row.rewards.filter(reward=>reward.itemId).map(reward=>({itemId:reward.itemId,amount:reward.amount}));
    const loadedBefore=JSON.stringify(loaded);
    const released=engine.discardPlanetTrayItems(loaded,loaded.activePlanetId,release_requests);
    if(released===loaded||JSON.stringify(loaded)!==loadedBefore)throw new Error('Actual immutable source tray release failed '+row.id);
    const paid=achievements.unlockAchievements(campaign.syncCampaignProgress(released));
    if(!paid.state.campaign.rewardedTaskIds.includes(row.id))throw new Error('Actual pending reward failed to resume '+row.id);
    const repeated=achievements.unlockAchievements(campaign.syncCampaignProgress(paid.state));
    const reopened=storage.migrateGame(structuredClone(paid.state));
    const reopenedRepeated=achievements.unlockAchievements(campaign.syncCampaignProgress(reopened));
    reward_resume_cases.push({id:row.id,input,release_requests,blocked:outcome(blocked.state),loaded_blocked:outcome(loaded),released:outcome(released),expected:outcome(paid.state),new_achievements:paid.unlockedIds,repeated:outcome(repeated.state),repeated_new_achievements:repeated.unlockedIds,loaded_after:outcome(reopened),reopened_repeated:outcome(reopenedRepeated.state),reopened_new_achievements:reopenedRepeated.unlockedIds});
  }
  writeFrozenFixture(runtime,'task27-progression.json',{
    scope:'Actual full source campaign and achievement APIs, 32 tasks and 13 achievements. Nine/five controlled metric and reward states; actual placement, miner, belt, spray and blueprint APIs where applicable; funded other completion records isolate the selected target. Power uses controlled persisted planet metrics; Dyson global and orbit ledgers are consistent. Reward capacity cases use the actual 100-construction automation target and 1000-item tray limit, without assuming that automation targets cap rewards. reward_retry covers an initially available slot. Six additional reward_resume_cases actually settle a full tray as completed/unrewarded, migrate storage, discard through the source API, repay once, repeat, reload and repeat again. These are local rule boundaries, not full growth or physical simulation. All source expectations, repeated settlement and storage migrations are executed afresh.',
    task_stages:taskStages,achievement_stages:achievementStages,cases,reward_resume_cases,
  });
  console.log('TASK27 PROGRESSION GOLD: '+cases.length+' boundaries + '+reward_resume_cases.length+' actual blocked/load/discard/repay sequences for 32 tasks and 13 achievements');
}finally{runtime.close();}
