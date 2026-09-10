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
var _dyson_receiver_outputs: Dictionary = {}
var _grids: Dictionary = {}

func _init(state: GameState, statistics: StatisticsSystem = null) -> void:
	game_state = state
	statistics_system = statistics
	galaxy_system = GalaxySystem.new(state)

func update(delta: float) -> void:
	_calculate_power(delta)

func _calculate_power(delta: float) -> void:
	_dyson_receiver_outputs = DysonSphereSystem.new(game_state).receiver_outputs()
	_grids.clear()
	_power_by_planet.clear()
	total_generation = 0
	total_consumption = 0
	var groups := {}
	var ids := game_state.buildings.keys()
	ids.sort()
	for id in ids:
		var building: Dictionary = game_state.buildings[id]
		var planet := String(building.get("planet_id", game_state.active_planet_id))
		var key := planet + "|" + PowerGridSystem.grid_id(building)
		if not groups.has(key): groups[key] = []
		groups[key].append(building)
	for key in groups:
		var info := _dispatch_grid(groups[key], maxf(delta, 0))
		_grids[key] = info
		var planet: String = key.split("|")[0]
		if not _power_by_planet.has(planet): _power_by_planet[planet] = _empty_power_info()
		var aggregate: Dictionary = _power_by_planet[planet]
		for field in ["generation", "consumption", "supplied", "actual_generation", "storage_charge", "storage_discharge", "spilled"]:
			aggregate[field] = float(aggregate.get(field, 0)) + float(info.get(field, 0))
	for info in _power_by_planet.values():
		info.balance = info.generation - info.consumption
		info.efficiency = 1.0 if info.consumption <= 0 else clampf(info.supplied / info.consumption, 0, 1)
		total_generation += info.generation
		total_consumption += info.consumption
	power_balance = total_generation - total_consumption
	var supplied := 0.0
	for info in _power_by_planet.values(): supplied += info.get("supplied", 0)
	power_ratio = 1.0 if total_consumption <= 0 else clampf(supplied / total_consumption, 0, 1)

func _dispatch_grid(buildings: Array, delta: float) -> Dictionary:
	var consumers: Array = []
	var dispatch: Array = []
	var chargers: Array = []
	var base := 0.0
	var demand := 0.0
	var covered := false
	for building in buildings:
		var definition := DataManager.get_building(String(building.get("type", "")))
		building["power_output"] = 0.0
		building["power_input"] = 0.0
		building["power_efficiency"] = 1.0
		var rated := float(definition.get("power_generation", 0))
		if definition.get("kind") == "generator" or rated > 0: covered = true
		var needed := maxf(float(definition.get("power_demand", 0)), 0)
		building["power_requested"] = needed
		if needed > 0:
			consumers.append({"building": building, "capacity": needed})
			demand += needed
		if building.get("type") in ["accumulator", "energy_exchanger"]:
			dispatch.append({"building": building, "capacity": PowerGridSystem.storage_capacity(building, delta, false)})
			chargers.append({"building": building, "capacity": PowerGridSystem.storage_capacity(building, delta, true)})
		elif definition.has("fuel"):
			dispatch.append({"building": building, "capacity": _fuel_capacity(building, definition, delta)})
		elif rated > 0:
			var generated := _building_generation(building, definition, rated, delta)
			building.power_output = generated
			base += generated
	var capacity := base
	for candidate in dispatch: capacity += candidate.capacity
	var supplied := minf(demand, capacity) if covered else 0.0
	var remaining := supplied
	for priority in [3, 2, 1]:
		var group: Array = consumers.filter(func(candidate): return int(candidate.building.get("power_priority", 2)) == priority)
		remaining -= _allocate(group, remaining, "power_input")
	for building in buildings:
		building["power_covered"] = covered
		var needed: float = building.power_requested
		building.power_efficiency = building.power_input / needed if needed > 0 else 1.0
	remaining = maxf(supplied - base, 0)
	for priority in [3, 2, 1]:
		var group: Array = dispatch.filter(func(candidate): return PowerGridSystem.generation_priority(candidate.building) == priority)
		remaining -= _allocate(group, remaining, "power_output")
	var actual := base
	var discharged := 0.0
	for candidate in dispatch:
		var building: Dictionary = candidate.building
		var output: float = building.power_output
		actual += output
		if output <= 0: continue
		if building.get("type") in ["accumulator", "energy_exchanger"]:
			PowerGridSystem.apply_storage(building, output * delta / 1000.0, false, statistics_system)
			discharged += output
		else:
			_burn_dispatched_fuel(building, output, delta)
	remaining = maxf(base - demand, 0)
	var charged := 0.0
	for type in ["energy_exchanger", "accumulator"]:
		var group: Array = chargers.filter(func(candidate): return candidate.building.get("type") == type)
		var allocated := _allocate(group, remaining, "power_input")
		remaining -= allocated
		charged += allocated
		for candidate in group:
			if candidate.building.power_input > 0: PowerGridSystem.apply_storage(candidate.building, candidate.building.power_input * delta / 1000.0, true, statistics_system)
	return {"generation": capacity, "consumption": demand, "supplied": supplied, "actual_generation": actual,
		"storage_charge": charged, "storage_discharge": discharged, "spilled": remaining,
		"balance": capacity - demand, "efficiency": 1.0 if demand <= 0 else supplied / demand, "covered": covered}

func _allocate(candidates: Array, requested: float, field: String) -> float:
	var capacity := 0.0
	for candidate in candidates: capacity += candidate.capacity
	var amount := minf(maxf(requested, 0), capacity)
	for candidate in candidates: candidate.building[field] = amount * candidate.capacity / capacity if capacity > 0 else 0.0
	return amount

func _fuel_capacity(building: Dictionary, definition: Dictionary, delta: float) -> float:
	var rule: Dictionary = definition.fuel
	var item := String(building.get("fuel_item", rule.get("item_id", "")))
	if item != rule.get("item_id"): return 0
	var seconds := float(building.get("fuel_remaining", 0)) + floorf(float(building.get("input_buffer", {}).get(item, 0))) * float(rule.get("burn_duration", 0))
	var rated := float(definition.get("power_generation", 0)) * float(building.get("generation_factor", 1))
	return rated * clampf(seconds / delta, 0, 1) if delta > 0 else 0.0

func _burn_dispatched_fuel(building: Dictionary, output: float, delta: float) -> void:
	var definition := DataManager.get_building(String(building.type))
	var rule: Dictionary = definition.fuel
	var item: String = rule.item_id
	var rated := float(definition.power_generation) * float(building.get("generation_factor", 1))
	var required := output * delta / rated if rated > 0 else 0.0
	var remaining := float(building.get("fuel_remaining", 0))
	var duration := float(rule.burn_duration)
	var count := maxi(int(ceil((required - remaining) / duration)), 0) if duration > 0 else 0
	if count > 0:
		building.input_buffer[item] = float(building.input_buffer.get(item, 0)) - count
		if statistics_system != null: statistics_system.record_consumed(item, count, building.id, building.planet_id)
	building["fuel_remaining"] = maxf(remaining + count * duration - required, 0)
	building["fuel_item"] = item

func get_grid_info(planet_id: String, grid_id: String) -> Dictionary:
	return _grids.get(planet_id + "|" + grid_id, _empty_power_info()).duplicate(true)

func _building_generation(building: Dictionary, building_definition: Dictionary, base_generation: float, _delta: float) -> float:
	if String(building.get("type", "")) == "ray_receiver":
		return float(_dyson_receiver_outputs.get(building.get("id", ""), 0))
	var generation_factor := clampf(float(building.get("generation_factor", 1.0)), 0.0, 1.0)
	var environment_multiplier := 1.0
	if String(building.get("type", "")) == "solar_panel":
		var planet := galaxy_system.get_planet(String(building.get("planet_id", game_state.active_planet_id)))
		environment_multiplier = maxf(float(planet.get("solar_multiplier", 1.0)), 0.0)
	return base_generation * generation_factor * environment_multiplier

func get_power_info(planet_id: String = "") -> Dictionary:
	var resolved_planet_id := game_state.active_planet_id if planet_id.is_empty() else planet_id
	return _power_by_planet.get(resolved_planet_id, _empty_power_info()).duplicate(true)

func is_power_sufficient(planet_id: String = "") -> bool:
	return float(get_power_info(planet_id)["efficiency"]) >= 1.0

func _empty_power_info() -> Dictionary:
	return {"generation": 0.0, "consumption": 0.0, "balance": 0.0, "efficiency": 1.0}
