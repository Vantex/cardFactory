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

	_validate_stable_id_array(errors, "completed_technologies", data.get("completed_technologies"))
	_validate_research_state(errors, data)
	for progression_field in ["completed_objective_ids", "claimed_progression_reward_ids", "completed_achievement_ids", "unlocked_progression_ids"]:
		_validate_stable_id_array(errors, progression_field, data.get(progression_field))
	_validate_root_inventory(errors, "planet_inventory", data.get("planet_inventory"), InventorySystem.MAX_PLANET_STACK)
	_validate_root_inventory(errors, "construction_inventory", data.get("construction_inventory"), 99.0, true)
	_validate_cursor_payload(errors, data.get("cursor_payload"))
	var handcraft_queue_value: Variant = data.get("handcraft_queue")
	if not handcraft_queue_value is Array:
		_add_error(errors, "invalid_handcraft_queue", "state", "", "手工制造队列必须是数组")

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
		_validate_power_state(errors, building_id, building)
		_validate_catalog_configuration(errors, building_id, building)

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

	if handcraft_queue_value is Array:
		var seen_job_ids: Dictionary = {}
		for job_value in handcraft_queue_value:
			if not job_value is Dictionary:
				_add_error(errors, "invalid_handcraft_job", "handcraft", "", "手工制造任务必须是字典")
				continue
			var job: Dictionary = job_value
			var job_id := String(job.get("id", ""))
			highest_id = maxi(highest_id, _numeric_id_suffix(job_id))
			_validate_handcraft_job(errors, job, seen_job_ids)
			seen_job_ids[job_id] = true

	if _is_integral_number(next_id) and int(next_id) <= highest_id:
		_add_error(errors, "next_id_not_ahead", "state", "", "下一实体 ID 必须大于所有已保存 ID")

	return errors

static func _validate_stable_id_array(errors: Array, field_name: String, value: Variant) -> void:
	if not value is Array:
		_add_error(errors, "invalid_%s" % field_name, "state", "", "%s 必须是数组" % field_name)
		return
	var seen: Dictionary = {}
	for id_value in value:
		if (typeof(id_value) != TYPE_STRING and typeof(id_value) != TYPE_STRING_NAME) or String(id_value).is_empty() or seen.has(String(id_value)):
			_add_error(errors, "invalid_%s" % field_name, "state", String(id_value), "%s 必须包含非空且不重复的 ID" % field_name)
			continue
		seen[String(id_value)] = true

static func _validate_research_state(errors: Array, data: Dictionary) -> void:
	var completed_value: Variant = data.get("completed_technologies")
	var completed: Array = completed_value if completed_value is Array else []
	for completed_id_value in completed:
		var completed_id := String(completed_id_value)
		if not completed_id.is_empty() and DataManager.get_technology(completed_id).is_empty():
			_add_error(errors, "unknown_completed_technology", "technology", completed_id, "已完成科技引用未知目录 ID")

	var current_id: Variant = data.get("research_current_id")
	if typeof(current_id) != TYPE_STRING and typeof(current_id) != TYPE_STRING_NAME:
		_add_error(errors, "invalid_research_current_id", "state", "", "当前研究必须是字符串")
	var current := String(current_id) if typeof(current_id) == TYPE_STRING or typeof(current_id) == TYPE_STRING_NAME else ""
	var current_technology := DataManager.get_technology(current)
	if not current.is_empty() and current_technology.is_empty():
		_add_error(errors, "unknown_research_current", "technology", current, "当前研究引用未知目录 ID")
	elif not current.is_empty():
		if completed.has(current) and not current_technology.has("repeatable"):
			_add_error(errors, "ineligible_research_current", "technology", current, "已完成的非重复科技不能再次研究")
		for prerequisite_value in current_technology.get("prerequisites", []):
			var prerequisite_id := String(prerequisite_value)
			if not completed.has(prerequisite_id):
				_add_error(errors, "invalid_research_current_prerequisite", "technology", current, "当前研究缺少已完成前置科技 '%s'" % prerequisite_id)

	_validate_stable_id_array(errors, "research_queue", data.get("research_queue"))
	var queue_value: Variant = data.get("research_queue")
	var queue: Array = queue_value if queue_value is Array else []
	if not current.is_empty() and queue.has(current):
		_add_error(errors, "research_current_queued", "technology", current, "当前研究不能同时存在于队列")
	if typeof(data.get("research_paused")) != TYPE_BOOL:
		_add_error(errors, "invalid_research_paused", "state", "", "研究暂停状态必须是布尔值")
	elif bool(data.get("research_paused")) and current.is_empty():
		_add_error(errors, "research_pause_without_current", "state", "", "没有当前研究时不能保存暂停状态")
	if (typeof(data.get("research_queue_wait_reason")) != TYPE_STRING and typeof(data.get("research_queue_wait_reason")) != TYPE_STRING_NAME) or not data.get("technology_levels") is Dictionary:
		_add_error(errors, "invalid_research_metadata", "state", "", "研究队列状态和科技层数无效")
	_validate_technology_levels(errors, data.get("technology_levels"), completed_value)

	var progress_value: Variant = data.get("research_progress")
	var progress_by_id: Dictionary = progress_value if progress_value is Dictionary else {}
	if not progress_value is Dictionary:
		_add_error(errors, "invalid_research_progress", "state", "", "research_progress 必须是字典")
	var invested_value: Variant = data.get("research_invested_costs")
	var invested_by_id: Dictionary = invested_value if invested_value is Dictionary else {}
	if not invested_value is Dictionary:
		_add_error(errors, "invalid_research_invested_costs", "state", "", "research_invested_costs 必须是字典")

	for tech_id_value in progress_by_id:
		var tech_id := String(tech_id_value)
		var technology := DataManager.get_technology(tech_id)
		if tech_id.is_empty():
			_add_error(errors, "invalid_research_progress", "state", tech_id, "研究科技 ID 不能为空")
		elif technology.is_empty():
			_add_error(errors, "unknown_research_progress", "technology", tech_id, "研究进度引用未知目录 ID")
		var progress: Variant = progress_by_id[tech_id_value]
		var duration := float(technology.get("duration", 0.0))
		if not _is_finite_number(progress) or float(progress) < 0.0 or (not technology.is_empty() and float(progress) > duration + 0.0000001):
			_add_error(errors, "invalid_research_progress", "technology", tech_id, "研究进度必须在目录时长范围内")
		if not invested_by_id.has(tech_id):
			_add_error(errors, "research_progress_without_investment", "technology", tech_id, "研究进度必须保留完整投入成本")

	for tech_id_value in invested_by_id:
		var tech_id := String(tech_id_value)
		var technology := DataManager.get_technology(tech_id)
		if tech_id.is_empty():
			_add_error(errors, "invalid_research_invested_costs", "state", tech_id, "研究科技 ID 不能为空")
		elif technology.is_empty():
			_add_error(errors, "unknown_research_investment", "technology", tech_id, "研究投入引用未知目录 ID")
			continue
		_validate_exact_research_cost(errors, tech_id, technology.get("cost", {}), invested_by_id[tech_id_value])
	if not current.is_empty() and not invested_by_id.has(current):
		_add_error(errors, "research_cost_not_paid", "technology", current, "当前研究必须已经支付完整目录成本")

	var scheduled: Dictionary = {}
	for completed_id_value in completed:
		scheduled[String(completed_id_value)] = true
	if not current.is_empty():
		scheduled[current] = true
	for queued_id_value in queue:
		var queued_id := String(queued_id_value)
		var technology := DataManager.get_technology(queued_id)
		if technology.is_empty():
			_add_error(errors, "unknown_research_queue", "technology", queued_id, "研究队列引用未知目录 ID")
			continue
		if completed.has(queued_id) and not technology.has("repeatable"):
			_add_error(errors, "ineligible_research_queue", "technology", queued_id, "已完成的非重复科技不能进入队列")
		for prerequisite_value in technology.get("prerequisites", []):
			var prerequisite_id := String(prerequisite_value)
			if not scheduled.has(prerequisite_id):
				_add_error(errors, "invalid_research_queue_prerequisite", "technology", queued_id, "队列前置科技 '%s' 必须已完成或排在其前面" % prerequisite_id)
		scheduled[queued_id] = true

static func _validate_technology_levels(errors: Array, levels_value: Variant, completed_value: Variant) -> void:
	if not levels_value is Dictionary:
		return
	var completed: Array = completed_value if completed_value is Array else []
	for technology_key in levels_value:
		var technology_id := String(technology_key)
		var technology := DataManager.get_technology(technology_id)
		if technology.is_empty():
			_add_error(errors, "unknown_technology_level", "technology", technology_id, "科技层数引用未知科技")
			continue
		var level: Variant = levels_value[technology_key]
		if not _is_integral_number(level) or int(level) < 1:
			_add_error(errors, "invalid_technology_level", "technology", technology_id, "科技层数必须是正整数")
		if not technology.has("repeatable"):
			_add_error(errors, "non_repeatable_technology_level", "technology", technology_id, "非重复科技不能保存层数")
		if not completed.has(technology_id):
			_add_error(errors, "technology_level_not_completed", "technology", technology_id, "科技层数必须对应已完成科技")
	for completed_id_value in completed:
		var completed_id := String(completed_id_value)
		var completed_technology := DataManager.get_technology(completed_id)
		if not completed_technology.is_empty() and completed_technology.has("repeatable") and not levels_value.has(completed_id):
			_add_error(errors, "missing_repeatable_technology_level", "technology", completed_id, "已完成的重复科技必须保存至少一级")

static func _validate_exact_research_cost(errors: Array, technology_id: String, expected_value: Variant, invested_value: Variant) -> void:
	if not expected_value is Dictionary or not invested_value is Dictionary:
		_add_error(errors, "invalid_research_invested_cost", "technology", technology_id, "研究投入必须精确匹配目录成本")
		return
	var expected: Dictionary = expected_value
	var invested: Dictionary = invested_value
	if invested.size() != expected.size():
		_add_error(errors, "invalid_research_invested_cost", "technology", technology_id, "研究投入物品必须精确匹配目录成本")
		return
	for item_id_value in expected:
		var item_id := String(item_id_value)
		var expected_amount: Variant = expected[item_id_value]
		var invested_amount: Variant = invested.get(item_id)
		if not invested.has(item_id) or not _is_finite_number(invested_amount) or not is_equal_approx(float(invested_amount), float(expected_amount)):
			_add_error(errors, "invalid_research_invested_cost", "technology", technology_id, "研究投入 '%s' 必须精确等于目录成本" % item_id)
			return

static func _validate_catalog_configuration(errors: Array, building_id: String, building: Dictionary) -> void:
	var building_type := String(building.get("type", ""))
	var definition := DataManager.get_building(building_type)
	var recipe_id := String(building.get("recipe_id", ""))
	if not recipe_id.is_empty():
		var recipe := DataManager.get_recipe(recipe_id)
		if recipe.is_empty():
			_add_error(errors, "invalid_recipe_reference", "building", building_id, "建筑引用的配方不存在")
		elif not DataManager.is_recipe_supported_by_building(recipe, building_type):
			_add_error(errors, "invalid_building_recipe", "building", building_id, "配方与建筑类型不匹配")
	if definition.get("kind", "") == "extractor":
		var extraction: Dictionary = definition.get("extraction", {})
		var allowed_items: Array = extraction.get("items", [extraction.get("item_id", "")])
		var output_item := String(building.get("output_item", extraction.get("item_id", "")))
		if not allowed_items.has(output_item):
			_add_error(errors, "invalid_extraction_item", "building", building_id, "采集目标不在建筑目录许可范围内")
	elif building.has("output_item") and not recipe_id.is_empty():
		var allowed_outputs: Array = []
		for output_value in DataManager.get_recipe(recipe_id).get("outputs", []):
			allowed_outputs.append(String(output_value.get("item_id", "")))
		if not allowed_outputs.has(String(building.get("output_item", ""))):
			_add_error(errors, "invalid_output_item", "building", building_id, "连接输出不在当前配方产物范围内")
	var fuel_rule: Dictionary = definition.get("fuel", {})
	if not fuel_rule.is_empty() and building.has("fuel_item") and String(building.get("fuel_item", "")) != String(fuel_rule.get("item_id", "")):
		_add_error(errors, "invalid_fuel_item", "building", building_id, "燃料物品与建筑目录不匹配")

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

static func _validate_root_inventory(errors: Array, inventory_name: String, inventory: Variant, max_amount: float, allow_legacy_credit: bool = false) -> void:
	if not inventory is Dictionary:
		_add_error(errors, "invalid_%s" % inventory_name, "state", "", "%s 必须是字典" % inventory_name)
		return
	for item_key in inventory:
		var item_id := String(item_key)
		var amount: Variant = inventory[item_key]
		if item_id.is_empty():
			_add_error(errors, "invalid_inventory_item", "inventory", inventory_name, "库存物品 ID 不能为空")
		elif not _is_number(amount) or is_nan(float(amount)) or is_inf(float(amount)):
			_add_error(errors, "invalid_inventory_amount", "inventory", "%s:%s" % [inventory_name, item_id], "库存数量必须是有限数字")
		elif float(amount) < 0.0:
			_add_error(errors, "negative_inventory", "inventory", "%s:%s" % [inventory_name, item_id], "库存数量不能为负数")
		elif not (allow_legacy_credit and item_id == "legacy_credit") and float(amount) > max_amount:
			_add_error(errors, "inventory_overflow", "inventory", "%s:%s" % [inventory_name, item_id], "库存数量超过容量上限")

static func _validate_cursor_payload(errors: Array, cursor: Variant) -> void:
	if not cursor is Dictionary:
		_add_error(errors, "invalid_cursor_payload", "state", "", "光标载荷必须是字典")
		return
	var item_value: Variant = cursor.get("item_id")
	var amount_value: Variant = cursor.get("amount")
	if (typeof(item_value) != TYPE_STRING and typeof(item_value) != TYPE_STRING_NAME) or not _is_number(amount_value):
		_add_error(errors, "invalid_cursor_payload", "state", "", "光标载荷需要合法物品 ID 和数量")
		return
	var item_id := String(item_value)
	var amount := float(amount_value)
	if is_nan(amount) or is_inf(amount) or amount < 0.0 or amount > InventorySystem.MAX_CURSOR_STACK:
		_add_error(errors, "invalid_cursor_amount", "state", "", "光标载荷数量超出合法范围")
	elif (item_id.is_empty() and amount != 0.0) or (not item_id.is_empty() and amount <= 0.0):
		_add_error(errors, "invalid_cursor_ownership", "state", "", "光标物品与数量必须同时为空或同时有效")

static func _validate_handcraft_job(errors: Array, job: Dictionary, seen_job_ids: Dictionary) -> void:
	var job_id := String(job.get("id", ""))
	if job_id.is_empty() or seen_job_ids.has(job_id):
		_add_error(errors, "invalid_handcraft_job_id", "handcraft", job_id, "手工制造任务 ID 必须非空且唯一")
	var recipe_id := String(job.get("recipe_id", ""))
	var recipe: Dictionary = HandcraftSystem.RECIPES.get(recipe_id, {})
	if recipe.is_empty():
		_add_error(errors, "invalid_handcraft_recipe", "handcraft", job_id, "手工制造任务引用未知配方")
	var total: Variant = job.get("quantity_total")
	var remaining: Variant = job.get("quantity_remaining")
	if not _is_integral_number(total) or int(total) < 1:
		_add_error(errors, "invalid_handcraft_quantity", "handcraft", job_id, "手工制造总数必须是正整数")
	if not _is_integral_number(remaining) or int(remaining) < 1 or (_is_integral_number(total) and int(remaining) > int(total)):
		_add_error(errors, "invalid_handcraft_remaining", "handcraft", job_id, "手工制造剩余数必须在合法范围内")
	var progress: Variant = job.get("progress")
	var duration := float(recipe.get("duration", 0.0))
	if not _is_number(progress) or is_nan(float(progress)) or is_inf(float(progress)) or float(progress) < 0.0 or (not recipe.is_empty() and float(progress) > duration + 0.0000001):
		_add_error(errors, "invalid_handcraft_progress", "handcraft", job_id, "手工制造进度超出合法范围")

static func _validate_power_state(errors: Array, building_id: String, building: Dictionary) -> void:
	if building.has("fuel_remaining"):
		var fuel_remaining: Variant = building["fuel_remaining"]
		if not _is_number(fuel_remaining) or float(fuel_remaining) < 0.0:
			_add_error(errors, "invalid_fuel_remaining", "building", building_id, "燃料剩余时间必须是非负数")
	if building.has("generation_factor"):
		var generation_factor: Variant = building["generation_factor"]
		if not _is_number(generation_factor) or float(generation_factor) < 0.0 or float(generation_factor) > 1.0:
			_add_error(errors, "invalid_generation_factor", "building", building_id, "可再生发电倍率必须在 0 到 1 之间")
	if building.has("fuel_item"):
		var fuel_item: Variant = building["fuel_item"]
		if (typeof(fuel_item) != TYPE_STRING and typeof(fuel_item) != TYPE_STRING_NAME) or String(fuel_item).is_empty():
			_add_error(errors, "invalid_fuel_item", "building", building_id, "燃料物品 ID 必须是非空字符串")

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

static func _is_finite_number(value: Variant) -> bool:
	return _is_number(value) and not is_nan(float(value)) and not is_inf(float(value))

static func _is_integral_number(value: Variant) -> bool:
	return _is_number(value) and float(value) == floor(float(value))

static func _add_error(errors: Array, code: String, source: String, id: String, message: String) -> void:
	errors.append({
		"code": code,
		"source": source,
		"id": id,
		"message": message,
	})
