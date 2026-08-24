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
			_:
				return _failure("missing_migration", "缺少从版本 %d 开始的迁移" % version)

	for integer_field in ["next_id", "construction_points"]:
		var field_value: Variant = migrated.get(integer_field)
		if _is_integral_number(field_value):
			migrated[integer_field] = int(field_value)

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

static func _failure(code: String, message: String) -> Dictionary:
	return {
		"ok": false,
		"data": {},
		"errors": [{"code": code, "source": "migration", "id": "", "message": message}],
	}

static func _is_integral_number(value: Variant) -> bool:
	return (typeof(value) == TYPE_INT or typeof(value) == TYPE_FLOAT) and float(value) == floor(float(value))
