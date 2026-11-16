import fs from 'node:fs';
import assert from 'node:assert/strict';
import crypto from 'node:crypto';
import {createFrozenSourceRuntime} from './frozen_source_runtime.mjs';
const runtime=createFrozenSourceRuntime();
try {
  const engine=await runtime.load('engine'),content=await runtime.load('content');
  const base=engine.createInitialState(240721,false);
  const resources=[...new Set(Object.values(base.galaxy.profiles).flatMap(profile=>profile.resourceIds))].sort();
  assert.equal(resources.length,16);
  const acidPlanet=Object.entries(base.galaxy.profiles).find(([,profile])=>profile.oceanType==='sulfuric-acid');
  assert.ok(acidPlanet,'Actual seeded galaxy has a sulfuric acid ocean profile');
  const planets=['home',acidPlanet[0],'giant'],modes=['finite','infinite'],levels=[0,1,9,10,11];
  for(const id of planets)assert.ok(base.galaxy.profiles[id]);
  const profiles=[
    {id:'unset',remaining:null,capacity:null,remainder:null},
    {id:'empty',remaining:0,capacity:100,remainder:0},
    {id:'negative',remaining:-1,capacity:-1,remainder:-1},
    {id:'fractional-empty',remaining:0.9,capacity:100.9,remainder:9.9},
    {id:'last-whole',remaining:1,capacity:100,remainder:0},
    {id:'last-fraction',remaining:1,capacity:100,remainder:9},
    {id:'partial',remaining:25.9,capacity:100.9,remainder:5},
    {id:'oversized-remaining',remaining:150,capacity:100,remainder:10},
    {id:'zero-capacity',remaining:0,capacity:0,remainder:0},
  ];
  const cases=[];
  const add=(id,input)=>{
    const state=engine.createInitialState(240721,false);
    state.settings.resourceMode=input.mode;
    state.endgame.infiniteResearch.vein_utilization={level:input.level,progress:'0'};
    const entity={id:'reserve-probe',kind:input.kind,planetId:input.planet};
    if(input.resource)entity.resourceId=input.resource;
    for(const [target,source] of [['resourceRemaining','remaining'],['resourceCapacity','capacity'],['resourceDepletionRemainder','remainder']])if(input[source]!==null)entity[target]=input[source];
    const before=JSON.stringify({state,entity});
    const expected=engine.getResourceReserveSnapshot(state,entity);
    const repeated=engine.getResourceReserveSnapshot(state,entity);
    assert.deepEqual(repeated,expected);assert.equal(JSON.stringify({state,entity}),before);
    cases.push({id,input,expected});
  };
  for(const resource of resources)for(const planet of planets)for(const mode of modes)for(const level of levels)for(const profile of profiles)add(`${resource}-${planet}-${mode}-l${level}-${profile.id}`,{resource,planet,mode,level,kind:'vein',...profile});
  for(const kind of ['vein','building','station','power'])for(const resource of ['', 'iron_ore'])add(`null-${kind}-${resource||'missing'}`,{resource,planet:'home',mode:'finite',level:0,kind,id:'null',remaining:1,capacity:100,remainder:0});
  const output={source_commit:runtime.commit,source_files:runtime.files,source_environment:{DEV:false,PROD:true,MODE:'production'},scope:'Actual frozen resource reserve public query,16resources/3planetprofiles/2modes/5valid research levels/9remaining-capacity-remainder profiles plus8 nonvein/missing cases. Queries repeat without raw source mutation. Controlled states include synthetic unavailable resource/planet combinations and malformed negative/fractional reserve inputs; not actual resource installation, mining throughput, save acceptance or earned research.',resources,planets,modes,levels,profiles,resource_kinds:Object.fromEntries(resources.map(id=>[id,content.ITEMS[id].kind])),cases};
  const bytes=JSON.stringify(output,null,2)+'\n';
  fs.writeFileSync(process.argv[2],bytes);
  console.log(`RESOURCE RESERVE SOURCE GOLD:${cases.length}cases/${Object.keys(runtime.files).length}modules/SHA256:${crypto.createHash('sha256').update(bytes).digest('hex')}`);
}finally{runtime.close();}
