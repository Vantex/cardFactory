import {createFrozenSourceRuntime,writeFrozenFixture} from './frozen_source_runtime.mjs';
const runtime = createFrozenSourceRuntime();
try {
  const engine = await runtime.load('engine');
  let state = engine.createInitialState(240721,false);
  state.construction.storage_mk1 = 2;
  state.construction.arc_smelter = 1;
  state.construction.conveyor_belt_mk1 = 30;
  state = engine.placeBuilding(state,'storage_mk1',{x:0,y:0});
  state = engine.placeBuilding(state,'arc_smelter',{x:200,y:0});
  state = engine.placeBuilding(state,'storage_mk1',{x:400,y:0});
  const stores = state.entities.filter(row => row.buildingId === 'storage_mk1');
  const machine = state.entities.find(row => row.buildingId === 'arc_smelter');
  stores[0].storedItemId = 'iron_ore';
  stores[0].outputs = {iron_ore:12};
  stores[1].storedItemId = 'iron_ingot';
  Object.assign(machine,{inputs:{iron_ore:3},outputs:{iron_ingot:2},progress:0.5});
  state = engine.connectBelt(state,stores[0].id,machine.id,'iron_ore',1,undefined,2);
  state = engine.connectBelt(state,machine.id,stores[1].id,'iron_ingot',1,undefined,3);
  if (state.belts.length !== 2) throw new Error('Frozen source could not create the real recipe-change connections.');
  const project = input => ({machine:input.entities.find(row => row.id===machine.id),tray:input.tray,construction:input.construction,belts:input.belts});
  const input = project(state);
  const cases = [];
  for (const [id,recipeId,locked] of [['same','iron_ingot',false],['switch','copper_ingot',false],['locked-tech','steel',false],['wrong-building','gear',false],['locked-entity','copper_ingot',true]]) {
    const before = structuredClone(state);
    before.entities.find(row => row.id===machine.id).interactionLocked = locked;
    const after = engine.setEntityRecipe(before,machine.id,recipeId);
    cases.push({id,recipe_id:recipeId,interaction_locked:locked,changed:after!==before,expected:project(after)});
  }
  writeFrozenFixture(runtime,'task27-recipe-changes.json',{scope:'Real source recipe command on a fixture-funded smelter with material buffers, phase and two paid connections; same, switched, locked and incompatible selections.',input,cases});
  console.log(`TASK27 RECIPE CHANGE GOLD: ${cases.length} commands; real ${state.belts.length} connections and five paid lanes`);
} finally {runtime.close();}
