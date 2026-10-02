class_name PureIdleState
extends RefCounted

static func defaults() -> Dictionary:
	return {"version": 1, "enabled": false, "mode": "stable", "carry_seconds": 0.0, "last_receipt": "", "report": {}}

static func configure(state: GameState, enabled: bool, mode: String) -> Dictionary:
	if state.save_mode != "normal" or mode not in ["stable", "extreme"]: return {"ok": false, "message": "纯挂机仅支持普通模式"}
	if enabled and (state.paused or not state.time_warp.get("enabled", false)): return {"ok": false, "message": "请先恢复游戏并启用时间扭曲"}
	if state.pure_idle.is_empty(): state.pure_idle = defaults()
	state.pure_idle.enabled = enabled
	state.pure_idle.mode = mode
	return {"ok": true, "message": "纯挂机已启用" if enabled else "纯挂机已停止；未结算时间保留"}

static func validate(data: Dictionary) -> Array:
	var raw: Variant = data.get("pure_idle", {})
	if not raw is Dictionary: return ["纯挂机状态必须是字典"]
	if raw.is_empty(): return []
	if raw.size() != 6 or raw.get("version") != 1 or not raw.get("enabled") is bool or raw.get("mode") not in ["stable", "extreme"]: return ["纯挂机配置无效"]
	if data.get("save_mode", "normal") != "normal": return ["速通存档不能携带纯挂机状态"]
	var carry: Variant = raw.get("carry_seconds")
	if not (carry is int or carry is float) or not is_finite(float(carry)) or carry < 0: return ["纯挂机待结算时间无效"]
	if not raw.get("last_receipt") is String or (raw.last_receipt != "" and raw.last_receipt.length() != 64) or not raw.get("report") is Dictionary: return ["纯挂机结算记录无效"]
	return []
