class_name GalaxySystem
extends RefCounted

const DEFAULT_CATALOG_PATH := "res://data/galaxy.json"

var game_state: GameState
var _systems: Dictionary = {}
var _planets: Dictionary = {}
var _catalog_errors: Array = []

func _init(state: GameState, catalog_path: String = DEFAULT_CATALOG_PATH) -> void:
	game_state = state
	_load_catalog(catalog_path)

func get_catalog_errors() -> Array:
	return _catalog_errors.duplicate(true)

func get_star_system(system_id: String) -> Dictionary:
	return _systems.get(system_id, {}).duplicate(true)

func get_planet(planet_id: String) -> Dictionary:
	return _planets.get(planet_id, {}).duplicate(true)

func get_all_system_ids() -> Array:
	var ids: Array = _systems.keys()
	ids.sort()
	return ids

func get_all_planet_ids() -> Array:
	var ids: Array = _planets.keys()
	ids.sort()
	return ids

func get_all_star_systems() -> Dictionary:
	return _systems.duplicate(true)

func get_system_name(system_id: String) -> String:
	return String(_systems.get(system_id, {}).get("name", ""))

func get_system_code(system_id: String) -> String:
	return String(_systems.get(system_id, {}).get("code", ""))

func get_star_type(system_id: String) -> String:
	return String(_systems.get(system_id, {}).get("star_type", ""))

func get_system_color(system_id: String) -> String:
	return String(_systems.get(system_id, {}).get("color", "#ffffff"))

func get_system_distance(from_system_id: String, to_system_id: String) -> float:
	var from_system: Dictionary = _systems.get(from_system_id, {})
	var to_system: Dictionary = _systems.get(to_system_id, {})
	if from_system.is_empty() or to_system.is_empty():
		return 0.0
	return _to_vector2(from_system.get("position", {})).distance_to(_to_vector2(to_system.get("position", {})))

func get_system_description(system_id: String) -> String:
	return String(_systems.get(system_id, {}).get("description", ""))

func get_system_planets(system_id: String) -> Array:
	return _systems.get(system_id, {}).get("planet_ids", []).duplicate(true)

func get_exploration_cost(system_id: String) -> Array:
	return _systems.get(system_id, {}).get("exploration_cost", []).duplicate(true)

func get_prerequisite_system(system_id: String) -> String:
	return String(_systems.get(system_id, {}).get("prerequisite_system_id", ""))

func system_exists(system_id: String) -> bool:
	return _systems.has(system_id)

func get_system_count() -> int:
	return _systems.size()

func get_exploration_duration(system_id: String) -> float:
	return maxf(float(_systems.get(system_id, {}).get("survey_duration_seconds", 0.0)), 0.0)

func get_exploration_requirements(system_id: String) -> Dictionary:
	var system: Dictionary = _systems.get(system_id, {})
	if system.is_empty():
		return {}
	var materials: Dictionary = {}
	for cost_value in system.get("exploration_cost", []):
		if cost_value is Dictionary:
			materials[String(cost_value.get("item_id", ""))] = float(cost_value.get("amount", 0.0))
	var availability := _exploration_availability(system_id, materials)
	return {
		"system_id": system_id,
		"materials": materials,
		"required_technology_id": String(system.get("required_technology_id", "")),
		"prerequisite_system_id": String(system.get("prerequisite_system_id", "")),
		"duration_seconds": get_exploration_duration(system_id),
		"available": availability.get("ok", false),
		"reason": availability.get("reason", ""),
		"message": availability.get("message", ""),
	}.duplicate(true)

func try_explore_system(system_id: String) -> Dictionary:
	var requirements := get_exploration_requirements(system_id)
	if requirements.is_empty():
		return _failure("unknown_system", "目标星系不存在")
	var availability := _exploration_availability(system_id, requirements.get("materials", {}))
	if not availability.get("ok", false):
		return availability
	var next_inventory := game_state.planet_inventory.duplicate(true)
	for item_id_value in requirements["materials"]:
		var item_id := String(item_id_value)
		var remaining := float(next_inventory.get(item_id, 0.0)) - float(requirements["materials"][item_id])
		if remaining <= 0.0000001:
			next_inventory.erase(item_id)
		else:
			next_inventory[item_id] = remaining
	game_state.planet_inventories[game_state.active_planet_id] = next_inventory.duplicate(true)
	game_state.planet_inventory = game_state.planet_inventories[game_state.active_planet_id]
	var duration := float(requirements["duration_seconds"])
	game_state.exploration_missions.append({"system_id": system_id, "progress": 0.0, "duration_seconds": duration})
	game_state.survey_progress_by_system[system_id] = 0.0
	return _success("勘探任务已启动", {"system_id": system_id, "duration_seconds": duration})

func update_exploration(delta: float) -> void:
	var step := maxf(delta, 0.0)
	var remaining_missions: Array = []
	for mission_value in game_state.exploration_missions:
		if not mission_value is Dictionary:
			continue
		var mission: Dictionary = mission_value
		var system_id := String(mission.get("system_id", ""))
		var duration := maxf(float(mission.get("duration_seconds", 0.0)), 0.0)
		if system_id.is_empty() or duration <= 0.0 or not _systems.has(system_id) or game_state.explored_system_ids.has(system_id):
			continue
		var progress := minf(maxf(float(mission.get("progress", 0.0)), 0.0) + step, duration)
		mission["progress"] = progress
		game_state.survey_progress_by_system[system_id] = progress / duration
		if progress + 0.0000001 >= duration:
			game_state.explored_system_ids.append(system_id)
			game_state.explored_system_ids.sort()
			game_state.survey_progress_by_system[system_id] = 1.0
			_create_pioneer_landing(system_id)
		else:
			remaining_missions.append(mission)
	game_state.exploration_missions = remaining_missions

func search(query: String) -> Dictionary:
	var needle := query.strip_edges().to_lower()
	var system_ids: Array = []
	var planet_ids: Array = []
	for system_id in get_all_system_ids():
		if needle.is_empty() or needle in _system_search_text(String(system_id)):
			system_ids.append(String(system_id))
	for planet_id in get_all_planet_ids():
		if needle.is_empty() or needle in _planet_search_text(String(planet_id)):
			planet_ids.append(String(planet_id))
	return {"system_ids": system_ids, "planet_ids": planet_ids}

func get_system_summary(system_id: String) -> Dictionary:
	var system := get_star_system(system_id)
	if system.is_empty():
		return {}
	var requirements := get_exploration_requirements(system_id)
	var mission := _get_exploration_mission(system_id)
	var status := "explored" if game_state.explored_system_ids.has(system_id) else ("surveying" if not mission.is_empty() else "locked")
	system["distance"] = float(system.get("distance_ly", 0.0))
	system["exploration"] = {
		"status": status,
		"progress": float(game_state.survey_progress_by_system.get(system_id, 0.0)),
		"mission": mission,
		"requirements": requirements,
	}
	return system.duplicate(true)

func get_planet_summary(planet_id: String) -> Dictionary:
	var planet := get_planet(planet_id)
	if planet.is_empty():
		return {}
	var resource_item_ids: Array = []
	for site_value in planet.get("resource_sites", []):
		if site_value is Dictionary:
			var item_id := String(site_value.get("item_id", ""))
			if not item_id.is_empty() and not resource_item_ids.has(item_id):
				resource_item_ids.append(item_id)
	resource_item_ids.sort()
	planet["resource_item_ids"] = resource_item_ids
	var resource_sites: Array = []
	var live_sites := PlanetSystem.new(game_state, self).get_planet_resource_sites(planet_id)
	if live_sites.is_empty():
		var projected_sites := build_resource_sites_for_planet(planet_id, game_state.galaxy_seed)
		var projected_ids := projected_sites.keys()
		projected_ids.sort()
		for site_id in projected_ids:
			resource_sites.append(projected_sites[site_id].duplicate(true))
	else:
		resource_sites = live_sites
	planet["resource_sites"] = resource_sites
	planet["colonization"] = {
		"colonized": game_state.colonized_planet_ids.has(planet_id),
		"active": game_state.active_planet_id == planet_id,
		"requirements": _get_colonization_requirements(planet),
	}
	planet["industry"] = _get_planet_industry_summary(planet_id)
	return planet.duplicate(true)

func build_resource_sites_for_planet(planet_id: String, seed: int) -> Dictionary:
	var planet: Dictionary = _planets.get(planet_id, {})
	if planet.is_empty():
		return {}
	var built: Dictionary = {}
	for template_value in planet.get("resource_sites", []):
		if not template_value is Dictionary:
			continue
		var template: Dictionary = template_value
		var site_id := String(template.get("id", ""))
		var item_id := String(template.get("item_id", ""))
		var infinite := bool(template.get("infinite", false))
		var capacity := 0
		if not infinite:
			capacity = roundi(float(template.get("base_capacity", 0.0)) * _reserve_multiplier(seed, site_id, item_id))
		built[site_id] = {"id": site_id, "planet_id": planet_id, "item_id": item_id, "position": _to_vector2(template.get("position", {})), "capacity": capacity, "remaining": capacity, "infinite": infinite}
	return built

func _load_catalog(catalog_path: String) -> void:
	var file := FileAccess.open(catalog_path, FileAccess.READ)
	if file == null:
		_add_error("catalog_not_found", catalog_path)
		return
	var json := JSON.new()
	var parse_error := json.parse(file.get_as_text())
	file.close()
	if parse_error != OK or not json.data is Dictionary:
		_add_error("invalid_catalog_json", catalog_path)
		return
	var catalog: Dictionary = json.data
	if not catalog.get("systems") is Array or not catalog.get("planets") is Array:
		_add_error("invalid_catalog_shape", catalog_path)
		return
	for value in catalog["systems"]:
		if not value is Dictionary:
			_add_error("invalid_system", "")
			continue
		var system: Dictionary = value.duplicate(true)
		var system_id := String(system.get("id", ""))
		if system_id.is_empty() or _systems.has(system_id):
			_add_error("duplicate_system_id", system_id)
			continue
		_systems[system_id] = system
	for value in catalog["planets"]:
		if not value is Dictionary:
			_add_error("invalid_planet", "")
			continue
		var planet: Dictionary = value.duplicate(true)
		var planet_id := String(planet.get("id", ""))
		if planet_id.is_empty() or _planets.has(planet_id):
			_add_error("duplicate_planet_id", planet_id)
			continue
		_planets[planet_id] = planet
	_validate_catalog()

func _validate_catalog() -> void:
	var global_site_ids: Dictionary = {}
	for system_id_value in _systems:
		var system_id := String(system_id_value)
		var system: Dictionary = _systems[system_id_value]
		if not _is_finite_number(system.get("distance_ly")) or float(system.get("distance_ly")) < 0.0:
			_add_error("invalid_distance", system_id)
		var prerequisite := String(system.get("prerequisite_system_id", ""))
		if not prerequisite.is_empty() and not _systems.has(prerequisite):
			_add_error("unknown_prerequisite_system", system_id)
		_validate_technology(system.get("required_technology_id", ""), system_id)
		_validate_costs(system.get("exploration_cost", []), system_id)
		var seen: Dictionary = {}
		for planet_id_value in system.get("planet_ids", []):
			var planet_id := String(planet_id_value)
			if planet_id.is_empty() or seen.has(planet_id) or not _planets.has(planet_id):
				_add_error("unknown_planet_reference", "%s:%s" % [system_id, planet_id])
			seen[planet_id] = true
	for planet_id_value in _planets:
		var planet_id := String(planet_id_value)
		var planet: Dictionary = _planets[planet_id_value]
		var system_id := String(planet.get("system_id", ""))
		if not _systems.has(system_id) or not _systems.get(system_id, {}).get("planet_ids", []).has(planet_id):
			_add_error("unknown_system_reference", planet_id)
		_validate_technology(planet.get("required_technology_id", ""), planet_id)
		_validate_costs(planet.get("colonization_cost", []), planet_id)
		var seen_sites: Dictionary = {}
		for value in planet.get("resource_sites", []):
			if not value is Dictionary:
				_add_error("invalid_resource_site", planet_id)
				continue
			var site: Dictionary = value
			var site_id := String(site.get("id", ""))
			if site_id.is_empty() or seen_sites.has(site_id) or global_site_ids.has(site_id):
				_add_error("duplicate_resource_site_id", site_id)
			seen_sites[site_id] = true
			global_site_ids[site_id] = true
			if DataManager.get_item(String(site.get("item_id", ""))).is_empty():
				_add_error("unknown_item_reference", String(site.get("item_id", "")))
			if not bool(site.get("infinite", false)) and (not _is_finite_number(site.get("base_capacity")) or float(site.get("base_capacity")) <= 0.0):
				_add_error("invalid_resource_capacity", site_id)

func _validate_costs(costs: Variant, owner_id: String) -> void:
	if not costs is Array:
		_add_error("invalid_cost", owner_id)
		return
	for value in costs:
		if not value is Dictionary:
			_add_error("invalid_cost", owner_id)
			continue
		var cost: Dictionary = value
		if DataManager.get_item(String(cost.get("item_id", ""))).is_empty():
			_add_error("unknown_item_reference", String(cost.get("item_id", "")))
		if not _is_finite_number(cost.get("amount")) or float(cost.get("amount")) <= 0.0:
			_add_error("invalid_cost", owner_id)

func _validate_technology(value: Variant, owner_id: String) -> void:
	var technology_id := String(value)
	if not technology_id.is_empty() and DataManager.get_technology(technology_id).is_empty():
		_add_error("unknown_technology_reference", owner_id)

func _reserve_multiplier(seed: int, site_id: String, item_id: String) -> float:
	var stable_hash := ("%d|%s|%s" % [seed, site_id, item_id]).hash() & 0x7fffffff
	return 0.85 + float(stable_hash % 3001) / 10000.0

func _exploration_availability(system_id: String, materials: Dictionary) -> Dictionary:
	if not _systems.has(system_id):
		return _failure("unknown_system", "目标星系不存在")
	if game_state.explored_system_ids.has(system_id):
		return _failure("already_explored", "目标星系已完成勘探")
	if not _get_exploration_mission(system_id).is_empty():
		return _failure("mission_running", "目标星系已有勘探任务")
	var system: Dictionary = _systems[system_id]
	var technology_id := String(system.get("required_technology_id", ""))
	if not technology_id.is_empty() and not game_state.completed_technologies.has(technology_id):
		return _failure("technology_locked", "缺少勘探所需科技")
	var prerequisite_id := String(system.get("prerequisite_system_id", ""))
	if not prerequisite_id.is_empty() and not game_state.explored_system_ids.has(prerequisite_id):
		return _failure("prerequisite_locked", "前置星系尚未探索", {"system_id": prerequisite_id})
	var material_ids := materials.keys()
	material_ids.sort()
	for item_id_value in material_ids:
		var item_id := String(item_id_value)
		var required := float(materials[item_id])
		if float(game_state.planet_inventory.get(item_id, 0.0)) + 0.0000001 < required:
			return _failure("missing_materials", "活动行星勘探材料不足", {"item_id": item_id, "required": required})
	if get_exploration_duration(system_id) <= 0.0:
		return _failure("invalid_duration", "目标星系没有有效勘探时长")
	return _success("可以启动勘探")

func _get_exploration_mission(system_id: String) -> Dictionary:
	for mission_value in game_state.exploration_missions:
		if mission_value is Dictionary and String(mission_value.get("system_id", "")) == system_id:
			return mission_value.duplicate(true)
	return {}

func _create_pioneer_landing(system_id: String) -> void:
	var planet_ids: Array = _systems.get(system_id, {}).get("planet_ids", [])
	if planet_ids.is_empty():
		return
	var planet_id := String(planet_ids[0])
	if planet_id.is_empty() or game_state.colonized_planet_ids.has(planet_id):
		return
	game_state.colonized_planet_ids.append(planet_id)
	game_state.colonized_planet_ids.sort()
	game_state.planet_inventories[planet_id] = {}
	game_state.planet_viewports[planet_id] = {"position": Vector2.ZERO, "zoom": Vector2.ONE}
	game_state.planet_metrics[planet_id] = {}
	var sites := build_resource_sites_for_planet(planet_id, game_state.galaxy_seed)
	for site_id in sites:
		game_state.resource_sites[site_id] = sites[site_id]

func _system_search_text(system_id: String) -> String:
	var system: Dictionary = _systems.get(system_id, {})
	return " ".join([
		system_id,
		String(system.get("name", "")),
		String(system.get("code", "")),
		String(system.get("star_type", "")),
		String(system.get("description", "")),
	]).to_lower()

func _planet_search_text(planet_id: String) -> String:
	var planet: Dictionary = _planets.get(planet_id, {})
	var terms: Array[String] = [
		planet_id,
		String(planet.get("name", "")),
		String(planet.get("code", "")),
		String(planet.get("planet_type", "")),
		String(planet.get("kind", "")),
		String(planet.get("system_id", "")),
	]
	for site_value in planet.get("resource_sites", []):
		if not site_value is Dictionary:
			continue
		var item_id := String(site_value.get("item_id", ""))
		terms.append(item_id)
		terms.append(String(DataManager.get_item(item_id).get("name", "")))
	return " ".join(terms).to_lower()

func _get_colonization_requirements(planet: Dictionary) -> Dictionary:
	var materials: Dictionary = {}
	var vehicles: Dictionary = {}
	for cost_value in planet.get("colonization_cost", []):
		if not cost_value is Dictionary:
			continue
		var item_id := String(cost_value.get("item_id", ""))
		var amount := float(cost_value.get("amount", 0.0))
		if item_id.begins_with("logistics_"):
			vehicles[item_id] = amount
		else:
			materials[item_id] = amount
	return {
		"planet_id": String(planet.get("id", "")),
		"materials": materials,
		"vehicles": vehicles,
		"required_technology_id": String(planet.get("required_technology_id", "")),
		"system_id": String(planet.get("system_id", "")),
	}

func _get_planet_industry_summary(planet_id: String) -> Dictionary:
	var building_count := 0
	var running_count := 0
	var blocked_count := 0
	var generation := 0.0
	var demand := 0.0
	for building_value in game_state.buildings.values():
		if building_value is Dictionary and String(building_value.get("planet_id", "")) == planet_id:
			building_count += 1
			var status := String(building_value.get("status", "idle"))
			if status == "running":
				running_count += 1
			elif status in ["blocked", "no_power", "no_fuel", "resource_depleted", "invalid_resource_site", "error"]:
				blocked_count += 1
			generation += maxf(float(building_value.get("power_output", 0.0)), 0.0)
			var definition := DataManager.get_building(String(building_value.get("type", "")))
			demand += maxf(float(definition.get("power_demand", 0.0)), 0.0)
	var connection_count := 0
	for connection_value in game_state.connections.values():
		if connection_value is Dictionary and String(connection_value.get("planet_id", "")) == planet_id:
			connection_count += 1
	var resource_site_count := 0
	for site_value in game_state.resource_sites.values():
		if site_value is Dictionary and String(site_value.get("planet_id", "")) == planet_id:
			resource_site_count += 1
	return {
		"planet_id": planet_id,
		"building_count": building_count,
		"connection_count": connection_count,
		"resource_site_count": resource_site_count,
		"running_count": running_count,
		"blocked_count": blocked_count,
		"generation": generation,
		"demand": demand,
		"inventory": game_state.get_planet_inventory(planet_id).duplicate(true),
	}

func _to_vector2(value: Variant) -> Vector2:
	if value is Vector2:
		return value
	if value is Dictionary:
		return Vector2(float(value.get("x", 0.0)), float(value.get("y", 0.0)))
	return Vector2.ZERO

func _is_finite_number(value: Variant) -> bool:
	return (typeof(value) == TYPE_INT or typeof(value) == TYPE_FLOAT) and not is_nan(float(value)) and not is_inf(float(value))

func _add_error(code: String, id: String) -> void:
	_catalog_errors.append({"code": code, "id": id})

func _success(message: String, details: Dictionary = {}) -> Dictionary:
	return {"ok": true, "reason": "", "message": message, "details": details}

func _failure(reason: String, message: String, details: Dictionary = {}) -> Dictionary:
	return {"ok": false, "reason": reason, "message": message, "details": details}
