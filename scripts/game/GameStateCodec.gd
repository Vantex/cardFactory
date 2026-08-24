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
}
const CONNECTION_RUNTIME_FIELDS := {
	"active": true,
	"current_flow": true,
}

static func to_persistent_dict(state: GameState) -> Dictionary:
	var completed_technologies: Array = state.completed_technologies.duplicate(true)
	completed_technologies.sort()
	var payload := {
		"schema_version": GameState.SCHEMA_VERSION,
		"next_id": state._next_id,
		"elapsed_time": state.elapsed_time,
		"construction_points": state.construction_points,
		"completed_technologies": completed_technologies,
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
	state.construction_points = int(data["construction_points"])
	state.completed_technologies = data["completed_technologies"].duplicate(true)
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
		connections[String(connection_id)] = connection
	return connections
