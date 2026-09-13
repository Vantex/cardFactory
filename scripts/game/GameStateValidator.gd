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
	var galaxy := GalaxySystem.new(GameState.new())
	_validate_galaxy_state(errors, data, galaxy)
	_validate_root_inventory(errors, "construction_inventory", data.get("construction_inventory"), 99.0, true)
	_validate_cursor_payload(errors, data.get("cursor_payload"))
	for message in ConstructionAutomationSystem.validate(data.get("production_orders", []), data.get("planet_inventories", {}), data.get("buildings", {})):
		_add_error(errors, "invalid_production_order", "state", "", message)
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
	errors.append_array(LogisticsStateValidator.validate(data))
	errors.append_array(DysonStateValidator.validate(data))
	errors.append_array(EndgameStateValidator.validate(data))
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
		_validate_entity_planet(errors, "building", building_id, building, data.get("colonized_planet_ids", []), galaxy)
		_validate_resource_binding(errors, building_id, building, data.get("resource_sites", {}))

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
		_validate_entity_planet(errors, "connection", connection_id, connection, data.get("colonized_planet_ids", []), galaxy)
		if buildings.has(source_id) and buildings.has(target_id):
			var connection_planet := String(connection.get("planet_id", ""))
			if connection_planet != String(buildings[source_id].get("planet_id", "")) or connection_planet != String(buildings[target_id].get("planet_id", "")):
				_add_error(errors, "cross_planet_connection", "connection", connection_id, "线路和端点必须属于同一行星")

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
			if String(job.get("planet_id", "")).is_empty() or not data.get("colonized_planet_ids", []).has(String(job.get("planet_id", ""))):
				_add_error(errors, "invalid_handcraft_planet", "handcraft", job_id, "手工制造任务必须属于已殖民行星")
			seen_job_ids[job_id] = true

	if _is_integral_number(next_id) and int(next_id) <= highest_id:
		_add_error(errors, "next_id_not_ahead", "state", "", "下一实体 ID 必须大于所有已保存 ID")

	return errors

static func _validate_galaxy_state(errors: Array, data: Dictionary, galaxy: GalaxySystem) -> void:
	var active_planet_id := String(data.get("active_planet_id", ""))
	if galaxy.get_planet(active_planet_id).is_empty():
		_add_error(errors, "unknown_active_planet", "state", active_planet_id, "活动行星不存在于星区目录")
	var colonized_value: Variant = data.get("colonized_planet_ids")
	_validate_stable_id_array(errors, "colonized_planet_ids", colonized_value)
	if not colonized_value is Array:
		_add_error(errors, "invalid_colonized_planet_ids", "state", "", "已殖民行星必须是数组")
		return
	var colonized: Array = colonized_value
	if not colonized.has(active_planet_id):
		_add_error(errors, "active_planet_not_colonized", "state", active_planet_id, "活动行星必须已殖民")
	for planet_id_value in colonized:
		var planet_id := String(planet_id_value)
		if galaxy.get_planet(planet_id).is_empty():
			_add_error(errors, "unknown_colonized_planet", "state", planet_id, "已殖民行星不存在于星区目录")
	var explored_value: Variant = data.get("explored_system_ids")
	_validate_stable_id_array(errors, "explored_system_ids", explored_value)
	if not explored_value is Array:
		_add_error(errors, "invalid_explored_system_ids", "state", "", "已探索星系必须是数组")
	else:
		for system_id_value in explored_value:
			var system_id := String(system_id_value)
			var system := galaxy.get_star_system(system_id)
			if system.is_empty():
				_add_error(errors, "unknown_explored_system", "state", system_id, "已探索星系不存在于星区目录")
				continue
			var prerequisite_id := String(system.get("prerequisite_system_id", ""))
			if not prerequisite_id.is_empty() and not explored_value.has(prerequisite_id):
				_add_error(errors, "invalid_system_prerequisite", "state", system_id, "已探索星系缺少目录前置星系")
	for planet_id_value in colonized:
		var planet_id := String(planet_id_value)
		var planet := galaxy.get_planet(planet_id)
		if not planet.is_empty() and (not explored_value is Array or not explored_value.has(String(planet.get("system_id", "")))):
			_add_error(errors, "colonized_system_unexplored", "state", planet_id, "已殖民行星所属星系必须已探索")
	var inventories_value: Variant = data.get("planet_inventories")
	if not inventories_value is Dictionary:
		_add_error(errors, "invalid_planet_inventories", "state", "", "行星托盘必须是字典")
	else:
		for planet_id_value in colonized:
			var planet_id := String(planet_id_value)
			if not inventories_value.has(planet_id):
				_add_error(errors, "missing_planet_inventory", "state", planet_id, "已殖民行星缺少材料托盘")
			else:
				_validate_root_inventory(errors, "planet_inventory", inventories_value[planet_id], InventorySystem.MAX_PLANET_STACK)
	_validate_viewports(errors, data.get("planet_viewports"), colonized)
	if not _is_integral_number(data.get("galaxy_seed")):
		_add_error(errors, "invalid_galaxy_seed", "state", "", "星区种子必须是整数")
	_validate_resource_sites(errors, data.get("resource_sites"), galaxy, int(data.get("galaxy_seed", 0)))
	_validate_exploration_state(errors, data, galaxy)
	if not data.get("planet_metrics") is Dictionary:
		_add_error(errors, "invalid_planet_metadata", "state", "", "行星元数据无效")
	_validate_portable_fleet(errors, data.get("portable_fleet"))

static func _validate_portable_fleet(errors: Array, value: Variant) -> void:
	const VEHICLE_IDS := ["logistics_drone", "logistics_vessel"]
	if not value is Dictionary:
		_add_error(errors, "invalid_portable_fleet", "state", "", "随身物流载具必须是字典")
		return
	var fleet: Dictionary = value
	var keys := fleet.keys()
	keys.sort()
	if keys != VEHICLE_IDS:
		_add_error(errors, "invalid_portable_fleet", "state", "", "随身物流载具键必须精确匹配目录")
		return
	for item_id in VEHICLE_IDS:
		var amount: Variant = fleet.get(item_id)
		if not _is_finite_number(amount) or float(amount) != floor(float(amount)) or float(amount) < 0.0:
			_add_error(errors, "invalid_portable_fleet", "state", item_id, "随身物流载具数量必须是非负整数")

static func _validate_entity_planet(errors: Array, source: String, entity_id: String, entity: Dictionary, colonized: Variant, galaxy: GalaxySystem) -> void:
	var planet_id := String(entity.get("planet_id", ""))
	if planet_id.is_empty() or galaxy.get_planet(planet_id).is_empty() or not colonized is Array or not colonized.has(planet_id):
		_add_error(errors, "invalid_entity_planet", source, entity_id, "实体必须属于已殖民行星")

static func _validate_resource_binding(errors: Array, building_id: String, building: Dictionary, sites_value: Variant) -> void:
	if not building.has("resource_site_id"):
		return
	var site_id := String(building.get("resource_site_id", ""))
	var site: Variant = sites_value.get(site_id) if sites_value is Dictionary else null
	if not site is Dictionary or String(site.get("planet_id", "")) != String(building.get("planet_id", "")) or String(site.get("item_id", "")) != String(building.get("output_item", "")):
		_add_error(errors, "invalid_resource_binding", "building", building_id, "采集建筑资源点绑定无效")

static func _validate_viewports(errors: Array, value: Variant, colonized: Array) -> void:
	if not value is Dictionary:
		_add_error(errors, "invalid_planet_viewports", "state", "", "行星视口必须是字典")
		return
	for planet_id_value in colonized:
		var planet_id := String(planet_id_value)
		var viewport: Variant = value.get(planet_id)
		if not viewport is Dictionary or not _is_vector2_dict(viewport.get("position")) or not _is_vector2_dict(viewport.get("zoom")):
			_add_error(errors, "invalid_planet_viewport", "state", planet_id, "已殖民行星视口无效")
			continue
		var zoom: Dictionary = viewport["zoom"]
		if float(zoom["x"]) <= 0.0 or float(zoom["y"]) <= 0.0:
			_add_error(errors, "invalid_planet_viewport", "state", planet_id, "行星视口缩放必须为正数")

static func _validate_resource_sites(errors: Array, value: Variant, galaxy: GalaxySystem, galaxy_seed: int) -> void:
	if not value is Dictionary:
		_add_error(errors, "invalid_resource_sites", "state", "", "资源点必须是字典")
		return
	var seen: Dictionary = {}
	for site_id_value in value:
		var site_id := String(site_id_value)
		var site: Variant = value[site_id_value]
		var declared_site_id := String(site.get("id", "")) if site is Dictionary else ""
		if not site is Dictionary or seen.has(declared_site_id) or declared_site_id != site_id:
			_add_error(errors, "invalid_resource_site", "resource_site", site_id, "资源点 ID 无效")
			continue
		seen[declared_site_id] = true
		var planet_id := String(site.get("planet_id", ""))
		var expected_sites := galaxy.build_resource_sites_for_planet(planet_id, galaxy_seed)
		var expected: Variant = expected_sites.get(site_id)
		if not expected is Dictionary or String(site.get("item_id", "")) != String(expected.get("item_id", "")) or bool(site.get("infinite", false)) != bool(expected.get("infinite", false)) or not _matches_resource_position(site.get("position"), expected.get("position", Vector2.ZERO)):
			_add_error(errors, "invalid_resource_site", "resource_site", site_id, "资源点必须匹配确定性星区目录")
			continue
		var capacity: Variant = site.get("capacity")
		var remaining: Variant = site.get("remaining")
		if not _is_finite_number(capacity) or not _is_finite_number(remaining) or float(capacity) != float(expected.get("capacity", -1.0)) or float(remaining) < 0.0 or (bool(expected.get("infinite", false)) and (float(capacity) != 0.0 or float(remaining) != 0.0)) or (not bool(expected.get("infinite", false)) and (float(capacity) <= 0.0 or float(remaining) > float(capacity))):
			_add_error(errors, "invalid_resource_reserve", "resource_site", site_id, "资源储量必须有限且合法")

static func _matches_resource_position(value: Variant, expected: Vector2) -> bool:
	return value is Dictionary and _is_finite_number(value.get("x")) and _is_finite_number(value.get("y")) and is_equal_approx(float(value.get("x")), expected.x) and is_equal_approx(float(value.get("y")), expected.y)

static func _validate_exploration_state(errors: Array, data: Dictionary, galaxy: GalaxySystem) -> void:
	var explored: Array = data.get("explored_system_ids", []) if data.get("explored_system_ids") is Array else []
	var completed: Array = data.get("completed_technologies", []) if data.get("completed_technologies") is Array else []
	var missions_value: Variant = data.get("exploration_missions")
	var mission_by_system: Dictionary = {}
	if not missions_value is Array:
		_add_error(errors, "invalid_exploration_mission", "state", "", "勘探任务必须是数组")
	else:
		var seen_systems: Dictionary = {}
		for mission_value in missions_value:
			if not mission_value is Dictionary:
				_add_error(errors, "invalid_exploration_mission", "state", "", "勘探任务必须是字典")
				continue
			var mission: Dictionary = mission_value
			var system_id := String(mission.get("system_id", ""))
			var progress: Variant = mission.get("progress")
			var duration: Variant = mission.get("duration_seconds")
			var system := galaxy.get_star_system(system_id)
			var required_technology_id := String(system.get("required_technology_id", ""))
			var prerequisite_id := String(system.get("prerequisite_system_id", ""))
			if system_id.is_empty() or seen_systems.has(system_id) or system.is_empty() or explored.has(system_id) or not _is_finite_number(duration) or float(duration) <= 0.0 or not is_equal_approx(float(duration), galaxy.get_exploration_duration(system_id)) or not _is_finite_number(progress) or float(progress) < 0.0 or (_is_finite_number(duration) and float(progress) >= float(duration)) or (not required_technology_id.is_empty() and not completed.has(required_technology_id)) or (not prerequisite_id.is_empty() and not explored.has(prerequisite_id)):
				_add_error(errors, "invalid_exploration_mission", "exploration", system_id, "勘探任务状态无效")
			seen_systems[system_id] = true
			mission_by_system[system_id] = mission
	var survey_value: Variant = data.get("survey_progress_by_system")
	if not survey_value is Dictionary:
		_add_error(errors, "invalid_survey_progress", "state", "", "勘探进度必须是字典")
		return
	for system_id_value in survey_value:
		var system_id := String(system_id_value)
		var progress: Variant = survey_value[system_id_value]
		if galaxy.get_star_system(system_id).is_empty() or not _is_finite_number(progress) or float(progress) < 0.0 or float(progress) > 1.0:
			_add_error(errors, "invalid_survey_progress", "exploration", system_id, "勘探进度必须属于已知星系且在零到一之间")
			continue
		if explored.has(system_id):
			if not is_equal_approx(float(progress), 1.0):
				_add_error(errors, "invalid_survey_progress", "exploration", system_id, "已探索星系进度必须完成")
			continue
		if mission_by_system.has(system_id):
			var mission: Dictionary = mission_by_system[system_id]
			var expected_progress := float(mission.get("progress", 0.0)) / maxf(float(mission.get("duration_seconds", 0.0)), 0.0000001)
			if not is_equal_approx(float(progress), expected_progress):
				_add_error(errors, "invalid_survey_progress", "exploration", system_id, "勘探进度必须与进行中的任务一致")
		elif not is_zero_approx(float(progress)):
			_add_error(errors, "invalid_survey_progress", "exploration", system_id, "未运行勘探任务的星系进度必须为零")
	for system_id in mission_by_system:
		if not survey_value.has(system_id):
			_add_error(errors, "invalid_survey_progress", "exploration", String(system_id), "进行中的勘探任务缺少进度记录")
	for system_id_value in explored:
		var system_id := String(system_id_value)
		var progress: Variant = survey_value.get(system_id)
		if not survey_value.has(system_id) or not _is_finite_number(progress) or not is_equal_approx(float(progress), 1.0):
			_add_error(errors, "invalid_survey_progress", "exploration", system_id, "已探索星系必须保留完成的勘探进度")

static func _is_vector2_dict(value: Variant) -> bool:
	return value is Dictionary and _is_finite_number(value.get("x")) and _is_finite_number(value.get("y"))

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
		if technology.get("source_research_bridge", false):
			_validate_source_research_cost(errors, tech_id, technology.cost, invested_by_id[tech_id_value], progress_by_id.get(tech_id, 0))
		else:
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
	if building.get("power_grid_id", "grid-a") not in ["grid-a", "grid-b", "grid-c"]:
		_add_error(errors, "invalid_power_grid", "building", building_id, "未知电网")
	for key in ["power_priority", "generation_priority"]:
		if building.has(key) and (not _is_integral_number(building[key]) or int(building[key]) not in [1, 2, 3]):
			_add_error(errors, "invalid_power_priority", "building", building_id, "电力优先级必须为 1 到 3")
	if building.has("stored_energy_mj"):
		var energy: Variant = building.stored_energy_mj
		if PowerGridSystem.kind_id(building) not in ["accumulator", "energy_exchanger"] or not _is_finite_number(energy) or float(energy) < 0 or float(energy) > 90:
			_add_error(errors, "invalid_stored_energy", "building", building_id, "储能必须在设备容量范围内")
	if building.has("energy_mode") and (PowerGridSystem.kind_id(building) != "energy_exchanger" or building.energy_mode not in ["charge", "discharge", "idle"]):
		_add_error(errors, "invalid_energy_mode", "building", building_id, "无效储能模式")
	if building.has("spray_coater_installed") and not building.spray_coater_installed is bool:
		_add_error(errors, "invalid_spray", "building", building_id, "喷涂安装状态无效")
	if building.has("proliferator_tier") and (not _is_integral_number(building.proliferator_tier) or int(building.proliferator_tier) not in [1, 2, 3]):
		_add_error(errors, "invalid_spray_tier", "building", building_id, "喷涂等级无效")
	if building.has("proliferator_mode") and building.proliferator_mode not in ["normal", "extra", "speed"]:
		_add_error(errors, "invalid_spray_mode", "building", building_id, "喷涂模式无效")
	if building.has("proliferator_points") and (not _is_finite_number(building.proliferator_points) or float(building.proliferator_points) < 0 or float(building.proliferator_points) > 60):
		_add_error(errors, "invalid_spray_points", "building", building_id, "剩余喷涂点无效")
	if building.has("proliferator_bonus"):
		if not building.proliferator_bonus is Dictionary:
			_add_error(errors, "invalid_spray_bonus", "building", building_id, "喷涂产出余量无效")
		else:
			for value in building.proliferator_bonus.values():
				if not _is_finite_number(value) or float(value) < 0 or float(value) >= 1:
					_add_error(errors, "invalid_spray_bonus", "building", building_id, "喷涂产出余量越界")
	if building.has("construction_targets"):
		if PowerGridSystem.kind_id(building) != "construction_center" or not building.construction_targets is Dictionary:
			_add_error(errors, "invalid_construction_targets", "building", building_id, "制造中心目标无效")
		else:
			for target in building.construction_targets:
				var count: Variant = building.construction_targets[target]
				if not DataManager.construction.has(target) or not _is_integral_number(count) or float(count) < 1 or float(count) > 99:
					_add_error(errors, "invalid_construction_targets", "building", building_id, "制造目标数量无效")
	if building.has("automation_paused") and not building.automation_paused is bool:
		_add_error(errors, "invalid_automation_pause", "building", building_id, "制造暂停状态无效")
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

static func _validate_source_research_cost(errors: Array, tech: String, expected: Dictionary, invested: Variant, progress: Variant) -> void:
	if not invested is Dictionary:
		_add_error(errors, "invalid_source_research", "technology", tech, "源科研投入必须是字典")
		return
	var total := 0.0
	for item in invested:
		var amount: Variant = invested[item]
		if not expected.has(item) or not _is_integral_number(amount) or float(amount) < 0 or float(amount) > float(expected[item]):
			_add_error(errors, "invalid_source_research", "technology", tech, "源科研投入超过目录成本")
			return
		total += float(amount)
	if not _is_finite_number(progress) or not is_equal_approx(float(progress), total * 3.0):
		_add_error(errors, "invalid_source_research", "technology", tech, "源科研进度与已消耗材料不一致")
