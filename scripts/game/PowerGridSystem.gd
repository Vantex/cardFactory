class_name PowerGridSystem
extends RefCounted

const GRIDS := ["grid-a", "grid-b", "grid-c"]
const CELL_ENERGY_MJ := 90.0
var state: GameState
func _init(game_state: GameState) -> void:
	state = game_state

static func grid_id(building: Dictionary) -> String:
	return String(building.get("power_grid_id", "grid-a"))

static func generation_priority(building: Dictionary) -> int:
	var definition := DataManager.get_building(String(building.get("type", "")))
	var fallback := 2 if building.get("type") == "energy_exchanger" else 1 if building.get("type") == "accumulator" or definition.has("fuel") else 3
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
	for id in ids:
		if not state.buildings.has(id) or seen.has(id): return _failure("建筑不存在或重复")
		seen[id] = true
		var building: Dictionary = state.buildings[id]
		if building.get("interaction_locked", false): return _failure("建筑已锁定")
		if changes.has("energy_mode"):
			if building.get("type") != "energy_exchanger": return _failure("只有能量枢纽可切换充放电模式")
			if float(building.get("stored_energy_mj", 0)) > 0: return _failure("请先完成当前蓄电器转换再切换模式")
	for id in ids:
		state.buildings[id].merge(changes, true)
		if changes.has("energy_mode"):
			state.buildings[id]["recipe_id"] = "charge_accumulator" if changes.energy_mode == "charge" else "discharge_accumulator" if changes.energy_mode == "discharge" else ""
	return {"ok": true, "message": "电力配置已更新"}

static func storage_capacity(building: Dictionary, delta: float, charge: bool) -> float:
	if delta <= 0: return 0
	var definition := DataManager.get_building(String(building.get("type", "")))
	var stored := float(building.get("stored_energy_mj", 0))
	var capacity := float(definition.get("energy_capacity_mj", 0))
	var energy := maxf(capacity - stored, 0) if charge else stored
	if building.get("type") == "energy_exchanger":
		if building.get("energy_mode", "charge") != ("charge" if charge else "discharge"): return 0
		var input := "accumulator" if charge else "charged_accumulator"
		var output := "charged_accumulator" if charge else "accumulator"
		var active := 1 if stored > 0 else 0
		var free := maxi(int(definition.get("output_buffer_capacity", 120)) - int(building.get("output_buffer", {}).get(output, 0)), 0)
		var cells := mini(active + int(building.get("input_buffer", {}).get(input, 0)), free)
		energy = maxf(cells * CELL_ENERGY_MJ - stored, 0) if charge else stored + maxi(cells - active, 0) * CELL_ENERGY_MJ
		if cells == 0: energy = 0
	return minf(float(definition.get("power_charge" if charge else "power_generation", 0)), energy * 1000.0 / delta)

static func apply_storage(building: Dictionary, energy: float, charge: bool, statistics: StatisticsSystem = null) -> void:
	var stored := float(building.get("stored_energy_mj", 0))
	if building.get("type") == "accumulator":
		building["stored_energy_mj"] = clampf(stored + (energy if charge else -energy), 0, CELL_ENERGY_MJ)
		return
	var input := "accumulator" if charge else "charged_accumulator"
	var output := "charged_accumulator" if charge else "accumulator"
	var inputs: Dictionary = building.get("input_buffer", {})
	var outputs: Dictionary = building.get("output_buffer", {})
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
			stored = 0
			if statistics != null: statistics.record_produced(output, 1, building.id, building.planet_id)
	building["stored_energy_mj"] = stored
	building["input_buffer"] = inputs
	building["output_buffer"] = outputs

static func _failure(message: String) -> Dictionary:
	return {"ok": false, "reason": "invalid_power_configuration", "message": message}
