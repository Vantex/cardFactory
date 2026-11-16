import crypto from 'node:crypto';
import assert from 'node:assert/strict';
import {createFrozenSourceRuntime,writeFrozenFixture} from './frozen_source_runtime.mjs';
const runtime=createFrozenSourceRuntime();
try {
 const engine=await runtime.load('engine'),mods=await runtime.load('mods'),packs=await runtime.load('contentPacks');
 const manifest={formatVersion:2,id:'item_input_capacity_pack',name:'输入容量对照包',version:'1.0.0',items:[],buildings:[],recipes:[],technologies:[],belts:[],buildingOverrides:[{id:'planetary_logistics_station',inputCapacity:200,outputCapacity:300},{id:'arc_smelter',inputCapacity:50,outputCapacity:70},{id:'storage_mk1',inputCapacity:80,outputCapacity:90}]};
 const validation=mods.validateContentPack(manifest);assert.equal(validation.valid,true);
 const registered=packs.registerContentPack(packs.createContentPackRegistry(),validation);
 const activation=packs.applyContentPackRegistry(registered.registry);assert.equal(activation.catalogValid,true);assert.deepEqual(activation.activePackIds,[manifest.id]);
 const cases=[];
 for(const building of ['planetary_logistics_station','arc_smelter','storage_mk1'])for(const count of [1,2,3])for(const maxStock of [0,59.9])for(const item of ['iron_ore','proliferator_mk1']){
  const state=engine.createInitialState(240721,false),entity={id:'probe',kind:building==='planetary_logistics_station'?'station':building==='storage_mk1'?'storage':'machine',buildingId:building,machineCount:count,stationSlots:[{itemId:'iron_ore',maxStock}]};
  const before=JSON.stringify({state,entity});
  const expected={getEntityInputCapacity:engine.getEntityInputCapacity(state,entity),getEntityOutputCapacity:engine.getEntityOutputCapacity(state,entity),getEntityItemInputCapacity:engine.getEntityItemInputCapacity(state,entity,item)};
  assert.equal(JSON.stringify({state,entity}),before);cases.push({id:`${building}-c${count}-s${maxStock}-i${item}`,input:{building,count,maxStock,item},expected});
 }
 const output={source_commit:runtime.commit,source_files:runtime.files,source_environment:{DEV:false,PROD:true,MODE:'production'},scope:'Actual frozen content-pack validation/registration/activation,36 controlled queries of three capacity providers after legal core building overrides. Synthetic stacks/slots, not paid installation or full gameplay proof.',manifest,cases};
 const bytes=JSON.stringify(output,null,2)+'\n';writeFrozenFixture(runtime,'task27-content-pack-capacity.json',output);
 console.log(`ITEM INPUT PACK SOURCE:${cases.length}states/${Object.keys(runtime.files).length}modules/SHA256:${crypto.createHash('sha256').update(bytes).digest('hex')}`);
} finally {runtime.close();}
