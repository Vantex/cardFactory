class_name ProductionDiagnostics
extends RefCounted

const DEFAULT_BUFFER_CAPACITY := 60.0
const EPSILON := 0.0000001

var game_state: GameState

func _init(state: GameState) -> void:
	game_state = state

func get_all_diagnostics() -> Array:
	var results: Array = []
	if game_state == null:
		return results
	var building_ids: Array = game_state.buildings.keys()
	building_ids.sort()
	for building_id_value in building_ids:
		var building_id := String(building_id_value)
		var entry := _diagnose_building(building_id, game_state.buildings[building_id_value])
		if not entry.is_empty():
			results.append(entry)
	var connection_ids: Array = game_state.connections.keys()
	connection_ids.sort()
	for connection_id_value in connection_ids:
		var connection_id := String(connection_id_value)
		var entry := _diagnose_connection(connection_id, game_state.connections[connection_id_value])
		if not entry.is_empty():
			results.append(entry)
	results.sort_custom(func(left: Dictionary, right: Dictionary) -> bool:
		return String(left.get("entity_id", "")) < String(right.get("entity_id", ""))
	)
	return results

func _diagnose_building(building_id: String, building: Dictionary) -> Dictionary:
	var building_type := String(building.get("type", ""))
	var definition := DataManager.get_building(building_type)
	var recipe_machine := _is_recipe_machine(building_type, definition)
	var recipe_id := String(building.get("recipe_id", ""))
	var recipe := DataManager.get_recipe(recipe_id)
	if recipe_machine and (recipe_id.is_empty() or recipe.is_empty() or not DataManager.is_recipe_supported_by_building(recipe, building_type)):
		return _make_entry("no_recipe", "未配置可用配方", building_id, building_id, building.get("position", Vector2.ZERO))
	if _is_powered_producer(recipe_machine, definition) and _power_ratio_for(building, definition) <= EPSILON:
		return _make_entry("no_power", "供电不足，设备无法运行", building_id, building_id, building.get("position", Vector2.ZERO))
	if not recipe_machine:
		return {}
	var input_buffer: Dictionary = building.get("input_buffer", {})
	for input_value in recipe.get("inputs", []):
		if not input_value is Dictionary:
			continue
		var input: Dictionary = input_value
		var item_id := String(input.get("item_id", ""))
		var required := float(input.get("amount", 0.0))
		if float(input_buffer.get(item_id, 0.0)) + EPSILON < required:
			return _make_entry("missing_input", "缺少输入物料：%s" % item_id, building_id, building_id, building.get("position", Vector2.ZERO))
	var output_buffer: Dictionary = building.get("output_buffer", {})
	var capacity := _buffer_capacity(building, definition, "output")
	for output_value in recipe.get("outputs", []):
		if not output_value is Dictionary:
			continue
		var output: Dictionary = output_value
		var item_id := String(output.get("item_id", ""))
		var amount := float(output.get("amount", 0.0))
		if float(output_buffer.get(item_id, 0.0)) + amount > capacity + EPSILON:
			return _make_entry("output_full", "输出缓冲区空间不足：%s" % item_id, building_id, building_id, building.get("position", Vector2.ZERO))
	return {}

func _diagnose_connection(connection_id: String, connection: Dictionary) -> Dictionary:
	var target_id := String(connection.get("target_id", ""))
	var target: Dictionary = game_state.get_building(target_id)
	var position: Variant = target.get("position", Vector2.ZERO)
	if not bool(connection.get("enabled", true)):
		return _make_entry("belt_disabled", "线路已关闭", connection_id, target_id, position)
	var source: Dictionary = game_state.get_building(String(connection.get("source_id", "")))
	if source.is_empty() or target.is_empty():
		return {}
	var item_id := String(connection.get("item_id", ""))
	if float(source.get("output_buffer", {}).get(item_id, 0.0)) <= EPSILON:
		return {}
	var definition := DataManager.get_building(String(target.get("type", "")))
	var capacity := _buffer_capacity(target, definition, "input")
	var input_buffer: Dictionary = target.get("input_buffer", {})
	if not item_id.is_empty() and float(input_buffer.get(item_id, 0.0)) + EPSILON >= capacity:
		return _make_entry("belt_blocked", "目标输入缓冲区已满：%s" % item_id, connection_id, target_id, position)
	return {}

func _is_recipe_machine(building_type: String, definition: Dictionary) -> bool:
	if String(definition.get("kind", "")) == "processor":
		return true
	return not DataManager.get_recipes_for_building(building_type).is_empty()

func _is_powered_producer(recipe_machine: bool, definition: Dictionary) -> bool:
	return recipe_machine or String(definition.get("kind", "")) == "extractor"

func _power_ratio_for(building: Dictionary, definition: Dictionary) -> float:
	var demand := maxf(float(definition.get("power_demand", 0.0)), 0.0)
	if demand <= 0.0:
		return 1.0
	if building.has("power_efficiency"):
		return clampf(float(building.get("power_efficiency", 0.0)), 0.0, 1.0)
	return _catalog_power_ratio()

func _catalog_power_ratio() -> float:
	var generation := 0.0
	var consumption := 0.0
	for building_value in game_state.buildings.values():
		if not building_value is Dictionary:
			continue
		var building: Dictionary = building_value
		var definition := DataManager.get_building(String(building.get("type", "")))
		consumption += maxf(float(definition.get("power_demand", 0.0)), 0.0)
		generation += maxf(float(definition.get("power_generation", 0.0)), 0.0) * clampf(float(building.get("generation_factor", 1.0)), 0.0, 1.0)
	return 1.0 if consumption <= 0.0 else clampf(generation / consumption, 0.0, 1.0)

func _buffer_capacity(building: Dictionary, definition: Dictionary, direction: String) -> float:
	var key := "%s_buffer_capacity" % direction
	return maxf(float(building.get(key, definition.get(key, DEFAULT_BUFFER_CAPACITY))), 0.0)

func _make_entry(code: String, message: String, entity_id: String, building_id: String, position: Variant) -> Dictionary:
	return {
		"code": code,
		"message": message,
		"entity_id": entity_id,
		"building_id": building_id,
		"planet_id": "home",
		"world_position": position if position is Vector2 else Vector2.ZERO,
	}
