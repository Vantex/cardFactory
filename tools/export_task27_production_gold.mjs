import { createFrozenSourceRuntime, writeFrozenFixture } from './frozen_source_runtime.mjs';

const runtime = createFrozenSourceRuntime();
try {
  const content = await runtime.load('content');
  const engine = await runtime.load('engine');
  const cases = [];
  const dedicated = new Set(['matrix_research', 'solar_sail_launch', 'carrier_rocket_launch', 'ray_power', 'critical_photon', 'accumulator_charge', 'accumulator_discharge']);
  const excluded = [];
  for (const recipe of Object.values(content.RECIPES)) {
    const building = content.getBuilding(recipe.buildingId);
    if (dedicated.has(recipe.id) || building.kind !== 'machine' || !recipe.outputs.length) {
      excluded.push({ recipe_id: recipe.id, reason: 'dedicated subsystem, power conversion or no material output; requires its own behavior fixture' });
      continue;
    }
    let state = engine.createInitialState(240721, false);
    state.research.completedTechIds = Object.keys(content.TECHNOLOGIES);
    state.construction.wind_turbine = 100;
    state.construction[recipe.buildingId] = 1;
    state = engine.placeBuilding(state, 'wind_turbine', { x: 0, y: 0 }, 100);
    state = engine.placeBuilding(state, recipe.buildingId, { x: 100, y: 0 });
    const machine = state.entities.find(entity => entity.buildingId === recipe.buildingId);
    if (!machine) throw new Error(`Could not place source machine for ${recipe.id}`);
    state = engine.setEntityRecipe(state, machine.id, recipe.id);
    const configured = state.entities.find(entity => entity.id === machine.id);
    for (const input of recipe.inputs) configured.inputs[input.itemId] = input.amount * 3;
    const seconds = recipe.duration / building.speed * 1.5;
    const input = structuredClone(configured);
    const after = engine.advanceSimulation(state, seconds);
    const result = after.entities.find(entity => entity.id === machine.id);
    const phaseRoundingBound = Math.ceil(seconds / engine.createSimulationAdvanceSession(state, seconds).stepSize) * 0.0000005 + 0.0000001;
    cases.push({ id: recipe.id, seconds, input, phase_rounding_bound: phaseRoundingBound, expected: { inputs: result.inputs, outputs: result.outputs, progress: result.progress, utilization: result.utilization, production_rate: result.productionRate } });
  }
  writeFrozenFixture(runtime, 'task27-production.json', { scope: 'Fixture-funded powered machines, full source simulation; compares core material conversion and normalized cycle phase, not clean-game progression or power dispatch. Source rounds phase to six decimals per step; the bound is half one decimal unit per actual source step.', cases, excluded });
  console.log(`TASK27 PRODUCTION GOLD: ${cases.length} real material conversions; ${excluded.length} dedicated recipes explicitly deferred`);
} finally {
  runtime.close();
}
