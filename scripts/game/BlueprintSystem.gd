class_name BlueprintSystem
extends RefCounted

const BlueprintCodecScript = preload("res://scripts/game/BlueprintCodec.gd")
const FactoryGeometryScript = preload("res://scripts/game/FactoryGeometry.gd")
const CONNECTION_TYPES := ["conveyor_belt_mk1", "conveyor_belt_mk2", "conveyor_belt_mk3"]
const AMOUNT_EPSILON := 0.0000001

var game_state: GameState

func _init(state: GameState) -> void:
	game_state = state

func capture_selection(selected_entity_ids: Array) -> Dictionary:
	var building_ids: Array[String] = []
	for id_value in selected_entity_ids:
		var entity_id := String(id_value)
		var selected_entity: Dictionary = game_state.buildings.get(entity_id, game_state.connections.get(entity_id, {}))
		if selected_entity.is_empty():
			return _failure("invalid_reference", "蓝图选择包含不存在的实体")
		if String(selected_entity.get("planet_id", "")) != game_state.active_planet_id:
			return _failure("inactive_entity", "蓝图只能捕获活动行星实体")
		if not game_state.buildings.has(entity_id):
			continue
		if not building_ids.has(entity_id):
			building_ids.append(entity_id)
	if building_ids.is_empty():
		return _failure("empty_selection", "请选择至少一个建筑")
	building_ids.sort_custom(func(left: String, right: String) -> bool:
		var left_position: Vector2 = game_state.buildings[left].get("position", Vector2.ZERO)
		var right_position: Vector2 = game_state.buildings[right].get("position", Vector2.ZERO)
		if not is_equal_approx(left_position.y, right_position.y):
			return left_position.y < right_position.y
		if not is_equal_approx(left_position.x, right_position.x):
			return left_position.x < right_position.x
		return left < right
	)
	var origin := Vector2(INF, INF)
	for building_id in building_ids:
		var position: Vector2 = game_state.buildings[building_id].get("position", Vector2.ZERO)
		origin.x = minf(origin.x, position.x)
		origin.y = minf(origin.y, position.y)

	var local_refs: Dictionary = {}
	var entities: Array = []
	for index in range(building_ids.size()):
		var building_id := building_ids[index]
		var building: Dictionary = game_state.buildings[building_id]
		var local_ref := "entity_%d" % index
		local_refs[building_id] = local_ref
		entities.append({
			"ref": local_ref,
			"type": String(building.get("type", "")),
			"position": Vector2(building.get("position", Vector2.ZERO)) - origin,
			"configuration": _capture_entity_configuration(building),
		})

	var connections: Array = []
	var connection_ids: Array = game_state.connections.keys()
	connection_ids.sort()
	for connection_id in connection_ids:
		var connection: Dictionary = game_state.connections[connection_id]
		if String(connection.get("planet_id", "")) != game_state.active_planet_id:
			continue
		var source_id := String(connection.get("source_id", ""))
		var target_id := String(connection.get("target_id", ""))
		if not local_refs.has(source_id) or not local_refs.has(target_id):
			continue
		connections.append({
			"source": local_refs[source_id],
			"target": local_refs[target_id],
			"type": String(connection.get("type", "conveyor_belt_mk1")),
			"configuration": _capture_connection_configuration(connection),
		})
	return BlueprintCodecScript.new().validate_and_normalize({"version": 1, "entities": entities, "connections": connections})

func deploy(blueprint: Dictionary, offset: Vector2, rotation_quarters: int = 0, mirrored: bool = false, commit_guard: Callable = Callable()) -> Dictionary:
	var normalized_result := BlueprintCodecScript.new().validate_and_normalize(blueprint)
	if not normalized_result.get("ok", false):
		return normalized_result
	var normalized: Dictionary = normalized_result.blueprint
	if normalized.entities.is_empty():
		return _failure("empty_blueprint", "蓝图没有可部署实体")

	var plans: Array = []
	var local_refs: Dictionary = {}
	var cost: Dictionary = {}
	var building_items: Array[String] = []
	for entity in normalized.entities:
		var building_type := String(entity.type)
		var definition := DataManager.get_building(building_type)
		if definition.is_empty():
			return _failure("invalid_reference", "蓝图引用了未知建筑")
		if not _is_catalog_entry_unlocked("building", building_type):
			return _failure("locked", "蓝图包含尚未解锁的建筑")
		var configuration_result := _validate_entity_configuration(building_type, entity.configuration)
		if not configuration_result.get("ok", false):
			return configuration_result
		var target_position := offset + _transform_position(entity.position, rotation_quarters, mirrored)
		if not is_finite(target_position.x) or not is_finite(target_position.y) or absf(target_position.x) > BlueprintCodecScript.MAX_COORDINATE or absf(target_position.y) > BlueprintCodecScript.MAX_COORDINATE:
			return _failure("coordinate_limit", "部署位置超过坐标限制")
		var plan := {"ref": String(entity.ref), "type": building_type, "position": target_position, "configuration": entity.configuration.duplicate(true)}
		plans.append(plan)
		local_refs[entity.ref] = plan
		cost[building_type] = float(cost.get(building_type, 0.0)) + 1.0
		building_items.append(building_type)

	var connection_plans: Array = []
	var connection_items: Array[String] = []
	var planned_edges: Dictionary = {}
	for connection in normalized.connections:
		if not local_refs.has(connection.source) or not local_refs.has(connection.target):
			return _failure("invalid_reference", "蓝图连接引用不存在")
		var connection_type := String(connection.type)
		if not CONNECTION_TYPES.has(connection_type):
			return _failure("invalid_reference", "蓝图引用了未知线路类型")
		var item_id := String(connection.configuration.get("item_id", ""))
		if not item_id.is_empty() and DataManager.get_item(item_id).is_empty():
			return _failure("invalid_reference", "蓝图线路物品引用不存在")
		var edge_key := "%s>%s" % [connection.source, connection.target]
		if planned_edges.has(edge_key):
			return _failure("duplicate_connection", "蓝图包含重复连接")
		planned_edges[edge_key] = true
		var semantic_result := _validate_planned_connection(local_refs[connection.source], local_refs[connection.target], item_id)
		if not semantic_result.get("ok", false):
			return semantic_result
		var parallel_count := int(connection.configuration.get("parallel_count", 1))
		cost[connection_type] = float(cost.get(connection_type, 0.0)) + parallel_count
		for _index in range(parallel_count):
			connection_items.append(connection_type)
		connection_plans.append(connection)

	var overlap_result := _validate_space(plans)
	if not overlap_result.get("ok", false):
		return overlap_result
	var deduction_result := _plan_inventory_deduction(building_items, connection_items)
	if not deduction_result.get("ok", false):
		return deduction_result

	var ref_to_id: Dictionary = {}
	var entity_ids: Array[String] = []
	var buildings_before := game_state.buildings.duplicate(true)
	var connections_before := game_state.connections.duplicate(true)
	var inventory_before := game_state.construction_inventory.duplicate(true)
	var next_id_before := game_state._next_id
	for plan_index in range(plans.size()):
		var plan: Dictionary = plans[plan_index]
		var entity_id := game_state.generate_id("building")
		ref_to_id[plan.ref] = entity_id
		entity_ids.append(entity_id)
		var building_data := _make_building_data(plan.type, plan.position, plan.configuration)
		building_data["id"] = entity_id
		game_state.buildings[entity_id] = building_data
		if commit_guard.is_valid() and not bool(commit_guard.call("entity", plan_index)):
			_restore_snapshot(buildings_before, connections_before, inventory_before, next_id_before)
			return _failure("commit_failed", "蓝图部署提交失败并已回滚")
	var connection_ids: Array[String] = []
	for connection_index in range(connection_plans.size()):
		var connection: Dictionary = connection_plans[connection_index]
		var connection_id := game_state.generate_id("conn")
		var connection_data := _make_connection_data(connection, ref_to_id)
		connection_data["id"] = connection_id
		game_state._normalize_belt_connection(connection_data)
		game_state.connections[connection_id] = connection_data
		connection_ids.append(connection_id)
		if commit_guard.is_valid() and not bool(commit_guard.call("connection", connection_index)):
			_restore_snapshot(buildings_before, connections_before, inventory_before, next_id_before)
			return _failure("commit_failed", "蓝图部署提交失败并已回滚")
	game_state.construction_inventory = deduction_result.inventory

	for entity_id in entity_ids:
		EventBus.card_placed.emit(entity_id, game_state.buildings[entity_id].position)
	for connection_id in connection_ids:
		var connection: Dictionary = game_state.connections[connection_id]
		EventBus.connection_created.emit(connection_id, connection.source_id, connection.target_id)
	return {"ok": true, "message": "蓝图已部署", "entity_ids": entity_ids, "connection_ids": connection_ids, "cost": cost}

func _capture_entity_configuration(building: Dictionary) -> Dictionary:
	var configuration: Dictionary = {}
	for key in ["recipe_id", "output_item"]:
		var value := String(building.get(key, ""))
		if not value.is_empty():
			configuration[key] = value
	return configuration

func _capture_connection_configuration(connection: Dictionary) -> Dictionary:
	var configuration: Dictionary = {}
	var item_id := String(connection.get("item_id", ""))
	if not item_id.is_empty():
		configuration["item_id"] = item_id
	for key in ["parallel_count", "stack_size", "priority"]:
		if connection.has(key):
			configuration[key] = int(connection[key])
	if connection.has("route_mode"):
		configuration["route_mode"] = String(connection.route_mode)
	if connection.has("route_offset_y"):
		configuration["route_offset_y"] = float(connection.route_offset_y)
	for key in ["monitor_enabled", "enabled"]:
		if connection.has(key):
			configuration[key] = bool(connection[key])
	return configuration

func _transform_position(position: Vector2, rotation_quarters: int, mirrored: bool) -> Vector2:
	var result := position
	for _index in range(posmod(rotation_quarters, 4)):
		result = Vector2(-result.y, result.x)
	if mirrored:
		result.x = -result.x
	return result

func _validate_entity_configuration(building_type: String, configuration: Dictionary) -> Dictionary:
	var definition := DataManager.get_building(building_type)
	var recipe_id := String(configuration.get("recipe_id", ""))
	if not recipe_id.is_empty():
		var recipe := DataManager.get_recipe(recipe_id)
		if recipe.is_empty() or not DataManager.is_recipe_supported_by_building(recipe, building_type):
			return _failure("invalid_reference", "蓝图配方与建筑不兼容")
		if not _is_catalog_entry_unlocked("recipe", recipe_id):
			return _failure("locked", "蓝图包含尚未解锁的配方")
	var output_item := String(configuration.get("output_item", ""))
	if not output_item.is_empty() and DataManager.get_item(output_item).is_empty():
		return _failure("invalid_reference", "蓝图输出物品引用不存在")
	if not output_item.is_empty() and definition.get("kind", "") == "extractor":
		var extraction: Dictionary = definition.get("extraction", {})
		var allowed: Array = extraction.get("items", [extraction.get("item_id", "")])
		if not allowed.has(output_item):
			return _failure("invalid_reference", "蓝图采集物品不属于该建筑")
	if not output_item.is_empty() and not recipe_id.is_empty():
		var recipe_outputs: Array = DataManager.get_recipe(recipe_id).get("outputs", [])
		var output_allowed := false
		for output in recipe_outputs:
			if String(output.get("item_id", "")) == output_item:
				output_allowed = true
		if not output_allowed:
			return _failure("invalid_reference", "蓝图输出物品不属于所选配方")
	return {"ok": true}

func _validate_planned_connection(source_plan: Dictionary, target_plan: Dictionary, item_id: String) -> Dictionary:
	var source_outputs: Array[String] = []
	var source_configuration: Dictionary = source_plan.configuration
	var explicit_output := String(source_configuration.get("output_item", ""))
	var source_definition := DataManager.get_building(String(source_plan.type))
	if source_definition.get("kind", "") == "extractor" and not explicit_output.is_empty():
		source_outputs.append(explicit_output)
	else:
		var source_recipe := DataManager.get_recipe(String(source_configuration.get("recipe_id", "")))
		for output in source_recipe.get("outputs", []):
			source_outputs.append(String(output.get("item_id", "")))
		if source_outputs.is_empty():
			var extraction: Dictionary = source_definition.get("extraction", {})
			for output_value in extraction.get("items", [extraction.get("item_id", "")]):
				if not String(output_value).is_empty():
					source_outputs.append(String(output_value))
	if item_id.is_empty() or not source_outputs.has(item_id):
		return _failure("incompatible_connection", "蓝图源建筑不提供线路物品")
	var target_configuration: Dictionary = target_plan.configuration
	var target_recipe_id := String(target_configuration.get("recipe_id", ""))
	var candidate_recipes: Array = []
	if target_recipe_id.is_empty():
		candidate_recipes = DataManager.get_recipes_for_building(String(target_plan.type))
	else:
		candidate_recipes = [DataManager.get_recipe(target_recipe_id)]
	var compatible_but_locked := false
	for recipe in candidate_recipes:
		for input in recipe.get("inputs", []):
			if String(input.get("item_id", "")) == item_id:
				var candidate_recipe_id := String(recipe.get("id", ""))
				if not _is_catalog_entry_unlocked("recipe", candidate_recipe_id):
					compatible_but_locked = true
					continue
				if target_recipe_id.is_empty():
					target_configuration["recipe_id"] = candidate_recipe_id
				return {"ok": true}
	if compatible_but_locked:
		return _failure("locked", "蓝图目标配方尚未解锁")
	return _failure("incompatible_connection", "蓝图目标配方无法接收线路物品")

func _is_catalog_entry_unlocked(kind: String, entry_id: String) -> bool:
	var owners: Array[String] = []
	for technology_id_value in DataManager.get_all_technologies():
		var technology_id := String(technology_id_value)
		var technology := DataManager.get_technology(technology_id)
		for unlock_value in technology.get("unlocks", []):
			if unlock_value is Dictionary and String(unlock_value.get("kind", "")) == kind and String(unlock_value.get("id", "")) == entry_id:
				owners.append(technology_id)
	if owners.is_empty():
		return true
	for technology_id in owners:
		if game_state.is_technology_completed(technology_id):
			return true
	return false

func _validate_space(plans: Array) -> Dictionary:
	for index in range(plans.size()):
		var target_rect := FactoryGeometryScript.card_rect(plans[index].position)
		for existing in game_state.buildings.values():
			if String(existing.get("planet_id", "")) != game_state.active_planet_id:
				continue
			if target_rect.intersects(FactoryGeometryScript.card_rect(existing.get("position", Vector2.ZERO)), false):
				return _failure("overlap", "蓝图部署位置与现有建筑重叠")
		for other_index in range(index):
			if target_rect.intersects(FactoryGeometryScript.card_rect(plans[other_index].position), false):
				return _failure("overlap", "蓝图内部建筑重叠")
	return {"ok": true}

func _plan_inventory_deduction(building_items: Array[String], connection_items: Array[String]) -> Dictionary:
	var inventory := game_state.construction_inventory.duplicate(true)
	for building_type in building_items:
		var owned := float(inventory.get(building_type, 0.0))
		if owned + AMOUNT_EPSILON >= 1.0:
			inventory[building_type] = maxf(owned - 1.0, 0.0)
			continue
		var legacy_cost := float(ConstructionSystem.LEGACY_COSTS.get(building_type, INF))
		var legacy_credit := float(inventory.get("legacy_credit", 0.0))
		if legacy_credit + AMOUNT_EPSILON < legacy_cost:
			return _failure("missing_materials", "蓝图部署缺少施工件")
		legacy_credit = maxf(legacy_credit - legacy_cost, 0.0)
		if legacy_credit <= AMOUNT_EPSILON:
			inventory.erase("legacy_credit")
		else:
			inventory["legacy_credit"] = legacy_credit
	for connection_type in connection_items:
		var owned := float(inventory.get(connection_type, 0.0))
		if owned + AMOUNT_EPSILON < 1.0:
			return _failure("missing_materials", "蓝图部署缺少线路施工件")
		inventory[connection_type] = maxf(owned - 1.0, 0.0)
	return {"ok": true, "inventory": inventory}

func _make_building_data(building_type: String, position: Vector2, configuration: Dictionary) -> Dictionary:
	var definition := DataManager.get_building(building_type)
	var building := {"type": building_type, "planet_id": game_state.active_planet_id, "position": position, "status": "idle", "recipe_id": String(configuration.get("recipe_id", "")), "progress": 0.0, "input_buffer": {}, "output_buffer": {}, "speed": definition.get("speed", 1.0)}
	var output_item := String(configuration.get("output_item", ""))
	if not output_item.is_empty():
		building["output_item"] = output_item
	elif definition.get("kind", "") == "extractor":
		building["output_item"] = String(definition.get("extraction", {}).get("item_id", ""))
	var fuel: Dictionary = definition.get("fuel", {})
	if not fuel.is_empty():
		building["fuel_item"] = String(fuel.get("item_id", ""))
		building["fuel_remaining"] = 0.0
	return building

func _make_connection_data(connection: Dictionary, ref_to_id: Dictionary) -> Dictionary:
	var configuration: Dictionary = connection.configuration
	var data := {"source_id": ref_to_id[connection.source], "target_id": ref_to_id[connection.target], "planet_id": game_state.active_planet_id, "type": String(connection.type), "item_id": String(configuration.get("item_id", "")), "construction_accounted": true, "enabled": true, "active": false, "current_flow": 0.0}
	for key in ["parallel_count", "stack_size", "priority", "route_mode", "route_offset_y", "monitor_enabled", "enabled"]:
		if configuration.has(key):
			data[key] = configuration[key]
	return data

func _restore_snapshot(buildings: Dictionary, connections: Dictionary, inventory: Dictionary, next_id: int) -> void:
	game_state.buildings = buildings
	game_state.connections = connections
	game_state.construction_inventory = inventory
	game_state._next_id = next_id

func _failure(reason: String, message: String) -> Dictionary:
	return {"ok": false, "reason": reason, "message": message}
