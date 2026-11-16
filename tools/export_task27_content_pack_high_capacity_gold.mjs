import assert from 'node:assert/strict';
import crypto from 'node:crypto';
import {createFrozenSourceRuntime,writeFrozenFixture} from './frozen_source_runtime.mjs';
const runtime=createFrozenSourceRuntime();
try {
 const engine=await runtime.load('engine'),mods=await runtime.load('mods'),packs=await runtime.load('contentPacks');
 const manifest={formatVersion:2,id:'high_capacity_pack',name:'高容量站保存回归',version:'1.0.0',buildingOverrides:[{id:'planetary_logistics_station',outputCapacity:2000},{id:'interstellar_logistics_station',outputCapacity:3000},{id:'orbital_collector',outputCapacity:4000}]};
 const valid=mods.validateContentPack(manifest);assert.equal(valid.valid,true);
 const registered=packs.registerContentPack(packs.createContentPackRegistry(),valid),activated=packs.applyContentPackRegistry(registered.registry);assert.equal(activated.catalogValid,true);assert.deepEqual(activated.activePackIds,[manifest.id]);
 const cases=[];
 for(const building of ['planetary_logistics_station','interstellar_logistics_station','orbital_collector'])for(const count of [1,2,3])for(const maxStock of [0,59.9])for(const item of ['iron_ore','proliferator_mk1']){
  const state=engine.createInitialState(240721,false),slot={itemId:'iron_ore',maxStock},entity={id:'probe',kind:'station',buildingId:building,machineCount:count,stationSlots:[slot]},before=JSON.stringify({state,entity});
  const expected={getEntityInputCapacity:engine.getEntityInputCapacity(state,entity),getEntityOutputCapacity:engine.getEntityOutputCapacity(state,entity),getEntityItemInputCapacity:engine.getEntityItemInputCapacity(state,entity,item),getStationSlotCapacity:engine.getStationSlotCapacity(state,entity,slot)};assert.equal(JSON.stringify({state,entity}),before);
  cases.push({id:`${building}-c${count}-s${maxStock}-i${item}`,input:{building,count,maxStock,item},expected});
 }
 const output={source_commit:runtime.commit,source_files:runtime.files,source_environment:{DEV:false,PROD:true,MODE:'production'},scope:'Actual frozen core pack validation/registration/activation and36 controlled high output capacity station states/144 provider values. Direct slot query preserves fractional maxStock; item input normalizes it. Query fixture alone is not real paid construction or complete logistics/growth.',manifest,cases};
 const bytes=JSON.stringify(output,null,2)+'\n';writeFrozenFixture(runtime,'task27-content-pack-high-capacity.json',output);
 console.log(`HIGH PACK SOURCE GOLD:${cases.length}states/${Object.keys(runtime.files).length}modules/SHA256:${crypto.createHash('sha256').update(bytes).digest('hex')}`);
} finally {runtime.close();}
