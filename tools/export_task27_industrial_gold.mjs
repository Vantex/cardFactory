import {createFrozenSourceRuntime,writeFrozenFixture} from './frozen_source_runtime.mjs';
const runtime = createFrozenSourceRuntime();
try {
  const engine = await runtime.load('engine');
  const content = await runtime.load('content');
  const galaxy = await runtime.load('galaxy');
  const baseline = engine.createInitialState(240721, false);
  const cases = [];
  for (const planet of content.PLANET_LIST.filter(row => row.kind !== 'gas-giant')) {
    const profile = galaxy.getPlanetIndustrialProfile(baseline, planet.id);
    if (profile.productionSpeedMultiplier === 1) continue;
    const recipe = Object.values(content.RECIPES).find(row => {
      const building = content.getBuilding(row.buildingId);
      return row.outputs.length && building.kind === 'machine' && !['ray_receiver','energy_exchanger','em_rail_ejector','vertical_launching_silo'].includes(building.id) && galaxy.specializationApplies(profile, building.family, building.id);
    });
    if (!recipe) continue;
    let state = engine.createInitialState(240721, false);
    state.activePlanetId = planet.id;
    state.exploration.colonizedPlanetIds = content.PLANET_LIST.map(row => row.id);
    state.research.completedTechIds = Object.keys(content.TECHNOLOGIES);
    state.construction.wind_turbine = 100;
    state.construction[recipe.buildingId] = 1;
    state = engine.placeBuilding(state,'wind_turbine',{x:0,y:0},100);
    state = engine.placeBuilding(state,recipe.buildingId,{x:100,y:0});
    const machine = state.entities.find(row => row.buildingId === recipe.buildingId);
    if (!machine) throw new Error('Source placement failed: ' + planet.id);
    state = engine.setEntityRecipe(state,machine.id,recipe.id);
    const configured = state.entities.find(row => row.id === machine.id);
    for (const input of recipe.inputs) configured.inputs[input.itemId] = input.amount*4;
    const seconds = recipe.duration/content.getBuilding(recipe.buildingId).speed*1.5;
    const input = structuredClone(configured);
    const after = engine.advanceSimulation(state,seconds);
    const result = after.entities.find(row => row.id === machine.id);
    cases.push({id:planet.id+'-'+recipe.id,planet_id:planet.id,recipe_id:recipe.id,seconds,input,phase_rounding_bound:Math.ceil(seconds/engine.createSimulationAdvanceSession(state,seconds).stepSize)*0.0000005+0.0000001,expected:{inputs:result.inputs,outputs:result.outputs,progress:result.progress,utilization:result.utilization,production_rate:result.productionRate}});
  }
  writeFrozenFixture(runtime,'task27-industrial.json',{scope:'Fixture-funded powered ordinary machines on the twelve specialized source planets, full frozen simulation and its cycle-phase rounding bound.',cases});
  console.log(`TASK27 INDUSTRIAL GOLD: ${cases.length} specialized planets executed from frozen source`);
} finally {runtime.close();}
