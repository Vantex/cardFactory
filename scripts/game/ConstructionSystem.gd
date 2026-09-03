class_name ConstructionSystem
extends RefCounted

const FactoryGeometry = preload("res://scripts/game/FactoryGeometry.gd")
const AMOUNT_EPSILON := 0.0000001
const GENERATOR_STARTUP_FUEL_UNITS := 10.0
const LEGACY_COSTS := {
	"miner": 1.0,
	"smelter": 2.0,
	"assembling_machine_mk1": 3.0,
	"power_generator": 2.0,
	"matrix_lab": 4.0,
}

var game_state: GameState

func _init(state: GameState) -> void:
	game_state = state

func try_place_building(building_type: String, position: Vector2) -> Dictionary:
	var building_definition := DataManager.get_building(building_type)
	if building_definition.is_empty():
		return _failure("unknown_building", "未知建筑类型")
	if not LEGACY_COSTS.has(building_type):
		return _failure("unconfigured_construction_item", "未配置施工件")
	var placement_rect := FactoryGeometry.card_rect(position)
	for existing_building in game_state.buildings.values():
		if String(existing_building.get("planet_id", game_state.active_planet_id)) != game_state.active_planet_id:
			continue
		var existing_rect := FactoryGeometry.card_rect(existing_building.get("position", Vector2.ZERO))
		if placement_rect.intersects(existing_rect, false):
			return _failure("overlap", "建筑卡片重叠")
	if not _has_construction_item(building_type):
		return _failure("missing_construction_item", "缺少%s施工件" % building_definition.get("name", building_type))
	var resource_site_id := ""
	var extraction: Dictionary = building_definition.get("extraction", {})
	if building_definition.get("kind", "") == "extractor":
		var output_item := String(extraction.get("item_id", ""))
		var nearest := PlanetSystem.new(game_state).find_nearest_resource_site(game_state.active_planet_id, output_item, position)
		if nearest.is_empty():
			return _failure("invalid_resource_site", "附近没有可用资源点")
		resource_site_id = String(nearest.get("id", ""))

	_consume_construction_item(building_type)
	var building_data := {
		"type": building_type,
		"position": position,
		"status": "idle",
		"recipe_id": "",
		"progress": 0.0,
		"input_buffer": {},
		"output_buffer": {},
		"speed": building_definition.get("speed", 1.0),
		"planet_id": game_state.active_planet_id,
	}
	if building_definition.get("kind", "") == "extractor":
		building_data["output_item"] = String(extraction.get("item_id", ""))
		building_data["resource_site_id"] = resource_site_id
	var fuel_rule: Dictionary = building_definition.get("fuel", {})
	if not fuel_rule.is_empty():
		var fuel_item := String(fuel_rule.get("item_id", ""))
		var burn_duration := float(fuel_rule.get("burn_duration", 0.0))
		var startup_fuel := minf(float(game_state.planet_inventory.get(fuel_item, 0.0)), GENERATOR_STARTUP_FUEL_UNITS)
		if startup_fuel > AMOUNT_EPSILON:
			InventorySystem.new(game_state).try_remove(fuel_item, startup_fuel)
		building_data["fuel_item"] = fuel_item
		building_data["fuel_remaining"] = startup_fuel * burn_duration
	var building_id := game_state.add_building(building_data)
	return {"ok": true, "reason": "", "message": "建筑已放置", "details": {"id": building_id}, "id": building_id}

func try_remove_building(building_id: String) -> Dictionary:
	var result := game_state.try_remove_entities([building_id])
	var normalized := result.duplicate(true)
	normalized["reason"] = String(result.get("reason", ""))
	normalized["details"] = {"building_id": building_id, "result": result.duplicate(true)}
	return normalized

func get_owned_count(building_type: String) -> float:
	return float(game_state.construction_inventory.get(building_type, 0.0))

func get_missing_reason(building_type: String) -> String:
	if DataManager.get_building(building_type).is_empty():
		return "未知建筑类型"
	return "" if _has_construction_item(building_type) else "缺少%s施工件" % DataManager.get_building(building_type).get("name", building_type)

func _has_construction_item(building_type: String) -> bool:
	if get_owned_count(building_type) >= 1.0:
		return true
	return float(game_state.construction_inventory.get("legacy_credit", 0.0)) + AMOUNT_EPSILON >= float(LEGACY_COSTS.get(building_type, INF))

func _consume_construction_item(building_type: String) -> void:
	var owned := get_owned_count(building_type)
	if owned >= 1.0:
		game_state.construction_inventory[building_type] = owned - 1.0
		return
	var remaining_credit := maxf(float(game_state.construction_inventory.get("legacy_credit", 0.0)) - float(LEGACY_COSTS[building_type]), 0.0)
	if remaining_credit <= AMOUNT_EPSILON:
		game_state.construction_inventory.erase("legacy_credit")
	else:
		game_state.construction_inventory["legacy_credit"] = remaining_credit

func _failure(reason: String, message: String) -> Dictionary:
	return {"ok": false, "reason": reason, "message": message, "details": {}}
