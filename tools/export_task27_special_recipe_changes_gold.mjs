import {createFrozenSourceRuntime,writeFrozenFixture} from './frozen_source_runtime.mjs';

const runtime = createFrozenSourceRuntime();
try {
  const engine = await runtime.load('engine');
  const content = await runtime.load('content');
  const cases = [];
  function setup(buildingId) {
    let state = engine.createInitialState(240721,false);
    state.research.completedTechIds.push('energy_storage','ray_receiver');
    state.construction[buildingId] = buildingId === 'ray_receiver' ? 2 : 1;
    state.construction.storage_mk1 = 2;
    state.construction.conveyor_belt_mk1 = 30;
    state = engine.placeBuilding(state,buildingId,{x:200,y:0});
    state = engine.placeBuilding(state,'storage_mk1',{x:0,y:0});
    state = engine.placeBuilding(state,'storage_mk1',{x:400,y:0});
    const machine = state.entities.find(e=>e.buildingId===buildingId);
    if (!machine) throw new Error('Frozen source did not place '+buildingId);
    const stores = state.entities.filter(e=>e.buildingId==='storage_mk1');
    const inputItem = buildingId === 'energy_exchanger' ? 'accumulator' : null;
    const outputItem = buildingId === 'energy_exchanger' ? 'charged_accumulator' : 'critical_photon';
    Object.assign(machine,{recipeId:buildingId==='energy_exchanger'?'accumulator_charge':'critical_photon',inputs:inputItem?{[inputItem]:3}:{},outputs:{[outputItem]:2},progress:0.5,proliferatorBonusProgress:{[outputItem]:0.25},powerInputKw:123,powerOutputKw:456,productionRate:7,utilization:0.5});
    stores[0].storedItemId = inputItem ?? outputItem;
    stores[1].storedItemId = outputItem;
    if (inputItem) state = engine.connectBelt(state,stores[0].id,machine.id,inputItem,1,undefined,2);
    state = engine.connectBelt(state,machine.id,stores[1].id,outputItem,1,undefined,3);
    if (state.belts.length !== (inputItem ? 2 : 1)) throw new Error('Frozen real paid connections failed');
    if (buildingId === 'ray_receiver') {
      state = engine.placeBuilding(state,'ray_receiver',{x:600,y:0});
      const peer = state.entities.filter(e=>e.buildingId==='ray_receiver')[1];
      Object.assign(peer,{recipeId:'ray_power',progress:0.4,productionRate:9,utilization:0.5,powerOutputKw:777});
      const systemId = content.getPlanet('home').systemId;
      state.dysonPlans[systemId].structurePoints = 3;
    }
    return {state,subject:machine.id};
  }
  const project = (state,subject) => ({subject,entities:state.entities.filter(e=>e.buildingId),tray:state.tray,construction:state.construction,belts:state.belts,completed_technologies:state.research.completedTechIds,dyson_system:content.getPlanet('home').systemId,structure_points:state.dysonPlans[content.getPlanet('home').systemId].structurePoints});
  const energy = setup('energy_exchanger');
  const ray = setup('ray_receiver');
  function add(id,base,operation,value,edit=()=>{}) {
    const before = structuredClone(base.state);
    edit(before,before.entities.find(e=>e.id===base.subject));
    const input = project(before,base.subject);
    const after = operation === 'mode' ? engine.setEnergyMode(before,base.subject,value) : engine.setEntityRecipe(before,base.subject,value);
    cases.push({id,operation,value,changed:after!==before,input,expected:project(after,base.subject)});
  }
  add('energy-recipe-same',energy,'recipe','accumulator_charge');
  add('energy-recipe-switch',energy,'recipe','accumulator_discharge');
  add('energy-recipe-partial-cell',energy,'recipe','accumulator_discharge',(s,e)=>e.storedEnergyMj=12);
  add('energy-recipe-locked-tech',energy,'recipe','accumulator_discharge',s=>s.research.completedTechIds=[]);
  add('energy-recipe-locked-entity',energy,'recipe','accumulator_discharge',(s,e)=>e.interactionLocked=true);
  add('energy-recipe-incompatible',energy,'recipe','gear');
  add('energy-mode-switch',energy,'mode','discharge');
  add('energy-mode-same',energy,'mode','charge');
  add('energy-mode-same-after-recipe',{state:engine.setEntityRecipe(energy.state,energy.subject,'accumulator_discharge'),subject:energy.subject},'mode','charge',(s,e)=>{
    e.inputs={charged_accumulator:1};
    e.outputs={accumulator:2};
    e.progress=0.4;
  });
  add('energy-mode-auto',energy,'mode','auto');
  add('energy-mode-partial-cell',energy,'mode','discharge',(s,e)=>e.storedEnergyMj=12);
  add('energy-mode-negligible-cell',energy,'mode','discharge',(s,e)=>e.storedEnergyMj=0.00001);
  add('energy-mode-locked-entity',energy,'mode','discharge',(s,e)=>e.interactionLocked=true);
  add('energy-mode-without-tech',energy,'mode','discharge',s=>s.research.completedTechIds=[]);
  add('energy-mode-wrong-building',{state:energy.state,subject:energy.state.entities.find(e=>e.buildingId==='storage_mk1').id},'mode','discharge');
  add('energy-mode-absent-entity',{state:energy.state,subject:'not_registered'},'mode','discharge');
  add('energy-recipe-absent',energy,'recipe','not_registered');
  add('ray-recipe-same',ray,'recipe','critical_photon');
  add('ray-recipe-power',ray,'recipe','ray_power');
  add('ray-recipe-photon',ray,'recipe','critical_photon',(s,e)=>e.recipeId='ray_power');
  add('ray-recipe-locked-tech',ray,'recipe','ray_power',s=>s.research.completedTechIds=[]);
  add('ray-recipe-locked-entity',ray,'recipe','ray_power',(s,e)=>e.interactionLocked=true);
  add('ray-recipe-incompatible',ray,'recipe','gear');
  add('ray-recipe-full-peer',ray,'recipe','ray_power',s=>{
    const peer=s.entities.filter(e=>e.buildingId==='ray_receiver')[1];
    Object.assign(peer,{recipeId:'critical_photon',outputs:{critical_photon:content.getBuilding('ray_receiver').outputCapacity}});
  });
  writeFrozenFixture(runtime,'task27-special-recipe-changes.json',{scope:'Actual frozen recipe selection versus energy-mode changes, material buffers, paid belts, partial cells, technology/interaction rejection and immediate reception presentation. Fixture-funded devices and Dyson structure; not a full production or player journey.',cases});
  console.log('TASK27 SPECIAL RECIPE COMMAND GOLD: '+cases.length+' actual source cases');
} finally {runtime.close();}
