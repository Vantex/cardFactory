import {createFrozenSourceRuntime,writeFrozenFixture} from './frozen_source_runtime.mjs';

const runtime = createFrozenSourceRuntime();
try {
  const engine = await runtime.load('engine');
  const content = await runtime.load('content');
  const cases = [];
  for (const id of ['matrix_research','solar_sail_launch','carrier_rocket_launch','ray_power','critical_photon','accumulator_charge','accumulator_discharge']) {
    const recipe = content.getRecipe(id);
    let state = engine.createInitialState(240721,false);
    state.research.completedTechIds = Object.keys(content.TECHNOLOGIES).filter(t=>id!=='matrix_research'||t!=='basic_logistics');
    const systemId = content.getPlanet('home').systemId;
    const winds = id==='accumulator_discharge' ? 0 : 200;
    if (winds) {
      state.construction.wind_turbine = winds;
      state = engine.placeBuilding(state,'wind_turbine',{x:0,y:0},winds);
    }
    state.construction[recipe.buildingId] = 1;
    state = engine.placeBuilding(state,recipe.buildingId,{x:200,y:0});
    const subject = state.entities.find(e=>e.buildingId===recipe.buildingId);
    if (!subject) throw new Error('Could not place special subject: '+id);
    state = id==='accumulator_discharge' ? engine.setEnergyMode(state,subject.id,'discharge') : engine.setEntityRecipe(state,subject.id,id);
    const configured = state.entities.find(e=>e.id===subject.id);
    for (const material of recipe.inputs) configured.inputs[material.itemId]=material.amount*3;
    if (id==='matrix_research') {
      configured.inputs.electromagnetic_matrix=6;
      state=engine.selectTechnology(state,'basic_logistics');
      if (state.research.selectedTechId!=='basic_logistics') throw new Error('Research fixture did not select actual technology');
    }
    if (id==='carrier_rocket_launch') {
      state=engine.createStandardDysonLayer(state,systemId,3);
      if (!state.dysonPlans[systemId].layers.length) throw new Error('Actual source rocket plan was not created');
    }
    if (id==='ray_power'||id==='critical_photon') state.dysonPlans[systemId].structurePoints=100;
    let consumer=null;
    if (id==='accumulator_discharge') {
      state.construction.arc_smelter=200;
      state=engine.placeBuilding(state,'arc_smelter',{x:400,y:0},200);
      const sink=state.entities.find(e=>e.buildingId==='arc_smelter');
      sink.inputs.iron_ore=600;
      consumer=structuredClone(sink);
    }
    const stages=['powered','starved'];
    if(id!=='ray_power') stages.push('blocked');
    if(recipe.requiredTechId) stages.push('locked');
    if(['matrix_research','solar_sail_launch','carrier_rocket_launch'].includes(id)) stages.push('unpowered');
    if(id==='accumulator_charge'||id==='accumulator_discharge') stages.push('cycle_boundary','partial_cell','near_full','negligible_cell','output_epsilon','epsilon_completion','fractional_input','fractional_output');
    if(id==='critical_photon') stages.push('near_full','output_epsilon','epsilon_completion','fractional_output');
    for(const stage of stages) {
      let scenario=structuredClone(state);
      const machine=scenario.entities.find(e=>e.id===subject.id);
      if(stage==='starved') {
        if(id==='ray_power'||id==='critical_photon') scenario.dysonPlans[systemId].structurePoints=0;
        else machine.inputs={};
      }
      if(stage==='blocked') {
        if(id==='matrix_research') scenario=engine.pauseCurrentResearch(scenario);
        else if(id==='solar_sail_launch'||id==='carrier_rocket_launch') scenario=engine.setDysonLaunchEnabled(scenario,false);
        else for(const output of recipe.outputs) machine.outputs[output.itemId]=content.getBuilding(recipe.buildingId).outputCapacity;
      }
      if(stage==='locked') scenario.research.completedTechIds=scenario.research.completedTechIds.filter(t=>t!==recipe.requiredTechId);
      if(stage==='unpowered') scenario.entities=scenario.entities.filter(e=>e.buildingId!=='wind_turbine');
      if(stage==='partial_cell') machine.storedEnergyMj=30;
      if(stage==='near_full') for(const output of recipe.outputs) machine.outputs[output.itemId]=content.getBuilding(recipe.buildingId).outputCapacity-0.5;
      if(stage==='output_epsilon'||stage==='epsilon_completion') for(const output of recipe.outputs) machine.outputs[output.itemId]=content.getBuilding(recipe.buildingId).outputCapacity-1+0.00005;
      if(stage==='fractional_input') for(const input of recipe.inputs) machine.inputs[input.itemId]=3.5;
      if(stage==='fractional_output') for(const output of recipe.outputs) machine.outputs[output.itemId]=0.5;
      let peer=null;
      if(id==='critical_photon'&&stage==='near_full') {
        scenario.dysonPlans[systemId].structurePoints=3;
        scenario.construction.ray_receiver=1;
        scenario=engine.placeBuilding(scenario,'ray_receiver',{x:400,y:0});
        peer=scenario.entities.find(e=>e.buildingId==='ray_receiver'&&e.id!==subject.id);
        scenario=engine.setEntityRecipe(scenario,peer.id,'ray_power');
      }
      let mode_transition=null;
      if(stage==='negligible_cell') {
        const requestedMode=id==='accumulator_charge'?'charge':'discharge';
        machine.energyMode=requestedMode==='charge'?'discharge':'charge';
        machine.recipeId=machine.energyMode==='charge'?'accumulator_charge':'accumulator_discharge';
        machine.storedEnergyMj=0.00001;
        machine.progress=0.25;
        mode_transition={before:structuredClone(machine),requested_mode:requestedMode};
        scenario=engine.setEnergyMode(scenario,machine.id,requestedMode);
        if(scenario.entities.find(e=>e.id===machine.id).energyMode!==requestedMode) throw new Error('Actual negligible cell mode transition failed');
      }
      const seconds=['powered','epsilon_completion','fractional_output'].includes(stage)?recipe.duration*1.5:stage==='cycle_boundary'?recipe.duration:1;
      const input=structuredClone({subject:scenario.entities.find(e=>e.id===subject.id),wind_count:stage==='unpowered'?0:winds,consumer:consumer?scenario.entities.find(e=>e.id===consumer.id):null,peer:peer?scenario.entities.find(e=>e.id===peer.id):null,mode_transition,completed_technologies:scenario.research.completedTechIds,research:scenario.research,system_id:systemId,dyson_plan:scenario.dysonPlans[systemId],dyson_engineering:scenario.dysonEngineering});
      const session=engine.createSimulationAdvanceSession(scenario,seconds);
      const tick_seconds=id==='accumulator_charge'||id==='accumulator_discharge'?1/60:null;
      let after=scenario;
      if(tick_seconds) for(let tick=0;tick<Math.round(seconds/tick_seconds);tick++) after=engine.advanceSimulation(after,tick_seconds);
      else after=engine.advanceSimulation(scenario,seconds);
      const result=after.entities.find(e=>e.id===subject.id);
      const expected={subject:result,peer:peer?after.entities.find(e=>e.id===peer.id):null,research:after.research,dyson_plan:after.dysonPlans[systemId],orbits:after.dysonEngineering.orbitsBySystem[systemId]};
      const phase_rounding_bound=Math.ceil(seconds/(tick_seconds??session.stepSize))*0.0000005+0.0000001;
      cases.push({id,stage,seconds,tick_seconds,phase_rounding_bound,input,expected});
    }
  }
  writeFrozenFixture(runtime,'task27-special-production.json',{scope:'Actual frozen full engine for seven dedicated recipes and powered/starved/blocked/locked/unpowered boundaries, real 60 Hz energy cells, partial cells, output-space and EPS boundaries. Fixture-funded power/materials, a real selected finite research and a real standard rocket layer. Source aggregate support counts expand into local individual devices. Not a clean-game growth or manual journey.',local_adaptations:[{id:'transport-cell-fractions',source:'The frozen engine floors cell buffers during conversion and discards injected nonintegral fractions.',local:'Continuous local belts can own nonintegral transport fractions. Whole cell projection is compared to the unchanged source gold; local fractions above source EPS are separately required to survive conversion and disk resume.'}],cases});
  console.log('TASK27 SPECIAL PRODUCTION GOLD: '+cases.length+' full source simulations for seven recipes and their blocked/starved/locked boundaries');
} finally {runtime.close();}
