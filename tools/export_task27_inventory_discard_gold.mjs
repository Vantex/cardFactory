import assert from 'node:assert/strict';
import {createFrozenSourceRuntime,writeFrozenFixture} from './frozen_source_runtime.mjs';

const runtime=createFrozenSourceRuntime();
try {
  const engine=await runtime.load('engine');
  const content=await runtime.load('content');
  const storage=await runtime.load('storage');
  const items=Object.keys(content.ITEMS);
  const constructions=content.CONSTRUCTION.map(row=>row.buildingId);
  const planets=content.PLANET_LIST.map(row=>row.id);
  const base=engine.createInitialState(240721,false);
  const project=state=>structuredClone({activePlanetId:state.activePlanetId,tray:state.tray,planetTrays:state.planetTrays,portableFleet:state.portableFleet,construction:state.construction});
  const encode=value=>JSON.parse(JSON.stringify(value,(_key,entry)=>typeof entry==='number'&&!Number.isFinite(entry)?{$number:String(entry)}:entry));
  const invoke=(state,command)=>command.kind==='tray'?engine.discardPlanetTrayItems(state,command.target,command.requests):engine.discardConstructionInventory(state,command.target);
  const cases=[];
  const record=(id,state,command,saveEligible=true)=>{
    const original=structuredClone(state);
    const next=invoke(state,command);
    const repeated=invoke(next,command);
    assert.deepEqual(state,original,'Source immutable discard changed input: '+id);
    cases.push({id,command:encode(command),input:encode(project(state)),expected:encode(project(next)),repeated:encode(project(repeated)),loaded_after:encode(project(storage.migrateGame(structuredClone(next)))),save_eligible:saveEligible});
  };
  const stages=['partial','exact','overshoot','fractional_request','negative','zero','below_one','duplicates','mixed_invalid','empty'];
  for(const item of items)for(const target of ['home','ashen'])for(const stage of stages){
    const state=structuredClone(base);
    state.tray={iron_ore:101,copper_ore:103};
    state.planetTrays.home=structuredClone(state.tray);
    state.planetTrays.ashen={iron_ore:107,copper_ore:109};
    const stock=target==='home'?state.tray:state.planetTrays.ashen;
    stock[item]=7;
    if(target==='home')state.planetTrays.home=structuredClone(stock);
    state.portableFleet={logistics_drone:17,logistics_vessel:19};
    let requests=[{itemId:item,amount:3}];
    if(stage==='exact')requests[0].amount=7;
    else if(stage==='overshoot')requests[0].amount=9;
    else if(stage==='fractional_request')requests[0].amount=2.9;
    else if(stage==='negative')requests[0].amount=-2;
    else if(stage==='zero')requests[0].amount=0;
    else if(stage==='below_one')requests[0].amount=0.9;
    else if(stage==='duplicates')requests=[{itemId:item,amount:1.9},{itemId:item,amount:2.9}];
    else if(stage==='mixed_invalid')requests=[{itemId:item,amount:2.9},{itemId:item,amount:NaN},{itemId:item,amount:Infinity},{itemId:item,amount:true},{itemId:'unknown_item',amount:5}];
    else if(stage==='empty')requests=[];
    record('tray-'+item+'-'+target+'-'+stage,state,{kind:'tray',target,requests});
  }
  for(const target of planets){
    const state=structuredClone(base);
    state.planetTrays[target]={iron_ore:13,copper_ore:17};
    if(target===state.activePlanetId)state.tray=structuredClone(state.planetTrays[target]);
    record('tray-all-worlds-'+target,state,{kind:'tray',target,requests:[{itemId:'iron_ore',amount:5},{itemId:'copper_ore',amount:3}]});
  }
  for(const stage of ['unknown_planet','missing_remote','empty_remote','unknown_item','no_owned_amount','fractional_stock']){
    const state=structuredClone(base);
    state.tray={iron_ore:11,copper_ore:13};
    state.planetTrays.home=structuredClone(state.tray);
    let target='ashen', requests=[{itemId:'iron_ore',amount:3}];
    if(stage==='unknown_planet')target='unknown_planet';
    else if(stage==='missing_remote')delete state.planetTrays.ashen;
    else if(stage==='empty_remote')state.planetTrays.ashen={};
    else if(stage==='unknown_item'){target='home';requests=[{itemId:'unknown_item',amount:3}];}
    else if(stage==='no_owned_amount'){target='home';requests=[{itemId:'universe_matrix',amount:3}];}
    else if(stage==='fractional_stock'){target='home';state.tray.iron_ore=7.9;state.planetTrays.home=structuredClone(state.tray);}
    record('tray-special-'+stage,state,{kind:'tray',target,requests});
  }
  const constructionStages=['owned','one','zero','missing','fractional','below_one','negative','nan','infinity'];
  for(const target of constructions)for(const stage of constructionStages){
    const state=structuredClone(base);
    const amount={owned:7,one:1,zero:0,fractional:2.9,below_one:0.9,negative:-2,nan:NaN,infinity:Infinity}[stage];
    if(stage==='missing')delete state.construction[target];
    else state.construction[target]=amount;
    record('construction-'+target+'-'+stage,state,{kind:'construction',target},['owned','one','zero','missing'].includes(stage));
  }
  record('construction-unknown',structuredClone(base),{kind:'construction',target:'unknown_construction'});
  writeFrozenFixture(runtime,'task27-inventory-discard.json',{
    scope:'Actual immutable frozen tray batch discard and whole construction-stack discard, repeats and raw source storage migration. Tray cases cover all 78 source item IDs, active/remote ownership, all 22 known worlds, duplicate aggregation, amount flooring, invalid/nonfinite requests and missing banks; portable fleet remains independent. Construction cases cover every source construction ID and raw malformed quantity guards; only nonnegative integral construction states are save-eligible. The fractional tray-stock case preserves the raw source floor result for an explicit comparison against CardFactory continuous inventory conservation, and is not permission to silently discard fractional local stock. This is controlled command/ownership evidence, not a growth journey. Source storage outputs remain original and are not used as a substitute for an independent exact local codec/disk round trip.',
    seed:240721,baseline:false,initial:encode({galaxy:base.galaxy,exploration:base.exploration,research:base.research}),items,constructions,planets,tray_stages:stages,construction_stages:constructionStages,cases,
  });
  console.log('TASK27 INVENTORY DISCARD GOLD: '+cases.length+' actual immutable source commands; '+items.length+' item IDs; '+constructions.length+' construction IDs');
} finally {runtime.close();}
