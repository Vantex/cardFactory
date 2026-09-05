class_name PowerSystem
extends RefCounted

var game_state: GameState
var statistics_system: StatisticsSystem
var galaxy_system: GalaxySystem
var total_generation := 0.0
var total_consumption := 0.0
var power_balance := 0.0
var power_ratio := 1.0
var _power_by_planet: Dictionary = {}

func _init(state: GameState, statistics: StatisticsSystem = null) -> void:
	game_state = state
	statistics_system = statistics
	galaxy_system = GalaxySystem.new(state)

func update(delta: float) -> void:
	_calculate_power(delta)
	_apply_power_effects()

func _calculate_power(delta: float) -> void:
	total_generation = 0.0
	total_consumption = 0.0
	_power_by_planet = {}
	for planet_id_value in game_state.colonized_planet_ids:
		_power_by_planet[String(planet_id_value)] = _empty_power_info()
	var building_ids: Array = game_state.buildings.keys()
	building_ids.sort()
	for building_id in building_ids:
		var building: Dictionary = game_state.buildings[building_id]
		var planet_id := String(building.get("planet_id", game_state.active_planet_id))
		if not _power_by_planet.has(planet_id):
			_power_by_planet[planet_id] = _empty_power_info()
		var planet_power: Dictionary = _power_by_planet[planet_id]
		building["power_output"] = 0.0
		var building_type := String(building.get("type", ""))
		var building_definition := DataManager.get_building(building_type)
		if building_definition.is_empty():
			continue
		var demand := maxf(float(building_definition.get("power_demand", 0.0)), 0.0)
		planet_power["consumption"] = float(planet_power["consumption"]) + demand
		var base_generation := maxf(float(building_definition.get("power_generation", 0.0)), 0.0)
		if base_generation <= 0.0:
			continue
		var actual_generation := _building_generation(building, building_definition, base_generation, delta)
		building["power_output"] = actual_generation
		planet_power["generation"] = float(planet_power["generation"]) + actual_generation
	for planet_id in _power_by_planet:
		var planet_power: Dictionary = _power_by_planet[planet_id]
		planet_power["balance"] = float(planet_power["generation"]) - float(planet_power["consumption"])
		planet_power["efficiency"] = 1.0 if float(planet_power["consumption"]) <= 0.0 else clampf(float(planet_power["generation"]) / float(planet_power["consumption"]), 0.0, 1.0)
		total_generation += float(planet_power["generation"])
		total_consumption += float(planet_power["consumption"])
	power_balance = total_generation - total_consumption
	power_ratio = 1.0 if total_consumption <= 0.0 else clampf(total_generation / total_consumption, 0.0, 1.0)

func _building_generation(building: Dictionary, building_definition: Dictionary, base_generation: float, delta: float) -> float:
	var generation_factor := clampf(float(building.get("generation_factor", 1.0)), 0.0, 1.0)
	var fuel_rule: Dictionary = building_definition.get("fuel", {})
	if not fuel_rule.is_empty():
		return base_generation * generation_factor * _consume_fuel_time(building, fuel_rule, delta)
	var environment_multiplier := 1.0
	if String(building.get("type", "")) == "solar_panel":
		var planet := galaxy_system.get_planet(String(building.get("planet_id", game_state.active_planet_id)))
		environment_multiplier = maxf(float(planet.get("solar_multiplier", 1.0)), 0.0)
	return base_generation * generation_factor * environment_multiplier

func _consume_fuel_time(building: Dictionary, rule: Dictionary, delta: float) -> float:
	var remaining := maxf(float(building.get("fuel_remaining", 0.0)), 0.0)
	if remaining <= 0.0:
		var item_id := String(building.get("fuel_item", rule.get("item_id", "")))
		var input_buffer: Dictionary = building.get("input_buffer", {})
		if item_id.is_empty() or float(input_buffer.get(item_id, 0.0)) < 1.0:
			building["fuel_remaining"] = 0.0
			return 0.0
		var fuel_before := float(input_buffer.get(item_id, 0.0))
		input_buffer[item_id] = fuel_before - 1.0
		building["input_buffer"] = input_buffer
		building["fuel_item"] = item_id
		if statistics_system != null:
			statistics_system.record_consumed(item_id, fuel_before - float(input_buffer[item_id]), String(building.get("id", "")), String(building.get("planet_id", game_state.active_planet_id)))
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
		var planet_id := String(building.get("planet_id", game_state.active_planet_id))
		var planet_power: Dictionary = _power_by_planet.get(planet_id, _empty_power_info())
		building["power_efficiency"] = float(planet_power["efficiency"]) if demand > 0.0 else 1.0

func get_power_info(planet_id: String = "") -> Dictionary:
	var resolved_planet_id := game_state.active_planet_id if planet_id.is_empty() else planet_id
	return _power_by_planet.get(resolved_planet_id, _empty_power_info()).duplicate(true)

func is_power_sufficient(planet_id: String = "") -> bool:
	return float(get_power_info(planet_id)["efficiency"]) >= 1.0

func _empty_power_info() -> Dictionary:
	return {"generation": 0.0, "consumption": 0.0, "balance": 0.0, "efficiency": 1.0}
