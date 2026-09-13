class_name BlueprintCodec
extends RefCounted

const VERSION := 1
const MAX_ENTITIES := 128
const MAX_CONNECTIONS := 256
const MAX_COORDINATE := 100000.0
const MAX_TEXT_LENGTH := 65536
const MAX_STRING_LENGTH := 256

const ROOT_KEYS := ["version", "entities", "connections"]
const ENTITY_KEYS := ["ref", "type", "position", "configuration"]
const CONNECTION_KEYS := ["source", "target", "type", "configuration"]
const ENTITY_CONFIGURATION_KEYS := ["recipe_id", "output_item", "spray_coater_installed", "proliferator_tier", "proliferator_mode"]
const CONNECTION_CONFIGURATION_KEYS := ["item_id", "parallel_count", "stack_size", "priority", "route_mode", "route_offset_y", "monitor_enabled", "enabled"]

func encode(blueprint: Dictionary) -> Dictionary:
	var normalized := validate_and_normalize(blueprint)
	if not normalized.get("ok", false):
		return normalized
	var json_value: Dictionary = normalized.blueprint.duplicate(true)
	for entity in json_value.entities:
		var position: Vector2 = entity.position
		entity.position = [position.x, position.y]
	var text := JSON.stringify(json_value)
	if text.length() > MAX_TEXT_LENGTH:
		return _failure("text_too_long", "蓝图文本超过长度限制")
	return {"ok": true, "text": text}

func decode(text: String) -> Dictionary:
	if text.length() > MAX_TEXT_LENGTH:
		return _failure("text_too_long", "蓝图文本超过长度限制")
	var parser := JSON.new()
	if parser.parse(text) != OK:
		return _failure("invalid_json", "蓝图不是有效 JSON")
	if not parser.data is Dictionary:
		return _failure("invalid_root", "蓝图根节点必须是对象")
	return validate_and_normalize(parser.data)

func validate_and_normalize(value: Dictionary) -> Dictionary:
	if not _has_exact_keys(value, ROOT_KEYS):
		return _failure("invalid_fields", "蓝图包含缺失或未允许的字段")
	if not _is_integer_number(value.get("version")):
		return _failure("invalid_version", "蓝图版本无效")
	if int(value.version) != VERSION:
		return _failure("unsupported_version", "仅支持蓝图 v1")
	if not value.get("entities") is Array or not value.get("connections") is Array:
		return _failure("invalid_collections", "蓝图实体与连接必须是数组")
	if value.entities.size() > MAX_ENTITIES:
		return _failure("too_many_entities", "蓝图实体数量超过限制")
	if value.connections.size() > MAX_CONNECTIONS:
		return _failure("too_many_connections", "蓝图连接数量超过限制")

	var normalized_entities: Array = []
	var references: Dictionary = {}
	for entity_value in value.entities:
		if not entity_value is Dictionary:
			return _failure("invalid_entity", "蓝图实体必须是对象")
		var entity: Dictionary = entity_value
		if not _has_exact_keys(entity, ENTITY_KEYS):
			return _failure("invalid_entity_fields", "蓝图实体字段无效")
		if not entity.get("ref") is String or not entity.get("type") is String:
			return _failure("invalid_reference", "蓝图实体引用和类型必须是字符串")
		var local_ref := String(entity.get("ref", ""))
		var building_type := String(entity.get("type", ""))
		if not _valid_identifier(local_ref) or not _valid_identifier(building_type) or references.has(local_ref):
			return _failure("invalid_reference", "蓝图实体引用无效或重复")
		var position_result := _normalize_position(entity.get("position"))
		if not position_result.get("ok", false):
			return position_result
		var configuration_result := _normalize_configuration(entity.get("configuration"), ENTITY_CONFIGURATION_KEYS)
		if not configuration_result.get("ok", false):
			return configuration_result
		references[local_ref] = true
		normalized_entities.append({"ref": local_ref, "type": building_type, "position": position_result.position, "configuration": configuration_result.configuration})

	var normalized_connections: Array = []
	for connection_value in value.connections:
		if not connection_value is Dictionary:
			return _failure("invalid_connection", "蓝图连接必须是对象")
		var connection: Dictionary = connection_value
		if not _has_exact_keys(connection, CONNECTION_KEYS):
			return _failure("invalid_connection_fields", "蓝图连接字段无效")
		if not connection.get("source") is String or not connection.get("target") is String or not connection.get("type") is String:
			return _failure("invalid_reference", "蓝图连接引用和类型必须是字符串")
		var source := String(connection.get("source", ""))
		var target := String(connection.get("target", ""))
		var connection_type := String(connection.get("type", ""))
		if not references.has(source) or not references.has(target) or source == target:
			return _failure("invalid_reference", "蓝图连接引用不存在")
		if not _valid_identifier(connection_type):
			return _failure("invalid_connection_type", "蓝图连接类型无效")
		var configuration_result := _normalize_configuration(connection.get("configuration"), CONNECTION_CONFIGURATION_KEYS)
		if not configuration_result.get("ok", false):
			return configuration_result
		var configuration: Dictionary = configuration_result.configuration
		for integer_key in ["parallel_count", "stack_size", "priority"]:
			if configuration.has(integer_key):
				configuration[integer_key] = int(configuration[integer_key])
		if configuration.has("route_offset_y"):
			configuration["route_offset_y"] = float(configuration.route_offset_y)
		if configuration.has("parallel_count") and (not _is_integer_number(configuration.parallel_count) or int(configuration.parallel_count) < 1 or int(configuration.parallel_count) > 4):
			return _failure("invalid_configuration", "蓝图并行线路数量无效")
		if configuration.has("stack_size") and (not _is_integer_number(configuration.stack_size) or not [1, 2, 4].has(int(configuration.stack_size))):
			return _failure("invalid_configuration", "蓝图线路堆叠数量无效")
		if configuration.has("priority") and (not _is_integer_number(configuration.priority) or not [0, 1, 2].has(int(configuration.priority))):
			return _failure("invalid_configuration", "蓝图线路优先级无效")
		if configuration.has("route_mode") and not ["bezier", "auto", "upper", "lower", "manual"].has(String(configuration.route_mode)):
			return _failure("invalid_configuration", "蓝图线路路径模式无效")
		if configuration.has("route_offset_y") and not _is_finite_number(configuration.route_offset_y):
			return _failure("invalid_configuration", "蓝图线路路径偏移无效")
		for toggle_key in ["monitor_enabled", "enabled"]:
			if configuration.has(toggle_key) and not configuration[toggle_key] is bool:
				return _failure("invalid_configuration", "蓝图线路开关字段无效")
		normalized_connections.append({"source": source, "target": target, "type": connection_type, "configuration": configuration})
	return {"ok": true, "blueprint": {"version": VERSION, "entities": normalized_entities, "connections": normalized_connections}}

func _normalize_position(value: Variant) -> Dictionary:
	var position := Vector2.ZERO
	if value is Vector2:
		position = value
	elif value is Array and value.size() == 2 and _is_finite_number(value[0]) and _is_finite_number(value[1]):
		position = Vector2(float(value[0]), float(value[1]))
	else:
		return _failure("invalid_position", "蓝图位置必须包含两个有限数值")
	if not is_finite(position.x) or not is_finite(position.y) or absf(position.x) > MAX_COORDINATE or absf(position.y) > MAX_COORDINATE:
		return _failure("coordinate_limit", "蓝图坐标超过限制")
	return {"ok": true, "position": position}

func _normalize_configuration(value: Variant, allowed_keys: Array) -> Dictionary:
	if not value is Dictionary:
		return _failure("invalid_configuration", "蓝图配置必须是对象")
	var configuration: Dictionary = value
	for key_value in configuration:
		var key := String(key_value)
		if not allowed_keys.has(key):
			return _failure("invalid_configuration_field", "蓝图配置包含未允许字段")
		var field_value: Variant = configuration[key_value]
		if ["recipe_id", "output_item", "item_id", "route_mode", "proliferator_mode"].has(key) and not field_value is String:
			return _failure("invalid_configuration_value", "蓝图配置文本字段类型无效")
		if ["parallel_count", "stack_size", "priority", "proliferator_tier"].has(key) and not _is_integer_number(field_value):
			return _failure("invalid_configuration_value", "蓝图配置整数字段类型无效")
		if key == "route_offset_y" and not _is_finite_number(field_value):
			return _failure("invalid_configuration_value", "蓝图配置数值字段类型无效")
		if ["monitor_enabled", "enabled", "spray_coater_installed"].has(key) and not field_value is bool:
			return _failure("invalid_configuration_value", "蓝图配置开关字段类型无效")
		if not (field_value is String or field_value is int or field_value is float or field_value is bool):
			return _failure("invalid_configuration_value", "蓝图配置值类型不受支持")
		if field_value is String and (String(field_value).length() > MAX_STRING_LENGTH or not _is_safe_text(String(field_value))):
			return _failure("invalid_text", "蓝图配置文本无效")
	return {"ok": true, "configuration": configuration.duplicate(true)}

func _has_exact_keys(value: Dictionary, allowed_keys: Array) -> bool:
	if value.size() != allowed_keys.size():
		return false
	for key_value in value:
		if not allowed_keys.has(String(key_value)):
			return false
	return true

func _valid_identifier(value: String) -> bool:
	return not value.is_empty() and value.length() <= MAX_STRING_LENGTH and value.is_valid_identifier()

func _is_safe_text(value: String) -> bool:
	for character in value:
		if character.unicode_at(0) < 32:
			return false
	return true

func _is_finite_number(value: Variant) -> bool:
	return (value is int or value is float) and is_finite(float(value))

func _is_integer_number(value: Variant) -> bool:
	return _is_finite_number(value) and is_equal_approx(float(value), float(int(value)))

func _failure(reason: String, message: String) -> Dictionary:
	return {"ok": false, "reason": reason, "message": message}
