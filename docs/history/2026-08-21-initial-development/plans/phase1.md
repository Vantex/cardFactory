# CardFactory 第一阶段实现计划

> **历史归档（2026-08-21 初始开发）：** 本计划保留当时设想，未勾选项不是当前待办；请以[项目状态](../../../PROJECT_STATUS.md)和[当前路线](../../../current/SINGLE_PLAYER_ROADMAP.md)为准。

> **面向 AI 代理的工作者：** 必需子技能：使用 superpowers:subagent-driven-development（推荐）或 superpowers:executing-plans 逐任务实现此计划。步骤使用复选框（- [ ]）语法来跟踪进度。

**目标：** 实现最小可行产品（MVP），验证核心玩法：放置卡牌、建立连接、铁矿→铁锭生产流程

**架构：** Canvas 2D渲染 + 数据驱动配置 + 简化的模拟引擎（参照DSPONLINE结构）

**技术栈：** Godot 4.7.2, GDScript, JSON

---

## 文件结构

`
card-factory/
├── project.godot                          # 项目配置（已有）
├── autoload/
│   ├── EventBus.gd                       # 事件总线（信号中心）
│   ├── GameManager.gd                    # 游戏状态管理
│   └── DataManager.gd                    # 数据加载器
├── scenes/
│   ├── main/
│   │   ├── Main.tscn                    # 主场景
│   │   └── Main.gd                      # 主场景脚本
│   └── canvas/
│       ├── GameCanvas.tscn              # 游戏画布场景
│       └── GameCanvas.gd                # 画布逻辑
├── scripts/
│   ├── game/
│   │   ├── GameState.gd                 # 游戏状态
│   │   ├── SimulationEngine.gd          # 模拟引擎
│   │   ├── ProductionSystem.gd          # 生产系统
│   │   └── LogisticsSystem.gd           # 物流系统
│   ├── rendering/
│   │   ├── CardRenderer.gd              # 卡牌渲染器
│   │   └── ConnectionRenderer.gd        # 连线渲染器
│   ├── input/
│   │   └── InputHandler.gd              # 输入处理
│   └── data/
│       ├── CardDefinition.gd            # 卡牌定义
│       └── RecipeDefinition.gd          # 配方定义
├── data/
│   └── base_metals.json                 # 基础金属生产线配置
└── tests/
    └── unit/
        ├── test_data_manager.gd         # DataManager测试
        ├── test_game_state.gd           # GameState测试
        └── test_simulation.gd           # 模拟引擎测试
`

---

## 任务分解

### 任务 1：项目基础架构

**目标：** 建立Godot项目基础结构，配置自动加载

**文件：**
- 修改：project.godot
- 创建：utoload/EventBus.gd
- 创建：utoload/GameManager.gd
- 创建：utoload/DataManager.gd

- [ ] **步骤 1：配置自动加载**

编辑 project.godot，添加自动加载配置：

`ini
[autoload]
EventBus="*res://autoload/EventBus.gd"
GameManager="*res://autoload/GameManager.gd"
DataManager="*res://autoload/DataManager.gd"
`

- [ ] **步骤 2：创建EventBus**

`gdscript
# autoload/EventBus.gd
extends Node

# 卡牌相关信号
signal card_placed(card_id: String, position: Vector2)
signal card_removed(card_id: String)
signal card_selected(card_id: String)

# 连接相关信号
signal connection_created(connection_id: String, source_id: String, target_id: String)
signal connection_removed(connection_id: String)

# 模拟相关信号
signal simulation_updated()
signal production_completed(card_id: String, item_id: String, amount: int)
`

- [ ] **步骤 3：创建GameManager**

`gdscript
# autoload/GameManager.gd
extends Node

var game_state: GameState
var simulation_engine: SimulationEngine

func _ready():
    game_state = GameState.new()
    simulation_engine = SimulationEngine.new(game_state)

func get_game_state() -> GameState:
    return game_state

func get_simulation_engine() -> SimulationEngine:
    return simulation_engine
`

- [ ] **步骤 4：创建DataManager**

`gdscript
# autoload/DataManager.gd
extends Node

var all_items: Dictionary = {}
var all_buildings: Dictionary = {}
var all_recipes: Dictionary = {}

func _ready():
    _load_all_data()

func _load_all_data():
    _load_data_file("res://data/base_metals.json")

func _load_data_file(path: String):
    var file = FileAccess.open(path, FileAccess.READ)
    if file:
        var json = JSON.new()
        json.parse(file.get_as_text())
        var data = json.data
        
        for item_id in data.get("items", {}):
            all_items[item_id] = data.items[item_id]
        
        for building_id in data.get("buildings", {}):
            all_buildings[building_id] = data.buildings[building_id]
        
        for recipe_id in data.get("recipes", {}):
            all_recipes[recipe_id] = data.recipes[recipe_id]

func get_item(item_id: String) -> Dictionary:
    return all_items.get(item_id, {})

func get_building(building_id: String) -> Dictionary:
    return all_buildings.get(building_id, {})

func get_recipe(recipe_id: String) -> Dictionary:
    return all_recipes.get(recipe_id, {})
`

- [ ] **步骤 5：验证自动加载**

运行Godot编辑器，检查输出面板是否有错误：
`
预期：无错误输出，自动加载成功
`

---

### 任务 2：数据配置文件

**目标：** 创建基础金属生产线的JSON配置

**文件：**
- 创建：data/base_metals.json

- [ ] **步骤 1：创建数据文件**

`json
{
  "line_id": "base_metals",
  "name": "基础金属生产线",
  "items": {
    "iron_ore": {
      "id": "iron_ore",
      "name": "铁矿石",
      "symbol": "Fe",
      "color": "#9aa6a8",
      "description": "铁系生产链的基础矿物"
    },
    "iron_ingot": {
      "id": "iron_ingot",
      "name": "铁锭",
      "symbol": "Fe↑",
      "color": "#c0c0c0",
      "description": "冶炼后的铁锭，用于制造各种零件"
    }
  },
  "buildings": {
    "miner": {
      "id": "miner",
      "name": "矿机",
      "symbol": "⛏️",
      "kind": "extractor",
      "description": "安装在矿脉上，持续开采矿物",
      "size": {"width": 1, "height": 1},
      "power_demand": 0,
      "speed": 1.0
    },
    "smelter": {
      "id": "smelter",
      "name": "熔炉",
      "symbol": "🔥",
      "kind": "processor",
      "description": "将矿石冶炼成锭",
      "size": {"width": 1, "height": 1},
      "power_demand": 0,
      "speed": 1.0,
      "input_slots": 1,
      "output_slots": 1
    }
  },
  "recipes": {
    "iron_ingot_recipe": {
      "id": "iron_ingot_recipe",
      "name": "铁锭冶炼",
      "building_id": "smelter",
      "inputs": [
        {"item_id": "iron_ore", "amount": 1}
      ],
      "outputs": [
        {"item_id": "iron_ingot", "amount": 1}
      ],
      "duration": 1.0
    }
  }
}
`

- [ ] **步骤 2：验证数据加载**

在GameManager._ready()中添加测试代码：
`gdscript
func _ready():
    game_state = GameState.new()
    simulation_engine = SimulationEngine.new(game_state)
    
    # 测试数据加载
    print("Items: ", DataManager.all_items.size())
    print("Buildings: ", DataManager.all_buildings.size())
    print("Recipes: ", DataManager.all_recipes.size())
`

运行Godot，检查输出：
`
预期输出：
Items: 2
Buildings: 2
Recipes: 1
`

---

### 任务 3：游戏状态系统

**目标：** 实现GameState，管理建筑和连接

**文件：**
- 创建：scripts/game/GameState.gd

- [ ] **步骤 1：创建GameState类**

`gdscript
# scripts/game/GameState.gd
class_name GameState
extends RefCounted

# 游戏状态
var paused: bool = false
var speed: float = 1.0
var elapsed_time: float = 0.0

# 所有建筑（卡牌）
var buildings: Dictionary = {}
# {
#   "building_1": {
#     "id": "building_1",
#     "type": "miner",
#     "position": Vector2(100, 200),
#     "status": "idle",
#     "progress": 0.0,
#     "input_buffer": {},
#     "output_buffer": {},
#     "recipe_id": ""
#   }
# }

# 所有连接
var connections: Dictionary = {}
# {
#   "conn_1": {
#     "id": "conn_1",
#     "source_id": "building_1",
#     "source_slot": 0,
#     "target_id": "building_2",
#     "target_slot": 0,
#     "item_id": "iron_ore",
#     "flow_rate": 10
#   }
# }

# ID计数器
var _next_id: int = 1

func generate_id(prefix: String) -> String:
    var id = prefix + "_" + str(_next_id)
    _next_id += 1
    return id

func add_building(building_data: Dictionary) -> String:
    var id = generate_id("building")
    building_data["id"] = id
    buildings[id] = building_data
    EventBus.card_placed.emit(id, building_data.get("position", Vector2.ZERO))
    return id

func remove_building(building_id: String):
    if buildings.has(building_id):
        buildings.erase(building_id)
        # 删除相关连接
        var connections_to_remove = []
        for conn_id in connections:
            var conn = connections[conn_id]
            if conn.source_id == building_id or conn.target_id == building_id:
                connections_to_remove.append(conn_id)
        for conn_id in connections_to_remove:
            remove_connection(conn_id)
        EventBus.card_removed.emit(building_id)

func add_connection(connection_data: Dictionary) -> String:
    var id = generate_id("conn")
    connection_data["id"] = id
    connections[id] = connection_data
    EventBus.connection_created.emit(id, connection_data.source_id, connection_data.target_id)
    return id

func remove_connection(connection_id: String):
    if connections.has(connection_id):
        connections.erase(connection_id)
        EventBus.connection_removed.emit(connection_id)

func get_building(building_id: String) -> Dictionary:
    return buildings.get(building_id, {})

func get_connections_for_building(building_id: String) -> Array:
    var result = []
    for conn_id in connections:
        var conn = connections[conn_id]
        if conn.source_id == building_id or conn.target_id == building_id:
            result.append(conn)
    return result
`

- [ ] **步骤 2：创建单元测试**

`gdscript
# tests/unit/test_game_state.gd
extends GutTest

var game_state: GameState

func before_each():
    game_state = GameState.new()

func test_add_building():
    var building_data = {
        "type": "miner",
        "position": Vector2(100, 200),
        "status": "idle"
    }
    var id = game_state.add_building(building_data)
    assert_not_empty(id)
    assert_true(game_state.buildings.has(id))
    assert_eq(game_state.buildings[id].type, "miner")

func test_remove_building():
    var building_data = {"type": "miner", "position": Vector2.ZERO}
    var id = game_state.add_building(building_data)
    game_state.remove_building(id)
    assert_false(game_state.buildings.has(id))

func test_add_connection():
    var source_id = game_state.add_building({"type": "miner"})
    var target_id = game_state.add_building({"type": "smelter"})
    
    var conn_data = {
        "source_id": source_id,
        "target_id": target_id,
        "item_id": "iron_ore"
    }
    var conn_id = game_state.add_connection(conn_data)
    assert_true(game_state.connections.has(conn_id))

func test_remove_building_removes_connections():
    var source_id = game_state.add_building({"type": "miner"})
    var target_id = game_state.add_building({"type": "smelter"})
    
    game_state.add_connection({
        "source_id": source_id,
        "target_id": target_id,
        "item_id": "iron_ore"
    })
    
    game_state.remove_building(source_id)
    assert_eq(game_state.connections.size(), 0)
`

- [ ] **步骤 3：运行测试**

`
预期：所有测试通过
`

---

### 任务 4：模拟引擎（简化版）

**目标：** 实现核心模拟循环，支持生产和物流

**文件：**
- 创建：scripts/game/SimulationEngine.gd
- 创建：scripts/game/ProductionSystem.gd
- 创建：scripts/game/LogisticsSystem.gd

- [ ] **步骤 1：创建SimulationEngine**

`gdscript
# scripts/game/SimulationEngine.gd
class_name SimulationEngine
extends Node

var game_state: GameState
var production_system: ProductionSystem
var logistics_system: LogisticsSystem

func _init(state: GameState):
    game_state = state
    production_system = ProductionSystem.new(state)
    logistics_system = LogisticsSystem.new(state)

func update(delta: float):
    if game_state.paused:
        return
    
    var game_delta = delta * game_state.speed
    game_state.elapsed_time += game_delta
    
    # 先物流，再生产（参照DSPONLINE）
    logistics_system.update(game_delta)
    production_system.update(game_delta)
    
    EventBus.simulation_updated.emit()

func toggle_pause():
    game_state.paused = !game_state.paused

func set_speed(new_speed: float):
    game_state.speed = clamp(new_speed, 0.5, 4.0)
`

- [ ] **步骤 2：创建ProductionSystem**

`gdscript
# scripts/game/ProductionSystem.gd
class_name ProductionSystem
extends RefCounted

var game_state: GameState

func _init(state: GameState):
    game_state = state

func update(delta: float):
    for building_id in game_state.buildings:
        var building = game_state.buildings[building_id]
        _update_building(building, delta)

func _update_building(building: Dictionary, delta: float):
    var building_type = building.get("type", "")
    var recipe_id = building.get("recipe_id", "")
    
    # 采矿机特殊逻辑
    if building_type == "miner":
        _update_miner(building, delta)
        return
    
    # 加工设备逻辑
    if recipe_id.is_empty():
        building.status = "idle"
        return
    
    var recipe = DataManager.get_recipe(recipe_id)
    if recipe.is_empty():
        building.status = "error"
        return
    
    # 检查输入
    if not _has_required_inputs(building, recipe):
        building.status = "blocked"
        return
    
    # 检查输出空间
    if not _has_output_space(building, recipe):
        building.status = "blocked"
        return
    
    # 更新进度
    building.progress += delta * building.get("speed", 1.0)
    building.status = "running"
    
    # 检查是否完成
    if building.progress >= recipe.duration:
        _consume_inputs(building, recipe)
        _produce_outputs(building, recipe)
        building.progress = 0.0
        EventBus.production_completed.emit(building.id, recipe.outputs[0].item_id, recipe.outputs[0].amount)

func _update_miner(building: Dictionary, delta: float):
    # 采矿机持续生产，无需输入
    var output_item = building.get("output_item", "iron_ore")
    var output_rate = building.get("output_rate", 10.0) / 60.0  # 转换为每秒
    
    if not building.has("output_buffer"):
        building.output_buffer = {}
    
    var current_amount = building.output_buffer.get(output_item, 0.0)
    building.output_buffer[output_item] = current_amount + output_rate * delta
    building.status = "running"

func _has_required_inputs(building: Dictionary, recipe: Dictionary) -> bool:
    for input in recipe.inputs:
        var item_id = input.item_id
        var required = input.amount
        var buffered = building.get("input_buffer", {}).get(item_id, 0.0)
        if buffered < required:
            return false
    return true

func _has_output_space(building: Dictionary, recipe: Dictionary) -> bool:
    for output in recipe.outputs:
        var item_id = output.item_id
        var amount = output.amount
        var buffered = building.get("output_buffer", {}).get(item_id, 0.0)
        if buffered + amount > 60:  # 最大缓冲60
            return false
    return true

func _consume_inputs(building: Dictionary, recipe: Dictionary):
    if not building.has("input_buffer"):
        building.input_buffer = {}
    for input in recipe.inputs:
        var item_id = input.item_id
        building.input_buffer[item_id] = building.input_buffer.get(item_id, 0.0) - input.amount

func _produce_outputs(building: Dictionary, recipe: Dictionary):
    if not building.has("output_buffer"):
        building.output_buffer = {}
    for output in recipe.outputs:
        var item_id = output.item_id
        building.output_buffer[item_id] = building.output_buffer.get(item_id, 0.0) + output.amount
`

- [ ] **步骤 3：创建LogisticsSystem**

`gdscript
# scripts/game/LogisticsSystem.gd
class_name LogisticsSystem
extends RefCounted

var game_state: GameState

func _init(state: GameState):
    game_state = state

func update(delta: float):
    for conn_id in game_state.connections:
        var connection = game_state.connections[conn_id]
        _update_connection(connection, delta)

func _update_connection(connection: Dictionary, delta: float):
    var source_id = connection.source_id
    var target_id = connection.target_id
    var item_id = connection.item_id
    var flow_rate = connection.get("flow_rate", 10.0) / 60.0  # 转换为每秒
    
    var source = game_state.get_building(source_id)
    var target = game_state.get_building(target_id)
    
    if source.is_empty() or target.is_empty():
        return
    
    # 计算可传输量
    var available = source.get("output_buffer", {}).get(item_id, 0.0)
    var target_buffer = target.get("input_buffer", {}).get(item_id, 0.0)
    var max_transfer = min(available, 60 - target_buffer)  # 目标最大60
    var transfer_amount = min(max_transfer, flow_rate * delta)
    
    if transfer_amount > 0:
        # 执行传输
        if not source.has("output_buffer"):
            source.output_buffer = {}
        if not target.has("input_buffer"):
            target.input_buffer = {}
        
        source.output_buffer[item_id] = source.output_buffer.get(item_id, 0.0) - transfer_amount
        target.input_buffer[item_id] = target.input_buffer.get(item_id, 0.0) + transfer_amount
`

- [ ] **步骤 4：创建模拟引擎测试**

`gdscript
# tests/unit/test_simulation.gd
extends GutTest

var game_state: GameState
var simulation: SimulationEngine

func before_each():
    game_state = GameState.new()
    simulation = SimulationEngine.new(game_state)

func test_miner_produces_ore():
    var miner_id = game_state.add_building({
        "type": "miner",
        "output_item": "iron_ore",
        "output_rate": 10.0,
        "output_buffer": {}
    })
    
    simulation.update(1.0)  # 模拟1秒
    
    var miner = game_state.get_building(miner_id)
    assert_almost_eq(miner.output_buffer.get("iron_ore", 0.0), 10.0 / 60.0, 0.01)

func test_smelter_produces_ingot():
    var miner_id = game_state.add_building({
        "type": "miner",
        "output_item": "iron_ore",
        "output_rate": 60.0,
        "output_buffer": {"iron_ore": 10.0}
    })
    
    var smelter_id = game_state.add_building({
        "type": "smelter",
        "recipe_id": "iron_ingot_recipe",
        "input_buffer": {},
        "output_buffer": {},
        "speed": 1.0
    })
    
    game_state.add_connection({
        "source_id": miner_id,
        "target_id": smelter_id,
        "item_id": "iron_ore",
        "flow_rate": 60.0
    })
    
    # 模拟足够时间让物流传输和生产完成
    simulation.update(2.0)
    
    var smelter = game_state.get_building(smelter_id)
    assert_true(smelter.output_buffer.get("iron_ingot", 0.0) > 0)
`

- [ ] **步骤 5：运行测试**

`
预期：所有测试通过
`

---

### 任务 5：主场景和画布

**目标：** 创建主场景和Canvas 2D画布

**文件：**
- 创建：scenes/main/Main.tscn
- 创建：scenes/main/Main.gd
- 创建：scenes/canvas/GameCanvas.tscn
- 创建：scenes/canvas/GameCanvas.gd

- [ ] **步骤 1：创建主场景**

在Godot编辑器中：
1. 创建新场景
2. 根节点：Node2D，命名为"Main"
3. 添加子节点：GameCanvas（Node2D）
4. 添加子节点：Camera2D
5. 保存为 scenes/main/Main.tscn

- [ ] **步骤 2：编写主场景脚本**

`gdscript
# scenes/main/Main.gd
extends Node2D

@onready var game_canvas: Node2D = 
@onready var camera: Camera2D = 

func _ready():
    # 连接信号
    EventBus.card_placed.connect(_on_card_placed)
    EventBus.card_removed.connect(_on_card_removed)

func _on_card_placed(card_id: String, position: Vector2):
    print("Card placed: ", card_id, " at ", position)

func _on_card_removed(card_id: String):
    print("Card removed: ", card_id)
`

- [ ] **步骤 3：创建GameCanvas场景**

1. 创建新场景
2. 根节点：Node2D，命名为"GameCanvas"
3. 添加脚本 scenes/canvas/GameCanvas.gd
4. 保存为 scenes/canvas/GameCanvas.tscn

- [ ] **步骤 4：编写GameCanvas脚本**

`gdscript
# scenes/canvas/GameCanvas.gd
extends Node2D

# 绘制配置
const CARD_WIDTH = 200
const CARD_HEIGHT = 150
const CARD_COLOR_IDLE = Color(0.4, 0.4, 0.4)
const CARD_COLOR_RUNNING = Color(0.0, 0.94, 1.0)
const CARD_COLOR_BLOCKED = Color(1.0, 0.27, 0.27)

func _draw():
    var game_state = GameManager.get_game_state()
    
    # 绘制所有建筑
    for building_id in game_state.buildings:
        var building = game_state.buildings[building_id]
        _draw_building(building)
    
    # 绘制所有连接
    for conn_id in game_state.connections:
        var connection = game_state.connections[conn_id]
        _draw_connection(connection)

func _draw_building(building: Dictionary):
    var pos = building.get("position", Vector2.ZERO)
    var status = building.get("status", "idle")
    var color = CARD_COLOR_IDLE
    
    match status:
        "running":
            color = CARD_COLOR_RUNNING
        "blocked":
            color = CARD_COLOR_BLOCKED
    
    # 绘制卡片背景
    var rect = Rect2(pos, Vector2(CARD_WIDTH, CARD_HEIGHT))
    draw_rect(rect, color)
    draw_rect(rect, Color.WHITE, false, 2.0)
    
    # 绘制文字
    var font = ThemeDB.fallback_font
    var building_type = building.get("type", "unknown")
    draw_string(font, pos + Vector2(10, 25), building_type, HORIZONTAL_ALIGNMENT_LEFT, -1, 16)
    
    # 绘制状态
    draw_string(font, pos + Vector2(10, 45), "Status: " + status, HORIZONTAL_ALIGNMENT_LEFT, -1, 12)

func _draw_connection(connection: Dictionary):
    var source = GameManager.get_game_state().get_building(connection.source_id)
    var target = GameManager.get_game_state().get_building(connection.target_id)
    
    if source.is_empty() or target.is_empty():
        return
    
    var start_pos = source.get("position", Vector2.ZERO) + Vector2(CARD_WIDTH, CARD_HEIGHT / 2)
    var end_pos = target.get("position", Vector2.ZERO) + Vector2(0, CARD_HEIGHT / 2)
    
    # 绘制连线
    draw_line(start_pos, end_pos, Color.WHITE, 2.0)
    
    # 绘制箭头
    var direction = (end_pos - start_pos).normalized()
    var arrow_pos = end_pos - direction * 10
    draw_line(arrow_pos, arrow_pos + direction.rotated(0.5) * 10, Color.WHITE, 2.0)
    draw_line(arrow_pos, arrow_pos + direction.rotated(-0.5) * 10, Color.WHITE, 2.0)

func _process(_delta):
    queue_redraw()  # 每帧重绘
`

- [ ] **步骤 5：运行场景**

在Godot编辑器中运行Main场景，检查是否正常显示。

---

### 任务 6：输入处理系统

**目标：** 实现卡牌放置和连线操作

**文件：**
- 创建：scripts/input/InputHandler.gd

- [ ] **步骤 1：创建InputHandler**

`gdscript
# scripts/input/InputHandler.gd
class_name InputHandler
extends Node

# 操作模式
enum Mode {
    IDLE,
    PLACING_CARD,
    CONNECTING
}

var current_mode: Mode = Mode.IDLE
var placing_building_type: String = ""
var connecting_source_id: String = ""
var mouse_position: Vector2 = Vector2.ZERO

func _input(event):
    if event is InputEventMouseMotion:
        mouse_position = event.position
    
    if event is InputEventMouseButton:
        if event.button_index == MOUSE_BUTTON_LEFT:
            if event.pressed:
                _handle_left_click()
            else:
                _handle_left_release()
    
    if event is InputEventKey:
        if event.pressed:
            _handle_key_press(event)

func _handle_left_click():
    match current_mode:
        Mode.IDLE:
            # 检查是否点击了建筑
            var clicked_building = _get_building_at_position(mouse_position)
            if not clicked_building.is_empty():
                EventBus.card_selected.emit(clicked_building.id)
        Mode.PLACING_CARD:
            _place_card()
        Mode.CONNECTING:
            _finish_connection()

func _handle_left_release():
    pass

func _handle_key_press(event: InputEventKey):
    match event.keycode:
        KEY_ESCAPE:
            _cancel_operation()
        KEY_Q:
            start_placing_card("miner")
        KEY_W:
            start_placing_card("smelter")

func start_placing_card(building_type: String):
    current_mode = Mode.PLACING_CARD
    placing_building_type = building_type

func _place_card():
    var building_data = {
        "type": placing_building_type,
        "position": mouse_position,
        "status": "idle",
        "progress": 0.0,
        "input_buffer": {},
        "output_buffer": {}
    }
    
    # 根据类型设置默认值
    var building_def = DataManager.get_building(placing_building_type)
    if not building_def.is_empty():
        if building_def.kind == "extractor":
            building_data.output_item = building_def.get("outputs", ["iron_ore"])[0]
            building_data.output_rate = 60.0
    
    GameManager.get_game_state().add_building(building_data)
    current_mode = Mode.IDLE

func start_connection(source_id: String):
    current_mode = Mode.CONNECTING
    connecting_source_id = source_id

func _finish_connection():
    var target_building = _get_building_at_position(mouse_position)
    if not target_building.is_empty() and target_building.id != connecting_source_id:
        var connection_data = {
            "source_id": connecting_source_id,
            "target_id": target_building.id,
            "item_id": "iron_ore",
            "flow_rate": 60.0
        }
        GameManager.get_game_state().add_connection(connection_data)
    current_mode = Mode.IDLE

func _cancel_operation():
    current_mode = Mode.IDLE
    placing_building_type = ""
    connecting_source_id = ""

func _get_building_at_position(pos: Vector2) -> Dictionary:
    var game_state = GameManager.get_game_state()
    for building_id in game_state.buildings:
        var building = game_state.buildings[building_id]
        var building_pos = building.get("position", Vector2.ZERO)
        var rect = Rect2(building_pos, Vector2(200, 150))
        if rect.has_point(pos):
            return building
    return {}
`

- [ ] **步骤 2：集成到主场景**

修改 Main.gd：

`gdscript
extends Node2D

@onready var game_canvas: Node2D = 
@onready var camera: Camera2D = 
@onready var input_handler: InputHandler = 

func _ready():
    EventBus.card_placed.connect(_on_card_placed)
    EventBus.card_removed.connect(_on_card_removed)

func _on_card_placed(card_id: String, position: Vector2):
    print("Card placed: ", card_id, " at ", position)

func _on_card_removed(card_id: String):
    print("Card removed: ", card_id)
`

在场景中添加InputHandler节点。

- [ ] **步骤 3：测试输入**

运行场景，按Q放置矿机，按W放置熔炉，点击建筑选中。

---

### 任务 7：完整流程测试

**目标：** 测试完整的生产流程

- [ ] **步骤 1：手动测试流程**

1. 运行游戏
2. 按Q放置矿机
3. 按W放置熔炉
4. 点击矿机，然后拖拽到熔炉创建连接
5. 观察生产流程

- [ ] **步骤 2：验证生产**

检查控制台输出，确认：
- 矿机状态变为"running"
- 铁矿石在矿机输出缓冲区增加
- 铁矿石通过连接传输到熔炉
- 熔炉开始生产铁锭

- [ ] **步骤 3：修复发现的问题**

根据测试结果修复任何问题。

---

## 完成标准

第一阶段完成时，应该能够：

1. ✅ 放置矿机和熔炉
2. ✅ 创建连接
3. ✅ 矿机自动生产铁矿石
4. ✅ 铁矿石通过连接传输到熔炉
5. ✅ 熔炉消耗铁矿石生产铁锭
6. ✅ 基础UI显示卡牌和连线

---

**计划完成日期：** 2026-08-28（2-3周）
