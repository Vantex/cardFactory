# scripts/game/GameState.gd
class_name GameState
extends RefCounted

const SCHEMA_VERSION: int = 5

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
    "conveyor_belt_mk1": 8.0,
    "conveyor_belt_mk2": 4.0,
    "conveyor_belt_mk3": 2.0,
}
var cursor_payload: Dictionary = {"item_id": "", "amount": 0.0}
var handcraft_queue: Array = []

# 所有建筑（卡牌）
var buildings: Dictionary = {}
var _spatial_index := SpatialIndex.new()

# 所有连接
var connections: Dictionary = {}

# 科技系统
var completed_technologies: Array = []
var research_current_id := ""
var research_queue: Array = []
var research_progress: Dictionary = {}
var research_invested_costs: Dictionary = {}
var research_paused := false
var research_queue_wait_reason := ""
var technology_levels: Dictionary = {}

# 本地单人进度；事实本身仍由建筑、库存和科技等权威状态提供。
var completed_objective_ids: Array = []
var claimed_progression_reward_ids: Array = []
var completed_achievement_ids: Array = []
var unlocked_progression_ids: Array = []

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

const BELT_RATED_THROUGHPUT := {
    "conveyor_belt_mk1": 10.0,
    "conveyor_belt_mk2": 20.0,
    "conveyor_belt_mk3": 30.0,
}
const BELT_STACK_SIZES := [1, 2, 4]
const BELT_PRIORITIES := [0, 1, 2]
const BELT_ROUTE_MODES := ["bezier", "auto", "upper", "lower", "manual"]
const BELT_MAX_INVENTORY := 99.0
const BELT_LEGACY_INVENTORY_DEFAULTS := {
    "conveyor_belt_mk1": 1.0,
    "conveyor_belt_mk2": 0.0,
    "conveyor_belt_mk3": 0.0,
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

func capture_blueprint(selected_entity_ids: Array) -> Dictionary:
    return BlueprintSystem.new(self).capture_selection(selected_entity_ids)

func try_deploy_blueprint(blueprint: Dictionary, position: Vector2, rotation_quarters: int = 0, mirrored: bool = false) -> Dictionary:
    return BlueprintSystem.new(self).deploy(blueprint, position, rotation_quarters, mirrored)

func remove_building(building_id: String) -> Dictionary:
    return ConstructionSystem.new(self).try_remove_building(building_id)

# Low-level fixture/import record insertion with no inventory settlement. Gameplay must use try_add_connection.
func add_connection(connection_data: Dictionary) -> String:
    var id = generate_id("conn")
    connection_data["id"] = id
    connection_data["construction_accounted"] = bool(connection_data.get("construction_accounted", false))
    connection_data["enabled"] = bool(connection_data.get("enabled", true))
    connection_data["active"] = bool(connection_data.get("active", false))
    connection_data["current_flow"] = float(connection_data.get("current_flow", 0.0))
    _normalize_belt_connection(connection_data)
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
        if not _has_belt_pieces("conveyor_belt_mk1", 1):
            return {"ok": false, "message": "缺少 Mk.I 线路施工件"}
        set_entity_recipe(target_id, selected_recipe.get("id", ""))

    if not _has_belt_pieces("conveyor_belt_mk1", 1):
        return {"ok": false, "message": "缺少 Mk.I 线路施工件"}
    _consume_belt_pieces("conveyor_belt_mk1", 1)

    var connection_id := add_connection({
        "source_id": source_id,
        "target_id": target_id,
        "type": "conveyor_belt_mk1",
        "item_id": output_item,
        "construction_accounted": true,
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

func try_remove_connection(connection_id: String) -> Dictionary:
    if not connections.has(connection_id):
        return {"ok": false, "message": "线路不存在", "reason": "connection_not_found"}
    var connection: Dictionary = connections[connection_id]
    var tier := ""
    var installed := 0
    if _is_belt_connection(connection) and _connection_construction_is_accounted(connection):
        tier = _belt_tier(connection)
        installed = _belt_parallel_count(connection)
        if _construction_inventory_count(construction_inventory, tier) + float(installed) > BELT_MAX_INVENTORY:
            return {"ok": false, "message": "线路施工库存容量不足", "reason": "construction_inventory_full"}
    if not tier.is_empty():
        construction_inventory[tier] = _construction_inventory_count(construction_inventory, tier) + float(installed)
    connections.erase(connection_id)
    EventBus.connection_removed.emit(connection_id)
    return {"ok": true, "message": "线路已拆除", "reason": ""}

func remove_connection(connection_id: String) -> bool:
    return try_remove_connection(connection_id).get("ok", false)

func get_building(building_id: String) -> Dictionary:
    return buildings.get(building_id, {})

func get_spatial_index() -> SpatialIndex:
    _spatial_index.clear()
    for building_id in buildings:
        _spatial_index.add_entity(String(building_id), buildings[building_id].get("position", Vector2.ZERO))
    return _spatial_index

func get_connections_for_building(building_id: String) -> Array:
    var result = []
    for conn_id in connections:
        var conn = connections[conn_id]
        if conn.source_id == building_id or conn.target_id == building_id:
            result.append(conn)
    return result

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

func try_move_entities(positions: Array) -> Dictionary:
    var normalized: Array[Dictionary] = []
    var seen: Dictionary = {}
    for value in positions:
        if not value is Dictionary:
            return _batch_failure("移动参数无效", "invalid_position")
        var entity_id := String(value.get("id", ""))
        var new_position: Variant = value.get("position")
        if entity_id.is_empty() or seen.has(entity_id) or not buildings.has(entity_id):
            return _batch_failure("移动建筑不存在或重复", "invalid_entity")
        if not new_position is Vector2:
            return _batch_failure("移动位置无效", "invalid_position")
        if bool(buildings[entity_id].get("interaction_locked", false)):
            return _batch_failure("锁定建筑不可移动", "locked")
        seen[entity_id] = true
        normalized.append({"id": entity_id, "position": new_position})
    for value in normalized:
        buildings[value.id]["position"] = value.position
    for value in normalized:
        EventBus.entity_moved.emit(value.id, value.position)
    return {"ok": true, "message": "已移动 %d 个建筑" % normalized.size(), "success": normalized.size(), "skipped": 0, "failed": 0, "results": normalized.duplicate(true)}

func move_entities(positions: Array) -> int:
    var result := try_move_entities(positions)
    return int(result.get("success", 0)) if result.get("ok", false) else 0

func try_remove_entities(entity_ids: Array) -> Dictionary:
    var normalized: Array[String] = []
    var seen: Dictionary = {}
    var construction_refund: Dictionary = {}
    var material_refund: Dictionary = {}
    var connection_ids: Dictionary = {}
    for id_value in entity_ids:
        var entity_id := String(id_value)
        if entity_id.is_empty() or seen.has(entity_id) or not buildings.has(entity_id):
            return _batch_failure("删除建筑不存在或重复", "invalid_entity")
        seen[entity_id] = true
        normalized.append(entity_id)
        var building: Dictionary = buildings[entity_id]
        var building_type := String(building.get("type", ""))
        if not ConstructionSystem.LEGACY_COSTS.has(building_type):
            return _batch_failure("建筑没有可返还的施工件", "invalid_construction_item")
        construction_refund[building_type] = float(construction_refund.get(building_type, 0.0)) + 1.0
        _collect_building_material_refund(building, material_refund)
        for connection_id in connections:
            var connection: Dictionary = connections[connection_id]
            if connection.get("source_id", "") == entity_id or connection.get("target_id", "") == entity_id:
                connection_ids[connection_id] = true
    for connection_id in connection_ids:
        var connection: Dictionary = connections[connection_id]
        if _is_belt_connection(connection) and _connection_construction_is_accounted(connection):
            var tier := _belt_tier(connection)
            construction_refund[tier] = float(construction_refund.get(tier, 0.0)) + float(_belt_parallel_count(connection))
    for item_id in construction_refund:
        if _construction_inventory_count(construction_inventory, String(item_id)) + float(construction_refund[item_id]) > BELT_MAX_INVENTORY:
            return _batch_failure("施工库存容量不足", "construction_inventory_full")
    var inventory := InventorySystem.new(self)
    if not material_refund.is_empty() and not inventory.can_add_batch(material_refund):
        return _batch_failure("行星托盘容量不足，无法安全拆除", "planet_inventory_full")

    if not material_refund.is_empty():
        var inventory_result := inventory.try_add_batch(material_refund)
        if not inventory_result.get("ok", false):
            return _batch_failure(String(inventory_result.get("message", "返还缓存失败")), "commit_failed")
    for item_id in construction_refund:
        construction_inventory[item_id] = _construction_inventory_count(construction_inventory, String(item_id)) + float(construction_refund[item_id])
    var removed_connection_ids: Array = connection_ids.keys()
    removed_connection_ids.sort()
    for connection_id in removed_connection_ids:
        connections.erase(connection_id)
    for entity_id in normalized:
        buildings.erase(entity_id)
    for connection_id in removed_connection_ids:
        EventBus.connection_removed.emit(String(connection_id))
    for entity_id in normalized:
        EventBus.card_removed.emit(entity_id)
    return {"ok": true, "message": "已拆除 %d 个建筑" % normalized.size(), "success": normalized.size(), "skipped": 0, "failed": 0, "results": normalized.duplicate()}

func remove_entities(entity_ids: Array) -> int:
    var result := try_remove_entities(entity_ids)
    return int(result.get("success", 0)) if result.get("ok", false) else 0

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

func upgrade_belt(belt_id: String) -> bool:
    var current := get_belt_configuration(belt_id)
    if current.is_empty():
        return false
    var upgrade_type := String(belt_upgrade_map.get(current.tier, ""))
    if upgrade_type.is_empty():
        return false
    return try_configure_belt(belt_id, {"tier": upgrade_type}).get("ok", false)

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

func upgrade_belt_network(template_belt_id: String) -> Dictionary:
    var template := get_belt_configuration(template_belt_id)
    if template.is_empty():
        return _network_failure(template_belt_id, "template_not_found")
    var results: Array[Dictionary] = []
    for belt_id in _get_connected_belt_ids(template_belt_id):
        var current := get_belt_configuration(belt_id)
        var target_tier := String(belt_upgrade_map.get(current.tier, ""))
        if target_tier.is_empty():
            results.append(_network_item_result(belt_id, "skipped", "max_tier"))
            continue
        var result := try_configure_belt(belt_id, {"tier": target_tier})
        results.append(_network_item_result(belt_id, "success" if result.get("ok", false) else "failed", String(result.get("reason", result.get("message", "")))))
    return _summarize_network_results(template_belt_id, results)

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

func set_belt_lane_count(belt_id: String, target_lanes: int) -> bool:
    return try_configure_belt(belt_id, {"parallel_count": target_lanes}).get("ok", false)

# 功能15: 设置传送带优先级
func set_belt_priority(belt_id: String, priority: int) -> bool:
    return try_configure_belt(belt_id, {"priority": priority}).get("ok", false)

# 功能16: 设置传送带堆叠大小
func set_belt_stack_size(belt_id: String, stack_size: int) -> bool:
    return try_configure_belt(belt_id, {"stack_size": stack_size}).get("ok", false)

# 功能17: 设置传送带监控
func set_belt_monitor_enabled(belt_id: String, enabled: bool) -> bool:
    return try_configure_belt(belt_id, {"monitor_enabled": enabled}).get("ok", false)

# 功能18: 设置传送带路由模式
func set_belt_route_mode(belt_id: String, route_mode: String) -> bool:
    return try_configure_belt(belt_id, {"route_mode": route_mode}).get("ok", false)

# 功能19: 设置传送带路由偏移Y
func set_belt_route_offset_y(belt_id: String, offset_y: float) -> bool:
    return try_configure_belt(belt_id, {"route_offset_y": offset_y}).get("ok", false)

# 功能20: 设置传送带网络路由模式
func set_belt_network_route_mode(template_belt_id: String, route_mode: String) -> Dictionary:
    if get_belt_configuration(template_belt_id).is_empty():
        return _network_failure(template_belt_id, "template_not_found")
    var results: Array[Dictionary] = []
    for belt_id in _get_connected_belt_ids(template_belt_id):
        var result := try_configure_belt(belt_id, {"route_mode": route_mode})
        results.append(_network_item_result(belt_id, "success" if result.get("ok", false) else "failed", String(result.get("reason", result.get("message", "")))))
    return _summarize_network_results(template_belt_id, results)

# 功能21: 应用传送带配置
func apply_belt_configuration(source_belt_id: String, target_belt_id: String) -> bool:
    var source := get_belt_configuration(source_belt_id)
    if source.is_empty():
        return false
    return try_configure_belt(target_belt_id, _persistent_belt_settings(source)).get("ok", false)

# 功能22: 应用传送带配置到网络
func apply_belt_configuration_to_network(template_belt_id: String) -> Dictionary:
    var template := get_belt_configuration(template_belt_id)
    if template.is_empty():
        return _network_failure(template_belt_id, "template_not_found")
    var settings := _persistent_belt_settings(template)
    var results: Array[Dictionary] = []
    for belt_id in _get_connected_belt_ids(template_belt_id):
        if belt_id == template_belt_id:
            results.append(_network_item_result(belt_id, "skipped", "template"))
            continue
        var current := get_belt_configuration(belt_id)
        if _persistent_belt_settings(current) == settings:
            results.append(_network_item_result(belt_id, "skipped", "already_matches"))
            continue
        var result := try_configure_belt(belt_id, settings)
        results.append(_network_item_result(belt_id, "success" if result.get("ok", false) else "failed", String(result.get("reason", result.get("message", "")))))
    return _summarize_network_results(template_belt_id, results)

func get_belt_configuration(belt_id: String) -> Dictionary:
    if not connections.has(belt_id):
        return {}
    var connection: Dictionary = connections[belt_id]
    if not _is_belt_connection(connection):
        return {}
    var tier := _belt_tier(connection)
    var parallel_count := _belt_parallel_count(connection)
    var stack_size := _belt_stack_size(connection)
    var rated_throughput := float(BELT_RATED_THROUGHPUT.get(tier, 10.0))
    return {
        "tier": tier,
        "rated_throughput": rated_throughput,
        "parallel_count": parallel_count,
        "stack_size": stack_size,
        "effective_throughput": rated_throughput * float(parallel_count) * float(stack_size),
        "priority": _belt_priority(connection),
        "route_mode": _belt_route_mode(connection),
        "route_offset_y": _belt_route_offset_y(connection),
        "monitor_enabled": bool(connection.get("monitor_enabled", false)),
        "enabled": bool(connection.get("enabled", true)),
    }

func try_configure_belt(belt_id: String, requested: Dictionary, emit_change: bool = true) -> Dictionary:
    var current := get_belt_configuration(belt_id)
    if current.is_empty():
        return {"ok": false, "message": "线路不存在", "reason": "belt_not_found"}
    var target := current.duplicate(true)
    for key in ["tier", "parallel_count", "stack_size", "priority", "route_mode", "route_offset_y", "monitor_enabled", "enabled"]:
        if requested.has(key):
            target[key] = requested[key]
    if not target.tier is String or not BELT_RATED_THROUGHPUT.has(String(target.tier)):
        return {"ok": false, "message": "线路等级无效", "reason": "invalid_tier"}
    if not _is_integral_value(target.parallel_count) or int(target.parallel_count) < 1 or int(target.parallel_count) > 4:
        return {"ok": false, "message": "并联数必须为 1..4", "reason": "invalid_parallel_count"}
    if not _is_integral_value(target.stack_size) or int(target.stack_size) not in BELT_STACK_SIZES:
        return {"ok": false, "message": "堆叠只支持 1/2/4", "reason": "invalid_stack_size"}
    if not _is_integral_value(target.priority) or int(target.priority) not in BELT_PRIORITIES:
        return {"ok": false, "message": "优先级无效", "reason": "invalid_priority"}
    if not target.route_mode is String or String(target.route_mode) not in BELT_ROUTE_MODES:
        return {"ok": false, "message": "线路路由模式无效", "reason": "invalid_route_mode"}
    if not _is_finite_number(target.route_offset_y):
        return {"ok": false, "message": "线路路由偏移无效", "reason": "invalid_route_offset_y"}
    if not target.monitor_enabled is bool or not target.enabled is bool:
        return {"ok": false, "message": "线路开关值无效", "reason": "invalid_toggle"}
    var current_tier := String(current.tier)
    var target_tier := String(target.tier)
    var current_count := int(current.parallel_count)
    var target_count := int(target.parallel_count)
    var next_inventory := construction_inventory.duplicate(true)
    if _connection_construction_is_accounted(connections[belt_id]) and (current_tier != target_tier or current_count != target_count):
        next_inventory[current_tier] = _construction_inventory_count(next_inventory, current_tier) + float(current_count)
        if _construction_inventory_count(next_inventory, target_tier) < float(target_count):
            return {"ok": false, "message": "线路施工件不足", "reason": "insufficient_construction_inventory"}
        next_inventory[target_tier] = _construction_inventory_count(next_inventory, target_tier) - float(target_count)
        if float(next_inventory[current_tier]) > BELT_MAX_INVENTORY:
            return {"ok": false, "message": "线路施工库存容量不足", "reason": "construction_inventory_full"}
    var connection: Dictionary = connections[belt_id]
    construction_inventory = next_inventory
    connection["type"] = target_tier
    connection["parallel_count"] = target_count
    connection.erase("lanes")
    connection["stack_size"] = int(target.stack_size)
    connection["priority"] = int(target.priority)
    connection["route_mode"] = String(target.route_mode)
    connection["route_offset_y"] = float(target.route_offset_y)
    connection["monitor_enabled"] = bool(target.monitor_enabled)
    connection["enabled"] = bool(target.enabled)
    connection["speed_multiplier"] = belt_speed_config.get(target_tier, 1.0)
    var configuration := get_belt_configuration(belt_id)
    if emit_change:
        EventBus.connection_configuration_changed.emit(belt_id, configuration.duplicate(true))
    return {"ok": true, "message": "线路配置已更新", "reason": "", "configuration": configuration}

func try_configure_belts(belt_ids: Array, requested: Dictionary) -> Dictionary:
    var normalized: Array[String] = []
    var seen: Dictionary = {}
    for id_value in belt_ids:
        var belt_id := String(id_value)
        if belt_id.is_empty() or seen.has(belt_id) or get_belt_configuration(belt_id).is_empty():
            return _batch_failure("批量线路选择无效", "invalid_belt")
        seen[belt_id] = true
        normalized.append(belt_id)
    if normalized.is_empty():
        return _batch_failure("没有选择线路", "empty_selection")
    var probe := copy_state()
    for belt_id in normalized:
        var probe_result := probe.try_configure_belt(belt_id, requested, false)
        if not probe_result.get("ok", false):
            return _batch_failure(String(probe_result.get("message", "批量线路配置失败")), String(probe_result.get("reason", "configuration_failed")))
    var connections_before := connections.duplicate(true)
    var inventory_before := construction_inventory.duplicate(true)
    var results: Array[Dictionary] = []
    for belt_id in normalized:
        var result := try_configure_belt(belt_id, requested, false)
        if not result.get("ok", false):
            connections = connections_before
            construction_inventory = inventory_before
            return _batch_failure(String(result.get("message", "批量线路配置失败")), "commit_failed")
        results.append({"id": belt_id, "status": "success", "reason": ""})
    for belt_id in normalized:
        EventBus.connection_configuration_changed.emit(belt_id, get_belt_configuration(belt_id).duplicate(true))
    return {"ok": true, "message": "已配置 %d 条线路" % normalized.size(), "success": normalized.size(), "skipped": 0, "failed": 0, "results": results}

func _persistent_belt_settings(configuration: Dictionary) -> Dictionary:
    return {
        "tier": configuration.get("tier", "conveyor_belt_mk1"),
        "parallel_count": configuration.get("parallel_count", 1),
        "stack_size": configuration.get("stack_size", 1),
        "priority": configuration.get("priority", 0),
        "route_mode": configuration.get("route_mode", "auto"),
        "route_offset_y": configuration.get("route_offset_y", 0.0),
        "monitor_enabled": configuration.get("monitor_enabled", false),
        "enabled": configuration.get("enabled", true),
    }

func _get_connected_belt_ids(template_belt_id: String) -> Array[String]:
    if get_belt_configuration(template_belt_id).is_empty():
        return []
    var result: Array[String] = []
    var queued: Array[String] = [template_belt_id]
    var seen: Dictionary = {template_belt_id: true}
    while not queued.is_empty():
        var belt_id: String = queued.pop_front()
        result.append(belt_id)
        var belt: Dictionary = connections[belt_id]
        var endpoints: Array[String] = [String(belt.get("source_id", "")), String(belt.get("target_id", ""))]
        for candidate_id_value in connections:
            var candidate_id := String(candidate_id_value)
            if seen.has(candidate_id) or get_belt_configuration(candidate_id).is_empty():
                continue
            var candidate: Dictionary = connections[candidate_id]
            if endpoints.has(String(candidate.get("source_id", ""))) or endpoints.has(String(candidate.get("target_id", ""))):
                seen[candidate_id] = true
                queued.append(candidate_id)
    result.sort()
    return result

func _network_item_result(belt_id: String, status: String, reason: String) -> Dictionary:
    return {"id": belt_id, "status": status, "reason": reason}

func _summarize_network_results(template_belt_id: String, results: Array[Dictionary]) -> Dictionary:
    var summary := {"ok": true, "template_id": template_belt_id, "success": 0, "skipped": 0, "failed": 0, "results": results}
    for result in results:
        var status := String(result.get("status", "failed"))
        if summary.has(status):
            summary[status] = int(summary[status]) + 1
    if int(summary.failed) > 0:
        summary.ok = false
    return summary

func _network_failure(template_belt_id: String, reason: String) -> Dictionary:
    return {"ok": false, "template_id": template_belt_id, "success": 0, "skipped": 0, "failed": 1, "results": [_network_item_result(template_belt_id, "failed", reason)]}

func _is_belt_connection(connection: Dictionary) -> bool:
    var connection_type := String(connection.get("type", "conveyor_belt_mk1"))
    return connection_type == "belt" or connection_type.begins_with("conveyor_belt")

func _normalize_belt_connection(connection: Dictionary) -> void:
    if not _is_belt_connection(connection):
        return
    connection["type"] = _belt_tier(connection)
    connection["parallel_count"] = _belt_parallel_count(connection)
    connection.erase("lanes")
    connection["stack_size"] = _belt_stack_size(connection)
    connection["priority"] = _belt_priority(connection)
    connection["route_mode"] = _belt_route_mode(connection)
    connection["route_offset_y"] = _belt_route_offset_y(connection)
    connection["monitor_enabled"] = bool(connection.get("monitor_enabled", false))
    connection["enabled"] = bool(connection.get("enabled", true))

func _belt_tier(connection: Dictionary) -> String:
    var tier := String(connection.get("type", "conveyor_belt_mk1"))
    return tier if BELT_RATED_THROUGHPUT.has(tier) else "conveyor_belt_mk1"

func _belt_parallel_count(connection: Dictionary) -> int:
    var value: Variant = connection.get("parallel_count", connection.get("lanes", 1))
    return int(value) if _is_integral_value(value) and int(value) >= 1 and int(value) <= 4 else 1

func _belt_stack_size(connection: Dictionary) -> int:
    var value: Variant = connection.get("stack_size", 1)
    return int(value) if _is_integral_value(value) and int(value) in BELT_STACK_SIZES else 1

func _belt_priority(connection: Dictionary) -> int:
    var value: Variant = connection.get("priority", 0)
    return int(value) if _is_integral_value(value) and int(value) in BELT_PRIORITIES else 0

func _belt_route_mode(connection: Dictionary) -> String:
    var value: Variant = connection.get("route_mode", "auto")
    return String(value) if value is String and String(value) in BELT_ROUTE_MODES else "auto"

func _belt_route_offset_y(connection: Dictionary) -> float:
    var value: Variant = connection.get("route_offset_y", 0.0)
    return float(value) if _is_finite_number(value) else 0.0

func _connection_construction_is_accounted(connection: Dictionary) -> bool:
    return bool(connection.get("construction_accounted", true))

func _has_belt_pieces(tier: String, amount: int) -> bool:
    var available := _construction_inventory_count(construction_inventory, tier)
    return available >= float(amount)

func _consume_belt_pieces(tier: String, amount: int) -> void:
    var available := _construction_inventory_count(construction_inventory, tier)
    construction_inventory[tier] = available - float(amount)

func _construction_inventory_count(inventory: Dictionary, item_id: String) -> float:
    return float(inventory.get(item_id, BELT_LEGACY_INVENTORY_DEFAULTS.get(item_id, 0.0)))

func _collect_building_material_refund(building: Dictionary, refund: Dictionary) -> void:
    for buffer_name in ["input_buffer", "output_buffer"]:
        var buffer: Dictionary = building.get(buffer_name, {})
        for item_key in buffer:
            var amount := float(buffer[item_key])
            if amount > 0.0:
                var item_id := String(item_key)
                refund[item_id] = float(refund.get(item_id, 0.0)) + amount
    var definition := DataManager.get_building(String(building.get("type", "")))
    var fuel_rule: Dictionary = definition.get("fuel", {})
    if not fuel_rule.is_empty():
        var fuel_item := String(building.get("fuel_item", fuel_rule.get("item_id", "")))
        var burn_duration := maxf(float(fuel_rule.get("burn_duration", 0.0)), 0.0000001)
        var unburned_fuel := maxf(float(building.get("fuel_remaining", 0.0)), 0.0) / burn_duration
        if not fuel_item.is_empty() and unburned_fuel > 0.0:
            refund[fuel_item] = float(refund.get(fuel_item, 0.0)) + unburned_fuel

func _batch_failure(message: String, reason: String) -> Dictionary:
    return {"ok": false, "message": message, "reason": reason, "success": 0, "skipped": 0, "failed": 1, "results": []}

func _is_integral_value(value: Variant) -> bool:
    return (typeof(value) == TYPE_INT or typeof(value) == TYPE_FLOAT) and float(value) == floorf(float(value))

func _is_finite_number(value: Variant) -> bool:
    return (typeof(value) == TYPE_INT or typeof(value) == TYPE_FLOAT) and not is_nan(float(value)) and not is_inf(float(value))

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
    return float(research_progress.get(tech_id, 0.0))

# 功能30: 设置科技研究
func set_technology_research(tech_id: String) -> bool:
    return TechnologySystem.new(self).start_research(tech_id)

func get_technology_effect_multiplier(effect_key: String) -> float:
    var multiplier := 1.0
    for technology_id_value in completed_technologies:
        var effects: Dictionary = DataManager.get_technology(String(technology_id_value)).get("effects", {})
        var value: Variant = effects.get(effect_key)
        if typeof(value) == TYPE_INT or typeof(value) == TYPE_FLOAT:
            var layers := maxi(get_technology_level(String(technology_id_value)), 1)
            for _layer in range(layers):
                multiplier *= float(value)
    return multiplier

func get_technology_level(tech_id: String) -> int:
    return int(technology_levels.get(tech_id, 0))

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
    var new_state := GameState.new()
    new_state.install_state(self)
    return new_state

func install_state(source: GameState) -> void:
    if source == null:
        return
    buildings = source.buildings.duplicate(true)
    connections = source.connections.duplicate(true)
    elapsed_time = source.elapsed_time
    paused = source.paused
    speed = source.speed
    planet_inventory = source.planet_inventory.duplicate(true)
    construction_inventory = source.construction_inventory.duplicate(true)
    cursor_payload = source.cursor_payload.duplicate(true)
    handcraft_queue = source.handcraft_queue.duplicate(true)
    completed_technologies = source.completed_technologies.duplicate(true)
    research_current_id = source.research_current_id
    research_queue = source.research_queue.duplicate(true)
    research_progress = source.research_progress.duplicate(true)
    research_invested_costs = source.research_invested_costs.duplicate(true)
    research_paused = source.research_paused
    research_queue_wait_reason = source.research_queue_wait_reason
    technology_levels = source.technology_levels.duplicate(true)
    completed_objective_ids = source.completed_objective_ids.duplicate(true)
    claimed_progression_reward_ids = source.claimed_progression_reward_ids.duplicate(true)
    completed_achievement_ids = source.completed_achievement_ids.duplicate(true)
    unlocked_progression_ids = source.unlocked_progression_ids.duplicate(true)
    simulation_budget = source.simulation_budget.duplicate(true)
    _next_id = source._next_id

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
