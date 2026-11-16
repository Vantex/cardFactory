import {createFrozenSourceRuntime,writeFrozenFixture} from './frozen_source_runtime.mjs';
const runtime=createFrozenSourceRuntime();
try {
  const engine=await runtime.load('engine');
  const content=await runtime.load('content');
  const storage=await runtime.load('storage');
  const planets=content.PLANET_LIST.map(row=>row.id);
  const systems=content.STAR_SYSTEM_LIST.map(row=>row.id);
  const roles=['auto','mining','smelting','manufacturing','chemical','research','logistics','power'];
  const cases=[];
  const portable=value=>typeof value==='string'?value.toWellFormed():Array.isArray(value)?value.map(portable):value&&typeof value==='object'?Object.fromEntries(Object.entries(value).map(([key,entry])=>[key,portable(entry)])):value;
  const unitTree=value=>typeof value==='string'?{utf16:Array.from({length:value.length},(_,index)=>value.charCodeAt(index))}:Array.isArray(value)?value.map(unitTree):value&&typeof value==='object'?Object.fromEntries(Object.entries(value).map(([key,entry])=>[key,unitTree(entry)])):value;
  const sourceUnits=state=>unitTree({planetMetadata:state.galaxy.planetMetadata,systemMetadata:state.galaxy.systemMetadata});
  const domain=state=>portable(structuredClone({roles:state.galaxy.planetRoles,planetMetadata:state.galaxy.planetMetadata,systemMetadata:state.galaxy.systemMetadata,limits:state.planetTrayItemLimits}));
  const invoke=(state,command)=>{
    const {kind,target,value}=command;
    if(kind==='role')return engine.setPlanetIndustryRole(state,target,value);
    if(kind==='planetMetadata')return engine.setPlanetDisplayMetadata(state,target,value);
    if(kind==='systemName')return engine.setStarSystemDisplayName(state,target,value);
    if(kind==='limit')return engine.setPlanetTrayItemLimit(state,target,typeof value==='string'?({Infinity:Infinity,NaN:NaN,'-Infinity':-Infinity}[value]):value);
    throw Error('Unknown control '+kind);
  };
  const record=(id,command,setup={})=>{
    const state=engine.createInitialState(240721,false);
    Object.assign(state.galaxy.planetMetadata,structuredClone(setup.planetMetadata??{}));
    Object.assign(state.galaxy.systemMetadata,structuredClone(setup.systemMetadata??{}));
    Object.assign(state.galaxy.planetRoles,structuredClone(setup.roles??{}));
    Object.assign(state.planetTrayItemLimits,structuredClone(setup.limits??{}));
    const original=JSON.stringify(state);
    const next=invoke(state,command);
    const repeated=invoke(next,command);
    if(JSON.stringify(state)!==original)throw Error('Immutable source control mutated input '+id);
    const loaded=storage.migrateGame(structuredClone(next));
    cases.push({id,command,setup,before:domain(state),expected:domain(next),repeated:domain(repeated),loaded_after:domain(loaded),expected_source_utf16:sourceUnits(next),repeated_source_utf16:sourceUnits(repeated),loaded_source_utf16:sourceUnits(loaded)});
  };
  for(const id of planets){
    for(const role of roles)record('role-'+id+'-'+role,{kind:'role',target:id,value:role});
    record('role-repeat-'+id,{kind:'role',target:id,value:'power'},{roles:{[id]:'power'}});
    record('role-invalid-'+id,{kind:'role',target:id,value:'unknown_role'});
  }
  record('role-unknown',{kind:'role',target:'unknown_planet',value:'power'});
  const metadata=[
    ['basic',{customName:'  基地 A  ',note:'  采矿与冶炼  ',tags:[' 矿业 ','矿业','科研','']}],
    ['empty',{customName:'',note:'',tags:[]}],
    ['whitespace',{customName:' \t\n ',note:' \r\n ',tags:[' ','\t']}],
    ['unicode_space',{customName:'\u3000基地\u00a0',note:'\ufeff说明\u202f',tags:['\u3000标签\u3000']}],
    ['control_characters',{customName:'\u001f基地\u001f',note:'\u0001说明\u001b',tags:['\u001f','\u0001标签\u001f','\u001b','\u200b','\u0085','\u0001标签\u001f',' \u001f ']}],
    ['exact',{customName:'名'.repeat(32),note:'注'.repeat(240),tags:Array.from({length:8},(_,i)=>String(i)+'签'.repeat(15))}],
    ['overflow',{customName:'名'.repeat(33),note:'注'.repeat(241),tags:Array.from({length:10},(_,i)=>String(i)+'签'.repeat(17))}],
    ['truncated_duplicate',{customName:'重复',note:'',tags:['A'.repeat(16)+'1','A'.repeat(16)+'2',' B ','B','']}],
    ['emoji_even',{customName:'😀'.repeat(17),note:'🚀'.repeat(121),tags:['🌍'.repeat(9),'🌍'.repeat(8)]}],
    ['emoji_odd',{customName:'A'.repeat(31)+'😀',note:'A'.repeat(239)+'🚀',tags:['A'.repeat(15)+'🌍']}],
    ['emoji_collision',{customName:'截断碰撞',note:'',tags:['A'.repeat(15)+'😀','A'.repeat(15)+'🌍','A'.repeat(15)+'😀','A'.repeat(15)+'🚀']}],
    ['replacement_collision',{customName:'替代字符碰撞',note:'',tags:['A'.repeat(15)+'😀','A'.repeat(15)+'�','A'.repeat(15)+'🌍','A'.repeat(15)+'�']}],
    ['capped_collision',{customName:'原始标签上限',note:'',tags:['A'.repeat(15)+'😀','A'.repeat(15)+'🌍',...Array.from({length:8},(_,i)=>'标签'+i),'A'.repeat(15)+'😀']}],
    ['tags_only',{customName:'',note:'',tags:['资源','制造']}],
    ['note_only',{customName:'',note:'备忘',tags:[]}],
    ['non_string_tags',{customName:'混合标签',note:'',tags:[1,null,true,{},' 有效 ','有效']}],
  ];
  for(const id of planets)for(const [stage,value]of metadata){
    record('metadata-'+id+'-'+stage,{kind:'planetMetadata',target:id,value},{planetMetadata:{[id]:{customName:'原名称',note:'原说明',tags:['原标签']}}});
  }
  record('metadata-unknown',{kind:'planetMetadata',target:'unknown_planet',value:metadata[0][1]});
  const names=[['basic',' 新名称 '],['empty',''],['whitespace',' \t\n '],['unicode_space','\u3000星系\ufeff'],['control_characters','\u001f星系\u001f'],['exact','星'.repeat(32)],['overflow','星'.repeat(33)],['emoji_even','🌟'.repeat(17)],['emoji_odd','A'.repeat(31)+'🌟']];
  for(const id of systems)for(const [stage,value]of names)record('name-'+id+'-'+stage,{kind:'systemName',target:id,value},{systemMetadata:{[id]:{customName:'原星系'}}});
  record('name-unknown',{kind:'systemName',target:'unknown_system',value:'新名称'});
  const limits=[['minimum',1000],['maximum',100000000],['fractional',1000.9],['too_low',999],['negative',-1],['zero',0],['too_high',100000001],['repeat',1000000],['nonfinite','Infinity'],['nan','NaN'],['negative_infinity','-Infinity']];
  for(const id of planets)for(const [stage,value]of limits)record('limit-'+id+'-'+stage,{kind:'limit',target:id,value});
  record('limit-unknown',{kind:'limit',target:'unknown_planet',value:2000});
  writeFrozenFixture(runtime,'task27-world-controls.json',{
    scope:'Actual immutable source industrial-role, planet/system display metadata and tray-limit commands with repeated results and actual storage migration. All 22 planets, 8 systems, 8 roles; source text trimming/truncation, tag normalization/deduplication, clearing, unknown targets and finite/nonfinite capacity boundaries. Metadata portable projection replaces unpaired UTF16 units with U+FFFD for valid local Unicode, matching their visible browser representation; exact original source UTF16 units, including odd-cut unpaired surrogates, are retained separately for next/repeated/source-storage states. This is an explicit representation adaptation, not raw string identity or DSPONLINE save import. State is controlled fresh seed 240721; not exploration, colonization, physical travel or full growth evidence. Nonfinite inputs are explicit string tags restored before source invocation.',
    representation_adaptation:'Only unpaired UTF16 source units become U+FFFD in portable metadata; original units remain in *_source_utf16 fields.',
    planets,systems,roles,metadata_stages:metadata.map(row=>row[0]),name_stages:names.map(row=>row[0]),limit_stages:limits.map(row=>row[0]),cases,
  });
  console.log('TASK27 WORLD CONTROL GOLD: '+cases.length+' actual immutable commands and repeated/migrated states');
}finally{runtime.close();}
