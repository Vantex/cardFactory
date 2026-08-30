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
			_:
				return _failure("missing_migration", "缺少从版本 %d 开始的迁移" % version)

	for integer_field in ["next_id"]:
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

static func _failure(code: String, message: String) -> Dictionary:
	return {
		"ok": false,
		"data": {},
		"errors": [{"code": code, "source": "migration", "id": "", "message": message}],
	}

static func _is_integral_number(value: Variant) -> bool:
	return (typeof(value) == TYPE_INT or typeof(value) == TYPE_FLOAT) and float(value) == floor(float(value))
