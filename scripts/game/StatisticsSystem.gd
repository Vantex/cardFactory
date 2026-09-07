class_name StatisticsSystem
extends RefCounted

const SAMPLE_INTERVAL := 1.0
const MAX_SAMPLES := 600
const SUPPORTED_WINDOWS := [60, 300, 600]
const FINITE_LIMIT := 1.0e308

var game_state: GameState
var _sample_elapsed := 0.0
var _sample_generation := 0
var _current_sample := _empty_sample()
var _history: Array = []

func _init(state: GameState) -> void:
	game_state = state

func record_produced(item_id: String, amount: float, building_id: String = "", planet_id: String = "") -> void:
	_record_amount("produced", item_id, amount, building_id, _resolve_planet_id(building_id, planet_id))

func record_consumed(item_id: String, amount: float, building_id: String = "", planet_id: String = "") -> void:
	_record_amount("consumed", item_id, amount, building_id, _resolve_planet_id(building_id, planet_id))

func record_transferred(item_id: String, amount: float, connection_id: String = "", planet_id: String = "") -> void:
	_record_amount("transferred", item_id, amount, "", _resolve_planet_id(connection_id, planet_id))

func update(delta: float) -> void:
	_sample_elapsed += maxf(delta, 0.0)
	while _sample_elapsed + 0.0000001 >= SAMPLE_INTERVAL:
		_history.append(_current_sample.duplicate(true))
		_sample_generation += 1
		if _history.size() > MAX_SAMPLES:
			_history.pop_front()
		_current_sample = _empty_sample()
		_sample_elapsed = maxf(_sample_elapsed - SAMPLE_INTERVAL, 0.0)

func get_item_rates(item_id: String, window_seconds: int = 60) -> Dictionary:
	return _get_rates_from_totals(_get_window_totals(window_seconds), item_id)

func get_building_item_rates(building_id: String, item_id: String, window_seconds: int = 60) -> Dictionary:
	return _get_rates_from_totals(_get_building_window_totals(building_id, window_seconds), item_id)

func get_statistics_summary(window_seconds: int = 60) -> Dictionary:
	var totals := _get_window_totals(window_seconds)
	return _build_summary(totals, window_seconds, get_total_buildings(), get_total_connections())

func get_planet_summary(planet_id: String = "", window_seconds: int = 60) -> Dictionary:
	var resolved_planet_id := game_state.active_planet_id if planet_id.is_empty() else planet_id
	var totals := _get_planet_window_totals(resolved_planet_id, window_seconds)
	var building_count := 0
	var connection_count := 0
	for building_value in game_state.buildings.values():
		if String(building_value.get("planet_id", "")) == resolved_planet_id:
			building_count += 1
	for connection_value in game_state.connections.values():
		if String(connection_value.get("planet_id", "")) == resolved_planet_id:
			connection_count += 1
	var summary := _build_summary(totals, window_seconds, building_count, connection_count)
	summary["planet_id"] = resolved_planet_id
	return summary

func _build_summary(totals: Dictionary, window_seconds: int, building_count: int, connection_count: int) -> Dictionary:
	var item_ids: Array = []
	for category in ["produced", "consumed", "transferred"]:
		for item_id in totals[category]:
			if not item_ids.has(item_id):
				item_ids.append(item_id)
	item_ids.sort()
	var item_rates := {}
	for item_id in item_ids:
		item_rates[item_id] = _get_rates_from_totals(totals, String(item_id))
	var production := _get_rates_by_item_from_totals(totals, "produced")
	var consumption := _get_rates_by_item_from_totals(totals, "consumed")
	var transferred := _get_rates_by_item_from_totals(totals, "transferred")
	return {
		"total_buildings": building_count,
		"total_connections": connection_count,
		"elapsed_time": game_state.elapsed_time,
		"window_seconds": window_seconds,
		"covered_seconds": totals["covered_seconds"],
		"production": production,
		"consumption": consumption,
		"transferred": transferred,
		"items": item_rates.duplicate(true),
	}

func get_history_size() -> int:
	return _history.size()

func get_sample_generation() -> int:
	return _sample_generation

func get_production_rate(item_id: String) -> float:
	return float(get_item_rates(item_id)["produced_per_minute"])

func get_consumption_rate(item_id: String) -> float:
	return float(get_item_rates(item_id)["consumed_per_minute"])

func get_net_production(item_id: String) -> float:
	return float(get_item_rates(item_id)["net_per_minute"])

func get_all_production(window_seconds: int = 60) -> Dictionary:
	return _get_rates_by_item("produced", window_seconds)

func get_all_consumption(window_seconds: int = 60) -> Dictionary:
	return _get_rates_by_item("consumed", window_seconds)

func get_all_transferred(window_seconds: int = 60) -> Dictionary:
	return _get_rates_by_item("transferred", window_seconds)

func get_total_buildings() -> int:
	return game_state.buildings.size()

func get_total_connections() -> int:
	return game_state.connections.size()

func get_building_count_by_type(building_type: String) -> int:
	var count := 0
	for building_id in game_state.buildings:
		if String(game_state.buildings[building_id].get("type", "")) == building_type:
			count += 1
	return count

func get_logistics_throughput(window_seconds: int = 60) -> Dictionary:
	return get_all_transferred(window_seconds)

func get_logistics_latency() -> Dictionary:
	return {"min_latency": 0.1, "max_latency": 1.0, "avg_latency": 0.5}

func get_logistics_efficiency() -> float:
	if game_state.connections.is_empty():
		return 0.0
	var active_connections := 0
	for connection_id in game_state.connections:
		if game_state.connections[connection_id].get("active", false):
			active_connections += 1
	return float(active_connections) / float(game_state.connections.size())

func get_power_statistics() -> Dictionary:
	var stats := {"total_demand": 0.0, "total_generation": 0.0, "balance": 0.0, "efficiency": 0.0}
	for building_id in game_state.buildings:
		var building: Dictionary = game_state.buildings[building_id]
		var building_def := DataManager.get_building(String(building.get("type", "")))
		stats["total_demand"] = _saturating_add(float(stats["total_demand"]), maxf(float(building_def.get("power_demand", 0.0)), 0.0))
		stats["total_generation"] = _saturating_add(float(stats["total_generation"]), maxf(float(building.get("power_output", 0.0)), 0.0))
	stats["balance"] = _finite_signed(float(stats["total_generation"]) - float(stats["total_demand"]))
	stats["efficiency"] = 1.0 if float(stats["total_demand"]) <= 0.0 else clampf(_finite_nonnegative(float(stats["total_generation"]) / float(stats["total_demand"])), 0.0, 1.0)
	return stats

func record_production_snapshot() -> void:
	pass

func get_production_history() -> Array:
	return _history.duplicate(true)

func get_production_trend(item_id: String) -> float:
	if _history.size() < 2:
		return 0.0
	var recent := float(_history[-1]["produced"].get(item_id, 0.0))
	var previous := float(_history[-2]["produced"].get(item_id, 0.0))
	if is_zero_approx(previous):
		return 0.0
	return _finite_signed((recent - previous) / previous)

func get_building_efficiency_stats() -> Dictionary:
	var stats := {"total_buildings": 0, "running_buildings": 0, "idle_buildings": 0, "blocked_buildings": 0, "avg_efficiency": 0.0}
	var total_efficiency := 0.0
	for building_id in game_state.buildings:
		var building: Dictionary = game_state.buildings[building_id]
		stats["total_buildings"] += 1
		match String(building.get("status", "idle")):
			"running":
				stats["running_buildings"] += 1
				total_efficiency = _saturating_add(total_efficiency, maxf(float(building.get("efficiency", 1.0)), 0.0))
			"blocked": stats["blocked_buildings"] += 1
			_: stats["idle_buildings"] += 1
	if int(stats["running_buildings"]) > 0:
		stats["avg_efficiency"] = total_efficiency / float(stats["running_buildings"])
	return stats

func get_resource_statistics() -> Dictionary:
	var stats := {}
	for building_id in game_state.buildings:
		var building: Dictionary = game_state.buildings[building_id]
		for buffer_name in ["input_buffer", "output_buffer"]:
			for item_id in building.get(buffer_name, {}):
				if not stats.has(item_id):
					stats[item_id] = {"stored": 0.0, "produced": 0.0, "consumed": 0.0}
				stats[item_id]["stored"] = _saturating_add(float(stats[item_id]["stored"]), maxf(float(building[buffer_name][item_id]), 0.0))
	return stats

func _record_amount(category: String, item_id: String, amount: float, building_id: String, planet_id: String) -> void:
	if item_id.is_empty() or not is_finite(amount) or amount <= 0.0:
		return
	var totals: Dictionary = _current_sample[category]
	totals[item_id] = _saturating_add(float(totals.get(item_id, 0.0)), amount)
	var planet_samples: Dictionary = _current_sample["planets"]
	if not planet_samples.has(planet_id):
		planet_samples[planet_id] = _empty_categories()
	var planet_totals: Dictionary = planet_samples[planet_id]
	var planet_category: Dictionary = planet_totals[category]
	planet_category[item_id] = _saturating_add(float(planet_category.get(item_id, 0.0)), amount)
	if building_id.is_empty():
		return
	var building_samples: Dictionary = _current_sample["buildings"]
	if not building_samples.has(building_id):
		building_samples[building_id] = _empty_categories()
	var building_totals: Dictionary = building_samples[building_id]
	var category_totals: Dictionary = building_totals[category]
	category_totals[item_id] = _saturating_add(float(category_totals.get(item_id, 0.0)), amount)

func _get_window_totals(window_seconds: int) -> Dictionary:
	if not SUPPORTED_WINDOWS.has(window_seconds):
		return _empty_totals()
	var totals := _empty_totals()
	var remaining := float(window_seconds)
	for index in range(_history.size() - 1, -1, -1):
		if remaining <= 0.0:
			break
		var sample: Dictionary = _history[index]
		var sample_duration := minf(SAMPLE_INTERVAL, remaining)
		_merge_amounts(totals["produced"], sample["produced"], sample_duration / SAMPLE_INTERVAL)
		_merge_amounts(totals["consumed"], sample["consumed"], sample_duration / SAMPLE_INTERVAL)
		_merge_amounts(totals["transferred"], sample["transferred"], sample_duration / SAMPLE_INTERVAL)
		totals["covered_seconds"] += sample_duration
		remaining -= sample_duration
	return totals

func _get_building_window_totals(building_id: String, window_seconds: int) -> Dictionary:
	if building_id.is_empty() or not SUPPORTED_WINDOWS.has(window_seconds):
		return _empty_totals()
	var totals := _empty_totals()
	var remaining := float(window_seconds)
	for index in range(_history.size() - 1, -1, -1):
		if remaining <= 0.0:
			break
		var sample: Dictionary = _history[index]
		var sample_duration := minf(SAMPLE_INTERVAL, remaining)
		var building_totals: Dictionary = sample["buildings"].get(building_id, {})
		_merge_amounts(totals["produced"], building_totals.get("produced", {}), sample_duration / SAMPLE_INTERVAL)
		_merge_amounts(totals["consumed"], building_totals.get("consumed", {}), sample_duration / SAMPLE_INTERVAL)
		_merge_amounts(totals["transferred"], building_totals.get("transferred", {}), sample_duration / SAMPLE_INTERVAL)
		totals["covered_seconds"] += sample_duration
		remaining -= sample_duration
	return totals

func _get_planet_window_totals(planet_id: String, window_seconds: int) -> Dictionary:
	if planet_id.is_empty() or not SUPPORTED_WINDOWS.has(window_seconds):
		return _empty_totals()
	var totals := _empty_totals()
	var remaining := float(window_seconds)
	for index in range(_history.size() - 1, -1, -1):
		if remaining <= 0.0:
			break
		var sample: Dictionary = _history[index]
		var sample_duration := minf(SAMPLE_INTERVAL, remaining)
		var planet_totals: Dictionary = sample.get("planets", {}).get(planet_id, {})
		_merge_amounts(totals["produced"], planet_totals.get("produced", {}), sample_duration / SAMPLE_INTERVAL)
		_merge_amounts(totals["consumed"], planet_totals.get("consumed", {}), sample_duration / SAMPLE_INTERVAL)
		_merge_amounts(totals["transferred"], planet_totals.get("transferred", {}), sample_duration / SAMPLE_INTERVAL)
		totals["covered_seconds"] += sample_duration
		remaining -= sample_duration
	return totals

func _get_rates_from_totals(totals: Dictionary, item_id: String) -> Dictionary:
	var covered_seconds := float(totals.get("covered_seconds", 0.0))
	if covered_seconds <= 0.0:
		return _empty_item_rates()
	var multiplier := 60.0 / covered_seconds
	var produced := _finite_nonnegative(float(totals["produced"].get(item_id, 0.0)) * multiplier)
	var consumed := _finite_nonnegative(float(totals["consumed"].get(item_id, 0.0)) * multiplier)
	var transferred := _finite_nonnegative(float(totals["transferred"].get(item_id, 0.0)) * multiplier)
	return {"produced_per_minute": produced, "consumed_per_minute": consumed, "net_per_minute": _finite_signed(produced - consumed), "transferred_per_minute": transferred}

func _get_rates_by_item(category: String, window_seconds: int) -> Dictionary:
	var totals := _get_window_totals(window_seconds)
	return _get_rates_by_item_from_totals(totals, category)

func _get_rates_by_item_from_totals(totals: Dictionary, category: String) -> Dictionary:
	var covered_seconds := float(totals["covered_seconds"])
	if covered_seconds <= 0.0:
		return {}
	var rates := {}
	for item_id in totals[category]:
		rates[item_id] = _finite_nonnegative(float(totals[category][item_id]) * 60.0 / covered_seconds)
	return rates.duplicate(true)

func _merge_amounts(destination: Dictionary, source: Dictionary, scale: float) -> void:
	for item_id in source:
		destination[item_id] = _saturating_add(float(destination.get(item_id, 0.0)), _finite_nonnegative(float(source[item_id]) * scale))

func _saturating_add(left: float, right: float) -> float:
	return _finite_nonnegative(left + right)

func _finite_nonnegative(value: float) -> float:
	if is_nan(value) or value <= 0.0:
		return 0.0
	return minf(value, FINITE_LIMIT)

func _finite_signed(value: float) -> float:
	if is_nan(value):
		return 0.0
	return clampf(value, -FINITE_LIMIT, FINITE_LIMIT)

func _empty_sample() -> Dictionary:
	var sample := _empty_categories()
	sample["buildings"] = {}
	sample["planets"] = {}
	return sample

func _resolve_planet_id(entity_id: String, explicit_planet_id: String) -> String:
	if not explicit_planet_id.is_empty():
		return explicit_planet_id
	if game_state.buildings.has(entity_id):
		return String(game_state.buildings[entity_id].get("planet_id", game_state.active_planet_id))
	if game_state.connections.has(entity_id):
		return String(game_state.connections[entity_id].get("planet_id", game_state.active_planet_id))
	return game_state.active_planet_id

func _empty_categories() -> Dictionary:
	return {"produced": {}, "consumed": {}, "transferred": {}}

func _empty_totals() -> Dictionary:
	var totals := _empty_categories()
	totals["covered_seconds"] = 0.0
	return totals

func _empty_item_rates() -> Dictionary:
	return {"produced_per_minute": 0.0, "consumed_per_minute": 0.0, "net_per_minute": 0.0, "transferred_per_minute": 0.0}

func get_recent_amounts() -> Dictionary:
	var totals := {"produced": {}, "consumed": {}, "transferred": {}}
	for sample in _history + [_current_sample]:
		for category in totals:
			_merge_amounts(totals[category], sample[category], 1.0)
	return totals
