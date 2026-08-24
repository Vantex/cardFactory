# CardFactory Phase 2 DSPONLINE 风格工作区实现计划

> **历史归档（2026-08-23 工作区交付）：** 本计划记录当时已结束的交付批次，复选框不代表当前路线；请以[项目状态](../../../PROJECT_STATUS.md)和[当前路线](../../../current/SINGLE_PLAYER_ROADMAP.md)为准。

> **面向 AI 代理的工作者：** 必需子技能：使用 superpowers:subagent-driven-development（推荐）或 superpowers:executing-plans 逐任务实现此计划。步骤使用复选框（`- [ ]`）语法来跟踪进度。

**目标：** 在 Godot 主场景中交付一个 DSPONLINE 风格的可玩工厂工作区，使玩家可从空白画布完成建造、选择、移动、配方配置、连接和删除，并看到真实模拟反馈。

**架构：** `FactoryWorkspaceUI` 负责固定界面与命令展示，`InputHandler` 独占世界画布输入，两个 Node2D renderer 只读绘制，所有原子验证与资源扣减收口到 `GameState`。现有 DataManager/SimulationEngine 保持冻结，通过 GameManager/EventBus 与新工作区桥接。

**技术栈：** Godot 4.7、GDScript、Node2D/Camera2D、CanvasLayer/Control、项目自带无窗口测试场景和 PowerShell 测试门。

---

## 文件结构

- 创建 `scripts/test/TestFactoryWorkspace.gd`：第二阶段领域命令与主场景结构回归。
- 创建 `scenes/test/TestFactoryWorkspace.tscn`：无窗口测试入口。
- 创建 `scenes/ui/FactoryWorkspaceUI.gd`：顶部状态栏、左资源栏、右检查器、底部建造坞和通知。
- 修改 `scripts/game/GameState.gd`：建造点、放置/连接命令、配方兼容辅助方法。
- 修改 `autoload/EventBus.gd`：工作区选择、放置、反馈和状态变更信号。
- 修改 `scripts/input/InputHandler.gd`：相机坐标、状态机、命中测试和端口连接。
- 修改 `scripts/rendering/CardRenderer.gd`：点阵、卡片、端口、状态和进度视觉。
- 修改 `scripts/rendering/ConnectionRenderer.gd`：曲线连接、方向箭头、活动物流粒子和草稿线。
- 修改 `scenes/main/Main.gd`、`scenes/main/Main.tscn`：组合新工作区并移除自动测试生产线。
- 修改 `project.godot`：设置桌面验证视口和输入映射。
- 修改 `tools/run_tests.ps1`：把第二阶段测试纳入唯一测试门。
- 修改 `README.md`、`docs/PROJECT_STATUS.md`：记录真实可玩范围和操作说明。

### 任务 1：原子工厂命令

**文件：**
- 创建：`scripts/test/TestFactoryWorkspace.gd`
- 创建：`scenes/test/TestFactoryWorkspace.tscn`
- 修改：`scripts/game/GameState.gd`

- [x] **步骤 1：编写失败的领域测试**

测试必须构造独立 `GameState` 并断言：初始建造点为 12；矿机成功放置扣 1；未知建筑、余额不足和重叠放置不修改状态；矿机→熔炉连接会自动选择 `iron_ingot_recipe`；自身、重复和不兼容连接被拒绝；删除建筑级联删除连接。

```gdscript
var state := GameState.new()
var miner := state.try_place_building("miner", Vector2(100, 100))
_expect(miner.ok and state.construction_points == 11, "miner placement is atomic")
var smelter := state.try_place_building("smelter", Vector2(420, 100))
var connected := state.try_add_connection(miner.id, smelter.id)
_expect(connected.ok, "compatible buildings connect")
_expect(state.get_building(smelter.id).recipe_id == "iron_ingot_recipe", "connection auto-selects recipe")
_expect(not state.try_add_connection(miner.id, smelter.id).ok, "duplicate connection is rejected")
```

- [x] **步骤 2：运行测试验证失败**

运行：`& 'C:\Program Files\Godot\Godot.exe' --headless --path . --quit-after 600 res://scenes/test/TestFactoryWorkspace.tscn`

预期：FAIL，报告 `try_place_building` 或 `construction_points` 不存在。

- [x] **步骤 3：实现最小命令边界**

在 `GameState.gd` 增加常量成本和下列稳定签名：

```gdscript
var construction_points: int = 12

func try_place_building(building_type: String, position: Vector2) -> Dictionary
func try_add_connection(source_id: String, target_id: String) -> Dictionary
func get_compatible_recipes(building_type: String, input_item_id: String = "") -> Array
func get_building_output_item(building_id: String) -> String
func get_building_display_name(building_id: String) -> String
```

放置成功才扣成本并调用现有 `add_building`；连接先完整验证，再在需要时设置配方并调用 `add_connection`。所有分支返回 `{ok, message}`，成功结果另含 `id`。

- [x] **步骤 4：运行领域测试和基线门**

运行：

```powershell
& 'C:\Program Files\Godot\Godot.exe' --headless --path . --quit-after 600 res://scenes/test/TestFactoryWorkspace.tscn
powershell -ExecutionPolicy Bypass -File tools/run_tests.ps1
```

预期：两个命令退出码均为 0，第二阶段测试打印 `FACTORY WORKSPACE TESTS PASSED`。

- [x] **步骤 5：提交**

```powershell
git add scripts/game/GameState.gd scripts/test/TestFactoryWorkspace.gd scenes/test/TestFactoryWorkspace.tscn
git commit -m "feat: add atomic factory workspace commands"
```

### 任务 2：DSPONLINE 风格固定工作区 UI

**文件：**
- 创建：`scenes/ui/FactoryWorkspaceUI.gd`
- 修改：`autoload/EventBus.gd`
- 修改：`scripts/test/TestFactoryWorkspace.gd`

- [x] **步骤 1：扩展失败的 UI 契约测试**

实例化 `FactoryWorkspaceUI`，加入场景树一帧后断言存在以下命名节点，并验证建造按钮发出 `placement_requested("miner")`：

```gdscript
for path in ["TopBar", "ResourceRail", "InspectorPanel", "ConstructionDock", "Toast"]:
    _expect(workspace.get_node_or_null(path) != null, "workspace exposes %s" % path)
workspace.call("_on_building_pressed", "miner")
_expect(workspace.get_selected_building_type() == "miner", "dock enters placement mode")
```

- [x] **步骤 2：运行测试验证失败**

运行第二阶段测试场景，预期因 `FactoryWorkspaceUI.gd` 或节点不存在而失败。

- [x] **步骤 3：实现主题和五个固定区域**

`FactoryWorkspaceUI.gd` 继承 `CanvasLayer`，程序化创建命名 Control。使用常量：顶部 52、左栏 216、右栏 286、底栏 92；面板颜色 `#101715/#151e1b`，青色 `#62b5ae`，绿色 `#70bb85`，黄色 `#e1b452`，错误 `#df7666`。公开稳定方法：

```gdscript
func set_selected_building(building_id: String) -> void
func get_selected_building_type() -> String
func show_notice(message: String, tone: String = "info") -> void
func is_pointer_over_ui(screen_position: Vector2) -> bool
func refresh_now() -> void
```

建造坞仅显示 miner、smelter、assembling_machine_mk1、power_generator；检查器配方列表来自 `DataManager.get_recipes_for_building`；所有修改通过 GameState 方法完成。

- [x] **步骤 4：运行测试并提交**

运行第二阶段测试与基线门，均通过后提交：

```powershell
git add autoload/EventBus.gd scenes/ui/FactoryWorkspaceUI.gd scripts/test/TestFactoryWorkspace.gd
git commit -m "feat: build DSPONLINE inspired workspace chrome"
```

### 任务 3：世界画布输入与相机

**文件：**
- 修改：`scripts/input/InputHandler.gd`
- 修改：`scenes/main/Main.tscn`
- 修改：`project.godot`
- 修改：`scripts/test/TestFactoryWorkspace.gd`

- [x] **步骤 1：编写失败的输入状态测试**

测试公开状态转换，不合成脆弱鼠标事件：进入放置、取消、开始连接、完成合法连接、Camera2D 存在且缩放范围为 0.45..1.8。

```gdscript
input_handler.start_placing_card("miner")
_expect(input_handler.get_mode_name() == "placing", "placement mode starts")
input_handler.cancel_operation()
_expect(input_handler.get_mode_name() == "idle", "escape contract cancels")
```

- [x] **步骤 2：运行测试确认公开契约尚不存在**

运行第二阶段测试，预期 `get_mode_name`、`cancel_operation` 或 Camera2D 断言失败。

- [x] **步骤 3：实现单一输入状态机**

状态固定为 `IDLE/PLACING/DRAGGING/CONNECTING/PANNING`。只在中央画布矩形内响应世界输入；屏幕坐标通过 Camera2D 转成世界坐标。输出端口矩形为卡片右侧 18×36，输入端口为左侧 18×36；节点主体拖动阈值 5 px。右键/中键平移，滚轮以指针为中心缩放，Escape 清理所有草稿。

- [x] **步骤 4：设置视口和快捷键**

`project.godot` 设置 1152×648 viewport/window override；添加 Space、1/2/3 行为。Q/W/E/R 沿用代码快捷键并与建造坞顺序一致。

- [x] **步骤 5：运行测试并提交**

```powershell
& 'C:\Program Files\Godot\Godot.exe' --headless --path . --quit-after 600 res://scenes/test/TestFactoryWorkspace.tscn
git add scripts/input/InputHandler.gd scenes/main/Main.tscn project.godot scripts/test/TestFactoryWorkspace.gd
git commit -m "feat: add pannable factory canvas interactions"
```

### 任务 4：节点与物流视觉

**文件：**
- 修改：`scripts/rendering/CardRenderer.gd`
- 修改：`scripts/rendering/ConnectionRenderer.gd`
- 修改：`scripts/test/TestFactoryWorkspace.gd`

- [x] **步骤 1：添加渲染契约测试**

断言两个 renderer 公开统一几何常量和状态注入：

```gdscript
_expect(CardRenderer.CARD_SIZE == Vector2(232, 144), "card geometry is stable")
_expect(CardRenderer.get_input_port_rect(Vector2.ZERO).has_point(Vector2(0, 72)), "input port hit area matches drawing")
_expect(CardRenderer.get_output_port_rect(Vector2.ZERO).has_point(Vector2(232, 72)), "output port hit area matches drawing")
```

- [x] **步骤 2：运行测试验证旧 200×150 几何失败**

运行第二阶段测试，预期几何常量或静态方法缺失。

- [x] **步骤 3：实现节点和连接绘制**

CardRenderer 先绘制 20 世界单位点阵，再绘制 232×144 卡片：标题、symbol/name、状态点、进度条、输入/输出摘要、功耗/速度页脚、端口与选择轮廓。ConnectionRenderer 使用 `draw_polyline` 近似二次 Bézier，绘制箭头、物品标签和按时间移动的 3 个粒子；连接草稿从 InputHandler 读取。

- [x] **步骤 4：运行测试并提交**

```powershell
& 'C:\Program Files\Godot\Godot.exe' --headless --path . --quit-after 600 res://scenes/test/TestFactoryWorkspace.tscn
git add scripts/rendering/CardRenderer.gd scripts/rendering/ConnectionRenderer.gd scripts/test/TestFactoryWorkspace.gd
git commit -m "feat: render factory cards and flowing belts"
```

### 任务 5：主场景集成和真实生产闭环

**文件：**
- 修改：`scenes/main/Main.gd`
- 修改：`scenes/main/Main.tscn`
- 修改：`scripts/test/TestFactoryWorkspace.gd`
- 修改：`tools/run_tests.ps1`

- [x] **步骤 1：添加主场景结构和闭环测试**

加载 `Main.tscn` 并断言存在 `WorldCamera`、`CardRenderer`、`ConnectionRenderer`、`InputHandler`、`FactoryWorkspaceUI`，不存在旧 `HUD`/`BuildingPanel`。另构造矿机→熔炉，运行 SimulationEngine 足够时间，断言铁矿进入熔炉并产生铁锭。

- [x] **步骤 2：运行测试验证旧主场景失败**

预期旧 HUD/BuildingPanel 或缺少 Camera2D/FactoryWorkspaceUI 断言失败。

- [x] **步骤 3：完成场景接线**

Main 不再调用 `_place_initial_buildings`。把 UI、InputHandler 和 renderer 相互注入；连接 card_selected/card_removed/placement_requested/notice_requested；删除后清理选择；暂停和速度按钮写入 GameState 公共字段。

- [x] **步骤 4：把第二阶段场景加入正式测试门**

`tools/run_tests.ps1` 依次运行 TestBaseline 和 TestFactoryWorkspace，分别要求唯一完整成功标记；任一 Godot 非零、SCRIPT ERROR、Parse Error 或失败标记均让脚本退出 1。

- [x] **步骤 5：运行完整验证并提交**

```powershell
powershell -ExecutionPolicy Bypass -File tools/run_tests.ps1
& 'C:\Program Files\Godot\Godot.exe' --headless --path . --quit-after 120 res://scenes/main/Main.tscn
git add scenes/main/Main.gd scenes/main/Main.tscn scripts/test/TestFactoryWorkspace.gd tools/run_tests.ps1
git commit -m "feat: integrate playable factory workspace"
```

预期：测试门退出 0，主场景 120 帧退出 0，无 `SCRIPT ERROR` 或 `Parse Error`。

### 任务 6：文档、审查与交付验证

**文件：**
- 修改：`README.md`
- 修改：`docs/PROJECT_STATUS.md`
- 修改：本计划复选框

- [x] **步骤 1：更新真实操作和范围**

README 写明：Q/W/E/R、左键放置/选择/拖动/端口连接、右键/中键平移、滚轮缩放、Escape、Delete、Space、1/2/3。PROJECT_STATUS 将 Phase 2 标为“已完成”仅在所有门通过后，并列出延后的多选、蓝图、缩略图和高级面板。

- [x] **步骤 2：执行完整证据检查**

```powershell
git diff --check
powershell -ExecutionPolicy Bypass -File tools/run_tests.ps1
& 'C:\Program Files\Godot\Godot.exe' --headless --path . --quit-after 120 res://scenes/main/Main.tscn
git status --short --branch
```

- [x] **步骤 3：按 requesting-code-review 技能审查**

审查重点：失败原子性、UI 输入穿透、相机坐标、端口几何一致、配方兼容、旧测试门无假绿。修复所有高置信度问题后重跑步骤 2。

- [x] **步骤 4：提交文档与审查修复**

```powershell
git add README.md docs/PROJECT_STATUS.md docs/superpowers/plans/2026-08-23-cardfactory-phase2-dsponline-ui.md
git commit -m "docs: complete phase 2 factory workspace"
```
