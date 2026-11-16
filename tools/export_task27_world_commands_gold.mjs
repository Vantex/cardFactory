import {createFrozenSourceRuntime,writeFrozenFixture} from './frozen_source_runtime.mjs';
const runtime=createFrozenSourceRuntime();
try {
  const engine=await runtime.load('engine');
  const content=await runtime.load('content');
  const galaxy=await runtime.load('galaxy');
  const storage=await runtime.load('storage');
  const planets=content.PLANET_LIST.map(row=>row.id);
  const systems=content.STAR_SYSTEM_LIST.map(row=>row.id);
  const cases=[];
  const project=state=>structuredClone({galaxy:state.galaxy,activePlanetId:state.activePlanetId,tray:state.tray,planetTrays:state.planetTrays,portableFleet:state.portableFleet,planetMetrics:state.planetMetrics,research:state.research,exploration:state.exploration,logicalColonized:planets.filter(id=>engine.isPlanetColonized(state,id))});
  const domain=state=>structuredClone({activePlanetId:state.activePlanetId,tray:state.tray,planetTrays:state.planetTrays,portableFleet:state.portableFleet,activeMetrics:state.metrics,exploration:state.exploration,logicalColonized:planets.filter(id=>engine.isPlanetColonized(state,id))});
  const invoke=(state,command)=>({explore:engine.exploreStarSystem,colonize:engine.colonizePlanet,active:engine.setActivePlanet}[command.kind])(state,command.target);
  const fresh=(seed,baseline)=>engine.createInitialState(seed,baseline);
  const funded=(seed,baseline)=>{
    const state=fresh(seed,baseline);
    state.research.completedTechIds=Object.keys(content.TECHNOLOGIES);
    state.exploration={unlockedSystemIds:['helios'],colonizedPlanetIds:['home'],missions:[],surveyProgressBySystem:{helios:1}};
    state.tray={iron_ore:17,copper_ore:23};
    state.planetTrays.home=structuredClone(state.tray);
    state.portableFleet={logistics_drone:7,logistics_vessel:11};
    return state;
  };
  const record=(id,state,command)=>{
    const original=JSON.stringify(state);
    const next=invoke(state,command);
    const repeated=invoke(next,command);
    if(JSON.stringify(state)!==original)throw Error('Immutable world command changed input '+id);
    const loaded=storage.migrateGame(structuredClone(next));
    cases.push({id,command,input:project(state),expected:domain(next),repeated:domain(repeated),loaded_after:domain(loaded)});
  };
  const prerequisites=(state,id)=>{
    const prerequisite=content.STAR_SYSTEMS[id].prerequisiteSystemId;
    if(prerequisite){prerequisites(state,prerequisite);if(!state.exploration.unlockedSystemIds.includes(prerequisite))state.exploration.unlockedSystemIds.push(prerequisite);state.exploration.surveyProgressBySystem[prerequisite]=1;}
  };
  for(const [seed,baseline] of [[240721,false],[42,false],[240721,true]]){
    const tag=seed+'-'+baseline;
    for(const systemId of systems.filter(id=>id!=='helios'))for(const stage of ['technology','prerequisite','below','exact','overshoot','already_unlocked','mission_running']){
      const state=funded(seed,baseline);
      const definition=content.STAR_SYSTEMS[systemId];
      if(stage!=='prerequisite')prerequisites(state,systemId);
      if(stage==='technology')state.research.completedTechIds=[];
      state.tray=Object.fromEntries(definition.explorationCost.map(cost=>[cost.itemId,cost.amount+(stage==='below'?-1:stage==='overshoot'?1:0)]));
      state.planetTrays.home=structuredClone(state.tray);
      if(stage==='already_unlocked'){state.exploration.unlockedSystemIds.push(systemId);state.exploration.surveyProgressBySystem[systemId]=1;}
      if(stage==='mission_running'){
        const duration=Math.max(...definition.planetIds.map(id=>galaxy.getPlanetIndustrialProfile(state,id).surveyDurationSeconds));
        if(duration>0){state.exploration.unlockedSystemIds.push(systemId);state.exploration.missions.push({systemId,elapsedSeconds:duration/2,durationSeconds:duration});state.exploration.surveyProgressBySystem[systemId]=0.5;}
      }
      record('explore-'+systemId+'-'+stage+'-'+tag,state,{kind:'explore',target:systemId});
    }
    for(const planetId of planets)for(const stage of ['locked','ready','below','remote_only','fleet_missing','already_colonized']){
      const state=funded(seed,baseline);
      if(stage==='locked')state.research.completedTechIds=[];
      else {state.exploration.unlockedSystemIds=[...systems];state.exploration.surveyProgressBySystem=Object.fromEntries(systems.map(id=>[id,1]));}
      const profile=galaxy.getPlanetIndustrialProfile(state,planetId);
      state.tray={iron_ore:17};
      state.portableFleet={logistics_drone:7,logistics_vessel:11};
      for(const cost of profile.colonyCost){
        const amount=Math.max(0,cost.amount+(stage==='below'?-1:0));
        if(engine.isPortableFleetItem(cost.itemId))state.portableFleet[cost.itemId]=stage==='fleet_missing'?0:amount;
        else state.tray[cost.itemId]=stage==='remote_only'?0:amount;
      }
      state.planetTrays.home=structuredClone(state.tray);
      state.planetTrays.ashen=Object.fromEntries(profile.colonyCost.filter(cost=>!engine.isPortableFleetItem(cost.itemId)).map(cost=>[cost.itemId,cost.amount]));
      if(stage==='already_colonized'&&!state.exploration.colonizedPlanetIds.includes(planetId))state.exploration.colonizedPlanetIds.push(planetId);
      record('colonize-'+planetId+'-'+stage+'-'+tag,state,{kind:'colonize',target:planetId});
    }
    for(const planetId of planets)for(const stage of ['locked','not_colonized','computed','explicit','already_active']){
      const state=funded(seed,baseline);
      planets.forEach((id,index)=>{state.planetMetrics[id]={...state.planetMetrics[id],generationKw:17+index,demandKw:34+index,powerFactor:0.5,totalItemsPerMinute:index*3};});
      state.metrics=structuredClone(state.planetMetrics.home);
      if(stage!=='locked'){state.exploration.unlockedSystemIds=[...systems];state.exploration.surveyProgressBySystem=Object.fromEntries(systems.map(id=>[id,1]));}
      if(stage==='not_colonized')state.research.completedTechIds=[];
      if(['explicit','already_active'].includes(stage)&&!state.exploration.colonizedPlanetIds.includes(planetId))state.exploration.colonizedPlanetIds.push(planetId);
      state.planetTrays[planetId]={copper_ore:41};
      if(stage==='already_active'){state.activePlanetId=planetId;state.tray=structuredClone(state.planetTrays[planetId]);state.metrics=structuredClone(state.planetMetrics[planetId]);}
      record('active-'+planetId+'-'+stage+'-'+tag,state,{kind:'active',target:planetId});
    }
    record('active-unknown-'+tag,fresh(seed,baseline),{kind:'active',target:'unknown_planet'});
    record('explore-unknown-'+tag,fresh(seed,baseline),{kind:'explore',target:'unknown_system'});
  }
  const surveys=[];
  for(const [seed,baseline] of [[240721,false],[42,false],[240721,true]])for(const systemId of systems.filter(id=>id!=='helios')){
    const started=funded(seed,baseline);
    prerequisites(started,systemId);
    started.tray=Object.fromEntries(content.STAR_SYSTEMS[systemId].explorationCost.map(cost=>[cost.itemId,cost.amount]));
    started.planetTrays.home=structuredClone(started.tray);
    const unlocked=engine.exploreStarSystem(started,systemId);
    const duration=unlocked.exploration.missions.find(mission=>mission.systemId===systemId)?.durationSeconds;
    if(!(duration>0))throw Error('Survey duration fixture missing '+systemId);
    for(const stage of ['zero','half','round_fraction','eps_before','eps_complete','exact','overshoot','sixty_hz']){
      const state=structuredClone(unlocked);
      const mission=state.exploration.missions.find(value=>value.systemId===systemId);
      let seconds=1/60, steps=1;
      if(stage==='zero')seconds=0;
      else if(stage==='half')seconds=duration/2;
      else if(stage==='round_fraction')mission.elapsedSeconds=duration*0.12345;
      else if(stage==='eps_before')mission.elapsedSeconds=duration*0.99989-1/60;
      else if(stage==='eps_complete')mission.elapsedSeconds=duration*0.99991-1/60;
      else if(stage==='exact'||stage==='overshoot'){mission.elapsedSeconds=duration-1/60;seconds=stage==='overshoot'?1:1/60;}
      else if(stage==='sixty_hz')steps=9;
      state.exploration.surveyProgressBySystem[systemId]=Math.round(mission.elapsedSeconds/duration*10000)/10000;
      const original=JSON.stringify(state);
      let next=state;
      const trace=[];
      for(let index=0;index<steps;index++){
        next=engine.advanceSimulation(next,seconds);
        trace.push(domain(next));
      }
      if(JSON.stringify(state)!==original)throw Error('Immutable source survey changed input');
      surveys.push({id:`survey-${systemId}-${stage}-${seed}-${baseline}`,systemId,stage,seconds,clock:seconds===1/60?{numerator:1,denominator:60}:null,steps,input:project(state),trace,loaded_after:domain(storage.migrateGame(structuredClone(next)))});
    }
  }
  writeFrozenFixture(runtime,'task27-world-commands.json',{
    scope:'Actual immutable frozen exploration, colonization and active-planet commands, repeats and source storage migration across three seeded/baseline galaxies. Payments use controlled nonnegative integral inventory/fleet; raw query-only fractional/EPS debt probes are excluded. Raw source explicit-colony arrays are inputs; logical ownership uses the actual source predicate. Local bindings materialize only when a command requires them, preserving existing records. Empty stock entries, computed colony arrays and absent zero survey keys are explicit representation adapters. Active metrics are a target-world lookup in CardFactory, instead of a duplicated global cache. Raw source storage removes unlocked background surveys; its original result remains in loaded_after, while local saves intentionally retain pending work and exact progress under the existing resume contract. Only stored inventory and computed availability are equated with source storage, never its survey queues/progress. Controlled actual source simulation survey traces isolate zero, half, rounding, EPS completion, overshoot and 60 Hz boundaries; they are not full factory simulation parity or a paid growth journey. Five 60 Hz stages declare the exact rational clock 1/60 alongside the original decimal seconds. The consumer restores this exact step after validating decimal agreement, because Godot JSON parsing slightly rounds that decimal; zero/half/overshoot use their original seconds without a rational-clock override. Source inputs, outputs and payment rules remain unchanged.',
    planets,systems,seeds:[[240721,false],[42,false],[240721,true]],cases,surveys,
  });
  console.log('TASK27 WORLD COMMAND GOLD: '+cases.length+' actual immutable commands; '+surveys.length+' actual source simulation survey traces');
} finally {runtime.close();}
