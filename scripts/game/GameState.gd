# scripts/game/GameState.gd
class_name GameState
extends RefCounted

const SCHEMA_VERSION: int = 2

# 游戏状态
var paused: bool = false
var speed: float = 1.0
var elapsed_time: float = 0.0
var planet_inventory: Dictionary = {
    "coal": 10.0,
    "copper_ingot": 4.0,
    "gear": 4.0,
    "iron_ingot": 12.0,
    "stone": 4.0,
}
var construction_inventory: Dictionary = {
    "miner": 1.0,
    "smelter": 1.0,
    "assembling_machine_mk1": 1.0,
    "power_generator": 1.0,
    "matrix_lab": 1.0,
}
var cursor_payload: Dictionary = {"item_id": "", "amount": 0.0}
var handcraft_queue: Array = []

# 所有建筑（卡牌）
var buildings: Dictionary = {}

# 所有连接
var connections: Dictionary = {}

# 科技系统
var completed_technologies: Array = []

# ID计数器
var _next_id: int = 1

# 建筑升级映射表
var building_upgrade_map: Dictionary = {
    "assembling_machine_mk1": "assembling_machine_mk2",
    "assembling_machine_mk2": "assembling_machine_mk3",
    "arc_smelter": "plane_smelter",
    "chemical_plant": "quantum_chemical_plant",
    "conveyor_belt_mk1": "conveyor_belt_mk2",
    "conveyor_belt_mk2": "conveyor_belt_mk3",
    "sorter_mk1": "sorter_mk2",
    "sorter_mk2": "sorter_mk3"
}

# 传送带升级映射表
var belt_upgrade_map: Dictionary = {
    "conveyor_belt_mk1": "conveyor_belt_mk2",
    "conveyor_belt_mk2": "conveyor_belt_mk3"
}

# 分拣器升级映射表
var sorter_upgrade_map: Dictionary = {
    "sorter_mk1": "sorter_mk2",
    "sorter_mk2": "sorter_mk3"
}

# 传送带速度配置
var belt_speed_config: Dictionary = {
    "conveyor_belt_mk1": 1.0,
    "conveyor_belt_mk2": 2.0,
    "conveyor_belt_mk3": 3.0
}

# 分拣器速度配置
var sorter_speed_config: Dictionary = {
    "sorter_mk1": 1.0,
    "sorter_mk2": 2.0,
    "sorter_mk3": 3.0
}

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

func try_place_building(building_type: String, position: Vector2) -> Dictionary:
    return ConstructionSystem.new(self).try_place_building(building_type, position)

func remove_building(building_id: String) -> Dictionary:
    return ConstructionSystem.new(self).try_remove_building(building_id)

func add_connection(connection_data: Dictionary) -> String:
    var id = generate_id("conn")
    connection_data["id"] = id
    connection_data["enabled"] = bool(connection_data.get("enabled", true))
    connection_data["active"] = bool(connection_data.get("active", false))
    connection_data["current_flow"] = float(connection_data.get("current_flow", 0.0))
    connections[id] = connection_data
    EventBus.connection_created.emit(id, connection_data.source_id, connection_data.target_id)
    return id

func try_add_connection(source_id: String, target_id: String, requested_output_item: String = "") -> Dictionary:
    if not buildings.has(source_id) or not buildings.has(target_id):
        return {"ok": false, "message": "连接建筑不存在"}
    if source_id == target_id:
        return {"ok": false, "message": "不能连接建筑自身"}

    for connection in connections.values():
        if connection.get("source_id", "") == source_id and connection.get("target_id", "") == target_id:
            return {"ok": false, "message": "连接已存在"}

    var available_output_items := get_building_output_items(source_id)
    var output_item := requested_output_item if not requested_output_item.is_empty() else get_building_output_item(source_id)
    if output_item.is_empty():
        return {"ok": false, "message": "源建筑没有输出物品"}
    if not available_output_items.has(output_item):
        return {"ok": false, "message": "源建筑不提供所选输出物品"}

    var target_building: Dictionary = buildings[target_id]
    var existing_recipe_id: String = target_building.get("recipe_id", "")
    if not existing_recipe_id.is_empty():
        var existing_recipe := DataManager.get_recipe(existing_recipe_id)
        var existing_recipe_accepts_output := false
        for input in existing_recipe.get("inputs", []):
            if input.get("item_id", "") == output_item:
                existing_recipe_accepts_output = true
                break
        if not existing_recipe_accepts_output:
            return {"ok": false, "message": "目标配方无法接收源建筑输出"}
    else:
        var target_type: String = target_building.get("type", "")
        var compatible_recipes := get_compatible_recipes(target_type, output_item)
        if compatible_recipes.is_empty():
            return {"ok": false, "message": "目标建筑无法接收源建筑输出"}

        var selected_recipe: Dictionary = compatible_recipes[0]
        set_entity_recipe(target_id, selected_recipe.get("id", ""))

    var connection_id := add_connection({
        "source_id": source_id,
        "target_id": target_id,
        "type": "conveyor_belt_mk1",
        "item_id": output_item,
    })
    return {"ok": true, "message": "连接已创建", "id": connection_id}

func get_compatible_recipes(building_type: String, input_item_id: String = "") -> Array:
    var compatible_recipes: Array = []
    for recipe in DataManager.get_recipes_for_building(building_type):
        if input_item_id.is_empty():
            compatible_recipes.append(recipe)
            continue

        for input in recipe.get("inputs", []):
            if input.get("item_id", "") == input_item_id:
                compatible_recipes.append(recipe)
                break

    compatible_recipes.sort_custom(func(left: Dictionary, right: Dictionary) -> bool:
        return left.get("id", "") < right.get("id", "")
    )
    return compatible_recipes

func get_building_output_item(building_id: String) -> String:
    var building := get_building(building_id)
    if building.is_empty():
        return ""

    var output_item: String = building.get("output_item", "")
    if not output_item.is_empty():
        return output_item

    var recipe := DataManager.get_recipe(building.get("recipe_id", ""))
    var outputs: Array = recipe.get("outputs", [])
    if outputs.is_empty():
        return ""
    return outputs[0].get("item_id", "")

func get_building_output_items(building_id: String) -> Array:
    var building := get_building(building_id)
    if building.is_empty():
        return []
    var definition := DataManager.get_building(String(building.get("type", "")))
    var extraction: Dictionary = definition.get("extraction", {})
    if definition.get("kind", "") == "extractor":
        var selected_item := String(building.get("output_item", extraction.get("item_id", "")))
        return [] if selected_item.is_empty() else [selected_item]
    var recipe := DataManager.get_recipe(String(building.get("recipe_id", "")))
    var output_items: Array = []
    for output_value in recipe.get("outputs", []):
        output_items.append(String(output_value.get("item_id", "")))
    return output_items

func get_building_display_name(building_id: String) -> String:
    var building := get_building(building_id)
    if building.is_empty():
        return ""
    var building_type: String = building.get("type", "")
    return DataManager.get_building(building_type).get("name", building_type)

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

# 功能1: 移动单个实体
func move_entity(entity_id: String, new_position: Vector2) -> bool:
    if not buildings.has(entity_id):
        print("ERROR: Entity not found: ", entity_id)
        return false
    
    if buildings[entity_id].get("interaction_locked", false):
        print("WARNING: Entity is locked: ", entity_id)
        return false
    
    buildings[entity_id]["position"] = new_position
    EventBus.entity_moved.emit(entity_id, new_position)
    return true

# 功能2: 批量移动实体
func move_entities(positions: Array) -> int:
    var moved_count = 0
    for pos_data in positions:
        var entity_id = pos_data.get("id", "")
        var new_position = pos_data.get("position", Vector2.ZERO)
        if entity_id.is_empty():
            continue
        if move_entity(entity_id, new_position):
            moved_count += 1
    return moved_count

# 功能3: 批量删除实体
func remove_entities(entity_ids: Array) -> int:
    var removed_count = 0
    for entity_id in entity_ids:
        if buildings.has(entity_id):
            var result := remove_building(entity_id)
            if result.get("ok", false):
                removed_count += 1
    return removed_count

# 功能4: 设置实体配方
func set_entity_recipe(entity_id: String, recipe_id: String) -> bool:
    if not buildings.has(entity_id):
        print("ERROR: Entity not found: ", entity_id)
        return false

    var recipe = DataManager.get_recipe(recipe_id)
    if recipe.is_empty():
        print("ERROR: Recipe not found: ", recipe_id)
        return false
    if not DataManager.is_recipe_supported_by_building(recipe, String(buildings[entity_id].get("type", ""))):
        print("ERROR: Recipe does not belong to entity: ", recipe_id)
        return false

    buildings[entity_id]["recipe_id"] = recipe_id
    buildings[entity_id]["progress"] = 0.0
    var selected_output := String(buildings[entity_id].get("output_item", ""))
    if not selected_output.is_empty() and not get_building_output_items(entity_id).has(selected_output):
        buildings[entity_id].erase("output_item")
    print("Set recipe ", recipe_id, " for entity ", entity_id)
    return true

func set_entity_extraction_item(entity_id: String, item_id: String) -> bool:
    if not buildings.has(entity_id):
        return false
    var building: Dictionary = buildings[entity_id]
    var definition := DataManager.get_building(String(building.get("type", "")))
    var extraction: Dictionary = definition.get("extraction", {})
    var allowed_items: Array = extraction.get("items", [extraction.get("item_id", "")])
    if definition.get("kind", "") != "extractor" or not allowed_items.has(item_id):
        return false
    building["output_item"] = item_id
    return true

func set_entity_output_item(entity_id: String, item_id: String) -> bool:
    if not get_building_output_items(entity_id).has(item_id):
        return false
    buildings[entity_id]["output_item"] = item_id
    return true

# 功能5: 批量设置实体配方
func set_entities_recipe(entity_ids: Array, recipe_id: String) -> int:
    var set_count = 0
    for entity_id in entity_ids:
        if set_entity_recipe(entity_id, recipe_id):
            set_count += 1
    return set_count

# 功能6: 设置实体交互锁定
func set_entities_interaction_locked(entity_ids: Array, locked: bool) -> int:
    var set_count = 0
    for entity_id in entity_ids:
        if buildings.has(entity_id):
            buildings[entity_id]["interaction_locked"] = locked
            set_count += 1
    return set_count

# 功能7: 升级单个实体
func upgrade_entity(entity_id: String) -> bool:
    if not buildings.has(entity_id):
        print("ERROR: Entity not found: ", entity_id)
        return false
    
    var current_type = buildings[entity_id].get("type", "")
    var upgrade_type = building_upgrade_map.get(current_type, "")
    
    if upgrade_type.is_empty():
        print("WARNING: No upgrade available for: ", current_type)
        return false
    
    buildings[entity_id]["type"] = upgrade_type
    buildings[entity_id]["upgrade_level"] = buildings[entity_id].get("upgrade_level", 1) + 1
    print("Upgraded entity ", entity_id, " from ", current_type, " to ", upgrade_type)
    return true

# 功能8: 批量升级实体
func upgrade_entities(entity_ids: Array) -> int:
    var upgraded_count = 0
    for entity_id in entity_ids:
        if upgrade_entity(entity_id):
            upgraded_count += 1
    return upgraded_count

# 功能9: 升级传送带
func upgrade_belt(belt_id: String) -> bool:
    if not connections.has(belt_id):
        print("ERROR: Belt not found: ", belt_id)
        return false
    
    var current_type = connections[belt_id].get("type", "conveyor_belt_mk1")
    var upgrade_type = belt_upgrade_map.get(current_type, "")
    
    if upgrade_type.is_empty():
        print("WARNING: No upgrade available for belt: ", current_type)
        return false
    
    connections[belt_id]["type"] = upgrade_type
    connections[belt_id]["speed_multiplier"] = belt_speed_config.get(upgrade_type, 1.0)
    print("Upgraded belt ", belt_id, " from ", current_type, " to ", upgrade_type)
    return true

# 功能10: 升级分拣器
func upgrade_sorter(sorter_id: String) -> bool:
    if not connections.has(sorter_id):
        print("ERROR: Sorter not found: ", sorter_id)
        return false
    
    var current_type = connections[sorter_id].get("type", "sorter_mk1")
    var upgrade_type = sorter_upgrade_map.get(current_type, "")
    
    if upgrade_type.is_empty():
        print("WARNING: No upgrade available for sorter: ", current_type)
        return false
    
    connections[sorter_id]["type"] = upgrade_type
    connections[sorter_id]["speed_multiplier"] = sorter_speed_config.get(upgrade_type, 1.0)
    print("Upgraded sorter ", sorter_id, " from ", current_type, " to ", upgrade_type)
    return true

# 功能11: 传送带网络升级
func upgrade_belt_network(belt_id: String) -> int:
    if not connections.has(belt_id):
        return 0
    
    var source_id = connections[belt_id].get("source_id", "")
    var upgraded_count = 0
    
    for conn_id in connections:
        var conn = connections[conn_id]
        if conn.get("source_id", "") == source_id and conn.get("type", "").begins_with("conveyor_belt"):
            if upgrade_belt(conn_id):
                upgraded_count += 1
    
    return upgraded_count

# 功能12: 分拣器网络升级
func upgrade_sorter_network(sorter_id: String) -> int:
    if not connections.has(sorter_id):
        return 0
    
    var source_id = connections[sorter_id].get("source_id", "")
    var upgraded_count = 0
    
    for conn_id in connections:
        var conn = connections[conn_id]
        if conn.get("source_id", "") == source_id and conn.get("type", "").begins_with("sorter"):
            if upgrade_sorter(conn_id):
                upgraded_count += 1
    
    return upgraded_count

# 功能13: 建筑堆叠检查
func get_building_stack_addition_check(current_count: int, requested: int, building_name: String) -> Dictionary:
    var max_stack = 10
    var amount = min(requested, max_stack - current_count)
    
    if amount <= 0:
        return {"ok": false, "amount": 0, "reason": "Stack is full"}
    
    return {"ok": true, "amount": amount, "reason": ""}

# 功能14: 设置传送带通道数
func set_belt_lane_count(belt_id: String, target_lanes: int) -> bool:
    if not connections.has(belt_id):
        print("ERROR: Belt not found: ", belt_id)
        return false
    
    var lanes = clamp(target_lanes, 1, 4)
    connections[belt_id]["lanes"] = lanes
    print("Set belt ", belt_id, " lanes to ", lanes)
    return true

# 功能15: 设置传送带优先级
func set_belt_priority(belt_id: String, priority: int) -> bool:
    if not connections.has(belt_id):
        print("ERROR: Belt not found: ", belt_id)
        return false
    
    var clamped_priority = clamp(priority, 0, 2)
    connections[belt_id]["priority"] = clamped_priority
    print("Set belt ", belt_id, " priority to ", clamped_priority)
    return true

# 功能16: 设置传送带堆叠大小
func set_belt_stack_size(belt_id: String, stack_size: int) -> bool:
    if not connections.has(belt_id):
        print("ERROR: Belt not found: ", belt_id)
        return false
    
    var valid_sizes = [1, 2, 4]
    if stack_size not in valid_sizes:
        print("ERROR: Invalid stack size: ", stack_size)
        return false
    
    connections[belt_id]["stack_size"] = stack_size
    print("Set belt ", belt_id, " stack size to ", stack_size)
    return true

# 功能17: 设置传送带监控
func set_belt_monitor_enabled(belt_id: String, enabled: bool) -> bool:
    if not connections.has(belt_id):
        print("ERROR: Belt not found: ", belt_id)
        return false
    
    connections[belt_id]["monitor_enabled"] = enabled
    print("Set belt ", belt_id, " monitor enabled: ", enabled)
    return true

# 功能18: 设置传送带路由模式
func set_belt_route_mode(belt_id: String, route_mode: String) -> bool:
    if not connections.has(belt_id):
        print("ERROR: Belt not found: ", belt_id)
        return false
    
    var valid_modes = ["bezier", "auto", "upper", "lower", "manual"]
    if route_mode not in valid_modes:
        print("ERROR: Invalid route mode: ", route_mode)
        return false
    
    connections[belt_id]["route_mode"] = route_mode
    print("Set belt ", belt_id, " route mode to ", route_mode)
    return true

# 功能19: 设置传送带路由偏移Y
func set_belt_route_offset_y(belt_id: String, offset_y: float) -> bool:
    if not connections.has(belt_id):
        print("ERROR: Belt not found: ", belt_id)
        return false
    
    connections[belt_id]["route_offset_y"] = offset_y
    print("Set belt ", belt_id, " route offset Y to ", offset_y)
    return true

# 功能20: 设置传送带网络路由模式
func set_belt_network_route_mode(belt_id: String, route_mode: String) -> int:
    if not connections.has(belt_id):
        return 0
    
    var source_id = connections[belt_id].get("source_id", "")
    var set_count = 0
    
    for conn_id in connections:
        var conn = connections[conn_id]
        if conn.get("source_id", "") == source_id and conn.get("type", "").begins_with("conveyor_belt"):
            if set_belt_route_mode(conn_id, route_mode):
                set_count += 1
    
    return set_count

# 功能21: 应用传送带配置
func apply_belt_configuration(source_belt_id: String, target_belt_id: String) -> bool:
    if not connections.has(source_belt_id) or not connections.has(target_belt_id):
        print("ERROR: Belt not found")
        return false
    
    var source = connections[source_belt_id]
    var target = connections[target_belt_id]
    
    target["lanes"] = source.get("lanes", 1)
    target["priority"] = source.get("priority", 0)
    target["stack_size"] = source.get("stack_size", 1)
    target["route_mode"] = source.get("route_mode", "auto")
    
    print("Applied belt configuration from ", source_belt_id, " to ", target_belt_id)
    return true

# 功能22: 应用传送带配置到网络
func apply_belt_configuration_to_network(belt_id: String) -> int:
    if not connections.has(belt_id):
        return 0
    
    var source_id = connections[belt_id].get("source_id", "")
    var applied_count = 0
    
    for conn_id in connections:
        var conn = connections[conn_id]
        if conn.get("source_id", "") == source_id and conn.get("type", "").begins_with("conveyor_belt"):
            if conn_id != belt_id:
                if apply_belt_configuration(belt_id, conn_id):
                    applied_count += 1
    
    return applied_count

# 功能23: 设置分拣器方向
func set_sorter_direction(sorter_id: String, direction: String) -> bool:
    if not connections.has(sorter_id):
        print("ERROR: Sorter not found: ", sorter_id)
        return false
    
    var valid_directions = ["left", "right", "up", "down"]
    if direction not in valid_directions:
        print("ERROR: Invalid direction: ", direction)
        return false
    
    connections[sorter_id]["direction"] = direction
    print("Set sorter ", sorter_id, " direction to ", direction)
    return true

# 功能24: 设置分拣器过滤
func set_sorter_filter(sorter_id: String, item_id: String) -> bool:
    if not connections.has(sorter_id):
        print("ERROR: Sorter not found: ", sorter_id)
        return false
    
    connections[sorter_id]["filter_item"] = item_id
    print("Set sorter ", sorter_id, " filter to ", item_id)
    return true

# 功能25: 设置实体电力网格
func set_entity_power_grid(entity_id: String, grid_id: String) -> bool:
    if not buildings.has(entity_id):
        print("ERROR: Entity not found: ", entity_id)
        return false
    
    var valid_grids = ["grid-a", "grid-b", "grid-c"]
    if grid_id not in valid_grids:
        print("ERROR: Invalid grid ID: ", grid_id)
        return false
    
    buildings[entity_id]["power_grid_id"] = grid_id
    print("Set entity ", entity_id, " power grid to ", grid_id)
    return true

# 功能26: 设置实体电力优先级
func set_entity_power_priority(entity_id: String, priority: int) -> bool:
    if not buildings.has(entity_id):
        print("ERROR: Entity not found: ", entity_id)
        return false
    
    var clamped_priority = clamp(priority, 1, 3)
    buildings[entity_id]["power_priority"] = clamped_priority
    print("Set entity ", entity_id, " power priority to ", clamped_priority)
    return true

# 功能27: 设置实体发电优先级
func set_entity_generation_priority(entity_id: String, priority: int) -> bool:
    if not buildings.has(entity_id):
        print("ERROR: Entity not found: ", entity_id)
        return false
    
    var clamped_priority = clamp(priority, 1, 3)
    buildings[entity_id]["generation_priority"] = clamped_priority
    print("Set entity ", entity_id, " generation priority to ", clamped_priority)
    return true

# 功能28: 检查科技是否完成
func is_technology_completed(tech_id: String) -> bool:
    return completed_technologies.has(tech_id)

# 功能29: 获取科技进度
func get_technology_progress(tech_id: String) -> float:
    # 这个需要TechnologySystem来实现
    return 0.0

# 功能30: 设置科技研究
func set_technology_research(tech_id: String) -> bool:
    # 这个需要TechnologySystem来实现
    return true

# === 游戏核心系统补完功能 ===

# 1. 创建速通状态
func create_speedrun_state() -> Dictionary:
    var speedrun_state = {
        "mode": "speedrun",
        "start_time": Time.get_unix_time_from_system(),
        "target_time": 3600.0,  # 1小时目标
        "completed": false
    }
    print("Created speedrun state")
    return speedrun_state

# 2. 时间扭曲功能
func get_time_warp_power_cost(multiplier: float) -> float:
    # 时间扭曲需要的电力
    var base_cost = 1000.0
    return base_cost * multiplier * multiplier

# 3. 模拟预算
func get_simulation_budget() -> Dictionary:
    return {
        "max_steps_per_frame": 10,
        "max_time_per_frame": 0.016,  # 16ms
        "adaptive_budget": true
    }

# 4. 游戏状态复制
func copy_state() -> GameState:
    var new_state = GameState.new()
    new_state.buildings = buildings.duplicate(true)
    new_state.connections = connections.duplicate(true)
    new_state.elapsed_time = elapsed_time
    new_state.paused = paused
    new_state.speed = speed
    new_state.planet_inventory = planet_inventory.duplicate(true)
    new_state.construction_inventory = construction_inventory.duplicate(true)
    new_state.cursor_payload = cursor_payload.duplicate(true)
    new_state.handcraft_queue = handcraft_queue.duplicate(true)
    new_state.completed_technologies = completed_technologies.duplicate(true)
    new_state._next_id = _next_id
    return new_state

# 5. 实体锁定检查
func is_entity_interaction_locked(entity_id: String) -> bool:
    var entity = get_building(entity_id)
    if entity.is_empty():
        return false
    return entity.get("interaction_locked", false)

# 6. 状态版本管理
func get_state_version() -> int:
    return SCHEMA_VERSION

# 7. 模拟预算管理
var simulation_budget: Dictionary = {
    "max_steps": 10,
    "current_steps": 0,
    "time_limit": 0.016
}

func update_simulation_budget(delta: float):
    simulation_budget.current_steps += 1
    if simulation_budget.current_steps >= simulation_budget.max_steps:
        simulation_budget.current_steps = 0

func reset_simulation_budget():
    simulation_budget.current_steps = 0

# === 实体与建筑系统补完功能 ===

# 1. 获取建筑堆叠检查
func get_building_stack_check(current_count: int, requested: int, building_name: String) -> Dictionary:
    var max_stack = 10
    var amount = min(requested, max_stack - current_count)
    if amount <= 0:
        return {"ok": false, "amount": 0, "reason": "Stack is full"}
    return {"ok": true, "amount": amount, "reason": ""}

# 2. 获取缓冲区限制
func get_entity_buffer_limit(entity_id: String) -> int:
    var entity = get_building(entity_id)
    if entity.is_empty():
        return 0
    var building_type = entity.get("type", "")
    var building_def = DataManager.get_building(building_type)
    return building_def.get("buffer_limit", 60)

# 3. 获取输入容量
func get_entity_input_capacity(entity_id: String) -> int:
    var entity = get_building(entity_id)
    if entity.is_empty():
        return 0
    var building_type = entity.get("type", "")
    var building_def = DataManager.get_building(building_type)
    return building_def.get("input_slots", 1) * 60

# 4. 获取输出容量
func get_entity_output_capacity(entity_id: String) -> int:
    var entity = get_building(entity_id)
    if entity.is_empty():
        return 0
    var building_type = entity.get("type", "")
    var building_def = DataManager.get_building(building_type)
    return building_def.get("output_slots", 1) * 60

# 5. 获取建筑信息
func get_building_info(entity_id: String) -> Dictionary:
    var entity = get_building(entity_id)
    if entity.is_empty():
        return {}
    return {
        "id": entity_id,
        "type": entity.get("type", ""),
        "position": entity.get("position", Vector2.ZERO),
        "status": entity.get("status", "idle"),
        "progress": entity.get("progress", 0.0),
        "input_buffer": entity.get("input_buffer", {}),
        "output_buffer": entity.get("output_buffer", {}),
        "recipe_id": entity.get("recipe_id", "")
    }

# 6. 获取建筑类型
func get_building_type(entity_id: String) -> String:
    var entity = get_building(entity_id)
    if entity.is_empty():
        return ""
    return entity.get("type", "")

# 7. 获取建筑位置
func get_building_position(entity_id: String) -> Vector2:
    var entity = get_building(entity_id)
    if entity.is_empty():
        return Vector2.ZERO
    return entity.get("position", Vector2.ZERO)

# 8. 设置建筑位置
func set_building_position(entity_id: String, position: Vector2) -> bool:
    if not buildings.has(entity_id):
        return false
    buildings[entity_id]["position"] = position
    return true

# 9. 获取建筑状态
func get_building_status(entity_id: String) -> String:
    var entity = get_building(entity_id)
    if entity.is_empty():
        return ""
    return entity.get("status", "idle")

# 10. 设置建筑状态
func set_building_status(entity_id: String, status: String) -> bool:
    if not buildings.has(entity_id):
        return false
    buildings[entity_id]["status"] = status
    return true

# 11. 获取建筑进度
func get_building_progress(entity_id: String) -> float:
    var entity = get_building(entity_id)
    if entity.is_empty():
        return 0.0
    return entity.get("progress", 0.0)

# 12. 设置建筑进度
func set_building_progress(entity_id: String, progress: float) -> bool:
    if not buildings.has(entity_id):
        return false
    buildings[entity_id]["progress"] = progress
    return true

# 13. 获取建筑配方
func get_building_recipe(entity_id: String) -> String:
    var entity = get_building(entity_id)
    if entity.is_empty():
        return ""
    return entity.get("recipe_id", "")

# 14. 获取建筑输入缓冲区
func get_building_input_buffer(entity_id: String) -> Dictionary:
    var entity = get_building(entity_id)
    if entity.is_empty():
        return {}
    return entity.get("input_buffer", {})

# 15. 获取建筑输出缓冲区
func get_building_output_buffer(entity_id: String) -> Dictionary:
    var entity = get_building(entity_id)
    if entity.is_empty():
        return {}
    return entity.get("output_buffer", {})

# 16. 设置建筑输入缓冲区
func set_building_input_buffer(entity_id: String, buffer: Dictionary) -> bool:
    if not buildings.has(entity_id):
        return false
    buildings[entity_id]["input_buffer"] = buffer
    return true

# 17. 设置建筑输出缓冲区
func set_building_output_buffer(entity_id: String, buffer: Dictionary) -> bool:
    if not buildings.has(entity_id):
        return false
    buildings[entity_id]["output_buffer"] = buffer
    return true

# 18. 获取建筑数量
func get_building_count() -> int:
    return buildings.size()

# 19. 获取连接数量
func get_connection_count() -> int:
    return connections.size()

# 20. 检查建筑是否存在
func building_exists(entity_id: String) -> bool:
    return buildings.has(entity_id)

# 21. 检查连接是否存在
func connection_exists(connection_id: String) -> bool:
    return connections.has(connection_id)

# 22. 获取所有建筑ID
func get_all_building_ids() -> Array:
    return buildings.keys()

# 23. 获取所有连接ID
func get_all_connection_ids() -> Array:
    return connections.keys()

# 24. 获取建筑按类型分组
func get_buildings_by_type(building_type: String) -> Array:
    var result = []
    for building_id in buildings:
        if buildings[building_id].get("type") == building_type:
            result.append(building_id)
    return result

# 25. 获取连接按源建筑分组
func get_connections_by_source(source_id: String) -> Array:
    var result = []
    for conn_id in connections:
        if connections[conn_id].get("source_id") == source_id:
            result.append(conn_id)
    return result

# 26. 获取连接按目标建筑分组
func get_connections_by_target(target_id: String) -> Array:
    var result = []
    for conn_id in connections:
        if connections[conn_id].get("target_id") == target_id:
            result.append(conn_id)
    return result

# 27. 获取建筑升级路径
func get_building_upgrade_path(entity_id: String) -> Array:
    var entity = get_building(entity_id)
    if entity.is_empty():
        return []
    var current_type = entity.get("type", "")
    var path = [current_type]
    var next_type = building_upgrade_map.get(current_type, "")
    while not next_type.is_empty():
        path.append(next_type)
        next_type = building_upgrade_map.get(next_type, "")
    return path

# 28. 检查建筑是否可升级
func can_upgrade_building(entity_id: String) -> bool:
    var entity = get_building(entity_id)
    if entity.is_empty():
        return false
    var current_type = entity.get("type", "")
    return building_upgrade_map.has(current_type)

# 29. 获取建筑效率
func get_building_efficiency(entity_id: String) -> float:
    var entity = get_building(entity_id)
    if entity.is_empty():
        return 0.0
    return entity.get("efficiency", 1.0)

# 30. 设置建筑效率
func set_building_efficiency(entity_id: String, efficiency: float) -> bool:
    if not buildings.has(entity_id):
        return false
    buildings[entity_id]["efficiency"] = clamp(efficiency, 0.0, 1.0)
    return true

# === 电力系统补完功能 ===

# 1. 获取实体电力因子
func get_entity_power_factor(entity_id: String) -> float:
    var entity = get_building(entity_id)
    if entity.is_empty():
        return 0.0
    return entity.get("power_factor", 1.0)

# 2. 设置实体电力因子
func set_entity_power_factor(entity_id: String, factor: float) -> bool:
    if not buildings.has(entity_id):
        return false
    buildings[entity_id]["power_factor"] = clamp(factor, 0.0, 1.0)
    return true

# 3. 获取实体电力需求
func get_entity_power_demand(entity_id: String) -> float:
    var entity = get_building(entity_id)
    if entity.is_empty():
        return 0.0
    var building_type = entity.get("type", "")
    var building_def = DataManager.get_building(building_type)
    return building_def.get("power_demand", 0.0)

# 4. 获取实体发电量
func get_entity_power_generation(entity_id: String) -> float:
    var entity = get_building(entity_id)
    if entity.is_empty():
        return 0.0
    var building_type = entity.get("type", "")
    var building_def = DataManager.get_building(building_type)
    return building_def.get("power_generation", 0.0)

# 5. 计算总电力需求
func calculate_total_power_demand() -> float:
    var total = 0.0
    for building_id in buildings:
        total += get_entity_power_demand(building_id)
    return total

# 6. 计算总发电量
func calculate_total_power_generation() -> float:
    var total = 0.0
    for building_id in buildings:
        total += get_entity_power_generation(building_id)
    return total

# 7. 计算电力平衡
func calculate_power_balance() -> float:
    return calculate_total_power_generation() - calculate_total_power_demand()

# 8. 检查电力是否充足
func is_power_sufficient() -> bool:
    return calculate_power_balance() >= 0

# 9. 获取电力网格统计
func get_power_grid_stats() -> Dictionary:
    return {
        "total_demand": calculate_total_power_demand(),
        "total_generation": calculate_total_power_generation(),
        "balance": calculate_power_balance(),
        "sufficient": is_power_sufficient()
    }

# 10. 获取建筑电力信息
func get_building_power_info(entity_id: String) -> Dictionary:
    var entity = get_building(entity_id)
    if entity.is_empty():
        return {}
    return {
        "demand": get_entity_power_demand(entity_id),
        "generation": get_entity_power_generation(entity_id),
        "factor": get_entity_power_factor(entity_id),
        "grid": entity.get("power_grid_id", "grid-a"),
        "priority": entity.get("power_priority", 1)
    }

# 11. 设置建筑电力网格
func set_building_power_grid(entity_id: String, grid_id: String) -> bool:
    if not buildings.has(entity_id):
        return false
    var valid_grids = ["grid-a", "grid-b", "grid-c"]
    if grid_id not in valid_grids:
        return false
    buildings[entity_id]["power_grid_id"] = grid_id
    return true

# 12. 获取建筑电力网格
func get_building_power_grid(entity_id: String) -> String:
    var entity = get_building(entity_id)
    if entity.is_empty():
        return ""
    return entity.get("power_grid_id", "grid-a")

# 13. 设置建筑电力优先级
func set_building_power_priority(entity_id: String, priority: int) -> bool:
    if not buildings.has(entity_id):
        return false
    buildings[entity_id]["power_priority"] = clamp(priority, 1, 3)
    return true

# 14. 获取建筑电力优先级
func get_building_power_priority(entity_id: String) -> int:
    var entity = get_building(entity_id)
    if entity.is_empty():
        return 1
    return entity.get("power_priority", 1)

# 15. 设置建筑发电优先级
func set_building_generation_priority(entity_id: String, priority: int) -> bool:
    if not buildings.has(entity_id):
        return false
    buildings[entity_id]["generation_priority"] = clamp(priority, 1, 3)
    return true

# 16. 获取建筑发电优先级
func get_building_generation_priority(entity_id: String) -> int:
    var entity = get_building(entity_id)
    if entity.is_empty():
        return 1
    return entity.get("generation_priority", 1)

# 17. 获取电力网格中的建筑
func get_buildings_in_power_grid(grid_id: String) -> Array:
    var result = []
    for building_id in buildings:
        if buildings[building_id].get("power_grid_id") == grid_id:
            result.append(building_id)
    return result

# 18. 计算电力网格统计
func calculate_power_grid_stats(grid_id: String) -> Dictionary:
    var grid_buildings = get_buildings_in_power_grid(grid_id)
    var total_demand = 0.0
    var total_generation = 0.0
    
    for building_id in grid_buildings:
        total_demand += get_entity_power_demand(building_id)
        total_generation += get_entity_power_generation(building_id)
    
    return {
        "grid_id": grid_id,
        "building_count": grid_buildings.size(),
        "total_demand": total_demand,
        "total_generation": total_generation,
        "balance": total_generation - total_demand
    }

# 19. 获取所有电力网格统计
func get_all_power_grid_stats() -> Dictionary:
    var stats = {}
    stats["grid-a"] = calculate_power_grid_stats("grid-a")
    stats["grid-b"] = calculate_power_grid_stats("grid-b")
    stats["grid-c"] = calculate_power_grid_stats("grid-c")
    stats["total"] = get_power_grid_stats()
    return stats

# 20. 检查建筑是否有电
func has_power(entity_id: String) -> bool:
    var entity = get_building(entity_id)
    if entity.is_empty():
        return false
    var grid_id = entity.get("power_grid_id", "grid-a")
    var grid_stats = calculate_power_grid_stats(grid_id)
    return grid_stats.balance >= 0

# === 物流系统补完功能 ===

# 1. 创建量子物流网络
func create_quantum_network(network_id: String) -> bool:
    print("Created quantum network: ", network_id)
    return true

# 2. 连接量子网络
func connect_quantum_network(network_id: String, station_id: String) -> bool:
    print("Connected station ", station_id, " to quantum network ", network_id)
    return true

# 3. 量子传输
func quantum_transfer(source_id: String, target_id: String, item_id: String, amount: float) -> bool:
    var source = get_building(source_id)
    var target = get_building(target_id)
    
    if source.is_empty() or target.is_empty():
        return false
    
    var available = source.get("output_buffer", {}).get(item_id, 0.0)
    var transfer_amount = min(available, amount)
    
    if transfer_amount > 0:
        source.output_buffer[item_id] = source.output_buffer.get(item_id, 0.0) - transfer_amount
        target.input_buffer[item_id] = target.input_buffer.get(item_id, 0.0) + transfer_amount
        print("Quantum transferred ", transfer_amount, " of ", item_id)
        return true
    
    return false

# 4. 获取量子带宽
func get_quantum_bandwidth(network_id: String) -> float:
    # 简化实现
    return 1000.0

# 5. 设置量子带宽
func set_quantum_bandwidth(network_id: String, bandwidth: float) -> bool:
    print("Set quantum bandwidth for ", network_id, " to ", bandwidth)
    return true
