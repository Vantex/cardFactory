import {createFrozenSourceRuntime,writeFrozenFixture} from './frozen_source_runtime.mjs';
const runtime = createFrozenSourceRuntime();
try {
  const engine = await runtime.load('engine');
  const planning = await runtime.load('planning');
  const mods = await runtime.load('mods');
  const packs = await runtime.load('contentPacks');
  const storage = await runtime.load('storage');
  const manifest = {formatVersion:2,id:'planning_parity_pack',name:'计划对照包',version:'1.0.0',items:[{id:'planning_product',name:'计划成品',symbol:'PP',kind:'solid',color:'#8844cc'}],buildings:[{id:'planning_machine',name:'计划机器',kind:'machine',speed:2,powerDemandKw:120,inputCapacity:100,outputCapacity:100,costs:[{itemId:'iron_ingot',amount:1}]}],technologies:[{id:'planning_technology',name:'计划科技',summary:'计划测试',costs:[]}],recipes:[{id:'planning_recipe',name:'计划配方',buildingId:'planning_machine',requiredTechId:'planning_technology',duration:4,inputs:[{itemId:'iron_ingot',amount:2}],outputs:[{itemId:'planning_product',amount:3}]}]};
  manifest.buildings.push({...manifest.buildings[0],id:'dsp_planning_machine',name:'另一台计划机器',speed:3,powerDemandKw:999});
  manifest.technologies.push({...manifest.technologies[0],id:'dsp_planning_technology',name:'另一项计划科技'});
  manifest.recipes.push({...manifest.recipes[0],id:'dsp_planning_recipe',name:'另一条计划配方',buildingId:'dsp_planning_machine',requiredTechId:'dsp_planning_technology',outputs:[{itemId:'copper_ingot',amount:2}]});
  manifest.items.push({id:'planning_long_name',name:'长'.repeat(50),symbol:'LP',kind:'solid',color:'#8844cc'});
  const validation = mods.validateContentPack(manifest);
  if (!validation.valid) throw new Error(JSON.stringify(validation));
  const registered = packs.registerContentPack(packs.createContentPackRegistry(),validation);
  const activation = packs.applyContentPackRegistry(registered.registry);
  if (!activation.catalogValid || activation.activePackIds.length!==1) throw new Error(JSON.stringify(activation));
  const cases=[];
  for (const stage of ['locked','unlocked','half-utilized','prefix-tech-only']) {
    let state=engine.createInitialState(240721,false);
    if(stage==='unlocked'||stage==='half-utilized') state.research.completedTechIds.push('planning_technology');
    if(stage==='prefix-tech-only') state.research.completedTechIds.push('dsp_planning_technology');
    if(stage==='half-utilized') {
      state.construction.planning_machine=1;
      state=engine.placeBuilding(state,'planning_machine',{x:200,y:0});
      const machine=state.entities.find(e=>e.buildingId==='planning_machine');
      Object.assign(machine,{recipeId:'planning_recipe',utilization:0.5,inputs:{iron_ingot:8},outputs:{planning_product:2}});
    }
    const input={next_id:state.nextId,elapsed_time:state.elapsedSeconds,completed_technologies:state.research.completedTechIds,planet_inventories:{...state.planetTrays,[state.activePlanetId]:state.tray},machines:state.entities.filter(e=>e.buildingId)};
    state=planning.createProductionPlan(state,'planning_product',45,'all');
    const plan=state.productionPlans.at(-1);
    cases.push({id:stage,input,plan,options:planning.getProductionRecipeOptions(state,'planning_product').map(r=>r.id),result:planning.calculateProductionPlan(state,plan),usage:packs.getContentPackUsage(state,validation.manifest)});
  }
  const longNameState = planning.createProductionPlan(engine.createInitialState(240721,false),'planning_long_name',60,'all');
  const longNameLoaded = storage.migrateGame(longNameState,registered.registry);
  if (!longNameLoaded || longNameState.productionPlans[0].name.length <= 40 || longNameLoaded.productionPlans[0].name.length !== 40) throw new Error('Frozen long-name migration did not exercise the normalization boundary');
  const nameNormalization = {created:longNameState.productionPlans[0],persisted:longNameLoaded.productionPlans[0],scope:'CardFactory normalizes the generated name at creation to the frozen source load-time 40-character limit, so a valid content item cannot prevent verified saving.'};
  if(runtime.unregisteredFiles().length && !process.argv.includes('--register-source'))throw new Error('Unregistered source modules: '+runtime.unregisteredFiles().join(', '));
  writeFrozenFixture(runtime,'task27-planning-packs.json',{scope:'Actual frozen content-pack activation and production planning for locked/unlocked recipes, prefix-distinct IDs, a half-utilized custom machine and long-name save normalization; fixture-funded setup, not a full player journey.',manifest,cases,nameNormalization});
  console.log('TASK27 PLANNING PACK GOLD: '+cases.length+' actual source cases');
} finally {runtime.close();}
