class_name GalacticExportSystem
extends RefCounted

const PROJECTS := {
	"universe_archive": {"item": "universe_matrix", "base_target": 1000, "growth": 1.55, "credits": 12, "rate": 120, "reserve": 120},
	"solar_sail_array": {"item": "solar_sail", "base_target": 5000, "growth": 1.5, "credits": 3, "rate": 360, "reserve": 240},
	"carrier_rocket_fleet": {"item": "small_carrier_rocket", "base_target": 1000, "growth": 1.52, "credits": 24, "rate": 60, "reserve": 60},
	"antimatter_exchange": {"item": "antimatter_fuel_rod", "base_target": 500, "growth": 1.58, "credits": 80, "rate": 30, "reserve": 24},
}

var state: GameState

func _init(game_state: GameState) -> void:
	state = game_state

func unlocked() -> bool:
	return state.completed_technologies.has("dsp_universe_matrix")

func snapshot() -> Dictionary:
	return {"unlocked": unlocked(), "state": state.galactic_exports.duplicate(true) if not state.galactic_exports.is_empty() else _initial_state()}

func award_research_completion(completed_level: int) -> void:
	_ensure_state()
	state.galactic_exports.score = floorf(float(state.galactic_exports.score) + 1000 + completed_level * 250)

func industry_snapshot(statistics: StatisticsSystem = null) -> Dictionary:
	var result := {"unlocked": unlocked(), "totalProductionPerMinute": 0.0, "totalConsumptionPerMinute": 0.0, "netPerMinute": 0.0, "activePlanets": 0, "operatingEntities": 0, "blockedEntities": 0, "logisticsTrips": state.logistics_routes.size(), "networkInventory": 0.0, "generationKw": 0.0, "demandKw": 0.0, "dysonGenerationKw": 0.0, "exportedPerMinute": 0.0, "totalExported": state.galactic_exports.get("total_exported", 0), "galacticCredits": state.galactic_exports.get("credits", 0), "galacticScore": state.galactic_exports.get("score", 0), "infiniteResearchLevels": 0}
	var active_planets := {}
	for building in state.buildings.values():
		var running: bool = building.get("status") == "running"
		if running:
			result.operatingEntities += 1
			active_planets[building.planet_id] = true
		elif building.get("status") in ["blocked", "no_power", "no_fuel", "resource_depleted"]: result.blockedEntities += 1
		for direction in ["input_buffer", "output_buffer"]:
			for amount in building.get(direction, {}).values(): result.networkInventory += floorf(float(amount))
		for slot in building.get("station", {}).get("slots", []): result.networkInventory += floorf(float(slot.amount))
		var generation := maxf(0, float(building.get("power_output", 0)))
		result.generationKw += generation
		result.demandKw += maxf(0, float(building.get("power_requested", DataManager.get_building(building.type).get("power_demand", 0))))
		if building.type in ["ray_receiver", "dsp_ray_receiver"]: result.dysonGenerationKw += generation
	for tray in state.planet_inventories.values():
		for amount in tray.values(): result.networkInventory += floorf(float(amount))
	result.activePlanets = active_planets.size()
	for row in state.progression_facts.get("infinite_research", {}).values(): result.infiniteResearchLevels += int(row.get("level", 0))
	if statistics != null:
		for item in DataManager.all_items:
			result.totalProductionPerMinute += statistics.get_production_rate(item)
			result.totalConsumptionPerMinute += statistics.get_consumption_rate(item)
	result.netPerMinute = result.totalProductionPerMinute - result.totalConsumptionPerMinute
	if state.galactic_exports.get("auto_dispatch", false):
		for id in state.galactic_exports.get("projects", {}):
			if state.galactic_exports.projects[id].enabled: result.exportedPerMinute += PROJECTS[id].rate * state.galactic_exports.throttle * (1 + InfiniteResearchSystem.new(state).level("galactic_logistics") * 0.1)
	return result

func set_automation(enabled: bool) -> Dictionary:
	if not unlocked(): return _result(false, "需要完成宇宙矩阵科技")
	_ensure_state()
	state.galactic_exports.auto_dispatch = enabled
	return _result(true, "银河自动出口已更新")

func set_throttle(value: float) -> Dictionary:
	if not unlocked() or value not in [0.25, 0.5, 1.0]: return _result(false, "出口速率只能为 25%、50% 或 100%")
	_ensure_state()
	state.galactic_exports.throttle = value
	return _result(true, "出口速率已更新")

func configure(project_id: String, enabled: bool, priority: int) -> Dictionary:
	if not unlocked() or not PROJECTS.has(project_id) or priority < 1 or priority > 3: return _result(false, "出口项目或优先级无效")
	_ensure_state()
	var project: Dictionary = state.galactic_exports.projects[project_id]
	project.enabled = enabled
	project.priority = priority
	return _result(true, "出口项目已配置")

func dispatch(project_id: String, requested: int) -> Dictionary:
	if not unlocked() or not PROJECTS.has(project_id) or requested < 1: return _result(false, "出口项目未解锁或数量无效")
	_ensure_state()
	var shipped := _dispatch_internal(project_id, requested)
	return _result(shipped > 0, "已出口 %d 份材料" % shipped if shipped > 0 else "可用库存未超过保留量")

func update(delta: float) -> void:
	if not unlocked() or delta <= 0 or not is_finite(delta) or state.galactic_exports.is_empty(): return
	if not state.galactic_exports.auto_dispatch: return
	var ids := PROJECTS.keys()
	ids.sort_custom(func(a: String, b: String) -> bool:
		var pa: Dictionary = state.galactic_exports.projects[a]
		var pb: Dictionary = state.galactic_exports.projects[b]
		return int(pa.priority) > int(pb.priority) if int(pa.priority) != int(pb.priority) else a < b)
	for id in ids:
		var project: Dictionary = state.galactic_exports.projects[id]
		if not project.enabled: continue
		var rate := float(PROJECTS[id].rate) * float(state.galactic_exports.throttle) * (1.0 + InfiniteResearchSystem.new(state).level("galactic_logistics") * 0.1)
		project.dispatch_progress = minf(rate * 2, float(project.dispatch_progress) + rate * delta / 60.0)
		var requested := int(floorf(float(project.dispatch_progress) + 0.0000001))
		if requested < 1: continue
		var shipped := _dispatch_internal(id, requested)
		project.dispatch_progress = maxf(0, float(project.dispatch_progress) - requested) if shipped >= requested else 0.0

func _dispatch_internal(project_id: String, requested: int) -> int:
	var definition: Dictionary = PROJECTS[project_id]
	var project: Dictionary = state.galactic_exports.projects[project_id]
	var reserve := int(floorf(float(definition.reserve) * (1.0 + int(project.level) * 0.08)))
	var item := String(definition.item)
	var available := maxi(0, _network_stock(item) - reserve)
	var remaining := mini(requested, available)
	var shipped := remaining
	var ids := state.buildings.keys()
	ids.sort()
	for id in ids:
		if remaining < 1: break
		var buffer: Dictionary = state.buildings[id].get("output_buffer", {})
		var take := mini(remaining, int(floorf(float(buffer.get(item, 0)))))
		if take > 0:
			buffer[item] = float(buffer[item]) - take
			remaining -= take
	var planet_ids := state.planet_inventories.keys()
	planet_ids.sort()
	for planet_id in planet_ids:
		if remaining < 1: break
		var tray: Dictionary = state.planet_inventories[planet_id]
		var take := mini(remaining, int(floorf(float(tray.get(item, 0)))))
		if take > 0:
			tray[item] = float(tray[item]) - take
			remaining -= take
	shipped -= remaining
	if shipped < 1: return 0
	project.delivered += shipped
	project.total_delivered += shipped
	state.galactic_exports.total_exported += shipped
	var base_credit := shipped * int(definition.credits)
	state.galactic_exports.credits += base_credit
	state.galactic_exports.score += base_credit
	var target := target_for(project_id, int(project.level))
	while int(project.delivered) >= target:
		project.delivered -= target
		project.level += 1
		var reward := target * int(definition.credits)
		state.galactic_exports.credits += reward
		state.galactic_exports.score += reward
		target = target_for(project_id, int(project.level))
	return shipped

func _network_stock(item: String) -> int:
	var total := 0
	for tray in state.planet_inventories.values(): total += int(floorf(float(tray.get(item, 0))))
	for building in state.buildings.values(): total += int(floorf(float(building.get("output_buffer", {}).get(item, 0))))
	return total

func _ensure_state() -> void:
	if not state.galactic_exports.is_empty(): return
	state.galactic_exports = _initial_state()

static func _initial_state() -> Dictionary:
	var projects := {}
	for id in PROJECTS: projects[id] = {"enabled": false, "priority": 1, "level": 0, "delivered": 0, "total_delivered": 0, "dispatch_progress": 0.0}
	return {"version": 1, "auto_dispatch": true, "throttle": 1.0, "projects": projects, "credits": 0, "score": 0, "total_exported": 0}

static func target_for(project_id: String, level: int) -> int:
	if not PROJECTS.has(project_id): return 0
	var definition: Dictionary = PROJECTS[project_id]
	return mini(2000000000, maxi(1, int(roundf(float(definition.base_target) * pow(float(definition.growth), maxi(0, level))))))

static func validate(data: Dictionary) -> Array:
	var value: Variant = data.get("galactic_exports", {})
	if not value is Dictionary: return ["银河出口状态必须是字典"]
	if value.is_empty(): return []
	var errors := []
	if value.size() != 7 or value.get("version") != 1 or not value.get("auto_dispatch") is bool or not value.get("throttle") in [0.25, 0.5, 1.0]: errors.append("银河出口配置无效")
	for field in ["credits", "score", "total_exported"]:
		if not _nonnegative_integer(value.get(field)): errors.append("银河出口累计数量无效")
	var projects: Variant = value.get("projects")
	if not projects is Dictionary or projects.size() != PROJECTS.size(): return errors + ["银河出口项目集合无效"]
	for id in projects:
		if not PROJECTS.has(id) or not projects[id] is Dictionary:
			errors.append("未知银河出口项目")
			continue
		var project: Dictionary = projects[id]
		if project.size() != 6 or not project.get("enabled") is bool or not project.get("priority") in [1, 2, 3]: errors.append("银河出口项目配置无效")
		for field in ["level", "delivered", "total_delivered"]:
			if not _nonnegative_integer(project.get(field)): errors.append("银河出口项目数量无效")
		if not (project.get("dispatch_progress") is int or project.get("dispatch_progress") is float) or not is_finite(float(project.get("dispatch_progress", 0))) or float(project.get("dispatch_progress", 0)) < 0: errors.append("银河出口派遣进度无效")
		if _nonnegative_integer(project.get("level")) and _nonnegative_integer(project.get("delivered")) and int(project.delivered) >= target_for(String(id), int(project.level)): errors.append("银河出口项目未结算升级")
	return errors

static func _nonnegative_integer(value: Variant) -> bool:
	return (value is int or value is float) and is_finite(float(value)) and float(value) >= 0 and float(value) == floorf(float(value)) and float(value) <= 9007199254740991.0

static func _result(ok: bool, message: String) -> Dictionary:
	return {"ok": ok, "message": message}
