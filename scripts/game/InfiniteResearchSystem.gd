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
	return not active().is_empty() and not state.progression_facts.get("infinite_paused", false) and state.research_current_id.is_empty()

func select(id: String, automatic: bool = false) -> bool:
	if not definitions().has(id) or level(id) >= int(definitions()[id].maximum) or not state.completed_technologies.has("dsp_universe_matrix") or not state.research_current_id.is_empty() or not state.research_queue.is_empty(): return false
	state.progression_facts["active_infinite"] = id
	state.progression_facts["infinite_paused"] = false
	state.progression_facts["infinite_auto"] = automatic
	return true

func pause(paused: bool) -> bool:
	if active().is_empty(): return false
	state.progression_facts["infinite_paused"] = paused
	return true

func cancel() -> void:
	state.progression_facts.erase("active_infinite")
	state.progression_facts.erase("infinite_paused")
	state.progression_facts.erase("infinite_auto")

func invest_one() -> bool:
	if not can_work(): return false
	var id := active()
	var progress := DecimalCount.add(invested(id), "1")
	if DecimalCount.compare(progress, cost(id)) > 0: return false
	var current_level := level(id)
	if progress == cost(id):
		current_level += 1
		progress = "0"
		if current_level >= int(definitions()[id].maximum) or not state.progression_facts.get("infinite_auto", false): cancel()
	if not state.progression_facts.has("infinite_research"): state.progression_facts["infinite_research"] = {}
	state.progression_facts.infinite_research[id] = {"level": current_level, "invested": progress}
	return true

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
