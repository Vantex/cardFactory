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

func get_system_distance(system_id: String) -> float:
	return float(_systems.get(system_id, {}).get("distance_ly", 0.0))

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
