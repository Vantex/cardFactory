class_name GameStateValidator
extends RefCounted

static func validate_persistent_dict(payload: Variant) -> Array:
	var errors: Array = []
	if not payload is Dictionary:
		_add_error(errors, "invalid_root", "state", "", "存档根节点必须是字典")
		return errors

	var data: Dictionary = payload
	if not _is_integral_number(data.get("schema_version")) or int(data.get("schema_version")) != GameState.SCHEMA_VERSION:
		_add_error(errors, "invalid_schema_version", "state", "", "存档版本无效")

	var next_id: Variant = data.get("next_id")
	if not _is_integral_number(next_id) or int(next_id) < 1:
		_add_error(errors, "invalid_next_id", "state", "", "下一实体 ID 必须是正整数")

	var elapsed_time: Variant = data.get("elapsed_time")
	if not _is_number(elapsed_time) or float(elapsed_time) < 0.0:
		_add_error(errors, "invalid_elapsed_time", "state", "", "累计时间必须是非负数")

	var construction_points: Variant = data.get("construction_points")
	if not _is_integral_number(construction_points) or int(construction_points) < 0:
		_add_error(errors, "invalid_construction_points", "state", "", "建造点必须是非负整数")

	if not data.get("completed_technologies") is Array:
		_add_error(errors, "invalid_completed_technologies", "state", "", "已完成科技必须是数组")

	var buildings_value: Variant = data.get("buildings")
	var connections_value: Variant = data.get("connections")
	if not buildings_value is Dictionary:
		_add_error(errors, "invalid_buildings", "state", "", "建筑集合必须是字典")
	if not connections_value is Dictionary:
		_add_error(errors, "invalid_connections", "state", "", "连接集合必须是字典")
	if not buildings_value is Dictionary or not connections_value is Dictionary:
		return errors

	var buildings: Dictionary = buildings_value
	var connections: Dictionary = connections_value
	var highest_id := 0
	for building_key in buildings:
		var building_id := String(building_key)
		highest_id = maxi(highest_id, _numeric_id_suffix(building_id))
		var building_value: Variant = buildings[building_key]
		if not building_value is Dictionary:
			_add_error(errors, "invalid_building", "building", building_id, "建筑记录必须是字典")
			continue

		var building: Dictionary = building_value
		if building.get("id") != building_id:
			_add_error(errors, "building_id_mismatch", "building", building_id, "建筑 ID 必须与字典键一致")
		_validate_position(errors, building_id, building.get("position"))
		_validate_inventory(errors, building_id, "input_buffer", building.get("input_buffer", {}))
		_validate_inventory(errors, building_id, "output_buffer", building.get("output_buffer", {}))

	for connection_key in connections:
		var connection_id := String(connection_key)
		highest_id = maxi(highest_id, _numeric_id_suffix(connection_id))
		var connection_value: Variant = connections[connection_key]
		if not connection_value is Dictionary:
			_add_error(errors, "invalid_connection", "connection", connection_id, "连接记录必须是字典")
			continue

		var connection: Dictionary = connection_value
		if connection.get("id") != connection_id:
			_add_error(errors, "connection_id_mismatch", "connection", connection_id, "连接 ID 必须与字典键一致")
		var source_id := String(connection.get("source_id", ""))
		var target_id := String(connection.get("target_id", ""))
		if not buildings.has(source_id):
			_add_error(errors, "dangling_connection_source", "connection", connection_id, "连接源建筑不存在")
		if not buildings.has(target_id):
			_add_error(errors, "dangling_connection_target", "connection", connection_id, "连接目标建筑不存在")

	if _is_integral_number(next_id) and int(next_id) <= highest_id:
		_add_error(errors, "next_id_not_ahead", "state", "", "下一实体 ID 必须大于所有已保存 ID")

	return errors

static func _validate_position(errors: Array, building_id: String, position: Variant) -> void:
	if not position is Dictionary:
		_add_error(errors, "invalid_position", "building", building_id, "建筑位置必须是 x/y 字典")
		return
	if not _is_number(position.get("x")) or not _is_number(position.get("y")):
		_add_error(errors, "invalid_position", "building", building_id, "建筑位置坐标必须是数字")

static func _validate_inventory(errors: Array, building_id: String, buffer_name: String, inventory: Variant) -> void:
	if not inventory is Dictionary:
		_add_error(errors, "invalid_inventory", "building", building_id, "%s 必须是字典" % buffer_name)
		return
	for item_key in inventory:
		var amount: Variant = inventory[item_key]
		if not _is_number(amount):
			_add_error(errors, "invalid_inventory_amount", "inventory", "%s:%s" % [building_id, item_key], "库存数量必须是数字")
		elif float(amount) < 0.0:
			_add_error(errors, "negative_inventory", "inventory", "%s:%s" % [building_id, item_key], "库存数量不能为负数")

static func _numeric_id_suffix(stable_id: String) -> int:
	var separator := stable_id.rfind("_")
	if separator < 0:
		return 0
	var suffix := stable_id.substr(separator + 1)
	if not suffix.is_valid_int():
		return 0
	return int(suffix)

static func _is_number(value: Variant) -> bool:
	return typeof(value) == TYPE_INT or typeof(value) == TYPE_FLOAT

static func _is_integral_number(value: Variant) -> bool:
	return _is_number(value) and float(value) == floor(float(value))

static func _add_error(errors: Array, code: String, source: String, id: String, message: String) -> void:
	errors.append({
		"code": code,
		"source": source,
		"id": id,
		"message": message,
	})
