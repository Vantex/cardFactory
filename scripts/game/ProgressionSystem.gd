class_name ProgressionSystem
extends RefCounted

var game_state: GameState
var objective_system: ObjectiveSystem
var catalog: Dictionary
var _objective_by_id: Dictionary = {}
var _custom_catalog := false
var _source_catalog_mode := false

func _init(state: GameState, custom_catalog: Dictionary = {}) -> void:
	game_state = state
	_custom_catalog = not custom_catalog.is_empty()
	_source_catalog_mode = uses_source_campaign(state)
	objective_system = ObjectiveSystem.new(custom_catalog)
	catalog = objective_system.catalog
	if custom_catalog.is_empty() and uses_source_campaign(state):
		for field in ["chapters", "objectives", "achievements"]:
			catalog[field] = catalog[field].filter(func(row): return row.has("source_id"))
	for objective_value in catalog.get("objectives", []):
		if objective_value is Dictionary:
			_objective_by_id[String(objective_value.get("id", ""))] = objective_value
	_ensure_state_arrays()

func _refresh_catalog() -> void:
	var source_mode := uses_source_campaign(game_state)
	if _custom_catalog or source_mode == _source_catalog_mode: return
	_source_catalog_mode = source_mode
	objective_system = ObjectiveSystem.new()
	catalog = objective_system.catalog
	if source_mode:
		for field in ["chapters", "objectives", "achievements"]:
			catalog[field] = catalog[field].filter(func(row): return row.has("source_id"))
	_objective_by_id.clear()
	for row in catalog.objectives: _objective_by_id[String(row.id)] = row

func evaluate() -> Dictionary:
	_refresh_catalog()
	_ensure_state_arrays()
	# Rewards do not mutate buildings; this snapshot lasts only for this evaluation.
	var facts := {}
	var completed_objectives: Array[String] = []
	var completed_achievements: Array[String] = []
	var blocked_reward_ids: Array[String] = []
	var changed := true
	while changed:
		changed = false
		for objective_value in catalog.get("objectives", []):
			if not objective_value is Dictionary:
				continue
			var objective: Dictionary = objective_value
			var objective_id := String(objective.get("id", ""))
			if objective.has("source_id") and game_state.completed_objective_ids.has(objective_id):
				if not _apply_reward_once("objective:" + objective_id, objective.get("reward", {}), true):
					if not blocked_reward_ids.has("objective:" + objective_id): blocked_reward_ids.append("objective:" + objective_id)
				continue
			if objective_id.is_empty() or game_state.completed_objective_ids.has(objective_id) or not _prerequisites_complete(objective):
				continue
			if not objective_system.is_complete(game_state, objective, facts):
				continue
			var reward_id := "objective:%s" % objective_id
			if not _apply_reward_once(reward_id, objective.get("reward", {}), objective.has("source_id")):
				if not blocked_reward_ids.has(reward_id):
					blocked_reward_ids.append(reward_id)
				if not objective.has("source_id"): continue
			game_state.completed_objective_ids.append(objective_id)
			completed_objectives.append(objective_id)
			changed = true

	for achievement_value in catalog.get("achievements", []):
		if not achievement_value is Dictionary:
			continue
		var achievement: Dictionary = achievement_value
		var achievement_id := String(achievement.get("id", ""))
		if achievement_id.is_empty() or game_state.completed_achievement_ids.has(achievement_id):
			continue
		if not objective_system.is_complete(game_state, achievement, facts):
			continue
		var reward_id := "achievement:%s" % achievement_id
		if not _apply_reward_once(reward_id, achievement.get("reward", {})):
			if not blocked_reward_ids.has(reward_id):
				blocked_reward_ids.append(reward_id)
			continue
		game_state.completed_achievement_ids.append(achievement_id)
		completed_achievements.append(achievement_id)

	_repair_source_selection()
	return {
		"completed_objectives": completed_objectives,
		"completed_achievements": completed_achievements,
		"blocked_reward_ids": blocked_reward_ids,
	}

func _pending_source_objective() -> Dictionary:
	var selected: Dictionary = _objective_by_id.get(game_state.selected_source_objective, {})
	if selected.has("source_id") and not game_state.completed_objective_ids.has(selected.id) and _prerequisites_complete(selected): return selected
	var pending: Array = catalog.objectives.filter(func(row): return row.has("source_id") and not game_state.completed_objective_ids.has(row.id))
	for track in ["main", "side"]:
		for row in pending:
			if row.get("track") == track and _prerequisites_complete(row): return row
	return pending[0] if not pending.is_empty() else {}

func _repair_source_selection() -> void:
	if not _owns_source_campaign(): return
	game_state.progression_facts["source_campaign_enabled"] = true
	var pending := _pending_source_objective()
	game_state.selected_source_objective = String(pending.get("id", ""))

func source_boundary_due() -> bool:
	_refresh_catalog()
	if not _owns_source_campaign(): return false
	var facts := {}
	for row in catalog.objectives:
		if not row.has("source_id"): continue
		if game_state.completed_objective_ids.has(row.id):
			if not game_state.claimed_progression_reward_ids.has("objective:" + row.id) and _can_apply_reward(row.get("reward", {}), true): return true
		elif _prerequisites_complete(row) and objective_system.is_complete(game_state, row, facts): return true
	return game_state.selected_source_objective != String(_pending_source_objective().get("id", ""))

func settle_source_campaign() -> void:
	_refresh_catalog()
	if not _owns_source_campaign(): return
	var source_catalog := {}
	for field in ["chapters", "objectives", "achievements"]:
		source_catalog[field] = catalog[field].filter(func(row): return row.has("source_id"))
	source_catalog.achievements = []
	ProgressionSystem.new(game_state, source_catalog).evaluate()

static func uses_source_campaign(state: GameState) -> bool:
	return bool(state.progression_facts.get("source_campaign_enabled", state.selected_source_objective.begins_with("dsp_")))

func _owns_source_campaign() -> bool:
	return uses_source_campaign(game_state) and catalog.objectives.any(func(row): return row.has("source_id"))

func get_current_objective() -> Dictionary:
	_refresh_catalog()
	var selected: Dictionary = _objective_by_id.get(game_state.selected_source_objective, {})
	if not selected.is_empty() and not game_state.completed_objective_ids.has(game_state.selected_source_objective) and _prerequisites_complete(selected): return selected.duplicate(true)
	for chapter_value in catalog.get("chapters", []):
		if not chapter_value is Dictionary:
			continue
		for objective_id_value in chapter_value.get("objective_ids", []):
			var objective_id := String(objective_id_value)
			var objective: Dictionary = _objective_by_id.get(objective_id, {})
			if game_state.selected_source_objective.begins_with("dsp_") and not objective.has("source_id"): continue
			if not objective.is_empty() and not game_state.completed_objective_ids.has(objective_id) and _prerequisites_complete(objective):
				return objective.duplicate(true)
	return {}

func get_objective_progress(objective_id: String) -> Dictionary:
	_refresh_catalog()
	var objective: Dictionary = _objective_by_id.get(objective_id, {})
	if objective.is_empty():
		return {"current": 0.0, "required": 0.0, "complete": false}
	return objective_system.get_progress(game_state, objective)

func get_campaign_snapshot() -> Dictionary:
	var current := get_current_objective()
	return {
		"current_objective": current,
		"current_progress": objective_system.get_progress(game_state, current) if not current.is_empty() else {},
		"completed_objective_ids": game_state.completed_objective_ids.duplicate(),
		"completed_achievement_ids": game_state.completed_achievement_ids.duplicate(),
		"chapter_count": catalog.get("chapters", []).size(),
	}

func has_pending_item_fact(item_id: String) -> bool:
	_refresh_catalog()
	if item_id.is_empty():
		return false
	for objective_value in catalog.get("objectives", []):
		if not objective_value is Dictionary:
			continue
		var objective: Dictionary = objective_value
		if game_state.completed_objective_ids.has(String(objective.get("id", ""))):
			continue
		var condition: Dictionary = objective.get("condition", {})
		if String(condition.get("fact", "")) == "item_amount" and String(condition.get("item_id", "")) == item_id:
			return true
	for achievement_value in catalog.get("achievements", []):
		if not achievement_value is Dictionary:
			continue
		var achievement: Dictionary = achievement_value
		if game_state.completed_achievement_ids.has(String(achievement.get("id", ""))):
			continue
		var condition: Dictionary = achievement.get("condition", {})
		if String(condition.get("fact", "")) == "item_amount" and String(condition.get("item_id", "")) == item_id:
			return true
	return false

func _prerequisites_complete(objective: Dictionary) -> bool:
	for prerequisite_value in objective.get("prerequisites", []):
		if not game_state.completed_objective_ids.has(String(prerequisite_value)):
			return false
	return true

func _apply_reward_once(reward_id: String, reward_value: Variant, source_reward: bool = false) -> bool:
	if game_state.claimed_progression_reward_ids.has(reward_id):
		return true
	var reward: Dictionary = reward_value if reward_value is Dictionary else {}
	var planet_items: Dictionary = reward.get("planet_inventory", {})
	var construction_items: Dictionary = reward.get("construction_inventory", {})
	var inventory := InventorySystem.new(game_state)
	if not _can_apply_reward(reward, source_reward): return false
	if not planet_items.is_empty():
		inventory.try_add_batch(planet_items)
	for item_key in construction_items:
		game_state.construction_inventory[item_key] = float(game_state.construction_inventory.get(item_key, 0.0)) + float(construction_items[item_key])
	for unlock_value in reward.get("unlocks", []):
		var unlock_id := String(unlock_value)
		if not unlock_id.is_empty() and not game_state.unlocked_progression_ids.has(unlock_id):
			game_state.unlocked_progression_ids.append(unlock_id)
	game_state.claimed_progression_reward_ids.append(reward_id)
	return true

func _can_apply_reward(reward_value: Variant, source_reward: bool) -> bool:
	var reward: Dictionary = reward_value if reward_value is Dictionary else {}
	var planet_items: Dictionary = reward.get("planet_inventory", {})
	var construction_items: Dictionary = reward.get("construction_inventory", {})
	var inventory := InventorySystem.new(game_state)
	if not planet_items.is_empty() and not inventory.can_add_batch(planet_items):
		return false
	for item_key in construction_items:
		var amount := float(construction_items[item_key])
		if amount <= 0.0 or float(game_state.construction_inventory.get(item_key, 0.0)) + amount > (GameState.construction_capacity(String(item_key)) if source_reward else 99.0):
			return false

	return true

func _ensure_state_arrays() -> void:
	# These fields are authoritative GameState arrays; this guard also supports
	# states constructed by older in-memory fixtures before schema migration.
	if game_state.completed_objective_ids == null:
		game_state.completed_objective_ids = []
	if game_state.claimed_progression_reward_ids == null:
		game_state.claimed_progression_reward_ids = []
	if game_state.completed_achievement_ids == null:
		game_state.completed_achievement_ids = []
	if game_state.unlocked_progression_ids == null:
		game_state.unlocked_progression_ids = []

func select_objective(id: String) -> bool:
	_refresh_catalog()
	var objective: Dictionary = _objective_by_id.get(id, {})
	if objective.is_empty() or not objective.has("source_id") or game_state.completed_objective_ids.has(id) or not _prerequisites_complete(objective): return false
	game_state.selected_source_objective = id
	game_state.progression_facts["source_campaign_enabled"] = true
	_refresh_catalog()
	return true

func get_source_objectives() -> Array:
	_refresh_catalog()
	var result := []
	for objective in catalog.get("objectives", []):
		if not objective.has("source_id"): continue
		var row: Dictionary = objective.duplicate(true)
		row["progress"] = objective_system.get_progress(game_state, objective)
		row["status"] = "completed" if game_state.completed_objective_ids.has(objective.id) or (_prerequisites_complete(objective) and row.progress.complete) else "available" if _prerequisites_complete(objective) else "locked"
		row["requirements"] = get_source_task_requirements(objective)
		row["deficits"] = get_source_task_deficits(objective)
		result.append(row)
	return result

func get_source_task_requirements(objective: Dictionary) -> Array:
	if objective.has("requirements"): return objective.requirements.duplicate(true)
	var navigation: Dictionary = objective.get("navigation", {})
	if navigation.get("kind") == "technology":
		var costs: Dictionary = DataManager.get_technology("dsp_" + String(navigation.techId)).get("cost", {})
		return costs.keys().map(func(item): return {"itemId": item, "amount": costs[item]})
	if navigation.get("kind") == "recipe":
		for recipe in DataManager.all_recipes.values():
			if not recipe.has("source_id"): continue
			if recipe.get("outputs", []).any(func(output): return output.item_id == navigation.itemId):
				return recipe.inputs.map(func(item): return {"itemId": item.item_id, "amount": item.amount})
	return []

func get_source_task_deficits(objective: Dictionary) -> Array:
	var result := []
	for requirement in get_source_task_requirements(objective):
		var missing := maxf(0, float(requirement.amount) - SourceProgressionFacts.network_stock(game_state, String(requirement.itemId)))
		if missing > 0: result.append({"itemId": requirement.itemId, "amount": missing})
	return result
