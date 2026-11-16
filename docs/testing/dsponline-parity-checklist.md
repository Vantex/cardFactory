# DSPONLINE 逐项行为验收台账

来源提交 `472bf62c76b695852b5577e563c1d113192ac731`；共 1099 条登记。状态：实现中 514，已验证 262，在线排除 26，未实现 297。

本文件由 `node tools/build_parity_checklist.mjs` 从既有 manifest 和人工复核记录生成；工具只生成台账，不改候选映射、不执行测试、不授予“已验证”。没有候选映射的回调保持“待逐项核实”，不得按名字相似推断功能存在或缺失。

实际发布测试由 `TestDSPOnlineParity` 运行 `ParityBehaviorRunner`，每个通过 key 都有具体断言和冻结夹具绑定；矩阵标记不能替代运行证据。自动 UI 与完整人工旅程分开登记。

## 分类统计

| 类别 | 总数 | 已验证 | 候选 | 待映射 | 在线排除 |
|---|---:|---:|---:|---:|---:|
| items | 78 | 0 | 78 | 0 | 0 |
| recipes | 80 | 80 | 0 | 0 | 0 |
| buildings | 39 | 0 | 39 | 0 | 0 |
| technologies | 76 | 76 | 0 | 0 | 0 |
| campaign | 32 | 32 | 0 | 0 | 0 |
| achievements | 13 | 13 | 0 | 0 | 0 |
| difficulties | 3 | 0 | 3 | 0 | 0 |
| matrices | 6 | 0 | 6 | 0 | 0 |
| belts | 3 | 3 | 0 | 0 | 0 |
| construction | 42 | 0 | 42 | 0 | 0 |
| proliferators | 3 | 0 | 3 | 0 | 0 |
| workspaces | 14 | 1 | 11 | 1 | 1 |
| commands | 706 | 57 | 328 | 296 | 25 |
| modes | 4 | 0 | 4 | 0 | 0 |

## 当前工作批次

按已采用的 [任务 27 工作流](../current/TASK27_WORKFLOW_PROPOSAL.md) 对全部待验收条目进行第一遍归组。归组只是执行安排；实际源契约、候选映射和证明仍在进入该批时核实。跨领域条目可随契约分析调整归属。B6 负责最终发布条件，不吸收未验收条目。

| 批次 | 范围 | 内容定义 | 命令/回调 | 工作区 | 待验收合计 |
|---|---|---:|---:|---:|---:|
| B1 | 资源与开局 | 19 | 21 | 0 | 40 |
| B2 | 工厂成长 | 125 | 372 | 8 | 505 |
| B3 | 多行星物流 | 13 | 106 | 2 | 121 |
| B4 | 终局系统 | 9 | 70 | 2 | 81 |
| B5 | 模式与恢复 | 9 | 55 | 0 | 64 |

待验收 811 项均已归组，未改变任何验证状态。当前实施 B1；优先收口已有资源输出候选，再按具体契约核实领取、运输、施工和 UI 回调。

## 已核实差异

- `workspaces:StatisticsWorkspace`：部分能力存在，完整契约待补。源工作区含 management/production/efficiency/networks/planning/power/issues/galaxy 八页；当前分析入口含统计、诊断、资料库和计划。计划已有 8 计算/8 命令、4 个具体回调与内容包受控金标，全部网络管理、其他页面和跨工作区回调尚未核实。保留整体未实现状态。 候选：`scenes/ui/CodexWorkspace.gd`（本地开发树）、[scenes/ui/StatisticsPanel.gd](../../scenes/ui/StatisticsPanel.gd)、`scenes/ui/ProductionPlanningPanel.gd`（本地开发树）。
- `modes:normal`：开局经济已修复并通过专项，完整模式仍待验证。新游戏现采用源原矿各 100 和源施工件，普通/速通 × 三档难度的库存及磁盘保存专项通过；原矿到三枚蓝矩阵和首项研究的自动旅程通过。完整模式、全成长链及人工旅程仍未验收，保留候选状态。 候选：[autoload/GameManager.gd](../../autoload/GameManager.gd)、[scripts/game/GameState.gd](../../scripts/game/GameState.gd)。
- `technologies:basic_logistics`：施工件奖励已修复并通过边界专项，完整科技仍待验证。现按源首次完成奖励各 2 件并防止重复发放，排除巨构件；全部 76 个定义的奖励/解锁行星边界和保存专项通过。这些检查直接调用完成边界，不能证明全部科技的前置条件、研究投入和正式入口已通过，保留候选状态。 候选：[scripts/game/TechnologySystem.gd](../../scripts/game/TechnologySystem.gd)。

## items

| key | 批次 | 状态/复核 | 源位置 | 当前映射 | 自动/人工编号 |
|---|---|---|---|---|---|
| items:accumulator | B2 | 实现中；候选待源行为比较 | src/game/content.ts:290 | accumulator | rule:items:accumulator / manual:items:accumulator |
| items:annihilation_constraint_sphere | B2 | 实现中；候选待源行为比较 | src/game/content.ts:316 | annihilation_constraint_sphere | rule:items:annihilation_constraint_sphere / manual:items:annihilation_constraint_sphere |
| items:antimatter | B2 | 实现中；候选待源行为比较 | src/game/content.ts:315 | antimatter | rule:items:antimatter / manual:items:antimatter |
| items:antimatter_fuel_rod | B2 | 实现中；候选待源行为比较 | src/game/content.ts:317 | antimatter_fuel_rod | rule:items:antimatter_fuel_rod / manual:items:antimatter_fuel_rod |
| items:carbon_nanotube | B2 | 实现中；候选待源行为比较 | src/game/content.ts:293 | carbon_nanotube | rule:items:carbon_nanotube / manual:items:carbon_nanotube |
| items:casimir_crystal | B2 | 实现中；候选待源行为比较 | src/game/content.ts:307 | casimir_crystal | rule:items:casimir_crystal / manual:items:casimir_crystal |
| items:charged_accumulator | B2 | 实现中；候选待源行为比较 | src/game/content.ts:291 | charged_accumulator | rule:items:charged_accumulator / manual:items:charged_accumulator |
| items:circuit_board | B2 | 实现中；候选待源行为比较 | src/game/content.ts:276 | circuit_board | rule:items:circuit_board / manual:items:circuit_board |
| items:coal | B1 | 实现中；候选待源行为比较 | src/game/content.ts:255 | coal | rule:items:coal / manual:items:coal |
| items:copper_ingot | B2 | 实现中；候选待源行为比较 | src/game/content.ts:269 | copper_ingot | rule:items:copper_ingot / manual:items:copper_ingot |
| items:copper_ore | B1 | 实现中；候选待源行为比较 | src/game/content.ts:254 | copper_ore | rule:items:copper_ore / manual:items:copper_ore |
| items:critical_photon | B2 | 实现中；候选待源行为比较 | src/game/content.ts:314 | critical_photon | rule:items:critical_photon / manual:items:critical_photon |
| items:crude_oil | B1 | 实现中；候选待源行为比较 | src/game/content.ts:257 | crude_oil | rule:items:crude_oil / manual:items:crude_oil |
| items:crystal_silicon | B2 | 实现中；候选待源行为比较 | src/game/content.ts:297 | crystal_silicon | rule:items:crystal_silicon / manual:items:crystal_silicon |
| items:deuterium | B2 | 实现中；候选待源行为比较 | src/game/content.ts:303 | deuterium | rule:items:deuterium / manual:items:deuterium |
| items:deuteron_fuel_rod | B2 | 实现中；候选待源行为比较 | src/game/content.ts:305 | deuteron_fuel_rod | rule:items:deuteron_fuel_rod / manual:items:deuteron_fuel_rod |
| items:diamond | B2 | 实现中；候选待源行为比较 | src/game/content.ts:321 | diamond | rule:items:diamond / manual:items:diamond |
| items:dyson_sphere_component | B4 | 实现中；候选待源行为比较 | src/game/content.ts:319 | dyson_sphere_component | rule:items:dyson_sphere_component / manual:items:dyson_sphere_component |
| items:electric_motor | B2 | 实现中；候选待源行为比较 | src/game/content.ts:299 | electric_motor | rule:items:electric_motor / manual:items:electric_motor |
| items:electromagnetic_matrix | B2 | 实现中；候选待源行为比较 | src/game/content.ts:325 | electromagnetic_matrix | rule:items:electromagnetic_matrix / manual:items:electromagnetic_matrix |
| items:electromagnetic_turbine | B2 | 实现中；候选待源行为比较 | src/game/content.ts:300 | electromagnetic_turbine | rule:items:electromagnetic_turbine / manual:items:electromagnetic_turbine |
| items:energetic_graphite | B2 | 实现中；候选待源行为比较 | src/game/content.ts:279 | energetic_graphite | rule:items:energetic_graphite / manual:items:energetic_graphite |
| items:energy_matrix | B2 | 实现中；候选待源行为比较 | src/game/content.ts:326 | energy_matrix | rule:items:energy_matrix / manual:items:energy_matrix |
| items:fire_ice | B1 | 实现中；候选待源行为比较 | src/game/content.ts:260 | fire_ice | rule:items:fire_ice / manual:items:fire_ice |
| items:fractal_silicon | B1 | 实现中；候选待源行为比较 | src/game/content.ts:262 | fractal_silicon | rule:items:fractal_silicon / manual:items:fractal_silicon |
| items:frame_material | B2 | 实现中；候选待源行为比较 | src/game/content.ts:318 | frame_material | rule:items:frame_material / manual:items:frame_material |
| items:gear | B2 | 实现中；候选待源行为比较 | src/game/content.ts:274 | gear | rule:items:gear / manual:items:gear |
| items:glass | B2 | 实现中；候选待源行为比较 | src/game/content.ts:272 | glass | rule:items:glass / manual:items:glass |
| items:graphene | B2 | 实现中；候选待源行为比较 | src/game/content.ts:292 | graphene | rule:items:graphene / manual:items:graphene |
| items:graviton_lens | B2 | 实现中；候选待源行为比较 | src/game/content.ts:311 | graviton_lens | rule:items:graviton_lens / manual:items:graviton_lens |
| items:gravity_matrix | B2 | 实现中；候选待源行为比较 | src/game/content.ts:329 | gravity_matrix | rule:items:gravity_matrix / manual:items:gravity_matrix |
| items:high_purity_silicon | B2 | 实现中；候选待源行为比较 | src/game/content.ts:282 | high_purity_silicon | rule:items:high_purity_silicon / manual:items:high_purity_silicon |
| items:hydrogen | B2 | 实现中；候选待源行为比较 | src/game/content.ts:281 | hydrogen | rule:items:hydrogen / manual:items:hydrogen |
| items:hydrogen_fuel_rod | B2 | 实现中；候选待源行为比较 | src/game/content.ts:304 | hydrogen_fuel_rod | rule:items:hydrogen_fuel_rod / manual:items:hydrogen_fuel_rod |
| items:information_matrix | B2 | 实现中；候选待源行为比较 | src/game/content.ts:328 | information_matrix | rule:items:information_matrix / manual:items:information_matrix |
| items:iron_ingot | B2 | 实现中；候选待源行为比较 | src/game/content.ts:268 | iron_ingot | rule:items:iron_ingot / manual:items:iron_ingot |
| items:iron_ore | B1 | 实现中；候选待源行为比较 | src/game/content.ts:253 | iron_ore | rule:items:iron_ore / manual:items:iron_ore |
| items:kimberlite_ore | B1 | 实现中；候选待源行为比较 | src/game/content.ts:261 | kimberlite_ore | rule:items:kimberlite_ore / manual:items:kimberlite_ore |
| items:logistics_drone | B2 | 实现中；候选待源行为比较 | src/game/content.ts:287 | logistics_drone | rule:items:logistics_drone / manual:items:logistics_drone |
| items:logistics_vessel | B2 | 实现中；候选待源行为比较 | src/game/content.ts:288 | logistics_vessel | rule:items:logistics_vessel / manual:items:logistics_vessel |
| items:magnet | B2 | 实现中；候选待源行为比较 | src/game/content.ts:270 | magnet | rule:items:magnet / manual:items:magnet |
| items:magnetic_coil | B2 | 实现中；候选待源行为比较 | src/game/content.ts:275 | magnetic_coil | rule:items:magnetic_coil / manual:items:magnetic_coil |
| items:microcrystalline_component | B2 | 实现中；候选待源行为比较 | src/game/content.ts:285 | microcrystalline_component | rule:items:microcrystalline_component / manual:items:microcrystalline_component |
| items:optical_grating_crystal | B1 | 实现中；候选待源行为比较 | src/game/content.ts:263 | optical_grating_crystal | rule:items:optical_grating_crystal / manual:items:optical_grating_crystal |
| items:organic_crystal | B1 | 实现中；候选待源行为比较 | src/game/content.ts:323 | organic_crystal | rule:items:organic_crystal / manual:items:organic_crystal |
| items:particle_broadband | B2 | 实现中；候选待源行为比较 | src/game/content.ts:298 | particle_broadband | rule:items:particle_broadband / manual:items:particle_broadband |
| items:particle_container | B2 | 实现中；候选待源行为比较 | src/game/content.ts:302 | particle_container | rule:items:particle_container / manual:items:particle_container |
| items:photon_combiner | B2 | 实现中；候选待源行为比较 | src/game/content.ts:312 | photon_combiner | rule:items:photon_combiner / manual:items:photon_combiner |
| items:plane_filter | B2 | 实现中；候选待源行为比较 | src/game/content.ts:308 | plane_filter | rule:items:plane_filter / manual:items:plane_filter |
| items:plasma_exciter | B2 | 实现中；候选待源行为比较 | src/game/content.ts:278 | plasma_exciter | rule:items:plasma_exciter / manual:items:plasma_exciter |
| items:plastic | B2 | 实现中；候选待源行为比较 | src/game/content.ts:322 | plastic | rule:items:plastic / manual:items:plastic |
| items:prism | B2 | 实现中；候选待源行为比较 | src/game/content.ts:277 | prism | rule:items:prism / manual:items:prism |
| items:processor | B2 | 实现中；候选待源行为比较 | src/game/content.ts:286 | processor | rule:items:processor / manual:items:processor |
| items:proliferator_mk1 | B2 | 实现中；候选待源行为比较 | src/game/content.ts:294 | proliferator_mk1 | rule:items:proliferator_mk1 / manual:items:proliferator_mk1 |
| items:proliferator_mk2 | B2 | 实现中；候选待源行为比较 | src/game/content.ts:295 | proliferator_mk2 | rule:items:proliferator_mk2 / manual:items:proliferator_mk2 |
| items:proliferator_mk3 | B2 | 实现中；候选待源行为比较 | src/game/content.ts:296 | proliferator_mk3 | rule:items:proliferator_mk3 / manual:items:proliferator_mk3 |
| items:quantum_chip | B3 | 实现中；候选待源行为比较 | src/game/content.ts:309 | quantum_chip | rule:items:quantum_chip / manual:items:quantum_chip |
| items:refined_oil | B2 | 实现中；候选待源行为比较 | src/game/content.ts:280 | refined_oil | rule:items:refined_oil / manual:items:refined_oil |
| items:silicon_ore | B1 | 实现中；候选待源行为比较 | src/game/content.ts:258 | silicon_ore | rule:items:silicon_ore / manual:items:silicon_ore |
| items:small_carrier_rocket | B2 | 实现中；候选待源行为比较 | src/game/content.ts:320 | small_carrier_rocket | rule:items:small_carrier_rocket / manual:items:small_carrier_rocket |
| items:solar_sail | B2 | 实现中；候选待源行为比较 | src/game/content.ts:313 | solar_sail | rule:items:solar_sail / manual:items:solar_sail |
| items:space_warper | B2 | 实现中；候选待源行为比较 | src/game/content.ts:289 | space_warper | rule:items:space_warper / manual:items:space_warper |
| items:spiniform_stalagmite_crystal | B1 | 实现中；候选待源行为比较 | src/game/content.ts:264 | spiniform_stalagmite_crystal | rule:items:spiniform_stalagmite_crystal / manual:items:spiniform_stalagmite_crystal |
| items:steel | B2 | 实现中；候选待源行为比较 | src/game/content.ts:273 | steel | rule:items:steel / manual:items:steel |
| items:stone | B1 | 实现中；候选待源行为比较 | src/game/content.ts:256 | stone | rule:items:stone / manual:items:stone |
| items:stone_brick | B2 | 实现中；候选待源行为比较 | src/game/content.ts:271 | stone_brick | rule:items:stone_brick / manual:items:stone_brick |
| items:strange_matter | B2 | 实现中；候选待源行为比较 | src/game/content.ts:310 | strange_matter | rule:items:strange_matter / manual:items:strange_matter |
| items:structure_matrix | B2 | 实现中；候选待源行为比较 | src/game/content.ts:327 | structure_matrix | rule:items:structure_matrix / manual:items:structure_matrix |
| items:sulfuric_acid | B1 | 实现中；候选待源行为比较 | src/game/content.ts:267 | sulfuric_acid | rule:items:sulfuric_acid / manual:items:sulfuric_acid |
| items:super_magnetic_ring | B2 | 实现中；候选待源行为比较 | src/game/content.ts:301 | super_magnetic_ring | rule:items:super_magnetic_ring / manual:items:super_magnetic_ring |
| items:titanium_alloy | B2 | 实现中；候选待源行为比较 | src/game/content.ts:284 | titanium_alloy | rule:items:titanium_alloy / manual:items:titanium_alloy |
| items:titanium_crystal | B2 | 实现中；候选待源行为比较 | src/game/content.ts:324 | titanium_crystal | rule:items:titanium_crystal / manual:items:titanium_crystal |
| items:titanium_glass | B2 | 实现中；候选待源行为比较 | src/game/content.ts:306 | titanium_glass | rule:items:titanium_glass / manual:items:titanium_glass |
| items:titanium_ingot | B2 | 实现中；候选待源行为比较 | src/game/content.ts:283 | titanium_ingot | rule:items:titanium_ingot / manual:items:titanium_ingot |
| items:titanium_ore | B1 | 实现中；候选待源行为比较 | src/game/content.ts:259 | titanium_ore | rule:items:titanium_ore / manual:items:titanium_ore |
| items:unipolar_magnet | B1 | 实现中；候选待源行为比较 | src/game/content.ts:265 | unipolar_magnet | rule:items:unipolar_magnet / manual:items:unipolar_magnet |
| items:universe_matrix | B2 | 实现中；候选待源行为比较 | src/game/content.ts:330 | universe_matrix | rule:items:universe_matrix / manual:items:universe_matrix |
| items:water | B1 | 实现中；候选待源行为比较 | src/game/content.ts:266 | water | rule:items:water / manual:items:water |

## recipes

| key | 批次 | 状态/复核 | 源位置 | 当前映射 | 自动/人工编号 |
|---|---|---|---|---|---|
| recipes:accumulator | — | 已验证；当前行为证据已绑定 | src/game/content.ts:595 | dsp_accumulator | rule:recipes:accumulator / manual:recipes:accumulator |
| recipes:accumulator_charge | — | 已验证；当前行为证据已绑定 | src/game/content.ts:596 | dsp_accumulator_charge | rule:recipes:accumulator_charge / manual:recipes:accumulator_charge |
| recipes:accumulator_discharge | — | 已验证；当前行为证据已绑定 | src/game/content.ts:597 | dsp_accumulator_discharge | rule:recipes:accumulator_discharge / manual:recipes:accumulator_discharge |
| recipes:annihilation_constraint_sphere | — | 已验证；当前行为证据已绑定 | src/game/content.ts:631 | dsp_annihilation_constraint_sphere | rule:recipes:annihilation_constraint_sphere / manual:recipes:annihilation_constraint_sphere |
| recipes:antimatter | — | 已验证；当前行为证据已绑定 | src/game/content.ts:630 | dsp_antimatter | rule:recipes:antimatter / manual:recipes:antimatter |
| recipes:antimatter_fuel_rod | — | 已验证；当前行为证据已绑定 | src/game/content.ts:632 | dsp_antimatter_fuel_rod | rule:recipes:antimatter_fuel_rod / manual:recipes:antimatter_fuel_rod |
| recipes:carbon_nanotube | — | 已验证；当前行为证据已绑定 | src/game/content.ts:602 | dsp_carbon_nanotube | rule:recipes:carbon_nanotube / manual:recipes:carbon_nanotube |
| recipes:carbon_nanotube_from_spiniform | — | 已验证；当前行为证据已绑定 | src/game/content.ts:603 | dsp_carbon_nanotube_from_spiniform | rule:recipes:carbon_nanotube_from_spiniform / manual:recipes:carbon_nanotube_from_spiniform |
| recipes:carrier_rocket_launch | — | 已验证；当前行为证据已绑定 | src/game/content.ts:636 | dsp_carrier_rocket_launch | rule:recipes:carrier_rocket_launch / manual:recipes:carrier_rocket_launch |
| recipes:casimir_crystal | — | 已验证；当前行为证据已绑定 | src/game/content.ts:618 | dsp_casimir_crystal | rule:recipes:casimir_crystal / manual:recipes:casimir_crystal |
| recipes:casimir_crystal_advanced | — | 已验证；当前行为证据已绑定 | src/game/content.ts:619 | dsp_casimir_crystal_advanced | rule:recipes:casimir_crystal_advanced / manual:recipes:casimir_crystal_advanced |
| recipes:circuit_board | — | 已验证；当前行为证据已绑定 | src/game/content.ts:578 | dsp_circuit_board | rule:recipes:circuit_board / manual:recipes:circuit_board |
| recipes:copper_ingot | — | 已验证；当前行为证据已绑定 | src/game/content.ts:570 | dsp_copper_ingot | rule:recipes:copper_ingot / manual:recipes:copper_ingot |
| recipes:critical_photon | — | 已验证；当前行为证据已绑定 | src/game/content.ts:629 | dsp_critical_photon | rule:recipes:critical_photon / manual:recipes:critical_photon |
| recipes:crystal_silicon | — | 已验证；当前行为证据已绑定 | src/game/content.ts:607 | dsp_crystal_silicon | rule:recipes:crystal_silicon / manual:recipes:crystal_silicon |
| recipes:crystal_silicon_from_fractal | — | 已验证；当前行为证据已绑定 | src/game/content.ts:608 | dsp_crystal_silicon_from_fractal | rule:recipes:crystal_silicon_from_fractal / manual:recipes:crystal_silicon_from_fractal |
| recipes:deuterium | — | 已验证；当前行为证据已绑定 | src/game/content.ts:615 | dsp_deuterium | rule:recipes:deuterium / manual:recipes:deuterium |
| recipes:deuterium_fractionation | — | 已验证；当前行为证据已绑定 | src/game/content.ts:599 | dsp_deuterium_fractionation | rule:recipes:deuterium_fractionation / manual:recipes:deuterium_fractionation |
| recipes:deuteron_fuel_rod | — | 已验证；当前行为证据已绑定 | src/game/content.ts:616 | dsp_deuteron_fuel_rod | rule:recipes:deuteron_fuel_rod / manual:recipes:deuteron_fuel_rod |
| recipes:diamond | — | 已验证；当前行为证据已绑定 | src/game/content.ts:637 | dsp_diamond | rule:recipes:diamond / manual:recipes:diamond |
| recipes:diamond_from_kimberlite | — | 已验证；当前行为证据已绑定 | src/game/content.ts:638 | dsp_diamond_from_kimberlite | rule:recipes:diamond_from_kimberlite / manual:recipes:diamond_from_kimberlite |
| recipes:dyson_sphere_component | — | 已验证；当前行为证据已绑定 | src/game/content.ts:634 | dsp_dyson_sphere_component | rule:recipes:dyson_sphere_component / manual:recipes:dyson_sphere_component |
| recipes:electric_motor | — | 已验证；当前行为证据已绑定 | src/game/content.ts:610 | dsp_electric_motor | rule:recipes:electric_motor / manual:recipes:electric_motor |
| recipes:electromagnetic_matrix | — | 已验证；当前行为证据已绑定 | src/game/content.ts:642 | dsp_electromagnetic_matrix | rule:recipes:electromagnetic_matrix / manual:recipes:electromagnetic_matrix |
| recipes:electromagnetic_turbine | — | 已验证；当前行为证据已绑定 | src/game/content.ts:611 | dsp_electromagnetic_turbine | rule:recipes:electromagnetic_turbine / manual:recipes:electromagnetic_turbine |
| recipes:energetic_graphite | — | 已验证；当前行为证据已绑定 | src/game/content.ts:575 | dsp_energetic_graphite | rule:recipes:energetic_graphite / manual:recipes:energetic_graphite |
| recipes:energy_matrix | — | 已验证；当前行为证据已绑定 | src/game/content.ts:643 | dsp_energy_matrix | rule:recipes:energy_matrix / manual:recipes:energy_matrix |
| recipes:frame_material | — | 已验证；当前行为证据已绑定 | src/game/content.ts:633 | dsp_frame_material | rule:recipes:frame_material / manual:recipes:frame_material |
| recipes:gear | — | 已验证；当前行为证据已绑定 | src/game/content.ts:576 | dsp_gear | rule:recipes:gear / manual:recipes:gear |
| recipes:glass | — | 已验证；当前行为证据已绑定 | src/game/content.ts:573 | dsp_glass | rule:recipes:glass / manual:recipes:glass |
| recipes:graphene | — | 已验证；当前行为证据已绑定 | src/game/content.ts:600 | dsp_graphene | rule:recipes:graphene / manual:recipes:graphene |
| recipes:graphene_from_fire_ice | — | 已验证；当前行为证据已绑定 | src/game/content.ts:601 | dsp_graphene_from_fire_ice | rule:recipes:graphene_from_fire_ice / manual:recipes:graphene_from_fire_ice |
| recipes:graviton_lens | — | 已验证；当前行为证据已绑定 | src/game/content.ts:623 | dsp_graviton_lens | rule:recipes:graviton_lens / manual:recipes:graviton_lens |
| recipes:gravity_matrix | — | 已验证；当前行为证据已绑定 | src/game/content.ts:646 | dsp_gravity_matrix | rule:recipes:gravity_matrix / manual:recipes:gravity_matrix |
| recipes:high_purity_silicon | — | 已验证；当前行为证据已绑定 | src/game/content.ts:584 | dsp_high_purity_silicon | rule:recipes:high_purity_silicon / manual:recipes:high_purity_silicon |
| recipes:hydrogen_fuel_rod | — | 已验证；当前行为证据已绑定 | src/game/content.ts:598 | dsp_hydrogen_fuel_rod | rule:recipes:hydrogen_fuel_rod / manual:recipes:hydrogen_fuel_rod |
| recipes:information_matrix | — | 已验证；当前行为证据已绑定 | src/game/content.ts:645 | dsp_information_matrix | rule:recipes:information_matrix / manual:recipes:information_matrix |
| recipes:iron_ingot | — | 已验证；当前行为证据已绑定 | src/game/content.ts:569 | dsp_iron_ingot | rule:recipes:iron_ingot / manual:recipes:iron_ingot |
| recipes:logistics_drone | — | 已验证；当前行为证据已绑定 | src/game/content.ts:591 | dsp_logistics_drone | rule:recipes:logistics_drone / manual:recipes:logistics_drone |
| recipes:logistics_vessel | — | 已验证；当前行为证据已绑定 | src/game/content.ts:592 | dsp_logistics_vessel | rule:recipes:logistics_vessel / manual:recipes:logistics_vessel |
| recipes:magnet | — | 已验证；当前行为证据已绑定 | src/game/content.ts:571 | dsp_magnet | rule:recipes:magnet / manual:recipes:magnet |
| recipes:magnetic_coil | — | 已验证；当前行为证据已绑定 | src/game/content.ts:577 | dsp_magnetic_coil | rule:recipes:magnetic_coil / manual:recipes:magnetic_coil |
| recipes:matrix_research | — | 已验证；当前行为证据已绑定 | src/game/content.ts:648 | dsp_matrix_research | rule:recipes:matrix_research / manual:recipes:matrix_research |
| recipes:microcrystalline_component | — | 已验证；当前行为证据已绑定 | src/game/content.ts:589 | dsp_microcrystalline_component | rule:recipes:microcrystalline_component / manual:recipes:microcrystalline_component |
| recipes:organic_crystal | — | 已验证；当前行为证据已绑定 | src/game/content.ts:640 | dsp_organic_crystal | rule:recipes:organic_crystal / manual:recipes:organic_crystal |
| recipes:particle_broadband | — | 已验证；当前行为证据已绑定 | src/game/content.ts:609 | dsp_particle_broadband | rule:recipes:particle_broadband / manual:recipes:particle_broadband |
| recipes:particle_container | — | 已验证；当前行为证据已绑定 | src/game/content.ts:613 | dsp_particle_container | rule:recipes:particle_container / manual:recipes:particle_container |
| recipes:particle_container_from_unipolar | — | 已验证；当前行为证据已绑定 | src/game/content.ts:614 | dsp_particle_container_from_unipolar | rule:recipes:particle_container_from_unipolar / manual:recipes:particle_container_from_unipolar |
| recipes:photon_combiner | — | 已验证；当前行为证据已绑定 | src/game/content.ts:624 | dsp_photon_combiner | rule:recipes:photon_combiner / manual:recipes:photon_combiner |
| recipes:photon_combiner_from_grating | — | 已验证；当前行为证据已绑定 | src/game/content.ts:625 | dsp_photon_combiner_from_grating | rule:recipes:photon_combiner_from_grating / manual:recipes:photon_combiner_from_grating |
| recipes:plane_filter | — | 已验证；当前行为证据已绑定 | src/game/content.ts:620 | dsp_plane_filter | rule:recipes:plane_filter / manual:recipes:plane_filter |
| recipes:plasma_exciter | — | 已验证；当前行为证据已绑定 | src/game/content.ts:580 | dsp_plasma_exciter | rule:recipes:plasma_exciter / manual:recipes:plasma_exciter |
| recipes:plasma_refining | — | 已验证；当前行为证据已绑定 | src/game/content.ts:581 | dsp_plasma_refining | rule:recipes:plasma_refining / manual:recipes:plasma_refining |
| recipes:plastic | — | 已验证；当前行为证据已绑定 | src/game/content.ts:639 | dsp_plastic | rule:recipes:plastic / manual:recipes:plastic |
| recipes:prism | — | 已验证；当前行为证据已绑定 | src/game/content.ts:579 | dsp_prism | rule:recipes:prism / manual:recipes:prism |
| recipes:processor | — | 已验证；当前行为证据已绑定 | src/game/content.ts:590 | dsp_processor | rule:recipes:processor / manual:recipes:processor |
| recipes:proliferator_mk1 | — | 已验证；当前行为证据已绑定 | src/game/content.ts:604 | dsp_proliferator_mk1 | rule:recipes:proliferator_mk1 / manual:recipes:proliferator_mk1 |
| recipes:proliferator_mk2 | — | 已验证；当前行为证据已绑定 | src/game/content.ts:605 | dsp_proliferator_mk2 | rule:recipes:proliferator_mk2 / manual:recipes:proliferator_mk2 |
| recipes:proliferator_mk3 | — | 已验证；当前行为证据已绑定 | src/game/content.ts:606 | dsp_proliferator_mk3 | rule:recipes:proliferator_mk3 / manual:recipes:proliferator_mk3 |
| recipes:quantum_chip | — | 已验证；当前行为证据已绑定 | src/game/content.ts:621 | dsp_quantum_chip | rule:recipes:quantum_chip / manual:recipes:quantum_chip |
| recipes:ray_power | — | 已验证；当前行为证据已绑定 | src/game/content.ts:628 | dsp_ray_power | rule:recipes:ray_power / manual:recipes:ray_power |
| recipes:reforming_refine | — | 已验证；当前行为证据已绑定 | src/game/content.ts:583 | dsp_reforming_refine | rule:recipes:reforming_refine / manual:recipes:reforming_refine |
| recipes:silicon_ore_from_stone | — | 已验证；当前行为证据已绑定 | src/game/content.ts:585 | dsp_silicon_ore_from_stone | rule:recipes:silicon_ore_from_stone / manual:recipes:silicon_ore_from_stone |
| recipes:small_carrier_rocket | — | 已验证；当前行为证据已绑定 | src/game/content.ts:635 | dsp_small_carrier_rocket | rule:recipes:small_carrier_rocket / manual:recipes:small_carrier_rocket |
| recipes:solar_sail | — | 已验证；当前行为证据已绑定 | src/game/content.ts:626 | dsp_solar_sail | rule:recipes:solar_sail / manual:recipes:solar_sail |
| recipes:solar_sail_launch | — | 已验证；当前行为证据已绑定 | src/game/content.ts:627 | dsp_solar_sail_launch | rule:recipes:solar_sail_launch / manual:recipes:solar_sail_launch |
| recipes:space_warper | — | 已验证；当前行为证据已绑定 | src/game/content.ts:593 | dsp_space_warper | rule:recipes:space_warper / manual:recipes:space_warper |
| recipes:space_warper_from_gravity_matrix | — | 已验证；当前行为证据已绑定 | src/game/content.ts:594 | dsp_space_warper_from_gravity_matrix | rule:recipes:space_warper_from_gravity_matrix / manual:recipes:space_warper_from_gravity_matrix |
| recipes:steel | — | 已验证；当前行为证据已绑定 | src/game/content.ts:574 | dsp_steel | rule:recipes:steel / manual:recipes:steel |
| recipes:stone_brick | — | 已验证；当前行为证据已绑定 | src/game/content.ts:572 | dsp_stone_brick | rule:recipes:stone_brick / manual:recipes:stone_brick |
| recipes:strange_matter | — | 已验证；当前行为证据已绑定 | src/game/content.ts:622 | dsp_strange_matter | rule:recipes:strange_matter / manual:recipes:strange_matter |
| recipes:structure_matrix | — | 已验证；当前行为证据已绑定 | src/game/content.ts:644 | dsp_structure_matrix | rule:recipes:structure_matrix / manual:recipes:structure_matrix |
| recipes:sulfuric_acid | — | 已验证；当前行为证据已绑定 | src/game/content.ts:587 | dsp_sulfuric_acid | rule:recipes:sulfuric_acid / manual:recipes:sulfuric_acid |
| recipes:super_magnetic_ring | — | 已验证；当前行为证据已绑定 | src/game/content.ts:612 | dsp_super_magnetic_ring | rule:recipes:super_magnetic_ring / manual:recipes:super_magnetic_ring |
| recipes:titanium_alloy | — | 已验证；当前行为证据已绑定 | src/game/content.ts:588 | dsp_titanium_alloy | rule:recipes:titanium_alloy / manual:recipes:titanium_alloy |
| recipes:titanium_crystal | — | 已验证；当前行为证据已绑定 | src/game/content.ts:641 | dsp_titanium_crystal | rule:recipes:titanium_crystal / manual:recipes:titanium_crystal |
| recipes:titanium_glass | — | 已验证；当前行为证据已绑定 | src/game/content.ts:617 | dsp_titanium_glass | rule:recipes:titanium_glass / manual:recipes:titanium_glass |
| recipes:titanium_ingot | — | 已验证；当前行为证据已绑定 | src/game/content.ts:586 | dsp_titanium_ingot | rule:recipes:titanium_ingot / manual:recipes:titanium_ingot |
| recipes:universe_matrix | — | 已验证；当前行为证据已绑定 | src/game/content.ts:647 | dsp_universe_matrix | rule:recipes:universe_matrix / manual:recipes:universe_matrix |
| recipes:xray_cracking | — | 已验证；当前行为证据已绑定 | src/game/content.ts:582 | dsp_xray_cracking | rule:recipes:xray_cracking / manual:recipes:xray_cracking |

## buildings

| key | 批次 | 状态/复核 | 源位置 | 当前映射 | 自动/人工编号 |
|---|---|---|---|---|---|
| buildings:accumulator | B2 | 实现中；候选待源行为比较 | src/game/content.ts:400 | dsp_accumulator | rule:buildings:accumulator / manual:buildings:accumulator |
| buildings:arc_smelter | B2 | 实现中；候选待源行为比较 | src/game/content.ts:417 | dsp_arc_smelter | rule:buildings:arc_smelter / manual:buildings:arc_smelter |
| buildings:artificial_star | B2 | 实现中；候选待源行为比较 | src/game/content.ts:395 | dsp_artificial_star | rule:buildings:artificial_star / manual:buildings:artificial_star |
| buildings:assembling_machine_mk1 | B2 | 实现中；候选待源行为比较 | src/game/content.ts:427 | dsp_assembling_machine_mk1 | rule:buildings:assembling_machine_mk1 / manual:buildings:assembling_machine_mk1 |
| buildings:assembling_machine_mk2 | B2 | 实现中；候选待源行为比较 | src/game/content.ts:432 | dsp_assembling_machine_mk2 | rule:buildings:assembling_machine_mk2 / manual:buildings:assembling_machine_mk2 |
| buildings:assembling_machine_mk3 | B2 | 实现中；候选待源行为比较 | src/game/content.ts:437 | dsp_assembling_machine_mk3 | rule:buildings:assembling_machine_mk3 / manual:buildings:assembling_machine_mk3 |
| buildings:chemical_plant | B2 | 实现中；候选待源行为比较 | src/game/content.ts:467 | dsp_chemical_plant | rule:buildings:chemical_plant / manual:buildings:chemical_plant |
| buildings:construction_center | B2 | 实现中；候选待源行为比较 | src/game/content.ts:542 | dsp_construction_center | rule:buildings:construction_center / manual:buildings:construction_center |
| buildings:em_rail_ejector | B4 | 实现中；候选待源行为比较 | src/game/content.ts:487 | dsp_em_rail_ejector | rule:buildings:em_rail_ejector / manual:buildings:em_rail_ejector |
| buildings:energy_exchanger | B2 | 实现中；候选待源行为比较 | src/game/content.ts:406 | dsp_energy_exchanger | rule:buildings:energy_exchanger / manual:buildings:energy_exchanger |
| buildings:fractionator | B2 | 实现中；候选待源行为比较 | src/game/content.ts:477 | dsp_fractionator | rule:buildings:fractionator / manual:buildings:fractionator |
| buildings:galactic_material_exporter | B4 | 实现中；候选待源行为比较 | src/game/content.ts:547 | dsp_galactic_material_exporter | rule:buildings:galactic_material_exporter / manual:buildings:galactic_material_exporter |
| buildings:geothermal_power_station | B3 | 实现中；候选待源行为比较 | src/game/content.ts:380 | dsp_geothermal_power_station | rule:buildings:geothermal_power_station / manual:buildings:geothermal_power_station |
| buildings:interstellar_logistics_station | B3 | 实现中；候选待源行为比较 | src/game/content.ts:507 | dsp_interstellar_logistics_station | rule:buildings:interstellar_logistics_station / manual:buildings:interstellar_logistics_station |
| buildings:material_delivery_hub | B2 | 实现中；候选待源行为比较 | src/game/content.ts:522 | dsp_material_delivery_hub | rule:buildings:material_delivery_hub / manual:buildings:material_delivery_hub |
| buildings:matrix_lab | B2 | 实现中；候选待源行为比较 | src/game/content.ts:447 | dsp_matrix_lab | rule:buildings:matrix_lab / manual:buildings:matrix_lab |
| buildings:micro_black_hole_connector | B4 | 实现中；候选待源行为比较 | src/game/content.ts:552 | dsp_micro_black_hole_connector | rule:buildings:micro_black_hole_connector / manual:buildings:micro_black_hole_connector |
| buildings:mini_fusion_power_plant | B2 | 实现中；候选待源行为比较 | src/game/content.ts:390 | dsp_mini_fusion_power_plant | rule:buildings:mini_fusion_power_plant / manual:buildings:mini_fusion_power_plant |
| buildings:miniature_particle_collider | B2 | 实现中；候选待源行为比较 | src/game/content.ts:482 | dsp_miniature_particle_collider | rule:buildings:miniature_particle_collider / manual:buildings:miniature_particle_collider |
| buildings:mining_machine | B1 | 实现中；候选待源行为比较 | src/game/content.ts:412 | dsp_mining_machine | rule:buildings:mining_machine / manual:buildings:mining_machine |
| buildings:oil_extractor | B1 | 实现中；候选待源行为比较 | src/game/content.ts:452 | dsp_oil_extractor | rule:buildings:oil_extractor / manual:buildings:oil_extractor |
| buildings:oil_refinery | B2 | 实现中；候选待源行为比较 | src/game/content.ts:457 | dsp_oil_refinery | rule:buildings:oil_refinery / manual:buildings:oil_refinery |
| buildings:orbital_cargo_terminal | B3 | 实现中；候选待源行为比较 | src/game/content.ts:527 | dsp_orbital_cargo_terminal | rule:buildings:orbital_cargo_terminal / manual:buildings:orbital_cargo_terminal |
| buildings:orbital_collector | B3 | 实现中；候选待源行为比较 | src/game/content.ts:512 | dsp_orbital_collector | rule:buildings:orbital_collector / manual:buildings:orbital_collector |
| buildings:plane_smelter | B2 | 实现中；候选待源行为比较 | src/game/content.ts:422 | dsp_plane_smelter | rule:buildings:plane_smelter / manual:buildings:plane_smelter |
| buildings:planetary_logistics_station | B3 | 实现中；候选待源行为比较 | src/game/content.ts:502 | dsp_planetary_logistics_station | rule:buildings:planetary_logistics_station / manual:buildings:planetary_logistics_station |
| buildings:quantum_chemical_plant | B3 | 实现中；候选待源行为比较 | src/game/content.ts:472 | dsp_quantum_chemical_plant | rule:buildings:quantum_chemical_plant / manual:buildings:quantum_chemical_plant |
| buildings:ray_receiver | B2 | 实现中；候选待源行为比较 | src/game/content.ts:492 | dsp_ray_receiver | rule:buildings:ray_receiver / manual:buildings:ray_receiver |
| buildings:solar_panel | B2 | 实现中；候选待源行为比较 | src/game/content.ts:375 | dsp_solar_panel | rule:buildings:solar_panel / manual:buildings:solar_panel |
| buildings:space_station_construction_launcher | B4 | 实现中；候选待源行为比较 | src/game/content.ts:562 | dsp_space_station_construction_launcher | rule:buildings:space_station_construction_launcher / manual:buildings:space_station_construction_launcher |
| buildings:splitter_4way | B2 | 实现中；候选待源行为比较 | src/game/content.ts:537 | dsp_splitter_4way | rule:buildings:splitter_4way / manual:buildings:splitter_4way |
| buildings:spray_coater | B2 | 实现中；候选待源行为比较 | src/game/content.ts:442 | dsp_spray_coater | rule:buildings:spray_coater / manual:buildings:spray_coater |
| buildings:storage_mk1 | B2 | 实现中；候选待源行为比较 | src/game/content.ts:517 | dsp_storage_mk1 | rule:buildings:storage_mk1 / manual:buildings:storage_mk1 |
| buildings:storage_tank | B2 | 实现中；候选待源行为比较 | src/game/content.ts:532 | dsp_storage_tank | rule:buildings:storage_tank / manual:buildings:storage_tank |
| buildings:thermal_power_plant | B2 | 实现中；候选待源行为比较 | src/game/content.ts:385 | dsp_thermal_power_plant | rule:buildings:thermal_power_plant / manual:buildings:thermal_power_plant |
| buildings:time_warp_device | B5 | 实现中；候选待源行为比较 | src/game/content.ts:557 | dsp_time_warp_device | rule:buildings:time_warp_device / manual:buildings:time_warp_device |
| buildings:vertical_launching_silo | B2 | 实现中；候选待源行为比较 | src/game/content.ts:497 | dsp_vertical_launching_silo | rule:buildings:vertical_launching_silo / manual:buildings:vertical_launching_silo |
| buildings:water_pump | B1 | 实现中；候选待源行为比较 | src/game/content.ts:462 | dsp_water_pump | rule:buildings:water_pump / manual:buildings:water_pump |
| buildings:wind_turbine | B2 | 实现中；候选待源行为比较 | src/game/content.ts:370 | dsp_wind_turbine | rule:buildings:wind_turbine / manual:buildings:wind_turbine |

## technologies

| key | 批次 | 状态/复核 | 源位置 | 当前映射 | 自动/人工编号 |
|---|---|---|---|---|---|
| technologies:antimatter | — | 已验证；当前行为证据已绑定 | src/game/content.ts:1249 | dsp_antimatter | rule:technologies:antimatter / manual:technologies:antimatter |
| technologies:artificial_star | — | 已验证；当前行为证据已绑定 | src/game/content.ts:1262 | dsp_artificial_star | rule:technologies:artificial_star / manual:technologies:artificial_star |
| technologies:autonomous_station_construction | — | 已验证；当前行为证据已绑定 | src/game/content.ts:1562 | dsp_autonomous_station_construction | rule:technologies:autonomous_station_construction / manual:technologies:autonomous_station_construction |
| technologies:basic_chemical_engineering | — | 已验证；当前行为证据已绑定 | src/game/content.ts:917 | dsp_basic_chemical_engineering | rule:technologies:basic_chemical_engineering / manual:technologies:basic_chemical_engineering |
| technologies:basic_logistics | — | 已验证；当前行为证据已绑定 | src/game/content.ts:824 | dsp_basic_logistics | rule:technologies:basic_logistics / manual:technologies:basic_logistics |
| technologies:construction_automation | — | 已验证；当前行为证据已绑定 | src/game/content.ts:1049 | dsp_construction_automation | rule:technologies:construction_automation / manual:technologies:construction_automation |
| technologies:construction_capacity_1 | — | 已验证；当前行为证据已绑定 | src/game/content.ts:1145 | dsp_construction_capacity_1 | rule:technologies:construction_capacity_1 / manual:technologies:construction_capacity_1 |
| technologies:construction_capacity_2 | — | 已验证；当前行为证据已绑定 | src/game/content.ts:1316 | dsp_construction_capacity_2 | rule:technologies:construction_capacity_2 / manual:technologies:construction_capacity_2 |
| technologies:dyson_absorption_1 | — | 已验证；当前行为证据已绑定 | src/game/content.ts:1513 | dsp_dyson_absorption_1 | rule:technologies:dyson_absorption_1 / manual:technologies:dyson_absorption_1 |
| technologies:dyson_shell | — | 已验证；当前行为证据已绑定 | src/game/content.ts:1372 | dsp_dyson_shell | rule:technologies:dyson_shell / manual:technologies:dyson_shell |
| technologies:dyson_sphere_program | — | 已验证；当前行为证据已绑定 | src/game/content.ts:1344 | dsp_dyson_sphere_program | rule:technologies:dyson_sphere_program / manual:technologies:dyson_sphere_program |
| technologies:dyson_swarm | — | 已验证；当前行为证据已绑定 | src/game/content.ts:1223 | dsp_dyson_swarm | rule:technologies:dyson_swarm / manual:technologies:dyson_swarm |
| technologies:electromagnetic_matrix | — | 已验证；当前行为证据已绑定 | src/game/content.ts:808 | dsp_electromagnetic_matrix | rule:technologies:electromagnetic_matrix / manual:technologies:electromagnetic_matrix |
| technologies:electromagnetism | — | 已验证；当前行为证据已绑定 | src/game/content.ts:813 | dsp_electromagnetism | rule:technologies:electromagnetism / manual:technologies:electromagnetism |
| technologies:energy_matrix | — | 已验证；当前行为证据已绑定 | src/game/content.ts:841 | dsp_energy_matrix | rule:technologies:energy_matrix / manual:technologies:energy_matrix |
| technologies:energy_storage | — | 已验证；当前行为证据已绑定 | src/game/content.ts:847 | dsp_energy_storage | rule:technologies:energy_storage / manual:technologies:energy_storage |
| technologies:fractionation | — | 已验证；当前行为证据已绑定 | src/game/content.ts:854 | dsp_fractionation | rule:technologies:fractionation / manual:technologies:fractionation |
| technologies:fusion_power | — | 已验证；当前行为证据已绑定 | src/game/content.ts:1097 | dsp_fusion_power | rule:technologies:fusion_power / manual:technologies:fusion_power |
| technologies:geothermal_power | — | 已验证；当前行为证据已绑定 | src/game/content.ts:861 | dsp_geothermal_power | rule:technologies:geothermal_power / manual:technologies:geothermal_power |
| technologies:gravity_matrix | — | 已验证；当前行为证据已绑定 | src/game/content.ts:1133 | dsp_gravity_matrix | rule:technologies:gravity_matrix / manual:technologies:gravity_matrix |
| technologies:high_efficiency_plasma_control | — | 已验证；当前行为证据已绑定 | src/game/content.ts:835 | dsp_high_efficiency_plasma_control | rule:technologies:high_efficiency_plasma_control / manual:technologies:high_efficiency_plasma_control |
| technologies:high_speed_assembling | — | 已验证；当前行为证据已绑定 | src/game/content.ts:868 | dsp_high_speed_assembling | rule:technologies:high_speed_assembling / manual:technologies:high_speed_assembling |
| technologies:high_speed_logistics | — | 已验证；当前行为证据已绑定 | src/game/content.ts:875 | dsp_high_speed_logistics | rule:technologies:high_speed_logistics / manual:technologies:high_speed_logistics |
| technologies:high_strength_crystal | — | 已验证；当前行为证据已绑定 | src/game/content.ts:910 | dsp_high_strength_crystal | rule:technologies:high_strength_crystal / manual:technologies:high_strength_crystal |
| technologies:information_matrix | — | 已验证；当前行为证据已绑定 | src/game/content.ts:1038 | dsp_information_matrix | rule:technologies:information_matrix / manual:technologies:information_matrix |
| technologies:interstellar_logistics | — | 已验证；当前行为证据已绑定 | src/game/content.ts:981 | dsp_interstellar_logistics | rule:technologies:interstellar_logistics / manual:technologies:interstellar_logistics |
| technologies:logistics_capacity_1 | — | 已验证；当前行为证据已绑定 | src/game/content.ts:1434 | dsp_logistics_capacity_1 | rule:technologies:logistics_capacity_1 / manual:technologies:logistics_capacity_1 |
| technologies:logistics_capacity_2 | — | 已验证；当前行为证据已绑定 | src/game/content.ts:1446 | dsp_logistics_capacity_2 | rule:technologies:logistics_capacity_2 / manual:technologies:logistics_capacity_2 |
| technologies:logistics_engine_1 | — | 已验证；当前行为证据已绑定 | src/game/content.ts:1410 | dsp_logistics_engine_1 | rule:technologies:logistics_engine_1 / manual:technologies:logistics_engine_1 |
| technologies:logistics_engine_2 | — | 已验证；当前行为证据已绑定 | src/game/content.ts:1421 | dsp_logistics_engine_2 | rule:technologies:logistics_engine_2 / manual:technologies:logistics_engine_2 |
| technologies:material_delivery_logistics | — | 已验证；当前行为证据已绑定 | src/game/content.ts:938 | dsp_material_delivery_logistics | rule:technologies:material_delivery_logistics / manual:technologies:material_delivery_logistics |
| technologies:micro_black_hole_containment | — | 已验证；当前行为证据已绑定 | src/game/content.ts:1288 | dsp_micro_black_hole_containment | rule:technologies:micro_black_hole_containment / manual:technologies:micro_black_hole_containment |
| technologies:miniature_particle_collider | — | 已验证；当前行为证据已绑定 | src/game/content.ts:1085 | dsp_miniature_particle_collider | rule:technologies:miniature_particle_collider / manual:technologies:miniature_particle_collider |
| technologies:mining_speed_1 | — | 已验证；当前行为证据已绑定 | src/game/content.ts:882 | dsp_mining_speed_1 | rule:technologies:mining_speed_1 / manual:technologies:mining_speed_1 |
| technologies:mining_speed_2 | — | 已验证；当前行为证据已绑定 | src/game/content.ts:1386 | dsp_mining_speed_2 | rule:technologies:mining_speed_2 / manual:technologies:mining_speed_2 |
| technologies:mining_speed_3 | — | 已验证；当前行为证据已绑定 | src/game/content.ts:1397 | dsp_mining_speed_3 | rule:technologies:mining_speed_3 / manual:technologies:mining_speed_3 |
| technologies:nanomaterials | — | 已验证；当前行为证据已绑定 | src/game/content.ts:991 | dsp_nanomaterials | rule:technologies:nanomaterials / manual:technologies:nanomaterials |
| technologies:orbital_collection | — | 已验证；当前行为证据已绑定 | src/game/content.ts:1027 | dsp_orbital_collection | rule:technologies:orbital_collection / manual:technologies:orbital_collection |
| technologies:orbital_elevator_engineering | — | 已验证；当前行为证据已绑定 | src/game/content.ts:1527 | dsp_orbital_elevator_engineering | rule:technologies:orbital_elevator_engineering / manual:technologies:orbital_elevator_engineering |
| technologies:orbital_energy_recovery | — | 已验证；当前行为证据已绑定 | src/game/content.ts:1541 | dsp_orbital_energy_recovery | rule:technologies:orbital_energy_recovery / manual:technologies:orbital_energy_recovery |
| technologies:orbital_modular_assembly | — | 已验证；当前行为证据已绑定 | src/game/content.ts:1555 | dsp_orbital_modular_assembly | rule:technologies:orbital_modular_assembly / manual:technologies:orbital_modular_assembly |
| technologies:orbital_multi_cargo_bus | — | 已验证；当前行为证据已绑定 | src/game/content.ts:1534 | dsp_orbital_multi_cargo_bus | rule:technologies:orbital_multi_cargo_bus / manual:technologies:orbital_multi_cargo_bus |
| technologies:plane_smelting | — | 已验证；当前行为证据已绑定 | src/game/content.ts:1121 | dsp_plane_smelting | rule:technologies:plane_smelting / manual:technologies:plane_smelting |
| technologies:planetary_logistics | — | 已验证；当前行为证据已绑定 | src/game/content.ts:970 | dsp_planetary_logistics | rule:technologies:planetary_logistics / manual:technologies:planetary_logistics |
| technologies:polymer_chemistry | — | 已验证；当前行为证据已绑定 | src/game/content.ts:924 | dsp_polymer_chemistry | rule:technologies:polymer_chemistry / manual:technologies:polymer_chemistry |
| technologies:processor | — | 已验证；当前行为证据已绑定 | src/game/content.ts:963 | dsp_processor | rule:technologies:processor / manual:technologies:processor |
| technologies:proliferator_1 | — | 已验证；当前行为证据已绑定 | src/game/content.ts:889 | dsp_proliferator_1 | rule:technologies:proliferator_1 / manual:technologies:proliferator_1 |
| technologies:proliferator_2 | — | 已验证；当前行为证据已绑定 | src/game/content.ts:949 | dsp_proliferator_2 | rule:technologies:proliferator_2 / manual:technologies:proliferator_2 |
| technologies:proliferator_3 | — | 已验证；当前行为证据已绑定 | src/game/content.ts:1061 | dsp_proliferator_3 | rule:technologies:proliferator_3 / manual:technologies:proliferator_3 |
| technologies:quantum_chemical_engineering | — | 已验证；当前行为证据已绑定 | src/game/content.ts:1014 | dsp_quantum_chemical_engineering | rule:technologies:quantum_chemical_engineering / manual:technologies:quantum_chemical_engineering |
| technologies:quantum_chip | — | 已验证；当前行为证据已绑定 | src/game/content.ts:1109 | dsp_quantum_chip | rule:technologies:quantum_chip / manual:technologies:quantum_chip |
| technologies:quantum_logistics_network | — | 已验证；当前行为证据已绑定 | src/game/content.ts:1576 | dsp_quantum_logistics_network | rule:technologies:quantum_logistics_network / manual:technologies:quantum_logistics_network |
| technologies:quantum_printing | — | 已验证；当前行为证据已绑定 | src/game/content.ts:1184 | dsp_quantum_printing | rule:technologies:quantum_printing / manual:technologies:quantum_printing |
| technologies:rare_resource_utilization | — | 已验证；当前行为证据已绑定 | src/game/content.ts:1002 | dsp_rare_resource_utilization | rule:technologies:rare_resource_utilization / manual:technologies:rare_resource_utilization |
| technologies:ray_receiver | — | 已验证；当前行为证据已绑定 | src/game/content.ts:1236 | dsp_ray_receiver | rule:technologies:ray_receiver / manual:technologies:ray_receiver |
| technologies:ray_transmission_1 | — | 已验证；当前行为证据已绑定 | src/game/content.ts:1486 | dsp_ray_transmission_1 | rule:technologies:ray_transmission_1 / manual:technologies:ray_transmission_1 |
| technologies:ray_transmission_2 | — | 已验证；当前行为证据已绑定 | src/game/content.ts:1499 | dsp_ray_transmission_2 | rule:technologies:ray_transmission_2 / manual:technologies:ray_transmission_2 |
| technologies:reforming_refine | — | 已验证；当前行为证据已绑定 | src/game/content.ts:903 | dsp_reforming_refine | rule:technologies:reforming_refine / manual:technologies:reforming_refine |
| technologies:research_speed_1 | — | 已验证；当前行为证据已绑定 | src/game/content.ts:1073 | dsp_research_speed_1 | rule:technologies:research_speed_1 / manual:technologies:research_speed_1 |
| technologies:research_speed_2 | — | 已验证；当前行为证据已绑定 | src/game/content.ts:1210 | dsp_research_speed_2 | rule:technologies:research_speed_2 / manual:technologies:research_speed_2 |
| technologies:research_speed_3 | — | 已验证；当前行为证据已绑定 | src/game/content.ts:1330 | dsp_research_speed_3 | rule:technologies:research_speed_3 / manual:technologies:research_speed_3 |
| technologies:solar_energy | — | 已验证；当前行为证据已绑定 | src/game/content.ts:818 | dsp_solar_energy | rule:technologies:solar_energy / manual:technologies:solar_energy |
| technologies:solar_sail_life_1 | — | 已验证；当前行为证据已绑定 | src/game/content.ts:1459 | dsp_solar_sail_life_1 | rule:technologies:solar_sail_life_1 / manual:technologies:solar_sail_life_1 |
| technologies:solar_sail_life_2 | — | 已验证；当前行为证据已绑定 | src/game/content.ts:1472 | dsp_solar_sail_life_2 | rule:technologies:solar_sail_life_2 / manual:technologies:solar_sail_life_2 |
| technologies:space_warp | — | 已验证；当前行为证据已绑定 | src/game/content.ts:1158 | dsp_space_warp | rule:technologies:space_warp / manual:technologies:space_warp |
| technologies:stellar_exploration | — | 已验证；当前行为证据已绑定 | src/game/content.ts:1171 | dsp_stellar_exploration | rule:technologies:stellar_exploration / manual:technologies:stellar_exploration |
| technologies:structure_matrix | — | 已验证；当前行为证据已绑定 | src/game/content.ts:931 | dsp_structure_matrix | rule:technologies:structure_matrix / manual:technologies:structure_matrix |
| technologies:super_magnetic_logistics | — | 已验证；当前行为证据已绑定 | src/game/content.ts:1197 | dsp_super_magnetic_logistics | rule:technologies:super_magnetic_logistics / manual:technologies:super_magnetic_logistics |
| technologies:system_space_station_engineering | — | 已验证；当前行为证据已绑定 | src/game/content.ts:1548 | dsp_system_space_station_engineering | rule:technologies:system_space_station_engineering / manual:technologies:system_space_station_engineering |
| technologies:thermal_power | — | 已验证；当前行为证据已绑定 | src/game/content.ts:829 | dsp_thermal_power | rule:technologies:thermal_power / manual:technologies:thermal_power |
| technologies:time_warp_engineering | — | 已验证；当前行为证据已绑定 | src/game/content.ts:1302 | dsp_time_warp_engineering | rule:technologies:time_warp_engineering / manual:technologies:time_warp_engineering |
| technologies:titanium_alloy | — | 已验证；当前行为证据已绑定 | src/game/content.ts:956 | dsp_titanium_alloy | rule:technologies:titanium_alloy / manual:technologies:titanium_alloy |
| technologies:unified_system_logistics_protocol | — | 已验证；当前行为证据已绑定 | src/game/content.ts:1569 | dsp_unified_system_logistics_protocol | rule:technologies:unified_system_logistics_protocol / manual:technologies:unified_system_logistics_protocol |
| technologies:universe_matrix | — | 已验证；当前行为证据已绑定 | src/game/content.ts:1275 | dsp_universe_matrix | rule:technologies:universe_matrix / manual:technologies:universe_matrix |
| technologies:vertical_launching_silo | — | 已验证；当前行为证据已绑定 | src/game/content.ts:1358 | dsp_vertical_launching_silo | rule:technologies:vertical_launching_silo / manual:technologies:vertical_launching_silo |
| technologies:xray_cracking | — | 已验证；当前行为证据已绑定 | src/game/content.ts:896 | dsp_xray_cracking | rule:technologies:xray_cracking / manual:technologies:xray_cracking |

## campaign

| key | 批次 | 状态/复核 | 源位置 | 当前映射 | 自动/人工编号 |
|---|---|---|---|---|---|
| campaign:absorb_shell_sail | — | 已验证；当前行为证据已绑定 | src/game/campaign.ts:208 | dsp_absorb_shell_sail | rule:campaign:absorb_shell_sail / manual:campaign:absorb_shell_sail |
| campaign:build_dyson_structure | — | 已验证；当前行为证据已绑定 | src/game/campaign.ts:204 | dsp_build_dyson_structure | rule:campaign:build_dyson_structure / manual:campaign:build_dyson_structure |
| campaign:complete_interstellar_trip | — | 已验证；当前行为证据已绑定 | src/game/campaign.ts:180 | dsp_complete_interstellar_trip | rule:campaign:complete_interstellar_trip / manual:campaign:complete_interstellar_trip |
| campaign:complete_planetary_trip | — | 已验证；当前行为证据已绑定 | src/game/campaign.ts:164 | dsp_complete_planetary_trip | rule:campaign:complete_planetary_trip / manual:campaign:complete_planetary_trip |
| campaign:deploy_interstellar_station | — | 已验证；当前行为证据已绑定 | src/game/campaign.ts:176 | dsp_deploy_interstellar_station | rule:campaign:deploy_interstellar_station / manual:campaign:deploy_interstellar_station |
| campaign:deploy_matrix_lab | — | 已验证；当前行为证据已绑定 | src/game/campaign.ts:140 | dsp_deploy_matrix_lab | rule:campaign:deploy_matrix_lab / manual:campaign:deploy_matrix_lab |
| campaign:deploy_miner | — | 已验证；当前行为证据已绑定 | src/game/campaign.ts:132 | dsp_deploy_miner | rule:campaign:deploy_miner / manual:campaign:deploy_miner |
| campaign:deploy_planetary_station | — | 已验证；当前行为证据已绑定 | src/game/campaign.ts:160 | dsp_deploy_planetary_station | rule:campaign:deploy_planetary_station / manual:campaign:deploy_planetary_station |
| campaign:endgame_export | — | 已验证；当前行为证据已绑定 | src/game/campaign.ts:240 | dsp_endgame_export | rule:campaign:endgame_export / manual:campaign:endgame_export |
| campaign:endgame_infinite_research | — | 已验证；当前行为证据已绑定 | src/game/campaign.ts:236 | dsp_endgame_infinite_research | rule:campaign:endgame_infinite_research / manual:campaign:endgame_infinite_research |
| campaign:endgame_mastery | — | 已验证；当前行为证据已绑定 | src/game/campaign.ts:248 | dsp_endgame_mastery | rule:campaign:endgame_mastery / manual:campaign:endgame_mastery |
| campaign:endgame_score | — | 已验证；当前行为证据已绑定 | src/game/campaign.ts:244 | dsp_endgame_score | rule:campaign:endgame_score / manual:campaign:endgame_score |
| campaign:launch_carrier_rocket | — | 已验证；当前行为证据已绑定 | src/game/campaign.ts:200 | dsp_launch_carrier_rocket | rule:campaign:launch_carrier_rocket / manual:campaign:launch_carrier_rocket |
| campaign:launch_solar_sail | — | 已验证；当前行为证据已绑定 | src/game/campaign.ts:196 | dsp_launch_solar_sail | rule:campaign:launch_solar_sail / manual:campaign:launch_solar_sail |
| campaign:lay_first_belt | — | 已验证；当前行为证据已绑定 | src/game/campaign.ts:136 | dsp_lay_first_belt | rule:campaign:lay_first_belt / manual:campaign:lay_first_belt |
| campaign:mine_first_ore | — | 已验证；当前行为证据已绑定 | src/game/campaign.ts:124 | dsp_mine_first_ore | rule:campaign:mine_first_ore / manual:campaign:mine_first_ore |
| campaign:produce_blue_matrix | — | 已验证；当前行为证据已绑定 | src/game/campaign.ts:144 | dsp_produce_blue_matrix | rule:campaign:produce_blue_matrix / manual:campaign:produce_blue_matrix |
| campaign:produce_gravity_matrix | — | 已验证；当前行为证据已绑定 | src/game/campaign.ts:188 | dsp_produce_gravity_matrix | rule:campaign:produce_gravity_matrix / manual:campaign:produce_gravity_matrix |
| campaign:produce_information_matrix | — | 已验证；当前行为证据已绑定 | src/game/campaign.ts:184 | dsp_produce_information_matrix | rule:campaign:produce_information_matrix / manual:campaign:produce_information_matrix |
| campaign:produce_plastic | — | 已验证；当前行为证据已绑定 | src/game/campaign.ts:152 | dsp_produce_plastic | rule:campaign:produce_plastic / manual:campaign:produce_plastic |
| campaign:produce_red_matrix | — | 已验证；当前行为证据已绑定 | src/game/campaign.ts:156 | dsp_produce_red_matrix | rule:campaign:produce_red_matrix / manual:campaign:produce_red_matrix |
| campaign:produce_structure_matrix | — | 已验证；当前行为证据已绑定 | src/game/campaign.ts:168 | dsp_produce_structure_matrix | rule:campaign:produce_structure_matrix / manual:campaign:produce_structure_matrix |
| campaign:produce_universe_matrix | — | 已验证；当前行为证据已绑定 | src/game/campaign.ts:192 | dsp_produce_universe_matrix | rule:campaign:produce_universe_matrix / manual:campaign:produce_universe_matrix |
| campaign:refine_oil | — | 已验证；当前行为证据已绑定 | src/game/campaign.ts:148 | dsp_refine_oil | rule:campaign:refine_oil / manual:campaign:refine_oil |
| campaign:side_belt_upgrade | — | 已验证；当前行为证据已绑定 | src/game/campaign.ts:220 | dsp_side_belt_upgrade | rule:campaign:side_belt_upgrade / manual:campaign:side_belt_upgrade |
| campaign:side_blueprint | — | 已验证；当前行为证据已绑定 | src/game/campaign.ts:232 | dsp_side_blueprint | rule:campaign:side_blueprint / manual:campaign:side_blueprint |
| campaign:side_rare_resource | — | 已验证；当前行为证据已绑定 | src/game/campaign.ts:224 | dsp_side_rare_resource | rule:campaign:side_rare_resource / manual:campaign:side_rare_resource |
| campaign:side_spray_coater | — | 已验证；当前行为证据已绑定 | src/game/campaign.ts:228 | dsp_side_spray_coater | rule:campaign:side_spray_coater / manual:campaign:side_spray_coater |
| campaign:side_stable_power | — | 已验证；当前行为证据已绑定 | src/game/campaign.ts:216 | dsp_side_stable_power | rule:campaign:side_stable_power / manual:campaign:side_stable_power |
| campaign:side_storage | — | 已验证；当前行为证据已绑定 | src/game/campaign.ts:212 | dsp_side_storage | rule:campaign:side_storage / manual:campaign:side_storage |
| campaign:smelt_iron | — | 已验证；当前行为证据已绑定 | src/game/campaign.ts:128 | dsp_smelt_iron | rule:campaign:smelt_iron / manual:campaign:smelt_iron |
| campaign:unlock_borealis | — | 已验证；当前行为证据已绑定 | src/game/campaign.ts:172 | dsp_unlock_borealis | rule:campaign:unlock_borealis / manual:campaign:unlock_borealis |

## achievements

| key | 批次 | 状态/复核 | 源位置 | 当前映射 | 自动/人工编号 |
|---|---|---|---|---|---|
| achievements:automated_mining | — | 已验证；当前行为证据已绑定 | src/game/progression.ts:39 | dsp_automated_mining | rule:achievements:automated_mining / manual:achievements:automated_mining |
| achievements:dyson_swarm_online | — | 已验证；当前行为证据已绑定 | src/game/progression.ts:105 | dsp_dyson_swarm_online | rule:achievements:dyson_swarm_online / manual:achievements:dyson_swarm_online |
| achievements:electromagnetic_matrix_online | — | 已验证；当前行为证据已绑定 | src/game/progression.ts:61 | dsp_electromagnetic_matrix_online | rule:achievements:electromagnetic_matrix_online / manual:achievements:electromagnetic_matrix_online |
| achievements:energy_matrix_online | — | 已验证；当前行为证据已绑定 | src/game/progression.ts:68 | dsp_energy_matrix_online | rule:achievements:energy_matrix_online / manual:achievements:energy_matrix_online |
| achievements:first_logistics_line | — | 已验证；当前行为证据已绑定 | src/game/progression.ts:46 | dsp_first_logistics_line | rule:achievements:first_logistics_line / manual:achievements:first_logistics_line |
| achievements:first_manual_mine | — | 已验证；当前行为证据已绑定 | src/game/progression.ts:32 | dsp_first_manual_mine | rule:achievements:first_manual_mine / manual:achievements:first_manual_mine |
| achievements:interstellar_delivery | — | 已验证；当前行为证据已绑定 | src/game/progression.ts:89 | dsp_interstellar_delivery | rule:achievements:interstellar_delivery / manual:achievements:interstellar_delivery |
| achievements:multi_system_industry | — | 已验证；当前行为证据已绑定 | src/game/progression.ts:119 | dsp_multi_system_industry | rule:achievements:multi_system_industry / manual:achievements:multi_system_industry |
| achievements:permanent_dyson_structure | — | 已验证；当前行为证据已绑定 | src/game/progression.ts:112 | dsp_permanent_dyson_structure | rule:achievements:permanent_dyson_structure / manual:achievements:permanent_dyson_structure |
| achievements:planetary_logistics_online | — | 已验证；当前行为证据已绑定 | src/game/progression.ts:82 | dsp_planetary_logistics_online | rule:achievements:planetary_logistics_online / manual:achievements:planetary_logistics_online |
| achievements:rare_resource_harvest | — | 已验证；当前行为证据已绑定 | src/game/progression.ts:98 | dsp_rare_resource_harvest | rule:achievements:rare_resource_harvest / manual:achievements:rare_resource_harvest |
| achievements:six_matrix_mastery | — | 已验证；当前行为证据已绑定 | src/game/progression.ts:75 | dsp_six_matrix_mastery | rule:achievements:six_matrix_mastery / manual:achievements:six_matrix_mastery |
| achievements:stable_power_grid | — | 已验证；当前行为证据已绑定 | src/game/progression.ts:53 | dsp_stable_power_grid | rule:achievements:stable_power_grid / manual:achievements:stable_power_grid |

## difficulties

| key | 批次 | 状态/复核 | 源位置 | 当前映射 | 自动/人工编号 |
|---|---|---|---|---|---|
| difficulties:hard | B5 | 实现中；候选待源行为比较 | src/game/difficulty.ts:38 | scripts/game/GameModeSystem.gd::configure_new_game | rule:difficulties:hard / manual:difficulties:hard |
| difficulties:relaxed | B5 | 实现中；候选待源行为比较 | src/game/difficulty.ts:20 | scripts/game/GameModeSystem.gd::configure_new_game | rule:difficulties:relaxed / manual:difficulties:relaxed |
| difficulties:standard | B5 | 实现中；候选待源行为比较 | src/game/difficulty.ts:29 | scripts/game/GameModeSystem.gd::configure_new_game | rule:difficulties:standard / manual:difficulties:standard |

## matrices

| key | 批次 | 状态/复核 | 源位置 | 当前映射 | 自动/人工编号 |
|---|---|---|---|---|---|
| matrices:electromagnetic_matrix | B2 | 实现中；候选待源行为比较 | src/game/content.ts:642 | electromagnetic_matrix | rule:matrices:electromagnetic_matrix / manual:matrices:electromagnetic_matrix |
| matrices:energy_matrix | B2 | 实现中；候选待源行为比较 | src/game/content.ts:643 | energy_matrix | rule:matrices:energy_matrix / manual:matrices:energy_matrix |
| matrices:gravity_matrix | B2 | 实现中；候选待源行为比较 | src/game/content.ts:646 | gravity_matrix | rule:matrices:gravity_matrix / manual:matrices:gravity_matrix |
| matrices:information_matrix | B2 | 实现中；候选待源行为比较 | src/game/content.ts:645 | information_matrix | rule:matrices:information_matrix / manual:matrices:information_matrix |
| matrices:structure_matrix | B2 | 实现中；候选待源行为比较 | src/game/content.ts:644 | structure_matrix | rule:matrices:structure_matrix / manual:matrices:structure_matrix |
| matrices:universe_matrix | B2 | 实现中；候选待源行为比较 | src/game/content.ts:647 | universe_matrix | rule:matrices:universe_matrix / manual:matrices:universe_matrix |

## belts

| key | 批次 | 状态/复核 | 源位置 | 当前映射 | 自动/人工编号 |
|---|---|---|---|---|---|
| belts:conveyor_belt_mk1 | — | 已验证；当前行为证据已绑定 | src/game/content.ts:681 | scripts/game/GameState.gd::get_belt_configuration | rule:belts:conveyor_belt_mk1 / manual:belts:conveyor_belt_mk1 |
| belts:conveyor_belt_mk2 | — | 已验证；当前行为证据已绑定 | src/game/content.ts:682 | scripts/game/GameState.gd::get_belt_configuration | rule:belts:conveyor_belt_mk2 / manual:belts:conveyor_belt_mk2 |
| belts:conveyor_belt_mk3 | — | 已验证；当前行为证据已绑定 | src/game/content.ts:683 | scripts/game/GameState.gd::get_belt_configuration | rule:belts:conveyor_belt_mk3 / manual:belts:conveyor_belt_mk3 |

## construction

| key | 批次 | 状态/复核 | 源位置 | 当前映射 | 自动/人工编号 |
|---|---|---|---|---|---|
| construction:accumulator | B2 | 实现中；候选待源行为比较 | src/game/content.ts:768 | dsp_accumulator | rule:construction:accumulator / manual:construction:accumulator |
| construction:arc_smelter | B2 | 实现中；候选待源行为比较 | src/game/content.ts:771 | dsp_arc_smelter | rule:construction:arc_smelter / manual:construction:arc_smelter |
| construction:artificial_star | B2 | 实现中；候选待源行为比较 | src/game/content.ts:767 | dsp_artificial_star | rule:construction:artificial_star / manual:construction:artificial_star |
| construction:assembling_machine_mk1 | B2 | 实现中；候选待源行为比较 | src/game/content.ts:773 | dsp_assembling_machine_mk1 | rule:construction:assembling_machine_mk1 / manual:construction:assembling_machine_mk1 |
| construction:assembling_machine_mk2 | B2 | 实现中；候选待源行为比较 | src/game/content.ts:774 | dsp_assembling_machine_mk2 | rule:construction:assembling_machine_mk2 / manual:construction:assembling_machine_mk2 |
| construction:assembling_machine_mk3 | B2 | 实现中；候选待源行为比较 | src/game/content.ts:775 | dsp_assembling_machine_mk3 | rule:construction:assembling_machine_mk3 / manual:construction:assembling_machine_mk3 |
| construction:chemical_plant | B2 | 实现中；候选待源行为比较 | src/game/content.ts:789 | dsp_chemical_plant | rule:construction:chemical_plant / manual:construction:chemical_plant |
| construction:construction_center | B2 | 实现中；候选待源行为比较 | src/game/content.ts:799 | dsp_construction_center | rule:construction:construction_center / manual:construction:construction_center |
| construction:conveyor_belt_mk1 | B2 | 实现中；候选待源行为比较 | src/game/content.ts:778 | dsp_conveyor_belt_mk1 | rule:construction:conveyor_belt_mk1 / manual:construction:conveyor_belt_mk1 |
| construction:conveyor_belt_mk2 | B2 | 实现中；候选待源行为比较 | src/game/content.ts:779 | dsp_conveyor_belt_mk2 | rule:construction:conveyor_belt_mk2 / manual:construction:conveyor_belt_mk2 |
| construction:conveyor_belt_mk3 | B2 | 实现中；候选待源行为比较 | src/game/content.ts:780 | dsp_conveyor_belt_mk3 | rule:construction:conveyor_belt_mk3 / manual:construction:conveyor_belt_mk3 |
| construction:em_rail_ejector | B4 | 实现中；候选待源行为比较 | src/game/content.ts:793 | dsp_em_rail_ejector | rule:construction:em_rail_ejector / manual:construction:em_rail_ejector |
| construction:energy_exchanger | B2 | 实现中；候选待源行为比较 | src/game/content.ts:769 | dsp_energy_exchanger | rule:construction:energy_exchanger / manual:construction:energy_exchanger |
| construction:fractionator | B2 | 实现中；候选待源行为比较 | src/game/content.ts:791 | dsp_fractionator | rule:construction:fractionator / manual:construction:fractionator |
| construction:galactic_material_exporter | B4 | 实现中；候选待源行为比较 | src/game/content.ts:800 | dsp_galactic_material_exporter | rule:construction:galactic_material_exporter / manual:construction:galactic_material_exporter |
| construction:geothermal_power_station | B3 | 实现中；候选待源行为比较 | src/game/content.ts:764 | dsp_geothermal_power_station | rule:construction:geothermal_power_station / manual:construction:geothermal_power_station |
| construction:interstellar_logistics_station | B3 | 实现中；候选待源行为比较 | src/game/content.ts:797 | dsp_interstellar_logistics_station | rule:construction:interstellar_logistics_station / manual:construction:interstellar_logistics_station |
| construction:material_delivery_hub | B2 | 实现中；候选待源行为比较 | src/game/content.ts:782 | dsp_material_delivery_hub | rule:construction:material_delivery_hub / manual:construction:material_delivery_hub |
| construction:matrix_lab | B2 | 实现中；候选待源行为比较 | src/game/content.ts:777 | dsp_matrix_lab | rule:construction:matrix_lab / manual:construction:matrix_lab |
| construction:micro_black_hole_connector | B4 | 实现中；候选待源行为比较 | src/game/content.ts:801 | dsp_micro_black_hole_connector | rule:construction:micro_black_hole_connector / manual:construction:micro_black_hole_connector |
| construction:mini_fusion_power_plant | B2 | 实现中；候选待源行为比较 | src/game/content.ts:766 | dsp_mini_fusion_power_plant | rule:construction:mini_fusion_power_plant / manual:construction:mini_fusion_power_plant |
| construction:miniature_particle_collider | B2 | 实现中；候选待源行为比较 | src/game/content.ts:792 | dsp_miniature_particle_collider | rule:construction:miniature_particle_collider / manual:construction:miniature_particle_collider |
| construction:mining_machine | B2 | 实现中；候选待源行为比较 | src/game/content.ts:770 | dsp_mining_machine | rule:construction:mining_machine / manual:construction:mining_machine |
| construction:oil_extractor | B2 | 实现中；候选待源行为比较 | src/game/content.ts:786 | dsp_oil_extractor | rule:construction:oil_extractor / manual:construction:oil_extractor |
| construction:oil_refinery | B2 | 实现中；候选待源行为比较 | src/game/content.ts:787 | dsp_oil_refinery | rule:construction:oil_refinery / manual:construction:oil_refinery |
| construction:orbital_cargo_terminal | B3 | 实现中；候选待源行为比较 | src/game/content.ts:783 | dsp_orbital_cargo_terminal | rule:construction:orbital_cargo_terminal / manual:construction:orbital_cargo_terminal |
| construction:orbital_collector | B3 | 实现中；候选待源行为比较 | src/game/content.ts:798 | dsp_orbital_collector | rule:construction:orbital_collector / manual:construction:orbital_collector |
| construction:plane_smelter | B2 | 实现中；候选待源行为比较 | src/game/content.ts:772 | dsp_plane_smelter | rule:construction:plane_smelter / manual:construction:plane_smelter |
| construction:planetary_logistics_station | B3 | 实现中；候选待源行为比较 | src/game/content.ts:796 | dsp_planetary_logistics_station | rule:construction:planetary_logistics_station / manual:construction:planetary_logistics_station |
| construction:quantum_chemical_plant | B3 | 实现中；候选待源行为比较 | src/game/content.ts:790 | dsp_quantum_chemical_plant | rule:construction:quantum_chemical_plant / manual:construction:quantum_chemical_plant |
| construction:ray_receiver | B2 | 实现中；候选待源行为比较 | src/game/content.ts:794 | dsp_ray_receiver | rule:construction:ray_receiver / manual:construction:ray_receiver |
| construction:solar_panel | B2 | 实现中；候选待源行为比较 | src/game/content.ts:763 | dsp_solar_panel | rule:construction:solar_panel / manual:construction:solar_panel |
| construction:space_station_construction_launcher | B4 | 实现中；候选待源行为比较 | src/game/content.ts:803 | dsp_space_station_construction_launcher | rule:construction:space_station_construction_launcher / manual:construction:space_station_construction_launcher |
| construction:splitter_4way | B2 | 实现中；候选待源行为比较 | src/game/content.ts:784 | dsp_splitter_4way | rule:construction:splitter_4way / manual:construction:splitter_4way |
| construction:spray_coater | B2 | 实现中；候选待源行为比较 | src/game/content.ts:776 | dsp_spray_coater | rule:construction:spray_coater / manual:construction:spray_coater |
| construction:storage_mk1 | B2 | 实现中；候选待源行为比较 | src/game/content.ts:781 | dsp_storage_mk1 | rule:construction:storage_mk1 / manual:construction:storage_mk1 |
| construction:storage_tank | B2 | 实现中；候选待源行为比较 | src/game/content.ts:785 | dsp_storage_tank | rule:construction:storage_tank / manual:construction:storage_tank |
| construction:thermal_power_plant | B2 | 实现中；候选待源行为比较 | src/game/content.ts:765 | dsp_thermal_power_plant | rule:construction:thermal_power_plant / manual:construction:thermal_power_plant |
| construction:time_warp_device | B5 | 实现中；候选待源行为比较 | src/game/content.ts:802 | dsp_time_warp_device | rule:construction:time_warp_device / manual:construction:time_warp_device |
| construction:vertical_launching_silo | B2 | 实现中；候选待源行为比较 | src/game/content.ts:795 | dsp_vertical_launching_silo | rule:construction:vertical_launching_silo / manual:construction:vertical_launching_silo |
| construction:water_pump | B2 | 实现中；候选待源行为比较 | src/game/content.ts:788 | dsp_water_pump | rule:construction:water_pump / manual:construction:water_pump |
| construction:wind_turbine | B2 | 实现中；候选待源行为比较 | src/game/content.ts:762 | dsp_wind_turbine | rule:construction:wind_turbine / manual:construction:wind_turbine |

## proliferators

| key | 批次 | 状态/复核 | 源位置 | 当前映射 | 自动/人工编号 |
|---|---|---|---|---|---|
| proliferators:proliferator_mk1 | B2 | 实现中；候选待源行为比较 | src/game/content.ts:604 | proliferator_mk1 | rule:proliferators:proliferator_mk1 / manual:proliferators:proliferator_mk1 |
| proliferators:proliferator_mk2 | B2 | 实现中；候选待源行为比较 | src/game/content.ts:605 | proliferator_mk2 | rule:proliferators:proliferator_mk2 / manual:proliferators:proliferator_mk2 |
| proliferators:proliferator_mk3 | B2 | 实现中；候选待源行为比较 | src/game/content.ts:606 | proliferator_mk3 | rule:proliferators:proliferator_mk3 / manual:proliferators:proliferator_mk3 |

## workspaces

| key | 批次 | 状态/复核 | 源位置 | 当前映射 | 自动/人工编号 |
|---|---|---|---|---|---|
| workspaces:BlueprintWorkspace | B2 | 实现中；候选待源行为比较 | src/components/BlueprintWorkspace.tsx:1 | scenes/ui/BlueprintWorkspace.gd::_ready | rule:workspaces:BlueprintWorkspace / manual:workspaces:BlueprintWorkspace |
| workspaces:CampaignWorkspace | — | 已验证；当前行为证据已绑定 | src/components/CampaignWorkspace.tsx:1 | scenes/ui/CampaignWorkspace.gd::_ready | rule:workspaces:CampaignWorkspace / manual:workspaces:CampaignWorkspace |
| workspaces:ConstructionCenterWorkspace | B2 | 实现中；候选待源行为比较 | src/components/ConstructionCenterWorkspace.tsx:1 | scenes/ui/ProductionCatalogWorkspace.gd | rule:workspaces:ConstructionCenterWorkspace / manual:workspaces:ConstructionCenterWorkspace |
| workspaces:DysonPlannerWorkspace | B4 | 实现中；候选待源行为比较 | src/components/DysonPlannerWorkspace.tsx:1 | scenes/ui/DysonUI.gd | rule:workspaces:DysonPlannerWorkspace / manual:workspaces:DysonPlannerWorkspace |
| workspaces:GalaxyWorkspace | — | 在线排除；固定在线白名单 | src/components/GalaxyWorkspace.tsx:1 | 尚未确认 | rule:workspaces:GalaxyWorkspace / manual:workspaces:GalaxyWorkspace |
| workspaces:OfflineReportWorkspace | B2 | 实现中；候选待源行为比较 | src/components/OfflineReportWorkspace.tsx:1 | scenes/ui/OfflineReportWorkspace.gd | rule:workspaces:OfflineReportWorkspace / manual:workspaces:OfflineReportWorkspace |
| workspaces:OperationsWorkspace | B2 | 实现中；候选待源行为比较 | src/components/OperationsWorkspace.tsx:1 | scenes/ui/SettingsWorkspace.gd | rule:workspaces:OperationsWorkspace / manual:workspaces:OperationsWorkspace |
| workspaces:OrbitalStationWorkspace | B3 | 实现中；候选待源行为比较 | src/components/OrbitalStationWorkspace.tsx:1 | scenes/ui/LocalSpaceStationWorkspace.gd | rule:workspaces:OrbitalStationWorkspace / manual:workspaces:OrbitalStationWorkspace |
| workspaces:RecipeWorkspace | B2 | 实现中；候选待源行为比较 | src/components/RecipeWorkspace.tsx:1 | scenes/ui/ProductionCatalogWorkspace.gd | rule:workspaces:RecipeWorkspace / manual:workspaces:RecipeWorkspace |
| workspaces:StarMapWorkspace | B3 | 实现中；候选待源行为比较 | src/components/StarMapWorkspace.tsx:1 | scenes/ui/GalaxyMap.gd | rule:workspaces:StarMapWorkspace / manual:workspaces:StarMapWorkspace |
| workspaces:StatisticsWorkspace | B2 | 未实现；部分能力存在，完整契约待补 | src/components/StatisticsWorkspace.tsx:1 | 尚未确认 | rule:workspaces:StatisticsWorkspace / manual:workspaces:StatisticsWorkspace |
| workspaces:SystemSpaceStationWorkspace | B4 | 实现中；候选待源行为比较 | src/components/SystemSpaceStationWorkspace.tsx:1 | scenes/ui/SystemSpaceStationWorkspace.gd | rule:workspaces:SystemSpaceStationWorkspace / manual:workspaces:SystemSpaceStationWorkspace |
| workspaces:TechnologyWorkspace | B2 | 实现中；候选待源行为比较 | src/components/TechnologyWorkspace.tsx:1 | scenes/ui/TechnologyPanel.gd::_ready | rule:workspaces:TechnologyWorkspace / manual:workspaces:TechnologyWorkspace |
| workspaces:TutorialWorkspace | B2 | 实现中；候选待源行为比较 | src/components/TutorialWorkspace.tsx:1 | scenes/ui/TutorialOverlay.gd::_ready | rule:workspaces:TutorialWorkspace / manual:workspaces:TutorialWorkspace |

## commands

| key | 批次 | 状态/复核 | 源位置 | 当前映射 | 自动/人工编号 |
|---|---|---|---|---|---|
| commands:AccessibleDialog.onRequestClose | B5 | 未实现；待逐项核实/映射 | src/components/AccessibleDialog.tsx:33 | 尚未确认 | rule:commands:AccessibleDialog.onRequestClose / manual:commands:AccessibleDialog.onRequestClose |
| commands:BlueprintWorkspace.onAutoLayout | B2 | 未实现；待逐项核实/映射 | src/components/BlueprintWorkspace.tsx:43 | 尚未确认 | rule:commands:BlueprintWorkspace.onAutoLayout / manual:commands:BlueprintWorkspace.onAutoLayout |
| commands:BlueprintWorkspace.onBatchConnectionModeChange | B2 | 未实现；待逐项核实/映射 | src/components/BlueprintWorkspace.tsx:40 | 尚未确认 | rule:commands:BlueprintWorkspace.onBatchConnectionModeChange / manual:commands:BlueprintWorkspace.onBatchConnectionModeChange |
| commands:BlueprintWorkspace.onBatchIncrease | B2 | 未实现；待逐项核实/映射 | src/components/BlueprintWorkspace.tsx:186 | 尚未确认 | rule:commands:BlueprintWorkspace.onBatchIncrease / manual:commands:BlueprintWorkspace.onBatchIncrease |
| commands:BlueprintWorkspace.onCancelQueue | B2 | 实现中；候选待源行为比较 | src/components/BlueprintWorkspace.tsx:458 | scenes/ui/BlueprintLibraryControls.gd::_cancel | rule:commands:BlueprintWorkspace.onCancelQueue / manual:commands:BlueprintWorkspace.onCancelQueue |
| commands:BlueprintWorkspace.onChange | B2 | 未实现；待逐项核实/映射 | src/components/BlueprintWorkspace.tsx:157 | 尚未确认 | rule:commands:BlueprintWorkspace.onChange / manual:commands:BlueprintWorkspace.onChange |
| commands:BlueprintWorkspace.onClear | B2 | 实现中；候选待源行为比较 | src/components/BlueprintWorkspace.tsx:190 | scenes/ui/BlueprintWorkspace.gd::clear_draft | rule:commands:BlueprintWorkspace.onClear / manual:commands:BlueprintWorkspace.onClear |
| commands:BlueprintWorkspace.onClose | B2 | 实现中；候选待源行为比较 | src/components/BlueprintWorkspace.tsx:159 | scenes/ui/BlueprintWorkspace.gd::_hide_workspace | rule:commands:BlueprintWorkspace.onClose / manual:commands:BlueprintWorkspace.onClose |
| commands:BlueprintWorkspace.onCopy | B2 | 实现中；候选待源行为比较 | src/components/BlueprintWorkspace.tsx:183 | scenes/ui/BlueprintWorkspace.gd::capture_selection | rule:commands:BlueprintWorkspace.onCopy / manual:commands:BlueprintWorkspace.onCopy |
| commands:BlueprintWorkspace.onDeploy | B2 | 实现中；候选待源行为比较 | src/components/BlueprintWorkspace.tsx:451 | scenes/ui/BlueprintWorkspace.gd::request_deployment | rule:commands:BlueprintWorkspace.onDeploy / manual:commands:BlueprintWorkspace.onDeploy |
| commands:BlueprintWorkspace.onDone | B2 | 未实现；待逐项核实/映射 | src/components/BlueprintWorkspace.tsx:191 | 尚未确认 | rule:commands:BlueprintWorkspace.onDone / manual:commands:BlueprintWorkspace.onDone |
| commands:BlueprintWorkspace.onExport | B2 | 实现中；候选待源行为比较 | src/components/BlueprintWorkspace.tsx:459 | scenes/ui/BlueprintWorkspace.gd::export_to_clipboard | rule:commands:BlueprintWorkspace.onExport / manual:commands:BlueprintWorkspace.onExport |
| commands:BlueprintWorkspace.onFocus | B2 | 未实现；待逐项核实/映射 | src/components/BlueprintWorkspace.tsx:181 | 尚未确认 | rule:commands:BlueprintWorkspace.onFocus / manual:commands:BlueprintWorkspace.onFocus |
| commands:BlueprintWorkspace.onFundAllQueues | B2 | 实现中；候选待源行为比较 | src/components/BlueprintWorkspace.tsx:457 | scenes/ui/BlueprintLibraryControls.gd::_ready | rule:commands:BlueprintWorkspace.onFundAllQueues / manual:commands:BlueprintWorkspace.onFundAllQueues |
| commands:BlueprintWorkspace.onFundQueue | B2 | 实现中；候选待源行为比较 | src/components/BlueprintWorkspace.tsx:456 | scenes/ui/BlueprintLibraryControls.gd::_fund | rule:commands:BlueprintWorkspace.onFundQueue / manual:commands:BlueprintWorkspace.onFundQueue |
| commands:BlueprintWorkspace.onImport | B2 | 实现中；候选待源行为比较 | src/components/BlueprintWorkspace.tsx:460 | scenes/ui/BlueprintWorkspace.gd::import_from_clipboard | rule:commands:BlueprintWorkspace.onImport / manual:commands:BlueprintWorkspace.onImport |
| commands:BlueprintWorkspace.onLock | B2 | 未实现；待逐项核实/映射 | src/components/BlueprintWorkspace.tsx:187 | 尚未确认 | rule:commands:BlueprintWorkspace.onLock / manual:commands:BlueprintWorkspace.onLock |
| commands:BlueprintWorkspace.onModeChange | B2 | 未实现；待逐项核实/映射 | src/components/BlueprintWorkspace.tsx:37 | 尚未确认 | rule:commands:BlueprintWorkspace.onModeChange / manual:commands:BlueprintWorkspace.onModeChange |
| commands:BlueprintWorkspace.onOpenBlueprints | B2 | 未实现；待逐项核实/映射 | src/components/BlueprintWorkspace.tsx:41 | 尚未确认 | rule:commands:BlueprintWorkspace.onOpenBlueprints / manual:commands:BlueprintWorkspace.onOpenBlueprints |
| commands:BlueprintWorkspace.onOpenNetworks | B2 | 未实现；待逐项核实/映射 | src/components/BlueprintWorkspace.tsx:42 | 尚未确认 | rule:commands:BlueprintWorkspace.onOpenNetworks / manual:commands:BlueprintWorkspace.onOpenNetworks |
| commands:BlueprintWorkspace.onRecipeOverride | B2 | 实现中；候选待源行为比较 | src/components/BlueprintWorkspace.tsx:455 | scenes/ui/BlueprintLibraryControls.gd::_replace_recipe | rule:commands:BlueprintWorkspace.onRecipeOverride / manual:commands:BlueprintWorkspace.onRecipeOverride |
| commands:BlueprintWorkspace.onRedo | B2 | 未实现；待逐项核实/映射 | src/components/BlueprintWorkspace.tsx:46 | 尚未确认 | rule:commands:BlueprintWorkspace.onRedo / manual:commands:BlueprintWorkspace.onRedo |
| commands:BlueprintWorkspace.onRegionModeChange | B2 | 未实现；待逐项核实/映射 | src/components/BlueprintWorkspace.tsx:38 | 尚未确认 | rule:commands:BlueprintWorkspace.onRegionModeChange / manual:commands:BlueprintWorkspace.onRegionModeChange |
| commands:BlueprintWorkspace.onRemove | B2 | 实现中；候选待源行为比较 | src/components/BlueprintWorkspace.tsx:158 | scenes/ui/BlueprintLibraryControls.gd::_remove | rule:commands:BlueprintWorkspace.onRemove / manual:commands:BlueprintWorkspace.onRemove |
| commands:BlueprintWorkspace.onRename | B2 | 实现中；候选待源行为比较 | src/components/BlueprintWorkspace.tsx:453 | scenes/ui/BlueprintLibraryControls.gd::_save | rule:commands:BlueprintWorkspace.onRename / manual:commands:BlueprintWorkspace.onRename |
| commands:BlueprintWorkspace.onResizeStart | B2 | 未实现；待逐项核实/映射 | src/components/BlueprintWorkspace.tsx:105 | 尚未确认 | rule:commands:BlueprintWorkspace.onResizeStart / manual:commands:BlueprintWorkspace.onResizeStart |
| commands:BlueprintWorkspace.onSelect | B2 | 实现中；候选待源行为比较 | src/components/BlueprintWorkspace.tsx:104 | scenes/ui/BlueprintLibraryControls.gd::_load_selected | rule:commands:BlueprintWorkspace.onSelect / manual:commands:BlueprintWorkspace.onSelect |
| commands:BlueprintWorkspace.onToggleLeftSidebar | B2 | 未实现；待逐项核实/映射 | src/components/BlueprintWorkspace.tsx:47 | 尚未确认 | rule:commands:BlueprintWorkspace.onToggleLeftSidebar / manual:commands:BlueprintWorkspace.onToggleLeftSidebar |
| commands:BlueprintWorkspace.onToggleLineFindMode | B2 | 未实现；待逐项核实/映射 | src/components/BlueprintWorkspace.tsx:39 | 尚未确认 | rule:commands:BlueprintWorkspace.onToggleLineFindMode / manual:commands:BlueprintWorkspace.onToggleLineFindMode |
| commands:BlueprintWorkspace.onToggleRightSidebar | B2 | 未实现；待逐项核实/映射 | src/components/BlueprintWorkspace.tsx:48 | 尚未确认 | rule:commands:BlueprintWorkspace.onToggleRightSidebar / manual:commands:BlueprintWorkspace.onToggleRightSidebar |
| commands:BlueprintWorkspace.onTransform | B2 | 实现中；候选待源行为比较 | src/components/BlueprintWorkspace.tsx:454 | scenes/ui/BlueprintWorkspace.gd::rotate_preview | rule:commands:BlueprintWorkspace.onTransform / manual:commands:BlueprintWorkspace.onTransform |
| commands:BlueprintWorkspace.onUndo | B2 | 未实现；待逐项核实/映射 | src/components/BlueprintWorkspace.tsx:45 | 尚未确认 | rule:commands:BlueprintWorkspace.onUndo / manual:commands:BlueprintWorkspace.onUndo |
| commands:BlueprintWorkspace.onUndoAutoLayout | B2 | 未实现；待逐项核实/映射 | src/components/BlueprintWorkspace.tsx:44 | 尚未确认 | rule:commands:BlueprintWorkspace.onUndoAutoLayout / manual:commands:BlueprintWorkspace.onUndoAutoLayout |
| commands:BlueprintWorkspace.onUnlock | B2 | 未实现；待逐项核实/映射 | src/components/BlueprintWorkspace.tsx:188 | 尚未确认 | rule:commands:BlueprintWorkspace.onUnlock / manual:commands:BlueprintWorkspace.onUnlock |
| commands:BlueprintWorkspace.onUpgrade | B2 | 未实现；待逐项核实/映射 | src/components/BlueprintWorkspace.tsx:184 | 尚未确认 | rule:commands:BlueprintWorkspace.onUpgrade / manual:commands:BlueprintWorkspace.onUpgrade |
| commands:BlueprintWorkspace.onUpgradeBelts | B2 | 未实现；待逐项核实/映射 | src/components/BlueprintWorkspace.tsx:185 | 尚未确认 | rule:commands:BlueprintWorkspace.onUpgradeBelts / manual:commands:BlueprintWorkspace.onUpgradeBelts |
| commands:CampaignWorkspace.onClose | — | 已验证；当前行为证据已绑定 | src/components/CampaignWorkspace.tsx:63 | scenes/ui/CampaignWorkspace.gd::_close_workspace | rule:commands:CampaignWorkspace.onClose / manual:commands:CampaignWorkspace.onClose |
| commands:CampaignWorkspace.onNavigate | — | 已验证；当前行为证据已绑定 | src/components/CampaignWorkspace.tsx:64 | scenes/ui/CampaignWorkspace.gd::_navigate_source | rule:commands:CampaignWorkspace.onNavigate / manual:commands:CampaignWorkspace.onNavigate |
| commands:CampaignWorkspace.onSelectTask | — | 已验证；当前行为证据已绑定 | src/components/CampaignWorkspace.tsx:65 | scenes/ui/CampaignWorkspace.gd::_source_action | rule:commands:CampaignWorkspace.onSelectTask / manual:commands:CampaignWorkspace.onSelectTask |
| commands:CanvasBeltLayer.onUnavailable | B2 | 未实现；待逐项核实/映射 | src/components/CanvasBeltLayer.tsx:19 | 尚未确认 | rule:commands:CanvasBeltLayer.onUnavailable / manual:commands:CanvasBeltLayer.onUnavailable |
| commands:CanvasInteractionOverlay.onPointerPosition | B2 | 未实现；待逐项核实/映射 | src/components/CanvasInteractionOverlay.tsx:26 | 尚未确认 | rule:commands:CanvasInteractionOverlay.onPointerPosition / manual:commands:CanvasInteractionOverlay.onPointerPosition |
| commands:CanvasMiniMap.onCenter | B2 | 未实现；待逐项核实/映射 | src/components/CanvasMiniMap.tsx:11 | 尚未确认 | rule:commands:CanvasMiniMap.onCenter / manual:commands:CanvasMiniMap.onCenter |
| commands:CanvasMiniMap.onUnavailable | B2 | 未实现；待逐项核实/映射 | src/components/CanvasMiniMap.tsx:13 | 尚未确认 | rule:commands:CanvasMiniMap.onUnavailable / manual:commands:CanvasMiniMap.onUnavailable |
| commands:CanvasMiniMap.onZoom | B2 | 未实现；待逐项核实/映射 | src/components/CanvasMiniMap.tsx:12 | 尚未确认 | rule:commands:CanvasMiniMap.onZoom / manual:commands:CanvasMiniMap.onZoom |
| commands:CatalogPicker.onChange | B2 | 未实现；待逐项核实/映射 | src/components/CatalogPicker.tsx:25 | 尚未确认 | rule:commands:CatalogPicker.onChange / manual:commands:CatalogPicker.onChange |
| commands:CloudAccountSecurity.onLoggedOut | — | 在线排除；固定在线白名单 | src/components/CloudAccountSecurity.tsx:53 | 尚未确认 | rule:commands:CloudAccountSecurity.onLoggedOut / manual:commands:CloudAccountSecurity.onLoggedOut |
| commands:CloudAccountSecurity.onUserChange | — | 在线排除；固定在线白名单 | src/components/CloudAccountSecurity.tsx:52 | 尚未确认 | rule:commands:CloudAccountSecurity.onUserChange / manual:commands:CloudAccountSecurity.onUserChange |
| commands:CloudSaveConflictDialog.onCancel | — | 在线排除；固定在线白名单 | src/components/CloudSaveConflictDialog.tsx:15 | 尚未确认 | rule:commands:CloudSaveConflictDialog.onCancel / manual:commands:CloudSaveConflictDialog.onCancel |
| commands:CloudSaveConflictDialog.onExportCloud | — | 在线排除；固定在线白名单 | src/components/CloudSaveConflictDialog.tsx:14 | 尚未确认 | rule:commands:CloudSaveConflictDialog.onExportCloud / manual:commands:CloudSaveConflictDialog.onExportCloud |
| commands:CloudSaveConflictDialog.onExportLocal | — | 在线排除；固定在线白名单 | src/components/CloudSaveConflictDialog.tsx:13 | 尚未确认 | rule:commands:CloudSaveConflictDialog.onExportLocal / manual:commands:CloudSaveConflictDialog.onExportLocal |
| commands:CloudSaveConflictDialog.onKeepLocal | — | 在线排除；固定在线白名单 | src/components/CloudSaveConflictDialog.tsx:12 | 尚未确认 | rule:commands:CloudSaveConflictDialog.onKeepLocal / manual:commands:CloudSaveConflictDialog.onKeepLocal |
| commands:CloudSaveConflictDialog.onUseCloud | — | 在线排除；固定在线白名单 | src/components/CloudSaveConflictDialog.tsx:11 | 尚未确认 | rule:commands:CloudSaveConflictDialog.onUseCloud / manual:commands:CloudSaveConflictDialog.onUseCloud |
| commands:CloudSaveSlotsPanel.onDelete | — | 在线排除；固定在线白名单 | src/components/CloudSaveSlotsPanel.tsx:46 | 尚未确认 | rule:commands:CloudSaveSlotsPanel.onDelete / manual:commands:CloudSaveSlotsPanel.onDelete |
| commands:CloudSaveSlotsPanel.onDownload | — | 在线排除；固定在线白名单 | src/components/CloudSaveSlotsPanel.tsx:45 | 尚未确认 | rule:commands:CloudSaveSlotsPanel.onDownload / manual:commands:CloudSaveSlotsPanel.onDownload |
| commands:CloudSaveSlotsPanel.onUpload | — | 在线排除；固定在线白名单 | src/components/CloudSaveSlotsPanel.tsx:44 | 尚未确认 | rule:commands:CloudSaveSlotsPanel.onUpload / manual:commands:CloudSaveSlotsPanel.onUpload |
| commands:CloudSaveStatusCenter.onCancel | — | 在线排除；固定在线白名单 | src/components/CloudSaveStatusCenter.tsx:19 | 尚未确认 | rule:commands:CloudSaveStatusCenter.onCancel / manual:commands:CloudSaveStatusCenter.onCancel |
| commands:CloudSaveStatusCenter.onExportCloud | — | 在线排除；固定在线白名单 | src/components/CloudSaveStatusCenter.tsx:21 | 尚未确认 | rule:commands:CloudSaveStatusCenter.onExportCloud / manual:commands:CloudSaveStatusCenter.onExportCloud |
| commands:CloudSaveStatusCenter.onExportLocal | — | 在线排除；固定在线白名单 | src/components/CloudSaveStatusCenter.tsx:20 | 尚未确认 | rule:commands:CloudSaveStatusCenter.onExportLocal / manual:commands:CloudSaveStatusCenter.onExportLocal |
| commands:CloudSaveStatusCenter.onRetry | — | 在线排除；固定在线白名单 | src/components/CloudSaveStatusCenter.tsx:18 | 尚未确认 | rule:commands:CloudSaveStatusCenter.onRetry / manual:commands:CloudSaveStatusCenter.onRetry |
| commands:CodexSections.onChange | B2 | 未实现；待逐项核实/映射 | src/components/CodexSections.tsx:95 | 尚未确认 | rule:commands:CodexSections.onChange / manual:commands:CodexSections.onChange |
| commands:CodexSections.onQuery | B2 | 未实现；待逐项核实/映射 | src/components/CodexSections.tsx:103 | 尚未确认 | rule:commands:CodexSections.onQuery / manual:commands:CodexSections.onQuery |
| commands:CodexSections.onSelect | B2 | 未实现；待逐项核实/映射 | src/components/CodexSections.tsx:91 | 尚未确认 | rule:commands:CodexSections.onSelect / manual:commands:CodexSections.onSelect |
| commands:CodexSections.onSelectBuilding | B2 | 未实现；待逐项核实/映射 | src/components/CodexSections.tsx:159 | 尚未确认 | rule:commands:CodexSections.onSelectBuilding / manual:commands:CodexSections.onSelectBuilding |
| commands:CodexSections.onSelectItem | B2 | 未实现；待逐项核实/映射 | src/components/CodexSections.tsx:114 | 尚未确认 | rule:commands:CodexSections.onSelectItem / manual:commands:CodexSections.onSelectItem |
| commands:CodexSections.onSelectPlanet | B2 | 实现中；候选待源行为比较 | src/components/CodexSections.tsx:212 | scripts/game/PlanetSystem.gd::try_set_active_planet | rule:commands:CodexSections.onSelectPlanet / manual:commands:CodexSections.onSelectPlanet |
| commands:CodexSections.onSelectTechnology | B2 | 未实现；待逐项核实/映射 | src/components/CodexSections.tsx:126 | 尚未确认 | rule:commands:CodexSections.onSelectTechnology / manual:commands:CodexSections.onSelectTechnology |
| commands:CommandPalette.onAutoLayout | B2 | 实现中；候选待源行为比较 | src/components/CommandPalette.tsx:20 | scripts/game/FactoryAutoLayout.gd::apply | rule:commands:CommandPalette.onAutoLayout / manual:commands:CommandPalette.onAutoLayout |
| commands:CommandPalette.onClose | B2 | 实现中；候选待源行为比较 | src/components/CommandPalette.tsx:16 | scenes/ui/CommandPalette.gd::_input | rule:commands:CommandPalette.onClose / manual:commands:CommandPalette.onClose |
| commands:CommandPalette.onFocusEntity | B2 | 实现中；候选待源行为比较 | src/components/CommandPalette.tsx:19 | scenes/ui/FactoryWorkspaceUI.gd::_locate_entity | rule:commands:CommandPalette.onFocusEntity / manual:commands:CommandPalette.onFocusEntity |
| commands:CommandPalette.onFocusRecipe | B2 | 未实现；待逐项核实/映射 | src/components/CommandPalette.tsx:18 | 尚未确认 | rule:commands:CommandPalette.onFocusRecipe / manual:commands:CommandPalette.onFocusRecipe |
| commands:CommandPalette.onOpenWorkspace | B2 | 实现中；候选待源行为比较 | src/components/CommandPalette.tsx:17 | scenes/ui/FactoryWorkspaceUI.gd::open_command_palette | rule:commands:CommandPalette.onOpenWorkspace / manual:commands:CommandPalette.onOpenWorkspace |
| commands:CommandPalette.onPauseToggle | B2 | 未实现；待逐项核实/映射 | src/components/CommandPalette.tsx:21 | 尚未确认 | rule:commands:CommandPalette.onPauseToggle / manual:commands:CommandPalette.onPauseToggle |
| commands:CommandPalette.onTogglePerformance | B2 | 未实现；待逐项核实/映射 | src/components/CommandPalette.tsx:22 | 尚未确认 | rule:commands:CommandPalette.onTogglePerformance / manual:commands:CommandPalette.onTogglePerformance |
| commands:CommandPalette.onToggleReducedMotion | B2 | 未实现；待逐项核实/映射 | src/components/CommandPalette.tsx:23 | 尚未确认 | rule:commands:CommandPalette.onToggleReducedMotion / manual:commands:CommandPalette.onToggleReducedMotion |
| commands:ConstructionCenterWorkspace.onBatchTargetChange | B2 | 未实现；待逐项核实/映射 | src/components/ConstructionCenterWorkspace.tsx:122 | 尚未确认 | rule:commands:ConstructionCenterWorkspace.onBatchTargetChange / manual:commands:ConstructionCenterWorkspace.onBatchTargetChange |
| commands:ConstructionCenterWorkspace.onChange | B2 | 未实现；待逐项核实/映射 | src/components/ConstructionCenterWorkspace.tsx:66 | 尚未确认 | rule:commands:ConstructionCenterWorkspace.onChange / manual:commands:ConstructionCenterWorkspace.onChange |
| commands:ConstructionCenterWorkspace.onClose | B2 | 未实现；待逐项核实/映射 | src/components/ConstructionCenterWorkspace.tsx:119 | 尚未确认 | rule:commands:ConstructionCenterWorkspace.onClose / manual:commands:ConstructionCenterWorkspace.onClose |
| commands:ConstructionCenterWorkspace.onEnabledChange | B2 | 未实现；待逐项核实/映射 | src/components/ConstructionCenterWorkspace.tsx:120 | 尚未确认 | rule:commands:ConstructionCenterWorkspace.onEnabledChange / manual:commands:ConstructionCenterWorkspace.onEnabledChange |
| commands:ConstructionCenterWorkspace.onTargetChange | B2 | 未实现；待逐项核实/映射 | src/components/ConstructionCenterWorkspace.tsx:121 | 尚未确认 | rule:commands:ConstructionCenterWorkspace.onTargetChange / manual:commands:ConstructionCenterWorkspace.onTargetChange |
| commands:DysonPlannerWorkspace.onAddLayer | B4 | 实现中；候选待源行为比较 | src/components/DysonPlannerWorkspace.tsx:60 | scripts/game/SourceDysonEngineering.gd::add_layer | rule:commands:DysonPlannerWorkspace.onAddLayer / manual:commands:DysonPlannerWorkspace.onAddLayer |
| commands:DysonPlannerWorkspace.onAddNode | B4 | 实现中；候选待源行为比较 | src/components/DysonPlannerWorkspace.tsx:66 | scripts/game/SourceDysonEngineering.gd::add_node | rule:commands:DysonPlannerWorkspace.onAddNode / manual:commands:DysonPlannerWorkspace.onAddNode |
| commands:DysonPlannerWorkspace.onAddStandardLayer | B4 | 实现中；候选待源行为比较 | src/components/DysonPlannerWorkspace.tsx:61 | scripts/game/SourceDysonEngineering.gd::standard_layer | rule:commands:DysonPlannerWorkspace.onAddStandardLayer / manual:commands:DysonPlannerWorkspace.onAddStandardLayer |
| commands:DysonPlannerWorkspace.onAddSwarmOrbit | B4 | 实现中；候选待源行为比较 | src/components/DysonPlannerWorkspace.tsx:75 | scripts/game/DysonSphereSystem.gd::create_orbit | rule:commands:DysonPlannerWorkspace.onAddSwarmOrbit / manual:commands:DysonPlannerWorkspace.onAddSwarmOrbit |
| commands:DysonPlannerWorkspace.onAutoConnect | B4 | 实现中；候选待源行为比较 | src/components/DysonPlannerWorkspace.tsx:69 | scripts/game/SourceDysonEngineering.gd::auto_connect | rule:commands:DysonPlannerWorkspace.onAutoConnect / manual:commands:DysonPlannerWorkspace.onAutoConnect |
| commands:DysonPlannerWorkspace.onClearShell | B4 | 实现中；候选待源行为比较 | src/components/DysonPlannerWorkspace.tsx:71 | scripts/game/SourceDysonEngineering.gd::clear_shells | rule:commands:DysonPlannerWorkspace.onClearShell / manual:commands:DysonPlannerWorkspace.onClearShell |
| commands:DysonPlannerWorkspace.onClose | B4 | 实现中；候选待源行为比较 | src/components/DysonPlannerWorkspace.tsx:58 | scenes/ui/DysonUI.gd | rule:commands:DysonPlannerWorkspace.onClose / manual:commands:DysonPlannerWorkspace.onClose |
| commands:DysonPlannerWorkspace.onConnectNodes | B4 | 实现中；候选待源行为比较 | src/components/DysonPlannerWorkspace.tsx:68 | scripts/game/SourceDysonEngineering.gd::connect_nodes | rule:commands:DysonPlannerWorkspace.onConnectNodes / manual:commands:DysonPlannerWorkspace.onConnectNodes |
| commands:DysonPlannerWorkspace.onLaunchEnabledChange | B4 | 实现中；候选待源行为比较 | src/components/DysonPlannerWorkspace.tsx:74 | scripts/game/SourceDysonEngineering.gd::configure_schedule | rule:commands:DysonPlannerWorkspace.onLaunchEnabledChange / manual:commands:DysonPlannerWorkspace.onLaunchEnabledChange |
| commands:DysonPlannerWorkspace.onLaunchModeChange | B4 | 实现中；候选待源行为比较 | src/components/DysonPlannerWorkspace.tsx:72 | scripts/game/SourceDysonEngineering.gd::configure_schedule | rule:commands:DysonPlannerWorkspace.onLaunchModeChange / manual:commands:DysonPlannerWorkspace.onLaunchModeChange |
| commands:DysonPlannerWorkspace.onLaunchThrottleChange | B4 | 实现中；候选待源行为比较 | src/components/DysonPlannerWorkspace.tsx:73 | scripts/game/SourceDysonEngineering.gd::configure_schedule | rule:commands:DysonPlannerWorkspace.onLaunchThrottleChange / manual:commands:DysonPlannerWorkspace.onLaunchThrottleChange |
| commands:DysonPlannerWorkspace.onOrbitChange | B4 | 实现中；候选待源行为比较 | src/components/DysonPlannerWorkspace.tsx:63 | scripts/game/SourceDysonEngineering.gd::set_geometry | rule:commands:DysonPlannerWorkspace.onOrbitChange / manual:commands:DysonPlannerWorkspace.onOrbitChange |
| commands:DysonPlannerWorkspace.onPasteLayer | B4 | 实现中；候选待源行为比较 | src/components/DysonPlannerWorkspace.tsx:65 | scripts/game/SourceDysonEngineering.gd::paste_template | rule:commands:DysonPlannerWorkspace.onPasteLayer / manual:commands:DysonPlannerWorkspace.onPasteLayer |
| commands:DysonPlannerWorkspace.onPlanShell | B4 | 实现中；候选待源行为比较 | src/components/DysonPlannerWorkspace.tsx:70 | scripts/game/SourceDysonEngineering.gd::plan_shell | rule:commands:DysonPlannerWorkspace.onPlanShell / manual:commands:DysonPlannerWorkspace.onPlanShell |
| commands:DysonPlannerWorkspace.onRemoveLayer | B4 | 实现中；候选待源行为比较 | src/components/DysonPlannerWorkspace.tsx:64 | scripts/game/DysonSphereSystem.gd::remove_plan | rule:commands:DysonPlannerWorkspace.onRemoveLayer / manual:commands:DysonPlannerWorkspace.onRemoveLayer |
| commands:DysonPlannerWorkspace.onRemoveNode | B4 | 实现中；候选待源行为比较 | src/components/DysonPlannerWorkspace.tsx:67 | scripts/game/SourceDysonEngineering.gd::remove_node | rule:commands:DysonPlannerWorkspace.onRemoveNode / manual:commands:DysonPlannerWorkspace.onRemoveNode |
| commands:DysonPlannerWorkspace.onRemoveSwarmOrbit | B4 | 实现中；候选待源行为比较 | src/components/DysonPlannerWorkspace.tsx:78 | scripts/game/DysonSphereSystem.gd::remove_plan | rule:commands:DysonPlannerWorkspace.onRemoveSwarmOrbit / manual:commands:DysonPlannerWorkspace.onRemoveSwarmOrbit |
| commands:DysonPlannerWorkspace.onSave | B4 | 实现中；候选待源行为比较 | src/components/DysonPlannerWorkspace.tsx:59 | scenes/ui/DysonUI.gd | rule:commands:DysonPlannerWorkspace.onSave / manual:commands:DysonPlannerWorkspace.onSave |
| commands:DysonPlannerWorkspace.onSelectLayer | B4 | 实现中；候选待源行为比较 | src/components/DysonPlannerWorkspace.tsx:62 | scenes/ui/DysonUI.gd | rule:commands:DysonPlannerWorkspace.onSelectLayer / manual:commands:DysonPlannerWorkspace.onSelectLayer |
| commands:DysonPlannerWorkspace.onSelectSwarmOrbit | B4 | 实现中；候选待源行为比较 | src/components/DysonPlannerWorkspace.tsx:76 | scenes/ui/DysonUI.gd | rule:commands:DysonPlannerWorkspace.onSelectSwarmOrbit / manual:commands:DysonPlannerWorkspace.onSelectSwarmOrbit |
| commands:DysonPlannerWorkspace.onSwarmOrbitChange | B4 | 实现中；候选待源行为比较 | src/components/DysonPlannerWorkspace.tsx:77 | scripts/game/SourceDysonEngineering.gd::set_geometry | rule:commands:DysonPlannerWorkspace.onSwarmOrbitChange / manual:commands:DysonPlannerWorkspace.onSwarmOrbitChange |
| commands:engine.addBuildingToGroup | B2 | 未实现；待逐项核实/映射 | src/game/engine.ts:8754 | 尚未确认 | rule:commands:engine.addBuildingToGroup / manual:commands:engine.addBuildingToGroup |
| commands:engine.addCanvasBookmark | B2 | 实现中；候选待源行为比较 | src/game/engine.ts:9274 | scripts/game/CanvasNavigation.gd::save_bookmark | rule:commands:engine.addCanvasBookmark / manual:commands:engine.addCanvasBookmark |
| commands:engine.addCanvasRegion | B2 | 实现中；候选待源行为比较 | src/game/engine.ts:9311 | scripts/game/CanvasNavigation.gd::save_region | rule:commands:engine.addCanvasRegion / manual:commands:engine.addCanvasRegion |
| commands:engine.addDysonLayer | B4 | 实现中；候选待源行为比较 | src/game/engine.ts:3059 | scripts/game/SourceDysonEngineering.gd::add_layer | rule:commands:engine.addDysonLayer / manual:commands:engine.addDysonLayer |
| commands:engine.addDysonNode | B4 | 实现中；候选待源行为比较 | src/game/engine.ts:3183 | scripts/game/SourceDysonEngineering.gd::add_node | rule:commands:engine.addDysonNode / manual:commands:engine.addDysonNode |
| commands:engine.addDysonSwarmOrbit | B4 | 实现中；候选待源行为比较 | src/game/engine.ts:2878 | scripts/game/DysonSphereSystem.gd::create_orbit | rule:commands:engine.addDysonSwarmOrbit / manual:commands:engine.addDysonSwarmOrbit |
| commands:engine.addUnitToEntityGroup | B2 | 未实现；待逐项核实/映射 | src/game/engine.ts:8769 | 尚未确认 | rule:commands:engine.addUnitToEntityGroup / manual:commands:engine.addUnitToEntityGroup |
| commands:engine.adjustRemoteStationWarpers | B3 | 实现中；候选待源行为比较 | src/game/engine.ts:12054 | scripts/game/StationSystem.gd::transfer_fleet | rule:commands:engine.adjustRemoteStationWarpers / manual:commands:engine.adjustRemoteStationWarpers |
| commands:engine.adjustStationDrones | B3 | 实现中；候选待源行为比较 | src/game/engine.ts:12016 | scripts/game/StationSystem.gd::transfer_fleet | rule:commands:engine.adjustStationDrones / manual:commands:engine.adjustStationDrones |
| commands:engine.adjustStationVessels | B3 | 实现中；候选待源行为比较 | src/game/engine.ts:12010 | scripts/game/StationSystem.gd::transfer_fleet | rule:commands:engine.adjustStationVessels / manual:commands:engine.adjustStationVessels |
| commands:engine.adjustStationWarpers | B3 | 实现中；候选待源行为比较 | src/game/engine.ts:12047 | scripts/game/StationSystem.gd::transfer_fleet | rule:commands:engine.adjustStationWarpers / manual:commands:engine.adjustStationWarpers |
| commands:engine.advanceSimulation | B5 | 实现中；候选待源行为比较 | src/game/engine.ts:7108 | scripts/game/SimulationEngine.gd::update | rule:commands:engine.advanceSimulation / manual:commands:engine.advanceSimulation |
| commands:engine.advanceSimulationBudget | B5 | 实现中；候选待源行为比较 | src/game/engine.ts:7114 | scripts/game/SimulationEngine.gd::update | rule:commands:engine.advanceSimulationBudget / manual:commands:engine.advanceSimulationBudget |
| commands:engine.applyBeltConfiguration | B2 | 实现中；候选待源行为比较 | src/game/engine.ts:12618 | scripts/game/GameState.gd::apply_belt_configuration | rule:commands:engine.applyBeltConfiguration / manual:commands:engine.applyBeltConfiguration |
| commands:engine.applyBeltConfigurationToBelts | B2 | 实现中；候选待源行为比较 | src/game/engine.ts:12549 | scripts/game/GameState.gd::try_configure_belts | rule:commands:engine.applyBeltConfigurationToBelts / manual:commands:engine.applyBeltConfigurationToBelts |
| commands:engine.applyBeltConfigurationToNetwork | B2 | 实现中；候选待源行为比较 | src/game/engine.ts:12604 | scripts/game/GameState.gd::apply_belt_configuration_to_network | rule:commands:engine.applyBeltConfigurationToNetwork / manual:commands:engine.applyBeltConfigurationToNetwork |
| commands:engine.applyBeltConfigurationToNetworkResult | B2 | 实现中；候选待源行为比较 | src/game/engine.ts:12600 | scripts/game/GameState.gd::apply_belt_configuration_to_network | rule:commands:engine.applyBeltConfigurationToNetworkResult / manual:commands:engine.applyBeltConfigurationToNetworkResult |
| commands:engine.applyStationSlotTemplateToEntities | B3 | 实现中；候选待源行为比较 | src/game/engine.ts:11715 | scripts/game/StationSystem.gd::configure_slots | rule:commands:engine.applyStationSlotTemplateToEntities / manual:commands:engine.applyStationSlotTemplateToEntities |
| commands:engine.attachAllInterstellarStationsToQuantumNetwork | B3 | 实现中；候选待源行为比较 | src/game/engine.ts:11873 | scripts/game/QuantumLogisticsSystem.gd::attach_all | rule:commands:engine.attachAllInterstellarStationsToQuantumNetwork / manual:commands:engine.attachAllInterstellarStationsToQuantumNetwork |
| commands:engine.attachInterstellarStationToQuantumNetwork | B3 | 实现中；候选待源行为比较 | src/game/engine.ts:11777 | scripts/game/QuantumLogisticsSystem.gd::attach | rule:commands:engine.attachInterstellarStationToQuantumNetwork / manual:commands:engine.attachInterstellarStationToQuantumNetwork |
| commands:engine.autoConnectDysonLayer | B4 | 实现中；候选待源行为比较 | src/game/engine.ts:3234 | scripts/game/SourceDysonEngineering.gd::auto_connect | rule:commands:engine.autoConnectDysonLayer / manual:commands:engine.autoConnectDysonLayer |
| commands:engine.batchIncreaseSelection | B2 | 未实现；待逐项核实/映射 | src/game/engine.ts:11354 | 尚未确认 | rule:commands:engine.batchIncreaseSelection / manual:commands:engine.batchIncreaseSelection |
| commands:engine.cancelConstructionQueueEntry | B2 | 实现中；候选待源行为比较 | src/game/engine.ts:8629 | scripts/game/ConstructionQueueSystem.gd::cancel | rule:commands:engine.cancelConstructionQueueEntry / manual:commands:engine.cancelConstructionQueueEntry |
| commands:engine.cancelCurrentResearch | — | 已验证；当前行为证据已绑定 | src/game/engine.ts:13061 | scripts/game/TechnologySystem.gd::cancel_research | rule:commands:engine.cancelCurrentResearch / manual:commands:engine.cancelCurrentResearch |
| commands:engine.cancelHandcraftQueueEntry | B2 | 实现中；候选待源行为比较 | src/game/engine.ts:12861 | scripts/game/ConstructionAutomationSystem.gd::cancel | rule:commands:engine.cancelHandcraftQueueEntry / manual:commands:engine.cancelHandcraftQueueEntry |
| commands:engine.cancelQuantumStationAttachment | B3 | 实现中；候选待源行为比较 | src/game/engine.ts:11920 | scripts/game/QuantumLogisticsSystem.gd::cancel | rule:commands:engine.cancelQuantumStationAttachment / manual:commands:engine.cancelQuantumStationAttachment |
| commands:engine.canColonizePlanet | — | 已验证；当前行为证据已绑定 | src/game/engine.ts:7450 | scripts/game/PlanetSystem.gd::can_colonize_source_planet | rule:commands:engine.canColonizePlanet / manual:commands:engine.canColonizePlanet |
| commands:engine.canConnectBelt | B2 | 未实现；待逐项核实/映射 | src/game/engine.ts:11132 | 尚未确认 | rule:commands:engine.canConnectBelt / manual:commands:engine.canConnectBelt |
| commands:engine.canCraftConstruction | B2 | 实现中；候选待源行为比较 | src/game/engine.ts:12643 | scripts/game/CraftingPlanner.gd::plan | rule:commands:engine.canCraftConstruction / manual:commands:engine.canCraftConstruction |
| commands:engine.canEntityAcceptBeltItem | B2 | 未实现；待逐项核实/映射 | src/game/engine.ts:9170 | 尚未确认 | rule:commands:engine.canEntityAcceptBeltItem / manual:commands:engine.canEntityAcceptBeltItem |
| commands:engine.canExploreStarSystem | — | 已验证；当前行为证据已绑定 | src/game/engine.ts:7339 | scripts/game/GalaxySystem.gd::can_explore_source_system | rule:commands:engine.canExploreStarSystem / manual:commands:engine.canExploreStarSystem |
| commands:engine.canHandcraftRecipe | B2 | 实现中；候选待源行为比较 | src/game/engine.ts:12689 | scripts/game/CraftingPlanner.gd::plan | rule:commands:engine.canHandcraftRecipe / manual:commands:engine.canHandcraftRecipe |
| commands:engine.canInstallSprayCoater | B2 | 实现中；候选待源行为比较 | src/game/engine.ts:9441 | scripts/game/ProliferatorSystem.gd::eligible | rule:commands:engine.canInstallSprayCoater / manual:commands:engine.canInstallSprayCoater |
| commands:engine.canPlaceBlueprint | B2 | 未实现；待逐项核实/映射 | src/game/engine.ts:7992 | 尚未确认 | rule:commands:engine.canPlaceBlueprint / manual:commands:engine.canPlaceBlueprint |
| commands:engine.canQueueBlueprint | B2 | 实现中；候选待源行为比较 | src/game/engine.ts:8338 | scripts/game/ConstructionQueueSystem.gd::_preview | rule:commands:engine.canQueueBlueprint / manual:commands:engine.canQueueBlueprint |
| commands:engine.canQueueHandcraftRecipe | B2 | 实现中；候选待源行为比较 | src/game/engine.ts:12822 | scripts/game/CraftingPlanner.gd::plan | rule:commands:engine.canQueueHandcraftRecipe / manual:commands:engine.canQueueHandcraftRecipe |
| commands:engine.canQueueTechnology | — | 已验证；当前行为证据已绑定 | src/game/engine.ts:12988 | scripts/game/TechnologySystem.gd::can_queue_source_technology | rule:commands:engine.canQueueTechnology / manual:commands:engine.canQueueTechnology |
| commands:engine.canSelectTechnology | — | 已验证；当前行为证据已绑定 | src/game/engine.ts:12981 | scripts/game/TechnologySystem.gd::can_select_source_technology | rule:commands:engine.canSelectTechnology / manual:commands:engine.canSelectTechnology |
| commands:engine.canSetBeltStackSize | B2 | 未实现；待逐项核实/映射 | src/game/engine.ts:12464 | 尚未确认 | rule:commands:engine.canSetBeltStackSize / manual:commands:engine.canSetBeltStackSize |
| commands:engine.canUpgradeBelt | B2 | 未实现；待逐项核实/映射 | src/game/engine.ts:12417 | 尚未确认 | rule:commands:engine.canUpgradeBelt / manual:commands:engine.canUpgradeBelt |
| commands:engine.canUpgradeEntities | B2 | 未实现；待逐项核实/映射 | src/game/engine.ts:12405 | 尚未确认 | rule:commands:engine.canUpgradeEntities / manual:commands:engine.canUpgradeEntities |
| commands:engine.canUpgradeEntity | B2 | 未实现；待逐项核实/映射 | src/game/engine.ts:12382 | 尚未确认 | rule:commands:engine.canUpgradeEntity / manual:commands:engine.canUpgradeEntity |
| commands:engine.canUpgradeSorter | B2 | 未实现；待逐项核实/映射 | src/game/engine.ts:12443 | 尚未确认 | rule:commands:engine.canUpgradeSorter / manual:commands:engine.canUpgradeSorter |
| commands:engine.clearDysonShells | B4 | 实现中；候选待源行为比较 | src/game/engine.ts:3277 | scripts/game/SourceDysonEngineering.gd::clear_shells | rule:commands:engine.clearDysonShells / manual:commands:engine.clearDysonShells |
| commands:engine.clearOrbitalCargoPort | B3 | 未实现；待逐项核实/映射 | src/game/engine.ts:9055 | 尚未确认 | rule:commands:engine.clearOrbitalCargoPort / manual:commands:engine.clearOrbitalCargoPort |
| commands:engine.colonizePlanet | — | 已验证；当前行为证据已绑定 | src/game/engine.ts:7454 | scripts/game/PlanetSystem.gd::try_colonize_planet | rule:commands:engine.colonizePlanet / manual:commands:engine.colonizePlanet |
| commands:engine.completeSimulationStep | B5 | 实现中；候选待源行为比较 | src/game/engine.ts:6333 | scripts/game/SimulationEngine.gd::update | rule:commands:engine.completeSimulationStep / manual:commands:engine.completeSimulationStep |
| commands:engine.connectBelt | B2 | 未实现；待逐项核实/映射 | src/game/engine.ts:11206 | 尚未确认 | rule:commands:engine.connectBelt / manual:commands:engine.connectBelt |
| commands:engine.connectBeltsAtomically | B2 | 实现中；候选待源行为比较 | src/game/engine.ts:11235 | scripts/game/GameState.gd::try_add_connections | rule:commands:engine.connectBeltsAtomically / manual:commands:engine.connectBeltsAtomically |
| commands:engine.connectBeltWithResult | B2 | 实现中；候选待源行为比较 | src/game/engine.ts:11142 | scripts/game/GameState.gd::try_add_connection | rule:commands:engine.connectBeltWithResult / manual:commands:engine.connectBeltWithResult |
| commands:engine.connectDysonNodes | B4 | 实现中；候选待源行为比较 | src/game/engine.ts:3213 | scripts/game/SourceDysonEngineering.gd::connect_nodes | rule:commands:engine.connectDysonNodes / manual:commands:engine.connectDysonNodes |
| commands:engine.craftConstruction | B2 | 实现中；候选待源行为比较 | src/game/engine.ts:9735 | scripts/game/ConstructionAutomationSystem.gd::queue | rule:commands:engine.craftConstruction / manual:commands:engine.craftConstruction |
| commands:engine.craftConstructionWithUpstream | B2 | 实现中；候选待源行为比较 | src/game/engine.ts:9951 | scripts/game/ConstructionAutomationSystem.gd::queue | rule:commands:engine.craftConstructionWithUpstream / manual:commands:engine.craftConstructionWithUpstream |
| commands:engine.createBlueprint | B2 | 实现中；候选待源行为比较 | src/game/engine.ts:7571 | scripts/game/BlueprintLibrary.gd::save_definition | rule:commands:engine.createBlueprint / manual:commands:engine.createBlueprint |
| commands:engine.createPersistentSimulationRuntime | B5 | 实现中；候选待源行为比较 | src/game/engine.ts:7137 | scripts/game/SimulationEngine.gd::_init | rule:commands:engine.createPersistentSimulationRuntime / manual:commands:engine.createPersistentSimulationRuntime |
| commands:engine.createSimulationAdvanceSession | B5 | 实现中；候选待源行为比较 | src/game/engine.ts:6983 | scripts/game/SimulationEngine.gd::_init | rule:commands:engine.createSimulationAdvanceSession / manual:commands:engine.createSimulationAdvanceSession |
| commands:engine.createSimulationLookupContext | B5 | 实现中；候选待源行为比较 | src/game/engine.ts:2034 | scripts/game/SimulationEngine.gd::_init | rule:commands:engine.createSimulationLookupContext / manual:commands:engine.createSimulationLookupContext |
| commands:engine.createSimulationPlanetPhaseLookup | B5 | 实现中；候选待源行为比较 | src/game/engine.ts:5256 | scripts/game/SimulationEngine.gd::_init | rule:commands:engine.createSimulationPlanetPhaseLookup / manual:commands:engine.createSimulationPlanetPhaseLookup |
| commands:engine.createStandardDysonLayer | B4 | 实现中；候选待源行为比较 | src/game/engine.ts:3083 | scripts/game/SourceDysonEngineering.gd::standard_layer | rule:commands:engine.createStandardDysonLayer / manual:commands:engine.createStandardDysonLayer |
| commands:engine.discardConstructionInventory | — | 已验证；当前行为证据已绑定 | src/game/engine.ts:8858 | scripts/game/ConstructionSystem.gd::discard_inventory | rule:commands:engine.discardConstructionInventory / manual:commands:engine.discardConstructionInventory |
| commands:engine.discardPlanetTrayItems | — | 已验证；当前行为证据已绑定 | src/game/engine.ts:8829 | scripts/game/PlanetTraySystem.gd::discard_batch | rule:commands:engine.discardPlanetTrayItems / manual:commands:engine.discardPlanetTrayItems |
| commands:engine.dispatchGalacticExport | B4 | 实现中；候选待源行为比较 | src/game/engine.ts:13279 | scripts/game/GalacticExportSystem.gd::dispatch | rule:commands:engine.dispatchGalacticExport / manual:commands:engine.dispatchGalacticExport |
| commands:engine.dropCargoToEntity | B1 | 未实现；待逐项核实/映射 | src/game/engine.ts:9679 | 尚未确认 | rule:commands:engine.dropCargoToEntity / manual:commands:engine.dropCargoToEntity |
| commands:engine.dropCargoToTray | B1 | 未实现；待逐项核实/映射 | src/game/engine.ts:9697 | 尚未确认 | rule:commands:engine.dropCargoToTray / manual:commands:engine.dropCargoToTray |
| commands:engine.ensureSimulationDynamicRouteLookup | B5 | 实现中；候选待源行为比较 | src/game/engine.ts:5250 | scripts/game/SimulationEngine.gd::_init | rule:commands:engine.ensureSimulationDynamicRouteLookup / manual:commands:engine.ensureSimulationDynamicRouteLookup |
| commands:engine.exploreStarSystem | — | 已验证；当前行为证据已绑定 | src/game/engine.ts:7347 | scripts/game/GalaxySystem.gd::try_explore_system | rule:commands:engine.exploreStarSystem / manual:commands:engine.exploreStarSystem |
| commands:engine.fillStationFleet | B3 | 实现中；候选待源行为比较 | src/game/engine.ts:12029 | scripts/game/StationSystem.gd::set_fleet_target | rule:commands:engine.fillStationFleet / manual:commands:engine.fillStationFleet |
| commands:engine.findInterstellarPeer | B3 | 未实现；待逐项核实/映射 | src/game/engine.ts:2445 | 尚未确认 | rule:commands:engine.findInterstellarPeer / manual:commands:engine.findInterstellarPeer |
| commands:engine.findPlanetaryPeer | B2 | 实现中；候选待源行为比较 | src/game/engine.ts:2457 | scripts/game/LogisticsSystem.gd::_dispatch | rule:commands:engine.findPlanetaryPeer / manual:commands:engine.findPlanetaryPeer |
| commands:engine.findStationSlotPeer | B3 | 实现中；候选待源行为比较 | src/game/engine.ts:2434 | scripts/game/LogisticsSystem.gd::_dispatch | rule:commands:engine.findStationSlotPeer / manual:commands:engine.findStationSlotPeer |
| commands:engine.findStationSlotPeers | B3 | 实现中；候选待源行为比较 | src/game/engine.ts:2362 | scripts/game/LogisticsSystem.gd::_dispatch | rule:commands:engine.findStationSlotPeers / manual:commands:engine.findStationSlotPeers |
| commands:engine.fundAllConstructionQueueEntries | B2 | 实现中；候选待源行为比较 | src/game/engine.ts:8622 | scripts/game/ConstructionQueueSystem.gd::fund_all | rule:commands:engine.fundAllConstructionQueueEntries / manual:commands:engine.fundAllConstructionQueueEntries |
| commands:engine.fundConstructionQueueEntry | B2 | 实现中；候选待源行为比较 | src/game/engine.ts:8578 | scripts/game/ConstructionQueueSystem.gd::fund | rule:commands:engine.fundConstructionQueueEntry / manual:commands:engine.fundConstructionQueueEntry |
| commands:engine.getBeltConnectionCheck | B2 | 实现中；候选待源行为比较 | src/game/engine.ts:11072 | scripts/game/GameState.gd::preview_connections | rule:commands:engine.getBeltConnectionCheck / manual:commands:engine.getBeltConnectionCheck |
| commands:engine.getBeltLaneAdjustmentCheck | B2 | 实现中；候选待源行为比较 | src/game/engine.ts:11295 | scripts/game/GameState.gd::try_adjust_belt_lanes | rule:commands:engine.getBeltLaneAdjustmentCheck / manual:commands:engine.getBeltLaneAdjustmentCheck |
| commands:engine.getBeltNetworkIds | B2 | 未实现；待逐项核实/映射 | src/game/engine.ts:12506 | 尚未确认 | rule:commands:engine.getBeltNetworkIds / manual:commands:engine.getBeltNetworkIds |
| commands:engine.getBlueprintEligibleEntityIds | B2 | 未实现；待逐项核实/映射 | src/game/engine.ts:7563 | 尚未确认 | rule:commands:engine.getBlueprintEligibleEntityIds / manual:commands:engine.getBlueprintEligibleEntityIds |
| commands:engine.getBlueprintFleetLoadPreview | B2 | 未实现；待逐项核实/映射 | src/game/engine.ts:7975 | 尚未确认 | rule:commands:engine.getBlueprintFleetLoadPreview / manual:commands:engine.getBlueprintFleetLoadPreview |
| commands:engine.getBlueprintPlacementPreview | B2 | 未实现；待逐项核实/映射 | src/game/engine.ts:7936 | 尚未确认 | rule:commands:engine.getBlueprintPlacementPreview / manual:commands:engine.getBlueprintPlacementPreview |
| commands:engine.getColonizationRequirements | — | 已验证；当前行为证据已绑定 | src/game/engine.ts:7411 | scripts/game/PlanetSystem.gd::get_source_colonization_requirements | rule:commands:engine.getColonizationRequirements / manual:commands:engine.getColonizationRequirements |
| commands:engine.getConstructionAutomationCycleSeconds | B2 | 未实现；待逐项核实/映射 | src/game/engine.ts:9970 | 尚未确认 | rule:commands:engine.getConstructionAutomationCycleSeconds / manual:commands:engine.getConstructionAutomationCycleSeconds |
| commands:engine.getConstructionAutomationMaterialSeconds | B2 | 未实现；待逐项核实/映射 | src/game/engine.ts:10248 | 尚未确认 | rule:commands:engine.getConstructionAutomationMaterialSeconds / manual:commands:engine.getConstructionAutomationMaterialSeconds |
| commands:engine.getConstructionAutomationStatus | B2 | 未实现；待逐项核实/映射 | src/game/engine.ts:10346 | 尚未确认 | rule:commands:engine.getConstructionAutomationStatus / manual:commands:engine.getConstructionAutomationStatus |
| commands:engine.getConstructionAutomationStockLimit | B2 | 未实现；待逐项核实/映射 | src/game/engine.ts:9964 | 尚未确认 | rule:commands:engine.getConstructionAutomationStockLimit / manual:commands:engine.getConstructionAutomationStockLimit |
| commands:engine.getConstructionCenterTraceSample | B2 | 未实现；待逐项核实/映射 | src/game/engine.ts:10444 | 尚未确认 | rule:commands:engine.getConstructionCenterTraceSample / manual:commands:engine.getConstructionCenterTraceSample |
| commands:engine.getConstructionCraftDeficits | B2 | 实现中；候选待源行为比较 | src/game/engine.ts:12622 | scripts/game/CraftingPlanner.gd::plan | rule:commands:engine.getConstructionCraftDeficits / manual:commands:engine.getConstructionCraftDeficits |
| commands:engine.getConstructionCraftNavigation | B2 | 未实现；待逐项核实/映射 | src/game/engine.ts:9911 | 尚未确认 | rule:commands:engine.getConstructionCraftNavigation / manual:commands:engine.getConstructionCraftNavigation |
| commands:engine.getConstructionQueueDeficits | B2 | 未实现；待逐项核实/映射 | src/game/engine.ts:8482 | 尚未确认 | rule:commands:engine.getConstructionQueueDeficits / manual:commands:engine.getConstructionQueueDeficits |
| commands:engine.getConstructionQueueDetails | B2 | 未实现；待逐项核实/映射 | src/game/engine.ts:8446 | 尚未确认 | rule:commands:engine.getConstructionQueueDetails / manual:commands:engine.getConstructionQueueDetails |
| commands:engine.getConstructionQuickCraftPlan | B2 | 实现中；候选待源行为比较 | src/game/engine.ts:9882 | scripts/game/CraftingPlanner.gd::plan | rule:commands:engine.getConstructionQuickCraftPlan / manual:commands:engine.getConstructionQuickCraftPlan |
| commands:engine.getDysonEngineeringSnapshot | B4 | 实现中；候选待源行为比较 | src/game/engine.ts:2961 | scripts/game/DysonSphereSystem.gd::get_summary | rule:commands:engine.getDysonEngineeringSnapshot / manual:commands:engine.getDysonEngineeringSnapshot |
| commands:engine.getDysonSailAbsorptionMultiplier | — | 已验证；当前行为证据已绑定 | src/game/engine.ts:1200 | scripts/game/SourceTechnologyEffects.gd::multiplier | rule:commands:engine.getDysonSailAbsorptionMultiplier / manual:commands:engine.getDysonSailAbsorptionMultiplier |
| commands:engine.getDysonShellCapacity | B4 | 实现中；候选待源行为比较 | src/game/engine.ts:2826 | scripts/game/DysonSphereSystem.gd::get_summary | rule:commands:engine.getDysonShellCapacity / manual:commands:engine.getDysonShellCapacity |
| commands:engine.getEffectiveSimulationMultiplier | B5 | 实现中；候选待源行为比较 | src/game/engine.ts:7215 | scripts/game/TimeWarpSystem.gd::effective_multiplier | rule:commands:engine.getEffectiveSimulationMultiplier / manual:commands:engine.getEffectiveSimulationMultiplier |
| commands:engine.getEjectorOrbitTargetStatus | B4 | 未实现；待逐项核实/映射 | src/game/engine.ts:2658 | 尚未确认 | rule:commands:engine.getEjectorOrbitTargetStatus / manual:commands:engine.getEjectorOrbitTargetStatus |
| commands:engine.getEntityBufferLimit | — | 已验证；当前行为证据已绑定 | src/game/engine.ts:1564 | scripts/game/GameState.gd::get_entity_buffer_limit | rule:commands:engine.getEntityBufferLimit / manual:commands:engine.getEntityBufferLimit |
| commands:engine.getEntityCycleRatePerSimulationSecond | B5 | 实现中；候选待源行为比较 | src/game/engine.ts:10337 | scripts/game/ProductionSystem.gd::_update_building | rule:commands:engine.getEntityCycleRatePerSimulationSecond / manual:commands:engine.getEntityCycleRatePerSimulationSecond |
| commands:engine.getEntityInputCapacity | — | 已验证；当前行为证据已绑定 | src/game/engine.ts:1597 | scripts/game/GameState.gd::get_entity_input_capacity | rule:commands:engine.getEntityInputCapacity / manual:commands:engine.getEntityInputCapacity |
| commands:engine.getEntityItemInputCapacity | — | 已验证；当前行为证据已绑定 | src/game/engine.ts:1613 | scripts/game/GameState.gd::get_entity_item_input_capacity, scripts/game/SourceEntityCapacitySystem.gd::item_input_capacity | rule:commands:engine.getEntityItemInputCapacity / manual:commands:engine.getEntityItemInputCapacity |
| commands:engine.getEntityOperatingStatus | B2 | 未实现；待逐项核实/映射 | src/game/engine.ts:13407 | 尚未确认 | rule:commands:engine.getEntityOperatingStatus / manual:commands:engine.getEntityOperatingStatus |
| commands:engine.getEntityOutputCapacity | — | 已验证；当前行为证据已绑定 | src/game/engine.ts:1602 | scripts/game/GameState.gd::get_entity_output_capacity | rule:commands:engine.getEntityOutputCapacity / manual:commands:engine.getEntityOutputCapacity |
| commands:engine.getEntityPowerFactor | B2 | 实现中；候选待源行为比较 | src/game/engine.ts:1409 | scripts/game/GameState.gd::get_entity_power_factor | rule:commands:engine.getEntityPowerFactor / manual:commands:engine.getEntityPowerFactor |
| commands:engine.getEntityRecipeCycleCapacityPerSimulationSecond | B5 | 实现中；候选待源行为比较 | src/game/engine.ts:10305 | scripts/game/ProductionSystem.gd::_update_building | rule:commands:engine.getEntityRecipeCycleCapacityPerSimulationSecond / manual:commands:engine.getEntityRecipeCycleCapacityPerSimulationSecond |
| commands:engine.getEntityRemovalPreview | B2 | 未实现；待逐项核实/映射 | src/game/engine.ts:12280 | 尚未确认 | rule:commands:engine.getEntityRemovalPreview / manual:commands:engine.getEntityRemovalPreview |
| commands:engine.getEntityStackTargetCheck | B2 | 未实现；待逐项核实/映射 | src/game/engine.ts:12322 | 尚未确认 | rule:commands:engine.getEntityStackTargetCheck / manual:commands:engine.getEntityStackTargetCheck |
| commands:engine.getGalacticIndustrySnapshot | B4 | 实现中；候选待源行为比较 | src/game/engine.ts:13326 | scripts/game/GalacticExportSystem.gd::industry_snapshot | rule:commands:engine.getGalacticIndustrySnapshot / manual:commands:engine.getGalacticIndustrySnapshot |
| commands:engine.getIndustrialEfficiencyMultiplier | — | 已验证；当前行为证据已绑定 | src/game/engine.ts:1205 | scripts/game/SourceTechnologyEffects.gd::multiplier | rule:commands:engine.getIndustrialEfficiencyMultiplier / manual:commands:engine.getIndustrialEfficiencyMultiplier |
| commands:engine.getInfiniteResourceCollectionSpeedMultiplier | — | 已验证；当前行为证据已绑定 | src/game/engine.ts:878 | scripts/game/SourceTechnologyEffects.gd::multiplier | rule:commands:engine.getInfiniteResourceCollectionSpeedMultiplier / manual:commands:engine.getInfiniteResourceCollectionSpeedMultiplier |
| commands:engine.getInterstellarCargoCapacity | — | 已验证；当前行为证据已绑定 | src/game/engine.ts:932 | scripts/game/StationSystem.gd::logistics_snapshot | rule:commands:engine.getInterstellarCargoCapacity / manual:commands:engine.getInterstellarCargoCapacity |
| commands:engine.getInterstellarRouteEconomics | — | 已验证；当前行为证据已绑定 | src/game/engine.ts:1102 | scripts/game/InterstellarRouteSystem.gd::query_economics | rule:commands:engine.getInterstellarRouteEconomics / manual:commands:engine.getInterstellarRouteEconomics |
| commands:engine.getInterstellarTripSeconds | — | 已验证；当前行为证据已绑定 | src/game/engine.ts:943 | scripts/game/InterstellarRouteSystem.gd::trip_seconds | rule:commands:engine.getInterstellarTripSeconds / manual:commands:engine.getInterstellarTripSeconds |
| commands:engine.getLogisticsSpeedMultiplier | — | 已验证；当前行为证据已绑定 | src/game/engine.ts:918 | scripts/game/SourceTechnologyEffects.gd::multiplier, scripts/game/GameModeSystem.gd::multiplier | rule:commands:engine.getLogisticsSpeedMultiplier / manual:commands:engine.getLogisticsSpeedMultiplier |
| commands:engine.getMaterialDeliverySlotChangeCheck | B2 | 未实现；待逐项核实/映射 | src/game/engine.ts:8951 | 尚未确认 | rule:commands:engine.getMaterialDeliverySlotChangeCheck / manual:commands:engine.getMaterialDeliverySlotChangeCheck |
| commands:engine.getMaxConstructionQuickCraftBatches | B2 | 未实现；待逐项核实/映射 | src/game/engine.ts:9887 | 尚未确认 | rule:commands:engine.getMaxConstructionQuickCraftBatches / manual:commands:engine.getMaxConstructionQuickCraftBatches |
| commands:engine.getMaxHandcraftBatches | B2 | 未实现；待逐项核实/映射 | src/game/engine.ts:12828 | 尚未确认 | rule:commands:engine.getMaxHandcraftBatches / manual:commands:engine.getMaxHandcraftBatches |
| commands:engine.getMaxRecursiveHandcraftBatches | B2 | 未实现；待逐项核实/映射 | src/game/engine.ts:12778 | 尚未确认 | rule:commands:engine.getMaxRecursiveHandcraftBatches / manual:commands:engine.getMaxRecursiveHandcraftBatches |
| commands:engine.getMiningSpeedMultiplier | — | 已验证；当前行为证据已绑定 | src/game/engine.ts:868 | scripts/game/SourceTechnologyEffects.gd::multiplier, scripts/game/GameModeSystem.gd::multiplier | rule:commands:engine.getMiningSpeedMultiplier / manual:commands:engine.getMiningSpeedMultiplier |
| commands:engine.getOrbitalCargoPortClearCheck | B3 | 未实现；待逐项核实/映射 | src/game/engine.ts:9027 | 尚未确认 | rule:commands:engine.getOrbitalCargoPortClearCheck / manual:commands:engine.getOrbitalCargoPortClearCheck |
| commands:engine.getOrbitalCollectorQuantumStatus | B3 | 实现中；候选待源行为比较 | src/game/engine.ts:11783 | scripts/game/QuantumLogisticsSystem.gd::snapshot | rule:commands:engine.getOrbitalCollectorQuantumStatus / manual:commands:engine.getOrbitalCollectorQuantumStatus |
| commands:engine.getPlanetaryCargoCapacity | — | 已验证；当前行为证据已绑定 | src/game/engine.ts:925 | scripts/game/StationSystem.gd::logistics_snapshot | rule:commands:engine.getPlanetaryCargoCapacity / manual:commands:engine.getPlanetaryCargoCapacity |
| commands:engine.getPlanetaryTripSeconds | — | 已验证；当前行为证据已绑定 | src/game/engine.ts:939 | scripts/game/StationSystem.gd::logistics_snapshot | rule:commands:engine.getPlanetaryTripSeconds / manual:commands:engine.getPlanetaryTripSeconds |
| commands:engine.getPlanetMetrics | B2 | 实现中；候选待源行为比较 | src/game/engine.ts:1401 | scripts/game/PlanetSystem.gd::get_planet_industrial_summary | rule:commands:engine.getPlanetMetrics / manual:commands:engine.getPlanetMetrics |
| commands:engine.getPlanetTrayItemFreeCapacity | — | 已验证；当前行为证据已绑定 | src/game/engine.ts:8808 | scripts/game/PlanetTraySystem.gd::free_capacity | rule:commands:engine.getPlanetTrayItemFreeCapacity / manual:commands:engine.getPlanetTrayItemFreeCapacity |
| commands:engine.getPlanetTrayItemLimit | — | 已验证；当前行为证据已绑定 | src/game/engine.ts:8801 | scripts/game/PlanetTraySystem.gd::limit | rule:commands:engine.getPlanetTrayItemLimit / manual:commands:engine.getPlanetTrayItemLimit |
| commands:engine.getPowerGridMetrics | B2 | 实现中；候选待源行为比较 | src/game/engine.ts:1405 | scripts/game/PowerSystem.gd::get_grid_info | rule:commands:engine.getPowerGridMetrics / manual:commands:engine.getPowerGridMetrics |
| commands:engine.getQuantumAttachmentStatus | B3 | 实现中；候选待源行为比较 | src/game/engine.ts:11762 | scripts/game/QuantumLogisticsSystem.gd::snapshot | rule:commands:engine.getQuantumAttachmentStatus / manual:commands:engine.getQuantumAttachmentStatus |
| commands:engine.getRayReceiverCapacityKw | — | 已验证；当前行为证据已绑定 | src/game/engine.ts:1193 | scripts/game/DysonSphereSystem.gd::receiver_capacity | rule:commands:engine.getRayReceiverCapacityKw / manual:commands:engine.getRayReceiverCapacityKw |
| commands:engine.getRecipeCompatibleEntityIds | B2 | 未实现；待逐项核实/映射 | src/game/engine.ts:9401 | 尚未确认 | rule:commands:engine.getRecipeCompatibleEntityIds / manual:commands:engine.getRecipeCompatibleEntityIds |
| commands:engine.getRecipeSpeedMultiplier | — | 已验证；当前行为证据已绑定 | src/game/engine.ts:859 | scripts/game/SourceTechnologyEffects.gd::multiplier, scripts/game/GameModeSystem.gd::multiplier | rule:commands:engine.getRecipeSpeedMultiplier / manual:commands:engine.getRecipeSpeedMultiplier |
| commands:engine.getRecursiveHandcraftPlan | B2 | 实现中；候选待源行为比较 | src/game/engine.ts:12773 | scripts/game/CraftingPlanner.gd::plan | rule:commands:engine.getRecursiveHandcraftPlan / manual:commands:engine.getRecursiveHandcraftPlan |
| commands:engine.getResourceReserveSnapshot | B5 | 实现中；候选待源行为比较 | src/game/engine.ts:13388 | scripts/game/PlanetSystem.gd::get_planet_resource_sites | rule:commands:engine.getResourceReserveSnapshot / manual:commands:engine.getResourceReserveSnapshot |
| commands:engine.getSolarSailLifetimeSeconds | — | 已验证；当前行为证据已绑定 | src/game/engine.ts:1187 | scripts/game/SourceDysonEngineering.gd::sail_lifetime_seconds | rule:commands:engine.getSolarSailLifetimeSeconds / manual:commands:engine.getSolarSailLifetimeSeconds |
| commands:engine.getSprayCoaterInstallCheck | B2 | 未实现；待逐项核实/映射 | src/game/engine.ts:9424 | 尚未确认 | rule:commands:engine.getSprayCoaterInstallCheck / manual:commands:engine.getSprayCoaterInstallCheck |
| commands:engine.getSprayCoaterRemovalRefund | B2 | 实现中；候选待源行为比较 | src/game/engine.ts:9471 | scripts/game/ProliferatorSystem.gd::_refund | rule:commands:engine.getSprayCoaterRemovalRefund / manual:commands:engine.getSprayCoaterRemovalRefund |
| commands:engine.getStationActiveRoutes | B3 | 实现中；候选待源行为比较 | src/game/engine.ts:5289 | scripts/game/StationSystem.gd::logistics_snapshot | rule:commands:engine.getStationActiveRoutes / manual:commands:engine.getStationActiveRoutes |
| commands:engine.getStationBusyVehicleCount | B3 | 实现中；候选待源行为比较 | src/game/engine.ts:5294 | scripts/game/StationSystem.gd::logistics_snapshot | rule:commands:engine.getStationBusyVehicleCount / manual:commands:engine.getStationBusyVehicleCount |
| commands:engine.getStationFleetDiagnostic | B3 | 实现中；候选待源行为比较 | src/game/engine.ts:5422 | scripts/game/StationSystem.gd::logistics_snapshot | rule:commands:engine.getStationFleetDiagnostic / manual:commands:engine.getStationFleetDiagnostic |
| commands:engine.getStationMinimumCargo | B3 | 实现中；候选待源行为比较 | src/game/engine.ts:2494 | scripts/game/StationSystem.gd::logistics_snapshot | rule:commands:engine.getStationMinimumCargo / manual:commands:engine.getStationMinimumCargo |
| commands:engine.getStationSlotCapacity | — | 已验证；当前行为证据已绑定 | src/game/engine.ts:1607 | scripts/game/StationSystem.gd::capacity_for, scripts/game/SourceEntityCapacitySystem.gd::station_slot_capacity | rule:commands:engine.getStationSlotCapacity / manual:commands:engine.getStationSlotCapacity |
| commands:engine.getStationTemplateCompatibleEntityIds | B3 | 实现中；候选待源行为比较 | src/game/engine.ts:11699 | scripts/game/StationSystem.gd::logistics_snapshot | rule:commands:engine.getStationTemplateCompatibleEntityIds / manual:commands:engine.getStationTemplateCompatibleEntityIds |
| commands:engine.getStationWarperRefillSnapshot | B3 | 实现中；候选待源行为比较 | src/game/engine.ts:5839 | scripts/game/StationSystem.gd::logistics_snapshot | rule:commands:engine.getStationWarperRefillSnapshot / manual:commands:engine.getStationWarperRefillSnapshot |
| commands:engine.getVeinConsumptionMultiplier | — | 已验证；当前行为证据已绑定 | src/game/engine.ts:882 | scripts/game/SourceTechnologyEffects.gd::multiplier | rule:commands:engine.getVeinConsumptionMultiplier / manual:commands:engine.getVeinConsumptionMultiplier |
| commands:engine.handcraftRecipe | B2 | 实现中；候选待源行为比较 | src/game/engine.ts:12806 | scripts/game/ConstructionAutomationSystem.gd::queue | rule:commands:engine.handcraftRecipe / manual:commands:engine.handcraftRecipe |
| commands:engine.handcraftRecipeWithUpstream | B2 | 实现中；候选待源行为比较 | src/game/engine.ts:12795 | scripts/game/ConstructionAutomationSystem.gd::queue | rule:commands:engine.handcraftRecipeWithUpstream / manual:commands:engine.handcraftRecipeWithUpstream |
| commands:engine.hasActiveResearch | — | 已验证；当前行为证据已绑定 | src/game/engine.ts:855 | scripts/game/TechnologySystem.gd::has_active_source_research | rule:commands:engine.hasActiveResearch / manual:commands:engine.hasActiveResearch |
| commands:engine.hasBlueprintExactOverlap | B2 | 未实现；待逐项核实/映射 | src/game/engine.ts:8303 | 尚未确认 | rule:commands:engine.hasBlueprintExactOverlap / manual:commands:engine.hasBlueprintExactOverlap |
| commands:engine.hasExactEntityPositionOverlap | B2 | 未实现；待逐项核实/映射 | src/game/engine.ts:8321 | 尚未确认 | rule:commands:engine.hasExactEntityPositionOverlap / manual:commands:engine.hasExactEntityPositionOverlap |
| commands:engine.installMiner | B1 | 未实现；待逐项核实/映射 | src/game/engine.ts:8777 | 尚未确认 | rule:commands:engine.installMiner / manual:commands:engine.installMiner |
| commands:engine.installSprayCoater | B2 | 实现中；候选待源行为比较 | src/game/engine.ts:9445 | scripts/game/ProliferatorSystem.gd::configure | rule:commands:engine.installSprayCoater / manual:commands:engine.installSprayCoater |
| commands:engine.installSprayCoaters | B2 | 实现中；候选待源行为比较 | src/game/engine.ts:9458 | scripts/game/ProliferatorSystem.gd::configure_batch | rule:commands:engine.installSprayCoaters / manual:commands:engine.installSprayCoaters |
| commands:engine.investInfiniteResearchBudgetInPlace | — | 已验证；当前行为证据已绑定 | src/game/engine.ts:4891 | scripts/game/InfiniteResearchSystem.gd::invest_budget | rule:commands:engine.investInfiniteResearchBudgetInPlace / manual:commands:engine.investInfiniteResearchBudgetInPlace |
| commands:engine.isEntityInPowerCoverage | B2 | 未实现；待逐项核实/映射 | src/game/engine.ts:3702 | 尚未确认 | rule:commands:engine.isEntityInPowerCoverage / manual:commands:engine.isEntityInPowerCoverage |
| commands:engine.isEntityInteractionLocked | B2 | 实现中；候选待源行为比较 | src/game/engine.ts:7233 | scripts/game/GameState.gd::is_entity_interaction_locked | rule:commands:engine.isEntityInteractionLocked / manual:commands:engine.isEntityInteractionLocked |
| commands:engine.isPlanetColonized | — | 已验证；当前行为证据已绑定 | src/game/engine.ts:7387 | scripts/game/PlanetSystem.gd::is_source_planet_colonized | rule:commands:engine.isPlanetColonized / manual:commands:engine.isPlanetColonized |
| commands:engine.isStarSystemUnlocked | — | 已验证；当前行为证据已绑定 | src/game/engine.ts:7335 | scripts/game/GalaxySystem.gd::is_source_system_unlocked | rule:commands:engine.isStarSystemUnlocked / manual:commands:engine.isStarSystemUnlocked |
| commands:engine.isTechnologyCompleted | — | 已验证；当前行为证据已绑定 | src/game/engine.ts:12901 | scripts/game/TechnologySystem.gd::is_technology_completed | rule:commands:engine.isTechnologyCompleted / manual:commands:engine.isTechnologyCompleted |
| commands:engine.manualMine | B1 | 未实现；待逐项核实/映射 | src/game/engine.ts:7526 | 尚未确认 | rule:commands:engine.manualMine / manual:commands:engine.manualMine |
| commands:engine.mergeSimulationPlanetPhaseResults | B5 | 实现中；候选待源行为比较 | src/game/engine.ts:6461 | scripts/game/GameState.gd::install_state | rule:commands:engine.mergeSimulationPlanetPhaseResults / manual:commands:engine.mergeSimulationPlanetPhaseResults |
| commands:engine.moveEntities | B2 | 实现中；候选待源行为比较 | src/game/engine.ts:7551 | scripts/game/GameState.gd::move_entities | rule:commands:engine.moveEntities / manual:commands:engine.moveEntities |
| commands:engine.moveEntity | B2 | 实现中；候选待源行为比较 | src/game/engine.ts:7543 | scripts/game/GameState.gd::move_entity | rule:commands:engine.moveEntity / manual:commands:engine.moveEntity |
| commands:engine.moveEntityInputToEntity | B1 | 未实现；待逐项核实/映射 | src/game/engine.ts:9640 | 尚未确认 | rule:commands:engine.moveEntityInputToEntity / manual:commands:engine.moveEntityInputToEntity |
| commands:engine.moveEntityInputToTray | B1 | 未实现；待逐项核实/映射 | src/game/engine.ts:9604 | 尚未确认 | rule:commands:engine.moveEntityInputToTray / manual:commands:engine.moveEntityInputToTray |
| commands:engine.moveEntityOutputToEntity | B1 | 未实现；待逐项核实/映射 | src/game/engine.ts:9617 | 尚未确认 | rule:commands:engine.moveEntityOutputToEntity / manual:commands:engine.moveEntityOutputToEntity |
| commands:engine.moveEntityOutputToTray | B1 | 未实现；待逐项核实/映射 | src/game/engine.ts:9590 | 尚未确认 | rule:commands:engine.moveEntityOutputToTray / manual:commands:engine.moveEntityOutputToTray |
| commands:engine.moveTrayItemToEntity | B1 | 未实现；待逐项核实/映射 | src/game/engine.ts:9663 | 尚未确认 | rule:commands:engine.moveTrayItemToEntity / manual:commands:engine.moveTrayItemToEntity |
| commands:engine.pasteDysonLayerTemplate | B4 | 实现中；候选待源行为比较 | src/game/engine.ts:3325 | scripts/game/SourceDysonEngineering.gd::paste_template | rule:commands:engine.pasteDysonLayerTemplate / manual:commands:engine.pasteDysonLayerTemplate |
| commands:engine.pauseCurrentResearch | — | 已验证；当前行为证据已绑定 | src/game/engine.ts:13034 | scripts/game/TechnologySystem.gd::pause_research | rule:commands:engine.pauseCurrentResearch / manual:commands:engine.pauseCurrentResearch |
| commands:engine.pickFromEntity | B1 | 未实现；待逐项核实/映射 | src/game/engine.ts:9554 | 尚未确认 | rule:commands:engine.pickFromEntity / manual:commands:engine.pickFromEntity |
| commands:engine.pickFromEntityInput | B1 | 未实现；待逐项核实/映射 | src/game/engine.ts:9573 | 尚未确认 | rule:commands:engine.pickFromEntityInput / manual:commands:engine.pickFromEntityInput |
| commands:engine.pickFromTray | B1 | 未实现；待逐项核实/映射 | src/game/engine.ts:9710 | 尚未确认 | rule:commands:engine.pickFromTray / manual:commands:engine.pickFromTray |
| commands:engine.placeBlueprint | B2 | 实现中；候选待源行为比较 | src/game/engine.ts:8019 | scripts/game/ConstructionQueueSystem.gd::deploy_immediately | rule:commands:engine.placeBlueprint / manual:commands:engine.placeBlueprint |
| commands:engine.placeBuilding | B2 | 未实现；待逐项核实/映射 | src/game/engine.ts:8663 | 尚未确认 | rule:commands:engine.placeBuilding / manual:commands:engine.placeBuilding |
| commands:engine.planDysonShell | B4 | 实现中；候选待源行为比较 | src/game/engine.ts:3245 | scripts/game/SourceDysonEngineering.gd::plan_shell | rule:commands:engine.planDysonShell / manual:commands:engine.planDysonShell |
| commands:engine.prepareSimulationStep | B5 | 实现中；候选待源行为比较 | src/game/engine.ts:6279 | scripts/game/SimulationEngine.gd::_run_fixed_tick | rule:commands:engine.prepareSimulationStep / manual:commands:engine.prepareSimulationStep |
| commands:engine.processConstructionQueue | B2 | 实现中；候选待源行为比较 | src/game/engine.ts:8648 | scripts/game/ConstructionQueueSystem.gd::fund_all | rule:commands:engine.processConstructionQueue / manual:commands:engine.processConstructionQueue |
| commands:engine.queueBlueprint | B2 | 实现中；候选待源行为比较 | src/game/engine.ts:8362 | scripts/game/ConstructionQueueSystem.gd::enqueue | rule:commands:engine.queueBlueprint / manual:commands:engine.queueBlueprint |
| commands:engine.queueHandcraftRecipe | B2 | 实现中；候选待源行为比较 | src/game/engine.ts:12844 | scripts/game/ConstructionAutomationSystem.gd::queue | rule:commands:engine.queueHandcraftRecipe / manual:commands:engine.queueHandcraftRecipe |
| commands:engine.refillStationWarpers | B3 | 实现中；候选待源行为比较 | src/game/engine.ts:5844 | scripts/game/LogisticsSystem.gd::_refill_warpers | rule:commands:engine.refillStationWarpers / manual:commands:engine.refillStationWarpers |
| commands:engine.refreshDysonGenerationSnapshot | B4 | 实现中；候选待源行为比较 | src/game/engine.ts:3451 | scripts/game/DysonSphereSystem.gd::receiver_outputs | rule:commands:engine.refreshDysonGenerationSnapshot / manual:commands:engine.refreshDysonGenerationSnapshot |
| commands:engine.refreshTimeWarpPowerSnapshot | B5 | 实现中；候选待源行为比较 | src/game/engine.ts:7305 | scripts/game/PowerSystem.gd::update | rule:commands:engine.refreshTimeWarpPowerSnapshot / manual:commands:engine.refreshTimeWarpPowerSnapshot |
| commands:engine.refreshTimeWarpPowerSnapshotInPlace | B5 | 实现中；候选待源行为比较 | src/game/engine.ts:7284 | scripts/game/PowerSystem.gd::update | rule:commands:engine.refreshTimeWarpPowerSnapshotInPlace / manual:commands:engine.refreshTimeWarpPowerSnapshotInPlace |
| commands:engine.removeBelt | B2 | 未实现；待逐项核实/映射 | src/game/engine.ts:11279 | 尚未确认 | rule:commands:engine.removeBelt / manual:commands:engine.removeBelt |
| commands:engine.removeBeltNetwork | B2 | 未实现；待逐项核实/映射 | src/game/engine.ts:12608 | 尚未确认 | rule:commands:engine.removeBeltNetwork / manual:commands:engine.removeBeltNetwork |
| commands:engine.removeBlueprint | B2 | 实现中；候选待源行为比较 | src/game/engine.ts:7715 | scripts/game/BlueprintLibrary.gd::remove | rule:commands:engine.removeBlueprint / manual:commands:engine.removeBlueprint |
| commands:engine.removeCanvasBookmark | B2 | 实现中；候选待源行为比较 | src/game/engine.ts:9302 | scripts/game/CanvasNavigation.gd::remove | rule:commands:engine.removeCanvasBookmark / manual:commands:engine.removeCanvasBookmark |
| commands:engine.removeCanvasRegion | B2 | 实现中；候选待源行为比较 | src/game/engine.ts:9369 | scripts/game/CanvasNavigation.gd::remove | rule:commands:engine.removeCanvasRegion / manual:commands:engine.removeCanvasRegion |
| commands:engine.removeDysonLayer | B4 | 实现中；候选待源行为比较 | src/game/engine.ts:3173 | scripts/game/DysonSphereSystem.gd::remove_plan | rule:commands:engine.removeDysonLayer / manual:commands:engine.removeDysonLayer |
| commands:engine.removeDysonNode | B4 | 实现中；候选待源行为比较 | src/game/engine.ts:3200 | scripts/game/SourceDysonEngineering.gd::remove_node | rule:commands:engine.removeDysonNode / manual:commands:engine.removeDysonNode |
| commands:engine.removeDysonSwarmOrbit | B4 | 实现中；候选待源行为比较 | src/game/engine.ts:2943 | scripts/game/DysonSphereSystem.gd::remove_plan | rule:commands:engine.removeDysonSwarmOrbit / manual:commands:engine.removeDysonSwarmOrbit |
| commands:engine.removeEntities | B2 | 实现中；候选待源行为比较 | src/game/engine.ts:12259 | scripts/game/GameState.gd::remove_entities | rule:commands:engine.removeEntities / manual:commands:engine.removeEntities |
| commands:engine.removeEntity | B2 | 未实现；待逐项核实/映射 | src/game/engine.ts:12183 | 尚未确认 | rule:commands:engine.removeEntity / manual:commands:engine.removeEntity |
| commands:engine.removeQueuedTechnology | — | 已验证；当前行为证据已绑定 | src/game/engine.ts:13078 | scripts/game/TechnologySystem.gd::remove_from_queue | rule:commands:engine.removeQueuedTechnology / manual:commands:engine.removeQueuedTechnology |
| commands:engine.removeSprayCoater | B2 | 实现中；候选待源行为比较 | src/game/engine.ts:9491 | scripts/game/ProliferatorSystem.gd::remove | rule:commands:engine.removeSprayCoater / manual:commands:engine.removeSprayCoater |
| commands:engine.renameBlueprint | B2 | 实现中；候选待源行为比较 | src/game/engine.ts:7689 | scripts/game/BlueprintLibrary.gd::rename | rule:commands:engine.renameBlueprint / manual:commands:engine.renameBlueprint |
| commands:engine.renameCanvasBookmark | B2 | 实现中；候选待源行为比较 | src/game/engine.ts:9296 | scripts/game/CanvasNavigation.gd::rename | rule:commands:engine.renameCanvasBookmark / manual:commands:engine.renameCanvasBookmark |
| commands:engine.resizeCanvasRegion | B2 | 实现中；候选待源行为比较 | src/game/engine.ts:9347 | scripts/game/CanvasNavigation.gd::save_region | rule:commands:engine.resizeCanvasRegion / manual:commands:engine.resizeCanvasRegion |
| commands:engine.resumePausedResearch | — | 已验证；当前行为证据已绑定 | src/game/engine.ts:13048 | scripts/game/TechnologySystem.gd::resume_research | rule:commands:engine.resumePausedResearch / manual:commands:engine.resumePausedResearch |
| commands:engine.runPlanetSimulationPhase | B5 | 实现中；候选待源行为比较 | src/game/engine.ts:6163 | scripts/game/SimulationEngine.gd::update | rule:commands:engine.runPlanetSimulationPhase / manual:commands:engine.runPlanetSimulationPhase |
| commands:engine.selectInfiniteResearch | — | 已验证；当前行为证据已绑定 | src/game/engine.ts:13101 | scripts/game/InfiniteResearchSystem.gd::select | rule:commands:engine.selectInfiniteResearch / manual:commands:engine.selectInfiniteResearch |
| commands:engine.selectTechnology | — | 已验证；当前行为证据已绑定 | src/game/engine.ts:13015 | scripts/game/TechnologySystem.gd::start_research | rule:commands:engine.selectTechnology / manual:commands:engine.selectTechnology |
| commands:engine.setActiveDysonLayer | B4 | 实现中；候选待源行为比较 | src/game/engine.ts:3142 | scenes/ui/DysonUI.gd | rule:commands:engine.setActiveDysonLayer / manual:commands:engine.setActiveDysonLayer |
| commands:engine.setActiveDysonSwarmOrbit | B4 | 实现中；候选待源行为比较 | src/game/engine.ts:2893 | scenes/ui/DysonUI.gd | rule:commands:engine.setActiveDysonSwarmOrbit / manual:commands:engine.setActiveDysonSwarmOrbit |
| commands:engine.setActivePlanet | — | 已验证；当前行为证据已绑定 | src/game/engine.ts:7470 | scripts/game/PlanetSystem.gd::try_set_active_planet | rule:commands:engine.setActivePlanet / manual:commands:engine.setActivePlanet |
| commands:engine.setAllOrbitalCollectorsQuantumMode | B3 | 实现中；候选待源行为比较 | src/game/engine.ts:11811 | scripts/game/QuantumLogisticsSystem.gd::set_all_collectors | rule:commands:engine.setAllOrbitalCollectorsQuantumMode / manual:commands:engine.setAllOrbitalCollectorsQuantumMode |
| commands:engine.setBeltLaneCount | B2 | 实现中；候选待源行为比较 | src/game/engine.ts:11323 | scripts/game/GameState.gd::set_belt_lane_count | rule:commands:engine.setBeltLaneCount / manual:commands:engine.setBeltLaneCount |
| commands:engine.setBeltMonitorEnabled | B2 | 实现中；候选待源行为比较 | src/game/engine.ts:12479 | scripts/game/GameState.gd::set_belt_monitor_enabled | rule:commands:engine.setBeltMonitorEnabled / manual:commands:engine.setBeltMonitorEnabled |
| commands:engine.setBeltNetworkRouteMode | B2 | 实现中；候选待源行为比较 | src/game/engine.ts:12534 | scripts/game/GameState.gd::set_belt_network_route_mode | rule:commands:engine.setBeltNetworkRouteMode / manual:commands:engine.setBeltNetworkRouteMode |
| commands:engine.setBeltPriority | B2 | 实现中；候选待源行为比较 | src/game/engine.ts:11491 | scripts/game/GameState.gd::set_belt_priority | rule:commands:engine.setBeltPriority / manual:commands:engine.setBeltPriority |
| commands:engine.setBeltRouteMode | B2 | 实现中；候选待源行为比较 | src/game/engine.ts:12489 | scripts/game/GameState.gd::set_belt_route_mode | rule:commands:engine.setBeltRouteMode / manual:commands:engine.setBeltRouteMode |
| commands:engine.setBeltRouteOffsetY | B2 | 实现中；候选待源行为比较 | src/game/engine.ts:12497 | scripts/game/GameState.gd::set_belt_route_offset_y | rule:commands:engine.setBeltRouteOffsetY / manual:commands:engine.setBeltRouteOffsetY |
| commands:engine.setBeltStackSize | B2 | 实现中；候选待源行为比较 | src/game/engine.ts:12470 | scripts/game/GameState.gd::set_belt_stack_size | rule:commands:engine.setBeltStackSize / manual:commands:engine.setBeltStackSize |
| commands:engine.setBlackHolePaused | B4 | 实现中；候选待源行为比较 | src/game/engine.ts:7250 | scripts/game/BlackHoleSystem.gd::set_paused | rule:commands:engine.setBlackHolePaused / manual:commands:engine.setBlackHolePaused |
| commands:engine.setBlueprintRecipeOverride | B2 | 实现中；候选待源行为比较 | src/game/engine.ts:7739 | scripts/game/BlueprintLibrary.gd::save_definition | rule:commands:engine.setBlueprintRecipeOverride / manual:commands:engine.setBlueprintRecipeOverride |
| commands:engine.setBlueprintTransform | B2 | 实现中；候选待源行为比较 | src/game/engine.ts:7723 | scripts/game/BlueprintLibrary.gd::save_definition | rule:commands:engine.setBlueprintTransform / manual:commands:engine.setBlueprintTransform |
| commands:engine.setConstructionAutomationEnabled | B2 | 未实现；待逐项核实/映射 | src/game/engine.ts:9976 | 尚未确认 | rule:commands:engine.setConstructionAutomationEnabled / manual:commands:engine.setConstructionAutomationEnabled |
| commands:engine.setConstructionAutomationTarget | B2 | 未实现；待逐项核实/映射 | src/game/engine.ts:10046 | 尚未确认 | rule:commands:engine.setConstructionAutomationTarget / manual:commands:engine.setConstructionAutomationTarget |
| commands:engine.setConstructionAutomationTargetsForBuildings | B2 | 未实现；待逐项核实/映射 | src/game/engine.ts:10082 | 尚未确认 | rule:commands:engine.setConstructionAutomationTargetsForBuildings / manual:commands:engine.setConstructionAutomationTargetsForBuildings |
| commands:engine.setDysonLaunchEnabled | B4 | 实现中；候选待源行为比较 | src/game/engine.ts:2873 | scripts/game/SourceDysonEngineering.gd::configure_schedule | rule:commands:engine.setDysonLaunchEnabled / manual:commands:engine.setDysonLaunchEnabled |
| commands:engine.setDysonLaunchMode | B4 | 实现中；候选待源行为比较 | src/game/engine.ts:2863 | scripts/game/SourceDysonEngineering.gd::configure_schedule | rule:commands:engine.setDysonLaunchMode / manual:commands:engine.setDysonLaunchMode |
| commands:engine.setDysonLaunchThrottle | B4 | 实现中；候选待源行为比较 | src/game/engine.ts:2868 | scripts/game/SourceDysonEngineering.gd::configure_schedule | rule:commands:engine.setDysonLaunchThrottle / manual:commands:engine.setDysonLaunchThrottle |
| commands:engine.setDysonLayerOrbit | B4 | 实现中；候选待源行为比较 | src/game/engine.ts:3153 | scripts/game/SourceDysonEngineering.gd::set_geometry | rule:commands:engine.setDysonLayerOrbit / manual:commands:engine.setDysonLayerOrbit |
| commands:engine.setDysonSwarmOrbit | B4 | 实现中；候选待源行为比较 | src/game/engine.ts:2927 | scripts/game/SourceDysonEngineering.gd::set_geometry | rule:commands:engine.setDysonSwarmOrbit / manual:commands:engine.setDysonSwarmOrbit |
| commands:engine.setEjectorTargetOrbit | B4 | 未实现；待逐项核实/映射 | src/game/engine.ts:2923 | 尚未确认 | rule:commands:engine.setEjectorTargetOrbit / manual:commands:engine.setEjectorTargetOrbit |
| commands:engine.setEjectorTargetOrbitForEntities | B4 | 未实现；待逐项核实/映射 | src/game/engine.ts:2904 | 尚未确认 | rule:commands:engine.setEjectorTargetOrbitForEntities / manual:commands:engine.setEjectorTargetOrbitForEntities |
| commands:engine.setEnergyMode | B2 | 实现中；候选待源行为比较 | src/game/engine.ts:12129 | scripts/game/GameState.gd::set_energy_mode | rule:commands:engine.setEnergyMode / manual:commands:engine.setEnergyMode |
| commands:engine.setEntitiesInteractionLocked | B2 | 实现中；候选待源行为比较 | src/game/engine.ts:7237 | scripts/game/GameState.gd::set_entities_interaction_locked | rule:commands:engine.setEntitiesInteractionLocked / manual:commands:engine.setEntitiesInteractionLocked |
| commands:engine.setEntitiesProliferatorConfiguration | B2 | 实现中；候选待源行为比较 | src/game/engine.ts:9544 | scripts/game/ProliferatorSystem.gd::configure_batch | rule:commands:engine.setEntitiesProliferatorConfiguration / manual:commands:engine.setEntitiesProliferatorConfiguration |
| commands:engine.setEntitiesRecipe | B2 | 实现中；候选待源行为比较 | src/game/engine.ts:9410 | scripts/game/GameState.gd::set_entities_recipe | rule:commands:engine.setEntitiesRecipe / manual:commands:engine.setEntitiesRecipe |
| commands:engine.setEntityGenerationPriority | B2 | 实现中；候选待源行为比较 | src/game/engine.ts:12166 | scripts/game/GameState.gd::set_entity_generation_priority | rule:commands:engine.setEntityGenerationPriority / manual:commands:engine.setEntityGenerationPriority |
| commands:engine.setEntityPowerGrid | B2 | 实现中；候选待源行为比较 | src/game/engine.ts:12150 | scripts/game/GameState.gd::set_entity_power_grid | rule:commands:engine.setEntityPowerGrid / manual:commands:engine.setEntityPowerGrid |
| commands:engine.setEntityPowerPriority | B2 | 实现中；候选待源行为比较 | src/game/engine.ts:12158 | scripts/game/GameState.gd::set_entity_power_priority | rule:commands:engine.setEntityPowerPriority / manual:commands:engine.setEntityPowerPriority |
| commands:engine.setEntityRecipe | B2 | 实现中；候选待源行为比较 | src/game/engine.ts:9231 | scripts/game/GameState.gd::set_entity_recipe | rule:commands:engine.setEntityRecipe / manual:commands:engine.setEntityRecipe |
| commands:engine.setEntityStackTarget | B2 | 未实现；待逐项核实/映射 | src/game/engine.ts:12370 | 尚未确认 | rule:commands:engine.setEntityStackTarget / manual:commands:engine.setEntityStackTarget |
| commands:engine.setFuelItem | B2 | 未实现；待逐项核实/映射 | src/game/engine.ts:12113 | 尚未确认 | rule:commands:engine.setFuelItem / manual:commands:engine.setFuelItem |
| commands:engine.setGalacticDispatchAutomation | B4 | 实现中；候选待源行为比较 | src/game/engine.ts:13118 | scripts/game/GalacticExportSystem.gd::set_automation | rule:commands:engine.setGalacticDispatchAutomation / manual:commands:engine.setGalacticDispatchAutomation |
| commands:engine.setGalacticDispatchThrottle | B4 | 实现中；候选待源行为比较 | src/game/engine.ts:13123 | scripts/game/GalacticExportSystem.gd::set_throttle | rule:commands:engine.setGalacticDispatchThrottle / manual:commands:engine.setGalacticDispatchThrottle |
| commands:engine.setGalacticExportEnabled | B4 | 实现中；候选待源行为比较 | src/game/engine.ts:13128 | scripts/game/GalacticExportSystem.gd::configure | rule:commands:engine.setGalacticExportEnabled / manual:commands:engine.setGalacticExportEnabled |
| commands:engine.setGalacticExportPriority | B4 | 实现中；候选待源行为比较 | src/game/engine.ts:13142 | scripts/game/GalacticExportSystem.gd::configure | rule:commands:engine.setGalacticExportPriority / manual:commands:engine.setGalacticExportPriority |
| commands:engine.setGalacticMaterialExporterPaused | — | 在线排除；固定在线白名单 | src/game/engine.ts:9981 | 尚未确认 | rule:commands:engine.setGalacticMaterialExporterPaused / manual:commands:engine.setGalacticMaterialExporterPaused |
| commands:engine.setInfiniteResearchAutomation | — | 已验证；当前行为证据已绑定 | src/game/engine.ts:13113 | scripts/game/InfiniteResearchSystem.gd::set_automation | rule:commands:engine.setInfiniteResearchAutomation / manual:commands:engine.setInfiniteResearchAutomation |
| commands:engine.setLogisticsItem | B3 | 未实现；待逐项核实/映射 | src/game/engine.ts:11499 | 尚未确认 | rule:commands:engine.setLogisticsItem / manual:commands:engine.setLogisticsItem |
| commands:engine.setMaterialDeliverySlot | B2 | 未实现；待逐项核实/映射 | src/game/engine.ts:8989 | 尚未确认 | rule:commands:engine.setMaterialDeliverySlot / manual:commands:engine.setMaterialDeliverySlot |
| commands:engine.setOrbitalCollectorQuantumMode | B3 | 实现中；候选待源行为比较 | src/game/engine.ts:11804 | scripts/game/QuantumLogisticsSystem.gd::set_collector_mode | rule:commands:engine.setOrbitalCollectorQuantumMode / manual:commands:engine.setOrbitalCollectorQuantumMode |
| commands:engine.setPaused | B5 | 未实现；待逐项核实/映射 | src/game/engine.ts:7220 | 尚未确认 | rule:commands:engine.setPaused / manual:commands:engine.setPaused |
| commands:engine.setPlanetDisplayMetadata | — | 已验证；当前行为证据已绑定 | src/game/engine.ts:7504 | scripts/game/SourceGalaxySystem.gd::set_metadata | rule:commands:engine.setPlanetDisplayMetadata / manual:commands:engine.setPlanetDisplayMetadata |
| commands:engine.setPlanetIndustryRole | — | 已验证；当前行为证据已绑定 | src/game/engine.ts:7492 | scripts/game/SourceGalaxySystem.gd::set_role | rule:commands:engine.setPlanetIndustryRole / manual:commands:engine.setPlanetIndustryRole |
| commands:engine.setPlanetTrayItemLimit | — | 已验证；当前行为证据已绑定 | src/game/engine.ts:8814 | scripts/game/PlanetTraySystem.gd::set_limit | rule:commands:engine.setPlanetTrayItemLimit / manual:commands:engine.setPlanetTrayItemLimit |
| commands:engine.setProliferatorConfiguration | B2 | 实现中；候选待源行为比较 | src/game/engine.ts:9514 | scripts/game/ProliferatorSystem.gd::configure | rule:commands:engine.setProliferatorConfiguration / manual:commands:engine.setProliferatorConfiguration |
| commands:engine.setQuantumLogisticsItemCapacity | B3 | 实现中；候选待源行为比较 | src/game/engine.ts:11850 | scripts/game/QuantumLogisticsSystem.gd::set_item_capacity | rule:commands:engine.setQuantumLogisticsItemCapacity / manual:commands:engine.setQuantumLogisticsItemCapacity |
| commands:engine.setRecipeFocus | B2 | 未实现；待逐项核实/映射 | src/game/engine.ts:9256 | 尚未确认 | rule:commands:engine.setRecipeFocus / manual:commands:engine.setRecipeFocus |
| commands:engine.setRecipeFocusMode | B2 | 未实现；待逐项核实/映射 | src/game/engine.ts:9262 | 尚未确认 | rule:commands:engine.setRecipeFocusMode / manual:commands:engine.setRecipeFocusMode |
| commands:engine.setRecipeFocusPosition | B2 | 未实现；待逐项核实/映射 | src/game/engine.ts:9267 | 尚未确认 | rule:commands:engine.setRecipeFocusPosition / manual:commands:engine.setRecipeFocusPosition |
| commands:engine.setRemoteBuildingStackTarget | B3 | 未实现；待逐项核实/映射 | src/game/engine.ts:12378 | 尚未确认 | rule:commands:engine.setRemoteBuildingStackTarget / manual:commands:engine.setRemoteBuildingStackTarget |
| commands:engine.setRemoteStationFleetTarget | B3 | 实现中；候选待源行为比较 | src/game/engine.ts:11965 | scripts/game/StationSystem.gd::set_fleet_target | rule:commands:engine.setRemoteStationFleetTarget / manual:commands:engine.setRemoteStationFleetTarget |
| commands:engine.setRemoteStationSlotItem | B3 | 实现中；候选待源行为比较 | src/game/engine.ts:11538 | scripts/game/StationSystem.gd::configure_slots | rule:commands:engine.setRemoteStationSlotItem / manual:commands:engine.setRemoteStationSlotItem |
| commands:engine.setSplitterMode | B2 | 未实现；待逐项核实/映射 | src/game/engine.ts:12175 | 尚未确认 | rule:commands:engine.setSplitterMode / manual:commands:engine.setSplitterMode |
| commands:engine.setStarSystemDisplayName | — | 已验证；当前行为证据已绑定 | src/game/engine.ts:7517 | scripts/game/SourceGalaxySystem.gd::set_metadata | rule:commands:engine.setStarSystemDisplayName / manual:commands:engine.setStarSystemDisplayName |
| commands:engine.setStationFleetTarget | B3 | 实现中；候选待源行为比较 | src/game/engine.ts:11951 | scripts/game/StationSystem.gd::set_fleet_target | rule:commands:engine.setStationFleetTarget / manual:commands:engine.setStationFleetTarget |
| commands:engine.setStationHubConfiguration | B3 | 实现中；候选待源行为比较 | src/game/engine.ts:11684 | scripts/game/StationSystem.gd::set_hub | rule:commands:engine.setStationHubConfiguration / manual:commands:engine.setStationHubConfiguration |
| commands:engine.setStationMinimumLoad | B3 | 实现中；候选待源行为比较 | src/game/engine.ts:12107 | scripts/game/StationSystem.gd::configure_slots | rule:commands:engine.setStationMinimumLoad / manual:commands:engine.setStationMinimumLoad |
| commands:engine.setStationMode | B3 | 实现中；候选待源行为比较 | src/game/engine.ts:11744 | scripts/game/StationSystem.gd::configure_slots | rule:commands:engine.setStationMode / manual:commands:engine.setStationMode |
| commands:engine.setStationSlotItem | B3 | 实现中；候选待源行为比较 | src/game/engine.ts:11526 | scripts/game/StationSystem.gd::configure_slots | rule:commands:engine.setStationSlotItem / manual:commands:engine.setStationSlotItem |
| commands:engine.setStationSlotLimits | B3 | 实现中；候选待源行为比较 | src/game/engine.ts:11620 | scripts/game/StationSystem.gd::set_slot_limits | rule:commands:engine.setStationSlotLimits / manual:commands:engine.setStationSlotLimits |
| commands:engine.setStationSlotMinimumLoad | B3 | 实现中；候选待源行为比较 | src/game/engine.ts:11605 | scripts/game/StationSystem.gd::configure_slots | rule:commands:engine.setStationSlotMinimumLoad / manual:commands:engine.setStationSlotMinimumLoad |
| commands:engine.setStationSlotMode | B3 | 实现中；候选待源行为比较 | src/game/engine.ts:11579 | scripts/game/StationSystem.gd::configure_slots | rule:commands:engine.setStationSlotMode / manual:commands:engine.setStationSlotMode |
| commands:engine.setStationSlotPriority | B3 | 实现中；候选待源行为比较 | src/game/engine.ts:11639 | scripts/game/StationSystem.gd::configure_slots | rule:commands:engine.setStationSlotPriority / manual:commands:engine.setStationSlotPriority |
| commands:engine.setStationSlotRoutePolicy | B3 | 实现中；候选待源行为比较 | src/game/engine.ts:11654 | scripts/game/StationSystem.gd::set_route_options | rule:commands:engine.setStationSlotRoutePolicy / manual:commands:engine.setStationSlotRoutePolicy |
| commands:engine.setStationSlotWarperBudget | B3 | 实现中；候选待源行为比较 | src/game/engine.ts:11669 | scripts/game/StationSystem.gd::set_route_options | rule:commands:engine.setStationSlotWarperBudget / manual:commands:engine.setStationSlotWarperBudget |
| commands:engine.setStationWarpEnabled | B3 | 实现中；候选待源行为比较 | src/game/engine.ts:12078 | scripts/game/StationSystem.gd::set_warp_enabled | rule:commands:engine.setStationWarpEnabled / manual:commands:engine.setStationWarpEnabled |
| commands:engine.setStationWarperAutoRefill | B3 | 实现中；候选待源行为比较 | src/game/engine.ts:12087 | scripts/game/StationSystem.gd::set_warper_refill | rule:commands:engine.setStationWarperAutoRefill / manual:commands:engine.setStationWarperAutoRefill |
| commands:engine.setStationWarperTarget | B3 | 实现中；候选待源行为比较 | src/game/engine.ts:12096 | scripts/game/StationSystem.gd::set_warper_refill | rule:commands:engine.setStationWarperTarget / manual:commands:engine.setStationWarperTarget |
| commands:engine.setTimeWarpController | B5 | 实现中；候选待源行为比较 | src/game/engine.ts:7264 | scripts/game/TimeWarpSystem.gd::select_controller | rule:commands:engine.setTimeWarpController / manual:commands:engine.setTimeWarpController |
| commands:engine.setTimeWarpEnabled | B5 | 实现中；候选待源行为比较 | src/game/engine.ts:7311 | scripts/game/TimeWarpSystem.gd::set_enabled | rule:commands:engine.setTimeWarpEnabled / manual:commands:engine.setTimeWarpEnabled |
| commands:engine.setTimeWarpRequestedMultiplier | B5 | 实现中；候选待源行为比较 | src/game/engine.ts:7329 | scripts/game/TimeWarpSystem.gd::set_requested | rule:commands:engine.setTimeWarpRequestedMultiplier / manual:commands:engine.setTimeWarpRequestedMultiplier |
| commands:engine.settleCompletedResearchBoundaries | — | 已验证；当前行为证据已绑定 | src/game/engine.ts:12968 | scripts/game/TechnologySystem.gd::settle_completed_source_research | rule:commands:engine.settleCompletedResearchBoundaries / manual:commands:engine.settleCompletedResearchBoundaries |
| commands:engine.settleCompletedResearchBoundariesInPlace | — | 已验证；当前行为证据已绑定 | src/game/engine.ts:12935 | scripts/game/TechnologySystem.gd::settle_completed_source_research_in_place | rule:commands:engine.settleCompletedResearchBoundariesInPlace / manual:commands:engine.settleCompletedResearchBoundariesInPlace |
| commands:engine.updateCanvasRegion | B2 | 实现中；候选待源行为比较 | src/game/engine.ts:9337 | scripts/game/CanvasNavigation.gd::save_region | rule:commands:engine.updateCanvasRegion / manual:commands:engine.updateCanvasRegion |
| commands:engine.upgradeBelt | B2 | 实现中；候选待源行为比较 | src/game/engine.ts:12428 | scripts/game/GameState.gd::upgrade_belt | rule:commands:engine.upgradeBelt / manual:commands:engine.upgradeBelt |
| commands:engine.upgradeBeltNetwork | B2 | 实现中；候选待源行为比较 | src/game/engine.ts:12526 | scripts/game/GameState.gd::upgrade_belt_network | rule:commands:engine.upgradeBeltNetwork / manual:commands:engine.upgradeBeltNetwork |
| commands:engine.upgradeEntities | B2 | 实现中；候选待源行为比较 | src/game/engine.ts:12409 | scripts/game/GameState.gd::upgrade_entities | rule:commands:engine.upgradeEntities / manual:commands:engine.upgradeEntities |
| commands:engine.upgradeEntity | B2 | 实现中；候选待源行为比较 | src/game/engine.ts:12392 | scripts/game/GameState.gd::upgrade_entity | rule:commands:engine.upgradeEntity / manual:commands:engine.upgradeEntity |
| commands:engine.upgradeSorter | B2 | 实现中；候选待源行为比较 | src/game/engine.ts:12451 | scripts/game/GameState.gd::upgrade_sorter | rule:commands:engine.upgradeSorter / manual:commands:engine.upgradeSorter |
| commands:engine.upgradeSorterNetwork | B2 | 实现中；候选待源行为比较 | src/game/engine.ts:12530 | scripts/game/GameState.gd::upgrade_sorter_network | rule:commands:engine.upgradeSorterNetwork / manual:commands:engine.upgradeSorterNetwork |
| commands:FactoryNodes.onAddBuilding | B2 | 未实现；待逐项核实/映射 | src/components/FactoryNodes.tsx:74 | 尚未确认 | rule:commands:FactoryNodes.onAddBuilding / manual:commands:FactoryNodes.onAddBuilding |
| commands:FactoryNodes.onDropCargo | B2 | 未实现；待逐项核实/映射 | src/components/FactoryNodes.tsx:71 | 尚未确认 | rule:commands:FactoryNodes.onDropCargo / manual:commands:FactoryNodes.onDropCargo |
| commands:FactoryNodes.onDropDraggedItem | B2 | 未实现；待逐项核实/映射 | src/components/FactoryNodes.tsx:72 | 尚未确认 | rule:commands:FactoryNodes.onDropDraggedItem / manual:commands:FactoryNodes.onDropDraggedItem |
| commands:FactoryNodes.onEnergyModeChange | B2 | 实现中；候选待源行为比较 | src/components/FactoryNodes.tsx:77 | scripts/game/GameState.gd::set_energy_mode | rule:commands:FactoryNodes.onEnergyModeChange / manual:commands:FactoryNodes.onEnergyModeChange |
| commands:FactoryNodes.onFuelChange | B2 | 未实现；待逐项核实/映射 | src/components/FactoryNodes.tsx:76 | 尚未确认 | rule:commands:FactoryNodes.onFuelChange / manual:commands:FactoryNodes.onFuelChange |
| commands:FactoryNodes.onInstallMiner | B1 | 未实现；待逐项核实/映射 | src/components/FactoryNodes.tsx:73 | 尚未确认 | rule:commands:FactoryNodes.onInstallMiner / manual:commands:FactoryNodes.onInstallMiner |
| commands:FactoryNodes.onInteractionLockChange | B2 | 未实现；待逐项核实/映射 | src/components/FactoryNodes.tsx:78 | 尚未确认 | rule:commands:FactoryNodes.onInteractionLockChange / manual:commands:FactoryNodes.onInteractionLockChange |
| commands:FactoryNodes.onMiningStart | B2 | 未实现；待逐项核实/映射 | src/components/FactoryNodes.tsx:67 | 尚未确认 | rule:commands:FactoryNodes.onMiningStart / manual:commands:FactoryNodes.onMiningStart |
| commands:FactoryNodes.onMiningStop | B2 | 未实现；待逐项核实/映射 | src/components/FactoryNodes.tsx:68 | 尚未确认 | rule:commands:FactoryNodes.onMiningStop / manual:commands:FactoryNodes.onMiningStop |
| commands:FactoryNodes.onPick | B2 | 未实现；待逐项核实/映射 | src/components/FactoryNodes.tsx:237 | 尚未确认 | rule:commands:FactoryNodes.onPick / manual:commands:FactoryNodes.onPick |
| commands:FactoryNodes.onPickInput | B2 | 未实现；待逐项核实/映射 | src/components/FactoryNodes.tsx:70 | 尚未确认 | rule:commands:FactoryNodes.onPickInput / manual:commands:FactoryNodes.onPickInput |
| commands:FactoryNodes.onPickOutput | B1 | 未实现；待逐项核实/映射 | src/components/FactoryNodes.tsx:69 | 尚未确认 | rule:commands:FactoryNodes.onPickOutput / manual:commands:FactoryNodes.onPickOutput |
| commands:FactoryNodes.onRecipeChange | B2 | 未实现；待逐项核实/映射 | src/components/FactoryNodes.tsx:75 | 尚未确认 | rule:commands:FactoryNodes.onRecipeChange / manual:commands:FactoryNodes.onRecipeChange |
| commands:FactoryNodes.onStackActivate | B2 | 未实现；待逐项核实/映射 | src/components/FactoryNodes.tsx:79 | 尚未确认 | rule:commands:FactoryNodes.onStackActivate / manual:commands:FactoryNodes.onStackActivate |
| commands:GalaxyWorkspace.onClose | — | 在线排除；固定在线白名单 | src/components/GalaxyWorkspace.tsx:75 | 尚未确认 | rule:commands:GalaxyWorkspace.onClose / manual:commands:GalaxyWorkspace.onClose |
| commands:GalaxyWorkspace.onCreateAccount | — | 在线排除；固定在线白名单 | src/components/GalaxyWorkspace.tsx:78 | 尚未确认 | rule:commands:GalaxyWorkspace.onCreateAccount / manual:commands:GalaxyWorkspace.onCreateAccount |
| commands:GalaxyWorkspace.onDiagnostics | — | 在线排除；固定在线白名单 | src/components/GalaxyWorkspace.tsx:488 | 尚未确认 | rule:commands:GalaxyWorkspace.onDiagnostics / manual:commands:GalaxyWorkspace.onDiagnostics |
| commands:GalaxyWorkspace.onRestoreCloudSave | — | 在线排除；固定在线白名单 | src/components/GalaxyWorkspace.tsx:80 | 尚未确认 | rule:commands:GalaxyWorkspace.onRestoreCloudSave / manual:commands:GalaxyWorkspace.onRestoreCloudSave |
| commands:GalaxyWorkspace.onStage | — | 在线排除；固定在线白名单 | src/components/GalaxyWorkspace.tsx:483 | 尚未确认 | rule:commands:GalaxyWorkspace.onStage / manual:commands:GalaxyWorkspace.onStage |
| commands:GalaxyWorkspace.onSwitchAccount | — | 在线排除；固定在线白名单 | src/components/GalaxyWorkspace.tsx:79 | 尚未确认 | rule:commands:GalaxyWorkspace.onSwitchAccount / manual:commands:GalaxyWorkspace.onSwitchAccount |
| commands:GalaxyWorkspace.onUpdateCloudBinding | — | 在线排除；固定在线白名单 | src/components/GalaxyWorkspace.tsx:77 | 尚未确认 | rule:commands:GalaxyWorkspace.onUpdateCloudBinding / manual:commands:GalaxyWorkspace.onUpdateCloudBinding |
| commands:GalaxyWorkspace.onUpdateProfile | — | 在线排除；固定在线白名单 | src/components/GalaxyWorkspace.tsx:76 | 尚未确认 | rule:commands:GalaxyWorkspace.onUpdateProfile / manual:commands:GalaxyWorkspace.onUpdateProfile |
| commands:GamePanels.onAddEntity | B2 | 未实现；待逐项核实/映射 | src/components/GamePanels.tsx:472 | 尚未确认 | rule:commands:GamePanels.onAddEntity / manual:commands:GamePanels.onAddEntity |
| commands:GamePanels.onApplyBeltConfigurationToNetwork | B2 | 未实现；待逐项核实/映射 | src/components/GamePanels.tsx:460 | 尚未确认 | rule:commands:GamePanels.onApplyBeltConfigurationToNetwork / manual:commands:GamePanels.onApplyBeltConfigurationToNetwork |
| commands:GamePanels.onApplyConfigurationToNetwork | B2 | 未实现；待逐项核实/映射 | src/components/GamePanels.tsx:1609 | 尚未确认 | rule:commands:GamePanels.onApplyConfigurationToNetwork / manual:commands:GamePanels.onApplyConfigurationToNetwork |
| commands:GamePanels.onBatchEjectorOrbitChange | B4 | 未实现；待逐项核实/映射 | src/components/GamePanels.tsx:484 | 尚未确认 | rule:commands:GamePanels.onBatchEjectorOrbitChange / manual:commands:GamePanels.onBatchEjectorOrbitChange |
| commands:GamePanels.onBatchInstallSprayCoater | B2 | 未实现；待逐项核实/映射 | src/components/GamePanels.tsx:485 | 尚未确认 | rule:commands:GamePanels.onBatchInstallSprayCoater / manual:commands:GamePanels.onBatchInstallSprayCoater |
| commands:GamePanels.onBatchProliferatorConfiguration | B2 | 未实现；待逐项核实/映射 | src/components/GamePanels.tsx:486 | 尚未确认 | rule:commands:GamePanels.onBatchProliferatorConfiguration / manual:commands:GamePanels.onBatchProliferatorConfiguration |
| commands:GamePanels.onBatchRecipeChange | B2 | 未实现；待逐项核实/映射 | src/components/GamePanels.tsx:483 | 尚未确认 | rule:commands:GamePanels.onBatchRecipeChange / manual:commands:GamePanels.onBatchRecipeChange |
| commands:GamePanels.onBeltLaneCountChange | B2 | 实现中；候选待源行为比较 | src/components/GamePanels.tsx:455 | scenes/ui/FactoryWorkspaceUI.gd::_on_belt_config_pressed | rule:commands:GamePanels.onBeltLaneCountChange / manual:commands:GamePanels.onBeltLaneCountChange |
| commands:GamePanels.onBeltMonitorChange | B2 | 未实现；待逐项核实/映射 | src/components/GamePanels.tsx:457 | 尚未确认 | rule:commands:GamePanels.onBeltMonitorChange / manual:commands:GamePanels.onBeltMonitorChange |
| commands:GamePanels.onBeltPriorityChange | B2 | 未实现；待逐项核实/映射 | src/components/GamePanels.tsx:454 | 尚未确认 | rule:commands:GamePanels.onBeltPriorityChange / manual:commands:GamePanels.onBeltPriorityChange |
| commands:GamePanels.onBeltRouteModeChange | B2 | 未实现；待逐项核实/映射 | src/components/GamePanels.tsx:458 | 尚未确认 | rule:commands:GamePanels.onBeltRouteModeChange / manual:commands:GamePanels.onBeltRouteModeChange |
| commands:GamePanels.onBeltRouteOffsetChange | B2 | 未实现；待逐项核实/映射 | src/components/GamePanels.tsx:459 | 尚未确认 | rule:commands:GamePanels.onBeltRouteOffsetChange / manual:commands:GamePanels.onBeltRouteOffsetChange |
| commands:GamePanels.onBeltStackSizeChange | B2 | 未实现；待逐项核实/映射 | src/components/GamePanels.tsx:456 | 尚未确认 | rule:commands:GamePanels.onBeltStackSizeChange / manual:commands:GamePanels.onBeltStackSizeChange |
| commands:GamePanels.onBeltTierChange | B2 | 未实现；待逐项核实/映射 | src/components/GamePanels.tsx:2180 | 尚未确认 | rule:commands:GamePanels.onBeltTierChange / manual:commands:GamePanels.onBeltTierChange |
| commands:GamePanels.onBeltTierModeChange | B2 | 未实现；待逐项核实/映射 | src/components/GamePanels.tsx:2181 | 尚未确认 | rule:commands:GamePanels.onBeltTierModeChange / manual:commands:GamePanels.onBeltTierModeChange |
| commands:GamePanels.onBlackHolePausedChange | B4 | 实现中；候选待源行为比较 | src/components/GamePanels.tsx:492 | scripts/game/BlackHoleSystem.gd::set_paused | rule:commands:GamePanels.onBlackHolePausedChange / manual:commands:GamePanels.onBlackHolePausedChange |
| commands:GamePanels.onCancelCraftQueue | B2 | 未实现；待逐项核实/映射 | src/components/GamePanels.tsx:471 | 尚未确认 | rule:commands:GamePanels.onCancelCraftQueue / manual:commands:GamePanels.onCancelCraftQueue |
| commands:GamePanels.onChange | B2 | 未实现；待逐项核实/映射 | src/components/GamePanels.tsx:504 | 尚未确认 | rule:commands:GamePanels.onChange / manual:commands:GamePanels.onChange |
| commands:GamePanels.onConfigure | B2 | 未实现；待逐项核实/映射 | src/components/GamePanels.tsx:706 | 尚未确认 | rule:commands:GamePanels.onConfigure / manual:commands:GamePanels.onConfigure |
| commands:GamePanels.onCopyBeltConfiguration | B2 | 未实现；待逐项核实/映射 | src/components/GamePanels.tsx:465 | 尚未确认 | rule:commands:GamePanels.onCopyBeltConfiguration / manual:commands:GamePanels.onCopyBeltConfiguration |
| commands:GamePanels.onCopyConfiguration | B2 | 未实现；待逐项核实/映射 | src/components/GamePanels.tsx:1613 | 尚未确认 | rule:commands:GamePanels.onCopyConfiguration / manual:commands:GamePanels.onCopyConfiguration |
| commands:GamePanels.onCraft | B2 | 未实现；待逐项核实/映射 | src/components/GamePanels.tsx:468 | 尚未确认 | rule:commands:GamePanels.onCraft / manual:commands:GamePanels.onCraft |
| commands:GamePanels.onCraftItem | B2 | 未实现；待逐项核实/映射 | src/components/GamePanels.tsx:469 | 尚未确认 | rule:commands:GamePanels.onCraftItem / manual:commands:GamePanels.onCraftItem |
| commands:GamePanels.onDeleteConstruction | B2 | 未实现；待逐项核实/映射 | src/components/GamePanels.tsx:2188 | 尚未确认 | rule:commands:GamePanels.onDeleteConstruction / manual:commands:GamePanels.onDeleteConstruction |
| commands:GamePanels.onDiscardTrayItems | B1 | 未实现；待逐项核实/映射 | src/components/GamePanels.tsx:130 | 尚未确认 | rule:commands:GamePanels.onDiscardTrayItems / manual:commands:GamePanels.onDiscardTrayItems |
| commands:GamePanels.onDropCargo | B2 | 未实现；待逐项核实/映射 | src/components/GamePanels.tsx:127 | 尚未确认 | rule:commands:GamePanels.onDropCargo / manual:commands:GamePanels.onDropCargo |
| commands:GamePanels.onDropDraggedItem | B2 | 未实现；待逐项核实/映射 | src/components/GamePanels.tsx:128 | 尚未确认 | rule:commands:GamePanels.onDropDraggedItem / manual:commands:GamePanels.onDropDraggedItem |
| commands:GamePanels.onEjectorOrbitChange | B4 | 未实现；待逐项核实/映射 | src/components/GamePanels.tsx:424 | 尚未确认 | rule:commands:GamePanels.onEjectorOrbitChange / manual:commands:GamePanels.onEjectorOrbitChange |
| commands:GamePanels.onEnergyModeChange | B2 | 实现中；候选待源行为比较 | src/components/GamePanels.tsx:431 | scripts/game/GameState.gd::set_energy_mode | rule:commands:GamePanels.onEnergyModeChange / manual:commands:GamePanels.onEnergyModeChange |
| commands:GamePanels.onEntityLockChange | B2 | 未实现；待逐项核实/映射 | src/components/GamePanels.tsx:488 | 尚未确认 | rule:commands:GamePanels.onEntityLockChange / manual:commands:GamePanels.onEntityLockChange |
| commands:GamePanels.onEntityStackTarget | B2 | 未实现；待逐项核实/映射 | src/components/GamePanels.tsx:473 | 尚未确认 | rule:commands:GamePanels.onEntityStackTarget / manual:commands:GamePanels.onEntityStackTarget |
| commands:GamePanels.onFocusBeltNetwork | B2 | 未实现；待逐项核实/映射 | src/components/GamePanels.tsx:461 | 尚未确认 | rule:commands:GamePanels.onFocusBeltNetwork / manual:commands:GamePanels.onFocusBeltNetwork |
| commands:GamePanels.onFocusNetwork | B2 | 未实现；待逐项核实/映射 | src/components/GamePanels.tsx:1610 | 尚未确认 | rule:commands:GamePanels.onFocusNetwork / manual:commands:GamePanels.onFocusNetwork |
| commands:GamePanels.onFuelChange | B2 | 未实现；待逐项核实/映射 | src/components/GamePanels.tsx:430 | 尚未确认 | rule:commands:GamePanels.onFuelChange / manual:commands:GamePanels.onFuelChange |
| commands:GamePanels.onGalacticExporterPausedChange | — | 在线排除；固定在线白名单 | src/components/GamePanels.tsx:491 | 尚未确认 | rule:commands:GamePanels.onGalacticExporterPausedChange / manual:commands:GamePanels.onGalacticExporterPausedChange |
| commands:GamePanels.onGenerationPriorityChange | B2 | 实现中；候选待源行为比较 | src/components/GamePanels.tsx:434 | scripts/game/GameState.gd::set_entity_generation_priority | rule:commands:GamePanels.onGenerationPriorityChange / manual:commands:GamePanels.onGenerationPriorityChange |
| commands:GamePanels.onGridChange | B2 | 实现中；候选待源行为比较 | src/components/GamePanels.tsx:775 | scripts/game/GameState.gd::set_entity_power_grid | rule:commands:GamePanels.onGridChange / manual:commands:GamePanels.onGridChange |
| commands:GamePanels.onInstall | B2 | 未实现；待逐项核实/映射 | src/components/GamePanels.tsx:704 | 尚未确认 | rule:commands:GamePanels.onInstall / manual:commands:GamePanels.onInstall |
| commands:GamePanels.onInstallSprayCoater | B2 | 未实现；待逐项核实/映射 | src/components/GamePanels.tsx:479 | 尚未确认 | rule:commands:GamePanels.onInstallSprayCoater / manual:commands:GamePanels.onInstallSprayCoater |
| commands:GamePanels.onLaneCountChange | B2 | 实现中；候选待源行为比较 | src/components/GamePanels.tsx:1604 | scenes/ui/FactoryWorkspaceUI.gd::_on_belt_config_pressed | rule:commands:GamePanels.onLaneCountChange / manual:commands:GamePanels.onLaneCountChange |
| commands:GamePanels.onLogisticsItemChange | B3 | 未实现；待逐项核实/映射 | src/components/GamePanels.tsx:425 | 尚未确认 | rule:commands:GamePanels.onLogisticsItemChange / manual:commands:GamePanels.onLogisticsItemChange |
| commands:GamePanels.onMaterialDeliverySlotChange | B2 | 未实现；待逐项核实/映射 | src/components/GamePanels.tsx:426 | 尚未确认 | rule:commands:GamePanels.onMaterialDeliverySlotChange / manual:commands:GamePanels.onMaterialDeliverySlotChange |
| commands:GamePanels.onMissingCraftNavigate | B2 | 未实现；待逐项核实/映射 | src/components/GamePanels.tsx:2187 | 尚未确认 | rule:commands:GamePanels.onMissingCraftNavigate / manual:commands:GamePanels.onMissingCraftNavigate |
| commands:GamePanels.onMonitorChange | B2 | 未实现；待逐项核实/映射 | src/components/GamePanels.tsx:1606 | 尚未确认 | rule:commands:GamePanels.onMonitorChange / manual:commands:GamePanels.onMonitorChange |
| commands:GamePanels.onOpenCampaign | — | 已验证；当前行为证据已绑定 | src/components/GamePanels.tsx:124 | scenes/ui/CampaignWorkspace.gd::_show_workspace | rule:commands:GamePanels.onOpenCampaign / manual:commands:GamePanels.onOpenCampaign |
| commands:GamePanels.onOpenCommandPalette | B2 | 实现中；候选待源行为比较 | src/components/GamePanels.tsx:2468 | scenes/ui/FactoryWorkspaceUI.gd::open_command_palette | rule:commands:GamePanels.onOpenCommandPalette / manual:commands:GamePanels.onOpenCommandPalette |
| commands:GamePanels.onOpenConstructionCenter | B2 | 未实现；待逐项核实/映射 | src/components/GamePanels.tsx:490 | 尚未确认 | rule:commands:GamePanels.onOpenConstructionCenter / manual:commands:GamePanels.onOpenConstructionCenter |
| commands:GamePanels.onOpenDysonPlanner | B4 | 实现中；候选待源行为比较 | src/components/GamePanels.tsx:125 | scenes/ui/DysonUI.gd | rule:commands:GamePanels.onOpenDysonPlanner / manual:commands:GamePanels.onOpenDysonPlanner |
| commands:GamePanels.onOpenFabricator | B2 | 未实现；待逐项核实/映射 | src/components/GamePanels.tsx:2183 | 尚未确认 | rule:commands:GamePanels.onOpenFabricator / manual:commands:GamePanels.onOpenFabricator |
| commands:GamePanels.onOpenGalaxy | B2 | 实现中；候选待源行为比较 | src/components/GamePanels.tsx:2464 | scenes/ui/GalaxyMap.gd | rule:commands:GamePanels.onOpenGalaxy / manual:commands:GamePanels.onOpenGalaxy |
| commands:GamePanels.onOpenInspector | B2 | 未实现；待逐项核实/映射 | src/components/GamePanels.tsx:2458 | 尚未确认 | rule:commands:GamePanels.onOpenInspector / manual:commands:GamePanels.onOpenInspector |
| commands:GamePanels.onOpenOrbitalStation | B3 | 实现中；候选待源行为比较 | src/components/GamePanels.tsx:428 | scenes/ui/LocalSpaceStationWorkspace.gd | rule:commands:GamePanels.onOpenOrbitalStation / manual:commands:GamePanels.onOpenOrbitalStation |
| commands:GamePanels.onOpenRecipes | B2 | 未实现；待逐项核实/映射 | src/components/GamePanels.tsx:2459 | 尚未确认 | rule:commands:GamePanels.onOpenRecipes / manual:commands:GamePanels.onOpenRecipes |
| commands:GamePanels.onOpenResources | B1 | 未实现；待逐项核实/映射 | src/components/GamePanels.tsx:2457 | 尚未确认 | rule:commands:GamePanels.onOpenResources / manual:commands:GamePanels.onOpenResources |
| commands:GamePanels.onOpenResourceSettings | B5 | 未实现；待逐项核实/映射 | src/components/GamePanels.tsx:481 | 尚未确认 | rule:commands:GamePanels.onOpenResourceSettings / manual:commands:GamePanels.onOpenResourceSettings |
| commands:GamePanels.onOpenSettings | B5 | 未实现；待逐项核实/映射 | src/components/GamePanels.tsx:2463 | 尚未确认 | rule:commands:GamePanels.onOpenSettings / manual:commands:GamePanels.onOpenSettings |
| commands:GamePanels.onOpenStarMap | B3 | 实现中；候选待源行为比较 | src/components/GamePanels.tsx:2462 | scenes/ui/GalaxyMap.gd | rule:commands:GamePanels.onOpenStarMap / manual:commands:GamePanels.onOpenStarMap |
| commands:GamePanels.onOpenStatistics | B2 | 未实现；待逐项核实/映射 | src/components/GamePanels.tsx:2461 | 尚未确认 | rule:commands:GamePanels.onOpenStatistics / manual:commands:GamePanels.onOpenStatistics |
| commands:GamePanels.onOpenTechnology | B2 | 实现中；候选待源行为比较 | src/components/GamePanels.tsx:2460 | scenes/ui/FactoryWorkspaceUI.gd::_toggle_technology_workspace | rule:commands:GamePanels.onOpenTechnology / manual:commands:GamePanels.onOpenTechnology |
| commands:GamePanels.onOpenTutorial | B2 | 实现中；候选待源行为比较 | src/components/GamePanels.tsx:498 | scenes/ui/TutorialOverlay.gd::_ready | rule:commands:GamePanels.onOpenTutorial / manual:commands:GamePanels.onOpenTutorial |
| commands:GamePanels.onOrbitalCargoPortClear | B3 | 未实现；待逐项核实/映射 | src/components/GamePanels.tsx:429 | 尚未确认 | rule:commands:GamePanels.onOrbitalCargoPortClear / manual:commands:GamePanels.onOrbitalCargoPortClear |
| commands:GamePanels.onOrbitalCollectorQuantumMode | B3 | 实现中；候选待源行为比较 | src/components/GamePanels.tsx:477 | scripts/game/QuantumLogisticsSystem.gd::set_collector_mode | rule:commands:GamePanels.onOrbitalCollectorQuantumMode / manual:commands:GamePanels.onOrbitalCollectorQuantumMode |
| commands:GamePanels.onPasteBeltConfiguration | B2 | 未实现；待逐项核实/映射 | src/components/GamePanels.tsx:466 | 尚未确认 | rule:commands:GamePanels.onPasteBeltConfiguration / manual:commands:GamePanels.onPasteBeltConfiguration |
| commands:GamePanels.onPasteConfiguration | B2 | 未实现；待逐项核实/映射 | src/components/GamePanels.tsx:1614 | 尚未确认 | rule:commands:GamePanels.onPasteConfiguration / manual:commands:GamePanels.onPasteConfiguration |
| commands:GamePanels.onPauseToggle | B2 | 未实现；待逐项核实/映射 | src/components/GamePanels.tsx:2456 | 尚未确认 | rule:commands:GamePanels.onPauseToggle / manual:commands:GamePanels.onPauseToggle |
| commands:GamePanels.onPickEntityInput | B2 | 未实现；待逐项核实/映射 | src/components/GamePanels.tsx:427 | 尚未确认 | rule:commands:GamePanels.onPickEntityInput / manual:commands:GamePanels.onPickEntityInput |
| commands:GamePanels.onPickTray | B1 | 未实现；待逐项核实/映射 | src/components/GamePanels.tsx:126 | 尚未确认 | rule:commands:GamePanels.onPickTray / manual:commands:GamePanels.onPickTray |
| commands:GamePanels.onPlacementChange | B2 | 未实现；待逐项核实/映射 | src/components/GamePanels.tsx:2179 | 尚未确认 | rule:commands:GamePanels.onPlacementChange / manual:commands:GamePanels.onPlacementChange |
| commands:GamePanels.onPlacementCountChange | B2 | 未实现；待逐项核实/映射 | src/components/GamePanels.tsx:2182 | 尚未确认 | rule:commands:GamePanels.onPlacementCountChange / manual:commands:GamePanels.onPlacementCountChange |
| commands:GamePanels.onPlanetChange | B2 | 实现中；候选待源行为比较 | src/components/GamePanels.tsx:378 | scripts/game/PlanetSystem.gd::try_set_active_planet | rule:commands:GamePanels.onPlanetChange / manual:commands:GamePanels.onPlanetChange |
| commands:GamePanels.onPowerGridChange | B2 | 实现中；候选待源行为比较 | src/components/GamePanels.tsx:432 | scripts/game/GameState.gd::set_entity_power_grid | rule:commands:GamePanels.onPowerGridChange / manual:commands:GamePanels.onPowerGridChange |
| commands:GamePanels.onPowerPriorityChange | B2 | 实现中；候选待源行为比较 | src/components/GamePanels.tsx:433 | scripts/game/GameState.gd::set_entity_power_priority | rule:commands:GamePanels.onPowerPriorityChange / manual:commands:GamePanels.onPowerPriorityChange |
| commands:GamePanels.onPriorityChange | B2 | 未实现；待逐项核实/映射 | src/components/GamePanels.tsx:1603 | 尚未确认 | rule:commands:GamePanels.onPriorityChange / manual:commands:GamePanels.onPriorityChange |
| commands:GamePanels.onProliferatorConfiguration | B2 | 未实现；待逐项核实/映射 | src/components/GamePanels.tsx:482 | 尚未确认 | rule:commands:GamePanels.onProliferatorConfiguration / manual:commands:GamePanels.onProliferatorConfiguration |
| commands:GamePanels.onQuantumAttachment | B3 | 实现中；候选待源行为比较 | src/components/GamePanels.tsx:476 | scripts/game/QuantumLogisticsSystem.gd::attach | rule:commands:GamePanels.onQuantumAttachment / manual:commands:GamePanels.onQuantumAttachment |
| commands:GamePanels.onQueueCraftItem | B2 | 未实现；待逐项核实/映射 | src/components/GamePanels.tsx:470 | 尚未确认 | rule:commands:GamePanels.onQueueCraftItem / manual:commands:GamePanels.onQueueCraftItem |
| commands:GamePanels.onRecipeChange | B2 | 未实现；待逐项核实/映射 | src/components/GamePanels.tsx:423 | 尚未确认 | rule:commands:GamePanels.onRecipeChange / manual:commands:GamePanels.onRecipeChange |
| commands:GamePanels.onRemove | B2 | 未实现；待逐项核实/映射 | src/components/GamePanels.tsx:705 | 尚未确认 | rule:commands:GamePanels.onRemove / manual:commands:GamePanels.onRemove |
| commands:GamePanels.onRemoveBelt | B2 | 未实现；待逐项核实/映射 | src/components/GamePanels.tsx:489 | 尚未确认 | rule:commands:GamePanels.onRemoveBelt / manual:commands:GamePanels.onRemoveBelt |
| commands:GamePanels.onRemoveBeltNetwork | B2 | 未实现；待逐项核实/映射 | src/components/GamePanels.tsx:462 | 尚未确认 | rule:commands:GamePanels.onRemoveBeltNetwork / manual:commands:GamePanels.onRemoveBeltNetwork |
| commands:GamePanels.onRemoveEntity | B2 | 未实现；待逐项核实/映射 | src/components/GamePanels.tsx:487 | 尚未确认 | rule:commands:GamePanels.onRemoveEntity / manual:commands:GamePanels.onRemoveEntity |
| commands:GamePanels.onRemoveNetwork | B2 | 未实现；待逐项核实/映射 | src/components/GamePanels.tsx:1616 | 尚未确认 | rule:commands:GamePanels.onRemoveNetwork / manual:commands:GamePanels.onRemoveNetwork |
| commands:GamePanels.onRemoveSprayCoater | B2 | 未实现；待逐项核实/映射 | src/components/GamePanels.tsx:480 | 尚未确认 | rule:commands:GamePanels.onRemoveSprayCoater / manual:commands:GamePanels.onRemoveSprayCoater |
| commands:GamePanels.onReturnToMenu | B2 | 未实现；待逐项核实/映射 | src/components/GamePanels.tsx:2455 | 尚未确认 | rule:commands:GamePanels.onReturnToMenu / manual:commands:GamePanels.onReturnToMenu |
| commands:GamePanels.onRouteModeChange | B2 | 未实现；待逐项核实/映射 | src/components/GamePanels.tsx:1607 | 尚未确认 | rule:commands:GamePanels.onRouteModeChange / manual:commands:GamePanels.onRouteModeChange |
| commands:GamePanels.onRouteOffsetChange | B2 | 未实现；待逐项核实/映射 | src/components/GamePanels.tsx:1608 | 尚未确认 | rule:commands:GamePanels.onRouteOffsetChange / manual:commands:GamePanels.onRouteOffsetChange |
| commands:GamePanels.onSetTarget | B2 | 未实现；待逐项核实/映射 | src/components/GamePanels.tsx:806 | 尚未确认 | rule:commands:GamePanels.onSetTarget / manual:commands:GamePanels.onSetTarget |
| commands:GamePanels.onSetTrayItemLimit | B1 | 未实现；待逐项核实/映射 | src/components/GamePanels.tsx:129 | 尚未确认 | rule:commands:GamePanels.onSetTrayItemLimit / manual:commands:GamePanels.onSetTrayItemLimit |
| commands:GamePanels.onSplitterModeChange | B2 | 未实现；待逐项核实/映射 | src/components/GamePanels.tsx:453 | 尚未确认 | rule:commands:GamePanels.onSplitterModeChange / manual:commands:GamePanels.onSplitterModeChange |
| commands:GamePanels.onStackSizeChange | B2 | 未实现；待逐项核实/映射 | src/components/GamePanels.tsx:1605 | 尚未确认 | rule:commands:GamePanels.onStackSizeChange / manual:commands:GamePanels.onStackSizeChange |
| commands:GamePanels.onStationDroneAdjust | B3 | 实现中；候选待源行为比较 | src/components/GamePanels.tsx:437 | scripts/game/StationSystem.gd::transfer_fleet | rule:commands:GamePanels.onStationDroneAdjust / manual:commands:GamePanels.onStationDroneAdjust |
| commands:GamePanels.onStationFleetFill | B3 | 实现中；候选待源行为比较 | src/components/GamePanels.tsx:439 | scripts/game/StationSystem.gd::set_fleet_target | rule:commands:GamePanels.onStationFleetFill / manual:commands:GamePanels.onStationFleetFill |
| commands:GamePanels.onStationFleetTarget | B3 | 实现中；候选待源行为比较 | src/components/GamePanels.tsx:438 | scripts/game/StationSystem.gd::set_fleet_target | rule:commands:GamePanels.onStationFleetTarget / manual:commands:GamePanels.onStationFleetTarget |
| commands:GamePanels.onStationHubChange | B3 | 实现中；候选待源行为比较 | src/components/GamePanels.tsx:444 | scripts/game/StationSystem.gd::set_hub | rule:commands:GamePanels.onStationHubChange / manual:commands:GamePanels.onStationHubChange |
| commands:GamePanels.onStationMinimumLoadChange | B3 | 实现中；候选待源行为比较 | src/components/GamePanels.tsx:445 | scripts/game/StationSystem.gd::configure_slots | rule:commands:GamePanels.onStationMinimumLoadChange / manual:commands:GamePanels.onStationMinimumLoadChange |
| commands:GamePanels.onStationModeChange | B3 | 实现中；候选待源行为比较 | src/components/GamePanels.tsx:435 | scripts/game/StationSystem.gd::configure_slots | rule:commands:GamePanels.onStationModeChange / manual:commands:GamePanels.onStationModeChange |
| commands:GamePanels.onStationSlotItemChange | B3 | 实现中；候选待源行为比较 | src/components/GamePanels.tsx:446 | scripts/game/StationSystem.gd::configure_slots | rule:commands:GamePanels.onStationSlotItemChange / manual:commands:GamePanels.onStationSlotItemChange |
| commands:GamePanels.onStationSlotLimitsChange | B3 | 实现中；候选待源行为比较 | src/components/GamePanels.tsx:449 | scripts/game/StationSystem.gd::set_slot_limits | rule:commands:GamePanels.onStationSlotLimitsChange / manual:commands:GamePanels.onStationSlotLimitsChange |
| commands:GamePanels.onStationSlotMinimumLoadChange | B3 | 实现中；候选待源行为比较 | src/components/GamePanels.tsx:448 | scripts/game/StationSystem.gd::configure_slots | rule:commands:GamePanels.onStationSlotMinimumLoadChange / manual:commands:GamePanels.onStationSlotMinimumLoadChange |
| commands:GamePanels.onStationSlotModeChange | B3 | 实现中；候选待源行为比较 | src/components/GamePanels.tsx:447 | scripts/game/StationSystem.gd::configure_slots | rule:commands:GamePanels.onStationSlotModeChange / manual:commands:GamePanels.onStationSlotModeChange |
| commands:GamePanels.onStationSlotPriorityChange | B3 | 实现中；候选待源行为比较 | src/components/GamePanels.tsx:450 | scripts/game/StationSystem.gd::configure_slots | rule:commands:GamePanels.onStationSlotPriorityChange / manual:commands:GamePanels.onStationSlotPriorityChange |
| commands:GamePanels.onStationSlotRoutePolicyChange | B3 | 实现中；候选待源行为比较 | src/components/GamePanels.tsx:451 | scripts/game/StationSystem.gd::set_route_options | rule:commands:GamePanels.onStationSlotRoutePolicyChange / manual:commands:GamePanels.onStationSlotRoutePolicyChange |
| commands:GamePanels.onStationSlotWarperBudgetChange | B3 | 实现中；候选待源行为比较 | src/components/GamePanels.tsx:452 | scripts/game/StationSystem.gd::set_route_options | rule:commands:GamePanels.onStationSlotWarperBudgetChange / manual:commands:GamePanels.onStationSlotWarperBudgetChange |
| commands:GamePanels.onStationVesselAdjust | B3 | 实现中；候选待源行为比较 | src/components/GamePanels.tsx:436 | scripts/game/StationSystem.gd::transfer_fleet | rule:commands:GamePanels.onStationVesselAdjust / manual:commands:GamePanels.onStationVesselAdjust |
| commands:GamePanels.onStationWarpEnabled | B3 | 实现中；候选待源行为比较 | src/components/GamePanels.tsx:441 | scripts/game/StationSystem.gd::set_warp_enabled | rule:commands:GamePanels.onStationWarpEnabled / manual:commands:GamePanels.onStationWarpEnabled |
| commands:GamePanels.onStationWarperAdjust | B3 | 实现中；候选待源行为比较 | src/components/GamePanels.tsx:440 | scripts/game/StationSystem.gd::transfer_fleet | rule:commands:GamePanels.onStationWarperAdjust / manual:commands:GamePanels.onStationWarperAdjust |
| commands:GamePanels.onStationWarperAutoRefillChange | B3 | 实现中；候选待源行为比较 | src/components/GamePanels.tsx:442 | scripts/game/StationSystem.gd::set_warper_refill | rule:commands:GamePanels.onStationWarperAutoRefillChange / manual:commands:GamePanels.onStationWarperAutoRefillChange |
| commands:GamePanels.onStationWarperTargetChange | B3 | 实现中；候选待源行为比较 | src/components/GamePanels.tsx:443 | scripts/game/StationSystem.gd::set_warper_refill | rule:commands:GamePanels.onStationWarperTargetChange / manual:commands:GamePanels.onStationWarperTargetChange |
| commands:GamePanels.onStowCargo | B2 | 未实现；待逐项核实/映射 | src/components/GamePanels.tsx:2186 | 尚未确认 | rule:commands:GamePanels.onStowCargo / manual:commands:GamePanels.onStowCargo |
| commands:GamePanels.onTabChange | B2 | 未实现；待逐项核实/映射 | src/components/GamePanels.tsx:422 | 尚未确认 | rule:commands:GamePanels.onTabChange / manual:commands:GamePanels.onTabChange |
| commands:GamePanels.onTimeWarpControllerChange | B5 | 实现中；候选待源行为比较 | src/components/GamePanels.tsx:493 | scripts/game/TimeWarpSystem.gd::select_controller | rule:commands:GamePanels.onTimeWarpControllerChange / manual:commands:GamePanels.onTimeWarpControllerChange |
| commands:GamePanels.onTimeWarpEnabledChange | B5 | 实现中；候选待源行为比较 | src/components/GamePanels.tsx:494 | scripts/game/TimeWarpSystem.gd::set_enabled | rule:commands:GamePanels.onTimeWarpEnabledChange / manual:commands:GamePanels.onTimeWarpEnabledChange |
| commands:GamePanels.onTimeWarpRequestedMultiplierChange | B5 | 实现中；候选待源行为比较 | src/components/GamePanels.tsx:495 | scripts/game/TimeWarpSystem.gd::set_requested | rule:commands:GamePanels.onTimeWarpRequestedMultiplierChange / manual:commands:GamePanels.onTimeWarpRequestedMultiplierChange |
| commands:GamePanels.onUpgrade | B2 | 未实现；待逐项核实/映射 | src/components/GamePanels.tsx:671 | 尚未确认 | rule:commands:GamePanels.onUpgrade / manual:commands:GamePanels.onUpgrade |
| commands:GamePanels.onUpgradeBelt | B2 | 未实现；待逐项核实/映射 | src/components/GamePanels.tsx:478 | 尚未确认 | rule:commands:GamePanels.onUpgradeBelt / manual:commands:GamePanels.onUpgradeBelt |
| commands:GamePanels.onUpgradeBeltNetwork | B2 | 未实现；待逐项核实/映射 | src/components/GamePanels.tsx:464 | 尚未确认 | rule:commands:GamePanels.onUpgradeBeltNetwork / manual:commands:GamePanels.onUpgradeBeltNetwork |
| commands:GamePanels.onUpgradeEntity | B2 | 未实现；待逐项核实/映射 | src/components/GamePanels.tsx:474 | 尚未确认 | rule:commands:GamePanels.onUpgradeEntity / manual:commands:GamePanels.onUpgradeEntity |
| commands:GamePanels.onUpgradeInterstellarStation | B3 | 实现中；候选待源行为比较 | src/components/GamePanels.tsx:475 | scripts/game/QuantumLogisticsSystem.gd::upgrade_station | rule:commands:GamePanels.onUpgradeInterstellarStation / manual:commands:GamePanels.onUpgradeInterstellarStation |
| commands:GamePanels.onUpgradeNetwork | B2 | 未实现；待逐项核实/映射 | src/components/GamePanels.tsx:1612 | 尚未确认 | rule:commands:GamePanels.onUpgradeNetwork / manual:commands:GamePanels.onUpgradeNetwork |
| commands:ItemReference.onLocate | B2 | 未实现；待逐项核实/映射 | src/components/ItemReference.tsx:22 | 尚未确认 | rule:commands:ItemReference.onLocate / manual:commands:ItemReference.onLocate |
| commands:ItemReference.onOpenCodex | B2 | 未实现；待逐项核实/映射 | src/components/ItemReference.tsx:23 | 尚未确认 | rule:commands:ItemReference.onOpenCodex / manual:commands:ItemReference.onOpenCodex |
| commands:LogisticsManagementPanel.onCollectorItemChange | B3 | 实现中；候选待源行为比较 | src/components/LogisticsManagementPanel.tsx:94 | scripts/game/OrbitalCollectorSystem.gd::select_item | rule:commands:LogisticsManagementPanel.onCollectorItemChange / manual:commands:LogisticsManagementPanel.onCollectorItemChange |
| commands:LogisticsManagementPanel.onCollectorQuantumModeChange | B3 | 实现中；候选待源行为比较 | src/components/LogisticsManagementPanel.tsx:93 | scripts/game/QuantumLogisticsSystem.gd::set_collector_mode | rule:commands:LogisticsManagementPanel.onCollectorQuantumModeChange / manual:commands:LogisticsManagementPanel.onCollectorQuantumModeChange |
| commands:LogisticsManagementPanel.onFleetTargetChange | B3 | 实现中；候选待源行为比较 | src/components/LogisticsManagementPanel.tsx:86 | scripts/game/StationSystem.gd::set_fleet_target | rule:commands:LogisticsManagementPanel.onFleetTargetChange / manual:commands:LogisticsManagementPanel.onFleetTargetChange |
| commands:LogisticsManagementPanel.onQuantumAttach | B3 | 实现中；候选待源行为比较 | src/components/LogisticsManagementPanel.tsx:92 | scripts/game/QuantumLogisticsSystem.gd::attach | rule:commands:LogisticsManagementPanel.onQuantumAttach / manual:commands:LogisticsManagementPanel.onQuantumAttach |
| commands:LogisticsManagementPanel.onSlotItemChange | B3 | 实现中；候选待源行为比较 | src/components/LogisticsManagementPanel.tsx:81 | scripts/game/StationSystem.gd::configure_slots | rule:commands:LogisticsManagementPanel.onSlotItemChange / manual:commands:LogisticsManagementPanel.onSlotItemChange |
| commands:LogisticsManagementPanel.onSlotLimitsChange | B3 | 实现中；候选待源行为比较 | src/components/LogisticsManagementPanel.tsx:84 | scripts/game/StationSystem.gd::set_slot_limits | rule:commands:LogisticsManagementPanel.onSlotLimitsChange / manual:commands:LogisticsManagementPanel.onSlotLimitsChange |
| commands:LogisticsManagementPanel.onSlotMinimumLoadChange | B3 | 实现中；候选待源行为比较 | src/components/LogisticsManagementPanel.tsx:83 | scripts/game/StationSystem.gd::configure_slots | rule:commands:LogisticsManagementPanel.onSlotMinimumLoadChange / manual:commands:LogisticsManagementPanel.onSlotMinimumLoadChange |
| commands:LogisticsManagementPanel.onSlotModeChange | B3 | 实现中；候选待源行为比较 | src/components/LogisticsManagementPanel.tsx:82 | scripts/game/StationSystem.gd::configure_slots | rule:commands:LogisticsManagementPanel.onSlotModeChange / manual:commands:LogisticsManagementPanel.onSlotModeChange |
| commands:LogisticsManagementPanel.onSlotPriorityChange | B3 | 实现中；候选待源行为比较 | src/components/LogisticsManagementPanel.tsx:85 | scripts/game/StationSystem.gd::configure_slots | rule:commands:LogisticsManagementPanel.onSlotPriorityChange / manual:commands:LogisticsManagementPanel.onSlotPriorityChange |
| commands:LogisticsManagementPanel.onStackTargetChange | B3 | 实现中；候选待源行为比较 | src/components/LogisticsManagementPanel.tsx:91 | scripts/game/StationSystem.gd::set_stack_target | rule:commands:LogisticsManagementPanel.onStackTargetChange / manual:commands:LogisticsManagementPanel.onStackTargetChange |
| commands:LogisticsManagementPanel.onToggle | B3 | 实现中；候选待源行为比较 | src/components/LogisticsManagementPanel.tsx:169 | scripts/game/StationSystem.gd::set_enabled | rule:commands:LogisticsManagementPanel.onToggle / manual:commands:LogisticsManagementPanel.onToggle |
| commands:LogisticsManagementPanel.onWarpEnabledChange | B3 | 实现中；候选待源行为比较 | src/components/LogisticsManagementPanel.tsx:88 | scripts/game/StationSystem.gd::set_warp_enabled | rule:commands:LogisticsManagementPanel.onWarpEnabledChange / manual:commands:LogisticsManagementPanel.onWarpEnabledChange |
| commands:LogisticsManagementPanel.onWarperAdjust | B3 | 实现中；候选待源行为比较 | src/components/LogisticsManagementPanel.tsx:87 | scripts/game/StationSystem.gd::transfer_fleet | rule:commands:LogisticsManagementPanel.onWarperAdjust / manual:commands:LogisticsManagementPanel.onWarperAdjust |
| commands:LogisticsManagementPanel.onWarperAutoRefillChange | B3 | 实现中；候选待源行为比较 | src/components/LogisticsManagementPanel.tsx:89 | scripts/game/StationSystem.gd::set_warper_refill | rule:commands:LogisticsManagementPanel.onWarperAutoRefillChange / manual:commands:LogisticsManagementPanel.onWarperAutoRefillChange |
| commands:LogisticsManagementPanel.onWarperTargetChange | B3 | 实现中；候选待源行为比较 | src/components/LogisticsManagementPanel.tsx:90 | scripts/game/StationSystem.gd::set_warper_refill | rule:commands:LogisticsManagementPanel.onWarperTargetChange / manual:commands:LogisticsManagementPanel.onWarperTargetChange |
| commands:OfflineReportWorkspace.onClose | B2 | 实现中；候选待源行为比较 | src/components/OfflineReportWorkspace.tsx:19 | scenes/ui/AppShell.gd::_on_session_started | rule:commands:OfflineReportWorkspace.onClose / manual:commands:OfflineReportWorkspace.onClose |
| commands:OnboardingCoach.onAction | B2 | 未实现；待逐项核实/映射 | src/components/OnboardingCoach.tsx:8 | 尚未确认 | rule:commands:OnboardingCoach.onAction / manual:commands:OnboardingCoach.onAction |
| commands:OnboardingCoach.onDismiss | B2 | 未实现；待逐项核实/映射 | src/components/OnboardingCoach.tsx:13 | 尚未确认 | rule:commands:OnboardingCoach.onDismiss / manual:commands:OnboardingCoach.onDismiss |
| commands:OperationsWorkspace.onAddSecondUnipolarVein | B2 | 未实现；待逐项核实/映射 | src/components/OperationsWorkspace.tsx:163 | 尚未确认 | rule:commands:OperationsWorkspace.onAddSecondUnipolarVein / manual:commands:OperationsWorkspace.onAddSecondUnipolarVein |
| commands:OperationsWorkspace.onAlertSelect | B2 | 未实现；待逐项核实/映射 | src/components/OperationsWorkspace.tsx:150 | 尚未确认 | rule:commands:OperationsWorkspace.onAlertSelect / manual:commands:OperationsWorkspace.onAlertSelect |
| commands:OperationsWorkspace.onAllowEditsDuringSaveChange | B5 | 未实现；待逐项核实/映射 | src/components/OperationsWorkspace.tsx:115 | 尚未确认 | rule:commands:OperationsWorkspace.onAllowEditsDuringSaveChange / manual:commands:OperationsWorkspace.onAllowEditsDuringSaveChange |
| commands:OperationsWorkspace.onBlueprintAllowOverlapChange | B2 | 未实现；待逐项核实/映射 | src/components/OperationsWorkspace.tsx:117 | 尚未确认 | rule:commands:OperationsWorkspace.onBlueprintAllowOverlapChange / manual:commands:OperationsWorkspace.onBlueprintAllowOverlapChange |
| commands:OperationsWorkspace.onCancelImport | B2 | 未实现；待逐项核实/映射 | src/components/OperationsWorkspace.tsx:158 | 尚未确认 | rule:commands:OperationsWorkspace.onCancelImport / manual:commands:OperationsWorkspace.onCancelImport |
| commands:OperationsWorkspace.onCanvasDetailPreferenceChange | B2 | 未实现；待逐项核实/映射 | src/components/OperationsWorkspace.tsx:125 | 尚未确认 | rule:commands:OperationsWorkspace.onCanvasDetailPreferenceChange / manual:commands:OperationsWorkspace.onCanvasDetailPreferenceChange |
| commands:OperationsWorkspace.onCanvasInteractionDetailPreferenceChange | B2 | 未实现；待逐项核实/映射 | src/components/OperationsWorkspace.tsx:127 | 尚未确认 | rule:commands:OperationsWorkspace.onCanvasInteractionDetailPreferenceChange / manual:commands:OperationsWorkspace.onCanvasInteractionDetailPreferenceChange |
| commands:OperationsWorkspace.onCanvasOverlapPreferenceChange | B2 | 未实现；待逐项核实/映射 | src/components/OperationsWorkspace.tsx:126 | 尚未确认 | rule:commands:OperationsWorkspace.onCanvasOverlapPreferenceChange / manual:commands:OperationsWorkspace.onCanvasOverlapPreferenceChange |
| commands:OperationsWorkspace.onCanvasPerformanceFeatureChange | B2 | 未实现；待逐项核实/映射 | src/components/OperationsWorkspace.tsx:129 | 尚未确认 | rule:commands:OperationsWorkspace.onCanvasPerformanceFeatureChange / manual:commands:OperationsWorkspace.onCanvasPerformanceFeatureChange |
| commands:OperationsWorkspace.onChange | B2 | 未实现；待逐项核实/映射 | src/components/OperationsWorkspace.tsx:270 | 尚未确认 | rule:commands:OperationsWorkspace.onChange / manual:commands:OperationsWorkspace.onChange |
| commands:OperationsWorkspace.onClear | B2 | 未实现；待逐项核实/映射 | src/components/OperationsWorkspace.tsx:797 | 尚未确认 | rule:commands:OperationsWorkspace.onClear / manual:commands:OperationsWorkspace.onClear |
| commands:OperationsWorkspace.onClearPerformanceMonitor | B2 | 未实现；待逐项核实/映射 | src/components/OperationsWorkspace.tsx:146 | 尚未确认 | rule:commands:OperationsWorkspace.onClearPerformanceMonitor / manual:commands:OperationsWorkspace.onClearPerformanceMonitor |
| commands:OperationsWorkspace.onClose | B2 | 未实现；待逐项核实/映射 | src/components/OperationsWorkspace.tsx:148 | 尚未确认 | rule:commands:OperationsWorkspace.onClose / manual:commands:OperationsWorkspace.onClose |
| commands:OperationsWorkspace.onConfirmImport | B2 | 未实现；待逐项核实/映射 | src/components/OperationsWorkspace.tsx:155 | 尚未确认 | rule:commands:OperationsWorkspace.onConfirmImport / manual:commands:OperationsWorkspace.onConfirmImport |
| commands:OperationsWorkspace.onConfirmImportRescue | B2 | 未实现；待逐项核实/映射 | src/components/OperationsWorkspace.tsx:156 | 尚未确认 | rule:commands:OperationsWorkspace.onConfirmImportRescue / manual:commands:OperationsWorkspace.onConfirmImportRescue |
| commands:OperationsWorkspace.onConnectExpandAllChange | B2 | 未实现；待逐项核实/映射 | src/components/OperationsWorkspace.tsx:106 | 尚未确认 | rule:commands:OperationsWorkspace.onConnectExpandAllChange / manual:commands:OperationsWorkspace.onConnectExpandAllChange |
| commands:OperationsWorkspace.onConnectionHitAreaChange | B2 | 未实现；待逐项核实/映射 | src/components/OperationsWorkspace.tsx:138 | 尚未确认 | rule:commands:OperationsWorkspace.onConnectionHitAreaChange / manual:commands:OperationsWorkspace.onConnectionHitAreaChange |
| commands:OperationsWorkspace.onConnectionPointSizeChange | B2 | 未实现；待逐项核实/映射 | src/components/OperationsWorkspace.tsx:137 | 尚未确认 | rule:commands:OperationsWorkspace.onConnectionPointSizeChange / manual:commands:OperationsWorkspace.onConnectionPointSizeChange |
| commands:OperationsWorkspace.onCreateSnapshot | B5 | 实现中；候选待源行为比较 | src/components/OperationsWorkspace.tsx:162 | autoload/GameManager.gd::create_recovery_snapshot | rule:commands:OperationsWorkspace.onCreateSnapshot / manual:commands:OperationsWorkspace.onCreateSnapshot |
| commands:OperationsWorkspace.onDefaultBeltLanesChange | B2 | 未实现；待逐项核实/映射 | src/components/OperationsWorkspace.tsx:139 | 尚未确认 | rule:commands:OperationsWorkspace.onDefaultBeltLanesChange / manual:commands:OperationsWorkspace.onDefaultBeltLanesChange |
| commands:OperationsWorkspace.onDeleteSlot | B2 | 未实现；待逐项核实/映射 | src/components/OperationsWorkspace.tsx:161 | 尚未确认 | rule:commands:OperationsWorkspace.onDeleteSlot / manual:commands:OperationsWorkspace.onDeleteSlot |
| commands:OperationsWorkspace.onDeleteSnapshot | B5 | 实现中；候选待源行为比较 | src/components/OperationsWorkspace.tsx:166 | scripts/game/SaveSystem.gd::delete_snapshots | rule:commands:OperationsWorkspace.onDeleteSnapshot / manual:commands:OperationsWorkspace.onDeleteSnapshot |
| commands:OperationsWorkspace.onDeleteSnapshots | B5 | 实现中；候选待源行为比较 | src/components/OperationsWorkspace.tsx:167 | scripts/game/SaveSystem.gd::delete_snapshots | rule:commands:OperationsWorkspace.onDeleteSnapshots / manual:commands:OperationsWorkspace.onDeleteSnapshots |
| commands:OperationsWorkspace.onEndgameExtremeModeChange | B2 | 实现中；候选待源行为比较 | src/components/OperationsWorkspace.tsx:104 | autoload/GameManager.gd::configure_pure_idle | rule:commands:OperationsWorkspace.onEndgameExtremeModeChange / manual:commands:OperationsWorkspace.onEndgameExtremeModeChange |
| commands:OperationsWorkspace.onExport | B2 | 未实现；待逐项核实/映射 | src/components/OperationsWorkspace.tsx:153 | 尚未确认 | rule:commands:OperationsWorkspace.onExport / manual:commands:OperationsWorkspace.onExport |
| commands:OperationsWorkspace.onExportModTemplate | B2 | 实现中；候选待源行为比较 | src/components/OperationsWorkspace.tsx:172 | scenes/ui/ContentPackWorkspace.gd::show_template | rule:commands:OperationsWorkspace.onExportModTemplate / manual:commands:OperationsWorkspace.onExportModTemplate |
| commands:OperationsWorkspace.onExportPerformanceMonitor | B2 | 未实现；待逐项核实/映射 | src/components/OperationsWorkspace.tsx:147 | 尚未确认 | rule:commands:OperationsWorkspace.onExportPerformanceMonitor / manual:commands:OperationsWorkspace.onExportPerformanceMonitor |
| commands:OperationsWorkspace.onExportTemplate | B2 | 实现中；候选待源行为比较 | src/components/OperationsWorkspace.tsx:1062 | scenes/ui/ContentPackWorkspace.gd::show_template | rule:commands:OperationsWorkspace.onExportTemplate / manual:commands:OperationsWorkspace.onExportTemplate |
| commands:OperationsWorkspace.onFactoryAlertsEnabledChange | B2 | 未实现；待逐项核实/映射 | src/components/OperationsWorkspace.tsx:110 | 尚未确认 | rule:commands:OperationsWorkspace.onFactoryAlertsEnabledChange / manual:commands:OperationsWorkspace.onFactoryAlertsEnabledChange |
| commands:OperationsWorkspace.onFullRealtimeSimulationChange | B5 | 实现中；候选待源行为比较 | src/components/OperationsWorkspace.tsx:108 | autoload/GameManager.gd::configure_pure_idle | rule:commands:OperationsWorkspace.onFullRealtimeSimulationChange / manual:commands:OperationsWorkspace.onFullRealtimeSimulationChange |
| commands:OperationsWorkspace.onImport | B2 | 未实现；待逐项核实/映射 | src/components/OperationsWorkspace.tsx:154 | 尚未确认 | rule:commands:OperationsWorkspace.onImport / manual:commands:OperationsWorkspace.onImport |
| commands:OperationsWorkspace.onItemHoverChange | B2 | 未实现；待逐项核实/映射 | src/components/OperationsWorkspace.tsx:141 | 尚未确认 | rule:commands:OperationsWorkspace.onItemHoverChange / manual:commands:OperationsWorkspace.onItemHoverChange |
| commands:OperationsWorkspace.onLargeSaveAutosaveProtectionChange | B5 | 未实现；待逐项核实/映射 | src/components/OperationsWorkspace.tsx:113 | 尚未确认 | rule:commands:OperationsWorkspace.onLargeSaveAutosaveProtectionChange / manual:commands:OperationsWorkspace.onLargeSaveAutosaveProtectionChange |
| commands:OperationsWorkspace.onLineFindModeChange | B2 | 未实现；待逐项核实/映射 | src/components/OperationsWorkspace.tsx:136 | 尚未确认 | rule:commands:OperationsWorkspace.onLineFindModeChange / manual:commands:OperationsWorkspace.onLineFindModeChange |
| commands:OperationsWorkspace.onLoadSlot | B2 | 未实现；待逐项核实/映射 | src/components/OperationsWorkspace.tsx:160 | 尚未确认 | rule:commands:OperationsWorkspace.onLoadSlot / manual:commands:OperationsWorkspace.onLoadSlot |
| commands:OperationsWorkspace.onLoadSnapshot | B5 | 实现中；候选待源行为比较 | src/components/OperationsWorkspace.tsx:165 | autoload/GameManager.gd::recover_game | rule:commands:OperationsWorkspace.onLoadSnapshot / manual:commands:OperationsWorkspace.onLoadSnapshot |
| commands:OperationsWorkspace.onManualSave | B5 | 实现中；候选待源行为比较 | src/components/OperationsWorkspace.tsx:152 | autoload/GameManager.gd::save_current_game | rule:commands:OperationsWorkspace.onManualSave / manual:commands:OperationsWorkspace.onManualSave |
| commands:OperationsWorkspace.onOpenReleaseNotes | B2 | 未实现；待逐项核实/映射 | src/components/OperationsWorkspace.tsx:169 | 尚未确认 | rule:commands:OperationsWorkspace.onOpenReleaseNotes / manual:commands:OperationsWorkspace.onOpenReleaseNotes |
| commands:OperationsWorkspace.onOpenTutorial | B2 | 未实现；待逐项核实/映射 | src/components/OperationsWorkspace.tsx:170 | 尚未确认 | rule:commands:OperationsWorkspace.onOpenTutorial / manual:commands:OperationsWorkspace.onOpenTutorial |
| commands:OperationsWorkspace.onProductionRefreshPreferenceChange | B2 | 未实现；待逐项核实/映射 | src/components/OperationsWorkspace.tsx:143 | 尚未确认 | rule:commands:OperationsWorkspace.onProductionRefreshPreferenceChange / manual:commands:OperationsWorkspace.onProductionRefreshPreferenceChange |
| commands:OperationsWorkspace.onRegister | B2 | 实现中；候选待源行为比较 | src/components/OperationsWorkspace.tsx:1063 | scripts/game/ContentPackSystem.gd::register_pack | rule:commands:OperationsWorkspace.onRegister / manual:commands:OperationsWorkspace.onRegister |
| commands:OperationsWorkspace.onRegisterContentPack | B5 | 实现中；候选待源行为比较 | src/components/OperationsWorkspace.tsx:173 | scripts/game/ContentPackSystem.gd::register_pack | rule:commands:OperationsWorkspace.onRegisterContentPack / manual:commands:OperationsWorkspace.onRegisterContentPack |
| commands:OperationsWorkspace.onRemove | B2 | 未实现；待逐项核实/映射 | src/components/OperationsWorkspace.tsx:1065 | 尚未确认 | rule:commands:OperationsWorkspace.onRemove / manual:commands:OperationsWorkspace.onRemove |
| commands:OperationsWorkspace.onRemoveContentPack | B5 | 实现中；候选待源行为比较 | src/components/OperationsWorkspace.tsx:175 | scripts/game/ContentPackSystem.gd::remove_pack | rule:commands:OperationsWorkspace.onRemoveContentPack / manual:commands:OperationsWorkspace.onRemoveContentPack |
| commands:OperationsWorkspace.onRunBenchmark | B2 | 未实现；待逐项核实/映射 | src/components/OperationsWorkspace.tsx:168 | 尚未确认 | rule:commands:OperationsWorkspace.onRunBenchmark / manual:commands:OperationsWorkspace.onRunBenchmark |
| commands:OperationsWorkspace.onRunLogChange | B2 | 未实现；待逐项核实/映射 | src/components/OperationsWorkspace.tsx:140 | 尚未确认 | rule:commands:OperationsWorkspace.onRunLogChange / manual:commands:OperationsWorkspace.onRunLogChange |
| commands:OperationsWorkspace.onSaveSlot | B5 | 实现中；候选待源行为比较 | src/components/OperationsWorkspace.tsx:159 | autoload/GameManager.gd::save_current_game | rule:commands:OperationsWorkspace.onSaveSlot / manual:commands:OperationsWorkspace.onSaveSlot |
| commands:OperationsWorkspace.onSelect | B2 | 未实现；待逐项核实/映射 | src/components/OperationsWorkspace.tsx:198 | 尚未确认 | rule:commands:OperationsWorkspace.onSelect / manual:commands:OperationsWorkspace.onSelect |
| commands:OperationsWorkspace.onSetContentPackEnabled | B5 | 实现中；候选待源行为比较 | src/components/OperationsWorkspace.tsx:174 | scripts/game/ContentPackSystem.gd::set_enabled | rule:commands:OperationsWorkspace.onSetContentPackEnabled / manual:commands:OperationsWorkspace.onSetContentPackEnabled |
| commands:OperationsWorkspace.onSetEnabled | B2 | 未实现；待逐项核实/映射 | src/components/OperationsWorkspace.tsx:1064 | 尚未确认 | rule:commands:OperationsWorkspace.onSetEnabled / manual:commands:OperationsWorkspace.onSetEnabled |
| commands:OperationsWorkspace.onSettingsChange | B5 | 未实现；待逐项核实/映射 | src/components/OperationsWorkspace.tsx:151 | 尚未确认 | rule:commands:OperationsWorkspace.onSettingsChange / manual:commands:OperationsWorkspace.onSettingsChange |
| commands:OperationsWorkspace.onStart | B2 | 未实现；待逐项核实/映射 | src/components/OperationsWorkspace.tsx:795 | 尚未确认 | rule:commands:OperationsWorkspace.onStart / manual:commands:OperationsWorkspace.onStart |
| commands:OperationsWorkspace.onStartPerformanceMonitor | B2 | 未实现；待逐项核实/映射 | src/components/OperationsWorkspace.tsx:144 | 尚未确认 | rule:commands:OperationsWorkspace.onStartPerformanceMonitor / manual:commands:OperationsWorkspace.onStartPerformanceMonitor |
| commands:OperationsWorkspace.onStop | B2 | 未实现；待逐项核实/映射 | src/components/OperationsWorkspace.tsx:796 | 尚未确认 | rule:commands:OperationsWorkspace.onStop / manual:commands:OperationsWorkspace.onStop |
| commands:OperationsWorkspace.onStopPerformanceMonitor | B2 | 未实现；待逐项核实/映射 | src/components/OperationsWorkspace.tsx:145 | 尚未确认 | rule:commands:OperationsWorkspace.onStopPerformanceMonitor / manual:commands:OperationsWorkspace.onStopPerformanceMonitor |
| commands:OperationsWorkspace.onTabChange | B2 | 未实现；待逐项核实/映射 | src/components/OperationsWorkspace.tsx:149 | 尚未确认 | rule:commands:OperationsWorkspace.onTabChange / manual:commands:OperationsWorkspace.onTabChange |
| commands:OperationsWorkspace.onValidate | B2 | 未实现；待逐项核实/映射 | src/components/OperationsWorkspace.tsx:1061 | 尚未确认 | rule:commands:OperationsWorkspace.onValidate / manual:commands:OperationsWorkspace.onValidate |
| commands:OperationsWorkspace.onValidateMod | B2 | 实现中；候选待源行为比较 | src/components/OperationsWorkspace.tsx:171 | scripts/game/ContentPackSystem.gd::validate_manifest | rule:commands:OperationsWorkspace.onValidateMod / manual:commands:OperationsWorkspace.onValidateMod |
| commands:OrbitalStationWorkspace.onClose | B3 | 实现中；候选待源行为比较 | src/components/OrbitalStationWorkspace.tsx:88 | scenes/ui/LocalSpaceStationWorkspace.gd | rule:commands:OrbitalStationWorkspace.onClose / manual:commands:OrbitalStationWorkspace.onClose |
| commands:OrbitalStationWorkspace.onGameChange | B3 | 实现中；候选待源行为比较 | src/components/OrbitalStationWorkspace.tsx:87 | scenes/ui/LocalSpaceStationWorkspace.gd | rule:commands:OrbitalStationWorkspace.onGameChange / manual:commands:OrbitalStationWorkspace.onGameChange |
| commands:palette.entity:{entity_id} | B2 | 实现中；候选待源行为比较 | src/components/CommandPalette.tsx:1 | scenes/ui/FactoryWorkspaceUI.gd::_locate_entity | rule:commands:palette.entity:{entity_id} / manual:commands:palette.entity:{entity_id} |
| commands:palette.recipe:{item_id} | B2 | 未实现；待逐项核实/映射 | src/components/CommandPalette.tsx:1 | 尚未确认 | rule:commands:palette.recipe:{item_id} / manual:commands:palette.recipe:{item_id} |
| commands:ProductionManagement.onBulkRecipeChange | B2 | 未实现；待逐项核实/映射 | src/components/ProductionManagement.tsx:66 | 尚未确认 | rule:commands:ProductionManagement.onBulkRecipeChange / manual:commands:ProductionManagement.onBulkRecipeChange |
| commands:ProductionManagement.onBulkStationSlotApply | B3 | 实现中；候选待源行为比较 | src/components/ProductionManagement.tsx:67 | scripts/game/StationSystem.gd::configure_slots | rule:commands:ProductionManagement.onBulkStationSlotApply / manual:commands:ProductionManagement.onBulkStationSlotApply |
| commands:ProductionManagement.onCreatePlan | B2 | 未实现；待逐项核实/映射 | src/components/ProductionManagement.tsx:68 | 尚未确认 | rule:commands:ProductionManagement.onCreatePlan / manual:commands:ProductionManagement.onCreatePlan |
| commands:ProductionManagement.onFocusBelt | B2 | 未实现；待逐项核实/映射 | src/components/ProductionManagement.tsx:65 | 尚未确认 | rule:commands:ProductionManagement.onFocusBelt / manual:commands:ProductionManagement.onFocusBelt |
| commands:ProductionManagement.onFocusEntity | B2 | 未实现；待逐项核实/映射 | src/components/ProductionManagement.tsx:64 | 尚未确认 | rule:commands:ProductionManagement.onFocusEntity / manual:commands:ProductionManagement.onFocusEntity |
| commands:QuantityStepper.onChange | B2 | 未实现；待逐项核实/映射 | src/components/QuantityStepper.tsx:17 | 尚未确认 | rule:commands:QuantityStepper.onChange / manual:commands:QuantityStepper.onChange |
| commands:QuantityStepper.onMax | B2 | 未实现；待逐项核实/映射 | src/components/QuantityStepper.tsx:18 | 尚未确认 | rule:commands:QuantityStepper.onMax / manual:commands:QuantityStepper.onMax |
| commands:RecipeFocusPanel.onClear | B2 | 未实现；待逐项核实/映射 | src/components/RecipeFocusPanel.tsx:69 | 尚未确认 | rule:commands:RecipeFocusPanel.onClear / manual:commands:RecipeFocusPanel.onClear |
| commands:RecipeFocusPanel.onModeChange | B2 | 未实现；待逐项核实/映射 | src/components/RecipeFocusPanel.tsx:70 | 尚未确认 | rule:commands:RecipeFocusPanel.onModeChange / manual:commands:RecipeFocusPanel.onModeChange |
| commands:RecipeFocusPanel.onOpen | B2 | 未实现；待逐项核实/映射 | src/components/RecipeFocusPanel.tsx:8 | 尚未确认 | rule:commands:RecipeFocusPanel.onOpen / manual:commands:RecipeFocusPanel.onOpen |
| commands:RecipeFocusPanel.onPositionChange | B2 | 未实现；待逐项核实/映射 | src/components/RecipeFocusPanel.tsx:72 | 尚未确认 | rule:commands:RecipeFocusPanel.onPositionChange / manual:commands:RecipeFocusPanel.onPositionChange |
| commands:RecipeWorkspace.onClose | B2 | 未实现；待逐项核实/映射 | src/components/RecipeWorkspace.tsx:123 | 尚未确认 | rule:commands:RecipeWorkspace.onClose / manual:commands:RecipeWorkspace.onClose |
| commands:RecipeWorkspace.onFocus | B2 | 未实现；待逐项核实/映射 | src/components/RecipeWorkspace.tsx:125 | 尚未确认 | rule:commands:RecipeWorkspace.onFocus / manual:commands:RecipeWorkspace.onFocus |
| commands:RecipeWorkspace.onLocateProductionLine | B2 | 未实现；待逐项核实/映射 | src/components/RecipeWorkspace.tsx:126 | 尚未确认 | rule:commands:RecipeWorkspace.onLocateProductionLine / manual:commands:RecipeWorkspace.onLocateProductionLine |
| commands:RecipeWorkspace.onSelect | B2 | 未实现；待逐项核实/映射 | src/components/RecipeWorkspace.tsx:59 | 尚未确认 | rule:commands:RecipeWorkspace.onSelect / manual:commands:RecipeWorkspace.onSelect |
| commands:RecipeWorkspace.onSelectBuilding | B2 | 未实现；待逐项核实/映射 | src/components/RecipeWorkspace.tsx:75 | 尚未确认 | rule:commands:RecipeWorkspace.onSelectBuilding / manual:commands:RecipeWorkspace.onSelectBuilding |
| commands:RecipeWorkspace.onSelectTechnology | B2 | 未实现；待逐项核实/映射 | src/components/RecipeWorkspace.tsx:76 | 尚未确认 | rule:commands:RecipeWorkspace.onSelectTechnology / manual:commands:RecipeWorkspace.onSelectTechnology |
| commands:ReleaseNotesDialog.onClose | B2 | 未实现；待逐项核实/映射 | src/components/ReleaseNotesDialog.tsx:520 | 尚未确认 | rule:commands:ReleaseNotesDialog.onClose / manual:commands:ReleaseNotesDialog.onClose |
| commands:SaveDeleteDialog.onCancel | B5 | 实现中；候选待源行为比较 | src/components/SaveDeleteDialog.tsx:13 | scenes/ui/SaveSlotsPanel.gd::_request_delete | rule:commands:SaveDeleteDialog.onCancel / manual:commands:SaveDeleteDialog.onCancel |
| commands:SaveDeleteDialog.onDelete | B5 | 实现中；候选待源行为比较 | src/components/SaveDeleteDialog.tsx:14 | scenes/ui/AppShell.gd::_delete_slot | rule:commands:SaveDeleteDialog.onDelete / manual:commands:SaveDeleteDialog.onDelete |
| commands:SpeedrunCopyDialog.onCancel | B5 | 实现中；候选待源行为比较 | src/components/SpeedrunCopyDialog.tsx:16 | scenes/ui/SaveSlotsPanel.gd::_create_ui | rule:commands:SpeedrunCopyDialog.onCancel / manual:commands:SpeedrunCopyDialog.onCancel |
| commands:SpeedrunCopyDialog.onCopy | B5 | 实现中；候选待源行为比较 | src/components/SpeedrunCopyDialog.tsx:17 | scripts/game/SaveSystem.gd::copy_speedrun_to_normal | rule:commands:SpeedrunCopyDialog.onCopy / manual:commands:SpeedrunCopyDialog.onCopy |
| commands:StableTextInput.onValueChange | B2 | 未实现；待逐项核实/映射 | src/components/StableTextInput.tsx:27 | 尚未确认 | rule:commands:StableTextInput.onValueChange / manual:commands:StableTextInput.onValueChange |
| commands:StarMapWorkspace.onChange | B3 | 实现中；候选待源行为比较 | src/components/StarMapWorkspace.tsx:241 | scenes/ui/GalaxyMap.gd | rule:commands:StarMapWorkspace.onChange / manual:commands:StarMapWorkspace.onChange |
| commands:StarMapWorkspace.onClose | B3 | 实现中；候选待源行为比较 | src/components/StarMapWorkspace.tsx:366 | scenes/ui/GalaxyMap.gd | rule:commands:StarMapWorkspace.onClose / manual:commands:StarMapWorkspace.onClose |
| commands:StarMapWorkspace.onCollectorModeChange | B3 | 实现中；候选待源行为比较 | src/components/StarMapWorkspace.tsx:289 | scripts/game/QuantumLogisticsSystem.gd::set_collector_mode | rule:commands:StarMapWorkspace.onCollectorModeChange / manual:commands:StarMapWorkspace.onCollectorModeChange |
| commands:StarMapWorkspace.onColonize | B3 | 实现中；候选待源行为比较 | src/components/StarMapWorkspace.tsx:368 | scripts/game/PlanetSystem.gd::try_colonize_planet | rule:commands:StarMapWorkspace.onColonize / manual:commands:StarMapWorkspace.onColonize |
| commands:StarMapWorkspace.onExplore | B3 | 实现中；候选待源行为比较 | src/components/StarMapWorkspace.tsx:367 | scripts/game/GalaxySystem.gd::try_explore_system | rule:commands:StarMapWorkspace.onExplore / manual:commands:StarMapWorkspace.onExplore |
| commands:StarMapWorkspace.onFocusStation | B3 | 实现中；候选待源行为比较 | src/components/StarMapWorkspace.tsx:112 | scenes/ui/StationPanel.gd | rule:commands:StarMapWorkspace.onFocusStation / manual:commands:StarMapWorkspace.onFocusStation |
| commands:StarMapWorkspace.onItemCapacityChange | B3 | 实现中；候选待源行为比较 | src/components/StarMapWorkspace.tsx:290 | scripts/game/PlanetTraySystem.gd::set_limit | rule:commands:StarMapWorkspace.onItemCapacityChange / manual:commands:StarMapWorkspace.onItemCapacityChange |
| commands:StarMapWorkspace.onPlanetMetadataChange | B3 | 实现中；候选待源行为比较 | src/components/StarMapWorkspace.tsx:57 | scripts/game/SourceGalaxySystem.gd::set_metadata | rule:commands:StarMapWorkspace.onPlanetMetadataChange / manual:commands:StarMapWorkspace.onPlanetMetadataChange |
| commands:StarMapWorkspace.onQuantumItemCapacityChange | B3 | 实现中；候选待源行为比较 | src/components/StarMapWorkspace.tsx:380 | scripts/game/QuantumLogisticsSystem.gd::set_item_capacity | rule:commands:StarMapWorkspace.onQuantumItemCapacityChange / manual:commands:StarMapWorkspace.onQuantumItemCapacityChange |
| commands:StarMapWorkspace.onRoleChange | B3 | 实现中；候选待源行为比较 | src/components/StarMapWorkspace.tsx:108 | scripts/game/SourceGalaxySystem.gd::set_role | rule:commands:StarMapWorkspace.onRoleChange / manual:commands:StarMapWorkspace.onRoleChange |
| commands:StarMapWorkspace.onStationLimitsChange | B3 | 实现中；候选待源行为比较 | src/components/StarMapWorkspace.tsx:111 | scripts/game/StationSystem.gd::set_slot_limits | rule:commands:StarMapWorkspace.onStationLimitsChange / manual:commands:StarMapWorkspace.onStationLimitsChange |
| commands:StarMapWorkspace.onStationMinimumLoadChange | B3 | 实现中；候选待源行为比较 | src/components/StarMapWorkspace.tsx:110 | scripts/game/StationSystem.gd::configure_slots | rule:commands:StarMapWorkspace.onStationMinimumLoadChange / manual:commands:StarMapWorkspace.onStationMinimumLoadChange |
| commands:StarMapWorkspace.onStationPriorityChange | B3 | 实现中；候选待源行为比较 | src/components/StarMapWorkspace.tsx:109 | scripts/game/StationSystem.gd::configure_slots | rule:commands:StarMapWorkspace.onStationPriorityChange / manual:commands:StarMapWorkspace.onStationPriorityChange |
| commands:StarMapWorkspace.onSystemNameChange | B3 | 实现中；候选待源行为比较 | src/components/StarMapWorkspace.tsx:58 | scripts/game/SourceGalaxySystem.gd::set_metadata | rule:commands:StarMapWorkspace.onSystemNameChange / manual:commands:StarMapWorkspace.onSystemNameChange |
| commands:StarMapWorkspace.onTravel | B3 | 实现中；候选待源行为比较 | src/components/StarMapWorkspace.tsx:107 | scripts/game/PlanetSystem.gd::try_set_active_planet | rule:commands:StarMapWorkspace.onTravel / manual:commands:StarMapWorkspace.onTravel |
| commands:StartMenu.onChange | B5 | 未实现；待逐项核实/映射 | src/components/StartMenu.tsx:314 | 尚未确认 | rule:commands:StartMenu.onChange / manual:commands:StartMenu.onChange |
| commands:StartMenu.onComplexity | B5 | 未实现；待逐项核实/映射 | src/components/StartMenu.tsx:628 | 尚未确认 | rule:commands:StartMenu.onComplexity / manual:commands:StartMenu.onComplexity |
| commands:StartMenu.onDiagnostics | B5 | 未实现；待逐项核实/映射 | src/components/StartMenu.tsx:1278 | 尚未确认 | rule:commands:StartMenu.onDiagnostics / manual:commands:StartMenu.onDiagnostics |
| commands:StartMenu.onEnterGame | B5 | 未实现；待逐项核实/映射 | src/components/StartMenu.tsx:228 | 尚未确认 | rule:commands:StartMenu.onEnterGame / manual:commands:StartMenu.onEnterGame |
| commands:StartMenu.onOpenReleaseNotes | B5 | 未实现；待逐项核实/映射 | src/components/StartMenu.tsx:229 | 尚未确认 | rule:commands:StartMenu.onOpenReleaseNotes / manual:commands:StartMenu.onOpenReleaseNotes |
| commands:StartMenu.onProgress | B5 | 未实现；待逐项核实/映射 | src/components/StartMenu.tsx:640 | 尚未确认 | rule:commands:StartMenu.onProgress / manual:commands:StartMenu.onProgress |
| commands:StartMenu.onStage | B5 | 未实现；待逐项核实/映射 | src/components/StartMenu.tsx:1268 | 尚未确认 | rule:commands:StartMenu.onStage / manual:commands:StartMenu.onStage |
| commands:StationCanvasRenderer.onMovePlacement | B3 | 实现中；候选待源行为比较 | src/components/StationCanvasRenderer.tsx:30 | scripts/game/StationPresentationSystem.gd::update_placement | rule:commands:StationCanvasRenderer.onMovePlacement / manual:commands:StationCanvasRenderer.onMovePlacement |
| commands:StationCanvasRenderer.onSelectPlacement | B3 | 实现中；候选待源行为比较 | src/components/StationCanvasRenderer.tsx:29 | scenes/ui/StationPresentationPanel.gd::load_placement | rule:commands:StationCanvasRenderer.onSelectPlacement / manual:commands:StationCanvasRenderer.onSelectPlacement |
| commands:StationCanvasRenderer.onViewportChange | B3 | 实现中；候选待源行为比较 | src/components/StationCanvasRenderer.tsx:31 | scripts/game/StationPresentationSystem.gd::set_viewport | rule:commands:StationCanvasRenderer.onViewportChange / manual:commands:StationCanvasRenderer.onViewportChange |
| commands:StatisticsWorkspace.onAddCanvasBookmark | B2 | 实现中；候选待源行为比较 | src/components/StatisticsWorkspace.tsx:75 | scenes/ui/CanvasNavigationControls.gd::_bookmark | rule:commands:StatisticsWorkspace.onAddCanvasBookmark / manual:commands:StatisticsWorkspace.onAddCanvasBookmark |
| commands:StatisticsWorkspace.onBeltHeatmapChange | B2 | 未实现；待逐项核实/映射 | src/components/StatisticsWorkspace.tsx:74 | 尚未确认 | rule:commands:StatisticsWorkspace.onBeltHeatmapChange / manual:commands:StatisticsWorkspace.onBeltHeatmapChange |
| commands:StatisticsWorkspace.onBulkBeltConfiguration | B2 | 未实现；待逐项核实/映射 | src/components/StatisticsWorkspace.tsx:67 | 尚未确认 | rule:commands:StatisticsWorkspace.onBulkBeltConfiguration / manual:commands:StatisticsWorkspace.onBulkBeltConfiguration |
| commands:StatisticsWorkspace.onBulkBeltRemove | B2 | 未实现；待逐项核实/映射 | src/components/StatisticsWorkspace.tsx:73 | 尚未确认 | rule:commands:StatisticsWorkspace.onBulkBeltRemove / manual:commands:StatisticsWorkspace.onBulkBeltRemove |
| commands:StatisticsWorkspace.onBulkBeltRoute | B2 | 未实现；待逐项核实/映射 | src/components/StatisticsWorkspace.tsx:66 | 尚未确认 | rule:commands:StatisticsWorkspace.onBulkBeltRoute / manual:commands:StatisticsWorkspace.onBulkBeltRoute |
| commands:StatisticsWorkspace.onBulkBeltUpgrade | B2 | 未实现；待逐项核实/映射 | src/components/StatisticsWorkspace.tsx:65 | 尚未确认 | rule:commands:StatisticsWorkspace.onBulkBeltUpgrade / manual:commands:StatisticsWorkspace.onBulkBeltUpgrade |
| commands:StatisticsWorkspace.onBulkRecipeChange | B2 | 未实现；待逐项核实/映射 | src/components/StatisticsWorkspace.tsx:63 | 尚未确认 | rule:commands:StatisticsWorkspace.onBulkRecipeChange / manual:commands:StatisticsWorkspace.onBulkRecipeChange |
| commands:StatisticsWorkspace.onBulkStationSlotApply | B3 | 实现中；候选待源行为比较 | src/components/StatisticsWorkspace.tsx:64 | scripts/game/StationSystem.gd::configure_slots | rule:commands:StatisticsWorkspace.onBulkStationSlotApply / manual:commands:StatisticsWorkspace.onBulkStationSlotApply |
| commands:StatisticsWorkspace.onClose | B2 | 未实现；待逐项核实/映射 | src/components/StatisticsWorkspace.tsx:48 | 尚未确认 | rule:commands:StatisticsWorkspace.onClose / manual:commands:StatisticsWorkspace.onClose |
| commands:StatisticsWorkspace.onCreatePlan | — | 已验证；当前行为证据已绑定 | src/components/StatisticsWorkspace.tsx:49 | scripts/game/ProductionPlanningSystem.gd::create_plan | rule:commands:StatisticsWorkspace.onCreatePlan / manual:commands:StatisticsWorkspace.onCreatePlan |
| commands:StatisticsWorkspace.onDispatchGalacticExport | B4 | 实现中；候选待源行为比较 | src/components/StatisticsWorkspace.tsx:60 | scripts/game/GalacticExportSystem.gd::dispatch | rule:commands:StatisticsWorkspace.onDispatchGalacticExport / manual:commands:StatisticsWorkspace.onDispatchGalacticExport |
| commands:StatisticsWorkspace.onFocusBeltNetwork | B2 | 未实现；待逐项核实/映射 | src/components/StatisticsWorkspace.tsx:62 | 尚未确认 | rule:commands:StatisticsWorkspace.onFocusBeltNetwork / manual:commands:StatisticsWorkspace.onFocusBeltNetwork |
| commands:StatisticsWorkspace.onFocusEntity | B2 | 未实现；待逐项核实/映射 | src/components/StatisticsWorkspace.tsx:61 | 尚未确认 | rule:commands:StatisticsWorkspace.onFocusEntity / manual:commands:StatisticsWorkspace.onFocusEntity |
| commands:StatisticsWorkspace.onGalacticDispatchAutomation | B4 | 实现中；候选待源行为比较 | src/components/StatisticsWorkspace.tsx:55 | scripts/game/GalacticExportSystem.gd::set_automation | rule:commands:StatisticsWorkspace.onGalacticDispatchAutomation / manual:commands:StatisticsWorkspace.onGalacticDispatchAutomation |
| commands:StatisticsWorkspace.onGalacticDispatchThrottle | B4 | 实现中；候选待源行为比较 | src/components/StatisticsWorkspace.tsx:56 | scripts/game/GalacticExportSystem.gd::set_throttle | rule:commands:StatisticsWorkspace.onGalacticDispatchThrottle / manual:commands:StatisticsWorkspace.onGalacticDispatchThrottle |
| commands:StatisticsWorkspace.onGalacticExportEnabled | B4 | 实现中；候选待源行为比较 | src/components/StatisticsWorkspace.tsx:58 | scripts/game/GalacticExportSystem.gd::configure | rule:commands:StatisticsWorkspace.onGalacticExportEnabled / manual:commands:StatisticsWorkspace.onGalacticExportEnabled |
| commands:StatisticsWorkspace.onGalacticExporterPausedChange | — | 在线排除；固定在线白名单 | src/components/StatisticsWorkspace.tsx:57 | 尚未确认 | rule:commands:StatisticsWorkspace.onGalacticExporterPausedChange / manual:commands:StatisticsWorkspace.onGalacticExporterPausedChange |
| commands:StatisticsWorkspace.onGalacticExportPriority | B4 | 实现中；候选待源行为比较 | src/components/StatisticsWorkspace.tsx:59 | scripts/game/GalacticExportSystem.gd::configure | rule:commands:StatisticsWorkspace.onGalacticExportPriority / manual:commands:StatisticsWorkspace.onGalacticExportPriority |
| commands:StatisticsWorkspace.onInfiniteResearchAutomation | B2 | 未实现；待逐项核实/映射 | src/components/StatisticsWorkspace.tsx:54 | 尚未确认 | rule:commands:StatisticsWorkspace.onInfiniteResearchAutomation / manual:commands:StatisticsWorkspace.onInfiniteResearchAutomation |
| commands:StatisticsWorkspace.onOpenCanvasBookmark | B2 | 实现中；候选待源行为比较 | src/components/StatisticsWorkspace.tsx:77 | scenes/ui/CanvasNavigationControls.gd::_navigate | rule:commands:StatisticsWorkspace.onOpenCanvasBookmark / manual:commands:StatisticsWorkspace.onOpenCanvasBookmark |
| commands:StatisticsWorkspace.onRemoveCanvasBookmark | B2 | 未实现；待逐项核实/映射 | src/components/StatisticsWorkspace.tsx:78 | 尚未确认 | rule:commands:StatisticsWorkspace.onRemoveCanvasBookmark / manual:commands:StatisticsWorkspace.onRemoveCanvasBookmark |
| commands:StatisticsWorkspace.onRemovePlan | — | 已验证；当前行为证据已绑定 | src/components/StatisticsWorkspace.tsx:52 | scripts/game/ProductionPlanningSystem.gd::remove_plan | rule:commands:StatisticsWorkspace.onRemovePlan / manual:commands:StatisticsWorkspace.onRemovePlan |
| commands:StatisticsWorkspace.onRenameCanvasBookmark | B2 | 未实现；待逐项核实/映射 | src/components/StatisticsWorkspace.tsx:76 | 尚未确认 | rule:commands:StatisticsWorkspace.onRenameCanvasBookmark / manual:commands:StatisticsWorkspace.onRenameCanvasBookmark |
| commands:StatisticsWorkspace.onSelectInfiniteResearch | B2 | 未实现；待逐项核实/映射 | src/components/StatisticsWorkspace.tsx:53 | 尚未确认 | rule:commands:StatisticsWorkspace.onSelectInfiniteResearch / manual:commands:StatisticsWorkspace.onSelectInfiniteResearch |
| commands:StatisticsWorkspace.onSetPlanRecipe | — | 已验证；当前行为证据已绑定 | src/components/StatisticsWorkspace.tsx:51 | scripts/game/ProductionPlanningSystem.gd::set_recipe | rule:commands:StatisticsWorkspace.onSetPlanRecipe / manual:commands:StatisticsWorkspace.onSetPlanRecipe |
| commands:StatisticsWorkspace.onUpdatePlan | — | 已验证；当前行为证据已绑定 | src/components/StatisticsWorkspace.tsx:50 | scripts/game/ProductionPlanningSystem.gd::update_plan | rule:commands:StatisticsWorkspace.onUpdatePlan / manual:commands:StatisticsWorkspace.onUpdatePlan |
| commands:SystemSpaceStationWorkspace.onClose | B4 | 实现中；候选待源行为比较 | src/components/SystemSpaceStationWorkspace.tsx:24 | scenes/ui/SystemSpaceStationWorkspace.gd | rule:commands:SystemSpaceStationWorkspace.onClose / manual:commands:SystemSpaceStationWorkspace.onClose |
| commands:SystemSpaceStationWorkspace.onDeliverMaterial | B4 | 实现中；候选待源行为比较 | src/components/SystemSpaceStationWorkspace.tsx:26 | scripts/game/SystemSpaceStationSystem.gd::deliver | rule:commands:SystemSpaceStationWorkspace.onDeliverMaterial / manual:commands:SystemSpaceStationWorkspace.onDeliverMaterial |
| commands:SystemSpaceStationWorkspace.onRequestMode | B4 | 实现中；候选待源行为比较 | src/components/SystemSpaceStationWorkspace.tsx:29 | scripts/game/SystemHubLogisticsSystem.gd::request_mode | rule:commands:SystemSpaceStationWorkspace.onRequestMode / manual:commands:SystemSpaceStationWorkspace.onRequestMode |
| commands:SystemSpaceStationWorkspace.onSetModuleCount | B4 | 实现中；候选待源行为比较 | src/components/SystemSpaceStationWorkspace.tsx:31 | scripts/game/SystemSpaceStationSystem.gd::set_module_count | rule:commands:SystemSpaceStationWorkspace.onSetModuleCount / manual:commands:SystemSpaceStationWorkspace.onSetModuleCount |
| commands:SystemSpaceStationWorkspace.onSetOutput | B4 | 实现中；候选待源行为比较 | src/components/SystemSpaceStationWorkspace.tsx:30 | scripts/game/SystemHubLogisticsSystem.gd::set_output | rule:commands:SystemSpaceStationWorkspace.onSetOutput / manual:commands:SystemSpaceStationWorkspace.onSetOutput |
| commands:SystemSpaceStationWorkspace.onStartConstruction | B4 | 实现中；候选待源行为比较 | src/components/SystemSpaceStationWorkspace.tsx:25 | scripts/game/SystemSpaceStationSystem.gd::start | rule:commands:SystemSpaceStationWorkspace.onStartConstruction / manual:commands:SystemSpaceStationWorkspace.onStartConstruction |
| commands:SystemSpaceStationWorkspace.onUpgradeAllStations | B4 | 实现中；候选待源行为比较 | src/components/SystemSpaceStationWorkspace.tsx:28 | scripts/game/QuantumLogisticsSystem.gd::upgrade_all | rule:commands:SystemSpaceStationWorkspace.onUpgradeAllStations / manual:commands:SystemSpaceStationWorkspace.onUpgradeAllStations |
| commands:SystemSpaceStationWorkspace.onUpgradeStation | B4 | 实现中；候选待源行为比较 | src/components/SystemSpaceStationWorkspace.tsx:27 | scripts/game/QuantumLogisticsSystem.gd::upgrade_station | rule:commands:SystemSpaceStationWorkspace.onUpgradeStation / manual:commands:SystemSpaceStationWorkspace.onUpgradeStation |
| commands:TechnologyWorkspace.onCancelResearch | B2 | 实现中；候选待源行为比较 | src/components/TechnologyWorkspace.tsx:23 | scenes/ui/TechnologyPanel.gd::_on_technology_intent | rule:commands:TechnologyWorkspace.onCancelResearch / manual:commands:TechnologyWorkspace.onCancelResearch |
| commands:TechnologyWorkspace.onClose | B2 | 实现中；候选待源行为比较 | src/components/TechnologyWorkspace.tsx:20 | scenes/ui/FactoryWorkspaceUI.gd::close_active_workspace | rule:commands:TechnologyWorkspace.onClose / manual:commands:TechnologyWorkspace.onClose |
| commands:TechnologyWorkspace.onInfiniteResearchAutomation | B2 | 未实现；待逐项核实/映射 | src/components/TechnologyWorkspace.tsx:27 | 尚未确认 | rule:commands:TechnologyWorkspace.onInfiniteResearchAutomation / manual:commands:TechnologyWorkspace.onInfiniteResearchAutomation |
| commands:TechnologyWorkspace.onLayoutChange | B2 | 未实现；待逐项核实/映射 | src/components/TechnologyWorkspace.tsx:28 | 尚未确认 | rule:commands:TechnologyWorkspace.onLayoutChange / manual:commands:TechnologyWorkspace.onLayoutChange |
| commands:TechnologyWorkspace.onPauseResearch | B2 | 实现中；候选待源行为比较 | src/components/TechnologyWorkspace.tsx:22 | scripts/game/TechnologySystem.gd::pause_research | rule:commands:TechnologyWorkspace.onPauseResearch / manual:commands:TechnologyWorkspace.onPauseResearch |
| commands:TechnologyWorkspace.onRemoveQueued | B2 | 实现中；候选待源行为比较 | src/components/TechnologyWorkspace.tsx:25 | scenes/ui/TechnologyPanel.gd::_on_remove_queue_intent | rule:commands:TechnologyWorkspace.onRemoveQueued / manual:commands:TechnologyWorkspace.onRemoveQueued |
| commands:TechnologyWorkspace.onResumeResearch | B2 | 实现中；候选待源行为比较 | src/components/TechnologyWorkspace.tsx:24 | scripts/game/TechnologySystem.gd::resume_research | rule:commands:TechnologyWorkspace.onResumeResearch / manual:commands:TechnologyWorkspace.onResumeResearch |
| commands:TechnologyWorkspace.onSelect | B2 | 实现中；候选待源行为比较 | src/components/TechnologyWorkspace.tsx:21 | scenes/ui/TechnologyPanel.gd::_on_technology_intent | rule:commands:TechnologyWorkspace.onSelect / manual:commands:TechnologyWorkspace.onSelect |
| commands:TechnologyWorkspace.onSelectInfiniteResearch | B2 | 实现中；候选待源行为比较 | src/components/TechnologyWorkspace.tsx:26 | scripts/game/InfiniteResearchSystem.gd::select | rule:commands:TechnologyWorkspace.onSelectInfiniteResearch / manual:commands:TechnologyWorkspace.onSelectInfiniteResearch |
| commands:TimeWarpIdleOverlay.onCancelSettlement | B5 | 实现中；候选待源行为比较 | src/components/TimeWarpIdleOverlay.tsx:118 | autoload/GameManager.gd::discard_offline_settlement | rule:commands:TimeWarpIdleOverlay.onCancelSettlement / manual:commands:TimeWarpIdleOverlay.onCancelSettlement |
| commands:TimeWarpIdleOverlay.onContinueNormally | B5 | 实现中；候选待源行为比较 | src/components/TimeWarpIdleOverlay.tsx:121 | autoload/GameManager.gd::configure_pure_idle | rule:commands:TimeWarpIdleOverlay.onContinueNormally / manual:commands:TimeWarpIdleOverlay.onContinueNormally |
| commands:TimeWarpIdleOverlay.onRetryRecovery | B5 | 实现中；候选待源行为比较 | src/components/TimeWarpIdleOverlay.tsx:120 | autoload/GameManager.gd::retry_offline_settlement | rule:commands:TimeWarpIdleOverlay.onRetryRecovery / manual:commands:TimeWarpIdleOverlay.onRetryRecovery |
| commands:TimeWarpIdleOverlay.onStop | B5 | 实现中；候选待源行为比较 | src/components/TimeWarpIdleOverlay.tsx:117 | autoload/GameManager.gd::configure_pure_idle | rule:commands:TimeWarpIdleOverlay.onStop / manual:commands:TimeWarpIdleOverlay.onStop |
| commands:TrayManagementDialog.onClose | B1 | 未实现；待逐项核实/映射 | src/components/TrayManagementDialog.tsx:20 | 尚未确认 | rule:commands:TrayManagementDialog.onClose / manual:commands:TrayManagementDialog.onClose |
| commands:TrayManagementDialog.onDiscard | B1 | 未实现；待逐项核实/映射 | src/components/TrayManagementDialog.tsx:18 | 尚未确认 | rule:commands:TrayManagementDialog.onDiscard / manual:commands:TrayManagementDialog.onDiscard |
| commands:TrayManagementDialog.onSetItemLimit | B1 | 未实现；待逐项核实/映射 | src/components/TrayManagementDialog.tsx:19 | 尚未确认 | rule:commands:TrayManagementDialog.onSetItemLimit / manual:commands:TrayManagementDialog.onSetItemLimit |
| commands:TutorialWorkspace.onClose | B2 | 实现中；候选待源行为比较 | src/components/TutorialWorkspace.tsx:54 | scenes/ui/TutorialOverlay.gd::_ready | rule:commands:TutorialWorkspace.onClose / manual:commands:TutorialWorkspace.onClose |
| commands:WorkspaceFrame.onRequestClose | B2 | 未实现；待逐项核实/映射 | src/components/WorkspaceFrame.tsx:14 | 尚未确认 | rule:commands:WorkspaceFrame.onRequestClose / manual:commands:WorkspaceFrame.onRequestClose |

## modes

| key | 批次 | 状态/复核 | 源位置 | 当前映射 | 自动/人工编号 |
|---|---|---|---|---|---|
| modes:normal | B5 | 实现中；开局经济已修复并通过专项，完整模式仍待验证 | src/game/types.ts:1 | scripts/game/GameModeSystem.gd::configure_new_game | rule:modes:normal / manual:modes:normal |
| modes:pure_idle | B5 | 实现中；候选待源行为比较 | src/game/pureIdleMacro.ts:1 | scripts/game/PureIdleSimulationJob.gd::begin | rule:modes:pure_idle / manual:modes:pure_idle |
| modes:speedrun | B5 | 实现中；候选待源行为比较 | src/game/types.ts:1 | scripts/game/GameModeSystem.gd::configure_new_game | rule:modes:speedrun / manual:modes:speedrun |
| modes:time_warp | B5 | 实现中；候选待源行为比较 | src/game/engine.ts:1 | scripts/game/TimeWarpSystem.gd::set_enabled | rule:modes:time_warp / manual:modes:time_warp |
