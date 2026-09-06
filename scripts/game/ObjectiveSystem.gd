class_name ObjectiveSystem
extends RefCounted

const DEFAULT_CATALOG_PATH := "res://data/progression.json"
const STOPPED_STATUSES := ["blocked", "no_power", "no_fuel", "error"]

static var _default_catalog_cache: Dictionary = {}

var catalog: Dictionary

func _init(custom_catalog: Dictionary = {}) -> void:
	catalog = custom_catalog.duplicate(true) if not custom_catalog.is_empty() else load_catalog()

static func load_catalog(path: String = DEFAULT_CATALOG_PATH) -> Dictionary:
	if path == DEFAULT_CATALOG_PATH and not _default_catalog_cache.is_empty():
		return _default_catalog_cache.duplicate(true)
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return {"chapters": [], "objectives": [], "achievements": []}
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	file.close()
	if not parsed is Dictionary:
		return {"chapters": [], "objectives": [], "achievements": []}
	var loaded := {
		"chapters": parsed.get("chapters", []).duplicate(true),
		"objectives": parsed.get("objectives", []).duplicate(true),
		"achievements": parsed.get("achievements", []).duplicate(true),
	}
	if path == DEFAULT_CATALOG_PATH:
		_default_catalog_cache = loaded.duplicate(true)
	return loaded

func get_progress(state: GameState, objective: Dictionary) -> Dictionary:
	return get_condition_progress(state, objective.get("condition", {}))

func is_complete(state: GameState, objective: Dictionary) -> bool:
	return bool(get_progress(state, objective).get("complete", false))

func get_condition_progress(state: GameState, condition: Dictionary) -> Dictionary:
	var fact := String(condition.get("fact", ""))
	var required := float(condition.get("at_least", 1.0))
	var current := 0.0
	match fact:
		"interplanetary_delivered":
			current = state.interplanetary_delivered
		"building_count":
			var building_types: Array = condition.get("building_types", [condition.get("building_type", "")])
			for building_value in state.buildings.values():
				if building_types.has(String(building_value.get("type", ""))):
					current += 1.0
		"connection_count":
			current = float(_count_valid_connections(state))
		"item_amount":
			current = _get_item_amount(state, String(condition.get("item_id", "")))
		"building_status_count":
			var allowed_statuses: Array = condition.get("statuses", [condition.get("status", "running")])
			var building_type := String(condition.get("building_type", ""))
			for building_value in state.buildings.values():
				var building: Dictionary = building_value
				if (building_type.is_empty() or String(building.get("type", "")) == building_type) and allowed_statuses.has(String(building.get("status", "idle"))):
					current += 1.0
		"technology_completed":
			current = 1.0 if state.completed_technologies.has(String(condition.get("technology_id", ""))) else 0.0
		"progression_unlocked":
			current = 1.0 if state.unlocked_progression_ids.has(String(condition.get("unlock_id", ""))) else 0.0
		_:
			return {"current": 0.0, "required": required, "complete": false}
	return {"current": current, "required": required, "complete": current >= required}

func find_stopped_building(state: GameState) -> Dictionary:
	var building_ids := state.buildings.keys()
	building_ids.sort()
	for id_value in building_ids:
		var building_id := String(id_value)
		var building: Dictionary = state.buildings[building_id]
		if STOPPED_STATUSES.has(String(building.get("status", "idle"))):
			return {
				"building_id": building_id,
				"position": building.get("position", Vector2.ZERO),
				"status": building.get("status", "idle"),
			}
	return {}

func _count_valid_connections(state: GameState) -> int:
	var count := 0
	for connection_value in state.connections.values():
		var connection: Dictionary = connection_value
		if not bool(connection.get("enabled", true)):
			continue
		var source_id := String(connection.get("source_id", ""))
		var target_id := String(connection.get("target_id", ""))
		var output_item := String(connection.get("item_id", ""))
		if source_id.is_empty() or target_id.is_empty() or source_id == target_id:
			continue
		if not state.buildings.has(source_id) or not state.buildings.has(target_id):
			continue
		if output_item.is_empty() or not state.get_building_output_items(source_id).has(output_item):
			continue
		count += 1
	return count

func _get_item_amount(state: GameState, item_id: String) -> float:
	var total := float(state.get_active_planet_inventory().get(item_id, 0.0))
	for building_value in state.buildings.values():
		var building: Dictionary = building_value
		if String(building.get("planet_id", "")) != state.active_planet_id:
			continue
		total += float(building.get("input_buffer", {}).get(item_id, 0.0))
		total += float(building.get("output_buffer", {}).get(item_id, 0.0))
	return total
