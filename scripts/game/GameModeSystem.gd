class_name GameModeSystem
extends RefCounted

const MODES := ["normal", "speedrun"]
const DIFFICULTIES := {
	"relaxed": {"production": 1.15, "mining": 1.15, "logistics": 1.1, "power_demand": 0.9},
	"standard": {"production": 1.0, "mining": 1.0, "logistics": 1.0, "power_demand": 1.0},
	"hard": {"production": 0.85, "mining": 0.85, "logistics": 0.9, "power_demand": 1.2},
}
const SPEEDRUN_RULESET := "speedrun-v1"
const SPEEDRUN_TARGETS := {"all_technologies": 69, "dyson_rockets_10000": 10000, "white_matrix_1m": 1000000}

var state: GameState

func _init(game_state: GameState) -> void:
	state = game_state

func configure_new_game(mode_id: String, difficulty_id: String) -> bool:
	if mode_id not in MODES or not DIFFICULTIES.has(difficulty_id): return false
	state.save_mode = mode_id
	state.difficulty = difficulty_id
	state.speedrun_state = {}
	if mode_id == "speedrun":
		state.speedrun_state = {"ruleset": SPEEDRUN_RULESET, "started_at": int(Time.get_unix_time_from_system()), "elapsed_active_seconds": 0.0, "milestones": {}, "baseline_rockets": rockets_launched(), "baseline_white_matrix": float(state.progression_facts.get("produced", {}).get("universe_matrix", 0))}
	return true

func multiplier(kind: String) -> float:
	return float(DIFFICULTIES.get(state.difficulty, DIFFICULTIES.standard).get(kind, 1.0))

func update_active_time(real_delta: float) -> void:
	if state.save_mode != "speedrun" or state.paused or not is_finite(real_delta) or real_delta <= 0: return
	state.speedrun_state["elapsed_active_seconds"] = float(state.speedrun_state.get("elapsed_active_seconds", 0)) + real_delta
	evaluate_milestones()

func evaluate_milestones() -> void:
	if state.save_mode != "speedrun": return
	var progress := get_progress()
	var milestones: Dictionary = state.speedrun_state.get("milestones", {})
	for id in progress:
		if float(progress[id]) < float(SPEEDRUN_TARGETS[id]) or milestones.has(id): continue
		milestones[id] = float(state.speedrun_state.get("elapsed_active_seconds", 0))
	state.speedrun_state["milestones"] = milestones

func get_progress() -> Dictionary:
	var completed_source := 0
	for id in state.completed_technologies:
		var technology := DataManager.get_technology(String(id))
		if technology.has("source_id") and not technology.get("deprecated", false): completed_source += 1
	return {"all_technologies": completed_source, "dyson_rockets_10000": maxi(0, rockets_launched() - int(state.speedrun_state.get("baseline_rockets", 0))), "white_matrix_1m": maxf(0, float(state.progression_facts.get("produced", {}).get("universe_matrix", 0)) - float(state.speedrun_state.get("baseline_white_matrix", 0)))}

func rockets_launched() -> int:
	var count := 0
	for system in state.dyson_systems.values(): count += int(system.get("rockets_launched", 0))
	return count

static func validate(data: Dictionary) -> Array:
	var errors := []
	var mode_id: Variant = data.get("save_mode", "normal")
	var difficulty_id: Variant = data.get("difficulty", "standard")
	if not mode_id is String or mode_id not in MODES: errors.append("存档模式无效")
	if not difficulty_id is String or not DIFFICULTIES.has(difficulty_id): errors.append("难度无效")
	var speedrun: Variant = data.get("speedrun_state", {})
	if not speedrun is Dictionary: return errors + ["速通状态必须是字典"]
	if mode_id != "speedrun":
		if not speedrun.is_empty(): errors.append("普通存档不能带有速通状态")
		return errors
	if speedrun.get("ruleset") != SPEEDRUN_RULESET: errors.append("速通规则版本无效")
	for field in ["started_at", "elapsed_active_seconds", "baseline_rockets", "baseline_white_matrix"]:
		var amount: Variant = speedrun.get(field)
		if not (amount is int or amount is float) or not is_finite(float(amount)) or float(amount) < 0: errors.append("速通数值无效：" + field)
	if not speedrun.get("milestones", {}) is Dictionary: errors.append("速通目标状态无效")
	else:
		for id in speedrun.milestones:
			var amount: Variant = speedrun.milestones[id]
			if not SPEEDRUN_TARGETS.has(id) or not (amount is int or amount is float) or not is_finite(float(amount)) or float(amount) < 0: errors.append("速通目标记录无效")
	return errors
