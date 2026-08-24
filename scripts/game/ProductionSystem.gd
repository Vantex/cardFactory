class_name ProductionSystem
extends RefCounted

const PROGRESS_EPSILON := 0.0000001
const MAX_BUFFER_AMOUNT := 60.0

var game_state: GameState

func _init(state: GameState) -> void:
	game_state = state

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
		elif building_type == "power_generator" or building_type == "antimatter_generator":
			building["status"] = "no_fuel"
		else:
			building["status"] = "idle"
		return
	if building_type == "miner":
		_update_miner(building, delta)
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
	progress += delta * maxf(float(building.get("speed", 1.0)), 0.0) * power_efficiency
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

func _update_miner(building: Dictionary, delta: float) -> void:
	var power_efficiency := clampf(float(building.get("power_efficiency", 1.0)), 0.0, 1.0)
	if power_efficiency <= 0.0:
		building["status"] = "no_power"
		return
	var output_item := String(building.get("output_item", "iron_ore"))
	var output_rate := maxf(float(building.get("output_rate", 10.0)), 0.0) / 60.0
	var speed := maxf(float(building.get("speed", 1.0)), 0.0)
	var output_buffer: Dictionary = building.get("output_buffer", {})
	var current_amount := float(output_buffer.get(output_item, 0.0))
	output_buffer[output_item] = minf(current_amount + output_rate * delta * speed * power_efficiency, MAX_BUFFER_AMOUNT)
	building["output_buffer"] = output_buffer
	building["status"] = "running"

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
	for output_value in recipe.get("outputs", []):
		var item_id := String(output_value.get("item_id", ""))
		var amount := float(output_value.get("amount", 0.0))
		if float(output_buffer.get(item_id, 0.0)) + amount > MAX_BUFFER_AMOUNT + PROGRESS_EPSILON:
			return false
	return true

func _consume_inputs(building: Dictionary, recipe: Dictionary) -> void:
	var input_buffer: Dictionary = building.get("input_buffer", {})
	for input_value in recipe.get("inputs", []):
		var item_id := String(input_value.get("item_id", ""))
		input_buffer[item_id] = maxf(float(input_buffer.get(item_id, 0.0)) - float(input_value.get("amount", 0.0)), 0.0)
	building["input_buffer"] = input_buffer

func _produce_outputs(building: Dictionary, recipe: Dictionary) -> void:
	var output_buffer: Dictionary = building.get("output_buffer", {})
	for output_value in recipe.get("outputs", []):
		var item_id := String(output_value.get("item_id", ""))
		output_buffer[item_id] = float(output_buffer.get(item_id, 0.0)) + float(output_value.get("amount", 0.0))
	building["output_buffer"] = output_buffer

func _emit_production_completed(building: Dictionary, recipe: Dictionary) -> void:
	var outputs: Array = recipe.get("outputs", [])
	if outputs.is_empty():
		return
	var first_output: Dictionary = outputs[0]
	EventBus.production_completed.emit(String(building.get("id", "")), String(first_output.get("item_id", "")), int(first_output.get("amount", 0)))
