class_name LogisticsSystem
extends RefCounted

var game_state: GameState
var stations: StationSystem
var galaxy: GalaxySystem
var diagnostics := {}
var statistics: StatisticsSystem

func _init(state: GameState, statistics_system: StatisticsSystem = null) -> void:
	game_state = state
	statistics = statistics_system
	stations = StationSystem.new(state)
	galaxy = GalaxySystem.new(state)

func update(delta: float) -> void:
	if delta <= 0 or not is_finite(delta):
		return
	diagnostics.clear()
	_advance_routes(delta)
	var ids := game_state.buildings.keys()
	ids.sort()
	var supplies := {}
	var demands: Array = []
	for id in ids:
		var b: Dictionary = game_state.buildings[id]
		if not b.has("station"):
			continue
		_bridge_buffers(b)
		for index in range(4):
			var slot: Dictionary = b.station.slots[index]
			if slot.item_id == "":
				continue
			var entry := {"id": id, "index": index, "slot": slot}
			if slot.mode == "supply":
				if not supplies.has(slot.item_id):
					supplies[slot.item_id] = []
				supplies[slot.item_id].append(entry)
			elif slot.mode == "demand":
				demands.append(entry)
	demands.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		if a.slot.priority != b.slot.priority:
			return a.slot.priority > b.slot.priority
		return a.id < b.id if a.id != b.id else a.index < b.index)
	for demand in demands:
		var candidates: Array = supplies.get(demand.slot.item_id, [])
		if candidates.is_empty():
			diagnostics[demand.id] = "无合法供应站"
			continue
		var dispatched := false
		for source_priority in [2, 1, 0]:
			var peers: Array = candidates.filter(func(candidate: Dictionary): return candidate.slot.priority == source_priority)
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
	if not a.station.enabled or not b.station.enabled:
		return "物流站已停发"
	var interplanetary: bool = a.planet_id != b.planet_id
	if interplanetary and (a.type != StationSystem.TYPES[1] or b.type != StationSystem.TYPES[1]):
		return "跨行星需要两座星际站"
	if interplanetary and not game_state.completed_technologies.has("interstellar_logistics"):
		return "需要星际物流科技"
	if float(a.get("power_efficiency", 0)) <= 0 or float(b.get("power_efficiency", 0)) <= 0:
		return "物流站断电"
	var vehicle := "logistics_vessel" if interplanetary else "logistics_drone"
	if int(a.station.fleet[vehicle]) < 1:
		return "供应站无可用载具"
	var ap := galaxy.get_planet(a.planet_id)
	var bp := galaxy.get_planet(b.planet_id)
	var cross_system: bool = ap.system_id != bp.system_id
	if cross_system and int(a.station.fleet.space_warper) < 2:
		return "缺少往返翘曲器（需要 2）"
	var free := float(target.slot.capacity) - float(target.slot.amount) - stations.reserved(target.id, target.index)
	if free <= 0:
		return "需求槽容量不足"
	var load_capacity := roundf((100.0 if interplanetary else 20.0) * game_state.get_technology_effect_multiplier("logistics_capacity"))
	var amount := minf(load_capacity, minf(float(source.slot.amount), free))
	if amount < load_capacity * maxf(float(source.slot.min_load), float(target.slot.min_load)):
		return "库存或空余容量未达到最低装载"
	var duration := maxf(1.0, a.position.distance_to(b.position) / 200.0)
	if interplanetary:
		duration = 5.0 + absf(float(ap.orbit) - float(bp.orbit)) * 5.0
	if cross_system:
		duration = 30.0 + galaxy.get_system_distance(ap.system_id, bp.system_id) * 10.0
		a.station.fleet.space_warper -= 2
	var id := game_state.generate_id("route")
	source.slot.amount -= amount
	a.station.fleet[vehicle] -= 1
	duration /= game_state.get_technology_effect_multiplier("logistics_speed")
	game_state.logistics_routes[id] = {"id": id, "source_id": source.id, "target_id": target.id, "source_slot": source.index, "target_slot": target.index, "vehicle": vehicle, "item_id": source.slot.item_id, "amount": amount, "phase": "outbound", "remaining": duration, "duration": duration, "interplanetary": interplanetary}
	return "已派遣"

func _advance_routes(delta: float) -> void:
	var ids := game_state.logistics_routes.keys()
	ids.sort()
	for id in ids:
		var route: Dictionary = game_state.logistics_routes[id]
		var source: Dictionary = game_state.buildings[route.source_id]
		var target: Dictionary = game_state.buildings[route.target_id]
		route.remaining = maxf(0, float(route.remaining) - delta)
		if route.remaining > 0.0000001:
			continue
		if route.phase == "returning":
			source.station.fleet[route.vehicle] += 1
			game_state.logistics_routes.erase(id)
			continue
		var slot: Dictionary = target.station.slots[int(route.target_slot)]
		if float(target.get("power_efficiency", 0)) <= 0:
			diagnostics[route.target_id] = "到达等待：物流站断电"
			continue
		if float(slot.amount) + float(route.amount) > float(slot.capacity):
			diagnostics[route.target_id] = "到达等待：容量不足"
			continue
		slot.amount += float(route.amount)
		if not game_state.progression_facts.has("station_trips"): game_state.progression_facts["station_trips"] = {}
		var trips: Dictionary = game_state.progression_facts.station_trips
		trips[source.id] = float(trips.get(source.id, 0)) + 1
		if route.interplanetary:
			game_state.interplanetary_delivered += float(route.amount)
		if statistics != null:
			statistics.record_transferred(route.item_id, float(route.amount), route.id, target.planet_id)
		route.amount = 0.0
		route.phase = "returning"
		route.remaining = route.duration
		if route.interplanetary:
			EventBus.logistics_delivered.emit()

func _bridge_buffers(building: Dictionary) -> void:
	if float(building.get("power_efficiency", 0)) <= 0:
		return
	for index in range(4):
		var slot: Dictionary = building.station.slots[index]
		var item := String(slot.item_id)
		if item == "":
			continue
		var incoming := minf(float(building.input_buffer.get(item, 0)), maxf(0, float(slot.capacity) - float(slot.amount) - stations.reserved(building.id, index)))
		if incoming > 0:
			building.input_buffer[item] -= incoming
			slot.amount += incoming
		for connection in game_state.get_connections_for_building(building.id):
			if connection.source_id == building.id and connection.item_id == item and connection.get("enabled", true):
				var outgoing := minf(float(slot.amount), maxf(0, 60.0 - float(building.output_buffer.get(item, 0))))
				if outgoing > 0:
					slot.amount -= outgoing
					building.output_buffer[item] = float(building.output_buffer.get(item, 0)) + outgoing
				break
