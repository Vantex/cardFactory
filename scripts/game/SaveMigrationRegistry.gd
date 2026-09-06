class_name SaveMigrationRegistry
extends RefCounted

static func migrate_to_current(payload: Variant) -> Dictionary:
	if not payload is Dictionary:
		return _failure("invalid_root", "存档根节点必须是字典")

	var migrated: Dictionary = payload.duplicate(true)
	var version_value: Variant = migrated.get("schema_version", 0)
	if not _is_integral_number(version_value):
		return _failure("invalid_schema_version", "存档版本必须是整数")

	var version := int(version_value)
	migrated["schema_version"] = version
	if version > GameState.SCHEMA_VERSION:
		return _failure("unsupported_future_version", "存档来自尚不支持的未来版本")
	if version < 0:
		return _failure("unsupported_legacy_version", "存档版本不能为负数")

	while version < GameState.SCHEMA_VERSION:
		match version:
			0:
				migrated = _migrate_v0_to_v1(migrated)
				version = 1
			1:
				migrated = _migrate_v1_to_v2(migrated)
				version = 2
			2:
				migrated = _migrate_v2_to_v3(migrated)
				version = 3
			3:
				migrated = _migrate_v3_to_v4(migrated)
				version = 4
			4:
				migrated = _migrate_v4_to_v5(migrated)
				version = 5
			5:
				migrated = _migrate_v5_to_v6(migrated)
				version = 6
			6:
				migrated["schema_version"] = 7
				migrated["logistics_routes"] = {}
				migrated["interplanetary_delivered"] = 0.0
				if migrated.get("buildings") is Dictionary:
					for building in migrated.buildings.values():
						if building is Dictionary and building.get("type", "") in StationSystem.TYPES:
							building["station"] = StationSystem.empty_station()
							if not building.has("input_buffer"):
								building["input_buffer"] = {}
							if not building.has("output_buffer"):
								building["output_buffer"] = {}
				version = 7
			7:
				migrated["schema_version"] = 8
				migrated["dyson_systems"] = {}
				migrated["dyson_tick"] = 0
				version = 8
			8:
				migrated["schema_version"] = 9
				migrated["endgame"] = EndgameSystem.initial_state()
				version = 9
			_:
				return _failure("missing_migration", "缺少从版本 %d 开始的迁移" % version)

	for integer_field in ["next_id", "galaxy_seed"]:
		var field_value: Variant = migrated.get(integer_field)
		if _is_integral_number(field_value):
			migrated[integer_field] = int(field_value)
	var handcraft_queue_value: Variant = migrated.get("handcraft_queue")
	if handcraft_queue_value is Array:
		for job_value in handcraft_queue_value:
			if not job_value is Dictionary:
				continue
			for quantity_field in ["quantity_total", "quantity_remaining"]:
				var quantity_value: Variant = job_value.get(quantity_field)
				if _is_integral_number(quantity_value):
					job_value[quantity_field] = int(quantity_value)
	var technology_levels_value: Variant = migrated.get("technology_levels")
	if technology_levels_value is Dictionary:
		for technology_id_value in technology_levels_value:
			var level_value: Variant = technology_levels_value[technology_id_value]
			if _is_integral_number(level_value):
				technology_levels_value[technology_id_value] = int(level_value)
	var portable_fleet_value: Variant = migrated.get("portable_fleet")
	if portable_fleet_value is Dictionary:
		for fleet_item_id in portable_fleet_value:
			var fleet_amount: Variant = portable_fleet_value[fleet_item_id]
			if _is_integral_number(fleet_amount):
				portable_fleet_value[fleet_item_id] = int(fleet_amount)

	LogisticsStateValidator.normalize_integer_fields(migrated)
	DysonStateValidator.normalize_integer_fields(migrated)
	EndgameStateValidator.normalize_integer_fields(migrated)
	var validation_errors := GameStateValidator.validate_persistent_dict(migrated)
	if not validation_errors.is_empty():
		return {"ok": false, "data": {}, "errors": validation_errors}
	return {"ok": true, "data": migrated, "errors": []}

static func _migrate_v0_to_v1(legacy: Dictionary) -> Dictionary:
	var migrated: Dictionary = legacy.duplicate(true)
	migrated.erase("version")
	migrated.erase("timestamp")
	migrated["schema_version"] = 1
	if not migrated.has("next_id"):
		migrated["next_id"] = 1
	if not migrated.has("elapsed_time"):
		migrated["elapsed_time"] = 0.0
	if not migrated.has("construction_points"):
		migrated["construction_points"] = 12
	if not migrated.has("completed_technologies"):
		migrated["completed_technologies"] = []
	if not migrated.has("buildings"):
		migrated["buildings"] = {}
	if not migrated.has("connections"):
		migrated["connections"] = {}

	var buildings_value: Variant = migrated["buildings"]
	if buildings_value is Dictionary:
		for building_value in buildings_value.values():
			if building_value is Dictionary and building_value.get("position") is Vector2:
				var position: Vector2 = building_value["position"]
				building_value["position"] = {"x": position.x, "y": position.y}
	return migrated

static func _migrate_v1_to_v2(legacy: Dictionary) -> Dictionary:
	var migrated: Dictionary = legacy.duplicate(true)
	var legacy_points := maxf(float(migrated.get("construction_points", 0.0)), 0.0)
	migrated.erase("construction_points")
	migrated["schema_version"] = 2
	if not migrated.has("planet_inventory"):
		migrated["planet_inventory"] = {}
	if not migrated.has("construction_inventory"):
		migrated["construction_inventory"] = {}
	if legacy_points > 0.0:
		migrated["construction_inventory"]["legacy_credit"] = legacy_points
	if not migrated.has("cursor_payload"):
		migrated["cursor_payload"] = {"item_id": "", "amount": 0.0}
	if not migrated.has("handcraft_queue"):
		migrated["handcraft_queue"] = []
	return migrated

static func _migrate_v2_to_v3(legacy: Dictionary) -> Dictionary:
	var migrated: Dictionary = legacy.duplicate(true)
	migrated["schema_version"] = 3
	for field in ["completed_objective_ids", "claimed_progression_reward_ids", "completed_achievement_ids", "unlocked_progression_ids"]:
		if not migrated.has(field):
			migrated[field] = []
	return migrated

static func _migrate_v3_to_v4(legacy: Dictionary) -> Dictionary:
	var migrated: Dictionary = legacy.duplicate(true)
	migrated["schema_version"] = 4
	for field in ["research_queue", "research_progress", "research_invested_costs"]:
		if not migrated.has(field):
			migrated[field] = [] if field == "research_queue" else {}
	if not migrated.has("research_current_id"):
		migrated["research_current_id"] = ""
	if not migrated.has("research_paused"):
		migrated["research_paused"] = false
	return migrated

static func _migrate_v4_to_v5(legacy: Dictionary) -> Dictionary:
	var migrated := legacy.duplicate(true)
	migrated["schema_version"] = 5
	migrated["research_queue_wait_reason"] = String(migrated.get("research_queue_wait_reason", ""))
	var levels_value: Variant = migrated.get("technology_levels", {})
	var levels: Dictionary = levels_value.duplicate(true) if levels_value is Dictionary else {}
	var completed_value: Variant = migrated.get("completed_technologies", [])
	if completed_value is Array:
		for technology_id_value in completed_value:
			var technology_id := String(technology_id_value)
			var technology := DataManager.get_technology(technology_id)
			if not technology.is_empty() and technology.has("repeatable") and not levels.has(technology_id):
				levels[technology_id] = 1
	migrated["technology_levels"] = levels
	return migrated

static func _migrate_v5_to_v6(legacy: Dictionary) -> Dictionary:
	var migrated := legacy.duplicate(true)
	var legacy_inventory: Variant = migrated.get("planet_inventory", {})
	migrated.erase("planet_inventory")
	migrated["schema_version"] = 6
	migrated["active_planet_id"] = GameState.HOME_PLANET_ID
	migrated["galaxy_seed"] = 240721
	migrated["explored_system_ids"] = ["helios"]
	migrated["colonized_planet_ids"] = [GameState.HOME_PLANET_ID]
	migrated["exploration_missions"] = []
	migrated["survey_progress_by_system"] = {"helios": 1.0}
	migrated["planet_inventories"] = {GameState.HOME_PLANET_ID: legacy_inventory.duplicate(true) if legacy_inventory is Dictionary else {}}
	migrated["planet_viewports"] = {}
	migrated["planet_metrics"] = {}
	migrated["portable_fleet"] = {"logistics_drone": 0, "logistics_vessel": 0}
	migrated["resource_sites"] = {}
	var galaxy := GalaxySystem.new(GameState.new())
	for planet_id in galaxy.get_all_planet_ids():
		migrated["planet_viewports"][planet_id] = {"position": {"x": 0.0, "y": 0.0}, "zoom": {"x": 1.0, "y": 1.0}}
		migrated["planet_metrics"][planet_id] = {}
		for site_id in galaxy.build_resource_sites_for_planet(String(planet_id), int(migrated["galaxy_seed"])):
			var site: Dictionary = galaxy.build_resource_sites_for_planet(String(planet_id), int(migrated["galaxy_seed"]))[site_id]
			var persisted_site := site.duplicate(true)
			var position: Vector2 = persisted_site.get("position", Vector2.ZERO)
			persisted_site["position"] = {"x": position.x, "y": position.y}
			migrated["resource_sites"][site_id] = persisted_site
	for collection_name in ["buildings", "connections"]:
		var collection: Variant = migrated.get(collection_name, {})
		if collection is Dictionary:
			for entity_id in collection:
				if collection[entity_id] is Dictionary:
					collection[entity_id]["planet_id"] = GameState.HOME_PLANET_ID
	var jobs: Variant = migrated.get("handcraft_queue", [])
	if jobs is Array:
		for job in jobs:
			if job is Dictionary:
				job["planet_id"] = GameState.HOME_PLANET_ID
	_bind_legacy_home_extractors(migrated)
	return migrated

static func _bind_legacy_home_extractors(migrated: Dictionary) -> void:
	var buildings: Variant = migrated.get("buildings", {})
	var sites: Variant = migrated.get("resource_sites", {})
	if not buildings is Dictionary or not sites is Dictionary:
		return
	var building_ids: Array = buildings.keys()
	building_ids.sort()
	for building_id_value in building_ids:
		var building: Dictionary = buildings[building_id_value]
		var item_id := String(building.get("output_item", ""))
		if item_id.is_empty():
			continue
		var candidates: Array = []
		var building_position: Dictionary = building.get("position", {})
		for site_id_value in sites:
			var site: Dictionary = sites[site_id_value]
			if String(site.get("planet_id", "")) == GameState.HOME_PLANET_ID and String(site.get("item_id", "")) == item_id:
				var site_position: Dictionary = site.get("position", {})
				var dx := float(building_position.get("x", 0.0)) - float(site_position.get("x", 0.0))
				var dy := float(building_position.get("y", 0.0)) - float(site_position.get("y", 0.0))
				candidates.append({"id": String(site_id_value), "distance_squared": dx * dx + dy * dy})
		candidates.sort_custom(func(left: Dictionary, right: Dictionary) -> bool:
			if not is_equal_approx(float(left["distance_squared"]), float(right["distance_squared"])):
				return float(left["distance_squared"]) < float(right["distance_squared"])
			return String(left["id"]) < String(right["id"])
		)
		if not candidates.is_empty():
			building["resource_site_id"] = candidates[0]["id"]

static func _failure(code: String, message: String) -> Dictionary:
	return {
		"ok": false,
		"data": {},
		"errors": [{"code": code, "source": "migration", "id": "", "message": message}],
	}

static func _is_integral_number(value: Variant) -> bool:
	return (typeof(value) == TYPE_INT or typeof(value) == TYPE_FLOAT) and float(value) == floor(float(value))
