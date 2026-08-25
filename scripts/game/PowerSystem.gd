class_name PowerSystem
extends RefCounted

var game_state: GameState
var total_generation := 0.0
var total_consumption := 0.0
var power_balance := 0.0
var power_ratio := 1.0

func _init(state: GameState) -> void:
	game_state = state

func update(delta: float) -> void:
	_calculate_power(delta)
	_apply_power_effects()

func _calculate_power(delta: float) -> void:
	total_generation = 0.0
	total_consumption = 0.0
	var building_ids: Array = game_state.buildings.keys()
	building_ids.sort()
	for building_id in building_ids:
		var building: Dictionary = game_state.buildings[building_id]
		building["power_output"] = 0.0
		var building_type := String(building.get("type", ""))
		var building_definition := DataManager.get_building(building_type)
		if building_definition.is_empty():
			continue
		var demand := maxf(float(building_definition.get("power_demand", 0.0)), 0.0)
		total_consumption += demand
		var base_generation := maxf(float(building_definition.get("power_generation", 0.0)), 0.0)
		if base_generation <= 0.0:
			continue
		var actual_generation := _building_generation(building, building_definition, base_generation, delta)
		building["power_output"] = actual_generation
		total_generation += actual_generation
	power_balance = total_generation - total_consumption
	power_ratio = 1.0 if total_consumption <= 0.0 else clampf(total_generation / total_consumption, 0.0, 1.0)

func _building_generation(building: Dictionary, building_definition: Dictionary, base_generation: float, delta: float) -> float:
	var generation_factor := clampf(float(building.get("generation_factor", 1.0)), 0.0, 1.0)
	var fuel_rule: Dictionary = building_definition.get("fuel", {})
	if not fuel_rule.is_empty():
		return base_generation * generation_factor * _consume_fuel_time(building, fuel_rule, delta)
	return base_generation * generation_factor

func _consume_fuel_time(building: Dictionary, rule: Dictionary, delta: float) -> float:
	var remaining := maxf(float(building.get("fuel_remaining", 0.0)), 0.0)
	if remaining <= 0.0:
		var item_id := String(building.get("fuel_item", rule.get("item_id", "")))
		var input_buffer: Dictionary = building.get("input_buffer", {})
		if item_id.is_empty() or float(input_buffer.get(item_id, 0.0)) < 1.0:
			building["fuel_remaining"] = 0.0
			return 0.0
		input_buffer[item_id] = float(input_buffer.get(item_id, 0.0)) - 1.0
		building["input_buffer"] = input_buffer
		building["fuel_item"] = item_id
		remaining = float(rule.get("burn_duration", 0.0))
	if delta <= 0.0:
		building["fuel_remaining"] = remaining
		return 1.0
	var powered_fraction := clampf(remaining / delta, 0.0, 1.0)
	building["fuel_remaining"] = maxf(remaining - delta, 0.0)
	return powered_fraction

func _apply_power_effects() -> void:
	for building_value in game_state.buildings.values():
		var building: Dictionary = building_value
		var building_definition := DataManager.get_building(String(building.get("type", "")))
		var demand := maxf(float(building_definition.get("power_demand", 0.0)), 0.0)
		building["power_efficiency"] = power_ratio if demand > 0.0 else 1.0

func get_power_info() -> Dictionary:
	return {
		"generation": total_generation,
		"consumption": total_consumption,
		"balance": power_balance,
		"efficiency": power_ratio,
	}

func is_power_sufficient() -> bool:
	return power_ratio >= 1.0
