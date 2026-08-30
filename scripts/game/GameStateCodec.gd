class_name GameStateCodec
extends RefCounted

const ROOT_RUNTIME_FIELDS := {
	"paused": true,
	"speed": true,
	"simulation_budget": true,
}
const BUILDING_RUNTIME_FIELDS := {
	"status": true,
	"interaction_locked": true,
	"power_efficiency": true,
	"power_output": true,
}
const CONNECTION_RUNTIME_FIELDS := {
	"active": true,
	"current_flow": true,
	"construction_accounted": true,
}

static func to_persistent_dict(state: GameState) -> Dictionary:
	var completed_technologies: Array = state.completed_technologies.duplicate(true)
	completed_technologies.sort()
	var completed_objective_ids: Array = state.completed_objective_ids.duplicate(true)
	completed_objective_ids.sort()
	var claimed_reward_ids: Array = state.claimed_progression_reward_ids.duplicate(true)
	claimed_reward_ids.sort()
	var completed_achievement_ids: Array = state.completed_achievement_ids.duplicate(true)
	completed_achievement_ids.sort()
	var unlocked_progression_ids: Array = state.unlocked_progression_ids.duplicate(true)
	unlocked_progression_ids.sort()
	var payload := {
		"schema_version": GameState.SCHEMA_VERSION,
		"next_id": state._next_id,
		"elapsed_time": state.elapsed_time,
		"planet_inventory": state.planet_inventory,
		"construction_inventory": state.construction_inventory,
		"cursor_payload": state.cursor_payload,
		"handcraft_queue": state.handcraft_queue,
		"completed_technologies": completed_technologies,
		"completed_objective_ids": completed_objective_ids,
		"claimed_progression_reward_ids": claimed_reward_ids,
		"completed_achievement_ids": completed_achievement_ids,
		"unlocked_progression_ids": unlocked_progression_ids,
		"buildings": _encode_entity_collection(state.buildings, BUILDING_RUNTIME_FIELDS),
		"connections": _encode_entity_collection(state.connections, CONNECTION_RUNTIME_FIELDS),
	}
	return _encode_dictionary(payload, ROOT_RUNTIME_FIELDS)

static func from_persistent_dict(payload: Variant) -> GameState:
	var migration_result := SaveMigrationRegistry.migrate_to_current(payload)
	if not migration_result.get("ok", false):
		return null

	var data: Dictionary = migration_result["data"]
	var state := GameState.new()
	state.elapsed_time = float(data["elapsed_time"])
	state.planet_inventory = data["planet_inventory"].duplicate(true)
	state.construction_inventory = data["construction_inventory"].duplicate(true)
	state.cursor_payload = data["cursor_payload"].duplicate(true)
	state.handcraft_queue = data["handcraft_queue"].duplicate(true)
	state.completed_technologies = data["completed_technologies"].duplicate(true)
	state.completed_objective_ids = data["completed_objective_ids"].duplicate(true)
	state.claimed_progression_reward_ids = data["claimed_progression_reward_ids"].duplicate(true)
	state.completed_achievement_ids = data["completed_achievement_ids"].duplicate(true)
	state.unlocked_progression_ids = data["unlocked_progression_ids"].duplicate(true)
	state._next_id = int(data["next_id"])
	state.buildings = _decode_buildings(data["buildings"])
	state.connections = _decode_connections(data["connections"])
	return state

static func state_digest_payload(state: GameState) -> Dictionary:
	return to_persistent_dict(state)

static func _encode_entity_collection(source: Dictionary, runtime_fields: Dictionary) -> Dictionary:
	var encoded: Dictionary = {}
	var keys: Array = source.keys()
	keys.sort()
	for key_value in keys:
		var entity_value: Variant = source[key_value]
		if entity_value is Dictionary:
			encoded[String(key_value)] = _encode_dictionary(entity_value, runtime_fields)
	return encoded

static func _encode_dictionary(source: Dictionary, excluded_fields: Dictionary = {}) -> Dictionary:
	var encoded: Dictionary = {}
	var keys: Array = source.keys()
	keys.sort_custom(func(left: Variant, right: Variant) -> bool:
		return String(left) < String(right)
	)
	for key_value in keys:
		var key := String(key_value)
		if excluded_fields.has(key):
			continue
		var encoded_value := _encode_value(source[key_value])
		if encoded_value.get("ok", false):
			encoded[key] = encoded_value.get("value")
	return encoded

static func _encode_value(value: Variant) -> Dictionary:
	match typeof(value):
		TYPE_NIL, TYPE_BOOL, TYPE_INT, TYPE_FLOAT, TYPE_STRING:
			return {"ok": true, "value": value}
		TYPE_STRING_NAME:
			return {"ok": true, "value": String(value)}
		TYPE_VECTOR2:
			return {"ok": true, "value": {"x": value.x, "y": value.y}}
		TYPE_DICTIONARY:
			return {"ok": true, "value": _encode_dictionary(value)}
		TYPE_ARRAY:
			var encoded_array: Array = []
			for item in value:
				var encoded_item := _encode_value(item)
				if encoded_item.get("ok", false):
					encoded_array.append(encoded_item.get("value"))
			return {"ok": true, "value": encoded_array}
		_:
			return {"ok": false}

static func _decode_buildings(encoded_buildings: Dictionary) -> Dictionary:
	var buildings: Dictionary = {}
	for building_id in encoded_buildings:
		var building: Dictionary = encoded_buildings[building_id].duplicate(true)
		var position: Dictionary = building.get("position", {})
		building["position"] = Vector2(float(position.get("x", 0.0)), float(position.get("y", 0.0)))
		building["status"] = "idle"
		buildings[String(building_id)] = building
	return buildings

static func _decode_connections(encoded_connections: Dictionary) -> Dictionary:
	var connections: Dictionary = {}
	for connection_id in encoded_connections:
		var connection: Dictionary = encoded_connections[connection_id].duplicate(true)
		connection["active"] = false
		connection["current_flow"] = 0.0
		var connection_type := String(connection.get("type", "conveyor_belt_mk1"))
		if connection_type == "belt" or connection_type.begins_with("conveyor_belt"):
			connection["construction_accounted"] = true
		connections[String(connection_id)] = connection
	return connections
