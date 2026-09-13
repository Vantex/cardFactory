class_name ProliferatorSystem
extends RefCounted

var emit_events := true
var state: GameState
func _init(game_state: GameState) -> void:
	state = game_state

func configure(id: String, tier: int, mode: String) -> Dictionary:
	var building: Dictionary = state.buildings.get(id, {})
	var recipe := DataManager.get_recipe(String(building.get("recipe_id", "")))
	if building.is_empty() or building.get("interaction_locked", false) or mode not in ["normal", "speed", "extra"] or tier not in [1, 2, 3]: return _failure("无效喷涂配置")
	if not eligible(building, recipe) or (recipe.get("source_id") == "matrix_research" and mode == "extra"): return _failure("该配方不支持此喷涂模式")
	var rule: Dictionary = DataManager.proliferators.get("proliferator_mk%d" % tier, {})
	if not DataManager.source_technology_unlocked(state, String(rule.get("required_source_technology", ""))): return _failure("增产剂科技未解锁")
	if building.get("spray_coater_installed", false) and int(building.get("proliferator_tier", tier)) != tier:
		var reset := _refund(id, false)
		if not reset.ok: return reset
	if not building.get("spray_coater_installed", false):
		if float(state.construction_inventory.get("dsp_spray_coater", 0)) < 1: return _failure("缺少喷涂机施工件")
		state.construction_inventory.dsp_spray_coater -= 1.0
	building.merge({"spray_coater_installed": true, "proliferator_tier": float(tier), "proliferator_mode": mode}, true)
	return {"ok": true, "message": "喷涂配置已更新"}

static func eligible(building: Dictionary, recipe: Dictionary) -> bool:
	return DataManager.get_building(String(building.get("type", ""))).get("kind") == "processor" and DataManager.get_building(String(building.get("type", ""))).get("source_id") != "spray_coater" and (recipe.get("source_id") == "matrix_research" or (not recipe.get("inputs", []).is_empty() and not recipe.get("outputs", []).is_empty()))

static func profile(building: Dictionary, recipe: Dictionary) -> Dictionary:
	var normal := {"active": false, "speed": 1.0, "power": 1.0, "bonus": 0.0, "cost": 0.0}
	if not building.get("spray_coater_installed", false) or not eligible(building, recipe) or building.get("proliferator_mode", "normal") == "normal": return normal
	var tier := int(building.get("proliferator_tier", 0))
	var rule: Dictionary = DataManager.proliferators.get("proliferator_mk%d" % tier, {})
	if rule.is_empty(): return normal
	var cost := 0.0
	for input in recipe.inputs: cost += float(input.amount)
	cost = maxf(1, cost)
	var points := float(building.get("proliferator_points", 0)) + floorf(float(building.get("input_buffer", {}).get(rule.id, 0))) * float(rule.spray_points)
	if points + 0.0000001 < cost: return normal
	return {"active": true, "speed": 1.0 + float(rule.speed_bonus) if building.proliferator_mode == "speed" else 1.0, "power": float(rule.power_multiplier), "bonus": float(rule.extra_bonus) if building.proliferator_mode == "extra" and recipe.get("source_id") != "matrix_research" else 0.0, "cost": cost, "rule": rule}

static func outputs(building: Dictionary, recipe: Dictionary, effect: Dictionary) -> Dictionary:
	var result := {}
	var remainders: Dictionary = building.get("proliferator_bonus", {})
	for output in recipe.outputs:
		var amount := float(output.amount)
		result[output.item_id] = amount + floorf(float(remainders.get(output.item_id, 0)) + amount * float(effect.bonus) + 0.0000001)
	return result

static func consume(building: Dictionary, recipe: Dictionary, effect: Dictionary, statistics: StatisticsSystem) -> void:
	if not effect.active: return
	var points := float(building.get("proliferator_points", 0))
	var count := maxi(ceili((float(effect.cost) - points) / float(effect.rule.spray_points)), 0)
	if count > 0:
		building.input_buffer[effect.rule.id] = float(building.input_buffer.get(effect.rule.id, 0)) - count
		points += count * float(effect.rule.spray_points)
		if statistics != null: statistics.record_consumed(effect.rule.id, count, building.id, building.planet_id)
	building.proliferator_points = maxf(points - float(effect.cost), 0)
	var remainders: Dictionary = building.get("proliferator_bonus", {})
	for output in recipe.outputs:
		var bonus := float(remainders.get(output.item_id, 0)) + float(output.amount) * float(effect.bonus)
		remainders[output.item_id] = maxf(bonus - floorf(bonus + 0.0000001), 0)
	building.proliferator_bonus = remainders

static func _failure(message: String) -> Dictionary:
	return {"ok": false, "message": message}

func remove(id: String) -> Dictionary:
	return _refund(id, true)

func _refund(id: String, uninstall: bool) -> Dictionary:
	var building: Dictionary = state.buildings.get(id, {})
	if building.is_empty() or building.get("interaction_locked", false) or not building.get("spray_coater_installed", false): return _failure("没有可拆卸的喷涂模块")
	var item := "proliferator_mk%d" % int(building.get("proliferator_tier", 1))
	var rule: Dictionary = DataManager.proliferators[item]
	var returned := floorf(float(building.get("input_buffer", {}).get(item, 0))) + (ceilf(float(building.get("proliferator_points", 0)) / float(rule.spray_points)) if uninstall else 0.0)
	var inventory := InventorySystem.new(state)
	var kits := {"dsp_spray_coater": 1.0} if uninstall else {}
	var connections: Array = []
	for connection_id in state.connections:
		var connection: Dictionary = state.connections[connection_id]
		if connection.get("target_id") != id or not String(connection.get("item_id", "")).begins_with("proliferator_mk"): continue
		connections.append(connection_id)
		if state._connection_construction_is_accounted(connection):
			var type := state._belt_tier(connection)
			kits[type] = float(kits.get(type, 0)) + state._belt_parallel_count(connection)
	for type in kits:
		if float(state.construction_inventory.get(type, 0)) + float(kits[type]) > 99: return _failure("施工库存不足以返还模块和线路")
	if returned > 0 and not inventory.can_add_batch({item: returned}, building.planet_id): return _failure("托盘不足以返还增产剂")
	if returned > 0: inventory.try_add(item, returned, building.planet_id)
	for type in kits: state.construction_inventory[type] = float(state.construction_inventory.get(type, 0)) + kits[type]
	for connection_id in connections:
		state.connections.erase(connection_id)
		if emit_events: EventBus.connection_removed.emit(connection_id)
	building.input_buffer[item] = 0.0
	building.proliferator_points = 0.0
	if uninstall:
		building.spray_coater_installed = false
		building.erase("proliferator_tier")
		building.erase("proliferator_mode")
		building.proliferator_bonus = {}
	return {"ok": true, "message": "已返还喷涂模块、剩余增产剂和专用线路"}

func configure_batch(ids: Array, tier: int, mode: String) -> Dictionary:
	if ids.is_empty(): return _failure("请选择生产设备")
	var seen := {}
	for id in ids:
		if not id is String or seen.has(id) or not state.buildings.has(id): return _failure("设备不存在或重复")
		seen[id] = true
	var trial := GameStateCodec.from_persistent_dict(GameStateCodec.to_persistent_dict(state))
	if trial == null: return _failure("当前状态无法进行批量配置")
	var service := ProliferatorSystem.new(trial)
	service.emit_events = false
	for id in ids:
		var result := service.configure(id, tier, mode)
		if not result.ok: return result
	var removed: Array = state.connections.keys().filter(func(id): return not trial.connections.has(id))
	state.buildings = trial.buildings
	state.connections = trial.connections
	state.construction_inventory = trial.construction_inventory
	state.planet_inventories = trial.planet_inventories
	state.planet_inventory = trial.planet_inventory
	for id in removed: EventBus.connection_removed.emit(id)
	return {"ok": true, "message": "已为 %d 台设备应用喷涂配置" % ids.size()}
