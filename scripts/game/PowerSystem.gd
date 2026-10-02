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
var allow_time_warp := true

func _init(state: GameState, statistics: StatisticsSystem = null) -> void:
	game_state = state
	statistics_system = statistics
	galaxy_system = GalaxySystem.new(state)

func update(delta: float) -> void:
	_calculate_power(delta)

func _calculate_power(delta: float) -> void:
	_dyson_receiver_outputs = DysonSphereSystem.new(game_state).receiver_outputs()
	TimeWarpSystem.new(game_state).reset_allocation()
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
		var rated := maxf(float(definition.get("power_generation", 0)), float(_dyson_receiver_outputs.get(building.get("id", ""), 0)))
		if definition.get("kind") == "generator" or rated > 0: covered = true
		var needed := maxf(float(definition.get("power_demand", 0)), 0)
		if definition.get("source_id") == "construction_center":
			needed = float(definition.get("power_demand", 0)) if not building.get("automation_paused", false) and game_state.production_orders.any(func(job): return job.center_id == building.id and not job.paused) else 0.0
		elif definition.get("source_id") in ["em_rail_ejector", "vertical_launching_silo"]:
			var ammo := String(DysonSphereSystem.AMMO.get(building.get("type", ""), ""))
			needed = needed if building.get("dyson", {}).get("enabled", false) and float(building.get("input_buffer", {}).get(ammo, 0)) >= 1 and (game_state.source_galaxy.is_empty() or SourceDysonEngineering.new(game_state).launch_factor(ammo == "solar_sail") > 0) else 0.0
		elif definition.has("source_id") and definition.get("kind") == "processor":
			var recipe := DataManager.get_recipe(String(building.get("recipe_id", "")))
			if recipe.get("source_id") == "matrix_research":
				needed = needed if TechnologySystem.new(game_state).source_lab_can_work(building) else 0.0
			elif recipe.is_empty() or not ProductionSystem.new(game_state)._has_required_inputs(building, recipe) or not ProductionSystem.new(game_state)._has_output_space(building, recipe): needed = 0
		if definition.has("source_id") and definition.get("kind") == "processor" and building.get("spray_coater_installed", false):
			var recipe := DataManager.get_recipe(String(building.get("recipe_id", "")))
			var outputs := ProliferatorSystem.outputs(building, recipe, ProliferatorSystem.profile(building, recipe))
			for item in outputs:
				if float(building.get("output_buffer", {}).get(item, 0)) + outputs[item] > float(definition.get("output_buffer_capacity", 60)): needed = 0
		if building.get("spray_coater_installed", false): needed *= float(ProliferatorSystem.profile(building, DataManager.get_recipe(String(building.get("recipe_id", "")))).power)
		needed *= StationSystem.stack_count(building)
		needed *= GameModeSystem.new(game_state).multiplier("power_demand")
		building["power_requested"] = needed
		if needed > 0:
			consumers.append({"building": building, "capacity": needed})
			demand += needed
		if PowerGridSystem.kind_id(building) in ["accumulator", "energy_exchanger"]:
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
	var warp_building: Dictionary = {}
	var warp_stable := 0
	var warp_required := 0.0
	if allow_time_warp and game_state.time_warp.get("enabled", false):
		for building in buildings:
			if building.get("id") == game_state.time_warp.get("controller_id") and building.get("type") == "dsp_time_warp_device":
				warp_building = building
				break
		if not warp_building.is_empty():
			warp_stable = TimeWarpSystem.maximum_stable(maxf(capacity - demand, 0), int(game_state.time_warp.get("requested", 5)))
			warp_required = TimeWarpSystem.required_power_kw(warp_stable) if warp_stable >= 4 else TimeWarpSystem.BASE_POWER_KW
			warp_building.power_requested = warp_required
			demand += warp_required
	var supplied := minf(demand, capacity) if covered else 0.0
	var remaining := supplied
	for priority in [3, 2, 1]:
		var group: Array = consumers.filter(func(candidate): return int(candidate.building.get("power_priority", 2)) == priority)
		remaining -= _allocate(group, remaining, "power_input")
	if not warp_building.is_empty():
		warp_building.power_input = minf(maxf(remaining, 0), warp_required)
		TimeWarpSystem.new(game_state).set_allocation(warp_stable, warp_required, float(warp_building.power_input))
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
		if PowerGridSystem.kind_id(building) in ["accumulator", "energy_exchanger"]:
			PowerGridSystem.apply_storage(building, output * delta / 1000.0, false, statistics_system)
			discharged += output
		else:
			_burn_dispatched_fuel(building, output, delta)
	remaining = maxf(base - demand, 0)
	var charged := 0.0
	for type in ["energy_exchanger", "accumulator"]:
		var group: Array = chargers.filter(func(candidate): return PowerGridSystem.kind_id(candidate.building) == type)
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
	var rule: Dictionary = fuel_rule(building, definition)
	var item := String(building.get("fuel_item", rule.get("item_id", "")))
	if item != rule.get("item_id"): return 0
	var seconds := float(building.get("fuel_remaining", 0)) + floorf(float(building.get("input_buffer", {}).get(item, 0))) * float(rule.get("burn_duration", 0))
	var rated := float(definition.get("power_generation", 0)) * float(building.get("generation_factor", 1))
	return rated * clampf(seconds / delta, 0, 1) if delta > 0 else 0.0

func _burn_dispatched_fuel(building: Dictionary, output: float, delta: float) -> void:
	var definition := DataManager.get_building(String(building.type))
	var rule: Dictionary = fuel_rule(building, definition)
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
	if String(building.get("type", "")) in ["ray_receiver", "dsp_ray_receiver"]:
		return float(_dyson_receiver_outputs.get(building.get("id", ""), 0))
	var generation_factor := clampf(float(building.get("generation_factor", 1.0)), 0.0, 1.0)
	var environment_multiplier := 1.0
	if PowerGridSystem.kind_id(building) == "solar_panel":
		var planet := galaxy_system.get_planet(String(building.get("planet_id", game_state.active_planet_id)))
		environment_multiplier = maxf(float(planet.get("solar_multiplier", 1.0)), 0.0)
	if building_definition.has("source_id"):
		environment_multiplier = source_environment_multiplier(game_state, String(building.type), String(building.planet_id))
	return base_generation * generation_factor * environment_multiplier

func get_power_info(planet_id: String = "") -> Dictionary:
	var resolved_planet_id := game_state.active_planet_id if planet_id.is_empty() else planet_id
	return _power_by_planet.get(resolved_planet_id, _empty_power_info()).duplicate(true)

func is_power_sufficient(planet_id: String = "") -> bool:
	return float(get_power_info(planet_id)["efficiency"]) >= 1.0

func _empty_power_info() -> Dictionary:
	return {"generation": 0.0, "consumption": 0.0, "balance": 0.0, "efficiency": 1.0}

static func fuel_rule(building: Dictionary, definition: Dictionary) -> Dictionary:
	var rule: Dictionary = definition.get("fuel", {}).duplicate()
	var item := String(building.get("fuel_item", rule.get("item_id", "")))
	if definition.get("fuel_options", {}).has(item):
		rule = {"item_id": item, "burn_duration": float(definition.fuel_options[item])}
	return rule

static func source_environment_multiplier(state: GameState, building_type: String, planet_id: String) -> float:
	var role := String(DataManager.get_building(building_type).get("source_id", ""))
	if not state.source_galaxy.is_empty():
		var service := SourceGalaxySystem.new(state)
		if role == "solar_panel": return service.solar_multiplier(planet_id)
		if role == "geothermal_power_station": return float(service.profile(planet_id).get("geothermalMultiplier", 0))
		if role == "wind_turbine": return float(service.profile(planet_id).get("windMultiplier", 0))
	if role == "solar_panel": return float(GalaxySystem.new(state).get_planet(planet_id).get("solar_multiplier", 0))
	if role == "geothermal_power_station": return float({"ashen": 1.0, "frost": 0.08, "magnetar": 0.18}.get(planet_id, 0))
	if role == "wind_turbine": return float({"home": 1.0, "ashen": 1.0, "frost": 1.32, "magnetar": 0.28}.get(planet_id, 0))
	return 1.0
