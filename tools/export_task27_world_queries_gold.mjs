import {createFrozenSourceRuntime,writeFrozenFixture} from './frozen_source_runtime.mjs';
const runtime=createFrozenSourceRuntime();
try{
  const engine=await runtime.load('engine');
  const content=await runtime.load('content');
  const galaxy=await runtime.load('galaxy');
  const cases=[];
  const items=Object.keys(content.ITEMS);
  const planets=content.PLANET_LIST.map(row=>row.id);
  const systems=content.STAR_SYSTEM_LIST.map(row=>row.id);
  const project=state=>structuredClone(Object.fromEntries(['galaxy','activePlanetId','tray','planetTrays','planetTrayItemLimits','portableFleet','research','exploration'].map(key=>[key,state[key]])));
  const finite=value=>Number.isFinite(value)?value:'Infinity';
  const record=(id,state)=>{
    const before=JSON.stringify(state);
    const capacityItems=id==='fresh-240721-false'||id.startsWith('tray-')?[...items,'unknown_item']:[...new Set(['iron_ore','logistics_drone','logistics_vessel','unknown_item',...Object.keys(state.tray),...Object.values(state.planetTrays).flatMap(tray=>Object.keys(tray))])];
    const expected={
      systems:[...systems,'unknown_system',''].map(id=>({id,unlocked:engine.isStarSystemUnlocked(state,id),canExplore:engine.canExploreStarSystem(state,id)})),
      planets:planets.map(id=>({
        id,colonized:engine.isPlanetColonized(state,id),canColonize:engine.canColonizePlanet(state,id),
        requirements:engine.getColonizationRequirements(state,id),
        trayLimit:engine.getPlanetTrayItemLimit(state,id),
        freeCapacity:capacityItems.map(itemId=>({itemId,value:finite(engine.getPlanetTrayItemFreeCapacity(state,id,itemId))})),
      })),
      activeTrayLimit:engine.getPlanetTrayItemLimit(state),
      unknownTrayLimit:engine.getPlanetTrayItemLimit(state,'unknown_planet'),
    };
    if(JSON.stringify(state)!==before)throw Error('Actual source world query mutated input '+id);
    cases.push({id,input:project(state),expected});
  };
  const initial=(seed=240721,baseline=false)=>engine.createInitialState(seed,baseline);
  const funded=(seed=240721,baseline=false)=>{
    const state=initial(seed,baseline);
    state.research.completedTechIds=Object.keys(content.TECHNOLOGIES);
    state.exploration={unlockedSystemIds:['helios'],colonizedPlanetIds:['home'],missions:[],surveyProgressBySystem:{helios:1}};
    state.tray={};
    state.planetTrays.home={};
    state.portableFleet={logistics_drone:0,logistics_vessel:0};
    return state;
  };
  for(const [seed,baseline] of [[240721,false],[42,false],[240721,true]]){
    const tag=seed+'-'+baseline;
    record('fresh-'+tag,initial(seed,baseline));
    record('technology-'+tag,funded(seed,baseline));
    const unlocked=funded(seed,baseline);
    unlocked.exploration.unlockedSystemIds=[...systems];
    record('unlocked-'+tag,unlocked);
    const allColonized=structuredClone(unlocked);
    allColonized.exploration.colonizedPlanetIds=[...planets];
    record('colonized-'+tag,allColonized);
    for(const planetId of planets){
      const profile=galaxy.getPlanetIndustrialProfile(unlocked,planetId);
      if(engine.isPlanetColonized(unlocked,planetId))continue;
      for(const stage of ['below','exact','overshoot','remote_only','fleet_missing']){
        const state=structuredClone(unlocked);
        state.tray={};
        state.portableFleet={logistics_drone:0,logistics_vessel:0};
        for(const cost of profile.colonyCost){
          const amount=cost.amount+(stage==='below'?-1:stage==='overshoot'?1:0);
          if(engine.isPortableFleetItem(cost.itemId)){
            state.portableFleet[cost.itemId]=stage==='fleet_missing'?0:amount;
          }else{
            state.tray[cost.itemId]=stage==='remote_only'?0:amount;
          }
        }
        state.planetTrays.home=structuredClone(state.tray);
        state.planetTrays.ashen=Object.fromEntries(profile.colonyCost.filter(cost=>!engine.isPortableFleetItem(cost.itemId)).map(cost=>[cost.itemId,cost.amount]));
        record('colony-'+planetId+'-'+stage+'-'+tag,state);
      }
    }
  }
  for(const systemId of systems.filter(id=>id!=='helios')){
    const definition=content.STAR_SYSTEMS[systemId];
    for(const stage of ['locked_technology','locked_prerequisite','materials_below','materials_exact','materials_epsilon','mission_running','already_unlocked']){
      const state=funded();
      if(stage==='locked_technology')state.research.completedTechIds=[];
      if(stage!=='locked_prerequisite'&&definition.prerequisiteSystemId&&!state.exploration.unlockedSystemIds.includes(definition.prerequisiteSystemId))state.exploration.unlockedSystemIds.push(definition.prerequisiteSystemId);
      state.tray=Object.fromEntries(definition.explorationCost.map(cost=>[cost.itemId,cost.amount-(stage==='materials_below'?1:stage==='materials_epsilon'?0.00005:0)]));
      state.planetTrays.home=structuredClone(state.tray);
      if(stage==='mission_running')state.exploration.missions=[{systemId,elapsedSeconds:0,durationSeconds:60}];
      if(stage==='already_unlocked')state.exploration.unlockedSystemIds.push(systemId);
      record('system-'+systemId+'-'+stage,state);
    }
  }
  for(const [id,limit] of [['minimum',1000],['maximum',100000000],['fractional',1000.9],['too_low',0],['too_high',100000001],['missing',null],['nonfinite','Infinity']]){
    const state=funded();
    if(limit===null)delete state.planetTrayItemLimits.home;
    else state.planetTrayItemLimits.home=limit==='Infinity'?Infinity:limit;
    state.tray={iron_ore:1000,copper_ore:1001,stone:3.9};
    state.planetTrays.home={iron_ore:1};
    state.planetTrays.ashen={iron_ore:15,copper_ore:100000001};
    record('tray-'+id,state);
    // JSON cannot carry nonfinite input. The runner restores this declared raw query probe.
    if(limit==='Infinity')cases.at(-1).input.planetTrayItemLimits.home='Infinity';
  }
  const statuses=[...new Set(cases.flatMap(row=>row.expected.planets.map(planet=>planet.requirements.status)))].sort();
  if(JSON.stringify(statuses)!==JSON.stringify(['colonized','materials','prerequisite-system','ready','system-locked','technology']))throw Error('Colonization status coverage incomplete '+statuses);
  writeFrozenFixture(runtime,'task27-world-queries.json',{
    scope:'Actual frozen read-only world/colonization and tray-capacity queries. All 22 worlds and 8 systems across three seeded/baseline galaxies; all 78 items in initial and seven tray probes, with both portable fleet types and all stocked items in other states. Controlled technology/unlock/pioneer/mission/material/fleet states, exact boundaries and local-versus-remote ownership. Raw fractional/out-of-range/nonfinite tray-limit probes test queries only and are not valid saves, colonization commands, physical exploration or full growth evidence. Infinity is explicitly tagged because JSON cannot encode it.',
    planets,systems,items,statuses,cases,
  });
  console.log('TASK27 WORLD QUERY GOLD: '+cases.length+' actual states, '+cases.length*planets.length+' world rows, '+cases.flatMap(row=>row.expected.planets).reduce((sum,row)=>sum+row.freeCapacity.length,0)+' free-capacity rows');
}finally{runtime.close();}
