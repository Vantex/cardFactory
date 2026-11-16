# 统计、诊断与生产资料库实现计划

> **面向 AI 代理的工作者：** 必需子技能：使用 superpowers:subagent-driven-development（推荐）或 superpowers:executing-plans 逐任务实现此计划。步骤使用复选框（`- [ ]`）语法来跟踪进度。

**目标：** 在固定模拟时钟上提供可信的生产统计、停工诊断、配方资料库和世界定位闭环。

**架构：** `SimulationEngine` 持有唯一运行时 `StatisticsSystem`，生产与线路系统只上报真实数量，统计阶段按 1 秒封装至最多 600 个样本。`ProductionDiagnostics` 和 `RecipeGraph` 是无副作用查询服务，`CodexWorkspace` 只读取服务并通过 Main 复用现有定位路径。

**技术栈：** Godot 4.7.2、GDScript、JSON 数据目录、项目自带场景测试 runner。

---

## 文件结构

- 重写 `scripts/game/StatisticsSystem.gd`：事件账本、有界时间桶与窗口查询。
- 修改 `scripts/game/ProductionSystem.gd`：记录真实配方生产/消耗和采矿增量。
- 修改 `scripts/game/BeltSystem.gd`：记录真实线路转运量。
- 修改 `scripts/game/SimulationEngine.gd`：创建并注入唯一统计服务。
- 创建 `scripts/game/ProductionDiagnostics.gd`：稳定停工原因与定位元数据。
- 创建 `scripts/game/RecipeGraph.gd`：目录正反向索引、链、循环、缺口与理论速率。
- 修改 `autoload/DataManager.gd`：提供物品、配方和建筑目录的深拷贝读取接口。
- 重写 `scenes/ui/StatisticsPanel.gd`：只读权威统计实例的可筛选窗口视图。
- 创建 `scenes/ui/CodexWorkspace.gd`：诊断与生产资料库正式工作区。
- 修改 `scenes/ui/FactoryWorkspaceUI.gd`：挂载“分析”入口并纳入互斥工作区。
- 修改 `scenes/main/Main.gd`：连接资料库定位意图到现有世界定位逻辑。
- 创建 `scripts/test/TestStatisticsCodex.gd` 和 `scenes/test/TestStatisticsCodex.tscn`：任务 11 权威行为测试。
- 修改 `tools/run_tests.ps1`：把第九个场景纳入统一门禁。
- 修改 `README.md`、`docs/PROJECT_STATUS.md`、`docs/current/SINGLE_PLAYER_ROADMAP.md`：同步交付状态与验收记录。

### 任务 1：固定时间生产统计

**文件：**
- 重写：`scripts/game/StatisticsSystem.gd`
- 修改：`scripts/game/ProductionSystem.gd`
- 修改：`scripts/game/BeltSystem.gd`
- 修改：`scripts/game/SimulationEngine.gd`
- 创建：`scripts/test/TestStatisticsCodex.gd`
- 创建：`scenes/test/TestStatisticsCodex.tscn`

- [ ] **步骤 1：创建统计测试场景与失败测试**

在真实 `SimulationEngine` 上构造一台有供电熔炉，运行固定模拟时间并断言：

```gdscript
var engine := SimulationEngine.new(state)
_run_seconds(engine, 2.0)
var rates := engine.statistics_system.get_item_rates("iron_ingot", 60)
_expect(rates["produced_per_minute"] > 0.0, "completed recipes contribute real production")
_expect(rates["consumed_per_minute"] > 0.0, "completed recipes contribute real consumption")
_expect(is_equal_approx(rates["net_per_minute"], rates["produced_per_minute"] - rates["consumed_per_minute"]), "net rate is production minus consumption")
```

另以 60 次 `1/60` 与 10 次 `0.1` 驱动相同状态，断言统计摘要相同；直接序列化 `GameState`，断言没有统计历史字段。

- [ ] **步骤 2：运行测试验证红灯**

运行：

```powershell
& 'C:\Program Files\Godot\Godot.exe' --headless --path . --quit-after 600 res://scenes/test/TestStatisticsCodex.tscn
```

预期：场景可解析，但因 `get_item_rates()` 不存在或真实速率为零而输出 `STATISTICS CODEX TESTS FAILED`。

- [ ] **步骤 3：实现最小事件账本与注入**

实现接口：

```gdscript
const SAMPLE_INTERVAL := 1.0
const MAX_SAMPLES := 600
const SUPPORTED_WINDOWS := [60, 300, 600]

func record_produced(item_id: String, amount: float, building_id: String = "") -> void
func record_consumed(item_id: String, amount: float, building_id: String = "") -> void
func record_transferred(item_id: String, amount: float, connection_id: String = "") -> void
func update(delta: float) -> void
func get_item_rates(item_id: String, window_seconds: int = 60) -> Dictionary
func get_statistics_summary(window_seconds: int = 60) -> Dictionary
```

生产配方每完成一次，按目录精确记录 inputs/outputs；采矿只记录实际写入缓冲区的增量；线路只记录真实 transfer amount。`SimulationEngine` 创建统计服务后注入两个系统。

- [ ] **步骤 4：运行聚焦测试验证绿灯**

运行同一场景，预期退出码 0 且恰好一行 `STATISTICS CODEX TESTS PASSED`，无 `SCRIPT ERROR`、`Parse Error` 或资源泄漏。

- [ ] **步骤 5：增加窗口与上限红灯测试并实现**

用合成记录逐秒封桶 601 次，断言：

```gdscript
_expect(stats.get_history_size() == 600, "statistics history is bounded")
_expect(stats.get_item_rates("iron_ingot", 60)["produced_per_minute"] > stats.get_item_rates("iron_ingot", 600)["produced_per_minute"], "windows read only their covered samples")
_expect(stats.get_item_rates("unknown", 60)["produced_per_minute"] == 0.0, "empty items return zero rates")
```

先运行确认窗口或上限结果错误，再实现窗口裁剪、实际覆盖时长除法和深拷贝返回，最后重跑至绿灯。

- [ ] **步骤 6：运行既有模拟核心回归并提交**

运行 `TestSimulationCore.tscn`，预期 `SIMULATION CORE TESTS PASSED`。提交：

```powershell
git add scripts/game/StatisticsSystem.gd scripts/game/ProductionSystem.gd scripts/game/BeltSystem.gd scripts/game/SimulationEngine.gd scripts/test/TestStatisticsCodex.gd scenes/test/TestStatisticsCodex.tscn
git commit -m "feat: add fixed time production statistics"
```

### 任务 2：生产诊断与配方图

**文件：**
- 创建：`scripts/game/ProductionDiagnostics.gd`
- 创建：`scripts/game/RecipeGraph.gd`
- 修改：`autoload/DataManager.gd`
- 修改：`scripts/test/TestStatisticsCodex.gd`

- [ ] **步骤 1：编写六类诊断失败测试**

用真实目录和 `GameState` 分别构造无配方、零供电、缺输入、输出满、目标缓冲区满和关闭线路，断言稳定原因码：

```gdscript
var diagnostics := ProductionDiagnostics.new(state)
var codes := diagnostics.get_all_diagnostics().map(func(entry): return entry["code"])
_expect(codes.has("no_recipe"), "configurable machines diagnose missing recipes")
_expect(codes.has("no_power"), "powered machines diagnose a zero power ratio")
_expect(codes.has("missing_input"), "recipes diagnose their first missing input")
_expect(codes.has("output_full"), "recipes diagnose full output buffers")
_expect(codes.has("belt_blocked"), "belts diagnose a full target buffer")
_expect(codes.has("belt_disabled"), "disabled belts remain distinguishable from congestion")
```

运行聚焦场景，确认因类或原因码不存在而正确失败。

- [ ] **步骤 2：实现无副作用诊断服务**

按 `no_recipe → no_power → missing_input → output_full` 的优先级为每台建筑返回首要原因；线路诊断独立追加。结果按 `entity_id` 排序，携带 `building_id`、`planet_id: "home"` 与真实 `position`。比较调用前后的 `GameStateCodec.state_digest_payload(state)`，确认查询不修改状态。

- [ ] **步骤 3：编写配方图失败测试**

```gdscript
var graph := RecipeGraph.new(DataManager.get_all_items(), DataManager.get_all_recipes(), DataManager.get_all_buildings())
_expect(graph.get_producers("iron_ingot").has("iron_ingot_recipe"), "items reverse-map to producer recipes")
_expect(graph.get_recipe_buildings("iron_ingot_recipe").has("smelter"), "recipes map to supported buildings")
_expect(graph.build_upstream_chain("matrix_science_1", 2)["max_depth"] == 2, "two-layer chains stop at the requested depth")
_expect(graph.build_upstream_chain("matrix_science_1", -1)["nodes"].size() >= graph.build_upstream_chain("matrix_science_1", 2)["nodes"].size(), "full chains include the two-layer view")
```

使用内存循环目录断言 `cycles` 非空且函数返回；使用无生产者输入断言 `gaps` 含该物品；断言铁锭配方理论每分钟产量等于 `output_amount / duration * 60`。

- [ ] **步骤 4：实现目录深拷贝接口与 RecipeGraph**

给 `DataManager` 增加 `get_all_items()`、`get_all_recipes()`、`get_all_buildings()`，均返回 `duplicate(true)`。`RecipeGraph` 在构造时建稳定排序索引，DFS 使用当前路径检测循环，达到深度后停止扩展；结果包含 `nodes`、`edges`、`cycles`、`gaps`、`rates_per_minute` 和 `max_depth`。重跑聚焦测试至绿灯。

- [ ] **步骤 5：提交查询服务**

```powershell
git add autoload/DataManager.gd scripts/game/ProductionDiagnostics.gd scripts/game/RecipeGraph.gd scripts/test/TestStatisticsCodex.gd
git commit -m "feat: add production diagnostics and recipe graph"
```

### 任务 3：正式分析工作区与生产定位

**文件：**
- 重写：`scenes/ui/StatisticsPanel.gd`
- 创建：`scenes/ui/CodexWorkspace.gd`
- 修改：`scenes/ui/FactoryWorkspaceUI.gd`
- 修改：`scenes/main/Main.gd`
- 修改：`scripts/test/TestStatisticsCodex.gd`

- [ ] **步骤 1：编写正式 UI 失败测试**

实例化 `Main.tscn`，断言存在分析入口、三个真实视图、搜索/窗口控件、滚动容器和互斥行为：

```gdscript
var workspace := main.get_node_or_null("FactoryWorkspaceUI/CodexWorkspace") as Control
_expect(workspace != null and not workspace.visible, "formal codex workspace mounts collapsed")
_expect(workspace.get_node_or_null("Layout/Tabs/Statistics") is Button, "codex exposes a statistics tab")
_expect(workspace.get_node_or_null("Layout/Tabs/Diagnostics") is Button, "codex exposes a diagnostics tab")
_expect(workspace.get_node_or_null("Layout/Tabs/Codex") is Button, "codex exposes a recipe codex tab")
_expect(workspace.get_node_or_null("Layout/Content/StatisticsPanel/Window") is OptionButton, "statistics exposes real time windows")
```

点击分析、科技、战役和蓝图入口，断言任一时刻最多一个工作区可见。运行聚焦场景，确认节点缺失导致正确红灯。

- [ ] **步骤 2：重写 StatisticsPanel**

面板不创建服务、不调用 `update()`。刷新时从 `GameManager.get_simulation_engine().statistics_system` 读取；搜索与 60/300/600 秒 `OptionButton` 组合筛选；结果按物品显示名排序，显示生产、消耗、净值和吞吐量。只在可见且收到模拟、状态或控件变化时刷新。

- [ ] **步骤 3：实现 CodexWorkspace 与互斥入口**

工作区程序化创建统计、诊断、资料库三个页签。诊断行使用真实 `ProductionDiagnostics`；资料库行使用真实 `RecipeGraph`，提供两层/完整链切换。所有长列表置于 `ScrollContainer`。`FactoryWorkspaceUI.show_exclusive_workspace()` 的候选集合加入 `CodexWorkspace`，顶栏新增“分析”按钮。

- [ ] **步骤 4：编写定位红灯并实现 Main 路由**

构造一个缺料建筑，点击诊断行“定位”，断言真实 InputHandler 唯一选择该建筑、相机移动到真实坐标，并且建筑的配方、缓冲区、进度和线路配置均未改变。测试必须先因未连接意图而失败。随后连接 `CodexWorkspace.locate_requested` 到 `Main._on_locate_requested`，复用现有定位路径，再重跑至绿灯。

- [ ] **步骤 5：验证真实滚动和状态替换**

改变统计或资料库 `ScrollContainer.scroll_vertical`，关闭再打开后断言实际值保留；调用 `GameManager.replace_game_state()` 后断言 UI 读取新模拟器且旧统计历史不再显示。

- [ ] **步骤 6：提交正式 UI**

```powershell
git add scenes/ui/StatisticsPanel.gd scenes/ui/CodexWorkspace.gd scenes/ui/FactoryWorkspaceUI.gd scenes/main/Main.gd scripts/test/TestStatisticsCodex.gd
git commit -m "feat: add statistics diagnostics codex workspace"
```

### 任务 4：门禁、文档与交付

**文件：**
- 修改：`tools/run_tests.ps1`
- 修改：`README.md`
- 修改：`docs/PROJECT_STATUS.md`
- 修改：`docs/current/SINGLE_PLAYER_ROADMAP.md`
- 修改：`scripts/test/TestStatisticsCodex.gd`

- [ ] **步骤 1：把第九个场景加入 runner**

新增用例：

```powershell
@{
    Name = "Statistics codex"
    ScenePath = Join-Path $repoRoot "scenes\test\TestStatisticsCodex.tscn"
    ResourcePath = "res://scenes/test/TestStatisticsCodex.tscn"
    SuccessMarker = "STATISTICS CODEX TESTS PASSED"
    FailureMarker = "STATISTICS CODEX TESTS FAILED"
}
```

先让场景保留红灯，运行 runner 确认退出码非零；恢复绿灯实现后确认 runner 能识别唯一完整成功行。

- [ ] **步骤 2：同步玩家与维护文档**

README 说明分析入口、窗口、诊断、资料库与定位；项目状态把 Stage 3 任务 11 标为完成；路线图勾选五个步骤并记录固定采样、有界历史、稳定诊断、图查询和正式 UI 的验收事实。明确统计缓存不存档、当前仅单行星、在线范围仍排除。

- [ ] **步骤 3：运行完整门禁**

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\tools\run_tests.ps1
```

预期九个成功标记各出现且只出现一次，退出码 0，无脚本、解析或生命周期泄漏错误。

- [ ] **步骤 4：运行主场景与静态检查**

```powershell
& 'C:\Program Files\Godot\Godot.exe' --headless --path . --quit-after 120 res://scenes/main/Main.tscn
git diff --check
git status --short --branch
```

预期主场景退出码 0，加载 39 个物品、30 个建筑、22 个配方与科技目录；diff check 无输出；任务工作树仅含计划内变更。

- [ ] **步骤 5：提交交付记录并进行代码审查**

```powershell
git add tools/run_tests.ps1 README.md docs/PROJECT_STATUS.md docs/current/SINGLE_PLAYER_ROADMAP.md scripts/test/TestStatisticsCodex.gd
git commit -m "docs: complete statistics diagnostics task"
```

审查重点：统计是否真实且与帧率无关、查询是否无副作用、UI 是否使用唯一服务、定位是否只改变相机/选择、历史是否有界且不进存档、九场景 runner 是否严格门禁。

- [ ] **步骤 6：合并与清理**

审查和最终验证通过后，从 `main` 执行 `git merge --ff-only stage3/statistics-diagnostics-codex`；在合并树上重跑完整门禁和 Main 120 帧，再删除任务工作树与分支。保留 `main` 上用户原有的未提交 `project.godot` 修改，不推送远端。
