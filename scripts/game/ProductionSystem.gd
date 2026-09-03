class_name ProductionSystem
extends RefCounted

const PROGRESS_EPSILON := 0.0000001
const DEFAULT_BUFFER_CAPACITY := 60.0

var game_state: GameState
var statistics_system: StatisticsSystem

func _init(state: GameState, statistics: StatisticsSystem = null) -> void:
	game_state = state
	statistics_system = statistics

func update(delta: float) -> void:
	var building_ids: Array = game_state.buildings.keys()
	building_ids.sort()
	for building_id in building_ids:
		_update_building(game_state.buildings[building_id], delta)

func _update_building(building: Dictionary, delta: float) -> void:
	var building_type := String(building.get("type", ""))
	var building_definition := DataManager.get_building(building_type)
	if building_definition.get("kind", "") == "generator":
		if float(building.get("power_output", 0.0)) > 0.0:
			building["status"] = "running"
		elif not building_definition.get("fuel", {}).is_empty():
			building["status"] = "no_fuel"
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
	var power_efficiency := clampf(float(building.get("power_efficiency", 1.0)), 0.0, 1.0)
	if power_efficiency <= 0.0:
		building["status"] = "no_power"
		return
	if not _has_required_inputs(building, recipe) or not _has_output_space(building, recipe):
		building["status"] = "blocked"
		return

	var progress := float(building.get("progress", 0.0))
	progress += delta * maxf(float(building.get("speed", 1.0)), 0.0) * power_efficiency * game_state.get_technology_effect_multiplier("production_speed")
	var duration := maxf(float(recipe.get("duration", 0.0)), PROGRESS_EPSILON)
	building["status"] = "running"
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
	var power_efficiency := clampf(float(building.get("power_efficiency", 1.0)), 0.0, 1.0)
	if power_efficiency <= 0.0:
		building["status"] = "no_power"
		return
	var extraction: Dictionary = building_definition.get("extraction", {})
	var output_item := String(building.get("output_item", extraction.get("item_id", "")))
	var output_rate := maxf(float(building.get("output_rate", extraction.get("rate_per_minute", 0.0))), 0.0) / 60.0
	if output_item.is_empty() or output_rate <= 0.0:
		building["status"] = "error"
		return
	var speed := maxf(float(building.get("speed", 1.0)), 0.0)
	var output_buffer: Dictionary = building.get("output_buffer", {})
	var current_amount := float(output_buffer.get(output_item, 0.0))
	var capacity := _get_buffer_capacity(building, building_definition, "output")
	var available_space := maxf(capacity - current_amount, 0.0)
	if available_space <= PROGRESS_EPSILON:
		building["status"] = "blocked"
		return
	var produced := minf(output_rate * delta * speed * power_efficiency * game_state.get_technology_effect_multiplier("production_speed"), available_space)
	var resource_site_id := String(building.get("resource_site_id", ""))
	if resource_site_id.is_empty():
		building["status"] = "invalid_resource_site"
		return
	var site: Variant = game_state.resource_sites.get(resource_site_id)
	if not site is Dictionary or String(site.get("planet_id", "")) != String(building.get("planet_id", "")) or String(site.get("item_id", "")) != output_item:
		building["status"] = "invalid_resource_site"
		return
	if not bool(site.get("infinite", false)):
		var remaining := maxf(float(site.get("remaining", 0.0)), 0.0)
		if remaining <= PROGRESS_EPSILON:
			building["status"] = "resource_depleted"
			return
		produced = minf(produced, remaining)
		site["remaining"] = maxf(remaining - produced, 0.0)
		game_state.resource_sites[resource_site_id] = site
	var next_amount := current_amount + produced
	output_buffer[output_item] = next_amount
	building["output_buffer"] = output_buffer
	if statistics_system != null:
		statistics_system.record_produced(output_item, produced, String(building.get("id", "")))
	building["status"] = "blocked" if current_amount >= capacity else ("resource_depleted" if not resource_site_id.is_empty() and not bool(game_state.resource_sites.get(resource_site_id, {}).get("infinite", false)) and float(game_state.resource_sites.get(resource_site_id, {}).get("remaining", 0.0)) <= PROGRESS_EPSILON else "running")

func _has_required_inputs(building: Dictionary, recipe: Dictionary) -> bool:
	var input_buffer: Dictionary = building.get("input_buffer", {})
	for input_value in recipe.get("inputs", []):
		var item_id := String(input_value.get("item_id", ""))
		var required := float(input_value.get("amount", 0.0))
		if float(input_buffer.get(item_id, 0.0)) + PROGRESS_EPSILON < required:
			return false
	return true

func _has_output_space(building: Dictionary, recipe: Dictionary) -> bool:
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
			statistics_system.record_consumed(item_id, amount, String(building.get("id", "")))
	building["input_buffer"] = input_buffer

func _produce_outputs(building: Dictionary, recipe: Dictionary) -> void:
	var output_buffer: Dictionary = building.get("output_buffer", {})
	for output_value in recipe.get("outputs", []):
		var item_id := String(output_value.get("item_id", ""))
		var amount := float(output_value.get("amount", 0.0))
		output_buffer[item_id] = float(output_buffer.get(item_id, 0.0)) + amount
		if statistics_system != null:
			statistics_system.record_produced(item_id, amount, String(building.get("id", "")))
	building["output_buffer"] = output_buffer

func _emit_production_completed(building: Dictionary, recipe: Dictionary) -> void:
	var outputs: Array = recipe.get("outputs", [])
	for output_value in outputs:
		var output: Dictionary = output_value
		EventBus.production_completed.emit(String(building.get("id", "")), String(output.get("item_id", "")), int(output.get("amount", 0)))

func _get_buffer_capacity(building: Dictionary, building_definition: Dictionary, direction: String) -> float:
	var key := "%s_buffer_capacity" % direction
	return maxf(float(building.get(key, building_definition.get(key, DEFAULT_BUFFER_CAPACITY))), PROGRESS_EPSILON)
