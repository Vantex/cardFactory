class_name LogisticsSystem
extends RefCounted

var game_state: GameState
var stations: StationSystem
var galaxy: GalaxySystem
var interstellar: InterstellarRouteSystem
var diagnostics := {}
var statistics: StatisticsSystem

func _init(state: GameState, statistics_system: StatisticsSystem = null) -> void:
	game_state = state
	statistics = statistics_system
	stations = StationSystem.new(state)
	galaxy = GalaxySystem.new(state)
	interstellar = InterstellarRouteSystem.new(state)

func update(delta: float) -> void:
	if delta <= 0 or not is_finite(delta):
		return
	diagnostics.clear()
	_advance_routes(delta)
	_refill_warpers()
	var outgoing := {}
	for connection in game_state.connections.values():
		if not outgoing.has(connection.source_id): outgoing[connection.source_id] = []
		outgoing[connection.source_id].append(connection)
	var ids := game_state.buildings.keys()
	ids.sort()
	var supplies := {}
	var demands: Array = []
	for id in ids:
		var b: Dictionary = game_state.buildings[id]
		if not b.has("station"):
			continue
		if SystemHubLogisticsSystem.is_elevator(b): continue
		_bridge_buffers(b, outgoing.get(id, []))
		for index in range(b.station.slots.size()):
			var slot: Dictionary = b.station.slots[index]
			if slot.item_id == "":
				continue
			for remote in [false, true]:
				if remote and not StationSystem.is_remote_endpoint(String(b.type)): continue
				var entry := {"id": id, "index": index, "slot": slot, "remote": remote}
				var mode := StationSystem.mode_for(b, slot, remote)
				if mode == "supply":
					if not supplies.has(slot.item_id): supplies[slot.item_id] = []
					supplies[slot.item_id].append(entry)
				elif mode == "demand": demands.append(entry)
	demands.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		if a.slot.priority != b.slot.priority:
			return a.slot.priority > b.slot.priority
		return a.id < b.id if a.id != b.id else a.index < b.index)
	var by_priority := {}
	for item in supplies:
		var groups := {2: [], 1: [], 0: []}
		for candidate in supplies[item]:
			groups[int(candidate.slot.priority)].append(candidate)
		by_priority[item] = groups
	for demand in demands:
		var candidates: Array = supplies.get(demand.slot.item_id, [])
		if candidates.is_empty():
			diagnostics[demand.id] = "无合法供应站"
			continue
		var dispatched := false
		for source_priority in [2, 1, 0]:
			var peers: Array = by_priority[demand.slot.item_id][source_priority]
			if peers.is_empty():
				continue
			var start := int(demand.slot.cursor) % peers.size()
			for offset in range(peers.size()):
				var n := (start + offset) % peers.size()
				var reason := _dispatch(peers[n], demand)
				if not diagnostics.has(demand.id):
					diagnostics[demand.id] = reason
				if reason == "已派遣":
					demand.slot.cursor = (n + 1) % peers.size()
					dispatched = true
					break
			if dispatched:
				break

func _dispatch(source: Dictionary, target: Dictionary) -> String:
	if source.id == target.id:
		return "无合法供应站"
	var a: Dictionary = game_state.buildings[source.id]
	var b: Dictionary = game_state.buildings[target.id]
	if SystemHubLogisticsSystem.is_elevator(a) or SystemHubLogisticsSystem.is_elevator(b) or a.station.has("mode_transition") or b.station.has("mode_transition"): return "电梯模式或正在等待模式切换"
	if not a.station.enabled or not b.station.enabled:
		return "物流站已停发"
	var interplanetary: bool = a.planet_id != b.planet_id
	if interplanetary and (a.station.get("quantum_mode", "legacy") != "legacy" or b.station.get("quantum_mode", "legacy") != "legacy"): return "量子挂接中或已接入量子网络"
	if source.remote != interplanetary or target.remote != interplanetary: return "物流范围不匹配"
	if interplanetary and (not StationSystem.is_remote_endpoint(a.type) or not StationSystem.is_interstellar(b.type)):
		return "跨行星需要两座星际站"
	if interplanetary and not DataManager.source_technology_unlocked(game_state, "interstellar_logistics"):
		return "需要星际物流科技"
	var source_rules := StationSystem.is_source(a.type) or StationSystem.is_source(b.type)
	if not source_rules: return _dispatch_owner(source, target, a, false)
	var owners: Array = [b] if a.type == OrbitalCollectorSystem.TYPE else [b, a]
	var dispatched := false
	var reason := "调度站无可用载具"
	for owner in owners:
		while true:
			reason = _dispatch_owner(source, target, owner, source_rules)
			if reason != "已派遣": break
			dispatched = true
	return "已派遣" if dispatched else reason

func _dispatch_owner(source: Dictionary, target: Dictionary, owner: Dictionary, source_rules: bool) -> String:
	var a: Dictionary = game_state.buildings[source.id]
	var b: Dictionary = game_state.buildings[target.id]
	var interplanetary: bool = a.planet_id != b.planet_id
	var power := minf(float(a.get("power_efficiency", 0)), float(b.get("power_efficiency", 0))) if interplanetary or not source_rules else float(owner.get("power_efficiency", 0))
	if power <= 0: return "物流站断电"
	var vehicle := "logistics_vessel" if interplanetary else "logistics_drone"
	if int(owner.station.fleet[vehicle]) < 1:
		return "调度站无可用载具"
	var ap := galaxy.get_planet(a.planet_id)
	var bp := galaxy.get_planet(b.planet_id)
	var cross_system: bool = ap.system_id != bp.system_id
	if cross_system and not owner.station.get("warp_enabled", true):
		return "供应站已关闭跨恒星翘曲"
	var economics := interstellar.economics(a, b, 1, target.slot) if source_rules and interplanetary else {}
	if not economics.is_empty():
		if not economics.available: return "中继策略和翘曲预算下无可用航线"
		power = minf(power, interstellar.hub_power(economics.waypoint_ids))
		if power <= 0: return "中继站断电"
	var warpers := int(economics.get("warpers_per_vessel", 1)) if source_rules else 2
	if cross_system and ((source_rules and not DataManager.source_technology_unlocked(game_state, "space_warp")) or int(owner.station.fleet.space_warper) < warpers):
		return "需要空间翘曲科技与航线翘曲器"
	var free := StationSystem.capacity_for(target.slot, game_state, b) - float(target.slot.amount) - stations.reserved(target.id, target.index)
	if not interplanetary and b.station.get("quantum_mode", "legacy") == "quantum" and StationSystem.mode_for(b, target.slot, true) == "supply": free = QuantumLogisticsSystem.new(game_state).free_capacity(target.slot.item_id) - stations.reserved(target.id, target.index)
	if free <= 0:
		return "需求槽容量不足"
	var load_capacity := roundf((100.0 if interplanetary else 25.0 if source_rules else 20.0) * game_state.get_technology_effect_multiplier("logistics_capacity"))
	var amount := minf(load_capacity, minf(maxf(0, float(source.slot.amount) - float(source.slot.get("min_stock", 0))), free))
	if source_rules: amount = floorf(amount + SimulationEngine.STEP_EPSILON)
	var minimum := float(target.slot.min_load) if owner.id == b.id else float(source.slot.min_load)
	if not source_rules: minimum = maxf(float(source.slot.min_load), float(target.slot.min_load))
	if amount < load_capacity * minimum:
		return "库存或空余容量未达到最低装载"
	var duration := maxf(1.0, a.position.distance_to(b.position) / 200.0)
	if interplanetary:
		duration = 5.0 + absf(float(ap.orbit) - float(bp.orbit)) * 5.0
	if cross_system:
		duration = 30.0 + galaxy.get_system_distance(ap.system_id, bp.system_id) * 10.0
		owner.station.fleet.space_warper -= warpers
	if source_rules: duration = float(economics.duration) if interplanetary else 8.0
	var id := game_state.generate_id("route")
	source.slot.amount -= amount
	owner.station.fleet[vehicle] -= 1
	if not source_rules or not interplanetary: duration /= game_state.get_technology_effect_multiplier("logistics_speed") * GameModeSystem.new(game_state).multiplier("logistics")
	game_state.logistics_routes[id] = {"id": id, "source_id": source.id, "target_id": target.id, "source_slot": source.index, "target_slot": target.index, "vehicle": vehicle, "item_id": source.slot.item_id, "amount": amount, "phase": "outbound", "remaining": duration, "duration": duration, "interplanetary": interplanetary}
	if owner.id != a.id: game_state.logistics_routes[id]["owner_id"] = owner.id
	if not economics.is_empty():
		game_state.logistics_routes[id].merge({"waypoint_ids": economics.waypoint_ids, "distance_ly": economics.distance_ly, "warpers_per_vessel": economics.warpers_per_vessel})
	return "已派遣"

func _advance_routes(delta: float) -> void:
	var ids := game_state.logistics_routes.keys()
	ids.sort()
	for id in ids:
		var route: Dictionary = game_state.logistics_routes[id]
		var source: Dictionary = game_state.buildings[route.source_id]
		var target: Dictionary = game_state.buildings[route.target_id]
		var source_rules := StationSystem.is_source(source.type) or StationSystem.is_source(target.type)
		var owner: Dictionary = game_state.buildings[route.get("owner_id", route.source_id)]
		var power := minf(float(source.get("power_efficiency", 0)), float(target.get("power_efficiency", 0))) if route.interplanetary else float(owner.get("power_efficiency", 0))
		if source_rules and route.interplanetary: power = minf(power, interstellar.hub_power(route.get("waypoint_ids", [])))
		route.remaining = maxf(0, float(route.remaining) - delta * (power if source_rules else 1.0))
		if route.remaining > 0.0000001:
			continue
		if route.phase == "returning":
			game_state.buildings[route.get("owner_id", route.source_id)].station.fleet[route.vehicle] += 1
			game_state.logistics_routes.erase(id)
			continue
		var slot: Dictionary = target.station.slots[int(route.target_slot)]
		if not source_rules and float(target.get("power_efficiency", 0)) <= 0:
			diagnostics[route.target_id] = "到达等待：物流站断电"
			continue
		var quantum_supply: bool = source_rules and not route.interplanetary and target.station.get("quantum_mode", "legacy") == "quantum" and StationSystem.mode_for(target, slot, true) == "supply"
		if not quantum_supply and float(slot.amount) + float(route.amount) > StationSystem.storage_capacity_for(target, slot):
			diagnostics[route.target_id] = "到达等待：容量不足"
			continue
		var delivered := float(route.amount)
		if quantum_supply:
			delivered = float(QuantumLogisticsSystem.new(game_state).deposit(route.item_id, int(route.amount)))
			if delivered < route.amount:
				route.amount -= delivered
				if statistics != null and delivered > 0: statistics.record_transferred(route.item_id, delivered, route.id, target.planet_id)
				continue
		else: slot.amount += delivered
		if not game_state.progression_facts.has("station_trips"): game_state.progression_facts["station_trips"] = {}
		var trips: Dictionary = game_state.progression_facts.station_trips
		trips[source.id] = float(trips.get(source.id, 0)) + 1
		if source_rules: trips[target.id] = float(trips.get(target.id, 0)) + 1
		if route.interplanetary:
			game_state.interplanetary_delivered += float(route.amount)
		if statistics != null:
			statistics.record_transferred(route.item_id, float(route.amount), route.id, target.planet_id)
		route.amount = 0.0
		route.phase = "returning"
		route.remaining = route.duration
		if route.interplanetary:
			EventBus.logistics_delivered.emit()
		if source_rules:
			owner.station.fleet[route.vehicle] += 1
			game_state.logistics_routes.erase(id)

func _bridge_buffers(building: Dictionary, outgoing_connections: Array) -> void:
	if float(building.get("power_efficiency", 0)) <= 0 and building.station.get("quantum_mode", "legacy") != "quantum":
		return
	for index in range(building.station.slots.size()):
		var slot: Dictionary = building.station.slots[index]
		var item := String(slot.item_id)
		if item == "":
			continue
		if building.type == OrbitalCollectorSystem.TYPE and item != building.get("collector_item", "hydrogen"): continue
		var incoming := minf(float(building.input_buffer.get(item, 0)), maxf(0, StationSystem.capacity_for(slot, game_state, building) - float(slot.amount) - stations.reserved(building.id, index)))
		if incoming > 0:
			building.input_buffer[item] -= incoming
			slot.amount += incoming
		if building.type != OrbitalCollectorSystem.TYPE and building.station.get("quantum_mode", "legacy") == "quantum" and StationSystem.mode_for(building, slot, true) == "supply":
			var accepted := QuantumLogisticsSystem.new(game_state).deposit(item, int(floorf(maxf(0, float(slot.amount) - float(slot.get("min_stock", 0))))))
			slot.amount -= accepted
		for connection in outgoing_connections:
			if connection.item_id == item and connection.get("enabled", true):
				var outgoing := minf(float(slot.amount), maxf(0, 60.0 - float(building.output_buffer.get(item, 0))))
				if outgoing > 0:
					slot.amount -= outgoing
					building.output_buffer[item] = float(building.output_buffer.get(item, 0)) + outgoing
				break

func _refill_warpers() -> void:
	if not game_state.completed_technologies.has("dsp_space_warp"): return
	var ids := game_state.buildings.keys()
	ids.sort()
	for id in ids:
		var building: Dictionary = game_state.buildings[id]
		if not StationSystem.is_interstellar(String(building.get("type", ""))) or not building.has("station") or not building.station.get("warper_auto_refill", false): continue
		var fleet: Dictionary = building.station.fleet
		var needed := maxi(0, mini(StationSystem.fleet_capacity(building, "space_warper"), int(building.station.get("warper_target", 50))) - int(fleet.space_warper))
		if needed < 1: continue
		for field in ["input_buffer", "output_buffer"]:
			var buffer: Dictionary = building.get(field, {})
			var take := mini(needed, int(floorf(float(buffer.get("space_warper", 0)))))
			if take > 0:
				buffer["space_warper"] = float(buffer.space_warper) - take
				fleet.space_warper += take
				needed -= take
			if needed < 1: break
		if needed < 1: continue
		var tray := game_state.get_planet_inventory(String(building.planet_id))
		var take := mini(needed, int(floorf(float(tray.get("space_warper", 0)))))
		if take > 0:
			tray["space_warper"] = float(tray.space_warper) - take
			fleet.space_warper += take
