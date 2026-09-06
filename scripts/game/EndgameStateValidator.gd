class_name EndgameStateValidator
extends RefCounted

static func validate(data: Dictionary) -> Array:
	var value: Variant = data.get("endgame")
	if not value is Dictionary: return _error()
	var rules := EndgameSystem.get_rules()
	if value.size() != 5 or value.get("phase") not in ["preparing", "running", "won"] or not value.get("planet_id") is String or not value.get("invested") is Dictionary or not value.get("reward_claimed") is bool:
		return _error()
	var ticks: Variant = value.get("progress_ticks")
	if not (ticks is int or ticks is float) or not is_finite(float(ticks)) or float(ticks) != floorf(float(ticks)) or float(ticks) < 0 or float(ticks) > float(rules.duration_ticks): return _error()
	if value.phase == "preparing":
		if value.planet_id != "" or not value.invested.is_empty() or ticks != 0 or value.reward_claimed: return _error()
	else:
		if not data.get("colonized_planet_ids") is Array or not data.colonized_planet_ids.has(value.planet_id) or not data.get("completed_technologies") is Array or not data.completed_technologies.has(rules.technology): return _error()
		if value.invested.size() != rules.cost.size(): return _error()
		for item in rules.cost:
			var amount: Variant = value.invested.get(item)
			if not (amount is int or amount is float) or float(amount) != float(rules.cost[item]): return _error()
		if value.phase == "running" and (ticks >= rules.duration_ticks or value.reward_claimed): return _error()
		if value.phase == "won" and ticks != rules.duration_ticks: return _error()
	return []

static func normalize_integer_fields(data: Dictionary) -> void:
	if not data.get("endgame") is Dictionary: return
	if data.endgame.get("invested") is Dictionary:
		for item in data.endgame.invested:
			var amount: Variant = data.endgame.invested[item]
			if (amount is int or amount is float) and is_finite(float(amount)):
				data.endgame.invested[item] = float(amount)
	var ticks: Variant = data.endgame.get("progress_ticks")
	if (ticks is int or ticks is float) and is_finite(float(ticks)) and float(ticks) == floorf(float(ticks)) and float(ticks) >= 0 and float(ticks) <= float(EndgameSystem.get_rules().duration_ticks):
		data.endgame.progress_ticks = int(ticks)

static func _error() -> Array:
	return [{"code": "invalid_endgame_state", "source": "state", "id": "endgame", "message": "终局阶段、投入、进度或奖励状态无效"}]
