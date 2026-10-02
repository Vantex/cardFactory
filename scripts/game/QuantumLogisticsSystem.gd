class_name QuantumLogisticsSystem
extends RefCounted

const SETTLEMENT_SECONDS := 5
const UNIT_CAP_PER_MINUTE := 5000
const CAPACITY_MIN := 10000
const CAPACITY_MAX := 10000000000

var state: GameState

func _init(game_state: GameState) -> void:
	state = game_state

func upgrade_station(id: String) -> Dictionary:
	var building: Dictionary = state.buildings.get(id, {})
	if not _editable(building) or not StationSystem.is_interstellar(String(building.get("type", ""))): return _result(false, "请选择未锁定的星际物流站")
	if not _technology_ready(): return _result(false, "需要量子物流网络科技")
	if int(building.station.get("tier", 1)) >= 2: return _result(false, "该站已经是 Mk.II")
	building.station["tier"] = 2
	return _result(true, "已升级为 Mk.II，可独立挂接量子网络")

func upgrade_all(system_id: String = "") -> Dictionary:
	var changed := []
	var skipped := []
	var ids := state.buildings.keys()
	ids.sort()
	for id in ids:
		var building: Dictionary = state.buildings[id]
		if not StationSystem.is_interstellar(String(building.get("type", ""))): continue
		if system_id != "" and GalaxySystem.new(state).get_planet(building.planet_id).system_id != system_id: continue
		var result := upgrade_station(id)
		if result.ok: changed.append(id)
		else: skipped.append({"id": id, "reason": result.message})
	return {"ok": true, "message": "升级 %d 站，跳过 %d 站" % [changed.size(), skipped.size()], "changed": changed, "skipped": skipped}

func attach(id: String) -> Dictionary:
	var building: Dictionary = state.buildings.get(id, {})
	if not _editable(building) or not StationSystem.is_interstellar(String(building.get("type", ""))): return _result(false, "请选择未锁定的星际物流站")
	if not _technology_ready(): return _result(false, "需要量子物流网络科技")
	if int(building.station.get("tier", 1)) < 2: return _result(false, "请先升级到 Mk.II")
	if building.station.get("quantum_mode", "legacy") != "legacy": return _result(false, "该站正在挂接或已经接入")
	building.station["quantum_mode"] = "transitioning"
	building.station["quantum_transition"] = {"target_mode": "quantum", "boundary_second": (int(floorf(state.elapsed_time / SETTLEMENT_SECONDS)) + 1) * SETTLEMENT_SECONDS}
	return _result(true, "挂接已排队；停止新派遣，尾货和载具完整返航后在五秒边界交接")

func attach_all(system_id: String = "") -> Dictionary:
	var started := []
	var skipped := []
	var ids := state.buildings.keys()
	ids.sort()
	for id in ids:
		var building: Dictionary = state.buildings[id]
		if not StationSystem.is_interstellar(String(building.get("type", ""))): continue
		if not system_id.is_empty() and GalaxySystem.new(state).get_planet(building.planet_id).system_id != system_id: continue
		var result := attach(id)
		if result.ok: started.append(id)
		else: skipped.append({"id": id, "reason": result.message})
	return {"ok": true, "message": "开始挂接 %d 站，跳过 %d 站" % [started.size(), skipped.size()], "started": started, "skipped": skipped}

func cancel(id: String) -> Dictionary:
	var building: Dictionary = state.buildings.get(id, {})
	if not _editable(building) or not building.station.has("quantum_transition"): return _result(false, "没有可取消的挂接")
	building.station.quantum_mode = "quantum" if building.station.quantum_transition.target_mode == "legacy" else "legacy"
	building.station.erase("quantum_transition")
	return _result(true, "已取消挂接；在途货物和载具保持原归属")

func set_collector_mode(id: String, enabled: bool) -> Dictionary:
	var building: Dictionary = state.buildings.get(id, {})
	if building.get("type") != OrbitalCollectorSystem.TYPE or not _editable(building): return _result(false, "请选择未锁定的轨道采集器")
	if enabled and not _technology_ready(): return _result(false, "需要量子物流网络科技")
	if building.station.has("quantum_transition"): return _result(false, "已有模式交接正在进行")
	var target := "quantum" if enabled else "legacy"
	if building.station.get("quantum_mode", "legacy") == target: return _result(false, "采集器已经使用所选模式")
	building.station["quantum_mode"] = "transitioning"
	building.station["quantum_transition"] = {"target_mode": target, "boundary_second": (int(floorf(state.elapsed_time / SETTLEMENT_SECONDS)) + 1) * SETTLEMENT_SECONDS}
	return _result(true, "采集器模式交接已排队，已有航线完整结算")

func set_all_collectors(enabled: bool, system_id: String = "") -> Dictionary:
	var changed := 0
	var skipped := 0
	var ids := state.buildings.keys()
	ids.sort()
	for id in ids:
		var building: Dictionary = state.buildings[id]
		if building.get("type") != OrbitalCollectorSystem.TYPE: continue
		if not system_id.is_empty() and GalaxySystem.new(state).get_planet(building.planet_id).system_id != system_id: continue
		if set_collector_mode(id, enabled).ok: changed += 1
		else: skipped += 1
	return _result(true, "采集器切换 %d 台，跳过 %d 台" % [changed, skipped])

func set_item_capacity(item: String, capacity: String) -> Dictionary:
	if DataManager.get_item(item).is_empty() or not _decimal(capacity, CAPACITY_MIN, CAPACITY_MAX): return _result(false, "量子容量必须是 10000～10000000000 的十进制整数")
	_network().item_capacities[item] = str(int(capacity))
	return _result(true, "物品容量已更新；已有库存完整保留")

func withdraw(item: String, requested: int, planet_id: String = "") -> Dictionary:
	if DataManager.get_item(item).is_empty() or requested < 1 or requested > 999: return _result(false, "交付数量无效")
	var network := _network()
	var stock := int(network.inventory.get(item, "0"))
	if stock < requested: return _result(false, "量子库存不足")
	var added := InventorySystem.new(state).try_add(item, requested, planet_id)
	if not added.ok: return added
	network.inventory[item] = str(stock - requested)
	return _result(true, "量子物资已转入行星托盘")

func deposit(item: String, requested: int) -> int:
	if requested < 1 or state.quantum_network.is_empty() or not state.quantum_network.enabled or DataManager.get_item(item).is_empty(): return 0
	var network := state.quantum_network
	var stock := int(network.inventory.get(item, "0"))
	var capacity := int(network.item_capacities.get(item, str(CAPACITY_MAX)))
	var accepted := mini(requested, maxi(0, capacity - stock))
	if accepted > 0: network.inventory[item] = str(stock + accepted)
	return accepted

func free_capacity(item: String) -> float:
	if state.quantum_network.is_empty() or not state.quantum_network.enabled: return 0.0
	return maxf(0, float(int(state.quantum_network.item_capacities.get(item, str(CAPACITY_MAX))) - int(state.quantum_network.inventory.get(item, "0"))))

func has_remote_routes(id: String) -> bool:
	for route in state.logistics_routes.values():
		if route.interplanetary and (route.source_id == id or route.target_id == id or route.get("owner_id", route.source_id) == id or id in route.get("waypoint_ids", [])): return true
	return false

func snapshot() -> Dictionary:
	var network := state.quantum_network.duplicate(true) if not state.quantum_network.is_empty() else _initial()
	var count := 0
	for building in state.buildings.values():
		if building.get("station", {}).get("quantum_mode", "legacy") == "quantum" and StationSystem.is_interstellar(String(building.get("type", ""))): count += StationSystem.stack_count(building)
	var level := InfiniteResearchSystem.new(state).level("galactic_logistics")
	return {"network": network, "active_towers": count, "per_minute": UNIT_CAP_PER_MINUTE * pow(1.0 + 0.05 * level, 2) * count}

func update() -> void:
	for id in state.buildings:
		var building: Dictionary = state.buildings[id]
		if not building.get("station", {}).has("quantum_transition"): continue
		var transition: Dictionary = building.station.quantum_transition
		if state.elapsed_time + SimulationEngine.STEP_EPSILON < float(transition.boundary_second) or has_remote_routes(id): continue
		building.station.quantum_mode = transition.target_mode
		building.station.erase("quantum_transition")
		_network().enabled = true
	if state.quantum_network.is_empty() or not state.quantum_network.enabled: return
	var boundary := int(floorf((state.elapsed_time + SimulationEngine.STEP_EPSILON) / SETTLEMENT_SECONDS))
	if boundary <= int(state.quantum_network.settled_boundary): return
	state.quantum_network.settled_boundary = boundary
	_settle()

func _settle() -> void:
	var uploads := []
	var downloads := []
	var count := 0
	var ids := state.buildings.keys()
	ids.sort()
	for id in ids:
		var building: Dictionary = state.buildings[id]
		if not StationSystem.is_remote_endpoint(String(building.get("type", ""))) or building.get("station", {}).get("quantum_mode", "legacy") != "quantum": continue
		var collector: bool = building.get("type") == OrbitalCollectorSystem.TYPE
		if not collector: count += StationSystem.stack_count(building)
		if not building.station.enabled: continue
		for index in range(building.station.slots.size()):
			var slot: Dictionary = building.station.slots[index]
			if String(slot.item_id).is_empty(): continue
			var mode := StationSystem.mode_for(building, slot, true)
			if mode == "supply" and not collector:
				var accepted := deposit(slot.item_id, int(floorf(maxf(0, float(slot.amount) - float(slot.get("min_stock", 0))))))
				slot.amount -= float(accepted)
				continue
			var requested := int(floorf(maxf(0, float(slot.amount) - float(slot.get("min_stock", 0))))) if mode == "supply" else int(floorf(maxf(0, StationSystem.capacity_for(slot) - float(slot.amount))))
			if requested < 1 or mode == "storage": continue
			var entry := {"key": "%s:%d" % [id, index], "id": id, "index": index, "item": slot.item_id, "amount": requested, "priority": int(slot.priority)}
			if mode == "supply": uploads.append(entry)
			else: downloads.append(entry)
	var level := InfiniteResearchSystem.new(state).level("galactic_logistics")
	var cap := int(floorf(UNIT_CAP_PER_MINUTE * pow(1.0 + 0.05 * level, 2) * count * SETTLEMENT_SECONDS / 60.0))
	var network := _network()
	_settle_direction(network, downloads, cap, false)
	_settle_direction(network, uploads, cap, true)

func _settle_direction(network: Dictionary, requests: Array, cap: int, upload: bool) -> void:
	var by_item := {}
	for request in requests:
		if not by_item.has(request.item): by_item[request.item] = []
		by_item[request.item].append(request)
	var feasible := []
	var cursor_field := "upload_cursors" if upload else "routing_cursors"
	var items := by_item.keys()
	items.sort()
	for item in items:
		var stock := int(network.inventory.get(item, "0"))
		var budget := maxi(0, int(network.item_capacities.get(item, str(CAPACITY_MAX))) - stock) if upload else stock
		var allocated := _allocate(budget, by_item[item], int(network[cursor_field].get(item, 0)))
		for request in by_item[item]:
			var prepared: Dictionary = request.duplicate()
			prepared.amount = int(allocated.get(request.key, 0))
			feasible.append(prepared)
	var result := _allocate(cap, feasible, 0)
	for request in feasible:
		var amount := int(result.get(request.key, 0))
		if amount < 1: continue
		var slot: Dictionary = state.buildings[request.id].station.slots[request.index]
		slot.amount = float(slot.amount) + (-amount if upload else amount)
		network.inventory[request.item] = str(int(network.inventory.get(request.item, "0")) + (amount if upload else -amount))
	for item in items:
		if by_item[item].size() > 1: network[cursor_field][item] = (int(network[cursor_field].get(item, 0)) + 1) % by_item[item].size()

static func _allocate(budget: int, requests: Array, cursor: int) -> Dictionary:
	var values := {}
	var remaining := maxi(0, budget)
	for priority in [2, 1, 0]:
		var group: Array = requests.filter(func(row): return row.priority == priority and int(row.amount) > 0)
		group.sort_custom(func(a, b): return a.key < b.key)
		if group.is_empty() or remaining < 1: continue
		var total := 0
		for row in group: total += int(row.amount)
		var available := mini(remaining, total)
		var allocated := 0
		for row in group:
			var amount := int(available * int(row.amount) / total)
			values[row.key] = amount
			allocated += amount
		var remainder := available - allocated
		for offset in range(group.size()):
			if remainder < 1: break
			var row: Dictionary = group[posmod(cursor + offset, group.size())]
			if int(values[row.key]) >= int(row.amount): continue
			values[row.key] += 1
			remainder -= 1
		remaining -= available - remainder
	return values

func _network() -> Dictionary:
	if state.quantum_network.is_empty():
		state.quantum_network = _initial()
		state.quantum_network.settled_boundary = int(floorf(state.elapsed_time / SETTLEMENT_SECONDS))
	return state.quantum_network

static func _initial() -> Dictionary:
	return {"version": 1, "enabled": false, "inventory": {}, "item_capacities": {}, "routing_cursors": {}, "upload_cursors": {}, "settled_boundary": 0}

func _technology_ready() -> bool:
	return DataManager.source_technology_unlocked(state, "quantum_logistics_network")

static func _editable(building: Dictionary) -> bool:
	return building.has("station") and not building.get("interaction_locked", false)

static func _decimal(value: Variant, minimum: int, maximum: int) -> bool:
	if not value is String or not BlackHoleSystem._decimal_valid(value) or value.length() > 11: return false
	return int(value) >= minimum and int(value) <= maximum

static func validate(data: Dictionary) -> Array:
	var errors := []
	var network: Variant = data.get("quantum_network", {})
	if not network is Dictionary: return ["量子网络必须是字典"]
	if not network.is_empty():
		if network.size() != 7 or network.get("version") != 1 or not network.get("enabled") is bool or not GalacticExportSystem._nonnegative_integer(network.get("settled_boundary")): errors.append("量子网络结构无效")
		for field in ["inventory", "item_capacities", "routing_cursors", "upload_cursors"]:
			if not network.get(field) is Dictionary:
				errors.append("量子网络集合无效")
				continue
			for item in network[field]:
				if not item is String or DataManager.get_item(item).is_empty(): errors.append("量子物品无效")
				if field in ["inventory", "item_capacities"]:
					if not _decimal(network[field][item], CAPACITY_MIN if field == "item_capacities" else 0, CAPACITY_MAX): errors.append("量子库存或容量无效")
				elif not GalacticExportSystem._nonnegative_integer(network[field][item]): errors.append("量子调度游标无效")
	var buildings: Variant = data.get("buildings", {})
	if not buildings is Dictionary: return errors
	for building in buildings.values():
		if not building is Dictionary or not building.get("station") is Dictionary: continue
		var station: Dictionary = building.station
		if not station.has("tier") and not station.has("quantum_mode") and not station.has("quantum_transition"): continue
		var collector: bool = building.get("type") == OrbitalCollectorSystem.TYPE
		if not StationSystem.is_remote_endpoint(String(building.get("type", ""))) or not GalacticExportSystem._nonnegative_integer(station.get("tier", 1)) or int(station.get("tier", 1)) not in [1, 2] or station.get("quantum_mode", "legacy") not in ["legacy", "transitioning", "quantum"]: errors.append("量子站点模式无效")
		var mode: String = station.get("quantum_mode", "legacy")
		if mode != "legacy" and not collector and int(station.get("tier", 1)) < 2: errors.append("量子站点尚未升级")
		if mode == "quantum" and (network.is_empty() or not network.get("enabled", false)): errors.append("量子站点缺少共享网络")
		if mode == "transitioning":
			var transition: Variant = station.get("quantum_transition")
			if not transition is Dictionary or transition.size() != 2 or transition.get("target_mode") not in (["quantum", "legacy"] if collector else ["quantum"]) or not GalacticExportSystem._nonnegative_integer(transition.get("boundary_second")): errors.append("量子交接边界无效")
		elif station.has("quantum_transition"): errors.append("量子交接与站点模式不符")
	return errors

static func _result(ok: bool, message: String) -> Dictionary:
	return {"ok": ok, "message": message}
