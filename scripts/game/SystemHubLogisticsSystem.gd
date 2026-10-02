class_name SystemHubLogisticsSystem
extends RefCounted

const STATION_TYPE := "dsp_interstellar_logistics_station"
var state: GameState
func _init(value: GameState) -> void: state = value

static func is_elevator(building: Dictionary) -> bool:
	return building.get("type") == STATION_TYPE and int(building.get("station", {}).get("tier", 1)) == 2 and building.station.get("operation_mode", "legacy") == "elevator"

func request_mode(id: String, mode: String) -> Dictionary:
	var building: Dictionary = state.buildings.get(id, {})
	if building.get("type") != STATION_TYPE or building.get("planet_id") != state.active_planet_id or building.get("interaction_locked", false) or int(building.get("station", {}).get("tier", 1)) < 2 or mode not in ["legacy", "elevator"]: return result(false, "请选择当前行星 Mk.II 星际站")
	if mode == "elevator" and not SourceTechnologyEffects.completed(state, "orbital_multi_cargo_bus"): return result(false, "需要轨道多货物总线科技")
	if building.station.get("operation_mode", "legacy") == mode and not building.station.has("mode_transition"): return result(false, "该站已使用所选模式")
	building.station.mode_transition = mode
	if not building.station.has("elevator_output_items"):
		var items := []
		for slot in building.station.slots:
			var item := String(slot.item_id)
			items.append(item if item == "" or not items.has(item) else "")
		building.station.elevator_output_items = items
	return result(true, "模式切换已排队，关联航线完成后生效")

func set_output(id: String, index: int, item: String, confirmations: int) -> Dictionary:
	var building: Dictionary = state.buildings.get(id, {})
	if not is_elevator(building) or building.get("planet_id") != state.active_planet_id or building.get("interaction_locked", false) or index < 0 or index >= 5 or confirmations < 2 or (item != "" and DataManager.get_item(item).is_empty()): return result(false, "输出口参数无效，变更需要两次确认")
	var items: Array = building.station.get("elevator_output_items", ["", "", "", "", ""])
	for n in range(5):
		if n != index and item != "" and items[n] == item: return result(false, "五个输出口不能配置重复物品")
	if items[index] == item: return result(false, "输出物品未变化")
	var probe := state.copy_state()
	probe.emit_canvas_events = false
	probe.command_history.enabled = false
	var removed := []
	for connection_id in probe.connections.keys():
		var connection: Dictionary = probe.connections[connection_id]
		if connection.source_id != id: continue
		if int(connection.get("elevator_output_index", -1)) == index or (not connection.has("elevator_output_index") and items[index] != "" and connection.item_id == items[index]):
			var outcome := probe.try_remove_connection(connection_id)
			if not outcome.ok: return outcome
			removed.append(connection_id)
	probe.buildings[id].station.elevator_output_items[index] = item
	state.install_state(probe)
	if state.emit_canvas_events:
		for connection_id in removed: EventBus.connection_removed.emit(connection_id)
	return result(true, "输出口已更新，原线路施工件已返还，缓存物资保留")

func update() -> void:
	for id in state.buildings:
		var building: Dictionary = state.buildings[id]
		if not building.get("station", {}).has("mode_transition"): continue
		if StationSystem.new(state).has_route(id): continue
		building.station.operation_mode = building.station.mode_transition
		building.station.erase("mode_transition")
		if state.galactic_hub_network.is_empty(): state.galactic_hub_network = initial_network()
	if state.galactic_hub_network.is_empty(): return
	var boundary := int(floorf((state.elapsed_time + SimulationEngine.STEP_EPSILON) / 5.0))
	if boundary <= int(state.galactic_hub_network.settled_boundary): return
	state.galactic_hub_network.settled_boundary = boundary
	release_fleet()
	settle_local()

func settle_local() -> void:
	var by_system := {}
	var world := SystemSpaceStationSystem.new(state)
	var ids := state.buildings.keys()
	ids.sort()
	for id in ids:
		var building: Dictionary = state.buildings[id]
		if not is_elevator(building): continue
		var system_id := world.planet_system(building.planet_id)
		if state.system_space_stations.get(system_id, {}).get("status") != "operational": continue
		if not by_system.has(system_id): by_system[system_id] = []
		by_system[system_id].append(building)
	for system_id in by_system:
		var stations: Array = by_system[system_id]
		var hub: Dictionary = state.system_space_stations[system_id]
		var power := 1.0
		for building in stations: power = minf(power, clampf(float(building.get("power_efficiency", 0)), 0, 1))
		for building in stations:
			for item in building.input_buffer:
				var available := int(floorf(float(building.input_buffer[item])))
				var moved := mini(int(floorf(available * power)), limited(HubInteger.subtract("9".repeat(256), hub.inventory.get(item, "0")), available))
				if moved <= 0: continue
				hub.inventory[item] = HubInteger.add(hub.inventory.get(item, "0"), str(moved))
				building.input_buffer[item] = float(building.input_buffer[item]) - moved
		var requests := {}
		for building in stations:
			var capacity := float(DataManager.get_building(building.type).get("output_buffer_capacity", 0))
			var items: Array = building.station.get("elevator_output_items", ["", "", "", "", ""])
			for index in range(items.size()):
				var item: String = items[index]
				if item.is_empty(): continue
				var free := int(floorf(maxf(0, capacity - float(building.output_buffer.get(item, 0)))))
				if free < 1: continue
				if not requests.has(item): requests[item] = []
				requests[item].append({"key": "%s:%d" % [building.id, index], "id": building.id, "amount": free})
		var items := requests.keys()
		items.sort()
		for item in items:
			var throughput := int(floorf(10000000.0 * (int(hub.modules.backbone) + 1) * power))
			var stock: String = hub.inventory.get(item, "0")
			var budget := throughput if DecimalCount.compare(stock, str(throughput)) > 0 else int(stock)
			var allocation := allocate_local(budget, requests[item], int(hub.routing_cursors.get(item, 0)))
			hub.routing_cursors[item] = allocation.next_cursor
			for request in requests[item]:
				var moved := int(allocation.amounts.get(request.key, 0))
				if moved <= 0: continue
				state.buildings[request.id].output_buffer[item] = float(state.buildings[request.id].output_buffer.get(item, 0)) + moved
				hub.inventory[item] = HubInteger.subtract(hub.inventory.get(item, "0"), str(moved))
	settle_cross_system(by_system)

static func allocate_local(budget: int, requests: Array, cursor: int) -> Dictionary:
	var normalized := requests.duplicate(true)
	normalized.sort_custom(func(a, b): return String(a.key) < String(b.key))
	var total := 0
	for row in normalized: total += int(row.amount)
	var available := mini(maxi(0, budget), total)
	var amounts := {}
	if total <= 0 or available <= 0: return {"amounts": amounts, "next_cursor": 0}
	var allocated := 0
	for row in normalized:
		# Local demands are bounded by real output buffers, not 256-digit stock.
		var amount := multiply_divide(available, int(row.amount), total)
		amounts[row.key] = amount
		allocated += amount
	var remainder := available - allocated
	var start := posmod(cursor, normalized.size())
	for offset in range(normalized.size()):
		if remainder <= 0: break
		var row: Dictionary = normalized[(start + offset) % normalized.size()]
		if int(amounts[row.key]) >= int(row.amount): continue
		amounts[row.key] += 1
		remainder -= 1
	return {"amounts": amounts, "next_cursor": (start + available - remainder) % normalized.size()}

static func initial_network() -> Dictionary:
	return {"version": 1, "settled_boundary": 0, "fleet_installed": 0, "fleet_busy": 0, "fleet_returns": [], "warpers": "0", "warper_target": "0", "routing_cursors": {}}

static func result(ok: bool, message: String) -> Dictionary:
	return {"ok": ok, "message": message}

static func multiply_divide(a: int, b: int, divisor: int) -> int:
	var quotient := int(a / divisor)
	var remainder := a % divisor
	var result := 0
	var residue := 0
	while b > 0:
		if b % 2 == 1:
			result += quotient
			residue += remainder
			if residue >= divisor:
				result += 1
				residue -= divisor
		b = b >> 1
		if b > 0:
			quotient *= 2
			remainder *= 2
			if remainder >= divisor:
				quotient += 1
				remainder -= divisor
	return result

static func validate(data: Dictionary) -> Array:
	var network: Variant = data.get("galactic_hub_network", {})
	if not network is Dictionary: return ["电梯网络状态无效"]
	if not network.is_empty():
		if not SourceDysonEngineering.number(data.get("elapsed_time"), 0, 9.0e15): return ["电梯时间无效"]
		if network.get("version") != 1 or not SourceDysonEngineering.number(network.get("settled_boundary"), 0, floorf(float(data.get("elapsed_time", 0)) / 5.0 + 0.0001), true): return ["电梯结算边界无效"]
		for field in ["fleet_installed", "fleet_busy"]:
			if not SourceDysonEngineering.number(network.get(field), 0, 100000000, true): return ["跨系舰队数量无效"]
		for field in ["warpers", "warper_target"]:
			if not HubInteger.valid(network.get(field)): return ["枢纽翘曲器整数无效"]
		if not network.get("fleet_returns") is Array or network.fleet_returns.size() > 100000 or not network.get("routing_cursors") is Dictionary: return ["电梯返航集合无效"]
	var buildings: Variant = data.get("buildings", {})
	if not buildings is Dictionary: return ["电梯建筑集合无效"]
	for building in buildings.values():
		if not building is Dictionary: continue
		var config: Variant = building.get("station", {})
		if not config is Dictionary: continue
		if not config.has("operation_mode") and not config.has("mode_transition") and not config.has("elevator_output_items"): continue
		if building.get("type") != STATION_TYPE or config.get("tier", 1) != 2 or config.get("operation_mode", "legacy") not in ["legacy", "elevator"]: return ["电梯模式或等级无效"]
		if config.has("mode_transition") and config.mode_transition not in ["legacy", "elevator"]: return ["电梯模式切换无效"]
		if config.get("operation_mode") == "elevator" and network.is_empty(): return ["电梯缺少共享结算边界"]
		var items: Variant = config.get("elevator_output_items")
		if not items is Array or items.size() != 5: return ["电梯必须有五个输出口"]
		var used := {}
		for item in items:
			if not item is String or (item != "" and (DataManager.get_item(item).is_empty() or used.has(item))): return ["电梯输出口物品重复或无效"]
			if item != "": used[item] = true
	if not network.is_empty():
		var busy := 0
		var owners := {}
		var keys := {}
		for bucket in network.fleet_returns:
			if not bucket is Dictionary or not bucket.get("route_key") is String or bucket.route_key.is_empty() or bucket.route_key.length() > 256 or not SourceDysonEngineering.number(bucket.get("return_at_second"), 0, 9000000000000, true) or not SourceDysonEngineering.number(bucket.get("vessel_count"), 1, 100000000, true) or not bucket.get("owners") is Dictionary: return ["跨系返航记录无效"]
			var key: String = bucket.route_key + ":" + str(int(bucket.return_at_second))
			if keys.has(key): return ["跨系返航批次重复"]
			keys[key] = true
			var count := 0
			for id in bucket.owners:
				if not id is String or not buildings.has(id) or not buildings[id] is Dictionary or not is_elevator(buildings[id]) or not SourceDysonEngineering.number(bucket.owners[id], 1, 10, true): return ["跨系返航载具归属无效"]
				count += int(bucket.owners[id])
				owners[id] = int(owners.get(id, 0)) + int(bucket.owners[id])
			if count != int(bucket.vessel_count): return ["跨系返航载具总数不守恒"]
			busy += count
		if busy != int(network.fleet_busy) or busy > int(network.fleet_installed): return ["跨系舰队忙碌总数不守恒"]
		for id in owners:
			if not buildings[id].station.get("fleet") is Dictionary or not SourceDysonEngineering.number(buildings[id].station.fleet.get("logistics_vessel"), 0, 10, true) or int(owners[id]) + int(buildings[id].station.fleet.logistics_vessel) > 10: return ["跨系在途和停泊载具超过机库容量"]
	return []

func set_policy(system_id: String, item: String, reserve: String, target: String, enabled: bool) -> Dictionary:
	var hub: Dictionary = state.system_space_stations.get(system_id, {})
	if hub.get("status") != "operational" or DataManager.get_item(item).is_empty() or not HubInteger.valid(reserve) or not HubInteger.valid(target): return result(false, "需要运行中的空间站和有效的精确库存限额")
	hub.item_policies[item] = {"reserve": reserve, "target": target, "interstellar_enabled": enabled}
	return result(true, "跨系物料策略已更新")

func load_warpers(amount: int) -> Dictionary:
	if amount < 1 or amount > 999 or state.galactic_hub_network.is_empty(): return result(false, "请先启用电梯网络，单次装载 1～999 个翘曲器")
	if DecimalCount.compare(HubInteger.subtract("9".repeat(256), state.galactic_hub_network.warpers), str(amount)) < 0: return result(false, "枢纽翘曲器库存已满")
	var paid := InventorySystem.new(state).try_remove("space_warper", amount)
	if not paid.ok: return paid
	state.galactic_hub_network.warpers = HubInteger.add(state.galactic_hub_network.warpers, str(amount))
	return result(true, "已向跨系枢纽装入 %d 个翘曲器" % amount)

func release_fleet() -> void:
	var network: Dictionary = state.galactic_hub_network
	var remaining := []
	for bucket in network.fleet_returns:
		if int(bucket.return_at_second) > int(floorf(state.elapsed_time + SimulationEngine.STEP_EPSILON)):
			remaining.append(bucket)
			continue
		for id in bucket.owners: state.buildings[id].station.fleet.logistics_vessel += int(bucket.owners[id])
		network.fleet_busy -= int(bucket.vessel_count)
	network.fleet_returns = remaining

func settle_cross_system(by_system: Dictionary) -> void:
	var network: Dictionary = state.galactic_hub_network
	var system_ids := by_system.keys()
	system_ids.sort()
	var fleet_ids := []
	var free := 0
	var module_count := 0
	var power := 1.0
	var item_set := {}
	for system_id in system_ids:
		var hub: Dictionary = state.system_space_stations[system_id]
		module_count += int(hub.modules.interstellar)
		for item in hub.item_policies: item_set[item] = true
		for building in by_system[system_id]:
			power = minf(power, clampf(float(building.get("power_efficiency", 0)), 0, 1))
			if building.station.has("mode_transition"): continue
			fleet_ids.append(building.id)
			free += int(building.station.fleet.logistics_vessel)
	network.fleet_installed = free + int(network.fleet_busy)
	if system_ids.size() < 2 or not SourceTechnologyEffects.completed(state, "unified_system_logistics_protocol"): return
	fleet_ids.sort()
	var warper_fleet := limited(HubInteger.half(network.warpers), free)
	var budget := int(floorf(minf(10000000.0 * (module_count + 1), mini(free, warper_fleet) * 100.0) * power))
	if budget <= 0: return
	var items := item_set.keys()
	items.sort()
	for item in items:
		if budget <= 0 or free <= 0: break
		var sources := []
		var targets := []
		for system_id in system_ids:
			var hub: Dictionary = state.system_space_stations[system_id]
			var policy: Dictionary = hub.item_policies.get(item, {})
			if not policy.get("interstellar_enabled", false): continue
			var stock: String = hub.inventory.get(item, "0")
			var supply := HubInteger.subtract(stock, policy.reserve)
			var demand := HubInteger.subtract(policy.target, stock)
			if supply != "0": sources.append({"key": system_id, "amount": supply})
			if demand != "0": targets.append({"key": system_id, "amount": demand})
		if sources.is_empty() or targets.is_empty(): continue
		var source_budget := allocate_decimal(budget, sources)
		var target_budget := allocate_decimal(budget, targets)
		for source in sources:
			for target in targets:
				if source.key == target.key: continue
				var moved := mini(int(source_budget[source.key]), int(target_budget[target.key]))
				moved = mini(moved, mini(budget, mini(free, limited(HubInteger.half(network.warpers), free)) * 100))
				if moved <= 0: continue
				var vessels := int((moved + 99) / 100)
				var owners := {}
				var needed := vessels
				for id in fleet_ids:
					var fleet: Dictionary = state.buildings[id].station.fleet
					var take := mini(needed, int(fleet.logistics_vessel))
					if take <= 0: continue
					owners[id] = take
					fleet.logistics_vessel -= take
					needed -= take
					if needed == 0: break
				assert(needed == 0)
				var source_hub: Dictionary = state.system_space_stations[source.key]
				var target_hub: Dictionary = state.system_space_stations[target.key]
				source_hub.inventory[item] = HubInteger.subtract(source_hub.inventory.get(item, "0"), str(moved))
				target_hub.inventory[item] = HubInteger.add(target_hub.inventory.get(item, "0"), str(moved))
				source_budget[source.key] -= moved
				target_budget[target.key] -= moved
				budget -= moved
				free -= vessels
				network.fleet_busy += vessels
				network.warpers = HubInteger.subtract(network.warpers, str(vessels * 2))
				var duration := maxi(30, int(ceilf(15.0 + 2.0 * GalaxySystem.new(state).get_system_distance(source.key, target.key))))
				var bucket := {"route_key": "%s->%s:%s" % [source.key, target.key, item], "return_at_second": int(floorf(state.elapsed_time + SimulationEngine.STEP_EPSILON)) + duration, "vessel_count": vessels, "owners": owners}
				var merged := false
				for existing in network.fleet_returns:
					if existing.route_key != bucket.route_key or existing.return_at_second != bucket.return_at_second: continue
					existing.vessel_count += vessels
					for id in owners: existing.owners[id] = int(existing.owners.get(id, 0)) + int(owners[id])
					merged = true
					break
				if not merged: network.fleet_returns.append(bucket)
	network.fleet_returns.sort_custom(func(a, b): return a.return_at_second < b.return_at_second if a.return_at_second != b.return_at_second else a.route_key < b.route_key)

static func limited(value: String, cap: int) -> int:
	return cap if DecimalCount.compare(value, str(cap)) >= 0 else int(value)

static func allocate_decimal(budget: int, requests: Array) -> Dictionary:
	var total := "0"
	for row in requests: total = DecimalCount.add(total, row.amount)
	var available := limited(total, maxi(0, budget))
	var result := {}
	var allocated := 0
	var bits := []
	var number := available
	while number > 0:
		bits.push_front(number % 2)
		number = number >> 1
	for row in requests:
		var quotient := 0
		var remainder := "0"
		for bit in bits:
			quotient *= 2
			remainder = DecimalCount.add(remainder, remainder)
			if bit == 1: remainder = DecimalCount.add(remainder, row.amount)
			while DecimalCount.compare(remainder, total) >= 0 and total != "0":
				remainder = DecimalCount.subtract(remainder, total)
				quotient += 1
		result[row.key] = quotient
		allocated += quotient
	for row in requests:
		if allocated >= available: break
		if DecimalCount.compare(str(result[row.key]), row.amount) >= 0: continue
		result[row.key] += 1
		allocated += 1
	return result
