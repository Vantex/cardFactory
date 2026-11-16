class_name LogisticsStateValidator
extends RefCounted

static func validate(data: Dictionary) -> Array:
	var errors: Array = []
	var buildings: Dictionary = data.get("buildings", {})
	var routes: Variant = data.get("logistics_routes")
	if not routes is Dictionary or not _number(data.get("interplanetary_delivered"), 0, 1e18):
		return [_error("物流根状态无效")]
	for id in buildings:
		var b: Variant = buildings[id]
		if not b is Dictionary:
			continue
		if not StationSystem.is_station(String(b.get("type", ""))):
			if b.has("station"):
				errors.append(_error("非物流建筑包含站点状态"))
			continue
		if not b.get("input_buffer") is Dictionary or not b.get("output_buffer") is Dictionary:
			errors.append(_error("物流站缓存结构无效"))
		var station: Variant = b.get("station")
		if not station is Dictionary or not station.get("enabled") is bool or not station.get("slots") is Array or station.slots.size() != StationSystem.slot_count(b.type) or not station.get("fleet") is Dictionary:
			errors.append(_error("物流站结构无效"))
			continue
		if not _integer(b.get("station_stack_count", 1), 1, 100000000) or (not StationSystem.is_source(b.type) and b.has("station_stack_count")): errors.append(_error("物流站堆叠数量无效"))
		var fleet: Dictionary = station.fleet
		if not station.get("hub_enabled", false) is bool or not _integer(station.get("hub_priority", 1), 0, 2) or (station.get("hub_enabled", false) and b.type != StationSystem.TYPES[3]): errors.append(_error("物流站中继配置无效"))
		if not station.get("warp_enabled", true) is bool or not station.get("warper_auto_refill", false) is bool or not _integer(station.get("warper_target", 50), 1, StationSystem.fleet_capacity(b, "space_warper")): errors.append(_error("物流站翘曲配置无效"))
		if not StationSystem.is_interstellar(b.type) and (station.get("warper_auto_refill", false) or not station.get("warp_enabled", true)): errors.append(_error("行星站不能配置翘曲"))
		if fleet.size() != 3:
			errors.append(_error("载具集合无效"))
		for item in StationSystem.FLEET_ITEMS:
			var cap := StationSystem.fleet_capacity(b, item)
			if b.type == OrbitalCollectorSystem.TYPE: cap = 0
			if not _integer(fleet.get(item), 0, cap):
				errors.append(_error("载具数量无效"))
			elif not StationSystem.is_interstellar(b.type) and item != "logistics_drone" and fleet[item] != 0:
				errors.append(_error("行星站不支持飞船和翘曲器"))
		var seen := {}
		for slot in station.slots:
			if not slot is Dictionary:
				errors.append(_error("槽位必须为字典"))
				continue
			var item: Variant = slot.get("item_id")
			if slot.get("route_policy", "relay-preferred") not in ["direct", "relay-preferred", "relay-required"] or not _integer(slot.get("warper_budget", 2), 1, 4): errors.append(_error("槽位航线策略无效"))
			if not item is String or (item != "" and (DataManager.get_item(item).is_empty() or seen.has(item))):
				errors.append(_error("槽位物品无效或重复"))
			else:
				seen[item] = true
			var max_capacity := 1000 if StationSystem.is_source(b.type) else 999
			if b.type == OrbitalCollectorSystem.TYPE: max_capacity = 2000
			if StationSystem.is_source(b.type): max_capacity *= StationSystem.stack_count(b)
			var retained_bound := StationSystem.storage_capacity_for(b, slot) if StationSystem.is_source(b.type) else float(max_capacity)
			if slot.get("mode") not in ["supply", "demand", "storage"] or not _number(slot.get("capacity"), 1, max_capacity) or not _number(slot.get("amount"), 0, retained_bound) or not _number(slot.get("min_load"), 0.01, 1) or not _integer(slot.get("priority"), 0, 2) or not _integer(slot.get("cursor"), 0, 1000000):
				errors.append(_error("槽位数值无效"))
			elif float(slot.amount) > StationSystem.storage_capacity_for(b, slot) or (item == "" and slot.amount != 0):
				errors.append(_error("槽位容量或空槽物资无效"))
			if StationSystem.is_source(b.type) and (slot.get("local_mode") not in ["supply", "demand", "storage"] or slot.get("remote_mode") not in ["supply", "demand", "storage"] or slot.get("min_load") not in [0.1, 0.25, 0.5, 1.0] or not _number(slot.get("min_stock"), 0, 100000000) or not _number(slot.get("max_stock"), 0, 100000000)): errors.append(_error("源物流站范围和库存限额无效"))
	if not errors.is_empty():
		return errors
	var occupied := {}
	for id in routes:
		var r: Variant = routes[id]
		if not r is Dictionary:
			errors.append(_error("航线必须为字典"))
			continue
		if r.get("id") != id or not String(id).begins_with("route_") or not String(id).trim_prefix("route_").is_valid_int() or int(String(id).trim_prefix("route_")) < 1 or int(String(id).trim_prefix("route_")) >= int(data.get("next_id", 0)):
			errors.append(_error("航线 ID 无效"))
		if not r.get("source_id") is String or not r.get("target_id") is String or not buildings.get(r.source_id, {}) is Dictionary or not buildings.get(r.target_id, {}) is Dictionary:
			errors.append(_error("航线端点类型无效"))
			continue
		var a: Dictionary = buildings.get(r.get("source_id", ""), {})
		var b: Dictionary = buildings.get(r.get("target_id", ""), {})
		if not a.has("station") or not b.has("station") or r.get("source_id") == r.get("target_id") or not _integer(r.get("source_slot"), 0, a.station.slots.size() - 1) or not _integer(r.get("target_slot"), 0, b.station.slots.size() - 1):
			errors.append(_error("航线端点无效"))
			continue
		var source_slot: Dictionary = a.station.slots[int(r.source_slot)]
		var waypoints: Variant = r.get("waypoint_ids", [])
		if not waypoints is Array or waypoints.size() > 3:
			errors.append(_error("航线中继列表无效"))
		else:
			var visited := {r.source_id: true, r.target_id: true}
			for waypoint in waypoints:
				if not waypoint is String or visited.has(waypoint) or buildings.get(waypoint, {}).get("type") != StationSystem.TYPES[3]: errors.append(_error("航线中继端点无效"))
				else: visited[waypoint] = true
			if not waypoints.is_empty() and not r.get("interplanetary", false): errors.append(_error("本地航线不能包含中继"))
		if not _number(r.get("distance_ly", 0), 0, 1e6) or not _integer(r.get("warpers_per_vessel", 0), 0, 4): errors.append(_error("航线经济数值无效"))
		var target_slot: Dictionary = b.station.slots[int(r.target_slot)]
		var interplanetary: bool = a.planet_id != b.planet_id
		var vehicle := "logistics_vessel" if interplanetary else "logistics_drone"
		if not r.get("interplanetary") is bool or r.interplanetary != interplanetary or r.get("vehicle") != vehicle or (interplanetary and (not StationSystem.is_remote_endpoint(a.type) or not StationSystem.is_interstellar(b.type))):
			errors.append(_error("航线载具与行星边界不符"))
		if r.get("item_id", "") == "" or r.get("item_id") != source_slot.item_id or r.get("item_id") != target_slot.item_id or StationSystem.mode_for(a, source_slot, interplanetary) != "supply" or StationSystem.mode_for(b, target_slot, interplanetary) != "demand":
			errors.append(_error("航线货物不匹配"))
		if r.get("phase") not in ["outbound", "returning"] or not _number(r.get("duration"), 0.000001, 100000) or not _number(r.get("remaining"), 0, 100000) or not _number(r.get("amount"), 0, _route_capacity(data, a, b, interplanetary)):
			errors.append(_error("航线阶段或数值无效"))
		elif float(r.remaining) > float(r.duration) or (r.phase == "returning" and r.amount != 0) or (r.phase == "outbound" and r.amount <= 0):
			errors.append(_error("航线进度与货物状态不符"))
		var owner_id: Variant = r.get("owner_id", r.source_id)
		if not owner_id is String or owner_id not in [r.source_id, r.target_id] or (owner_id == r.target_id and not StationSystem.is_source(b.type) and a.type != OrbitalCollectorSystem.TYPE) or (owner_id == r.source_id and a.type == OrbitalCollectorSystem.TYPE):
			errors.append(_error("航线载具归属无效"))
			continue
		var owning_building: Dictionary = buildings[owner_id]
		var owner := String(owner_id) + ":" + vehicle
		occupied[owner] = int(occupied.get(owner, 0)) + 1
		var hangar_cap := StationSystem.fleet_capacity(owning_building, vehicle)
		if int(occupied[owner]) + int(owning_building.station.fleet[vehicle]) > hangar_cap:
			errors.append(_error("在途与停泊载具超过机库容量"))
	return errors

static func _number(value: Variant, low: float, high: float) -> bool:
	return (value is int or value is float) and is_finite(float(value)) and float(value) >= low and float(value) <= high

static func _route_capacity(data: Dictionary, source: Dictionary, target: Dictionary, interplanetary: bool) -> float:
	var rules := GameState.new()
	if data.get("completed_technologies") is Array: rules.completed_technologies = data.completed_technologies
	if data.get("technology_levels") is Dictionary: rules.technology_levels = data.technology_levels
	var base := 100.0 if interplanetary else 25.0 if StationSystem.is_source(source.type) or StationSystem.is_source(target.type) else 20.0
	return roundf(base * rules.get_technology_effect_multiplier("logistics_capacity"))

static func _integer(value: Variant, low: int, high: int) -> bool:
	return _number(value, low, high) and float(value) == floorf(float(value))

static func _error(message: String) -> Dictionary:
	return {"code": "invalid_logistics_state", "entity_type": "logistics", "entity_id": "", "message": message}



static func normalize_integer_fields(payload: Dictionary) -> void:
	var buildings: Variant = payload.get("buildings")
	if buildings is Dictionary:
		for building in buildings.values():
			if not building is Dictionary or not building.get("station") is Dictionary:
				continue
			var station: Dictionary = building.station
			if station.get("fleet") is Dictionary:
				for item in StationSystem.FLEET_ITEMS:
					if _integer(station.fleet.get(item), 0, StationSystem.fleet_capacity(building, item)):
						station.fleet[item] = int(station.fleet[item])
			if station.get("slots") is Array:
				for slot in station.slots:
					if slot is Dictionary:
						for field in ["cursor", "priority"]:
							if _integer(slot.get(field), 0, 1000000):
								slot[field] = int(slot[field])
						if _integer(slot.get("warper_budget"), 1, 4): slot.warper_budget = int(slot.warper_budget)
			if _integer(station.get("hub_priority"), 0, 2): station.hub_priority = int(station.hub_priority)
	var routes: Variant = payload.get("logistics_routes")
	if routes is Dictionary:
		for route in routes.values():
			if route is Dictionary:
				for field in ["source_slot", "target_slot", "warpers_per_vessel"]:
					if _integer(route.get(field), 0, 4):
						route[field] = int(route[field])
