# CardFactory 第三阶段实现计划

> **历史资料：** 本计划保留当时设想，不证明当前完成状态；请以 [`docs/PROJECT_STATUS.md`](../../PROJECT_STATUS.md) 为准。

**目标：** 性能优化、视觉升级、统计系统、存档系统

**架构：** Canvas 2D + Shader特效 + 索引优化

**技术栈：** Godot 4.7.2, GDScript, JSON

---

## 任务分解

### 任务 1：性能优化 - 空间索引系统

**目标：** 优化大量建筑的查询性能

**文件：**
- 创建：scripts/utils/SpatialIndex.gd
- 修改：scripts/game/GameState.gd

- [ ] **步骤 1：创建SpatialIndex**

```gdscript
# scripts/utils/SpatialIndex.gd
class_name SpatialIndex
extends RefCounted

const CELL_SIZE = 256
var cells: Dictionary = {}

func add_entity(entity_id: String, position: Vector2):
    var cell_key = _get_cell_key(position)
    if not cells.has(cell_key):
        cells[cell_key] = []
    cells[cell_key].append(entity_id)

func remove_entity(entity_id: String, position: Vector2):
    var cell_key = _get_cell_key(position)
    if cells.has(cell_key):
        cells[cell_key].erase(entity_id)

func get_entities_in_rect(rect: Rect2) -> Array:
    var result = []
    var start_x = int(rect.position.x / CELL_SIZE)
    var start_y = int(rect.position.y / CELL_SIZE)
    var end_x = int((rect.position.x + rect.size.x) / CELL_SIZE)
    var end_y = int((rect.position.y + rect.size.y) / CELL_SIZE)
    
    for x in range(start_x, end_x + 1):
        for y in range(start_y, end_y + 1):
            var cell_key = Vector2i(x, y)
            if cells.has(cell_key):
                result.append_array(cells[cell_key])
    
    return result

func _get_cell_key(position: Vector2) -> Vector2i:
    return Vector2i(int(position.x / CELL_SIZE), int(position.y / CELL_SIZE))
```

---

### 任务 2：视觉升级 - Shader特效

**目标：** 添加发光边框、流动粒子等科幻特效

**文件：**
- 创建：shaders/glow.gdshader
- 创建：shaders/particle_flow.gdshader
- 修改：scripts/rendering/CardRenderer.gd

- [ ] **步骤 1：创建发光Shader**

```glsl
// shaders/glow.gdshader
shader_type canvas_item;

uniform float glow_strength = 0.5;
uniform vec4 glow_color : source_color = vec4(0.0, 0.94, 1.0, 1.0);
uniform float time_scale = 2.0;

void fragment() {
    vec4 tex_color = texture(TEXTURE, UV);
    float glow = sin(TIME * time_scale) * 0.5 + 0.5;
    vec4 final_color = mix(tex_color, glow_color, glow * glow_strength);
    COLOR = final_color;
}
```

- [ ] **步骤 2：创建流动粒子Shader**

```glsl
// shaders/particle_flow.gdshader
shader_type canvas_item;

uniform float speed = 1.0;
uniform float particle_size = 0.1;
uniform vec4 particle_color : source_color = vec4(1.0, 1.0, 0.0, 1.0);

void fragment() {
    vec2 uv = UV;
    float progress = fract(uv.x - TIME * speed);
    float particle = step(1.0 - particle_size, progress);
    vec4 tex_color = texture(TEXTURE, UV);
    COLOR = mix(tex_color, particle_color, particle * tex_color.a);
}
```

---

### 任务 3：统计系统

**目标：** 记录和显示生产统计信息

**文件：**
- 创建：scripts/game/StatisticsSystem.gd
- 修改：scenes/ui/HUD.gd

- [ ] **步骤 1：创建StatisticsSystem**

```gdscript
# scripts/game/StatisticsSystem.gd
class_name StatisticsSystem
extends RefCounted

var game_state: GameState
var production_history: Array = []
var consumption_history: Array = []

func _init(state: GameState):
    game_state = state

func update(delta: float):
    _record_production(delta)

func _record_production(delta: float):
    var production = {}
    var consumption = {}
    
    for building_id in game_state.buildings:
        var building = game_state.buildings[building_id]
        var building_def = DataManager.get_building(building.get("type", ""))
        
        if building_def.is_empty():
            continue
        
        # 记录生产
        var output_buffer = building.get("output_buffer", {})
        for item_id in output_buffer:
            if not production.has(item_id):
                production[item_id] = 0.0
            production[item_id] += output_buffer[item_id]
        
        # 记录消耗
        var input_buffer = building.get("input_buffer", {})
        for item_id in input_buffer:
            if not consumption.has(item_id):
                consumption[item_id] = 0.0
            consumption[item_id] += input_buffer[item_id]
    
    production_history.append(production)
    consumption_history.append(consumption)
    
    # 保留最近100条记录
    if production_history.size() > 100:
        production_history.pop_front()
    if consumption_history.size() > 100:
        consumption_history.pop_front()

func get_production_rate(item_id: String) -> float:
    if production_history.size() < 2:
        return 0.0
    
    var recent = production_history[-1]
    var previous = production_history[-2]
    
    if recent.has(item_id) and previous.has(item_id):
        return recent[item_id] - previous[item_id]
    return 0.0

func get_total_production(item_id: String) -> float:
    if production_history.is_empty():
        return 0.0
    return production_history[-1].get(item_id, 0.0)
```

---

### 任务 4：存档系统增强

**目标：** 完善存档系统，支持自动存档

**文件：**
- 修改：scripts/game/SaveSystem.gd
- 修改：autoload/GameManager.gd

- [ ] **步骤 1：增强SaveSystem**

```gdscript
# scripts/game/SaveSystem.gd
class_name SaveSystem
extends RefCounted

const SAVE_PATH = "user://saves/"
const AUTO_SAVE_INTERVAL = 60.0  # 自动存档间隔（秒）

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
        "elapsed_time": game_state.elapsed_time,
        "statistics": GameManager.get_statistics()
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

static func auto_save():
    save_game(0)  # 自动存档使用槽位0
    print("自动存档完成")

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

### 任务 5：视觉升级 - 卡牌动画

**目标：** 添加卡牌放置动画、状态变化动画

**文件：**
- 修改：scripts/rendering/CardRenderer.gd

- [ ] **步骤 1：添加卡牌动画**

```gdscript
func _draw_building(building: Dictionary):
    var pos = building.get("position", Vector2.ZERO)
    var status = building.get("status", "idle")
    var color = CARD_COLOR_IDLE
    
    # 动画效果
    var animation_progress = building.get("animation_progress", 0.0)
    var scale = 1.0
    
    match status:
        "running":
            color = CARD_COLOR_RUNNING
            scale = 1.0 + sin(Time.get_ticks_msec() * 0.005) * 0.02
        "blocked":
            color = CARD_COLOR_BLOCKED
            scale = 1.0 + sin(Time.get_ticks_msec() * 0.01) * 0.05
    
    # 绘制卡片背景（带缩放）
    var rect = Rect2(pos, Vector2(CARD_WIDTH, CARD_HEIGHT) * scale)
    draw_rect(rect, color)
    draw_rect(rect, Color.WHITE, false, 2.0)
```

---

## 完成标准

第三阶段完成时，应该能够：

1. ✅ 空间索引系统正常工作
2. ✅ Shader特效正常显示
3. ✅ 统计系统正常记录
4. ✅ 存档系统正常工作
5. ✅ 卡牌动画正常显示

---

**计划完成日期：** 2026-09-25（3-4周）
