# 独立行星工厂与星图实现计划

> **面向 AI 代理的工作者：** 必需子技能：使用 superpowers:subagent-driven-development（推荐）或 superpowers:executing-plans 逐任务实现此计划。每个实现任务必须先运行红灯测试，再写最小实现，并在提交前独立审查。

**目标：** 把现有单行星工厂升级为一个可保存、可持续模拟的多行星单机世界，并交付参考 DSPONLINE 信息结构的正式 Godot 星图工作区。

**架构：** 继续使用唯一 `GameState`。建筑、线路和手工任务保存在全局集合中并携带 `planet_id`；材料托盘、视口、工业指标和资源点按行星隔离；模拟器对所有已殖民行星运行，渲染与输入只投影活动行星。`GalaxySystem` 负责静态目录和勘探，`PlanetSystem` 负责殖民、切换和资源点命令，Main 处理 UI 发出的意图。

**技术栈：** Godot 4.7.2、GDScript、JSON 数据目录、项目自带场景测试 runner、PowerShell。

---

## 文件结构

- 创建 `data/galaxy.json`：3 个恒星系、6 颗行星、勘探/殖民要求和资源点模板。
- 重写 `scripts/game/GalaxySystem.gd`：严格目录、确定性资源、勘探事务与摘要查询。
- 重写 `scripts/game/PlanetSystem.gd`：活动行星、殖民事务、资源绑定和行星投影。
- 修改 `scripts/game/GameState.gd`：schema v6、多行星权威字段和活动托盘兼容视图。
- 修改 `scripts/game/GameStateCodec.gd`、`scripts/game/GameStateValidator.gd`、`scripts/game/SaveMigrationRegistry.gd`、`scripts/game/SaveSystem.gd`、`autoload/GameManager.gd`：v6 保存、验证、v5 迁移并删除第二份活动行星权威状态。
- 修改 `scripts/game/InventorySystem.gd`、`scripts/game/ConstructionSystem.gd`、`scripts/game/BlueprintSystem.gd`：命令显式作用于活动行星并阻止跨行星操作。
- 修改 `scripts/game/PowerSystem.gd`、`scripts/game/ProductionSystem.gd`、`scripts/game/BeltSystem.gd`、`scripts/game/HandcraftSystem.gd`、`scripts/game/SimulationEngine.gd`、`scripts/game/StatisticsSystem.gd`、`scripts/game/ProductionDiagnostics.gd`：按行星模拟且全局阶段只推进一次。
- 修改 `scripts/rendering/CardRenderer.gd`、`scripts/rendering/ConnectionRenderer.gd`、`scripts/input/InputHandler.gd`、`scenes/ui/MiniMap.gd`：只展示和操作活动行星。
- 重写 `scenes/ui/GalaxyMap.gd`，修改 `scenes/ui/FactoryWorkspaceUI.gd`、`scenes/main/Main.gd`、`scenes/main/Main.tscn`、`autoload/EventBus.gd`：正式星图、互斥工作区和权威意图路由。
- 创建 `scripts/test/TestGalaxyLogistics.gd` 和 `scenes/test/TestGalaxyLogistics.tscn`：任务 12 的权威行为场景；文件名沿用路线图，测试不包含任务 13 的星际运输。
- 修改 `scripts/test/TestBaseline.gd`、`scripts/test/TestStatePersistence.gd`、`scripts/test/TestSimulationCore.gd`、`scripts/test/TestInventoryConstruction.gd`、`scripts/test/TestAdvancedCanvas.gd`、`scripts/test/TestBlueprints.gd`、`scripts/test/TestStatisticsCodex.gd`：更新受 schema/目录/默认 planet 影响的既有断言。
- 修改 `tools/run_tests.ps1`、`README.md`、`docs/PROJECT_STATUS.md`、`docs/current/SINGLE_PLAYER_ROADMAP.md`：第十道门禁和交付记录。

### 任务 1：星区目录、schema v6 与无损迁移

**文件：**
- 创建：`data/galaxy.json`
- 重写：`scripts/game/GalaxySystem.gd`
- 修改：`scripts/game/GameState.gd`
- 修改：`scripts/game/GameStateCodec.gd`
- 修改：`scripts/game/GameStateValidator.gd`
- 修改：`scripts/game/SaveMigrationRegistry.gd`
- 修改：`scripts/game/SaveSystem.gd`
- 修改：`autoload/GameManager.gd`
- 创建：`scripts/test/TestGalaxyLogistics.gd`
- 创建：`scenes/test/TestGalaxyLogistics.tscn`
- 修改：`scripts/test/TestBaseline.gd`
- 修改：`scripts/test/TestStatePersistence.gd`

- [ ] **步骤 1：创建第十个测试场景骨架和 schema 红灯测试**

在 `TestGalaxyLogistics.gd` 中沿用既有 `_expect()`/失败计数/退出方式，先加入以下断言，并保证成功标记仅由最终汇总打印：

```gdscript
func _test_schema_v6_defaults() -> void:
	var state := GameState.new()
	_expect(GameState.SCHEMA_VERSION == 6, "planet saves use schema v6")
	_expect(state.active_planet_id == "home", "home starts active")
	_expect(state.explored_system_ids == ["helios"], "helios starts explored")
	_expect(state.colonized_planet_ids == ["home"], "home starts colonized")
	_expect(state.planet_inventories.has("home"), "home tray exists")
	_expect(state.planet_inventory == state.get_active_planet_inventory(), "compatibility tray mirrors active planet")
```

场景根节点脚本运行全部测试；有失败时打印 `GALAXY LOGISTICS TESTS FAILED` 并 `get_tree().quit(1)`，全部通过时只打印一次 `GALAXY LOGISTICS TESTS PASSED`。

- [ ] **步骤 2：运行测试确认红灯**

```powershell
& 'C:\Program Files\Godot\Godot.exe' --headless --path . --quit-after 600 res://scenes/test/TestGalaxyLogistics.tscn
```

预期：因 `SCHEMA_VERSION` 仍为 5 或新字段/方法不存在而退出非零；不得把解析失败当作预期行为，测试脚本本身必须可解析。

- [ ] **步骤 3：加入 v6 权威字段与活动托盘 API**

在 `GameState.gd` 中实现：

```gdscript
const SCHEMA_VERSION: int = 6
const HOME_PLANET_ID := "home"

var active_planet_id := HOME_PLANET_ID
var galaxy_seed := 240721
var explored_system_ids: Array = ["helios"]
var colonized_planet_ids: Array = [HOME_PLANET_ID]
var exploration_missions: Array = []
var survey_progress_by_system := {"helios": 1.0}
var planet_inventories := {HOME_PLANET_ID: {}}
var planet_viewports := {HOME_PLANET_ID: {"position": Vector2.ZERO, "zoom": Vector2.ONE}}
var planet_metrics := {HOME_PLANET_ID: {}}
var portable_fleet := {"logistics_drone": 0, "logistics_vessel": 0}
var resource_sites: Dictionary = {}

func get_planet_inventory(planet_id: String) -> Dictionary
func get_active_planet_inventory() -> Dictionary
func set_active_planet(planet_id: String) -> bool
func sync_active_planet_inventory() -> void
```

`set_active_planet()` 必须先同步旧托盘、再切换、最后令 `planet_inventory` 成为目标托盘的运行时兼容视图；失败不得改状态。`copy_from()` 同步复制所有 v6 字段并重建活动视图。

- [ ] **步骤 4：编写目录严格性与确定性红灯测试**

```gdscript
var galaxy := GalaxySystem.new(state)
_expect(galaxy.get_catalog_errors().is_empty(), "shipped galaxy catalog is valid")
_expect(galaxy.get_all_system_ids() == ["borealis", "helios", "neutron"], "system ids are stable and sorted")
_expect(galaxy.get_all_planet_ids() == ["ashen", "boreal_giant", "frost", "giant", "home", "magnetar"], "six planet ids are stable")
var first := galaxy.build_resource_sites_for_planet("home", 240721)
var same := galaxy.build_resource_sites_for_planet("home", 240721)
var changed := galaxy.build_resource_sites_for_planet("home", 240722)
_expect(first == same, "same seed creates identical reserves")
_expect(_has_changed_finite_reserve(first, changed), "a different seed changes a finite reserve")
```

还要把返回目录修改后再次查询，断言内部目录未被污染；用测试临时 JSON 路径分别覆盖重复 ID、未知物品、未知科技、悬空前置星系、非法距离和负成本，断言稳定错误码。

- [ ] **步骤 5：创建目录并重写 GalaxySystem**

`galaxy.json` 只引用现有目录中的 `iron_ore`、`copper_ore`、`coal`、`stone`、`crude_oil`、`water`、`hydrogen`、`deuterium`、`space_warper`、`logistics_drone` 和 `logistics_vessel`。根结构固定为：

```json
{
  "systems": [{"id":"helios","position":{"x":0,"y":0},"planet_ids":["home","ashen","giant"],"exploration_cost":[]}],
  "planets": [{"id":"home","system_id":"helios","colonization_cost":[],"resource_sites":[]}]
}
```

补齐批准规格中的 3 系/6 星显示字段、资源模板和门槛。`GalaxySystem` 构造函数接受可注入目录路径：

```gdscript
const DEFAULT_CATALOG_PATH := "res://data/galaxy.json"

func _init(state: GameState, catalog_path: String = DEFAULT_CATALOG_PATH) -> void
func get_catalog_errors() -> Array
func get_star_system(system_id: String) -> Dictionary
func get_planet(planet_id: String) -> Dictionary
func get_all_system_ids() -> Array
func get_all_planet_ids() -> Array
func build_resource_sites_for_planet(planet_id: String, seed: int) -> Dictionary
```

所有查询深拷贝、所有 ID 排序。储量只使用整数/字符串确定性哈希，不使用全局 `rand*()`；无限资源保存 `infinite: true`，有限资源的 `remaining == capacity > 0`。

- [ ] **步骤 6：编写 v5 迁移和 v6 round-trip 红灯测试**

从当前 v5 fixture 构造两栋建筑、一条线路、一个手工任务、已有库存与 `_next_id`，断言：

```gdscript
var result := SaveMigrationRegistry.migrate_to_current(v5_payload)
_expect(result["ok"], "v5 save migrates")
var data: Dictionary = result["data"]
_expect(data["planet_inventories"]["home"] == v5_payload["planet_inventory"], "legacy tray moves to home")
_expect(not data.has("planet_inventory"), "v6 does not persist the compatibility alias")
_expect(data["buildings"]["building_1"]["planet_id"] == "home", "legacy building belongs to home")
_expect(data["connections"]["connection_2"]["planet_id"] == "home", "legacy belt belongs to home")
_expect(data["handcraft_queue"][0]["planet_id"] == "home", "legacy handcraft job belongs to home")
_expect(data["next_id"] == v5_payload["next_id"], "migration preserves the next stable id")
```

迁移后 decode→encode，断言全部 v6 字段、Vector2 视口、资源点绑定和 `_next_id` 相同；断言编码结果不含根字段 `planet_inventory`。

- [ ] **步骤 7：实现 codec、验证器、迁移与单一活动行星权威**

`GameStateCodec` 编码 v6 字段，解码时先填充 `planet_inventories` 再调用活动视图同步。`SaveMigrationRegistry` 增加 `5` 分支和 `_migrate_v5_to_v6()`；使用 `GalaxySystem.build_resource_sites_for_planet()` 建立确定性资源点，并按输出物品、距离、资源点 ID 的稳定顺序绑定旧母星采集器。

`GameStateValidator` 对以下内容返回稳定错误：未知/未殖民活动行星、未知集合成员、缺少已殖民托盘、无 `planet_id` 实体、跨行星线路、非法资源绑定、负数或非有限储量、非法视口、非法勘探任务。`SaveSystem` v6 metadata 的 `active_planet` 仅作兼容显示并从 `state.active_planet_id` 派生；`GameManager` 删除 `_active_planet`，`get_active_planet()` 直接返回 `game_state.active_planet_id`。

- [ ] **步骤 8：更新受影响既有测试并验证**

更新 `TestBaseline.gd` 的数据文件数量为 7；更新持久化测试的预期 schema 和 canonical payload。运行：

```powershell
& 'C:\Program Files\Godot\Godot.exe' --headless --path . --quit-after 600 res://scenes/test/TestGalaxyLogistics.tscn
& 'C:\Program Files\Godot\Godot.exe' --headless --path . --quit-after 600 res://scenes/test/TestStatePersistence.tscn
& 'C:\Program Files\Godot\Godot.exe' --headless --path . --quit-after 600 res://scenes/test/TestBaseline.tscn
```

预期三个场景退出码均为 0，各自成功标记恰好一次，无 `SCRIPT ERROR`、`Parse Error` 或生命周期泄漏。

- [ ] **步骤 9：独立审查并提交**

审查目录深拷贝、确定性算法、迁移字段完整性、兼容别名不会被重复持久化、失败验证不会吞掉合法旧状态。提交：

```powershell
git add data/galaxy.json scripts/game/GalaxySystem.gd scripts/game/GameState.gd scripts/game/GameStateCodec.gd scripts/game/GameStateValidator.gd scripts/game/SaveMigrationRegistry.gd scripts/game/SaveSystem.gd autoload/GameManager.gd scripts/test/TestGalaxyLogistics.gd scenes/test/TestGalaxyLogistics.tscn scripts/test/TestBaseline.gd scripts/test/TestStatePersistence.gd
git commit -m "feat: add persistent galaxy state"
```

### 任务 2：行星命令、殖民事务与真实资源点

**文件：**
- 重写：`scripts/game/PlanetSystem.gd`
- 修改：`scripts/game/GameState.gd`
- 修改：`scripts/game/InventorySystem.gd`
- 修改：`scripts/game/ConstructionSystem.gd`
- 修改：`scripts/game/ProductionSystem.gd`
- 修改：`scripts/test/TestGalaxyLogistics.gd`
- 修改：`scripts/test/TestInventoryConstruction.gd`

- [ ] **步骤 1：编写活动行星和殖民原子性红灯测试**

构造已探索 `borealis`、活动母星库存足够但载具不足的状态，保存 `GameStateCodec.state_digest_payload(state)`，调用殖民并断言 `missing_vehicle` 且 digest 完全相同；依次补载具和材料后断言：

```gdscript
var colonize := planets.try_colonize_planet("frost")
_expect(colonize["ok"], "ready planet colonizes")
_expect(state.colonized_planet_ids.has("frost"), "target becomes colonized")
_expect(state.planet_inventories.has("frost"), "target tray initializes")
_expect(state.planet_viewports.has("frost"), "target viewport initializes")
_expect(float(state.portable_fleet["logistics_vessel"]) == fleet_before - 1.0, "vehicle is charged once")
_expect(planets.try_set_active_planet("frost")["ok"], "colonized target becomes active")
_expect(state.active_planet_id == "frost", "authority records the active planet")
```

覆盖 `unknown_planet`、`system_locked`、`technology_locked`、`not_colonized`、`already_colonized`、`missing_materials`、`missing_vehicle`。

- [ ] **步骤 2：实现 PlanetSystem 查询与原子命令**

提供稳定接口：

```gdscript
func get_planet_buildings(planet_id: String) -> Array
func get_planet_connections(planet_id: String) -> Array
func get_planet_resource_sites(planet_id: String) -> Array
func get_colonization_requirements(planet_id: String) -> Dictionary
func try_colonize_planet(planet_id: String) -> Dictionary
func try_set_active_planet(planet_id: String) -> Dictionary
func try_bind_extractor(building_id: String, resource_site_id: String) -> Dictionary
func get_planet_industrial_summary(planet_id: String) -> Dictionary
```

所有命令返回 `{"ok": bool, "reason": String, "message": String, "details": Dictionary}`。殖民先在副本上验证和扣费，全部成功后一次写回；失败不得消耗 ID、材料、载具、视口或选择。

- [ ] **步骤 3：编写资源绑定、放置和耗尽红灯测试**

在 home 和 frost 各建同物品资源点；断言跨行星绑定返回 `invalid_resource_site`，物品不匹配返回 `resource_mismatch`，耗尽点返回 `resource_depleted`。在合法点附近放置矿机，断言自动选择距离最近、ID 次序稳定的兼容点。驱动真实生产后断言：

```gdscript
var before := float(state.resource_sites[site_id]["remaining"])
var output_before := float(state.buildings[miner_id]["output_buffer"].get("iron_ore", 0.0))
production.update(60.0)
var produced := float(state.buildings[miner_id]["output_buffer"].get("iron_ore", 0.0)) - output_before
_expect(is_equal_approx(float(state.resource_sites[site_id]["remaining"]), before - produced), "actual output depletes the reserve")
_expect(float(state.resource_sites[site_id]["remaining"]) >= 0.0, "reserve never becomes negative")
```

无限水点连续生产后 `remaining` 不变；有限点不足一个完整批次时只产出剩余量，再次 tick 状态为 `resource_depleted`。

- [ ] **步骤 4：实现活动托盘库存和资源点放置**

给 `InventorySystem` 增加可选 `planet_id` 或显式 `get_planet_inventory()` 路径；默认命令使用活动行星，模拟调用必须传实体 `planet_id`。`ConstructionSystem.try_place_building()` 写入 `planet_id = state.active_planet_id`；采集器在提交建筑前调用最近资源点查询，找不到时原子失败。`ProductionSystem` 从建筑的 `resource_site_id` 读取真实储量，只按实际写入量递减。

- [ ] **步骤 5：验证聚焦和库存施工回归**

```powershell
& 'C:\Program Files\Godot\Godot.exe' --headless --path . --quit-after 600 res://scenes/test/TestGalaxyLogistics.tscn
& 'C:\Program Files\Godot\Godot.exe' --headless --path . --quit-after 600 res://scenes/test/TestInventoryConstruction.tscn
```

预期两个场景绿灯，既有单行星施工仍默认作用于 home。

- [ ] **步骤 6：独立审查并提交**

审查每条失败路径的 digest、资源点选择次序、无限资源、最后不足批次以及库存上限。提交：

```powershell
git add scripts/game/PlanetSystem.gd scripts/game/GameState.gd scripts/game/InventorySystem.gd scripts/game/ConstructionSystem.gd scripts/game/ProductionSystem.gd scripts/test/TestGalaxyLogistics.gd scripts/test/TestInventoryConstruction.gd
git commit -m "feat: add atomic planetary colonization"
```

### 任务 3：多行星固定步长模拟隔离

**文件：**
- 修改：`scripts/game/PowerSystem.gd`
- 修改：`scripts/game/ProductionSystem.gd`
- 修改：`scripts/game/BeltSystem.gd`
- 修改：`scripts/game/HandcraftSystem.gd`
- 修改：`scripts/game/SimulationEngine.gd`
- 修改：`scripts/game/StatisticsSystem.gd`
- 修改：`scripts/game/ProductionDiagnostics.gd`
- 修改：`scripts/game/TechnologySystem.gd`
- 修改：`scripts/game/ObjectiveSystem.gd`
- 修改：`scripts/test/TestGalaxyLogistics.gd`
- 修改：`scripts/test/TestSimulationCore.gd`
- 修改：`scripts/test/TestStatisticsCodex.gd`

- [ ] **步骤 1：编写电力和线路隔离红灯测试**

创建 home 发电机、home 熔炉和 frost 熔炉，只给 home 加燃料；运行电力阶段后断言 frost 供电效率为 0。分别在命令边界和 validator 构造 home→frost 线路，断言 `cross_planet_connection`。合法线路必须保存线路端点共同的 `planet_id`。

```gdscript
_expect(float(state.buildings[home_smelter]["power_efficiency"]) > 0.0, "home generator powers home")
_expect(float(state.buildings[frost_smelter]["power_efficiency"]) == 0.0, "home power does not cross planets")
_expect(belts.create_belt(home_smelter, frost_smelter, "iron_ingot") == "", "belt command rejects a cross-planet edge")
```

- [ ] **步骤 2：按 planet_id 分组电力和线路**

`PowerSystem.update()` 先以 `planet_id` 建组，再在组内计算燃料、发电、需求和效率；`get_power_info(planet_id = "")` 默认返回活动行星并允许显式查询。`BeltSystem.create_belt()` 在消耗 ID/施工件之前验证端点与活动行星；`update()` 忽略并报告加载边界遗留的非法线路。

- [ ] **步骤 3：编写非活动行星持续生产与全局只推进一次红灯测试**

让 home 和 frost 各有一条完整生产链，活动行星保持 home，运行 `SimulationEngine` 120 个固定 tick，断言两边缓冲区均增长。记录 `elapsed_time` 和研究进度，断言增加量与固定时间一致而不是乘以殖民行星数。把一个 handcraft job 固定到 frost 后切回 home，完成产物只能进入 frost 托盘。

- [ ] **步骤 4：实现模拟索引与勘探阶段**

`ProductionSystem` 遍历全局实体但使用实体 `planet_id` 的环境/资源点；`HandcraftSystem.queue_recipe()` 写入创建时的 `planet_id`，完成时写该托盘。`TechnologySystem` 的研究成本与全局研究实验室检测继续每 tick 一次；玩家发起研究仍从活动行星托盘扣成本。`ObjectiveSystem` 明确读取活动行星库存，防止无意把全部行星库存相加。

把模拟阶段固定为：

```gdscript
const PHASE_ORDER := ["power", "production", "handcraft", "belt", "galaxy", "research", "statistics"]
```

`SimulationEngine` 持有唯一 `GalaxySystem`，每个 fixed tick 只调用一次 `update_exploration(FIXED_DELTA)`、研究和总时间。统计服务保留全局汇总，同时按 `planet_id` 提供 `get_planet_summary()`；诊断条目始终携带真实 `planet_id`。

- [ ] **步骤 5：验证模拟、统计与聚焦场景**

```powershell
& 'C:\Program Files\Godot\Godot.exe' --headless --path . --quit-after 600 res://scenes/test/TestGalaxyLogistics.tscn
& 'C:\Program Files\Godot\Godot.exe' --headless --path . --quit-after 600 res://scenes/test/TestSimulationCore.tscn
& 'C:\Program Files\Godot\Godot.exe' --headless --path . --quit-after 600 res://scenes/test/TestStatisticsCodex.tscn
```

预期固定步长、统计窗口和单行星旧断言保持绿灯。

- [ ] **步骤 6：独立审查并提交**

审查循环复杂度、跨行星电力/线路、后台行星推进、全局研究/时间不倍增、手工任务归属和统计缓存仍不进存档。提交：

```powershell
git add scripts/game/PowerSystem.gd scripts/game/ProductionSystem.gd scripts/game/BeltSystem.gd scripts/game/HandcraftSystem.gd scripts/game/SimulationEngine.gd scripts/game/StatisticsSystem.gd scripts/game/ProductionDiagnostics.gd scripts/game/TechnologySystem.gd scripts/game/ObjectiveSystem.gd scripts/test/TestGalaxyLogistics.gd scripts/test/TestSimulationCore.gd scripts/test/TestStatisticsCodex.gd
git commit -m "feat: isolate planetary simulation"
```

### 任务 4：活动画布投影、切换与相机恢复

**文件：**
- 修改：`scripts/rendering/CardRenderer.gd`
- 修改：`scripts/rendering/ConnectionRenderer.gd`
- 修改：`scripts/input/InputHandler.gd`
- 修改：`scripts/game/BlueprintSystem.gd`
- 修改：`scenes/ui/MiniMap.gd`
- 修改：`scenes/ui/FactoryWorkspaceUI.gd`
- 修改：`scenes/main/Main.gd`
- 修改：`autoload/EventBus.gd`
- 修改：`scripts/test/TestGalaxyLogistics.gd`
- 修改：`scripts/test/TestAdvancedCanvas.gd`
- 修改：`scripts/test/TestBlueprints.gd`

- [ ] **步骤 1：编写活动投影和输入保护红灯测试**

在两颗行星放置重叠坐标建筑和各自线路，切换活动行星后断言渲染器的可见 ID、连接绘制投影、MiniMap 标记和 InputHandler 命中只包含目标行星。尝试通过保留的另一行星 ID 删除、拖动、框选、连接和捕获蓝图，断言均失败且 digest 不变。

```gdscript
_expect(card_renderer.get_visible_building_ids() == [frost_building], "cards project only the active planet")
_expect(connection_renderer.get_visible_connection_ids() == [frost_belt], "belts project only the active planet")
_expect(not input_handler.request_delete(home_building), "input rejects an inactive building")
```

- [ ] **步骤 2：实现共享活动行星过滤器**

渲染器、连接渲染器和 MiniMap 从 `GameState.active_planet_id` 过滤，不复制自己的活动行星字段。InputHandler 给所有实体入口统一调用：

```gdscript
func _is_active_entity(entity_id: String) -> bool:
	var entity: Dictionary = game_state.buildings.get(entity_id, {})
	return not entity.is_empty() and String(entity.get("planet_id", "")) == game_state.active_planet_id
```

`BlueprintSystem.capture()` 只接受同一活动行星实体；部署写活动 `planet_id`，失败不消耗施工库存或稳定 ID。

- [ ] **步骤 3：编写切换清理与相机恢复红灯测试**

在 home 保存相机 A、frost 保存相机 B。开始放置、连接、拖动、框选并创建多选，然后切换到 frost；断言临时操作和选择全部取消、全局 `cursor_payload` 原样保留、相机为 B。切回 home 后相机恢复 A。失败切换不得取消当前操作。

- [ ] **步骤 4：实现 Main 唯一切换闭环**

新增 `EventBus.active_planet_changed(planet_id)`。Main 的 `try_travel_to_planet()` 顺序固定为：保存旧相机→调用 `PlanetSystem.try_set_active_planet()`→成功后取消 InputHandler 临时操作/清空选择→应用目标视口→刷新渲染、MiniMap、Inspector 和工作区→发信号。所有 UI 和诊断定位调用该入口。

跨星诊断定位先验证目标已殖民，成功切换后才移动相机并选中；不得隐式殖民。`FactoryWorkspaceUI` 的材料库存和建筑计数读取活动投影，施工库存保持全局。

- [ ] **步骤 5：验证画布与蓝图回归**

```powershell
& 'C:\Program Files\Godot\Godot.exe' --headless --path . --quit-after 600 res://scenes/test/TestGalaxyLogistics.tscn
& 'C:\Program Files\Godot\Godot.exe' --headless --path . --quit-after 600 res://scenes/test/TestAdvancedCanvas.tscn
& 'C:\Program Files\Godot\Godot.exe' --headless --path . --quit-after 600 res://scenes/test/TestBlueprints.tscn
```

预期活动投影和既有画布手势、蓝图原子性同时通过。

- [ ] **步骤 6：独立审查并提交**

审查是否还有第二份活动行星状态、所有输入入口是否统一守卫、相机是否在成功切换前被错误覆盖、光标载荷是否被清空。提交：

```powershell
git add scripts/rendering/CardRenderer.gd scripts/rendering/ConnectionRenderer.gd scripts/input/InputHandler.gd scripts/game/BlueprintSystem.gd scenes/ui/MiniMap.gd scenes/ui/FactoryWorkspaceUI.gd scenes/main/Main.gd autoload/EventBus.gd scripts/test/TestGalaxyLogistics.gd scripts/test/TestAdvancedCanvas.gd scripts/test/TestBlueprints.gd
git commit -m "feat: project the active planet factory"
```

### 任务 5：勘探流程与正式星图工作区

**文件：**
- 修改：`scripts/game/GalaxySystem.gd`
- 重写：`scenes/ui/GalaxyMap.gd`
- 修改：`scenes/ui/FactoryWorkspaceUI.gd`
- 修改：`scenes/main/Main.gd`
- 修改：`scenes/main/Main.tscn`
- 修改：`scripts/test/TestGalaxyLogistics.gd`
- 修改：`scripts/test/TestFactoryWorkspace.gd`

- [ ] **步骤 1：编写勘探门槛和固定时间红灯测试**

分别覆盖未知星系、科技未解锁、前置星系缺失、材料不足、任务已运行和已探索。每次失败比较 digest 不变。成功时仅从活动托盘扣一次成本并创建任务；用两个不同帧分块推进相同固定模拟秒，断言进度相同，完成后加入 explored 且首颗行星成为先遣殖民点。

```gdscript
var started := galaxy.try_explore_system("borealis")
_expect(started["ok"], "ready system starts surveying")
_expect(state.exploration_missions.size() == 1, "one background mission is created")
_run_fixed_seconds(engine, galaxy.get_exploration_duration("borealis"))
_expect(state.explored_system_ids.has("borealis"), "survey completes on simulation time")
_expect(state.colonized_planet_ids.has("frost"), "first planet becomes a pioneer landing")
```

- [ ] **步骤 2：实现勘探事务、搜索和摘要**

`GalaxySystem` 增加：

```gdscript
func get_exploration_requirements(system_id: String) -> Dictionary
func try_explore_system(system_id: String) -> Dictionary
func update_exploration(delta: float) -> void
func search(query: String) -> Dictionary
func get_system_summary(system_id: String) -> Dictionary
func get_planet_summary(planet_id: String) -> Dictionary
func get_system_distance(from_system_id: String, to_system_id: String) -> float
```

搜索大小写不敏感，匹配名称、代码、ID、资源和环境；结果按目录稳定 ID 排序。摘要只读并深拷贝，不修改调查任务。

- [ ] **步骤 3：编写正式 UI 红灯测试**

实例化 `Main.tscn`，断言星图挂在 `FactoryWorkspaceUI/GalaxyMap` 且初始隐藏；存在真实 `LineEdit`、系统列表、行星列表、详情滚动、资源/殖民/工业摘要以及三个动作按钮。打开星图再打开科技/战役/蓝图/分析，断言最多一个工作区可见；星图可见时 `is_pointer_over_ui()` 对其内部坐标返回 true。

模拟点击后只捕获 `explore_requested`、`colonize_requested`、`travel_requested`，断言 UI 自身不直接改变 digest；连接 Main 后再断言权威命令改变状态并给出通知。

- [ ] **步骤 4：重写 GalaxyMap 并接入工作区**

`GalaxyMap.gd` 只持有查询服务和状态引用，声明：

```gdscript
signal explore_requested(system_id: String)
signal colonize_requested(planet_id: String)
signal travel_requested(planet_id: String)

func configure(state: GameState, galaxy: GalaxySystem, planets: PlanetSystem) -> void
func refresh_now() -> void
func get_selected_system_id() -> String
func get_selected_planet_id() -> String
```

用锚点和 `MarginContainer/HBoxContainer/VBoxContainer/ScrollContainer` 建正式固定边界布局，禁止逐帧重建控件。保留系统/行星选择、搜索文本和滚动值。`FactoryWorkspaceUI.show_exclusive_workspace()` 与 `is_pointer_over_ui()` 都加入 `GalaxyMap`；顶栏增加“星图”入口。Main 创建唯一两个领域服务、连接三个意图，并复用任务 4 的旅行入口。

- [ ] **步骤 5：验证正式 UI 和主场景**

```powershell
& 'C:\Program Files\Godot\Godot.exe' --headless --path . --quit-after 600 res://scenes/test/TestGalaxyLogistics.tscn
& 'C:\Program Files\Godot\Godot.exe' --headless --path . --quit-after 600 res://scenes/test/TestFactoryWorkspace.tscn
& 'C:\Program Files\Godot\Godot.exe' --headless --path . --quit-after 120 res://scenes/main/Main.tscn
```

预期星图行为和原有工作区互斥绿灯；Main 120 帧退出码 0，无布局节点重复、空引用或脚本错误。

- [ ] **步骤 6：独立审查并提交**

审查 UI 不写权威状态、长列表可滚动、搜索稳定、按钮禁用理由与领域结果一致、关闭后相机恢复。提交：

```powershell
git add scripts/game/GalaxySystem.gd scenes/ui/GalaxyMap.gd scenes/ui/FactoryWorkspaceUI.gd scenes/main/Main.gd scenes/main/Main.tscn scripts/test/TestGalaxyLogistics.gd scripts/test/TestFactoryWorkspace.gd
git commit -m "feat: add the formal galaxy workspace"
```

### 任务 6：第十道门禁、文档与自动合并

**文件：**
- 修改：`tools/run_tests.ps1`
- 修改：`README.md`
- 修改：`docs/PROJECT_STATUS.md`
- 修改：`docs/current/SINGLE_PLAYER_ROADMAP.md`
- 修改：`scripts/test/TestGalaxyLogistics.gd`

- [ ] **步骤 1：把第十个场景加入严格 runner**

新增：

```powershell
@{
    Name = "Galaxy logistics"
    ScenePath = Join-Path $repoRoot "scenes\test\TestGalaxyLogistics.tscn"
    ResourcePath = "res://scenes/test/TestGalaxyLogistics.tscn"
    SuccessMarker = "GALAXY LOGISTICS TESTS PASSED"
    FailureMarker = "GALAXY LOGISTICS TESTS FAILED"
}
```

先临时使一条期望失败并运行 runner，确认缺少唯一成功标记或出现失败标记时退出非零；恢复测试后再运行，证明门禁不是无条件绿灯。

- [ ] **步骤 2：同步交付文档**

README 说明星图入口、勘探、殖民、行星切换、活动托盘和后台工厂；`PROJECT_STATUS.md` 把 Stage 4 任务 12 标为完成；路线图勾选任务 12 全部步骤并写入日期、schema v6、3 系/6 星、资源耗尽、后台模拟、正式星图和第十场景的实测事实。明确任务 13 星际物流仍未实现，在线服务继续排除。

- [ ] **步骤 3：运行完整门禁**

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\tools\run_tests.ps1
```

预期十个场景各自成功标记恰好一次，退出码 0；无 `SCRIPT ERROR`、`Parse Error`、`ObjectDB instances were leaked` 或 `resources still in use at exit`。

- [ ] **步骤 4：运行最终主场景和静态检查**

```powershell
& 'C:\Program Files\Godot\Godot.exe' --headless --path . --quit-after 120 res://scenes/main/Main.tscn
git diff --check
git status --short --branch
```

预期 Main 退出码 0；diff check 无输出；任务工作树只包含计划内文档收尾变更。

- [ ] **步骤 5：最终代码审查并提交交付记录**

审查重点：全局只有一个活动行星权威值；离线范围没有引入网络依赖；殖民/勘探失败原子；非活动行星持续模拟；UI 不直接写状态；旧 v5 存档无损；所有新字段有验证和 round-trip。

```powershell
git add tools/run_tests.ps1 README.md docs/PROJECT_STATUS.md docs/current/SINGLE_PLAYER_ROADMAP.md scripts/test/TestGalaxyLogistics.gd
git commit -m "docs: complete planetary factories task"
```

- [ ] **步骤 6：按用户约定自动合并并清理**

先确认主仓库现有 `project.godot` 和路线图未提交修改仍可恢复；必要时只暂存这两个已知用户修改。然后在主仓库执行：

```powershell
git merge --ff-only stage4/planet-factories-star-map-codex
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\tools\run_tests.ps1
& 'C:\Program Files\Godot\Godot.exe' --headless --path . --quit-after 120 res://scenes/main/Main.tscn
```

合并树验证通过后恢复用户修改，再移除任务 worktree 并删除已合并分支。不得触碰 `.worktrees/recovery-baseline`，不得自动推送远端。

---

## 最终验收矩阵

| 规格承诺 | 首要测试位置 | 交付任务 |
| --- | --- | --- |
| schema v6、v5 无损迁移、canonical 保存 | `TestStatePersistence`、`TestGalaxyLogistics` | 任务 1 |
| 3 系/6 星、确定性资源目录 | `TestGalaxyLogistics` | 任务 1 |
| 殖民原子性、稳定失败原因 | `TestGalaxyLogistics` | 任务 2 |
| 资源点绑定、有限耗尽、无限资源 | `TestGalaxyLogistics` | 任务 2 |
| 电力、线路、库存、手工任务按行星隔离 | `TestGalaxyLogistics`、`TestSimulationCore` | 任务 3 |
| 非活动行星持续模拟，全局研究/时间只推进一次 | `TestGalaxyLogistics` | 任务 3 |
| 活动画布、输入保护、视口恢复 | `TestGalaxyLogistics`、`TestAdvancedCanvas` | 任务 4 |
| 星图搜索、摘要、意图、互斥与命中 | `TestGalaxyLogistics`、`TestFactoryWorkspace` | 任务 5 |
| 既有九场景无回归、第十场景严格门禁 | `tools/run_tests.ps1` | 任务 6 |
| 离线范围、文档状态、自动合并与保留用户改动 | 文档 diff、主仓库状态 | 任务 6 |
