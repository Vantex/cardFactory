import { createFrozenSourceRuntime, writeFrozenFixture } from './frozen_source_runtime.mjs';

const runtime = createFrozenSourceRuntime();
try {
  const content = await runtime.load('content');
  const engine = await runtime.load('engine');
  const initial = engine.createInitialState(240721, false);
  const beltCases = [];
  for (const tier of content.getBeltTiers()) {
    for (const [lanes, stackSize] of [[1, 1], [2, 2], [7, 4]]) {
      const belt = { tier, lanes, stackSize };
      beltCases.push({ id: `mk${tier}-${lanes}x${stackSize}`, belt, speed: content.getBeltSpeed(tier), capacity: engine.getBeltCapacity(belt) });
    }
  }
  const rewardCases = Object.values(content.TECHNOLOGIES).map(row => {
    const state = engine.createInitialState(240721, false);
    state.construction = {};
    engine.completeTechnology(state, row.id);
    const once = structuredClone(state);
    engine.completeTechnology(state, row.id);
    return { tech_id: row.id, ids: engine.getTechnologyConstructionRewards(row.id), once: once.construction, twice: state.construction, colonies: once.exploration.colonizedPlanetIds };
  });
  writeFrozenFixture(runtime, 'task27-basics.json', {
    belt_cases: beltCases,
    initial_economy: { tray: initial.tray, construction: initial.construction, colonies: initial.exploration.colonizedPlanetIds },
    research_rewards: rewardCases,
    initial_scope: 'Complete frozen createInitialState executed; comparison projects tray, construction and colonies only',
  });
  console.log(`TASK27 BASICS GOLD: ${beltCases.length} belt capacities, initial economy, ${rewardCases.length} research reward boundaries; ${Object.keys(runtime.files).length} real source modules`);
} finally {
  runtime.close();
}
