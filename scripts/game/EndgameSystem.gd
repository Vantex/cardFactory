class_name EndgameSystem
extends RefCounted

static var _rules_cache: Dictionary = {}
var state: GameState
var rules: Dictionary

func _init(game_state: GameState) -> void:
	state = game_state
	rules = get_rules()

static func get_rules() -> Dictionary:
	if _rules_cache.is_empty():
		var file := FileAccess.open("res://data/progression.json", FileAccess.READ)
		if file != null:
			var parsed: Variant = JSON.parse_string(file.get_as_text())
			if parsed is Dictionary: _rules_cache = parsed.get("endgame", {})
	return _rules_cache.duplicate(true)

static func initial_state() -> Dictionary:
	return {"phase": "preparing", "planet_id": "", "invested": {}, "progress_ticks": 0, "reward_claimed": false}

func get_snapshot() -> Dictionary:
	var planet_id := String(state.endgame.planet_id) if state.endgame.phase != "preparing" else state.active_planet_id
	var system_id := String(GalaxySystem.new(state).get_planet(planet_id).get("system_id", ""))
	var inventory := state.get_planet_inventory(planet_id)
	var missing := {}
	for item in rules.cost:
		missing[item] = maxf(0, float(rules.cost[item]) - float(inventory.get(item, 0))) if state.endgame.phase == "preparing" else 0.0
	var power := float(DysonSphereSystem.new(state).get_summary(system_id).power_kw)
	var reason := ""
	if not state.completed_technologies.has(rules.technology): reason = "需要完成戴森工程科技"
	elif power < float(rules.power_kw): reason = "本恒星系戴森功率不足"
	elif state.endgame.phase == "preparing" and not InventorySystem.new(state).can_remove_batch(rules.cost, planet_id): reason = "来源行星托盘材料不足"
	var rate := 1.0 if reason.is_empty() and not state.paused and state.endgame.phase == "running" else 0.0
	return {"phase": state.endgame.phase, "planet_id": planet_id, "system_id": system_id, "missing": missing, "cost": rules.cost.duplicate(true), "power_kw": power, "required_power_kw": rules.power_kw, "progress_ticks": state.endgame.progress_ticks, "duration_ticks": rules.duration_ticks, "rate": rate, "remaining_seconds": (float(rules.duration_ticks) - float(state.endgame.progress_ticks)) / 60.0, "reason": reason, "can_start": state.endgame.phase == "preparing" and reason.is_empty(), "reward_claimed": state.endgame.reward_claimed}

func try_start(expected_planet_id: String, confirmed: bool = false) -> Dictionary:
	if not confirmed: return _result(false, "需要确认一次性投入终局材料")
	if expected_planet_id != state.active_planet_id: return _result(false, "来源行星已改变，请重新确认")
	var snapshot := get_snapshot()
	if not snapshot.can_start: return _result(false, snapshot.reason if snapshot.phase == "preparing" else "终局已经启动")
	var paid := InventorySystem.new(state).try_remove_batch(rules.cost, expected_planet_id)
	if not paid.ok: return paid
	state.endgame = {"phase": "running", "planet_id": expected_planet_id, "invested": rules.cost.duplicate(true), "progress_ticks": 0, "reward_claimed": false}
	return _result(true, "终局计划已启动，材料已投入")

func update_tick() -> void:
	if state.endgame.phase == "running":
		var snapshot := get_snapshot()
		if not snapshot.reason.is_empty(): return
		state.endgame.progress_ticks += 1
		if int(state.endgame.progress_ticks) >= int(rules.duration_ticks):
			state.endgame.phase = "won"
			EventBus.notice_requested.emit("单机胜利：星际文明计划完成！可以继续建设工厂。", "success")
	if state.endgame.phase == "won" and not state.endgame.reward_claimed:
		claim_reward()

func claim_reward() -> Dictionary:
	if state.endgame.phase != "won" or state.endgame.reward_claimed: return _result(false, "没有待领取的终局奖励")
	var result := InventorySystem.new(state).try_add_batch(rules.reward, String(state.endgame.planet_id))
	if not result.ok: return _result(false, "来源行星托盘已满，终局奖励保留待领取")
	state.endgame.reward_claimed = true
	return _result(true, "一次性终局奖励已发放至来源行星")

func find_producer(item_id: String) -> Dictionary:
	var ids := state.buildings.keys()
	ids.sort()
	for id in ids:
		var building: Dictionary = state.buildings[id]
		var recipe := DataManager.get_recipe(String(building.get("recipe_id", "")))
		for output in recipe.get("outputs", []):
			if output.item_id == item_id:
				return {"building_id": id, "planet_id": building.planet_id, "position": building.position}
	return {}

static func _result(ok: bool, message: String) -> Dictionary:
	return {"ok": ok, "message": message}
