class_name PureIdleSimulationJob
extends RefCounted

const BUCKET_SECONDS := 30.0
const CALIBRATION_TICKS := 1800
const VALIDATION_SECONDS := 600.0
const DEADLINE_USEC := 30000000
const IGNORED := ["planet_metrics", "fuel_progress", "dispatch_progress", "routing_cursors", "upload_cursors", "production_history", "dyson_tick", "pure_idle", "research_progress", "research_invested_costs"]
const DYNAMIC_MAPS := ["input_buffer", "output_buffer", "produced", "consumed", "planet_inventory", "planet_inventories", "input_consumed", "proliferator_consumed"]
var base_state: GameState
var candidate: GameState
var engine: SimulationEngine
var phase := "idle"
var mode := "stable"
var target_wall := 0.0
var settled_wall := 0.0
var settled_simulation := 0.0
var exact_ticks := 0
var macro_seconds := 0.0
var deadline_at := 0
var calibration_ticks := 0
var next_validation_wall := VALIDATION_SECONDS
var snapshots: Array = []
var contract: Array = []
var reason := ""
var boundary_corrections := 0
var validation_count := 0
var partial := false

func begin(source: GameState, wall_seconds: float, selected_mode: String = "stable") -> Dictionary:
	if source.save_mode != "normal" or source.paused or not source.time_warp.get("enabled", false) or wall_seconds < SimulationEngine.FIXED_DELTA or not is_finite(wall_seconds) or selected_mode not in ["stable", "extreme"]: return result(false, "纯挂机需要普通模式、未暂停且已启用的时间扭曲，结算时间至少一个模拟步长")
	if not GameStateValidator.validate_persistent_dict(GameStateCodec.to_persistent_dict(source)).is_empty(): return result(false, "纯挂机起点未通过存档校验")
	base_state = source.copy_state()
	candidate = source.copy_state()
	candidate.emit_canvas_events = false
	candidate.command_history.enabled = false
	engine = SimulationEngine.new(candidate)
	engine.offline_replay = true
	mode = selected_mode
	target_wall = wall_seconds
	deadline_at = Time.get_ticks_usec() + DEADLINE_USEC
	snapshots = [capture(GameStateCodec.to_persistent_dict(candidate))]
	contract = []
	phase = "calibrating"
	return result(true, "纯挂机候选已隔离")

func advance(budget_usec: int = 5000, max_ticks: int = 600) -> void:
	if phase not in ["calibrating", "running", "conservative"]: return
	var started := Time.get_ticks_usec()
	var blocked := EventBus.is_blocking_signals()
	EventBus.set_block_signals(true)
	var ticks := 0
	while ticks < max_ticks and Time.get_ticks_usec() - started < budget_usec:
		if Time.get_ticks_usec() >= deadline_at:
			partial = settled_wall + 0.000001 < target_wall
			reason = "达到 30 秒计算预算，保留已完成的精确进度"
			phase = "ready"
			break
		if settled_wall + 0.000001 >= target_wall:
			phase = "ready"
			break
		if phase == "running" and mode == "stable" and settled_wall + 0.000001 >= next_validation_wall:
			phase = "calibrating"
			calibration_ticks = 0
			snapshots = [capture(GameStateCodec.to_persistent_dict(candidate))]
			contract.clear()
			next_validation_wall += VALIDATION_SECONDS
		if phase == "running":
			var multiplier := TimeWarpSystem.new(candidate).effective_multiplier()
			var wall_bucket := minf(BUCKET_SECONDS, target_wall - settled_wall)
			if mode == "stable": wall_bucket = minf(wall_bucket, next_validation_wall - settled_wall)
			var seconds := floorf((wall_bucket * multiplier + SimulationEngine.STEP_EPSILON) / 10.0) * 10.0
			if seconds >= 10 and _apply_contract(seconds):
				settled_simulation += seconds
				settled_wall += seconds / multiplier
				macro_seconds += seconds
				continue
			else:
				boundary_corrections += 1
			phase = "conservative"
			continue
		var tail_checkpoint := candidate.copy_state() if target_wall - settled_wall < SimulationEngine.FIXED_DELTA else null
		var before_time := candidate.elapsed_time
		engine.update(SimulationEngine.FIXED_DELTA)
		var step := candidate.elapsed_time - before_time
		var multiplier := TimeWarpSystem.new(candidate).effective_multiplier()
		var paid_wall := step / maxf(1.0, multiplier)
		if paid_wall > target_wall - settled_wall + SimulationEngine.STEP_EPSILON:
			candidate = tail_checkpoint
			engine = SimulationEngine.new(candidate)
			engine.offline_replay = true
			phase = "ready"
			break
		settled_simulation += step
		settled_wall += paid_wall
		exact_ticks += 1
		ticks += 1
		if phase == "calibrating": calibration_ticks += 1
		if phase == "calibrating" and calibration_ticks % 600 == 0:
			snapshots.append(capture(GameStateCodec.to_persistent_dict(candidate)))
			if calibration_ticks >= CALIBRATION_TICKS:
				contract = build_contract(snapshots)
				validation_count += 1
				phase = "running" if not contract.is_empty() and supports_macro(candidate) else "conservative"
				if phase == "conservative": reason = last_contract_failure if not last_contract_failure.is_empty() else "产线或离散系统边界需要精确模拟"
	EventBus.set_block_signals(blocked)

static func supports_macro(state: GameState) -> bool:
	if not InfiniteResearchSystem.new(state).active().is_empty(): return false
	if not state.research_current_id.is_empty() or not state.research_queue.is_empty() or not state.handcraft_queue.is_empty() or not state.construction_queue.is_empty() or not state.production_orders.is_empty() or not state.exploration_missions.is_empty() or not state.logistics_routes.is_empty(): return false
	if state.quantum_network.get("enabled", false) or not state.galactic_hub_network.is_empty() or not state.galactic_exports.is_empty() or state.endgame.get("phase") in ["running", "reward_pending"]: return false
	for building in state.buildings.values():
		var kind: String = DataManager.get_building(building.type).get("kind", "")
		if kind in ["station", "lab"] or building.type in DysonSphereSystem.BUILDINGS or building.type in [BlackHoleSystem.TYPE, OrbitalCargoTerminalSystem.TYPE, SystemSpaceStationSystem.TYPE, OrbitalCollectorSystem.TYPE] or building.has("proliferator") or building.get("spray_coater_installed", false): return false
		var recipe := DataManager.get_recipe(String(building.get("recipe_id", "")))
		if not recipe.is_empty():
			if building.get("status", "") != "running": return false
			var rate := maxf(0, float(building.get("speed", 1))) * clampf(float(building.get("power_efficiency", 0)), 0, 1) * state.get_technology_effect_multiplier("production_speed") * GameModeSystem.new(state).multiplier("production")
			var cycles := 10.0 * rate / maxf(float(recipe.duration), ProductionSystem.PROGRESS_EPSILON)
			# A ten-second observation must end at the same recipe phase before projection.
			if cycles < 1 or absf(cycles - roundf(cycles)) > 0.0000001: return false
	for system in state.dyson_systems.values():
		if not system.get("orbits", {}).is_empty(): return false
	return true

static func capture(value: Variant, path: Array = [], output: Dictionary = {}) -> Dictionary:
	if not path.is_empty() and path.back() in IGNORED: return output
	var key := JSON.stringify(path)
	if value is Dictionary:
		var keys: Array = value.keys()
		keys.sort()
		output[key] = {"path": path, "kind": "structure", "value": "map" if not path.is_empty() and path.back() in DYNAMIC_MAPS else JSON.stringify(keys)}
		for child in keys: capture(value[child], path + [child], output)
	elif value is Array:
		output[key] = {"path": path, "kind": "structure", "value": "array:" + str(value.size())}
		for index in range(value.size()): capture(value[index], path + [index], output)
	elif value is int or value is float:
		output[key] = {"path": path, "kind": "number", "value": float(value)}
	else:
		output[key] = {"path": path, "kind": "structure", "value": value}
	return output

static var last_contract_failure := ""

static func reject_contract(message: String) -> Array:
	last_contract_failure = message
	return []

static func build_contract(observed: Array) -> Array:
	last_contract_failure = ""
	if observed.size() != 4: return []
	var first: Dictionary = observed[1]
	var second: Dictionary = observed[2]
	var third: Dictionary = observed[3]
	var keys := {}
	for snapshot in [first, second, third]:
		for key in snapshot: keys[key] = true
	var deltas := []
	for key in keys:
		var last: Dictionary = third.get(key, second.get(key, first.get(key)))
		var path: Array = last.path
		var dynamic: bool = path.size() > 1 and path[path.size() - 2] in DYNAMIC_MAPS
		var a: Dictionary = first.get(key, {"kind": "number", "value": 0.0}) if dynamic else first.get(key, {})
		var b: Dictionary = second.get(key, {"kind": "number", "value": 0.0}) if dynamic else second.get(key, {})
		var c: Dictionary = third.get(key, {"kind": "number", "value": 0.0}) if dynamic else third.get(key, {})
		if a.is_empty() or b.is_empty() or c.is_empty() or a.kind != b.kind or b.kind != c.kind: return reject_contract("结构变化：" + key)
		if a.kind == "structure":
			if a.value != b.value or b.value != c.value: return reject_contract("离散变化：" + key)
			continue
		var d1 := float(b.value) - float(a.value)
		var d2 := float(c.value) - float(b.value)
		if not is_finite(d1) or not is_finite(d2) or absf(d1 - d2) > maxf(0.0000001, maxf(absf(d1), absf(d2)) * 0.000001): return reject_contract("速率变化：" + key + " " + str(d1) + " / " + str(d2))
		if absf(d2) > 0.0000001: deltas.append({"path": path.duplicate(), "delta": d2})
	return deltas

func _apply_contract(seconds: float) -> bool:
	if contract.is_empty() or not supports_macro(candidate): return false
	var payload := GameStateCodec.to_persistent_dict(candidate).duplicate(true)
	for row in contract:
		var parent: Variant = payload
		for segment in row.path.slice(0, -1):
			if not parent is Dictionary and not parent is Array: return false
			if parent is Dictionary and not parent.has(segment): return false
			parent = parent[segment]
		var key: Variant = row.path.back()
		var previous: Variant = parent.get(key, 0) if parent is Dictionary else parent[key]
		if not previous is int and not previous is float: return false
		var next := float(previous) + float(row.delta) * seconds / 10.0
		if not is_finite(next) or next < -0.0000001: return false
		parent[key] = maxf(next, 0.0)
	payload.elapsed_time = candidate.elapsed_time + seconds
	payload.dyson_tick = candidate.dyson_tick + int(round(seconds * 60))
	var probe := GameStateCodec.from_persistent_dict(payload)
	if probe == null:
		reason = "投影未通过存档结构校验"
		return false
	if not capacity_safe(probe) or not resource_safe(candidate, probe):
		reason = "投影到达容量或有限矿脉边界"
		return false
	var blocked := EventBus.is_blocking_signals()
	EventBus.set_block_signals(true)
	ProgressionSystem.new(probe).evaluate()
	var power_probe := probe.copy_state()
	PowerSystem.new(power_probe).update(SimulationEngine.FIXED_DELTA)
	probe.time_warp = power_probe.time_warp.duplicate(true)
	for id in probe.buildings:
		for field in ["power_efficiency", "power_input", "power_output", "power_requested", "power_covered"]:
			probe.buildings[id][field] = power_probe.buildings[id].get(field, 0.0)
	EventBus.set_block_signals(blocked)
	if TimeWarpSystem.new(probe).effective_multiplier() != TimeWarpSystem.new(candidate).effective_multiplier():
		reason = "投影跨越时间扭曲供电边界"
		return false
	candidate = probe
	candidate.emit_canvas_events = false
	candidate.command_history.enabled = false
	engine = SimulationEngine.new(candidate)
	engine.offline_replay = true
	return true

static func capacity_safe(state: GameState) -> bool:
	var production := ProductionSystem.new(state)
	for building in state.buildings.values():
		var definition := DataManager.get_building(building.type)
		for direction in ["input", "output"]:
			var capacity := production._get_buffer_capacity(building, definition, direction)
			for amount in building.get(direction + "_buffer", {}).values():
				if float(amount) < 0 or float(amount) > capacity + 0.000001: return false
	return true

static func resource_safe(before: GameState, after: GameState) -> bool:
	var depleted := {}
	for id in before.resource_sites:
		var site: Dictionary = before.resource_sites[id]
		if site.get("infinite", false): continue
		if not after.resource_sites.has(id): return false
		var delta := float(site.remaining) - float(after.resource_sites[id].remaining)
		if delta < -0.000001: return false
		depleted[site.item_id] = float(depleted.get(site.item_id, 0)) + maxf(delta, 0)
	for item in depleted:
		var production := float(after.progression_facts.get("produced", {}).get(item, 0)) - float(before.progression_facts.get("produced", {}).get(item, 0))
		var multiplier := before.get_technology_effect_multiplier("vein_consumption") if DataManager.get_item(item).get("kind") == "solid" else 1.0
		if float(depleted[item]) > maxf(0, production) * multiplier + 0.000001: return false
	return true

func summary() -> Dictionary:
	return {"phase": phase, "mode": mode, "settled_wall_seconds": settled_wall, "settled_simulation_seconds": settled_simulation, "exact_ticks": exact_ticks, "macro_seconds": macro_seconds, "calibration_windows": mini(3, int(exact_ticks / 600)), "validation_count": validation_count, "boundary_corrections": boundary_corrections, "partial": partial, "reason": reason, "macro_supported": supports_macro(candidate)}

static func result(ok: bool, message: String) -> Dictionary:
	return {"ok": ok, "message": message}
