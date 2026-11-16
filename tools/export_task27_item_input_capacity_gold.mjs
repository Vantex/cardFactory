import assert from 'node:assert/strict';
import crypto from 'node:crypto';
import {createFrozenSourceRuntime,writeFrozenFixture} from './frozen_source_runtime.mjs';
const runtime=createFrozenSourceRuntime();
try {
 const engine=await runtime.load('engine'),content=await runtime.load('content');
 const counts=[1,2,3,0,-1,1.9,100000000,1000000000];
 const limits=[['default',1000000,1000000],['minimum',1000,1000],['maximum',100000000,100000000],['split-production',1000,100000000],['split-logistics',100000000,1000],['below',-1,999.9],['fractional',1234.9,2345.9],['above',1e12,1e12],['null',null,null],['boolean',false,true],['string','1000','2000']];
 const sprayLimits=[['default',600],['minimum',1],['maximum',100000000],['below',-1],['fractional',59.9],['above',1e12],['null',null],['boolean-false',false],['boolean-true',true],['string','600']];
 const items=['iron_ore','proliferator_mk1','proliferator_mk2','proliferator_mk3','','unknown'];
 const stocks=[-1,0,1,59.9,600,1200,100000000,1e12];
 const buildings=Object.keys(content.BUILDINGS).sort(),stations=buildings.filter(id=>content.BUILDINGS[id].kind==='station');
 const cases=[];
 const add=(id,input)=>{
  const state=engine.createInitialState(240721,false);
  state.settings.productionBufferLimit=input.production;state.settings.logisticsBufferLimit=input.logistics;state.settings.proliferatorBufferLimit=input.spray_limit;
  const entity={id:'probe',kind:input.kind,machineCount:input.count,sprayCoaterInstalled:input.installed};
  if(input.building)entity.buildingId=input.building;
  if(input.tier!==null)entity.proliferatorTier=input.tier;
  if(input.slots!==null)entity.stationSlots=input.slots.map(([itemId,maxStock])=>({itemId,maxStock,localMode:'storage',remoteMode:'storage',minimumLoad:1,minStock:0,priority:1,routePolicy:'relay-preferred',warperBudget:2}));
  if(input.legacy_item!==null)entity.storedItemId=input.legacy_item;
  const before=JSON.stringify({state,entity});
  const expected={getEntityItemInputCapacity:engine.getEntityItemInputCapacity(state,entity,input.item)};
  assert.equal(JSON.stringify({state,entity}),before,'Source query preserves raw input');cases.push({id,input,expected});
 };
 const input=(building,count=1,profile=limits[0],item='iron_ore',extra={})=>({building,kind:content.BUILDINGS[building]?.kind??'station',count,profile:profile[0],production:profile[1],logistics:profile[2],item,installed:false,tier:null,spray_profile:'default',spray_limit:600,slots:null,legacy_item:null,...extra});
 for(const building of buildings)for(const profile of limits)for(const [ci,count] of counts.entries())for(const [ii,item] of items.entries())add(`base-${building}-${profile[0]}-c${ci}-i${ii}`,input(building,count,profile,item));
 for(const building of buildings)for(const count of [1,3])for(const tier of [null,1,2,3])for(const spray of sprayLimits)for(const [ii,item] of items.entries())add(`spray-${building}-c${count}-t${tier??'unset'}-${spray[0]}-i${ii}`,input(building,count,limits[0],item,{installed:true,tier,spray_profile:spray[0],spray_limit:spray[1]}));
 for(const building of stations)for(const profile of limits)for(const [ci,count] of counts.entries())for(const [si,maxStock] of stocks.entries())for(const [ii,item] of ['iron_ore','proliferator_mk1'].entries())add(`slot-${building}-${profile[0]}-c${ci}-s${si}-i${ii}`,input(building,count,profile,item,{slots:[['iron_ore',maxStock]]}));
 for(const building of stations)for(const spray of sprayLimits)for(const [si,maxStock] of stocks.entries())for(const [ii,item] of ['proliferator_mk1','proliferator_mk2'].entries())add(`priority-${building}-${spray[0]}-s${si}-i${ii}`,input(building,3,limits[0],item,{installed:true,tier:1,spray_profile:spray[0],spray_limit:spray[1],slots:[['proliferator_mk1',maxStock]]}));
 for(const building of stations)for(const [ci,count] of counts.entries())for(const [ii,item] of ['iron_ore','proliferator_mk1'].entries())add(`legacy-${building}-c${ci}-i${ii}`,input(building,count,limits[0],item,{legacy_item:'iron_ore'}));
 for(const building of stations)for(const [si,maxStock] of stocks.entries())add(`duplicate-${building}-s${si}`,input(building,2,limits[0],'iron_ore',{slots:[['iron_ore',maxStock],['iron_ore',1200]]}));
 for(const [si,maxStock] of stocks.entries())for(const [ii,item] of ['iron_ore','proliferator_mk1'].entries())add(`missing-building-s${si}-i${ii}`,input('',1,limits[0],item,{slots:[['iron_ore',maxStock]]}));
 assert.equal(new Set(cases.map(row=>row.id)).size,cases.length);
 const output={source_commit:runtime.commit,source_files:runtime.files,source_environment:{DEV:false,PROD:true,MODE:'production'},scope:'Exploratory read-only per-item input capacity source output. All39 buildings,8 raw counts,11 building limit profiles,6 item queries; all39 installed spray tiers1/2/3/unset with counts1/3 and10 raw spray limits; all4 station kinds with matching/unmatched slots,raw maxStock,normalized first duplicate andlegacy stored item,station-before-spray priority andmissing building. Synthetic inputs may be unsaveable or ineligible for paid construction. Not a registered proof or real installation/throughput/growth.',functions:['getEntityItemInputCapacity'],buildings,stations,counts,limits,spray_limits:sprayLimits,items,stocks,cases};
 const bytes=JSON.stringify(output,null,2)+'\n';writeFrozenFixture(runtime,'task27-item-input-capacity.json',output);
 console.log(`ITEM INPUT SOURCE:${cases.length}queries/${Object.keys(runtime.files).length}modules/SHA256:${crypto.createHash('sha256').update(bytes).digest('hex')}`);
} finally {runtime.close();}
