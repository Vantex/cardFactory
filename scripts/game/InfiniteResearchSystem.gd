class_name InfiniteResearchSystem
extends RefCounted

static var _definitions: Dictionary = {}
var state: GameState

func _init(game_state: GameState) -> void:
	state = game_state

static func definitions() -> Dictionary:
	if _definitions.is_empty():
		var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string("res://data/infinite_research.json"))
		if parsed is Dictionary: _definitions = parsed.get("definitions", {})
	return _definitions

func level(id: String) -> int:
	return int(state.progression_facts.get("infinite_research", {}).get(id, {}).get("level", 0))

func invested(id: String) -> String:
	return String(state.progression_facts.get("infinite_research", {}).get(id, {}).get("invested", "0"))

func cost(id: String) -> String:
	var definition: Dictionary = definitions().get(id, {})
	if definition.is_empty(): return "0"
	return String(definition.costs[mini(level(id), int(definition.maximum) - 1)])

func active() -> String:
	return String(state.progression_facts.get("active_infinite", ""))

func can_work() -> bool:
	var id := active()
	return definitions().has(id) and level(id) < int(definitions()[id].maximum) and state.completed_technologies.has("dsp_universe_matrix") and not state.progression_facts.get("infinite_paused", false) and state.research_current_id.is_empty()

func select(id: String, automatic: Variant = null) -> bool:
	if not definitions().has(id) or level(id) >= int(definitions()[id].maximum) or not state.completed_technologies.has("dsp_universe_matrix") or active() == id: return false
	if not state.research_current_id.is_empty() and not DataManager.get_technology(state.research_current_id).get("source_research_bridge", false): return false
	for queued in state.research_queue:
		if not DataManager.get_technology(queued).get("source_research_bridge", false): return false
	if automatic != null and not automatic is bool: return false
	state.progression_facts["active_infinite"] = id
	state.progression_facts["infinite_paused"] = false
	if automatic != null: set_automation(automatic)
	_reset_lab_cycles()
	return true

func set_automation(enabled: bool) -> bool:
	if state.progression_facts.get("infinite_auto", false) == enabled: return false
	state.progression_facts["infinite_auto"] = enabled
	return true

func pause(paused: bool) -> bool:
	if active().is_empty(): return false
	state.progression_facts["infinite_paused"] = paused
	return true

func cancel() -> void:
	state.progression_facts.erase("active_infinite")
	state.progression_facts.erase("infinite_paused")
	_reset_lab_cycles()

func invest_one() -> bool:
	if not can_work(): return false
	return invest_budget(active(), "1") == "1"

func invest_budget(id: String, requested: String) -> String:
	if not definitions().has(id): return "0"
	var budget := requested
	if requested.begins_with("-") and DecimalCount.valid(requested.substr(1)): budget = "0"
	if not DecimalCount.valid(budget) or not DecimalCount.valid(invested(id)): return "0"
	var maximum := int(definitions()[id].maximum)
	var current_level := clampi(level(id), 0, maximum)
	var progress := invested(id)
	var remaining := budget
	var completed: Array[int] = []
	var automatic: bool = state.progression_facts.get("infinite_auto", false)
	while current_level < maximum:
		var required := String(definitions()[id].costs[current_level])
		if DecimalCount.compare(progress, required) > 0: progress = required
		if progress == required:
			current_level += 1
			progress = "0"
			completed.append(current_level)
			if not automatic: break
			continue
		if remaining == "0": break
		var needed := DecimalCount.subtract(required, progress)
		var taken := remaining if DecimalCount.compare(remaining, needed) < 0 else needed
		progress = DecimalCount.add(progress, taken)
		remaining = DecimalCount.subtract(remaining, taken)
	if not state.progression_facts.has("infinite_research"): state.progression_facts["infinite_research"] = {}
	state.progression_facts.infinite_research[id] = {"level": current_level, "invested": progress}
	var exports := GalacticExportSystem.new(state)
	for completed_level in completed: exports.award_research_completion(completed_level)
	if current_level >= maximum or (not completed.is_empty() and not automatic):
		state.progression_facts.erase("active_infinite")
		state.progression_facts.erase("infinite_paused")
	return DecimalCount.subtract(budget, remaining)

func _reset_lab_cycles() -> void:
	for building in state.buildings.values():
		if building.get("recipe_id") == "dsp_matrix_research": building.progress = 0.0

static func validate(facts: Dictionary) -> Array:
	var errors := []
	var progress: Variant = facts.get("infinite_research", {})
	if not progress is Dictionary: return ["无限研究记录必须是字典"]
	for id in progress:
		if not definitions().has(id) or not progress[id] is Dictionary:
			errors.append("未知无限研究记录")
			continue
		var row: Dictionary = progress[id]
		var current: Variant = row.get("level")
		if not (current is int or current is float) or not is_finite(float(current)) or float(current) != floorf(float(current)) or float(current) < 0 or float(current) > int(definitions()[id].maximum):
			errors.append("无限研究层数无效")
			continue
		var paid: Variant = row.get("invested")
		if not DecimalCount.valid(paid):
			errors.append("无限研究投入必须为精确十进制字符串")
		elif int(current) == int(definitions()[id].maximum):
			if paid != "0": errors.append("满级研究不能保留投入")
		elif DecimalCount.compare(paid, String(definitions()[id].costs[int(current)])) >= 0: errors.append("无限研究投入越界")
	var active_id: Variant = facts.get("active_infinite", "")
	if not active_id is String or (not active_id.is_empty() and not definitions().has(active_id)): errors.append("当前无限研究无效")
	for key in ["infinite_paused", "infinite_auto"]:
		if facts.has(key) and not facts[key] is bool: errors.append("无限研究开关无效")
	return errors
