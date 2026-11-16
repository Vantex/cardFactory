import crypto from 'node:crypto';
import assert from 'node:assert/strict';
import {createFrozenSourceRuntime,writeFrozenFixture} from './frozen_source_runtime.mjs';
const runtime=createFrozenSourceRuntime();
try {
 const engine=await runtime.load('engine'),content=await runtime.load('content');
 const functions=['getStationSlotCapacity'];
 const counts=[1,2,3,0,-1,1.9,100000000,1000000000];
 const limits=[['default',1000000,1000000],['minimum',1000,1000],['maximum',100000000,100000000],['split-production',1000,100000000],['split-logistics',100000000,1000],['below',-1,999.9],['fractional',1234.9,2345.9],['above',1e12,1e12],['null',null,null],['boolean',false,true],['string','1000','2000']];
 const stocks=[-1,0,1,59.9,600,1200,100000000,1000000000000];
 const buildings=Object.entries(content.BUILDINGS).filter(([,row])=>row.kind==='station').map(([id])=>id).sort();
 const cases=[];
 const add=(id,input)=>{
  const state=engine.createInitialState(240721,false);state.settings.productionBufferLimit=input.production;state.settings.logisticsBufferLimit=input.logistics;
  const entity={id:'probe',kind:'station',machineCount:input.count};if(input.building)entity.buildingId=input.building;
  const slot={itemId:'iron_ore',maxStock:input.maxStock};
  const before=JSON.stringify({state,entity,slot});
  const expected={getStationSlotCapacity:engine.getStationSlotCapacity(state,entity,slot)};
  assert.equal(JSON.stringify({state,entity,slot}),before);cases.push({id,input,expected});
 };
 for(const building of buildings)for(const [profile,production,logistics] of limits)for(const [countIndex,count] of counts.entries())for(const [stockIndex,maxStock] of stocks.entries())add(`${building}-${profile}-c${countIndex}-s${stockIndex}`,{building,count,profile,production,logistics,maxStock});
 for(const [index,maxStock] of stocks.entries())add(`missing-building-s${index}`,{building:'',count:1,profile:'default',production:1000000,logistics:1000000,maxStock});
 const output={source_commit:runtime.commit,source_files:runtime.files,source_environment:{DEV:false,PROD:true,MODE:'production'},scope:'One readonly station slot capacity query:all4 frozen station-kind definitions,8 raw counts,11 production/logistics setting profiles,8 raw numeric maxStock values,plus8 missing-building-id queries. Synthetic inputs may fail legal-save validation; no paid installation, throughput, earned growth or other command claim.',functions,buildings,counts,limits,stocks,cases};
 const bytes=JSON.stringify(output,null,2)+'\n';writeFrozenFixture(runtime,'task27-slot-capacity.json',output);
 console.log(`FORMAL SLOT SOURCE GOLD:${cases.length}queries/${Object.keys(runtime.files).length}modules/SHA256:${crypto.createHash('sha256').update(bytes).digest('hex')}`);
} finally {runtime.close();}
