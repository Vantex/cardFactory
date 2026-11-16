# scripts/game/BeltSystem.gd
class_name BeltSystem
extends RefCounted

const DEFAULT_BUFFER_CAPACITY := 60.0

var optimize_queries := true
var _tick_priorities: Dictionary = {}
var game_state: GameState
var statistics_system: StatisticsSystem

func _init(state: GameState, statistics: StatisticsSystem = null):
	game_state = state
	statistics_system = statistics

func clear_flow_state() -> void:
	for conn_id in game_state.connections:
		var connection = game_state.connections[conn_id]
		connection["active"] = false
		connection["current_flow"] = 0.0

func update(delta: float):
	clear_flow_state()
	var connection_ids: Array = game_state.connections.keys()
	_tick_priorities.clear()
	if optimize_queries:
		for id in connection_ids:
			_tick_priorities[id] = int(game_state.get_belt_configuration(String(id)).get("priority", 0))
	connection_ids.sort_custom(_connection_precedes)
	_tick_priorities.clear()
	var balanced := _balanced_allocations(connection_ids, delta)
	for conn_id in connection_ids:
		var connection = game_state.connections[conn_id]
		if not _is_connection_planet_local(connection):
			continue
		_update_connection(connection, delta, float(balanced.get(conn_id, INF)))

func _balanced_allocations(ids: Array, delta: float) -> Dictionary:
	var groups := {}
	for id in ids:
		var connection: Dictionary = game_state.connections[id]
		var source := game_state.get_building(connection.source_id)
		var target := game_state.get_building(connection.target_id)
		if source.is_empty() or target.is_empty() or not connection.get("enabled", true) or not _is_connection_planet_local(connection): continue
		if DataManager.get_building(source.type).get("kind") != "splitter" or source.get("distribution_mode", "balanced") == "priority": continue
		if target.get("type") == BlackHoleSystem.TYPE or target.get("station", {}).get("quantum_mode") == "quantum": continue
		var key := str([connection.source_id, connection.item_id])
		if not groups.has(key): groups[key] = {"available": maxf(0, float(source.get("output_buffer", {}).get(connection.item_id, 0))), "candidates": []}
		var definition := DataManager.get_building(target.type)
		var free := maxf(0, _target_input_capacity(target, definition, String(connection.item_id)) - float(target.get("input_buffer", {}).get(connection.item_id, 0)))
		var power := minf(clampf(float(source.get("power_efficiency", 1)), 0, 1), clampf(float(target.get("power_efficiency", 1)), 0, 1))
		groups[key].candidates.append({"id": id, "capacity": minf(free, _effective_throughput(connection) * delta * power)})
	var result := {}
	for group in groups.values():
		var candidates: Array = group.candidates
		var remaining: float = group.available
		while not candidates.is_empty():
			var share := remaining / candidates.size()
			var constrained := false
			for candidate in candidates.duplicate():
				if candidate.capacity <= share:
					result[candidate.id] = candidate.capacity
					remaining -= candidate.capacity
					candidates.erase(candidate)
					constrained = true
			if not constrained:
				for candidate in candidates: result[candidate.id] = share
				break
	return result

func _connection_precedes(left_id: Variant, right_id: Variant) -> bool:
	var left_key := String(left_id)
	var right_key := String(right_id)
	if optimize_queries:
		var left := int(_tick_priorities[left_key])
		var right := int(_tick_priorities[right_key])
		return left > right if left != right else left_key < right_key
	var left_config := game_state.get_belt_configuration(left_key)
	var right_config := game_state.get_belt_configuration(right_key)
	var left_priority := int(left_config.get("priority", 0))
	var right_priority := int(right_config.get("priority", 0))
	if left_priority != right_priority:
		return left_priority > right_priority
	return left_key < right_key

func _update_connection(connection: Dictionary, delta: float, allocation: float = INF):
	if not connection.get("enabled", true) or delta <= 0.0:
		return

	var source_id = connection.get("source_id", "")
	var target_id = connection.get("target_id", "")
	var item_id = connection.get("item_id", "")
	var flow_rate := _effective_throughput(connection)

	var source = game_state.get_building(source_id)
	var target = game_state.get_building(target_id)

	if source.is_empty() or target.is_empty():
		return
	if target.get("station", {}).get("quantum_mode", "legacy") == "quantum":
		for slot in target.station.slots:
			if slot.item_id == item_id and StationSystem.mode_for(target, slot, true) == "supply":
				_update_quantum_connection(connection, source, item_id, flow_rate, delta)
				return
	if target.get("type") == BlackHoleSystem.TYPE:
		_update_black_hole_connection(connection, source, target, item_id, flow_rate, delta)
		return
	var source_power := clampf(float(source.get("power_efficiency", 1.0)), 0.0, 1.0)
	var target_power := clampf(float(target.get("power_efficiency", 1.0)), 0.0, 1.0)
	var power_efficiency := minf(source_power, target_power)
	if power_efficiency <= 0.0:
		return

	var available := _source_available(source, item_id)
	var target_buffer = target.get("input_buffer", {}).get(item_id, 0.0)
	var target_definition := DataManager.get_building(String(target.get("type", "")))
	var target_capacity := _target_input_capacity(target, target_definition, String(item_id))
	var max_transfer = min(available, target_capacity - target_buffer)
	var transfer_amount = minf(allocation, min(max_transfer, flow_rate * delta * power_efficiency))

	if target.get("type") == SystemSpaceStationSystem.TYPE:
		var credit := minf(1.0, float(connection.get("construction_credit", 0))) + flow_rate * delta * power_efficiency
		transfer_amount = minf(floorf(max_transfer), floorf(credit))
		connection.construction_credit = clampf(credit - transfer_amount, 0, 1)
	if transfer_amount > 0:
		if _take_source(source, item_id, transfer_amount) != transfer_amount:
			return
		if not source.has("output_buffer"):
			source.output_buffer = {}
		if not target.has("input_buffer"):
			target.input_buffer = {}

		target.input_buffer[item_id] = target.input_buffer.get(item_id, 0.0) + transfer_amount
		connection["current_flow"] = transfer_amount / delta
		connection["active"] = true
		if connection.get("monitor_enabled", false):
			connection["total_transferred"] = float(connection.get("total_transferred", 0.0)) + transfer_amount
		if statistics_system != null:
			statistics_system.record_transferred(String(item_id), transfer_amount, String(connection.get("id", "")), String(connection.get("planet_id", game_state.active_planet_id)))

func _update_black_hole_connection(connection: Dictionary, source: Dictionary, target: Dictionary, item_id: String, flow_rate: float, delta: float) -> void:
	if target.get("black_hole_paused", true) or not target.get("black_hole_activation_confirmed", false): return
	var available := maxi(0, int(floorf(_source_available(source, item_id))))
	if available < 1: return
	var credit := maxf(float(connection.get("black_hole_credit", 0)), 0) + flow_rate * delta * clampf(float(source.get("power_efficiency", 1)), 0, 1)
	var amount := mini(available, int(floorf(credit)))
	connection.black_hole_credit = minf(credit - amount, 1.0)
	if amount <= 0: return
	var staged_target := target.duplicate(true)
	if not BlackHoleSystem.record_transfer(staged_target, int(connection.get("target_port_index", -1)), item_id, amount): return
	if _take_source(source, item_id, float(amount)) != float(amount): return
	target.black_hole_ports = staged_target.black_hole_ports
	connection.current_flow = float(amount) / delta
	connection.active = true
	if connection.get("monitor_enabled", false): connection.total_transferred = float(connection.get("total_transferred", 0)) + amount
	if statistics_system != null: statistics_system.record_consumed(item_id, amount, target.id, target.planet_id)

func _update_quantum_connection(connection: Dictionary, source: Dictionary, item_id: String, flow_rate: float, delta: float) -> void:
	var available := maxi(0, int(floorf(_source_available(source, item_id))))
	if available < 1: return
	var credit := maxf(float(connection.get("quantum_credit", 0)), 0) + flow_rate * delta * clampf(float(source.get("power_efficiency", 1)), 0, 1)
	var inventory: Dictionary = game_state.quantum_network.get("inventory", {})
	var had_stock := inventory.has(item_id)
	var previous_stock: Variant = inventory.get(item_id)
	var accepted := QuantumLogisticsSystem.new(game_state).deposit(item_id, mini(available, int(floorf(credit))))
	connection.quantum_credit = minf(credit - accepted, 1.0)
	if accepted < 1: return
	if _take_source(source, item_id, accepted) != accepted:
		if had_stock: inventory[item_id] = previous_stock
		else: inventory.erase(item_id)
		return
	connection.current_flow = float(accepted) / delta
	connection.active = true
	if connection.get("monitor_enabled", false): connection.total_transferred = float(connection.get("total_transferred", 0)) + accepted
	if statistics_system != null: statistics_system.record_transferred(item_id, accepted, connection.id, connection.planet_id)

func _resource_output_site(source: Dictionary, item: String) -> Dictionary:
	var definition := DataManager.get_building(String(source.get("type", "")))
	if game_state.source_galaxy.is_empty() or not definition.has("source_id") or definition.get("kind") != "extractor": return {}
	var site: Dictionary = game_state.resource_sites.get(String(source.get("resource_site_id", "")), {})
	return site if site.has("output_buffer") and site.get("item_id") == item else {}

func _source_available(source: Dictionary, item: String) -> float:
	var site := _resource_output_site(source, item)
	return preload("res://scripts/game/SourceResourceOutputSystem.gd").raw_amount(game_state, site) if not site.is_empty() else float(source.get("output_buffer", {}).get(item, 0))

func _take_source(source: Dictionary, item: String, amount: float) -> float:
	var site := _resource_output_site(source, item)
	if not site.is_empty(): return preload("res://scripts/game/SourceResourceOutputSystem.gd").take(game_state, site, amount)
	var available := float(source.get("output_buffer", {}).get(item, 0))
	if not is_finite(amount) or not is_finite(available) or amount <= 0 or amount > available: return 0
	source.output_buffer[item] = available - amount
	return amount

func _effective_throughput(connection: Dictionary) -> float:
	var connection_type := String(connection.get("type", "belt"))
	if connection_type == "belt":
		return maxf(float(connection.get("flow_rate", 10.0)), 0.0)
	var configuration := game_state.get_belt_configuration(String(connection.get("id", "")))
	if configuration.is_empty():
		return maxf(float(connection.get("flow_rate", 10.0)), 0.0)
	return maxf(float(configuration.get("effective_throughput", 10.0)), 0.0)

func create_belt(source_id: String, target_id: String, item_id: String, flow_rate: float = 10.0) -> String:
	var result := try_create_belt(source_id, target_id, item_id, flow_rate)
	return String(result.get("id", "")) if result.get("ok", false) else ""

func try_create_belt(source_id: String, target_id: String, item_id: String = "", flow_rate: float = 10.0) -> Dictionary:
	if not game_state.buildings.has(source_id) or not game_state.buildings.has(target_id):
		return {"ok": false, "message": "连接建筑不存在"}
	var source_planet := String(game_state.buildings[source_id].get("planet_id", ""))
	var target_planet := String(game_state.buildings[target_id].get("planet_id", ""))
	if source_planet.is_empty() or source_planet != target_planet:
		return {"ok": false, "message": "不能跨行星连接"}
	if source_planet != game_state.active_planet_id:
		return {"ok": false, "message": "只能连接活动行星上的建筑"}
	return game_state.try_add_connection(source_id, target_id, item_id)

func _is_connection_planet_local(connection: Dictionary) -> bool:
	var source: Dictionary = game_state.get_building(String(connection.get("source_id", "")))
	var target: Dictionary = game_state.get_building(String(connection.get("target_id", "")))
	if source.is_empty() or target.is_empty():
		return false
	var planet_id := String(connection.get("planet_id", ""))
	return not planet_id.is_empty() and planet_id == String(source.get("planet_id", "")) and planet_id == String(target.get("planet_id", ""))

func _target_input_capacity(target: Dictionary, definition: Dictionary, item: String) -> float:
	if definition.has("source_id"):
		return game_state.get_entity_item_input_capacity(String(target.id), item)
	return maxf(float(target.get("input_buffer_capacity", definition.get("input_buffer_capacity", DEFAULT_BUFFER_CAPACITY))), 0.0)
