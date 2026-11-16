import fs from 'node:fs';
import path from 'node:path';
import assert from 'node:assert/strict';
import {createFrozenSourceRuntime,writeFrozenFixture} from './frozen_source_runtime.mjs';

const runtime=createFrozenSourceRuntime();
try {
 const engine=await runtime.load('engine');
 const content=await runtime.load('content');
 const finite=['logistics_engine_1','logistics_engine_2','logistics_capacity_1','logistics_capacity_2'];
 const profiles=[{mask:0,level:0},{mask:1,level:0},{mask:2,level:0},{mask:3,level:0},{mask:4,level:0},{mask:8,level:1},{mask:15,level:10},{mask:15,level:1000}];
 const seeds=[{seed:240721,baseline:false},{seed:42,baseline:false},{seed:240721,baseline:true}];
 const difficulties=['relaxed','standard','hard'];
 const planetIds=content.PLANET_LIST.map(row=>row.id);
 const systemIds=content.STAR_SYSTEM_LIST.map(row=>row.id);
 const firstPlanet=Object.fromEntries(content.STAR_SYSTEM_LIST.map(row=>[row.id,row.planetIds[0]]));
 const remote=firstPlanet[systemIds.at(-1)];
 const scenarios=planetIds.map((target,index)=>({id:'planet-'+target,target,policy:'relay-preferred',budget:2,vessels:1+(index%3),stack:1+(index%2),hubs:'none'}));
 for(const policy of ['direct','relay-preferred','relay-required'])for(const budget of [1,2,3,4])scenarios.push({id:`policy-${policy}-${budget}`,target:remote,policy,budget,vessels:3,stack:2,hubs:'all'});
 for(const hubs of ['disabled','locked','priority','tie','mode-transition','elevator'])scenarios.push({id:'hubs-'+hubs,target:remote,policy:'relay-required',budget:4,vessels:2,stack:1,hubs});
 for(const vessels of [0,1,7,100])scenarios.push({id:'vessels-'+vessels,target:remote,policy:'direct',budget:1,vessels,stack:3,hubs:'none'});
 const cases=[];
 for(const seed of seeds)for(const difficulty of difficulties)for(const profile of profiles)for(const scenario of scenarios){
  let state=engine.createInitialState(seed.seed,seed.baseline);
  state.settings.difficulty=difficulty;
  state.exploration.unlockedSystemIds=[...systemIds];
  state.exploration.surveyProgressBySystem=Object.fromEntries(systemIds.map(id=>[id,1]));
  state.exploration.colonizedPlanetIds=[...planetIds];
  state.research.completedTechIds=Object.keys(content.TECHNOLOGIES);
  state.construction.interstellar_logistics_station=1000;
  const station=(planet,count,position)=>{
   // Gas planets are still valid query inputs; place the funded piece on home before controlled relocation.
   const placementPlanet=engine.canPlaceBuildingOnPlanet('interstellar_logistics_station',planet,state)?planet:'home';
   state.activePlanetId=placementPlanet;
   const before=state.entities.length;
   state=engine.placeBuilding(state,'interstellar_logistics_station',position,count);
   assert.equal(state.entities.length,before+1,'Controlled source station actually placed: '+scenario.id+'/'+planet);
   state.entities.at(-1).planetId=planet;
   return state.entities.at(-1).id;
  };
  const sourceId=station('home',scenario.stack,{x:0,y:0});
  const targetId=station(scenario.target,scenario.stack,{x:500,y:0});
  if(scenario.hubs!=='none')for(const system of systemIds){
   if(['helios',content.getPlanet(scenario.target).systemId].includes(system))continue;
   const id=station(firstPlanet[system],1,{x:1000,y:0});
   state=engine.setStationHubConfiguration(state,id,scenario.hubs!=='disabled',1);
   const hub=state.entities.find(row=>row.id===id);
   if(scenario.hubs==='locked')state.exploration.unlockedSystemIds=state.exploration.unlockedSystemIds.filter(value=>value!==system);
   if(scenario.hubs==='mode-transition'){hub.stationTier=2;hub.stationModeTransition='to-elevator';}
   if(scenario.hubs==='elevator'){hub.stationTier=2;hub.stationOperationMode='elevator';}
   if(['priority','tie'].includes(scenario.hubs)){
    const other=station(firstPlanet[system],2,{x:1500,y:0});
    state=engine.setStationHubConfiguration(state,other,true,scenario.hubs==='priority'?2:1);
   }
  }
  state.research.completedTechIds=finite.filter((_id,index)=>profile.mask&(1<<index));
  state.endgame.infiniteResearch.galactic_logistics={level:profile.level,progress:'0'};
  const source=state.entities.find(row=>row.id===sourceId);
  const target=state.entities.find(row=>row.id===targetId);
  const options={routePolicy:scenario.policy,warperBudget:scenario.budget};
  const before=JSON.stringify(state);
  const expected={getInterstellarTripSeconds:{normal:engine.getInterstellarTripSeconds(state,false),warp:engine.getInterstellarTripSeconds(state,true)},getInterstellarRouteEconomics:engine.getInterstellarRouteEconomics(state,source,target,scenario.vessels,options)};
  assert.deepEqual(engine.getInterstellarRouteEconomics(state,source,target,scenario.vessels,options),expected.getInterstellarRouteEconomics,'Repeated source route query changed result');
  assert.equal(JSON.stringify(state),before,'Source route query changed raw state');
  cases.push({id:`${seed.seed}-${seed.baseline}-${difficulty}-${profile.mask}-${profile.level}-${scenario.id}`,input:{seed:seed.seed,baseline:seed.baseline,difficulty,completed:state.research.completedTechIds,level:profile.level,unlocked:state.exploration.unlockedSystemIds,source_id:sourceId,target_id:targetId,vessels:scenario.vessels,options,stations:state.entities.filter(row=>row.buildingId==='interstellar_logistics_station').map(row=>({id:row.id,planet:row.planetId,count:row.machineCount,tier:row.stationTier,hub_enabled:row.stationHubEnabled,hub_priority:row.stationHubPriority,operation_mode:row.stationOperationMode,mode_transition:row.stationModeTransition}))},expected});
 }
 const output={scope:'Actual controlled read-only interstellar trip/route economics queries: every source planet, generated and baseline environments, three difficulties, independent finite logistics effects, integer infinite boundaries, direct/preferred/required relay policies, budgets1..4, hub priority/ties/unlocked state and integer vessel counts. Station pieces are separately funded and actually placed; gas-planet inputs relocate a paid home piece solely for the query. This is not a placement, earned-growth, dispatched route, throughput or legal-save claim. Source mode-transition/elevator hub handling is captured without adapting source outputs.',functions:['getInterstellarTripSeconds','getInterstellarRouteEconomics'],finite,profiles,seeds,difficulties,scenarios,cases};
 const index=process.argv.indexOf('--output');
 if(index!==-1){
  assert.ok(process.argv[index+1],'Output path required');
  assert.deepEqual(runtime.unregisteredFiles(),[],'Keep current frozen catalog unchanged');
  const destination=path.resolve(process.argv[index+1]);
  const staging=path.resolve(import.meta.dirname,'../.godot');
  assert.ok(destination.startsWith(staging+path.sep),'Preparation output stays in ignored staging');
  fs.mkdirSync(path.dirname(destination),{recursive:true});
  fs.writeFileSync(destination,JSON.stringify({source_commit:runtime.commit,source_files:runtime.files,source_environment:{DEV:false,PROD:true,MODE:'production'},...output},null,2)+'\n');
 }else writeFrozenFixture(runtime,'task27-route-queries.json',output);
 console.log(`TASK27 ROUTE QUERY GOLD: ${cases.length} controlled states; ${scenarios.length} route scenarios; ${Object.keys(runtime.files).length} actual frozen modules`);
}finally{runtime.close();}
