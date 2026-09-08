import {readFileSync, writeFileSync, readdirSync, mkdirSync} from 'node:fs';
import {resolve, relative} from 'node:path';
import {createHash} from 'node:crypto';

import {stripTypeScriptTypes} from 'node:module';
const repo=resolve(import.meta.dirname,'..');
const source=resolve(process.argv[2]||resolve(repo,'../DSPONLINE'));
const dest=resolve(repo,'tests/fixtures/parity');
const commit=process.argv[3];
if(!/^[a-f0-9]{40}$/.test(commit||''))throw Error('Use export_dsponline_parity.ps1 to verify source revision.');
const hash=x=>createHash('sha256').update(x).digest('hex');
const files={};
function read(path){const b=readFileSync(resolve(source,path));files[path]=hash(b);return b.toString('utf8');}
const urls={};
async function load(name){let text=stripTypeScriptTypes(read(`src/game/${name}.ts`));if(name!=='content')text=text.replaceAll('"./content"',JSON.stringify(urls.content));urls[name]='data:text/javascript;base64,'+Buffer.from(text).toString('base64');return import(urls[name]);}
const c=await load('content'),p=await load('campaign'),a=await load('progression'),d=await load('difficulty');
const catalog={};
function add(category,values,file,symbol){catalog[category]=Object.values(values).map(value=>{const id=String(value.id??value.buildingId);const text=read(file);const begin=Math.max(0,text.indexOf(`export const ${symbol}`));const pos=text.indexOf(`${category==="construction"?"buildingId":"id"}: "${id}"`,begin);return {id,name:value.name||value.title||id,definition:JSON.parse(JSON.stringify(value,(_k,v)=>typeof v==='function'?{predicate:'source-defined; behavior test pending'}:v)),source:{file,symbol,line:pos<0?1:text.slice(0,pos).split('\n').length}};});}
add('items',c.ITEMS,'src/game/content.ts','ITEMS');add('recipes',c.RECIPES,'src/game/content.ts','RECIPES');add('buildings',c.BUILDINGS,'src/game/content.ts','BUILDINGS');
add('technologies',Object.values(c.TECHNOLOGIES).map(t=>({...t,deprecated:c.DEPRECATED_TECHNOLOGY_IDS.has(t.id)})),'src/game/content.ts','TECHNOLOGIES');
add('campaign',p.CAMPAIGN_TASKS,'src/game/campaign.ts','CAMPAIGN_TASKS');add('achievements',a.ACHIEVEMENTS,'src/game/progression.ts','ACHIEVEMENTS');add('difficulties',d.DIFFICULTY_DEFINITIONS,'src/game/difficulty.ts','DIFFICULTY_DEFINITIONS');
add('matrices',c.MATRIX_ITEM_IDS.map(id=>c.ITEMS[id]),'src/game/content.ts','MATRIX_ITEM_IDS');
add('belts',c.getBeltTiers().map(t=>({id:c.getBeltConstructionId(t),tier:t,speed:c.getBeltSpeed(t)})),'src/game/content.ts','getBeltTiers');
add('construction',c.CONSTRUCTION,'src/game/content.ts','CONSTRUCTION');
add('proliferators',Object.values(c.PROLIFERATORS).map(t=>({...t,id:t.itemId})),'src/game/content.ts','PROLIFERATORS');
// Public desktop callback contracts are inventoried separately from behavior.
const componentFiles=readdirSync(resolve(source,'src/components')).filter(f=>f.endsWith('.tsx')&&!f.includes('.test.')).sort();
catalog.workspaces=[];catalog.commands=[];
for(const file of componentFiles){
 const path='src/components/'+file;const text=read(path);
 if(/Workspace\.tsx$/.test(file)&&file!=='WorkspaceFrame.tsx')catalog.workspaces.push({id:file.slice(0,-4),name:file.slice(0,-4),definition:{entry_component:file,scope:'desktop'},source:{file:path,line:1,symbol:file.slice(0,-4)}});
 const found=new Set();
 for(const match of text.matchAll(/\b(on[A-Z]\w+)\??\s*:\s*\(/g)){
  if(found.has(match[1]))continue;found.add(match[1]);
  catalog.commands.push({id:file.slice(0,-4)+'.'+match[1],name:match[1],definition:{kind:'desktop_callback',entry_component:file,callback:match[1]},source:{file:path,line:text.slice(0,match.index).split('\n').length,symbol:match[1]}});
 }
}
const engine=read('src/game/engine.ts');
for(const match of engine.matchAll(/export function (\w+)\(\s*state:\s*GameState\b/g))catalog.commands.push({id:'engine.'+match[1],name:match[1],definition:{kind:'state_command_or_query',function:match[1]},source:{file:'src/game/engine.ts',line:engine.slice(0,match.index).split('\n').length,symbol:match[1]}});
const palette=read('src/components/CommandPalette.tsx');
for(const id of ['recipe:{item_id}','entity:{entity_id}'])catalog.commands.push({id:'palette.'+id,name:id,definition:{kind:'dynamic_command_family',enumeration:'per current item/entity'},source:{file:'src/components/CommandPalette.tsx',line:1,symbol:'OpenCommandPalette'}});
for(const [id,name,file] of [['normal','标准单机','src/game/types.ts'],['speedrun','速通','src/game/types.ts'],['time_warp','时间扭曲','src/game/engine.ts'],['pure_idle','纯挂机推进','src/game/pureIdleMacro.ts']]){
 try{read(file);}catch{if(id==='pure_idle')continue;throw Error(file);}
 (catalog.modes??=[]).push({id,name,definition:{rule_source:file},source:{file,line:1,symbol:id}});
}
for(const entries of Object.values(catalog))entries.sort((a,b)=>a.id.localeCompare(b.id,'en'));
for(const [category,entries] of Object.entries(catalog)){if(entries.some(e=>e.id==='undefined')||new Set(entries.map(e=>e.id)).size!==entries.length)throw Error('Invalid/duplicate ID: '+category);}
const snapshot={format_version:1,source:{project:'DSPONLINE',commit,version:JSON.parse(read('package.json')).version,clean:true,license:'PolyForm-Noncommercial-1.0.0',notice:'Copyright 2026 snowsnow0926. Commercial use requires a separate written license from the licensor.',files},counts:Object.fromEntries(Object.entries(catalog).map(([k,v])=>[k,v.length])),catalog};
mkdirSync(dest,{recursive:true});const json=JSON.stringify(snapshot,null,2)+'\n';writeFileSync(resolve(dest,'dsponline_source_catalog.json'),json);writeFileSync(resolve(dest,'dsponline_source_catalog.sha256'),hash(json)+'\n');
console.log(JSON.stringify(snapshot.counts));
