# 任务 12：独立行星工厂与星图设计规格

## 目标

在 CardFactory 的现有单机权威状态上交付第一版多行星工厂与正式星图：全星区建筑、线路和资源点使用全局稳定 ID 并携带 `planet_id`；行星材料库存、视口和工业指标彼此隔离；所有已殖民行星持续参与固定步长模拟；玩家可以勘探星系、原子殖民目标行星并在正式 UI 中切换工厂。实现参考 DSPONLINE 当前离线单机行为，但使用 Godot 原生结构，不复制其 React 源码、素材或存档格式。

## 范围

本任务交付 DSPONLINE 早期稳定基线对应的 3 个恒星系和 6 颗行星：`helios`（`home`、`ashen`、`giant`）、`borealis`（`frost`、`boreal_giant`）和 `neutron`（`magnetar`）。星区拓扑与稳定 ID 来自 `data/galaxy.json`；存档保存确定性星区种子，种子只影响有限矿储量和允许波动的环境数值。

本任务不实现星际货物运输、物流站调度、翘曲航行、戴森工程、完整 8 星系/22 行星内容目录、DSPONLINE 存档导入或任何在线服务。跨行星物流属于任务 13；完整内容数量对齐属于后续 DSPONLINE 单机内容阶段。

## 备选方案与决定

### 方案 A：全局实体携带 `planet_id`（采用）

`GameState` 继续只有一个。建筑、线路和手工任务携带 `planet_id`，模拟器按行星建立索引，渲染和输入只投影活动行星。该方案与 DSPONLINE 的生产实现一致，支持非活动行星持续运行，也为任务 13 的星际物流提供稳定端点。

### 方案 B：每颗行星保存嵌套工厂快照（不采用）

切换时把当前建筑和线路整体换入换出。改造量较小，但非活动工厂会冻结，跨星统计、物流和全局诊断需要反复展开快照，容易发生引用漂移。

### 方案 C：每颗行星一个 `GameState`（不采用）

隔离直观，但科技、战役、时间、稳定 ID 和保存协调器会被复制，必须额外实现跨状态事务，不符合当前单机权威状态模型。

## 权威状态模型

`GameState.SCHEMA_VERSION` 从 5 升到 6。新增持久字段：

```gdscript
var active_planet_id := "home"
var galaxy_seed := 240721
var explored_system_ids: Array = ["helios"]
var colonized_planet_ids: Array = ["home"]
var exploration_missions: Array = []
var survey_progress_by_system := {"helios": 1.0}
var planet_inventories := {"home": {}}
var planet_viewports := {"home": {"position": Vector2.ZERO, "zoom": Vector2.ONE}}
var planet_metrics := {"home": {}}
var portable_fleet := {"logistics_drone": 0, "logistics_vessel": 0}
var resource_sites: Dictionary = {}
```

现有 `buildings` 和 `connections` 保持全局字典，每条记录增加 `planet_id`。稳定 ID 仍由一个全局 `_next_id` 生成，允许不同星球出现相同业务前缀，但不允许相同完整 ID。线路还必须满足源、目标和自身的 `planet_id` 完全一致。

现有 `planet_inventory` 作为活动行星材料托盘的运行时兼容视图。权威写入通过 `GameState.get_planet_inventory(planet_id)`、`get_active_planet_inventory()` 和 `set_active_planet()` 完成；切换前将活动视图同步到 `planet_inventories[旧行星]`，切换后载入目标行星托盘。schema v6 只序列化 `planet_inventories`，不重复序列化活动别名。

以下状态保持全局，与 DSPONLINE 一致：

- `construction_inventory`：玩家可随身使用的建筑件和线路件。
- `cursor_payload`：玩家随身持有的单一载荷；切换行星时保持不变。
- 科技、战役、成就、蓝图库、稳定 ID、暂停、速度和总游玩时间。
- `portable_fleet`：随身物流无人机和运输船，独立于任一行星材料托盘。任务 13 直接复用该所有权，不再二次迁移。

`handcraft_queue` 保持单一数组，每个任务增加 `planet_id`。完成产物写回该任务所属行星的材料托盘，切换活动行星不会改变任务归属或进度。

## 星区目录与确定性环境

`data/galaxy.json` 声明恒星系、行星、显示信息、星系坐标、前置科技、前置星系、勘探成本、殖民成本、可采资源、能源倍率和基础资源点。所有引用的物品和科技必须存在于当前 DataManager 目录；未知引用使统一门失败。

`GalaxySystem` 是目录和勘探规则的唯一入口：

- 严格加载并深拷贝 `galaxy.json`，拒绝重复 ID、悬空行星/星系引用、非有限距离和非法成本。
- 使用 `galaxy_seed + resource_site_id + item_id` 计算确定性储量；同一存档重载不得漂移。
- 提供星系距离、搜索文本、系统/行星摘要和探索需求查询。
- `try_explore_system()` 先检查科技、前置星系和活动行星库存，再一次扣除成本并创建后台勘探任务。
- 导航航标在任务开始时可见；`update_exploration()` 按固定模拟秒推进调查进度。完成后确认星系已探索，并把该星系首颗行星加入殖民集合，作为先遣落点。

首版目录只使用当前 39 个物品可解释的资源和成本。尚未进入 CardFactory 目录的 DSPONLINE 资源不会以不可采占位物混入权威状态。

## 行星工厂与资源点

`PlanetSystem` 负责活动行星、殖民、资源绑定、视口和工业摘要：

- `get_planet_buildings()`、`get_planet_connections()` 和 `get_planet_resource_sites()` 返回稳定排序的深拷贝或只读投影。
- `try_set_active_planet()` 仅接受已探索星系中的已殖民行星；失败不改变托盘、相机或选择。
- `get_colonization_requirements()` 返回稳定状态码：`colonized`、`technology`、`prerequisite_system`、`system_locked`、`materials` 或 `ready`。
- `try_colonize_planet()` 先验证目录、科技、星系、材料和所需物流载具，再在副本上扣除成本、初始化目标托盘/视口/指标并加入 `colonized_planet_ids`；任何失败保持整个状态逐字段不变。
- `try_bind_extractor(building_id, resource_site_id)` 只允许同一行星、物品受建筑目录支持、资源点未被不兼容设备占用且储量有效的组合。

资源点不伪装成普通建筑卡片，单独保存在 `resource_sites`：

```gdscript
{
  "id": "home_iron_1",
  "planet_id": "home",
  "item_id": "iron_ore",
  "position": Vector2(-470, -250),
  "remaining": 240000.0,
  "capacity": 240000.0,
  "infinite": false
}
```

采集建筑持久化 `resource_site_id`。`ProductionSystem` 在每次实际采集前验证绑定，并以实际产出量减少有限储量；剩余不足时只产出可用量，归零后状态稳定为 `resource_depleted`。水等目录明确标记为无限的资源不减少储量。

新放置采集器选择当前位置一定半径内、与当前输出物品兼容且可用的最近资源点；无合法资源点时放置命令原子失败。schema v5 迁移的母星采集器按输出物品和稳定距离顺序绑定到母星资源点，无法绑定的旧建筑保留但停止采集，并由诊断报告明确原因。

## 模拟隔离

所有已殖民行星继续参与固定 tick，不因 UI 切换冻结：

- `PowerSystem` 按 `planet_id` 分组计算发电、需求、燃料和供电倍率，禁止一颗行星的发电为另一颗行星供电。
- `ProductionSystem` 遍历全局建筑，但只使用建筑所属行星的环境、资源点和缓冲区。
- `BeltSystem` 只处理端点与线路 `planet_id` 一致的线路；创建和加载边界都拒绝跨行星线路。
- `HandcraftSystem` 按任务 `planet_id` 将结果写回正确托盘。
- `StatisticsSystem` 继续保留全局汇总，同时按 `planet_id` 维护运行时工业摘要；这些采样历史仍不进入存档。
- `GalaxySystem.update_exploration()` 作为固定 tick 阶段推进后台勘探，不读取墙钟。

科技研究、战役进度和全局时间只推进一次，不能因为行星数量增加而倍增。

## 活动画布投影

渲染、输入和工作区只允许操作 `active_planet_id`：

- `CardRenderer`、`ConnectionRenderer` 和 `MiniMap` 过滤其他行星实体。
- `InputHandler` 的命中、框选、拖动、删除、连接和蓝图命令都验证实体属于活动行星。
- `FactoryWorkspaceUI` 的库存、建筑计数、检查器和建造结果读取活动行星投影；施工件仍显示全局库存。
- 诊断定位如果目标位于其他已殖民行星，先请求 Main 切换行星，再恢复该行星相机并选中目标；未殖民目标不得隐式殖民。
- 切换行星会取消放置、连接、拖动和框选，清空会话选择，保留全局 `cursor_payload`，隐藏短时通知之外的冲突工作区，然后刷新正式 UI。

## 星图工作区

`GalaxyMap.gd` 重写为正式 Godot `Control`，挂载在 `FactoryWorkspaceUI`，并加入现有互斥工作区与 UI 命中测试。它只读取权威状态并发出意图：

```gdscript
signal explore_requested(system_id: String)
signal colonize_requested(planet_id: String)
signal travel_requested(planet_id: String)
```

Main 持有 `GalaxySystem` 和 `PlanetSystem`，处理这些意图并发布结果通知。UI 不直接扣资源或修改殖民集合。

工作区提供：

- 按恒星系分组的行星导航与当前行星标记。
- 名称、代码、资源和环境的组合搜索。
- 距离、恒星类型、环境倍率、资源点、殖民成本与稳定失败原因。
- 每颗行星的建筑数、运行/阻塞数、发电、需求和主要库存摘要。
- `开始勘探`、`建立殖民前哨`、`进入行星工厂` 三类真实按钮。
- 关闭并返回工厂后恢复目标行星保存的相机位置和缩放。

布局沿用当前 CardFactory 深色 Godot 工作区的固定边界和互斥机制，信息层级参考 DSPONLINE `StarMapWorkspace`，不复制网页 CSS 或素材。

## 存档迁移与验证

`SaveMigrationRegistry` 新增 v5→v6：

1. 设置固定基线 `galaxy_seed`、活动行星 `home`、已探索 `helios` 和已殖民 `home`。
2. 把旧 `planet_inventory` 迁入 `planet_inventories.home`。
3. 给所有旧建筑和线路补 `planet_id = home`。
4. 给旧手工任务补 `planet_id = home`。
5. 创建每颗目录行星的默认视口、指标和确定性资源点。
6. 为母星旧采集器执行确定性资源绑定。

迁移不改变旧建筑 ID、线路 ID、位置、配方、缓冲区、进度、燃料、研究、库存数值和 `_next_id`。旧 metadata 中的 `active_planet` 只作为 v5 兼容输入；schema v6 的活动行星由权威状态保存，GameManager 不再维护第二份可漂移字段。

`GameStateValidator` 额外拒绝：未知活动行星、未殖民活动行星、未知探索集合成员、行星托盘缺失、实体行星缺失、跨行星线路、非法资源绑定、负数/非有限储量、重复资源点、非法视口、勘探任务引用错误以及殖民集合未满足目录约束。

## 错误和事务约定

所有玩家命令返回：

```gdscript
{"ok": bool, "reason": String, "message": String, "details": Dictionary}
```

稳定原因至少包括 `unknown_planet`、`system_locked`、`technology_locked`、`not_colonized`、`already_colonized`、`missing_materials`、`missing_vehicle`、`invalid_resource_site`、`resource_mismatch`、`resource_depleted` 和 `cross_planet_connection`。失败命令不得消耗稳定 ID、资源、载具、相机状态或选择状态。

## 测试策略

新增 `TestGalaxyLogistics.gd/.tscn`，唯一成功标记为 `GALAXY LOGISTICS TESTS PASSED`，加入统一 runner 成为第 10 个权威场景。按 TDD 依次覆盖：

1. 两颗行星使用相同业务 ID 前缀时，完整 ID、建筑、线路、库存、视口和选择互不混合。
2. 跨行星线路在命令和存档验证边界均被拒绝。
3. 一颗行星的发电不能供给另一颗行星；切换后两颗已殖民行星仍按固定 tick 继续生产。
4. 相同星区种子生成相同有限储量，不同合法种子至少改变一个允许波动的储量。
5. 采集器只能绑定合法资源点，实际产量严格减少储量，耗尽后不产生负数或额外产物。
6. 勘探科技、前置和材料门；固定时间推进；完成后先遣行星状态。
7. 殖民对科技、材料和载具完整预检，失败逐字段不变，成功只扣一次。
8. 正式星图的搜索、摘要、按钮、工作区互斥、UI 命中和返回恢复相机。
9. v5 单工厂迁移到 home 后摘要等价，schema v6 保存加载保持所有行星状态和稳定 ID。
10. 现有 9 个场景、Main 120 帧和 `git diff --check` 全部通过。

## 完成标准

- 单一权威状态能同时保存并模拟至少两颗殖民行星，活动画布只展示一颗。
- 行星电力、库存、线路、资源和相机不存在串线。
- 勘探、殖民和切换只能经过可测试的领域命令，UI 不直接写状态。
- 旧单行星存档无损迁入母星。
- 星图是正式主场景的一部分，并与科技、战役、蓝图和分析工作区互斥。
- 第 10 个门禁场景及全部既有门禁通过。
