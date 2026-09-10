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
	"power_input": true,
	"power_requested": true,
	"power_covered": true,
}
const CONNECTION_RUNTIME_FIELDS := {
	"active": true,
	"current_flow": true,
	"construction_accounted": true,
}

static func to_persistent_dict(state: GameState) -> Dictionary:
	state.sync_active_planet_inventory()
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
	var research_queue: Array = state.research_queue.duplicate(true)
	var research_progress := state.research_progress.duplicate(true)
	var research_invested_costs := state.research_invested_costs.duplicate(true)
	var endgame_payload := {"endgame": state.endgame.duplicate(true)}
	EndgameStateValidator.normalize_integer_fields(endgame_payload)
	var payload := {
		"schema_version": GameState.SCHEMA_VERSION,
		"next_id": state._next_id,
		"elapsed_time": state.elapsed_time,
		"active_planet_id": state.active_planet_id,
		"galaxy_seed": state.galaxy_seed,
		"explored_system_ids": state.explored_system_ids,
		"colonized_planet_ids": state.colonized_planet_ids,
		"exploration_missions": state.exploration_missions,
		"survey_progress_by_system": state.survey_progress_by_system,
		"planet_inventories": state.planet_inventories,
		"planet_viewports": state.planet_viewports,
		"planet_metrics": state.planet_metrics,
		"portable_fleet": state.portable_fleet,
		"resource_sites": state.resource_sites,
		"logistics_routes": state.logistics_routes,
		"dyson_systems": state.dyson_systems,
		"dyson_tick": state.dyson_tick,
		"endgame": endgame_payload.endgame,
		"interplanetary_delivered": state.interplanetary_delivered,
		"construction_inventory": state.construction_inventory,
		"cursor_payload": state.cursor_payload,
		"handcraft_queue": _encode_handcraft_queue(state.handcraft_queue),
		"completed_technologies": completed_technologies,
		"research_current_id": state.research_current_id,
		"research_queue": research_queue,
		"research_progress": research_progress,
		"research_invested_costs": research_invested_costs,
		"research_paused": state.research_paused,
		"research_queue_wait_reason": state.research_queue_wait_reason,
		"technology_levels": state.technology_levels,
		"completed_objective_ids": completed_objective_ids,
		"claimed_progression_reward_ids": claimed_reward_ids,
		"completed_achievement_ids": completed_achievement_ids,
		"unlocked_progression_ids": unlocked_progression_ids,
		"buildings": _encode_entity_collection(state.buildings, BUILDING_RUNTIME_FIELDS, state.active_planet_id),
		"connections": _encode_connections(state),
	}
	return _encode_dictionary(payload, ROOT_RUNTIME_FIELDS)

static func from_persistent_dict(payload: Variant) -> GameState:
	var migration_result := SaveMigrationRegistry.migrate_to_current(payload)
	if not migration_result.get("ok", false):
		return null

	var data: Dictionary = migration_result["data"]
	var state := GameState.new()
	state.elapsed_time = float(data["elapsed_time"])
	state.active_planet_id = String(data["active_planet_id"])
	state.galaxy_seed = int(data["galaxy_seed"])
	state.explored_system_ids = data["explored_system_ids"].duplicate(true)
	state.colonized_planet_ids = data["colonized_planet_ids"].duplicate(true)
	state.exploration_missions = data["exploration_missions"].duplicate(true)
	state.survey_progress_by_system = data["survey_progress_by_system"].duplicate(true)
	state.planet_inventories = data["planet_inventories"].duplicate(true)
	state.planet_viewports = _decode_viewports(data["planet_viewports"])
	state.planet_metrics = data["planet_metrics"].duplicate(true)
	state.portable_fleet = data["portable_fleet"].duplicate(true)
	state.resource_sites = _decode_resource_sites(data["resource_sites"])
	state.dyson_systems = data["dyson_systems"].duplicate(true)
	state.dyson_tick = int(data["dyson_tick"])
	state.endgame = data["endgame"].duplicate(true)
	state.logistics_routes = data["logistics_routes"].duplicate(true)
	for route in state.logistics_routes.values():
		route.source_slot = int(route.source_slot)
		route.target_slot = int(route.target_slot)
	state.interplanetary_delivered = float(data["interplanetary_delivered"])
	state.construction_inventory = data["construction_inventory"].duplicate(true)
	state.cursor_payload = data["cursor_payload"].duplicate(true)
	state.handcraft_queue = data["handcraft_queue"].duplicate(true)
	state.completed_technologies = data["completed_technologies"].duplicate(true)
	state.research_current_id = String(data["research_current_id"])
	state.research_queue = data["research_queue"].duplicate(true)
	state.research_progress = data["research_progress"].duplicate(true)
	state.research_invested_costs = data["research_invested_costs"].duplicate(true)
	state.research_paused = bool(data["research_paused"])
	state.research_queue_wait_reason = String(data["research_queue_wait_reason"])
	state.technology_levels = data["technology_levels"].duplicate(true)
	state.completed_objective_ids = data["completed_objective_ids"].duplicate(true)
	state.claimed_progression_reward_ids = data["claimed_progression_reward_ids"].duplicate(true)
	state.completed_achievement_ids = data["completed_achievement_ids"].duplicate(true)
	state.unlocked_progression_ids = data["unlocked_progression_ids"].duplicate(true)
	state._next_id = int(data["next_id"])
	state.buildings = _decode_buildings(data["buildings"])
	state.connections = _decode_connections(data["connections"])
	state.planet_inventory = state.get_active_planet_inventory()
	state.sync_active_planet_inventory()
	return state

static func state_digest_payload(state: GameState) -> Dictionary:
	return to_persistent_dict(state)

static func _encode_entity_collection(source: Dictionary, runtime_fields: Dictionary, fallback_planet_id: String) -> Dictionary:
	var encoded: Dictionary = {}
	var keys: Array = source.keys()
	keys.sort()
	for key_value in keys:
		var entity_value: Variant = source[key_value]
		if entity_value is Dictionary:
			var entity: Dictionary = entity_value.duplicate(true)
			if String(entity.get("planet_id", "")).is_empty():
				entity["planet_id"] = fallback_planet_id
			encoded[String(key_value)] = _encode_dictionary(entity, runtime_fields)
	return encoded

static func _encode_handcraft_queue(source: Array) -> Array:
	var encoded: Array = []
	for value in source:
		if not value is Dictionary:
			encoded.append(value)
			continue
		encoded.append(value.duplicate(true))
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
		if building.has("station"):
			for item in building.station.fleet:
				building.station.fleet[item] = int(building.station.fleet[item])
			for slot in building.station.slots:
				slot.cursor = int(slot.cursor)
				slot.priority = int(slot.priority)
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

static func _decode_viewports(encoded_viewports: Dictionary) -> Dictionary:
	var viewports := encoded_viewports.duplicate(true)
	for planet_id in viewports:
		var viewport: Dictionary = viewports[planet_id]
		viewport["position"] = _vector2_from_value(viewport.get("position", {}))
		viewport["zoom"] = _vector2_from_value(viewport.get("zoom", {}))
	return viewports

static func _decode_resource_sites(encoded_sites: Dictionary) -> Dictionary:
	var sites := encoded_sites.duplicate(true)
	for site_id in sites:
		var site: Dictionary = sites[site_id]
		site["position"] = _vector2_from_value(site.get("position", {}))
	return sites

static func _vector2_from_value(value: Variant) -> Vector2:
	if value is Vector2:
		return value
	if value is Dictionary:
		return Vector2(float(value.get("x", 0.0)), float(value.get("y", 0.0)))
	return Vector2.ZERO

static func _encode_connections(state: GameState) -> Dictionary:
	var encoded := _encode_entity_collection(state.connections, CONNECTION_RUNTIME_FIELDS, state.active_planet_id)
	for connection in encoded.values():
		for field in ["priority", "parallel_count", "stack_size"]:
			if connection.get(field) is int:
				connection[field] = float(connection[field])
	return encoded
