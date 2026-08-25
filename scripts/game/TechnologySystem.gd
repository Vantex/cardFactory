class_name TechnologySystem
extends RefCounted

var game_state: GameState
var technologies: Dictionary = {}
var current_research := ""
var research_progress := 0.0
var research_queue: Array = []
var tech_effects: Dictionary = {}

func _init(state: GameState) -> void:
	game_state = state
	technologies = DataManager.get_all_technologies()
	print("Loaded ", technologies.size(), " technologies from catalog")

func get_technology(tech_id: String) -> Dictionary:
	return technologies.get(tech_id, {})

func get_all_technologies() -> Dictionary:
	return technologies.duplicate(true)

func is_technology_completed(tech_id: String) -> bool:
	return game_state.completed_technologies.has(tech_id)

func can_research_technology(tech_id: String) -> bool:
	if is_technology_completed(tech_id):
		return false
	var technology := get_technology(tech_id)
	if technology.is_empty():
		return false
	for prerequisite_value in technology.get("prerequisites", []):
		if not is_technology_completed(String(prerequisite_value)):
			return false
	return true

func start_research(tech_id: String) -> bool:
	if not can_research_technology(tech_id):
		return false
	current_research = tech_id
	research_progress = 0.0
	EventBus.technology_research_started.emit(tech_id)
	return true

func update_research(delta: float) -> void:
	if current_research.is_empty():
		return
	var technology := get_technology(current_research)
	if technology.is_empty():
		cancel_research()
		return
	research_progress += maxf(delta, 0.0)
	if research_progress >= float(technology.get("duration", 0.0)):
		_complete_research()

func _complete_research() -> void:
	if current_research.is_empty():
		return
	var completed_id := current_research
	var technology := get_technology(completed_id)
	if technology.is_empty():
		return
	if not game_state.completed_technologies.has(completed_id):
		game_state.completed_technologies.append(completed_id)
	EventBus.technology_research_completed.emit(completed_id)
	for unlock_value in technology.get("unlocks", []):
		var unlock_id := String(unlock_value.get("id", "")) if unlock_value is Dictionary else String(unlock_value)
		if not unlock_id.is_empty():
			EventBus.technology_unlocked.emit(unlock_id)
	_apply_tech_effects(completed_id)
	current_research = ""
	research_progress = 0.0
	if not research_queue.is_empty():
		start_research(String(research_queue.pop_front()))

func _apply_tech_effects(tech_id: String) -> void:
	var effects: Dictionary = get_technology(tech_id).get("effects", {})
	for effect_key in effects:
		tech_effects[effect_key] = effects[effect_key]

func add_to_queue(tech_id: String) -> bool:
	if not can_research_technology(tech_id) or research_queue.has(tech_id):
		return false
	research_queue.append(tech_id)
	return true

func remove_from_queue(tech_id: String) -> void:
	research_queue.erase(tech_id)

func get_research_progress() -> Dictionary:
	if current_research.is_empty():
		return {"tech_id": "", "progress": 0.0, "duration": 0.0}
	return {"tech_id": current_research, "progress": research_progress, "duration": get_technology_duration(current_research)}

func get_tech_effect(effect_key: String) -> float:
	return float(tech_effects.get(effect_key, 1.0))

func get_completed_technologies() -> Array:
	return game_state.completed_technologies.duplicate()

func get_available_technologies() -> Array:
	var available: Array = []
	var technology_ids := technologies.keys()
	technology_ids.sort()
	for tech_id_value in technology_ids:
		var tech_id := String(tech_id_value)
		if can_research_technology(tech_id):
			available.append(tech_id)
	return available

func get_technology_cost(tech_id: String) -> Dictionary:
	return get_technology(tech_id).get("cost", {}).duplicate(true)

func get_technology_duration(tech_id: String) -> float:
	return float(get_technology(tech_id).get("duration", 0.0))

func get_technology_unlocks(tech_id: String) -> Array:
	return get_technology(tech_id).get("unlocks", []).duplicate(true)

func get_technology_prerequisites(tech_id: String) -> Array:
	return get_technology(tech_id).get("prerequisites", []).duplicate()

func has_prerequisites(tech_id: String) -> bool:
	return not get_technology_prerequisites(tech_id).is_empty()

func get_technology_description(tech_id: String) -> String:
	return String(get_technology(tech_id).get("description", ""))

func get_technology_name(tech_id: String) -> String:
	return String(get_technology(tech_id).get("name", ""))

func is_in_queue(tech_id: String) -> bool:
	return research_queue.has(tech_id)

func get_queue_length() -> int:
	return research_queue.size()

func clear_queue() -> void:
	research_queue.clear()

func get_current_research() -> String:
	return current_research

func is_researching() -> bool:
	return not current_research.is_empty()

func cancel_research() -> bool:
	if current_research.is_empty():
		return false
	current_research = ""
	research_progress = 0.0
	return true

func get_research_progress_percent() -> float:
	var duration := get_technology_duration(current_research)
	return 0.0 if current_research.is_empty() or duration <= 0.0 else research_progress / duration

func get_tech_tree() -> Dictionary:
	var tree: Dictionary = {}
	for tech_id_value in technologies:
		var tech_id := String(tech_id_value)
		tree[tech_id] = {"prerequisites": get_technology_prerequisites(tech_id), "unlocks": get_technology_unlocks(tech_id)}
	return tree

func reset() -> void:
	current_research = ""
	research_progress = 0.0
	research_queue.clear()
	tech_effects.clear()
	game_state.completed_technologies.clear()
