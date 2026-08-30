class_name TechnologySystem
extends RefCounted

## Domain command service. Every mutable research fact is owned by GameState.
var game_state: GameState

func _init(state: GameState) -> void:
	game_state = state

func get_technology(tech_id: String) -> Dictionary:
	return DataManager.get_technology(tech_id)

func get_all_technologies() -> Dictionary:
	return DataManager.get_all_technologies()

func is_technology_completed(tech_id: String) -> bool:
	return game_state.completed_technologies.has(tech_id)

func can_research_technology(tech_id: String) -> bool:
	if is_technology_completed(tech_id) or get_technology(tech_id).is_empty():
		return false
	for prerequisite_value in get_technology_prerequisites(tech_id):
		if not is_technology_completed(String(prerequisite_value)):
			return false
	return _has_paid_cost(tech_id) or _has_cost_in_inventory(tech_id)

func start_research(tech_id: String) -> bool:
	if tech_id != game_state.research_current_id and not game_state.research_current_id.is_empty():
		return false
	if not can_research_technology(tech_id):
		return false
	if not _has_paid_cost(tech_id):
		_consume_cost(tech_id)
	game_state.research_current_id = tech_id
	game_state.research_paused = false
	EventBus.technology_research_started.emit(tech_id)
	return true

func add_to_queue(tech_id: String) -> bool:
	if tech_id.is_empty() or is_technology_completed(tech_id) or game_state.research_queue.has(tech_id) or tech_id == game_state.research_current_id:
		return false
	if get_technology(tech_id).is_empty() or not _queue_prerequisites_are_scheduled(tech_id):
		return false
	game_state.research_queue.append(tech_id)
	EventBus.technology_research_queue_changed.emit(game_state.research_queue.duplicate())
	return true

func remove_from_queue(tech_id: String) -> bool:
	if not game_state.research_queue.has(tech_id):
		return false
	game_state.research_queue.erase(tech_id)
	EventBus.technology_research_queue_changed.emit(game_state.research_queue.duplicate())
	return true

func pause_research() -> bool:
	if game_state.research_current_id.is_empty() or game_state.research_paused:
		return false
	game_state.research_paused = true
	EventBus.technology_research_paused.emit(game_state.research_current_id)
	return true

func resume_research() -> bool:
	if game_state.research_current_id.is_empty() or not game_state.research_paused:
		return false
	game_state.research_paused = false
	EventBus.technology_research_resumed.emit(game_state.research_current_id)
	return true

func cancel_research() -> bool:
	if game_state.research_current_id.is_empty():
		return false
	var cancelled := game_state.research_current_id
	game_state.research_current_id = ""
	game_state.research_paused = false
	EventBus.technology_research_cancelled.emit(cancelled)
	_start_next_queued_research()
	return true

func update_research(delta: float, can_progress: bool = true) -> void:
	if game_state.research_current_id.is_empty() or game_state.research_paused or not can_progress:
		return
	var tech_id := game_state.research_current_id
	var duration := get_technology_duration(tech_id)
	if duration <= 0.0:
		return
	game_state.research_progress[tech_id] = minf(game_state.get_technology_progress(tech_id) + maxf(delta, 0.0), duration)
	EventBus.technology_research_progressed.emit(tech_id, game_state.get_technology_progress(tech_id), duration)
	if game_state.get_technology_progress(tech_id) + 0.0000001 >= duration:
		_complete_research(tech_id)

func _complete_research(tech_id: String) -> void:
	if not game_state.completed_technologies.has(tech_id):
		game_state.completed_technologies.append(tech_id)
		game_state.completed_technologies.sort()
	game_state.research_progress.erase(tech_id)
	game_state.research_invested_costs.erase(tech_id)
	game_state.research_current_id = ""
	game_state.research_paused = false
	EventBus.technology_research_completed.emit(tech_id)
	for unlock_value in get_technology_unlocks(tech_id):
		if unlock_value is Dictionary:
			EventBus.technology_unlocked.emit(String(unlock_value.get("id", "")))
	_start_next_queued_research()

func _start_next_queued_research() -> void:
	while not game_state.research_queue.is_empty():
		var next_id := String(game_state.research_queue.pop_front())
		if start_research(next_id):
			EventBus.technology_research_queue_changed.emit(game_state.research_queue.duplicate())
			return
	EventBus.technology_research_queue_changed.emit(game_state.research_queue.duplicate())

func _queue_prerequisites_are_scheduled(tech_id: String) -> bool:
	var scheduled: Dictionary = {}
	if not game_state.research_current_id.is_empty():
		scheduled[game_state.research_current_id] = true
	for queued_id_value in game_state.research_queue:
		scheduled[String(queued_id_value)] = true
	for prerequisite_value in get_technology_prerequisites(tech_id):
		var prerequisite_id := String(prerequisite_value)
		if not is_technology_completed(prerequisite_id) and not scheduled.has(prerequisite_id):
			return false
	return true

func _has_cost_in_inventory(tech_id: String) -> bool:
	var cost := get_technology_cost(tech_id)
	for item_id_value in cost:
		var item_id := String(item_id_value)
		if float(game_state.planet_inventory.get(item_id, 0.0)) + 0.0000001 < float(cost[item_id_value]):
			return false
	return true

func _consume_cost(tech_id: String) -> void:
	var cost := get_technology_cost(tech_id)
	var paid: Dictionary = {}
	for item_id_value in cost:
		var item_id := String(item_id_value)
		var amount := float(cost[item_id_value])
		game_state.planet_inventory[item_id] = float(game_state.planet_inventory.get(item_id, 0.0)) - amount
		paid[item_id] = amount
	game_state.research_invested_costs[tech_id] = paid

func _has_paid_cost(tech_id: String) -> bool:
	return game_state.research_invested_costs.has(tech_id)

func get_current_research() -> String:
	return game_state.research_current_id

func is_researching() -> bool:
	return not game_state.research_current_id.is_empty()

func get_research_progress() -> Dictionary:
	var tech_id := game_state.research_current_id
	return {"tech_id": tech_id, "progress": game_state.get_technology_progress(tech_id), "duration": get_technology_duration(tech_id), "paused": game_state.research_paused}

func get_research_progress_percent() -> float:
	var duration := get_technology_duration(game_state.research_current_id)
	return 0.0 if duration <= 0.0 else game_state.get_technology_progress(game_state.research_current_id) / duration

func get_effect_multiplier(effect_key: String) -> float:
	return game_state.get_technology_effect_multiplier(effect_key)

func get_technology_cost(tech_id: String) -> Dictionary:
	return get_technology(tech_id).get("cost", {}).duplicate(true)

func get_technology_duration(tech_id: String) -> float:
	return float(get_technology(tech_id).get("duration", 0.0))

func get_technology_unlocks(tech_id: String) -> Array:
	return get_technology(tech_id).get("unlocks", []).duplicate(true)

func get_technology_prerequisites(tech_id: String) -> Array:
	return get_technology(tech_id).get("prerequisites", []).duplicate()

func get_technology_description(tech_id: String) -> String:
	return String(get_technology(tech_id).get("description", ""))

func get_technology_name(tech_id: String) -> String:
	return String(get_technology(tech_id).get("name", tech_id))

func get_available_technologies() -> Array:
	var result: Array = []
	var ids := get_all_technologies().keys()
	ids.sort()
	for id_value in ids:
		var tech_id := String(id_value)
		if can_research_technology(tech_id):
			result.append(tech_id)
	return result
