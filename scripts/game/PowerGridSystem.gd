class_name PowerGridSystem
extends RefCounted

const GRIDS := ["grid-a", "grid-b", "grid-c"]
const CELL_ENERGY_MJ := 90.0
const SOURCE_ENERGY_EPSILON := 0.0001
var state: GameState
func _init(game_state: GameState) -> void:
	state = game_state

static func grid_id(building: Dictionary) -> String:
	return String(building.get("power_grid_id", "grid-a"))

static func generation_priority(building: Dictionary) -> int:
	var definition := DataManager.get_building(String(building.get("type", "")))
	var fallback := 2 if kind_id(building) == "energy_exchanger" else 1 if kind_id(building) == "accumulator" or definition.has("fuel") else 3
	return int(building.get("generation_priority", fallback))

func configure(ids: Array, changes: Dictionary) -> Dictionary:
	if ids.is_empty() or changes.is_empty(): return _failure("请选择建筑和配置")
	for key in changes:
		if key not in ["power_grid_id", "power_priority", "generation_priority", "energy_mode"]: return _failure("未知电力配置")
		var value: Variant = changes[key]
		if key == "power_grid_id" and value not in GRIDS: return _failure("未知电网")
		if key in ["power_priority", "generation_priority"] and (not (value is int or value is float) or not is_finite(float(value)) or float(value) != floorf(float(value)) or int(value) not in [1, 2, 3]): return _failure("优先级必须为 1、2 或 3")
		if key == "energy_mode" and value not in ["charge", "discharge", "idle"]: return _failure("无效储能模式")
	var seen := {}
	var reset_source_ids := []
	for id in ids:
		if not state.buildings.has(id) or seen.has(id): return _failure("建筑不存在或重复")
		seen[id] = true
		var building: Dictionary = state.buildings[id]
		if building.get("interaction_locked", false): return _failure("建筑已锁定")
		if changes.has("energy_mode"):
			if kind_id(building) != "energy_exchanger": return _failure("只有能量枢纽可切换充放电模式")
			var source := DataManager.get_building(String(building.type)).has("source_id")
			if changes.energy_mode != building.get("energy_mode", "charge"):
				if float(building.get("stored_energy_mj", 0)) > (SOURCE_ENERGY_EPSILON if source else 0.0): return _failure("请先完成当前蓄电器转换再切换模式")
				if source: reset_source_ids.append(id)
	if not reset_source_ids.is_empty() and not state._reset_source_recipe_buffers(reset_source_ids): return _failure("托盘或施工件容量不足，无法返还当前缓存与传送带")
	for id in reset_source_ids:
		state.buildings[id].power_input = 0.0
		state.buildings[id].power_output = 0.0
	for id in ids:
		state.buildings[id].merge(changes, true)
		if changes.has("energy_mode") and (not DataManager.get_building(String(state.buildings[id].type)).has("source_id") or reset_source_ids.has(id)):
			state.buildings[id]["recipe_id"] = energy_recipe(state.buildings[id], changes.energy_mode)
	return {"ok": true, "message": "电力配置已更新"}

static func storage_capacity(building: Dictionary, delta: float, charge: bool) -> float:
	if delta <= 0: return 0
	var definition := DataManager.get_building(String(building.get("type", "")))
	var stored := float(building.get("stored_energy_mj", 0))
	var capacity := float(definition.get("energy_capacity_mj", 0))
	var energy := maxf(capacity - stored, 0) if charge else stored
	if kind_id(building) == "energy_exchanger":
		if building.get("energy_mode", "charge") != ("charge" if charge else "discharge"): return 0
		var input := "accumulator" if charge else "charged_accumulator"
		var output := "charged_accumulator" if charge else "accumulator"
		var epsilon := SOURCE_ENERGY_EPSILON if definition.has("source_id") else 0.0
		var active := 1 if stored > epsilon else 0
		var free := maxi(int(definition.get("output_buffer_capacity", 120)) - int(building.get("output_buffer", {}).get(output, 0)), 0)
		if definition.has("source_id"): free = maxi(floori(float(definition.get("output_buffer_capacity", 120)) - float(building.get("output_buffer", {}).get(output, 0)) + SOURCE_ENERGY_EPSILON), 0)
		var cells := mini(active + floori(float(building.get("input_buffer", {}).get(input, 0)) + epsilon), free)
		energy = maxf(cells * CELL_ENERGY_MJ - stored, 0) if charge else stored + maxi(cells - active, 0) * CELL_ENERGY_MJ
		if cells == 0: energy = 0
	return minf(float(definition.get("power_charge" if charge else "power_generation", 0)), energy * 1000.0 / delta)

static func apply_storage(building: Dictionary, energy: float, charge: bool, statistics: StatisticsSystem = null) -> int:
	var stored := float(building.get("stored_energy_mj", 0))
	if kind_id(building) == "accumulator":
		building["stored_energy_mj"] = clampf(stored + (energy if charge else -energy), 0, CELL_ENERGY_MJ)
		return 0
	if DataManager.get_building(String(building.type)).has("source_id"): return _apply_source_exchanger(building, energy, charge, statistics)
	var input := "accumulator" if charge else "charged_accumulator"
	var output := "charged_accumulator" if charge else "accumulator"
	var inputs: Dictionary = building.get("input_buffer", {})
	var outputs: Dictionary = building.get("output_buffer", {})
	var completed := 0
	while energy > 0.000000001:
		if stored <= 0:
			if float(inputs.get(input, 0)) < 1: break
			inputs[input] = float(inputs[input]) - 1
			if statistics != null: statistics.record_consumed(input, 1, building.id, building.planet_id)
			if not charge: stored = CELL_ENERGY_MJ
		var applied := minf(energy, CELL_ENERGY_MJ - stored if charge else stored)
		stored += applied if charge else -applied
		energy -= applied
		if (charge and stored >= CELL_ENERGY_MJ - 0.000000001) or (not charge and stored <= 0.000000001):
			outputs[output] = float(outputs.get(output, 0)) + 1
			completed += 1
			stored = 0
			if statistics != null: statistics.record_produced(output, 1, building.id, building.planet_id)
	building["stored_energy_mj"] = stored
	building["input_buffer"] = inputs
	building["output_buffer"] = outputs
	return completed

static func _apply_source_exchanger(building: Dictionary, energy: float, charge: bool, statistics: StatisticsSystem) -> int:
	if energy <= SOURCE_ENERGY_EPSILON: return 0
	var input := "accumulator" if charge else "charged_accumulator"
	var output := "charged_accumulator" if charge else "accumulator"
	var inputs: Dictionary = building.get("input_buffer", {})
	var outputs: Dictionary = building.get("output_buffer", {})
	var stored := clampf(float(building.get("stored_energy_mj", 0)), 0, CELL_ENERGY_MJ)
	var active := 1 if stored > SOURCE_ENERGY_EPSILON else 0
	var queued := floori(float(inputs.get(input, 0)) + SOURCE_ENERGY_EPSILON)
	var capacity := float(DataManager.get_building(String(building.type)).get("output_buffer_capacity", 120))
	var usable := mini(active + queued, floori(maxf(0, capacity - float(outputs.get(output, 0))) + SOURCE_ENERGY_EPSILON))
	if usable < 1: return 0
	var available := maxf(0, usable * CELL_ENERGY_MJ - stored) if charge else stored + maxi(0, usable - active) * CELL_ENERGY_MJ
	var applied := minf(maxf(0, energy), available)
	if applied <= SOURCE_ENERGY_EPSILON: return 0
	var consumed := 0
	var completed := 0
	var residual := 0.0
	if charge:
		var total := stored + applied
		completed = mini(usable, floori((total + SOURCE_ENERGY_EPSILON) / CELL_ENERGY_MJ))
		residual = maxf(0, total - completed * CELL_ENERGY_MJ)
		if residual <= SOURCE_ENERGY_EPSILON: residual = 0
		consumed = mini(queued, maxi(0, completed + (1 if residual > SOURCE_ENERGY_EPSILON else 0) - active))
	else:
		var needed := maxf(0, applied - stored)
		consumed = mini(queued, ceili(maxf(0, needed - SOURCE_ENERGY_EPSILON) / CELL_ENERGY_MJ)) if needed > SOURCE_ENERGY_EPSILON else 0
		residual = maxf(0, stored + consumed * CELL_ENERGY_MJ - applied)
		if residual <= SOURCE_ENERGY_EPSILON: residual = 0
		completed = maxi(0, active + consumed - (1 if residual > SOURCE_ENERGY_EPSILON else 0))
	if consumed > 0:
		var raw_input := float(inputs.get(input, 0))
		inputs[input] = maxf(0, raw_input - consumed) if absf(raw_input - queued) > SOURCE_ENERGY_EPSILON else float(queued - consumed)
	outputs[output] = normalize_source_cell_output(float(outputs.get(output, 0)) + completed)
	building.input_buffer = inputs
	building.output_buffer = outputs
	building.stored_energy_mj = floorf(residual * 1000000.0 + 0.5) / 1000000.0
	var phase := residual / CELL_ENERGY_MJ if charge else 1.0 - residual / CELL_ENERGY_MJ if residual > SOURCE_ENERGY_EPSILON else 0.0
	building.progress = phase * float(DataManager.get_recipe(String(building.get("recipe_id", ""))).get("duration", 2.0))
	if statistics != null:
		if consumed > 0: statistics.record_consumed(input, consumed, building.id, building.planet_id)
		if completed > 0: statistics.record_produced(output, completed, building.id, building.planet_id)
	return completed

static func normalize_source_cell_output(amount: float) -> float:
	# Source rounds whole cells; continuous local belts retain owned transport fractions.
	var whole := floorf(amount)
	return whole if amount - whole <= SOURCE_ENERGY_EPSILON else amount

static func _failure(message: String) -> Dictionary:
	return {"ok": false, "reason": "invalid_power_configuration", "message": message}

static func kind_id(building: Dictionary) -> String:
	return String(DataManager.get_building(String(building.get("type", ""))).get("source_id", building.get("type", "")))

static func energy_recipe(building: Dictionary, mode: String) -> String:
	if mode == "idle": return ""
	if String(building.get("type", "")).begins_with("dsp_"): return "dsp_accumulator_charge" if mode == "charge" else "dsp_accumulator_discharge"
	return "charge_accumulator" if mode == "charge" else "discharge_accumulator"
