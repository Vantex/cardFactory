class_name StationSystem
extends RefCounted

const TYPES := ["planetary_logistics_station", "interstellar_logistics_station", "dsp_planetary_logistics_station", "dsp_interstellar_logistics_station", "dsp_orbital_collector"]
const FLEET_ITEMS := ["logistics_drone", "logistics_vessel", "space_warper"]
var game_state: GameState
var remote_edits := false

func _init(state: GameState, allow_remote_edits: bool = false) -> void:
	game_state = state
	remote_edits = allow_remote_edits

static func is_station(type: String) -> bool:
	return type in TYPES or DataManager.get_building(type).get("kind") == "station"

static func is_interstellar(type: String) -> bool:
	return type in [TYPES[1], TYPES[3]]

static func is_source(type: String) -> bool:
	return type in [TYPES[2], TYPES[3], TYPES[4]]

static func is_remote_endpoint(type: String) -> bool:
	return is_interstellar(type) or type == TYPES[4]

static func slot_count(type: String) -> int:
	if type == TYPES[4]: return 3
	return 5 if is_source(type) else 4

static func empty_station(type: String = "") -> Dictionary:
	var slots: Array = []
	for i in range(slot_count(type)):
		var slot := {"item_id": "", "mode": "storage", "capacity": 1000.0 if is_source(type) else 100.0, "min_load": 1.0 if is_source(type) else 0.1, "priority": 1 if is_source(type) else 0, "amount": 0.0, "cursor": 0}
		if is_source(type): slot.merge({"local_mode": "storage", "remote_mode": "storage", "min_stock": 0.0, "max_stock": 0.0, "route_policy": "relay-preferred", "warper_budget": 2})
		if type == TYPES[4]: slot.capacity = 2000.0
		slots.append(slot)
	return {"enabled": true, "slots": slots, "fleet": {"logistics_drone": 0, "logistics_vessel": 0, "space_warper": 0}, "warp_enabled": true, "warper_auto_refill": false, "warper_target": 50}

static func mode_for(building: Dictionary, slot: Dictionary, remote: bool) -> String:
	if is_source(String(building.type)): return String(slot.get("remote_mode" if remote else "local_mode", "storage"))
	return String(slot.mode)

static func capacity_for(slot: Dictionary, state: GameState = null, building: Dictionary = {}) -> float:
	if state != null:
		if String(building.get("type", "")).is_empty(): return 0.0
		if DataManager.get_building(String(building.type)).has("source_id"):
			return preload("res://scripts/game/SourceEntityCapacitySystem.gd").station_slot_capacity(state, building, slot)
	return minf(float(slot.capacity), float(slot.max_stock)) if float(slot.get("max_stock", 0)) > 0 else float(slot.capacity)

static func storage_capacity_for(building: Dictionary, slot: Dictionary) -> float:
	# Saved source stock and promised deliveries survive reduced admission limits.
	if is_source(String(building.type)):
		var count := stack_count(building)
		var legacy := float((2000 if building.type == TYPES[4] else 1000) * count)
		var definition := DataManager.get_building(String(building.type))
		var base := maxf(0, floorf(float(definition.get("source_output_capacity", 0))))
		var source_bound := minf(preload("res://scripts/game/SourceEntityCapacitySystem.gd").MAXIMUM, base * count)
		return maxf(legacy, source_bound)
	return float(slot.capacity)

func get_station_info(id: String) -> Dictionary:
	return game_state.buildings.get(id, {}).get("station", {}).duplicate(true)

func logistics_snapshot(id: String) -> Dictionary:
	var building: Dictionary = game_state.buildings.get(id, {})
	if not building.has("station"): return {}
	var local_capacity := int(roundf(25 * game_state.get_technology_effect_multiplier("logistics_capacity")))
	var remote_capacity := int(roundf(100 * game_state.get_technology_effect_multiplier("logistics_capacity")))
	var speed := game_state.get_technology_effect_multiplier("logistics_speed") * GameModeSystem.new(game_state).multiplier("logistics")
	var routes := []
	for route in game_state.logistics_routes.values():
		if id in [route.source_id, route.target_id, route.get("owner_id", route.source_id)] or id in route.get("waypoint_ids", []): routes.append(route.duplicate(true))
	var slots := []
	for slot in building.station.slots:
		slots.append({"item_id": slot.item_id, "capacity": capacity_for(slot, game_state, building), "minimum_local_cargo": int(ceilf(local_capacity * float(slot.min_load))), "minimum_remote_cargo": int(ceilf(remote_capacity * float(slot.min_load))), "local_mode": mode_for(building, slot, false), "remote_mode": mode_for(building, slot, true)})
	return {"station": get_station_info(id), "slots": slots, "routes": routes, "local_cargo_capacity": local_capacity, "remote_cargo_capacity": remote_capacity, "local_trip_seconds": 8 / maxf(speed, 0.000001), "busy_drones": busy_fleet(id, "logistics_drone"), "busy_vessels": busy_fleet(id, "logistics_vessel"), "fleet": building.station.fleet.duplicate(true)}

static func stack_count(building: Dictionary) -> int:
	return int(building.get("station_stack_count", 1))

static func fleet_capacity(building: Dictionary, item: String) -> int:
	return (10 if item == "logistics_vessel" else 50) * stack_count(building) if is_source(String(building.type)) else 999

func set_stack_target(id: String, target: int) -> Dictionary:
	if not _editable(id) or not is_source(game_state.buildings[id].type) or target < 1 or target > 100000000: return result(false, "请选择源物流站并设置 1～100000000 座")
	var building: Dictionary = game_state.buildings[id]
	if has_route(id) or building.station.has("quantum_transition") or SystemHubLogisticsSystem.is_elevator(building): return result(false, "请等待航线与模式交接完成，并退出电梯模式")
	var current := stack_count(building)
	var delta := target - current
	var owned := float(game_state.construction_inventory.get(building.type, 0))
	if delta > owned or owned - delta > game_state.construction_capacity(building.type): return result(false, "施工件不足或退款托盘已满")
	var base_capacity := 2000 if building.type == OrbitalCollectorSystem.TYPE else 1000
	for slot in building.station.slots:
		if float(slot.amount) > base_capacity * target: return result(false, "请先取出超过缩减后容量的货物")
	for item in FLEET_ITEMS:
		if int(building.station.fleet[item]) > (10 if item == "logistics_vessel" else 50) * target: return result(false, "请先取回超过缩减后机库容量的载具")
	game_state.construction_inventory[building.type] = owned - delta
	building.station_stack_count = target
	for slot in building.station.slots: slot.capacity = float(base_capacity * target)
	return result(true, "物流站堆叠已调整，施工件与货物保持守恒")

func has_route(id: String) -> bool:
	for bucket in game_state.galactic_hub_network.get("fleet_returns", []):
		if bucket.get("owners", {}).has(id): return true
	for route in game_state.logistics_routes.values():
		if route.source_id == id or route.target_id == id or id in route.get("waypoint_ids", []):
			return true
	return false

func configure_slots(ids: Array, index: int, item: String, mode: String, capacity: float, min_load: float, priority: int, scope: String = "local") -> Dictionary:
	if ids.is_empty() or index < 0 or (item != "" and DataManager.get_item(item).is_empty()) or mode not in ["supply", "demand", "storage"] or scope not in ["local", "remote"]:
		return result(false, "槽位、物品或模式无效")
	if not is_finite(capacity) or capacity < 1 or capacity > 200000000000 or not is_finite(min_load) or min_load < 0.01 or min_load > 1 or priority < 0 or priority > 2:
		return result(false, "容量、最低装载或优先级无效")
	var seen := {}
	for id in ids:
		if seen.has(id) or not _editable(id) or index >= game_state.buildings[id].station.slots.size():
			return result(false, "只能配置当前行星未锁定的物流站")
		var type := String(game_state.buildings[id].type)
		if type == TYPES[4]: return result(false, "采集器槽位固定，请选择采集物品")
		if (not is_source(type) and capacity > 999) or (is_source(type) and (min_load not in [0.1, 0.25, 0.5, 1.0] or capacity > 1000 * stack_count(game_state.buildings[id]))) or (scope == "remote" and not is_interstellar(type)): return result(false, "该站容量、装载比例或物流范围不支持")
		seen[id] = true
		var slot: Dictionary = game_state.buildings[id].station.slots[index]
		if has_route(id):
			return result(false, "请等待关联航线返航后再配置")
		if slot.amount > capacity or (slot.item_id != item and slot.amount > 0):
			return result(false, "请先取空槽位物资")
		for other_index in range(game_state.buildings[id].station.slots.size()):
			if other_index != index and item != "" and game_state.buildings[id].station.slots[other_index].item_id == item:
				return result(false, "同站物品不能重复配置")
		if slot.item_id != item:
			var building: Dictionary = game_state.buildings[id]
			if float(building.input_buffer.get(slot.item_id, 0)) > 0 or float(building.output_buffer.get(slot.item_id, 0)) > 0:
				return result(false, "请先清空该物品的输入和输出缓存")
			for connection in game_state.get_connections_for_building(id):
				if connection.item_id == slot.item_id:
					return result(false, "请先拆除该物品线路")
	for id in ids:
		var slot: Dictionary = game_state.buildings[id].station.slots[index]
		slot.merge({"item_id": item, "mode": mode, "capacity": capacity, "min_load": min_load, "priority": priority}, true)
		if is_source(String(game_state.buildings[id].type)):
			slot[scope + "_mode"] = mode if not item.is_empty() else "storage"
	return result(true, "物流槽位已配置")

func transfer_cargo(id: String, index: int, amount: float, deposit: bool) -> Dictionary:
	if not _editable(id) or index < 0 or index >= game_state.buildings[id].station.slots.size() or not is_finite(amount) or amount <= 0:
		return result(false, "物流转移参数无效")
	var slot: Dictionary = game_state.buildings[id].station.slots[index]
	var inventory := InventorySystem.new(game_state)
	if slot.item_id == "":
		return result(false, "请先配置物品")
	if deposit and game_state.buildings[id].type == TYPES[4]: return result(false, "轨道采集器只支持采集和取出")
	if deposit:
		if float(slot.amount) + amount + reserved(id, index) > capacity_for(slot, game_state, game_state.buildings[id]):
			return result(false, "槽位容量不足（含在途预留）")
		var removed := inventory.try_remove(slot.item_id, amount, game_state.buildings[id].planet_id)
		if not removed.ok:
			return removed
		slot.amount += amount
	else:
		if float(slot.amount) < amount:
			return result(false, "槽位库存不足")
		var added := inventory.try_add(slot.item_id, amount, game_state.buildings[id].planet_id)
		if not added.ok:
			return added
		slot.amount -= amount
	return result(true, "货物已转移")

func transfer_fleet(id: String, item: String, count: int, deposit: bool) -> Dictionary:
	if not _editable(id) or item not in FLEET_ITEMS or count <= 0:
		return result(false, "载具转移参数无效")
	var building: Dictionary = game_state.buildings[id]
	if building.type == TYPES[4]: return result(false, "轨道采集器没有载具机库")
	if not is_interstellar(building.type) and item != "logistics_drone":
		return result(false, "行星站仅支持运输机")
	var fleet: Dictionary = building.station.fleet
	if is_source(String(building.type)) and item != "space_warper":
		var busy := busy_fleet(id, item)
		return set_fleet_target(id, item, int(fleet[item]) + busy + (count if deposit else -count))
	var inventory := InventorySystem.new(game_state)
	if deposit:
		var occupied := int(fleet[item])
		for route in game_state.logistics_routes.values():
			if route.source_id == id and route.vehicle == item:
				occupied += 1
		if occupied + count > fleet_capacity(building, item):
			return result(false, "机库容量不足")
		var removed := inventory.try_remove(item, count, building.planet_id)
		if not removed.ok:
			return removed
		fleet[item] += count
	else:
		if int(fleet[item]) < count:
			return result(false, "停泊载具或翘曲器不足")
		var added := inventory.try_add(item, count, building.planet_id)
		if not added.ok:
			return added
		fleet[item] -= count
	return result(true, "载具/翘曲器已转移")

func reserved(id: String, index: int) -> float:
	var amount := 0.0
	for route in game_state.logistics_routes.values():
		if route.target_id == id and int(route.target_slot) == index:
			amount += float(route.amount)
	return amount

func busy_fleet(id: String, item: String) -> int:
	var busy := 0
	if item == "logistics_vessel":
		for bucket in game_state.galactic_hub_network.get("fleet_returns", []): busy += int(bucket.get("owners", {}).get(id, 0))
	for route in game_state.logistics_routes.values():
		if route.get("owner_id", route.source_id) == id and route.vehicle == item: busy += 1
	return busy

func set_fleet_target(id: String, item: String, target: int) -> Dictionary:
	if not _editable(id) or game_state.buildings[id].type == TYPES[4] or item not in ["logistics_drone", "logistics_vessel"] or target < 0 or (item == "logistics_vessel" and not is_interstellar(game_state.buildings[id].type)): return result(false, "舰队目标无效")
	var fleet: Dictionary = game_state.buildings[id].station.fleet
	var cap := fleet_capacity(game_state.buildings[id], item)
	var busy := busy_fleet(id, item)
	var requested := mini(target, cap)
	var parked := maxi(0, requested - busy)
	var current := int(fleet[item])
	var available := int(game_state.portable_fleet.get(item, 0))
	var loaded := mini(maxi(0, parked - current), available)
	var unloaded := maxi(0, current - parked)
	fleet[item] = current + loaded - unloaded
	game_state.portable_fleet[item] = available - loaded + unloaded
	return {"ok": true, "message": "舰队目标已更新；停泊 %d，在途 %d，缺少 %d" % [fleet[item], busy, maxi(0, requested - busy - int(fleet[item]))], "busy": busy, "loaded": loaded, "unloaded": unloaded, "final": int(fleet[item]) + busy}

func set_slot_limits(id: String, index: int, minimum: int, maximum: int) -> Dictionary:
	if not _editable(id) or not is_source(game_state.buildings[id].type) or index < 0 or index >= game_state.buildings[id].station.slots.size() or minimum < 0 or maximum < 0 or minimum > 100000000 or maximum > 100000000: return result(false, "库存限额无效")
	var slot: Dictionary = game_state.buildings[id].station.slots[index]
	if maximum > 0 and minimum > maximum: minimum = maximum
	slot.min_stock = float(minimum)
	slot.max_stock = float(maximum)
	return result(true, "库存限额已更新")

func set_route_options(id: String, index: int, policy: String, budget: int) -> Dictionary:
	if not _editable(id) or game_state.buildings[id].type != TYPES[3] or index < 0 or index >= slot_count(TYPES[3]) or policy not in ["direct", "relay-preferred", "relay-required"] or budget < 1 or budget > 4: return result(false, "请选择源星际站，航线策略和翘曲预算无效")
	var slot: Dictionary = game_state.buildings[id].station.slots[index]
	if String(slot.item_id).is_empty(): return result(false, "请先配置槽位物品")
	slot.route_policy = policy
	slot.warper_budget = budget
	return result(true, "新派遣使用所选航线策略；在途航线继续原计划")

func set_hub(id: String, enabled: bool, priority: int) -> Dictionary:
	if not _editable(id) or game_state.buildings[id].type != TYPES[3] or priority < 0 or priority > 2: return result(false, "请选择源星际站并设定中继优先级")
	game_state.buildings[id].station.hub_enabled = enabled
	game_state.buildings[id].station.hub_priority = priority
	return result(true, "中继设置已更新")

func _editable(id: String) -> bool:
	var b: Dictionary = game_state.buildings.get(id, {})
	return b.has("station") and (b.get("planet_id", "") == game_state.active_planet_id or (remote_edits and is_source(String(b.get("type", ""))) and game_state.colonized_planet_ids.has(b.get("planet_id", "")))) and not b.get("interaction_locked", false)

static func result(ok: bool, message: String) -> Dictionary:
	return {"ok": ok, "message": message}




func set_enabled(ids: Array, enabled: bool) -> Dictionary:
	if ids.is_empty():
		return result(false, "请选择物流站")
	for id in ids:
		if not _editable(id):
			return result(false, "只能控制当前行星未锁定的物流站")
	for id in ids:
		game_state.buildings[id].station.enabled = enabled
	return result(true, "已启用调度" if enabled else "已停发，现有航线继续送达和返航")

func set_warp_enabled(id: String, enabled: bool) -> Dictionary:
	if not _editable(id) or not is_interstellar(game_state.buildings[id].type): return result(false, "请选择当前行星的星际物流站")
	if enabled and not game_state.completed_technologies.has("dsp_space_warp"): return result(false, "需要空间翘曲科技")
	game_state.buildings[id].station.warp_enabled = enabled
	return result(true, "跨恒星翘曲已更新")

func set_warper_refill(id: String, enabled: bool, target: int) -> Dictionary:
	if not _editable(id) or not is_interstellar(game_state.buildings[id].type) or target < 1 or target > fleet_capacity(game_state.buildings[id], "space_warper"): return result(false, "请选择星际站并设定 1～50 个翘曲器")
	if enabled and not game_state.completed_technologies.has("dsp_space_warp"): return result(false, "需要空间翘曲科技")
	var station: Dictionary = game_state.buildings[id].station
	station.warper_auto_refill = enabled
	station.warper_target = target
	return result(true, "翘曲器自动补充已更新")
