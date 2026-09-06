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
		if b.get("type", "") not in StationSystem.TYPES:
			if b.has("station"):
				errors.append(_error("非物流建筑包含站点状态"))
			continue
		if not b.get("input_buffer") is Dictionary or not b.get("output_buffer") is Dictionary:
			errors.append(_error("物流站缓存结构无效"))
		var station: Variant = b.get("station")
		if not station is Dictionary or not station.get("enabled") is bool or not station.get("slots") is Array or station.slots.size() != 4 or not station.get("fleet") is Dictionary:
			errors.append(_error("物流站结构无效"))
			continue
		var fleet: Dictionary = station.fleet
		if fleet.size() != 3:
			errors.append(_error("载具集合无效"))
		for item in StationSystem.FLEET_ITEMS:
			if not _integer(fleet.get(item), 0, 999):
				errors.append(_error("载具数量无效"))
			elif b.type == StationSystem.TYPES[0] and item != "logistics_drone" and fleet[item] != 0:
				errors.append(_error("行星站不支持飞船和翘曲器"))
		var seen := {}
		for slot in station.slots:
			if not slot is Dictionary:
				errors.append(_error("槽位必须为字典"))
				continue
			var item: Variant = slot.get("item_id")
			if not item is String or (item != "" and (DataManager.get_item(item).is_empty() or seen.has(item))):
				errors.append(_error("槽位物品无效或重复"))
			else:
				seen[item] = true
			if slot.get("mode") not in ["supply", "demand", "storage"] or not _number(slot.get("capacity"), 1, 999) or not _number(slot.get("amount"), 0, 999) or not _number(slot.get("min_load"), 0.01, 1) or not _integer(slot.get("priority"), 0, 2) or not _integer(slot.get("cursor"), 0, 1000000):
				errors.append(_error("槽位数值无效"))
			elif float(slot.amount) > float(slot.capacity) or (item == "" and slot.amount != 0):
				errors.append(_error("槽位容量或空槽物资无效"))
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
		if not a.has("station") or not b.has("station") or r.get("source_id") == r.get("target_id") or not _integer(r.get("source_slot"), 0, 3) or not _integer(r.get("target_slot"), 0, 3):
			errors.append(_error("航线端点无效"))
			continue
		var source_slot: Dictionary = a.station.slots[int(r.source_slot)]
		var target_slot: Dictionary = b.station.slots[int(r.target_slot)]
		var interplanetary: bool = a.planet_id != b.planet_id
		var vehicle := "logistics_vessel" if interplanetary else "logistics_drone"
		if not r.get("interplanetary") is bool or r.interplanetary != interplanetary or r.get("vehicle") != vehicle or (interplanetary and (a.type != StationSystem.TYPES[1] or b.type != StationSystem.TYPES[1])):
			errors.append(_error("航线载具与行星边界不符"))
		if r.get("item_id", "") == "" or r.get("item_id") != source_slot.item_id or r.get("item_id") != target_slot.item_id or source_slot.mode != "supply" or target_slot.mode != "demand":
			errors.append(_error("航线货物不匹配"))
		if r.get("phase") not in ["outbound", "returning"] or not _number(r.get("duration"), 1, 100000) or not _number(r.get("remaining"), 0, 100000) or not _number(r.get("amount"), 0, 100 if interplanetary else 20):
			errors.append(_error("航线阶段或数值无效"))
		elif float(r.remaining) > float(r.duration) or (r.phase == "returning" and r.amount != 0) or (r.phase == "outbound" and r.amount <= 0):
			errors.append(_error("航线进度与货物状态不符"))
		var owner := String(r.source_id) + ":" + vehicle
		occupied[owner] = int(occupied.get(owner, 0)) + 1
		if int(occupied[owner]) + int(a.station.fleet[vehicle]) > 999:
			errors.append(_error("在途与停泊载具超过机库容量"))
	return errors

static func _number(value: Variant, low: float, high: float) -> bool:
	return (value is int or value is float) and is_finite(float(value)) and float(value) >= low and float(value) <= high

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
					if _integer(station.fleet.get(item), 0, 999):
						station.fleet[item] = int(station.fleet[item])
			if station.get("slots") is Array:
				for slot in station.slots:
					if slot is Dictionary:
						for field in ["cursor", "priority"]:
							if _integer(slot.get(field), 0, 1000000):
								slot[field] = int(slot[field])
	var routes: Variant = payload.get("logistics_routes")
	if routes is Dictionary:
		for route in routes.values():
			if route is Dictionary:
				for field in ["source_slot", "target_slot"]:
					if _integer(route.get(field), 0, 3):
						route[field] = int(route[field])
