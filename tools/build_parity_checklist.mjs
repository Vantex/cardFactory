import fs from 'node:fs';
import path from 'node:path';
import assert from 'node:assert/strict';

const root = path.resolve(import.meta.dirname, '..');
const read = file => JSON.parse(fs.readFileSync(path.join(root, file), 'utf8'));
const manifest = read('tests/fixtures/parity/dsponline_single_player_manifest.json');
const source = read('tests/fixtures/parity/dsponline_source_catalog.json');
const review = read('tests/fixtures/parity/coverage_review.json');
assert.equal(review.source_commit, manifest.source_commit);
const sourceRows = new Map(Object.entries(source.catalog).flatMap(([category, rows]) => rows.map(row => [`${category}:${row.id}`, row])));
const counts = {};
const categories = {};
for (const row of manifest.entries) {
  counts[row.status] = (counts[row.status] ?? 0) + 1;
  const group = categories[row.category] ??= { total: 0, verified: 0, candidate: 0, unmapped: 0, online: 0 };
  group.total++;
  group[{ '已验证': 'verified', '实现中': 'candidate', '未实现': 'unmapped', '在线排除': 'online' }[row.status]]++;
}
const cell = value => String(value).replaceAll('|', '\\|').replaceAll('\n', ' ');
const batches = {
  B1: '资源与开局', B2: '工厂成长', B3: '多行星物流',
  B4: '终局系统', B5: '模式与恢复',
};
// First-pass scheduling only. Assignment never confirms a mapping or grants evidence.
const batchFor = row => {
  const id = row.source_id;
  const name = row.key;
  if (['modes', 'difficulties'].includes(row.category)) return 'B5';
  if (/Dyson|Ejector|Galactic|SystemSpaceStation|SystemSpaceElevator|SystemHub|BlackHole|dyson|ejector|galactic|space_station|space_elevator|system_hub|black_hole/.test(name)) return 'B4';
  if (/Quantum|Orbital|Station|Remote|Interstellar|StarMap|Logistics|Collector|CargoPort|quantum|orbital|station|interstellar|collector|cargo_port/.test(name)) return 'B3';
  if (/Simulation|TimeWarp|Idle|Speedrun|Save|Snapshot|Recovery|ContentPack|Settings|StartMenu|PauseMenu|AccessibleDialog|Device|updateGameState|setPaused|advanceSimulation|simulation|time_warp/.test(name)) return 'B5';
  if (/manualMine|installMiner|getResourceReserveSnapshot|onInstallMiner|onPickOutput|onOpenResources|onOpenResourceSettings|onPickTray|TrayManagement|TrayItem|TrayItems|moveEntity(Input|Output)To|moveTrayItemToEntity|pickFrom|dropCargo/.test(name)) return 'B1';
  if (row.category === 'items' && ['iron_ore', 'copper_ore', 'stone', 'coal', 'silicon_ore', 'titanium_ore', 'crude_oil', 'water', 'sulfuric_acid', 'kimberlite_ore', 'fractal_silicon', 'organic_crystal', 'optical_grating_crystal', 'spiniform_stalagmite_crystal', 'unipolar_magnet', 'fire_ice'].includes(id)) return 'B1';
  if (row.category === 'buildings' && ['mining_machine', 'water_pump', 'oil_extractor'].includes(id)) return 'B1';
  return 'B2';
};
const pending = manifest.entries.filter(row => ['实现中', '未实现'].includes(row.status));
const grouped = Object.fromEntries(Object.keys(batches).map(id => [id, pending.filter(row => batchFor(row) === id)]));
assert.equal(Object.values(grouped).reduce((sum, rows) => sum + rows.length, 0), pending.length);
let doc = `# DSPONLINE 逐项行为验收台账\n\n来源提交 \`${manifest.source_commit}\`；共 ${manifest.entries.length} 条登记。状态：${Object.entries(counts).map(([name, count]) => `${name} ${count}`).join('，')}。\n\n本文件由 \`node tools/build_parity_checklist.mjs\` 从既有 manifest 和人工复核记录生成；工具只生成台账，不改候选映射、不执行测试、不授予“已验证”。没有候选映射的回调保持“待逐项核实”，不得按名字相似推断功能存在或缺失。\n\n实际发布测试由 \`TestDSPOnlineParity\` 运行 \`ParityBehaviorRunner\`，每个通过 key 都有具体断言和冻结夹具绑定；矩阵标记不能替代运行证据。自动 UI 与完整人工旅程分开登记。\n\n## 分类统计\n\n| 类别 | 总数 | 已验证 | 候选 | 待映射 | 在线排除 |\n|---|---:|---:|---:|---:|---:|\n`;
for (const [category, group] of Object.entries(categories)) doc += `| ${category} | ${group.total} | ${group.verified} | ${group.candidate} | ${group.unmapped} | ${group.online} |\n`;
doc += '\n## 当前工作批次\n\n按已采用的 [任务 27 工作流](../current/TASK27_WORKFLOW_PROPOSAL.md) 对全部待验收条目进行第一遍归组。归组只是执行安排；实际源契约、候选映射和证明仍在进入该批时核实。跨领域条目可随契约分析调整归属。B6 负责最终发布条件，不吸收未验收条目。\n\n| 批次 | 范围 | 内容定义 | 命令/回调 | 工作区 | 待验收合计 |\n|---|---|---:|---:|---:|---:|\n';
for (const [id, rows] of Object.entries(grouped)) {
  const commands = rows.filter(row => row.category === 'commands').length;
  const workspaces = rows.filter(row => row.category === 'workspaces').length;
  doc += `| ${id} | ${batches[id]} | ${rows.length - commands - workspaces} | ${commands} | ${workspaces} | ${rows.length} |\n`;
}
doc += `\n待验收 ${pending.length} 项均已归组，未改变任何验证状态。当前实施 B1；优先收口已有资源输出候选，再按具体契约核实领取、运输、施工和 UI 回调。\n`;
doc += '\n## 已核实差异\n\n';
for (const [key, detail] of Object.entries(review.reviews)) {
  assert.ok(manifest.entries.some(row => row.key === key), `Unknown review key: ${key}`);
  doc += `- \`${key}\`：${detail.classification}。${detail.finding} 候选：${detail.candidates.map(file => `[${file}](../../${file})`).join('、')}。\n`;
}
for (const category of Object.keys(categories)) {
  doc += `\n## ${category}\n\n| key | 批次 | 状态/复核 | 源位置 | 当前映射 | 自动/人工编号 |\n|---|---|---|---|---|---|\n`;
  for (const row of manifest.entries.filter(entry => entry.category === category)) {
    const definition = sourceRows.get(row.key);
    assert.ok(definition, `Missing source: ${row.key}`);
    const detail = review.reviews[row.key];
    const classification = row.status === '已验证' ? '当前行为证据已绑定' : row.status === '在线排除' ? '固定在线白名单' : detail?.classification ?? (row.target.ids.length ? '候选待源行为比较' : '待逐项核实/映射');
    const location = `${definition.source.file}:${definition.source.line ?? '?'}`;
    const target = row.target.ids.length ? row.target.ids.join(', ') : '尚未确认';
    const batch = ['实现中', '未实现'].includes(row.status) ? batchFor(row) : '—';
    doc += `| ${cell(row.key)} | ${batch} | ${cell(`${row.status}；${classification}`)} | ${cell(location)} | ${cell(target)} | ${cell(`${row.rule_test} / ${row.manual_acceptance}`)} |\n`;
  }
}
fs.mkdirSync(path.join(root, 'docs/testing'), { recursive: true });
fs.writeFileSync(path.join(root, 'docs/testing/dsponline-parity-checklist.md'), doc);
console.log(`PARITY CHECKLIST GENERATED: ${manifest.entries.length} rows; mappings and verification unchanged`);
