class_name TechnologySystem
extends RefCounted

## Domain command service. Every mutable research fact is owned by GameState.
var game_state: GameState
var _settling_source_boundary := false
var _emit_events := true

func _init(state: GameState, emit_events: bool = true) -> void:
	game_state = state
	_emit_events = emit_events

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

func can_select_source_technology(tech_id: String) -> bool:
	return _source_query_target_available(tech_id) and can_research_technology(tech_id)

func can_queue_source_technology(tech_id: String) -> bool:
	return _source_query_target_available(tech_id) and _queue_prerequisites_are_scheduled(tech_id)

func _source_query_target_available(tech_id: String) -> bool:
	var technology := get_technology(tech_id)
	return technology.get("source_research_bridge", false) and not technology.get("deprecated", false) and not is_technology_completed(tech_id) and tech_id != game_state.research_current_id and not game_state.research_queue.has(tech_id)

func has_active_source_research() -> bool:
	return not game_state.research_current_id.is_empty() or (not InfiniteResearchSystem.new(game_state).active().is_empty() and is_technology_completed("dsp_universe_matrix"))

func start_research(tech_id: String) -> bool:
	if get_technology(tech_id).get("source_research_bridge", false) and not game_state.research_current_id.is_empty():
		return add_to_queue(tech_id)
	return _start_research_transaction(tech_id, false)

func add_to_queue(tech_id: String) -> bool:
	var technology := get_technology(tech_id)
	if not technology.get("source_research_bridge", false) and not InfiniteResearchSystem.new(game_state).active().is_empty(): return false
	if tech_id.is_empty() or (is_technology_completed(tech_id) and not technology.has("repeatable")) or game_state.research_queue.has(tech_id) or tech_id == game_state.research_current_id:
		return false
	if technology.is_empty() or technology.get("deprecated", false) or not _queue_prerequisites_are_scheduled(tech_id):
		return false
	game_state.research_queue.append(tech_id)
	if _emit_events: EventBus.technology_research_queue_changed.emit(game_state.research_queue.duplicate())
	if technology.get("source_research_bridge", false): settle_source_research_boundaries()
	return true

func remove_from_queue(tech_id: String) -> bool:
	if not game_state.research_queue.has(tech_id):
		return false
	var remaining_queue := game_state.research_queue.duplicate(true)
	remaining_queue.erase(tech_id)
	if get_technology(tech_id).get("source_research_bridge", false):
		remaining_queue = _valid_source_queue(remaining_queue)
	elif not _research_queue_closure_is_valid(remaining_queue, game_state.research_current_id):
		return false
	game_state.research_queue = remaining_queue
	game_state.research_queue_wait_reason = ""
	if _emit_events: EventBus.technology_research_queue_changed.emit(game_state.research_queue.duplicate())
	return true

func pause_research() -> bool:
	var infinite := InfiniteResearchSystem.new(game_state)
	if game_state.research_current_id.is_empty() and not infinite.active().is_empty():
		infinite.cancel()
		if _emit_events: EventBus.technology_research_paused.emit("")
		return true
	if game_state.research_current_id.is_empty() or game_state.research_paused:
		return false
	var paused := game_state.research_current_id
	if get_technology(paused).get("source_research_bridge", false):
		game_state.research_paused_id = paused
		game_state.research_current_id = ""
		infinite.cancel()
		_reset_source_lab_cycles()
	else:
		game_state.research_paused = true
	if _emit_events: EventBus.technology_research_paused.emit(paused)
	return true

func get_paused_research() -> String:
	return game_state.research_current_id if game_state.research_paused else game_state.research_paused_id

func can_resume_research() -> bool:
	if game_state.research_paused: return not game_state.research_current_id.is_empty()
	var paused := game_state.research_paused_id
	return not paused.is_empty() and game_state.research_current_id.is_empty() and not game_state.research_queue.has(paused) and can_research_technology(paused)

func resume_research() -> bool:
	if not game_state.research_paused:
		if not can_resume_research(): return false
		var resumed := game_state.research_paused_id
		if not _start_research_transaction(resumed, false): return false
		if _emit_events: EventBus.technology_research_resumed.emit(resumed)
		return true
	if game_state.research_current_id.is_empty() or not game_state.research_paused:
		return false
	game_state.research_paused = false
	if get_technology(game_state.research_current_id).get("source_research_bridge", false): _reset_source_lab_cycles()
	if _emit_events: EventBus.technology_research_resumed.emit(game_state.research_current_id)
	return true

func cancel_research() -> bool:
	if game_state.research_current_id.is_empty():
		var infinite := InfiniteResearchSystem.new(game_state)
		if not infinite.active().is_empty():
			infinite.cancel()
			_start_next_queued_research()
			if _emit_events: EventBus.technology_research_cancelled.emit("")
			return true
		return false
	var source_research: bool = get_technology(game_state.research_current_id).get("source_research_bridge", false)
	if source_research and settle_source_research_boundaries(): return true
	if not source_research and not _research_queue_closure_is_valid(game_state.research_queue):
		return false
	var cancelled := game_state.research_current_id
	game_state.research_current_id = ""
	game_state.research_paused = false
	if source_research:
		InfiniteResearchSystem.new(game_state).cancel()
		_reset_source_lab_cycles()
	if _emit_events: EventBus.technology_research_cancelled.emit(cancelled)
	_start_next_queued_research()
	return true

func update_research(delta: float, can_progress: bool = true) -> void:
	if game_state.research_current_id.is_empty() and game_state.research_paused_id.is_empty():
		_start_next_queued_research()
	if game_state.research_current_id.is_empty() or game_state.research_paused or not can_progress:
		return
	var tech_id := game_state.research_current_id
	if get_technology(tech_id).get("source_research_bridge", false): return
	var duration := get_technology_duration(tech_id)
	if duration <= 0.0:
		return
	game_state.research_progress[tech_id] = minf(game_state.get_technology_progress(tech_id) + maxf(delta, 0.0), duration)
	if _emit_events: EventBus.technology_research_progressed.emit(tech_id, game_state.get_technology_progress(tech_id), duration)
	if game_state.get_technology_progress(tech_id) + 0.0000001 >= duration:
		_complete_research(tech_id)

func _complete_research(tech_id: String, activate_next: bool = true) -> void:
	var technology := get_technology(tech_id)
	if game_state.completed_technologies.has(tech_id) and not technology.has("repeatable"): return
	if not game_state.completed_technologies.has(tech_id):
		game_state.completed_technologies.append(tech_id)
		game_state.completed_technologies.sort()
	_grant_source_construction_rewards(technology)
	if tech_id in ["dsp_interstellar_logistics", "interstellar_logistics"] and not game_state.source_galaxy.is_empty():
		for planet in ["ashen", "giant"]:
			if game_state.colonized_planet_ids.has(planet): continue
			game_state.colonized_planet_ids.append(planet)
			game_state.planet_inventories[planet] = {}
			game_state.planet_viewports[planet] = {"position": Vector2.ZERO, "zoom": Vector2.ONE}
			game_state.planet_metrics[planet] = {}
		PlanetSystem.new(game_state).initialize_colonized_resource_sites()
	if not technology.get("source_research_bridge", false):
		game_state.research_progress.erase(tech_id)
		game_state.research_invested_costs.erase(tech_id)
	if technology.has("repeatable"):
		game_state.technology_levels[tech_id] = game_state.get_technology_level(tech_id) + 1
	game_state.research_current_id = ""
	game_state.research_paused = false
	if _emit_events: EventBus.technology_research_completed.emit(tech_id)
	for unlock_value in get_technology_unlocks(tech_id):
		if _emit_events and unlock_value is Dictionary:
			EventBus.technology_unlocked.emit(String(unlock_value.get("id", "")))
	if activate_next: _start_next_queued_research()

func _grant_source_construction_rewards(technology: Dictionary) -> void:
	var source_id := String(technology.get("source_id", ""))
	if source_id.is_empty(): return
	for construction_id in DataManager.construction:
		var definition: Dictionary = DataManager.construction[construction_id]
		if definition.get("required_source_technology", "") != source_id: continue
		if DataManager.get_building(construction_id).get("source_megastructure", false): continue
		var id := String(construction_id).trim_prefix("dsp_")
		var stock_id := id if DataManager.belt_definitions().has(id) else String(construction_id)
		game_state.construction_inventory[stock_id] = floorf(float(game_state.construction_inventory.get(stock_id, 0)) + 2)
	if source_id == "universe_matrix" and float(game_state.construction_inventory.get("dsp_galactic_material_exporter", 0)) < 1:
		var placed := game_state.buildings.values().any(func(building): return building.get("type") == "dsp_galactic_material_exporter")
		if not placed: game_state.construction_inventory.dsp_galactic_material_exporter = 1.0

func _start_next_queued_research() -> void:
	if not game_state.research_current_id.is_empty() or game_state.research_queue.is_empty():
		return
	var next_id := String(game_state.research_queue[0])
	if get_technology(next_id).get("source_research_bridge", false):
		for candidate in game_state.research_queue:
			if can_research_technology(candidate):
				next_id = candidate
				break
	if _start_research_transaction(next_id, true):
		return
	game_state.research_queue_wait_reason = "等待前置或矩阵成本：%s" % next_id
	if _emit_events: EventBus.technology_research_queue_changed.emit(game_state.research_queue.duplicate(true))

func _start_research_transaction(tech_id: String, from_queue: bool) -> bool:
	var source_research: bool = get_technology(tech_id).get("source_research_bridge", false)
	if not game_state.research_current_id.is_empty() or (not source_research and not InfiniteResearchSystem.new(game_state).active().is_empty()):
		return false
	if from_queue:
		if not game_state.research_queue.has(tech_id) or (not source_research and String(game_state.research_queue[0]) != tech_id):
			return false
	elif game_state.research_queue.has(tech_id) or (not source_research and not game_state.research_queue.is_empty()):
		return false
	if not can_research_technology(tech_id):
		return false
	if source_research:
		if not game_state.research_invested_costs.has(tech_id): game_state.research_invested_costs[tech_id] = {}
	elif not _has_paid_cost(tech_id):
		_consume_cost(tech_id)
	if from_queue:
		game_state.research_queue.erase(tech_id)
	game_state.research_current_id = tech_id
	game_state.research_queue_wait_reason = ""
	game_state.research_paused = false
	if source_research:
		if not from_queue and game_state.research_paused_id == tech_id: game_state.research_paused_id = ""
		_reset_source_lab_cycles()
	if from_queue:
		if _emit_events: EventBus.technology_research_queue_changed.emit(game_state.research_queue.duplicate(true))
	if _emit_events: EventBus.technology_research_started.emit(tech_id)
	if source_research: settle_source_research_boundaries()
	if get_technology(tech_id).get("source_content_pack", "") != "" and get_technology_cost(tech_id).is_empty(): _complete_research(tech_id)
	return true

func settle_completed_source_research() -> GameState:
	if not _raw_source_boundary_due(false): return game_state
	var copied := GameState.new()
	copied.copy_from(game_state)
	TechnologySystem.new(copied, false).settle_completed_source_research_in_place()
	return copied

func settle_completed_source_research_in_place() -> Array[String]:
	var completed: Array[String] = []
	var limit := game_state.research_queue.size() + 8
	for _index in range(limit):
		var id := game_state.research_current_id
		if id.is_empty(): break
		var technology := get_technology(id)
		if technology.is_empty() or game_state.completed_technologies.has(id):
			_activate_source_boundary_queue()
			continue
		if not technology.get("source_research_bridge", false) or not _raw_source_boundary_due(true): break
		var paid: Dictionary = game_state.research_invested_costs.get(id, {}).duplicate(true)
		for item in get_technology_cost(id): paid[item] = get_technology_cost(id)[item]
		game_state.research_invested_costs[id] = paid
		var spent := 0.0
		for amount in paid.values(): spent += float(amount)
		game_state.research_progress[id] = spent * float(DataManager.get_recipe("dsp_matrix_research").duration)
		_complete_research(id, false)
		completed.append(id)
		_activate_source_boundary_queue()
		_reset_source_lab_cycles()
	return completed

func _raw_source_boundary_due(require_finite: bool) -> bool:
	var id := game_state.research_current_id
	var technology := get_technology(id)
	if id.is_empty() or not technology.get("source_research_bridge", false): return false
	var paid: Variant = game_state.research_invested_costs.get(id, {})
	if not paid is Dictionary: return false
	for item in get_technology_cost(id):
		var amount: Variant = paid.get(item, 0)
		if not (amount is int or amount is float): return false
		if (require_finite and not is_finite(float(amount))) or is_nan(float(amount)) or floorf(float(amount)) < float(technology.cost[item]): return false
	return true

func _activate_source_boundary_queue() -> void:
	game_state.research_current_id = ""
	for id in game_state.research_queue:
		var technology := get_technology(id)
		if not technology.is_empty() and technology.get("source_research_bridge", false) and technology.get("prerequisites", []).all(func(parent): return is_technology_completed(String(parent))):
			game_state.research_current_id = id
			game_state.research_queue.erase(id)
			if not game_state.research_invested_costs.has(id): game_state.research_invested_costs[id] = {}
			if not game_state.research_progress.has(id): game_state.research_progress[id] = 0.0
			break

func source_boundary_due() -> bool:
	var id := game_state.research_current_id
	var technology := get_technology(id)
	if id.is_empty() or game_state.completed_technologies.has(id) or not technology.get("source_research_bridge", false): return false
	var value: Variant = game_state.research_invested_costs.get(id, {})
	if not value is Dictionary: return false
	var paid: Dictionary = value
	for item in paid:
		var amount: Variant = paid[item]
		if not technology.cost.has(item) or not (amount is int or amount is float) or not is_finite(float(amount)) or float(amount) < 0 or float(amount) != floorf(float(amount)): return false
	for item in get_technology_cost(id):
		if floorf(float(paid.get(item, 0))) < float(technology.cost[item]): return false
	return true

func settle_source_research_boundaries() -> bool:
	if _settling_source_boundary: return false
	_settling_source_boundary = true
	var settled := false
	var limit := game_state.research_queue.size() + 8
	for _index in range(limit):
		var id := game_state.research_current_id
		if not source_boundary_due(): break
		game_state.research_invested_costs[id] = get_technology_cost(id)
		var spent := 0.0
		for amount in get_technology_cost(id).values(): spent += float(amount)
		game_state.research_progress[id] = spent * float(DataManager.get_recipe("dsp_matrix_research").duration)
		_reset_source_lab_cycles()
		_complete_research(id)
		settled = true
	_settling_source_boundary = false
	return settled

func _valid_source_queue(queue: Array) -> Array:
	var planned := {}
	for id in game_state.completed_technologies: planned[id] = true
	if not game_state.research_current_id.is_empty(): planned[game_state.research_current_id] = true
	if not game_state.research_paused_id.is_empty(): planned[game_state.research_paused_id] = true
	var valid := []
	for id in queue:
		var technology := get_technology(id)
		if technology.is_empty() or not technology.get("prerequisites", []).all(func(parent): return planned.has(parent)): continue
		valid.append(id)
		planned[id] = true
	return valid

func _reset_source_lab_cycles() -> void:
	for building in game_state.buildings.values():
		if building.get("recipe_id") == "dsp_matrix_research": building.progress = 0.0

func _queue_prerequisites_are_scheduled(tech_id: String) -> bool:
	var scheduled: Dictionary = {}
	if not game_state.research_current_id.is_empty():
		scheduled[game_state.research_current_id] = true
	if not game_state.research_paused_id.is_empty(): scheduled[game_state.research_paused_id] = true
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
	if not game_state.research_paused_id.is_empty(): scheduled[game_state.research_paused_id] = true
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
	settle_source_research_boundaries()
	var ids := game_state.buildings.keys()
	ids.sort()
	for id in ids:
		var lab: Dictionary = game_state.buildings[id]
		if lab.get("recipe_id") != "dsp_matrix_research": continue
		if game_state.research_current_id.is_empty() and (InfiniteResearchSystem.new(game_state).active().is_empty() or not game_state.completed_technologies.has("dsp_universe_matrix")):
			if delta > 0: lab.progress = 0.0
			continue
		if InfiniteResearchSystem.new(game_state).can_work():
			_update_infinite_lab(lab, delta, statistics)
			continue
		var remaining := maxf(delta, 0)
		while remaining > 0.0000001 and source_lab_can_work(lab):
			var efficiency := clampf(float(lab.get("power_efficiency", 0)), 0, 1)
			if float(lab.get("power_requested", 0)) <= 0 or efficiency <= 0: break
			var recipe := DataManager.get_recipe("dsp_matrix_research")
			var effect := ProliferatorSystem.profile(lab, recipe)
			var rate := maxf(float(lab.get("speed", 1)), 0) * efficiency * float(effect.speed) * game_state.get_technology_effect_multiplier("research_speed") * GameModeSystem.new(game_state).multiplier("production") * SourceGalaxySystem.new(game_state).production_multiplier(String(lab.planet_id), String(lab.type))
			if rate <= 0: break
			var duration := float(recipe.duration)
			var progress := minf(float(lab.get("progress", 0)), duration)
			var used := minf(remaining, (duration - progress) / rate)
			progress += used * rate
			remaining -= used
			lab.progress = progress
			lab.status = "running"
			lab.production_utilization = efficiency
			lab.last_production_per_minute = 60.0 / duration * rate
			if progress + 0.0000001 < duration: break
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
				if _emit_events: EventBus.technology_research_progressed.emit(tech, game_state.research_progress[tech], get_technology_duration(tech))
				break
			lab.progress = 0.0
			if remaining_source_cost().is_empty():
				_complete_research(tech)
				for other in game_state.buildings.values():
					if other.get("recipe_id") == "dsp_matrix_research": other.progress = 0.0
				break

func _update_infinite_lab(lab: Dictionary, delta: float, statistics: StatisticsSystem) -> void:
	if delta <= 0 or not source_lab_can_work(lab): return
	var efficiency := clampf(float(lab.get("power_efficiency", 0)), 0, 1)
	if float(lab.get("power_requested", 0)) <= 0 or efficiency <= 0: return
	var recipe := DataManager.get_recipe("dsp_matrix_research")
	var duration := float(recipe.duration)
	var effect := ProliferatorSystem.profile(lab, recipe)
	var rate := maxf(float(lab.get("speed", 1)), 0) * efficiency * game_state.get_technology_effect_multiplier("research_speed") * GameModeSystem.new(game_state).multiplier("production") * SourceGalaxySystem.new(game_state).production_multiplier(String(lab.planet_id), String(lab.type)) / duration
	if rate <= 0: return
	var maximum := minf(floorf(float(lab.input_buffer.get("universe_matrix", 0))), float(remaining_source_cost().get("universe_matrix", 0)))
	var phase := maxf(float(lab.get("progress", 0)) / duration, 0)
	var potential := rate * delta
	var sprayed_limit := 0.0
	if effect.active:
		var points := float(lab.get("proliferator_points", 0)) + floorf(float(lab.input_buffer.get(effect.rule.id, 0))) * float(effect.rule.spray_points)
		sprayed_limit = floorf(points / float(effect.cost))
		if lab.get("proliferator_mode") == "speed":
			var accelerated := rate * float(effect.speed)
			var capacity := maxf(0, minf(maximum, sprayed_limit) - phase)
			var accelerated_seconds := minf(delta, capacity / accelerated)
			potential = minf(capacity, accelerated * accelerated_seconds) + rate * (delta - accelerated_seconds)
	if potential <= 0.0001: return
	var work := minf(potential, maxf(0, maximum - phase))
	var rounded_phase := floorf((phase + work) * 1000000.0 + 0.5) / 1000000.0
	lab.progress = rounded_phase * duration
	lab.status = "running"
	lab.production_utilization = efficiency
	lab.last_production_per_minute = 60.0 * rate * float(effect.speed)
	var cycles := int(minf(maximum, floorf(rounded_phase + 0.0001)))
	if cycles <= 0: return
	var consumed := int(InfiniteResearchSystem.new(game_state).invest_budget(InfiniteResearchSystem.new(game_state).active(), str(cycles)))
	if consumed <= 0: return
	lab.input_buffer["universe_matrix"] -= consumed
	if statistics != null: statistics.record_consumed("universe_matrix", consumed, lab.id, lab.planet_id)
	for _cycle in range(mini(consumed, int(sprayed_limit))): ProliferatorSystem.consume(lab, recipe, effect, statistics)
	# Source infinite payments reset the whole step, including its remaining phase.
	_reset_source_lab_cycles()
