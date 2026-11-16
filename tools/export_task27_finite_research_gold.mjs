import {createFrozenSourceRuntime,writeFrozenFixture} from './frozen_source_runtime.mjs';

const runtime=createFrozenSourceRuntime();
try {
  const engine=await runtime.load('engine');
  const content=await runtime.load('content');
  const campaign=await runtime.load('campaign');
  const cases=[];
  for(const definition of Object.values(content.TECHNOLOGIES)) {
    const id=definition.id;
    const deprecated=content.isDeprecatedTechnology(id);
    const stages=deprecated?['select','queue']:['half_cycle','first_payment','last_payment','starved','paused','unpowered',...(definition.prerequisites.length?['locked']:[])];
    for(const stage of stages) {
      let state=engine.createInitialState(240721,false);
      state.research.completedTechIds=Object.keys(content.TECHNOLOGIES).filter(t=>t!==id);
      state.campaign.completedTaskIds=campaign.CAMPAIGN_TASKS.map(task=>task.id);
      state.campaign.rewardedTaskIds=[...state.campaign.completedTaskIds];
      state.campaign.activeTaskId=null;
      if(stage==='locked') state.research.completedTechIds=state.research.completedTechIds.filter(t=>t!==definition.prerequisites[0]);
      state.construction.wind_turbine=4;
      state=engine.placeBuilding(state,'wind_turbine',{x:0,y:0},4);
      state.construction.matrix_lab=1;
      state=engine.placeBuilding(state,'matrix_lab',{x:200,y:0});
      const labId=state.entities.find(e=>e.buildingId==='matrix_lab').id;
      state=engine.setEntityRecipe(state,labId,'matrix_research');
      if(stage==='queue') {
        // An actual active eligible technology is needed to exercise queuing.
        state.research.completedTechIds=state.research.completedTechIds.filter(t=>t!=='basic_logistics');
        state=engine.selectTechnology(state,'basic_logistics');
      }
      const beforeSelection=structuredClone(state.research);
      state=engine.selectTechnology(state,id);
      const selection=structuredClone(state.research);
      const lab=state.entities.find(e=>e.id===labId);
      if(stage==='last_payment') {
        state.research.progressByTech[id]=Object.fromEntries(definition.costs.map(cost=>[cost.itemId,cost.amount-1]));
        for(const cost of definition.costs) lab.inputs[cost.itemId]=1;
      } else if(!deprecated&&stage!=='starved') {
        lab.inputs[definition.costs[0].itemId]=1;
      }
      if(stage==='paused') state=engine.pauseCurrentResearch(state);
      if(stage==='unpowered') state.entities=state.entities.filter(e=>e.buildingId!=='wind_turbine');
      const seconds=deprecated?0:stage==='half_cycle'?0.75:6*definition.costs.length;
      const input=structuredClone({research:state.research,subject:state.entities.find(e=>e.id===labId),construction:state.construction,colonized_planets:state.exploration.colonizedPlanetIds,campaign:state.campaign,wind_count:stage==='unpowered'?0:4,before_selection:beforeSelection,selection});
      const session=engine.createSimulationAdvanceSession(state,seconds);
      const after=engine.advanceSimulation(state,seconds);
      const repeated=engine.selectTechnology(after,id);
      cases.push({id,stage,seconds,phase_rounding_bound:Math.ceil(seconds/session.stepSize)*0.0000005+0.0000001,input,expected:{research:after.research,subject:after.entities.find(e=>e.id===labId),construction:after.construction,colonized_planets:after.exploration.colonizedPlanetIds,repeated_selection:repeated.research,repeated_construction:repeated.construction}});
    }
  }
  writeFrozenFixture(runtime,'task27-finite-research.json',{scope:'Actual frozen engine half-cycle phase, first and final finite research payments, full persisted cost boundary, prerequisites, stopped labs, real power, completion construction/colonization rewards and repeated selection. All other technologies, already claimed campaign tasks and final-boundary progress are fixture-funded. Campaign rewards are isolated from research rewards in both inputs. Seven deprecated technologies are retained but reject selection/queue. Not full-cost growth or a clean-game journey.',cases});
  console.log('TASK27 FINITE RESEARCH GOLD: '+cases.length+' actual engine cases for '+Object.keys(content.TECHNOLOGIES).length+' definitions');
} finally {runtime.close();}
