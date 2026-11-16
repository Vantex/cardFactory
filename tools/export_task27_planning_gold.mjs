import { createFrozenSourceRuntime, writeFrozenFixture } from './frozen_source_runtime.mjs';
import fs from 'node:fs';
import path from 'node:path';

const runtime = createFrozenSourceRuntime();
try {
  const content = await runtime.load('content');
  const engine = await runtime.load('engine');
  const planning = await runtime.load('planning');
  const statistics = await runtime.load('statistics');
  const cases = [];
  for (const definition of [
    { id: 'initial-iron', item: 'iron_ingot', target: 60 },
    { id: 'initial-blue', item: 'electromagnetic_matrix', target: 60 },
    { id: 'all-tech-white', item: 'universe_matrix', target: 30, all: true },
    { id: 'all-tech-liquid', item: 'sulfuric_acid', target: 120, all: true },
    { id: 'selected-hydrogen', item: 'hydrogen', target: 60, all: true, selection: ['hydrogen', 'plasma_refining'] },
    { id: 'minimum-target', item: 'iron_ingot', target: -10 },
    { id: 'half-utilized-home', item: 'iron_ingot', target: 120, live: true, scope: 'home' },
    { id: 'half-utilized-other-planet', item: 'iron_ingot', target: 120, live: true, scope: 'ashen' },
  ]) {
    let state = engine.createInitialState(240721, false);
    if (definition.all) state.research.completedTechIds = Object.keys(content.TECHNOLOGIES);
    if (definition.live) {
      state = engine.placeBuilding(state, 'arc_smelter', { x: 500, y: 500 });
      const machine = state.entities.find(entity => entity.buildingId === 'arc_smelter');
      Object.assign(machine, { recipeId: 'iron_ingot', utilization: 0.5, inputs: { iron_ore: 16 }, outputs: { iron_ingot: 4 } });
      state.planetTrays.ashen = { iron_ingot: 120, iron_ore: 30 };
    }
    const input = {
      next_id: state.nextId,
      elapsed_time: state.elapsedSeconds,
      completed_technologies: state.research.completedTechIds,
      planet_inventories: { ...state.planetTrays, [state.activePlanetId]: state.tray },
      machines: state.entities.filter(entity => entity.buildingId),
    };
    state = planning.createProductionPlan(state, definition.item, definition.target, definition.scope ?? 'all');
    const id = state.productionPlans[0].id;
    if (definition.selection) state = planning.setProductionPlanRecipe(state, id, ...definition.selection);
    const plan = state.productionPlans[0];
    const scope = definition.scope ?? 'all';
    cases.push({ id: definition.id, input, plan, options: planning.getProductionRecipeOptions(state, definition.item).map(recipe => recipe.id), statistics: statistics.calculateFactoryStatistics(state, scope).items, result: planning.calculateProductionPlan(state, plan) });
  }
  let state = engine.createInitialState(240721, false);
  const initialId = state.nextId;
  const operations = [
    ['create', ['iron_ingot', 60, 'all']],
    ['update', [`plan_${initialId}`, { name: '  产能目标  ', targetPerMinute: 120 }]],
    ['recipe', [`plan_${initialId}`, 'iron_ingot', 'copper_ingot']],
    ['recipe', [`plan_${initialId}`, 'iron_ingot', 'iron_ingot']],
    ['update', [`plan_${initialId}`, { itemId: 'copper_ingot', name: ' ', targetPerMinute: -5 }]],
    ['update', ['missing_plan', { name: '不存在' }]],
    ['remove', [`plan_${initialId}`]],
    ['remove', [`plan_${initialId}`]],
  ];
  const commands = operations.map(([operation, args]) => {
    const before = state;
    state = ({ create: planning.createProductionPlan, update: planning.updateProductionPlan, recipe: planning.setProductionPlanRecipe, remove: planning.removeProductionPlan })[operation](state, ...args);
    return { operation, args, changed: state !== before, plans: state.productionPlans, next_id: state.nextId };
  });
  writeFrozenFixture(runtime, 'task27-planning.json', { cases, commands, command_initial_id: initialId });
  const directory = path.resolve(import.meta.dirname, '../data/planning');
  fs.mkdirSync(directory, { recursive: true });
  fs.writeFileSync(path.join(directory, 'source_recipe_order.json'), `${JSON.stringify({ source_commit: runtime.commit, source_content_sha256: runtime.files['src/game/content.ts'], items: Object.keys(content.ITEMS), recipes: Object.keys(content.RECIPES) }, null, 2)}\n`);
  console.log(`TASK27 PLANNING GOLD: ${cases.length} calculations and ${commands.length} commands executed from frozen source`);
} finally {
  runtime.close();
}
