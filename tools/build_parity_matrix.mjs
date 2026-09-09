import {taskFor} from './parity_task_ownership.mjs';
import {readFileSync,writeFileSync,readdirSync,existsSync} from 'node:fs';
import {resolve} from 'node:path';
const root=resolve(import.meta.dirname,'..'),dir=resolve(root,'tests/fixtures/parity');
const snapshot=JSON.parse(readFileSync(resolve(dir,'dsponline_source_catalog.json'),'utf8'));
const target={items:{},recipes:{},buildings:{},technologies:{},campaign:{},achievements:{}};
for(const f of readdirSync(resolve(root,'data')).filter(f=>f.endsWith('.json')).sort()){
 const data=JSON.parse(readFileSync(resolve(root,'data',f),'utf8'));
 for(const k of ['items','recipes','buildings','technologies'])Object.assign(target[k],data[k]||{});
 for(const [k,field] of [['campaign','objectives'],['achievements','achievements']])for(const row of data[field]||[])target[k][row.id]=row;
}
const ui={BlueprintWorkspace:'scenes/ui/BlueprintWorkspace.gd',CampaignWorkspace:'scenes/ui/CampaignWorkspace.gd',DysonPlannerWorkspace:'scenes/ui/DysonPanel.gd',OfflineReportWorkspace:'scenes/ui/OfflineReportWorkspace.gd',OperationsWorkspace:'scenes/ui/SettingsWorkspace.gd',RecipeWorkspace:'scenes/ui/CodexWorkspace.gd',StarMapWorkspace:'scenes/ui/GalaxyMap.gd',StatisticsWorkspace:'scenes/ui/StatsPanel.gd',TechnologyWorkspace:'scenes/ui/TechnologyPanel.gd',TutorialWorkspace:'scenes/ui/TutorialOverlay.gd'};
const symbols={};
for(const folder of ['scripts/game','scripts/input','autoload'])for(const f of readdirSync(resolve(root,folder)).filter(f=>f.endsWith('.gd'))){const text=readFileSync(resolve(root,folder,f),'utf8');for(const m of text.matchAll(/^func (\w+)\(/gm))(symbols[m[1]]??=[]).push(folder+'/'+f+'::'+m[1]);}
const sourceUi={items:'RecipeWorkspace',recipes:'RecipeWorkspace',buildings:'RecipeWorkspace',technologies:'TechnologyWorkspace',campaign:'CampaignWorkspace',achievements:'CampaignWorkspace',difficulties:'OperationsWorkspace',matrices:'TechnologyWorkspace',construction:'ConstructionCenterWorkspace',proliferators:'RecipeWorkspace',belts:'RecipeWorkspace',modes:'OperationsWorkspace'};
const rows=[],rules={},online={},scope={};
for(const [category,entries] of Object.entries(snapshot.catalog))for(const entry of entries){
 const key=category+':'+entry.id;
 if(['commands','workspaces'].includes(category)&&/Mobile|Touch|Language|Locale/.test(entry.id)){scope[key]={reason:'用户明确只做电脑中文版本',policy:'desktop_chinese_only'};continue;}
 const excluded=category==='workspaces'&&entry.id==='GalaxyWorkspace'||category==='commands'&&(/^(Cloud|GalaxyWorkspace\.)/.test(entry.id));
 if(excluded)online[key]={reason:'账号、云存档或公共银河网络入口，不属于单机范围'};
 let targetCategory=category,targetIds=[];
 if(category==='matrices'){targetCategory='items';if(target.items[entry.id])targetIds=[entry.id];}
 else if(category==='construction'){targetCategory='buildings';if(target.buildings[entry.id])targetIds=[entry.id];}
 else if(target[category]?.[entry.id])targetIds=[entry.id];
 else if(category==='recipes'&&target.recipes[entry.id+'_recipe'])targetIds=[entry.id+'_recipe'];
 else if(category==='workspaces'&&ui[entry.id]&&existsSync(resolve(root,ui[entry.id]))){targetCategory='file';targetIds=[ui[entry.id]];}
 if(category==='commands'&&entry.id.startsWith('engine.')){const snake=entry.id.slice(7).replace(/[A-Z]/g,c=>'_'+c.toLowerCase());if(symbols[snake]){targetCategory='symbol';targetIds=symbols[snake];}}
 const owner=taskFor(category,entry.id),status=excluded?'在线排除':targetIds.length?'实现中':'未实现';
 const rule='rule:'+key,manual='manual:'+key;
 rules[rule]={source_key:key,kind:excluded?'online_exclusion':'pending_behavior',owner_task:owner,acceptance:['来源定义及 ID 必须存在','候选映射必须存在或明确登记缺口','同初始输入与命令序列验证数值、守恒、UI 与保存恢复；任务 27 验收前完成'],behavior_verified:false};
 rows.push({key,category,source_id:entry.id,name:entry.name,status,target:{category:targetCategory,ids:targetIds},gap:excluded?online[key].reason:targetIds.length?'已有候选；源数值、约束、效果和操作尚未逐项对比验证':'无已确认对应项，需实现或明确映射后验证',owner_task:owner,rule_test:rule,manual_acceptance:manual,ui_entry:sourceUi[category]?`src/components/${sourceUi[category]}.tsx`:entry.source.file,supporting_tests:[],source_definition:key});
}
const manifest={format_version:1,source_commit:snapshot.source.commit,source_catalog:'dsponline_source_catalog.json',scope:'desktop Chinese offline; no DSPONLINE save import',entries:rows};
writeFileSync(resolve(dir,'dsponline_single_player_manifest.json'),JSON.stringify(manifest,null,2)+'\n');
writeFileSync(resolve(dir,'rule_cases.json'),JSON.stringify(rules,null,2)+'\n');
writeFileSync(resolve(dir,'exclusions.json'),JSON.stringify({online,scope},null,2)+'\n');
const counts={};for(const row of rows)counts[row.status]=(counts[row.status]||0)+1;
let doc=`# DSPONLINE 单机对齐清单\n\n源版本 ${snapshot.source.version}，提交 \`${snapshot.source.commit}\`，工作区干净。固定文件 SHA-256 与完整数据定义见 [冻结目录](../tests/fixtures/parity/dsponline_source_catalog.json)。\n\n## 如何阅读\n\n此表是任务 19 的差距登记，不是玩法已经对齐的证明。现有系统仍可使用；“实现中”只表示存在候选映射，未逐项验证原版数值和行为。登记门允许明确登记的缺口，最终发布门必须清零未实现/实现中。\n\n状态统计：${JSON.stringify(counts)}。没有把同名条目自动标为已验证。\n\n完整来源定义保存输入输出、数值、前置、解锁、奖励和目录规则；成就判定等代码规则记录源文件及哈希，行为验证仍待任务 25/27。每行的自动规则编号为 rule:类别:源ID，人工编号为 manual:类别:源ID；规则规格见 [rule_cases.json](../tests/fixtures/parity/rule_cases.json)，规格登记不等于已执行行为测试。UI 栏为原版入口/定义来源，当前候选路径和缺口见 [机器清单](../tests/fixtures/parity/dsponline_single_player_manifest.json)。\n\n## 源目录规模\n\n| 类别 | 冻结数量 |\n|---|---:|\n`;
for(const [k,n] of Object.entries(snapshot.counts))doc+=`| ${k} | ${n} |\n`;
doc+=`\n科技含 69 项有效定义和 7 项 deprecated 旧定义，保留旧定义以追踪兼容规则；不把它们算成 76 项可研究科技。旧路线图的 78 配方/37 建筑/67 科技已过时，本次按实际源代码冻结。\n\n操作清单覆盖根目录桌面组件显式 onX 回调契约、engine.ts 首参为 GameState 的公开操作/查询及命令面板动态条目族；包含辅助 UI 回调，不能把条目数量当作独立玩法数量。移动/语言回调单独按用户范围排除；在线排除使用固定逐项白名单，不以关键词在运行时自动放行。\n\n## 逐项矩阵\n\n`;
for(const category of Object.keys(snapshot.catalog)){
 doc+=`### ${category}\n\n| 源 ID | 名称 | 当前候选 ID/文件 | 状态 | 后续任务 | 来源/UI |\n|---|---|---|---|---:|---|\n`;
 for(const row of rows.filter(r=>r.category===category))doc+=`| ${row.source_id.replaceAll('|','\\|')} | ${row.name.replaceAll('|','\\|')} | ${row.target.ids.join(', ')||'待映射'} | ${row.status} | ${row.owner_task} | ${row.ui_entry} |\n`;
 doc+='\n';
}
doc+='## 排除与许可\n\n固定在线与用户范围排除条目见 [exclusions.json](../tests/fixtures/parity/exclusions.json)，每项均有理由。账号、云、公共银河网络不实现；手机、国际化和 DSPONLINE 旧存档导入不在范围内。\n\n来源数据：Copyright 2026 snowsnow0926，PolyForm Noncommercial 1.0.0。仅冻结目录和操作标识，不复制原版实现、素材或玩家数据；原始许可与来源说明见 [来源说明](../tests/fixtures/parity/NOTICE.md)。\n';
writeFileSync(resolve(root,'docs/CONTENT_PARITY.md'),doc);
console.log({rows:rows.length,statuses:counts,online:Object.keys(online).length,scope:Object.keys(scope).length});
