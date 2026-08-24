class_name ConstructionSystem
extends RefCounted

const FactoryGeometry = preload("res://scripts/game/FactoryGeometry.gd")
const MAX_CONSTRUCTION_STACK := 99.0
const AMOUNT_EPSILON := 0.0000001
const GENERATOR_FUEL_ITEM := "coal"
const GENERATOR_STARTUP_FUEL_UNITS := 10.0
const GENERATOR_FUEL_SECONDS_PER_UNIT := 30.0
const LEGACY_COSTS := {
	"miner": 1.0,
	"smelter": 2.0,
	"assembling_machine_mk1": 3.0,
	"power_generator": 2.0,
}

var game_state: GameState

func _init(state: GameState) -> void:
	game_state = state

func try_place_building(building_type: String, position: Vector2) -> Dictionary:
	var building_definition := DataManager.get_building(building_type)
	if building_definition.is_empty():
		return _failure("未知建筑类型")
	if not LEGACY_COSTS.has(building_type):
		return _failure("未配置施工件")
	var placement_rect := FactoryGeometry.card_rect(position)
	for existing_building in game_state.buildings.values():
		var existing_rect := FactoryGeometry.card_rect(existing_building.get("position", Vector2.ZERO))
		if placement_rect.intersects(existing_rect, false):
			return _failure("建筑卡片重叠")
	if not _has_construction_item(building_type):
		return _failure("缺少%s施工件" % building_definition.get("name", building_type))

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
	}
	if building_type == "miner":
		building_data["output_item"] = "iron_ore"
	elif building_type == "power_generator":
		var startup_fuel := minf(float(game_state.planet_inventory.get(GENERATOR_FUEL_ITEM, 0.0)), GENERATOR_STARTUP_FUEL_UNITS)
		if startup_fuel > AMOUNT_EPSILON:
			InventorySystem.new(game_state).try_remove(GENERATOR_FUEL_ITEM, startup_fuel)
		building_data["fuel_item"] = GENERATOR_FUEL_ITEM
		building_data["fuel_remaining"] = startup_fuel * GENERATOR_FUEL_SECONDS_PER_UNIT
	var building_id := game_state.add_building(building_data)
	return {"ok": true, "message": "建筑已放置", "id": building_id}

func try_remove_building(building_id: String) -> Dictionary:
	var building := game_state.get_building(building_id)
	if building.is_empty():
		return _failure("建筑不存在或已删除")
	var building_type := String(building.get("type", ""))
	if not LEGACY_COSTS.has(building_type):
		return _failure("建筑没有可返还的施工件")
	if get_owned_count(building_type) + 1.0 > MAX_CONSTRUCTION_STACK + AMOUNT_EPSILON:
		return _failure("施工库存容量不足")

	var material_refund := _collect_buffered_materials(building)
	var inventory := InventorySystem.new(game_state)
	if not material_refund.is_empty() and not inventory.can_add_batch(material_refund):
		return _failure("行星托盘容量不足，无法安全拆除")

	game_state.construction_inventory[building_type] = get_owned_count(building_type) + 1.0
	if not material_refund.is_empty():
		inventory.try_add_batch(material_refund)
	var connections_to_remove: Array = []
	for connection_id in game_state.connections:
		var connection: Dictionary = game_state.connections[connection_id]
		if connection.get("source_id", "") == building_id or connection.get("target_id", "") == building_id:
			connections_to_remove.append(connection_id)
	for connection_id in connections_to_remove:
		game_state.remove_connection(String(connection_id))
	game_state.buildings.erase(building_id)
	EventBus.card_removed.emit(building_id)
	return {"ok": true, "message": "建筑已拆除，施工件和缓存已返还"}

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

func _collect_buffered_materials(building: Dictionary) -> Dictionary:
	var refund: Dictionary = {}
	for buffer_name in ["input_buffer", "output_buffer"]:
		var buffer: Dictionary = building.get(buffer_name, {})
		for item_key in buffer:
			var amount := float(buffer[item_key])
			if amount > AMOUNT_EPSILON:
				var item_id := String(item_key)
				refund[item_id] = float(refund.get(item_id, 0.0)) + amount
	if String(building.get("type", "")) == "power_generator":
		var fuel_item := String(building.get("fuel_item", GENERATOR_FUEL_ITEM))
		var unburned_fuel := maxf(float(building.get("fuel_remaining", 0.0)), 0.0) / GENERATOR_FUEL_SECONDS_PER_UNIT
		if not fuel_item.is_empty() and unburned_fuel > AMOUNT_EPSILON:
			refund[fuel_item] = float(refund.get(fuel_item, 0.0)) + unburned_fuel
	return refund

func _failure(message: String) -> Dictionary:
	return {"ok": false, "message": message}
