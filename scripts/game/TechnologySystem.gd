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
	var technology := get_technology(tech_id)
	if technology.is_empty() or technology.get("deprecated", false) or (is_technology_completed(tech_id) and not technology.has("repeatable")):
		return false
	for prerequisite_value in get_technology_prerequisites(tech_id):
		if not is_technology_completed(String(prerequisite_value)):
			return false
	return technology.get("source_research_bridge", false) or _has_paid_cost(tech_id) or _has_cost_in_inventory(tech_id)

func start_research(tech_id: String) -> bool:
	return _start_research_transaction(tech_id, false)

func add_to_queue(tech_id: String) -> bool:
	if not InfiniteResearchSystem.new(game_state).active().is_empty(): return false
	var technology := get_technology(tech_id)
	if tech_id.is_empty() or (is_technology_completed(tech_id) and not technology.has("repeatable")) or game_state.research_queue.has(tech_id) or tech_id == game_state.research_current_id:
		return false
	if technology.is_empty() or technology.get("deprecated", false) or not _queue_prerequisites_are_scheduled(tech_id):
		return false
	game_state.research_queue.append(tech_id)
	EventBus.technology_research_queue_changed.emit(game_state.research_queue.duplicate())
	return true

func remove_from_queue(tech_id: String) -> bool:
	if not game_state.research_queue.has(tech_id):
		return false
	var remaining_queue := game_state.research_queue.duplicate(true)
	remaining_queue.erase(tech_id)
	if not _research_queue_closure_is_valid(remaining_queue, game_state.research_current_id):
		return false
	game_state.research_queue = remaining_queue
	game_state.research_queue_wait_reason = ""
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
	if not _research_queue_closure_is_valid(game_state.research_queue):
		return false
	var cancelled := game_state.research_current_id
	game_state.research_current_id = ""
	game_state.research_paused = false
	EventBus.technology_research_cancelled.emit(cancelled)
	_start_next_queued_research()
	return true

func update_research(delta: float, can_progress: bool = true) -> void:
	if game_state.research_current_id.is_empty():
		_start_next_queued_research()
	if game_state.research_current_id.is_empty() or game_state.research_paused or not can_progress:
		return
	var tech_id := game_state.research_current_id
	if get_technology(tech_id).get("source_research_bridge", false): return
	var duration := get_technology_duration(tech_id)
	if duration <= 0.0:
		return
	game_state.research_progress[tech_id] = minf(game_state.get_technology_progress(tech_id) + maxf(delta, 0.0), duration)
	EventBus.technology_research_progressed.emit(tech_id, game_state.get_technology_progress(tech_id), duration)
	if game_state.get_technology_progress(tech_id) + 0.0000001 >= duration:
		_complete_research(tech_id)

func _complete_research(tech_id: String) -> void:
	var technology := get_technology(tech_id)
	if not game_state.completed_technologies.has(tech_id):
		game_state.completed_technologies.append(tech_id)
		game_state.completed_technologies.sort()
	game_state.research_progress.erase(tech_id)
	game_state.research_invested_costs.erase(tech_id)
	if technology.has("repeatable"):
		game_state.technology_levels[tech_id] = game_state.get_technology_level(tech_id) + 1
	game_state.research_current_id = ""
	game_state.research_paused = false
	EventBus.technology_research_completed.emit(tech_id)
	for unlock_value in get_technology_unlocks(tech_id):
		if unlock_value is Dictionary:
			EventBus.technology_unlocked.emit(String(unlock_value.get("id", "")))
	_start_next_queued_research()

func _start_next_queued_research() -> void:
	if not game_state.research_current_id.is_empty() or game_state.research_queue.is_empty():
		return
	var next_id := String(game_state.research_queue[0])
	if _start_research_transaction(next_id, true):
		return
	game_state.research_queue_wait_reason = "等待前置或矩阵成本：%s" % next_id
	EventBus.technology_research_queue_changed.emit(game_state.research_queue.duplicate(true))

func _start_research_transaction(tech_id: String, from_queue: bool) -> bool:
	if not game_state.research_current_id.is_empty() or not InfiniteResearchSystem.new(game_state).active().is_empty():
		return false
	if from_queue:
		if game_state.research_queue.is_empty() or String(game_state.research_queue[0]) != tech_id:
			return false
	elif not game_state.research_queue.is_empty():
		return false
	if not can_research_technology(tech_id):
		return false
	if get_technology(tech_id).get("source_research_bridge", false):
		if not game_state.research_invested_costs.has(tech_id): game_state.research_invested_costs[tech_id] = {}
	elif not _has_paid_cost(tech_id):
		_consume_cost(tech_id)
	if from_queue:
		game_state.research_queue.pop_front()
	game_state.research_current_id = tech_id
	game_state.research_queue_wait_reason = ""
	game_state.research_paused = false
	if from_queue:
		EventBus.technology_research_queue_changed.emit(game_state.research_queue.duplicate(true))
	EventBus.technology_research_started.emit(tech_id)
	return true

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

func _research_queue_closure_is_valid(queue: Array, current_id: String = "") -> bool:
	var scheduled: Dictionary = {}
	for completed_id_value in game_state.completed_technologies:
		scheduled[String(completed_id_value)] = true
	if not current_id.is_empty():
		scheduled[current_id] = true
	for queued_id_value in queue:
		var queued_id := String(queued_id_value)
		var technology := get_technology(queued_id)
		if technology.is_empty():
			return false
		for prerequisite_value in technology.get("prerequisites", []):
			if not scheduled.has(String(prerequisite_value)):
				return false
		scheduled[queued_id] = true
	return true

func _has_cost_in_inventory(tech_id: String) -> bool:
	var cost := get_technology_cost(tech_id)
	var inventory := game_state.get_active_planet_inventory()
	for item_id_value in cost:
		var item_id := String(item_id_value)
		if float(inventory.get(item_id, 0.0)) + 0.0000001 < float(cost[item_id_value]):
			return false
	return true

func _consume_cost(tech_id: String) -> void:
	var cost := get_technology_cost(tech_id)
	var paid: Dictionary = {}
	var inventory := game_state.get_active_planet_inventory()
	for item_id_value in cost:
		var item_id := String(item_id_value)
		var amount := float(cost[item_id_value])
		inventory[item_id] = float(inventory.get(item_id, 0.0)) - amount
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

func remaining_source_cost() -> Dictionary:
	var infinite := InfiniteResearchSystem.new(game_state)
	if infinite.can_work():
		return {"universe_matrix": minf(1000000, float(DecimalCount.subtract(infinite.cost(infinite.active()), infinite.invested(infinite.active()))))}
	var tech := game_state.research_current_id
	if not get_technology(tech).get("source_research_bridge", false): return {}
	var result := {}
	var invested: Dictionary = game_state.research_invested_costs.get(tech, {})
	for item in get_technology_cost(tech):
		var amount := float(get_technology_cost(tech)[item]) - float(invested.get(item, 0))
		if amount > 0: result[item] = amount
	return result

func source_lab_can_work(building: Dictionary) -> bool:
	if game_state.research_paused or building.get("recipe_id") != "dsp_matrix_research": return false
	for item in remaining_source_cost():
		if float(building.get("input_buffer", {}).get(item, 0)) >= 1: return true
	return false

func supply_source_lab(id: String) -> Dictionary:
	var building: Dictionary = game_state.buildings.get(id, {})
	if building.get("recipe_id") != "dsp_matrix_research" or building.get("interaction_locked", false): return {"ok": false, "message": "请选择未锁定的科研实验室"}
	var capacity := float(DataManager.get_building(building.type).get("input_buffer_capacity", 0))
	var available := game_state.get_planet_inventory(building.planet_id)
	var supplied := {}
	for item in remaining_source_cost():
		var buffered := float(building.input_buffer.get(item, 0))
		var amount := floorf(minf(minf(float(available.get(item, 0)), capacity - buffered), float(remaining_source_cost()[item]) - buffered))
		if amount > 0: supplied[item] = amount
	if supplied.is_empty(): return {"ok": false, "message": "没有可投放的研究材料，或实验室缓存已满"}
	var result := InventorySystem.new(game_state).try_remove_batch(supplied, building.planet_id)
	if not result.ok: return result
	for item in supplied: building.input_buffer[item] = float(building.input_buffer.get(item, 0)) + supplied[item]
	return {"ok": true, "message": "研究材料已投放，实验室将逐件研究"}

func update_source_labs(delta: float, statistics: StatisticsSystem = null) -> void:
	var ids := game_state.buildings.keys()
	ids.sort()
	for id in ids:
		var lab: Dictionary = game_state.buildings[id]
		if lab.get("recipe_id") != "dsp_matrix_research": continue
		var remaining := maxf(delta, 0)
		while remaining > 0.0000001 and source_lab_can_work(lab):
			var efficiency := clampf(float(lab.get("power_efficiency", 0)), 0, 1)
			if float(lab.get("power_requested", 0)) <= 0 or efficiency <= 0: break
			var recipe := DataManager.get_recipe("dsp_matrix_research")
			var effect := ProliferatorSystem.profile(lab, recipe)
			var rate := maxf(float(lab.get("speed", 1)), 0) * efficiency * float(effect.speed) * game_state.get_technology_effect_multiplier("research_speed")
			if rate <= 0: break
			var duration := float(recipe.duration)
			var progress := minf(float(lab.get("progress", 0)), duration)
			var used := minf(remaining, (duration - progress) / rate)
			progress += used * rate
			remaining -= used
			lab.progress = progress
			lab.status = "running"
			if progress + 0.0000001 < duration: break
			var infinite := InfiniteResearchSystem.new(game_state)
			if infinite.can_work():
				if infinite.invest_one():
					lab.input_buffer["universe_matrix"] -= 1.0
					if statistics != null: statistics.record_consumed("universe_matrix", 1, lab.id, lab.planet_id)
					ProliferatorSystem.consume(lab, recipe, effect, statistics)
				lab.progress = 0.0
				continue
			var tech := game_state.research_current_id
			var costs := remaining_source_cost()
			for item in costs:
				if float(lab.input_buffer.get(item, 0)) < 1: continue
				lab.input_buffer[item] -= 1.0
				var invested: Dictionary = game_state.research_invested_costs[tech]
				invested[item] = float(invested.get(item, 0)) + 1
				if statistics != null: statistics.record_consumed(item, 1, lab.id, lab.planet_id)
				ProliferatorSystem.consume(lab, recipe, effect, statistics)
				game_state.research_progress[tech] = game_state.get_technology_progress(tech) + duration
				EventBus.technology_research_progressed.emit(tech, game_state.research_progress[tech], get_technology_duration(tech))
				break
			lab.progress = 0.0
			if remaining_source_cost().is_empty():
				_complete_research(tech)
				for other in game_state.buildings.values():
					if other.get("recipe_id") == "dsp_matrix_research": other.progress = 0.0
				break
