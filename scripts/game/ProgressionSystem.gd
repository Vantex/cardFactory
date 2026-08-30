class_name ProgressionSystem
extends RefCounted

var game_state: GameState
var objective_system: ObjectiveSystem
var catalog: Dictionary
var _objective_by_id: Dictionary = {}

func _init(state: GameState, custom_catalog: Dictionary = {}) -> void:
	game_state = state
	objective_system = ObjectiveSystem.new(custom_catalog)
	catalog = objective_system.catalog
	for objective_value in catalog.get("objectives", []):
		if objective_value is Dictionary:
			_objective_by_id[String(objective_value.get("id", ""))] = objective_value
	_ensure_state_arrays()

func evaluate() -> Dictionary:
	_ensure_state_arrays()
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
			if objective_id.is_empty() or game_state.completed_objective_ids.has(objective_id) or not _prerequisites_complete(objective):
				continue
			if not objective_system.is_complete(game_state, objective):
				continue
			var reward_id := "objective:%s" % objective_id
			if not _apply_reward_once(reward_id, objective.get("reward", {})):
				if not blocked_reward_ids.has(reward_id):
					blocked_reward_ids.append(reward_id)
				continue
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
		if not objective_system.is_complete(game_state, achievement):
			continue
		var reward_id := "achievement:%s" % achievement_id
		if not _apply_reward_once(reward_id, achievement.get("reward", {})):
			if not blocked_reward_ids.has(reward_id):
				blocked_reward_ids.append(reward_id)
			continue
		game_state.completed_achievement_ids.append(achievement_id)
		completed_achievements.append(achievement_id)

	return {
		"completed_objectives": completed_objectives,
		"completed_achievements": completed_achievements,
		"blocked_reward_ids": blocked_reward_ids,
	}

func get_current_objective() -> Dictionary:
	for chapter_value in catalog.get("chapters", []):
		if not chapter_value is Dictionary:
			continue
		for objective_id_value in chapter_value.get("objective_ids", []):
			var objective_id := String(objective_id_value)
			var objective: Dictionary = _objective_by_id.get(objective_id, {})
			if not objective.is_empty() and not game_state.completed_objective_ids.has(objective_id) and _prerequisites_complete(objective):
				return objective.duplicate(true)
	return {}

func get_objective_progress(objective_id: String) -> Dictionary:
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

func _apply_reward_once(reward_id: String, reward_value: Variant) -> bool:
	if game_state.claimed_progression_reward_ids.has(reward_id):
		return true
	var reward: Dictionary = reward_value if reward_value is Dictionary else {}
	var planet_items: Dictionary = reward.get("planet_inventory", {})
	var construction_items: Dictionary = reward.get("construction_inventory", {})
	var inventory := InventorySystem.new(game_state)
	if not planet_items.is_empty() and not inventory.can_add_batch(planet_items):
		return false
	for item_key in construction_items:
		var amount := float(construction_items[item_key])
		if amount <= 0.0 or float(game_state.construction_inventory.get(item_key, 0.0)) + amount > 99.0:
			return false

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
