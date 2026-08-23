# CardFactory 第二阶段实现计划

> **历史资料：** 本计划保留当时设想，不证明当前完成状态；请以 [`docs/PROJECT_STATUS.md`](../../PROJECT_STATUS.md) 为准。

> **面向 AI 代理的工作者：** 必需子技能：使用 superpowers:subagent-driven-development（推荐）或 superpowers:executing-plans 逐任务实现此计划。步骤使用复选框（`- [ ]`）语法来跟踪进度。

**目标：** 扩展游戏功能，添加更多生产线、电力系统、传送带系统，完善UI界面

**架构：** 数据驱动 + Canvas 2D渲染 + 模块化系统

**技术栈：** Godot 4.7.2, GDScript, JSON

---

## 任务分解

### 任务 1：扩展数据配置

**目标：** 添加更多生产线数据（化工、电子）

**文件：**
- 创建：data/chemicals.json
- 创建：data/electronics.json
- 修改：autoload/DataManager.gd（自动加载所有数据文件）

- [ ] **步骤 1：创建化工生产线配置**

```json
{
  "line_id": "chemicals",
  "name": "化工生产线",
  "items": {
    "plastic": {
      "id": "plastic",
      "name": "塑料",
      "symbol": "Pl",
      "color": "#e8e8e8",
      "description": "基础化工产品"
    },
    "rubber": {
      "id": "rubber",
      "name": "橡胶",
      "symbol": "Rb",
      "color": "#4a4a4a",
      "description": "弹性材料"
    }
  },
  "buildings": {
    "chemical_plant": {
      "id": "chemical_plant",
      "name": "化工厂",
      "symbol": "🧪",
      "kind": "processor",
      "description": "处理化工配方",
      "size": {"width": 2, "height": 2},
      "power_demand": 100,
      "speed": 0.5,
      "input_slots": 2,
      "output_slots": 2
    }
  },
  "recipes": {
    "plastic_recipe": {
      "id": "plastic_recipe",
      "name": "塑料生产",
      "building_id": "chemical_plant",
      "inputs": [
        {"item_id": "iron_ore", "amount": 2},
        {"item_id": "coal", "amount": 1}
      ],
      "outputs": [
        {"item_id": "plastic", "amount": 1}
      ],
      "duration": 2.0
    }
  }
}
```

- [ ] **步骤 2：创建电子生产线配置**

```json
{
  "line_id": "electronics",
  "name": "电子生产线",
  "items": {
    "circuit": {
      "id": "circuit",
      "name": "电路板",
      "symbol": "⚡",
      "color": "#00ff00",
      "description": "基础电子元件"
    },
    "chip": {
      "id": "chip",
      "name": "芯片",
      "symbol": "💎",
      "color": "#00bfff",
      "description": "高级电子元件"
    }
  },
  "buildings": {
    "assembler": {
      "id": "assembler",
      "name": "组装机",
      "symbol": "⚙️",
      "kind": "processor",
      "description": "组装电子元件",
      "size": {"width": 1, "height": 1},
      "power_demand": 50,
      "speed": 1.0,
      "input_slots": 3,
      "output_slots": 1
    }
  },
  "recipes": {
    "circuit_recipe": {
      "id": "circuit_recipe",
      "name": "电路板组装",
      "building_id": "assembler",
      "inputs": [
        {"item_id": "iron_ingot", "amount": 2},
        {"item_id": "copper_ingot", "amount": 1}
      ],
      "outputs": [
        {"item_id": "circuit", "amount": 1}
      ],
      "duration": 1.5
    }
  }
}
```

- [ ] **步骤 3：修改DataManager自动加载所有数据文件**

```gdscript
func _load_all_data():
    var dir = DirAccess.open("res://data")
    if dir:
        dir.list_dir_begin()
        var file_name = dir.get_next()
        while file_name != "":
            if file_name.ends_with(".json"):
                _load_data_file("res://data/" + file_name)
            file_name = dir.get_next()
```

---

### 任务 2：电力系统

**目标：** 实现电力生产和消耗系统

**文件：**
- 创建：scripts/game/PowerSystem.gd
- 修改：scripts/game/SimulationEngine.gd
- 修改：data/base_metals.json（添加电力相关建筑）

- [ ] **步骤 1：创建PowerSystem**

```gdscript
# scripts/game/PowerSystem.gd
class_name PowerSystem
extends RefCounted

var game_state: GameState

# 电力数据
var total_generation: float = 0.0
var total_consumption: float = 0.0
var power_balance: float = 0.0

func _init(state: GameState):
    game_state = state

func update(delta: float):
    _calculate_power()
    _apply_power_effects()

func _calculate_power():
    total_generation = 0.0
    total_consumption = 0.0
    
    for building_id in game_state.buildings:
        var building = game_state.buildings[building_id]
        var building_def = DataManager.get_building(building.type)
        
        if building_def.is_empty():
            continue
        
        # 发电建筑
        if building_def.has("power_generation"):
            total_generation += building_def.power_generation * building.get("efficiency", 1.0)
        
        # 耗电建筑
        if building_def.has("power_demand"):
            total_consumption += building_def.power_demand
    
    power_balance = total_generation - total_consumption

func _apply_power_effects():
    # 如果电力不足，降低建筑效率
    if power_balance < 0:
        var efficiency_multiplier = max(0.0, 1.0 + power_balance / total_consumption)
        for building_id in game_state.buildings:
            var building = game_state.buildings[building_id]
            building["power_efficiency"] = efficiency_multiplier
    else:
        for building_id in game_state.buildings:
            var building = game_state.buildings[building_id]
            building["power_efficiency"] = 1.0

func get_power_info() -> Dictionary:
    return {
        "generation": total_generation,
        "consumption": total_consumption,
        "balance": power_balance
    }
```

- [ ] **步骤 2：添加发电机到数据配置**

```json
{
  "buildings": {
    "power_generator": {
      "id": "power_generator",
      "name": "发电机",
      "symbol": "🔋",
      "kind": "generator",
      "description": "燃烧燃料产生电力",
      "size": {"width": 1, "height": 1},
      "power_demand": 0,
      "power_generation": 500,
      "input_slots": 1,
      "output_slots": 0
    }
  }
}
```

- [ ] **步骤 3：修改SimulationEngine集成电力系统**

```gdscript
func _init(state: GameState):
    game_state = state
    production_system = ProductionSystem.new(state)
    logistics_system = LogisticsSystem.new(state)
    power_system = PowerSystem.new(state)

func update(delta: float):
    if game_state.paused:
        return
    
    var game_delta = delta * game_state.speed
    game_state.elapsed_time += game_delta
    
    # 更新顺序：电力 → 物流 → 生产
    power_system.update(game_delta)
    logistics_system.update(game_delta)
    production_system.update(game_delta)
    
    EventBus.simulation_updated.emit()
```

---

### 任务 3：传送带系统

**目标：** 实现传送带连接和物品传输可视化

**文件：**
- 创建：scripts/game/BeltSystem.gd
- 修改：scripts/rendering/ConnectionRenderer.gd
- 修改：scripts/input/InputHandler.gd

- [ ] **步骤 1：创建BeltSystem**

```gdscript
# scripts/game/BeltSystem.gd
class_name BeltSystem
extends RefCounted

var game_state: GameState

func _init(state: GameState):
    game_state = state

func update(delta: float):
    for conn_id in game_state.connections:
        var connection = game_state.connections[conn_id]
        if connection.get("type") == "belt":
            _update_belt(connection, delta)

func _update_belt(belt: Dictionary, delta: float):
    var source = game_state.get_building(belt.source_id)
    var target = game_state.get_building(belt.target_id)
    
    if source.is_empty() or target.is_empty():
        return
    
    var item_id = belt.item_id
    var flow_rate = belt.get("flow_rate", 10.0)
    var belt_speed = belt.get("speed", 1.0)
    
    # 计算实际传输量
    var available = source.get("output_buffer", {}).get(item_id, 0.0)
    var target_space = 60.0 - target.get("input_buffer", {}).get(item_id, 0.0)
    var max_transfer = min(available, target_space)
    var transfer_amount = min(max_transfer, flow_rate * belt_speed * delta)
    
    if transfer_amount > 0:
        # 执行传输
        if not source.has("output_buffer"):
            source.output_buffer = {}
        if not target.has("input_buffer"):
            target.input_buffer = {}
        
        source.output_buffer[item_id] = source.output_buffer.get(item_id, 0.0) - transfer_amount
        target.input_buffer[item_id] = target.input_buffer.get(item_id, 0.0) + transfer_amount
        
        # 更新传送带状态
        belt["current_flow"] = transfer_amount / delta
        belt["active"] = true
    else:
        belt["current_flow"] = 0.0
        belt["active"] = false
```

- [ ] **步骤 2：增强ConnectionRenderer显示传送带动画**

```gdscript
func _draw_connection(connection: Dictionary):
    var source = GameManager.get_game_state().get_building(connection.source_id)
    var target = GameManager.get_game_state().get_building(connection.target_id)
    
    if source.is_empty() or target.is_empty():
        return
    
    var start_pos = source.get("position", Vector2.ZERO) + Vector2(200, 75)
    var end_pos = target.get("position", Vector2.ZERO) + Vector2(0, 75)
    
    # 绘制连线
    var color = Color.WHITE
    if connection.get("active", false):
        color = Color.GREEN
    
    draw_line(start_pos, end_pos, color, 2.0)
    
    # 绘制流动粒子
    if connection.get("active", false):
        _draw_flow_particles(start_pos, end_pos, connection)

func _draw_flow_particles(start: Vector2, end: Vector2, connection: Dictionary):
    var progress = fmod(Time.get_ticks_msec() / 1000.0, 1.0)
    var particle_pos = start.lerp(end, progress)
    
    draw_circle(particle_pos, 4.0, Color.YELLOW)
```

- [ ] **步骤 3：修改InputHandler添加传送带放置**

```gdscript
func _handle_key_press(event: InputEventKey):
    match event.keycode:
        KEY_ESCAPE:
            _cancel_operation()
        KEY_Q:
            start_placing_card("miner")
        KEY_W:
            start_placing_card("smelter")
        KEY_E:
            start_placing_card("power_generator")
        KEY_R:
            start_placing_belt()

func start_placing_belt():
    current_mode = Mode.CONNECTING
    connecting_source_id = ""
```

---

### 任务 4：UI界面系统

**目标：** 添加HUD界面、建筑选择面板、信息显示

**文件：**
- 创建：scenes/ui/HUD.tscn
- 创建：scenes/ui/HUD.gd
- 创建：scenes/ui/BuildingPanel.tscn
- 创建：scenes/ui/BuildingPanel.gd
- 修改：scenes/main/Main.tscn

- [ ] **步骤 1：创建HUD场景**

```gdscript
# scenes/ui/HUD.gd
extends CanvasLayer

@onready var power_label: Label = $PowerLabel
@onready var building_count_label: Label = $BuildingCountLabel
@onready var time_label: Label = $TimeLabel

func _process(delta):
    _update_power_info()
    _update_building_count()
    _update_time()

func _update_power_info():
    var power_info = GameManager.get_simulation_engine().power_system.get_power_info()
    power_label.text = "电力: %d / %d (余额: %d)" % [
        power_info.generation,
        power_info.consumption,
        power_info.balance
    ]

func _update_building_count():
    var building_count = GameManager.get_game_state().buildings.size()
    building_count_label.text = "建筑: %d" % building_count

func _update_time():
    var elapsed = GameManager.get_game_state().elapsed_time
    var minutes = int(elapsed) / 60
    var seconds = int(elapsed) % 60
    time_label.text = "时间: %02d:%02d" % [minutes, seconds]
```

- [ ] **步骤 2：创建建筑选择面板**

```gdscript
# scenes/ui/BuildingPanel.gd
extends PanelContainer

var building_types = [
    {"id": "miner", "name": "矿机", "key": "Q"},
    {"id": "smelter", "name": "熔炉", "key": "W"},
    {"id": "power_generator", "name": "发电机", "key": "E"},
    {"id": "chemical_plant", "name": "化工厂", "key": "R"}
]

func _ready():
    _create_building_buttons()

func _create_building_buttons():
    var vbox = VBoxContainer.new()
    add_child(vbox)
    
    for building in building_types:
        var button = Button.new()
        button.text = "%s (%s)" % [building.name, building.key]
        button.pressed.connect(_on_building_selected.bind(building.id))
        vbox.add_child(button)

func _on_building_selected(building_id: String):
    GameManager.get_game_state().selected_building_type = building_id
```

---

### 任务 5：小地图系统

**目标：** 添加小地图显示和导航

**文件：**
- 创建：scenes/ui/MiniMap.tscn
- 创建：scenes/ui/MiniMap.gd
- 修改：scenes/main/Main.tscn

- [ ] **步骤 1：创建小地图**

```gdscript
# scenes/ui/MiniMap.gd
extends Control

const MINIMAP_SIZE = Vector2(200, 150)
const WORLD_SIZE = Vector2(2000, 1500)

@onready var camera: Camera2D

func _draw():
    # 绘制背景
    draw_rect(Rect2(Vector2.ZERO, MINIMAP_SIZE), Color(0.1, 0.1, 0.1, 0.8))
    
    # 绘制建筑
    var game_state = GameManager.get_game_state()
    for building_id in game_state.buildings:
        var building = game_state.buildings[building_id]
        var world_pos = building.get("position", Vector2.ZERO)
        var minimap_pos = world_pos / WORLD_SIZE * MINIMAP_SIZE
        
        var color = Color.GRAY
        if building.get("status") == "running":
            color = Color.GREEN
        
        draw_rect(Rect2(minimap_pos, Vector2(4, 4)), color)
    
    # 绘制相机视野
    if camera:
        var camera_pos = camera.global_position
        var viewport_size = get_viewport().get_visible_rect().size
        var camera_minimap_pos = camera_pos / WORLD_SIZE * MINIMAP_SIZE
        var camera_size = viewport_size / WORLD_SIZE * MINIMAP_SIZE
        
        draw_rect(Rect2(camera_minimap_pos - camera_size / 2, camera_size), Color.WHITE, false, 1.0)

func _input(event):
    if event is InputEventMouseButton and event.pressed:
        if Rect2(Vector2.ZERO, MINIMAP_SIZE).has_point(event.position):
            var world_pos = event.position / MINIMAP_SIZE * WORLD_SIZE
            if camera:
                camera.global_position = world_pos
```

---

### 任务 6：存档系统

**目标：** 实现游戏存档和读档功能

**文件：**
- 创建：scripts/game/SaveSystem.gd
- 修改：autoload/GameManager.gd

- [ ] **步骤 1：创建SaveSystem**

```gdscript
# scripts/game/SaveSystem.gd
class_name SaveSystem
extends RefCounted

const SAVE_PATH = "user://saves/"

static func save_game(slot: int):
    var dir = DirAccess.open("user://")
    if not dir.dir_exists("saves"):
        dir.make_dir("saves")
    
    var game_state = GameManager.get_game_state()
    var save_data = {
        "version": "1.0.0",
        "timestamp": Time.get_unix_time_from_system(),
        "buildings": game_state.buildings,
        "connections": game_state.connections,
        "elapsed_time": game_state.elapsed_time
    }
    
    var file = FileAccess.open(SAVE_PATH + "save_%d.json" % slot, FileAccess.WRITE)
    if file:
        file.store_string(JSON.stringify(save_data, "\t"))
        file.close()
        print("游戏已保存到槽位: ", slot)

static func load_game(slot: int) -> bool:
    var file_path = SAVE_PATH + "save_%d.json" % slot
    if not FileAccess.file_exists(file_path):
        print("存档不存在: ", slot)
        return false
    
    var file = FileAccess.open(file_path, FileAccess.READ)
    if file:
        var json = JSON.new()
        var error = json.parse(file.get_as_text())
        file.close()
        
        if error == OK:
            var save_data = json.data
            var game_state = GameManager.get_game_state()
            
            game_state.buildings = save_data.get("buildings", {})
            game_state.connections = save_data.get("connections", {})
            game_state.elapsed_time = save_data.get("elapsed_time", 0.0)
            
            print("游戏已从槽位加载: ", slot)
            return true
    
    return false

static func get_save_slots() -> Array:
    var slots = []
    var dir = DirAccess.open(SAVE_PATH)
    if dir:
        dir.list_dir_begin()
        var file_name = dir.get_next()
        while file_name != "":
            if file_name.ends_with(".json"):
                slots.append(file_name)
            file_name = dir.get_next()
    return slots
```

---

## 完成标准

第二阶段完成时，应该能够：

1. ✅ 支持至少3条生产线（基础金属、化工、电子）
2. ✅ 电力系统正常工作（发电、耗电、电力平衡）
3. ✅ 传送带系统正常工作（物品传输、动画显示）
4. ✅ UI界面正常显示（HUD、建筑面板、信息）
5. ✅ 小地图正常工作（显示、导航）
6. ✅ 存档系统正常工作（保存、加载）

---

**计划完成日期：** 2026-09-18（4-6周）
