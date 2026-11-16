class_name ProductionSystem
extends RefCounted

const PROGRESS_EPSILON := 0.0000001
const DEFAULT_BUFFER_CAPACITY := 60.0
const SOURCE_EPSILON := 0.0001

var game_state: GameState
var statistics_system: StatisticsSystem
var _dyson_receipts: Dictionary = {}

func _init(state: GameState, statistics: StatisticsSystem = null) -> void:
	game_state = state
	statistics_system = statistics

func update(delta: float) -> void:
	_dyson_receipts = DysonSphereSystem.new(game_state).receiver_allocations()
	var building_ids: Array = game_state.buildings.keys()
	building_ids.sort()
	for building_id in building_ids:
		_update_building(game_state.buildings[building_id], delta)

func _update_building(building: Dictionary, delta: float) -> void:
	building["production_utilization"] = 0.0
	var building_type := String(building.get("type", ""))
	var building_definition := DataManager.get_building(building_type)
	if building_definition.get("source_id") != "energy_exchanger": building["last_production_per_minute"] = 0.0
	if building_definition.get("kind") in ["storage", "splitter"]:
		var item := String(building.get("stored_item", ""))
		var inputs: Dictionary = building.get("input_buffer", {})
		var outputs: Dictionary = building.get("output_buffer", {})
		var capacity := _get_buffer_capacity(building, building_definition, "output")
		var moved := minf(floorf(float(inputs.get(item, 0)) + PROGRESS_EPSILON), maxf(0, capacity - float(outputs.get(item, 0))))
		if item != "" and moved > 0:
			inputs[item] = float(inputs.get(item, 0)) - moved
			outputs[item] = float(outputs.get(item, 0)) + moved
			building.input_buffer = inputs
			building.output_buffer = outputs
		building.status = "running" if moved > 0 else "idle"
		return
	if building_type == "dsp_ray_receiver" and building.get("recipe_id", "") == "dsp_critical_photon":
		_update_photon_receiver(building, delta)
		return
	if building_definition.get("kind", "") == "generator":
		if building_definition.get("source_id", "") == "energy_exchanger":
			var charging: bool = building.get("energy_mode", "charge") == "charge"
			var actual_power := float(building.get("power_input" if charging else "power_output", 0))
			var rated := float(building_definition.get("power_charge" if charging else "power_generation", 0))
			building.production_utilization = clampf(actual_power / rated, 0, 1) if rated > 0 else 0.0
		if float(building.get("power_input", 0.0)) > 0.0:
			building["status"] = "charging"
			return
		if float(building.get("power_output", 0.0)) > 0.0:
			building["status"] = "running"
		elif not building_definition.get("fuel", {}).is_empty():
			building["status"] = "standby" if float(building.get("fuel_remaining", 0)) > 0 or float(building.get("input_buffer", {}).get(PowerSystem.fuel_rule(building, building_definition).item_id, 0)) >= 1 else "no_fuel"
		else:
			building["status"] = "idle"
		return
	if building_definition.get("kind", "") == "extractor":
		_update_extractor(building, building_definition, delta)
		return
	var recipe_id := String(building.get("recipe_id", ""))
	if recipe_id.is_empty():
		building["status"] = "idle"
		return
	var recipe := DataManager.get_recipe(recipe_id)
	if recipe.is_empty():
		building["status"] = "error"
		return
	# Special operations are advanced by their owning systems, never by item conversion.
	if recipe.get("operation", "production") != "production" or building_definition.get("source_id") in ["ray_receiver", "energy_exchanger"]:
		if recipe.get("source_id", "") == "ray_power":
			var capacity := DysonSphereSystem.new(game_state).receiver_capacity("dsp_ray_receiver")
			building.production_utilization = clampf(float(building.get("power_output", 0)) / capacity, 0, 1) if capacity > 0 else 0.0
		building["status"] = "idle"
		return
	if building.get("spray_coater_installed", false):
		_update_sprayed(building, recipe, delta)
		return
	var power_efficiency := clampf(float(building.get("power_efficiency", 1.0)), 0.0, 1.0)
	if power_efficiency <= 0.0:
		building["status"] = "no_power"
		return
	if not _has_required_inputs(building, recipe) or not _has_output_space(building, recipe):
		building["status"] = "blocked"
		return

	var progress := float(building.get("progress", 0.0))
	var planet_speed := SourceGalaxySystem.new(game_state).production_multiplier(String(building.planet_id), building_type) if building_definition.has("source_id") else 1.0
	progress += delta * maxf(float(building.get("speed", 1.0)), 0.0) * power_efficiency * game_state.get_technology_effect_multiplier("production_speed") * GameModeSystem.new(game_state).multiplier("production") * planet_speed
	var duration := maxf(float(recipe.get("duration", 0.0)), PROGRESS_EPSILON)
	building["status"] = "running"
	building["production_utilization"] = power_efficiency
	while progress + PROGRESS_EPSILON >= duration:
		if not _has_required_inputs(building, recipe) or not _has_output_space(building, recipe):
			building["status"] = "blocked"
			break
		_consume_inputs(building, recipe)
		_produce_outputs(building, recipe)
		progress = maxf(progress - duration, 0.0)
		_emit_production_completed(building, recipe)
	building["progress"] = progress

func _update_extractor(building: Dictionary, building_definition: Dictionary, delta: float) -> void:
	var extraction: Dictionary = building_definition.get("extraction", {})
	var output_item := String(building.get("output_item", extraction.get("item_id", "")))
	var output_rate := maxf(float(building.get("output_rate", extraction.get("rate_per_minute", 0.0))), 0.0) / 60.0
	if output_item.is_empty() or output_rate <= 0.0:
		building["status"] = "error"
		return
	var resource_site_id := String(building.get("resource_site_id", ""))
	if resource_site_id.is_empty():
		building["status"] = "invalid_resource_site"
		return
	var site: Variant = game_state.resource_sites.get(resource_site_id)
	if not site is Dictionary or String(site.get("planet_id", "")) != String(building.get("planet_id", "")) or String(site.get("item_id", "")) != output_item:
		building["status"] = "invalid_resource_site"
		return
	if building_definition.has("source_id"):
		_update_source_extractor(building, building_definition, site, output_item, output_rate, delta)
		return
	var consumption := game_state.get_technology_effect_multiplier("vein_consumption") if DataManager.get_item(output_item).get("kind") == "solid" else 1.0
	if not preload("res://scripts/game/SourceResourceReserveSystem.gd").is_infinite(game_state, site) and consumption > 0:
		var remaining := maxf(float(site.get("remaining", 0.0)), 0.0)
		if remaining <= PROGRESS_EPSILON:
			building["status"] = "resource_depleted"
			return
	var power_efficiency := clampf(float(building.get("power_efficiency", 1.0)), 0.0, 1.0)
	if power_efficiency <= 0.0:
		building["status"] = "no_power"
		return
	var speed := maxf(float(building.get("speed", 1.0)), 0.0)
	var output_buffer: Dictionary = building.get("output_buffer", {})
	var current_amount := float(output_buffer.get(output_item, 0.0))
	var capacity := _get_buffer_capacity(building, building_definition, "output")
	var available_space := maxf(capacity - current_amount, 0.0)
	if available_space <= PROGRESS_EPSILON:
		building["status"] = "blocked"
		return
	var extraction_effect := game_state.get_technology_effect_multiplier("mining_speed" if DataManager.get_item(output_item).get("kind") == "solid" else "resource_collection")
	if building_definition.has("source_id"): extraction_effect *= float(SourceGalaxySystem.new(game_state).profile(String(building.planet_id)).get("miningMultiplier", 1.0))
	if not building_definition.has("source_id"): extraction_effect *= game_state.get_technology_effect_multiplier("production_speed")
	var produced := minf(output_rate * delta * speed * power_efficiency * extraction_effect * GameModeSystem.new(game_state).multiplier("mining"), available_space)
	if not preload("res://scripts/game/SourceResourceReserveSystem.gd").is_infinite(game_state, site) and consumption > 0:
		produced = minf(produced, float(site.get("remaining", 0.0)) / consumption)
		site["remaining"] = maxf(float(site.get("remaining", 0.0)) - produced * consumption, 0.0)
		game_state.resource_sites[resource_site_id] = site
	var next_amount := current_amount + produced
	output_buffer[output_item] = next_amount
	building["last_production_per_minute"] = produced * 60.0 / delta if delta > 0 else 0.0
	building["output_buffer"] = output_buffer
	if statistics_system != null:
		statistics_system.record_produced(output_item, produced, String(building.get("id", "")), String(building.get("planet_id", game_state.active_planet_id)))
	building["status"] = "blocked" if current_amount >= capacity else ("resource_depleted" if consumption > 0 and not preload("res://scripts/game/SourceResourceReserveSystem.gd").is_infinite(game_state, site) and float(site.get("remaining", 0.0)) <= PROGRESS_EPSILON else "running")

func _update_source_extractor(building: Dictionary, definition: Dictionary, site: Dictionary, item: String, output_rate: float, delta: float) -> void:
	var solid: bool = DataManager.get_item(item).get("kind") == "solid"
	var level := InfiniteResearchSystem.new(game_state).level("vein_utilization")
	var tenths := maxi(0, 10 - mini(level, 10)) if solid else 10
	var finite: bool = not preload("res://scripts/game/SourceResourceReserveSystem.gd").is_infinite(game_state, site) and tenths > 0
	var reserve := maxf(0, float(site.get("remaining", 0)))
	var remainder := clampf(floorf(float(site.get("depletion_remainder", 0))), 0, 9)
	var allowance := preload("res://scripts/game/SourceResourceReserveSystem.gd").available_output(game_state, site)
	var power := clampf(float(building.get("power_efficiency", 1)), 0, 1)
	var output: Dictionary = building.get("output_buffer", {})
	var current := maxf(float(output.get(item, 0)), 0)
	var capacity := float(preload("res://scripts/game/SourceEntityCapacitySystem.gd").output_capacity(game_state, building))
	var free := floorf(maxf(0, capacity - current))
	if site.has("output_buffer"):
		var shared_capacity := float(preload("res://scripts/game/SourceEntityCapacitySystem.gd").site_output_capacity(game_state, String(site.id)))
		var shared_current := preload("res://scripts/game/SourceResourceOutputSystem.gd").raw_amount(game_state, site)
		free = minf(free, floorf(maxf(0, shared_capacity - shared_current)))
	if free < 1 or power <= SOURCE_EPSILON or allowance < 1:
		building.progress = 0.0
		building.status = "blocked" if free < 1 else ("no_power" if power <= SOURCE_EPSILON else "resource_depleted")
		return
	var count := maxf(1, floorf(float(building.get("machine_count", 1))))
	var speed := maxf(float(building.get("speed", definition.get("speed", 1))), 0)
	var effect := game_state.get_technology_effect_multiplier("mining_speed" if solid else "resource_collection")
	effect *= float(SourceGalaxySystem.new(game_state).profile(String(building.planet_id)).get("miningMultiplier", 1))
	var rate := output_rate * speed * effect * count * power * GameModeSystem.new(game_state).multiplier("mining")
	var progress := _source_round(float(building.get("progress", 0)) + output_rate * speed * effect * count * delta * power * GameModeSystem.new(game_state).multiplier("mining"))
	var produced := minf(minf(free, allowance), floorf(progress + SOURCE_EPSILON))
	output[item] = current + produced
	building.output_buffer = output
	if finite and produced > 0:
		var accrued := remainder + produced * tenths
		var depleted := minf(floorf(reserve), floorf(accrued / 10))
		site.remaining = reserve - depleted
		site.depletion_remainder = accrued - depleted * 10
	building.progress = 0.0 if produced >= free else _source_round(progress - produced)
	building.production_utilization = power
	building.last_production_per_minute = _source_round(rate * 60, 2)
	building.status = "running"
	if statistics_system != null and produced > 0:
		statistics_system.record_produced(item, produced, String(building.id), String(building.planet_id))

# Compare the fractional part before adding one: value + 0.5 can round up
# across an IEEE-754 boundary that JavaScript Math.round leaves below the tie.
static func _source_round(value: float, digits: int = 4) -> float:
	var scale := pow(10.0, digits)
	var scaled := value * scale
	var lower := floorf(scaled)
	return (lower + 1.0 if scaled - lower >= 0.5 else lower) / scale

func _has_required_inputs(building: Dictionary, recipe: Dictionary) -> bool:
	var input_buffer: Dictionary = building.get("input_buffer", {})
	for input_value in recipe.get("inputs", []):
		var item_id := String(input_value.get("item_id", ""))
		var required := float(input_value.get("amount", 0.0))
		if float(input_buffer.get(item_id, 0.0)) + PROGRESS_EPSILON < required:
			return false
	return true

func _has_output_space(building: Dictionary, recipe: Dictionary) -> bool:
	if building.get("type") == "dsp_ray_receiver" and recipe.get("source_id") == "critical_photon": return DysonSphereSystem.source_photon_has_space(building)
	var output_buffer: Dictionary = building.get("output_buffer", {})
	var building_definition := DataManager.get_building(String(building.get("type", "")))
	var capacity := _get_buffer_capacity(building, building_definition, "output")
	for output_value in recipe.get("outputs", []):
		var item_id := String(output_value.get("item_id", ""))
		var amount := float(output_value.get("amount", 0.0))
		if float(output_buffer.get(item_id, 0.0)) + amount > capacity + PROGRESS_EPSILON:
			return false
	return true

func _consume_inputs(building: Dictionary, recipe: Dictionary) -> void:
	var input_buffer: Dictionary = building.get("input_buffer", {})
	for input_value in recipe.get("inputs", []):
		var item_id := String(input_value.get("item_id", ""))
		var amount := float(input_value.get("amount", 0.0))
		input_buffer[item_id] = maxf(float(input_buffer.get(item_id, 0.0)) - amount, 0.0)
		if statistics_system != null:
			statistics_system.record_consumed(item_id, amount, String(building.get("id", "")), String(building.get("planet_id", game_state.active_planet_id)))
	building["input_buffer"] = input_buffer

func _produce_outputs(building: Dictionary, recipe: Dictionary) -> void:
	var output_buffer: Dictionary = building.get("output_buffer", {})
	for output_value in recipe.get("outputs", []):
		var item_id := String(output_value.get("item_id", ""))
		var amount := float(output_value.get("amount", 0.0))
		output_buffer[item_id] = float(output_buffer.get(item_id, 0.0)) + amount
		if building.get("type") == "dsp_ray_receiver" and recipe.get("source_id") == "critical_photon": output_buffer[item_id] = PowerGridSystem.normalize_source_cell_output(float(output_buffer[item_id]))
		if statistics_system != null:
			statistics_system.record_produced(item_id, amount, String(building.get("id", "")), String(building.get("planet_id", game_state.active_planet_id)))
	building["output_buffer"] = output_buffer

func _emit_production_completed(building: Dictionary, recipe: Dictionary) -> void:
	var outputs: Array = recipe.get("outputs", [])
	for output_value in outputs:
		var output: Dictionary = output_value
		EventBus.production_completed.emit(String(building.get("id", "")), String(output.get("item_id", "")), int(output.get("amount", 0)))

func _get_buffer_capacity(building: Dictionary, building_definition: Dictionary, direction: String) -> float:
	var key := "%s_buffer_capacity" % direction
	return maxf(float(building.get(key, building_definition.get(key, DEFAULT_BUFFER_CAPACITY))), 0.0)

func _update_sprayed(building: Dictionary, recipe: Dictionary, delta: float) -> void:
	var remaining := delta
	var efficiency := float(building.get("power_efficiency", 0))
	if efficiency <= 0:
		building.status = "no_power"
		return
	while remaining > PROGRESS_EPSILON:
		var effect := ProliferatorSystem.profile(building, recipe)
		var outputs := ProliferatorSystem.outputs(building, recipe, effect)
		var capacity := _get_buffer_capacity(building, DataManager.get_building(building.type), "output")
		if not _has_required_inputs(building, recipe):
			building.status = "blocked"
			return
		for item in outputs:
			if float(building.get("output_buffer", {}).get(item, 0)) + outputs[item] > capacity:
				building.status = "blocked"
				return
		var rate := float(building.get("speed", 1)) * efficiency * float(effect.speed) * game_state.get_technology_effect_multiplier("production_speed") * GameModeSystem.new(game_state).multiplier("production") * SourceGalaxySystem.new(game_state).production_multiplier(String(building.planet_id), String(building.type))
		if rate <= 0: return
		var progress := float(building.get("progress", 0))
		var seconds := maxf(float(recipe.duration) - progress, 0) / rate
		var applied := minf(remaining, seconds)
		building.progress = progress + applied * rate
		building.production_utilization = efficiency * (delta - remaining + applied) / delta if delta > 0 else 0.0
		remaining -= applied
		building.status = "running"
		if building.progress + PROGRESS_EPSILON < float(recipe.duration): return
		_consume_inputs(building, recipe)
		ProliferatorSystem.consume(building, recipe, effect, statistics_system)
		for item in outputs:
			building.output_buffer[item] = float(building.output_buffer.get(item, 0)) + outputs[item]
			if statistics_system != null: statistics_system.record_produced(item, outputs[item], building.id, building.planet_id)
		building.progress = 0.0
		_emit_production_completed(building, recipe)

func _update_photon_receiver(building: Dictionary, delta: float) -> void:
	var recipe := DataManager.get_recipe("dsp_critical_photon")
	if not _has_output_space(building, recipe):
		building.status = "blocked"
		return
	var received := float(_dyson_receipts.get(building.id, 0.0))
	var capacity := DysonSphereSystem.new(game_state).receiver_capacity("dsp_ray_receiver")
	if received <= 0 or capacity <= 0:
		building.status = "no_power"
		return
	var rate := received / capacity * maxf(float(building.get("speed", 1.0)), 0.0) * SourceTechnologyEffects.multiplier(game_state, "production_speed") * GameModeSystem.new(game_state).multiplier("production") * SourceGalaxySystem.new(game_state).production_multiplier(String(building.planet_id), String(building.type))
	building.power_output = floorf(received * 100.0 + 0.5) / 100.0
	building.production_utilization = clampf(received / capacity, 0, 1)
	building.last_production_per_minute = 60.0 / float(recipe.duration) * rate
	building.progress = float(building.get("progress", 0.0)) + delta * rate
	while float(building.progress) + PROGRESS_EPSILON >= float(recipe.duration) and _has_output_space(building, recipe):
		_produce_outputs(building, recipe)
		building.progress = maxf(0.0, float(building.progress) - float(recipe.duration))
		_emit_production_completed(building, recipe)
	building.status = "running" if _has_output_space(building, recipe) else "blocked"
