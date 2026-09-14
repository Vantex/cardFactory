# DSPONLINE 单机对齐清单

源版本 1.0.46，提交 `472bf62c76b695852b5577e563c1d113192ac731`，工作区干净。固定文件 SHA-256 与完整数据定义见 [冻结目录](../tests/fixtures/parity/dsponline_source_catalog.json)。

任务 22 已登记正式源目录及制造/喷涂候选，仍保留跨系统运行缺口；详见 [任务 22 验收](current/TASK22_ACCEPTANCE.md)。

任务 23 新增会话历史、布局与桌面命令入口，更新 15 项候选映射（14 项从未实现转入实现中）；详见 [任务 23 验收](current/TASK23_ACCEPTANCE.md)。

## 如何阅读

此表是任务 19 的差距登记，不是玩法已经对齐的证明。现有系统仍可使用；“实现中”只表示存在候选映射，未逐项验证原版数值和行为。登记门允许明确登记的缺口，最终发布门必须清零未实现/实现中。

状态统计：{"实现中":340,"未实现":736,"在线排除":23}。没有把同名条目自动标为已验证。

完整来源定义保存输入输出、数值、前置、解锁、奖励和目录规则；成就判定等代码规则记录源文件及哈希，行为验证仍待任务 25/27。每行的自动规则编号为 rule:类别:源ID，人工编号为 manual:类别:源ID；规则规格见 [rule_cases.json](../tests/fixtures/parity/rule_cases.json)，规格登记不等于已执行行为测试。UI 栏为原版入口/定义来源，当前候选路径和缺口见 [机器清单](../tests/fixtures/parity/dsponline_single_player_manifest.json)。

## 源目录规模

| 类别 | 冻结数量 |
|---|---:|
| items | 78 |
| recipes | 80 |
| buildings | 39 |
| technologies | 76 |
| campaign | 32 |
| achievements | 13 |
| difficulties | 3 |
| matrices | 6 |
| belts | 3 |
| construction | 42 |
| proliferators | 3 |
| workspaces | 14 |
| commands | 714 |
| modes | 4 |

科技含 69 项有效定义和 7 项 deprecated 旧定义，保留旧定义以追踪兼容规则；不把它们算成 76 项可研究科技。旧路线图的 78 配方/37 建筑/67 科技已过时，本次按实际源代码冻结。

操作清单覆盖根目录桌面组件显式 onX 回调契约、engine.ts 首参为 GameState 的公开操作/查询及命令面板动态条目族；包含辅助 UI 回调，不能把条目数量当作独立玩法数量。移动/语言回调单独按用户范围排除；在线排除使用固定逐项白名单，不以关键词在运行时自动放行。

## 逐项矩阵

### items

| 源 ID | 名称 | 当前候选 ID/文件 | 状态 | 后续任务 | 来源/UI |
|---|---|---|---|---:|---|
| accumulator | 蓄电器 | accumulator | 实现中 | 22 | src/components/RecipeWorkspace.tsx |
| annihilation_constraint_sphere | 湮灭约束球 | annihilation_constraint_sphere | 实现中 | 22 | src/components/RecipeWorkspace.tsx |
| antimatter | 反物质 | antimatter | 实现中 | 22 | src/components/RecipeWorkspace.tsx |
| antimatter_fuel_rod | 反物质燃料棒 | antimatter_fuel_rod | 实现中 | 22 | src/components/RecipeWorkspace.tsx |
| carbon_nanotube | 碳纳米管 | carbon_nanotube | 实现中 | 22 | src/components/RecipeWorkspace.tsx |
| casimir_crystal | 卡西米尔晶体 | casimir_crystal | 实现中 | 22 | src/components/RecipeWorkspace.tsx |
| charged_accumulator | 蓄电器（满） | charged_accumulator | 实现中 | 22 | src/components/RecipeWorkspace.tsx |
| circuit_board | 电路板 | circuit_board | 实现中 | 22 | src/components/RecipeWorkspace.tsx |
| coal | 煤矿 | coal | 实现中 | 22 | src/components/RecipeWorkspace.tsx |
| copper_ingot | 铜块 | copper_ingot | 实现中 | 22 | src/components/RecipeWorkspace.tsx |
| copper_ore | 铜矿石 | copper_ore | 实现中 | 22 | src/components/RecipeWorkspace.tsx |
| critical_photon | 临界光子 | critical_photon | 实现中 | 22 | src/components/RecipeWorkspace.tsx |
| crude_oil | 原油 | crude_oil | 实现中 | 22 | src/components/RecipeWorkspace.tsx |
| crystal_silicon | 晶格硅 | crystal_silicon | 实现中 | 22 | src/components/RecipeWorkspace.tsx |
| deuterium | 氘 | deuterium | 实现中 | 22 | src/components/RecipeWorkspace.tsx |
| deuteron_fuel_rod | 氘核燃料棒 | deuteron_fuel_rod | 实现中 | 22 | src/components/RecipeWorkspace.tsx |
| diamond | 金刚石 | diamond | 实现中 | 22 | src/components/RecipeWorkspace.tsx |
| dyson_sphere_component | 戴森球组件 | dyson_sphere_component | 实现中 | 22 | src/components/RecipeWorkspace.tsx |
| electric_motor | 电动机 | electric_motor | 实现中 | 22 | src/components/RecipeWorkspace.tsx |
| electromagnetic_matrix | 电磁矩阵 | electromagnetic_matrix | 实现中 | 22 | src/components/RecipeWorkspace.tsx |
| electromagnetic_turbine | 电磁涡轮 | electromagnetic_turbine | 实现中 | 22 | src/components/RecipeWorkspace.tsx |
| energetic_graphite | 高能石墨 | energetic_graphite | 实现中 | 22 | src/components/RecipeWorkspace.tsx |
| energy_matrix | 能量矩阵 | energy_matrix | 实现中 | 22 | src/components/RecipeWorkspace.tsx |
| fire_ice | 可燃冰 | fire_ice | 实现中 | 22 | src/components/RecipeWorkspace.tsx |
| fractal_silicon | 分形硅石 | fractal_silicon | 实现中 | 22 | src/components/RecipeWorkspace.tsx |
| frame_material | 框架材料 | frame_material | 实现中 | 22 | src/components/RecipeWorkspace.tsx |
| gear | 齿轮 | gear | 实现中 | 22 | src/components/RecipeWorkspace.tsx |
| glass | 玻璃 | glass | 实现中 | 22 | src/components/RecipeWorkspace.tsx |
| graphene | 石墨烯 | graphene | 实现中 | 22 | src/components/RecipeWorkspace.tsx |
| graviton_lens | 引力透镜 | graviton_lens | 实现中 | 22 | src/components/RecipeWorkspace.tsx |
| gravity_matrix | 引力矩阵 | gravity_matrix | 实现中 | 22 | src/components/RecipeWorkspace.tsx |
| high_purity_silicon | 高纯硅块 | high_purity_silicon | 实现中 | 22 | src/components/RecipeWorkspace.tsx |
| hydrogen | 氢 | hydrogen | 实现中 | 22 | src/components/RecipeWorkspace.tsx |
| hydrogen_fuel_rod | 氢燃料棒 | hydrogen_fuel_rod | 实现中 | 22 | src/components/RecipeWorkspace.tsx |
| information_matrix | 信息矩阵 | information_matrix | 实现中 | 22 | src/components/RecipeWorkspace.tsx |
| iron_ingot | 铁块 | iron_ingot | 实现中 | 22 | src/components/RecipeWorkspace.tsx |
| iron_ore | 铁矿石 | iron_ore | 实现中 | 22 | src/components/RecipeWorkspace.tsx |
| kimberlite_ore | 金伯利矿石 | kimberlite_ore | 实现中 | 22 | src/components/RecipeWorkspace.tsx |
| logistics_drone | 物流运输机 | logistics_drone | 实现中 | 22 | src/components/RecipeWorkspace.tsx |
| logistics_vessel | 物流运输船 | logistics_vessel | 实现中 | 22 | src/components/RecipeWorkspace.tsx |
| magnet | 磁铁 | magnet | 实现中 | 22 | src/components/RecipeWorkspace.tsx |
| magnetic_coil | 磁线圈 | magnetic_coil | 实现中 | 22 | src/components/RecipeWorkspace.tsx |
| microcrystalline_component | 微晶元件 | microcrystalline_component | 实现中 | 22 | src/components/RecipeWorkspace.tsx |
| optical_grating_crystal | 光栅石 | optical_grating_crystal | 实现中 | 22 | src/components/RecipeWorkspace.tsx |
| organic_crystal | 有机晶体 | organic_crystal | 实现中 | 22 | src/components/RecipeWorkspace.tsx |
| particle_broadband | 粒子宽带 | particle_broadband | 实现中 | 22 | src/components/RecipeWorkspace.tsx |
| particle_container | 粒子容器 | particle_container | 实现中 | 22 | src/components/RecipeWorkspace.tsx |
| photon_combiner | 光子合并器 | photon_combiner | 实现中 | 22 | src/components/RecipeWorkspace.tsx |
| plane_filter | 位面过滤器 | plane_filter | 实现中 | 22 | src/components/RecipeWorkspace.tsx |
| plasma_exciter | 电浆激发器 | plasma_exciter | 实现中 | 22 | src/components/RecipeWorkspace.tsx |
| plastic | 塑料 | plastic | 实现中 | 22 | src/components/RecipeWorkspace.tsx |
| prism | 棱镜 | prism | 实现中 | 22 | src/components/RecipeWorkspace.tsx |
| processor | 处理器 | processor | 实现中 | 22 | src/components/RecipeWorkspace.tsx |
| proliferator_mk1 | 增产剂 Mk.I | proliferator_mk1 | 实现中 | 22 | src/components/RecipeWorkspace.tsx |
| proliferator_mk2 | 增产剂 Mk.II | proliferator_mk2 | 实现中 | 22 | src/components/RecipeWorkspace.tsx |
| proliferator_mk3 | 增产剂 Mk.III | proliferator_mk3 | 实现中 | 22 | src/components/RecipeWorkspace.tsx |
| quantum_chip | 量子芯片 | quantum_chip | 实现中 | 22 | src/components/RecipeWorkspace.tsx |
| refined_oil | 精炼油 | refined_oil | 实现中 | 22 | src/components/RecipeWorkspace.tsx |
| silicon_ore | 硅石 | silicon_ore | 实现中 | 22 | src/components/RecipeWorkspace.tsx |
| small_carrier_rocket | 小型运载火箭 | small_carrier_rocket | 实现中 | 22 | src/components/RecipeWorkspace.tsx |
| solar_sail | 太阳帆 | solar_sail | 实现中 | 22 | src/components/RecipeWorkspace.tsx |
| space_warper | 空间翘曲器 | space_warper | 实现中 | 22 | src/components/RecipeWorkspace.tsx |
| spiniform_stalagmite_crystal | 刺笋结晶 | spiniform_stalagmite_crystal | 实现中 | 22 | src/components/RecipeWorkspace.tsx |
| steel | 钢材 | steel | 实现中 | 22 | src/components/RecipeWorkspace.tsx |
| stone | 石矿 | stone | 实现中 | 22 | src/components/RecipeWorkspace.tsx |
| stone_brick | 石材 | stone_brick | 实现中 | 22 | src/components/RecipeWorkspace.tsx |
| strange_matter | 奇异物质 | strange_matter | 实现中 | 22 | src/components/RecipeWorkspace.tsx |
| structure_matrix | 结构矩阵 | structure_matrix | 实现中 | 22 | src/components/RecipeWorkspace.tsx |
| sulfuric_acid | 硫酸 | sulfuric_acid | 实现中 | 22 | src/components/RecipeWorkspace.tsx |
| super_magnetic_ring | 超级磁场环 | super_magnetic_ring | 实现中 | 22 | src/components/RecipeWorkspace.tsx |
| titanium_alloy | 钛合金 | titanium_alloy | 实现中 | 22 | src/components/RecipeWorkspace.tsx |
| titanium_crystal | 钛晶石 | titanium_crystal | 实现中 | 22 | src/components/RecipeWorkspace.tsx |
| titanium_glass | 钛化玻璃 | titanium_glass | 实现中 | 22 | src/components/RecipeWorkspace.tsx |
| titanium_ingot | 钛块 | titanium_ingot | 实现中 | 22 | src/components/RecipeWorkspace.tsx |
| titanium_ore | 钛石 | titanium_ore | 实现中 | 22 | src/components/RecipeWorkspace.tsx |
| unipolar_magnet | 单极磁石 | unipolar_magnet | 实现中 | 22 | src/components/RecipeWorkspace.tsx |
| universe_matrix | 宇宙矩阵 | universe_matrix | 实现中 | 22 | src/components/RecipeWorkspace.tsx |
| water | 水 | water | 实现中 | 22 | src/components/RecipeWorkspace.tsx |

### recipes

| 源 ID | 名称 | 当前候选 ID/文件 | 状态 | 后续任务 | 来源/UI |
|---|---|---|---|---:|---|
| accumulator | 蓄电器 | dsp_accumulator | 实现中 | 22 | src/components/RecipeWorkspace.tsx |
| accumulator_charge | 蓄电器充电 | dsp_accumulator_charge | 实现中 | 22 | src/components/RecipeWorkspace.tsx |
| accumulator_discharge | 蓄电器放电 | dsp_accumulator_discharge | 实现中 | 22 | src/components/RecipeWorkspace.tsx |
| annihilation_constraint_sphere | 湮灭约束球 | dsp_annihilation_constraint_sphere | 实现中 | 22 | src/components/RecipeWorkspace.tsx |
| antimatter | 质能转换 | dsp_antimatter | 实现中 | 22 | src/components/RecipeWorkspace.tsx |
| antimatter_fuel_rod | 反物质燃料棒 | dsp_antimatter_fuel_rod | 实现中 | 22 | src/components/RecipeWorkspace.tsx |
| carbon_nanotube | 碳纳米管 | dsp_carbon_nanotube | 实现中 | 22 | src/components/RecipeWorkspace.tsx |
| carbon_nanotube_from_spiniform | 刺笋结晶制碳纳米管 | dsp_carbon_nanotube_from_spiniform | 实现中 | 22 | src/components/RecipeWorkspace.tsx |
| carrier_rocket_launch | 运载火箭发射 | dsp_carrier_rocket_launch | 实现中 | 22 | src/components/RecipeWorkspace.tsx |
| casimir_crystal | 卡西米尔晶体 | dsp_casimir_crystal | 实现中 | 22 | src/components/RecipeWorkspace.tsx |
| casimir_crystal_advanced | 高效卡西米尔晶体 | dsp_casimir_crystal_advanced | 实现中 | 22 | src/components/RecipeWorkspace.tsx |
| circuit_board | 电路板 | dsp_circuit_board | 实现中 | 22 | src/components/RecipeWorkspace.tsx |
| copper_ingot | 铜块 | dsp_copper_ingot | 实现中 | 22 | src/components/RecipeWorkspace.tsx |
| critical_photon | 临界光子 | dsp_critical_photon | 实现中 | 22 | src/components/RecipeWorkspace.tsx |
| crystal_silicon | 晶格硅 | dsp_crystal_silicon | 实现中 | 22 | src/components/RecipeWorkspace.tsx |
| crystal_silicon_from_fractal | 分形硅晶格化 | dsp_crystal_silicon_from_fractal | 实现中 | 22 | src/components/RecipeWorkspace.tsx |
| deuterium | 氘富集 | dsp_deuterium | 实现中 | 22 | src/components/RecipeWorkspace.tsx |
| deuterium_fractionation | 氢分馏 | dsp_deuterium_fractionation | 实现中 | 22 | src/components/RecipeWorkspace.tsx |
| deuteron_fuel_rod | 氘核燃料棒 | dsp_deuteron_fuel_rod | 实现中 | 22 | src/components/RecipeWorkspace.tsx |
| diamond | 金刚石 | dsp_diamond | 实现中 | 22 | src/components/RecipeWorkspace.tsx |
| diamond_from_kimberlite | 金伯利矿提炼 | dsp_diamond_from_kimberlite | 实现中 | 22 | src/components/RecipeWorkspace.tsx |
| dyson_sphere_component | 戴森球组件 | dsp_dyson_sphere_component | 实现中 | 22 | src/components/RecipeWorkspace.tsx |
| electric_motor | 电动机 | dsp_electric_motor | 实现中 | 22 | src/components/RecipeWorkspace.tsx |
| electromagnetic_matrix | 电磁矩阵 | dsp_electromagnetic_matrix | 实现中 | 22 | src/components/RecipeWorkspace.tsx |
| electromagnetic_turbine | 电磁涡轮 | dsp_electromagnetic_turbine | 实现中 | 22 | src/components/RecipeWorkspace.tsx |
| energetic_graphite | 高能石墨 | dsp_energetic_graphite | 实现中 | 22 | src/components/RecipeWorkspace.tsx |
| energy_matrix | 能量矩阵 | dsp_energy_matrix | 实现中 | 22 | src/components/RecipeWorkspace.tsx |
| frame_material | 框架材料 | dsp_frame_material | 实现中 | 22 | src/components/RecipeWorkspace.tsx |
| gear | 齿轮 | dsp_gear | 实现中 | 22 | src/components/RecipeWorkspace.tsx |
| glass | 玻璃 | dsp_glass | 实现中 | 22 | src/components/RecipeWorkspace.tsx |
| graphene | 石墨烯 | dsp_graphene | 实现中 | 22 | src/components/RecipeWorkspace.tsx |
| graphene_from_fire_ice | 可燃冰裂解 | dsp_graphene_from_fire_ice | 实现中 | 22 | src/components/RecipeWorkspace.tsx |
| graviton_lens | 引力透镜 | dsp_graviton_lens | 实现中 | 22 | src/components/RecipeWorkspace.tsx |
| gravity_matrix | 引力矩阵 | dsp_gravity_matrix | 实现中 | 22 | src/components/RecipeWorkspace.tsx |
| high_purity_silicon | 高纯硅块 | dsp_high_purity_silicon | 实现中 | 22 | src/components/RecipeWorkspace.tsx |
| hydrogen_fuel_rod | 氢燃料棒 | dsp_hydrogen_fuel_rod | 实现中 | 22 | src/components/RecipeWorkspace.tsx |
| information_matrix | 信息矩阵 | dsp_information_matrix | 实现中 | 22 | src/components/RecipeWorkspace.tsx |
| iron_ingot | 铁块 | dsp_iron_ingot | 实现中 | 22 | src/components/RecipeWorkspace.tsx |
| logistics_drone | 物流运输机 | dsp_logistics_drone | 实现中 | 22 | src/components/RecipeWorkspace.tsx |
| logistics_vessel | 物流运输船 | dsp_logistics_vessel | 实现中 | 22 | src/components/RecipeWorkspace.tsx |
| magnet | 磁铁 | dsp_magnet | 实现中 | 22 | src/components/RecipeWorkspace.tsx |
| magnetic_coil | 磁线圈 | dsp_magnetic_coil | 实现中 | 22 | src/components/RecipeWorkspace.tsx |
| matrix_research | 科研模式 | dsp_matrix_research | 实现中 | 22 | src/components/RecipeWorkspace.tsx |
| microcrystalline_component | 微晶元件 | dsp_microcrystalline_component | 实现中 | 22 | src/components/RecipeWorkspace.tsx |
| organic_crystal | 有机晶体 | dsp_organic_crystal | 实现中 | 22 | src/components/RecipeWorkspace.tsx |
| particle_broadband | 粒子宽带 | dsp_particle_broadband | 实现中 | 22 | src/components/RecipeWorkspace.tsx |
| particle_container | 粒子容器 | dsp_particle_container | 实现中 | 22 | src/components/RecipeWorkspace.tsx |
| particle_container_from_unipolar | 单极磁石粒子容器 | dsp_particle_container_from_unipolar | 实现中 | 22 | src/components/RecipeWorkspace.tsx |
| photon_combiner | 光子合并器 | dsp_photon_combiner | 实现中 | 22 | src/components/RecipeWorkspace.tsx |
| photon_combiner_from_grating | 光栅石光子合并器 | dsp_photon_combiner_from_grating | 实现中 | 22 | src/components/RecipeWorkspace.tsx |
| plane_filter | 位面过滤器 | dsp_plane_filter | 实现中 | 22 | src/components/RecipeWorkspace.tsx |
| plasma_exciter | 电浆激发器 | dsp_plasma_exciter | 实现中 | 22 | src/components/RecipeWorkspace.tsx |
| plasma_refining | 等离子精炼 | dsp_plasma_refining | 实现中 | 22 | src/components/RecipeWorkspace.tsx |
| plastic | 塑料 | dsp_plastic | 实现中 | 22 | src/components/RecipeWorkspace.tsx |
| prism | 棱镜 | dsp_prism | 实现中 | 22 | src/components/RecipeWorkspace.tsx |
| processor | 处理器 | dsp_processor | 实现中 | 22 | src/components/RecipeWorkspace.tsx |
| proliferator_mk1 | 增产剂 Mk.I | dsp_proliferator_mk1 | 实现中 | 22 | src/components/RecipeWorkspace.tsx |
| proliferator_mk2 | 增产剂 Mk.II | dsp_proliferator_mk2 | 实现中 | 22 | src/components/RecipeWorkspace.tsx |
| proliferator_mk3 | 增产剂 Mk.III | dsp_proliferator_mk3 | 实现中 | 22 | src/components/RecipeWorkspace.tsx |
| quantum_chip | 量子芯片 | dsp_quantum_chip | 实现中 | 22 | src/components/RecipeWorkspace.tsx |
| ray_power | 电力接收 | dsp_ray_power | 实现中 | 22 | src/components/RecipeWorkspace.tsx |
| reforming_refine | 重整精炼 | dsp_reforming_refine | 实现中 | 22 | src/components/RecipeWorkspace.tsx |
| silicon_ore_from_stone | 石矿提炼硅石 | dsp_silicon_ore_from_stone | 实现中 | 22 | src/components/RecipeWorkspace.tsx |
| small_carrier_rocket | 小型运载火箭 | dsp_small_carrier_rocket | 实现中 | 22 | src/components/RecipeWorkspace.tsx |
| solar_sail | 太阳帆 | dsp_solar_sail | 实现中 | 22 | src/components/RecipeWorkspace.tsx |
| solar_sail_launch | 太阳帆发射 | dsp_solar_sail_launch | 实现中 | 22 | src/components/RecipeWorkspace.tsx |
| space_warper | 空间翘曲器 | dsp_space_warper | 实现中 | 22 | src/components/RecipeWorkspace.tsx |
| space_warper_from_gravity_matrix | 引力矩阵制空间翘曲器 | dsp_space_warper_from_gravity_matrix | 实现中 | 22 | src/components/RecipeWorkspace.tsx |
| steel | 钢材 | dsp_steel | 实现中 | 22 | src/components/RecipeWorkspace.tsx |
| stone_brick | 石材 | dsp_stone_brick | 实现中 | 22 | src/components/RecipeWorkspace.tsx |
| strange_matter | 奇异物质 | dsp_strange_matter | 实现中 | 22 | src/components/RecipeWorkspace.tsx |
| structure_matrix | 结构矩阵 | dsp_structure_matrix | 实现中 | 22 | src/components/RecipeWorkspace.tsx |
| sulfuric_acid | 硫酸 | dsp_sulfuric_acid | 实现中 | 22 | src/components/RecipeWorkspace.tsx |
| super_magnetic_ring | 超级磁场环 | dsp_super_magnetic_ring | 实现中 | 22 | src/components/RecipeWorkspace.tsx |
| titanium_alloy | 钛合金 | dsp_titanium_alloy | 实现中 | 22 | src/components/RecipeWorkspace.tsx |
| titanium_crystal | 钛晶石 | dsp_titanium_crystal | 实现中 | 22 | src/components/RecipeWorkspace.tsx |
| titanium_glass | 钛化玻璃 | dsp_titanium_glass | 实现中 | 22 | src/components/RecipeWorkspace.tsx |
| titanium_ingot | 钛块 | dsp_titanium_ingot | 实现中 | 22 | src/components/RecipeWorkspace.tsx |
| universe_matrix | 宇宙矩阵 | dsp_universe_matrix | 实现中 | 22 | src/components/RecipeWorkspace.tsx |
| xray_cracking | X 射线裂解 | dsp_xray_cracking | 实现中 | 22 | src/components/RecipeWorkspace.tsx |

### buildings

| 源 ID | 名称 | 当前候选 ID/文件 | 状态 | 后续任务 | 来源/UI |
|---|---|---|---|---:|---|
| accumulator | 蓄电器 | dsp_accumulator | 实现中 | 21 | src/components/RecipeWorkspace.tsx |
| arc_smelter | 电弧熔炉 | dsp_arc_smelter | 实现中 | 22 | src/components/RecipeWorkspace.tsx |
| artificial_star | 人造恒星 | dsp_artificial_star | 实现中 | 21 | src/components/RecipeWorkspace.tsx |
| assembling_machine_mk1 | 制造台 Mk.I | dsp_assembling_machine_mk1 | 实现中 | 22 | src/components/RecipeWorkspace.tsx |
| assembling_machine_mk2 | 制造台 Mk.II | dsp_assembling_machine_mk2 | 实现中 | 22 | src/components/RecipeWorkspace.tsx |
| assembling_machine_mk3 | 制造台 Mk.III | dsp_assembling_machine_mk3 | 实现中 | 22 | src/components/RecipeWorkspace.tsx |
| chemical_plant | 化工厂 | dsp_chemical_plant | 实现中 | 22 | src/components/RecipeWorkspace.tsx |
| construction_center | 建筑制造中心 | dsp_construction_center | 实现中 | 22 | src/components/RecipeWorkspace.tsx |
| em_rail_ejector | 电磁轨道弹射器 | dsp_em_rail_ejector | 实现中 | 22 | src/components/RecipeWorkspace.tsx |
| energy_exchanger | 能量枢纽 | dsp_energy_exchanger | 实现中 | 21 | src/components/RecipeWorkspace.tsx |
| fractionator | 分馏塔 | dsp_fractionator | 实现中 | 22 | src/components/RecipeWorkspace.tsx |
| galactic_material_exporter | 超大型物资出口 | dsp_galactic_material_exporter | 实现中 | 22 | src/components/RecipeWorkspace.tsx |
| geothermal_power_station | 地热发电站 | dsp_geothermal_power_station | 实现中 | 21 | src/components/RecipeWorkspace.tsx |
| interstellar_logistics_station | 星际物流站 | dsp_interstellar_logistics_station | 实现中 | 22 | src/components/RecipeWorkspace.tsx |
| material_delivery_hub | 物资配送枢纽 | dsp_material_delivery_hub | 实现中 | 22 | src/components/RecipeWorkspace.tsx |
| matrix_lab | 矩阵研究站 | dsp_matrix_lab | 实现中 | 22 | src/components/RecipeWorkspace.tsx |
| micro_black_hole_connector | 微型黑洞连接装置 | dsp_micro_black_hole_connector | 实现中 | 22 | src/components/RecipeWorkspace.tsx |
| mini_fusion_power_plant | 微型聚变发电站 | dsp_mini_fusion_power_plant | 实现中 | 21 | src/components/RecipeWorkspace.tsx |
| miniature_particle_collider | 微型粒子对撞机 | dsp_miniature_particle_collider | 实现中 | 22 | src/components/RecipeWorkspace.tsx |
| mining_machine | 采矿机 | dsp_mining_machine | 实现中 | 22 | src/components/RecipeWorkspace.tsx |
| oil_extractor | 原油萃取站 | dsp_oil_extractor | 实现中 | 22 | src/components/RecipeWorkspace.tsx |
| oil_refinery | 原油精炼厂 | dsp_oil_refinery | 实现中 | 22 | src/components/RecipeWorkspace.tsx |
| orbital_cargo_terminal | 轨道货运终端 | dsp_orbital_cargo_terminal | 实现中 | 22 | src/components/RecipeWorkspace.tsx |
| orbital_collector | 轨道采集器 | dsp_orbital_collector | 实现中 | 22 | src/components/RecipeWorkspace.tsx |
| plane_smelter | 位面熔炉 | dsp_plane_smelter | 实现中 | 22 | src/components/RecipeWorkspace.tsx |
| planetary_logistics_station | 行星物流站 | dsp_planetary_logistics_station | 实现中 | 22 | src/components/RecipeWorkspace.tsx |
| quantum_chemical_plant | 量子化工厂 | dsp_quantum_chemical_plant | 实现中 | 22 | src/components/RecipeWorkspace.tsx |
| ray_receiver | 射线接收站 | dsp_ray_receiver | 实现中 | 22 | src/components/RecipeWorkspace.tsx |
| solar_panel | 太阳能板 | dsp_solar_panel | 实现中 | 21 | src/components/RecipeWorkspace.tsx |
| space_station_construction_launcher | 空间站施工发射平台 | dsp_space_station_construction_launcher | 实现中 | 22 | src/components/RecipeWorkspace.tsx |
| splitter_4way | 四向分流器 | dsp_splitter_4way | 实现中 | 22 | src/components/RecipeWorkspace.tsx |
| spray_coater | 喷涂机 | dsp_spray_coater | 实现中 | 22 | src/components/RecipeWorkspace.tsx |
| storage_mk1 | 小型储物仓 | dsp_storage_mk1 | 实现中 | 22 | src/components/RecipeWorkspace.tsx |
| storage_tank | 储液罐 | dsp_storage_tank | 实现中 | 22 | src/components/RecipeWorkspace.tsx |
| thermal_power_plant | 火力发电厂 | dsp_thermal_power_plant | 实现中 | 21 | src/components/RecipeWorkspace.tsx |
| time_warp_device | 时间扭曲装置 | dsp_time_warp_device | 实现中 | 22 | src/components/RecipeWorkspace.tsx |
| vertical_launching_silo | 垂直发射井 | dsp_vertical_launching_silo | 实现中 | 22 | src/components/RecipeWorkspace.tsx |
| water_pump | 抽水站 | dsp_water_pump | 实现中 | 22 | src/components/RecipeWorkspace.tsx |
| wind_turbine | 风力涡轮机 | dsp_wind_turbine | 实现中 | 21 | src/components/RecipeWorkspace.tsx |

### technologies

| 源 ID | 名称 | 当前候选 ID/文件 | 状态 | 后续任务 | 来源/UI |
|---|---|---|---|---:|---|
| antimatter | 质能储存 | 待映射 | 未实现 | 25 | src/components/TechnologyWorkspace.tsx |
| artificial_star | 人造恒星 | 待映射 | 未实现 | 25 | src/components/TechnologyWorkspace.tsx |
| autonomous_station_construction | 自律空间站建造 | 待映射 | 未实现 | 25 | src/components/TechnologyWorkspace.tsx |
| basic_chemical_engineering | 基础化工 | 待映射 | 未实现 | 25 | src/components/TechnologyWorkspace.tsx |
| basic_logistics | 基础物流系统 | 待映射 | 未实现 | 25 | src/components/TechnologyWorkspace.tsx |
| construction_automation | 巨构建筑制造 | 待映射 | 未实现 | 25 | src/components/TechnologyWorkspace.tsx |
| construction_capacity_1 | 建筑仓储扩容 I | 待映射 | 未实现 | 25 | src/components/TechnologyWorkspace.tsx |
| construction_capacity_2 | 建筑仓储扩容 II | 待映射 | 未实现 | 25 | src/components/TechnologyWorkspace.tsx |
| dyson_absorption_1 | 壳面吸附效率 | 待映射 | 未实现 | 25 | src/components/TechnologyWorkspace.tsx |
| dyson_shell | 戴森壳面 | 待映射 | 未实现 | 25 | src/components/TechnologyWorkspace.tsx |
| dyson_sphere_program | 戴森球计划 | 待映射 | 未实现 | 25 | src/components/TechnologyWorkspace.tsx |
| dyson_swarm | 戴森云 | 待映射 | 未实现 | 25 | src/components/TechnologyWorkspace.tsx |
| electromagnetic_matrix | 电磁矩阵 | 待映射 | 未实现 | 25 | src/components/TechnologyWorkspace.tsx |
| electromagnetism | 电磁学 | 待映射 | 未实现 | 25 | src/components/TechnologyWorkspace.tsx |
| energy_matrix | 能量矩阵 | 待映射 | 未实现 | 25 | src/components/TechnologyWorkspace.tsx |
| energy_storage | 能量储存 | 待映射 | 未实现 | 25 | src/components/TechnologyWorkspace.tsx |
| fractionation | 流体分馏 | 待映射 | 未实现 | 25 | src/components/TechnologyWorkspace.tsx |
| fusion_power | 可控核聚变 | 待映射 | 未实现 | 25 | src/components/TechnologyWorkspace.tsx |
| geothermal_power | 地热发电 | 待映射 | 未实现 | 25 | src/components/TechnologyWorkspace.tsx |
| gravity_matrix | 引力矩阵 | 待映射 | 未实现 | 25 | src/components/TechnologyWorkspace.tsx |
| high_efficiency_plasma_control | 高效电浆控制 | 待映射 | 未实现 | 25 | src/components/TechnologyWorkspace.tsx |
| high_speed_assembling | 高速装配工艺 | 待映射 | 未实现 | 25 | src/components/TechnologyWorkspace.tsx |
| high_speed_logistics | 高速物流系统 | 待映射 | 未实现 | 25 | src/components/TechnologyWorkspace.tsx |
| high_strength_crystal | 高强度晶体 | 待映射 | 未实现 | 25 | src/components/TechnologyWorkspace.tsx |
| information_matrix | 信息矩阵 | 待映射 | 未实现 | 25 | src/components/TechnologyWorkspace.tsx |
| interstellar_logistics | 星际物流系统 | interstellar_logistics | 实现中 | 25 | src/components/TechnologyWorkspace.tsx |
| logistics_capacity_1 | 物流载荷扩容 I | 待映射 | 未实现 | 25 | src/components/TechnologyWorkspace.tsx |
| logistics_capacity_2 | 物流载荷扩容 II | 待映射 | 未实现 | 25 | src/components/TechnologyWorkspace.tsx |
| logistics_engine_1 | 物流运输引擎 I | 待映射 | 未实现 | 25 | src/components/TechnologyWorkspace.tsx |
| logistics_engine_2 | 物流运输引擎 II | 待映射 | 未实现 | 25 | src/components/TechnologyWorkspace.tsx |
| material_delivery_logistics | 物资直送物流 | 待映射 | 未实现 | 25 | src/components/TechnologyWorkspace.tsx |
| micro_black_hole_containment | 微型黑洞约束工程 | 待映射 | 未实现 | 25 | src/components/TechnologyWorkspace.tsx |
| miniature_particle_collider | 微型粒子对撞机 | 待映射 | 未实现 | 25 | src/components/TechnologyWorkspace.tsx |
| mining_speed_1 | 高效采矿 I | 待映射 | 未实现 | 25 | src/components/TechnologyWorkspace.tsx |
| mining_speed_2 | 高效采矿 II | 待映射 | 未实现 | 25 | src/components/TechnologyWorkspace.tsx |
| mining_speed_3 | 高效采矿 III | 待映射 | 未实现 | 25 | src/components/TechnologyWorkspace.tsx |
| nanomaterials | 纳米材料 | 待映射 | 未实现 | 25 | src/components/TechnologyWorkspace.tsx |
| orbital_collection | 气态行星开采 | 待映射 | 未实现 | 25 | src/components/TechnologyWorkspace.tsx |
| orbital_elevator_engineering | 轨道升降工程 | 待映射 | 未实现 | 25 | src/components/TechnologyWorkspace.tsx |
| orbital_energy_recovery | 轨道升降能量回收 | 待映射 | 未实现 | 25 | src/components/TechnologyWorkspace.tsx |
| orbital_modular_assembly | 轨道模块化装配 | 待映射 | 未实现 | 25 | src/components/TechnologyWorkspace.tsx |
| orbital_multi_cargo_bus | 多物质轨道汇流 | 待映射 | 未实现 | 25 | src/components/TechnologyWorkspace.tsx |
| plane_smelting | 位面冶金 | 待映射 | 未实现 | 25 | src/components/TechnologyWorkspace.tsx |
| planetary_logistics | 行星物流系统 | 待映射 | 未实现 | 25 | src/components/TechnologyWorkspace.tsx |
| polymer_chemistry | 高分子化工 | 待映射 | 未实现 | 25 | src/components/TechnologyWorkspace.tsx |
| processor | 处理器 | 待映射 | 未实现 | 25 | src/components/TechnologyWorkspace.tsx |
| proliferator_1 | 增产剂 Mk.I | 待映射 | 未实现 | 25 | src/components/TechnologyWorkspace.tsx |
| proliferator_2 | 增产剂 Mk.II | 待映射 | 未实现 | 25 | src/components/TechnologyWorkspace.tsx |
| proliferator_3 | 增产剂 Mk.III | 待映射 | 未实现 | 25 | src/components/TechnologyWorkspace.tsx |
| quantum_chemical_engineering | 量子化工 | 待映射 | 未实现 | 25 | src/components/TechnologyWorkspace.tsx |
| quantum_chip | 量子芯片 | 待映射 | 未实现 | 25 | src/components/TechnologyWorkspace.tsx |
| quantum_logistics_network | 量子物流网络 | 待映射 | 未实现 | 25 | src/components/TechnologyWorkspace.tsx |
| quantum_printing | 量子打印技术 | 待映射 | 未实现 | 25 | src/components/TechnologyWorkspace.tsx |
| rare_resource_utilization | 稀有资源利用 | 待映射 | 未实现 | 25 | src/components/TechnologyWorkspace.tsx |
| ray_receiver | 射线接收站 | 待映射 | 未实现 | 25 | src/components/TechnologyWorkspace.tsx |
| ray_transmission_1 | 射线传输效率 I | 待映射 | 未实现 | 25 | src/components/TechnologyWorkspace.tsx |
| ray_transmission_2 | 射线传输效率 II | 待映射 | 未实现 | 25 | src/components/TechnologyWorkspace.tsx |
| reforming_refine | 重整精炼 | 待映射 | 未实现 | 25 | src/components/TechnologyWorkspace.tsx |
| research_speed_1 | 科研速度 I | 待映射 | 未实现 | 25 | src/components/TechnologyWorkspace.tsx |
| research_speed_2 | 科研速度 II | 待映射 | 未实现 | 25 | src/components/TechnologyWorkspace.tsx |
| research_speed_3 | 科研速度 III | 待映射 | 未实现 | 25 | src/components/TechnologyWorkspace.tsx |
| solar_energy | 太阳能收集 | 待映射 | 未实现 | 25 | src/components/TechnologyWorkspace.tsx |
| solar_sail_life_1 | 太阳帆轨道寿命 I | 待映射 | 未实现 | 25 | src/components/TechnologyWorkspace.tsx |
| solar_sail_life_2 | 太阳帆轨道寿命 II | 待映射 | 未实现 | 25 | src/components/TechnologyWorkspace.tsx |
| space_warp | 空间翘曲 | 待映射 | 未实现 | 25 | src/components/TechnologyWorkspace.tsx |
| stellar_exploration | 恒星探索 | 待映射 | 未实现 | 25 | src/components/TechnologyWorkspace.tsx |
| structure_matrix | 结构矩阵 | 待映射 | 未实现 | 25 | src/components/TechnologyWorkspace.tsx |
| super_magnetic_logistics | 超级磁场物流 | 待映射 | 未实现 | 25 | src/components/TechnologyWorkspace.tsx |
| system_space_station_engineering | 恒星系空间站工程 | 待映射 | 未实现 | 25 | src/components/TechnologyWorkspace.tsx |
| thermal_power | 火力发电 | 待映射 | 未实现 | 25 | src/components/TechnologyWorkspace.tsx |
| time_warp_engineering | 时间扭曲工程 | 待映射 | 未实现 | 25 | src/components/TechnologyWorkspace.tsx |
| titanium_alloy | 钛合金 | 待映射 | 未实现 | 25 | src/components/TechnologyWorkspace.tsx |
| unified_system_logistics_protocol | 恒星系联合物流协议 | 待映射 | 未实现 | 25 | src/components/TechnologyWorkspace.tsx |
| universe_matrix | 宇宙矩阵 | 待映射 | 未实现 | 25 | src/components/TechnologyWorkspace.tsx |
| vertical_launching_silo | 垂直发射井 | 待映射 | 未实现 | 25 | src/components/TechnologyWorkspace.tsx |
| xray_cracking | X 射线裂解 | 待映射 | 未实现 | 25 | src/components/TechnologyWorkspace.tsx |

### campaign

| 源 ID | 名称 | 当前候选 ID/文件 | 状态 | 后续任务 | 来源/UI |
|---|---|---|---|---:|---|
| absorb_shell_sail | 形成首片永久壳面 | 待映射 | 未实现 | 25 | src/components/CampaignWorkspace.tsx |
| build_dyson_structure | 完成第一个结构点 | 待映射 | 未实现 | 25 | src/components/CampaignWorkspace.tsx |
| complete_interstellar_trip | 完成首次星际运输 | 待映射 | 未实现 | 25 | src/components/CampaignWorkspace.tsx |
| complete_planetary_trip | 完成首次行星配送 | 待映射 | 未实现 | 25 | src/components/CampaignWorkspace.tsx |
| deploy_interstellar_station | 部署星际物流站 | 待映射 | 未实现 | 25 | src/components/CampaignWorkspace.tsx |
| deploy_matrix_lab | 部署矩阵研究站 | 待映射 | 未实现 | 25 | src/components/CampaignWorkspace.tsx |
| deploy_miner | 部署第一台采矿机 | 待映射 | 未实现 | 25 | src/components/CampaignWorkspace.tsx |
| deploy_planetary_station | 部署行星物流站 | 待映射 | 未实现 | 25 | src/components/CampaignWorkspace.tsx |
| endgame_export | 完成银河出口 | 待映射 | 未实现 | 25 | src/components/CampaignWorkspace.tsx |
| endgame_infinite_research | 启动无限科研 | 待映射 | 未实现 | 25 | src/components/CampaignWorkspace.tsx |
| endgame_mastery | 完成银河工业协议 | 待映射 | 未实现 | 25 | src/components/CampaignWorkspace.tsx |
| endgame_score | 达到银河级评分 | 待映射 | 未实现 | 25 | src/components/CampaignWorkspace.tsx |
| launch_carrier_rocket | 发射第一枚运载火箭 | 待映射 | 未实现 | 25 | src/components/CampaignWorkspace.tsx |
| launch_solar_sail | 发射第一片太阳帆 | 待映射 | 未实现 | 25 | src/components/CampaignWorkspace.tsx |
| lay_first_belt | 铺设第一条传送带 | 待映射 | 未实现 | 25 | src/components/CampaignWorkspace.tsx |
| mine_first_ore | 采集第一份矿石 | 待映射 | 未实现 | 25 | src/components/CampaignWorkspace.tsx |
| produce_blue_matrix | 产出电磁矩阵 | 待映射 | 未实现 | 25 | src/components/CampaignWorkspace.tsx |
| produce_gravity_matrix | 产出引力矩阵 | 待映射 | 未实现 | 25 | src/components/CampaignWorkspace.tsx |
| produce_information_matrix | 产出信息矩阵 | 待映射 | 未实现 | 25 | src/components/CampaignWorkspace.tsx |
| produce_plastic | 合成塑料 | 待映射 | 未实现 | 25 | src/components/CampaignWorkspace.tsx |
| produce_red_matrix | 产出能量矩阵 | 待映射 | 未实现 | 25 | src/components/CampaignWorkspace.tsx |
| produce_structure_matrix | 产出结构矩阵 | 待映射 | 未实现 | 25 | src/components/CampaignWorkspace.tsx |
| produce_universe_matrix | 产出宇宙矩阵 | 待映射 | 未实现 | 25 | src/components/CampaignWorkspace.tsx |
| refine_oil | 启动原油精炼 | 待映射 | 未实现 | 25 | src/components/CampaignWorkspace.tsx |
| side_belt_upgrade | 升级高速运输线 | 待映射 | 未实现 | 25 | src/components/CampaignWorkspace.tsx |
| side_blueprint | 保存第一张蓝图 | 待映射 | 未实现 | 25 | src/components/CampaignWorkspace.tsx |
| side_rare_resource | 采集稀有资源 | 待映射 | 未实现 | 25 | src/components/CampaignWorkspace.tsx |
| side_spray_coater | 安装首台喷涂机 | 待映射 | 未实现 | 25 | src/components/CampaignWorkspace.tsx |
| side_stable_power | 稳定火力电网 | 待映射 | 未实现 | 25 | src/components/CampaignWorkspace.tsx |
| side_storage | 建立物流缓存 | 待映射 | 未实现 | 25 | src/components/CampaignWorkspace.tsx |
| smelt_iron | 铸造基础铁块 | 待映射 | 未实现 | 25 | src/components/CampaignWorkspace.tsx |
| unlock_borealis | 解锁下一恒星系 | 待映射 | 未实现 | 25 | src/components/CampaignWorkspace.tsx |

### achievements

| 源 ID | 名称 | 当前候选 ID/文件 | 状态 | 后续任务 | 来源/UI |
|---|---|---|---|---:|---|
| automated_mining | 自动化开端 | 待映射 | 未实现 | 25 | src/components/CampaignWorkspace.tsx |
| dyson_swarm_online | 逐日之帆 | 待映射 | 未实现 | 25 | src/components/CampaignWorkspace.tsx |
| electromagnetic_matrix_online | 蓝色火花 | 待映射 | 未实现 | 25 | src/components/CampaignWorkspace.tsx |
| energy_matrix_online | 红色燃流 | 待映射 | 未实现 | 25 | src/components/CampaignWorkspace.tsx |
| first_logistics_line | 物流脉搏 | 待映射 | 未实现 | 25 | src/components/CampaignWorkspace.tsx |
| first_manual_mine | 第一镐 | 待映射 | 未实现 | 25 | src/components/CampaignWorkspace.tsx |
| interstellar_delivery | 星际航次 | 待映射 | 未实现 | 25 | src/components/CampaignWorkspace.tsx |
| multi_system_industry | 群星工业 | 待映射 | 未实现 | 25 | src/components/CampaignWorkspace.tsx |
| permanent_dyson_structure | 恒星骨架 | 待映射 | 未实现 | 25 | src/components/CampaignWorkspace.tsx |
| planetary_logistics_online | 行星配送 | 待映射 | 未实现 | 25 | src/components/CampaignWorkspace.tsx |
| rare_resource_harvest | 奇珍样本 | 待映射 | 未实现 | 25 | src/components/CampaignWorkspace.tsx |
| six_matrix_mastery | 矩阵全谱 | 待映射 | 未实现 | 25 | src/components/CampaignWorkspace.tsx |
| stable_power_grid | 电网并轨 | 待映射 | 未实现 | 25 | src/components/CampaignWorkspace.tsx |

### difficulties

| 源 ID | 名称 | 当前候选 ID/文件 | 状态 | 后续任务 | 来源/UI |
|---|---|---|---|---:|---|
| hard | 高压 | 待映射 | 未实现 | 26 | src/components/OperationsWorkspace.tsx |
| relaxed | 舒缓 | 待映射 | 未实现 | 26 | src/components/OperationsWorkspace.tsx |
| standard | 标准 | 待映射 | 未实现 | 26 | src/components/OperationsWorkspace.tsx |

### matrices

| 源 ID | 名称 | 当前候选 ID/文件 | 状态 | 后续任务 | 来源/UI |
|---|---|---|---|---:|---|
| electromagnetic_matrix | 电磁矩阵 | electromagnetic_matrix | 实现中 | 22 | src/components/TechnologyWorkspace.tsx |
| energy_matrix | 能量矩阵 | energy_matrix | 实现中 | 22 | src/components/TechnologyWorkspace.tsx |
| gravity_matrix | 引力矩阵 | gravity_matrix | 实现中 | 22 | src/components/TechnologyWorkspace.tsx |
| information_matrix | 信息矩阵 | information_matrix | 实现中 | 22 | src/components/TechnologyWorkspace.tsx |
| structure_matrix | 结构矩阵 | structure_matrix | 实现中 | 22 | src/components/TechnologyWorkspace.tsx |
| universe_matrix | 宇宙矩阵 | universe_matrix | 实现中 | 22 | src/components/TechnologyWorkspace.tsx |

### belts

| 源 ID | 名称 | 当前候选 ID/文件 | 状态 | 后续任务 | 来源/UI |
|---|---|---|---|---:|---|
| conveyor_belt_mk1 | conveyor_belt_mk1 | 待映射 | 未实现 | 23 | src/components/RecipeWorkspace.tsx |
| conveyor_belt_mk2 | conveyor_belt_mk2 | 待映射 | 未实现 | 23 | src/components/RecipeWorkspace.tsx |
| conveyor_belt_mk3 | conveyor_belt_mk3 | 待映射 | 未实现 | 23 | src/components/RecipeWorkspace.tsx |

### construction

| 源 ID | 名称 | 当前候选 ID/文件 | 状态 | 后续任务 | 来源/UI |
|---|---|---|---|---:|---|
| accumulator | 蓄电器 | dsp_accumulator | 实现中 | 22 | src/components/ConstructionCenterWorkspace.tsx |
| arc_smelter | 电弧熔炉 | dsp_arc_smelter | 实现中 | 22 | src/components/ConstructionCenterWorkspace.tsx |
| artificial_star | 人造恒星 | dsp_artificial_star | 实现中 | 22 | src/components/ConstructionCenterWorkspace.tsx |
| assembling_machine_mk1 | 制造台 Mk.I | dsp_assembling_machine_mk1 | 实现中 | 22 | src/components/ConstructionCenterWorkspace.tsx |
| assembling_machine_mk2 | 制造台 Mk.II | dsp_assembling_machine_mk2 | 实现中 | 22 | src/components/ConstructionCenterWorkspace.tsx |
| assembling_machine_mk3 | 制造台 Mk.III | dsp_assembling_machine_mk3 | 实现中 | 22 | src/components/ConstructionCenterWorkspace.tsx |
| chemical_plant | 化工厂 | dsp_chemical_plant | 实现中 | 22 | src/components/ConstructionCenterWorkspace.tsx |
| construction_center | 建筑制造中心 | dsp_construction_center | 实现中 | 22 | src/components/ConstructionCenterWorkspace.tsx |
| conveyor_belt_mk1 | 传送带 Mk.I | dsp_conveyor_belt_mk1 | 实现中 | 22 | src/components/ConstructionCenterWorkspace.tsx |
| conveyor_belt_mk2 | 传送带 Mk.II | dsp_conveyor_belt_mk2 | 实现中 | 22 | src/components/ConstructionCenterWorkspace.tsx |
| conveyor_belt_mk3 | 传送带 Mk.III | dsp_conveyor_belt_mk3 | 实现中 | 22 | src/components/ConstructionCenterWorkspace.tsx |
| em_rail_ejector | 电磁轨道弹射器 | dsp_em_rail_ejector | 实现中 | 22 | src/components/ConstructionCenterWorkspace.tsx |
| energy_exchanger | 能量枢纽 | dsp_energy_exchanger | 实现中 | 22 | src/components/ConstructionCenterWorkspace.tsx |
| fractionator | 分馏塔 | dsp_fractionator | 实现中 | 22 | src/components/ConstructionCenterWorkspace.tsx |
| galactic_material_exporter | 超大型物资出口 | dsp_galactic_material_exporter | 实现中 | 22 | src/components/ConstructionCenterWorkspace.tsx |
| geothermal_power_station | 地热发电站 | dsp_geothermal_power_station | 实现中 | 22 | src/components/ConstructionCenterWorkspace.tsx |
| interstellar_logistics_station | 星际物流站 | dsp_interstellar_logistics_station | 实现中 | 22 | src/components/ConstructionCenterWorkspace.tsx |
| material_delivery_hub | 物资配送枢纽 | dsp_material_delivery_hub | 实现中 | 22 | src/components/ConstructionCenterWorkspace.tsx |
| matrix_lab | 矩阵研究站 | dsp_matrix_lab | 实现中 | 22 | src/components/ConstructionCenterWorkspace.tsx |
| micro_black_hole_connector | 微型黑洞连接装置 | dsp_micro_black_hole_connector | 实现中 | 22 | src/components/ConstructionCenterWorkspace.tsx |
| mini_fusion_power_plant | 微型聚变发电站 | dsp_mini_fusion_power_plant | 实现中 | 22 | src/components/ConstructionCenterWorkspace.tsx |
| miniature_particle_collider | 微型粒子对撞机 | dsp_miniature_particle_collider | 实现中 | 22 | src/components/ConstructionCenterWorkspace.tsx |
| mining_machine | 采矿机 | dsp_mining_machine | 实现中 | 22 | src/components/ConstructionCenterWorkspace.tsx |
| oil_extractor | 原油萃取站 | dsp_oil_extractor | 实现中 | 22 | src/components/ConstructionCenterWorkspace.tsx |
| oil_refinery | 原油精炼厂 | dsp_oil_refinery | 实现中 | 22 | src/components/ConstructionCenterWorkspace.tsx |
| orbital_cargo_terminal | 轨道货运终端 | dsp_orbital_cargo_terminal | 实现中 | 22 | src/components/ConstructionCenterWorkspace.tsx |
| orbital_collector | 轨道采集器 | dsp_orbital_collector | 实现中 | 22 | src/components/ConstructionCenterWorkspace.tsx |
| plane_smelter | 位面熔炉 | dsp_plane_smelter | 实现中 | 22 | src/components/ConstructionCenterWorkspace.tsx |
| planetary_logistics_station | 行星物流站 | dsp_planetary_logistics_station | 实现中 | 22 | src/components/ConstructionCenterWorkspace.tsx |
| quantum_chemical_plant | 量子化工厂 | dsp_quantum_chemical_plant | 实现中 | 22 | src/components/ConstructionCenterWorkspace.tsx |
| ray_receiver | 射线接收站 | dsp_ray_receiver | 实现中 | 22 | src/components/ConstructionCenterWorkspace.tsx |
| solar_panel | 太阳能板 | dsp_solar_panel | 实现中 | 22 | src/components/ConstructionCenterWorkspace.tsx |
| space_station_construction_launcher | 空间站施工发射平台 | dsp_space_station_construction_launcher | 实现中 | 22 | src/components/ConstructionCenterWorkspace.tsx |
| splitter_4way | 四向分流器 | dsp_splitter_4way | 实现中 | 22 | src/components/ConstructionCenterWorkspace.tsx |
| spray_coater | 喷涂机 | dsp_spray_coater | 实现中 | 22 | src/components/ConstructionCenterWorkspace.tsx |
| storage_mk1 | 小型储物仓 | dsp_storage_mk1 | 实现中 | 22 | src/components/ConstructionCenterWorkspace.tsx |
| storage_tank | 储液罐 | dsp_storage_tank | 实现中 | 22 | src/components/ConstructionCenterWorkspace.tsx |
| thermal_power_plant | 火力发电厂 | dsp_thermal_power_plant | 实现中 | 22 | src/components/ConstructionCenterWorkspace.tsx |
| time_warp_device | 时间扭曲装置 | dsp_time_warp_device | 实现中 | 22 | src/components/ConstructionCenterWorkspace.tsx |
| vertical_launching_silo | 垂直发射井 | dsp_vertical_launching_silo | 实现中 | 22 | src/components/ConstructionCenterWorkspace.tsx |
| water_pump | 抽水站 | dsp_water_pump | 实现中 | 22 | src/components/ConstructionCenterWorkspace.tsx |
| wind_turbine | 风力涡轮机 | dsp_wind_turbine | 实现中 | 22 | src/components/ConstructionCenterWorkspace.tsx |

### proliferators

| 源 ID | 名称 | 当前候选 ID/文件 | 状态 | 后续任务 | 来源/UI |
|---|---|---|---|---:|---|
| proliferator_mk1 | proliferator_mk1 | proliferator_mk1 | 实现中 | 22 | src/components/RecipeWorkspace.tsx |
| proliferator_mk2 | proliferator_mk2 | proliferator_mk2 | 实现中 | 22 | src/components/RecipeWorkspace.tsx |
| proliferator_mk3 | proliferator_mk3 | proliferator_mk3 | 实现中 | 22 | src/components/RecipeWorkspace.tsx |

### workspaces

| 源 ID | 名称 | 当前候选 ID/文件 | 状态 | 后续任务 | 来源/UI |
|---|---|---|---|---:|---|
| BlueprintWorkspace | BlueprintWorkspace | scenes/ui/BlueprintWorkspace.gd | 实现中 | 24 | src/components/BlueprintWorkspace.tsx |
| CampaignWorkspace | CampaignWorkspace | scenes/ui/CampaignWorkspace.gd | 实现中 | 25 | src/components/CampaignWorkspace.tsx |
| ConstructionCenterWorkspace | ConstructionCenterWorkspace | scenes/ui/ProductionCatalogWorkspace.gd | 实现中 | 22 | src/components/ConstructionCenterWorkspace.tsx |
| DysonPlannerWorkspace | DysonPlannerWorkspace | 待映射 | 未实现 | 26 | src/components/DysonPlannerWorkspace.tsx |
| GalaxyWorkspace | GalaxyWorkspace | 待映射 | 在线排除 | 26 | src/components/GalaxyWorkspace.tsx |
| OfflineReportWorkspace | OfflineReportWorkspace | scenes/ui/OfflineReportWorkspace.gd | 实现中 | 20 | src/components/OfflineReportWorkspace.tsx |
| OperationsWorkspace | OperationsWorkspace | scenes/ui/SettingsWorkspace.gd | 实现中 | 23 | src/components/OperationsWorkspace.tsx |
| OrbitalStationWorkspace | OrbitalStationWorkspace | 待映射 | 未实现 | 26 | src/components/OrbitalStationWorkspace.tsx |
| RecipeWorkspace | RecipeWorkspace | scenes/ui/ProductionCatalogWorkspace.gd | 实现中 | 22 | src/components/RecipeWorkspace.tsx |
| StarMapWorkspace | StarMapWorkspace | scenes/ui/GalaxyMap.gd | 实现中 | 26 | src/components/StarMapWorkspace.tsx |
| StatisticsWorkspace | StatisticsWorkspace | 待映射 | 未实现 | 23 | src/components/StatisticsWorkspace.tsx |
| SystemSpaceStationWorkspace | SystemSpaceStationWorkspace | 待映射 | 未实现 | 26 | src/components/SystemSpaceStationWorkspace.tsx |
| TechnologyWorkspace | TechnologyWorkspace | scenes/ui/TechnologyPanel.gd | 实现中 | 25 | src/components/TechnologyWorkspace.tsx |
| TutorialWorkspace | TutorialWorkspace | scenes/ui/TutorialOverlay.gd | 实现中 | 25 | src/components/TutorialWorkspace.tsx |

### commands

| 源 ID | 名称 | 当前候选 ID/文件 | 状态 | 后续任务 | 来源/UI |
|---|---|---|---|---:|---|
| AccessibleDialog.onRequestClose | onRequestClose | 待映射 | 未实现 | 23 | src/components/AccessibleDialog.tsx |
| BlueprintWorkspace.onAutoLayout | onAutoLayout | 待映射 | 未实现 | 24 | src/components/BlueprintWorkspace.tsx |
| BlueprintWorkspace.onBatchConnectionModeChange | onBatchConnectionModeChange | 待映射 | 未实现 | 24 | src/components/BlueprintWorkspace.tsx |
| BlueprintWorkspace.onBatchIncrease | onBatchIncrease | 待映射 | 未实现 | 24 | src/components/BlueprintWorkspace.tsx |
| BlueprintWorkspace.onCancelQueue | onCancelQueue | 待映射 | 未实现 | 24 | src/components/BlueprintWorkspace.tsx |
| BlueprintWorkspace.onChange | onChange | 待映射 | 未实现 | 24 | src/components/BlueprintWorkspace.tsx |
| BlueprintWorkspace.onClear | onClear | 待映射 | 未实现 | 24 | src/components/BlueprintWorkspace.tsx |
| BlueprintWorkspace.onClose | onClose | 待映射 | 未实现 | 24 | src/components/BlueprintWorkspace.tsx |
| BlueprintWorkspace.onCopy | onCopy | 待映射 | 未实现 | 24 | src/components/BlueprintWorkspace.tsx |
| BlueprintWorkspace.onDeploy | onDeploy | 待映射 | 未实现 | 24 | src/components/BlueprintWorkspace.tsx |
| BlueprintWorkspace.onDone | onDone | 待映射 | 未实现 | 24 | src/components/BlueprintWorkspace.tsx |
| BlueprintWorkspace.onExport | onExport | 待映射 | 未实现 | 24 | src/components/BlueprintWorkspace.tsx |
| BlueprintWorkspace.onFocus | onFocus | 待映射 | 未实现 | 24 | src/components/BlueprintWorkspace.tsx |
| BlueprintWorkspace.onFundAllQueues | onFundAllQueues | 待映射 | 未实现 | 24 | src/components/BlueprintWorkspace.tsx |
| BlueprintWorkspace.onFundQueue | onFundQueue | 待映射 | 未实现 | 24 | src/components/BlueprintWorkspace.tsx |
| BlueprintWorkspace.onImport | onImport | 待映射 | 未实现 | 24 | src/components/BlueprintWorkspace.tsx |
| BlueprintWorkspace.onLock | onLock | 待映射 | 未实现 | 24 | src/components/BlueprintWorkspace.tsx |
| BlueprintWorkspace.onModeChange | onModeChange | 待映射 | 未实现 | 24 | src/components/BlueprintWorkspace.tsx |
| BlueprintWorkspace.onOpenBlueprints | onOpenBlueprints | 待映射 | 未实现 | 24 | src/components/BlueprintWorkspace.tsx |
| BlueprintWorkspace.onOpenNetworks | onOpenNetworks | 待映射 | 未实现 | 24 | src/components/BlueprintWorkspace.tsx |
| BlueprintWorkspace.onRecipeOverride | onRecipeOverride | 待映射 | 未实现 | 24 | src/components/BlueprintWorkspace.tsx |
| BlueprintWorkspace.onRedo | onRedo | 待映射 | 未实现 | 24 | src/components/BlueprintWorkspace.tsx |
| BlueprintWorkspace.onRegionModeChange | onRegionModeChange | 待映射 | 未实现 | 24 | src/components/BlueprintWorkspace.tsx |
| BlueprintWorkspace.onRemove | onRemove | 待映射 | 未实现 | 24 | src/components/BlueprintWorkspace.tsx |
| BlueprintWorkspace.onRename | onRename | 待映射 | 未实现 | 24 | src/components/BlueprintWorkspace.tsx |
| BlueprintWorkspace.onResizeStart | onResizeStart | 待映射 | 未实现 | 24 | src/components/BlueprintWorkspace.tsx |
| BlueprintWorkspace.onSelect | onSelect | 待映射 | 未实现 | 24 | src/components/BlueprintWorkspace.tsx |
| BlueprintWorkspace.onToggleLeftSidebar | onToggleLeftSidebar | 待映射 | 未实现 | 24 | src/components/BlueprintWorkspace.tsx |
| BlueprintWorkspace.onToggleLineFindMode | onToggleLineFindMode | 待映射 | 未实现 | 24 | src/components/BlueprintWorkspace.tsx |
| BlueprintWorkspace.onToggleRightSidebar | onToggleRightSidebar | 待映射 | 未实现 | 24 | src/components/BlueprintWorkspace.tsx |
| BlueprintWorkspace.onTransform | onTransform | 待映射 | 未实现 | 24 | src/components/BlueprintWorkspace.tsx |
| BlueprintWorkspace.onUndo | onUndo | 待映射 | 未实现 | 24 | src/components/BlueprintWorkspace.tsx |
| BlueprintWorkspace.onUndoAutoLayout | onUndoAutoLayout | 待映射 | 未实现 | 24 | src/components/BlueprintWorkspace.tsx |
| BlueprintWorkspace.onUnlock | onUnlock | 待映射 | 未实现 | 24 | src/components/BlueprintWorkspace.tsx |
| BlueprintWorkspace.onUpgrade | onUpgrade | 待映射 | 未实现 | 24 | src/components/BlueprintWorkspace.tsx |
| BlueprintWorkspace.onUpgradeBelts | onUpgradeBelts | 待映射 | 未实现 | 24 | src/components/BlueprintWorkspace.tsx |
| CampaignWorkspace.onClose | onClose | 待映射 | 未实现 | 25 | src/components/CampaignWorkspace.tsx |
| CampaignWorkspace.onNavigate | onNavigate | 待映射 | 未实现 | 25 | src/components/CampaignWorkspace.tsx |
| CampaignWorkspace.onSelectTask | onSelectTask | 待映射 | 未实现 | 25 | src/components/CampaignWorkspace.tsx |
| CanvasBeltLayer.onUnavailable | onUnavailable | 待映射 | 未实现 | 23 | src/components/CanvasBeltLayer.tsx |
| CanvasInteractionOverlay.onPointerPosition | onPointerPosition | 待映射 | 未实现 | 23 | src/components/CanvasInteractionOverlay.tsx |
| CanvasMiniMap.onCenter | onCenter | 待映射 | 未实现 | 23 | src/components/CanvasMiniMap.tsx |
| CanvasMiniMap.onUnavailable | onUnavailable | 待映射 | 未实现 | 23 | src/components/CanvasMiniMap.tsx |
| CanvasMiniMap.onZoom | onZoom | 待映射 | 未实现 | 23 | src/components/CanvasMiniMap.tsx |
| CatalogPicker.onChange | onChange | 待映射 | 未实现 | 23 | src/components/CatalogPicker.tsx |
| CloudAccountSecurity.onLoggedOut | onLoggedOut | 待映射 | 在线排除 | 23 | src/components/CloudAccountSecurity.tsx |
| CloudAccountSecurity.onUserChange | onUserChange | 待映射 | 在线排除 | 23 | src/components/CloudAccountSecurity.tsx |
| CloudSaveConflictDialog.onCancel | onCancel | 待映射 | 在线排除 | 20 | src/components/CloudSaveConflictDialog.tsx |
| CloudSaveConflictDialog.onExportCloud | onExportCloud | 待映射 | 在线排除 | 20 | src/components/CloudSaveConflictDialog.tsx |
| CloudSaveConflictDialog.onExportLocal | onExportLocal | 待映射 | 在线排除 | 20 | src/components/CloudSaveConflictDialog.tsx |
| CloudSaveConflictDialog.onKeepLocal | onKeepLocal | 待映射 | 在线排除 | 20 | src/components/CloudSaveConflictDialog.tsx |
| CloudSaveConflictDialog.onUseCloud | onUseCloud | 待映射 | 在线排除 | 20 | src/components/CloudSaveConflictDialog.tsx |
| CloudSaveSlotsPanel.onDelete | onDelete | 待映射 | 在线排除 | 20 | src/components/CloudSaveSlotsPanel.tsx |
| CloudSaveSlotsPanel.onDownload | onDownload | 待映射 | 在线排除 | 20 | src/components/CloudSaveSlotsPanel.tsx |
| CloudSaveSlotsPanel.onUpload | onUpload | 待映射 | 在线排除 | 20 | src/components/CloudSaveSlotsPanel.tsx |
| CloudSaveStatusCenter.onCancel | onCancel | 待映射 | 在线排除 | 20 | src/components/CloudSaveStatusCenter.tsx |
| CloudSaveStatusCenter.onExportCloud | onExportCloud | 待映射 | 在线排除 | 20 | src/components/CloudSaveStatusCenter.tsx |
| CloudSaveStatusCenter.onExportLocal | onExportLocal | 待映射 | 在线排除 | 20 | src/components/CloudSaveStatusCenter.tsx |
| CloudSaveStatusCenter.onRetry | onRetry | 待映射 | 在线排除 | 20 | src/components/CloudSaveStatusCenter.tsx |
| CodexSections.onChange | onChange | 待映射 | 未实现 | 23 | src/components/CodexSections.tsx |
| CodexSections.onQuery | onQuery | 待映射 | 未实现 | 23 | src/components/CodexSections.tsx |
| CodexSections.onSelect | onSelect | 待映射 | 未实现 | 23 | src/components/CodexSections.tsx |
| CodexSections.onSelectBuilding | onSelectBuilding | 待映射 | 未实现 | 23 | src/components/CodexSections.tsx |
| CodexSections.onSelectItem | onSelectItem | 待映射 | 未实现 | 23 | src/components/CodexSections.tsx |
| CodexSections.onSelectPlanet | onSelectPlanet | 待映射 | 未实现 | 26 | src/components/CodexSections.tsx |
| CodexSections.onSelectTechnology | onSelectTechnology | 待映射 | 未实现 | 25 | src/components/CodexSections.tsx |
| CommandPalette.onAutoLayout | onAutoLayout | scripts/game/FactoryAutoLayout.gd::apply | 实现中 | 23 | src/components/CommandPalette.tsx |
| CommandPalette.onClose | onClose | scenes/ui/CommandPalette.gd::_input | 实现中 | 23 | src/components/CommandPalette.tsx |
| CommandPalette.onFocusEntity | onFocusEntity | scenes/ui/FactoryWorkspaceUI.gd::_locate_entity | 实现中 | 23 | src/components/CommandPalette.tsx |
| CommandPalette.onFocusRecipe | onFocusRecipe | 待映射 | 未实现 | 23 | src/components/CommandPalette.tsx |
| CommandPalette.onOpenWorkspace | onOpenWorkspace | scenes/ui/FactoryWorkspaceUI.gd::open_command_palette | 实现中 | 23 | src/components/CommandPalette.tsx |
| CommandPalette.onPauseToggle | onPauseToggle | 待映射 | 未实现 | 23 | src/components/CommandPalette.tsx |
| CommandPalette.onTogglePerformance | onTogglePerformance | 待映射 | 未实现 | 23 | src/components/CommandPalette.tsx |
| CommandPalette.onToggleReducedMotion | onToggleReducedMotion | 待映射 | 未实现 | 23 | src/components/CommandPalette.tsx |
| ConstructionCenterWorkspace.onBatchTargetChange | onBatchTargetChange | 待映射 | 未实现 | 22 | src/components/ConstructionCenterWorkspace.tsx |
| ConstructionCenterWorkspace.onChange | onChange | 待映射 | 未实现 | 22 | src/components/ConstructionCenterWorkspace.tsx |
| ConstructionCenterWorkspace.onClose | onClose | 待映射 | 未实现 | 22 | src/components/ConstructionCenterWorkspace.tsx |
| ConstructionCenterWorkspace.onEnabledChange | onEnabledChange | 待映射 | 未实现 | 22 | src/components/ConstructionCenterWorkspace.tsx |
| ConstructionCenterWorkspace.onTargetChange | onTargetChange | 待映射 | 未实现 | 22 | src/components/ConstructionCenterWorkspace.tsx |
| DysonPlannerWorkspace.onAddLayer | onAddLayer | 待映射 | 未实现 | 26 | src/components/DysonPlannerWorkspace.tsx |
| DysonPlannerWorkspace.onAddNode | onAddNode | 待映射 | 未实现 | 26 | src/components/DysonPlannerWorkspace.tsx |
| DysonPlannerWorkspace.onAddStandardLayer | onAddStandardLayer | 待映射 | 未实现 | 26 | src/components/DysonPlannerWorkspace.tsx |
| DysonPlannerWorkspace.onAddSwarmOrbit | onAddSwarmOrbit | 待映射 | 未实现 | 26 | src/components/DysonPlannerWorkspace.tsx |
| DysonPlannerWorkspace.onAutoConnect | onAutoConnect | 待映射 | 未实现 | 26 | src/components/DysonPlannerWorkspace.tsx |
| DysonPlannerWorkspace.onClearShell | onClearShell | 待映射 | 未实现 | 26 | src/components/DysonPlannerWorkspace.tsx |
| DysonPlannerWorkspace.onClose | onClose | 待映射 | 未实现 | 26 | src/components/DysonPlannerWorkspace.tsx |
| DysonPlannerWorkspace.onConnectNodes | onConnectNodes | 待映射 | 未实现 | 26 | src/components/DysonPlannerWorkspace.tsx |
| DysonPlannerWorkspace.onLaunchEnabledChange | onLaunchEnabledChange | 待映射 | 未实现 | 26 | src/components/DysonPlannerWorkspace.tsx |
| DysonPlannerWorkspace.onLaunchModeChange | onLaunchModeChange | 待映射 | 未实现 | 26 | src/components/DysonPlannerWorkspace.tsx |
| DysonPlannerWorkspace.onLaunchThrottleChange | onLaunchThrottleChange | 待映射 | 未实现 | 26 | src/components/DysonPlannerWorkspace.tsx |
| DysonPlannerWorkspace.onOrbitChange | onOrbitChange | 待映射 | 未实现 | 26 | src/components/DysonPlannerWorkspace.tsx |
| DysonPlannerWorkspace.onPasteLayer | onPasteLayer | 待映射 | 未实现 | 26 | src/components/DysonPlannerWorkspace.tsx |
| DysonPlannerWorkspace.onPlanShell | onPlanShell | 待映射 | 未实现 | 26 | src/components/DysonPlannerWorkspace.tsx |
| DysonPlannerWorkspace.onRemoveLayer | onRemoveLayer | 待映射 | 未实现 | 26 | src/components/DysonPlannerWorkspace.tsx |
| DysonPlannerWorkspace.onRemoveNode | onRemoveNode | 待映射 | 未实现 | 26 | src/components/DysonPlannerWorkspace.tsx |
| DysonPlannerWorkspace.onRemoveSwarmOrbit | onRemoveSwarmOrbit | 待映射 | 未实现 | 26 | src/components/DysonPlannerWorkspace.tsx |
| DysonPlannerWorkspace.onSave | onSave | 待映射 | 未实现 | 26 | src/components/DysonPlannerWorkspace.tsx |
| DysonPlannerWorkspace.onSelectLayer | onSelectLayer | 待映射 | 未实现 | 26 | src/components/DysonPlannerWorkspace.tsx |
| DysonPlannerWorkspace.onSelectSwarmOrbit | onSelectSwarmOrbit | 待映射 | 未实现 | 26 | src/components/DysonPlannerWorkspace.tsx |
| DysonPlannerWorkspace.onSwarmOrbitChange | onSwarmOrbitChange | 待映射 | 未实现 | 26 | src/components/DysonPlannerWorkspace.tsx |
| engine.addBuildingToGroup | addBuildingToGroup | 待映射 | 未实现 | 23 | src/game/engine.ts |
| engine.addCanvasBookmark | addCanvasBookmark | 待映射 | 未实现 | 24 | src/game/engine.ts |
| engine.addCanvasRegion | addCanvasRegion | 待映射 | 未实现 | 24 | src/game/engine.ts |
| engine.addDysonLayer | addDysonLayer | 待映射 | 未实现 | 26 | src/game/engine.ts |
| engine.addDysonNode | addDysonNode | 待映射 | 未实现 | 26 | src/game/engine.ts |
| engine.addDysonSwarmOrbit | addDysonSwarmOrbit | 待映射 | 未实现 | 26 | src/game/engine.ts |
| engine.addUnitToEntityGroup | addUnitToEntityGroup | 待映射 | 未实现 | 23 | src/game/engine.ts |
| engine.adjustRemoteStationWarpers | adjustRemoteStationWarpers | 待映射 | 未实现 | 26 | src/game/engine.ts |
| engine.adjustStationDrones | adjustStationDrones | 待映射 | 未实现 | 26 | src/game/engine.ts |
| engine.adjustStationVessels | adjustStationVessels | 待映射 | 未实现 | 26 | src/game/engine.ts |
| engine.adjustStationWarpers | adjustStationWarpers | 待映射 | 未实现 | 26 | src/game/engine.ts |
| engine.advanceSimulation | advanceSimulation | 待映射 | 未实现 | 26 | src/game/engine.ts |
| engine.advanceSimulationBudget | advanceSimulationBudget | 待映射 | 未实现 | 26 | src/game/engine.ts |
| engine.applyBeltConfiguration | applyBeltConfiguration | scripts/game/GameState.gd::apply_belt_configuration | 实现中 | 23 | src/game/engine.ts |
| engine.applyBeltConfigurationToBelts | applyBeltConfigurationToBelts | scripts/game/GameState.gd::try_configure_belts | 实现中 | 23 | src/game/engine.ts |
| engine.applyBeltConfigurationToNetwork | applyBeltConfigurationToNetwork | scripts/game/GameState.gd::apply_belt_configuration_to_network | 实现中 | 23 | src/game/engine.ts |
| engine.applyBeltConfigurationToNetworkResult | applyBeltConfigurationToNetworkResult | scripts/game/GameState.gd::apply_belt_configuration_to_network | 实现中 | 23 | src/game/engine.ts |
| engine.applyStationSlotTemplateToEntities | applyStationSlotTemplateToEntities | 待映射 | 未实现 | 26 | src/game/engine.ts |
| engine.attachAllInterstellarStationsToQuantumNetwork | attachAllInterstellarStationsToQuantumNetwork | 待映射 | 未实现 | 26 | src/game/engine.ts |
| engine.attachInterstellarStationToQuantumNetwork | attachInterstellarStationToQuantumNetwork | 待映射 | 未实现 | 26 | src/game/engine.ts |
| engine.autoConnectDysonLayer | autoConnectDysonLayer | 待映射 | 未实现 | 26 | src/game/engine.ts |
| engine.batchIncreaseSelection | batchIncreaseSelection | 待映射 | 未实现 | 23 | src/game/engine.ts |
| engine.cancelConstructionQueueEntry | cancelConstructionQueueEntry | 待映射 | 未实现 | 24 | src/game/engine.ts |
| engine.cancelCurrentResearch | cancelCurrentResearch | 待映射 | 未实现 | 25 | src/game/engine.ts |
| engine.cancelHandcraftQueueEntry | cancelHandcraftQueueEntry | scripts/game/ConstructionAutomationSystem.gd::cancel | 实现中 | 22 | src/game/engine.ts |
| engine.cancelQuantumStationAttachment | cancelQuantumStationAttachment | 待映射 | 未实现 | 26 | src/game/engine.ts |
| engine.canColonizePlanet | canColonizePlanet | 待映射 | 未实现 | 26 | src/game/engine.ts |
| engine.canConnectBelt | canConnectBelt | 待映射 | 未实现 | 23 | src/game/engine.ts |
| engine.canCraftConstruction | canCraftConstruction | scripts/game/CraftingPlanner.gd::plan | 实现中 | 22 | src/game/engine.ts |
| engine.canEntityAcceptBeltItem | canEntityAcceptBeltItem | 待映射 | 未实现 | 23 | src/game/engine.ts |
| engine.canExploreStarSystem | canExploreStarSystem | 待映射 | 未实现 | 23 | src/game/engine.ts |
| engine.canHandcraftRecipe | canHandcraftRecipe | scripts/game/CraftingPlanner.gd::plan | 实现中 | 22 | src/game/engine.ts |
| engine.canInstallSprayCoater | canInstallSprayCoater | scripts/game/ProliferatorSystem.gd::eligible | 实现中 | 22 | src/game/engine.ts |
| engine.canPlaceBlueprint | canPlaceBlueprint | 待映射 | 未实现 | 24 | src/game/engine.ts |
| engine.canQueueBlueprint | canQueueBlueprint | 待映射 | 未实现 | 24 | src/game/engine.ts |
| engine.canQueueHandcraftRecipe | canQueueHandcraftRecipe | scripts/game/CraftingPlanner.gd::plan | 实现中 | 22 | src/game/engine.ts |
| engine.canQueueTechnology | canQueueTechnology | 待映射 | 未实现 | 25 | src/game/engine.ts |
| engine.canSelectTechnology | canSelectTechnology | 待映射 | 未实现 | 25 | src/game/engine.ts |
| engine.canSetBeltStackSize | canSetBeltStackSize | 待映射 | 未实现 | 23 | src/game/engine.ts |
| engine.canUpgradeBelt | canUpgradeBelt | 待映射 | 未实现 | 23 | src/game/engine.ts |
| engine.canUpgradeEntities | canUpgradeEntities | 待映射 | 未实现 | 23 | src/game/engine.ts |
| engine.canUpgradeEntity | canUpgradeEntity | 待映射 | 未实现 | 23 | src/game/engine.ts |
| engine.canUpgradeSorter | canUpgradeSorter | 待映射 | 未实现 | 23 | src/game/engine.ts |
| engine.clearDysonShells | clearDysonShells | 待映射 | 未实现 | 26 | src/game/engine.ts |
| engine.clearOrbitalCargoPort | clearOrbitalCargoPort | 待映射 | 未实现 | 23 | src/game/engine.ts |
| engine.colonizePlanet | colonizePlanet | 待映射 | 未实现 | 26 | src/game/engine.ts |
| engine.completeSimulationStep | completeSimulationStep | 待映射 | 未实现 | 26 | src/game/engine.ts |
| engine.connectBelt | connectBelt | 待映射 | 未实现 | 23 | src/game/engine.ts |
| engine.connectBeltsAtomically | connectBeltsAtomically | scripts/game/GameState.gd::try_add_connections | 实现中 | 23 | src/game/engine.ts |
| engine.connectBeltWithResult | connectBeltWithResult | scripts/game/GameState.gd::try_add_connection | 实现中 | 23 | src/game/engine.ts |
| engine.connectDysonNodes | connectDysonNodes | 待映射 | 未实现 | 26 | src/game/engine.ts |
| engine.craftConstruction | craftConstruction | scripts/game/ConstructionAutomationSystem.gd::queue | 实现中 | 22 | src/game/engine.ts |
| engine.craftConstructionWithUpstream | craftConstructionWithUpstream | scripts/game/ConstructionAutomationSystem.gd::queue | 实现中 | 22 | src/game/engine.ts |
| engine.createBlueprint | createBlueprint | 待映射 | 未实现 | 24 | src/game/engine.ts |
| engine.createPersistentSimulationRuntime | createPersistentSimulationRuntime | 待映射 | 未实现 | 26 | src/game/engine.ts |
| engine.createSimulationAdvanceSession | createSimulationAdvanceSession | 待映射 | 未实现 | 26 | src/game/engine.ts |
| engine.createSimulationLookupContext | createSimulationLookupContext | 待映射 | 未实现 | 26 | src/game/engine.ts |
| engine.createSimulationPlanetPhaseLookup | createSimulationPlanetPhaseLookup | 待映射 | 未实现 | 26 | src/game/engine.ts |
| engine.createStandardDysonLayer | createStandardDysonLayer | 待映射 | 未实现 | 26 | src/game/engine.ts |
| engine.discardConstructionInventory | discardConstructionInventory | 待映射 | 未实现 | 23 | src/game/engine.ts |
| engine.discardPlanetTrayItems | discardPlanetTrayItems | 待映射 | 未实现 | 26 | src/game/engine.ts |
| engine.dispatchGalacticExport | dispatchGalacticExport | 待映射 | 未实现 | 26 | src/game/engine.ts |
| engine.dropCargoToEntity | dropCargoToEntity | 待映射 | 未实现 | 23 | src/game/engine.ts |
| engine.dropCargoToTray | dropCargoToTray | 待映射 | 未实现 | 23 | src/game/engine.ts |
| engine.ensureSimulationDynamicRouteLookup | ensureSimulationDynamicRouteLookup | 待映射 | 未实现 | 26 | src/game/engine.ts |
| engine.exploreStarSystem | exploreStarSystem | 待映射 | 未实现 | 23 | src/game/engine.ts |
| engine.fillStationFleet | fillStationFleet | 待映射 | 未实现 | 26 | src/game/engine.ts |
| engine.findInterstellarPeer | findInterstellarPeer | 待映射 | 未实现 | 23 | src/game/engine.ts |
| engine.findPlanetaryPeer | findPlanetaryPeer | 待映射 | 未实现 | 26 | src/game/engine.ts |
| engine.findStationSlotPeer | findStationSlotPeer | 待映射 | 未实现 | 26 | src/game/engine.ts |
| engine.findStationSlotPeers | findStationSlotPeers | 待映射 | 未实现 | 26 | src/game/engine.ts |
| engine.fundAllConstructionQueueEntries | fundAllConstructionQueueEntries | 待映射 | 未实现 | 24 | src/game/engine.ts |
| engine.fundConstructionQueueEntry | fundConstructionQueueEntry | 待映射 | 未实现 | 24 | src/game/engine.ts |
| engine.getBeltConnectionCheck | getBeltConnectionCheck | scripts/game/GameState.gd::preview_connections | 实现中 | 23 | src/game/engine.ts |
| engine.getBeltLaneAdjustmentCheck | getBeltLaneAdjustmentCheck | scripts/game/GameState.gd::try_adjust_belt_lanes | 实现中 | 23 | src/game/engine.ts |
| engine.getBeltNetworkIds | getBeltNetworkIds | 待映射 | 未实现 | 23 | src/game/engine.ts |
| engine.getBlueprintEligibleEntityIds | getBlueprintEligibleEntityIds | 待映射 | 未实现 | 24 | src/game/engine.ts |
| engine.getBlueprintFleetLoadPreview | getBlueprintFleetLoadPreview | 待映射 | 未实现 | 24 | src/game/engine.ts |
| engine.getBlueprintPlacementPreview | getBlueprintPlacementPreview | 待映射 | 未实现 | 24 | src/game/engine.ts |
| engine.getColonizationRequirements | getColonizationRequirements | scripts/game/PlanetSystem.gd::get_colonization_requirements | 实现中 | 23 | src/game/engine.ts |
| engine.getConstructionAutomationCycleSeconds | getConstructionAutomationCycleSeconds | 待映射 | 未实现 | 23 | src/game/engine.ts |
| engine.getConstructionAutomationMaterialSeconds | getConstructionAutomationMaterialSeconds | 待映射 | 未实现 | 23 | src/game/engine.ts |
| engine.getConstructionAutomationStatus | getConstructionAutomationStatus | 待映射 | 未实现 | 23 | src/game/engine.ts |
| engine.getConstructionAutomationStockLimit | getConstructionAutomationStockLimit | 待映射 | 未实现 | 23 | src/game/engine.ts |
| engine.getConstructionCenterTraceSample | getConstructionCenterTraceSample | 待映射 | 未实现 | 22 | src/game/engine.ts |
| engine.getConstructionCraftDeficits | getConstructionCraftDeficits | scripts/game/CraftingPlanner.gd::plan | 实现中 | 22 | src/game/engine.ts |
| engine.getConstructionCraftNavigation | getConstructionCraftNavigation | 待映射 | 未实现 | 22 | src/game/engine.ts |
| engine.getConstructionQueueDeficits | getConstructionQueueDeficits | 待映射 | 未实现 | 24 | src/game/engine.ts |
| engine.getConstructionQueueDetails | getConstructionQueueDetails | 待映射 | 未实现 | 24 | src/game/engine.ts |
| engine.getConstructionQuickCraftPlan | getConstructionQuickCraftPlan | scripts/game/CraftingPlanner.gd::plan | 实现中 | 22 | src/game/engine.ts |
| engine.getDysonEngineeringSnapshot | getDysonEngineeringSnapshot | 待映射 | 未实现 | 26 | src/game/engine.ts |
| engine.getDysonSailAbsorptionMultiplier | getDysonSailAbsorptionMultiplier | 待映射 | 未实现 | 26 | src/game/engine.ts |
| engine.getDysonShellCapacity | getDysonShellCapacity | 待映射 | 未实现 | 26 | src/game/engine.ts |
| engine.getEffectiveSimulationMultiplier | getEffectiveSimulationMultiplier | 待映射 | 未实现 | 26 | src/game/engine.ts |
| engine.getEjectorOrbitTargetStatus | getEjectorOrbitTargetStatus | 待映射 | 未实现 | 23 | src/game/engine.ts |
| engine.getEntityBufferLimit | getEntityBufferLimit | scripts/game/GameState.gd::get_entity_buffer_limit | 实现中 | 23 | src/game/engine.ts |
| engine.getEntityCycleRatePerSimulationSecond | getEntityCycleRatePerSimulationSecond | 待映射 | 未实现 | 26 | src/game/engine.ts |
| engine.getEntityInputCapacity | getEntityInputCapacity | scripts/game/GameState.gd::get_entity_input_capacity | 实现中 | 23 | src/game/engine.ts |
| engine.getEntityItemInputCapacity | getEntityItemInputCapacity | 待映射 | 未实现 | 23 | src/game/engine.ts |
| engine.getEntityOperatingStatus | getEntityOperatingStatus | 待映射 | 未实现 | 23 | src/game/engine.ts |
| engine.getEntityOutputCapacity | getEntityOutputCapacity | scripts/game/GameState.gd::get_entity_output_capacity | 实现中 | 23 | src/game/engine.ts |
| engine.getEntityPowerFactor | getEntityPowerFactor | scripts/game/GameState.gd::get_entity_power_factor | 实现中 | 21 | src/game/engine.ts |
| engine.getEntityRecipeCycleCapacityPerSimulationSecond | getEntityRecipeCycleCapacityPerSimulationSecond | 待映射 | 未实现 | 26 | src/game/engine.ts |
| engine.getEntityRemovalPreview | getEntityRemovalPreview | 待映射 | 未实现 | 23 | src/game/engine.ts |
| engine.getEntityStackTargetCheck | getEntityStackTargetCheck | 待映射 | 未实现 | 23 | src/game/engine.ts |
| engine.getGalacticIndustrySnapshot | getGalacticIndustrySnapshot | 待映射 | 未实现 | 26 | src/game/engine.ts |
| engine.getIndustrialEfficiencyMultiplier | getIndustrialEfficiencyMultiplier | 待映射 | 未实现 | 23 | src/game/engine.ts |
| engine.getInfiniteResourceCollectionSpeedMultiplier | getInfiniteResourceCollectionSpeedMultiplier | 待映射 | 未实现 | 23 | src/game/engine.ts |
| engine.getInterstellarCargoCapacity | getInterstellarCargoCapacity | 待映射 | 未实现 | 23 | src/game/engine.ts |
| engine.getInterstellarRouteEconomics | getInterstellarRouteEconomics | 待映射 | 未实现 | 23 | src/game/engine.ts |
| engine.getInterstellarTripSeconds | getInterstellarTripSeconds | 待映射 | 未实现 | 23 | src/game/engine.ts |
| engine.getLogisticsSpeedMultiplier | getLogisticsSpeedMultiplier | 待映射 | 未实现 | 23 | src/game/engine.ts |
| engine.getMaterialDeliverySlotChangeCheck | getMaterialDeliverySlotChangeCheck | 待映射 | 未实现 | 23 | src/game/engine.ts |
| engine.getMaxConstructionQuickCraftBatches | getMaxConstructionQuickCraftBatches | 待映射 | 未实现 | 22 | src/game/engine.ts |
| engine.getMaxHandcraftBatches | getMaxHandcraftBatches | 待映射 | 未实现 | 22 | src/game/engine.ts |
| engine.getMaxRecursiveHandcraftBatches | getMaxRecursiveHandcraftBatches | 待映射 | 未实现 | 22 | src/game/engine.ts |
| engine.getMiningSpeedMultiplier | getMiningSpeedMultiplier | 待映射 | 未实现 | 23 | src/game/engine.ts |
| engine.getOrbitalCargoPortClearCheck | getOrbitalCargoPortClearCheck | 待映射 | 未实现 | 23 | src/game/engine.ts |
| engine.getOrbitalCollectorQuantumStatus | getOrbitalCollectorQuantumStatus | 待映射 | 未实现 | 26 | src/game/engine.ts |
| engine.getPlanetaryCargoCapacity | getPlanetaryCargoCapacity | 待映射 | 未实现 | 26 | src/game/engine.ts |
| engine.getPlanetaryTripSeconds | getPlanetaryTripSeconds | 待映射 | 未实现 | 26 | src/game/engine.ts |
| engine.getPlanetMetrics | getPlanetMetrics | 待映射 | 未实现 | 26 | src/game/engine.ts |
| engine.getPlanetTrayItemFreeCapacity | getPlanetTrayItemFreeCapacity | 待映射 | 未实现 | 26 | src/game/engine.ts |
| engine.getPlanetTrayItemLimit | getPlanetTrayItemLimit | 待映射 | 未实现 | 26 | src/game/engine.ts |
| engine.getPowerGridMetrics | getPowerGridMetrics | scripts/game/PowerSystem.gd::get_grid_info | 实现中 | 21 | src/game/engine.ts |
| engine.getQuantumAttachmentStatus | getQuantumAttachmentStatus | 待映射 | 未实现 | 26 | src/game/engine.ts |
| engine.getRayReceiverCapacityKw | getRayReceiverCapacityKw | 待映射 | 未实现 | 23 | src/game/engine.ts |
| engine.getRecipeCompatibleEntityIds | getRecipeCompatibleEntityIds | 待映射 | 未实现 | 23 | src/game/engine.ts |
| engine.getRecipeSpeedMultiplier | getRecipeSpeedMultiplier | 待映射 | 未实现 | 23 | src/game/engine.ts |
| engine.getRecursiveHandcraftPlan | getRecursiveHandcraftPlan | scripts/game/CraftingPlanner.gd::plan | 实现中 | 22 | src/game/engine.ts |
| engine.getResourceReserveSnapshot | getResourceReserveSnapshot | 待映射 | 未实现 | 26 | src/game/engine.ts |
| engine.getSolarSailLifetimeSeconds | getSolarSailLifetimeSeconds | 待映射 | 未实现 | 23 | src/game/engine.ts |
| engine.getSprayCoaterInstallCheck | getSprayCoaterInstallCheck | 待映射 | 未实现 | 22 | src/game/engine.ts |
| engine.getSprayCoaterRemovalRefund | getSprayCoaterRemovalRefund | scripts/game/ProliferatorSystem.gd::_refund | 实现中 | 22 | src/game/engine.ts |
| engine.getStationActiveRoutes | getStationActiveRoutes | 待映射 | 未实现 | 26 | src/game/engine.ts |
| engine.getStationBusyVehicleCount | getStationBusyVehicleCount | 待映射 | 未实现 | 26 | src/game/engine.ts |
| engine.getStationFleetDiagnostic | getStationFleetDiagnostic | 待映射 | 未实现 | 26 | src/game/engine.ts |
| engine.getStationMinimumCargo | getStationMinimumCargo | 待映射 | 未实现 | 26 | src/game/engine.ts |
| engine.getStationSlotCapacity | getStationSlotCapacity | 待映射 | 未实现 | 26 | src/game/engine.ts |
| engine.getStationTemplateCompatibleEntityIds | getStationTemplateCompatibleEntityIds | 待映射 | 未实现 | 26 | src/game/engine.ts |
| engine.getStationWarperRefillSnapshot | getStationWarperRefillSnapshot | 待映射 | 未实现 | 26 | src/game/engine.ts |
| engine.getVeinConsumptionMultiplier | getVeinConsumptionMultiplier | 待映射 | 未实现 | 23 | src/game/engine.ts |
| engine.handcraftRecipe | handcraftRecipe | scripts/game/ConstructionAutomationSystem.gd::queue | 实现中 | 22 | src/game/engine.ts |
| engine.handcraftRecipeWithUpstream | handcraftRecipeWithUpstream | scripts/game/ConstructionAutomationSystem.gd::queue | 实现中 | 22 | src/game/engine.ts |
| engine.hasActiveResearch | hasActiveResearch | 待映射 | 未实现 | 25 | src/game/engine.ts |
| engine.hasBlueprintExactOverlap | hasBlueprintExactOverlap | 待映射 | 未实现 | 24 | src/game/engine.ts |
| engine.hasExactEntityPositionOverlap | hasExactEntityPositionOverlap | 待映射 | 未实现 | 23 | src/game/engine.ts |
| engine.installMiner | installMiner | 待映射 | 未实现 | 23 | src/game/engine.ts |
| engine.installSprayCoater | installSprayCoater | scripts/game/ProliferatorSystem.gd::configure | 实现中 | 22 | src/game/engine.ts |
| engine.installSprayCoaters | installSprayCoaters | scripts/game/ProliferatorSystem.gd::configure_batch | 实现中 | 22 | src/game/engine.ts |
| engine.investInfiniteResearchBudgetInPlace | investInfiniteResearchBudgetInPlace | 待映射 | 未实现 | 25 | src/game/engine.ts |
| engine.isEntityInPowerCoverage | isEntityInPowerCoverage | 待映射 | 未实现 | 21 | src/game/engine.ts |
| engine.isEntityInteractionLocked | isEntityInteractionLocked | scripts/game/GameState.gd::is_entity_interaction_locked | 实现中 | 23 | src/game/engine.ts |
| engine.isPlanetColonized | isPlanetColonized | 待映射 | 未实现 | 26 | src/game/engine.ts |
| engine.isStarSystemUnlocked | isStarSystemUnlocked | 待映射 | 未实现 | 23 | src/game/engine.ts |
| engine.isTechnologyCompleted | isTechnologyCompleted | scripts/game/GameState.gd::is_technology_completed, scripts/game/TechnologySystem.gd::is_technology_completed | 实现中 | 25 | src/game/engine.ts |
| engine.manualMine | manualMine | 待映射 | 未实现 | 23 | src/game/engine.ts |
| engine.mergeSimulationPlanetPhaseResults | mergeSimulationPlanetPhaseResults | 待映射 | 未实现 | 26 | src/game/engine.ts |
| engine.moveEntities | moveEntities | scripts/game/GameState.gd::move_entities | 实现中 | 23 | src/game/engine.ts |
| engine.moveEntity | moveEntity | scripts/game/GameState.gd::move_entity | 实现中 | 23 | src/game/engine.ts |
| engine.moveEntityInputToEntity | moveEntityInputToEntity | 待映射 | 未实现 | 23 | src/game/engine.ts |
| engine.moveEntityInputToTray | moveEntityInputToTray | 待映射 | 未实现 | 23 | src/game/engine.ts |
| engine.moveEntityOutputToEntity | moveEntityOutputToEntity | 待映射 | 未实现 | 23 | src/game/engine.ts |
| engine.moveEntityOutputToTray | moveEntityOutputToTray | 待映射 | 未实现 | 23 | src/game/engine.ts |
| engine.moveTrayItemToEntity | moveTrayItemToEntity | 待映射 | 未实现 | 23 | src/game/engine.ts |
| engine.pasteDysonLayerTemplate | pasteDysonLayerTemplate | 待映射 | 未实现 | 26 | src/game/engine.ts |
| engine.pauseCurrentResearch | pauseCurrentResearch | 待映射 | 未实现 | 25 | src/game/engine.ts |
| engine.pickFromEntity | pickFromEntity | 待映射 | 未实现 | 23 | src/game/engine.ts |
| engine.pickFromEntityInput | pickFromEntityInput | 待映射 | 未实现 | 23 | src/game/engine.ts |
| engine.pickFromTray | pickFromTray | 待映射 | 未实现 | 23 | src/game/engine.ts |
| engine.placeBlueprint | placeBlueprint | 待映射 | 未实现 | 24 | src/game/engine.ts |
| engine.placeBuilding | placeBuilding | 待映射 | 未实现 | 23 | src/game/engine.ts |
| engine.planDysonShell | planDysonShell | 待映射 | 未实现 | 26 | src/game/engine.ts |
| engine.prepareSimulationStep | prepareSimulationStep | 待映射 | 未实现 | 26 | src/game/engine.ts |
| engine.processConstructionQueue | processConstructionQueue | 待映射 | 未实现 | 24 | src/game/engine.ts |
| engine.queueBlueprint | queueBlueprint | 待映射 | 未实现 | 24 | src/game/engine.ts |
| engine.queueHandcraftRecipe | queueHandcraftRecipe | scripts/game/ConstructionAutomationSystem.gd::queue | 实现中 | 22 | src/game/engine.ts |
| engine.refillStationWarpers | refillStationWarpers | 待映射 | 未实现 | 26 | src/game/engine.ts |
| engine.refreshDysonGenerationSnapshot | refreshDysonGenerationSnapshot | 待映射 | 未实现 | 26 | src/game/engine.ts |
| engine.refreshTimeWarpPowerSnapshot | refreshTimeWarpPowerSnapshot | 待映射 | 未实现 | 26 | src/game/engine.ts |
| engine.refreshTimeWarpPowerSnapshotInPlace | refreshTimeWarpPowerSnapshotInPlace | 待映射 | 未实现 | 26 | src/game/engine.ts |
| engine.removeBelt | removeBelt | 待映射 | 未实现 | 23 | src/game/engine.ts |
| engine.removeBeltNetwork | removeBeltNetwork | 待映射 | 未实现 | 23 | src/game/engine.ts |
| engine.removeBlueprint | removeBlueprint | 待映射 | 未实现 | 24 | src/game/engine.ts |
| engine.removeCanvasBookmark | removeCanvasBookmark | 待映射 | 未实现 | 24 | src/game/engine.ts |
| engine.removeCanvasRegion | removeCanvasRegion | 待映射 | 未实现 | 24 | src/game/engine.ts |
| engine.removeDysonLayer | removeDysonLayer | 待映射 | 未实现 | 26 | src/game/engine.ts |
| engine.removeDysonNode | removeDysonNode | 待映射 | 未实现 | 26 | src/game/engine.ts |
| engine.removeDysonSwarmOrbit | removeDysonSwarmOrbit | 待映射 | 未实现 | 26 | src/game/engine.ts |
| engine.removeEntities | removeEntities | scripts/game/GameState.gd::remove_entities | 实现中 | 23 | src/game/engine.ts |
| engine.removeEntity | removeEntity | 待映射 | 未实现 | 23 | src/game/engine.ts |
| engine.removeQueuedTechnology | removeQueuedTechnology | 待映射 | 未实现 | 25 | src/game/engine.ts |
| engine.removeSprayCoater | removeSprayCoater | scripts/game/ProliferatorSystem.gd::remove | 实现中 | 22 | src/game/engine.ts |
| engine.renameBlueprint | renameBlueprint | 待映射 | 未实现 | 24 | src/game/engine.ts |
| engine.renameCanvasBookmark | renameCanvasBookmark | 待映射 | 未实现 | 24 | src/game/engine.ts |
| engine.resizeCanvasRegion | resizeCanvasRegion | 待映射 | 未实现 | 24 | src/game/engine.ts |
| engine.resumePausedResearch | resumePausedResearch | 待映射 | 未实现 | 25 | src/game/engine.ts |
| engine.runPlanetSimulationPhase | runPlanetSimulationPhase | 待映射 | 未实现 | 26 | src/game/engine.ts |
| engine.selectInfiniteResearch | selectInfiniteResearch | 待映射 | 未实现 | 25 | src/game/engine.ts |
| engine.selectTechnology | selectTechnology | 待映射 | 未实现 | 25 | src/game/engine.ts |
| engine.setActiveDysonLayer | setActiveDysonLayer | 待映射 | 未实现 | 26 | src/game/engine.ts |
| engine.setActiveDysonSwarmOrbit | setActiveDysonSwarmOrbit | 待映射 | 未实现 | 26 | src/game/engine.ts |
| engine.setActivePlanet | setActivePlanet | scripts/game/GameState.gd::set_active_planet | 实现中 | 26 | src/game/engine.ts |
| engine.setAllOrbitalCollectorsQuantumMode | setAllOrbitalCollectorsQuantumMode | 待映射 | 未实现 | 26 | src/game/engine.ts |
| engine.setBeltLaneCount | setBeltLaneCount | scripts/game/GameState.gd::set_belt_lane_count | 实现中 | 23 | src/game/engine.ts |
| engine.setBeltMonitorEnabled | setBeltMonitorEnabled | scripts/game/GameState.gd::set_belt_monitor_enabled | 实现中 | 23 | src/game/engine.ts |
| engine.setBeltNetworkRouteMode | setBeltNetworkRouteMode | scripts/game/GameState.gd::set_belt_network_route_mode | 实现中 | 23 | src/game/engine.ts |
| engine.setBeltPriority | setBeltPriority | scripts/game/GameState.gd::set_belt_priority | 实现中 | 23 | src/game/engine.ts |
| engine.setBeltRouteMode | setBeltRouteMode | scripts/game/GameState.gd::set_belt_route_mode | 实现中 | 23 | src/game/engine.ts |
| engine.setBeltRouteOffsetY | setBeltRouteOffsetY | scripts/game/GameState.gd::set_belt_route_offset_y | 实现中 | 23 | src/game/engine.ts |
| engine.setBeltStackSize | setBeltStackSize | scripts/game/GameState.gd::set_belt_stack_size | 实现中 | 23 | src/game/engine.ts |
| engine.setBlackHolePaused | setBlackHolePaused | 待映射 | 未实现 | 26 | src/game/engine.ts |
| engine.setBlueprintRecipeOverride | setBlueprintRecipeOverride | 待映射 | 未实现 | 24 | src/game/engine.ts |
| engine.setBlueprintTransform | setBlueprintTransform | 待映射 | 未实现 | 24 | src/game/engine.ts |
| engine.setConstructionAutomationEnabled | setConstructionAutomationEnabled | 待映射 | 未实现 | 23 | src/game/engine.ts |
| engine.setConstructionAutomationTarget | setConstructionAutomationTarget | 待映射 | 未实现 | 23 | src/game/engine.ts |
| engine.setConstructionAutomationTargetsForBuildings | setConstructionAutomationTargetsForBuildings | 待映射 | 未实现 | 23 | src/game/engine.ts |
| engine.setDysonLaunchEnabled | setDysonLaunchEnabled | 待映射 | 未实现 | 26 | src/game/engine.ts |
| engine.setDysonLaunchMode | setDysonLaunchMode | 待映射 | 未实现 | 26 | src/game/engine.ts |
| engine.setDysonLaunchThrottle | setDysonLaunchThrottle | 待映射 | 未实现 | 26 | src/game/engine.ts |
| engine.setDysonLayerOrbit | setDysonLayerOrbit | 待映射 | 未实现 | 26 | src/game/engine.ts |
| engine.setDysonSwarmOrbit | setDysonSwarmOrbit | 待映射 | 未实现 | 26 | src/game/engine.ts |
| engine.setEjectorTargetOrbit | setEjectorTargetOrbit | 待映射 | 未实现 | 23 | src/game/engine.ts |
| engine.setEjectorTargetOrbitForEntities | setEjectorTargetOrbitForEntities | 待映射 | 未实现 | 23 | src/game/engine.ts |
| engine.setEnergyMode | setEnergyMode | scripts/game/GameState.gd::set_energy_mode | 实现中 | 21 | src/game/engine.ts |
| engine.setEntitiesInteractionLocked | setEntitiesInteractionLocked | scripts/game/GameState.gd::set_entities_interaction_locked | 实现中 | 23 | src/game/engine.ts |
| engine.setEntitiesProliferatorConfiguration | setEntitiesProliferatorConfiguration | scripts/game/ProliferatorSystem.gd::configure_batch | 实现中 | 22 | src/game/engine.ts |
| engine.setEntitiesRecipe | setEntitiesRecipe | scripts/game/GameState.gd::set_entities_recipe | 实现中 | 23 | src/game/engine.ts |
| engine.setEntityGenerationPriority | setEntityGenerationPriority | scripts/game/GameState.gd::set_entity_generation_priority | 实现中 | 21 | src/game/engine.ts |
| engine.setEntityPowerGrid | setEntityPowerGrid | scripts/game/GameState.gd::set_entity_power_grid | 实现中 | 21 | src/game/engine.ts |
| engine.setEntityPowerPriority | setEntityPowerPriority | scripts/game/GameState.gd::set_entity_power_priority | 实现中 | 21 | src/game/engine.ts |
| engine.setEntityRecipe | setEntityRecipe | scripts/game/GameState.gd::set_entity_recipe | 实现中 | 23 | src/game/engine.ts |
| engine.setEntityStackTarget | setEntityStackTarget | 待映射 | 未实现 | 23 | src/game/engine.ts |
| engine.setFuelItem | setFuelItem | 待映射 | 未实现 | 21 | src/game/engine.ts |
| engine.setGalacticDispatchAutomation | setGalacticDispatchAutomation | 待映射 | 未实现 | 26 | src/game/engine.ts |
| engine.setGalacticDispatchThrottle | setGalacticDispatchThrottle | 待映射 | 未实现 | 26 | src/game/engine.ts |
| engine.setGalacticExportEnabled | setGalacticExportEnabled | 待映射 | 未实现 | 26 | src/game/engine.ts |
| engine.setGalacticExportPriority | setGalacticExportPriority | 待映射 | 未实现 | 26 | src/game/engine.ts |
| engine.setGalacticMaterialExporterPaused | setGalacticMaterialExporterPaused | 待映射 | 未实现 | 26 | src/game/engine.ts |
| engine.setInfiniteResearchAutomation | setInfiniteResearchAutomation | 待映射 | 未实现 | 25 | src/game/engine.ts |
| engine.setLogisticsItem | setLogisticsItem | 待映射 | 未实现 | 23 | src/game/engine.ts |
| engine.setMaterialDeliverySlot | setMaterialDeliverySlot | 待映射 | 未实现 | 23 | src/game/engine.ts |
| engine.setOrbitalCollectorQuantumMode | setOrbitalCollectorQuantumMode | 待映射 | 未实现 | 26 | src/game/engine.ts |
| engine.setPaused | setPaused | 待映射 | 未实现 | 23 | src/game/engine.ts |
| engine.setPlanetDisplayMetadata | setPlanetDisplayMetadata | 待映射 | 未实现 | 26 | src/game/engine.ts |
| engine.setPlanetIndustryRole | setPlanetIndustryRole | 待映射 | 未实现 | 26 | src/game/engine.ts |
| engine.setPlanetTrayItemLimit | setPlanetTrayItemLimit | 待映射 | 未实现 | 26 | src/game/engine.ts |
| engine.setProliferatorConfiguration | setProliferatorConfiguration | scripts/game/ProliferatorSystem.gd::configure | 实现中 | 22 | src/game/engine.ts |
| engine.setQuantumLogisticsItemCapacity | setQuantumLogisticsItemCapacity | 待映射 | 未实现 | 26 | src/game/engine.ts |
| engine.setRecipeFocus | setRecipeFocus | 待映射 | 未实现 | 22 | src/game/engine.ts |
| engine.setRecipeFocusMode | setRecipeFocusMode | 待映射 | 未实现 | 22 | src/game/engine.ts |
| engine.setRecipeFocusPosition | setRecipeFocusPosition | 待映射 | 未实现 | 22 | src/game/engine.ts |
| engine.setRemoteBuildingStackTarget | setRemoteBuildingStackTarget | 待映射 | 未实现 | 23 | src/game/engine.ts |
| engine.setRemoteStationFleetTarget | setRemoteStationFleetTarget | 待映射 | 未实现 | 26 | src/game/engine.ts |
| engine.setRemoteStationSlotItem | setRemoteStationSlotItem | 待映射 | 未实现 | 26 | src/game/engine.ts |
| engine.setSplitterMode | setSplitterMode | 待映射 | 未实现 | 22 | src/game/engine.ts |
| engine.setStarSystemDisplayName | setStarSystemDisplayName | 待映射 | 未实现 | 23 | src/game/engine.ts |
| engine.setStationFleetTarget | setStationFleetTarget | 待映射 | 未实现 | 26 | src/game/engine.ts |
| engine.setStationHubConfiguration | setStationHubConfiguration | 待映射 | 未实现 | 26 | src/game/engine.ts |
| engine.setStationMinimumLoad | setStationMinimumLoad | 待映射 | 未实现 | 26 | src/game/engine.ts |
| engine.setStationMode | setStationMode | 待映射 | 未实现 | 26 | src/game/engine.ts |
| engine.setStationSlotItem | setStationSlotItem | 待映射 | 未实现 | 26 | src/game/engine.ts |
| engine.setStationSlotLimits | setStationSlotLimits | 待映射 | 未实现 | 26 | src/game/engine.ts |
| engine.setStationSlotMinimumLoad | setStationSlotMinimumLoad | 待映射 | 未实现 | 26 | src/game/engine.ts |
| engine.setStationSlotMode | setStationSlotMode | 待映射 | 未实现 | 26 | src/game/engine.ts |
| engine.setStationSlotPriority | setStationSlotPriority | 待映射 | 未实现 | 26 | src/game/engine.ts |
| engine.setStationSlotRoutePolicy | setStationSlotRoutePolicy | 待映射 | 未实现 | 26 | src/game/engine.ts |
| engine.setStationSlotWarperBudget | setStationSlotWarperBudget | 待映射 | 未实现 | 26 | src/game/engine.ts |
| engine.setStationWarpEnabled | setStationWarpEnabled | 待映射 | 未实现 | 26 | src/game/engine.ts |
| engine.setStationWarperAutoRefill | setStationWarperAutoRefill | 待映射 | 未实现 | 26 | src/game/engine.ts |
| engine.setStationWarperTarget | setStationWarperTarget | 待映射 | 未实现 | 26 | src/game/engine.ts |
| engine.setTimeWarpController | setTimeWarpController | 待映射 | 未实现 | 26 | src/game/engine.ts |
| engine.setTimeWarpEnabled | setTimeWarpEnabled | 待映射 | 未实现 | 26 | src/game/engine.ts |
| engine.setTimeWarpRequestedMultiplier | setTimeWarpRequestedMultiplier | 待映射 | 未实现 | 26 | src/game/engine.ts |
| engine.settleCompletedResearchBoundaries | settleCompletedResearchBoundaries | 待映射 | 未实现 | 25 | src/game/engine.ts |
| engine.settleCompletedResearchBoundariesInPlace | settleCompletedResearchBoundariesInPlace | 待映射 | 未实现 | 25 | src/game/engine.ts |
| engine.updateCanvasRegion | updateCanvasRegion | 待映射 | 未实现 | 24 | src/game/engine.ts |
| engine.upgradeBelt | upgradeBelt | scripts/game/GameState.gd::upgrade_belt | 实现中 | 23 | src/game/engine.ts |
| engine.upgradeBeltNetwork | upgradeBeltNetwork | scripts/game/GameState.gd::upgrade_belt_network | 实现中 | 23 | src/game/engine.ts |
| engine.upgradeEntities | upgradeEntities | scripts/game/GameState.gd::upgrade_entities | 实现中 | 23 | src/game/engine.ts |
| engine.upgradeEntity | upgradeEntity | scripts/game/GameState.gd::upgrade_entity | 实现中 | 23 | src/game/engine.ts |
| engine.upgradeSorter | upgradeSorter | scripts/game/GameState.gd::upgrade_sorter | 实现中 | 23 | src/game/engine.ts |
| engine.upgradeSorterNetwork | upgradeSorterNetwork | scripts/game/GameState.gd::upgrade_sorter_network | 实现中 | 23 | src/game/engine.ts |
| FactoryNodes.onAddBuilding | onAddBuilding | 待映射 | 未实现 | 23 | src/components/FactoryNodes.tsx |
| FactoryNodes.onDropCargo | onDropCargo | 待映射 | 未实现 | 23 | src/components/FactoryNodes.tsx |
| FactoryNodes.onDropDraggedItem | onDropDraggedItem | 待映射 | 未实现 | 23 | src/components/FactoryNodes.tsx |
| FactoryNodes.onEnergyModeChange | onEnergyModeChange | scripts/game/GameState.gd::set_energy_mode | 实现中 | 21 | src/components/FactoryNodes.tsx |
| FactoryNodes.onFuelChange | onFuelChange | 待映射 | 未实现 | 21 | src/components/FactoryNodes.tsx |
| FactoryNodes.onInstallMiner | onInstallMiner | 待映射 | 未实现 | 23 | src/components/FactoryNodes.tsx |
| FactoryNodes.onInteractionLockChange | onInteractionLockChange | 待映射 | 未实现 | 23 | src/components/FactoryNodes.tsx |
| FactoryNodes.onMiningStart | onMiningStart | 待映射 | 未实现 | 23 | src/components/FactoryNodes.tsx |
| FactoryNodes.onMiningStop | onMiningStop | 待映射 | 未实现 | 23 | src/components/FactoryNodes.tsx |
| FactoryNodes.onPick | onPick | 待映射 | 未实现 | 23 | src/components/FactoryNodes.tsx |
| FactoryNodes.onPickInput | onPickInput | 待映射 | 未实现 | 23 | src/components/FactoryNodes.tsx |
| FactoryNodes.onPickOutput | onPickOutput | 待映射 | 未实现 | 23 | src/components/FactoryNodes.tsx |
| FactoryNodes.onRecipeChange | onRecipeChange | 待映射 | 未实现 | 23 | src/components/FactoryNodes.tsx |
| FactoryNodes.onStackActivate | onStackActivate | 待映射 | 未实现 | 23 | src/components/FactoryNodes.tsx |
| GalaxyWorkspace.onClose | onClose | 待映射 | 在线排除 | 26 | src/components/GalaxyWorkspace.tsx |
| GalaxyWorkspace.onCreateAccount | onCreateAccount | 待映射 | 在线排除 | 26 | src/components/GalaxyWorkspace.tsx |
| GalaxyWorkspace.onDiagnostics | onDiagnostics | 待映射 | 在线排除 | 26 | src/components/GalaxyWorkspace.tsx |
| GalaxyWorkspace.onRestoreCloudSave | onRestoreCloudSave | 待映射 | 在线排除 | 20 | src/components/GalaxyWorkspace.tsx |
| GalaxyWorkspace.onStage | onStage | 待映射 | 在线排除 | 26 | src/components/GalaxyWorkspace.tsx |
| GalaxyWorkspace.onSwitchAccount | onSwitchAccount | 待映射 | 在线排除 | 26 | src/components/GalaxyWorkspace.tsx |
| GalaxyWorkspace.onUpdateCloudBinding | onUpdateCloudBinding | 待映射 | 在线排除 | 26 | src/components/GalaxyWorkspace.tsx |
| GalaxyWorkspace.onUpdateProfile | onUpdateProfile | 待映射 | 在线排除 | 26 | src/components/GalaxyWorkspace.tsx |
| GamePanels.onAddEntity | onAddEntity | 待映射 | 未实现 | 23 | src/components/GamePanels.tsx |
| GamePanels.onApplyBeltConfigurationToNetwork | onApplyBeltConfigurationToNetwork | 待映射 | 未实现 | 23 | src/components/GamePanels.tsx |
| GamePanels.onApplyConfigurationToNetwork | onApplyConfigurationToNetwork | 待映射 | 未实现 | 23 | src/components/GamePanels.tsx |
| GamePanels.onBatchEjectorOrbitChange | onBatchEjectorOrbitChange | 待映射 | 未实现 | 23 | src/components/GamePanels.tsx |
| GamePanels.onBatchInstallSprayCoater | onBatchInstallSprayCoater | 待映射 | 未实现 | 22 | src/components/GamePanels.tsx |
| GamePanels.onBatchProliferatorConfiguration | onBatchProliferatorConfiguration | 待映射 | 未实现 | 22 | src/components/GamePanels.tsx |
| GamePanels.onBatchRecipeChange | onBatchRecipeChange | 待映射 | 未实现 | 23 | src/components/GamePanels.tsx |
| GamePanels.onBeltLaneCountChange | onBeltLaneCountChange | scenes/ui/FactoryWorkspaceUI.gd::_on_belt_config_pressed | 实现中 | 23 | src/components/GamePanels.tsx |
| GamePanels.onBeltMonitorChange | onBeltMonitorChange | 待映射 | 未实现 | 23 | src/components/GamePanels.tsx |
| GamePanels.onBeltPriorityChange | onBeltPriorityChange | 待映射 | 未实现 | 23 | src/components/GamePanels.tsx |
| GamePanels.onBeltRouteModeChange | onBeltRouteModeChange | 待映射 | 未实现 | 23 | src/components/GamePanels.tsx |
| GamePanels.onBeltRouteOffsetChange | onBeltRouteOffsetChange | 待映射 | 未实现 | 23 | src/components/GamePanels.tsx |
| GamePanels.onBeltStackSizeChange | onBeltStackSizeChange | 待映射 | 未实现 | 23 | src/components/GamePanels.tsx |
| GamePanels.onBeltTierChange | onBeltTierChange | 待映射 | 未实现 | 23 | src/components/GamePanels.tsx |
| GamePanels.onBeltTierModeChange | onBeltTierModeChange | 待映射 | 未实现 | 23 | src/components/GamePanels.tsx |
| GamePanels.onBlackHolePausedChange | onBlackHolePausedChange | 待映射 | 未实现 | 26 | src/components/GamePanels.tsx |
| GamePanels.onCancelCraftQueue | onCancelCraftQueue | 待映射 | 未实现 | 22 | src/components/GamePanels.tsx |
| GamePanels.onChange | onChange | 待映射 | 未实现 | 23 | src/components/GamePanels.tsx |
| GamePanels.onConfigure | onConfigure | 待映射 | 未实现 | 23 | src/components/GamePanels.tsx |
| GamePanels.onCopyBeltConfiguration | onCopyBeltConfiguration | 待映射 | 未实现 | 23 | src/components/GamePanels.tsx |
| GamePanels.onCopyConfiguration | onCopyConfiguration | 待映射 | 未实现 | 23 | src/components/GamePanels.tsx |
| GamePanels.onCraft | onCraft | 待映射 | 未实现 | 22 | src/components/GamePanels.tsx |
| GamePanels.onCraftItem | onCraftItem | 待映射 | 未实现 | 22 | src/components/GamePanels.tsx |
| GamePanels.onDeleteConstruction | onDeleteConstruction | 待映射 | 未实现 | 23 | src/components/GamePanels.tsx |
| GamePanels.onDiscardTrayItems | onDiscardTrayItems | 待映射 | 未实现 | 23 | src/components/GamePanels.tsx |
| GamePanels.onDropCargo | onDropCargo | 待映射 | 未实现 | 23 | src/components/GamePanels.tsx |
| GamePanels.onDropDraggedItem | onDropDraggedItem | 待映射 | 未实现 | 23 | src/components/GamePanels.tsx |
| GamePanels.onEjectorOrbitChange | onEjectorOrbitChange | 待映射 | 未实现 | 23 | src/components/GamePanels.tsx |
| GamePanels.onEnergyModeChange | onEnergyModeChange | scripts/game/GameState.gd::set_energy_mode | 实现中 | 21 | src/components/GamePanels.tsx |
| GamePanels.onEntityLockChange | onEntityLockChange | 待映射 | 未实现 | 23 | src/components/GamePanels.tsx |
| GamePanels.onEntityStackTarget | onEntityStackTarget | 待映射 | 未实现 | 23 | src/components/GamePanels.tsx |
| GamePanels.onFocusBeltNetwork | onFocusBeltNetwork | 待映射 | 未实现 | 23 | src/components/GamePanels.tsx |
| GamePanels.onFocusNetwork | onFocusNetwork | 待映射 | 未实现 | 23 | src/components/GamePanels.tsx |
| GamePanels.onFuelChange | onFuelChange | 待映射 | 未实现 | 21 | src/components/GamePanels.tsx |
| GamePanels.onGalacticExporterPausedChange | onGalacticExporterPausedChange | 待映射 | 未实现 | 26 | src/components/GamePanels.tsx |
| GamePanels.onGenerationPriorityChange | onGenerationPriorityChange | scripts/game/GameState.gd::set_entity_generation_priority | 实现中 | 21 | src/components/GamePanels.tsx |
| GamePanels.onGridChange | onGridChange | scripts/game/GameState.gd::set_entity_power_grid | 实现中 | 21 | src/components/GamePanels.tsx |
| GamePanels.onInstall | onInstall | 待映射 | 未实现 | 23 | src/components/GamePanels.tsx |
| GamePanels.onInstallSprayCoater | onInstallSprayCoater | 待映射 | 未实现 | 22 | src/components/GamePanels.tsx |
| GamePanels.onLaneCountChange | onLaneCountChange | scenes/ui/FactoryWorkspaceUI.gd::_on_belt_config_pressed | 实现中 | 23 | src/components/GamePanels.tsx |
| GamePanels.onLogisticsItemChange | onLogisticsItemChange | 待映射 | 未实现 | 23 | src/components/GamePanels.tsx |
| GamePanels.onMaterialDeliverySlotChange | onMaterialDeliverySlotChange | 待映射 | 未实现 | 23 | src/components/GamePanels.tsx |
| GamePanels.onMissingCraftNavigate | onMissingCraftNavigate | 待映射 | 未实现 | 22 | src/components/GamePanels.tsx |
| GamePanels.onMonitorChange | onMonitorChange | 待映射 | 未实现 | 23 | src/components/GamePanels.tsx |
| GamePanels.onOpenCampaign | onOpenCampaign | 待映射 | 未实现 | 25 | src/components/GamePanels.tsx |
| GamePanels.onOpenCommandPalette | onOpenCommandPalette | scenes/ui/FactoryWorkspaceUI.gd::open_command_palette | 实现中 | 23 | src/components/GamePanels.tsx |
| GamePanels.onOpenConstructionCenter | onOpenConstructionCenter | 待映射 | 未实现 | 22 | src/components/GamePanels.tsx |
| GamePanels.onOpenDysonPlanner | onOpenDysonPlanner | 待映射 | 未实现 | 26 | src/components/GamePanels.tsx |
| GamePanels.onOpenFabricator | onOpenFabricator | 待映射 | 未实现 | 23 | src/components/GamePanels.tsx |
| GamePanels.onOpenGalaxy | onOpenGalaxy | 待映射 | 未实现 | 26 | src/components/GamePanels.tsx |
| GamePanels.onOpenInspector | onOpenInspector | 待映射 | 未实现 | 23 | src/components/GamePanels.tsx |
| GamePanels.onOpenOrbitalStation | onOpenOrbitalStation | 待映射 | 未实现 | 26 | src/components/GamePanels.tsx |
| GamePanels.onOpenRecipes | onOpenRecipes | 待映射 | 未实现 | 23 | src/components/GamePanels.tsx |
| GamePanels.onOpenResources | onOpenResources | 待映射 | 未实现 | 23 | src/components/GamePanels.tsx |
| GamePanels.onOpenResourceSettings | onOpenResourceSettings | 待映射 | 未实现 | 23 | src/components/GamePanels.tsx |
| GamePanels.onOpenSettings | onOpenSettings | 待映射 | 未实现 | 23 | src/components/GamePanels.tsx |
| GamePanels.onOpenStarMap | onOpenStarMap | 待映射 | 未实现 | 26 | src/components/GamePanels.tsx |
| GamePanels.onOpenStatistics | onOpenStatistics | 待映射 | 未实现 | 23 | src/components/GamePanels.tsx |
| GamePanels.onOpenTechnology | onOpenTechnology | 待映射 | 未实现 | 25 | src/components/GamePanels.tsx |
| GamePanels.onOpenTutorial | onOpenTutorial | 待映射 | 未实现 | 25 | src/components/GamePanels.tsx |
| GamePanels.onOrbitalCargoPortClear | onOrbitalCargoPortClear | 待映射 | 未实现 | 23 | src/components/GamePanels.tsx |
| GamePanels.onOrbitalCollectorQuantumMode | onOrbitalCollectorQuantumMode | 待映射 | 未实现 | 26 | src/components/GamePanels.tsx |
| GamePanels.onPasteBeltConfiguration | onPasteBeltConfiguration | 待映射 | 未实现 | 23 | src/components/GamePanels.tsx |
| GamePanels.onPasteConfiguration | onPasteConfiguration | 待映射 | 未实现 | 23 | src/components/GamePanels.tsx |
| GamePanels.onPauseToggle | onPauseToggle | 待映射 | 未实现 | 23 | src/components/GamePanels.tsx |
| GamePanels.onPickEntityInput | onPickEntityInput | 待映射 | 未实现 | 23 | src/components/GamePanels.tsx |
| GamePanels.onPickTray | onPickTray | 待映射 | 未实现 | 23 | src/components/GamePanels.tsx |
| GamePanels.onPlacementChange | onPlacementChange | 待映射 | 未实现 | 23 | src/components/GamePanels.tsx |
| GamePanels.onPlacementCountChange | onPlacementCountChange | 待映射 | 未实现 | 23 | src/components/GamePanels.tsx |
| GamePanels.onPlanetChange | onPlanetChange | 待映射 | 未实现 | 26 | src/components/GamePanels.tsx |
| GamePanels.onPowerGridChange | onPowerGridChange | scripts/game/GameState.gd::set_entity_power_grid | 实现中 | 21 | src/components/GamePanels.tsx |
| GamePanels.onPowerPriorityChange | onPowerPriorityChange | scripts/game/GameState.gd::set_entity_power_priority | 实现中 | 21 | src/components/GamePanels.tsx |
| GamePanels.onPriorityChange | onPriorityChange | 待映射 | 未实现 | 23 | src/components/GamePanels.tsx |
| GamePanels.onProliferatorConfiguration | onProliferatorConfiguration | 待映射 | 未实现 | 22 | src/components/GamePanels.tsx |
| GamePanels.onQuantumAttachment | onQuantumAttachment | 待映射 | 未实现 | 26 | src/components/GamePanels.tsx |
| GamePanels.onQueueCraftItem | onQueueCraftItem | 待映射 | 未实现 | 22 | src/components/GamePanels.tsx |
| GamePanels.onRecipeChange | onRecipeChange | 待映射 | 未实现 | 23 | src/components/GamePanels.tsx |
| GamePanels.onRemove | onRemove | 待映射 | 未实现 | 23 | src/components/GamePanels.tsx |
| GamePanels.onRemoveBelt | onRemoveBelt | 待映射 | 未实现 | 23 | src/components/GamePanels.tsx |
| GamePanels.onRemoveBeltNetwork | onRemoveBeltNetwork | 待映射 | 未实现 | 23 | src/components/GamePanels.tsx |
| GamePanels.onRemoveEntity | onRemoveEntity | 待映射 | 未实现 | 23 | src/components/GamePanels.tsx |
| GamePanels.onRemoveNetwork | onRemoveNetwork | 待映射 | 未实现 | 23 | src/components/GamePanels.tsx |
| GamePanels.onRemoveSprayCoater | onRemoveSprayCoater | 待映射 | 未实现 | 22 | src/components/GamePanels.tsx |
| GamePanels.onReturnToMenu | onReturnToMenu | 待映射 | 未实现 | 23 | src/components/GamePanels.tsx |
| GamePanels.onRouteModeChange | onRouteModeChange | 待映射 | 未实现 | 23 | src/components/GamePanels.tsx |
| GamePanels.onRouteOffsetChange | onRouteOffsetChange | 待映射 | 未实现 | 23 | src/components/GamePanels.tsx |
| GamePanels.onSetTarget | onSetTarget | 待映射 | 未实现 | 23 | src/components/GamePanels.tsx |
| GamePanels.onSetTrayItemLimit | onSetTrayItemLimit | 待映射 | 未实现 | 23 | src/components/GamePanels.tsx |
| GamePanels.onSplitterModeChange | onSplitterModeChange | 待映射 | 未实现 | 22 | src/components/GamePanels.tsx |
| GamePanels.onStackSizeChange | onStackSizeChange | 待映射 | 未实现 | 23 | src/components/GamePanels.tsx |
| GamePanels.onStationDroneAdjust | onStationDroneAdjust | 待映射 | 未实现 | 26 | src/components/GamePanels.tsx |
| GamePanels.onStationFleetFill | onStationFleetFill | 待映射 | 未实现 | 26 | src/components/GamePanels.tsx |
| GamePanels.onStationFleetTarget | onStationFleetTarget | 待映射 | 未实现 | 26 | src/components/GamePanels.tsx |
| GamePanels.onStationHubChange | onStationHubChange | 待映射 | 未实现 | 26 | src/components/GamePanels.tsx |
| GamePanels.onStationMinimumLoadChange | onStationMinimumLoadChange | 待映射 | 未实现 | 26 | src/components/GamePanels.tsx |
| GamePanels.onStationModeChange | onStationModeChange | 待映射 | 未实现 | 26 | src/components/GamePanels.tsx |
| GamePanels.onStationSlotItemChange | onStationSlotItemChange | 待映射 | 未实现 | 26 | src/components/GamePanels.tsx |
| GamePanels.onStationSlotLimitsChange | onStationSlotLimitsChange | 待映射 | 未实现 | 26 | src/components/GamePanels.tsx |
| GamePanels.onStationSlotMinimumLoadChange | onStationSlotMinimumLoadChange | 待映射 | 未实现 | 26 | src/components/GamePanels.tsx |
| GamePanels.onStationSlotModeChange | onStationSlotModeChange | 待映射 | 未实现 | 26 | src/components/GamePanels.tsx |
| GamePanels.onStationSlotPriorityChange | onStationSlotPriorityChange | 待映射 | 未实现 | 26 | src/components/GamePanels.tsx |
| GamePanels.onStationSlotRoutePolicyChange | onStationSlotRoutePolicyChange | 待映射 | 未实现 | 26 | src/components/GamePanels.tsx |
| GamePanels.onStationSlotWarperBudgetChange | onStationSlotWarperBudgetChange | 待映射 | 未实现 | 26 | src/components/GamePanels.tsx |
| GamePanels.onStationVesselAdjust | onStationVesselAdjust | 待映射 | 未实现 | 26 | src/components/GamePanels.tsx |
| GamePanels.onStationWarpEnabled | onStationWarpEnabled | 待映射 | 未实现 | 26 | src/components/GamePanels.tsx |
| GamePanels.onStationWarperAdjust | onStationWarperAdjust | 待映射 | 未实现 | 26 | src/components/GamePanels.tsx |
| GamePanels.onStationWarperAutoRefillChange | onStationWarperAutoRefillChange | 待映射 | 未实现 | 26 | src/components/GamePanels.tsx |
| GamePanels.onStationWarperTargetChange | onStationWarperTargetChange | 待映射 | 未实现 | 26 | src/components/GamePanels.tsx |
| GamePanels.onStowCargo | onStowCargo | 待映射 | 未实现 | 23 | src/components/GamePanels.tsx |
| GamePanels.onTabChange | onTabChange | 待映射 | 未实现 | 23 | src/components/GamePanels.tsx |
| GamePanels.onTimeWarpControllerChange | onTimeWarpControllerChange | 待映射 | 未实现 | 26 | src/components/GamePanels.tsx |
| GamePanels.onTimeWarpEnabledChange | onTimeWarpEnabledChange | 待映射 | 未实现 | 26 | src/components/GamePanels.tsx |
| GamePanels.onTimeWarpRequestedMultiplierChange | onTimeWarpRequestedMultiplierChange | 待映射 | 未实现 | 26 | src/components/GamePanels.tsx |
| GamePanels.onUpgrade | onUpgrade | 待映射 | 未实现 | 23 | src/components/GamePanels.tsx |
| GamePanels.onUpgradeBelt | onUpgradeBelt | 待映射 | 未实现 | 23 | src/components/GamePanels.tsx |
| GamePanels.onUpgradeBeltNetwork | onUpgradeBeltNetwork | 待映射 | 未实现 | 23 | src/components/GamePanels.tsx |
| GamePanels.onUpgradeEntity | onUpgradeEntity | 待映射 | 未实现 | 23 | src/components/GamePanels.tsx |
| GamePanels.onUpgradeInterstellarStation | onUpgradeInterstellarStation | 待映射 | 未实现 | 26 | src/components/GamePanels.tsx |
| GamePanels.onUpgradeNetwork | onUpgradeNetwork | 待映射 | 未实现 | 23 | src/components/GamePanels.tsx |
| ItemReference.onLocate | onLocate | 待映射 | 未实现 | 23 | src/components/ItemReference.tsx |
| ItemReference.onOpenCodex | onOpenCodex | 待映射 | 未实现 | 23 | src/components/ItemReference.tsx |
| LogisticsManagementPanel.onCollectorItemChange | onCollectorItemChange | 待映射 | 未实现 | 26 | src/components/LogisticsManagementPanel.tsx |
| LogisticsManagementPanel.onCollectorQuantumModeChange | onCollectorQuantumModeChange | 待映射 | 未实现 | 26 | src/components/LogisticsManagementPanel.tsx |
| LogisticsManagementPanel.onFleetTargetChange | onFleetTargetChange | 待映射 | 未实现 | 26 | src/components/LogisticsManagementPanel.tsx |
| LogisticsManagementPanel.onQuantumAttach | onQuantumAttach | 待映射 | 未实现 | 26 | src/components/LogisticsManagementPanel.tsx |
| LogisticsManagementPanel.onSlotItemChange | onSlotItemChange | 待映射 | 未实现 | 26 | src/components/LogisticsManagementPanel.tsx |
| LogisticsManagementPanel.onSlotLimitsChange | onSlotLimitsChange | 待映射 | 未实现 | 26 | src/components/LogisticsManagementPanel.tsx |
| LogisticsManagementPanel.onSlotMinimumLoadChange | onSlotMinimumLoadChange | 待映射 | 未实现 | 26 | src/components/LogisticsManagementPanel.tsx |
| LogisticsManagementPanel.onSlotModeChange | onSlotModeChange | 待映射 | 未实现 | 26 | src/components/LogisticsManagementPanel.tsx |
| LogisticsManagementPanel.onSlotPriorityChange | onSlotPriorityChange | 待映射 | 未实现 | 26 | src/components/LogisticsManagementPanel.tsx |
| LogisticsManagementPanel.onStackTargetChange | onStackTargetChange | 待映射 | 未实现 | 26 | src/components/LogisticsManagementPanel.tsx |
| LogisticsManagementPanel.onToggle | onToggle | 待映射 | 未实现 | 26 | src/components/LogisticsManagementPanel.tsx |
| LogisticsManagementPanel.onWarpEnabledChange | onWarpEnabledChange | 待映射 | 未实现 | 26 | src/components/LogisticsManagementPanel.tsx |
| LogisticsManagementPanel.onWarperAdjust | onWarperAdjust | 待映射 | 未实现 | 26 | src/components/LogisticsManagementPanel.tsx |
| LogisticsManagementPanel.onWarperAutoRefillChange | onWarperAutoRefillChange | 待映射 | 未实现 | 26 | src/components/LogisticsManagementPanel.tsx |
| LogisticsManagementPanel.onWarperTargetChange | onWarperTargetChange | 待映射 | 未实现 | 26 | src/components/LogisticsManagementPanel.tsx |
| OfflineReportWorkspace.onClose | onClose | scenes/ui/AppShell.gd::_on_session_started | 实现中 | 20 | src/components/OfflineReportWorkspace.tsx |
| OnboardingCoach.onAction | onAction | 待映射 | 未实现 | 23 | src/components/OnboardingCoach.tsx |
| OnboardingCoach.onDismiss | onDismiss | 待映射 | 未实现 | 23 | src/components/OnboardingCoach.tsx |
| OperationsWorkspace.onAddSecondUnipolarVein | onAddSecondUnipolarVein | 待映射 | 未实现 | 23 | src/components/OperationsWorkspace.tsx |
| OperationsWorkspace.onAlertSelect | onAlertSelect | 待映射 | 未实现 | 23 | src/components/OperationsWorkspace.tsx |
| OperationsWorkspace.onAllowEditsDuringSaveChange | onAllowEditsDuringSaveChange | 待映射 | 未实现 | 20 | src/components/OperationsWorkspace.tsx |
| OperationsWorkspace.onBlueprintAllowOverlapChange | onBlueprintAllowOverlapChange | 待映射 | 未实现 | 24 | src/components/OperationsWorkspace.tsx |
| OperationsWorkspace.onCancelImport | onCancelImport | 待映射 | 未实现 | 23 | src/components/OperationsWorkspace.tsx |
| OperationsWorkspace.onCanvasDetailPreferenceChange | onCanvasDetailPreferenceChange | 待映射 | 未实现 | 23 | src/components/OperationsWorkspace.tsx |
| OperationsWorkspace.onCanvasInteractionDetailPreferenceChange | onCanvasInteractionDetailPreferenceChange | 待映射 | 未实现 | 23 | src/components/OperationsWorkspace.tsx |
| OperationsWorkspace.onCanvasOverlapPreferenceChange | onCanvasOverlapPreferenceChange | 待映射 | 未实现 | 23 | src/components/OperationsWorkspace.tsx |
| OperationsWorkspace.onCanvasPerformanceFeatureChange | onCanvasPerformanceFeatureChange | 待映射 | 未实现 | 23 | src/components/OperationsWorkspace.tsx |
| OperationsWorkspace.onChange | onChange | 待映射 | 未实现 | 23 | src/components/OperationsWorkspace.tsx |
| OperationsWorkspace.onClear | onClear | 待映射 | 未实现 | 23 | src/components/OperationsWorkspace.tsx |
| OperationsWorkspace.onClearPerformanceMonitor | onClearPerformanceMonitor | 待映射 | 未实现 | 23 | src/components/OperationsWorkspace.tsx |
| OperationsWorkspace.onClose | onClose | 待映射 | 未实现 | 23 | src/components/OperationsWorkspace.tsx |
| OperationsWorkspace.onConfirmImport | onConfirmImport | 待映射 | 未实现 | 23 | src/components/OperationsWorkspace.tsx |
| OperationsWorkspace.onConfirmImportRescue | onConfirmImportRescue | 待映射 | 未实现 | 20 | src/components/OperationsWorkspace.tsx |
| OperationsWorkspace.onConnectExpandAllChange | onConnectExpandAllChange | 待映射 | 未实现 | 23 | src/components/OperationsWorkspace.tsx |
| OperationsWorkspace.onConnectionHitAreaChange | onConnectionHitAreaChange | 待映射 | 未实现 | 23 | src/components/OperationsWorkspace.tsx |
| OperationsWorkspace.onConnectionPointSizeChange | onConnectionPointSizeChange | 待映射 | 未实现 | 23 | src/components/OperationsWorkspace.tsx |
| OperationsWorkspace.onCreateSnapshot | onCreateSnapshot | autoload/GameManager.gd::create_recovery_snapshot | 实现中 | 20 | src/components/OperationsWorkspace.tsx |
| OperationsWorkspace.onDefaultBeltLanesChange | onDefaultBeltLanesChange | 待映射 | 未实现 | 23 | src/components/OperationsWorkspace.tsx |
| OperationsWorkspace.onDeleteSlot | onDeleteSlot | 待映射 | 未实现 | 23 | src/components/OperationsWorkspace.tsx |
| OperationsWorkspace.onDeleteSnapshot | onDeleteSnapshot | scripts/game/SaveSystem.gd::delete_snapshots | 实现中 | 20 | src/components/OperationsWorkspace.tsx |
| OperationsWorkspace.onDeleteSnapshots | onDeleteSnapshots | scripts/game/SaveSystem.gd::delete_snapshots | 实现中 | 20 | src/components/OperationsWorkspace.tsx |
| OperationsWorkspace.onEndgameExtremeModeChange | onEndgameExtremeModeChange | 待映射 | 未实现 | 26 | src/components/OperationsWorkspace.tsx |
| OperationsWorkspace.onExport | onExport | 待映射 | 未实现 | 23 | src/components/OperationsWorkspace.tsx |
| OperationsWorkspace.onExportModTemplate | onExportModTemplate | 待映射 | 未实现 | 26 | src/components/OperationsWorkspace.tsx |
| OperationsWorkspace.onExportPerformanceMonitor | onExportPerformanceMonitor | 待映射 | 未实现 | 23 | src/components/OperationsWorkspace.tsx |
| OperationsWorkspace.onExportTemplate | onExportTemplate | 待映射 | 未实现 | 26 | src/components/OperationsWorkspace.tsx |
| OperationsWorkspace.onFactoryAlertsEnabledChange | onFactoryAlertsEnabledChange | 待映射 | 未实现 | 23 | src/components/OperationsWorkspace.tsx |
| OperationsWorkspace.onFullRealtimeSimulationChange | onFullRealtimeSimulationChange | 待映射 | 未实现 | 26 | src/components/OperationsWorkspace.tsx |
| OperationsWorkspace.onImport | onImport | 待映射 | 未实现 | 23 | src/components/OperationsWorkspace.tsx |
| OperationsWorkspace.onItemHoverChange | onItemHoverChange | 待映射 | 未实现 | 23 | src/components/OperationsWorkspace.tsx |
| OperationsWorkspace.onLargeSaveAutosaveProtectionChange | onLargeSaveAutosaveProtectionChange | 待映射 | 未实现 | 20 | src/components/OperationsWorkspace.tsx |
| OperationsWorkspace.onLineFindModeChange | onLineFindModeChange | 待映射 | 未实现 | 23 | src/components/OperationsWorkspace.tsx |
| OperationsWorkspace.onLoadSlot | onLoadSlot | 待映射 | 未实现 | 23 | src/components/OperationsWorkspace.tsx |
| OperationsWorkspace.onLoadSnapshot | onLoadSnapshot | autoload/GameManager.gd::recover_game | 实现中 | 20 | src/components/OperationsWorkspace.tsx |
| OperationsWorkspace.onManualSave | onManualSave | autoload/GameManager.gd::save_current_game | 实现中 | 20 | src/components/OperationsWorkspace.tsx |
| OperationsWorkspace.onOpenReleaseNotes | onOpenReleaseNotes | 待映射 | 未实现 | 23 | src/components/OperationsWorkspace.tsx |
| OperationsWorkspace.onOpenTutorial | onOpenTutorial | 待映射 | 未实现 | 25 | src/components/OperationsWorkspace.tsx |
| OperationsWorkspace.onProductionRefreshPreferenceChange | onProductionRefreshPreferenceChange | 待映射 | 未实现 | 23 | src/components/OperationsWorkspace.tsx |
| OperationsWorkspace.onRegister | onRegister | 待映射 | 未实现 | 26 | src/components/OperationsWorkspace.tsx |
| OperationsWorkspace.onRegisterContentPack | onRegisterContentPack | 待映射 | 未实现 | 26 | src/components/OperationsWorkspace.tsx |
| OperationsWorkspace.onRemove | onRemove | 待映射 | 未实现 | 23 | src/components/OperationsWorkspace.tsx |
| OperationsWorkspace.onRemoveContentPack | onRemoveContentPack | 待映射 | 未实现 | 26 | src/components/OperationsWorkspace.tsx |
| OperationsWorkspace.onRunBenchmark | onRunBenchmark | 待映射 | 未实现 | 23 | src/components/OperationsWorkspace.tsx |
| OperationsWorkspace.onRunLogChange | onRunLogChange | 待映射 | 未实现 | 23 | src/components/OperationsWorkspace.tsx |
| OperationsWorkspace.onSaveSlot | onSaveSlot | autoload/GameManager.gd::save_current_game | 实现中 | 20 | src/components/OperationsWorkspace.tsx |
| OperationsWorkspace.onSelect | onSelect | 待映射 | 未实现 | 23 | src/components/OperationsWorkspace.tsx |
| OperationsWorkspace.onSetContentPackEnabled | onSetContentPackEnabled | 待映射 | 未实现 | 26 | src/components/OperationsWorkspace.tsx |
| OperationsWorkspace.onSetEnabled | onSetEnabled | 待映射 | 未实现 | 23 | src/components/OperationsWorkspace.tsx |
| OperationsWorkspace.onSettingsChange | onSettingsChange | 待映射 | 未实现 | 23 | src/components/OperationsWorkspace.tsx |
| OperationsWorkspace.onStart | onStart | 待映射 | 未实现 | 23 | src/components/OperationsWorkspace.tsx |
| OperationsWorkspace.onStartPerformanceMonitor | onStartPerformanceMonitor | 待映射 | 未实现 | 23 | src/components/OperationsWorkspace.tsx |
| OperationsWorkspace.onStop | onStop | 待映射 | 未实现 | 23 | src/components/OperationsWorkspace.tsx |
| OperationsWorkspace.onStopPerformanceMonitor | onStopPerformanceMonitor | 待映射 | 未实现 | 23 | src/components/OperationsWorkspace.tsx |
| OperationsWorkspace.onTabChange | onTabChange | 待映射 | 未实现 | 23 | src/components/OperationsWorkspace.tsx |
| OperationsWorkspace.onValidate | onValidate | 待映射 | 未实现 | 23 | src/components/OperationsWorkspace.tsx |
| OperationsWorkspace.onValidateMod | onValidateMod | 待映射 | 未实现 | 26 | src/components/OperationsWorkspace.tsx |
| OrbitalStationWorkspace.onClose | onClose | 待映射 | 未实现 | 26 | src/components/OrbitalStationWorkspace.tsx |
| OrbitalStationWorkspace.onGameChange | onGameChange | 待映射 | 未实现 | 26 | src/components/OrbitalStationWorkspace.tsx |
| palette.entity:{entity_id} | entity:{entity_id} | scenes/ui/FactoryWorkspaceUI.gd::_locate_entity | 实现中 | 23 | src/components/CommandPalette.tsx |
| palette.recipe:{item_id} | recipe:{item_id} | 待映射 | 未实现 | 23 | src/components/CommandPalette.tsx |
| ProductionManagement.onBulkRecipeChange | onBulkRecipeChange | 待映射 | 未实现 | 23 | src/components/ProductionManagement.tsx |
| ProductionManagement.onBulkStationSlotApply | onBulkStationSlotApply | 待映射 | 未实现 | 26 | src/components/ProductionManagement.tsx |
| ProductionManagement.onCreatePlan | onCreatePlan | 待映射 | 未实现 | 23 | src/components/ProductionManagement.tsx |
| ProductionManagement.onFocusBelt | onFocusBelt | 待映射 | 未实现 | 23 | src/components/ProductionManagement.tsx |
| ProductionManagement.onFocusEntity | onFocusEntity | 待映射 | 未实现 | 23 | src/components/ProductionManagement.tsx |
| QuantityStepper.onChange | onChange | 待映射 | 未实现 | 23 | src/components/QuantityStepper.tsx |
| QuantityStepper.onMax | onMax | 待映射 | 未实现 | 23 | src/components/QuantityStepper.tsx |
| RecipeFocusPanel.onClear | onClear | 待映射 | 未实现 | 22 | src/components/RecipeFocusPanel.tsx |
| RecipeFocusPanel.onModeChange | onModeChange | 待映射 | 未实现 | 22 | src/components/RecipeFocusPanel.tsx |
| RecipeFocusPanel.onOpen | onOpen | 待映射 | 未实现 | 22 | src/components/RecipeFocusPanel.tsx |
| RecipeFocusPanel.onPositionChange | onPositionChange | 待映射 | 未实现 | 22 | src/components/RecipeFocusPanel.tsx |
| RecipeWorkspace.onClose | onClose | 待映射 | 未实现 | 22 | src/components/RecipeWorkspace.tsx |
| RecipeWorkspace.onFocus | onFocus | 待映射 | 未实现 | 22 | src/components/RecipeWorkspace.tsx |
| RecipeWorkspace.onLocateProductionLine | onLocateProductionLine | 待映射 | 未实现 | 22 | src/components/RecipeWorkspace.tsx |
| RecipeWorkspace.onSelect | onSelect | 待映射 | 未实现 | 22 | src/components/RecipeWorkspace.tsx |
| RecipeWorkspace.onSelectBuilding | onSelectBuilding | 待映射 | 未实现 | 22 | src/components/RecipeWorkspace.tsx |
| RecipeWorkspace.onSelectTechnology | onSelectTechnology | 待映射 | 未实现 | 22 | src/components/RecipeWorkspace.tsx |
| ReleaseNotesDialog.onClose | onClose | 待映射 | 未实现 | 23 | src/components/ReleaseNotesDialog.tsx |
| SaveDeleteDialog.onCancel | onCancel | scenes/ui/SaveSlotsPanel.gd::_request_delete | 实现中 | 20 | src/components/SaveDeleteDialog.tsx |
| SaveDeleteDialog.onDelete | onDelete | scenes/ui/AppShell.gd::_delete_slot | 实现中 | 20 | src/components/SaveDeleteDialog.tsx |
| SpeedrunCopyDialog.onCancel | onCancel | 待映射 | 未实现 | 26 | src/components/SpeedrunCopyDialog.tsx |
| SpeedrunCopyDialog.onCopy | onCopy | 待映射 | 未实现 | 26 | src/components/SpeedrunCopyDialog.tsx |
| StableTextInput.onValueChange | onValueChange | 待映射 | 未实现 | 23 | src/components/StableTextInput.tsx |
| StarMapWorkspace.onChange | onChange | 待映射 | 未实现 | 26 | src/components/StarMapWorkspace.tsx |
| StarMapWorkspace.onClose | onClose | 待映射 | 未实现 | 26 | src/components/StarMapWorkspace.tsx |
| StarMapWorkspace.onCollectorModeChange | onCollectorModeChange | 待映射 | 未实现 | 26 | src/components/StarMapWorkspace.tsx |
| StarMapWorkspace.onColonize | onColonize | 待映射 | 未实现 | 26 | src/components/StarMapWorkspace.tsx |
| StarMapWorkspace.onExplore | onExplore | 待映射 | 未实现 | 26 | src/components/StarMapWorkspace.tsx |
| StarMapWorkspace.onFocusStation | onFocusStation | 待映射 | 未实现 | 26 | src/components/StarMapWorkspace.tsx |
| StarMapWorkspace.onItemCapacityChange | onItemCapacityChange | 待映射 | 未实现 | 26 | src/components/StarMapWorkspace.tsx |
| StarMapWorkspace.onPlanetMetadataChange | onPlanetMetadataChange | 待映射 | 未实现 | 26 | src/components/StarMapWorkspace.tsx |
| StarMapWorkspace.onQuantumItemCapacityChange | onQuantumItemCapacityChange | 待映射 | 未实现 | 26 | src/components/StarMapWorkspace.tsx |
| StarMapWorkspace.onRoleChange | onRoleChange | 待映射 | 未实现 | 26 | src/components/StarMapWorkspace.tsx |
| StarMapWorkspace.onStationLimitsChange | onStationLimitsChange | 待映射 | 未实现 | 26 | src/components/StarMapWorkspace.tsx |
| StarMapWorkspace.onStationMinimumLoadChange | onStationMinimumLoadChange | 待映射 | 未实现 | 26 | src/components/StarMapWorkspace.tsx |
| StarMapWorkspace.onStationPriorityChange | onStationPriorityChange | 待映射 | 未实现 | 26 | src/components/StarMapWorkspace.tsx |
| StarMapWorkspace.onSystemNameChange | onSystemNameChange | 待映射 | 未实现 | 26 | src/components/StarMapWorkspace.tsx |
| StarMapWorkspace.onTravel | onTravel | 待映射 | 未实现 | 26 | src/components/StarMapWorkspace.tsx |
| StartMenu.onChange | onChange | 待映射 | 未实现 | 23 | src/components/StartMenu.tsx |
| StartMenu.onComplexity | onComplexity | 待映射 | 未实现 | 23 | src/components/StartMenu.tsx |
| StartMenu.onDiagnostics | onDiagnostics | 待映射 | 未实现 | 23 | src/components/StartMenu.tsx |
| StartMenu.onEnterGame | onEnterGame | 待映射 | 未实现 | 23 | src/components/StartMenu.tsx |
| StartMenu.onOpenReleaseNotes | onOpenReleaseNotes | 待映射 | 未实现 | 23 | src/components/StartMenu.tsx |
| StartMenu.onProgress | onProgress | 待映射 | 未实现 | 23 | src/components/StartMenu.tsx |
| StartMenu.onStage | onStage | 待映射 | 未实现 | 23 | src/components/StartMenu.tsx |
| StationCanvasRenderer.onMovePlacement | onMovePlacement | 待映射 | 未实现 | 26 | src/components/StationCanvasRenderer.tsx |
| StationCanvasRenderer.onSelectPlacement | onSelectPlacement | 待映射 | 未实现 | 26 | src/components/StationCanvasRenderer.tsx |
| StationCanvasRenderer.onViewportChange | onViewportChange | 待映射 | 未实现 | 26 | src/components/StationCanvasRenderer.tsx |
| StatisticsWorkspace.onAddCanvasBookmark | onAddCanvasBookmark | 待映射 | 未实现 | 24 | src/components/StatisticsWorkspace.tsx |
| StatisticsWorkspace.onBeltHeatmapChange | onBeltHeatmapChange | 待映射 | 未实现 | 23 | src/components/StatisticsWorkspace.tsx |
| StatisticsWorkspace.onBulkBeltConfiguration | onBulkBeltConfiguration | 待映射 | 未实现 | 23 | src/components/StatisticsWorkspace.tsx |
| StatisticsWorkspace.onBulkBeltRemove | onBulkBeltRemove | 待映射 | 未实现 | 23 | src/components/StatisticsWorkspace.tsx |
| StatisticsWorkspace.onBulkBeltRoute | onBulkBeltRoute | 待映射 | 未实现 | 23 | src/components/StatisticsWorkspace.tsx |
| StatisticsWorkspace.onBulkBeltUpgrade | onBulkBeltUpgrade | 待映射 | 未实现 | 23 | src/components/StatisticsWorkspace.tsx |
| StatisticsWorkspace.onBulkRecipeChange | onBulkRecipeChange | 待映射 | 未实现 | 23 | src/components/StatisticsWorkspace.tsx |
| StatisticsWorkspace.onBulkStationSlotApply | onBulkStationSlotApply | 待映射 | 未实现 | 26 | src/components/StatisticsWorkspace.tsx |
| StatisticsWorkspace.onClose | onClose | 待映射 | 未实现 | 23 | src/components/StatisticsWorkspace.tsx |
| StatisticsWorkspace.onCreatePlan | onCreatePlan | 待映射 | 未实现 | 23 | src/components/StatisticsWorkspace.tsx |
| StatisticsWorkspace.onDispatchGalacticExport | onDispatchGalacticExport | 待映射 | 未实现 | 26 | src/components/StatisticsWorkspace.tsx |
| StatisticsWorkspace.onFocusBeltNetwork | onFocusBeltNetwork | 待映射 | 未实现 | 23 | src/components/StatisticsWorkspace.tsx |
| StatisticsWorkspace.onFocusEntity | onFocusEntity | 待映射 | 未实现 | 23 | src/components/StatisticsWorkspace.tsx |
| StatisticsWorkspace.onGalacticDispatchAutomation | onGalacticDispatchAutomation | 待映射 | 未实现 | 26 | src/components/StatisticsWorkspace.tsx |
| StatisticsWorkspace.onGalacticDispatchThrottle | onGalacticDispatchThrottle | 待映射 | 未实现 | 26 | src/components/StatisticsWorkspace.tsx |
| StatisticsWorkspace.onGalacticExportEnabled | onGalacticExportEnabled | 待映射 | 未实现 | 26 | src/components/StatisticsWorkspace.tsx |
| StatisticsWorkspace.onGalacticExporterPausedChange | onGalacticExporterPausedChange | 待映射 | 未实现 | 26 | src/components/StatisticsWorkspace.tsx |
| StatisticsWorkspace.onGalacticExportPriority | onGalacticExportPriority | 待映射 | 未实现 | 26 | src/components/StatisticsWorkspace.tsx |
| StatisticsWorkspace.onInfiniteResearchAutomation | onInfiniteResearchAutomation | 待映射 | 未实现 | 25 | src/components/StatisticsWorkspace.tsx |
| StatisticsWorkspace.onOpenCanvasBookmark | onOpenCanvasBookmark | 待映射 | 未实现 | 24 | src/components/StatisticsWorkspace.tsx |
| StatisticsWorkspace.onRemoveCanvasBookmark | onRemoveCanvasBookmark | 待映射 | 未实现 | 24 | src/components/StatisticsWorkspace.tsx |
| StatisticsWorkspace.onRemovePlan | onRemovePlan | 待映射 | 未实现 | 23 | src/components/StatisticsWorkspace.tsx |
| StatisticsWorkspace.onRenameCanvasBookmark | onRenameCanvasBookmark | 待映射 | 未实现 | 24 | src/components/StatisticsWorkspace.tsx |
| StatisticsWorkspace.onSelectInfiniteResearch | onSelectInfiniteResearch | 待映射 | 未实现 | 25 | src/components/StatisticsWorkspace.tsx |
| StatisticsWorkspace.onSetPlanRecipe | onSetPlanRecipe | 待映射 | 未实现 | 23 | src/components/StatisticsWorkspace.tsx |
| StatisticsWorkspace.onUpdatePlan | onUpdatePlan | 待映射 | 未实现 | 23 | src/components/StatisticsWorkspace.tsx |
| SystemSpaceStationWorkspace.onClose | onClose | 待映射 | 未实现 | 26 | src/components/SystemSpaceStationWorkspace.tsx |
| SystemSpaceStationWorkspace.onDeliverMaterial | onDeliverMaterial | 待映射 | 未实现 | 26 | src/components/SystemSpaceStationWorkspace.tsx |
| SystemSpaceStationWorkspace.onRequestMode | onRequestMode | 待映射 | 未实现 | 26 | src/components/SystemSpaceStationWorkspace.tsx |
| SystemSpaceStationWorkspace.onSetModuleCount | onSetModuleCount | 待映射 | 未实现 | 26 | src/components/SystemSpaceStationWorkspace.tsx |
| SystemSpaceStationWorkspace.onSetOutput | onSetOutput | 待映射 | 未实现 | 26 | src/components/SystemSpaceStationWorkspace.tsx |
| SystemSpaceStationWorkspace.onStartConstruction | onStartConstruction | 待映射 | 未实现 | 26 | src/components/SystemSpaceStationWorkspace.tsx |
| SystemSpaceStationWorkspace.onUpgradeAllStations | onUpgradeAllStations | 待映射 | 未实现 | 26 | src/components/SystemSpaceStationWorkspace.tsx |
| SystemSpaceStationWorkspace.onUpgradeStation | onUpgradeStation | 待映射 | 未实现 | 26 | src/components/SystemSpaceStationWorkspace.tsx |
| TechnologyWorkspace.onCancelResearch | onCancelResearch | 待映射 | 未实现 | 25 | src/components/TechnologyWorkspace.tsx |
| TechnologyWorkspace.onClose | onClose | 待映射 | 未实现 | 25 | src/components/TechnologyWorkspace.tsx |
| TechnologyWorkspace.onInfiniteResearchAutomation | onInfiniteResearchAutomation | 待映射 | 未实现 | 25 | src/components/TechnologyWorkspace.tsx |
| TechnologyWorkspace.onLayoutChange | onLayoutChange | 待映射 | 未实现 | 25 | src/components/TechnologyWorkspace.tsx |
| TechnologyWorkspace.onPauseResearch | onPauseResearch | 待映射 | 未实现 | 25 | src/components/TechnologyWorkspace.tsx |
| TechnologyWorkspace.onRemoveQueued | onRemoveQueued | 待映射 | 未实现 | 25 | src/components/TechnologyWorkspace.tsx |
| TechnologyWorkspace.onResumeResearch | onResumeResearch | 待映射 | 未实现 | 25 | src/components/TechnologyWorkspace.tsx |
| TechnologyWorkspace.onSelect | onSelect | 待映射 | 未实现 | 25 | src/components/TechnologyWorkspace.tsx |
| TechnologyWorkspace.onSelectInfiniteResearch | onSelectInfiniteResearch | 待映射 | 未实现 | 25 | src/components/TechnologyWorkspace.tsx |
| TimeWarpIdleOverlay.onCancelSettlement | onCancelSettlement | 待映射 | 未实现 | 26 | src/components/TimeWarpIdleOverlay.tsx |
| TimeWarpIdleOverlay.onContinueNormally | onContinueNormally | 待映射 | 未实现 | 26 | src/components/TimeWarpIdleOverlay.tsx |
| TimeWarpIdleOverlay.onRetryRecovery | onRetryRecovery | 待映射 | 未实现 | 26 | src/components/TimeWarpIdleOverlay.tsx |
| TimeWarpIdleOverlay.onStop | onStop | 待映射 | 未实现 | 26 | src/components/TimeWarpIdleOverlay.tsx |
| TrayManagementDialog.onClose | onClose | 待映射 | 未实现 | 23 | src/components/TrayManagementDialog.tsx |
| TrayManagementDialog.onDiscard | onDiscard | 待映射 | 未实现 | 23 | src/components/TrayManagementDialog.tsx |
| TrayManagementDialog.onSetItemLimit | onSetItemLimit | 待映射 | 未实现 | 23 | src/components/TrayManagementDialog.tsx |
| TutorialWorkspace.onClose | onClose | 待映射 | 未实现 | 25 | src/components/TutorialWorkspace.tsx |
| WorkspaceFrame.onRequestClose | onRequestClose | 待映射 | 未实现 | 23 | src/components/WorkspaceFrame.tsx |

### modes

| 源 ID | 名称 | 当前候选 ID/文件 | 状态 | 后续任务 | 来源/UI |
|---|---|---|---|---:|---|
| normal | 标准单机 | 待映射 | 未实现 | 26 | src/components/OperationsWorkspace.tsx |
| pure_idle | 纯挂机推进 | 待映射 | 未实现 | 26 | src/components/OperationsWorkspace.tsx |
| speedrun | 速通 | 待映射 | 未实现 | 26 | src/components/OperationsWorkspace.tsx |
| time_warp | 时间扭曲 | 待映射 | 未实现 | 26 | src/components/OperationsWorkspace.tsx |

## 排除与许可

固定在线与用户范围排除条目见 [exclusions.json](../tests/fixtures/parity/exclusions.json)，每项均有理由。账号、云、公共银河网络不实现；手机、国际化和 DSPONLINE 旧存档导入不在范围内。

来源数据：Copyright 2026 snowsnow0926，PolyForm Noncommercial 1.0.0。仅冻结目录和操作标识，不复制原版实现、素材或玩家数据；原始许可与来源说明见 [来源说明](../tests/fixtures/parity/NOTICE.md)。
