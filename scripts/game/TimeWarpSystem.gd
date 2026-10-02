class_name TimeWarpSystem
extends RefCounted

const BASE_POWER_KW := 100000.0
const MIN_REQUESTED := 5
const MAX_REQUESTED := 307

var state: GameState

func _init(game_state: GameState) -> void:
	state = game_state

func select_controller(id: String) -> bool:
	var building: Dictionary = state.buildings.get(id, {})
	if building.get("type") != "dsp_time_warp_device" or building.get("interaction_locked", false): return false
	state.time_warp = {"controller_id": id, "enabled": false, "requested": int(state.time_warp.get("requested", MIN_REQUESTED)), "effective": state.speed, "required_kw": 0.0, "allocated_kw": 0.0}
	return true

func set_enabled(enabled: bool) -> bool:
	var id := String(state.time_warp.get("controller_id", ""))
	if state.buildings.get(id, {}).get("type") != "dsp_time_warp_device" or state.buildings[id].get("interaction_locked", false): return false
	state.time_warp["enabled"] = enabled
	state.time_warp["effective"] = state.speed
	state.time_warp["required_kw"] = 0.0
	state.time_warp["allocated_kw"] = 0.0
	return true

func set_requested(multiplier: int) -> bool:
	if multiplier < MIN_REQUESTED or multiplier > MAX_REQUESTED: return false
	var id := String(state.time_warp.get("controller_id", ""))
	if not id.is_empty() and state.buildings.get(id, {}).get("interaction_locked", false): return false
	state.time_warp["requested"] = multiplier
	return true

func effective_multiplier() -> float:
	var id := String(state.time_warp.get("controller_id", ""))
	if not state.time_warp.get("enabled", false) or state.buildings.get(id, {}).get("type") != "dsp_time_warp_device": return state.speed
	return maxf(state.speed, float(state.time_warp.get("effective", state.speed)))

func reset_allocation() -> void:
	if state.time_warp.is_empty(): return
	state.time_warp["effective"] = state.speed
	state.time_warp["required_kw"] = 0.0
	state.time_warp["allocated_kw"] = 0.0

func set_allocation(stable: int, required_kw: float, allocated_kw: float) -> void:
	state.time_warp["required_kw"] = required_kw
	state.time_warp["allocated_kw"] = allocated_kw
	state.time_warp["effective"] = maxf(state.speed, float(stable)) if allocated_kw + 0.0001 >= required_kw and stable >= 4 else state.speed

static func required_power_kw(multiplier: int) -> float:
	if multiplier < 4 or multiplier > 307: return 0.0
	return pow(10.0, multiplier + 1)

static func maximum_stable(available_kw: float, requested: int) -> int:
	if not is_finite(available_kw) or available_kw < BASE_POWER_KW or requested < MIN_REQUESTED: return 0
	return mini(requested, maxi(4, int(floor(log(available_kw) / log(10.0) - 1.0 + 0.000000000001))))

static func validate(data: Dictionary) -> Array:
	var errors := []
	var raw: Variant = data.get("time_warp", {})
	if not raw is Dictionary: return ["时间扭曲状态必须是字典"]
	if raw.is_empty(): return errors
	var id: Variant = raw.get("controller_id", "")
	if not id is String: errors.append("时间扭曲主控 ID 无效")
	elif not id.is_empty() and data.get("buildings", {}).get(id, {}).get("type") != "dsp_time_warp_device": errors.append("时间扭曲主控建筑不存在")
	if not raw.get("enabled", false) is bool: errors.append("时间扭曲开关无效")
	elif raw.get("enabled", false) and id == "": errors.append("时间扭曲缺少主控建筑")
	var requested: Variant = raw.get("requested", MIN_REQUESTED)
	if not (requested is int or requested is float) or not is_finite(float(requested)) or float(requested) != floorf(float(requested)) or float(requested) < MIN_REQUESTED or float(requested) > MAX_REQUESTED: errors.append("时间扭曲倍率无效")
	return errors
