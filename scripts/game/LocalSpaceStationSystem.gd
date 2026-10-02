class_name LocalSpaceStationSystem
extends RefCounted

const STAGES := ["core", "dock", "showcase"]
const COSTS := {
	"core": {"titanium_alloy": 200000, "frame_material": 100000, "processor": 200000, "universe_matrix": 20000},
	"dock": {"quantum_chip": 100000, "particle_container": 200000, "space_warper": 20000, "logistics_vessel": 200},
	"showcase": {"titanium_glass": 300000, "particle_broadband": 200000, "plastic": 500000, "universe_matrix": 50000},
}

var state: GameState

func _init(game_state: GameState) -> void:
	state = game_state

func snapshot() -> Dictionary:
	var station := state.orbital_station if not state.orbital_station.is_empty() else _initial_state()
	var stage := String(station.get("stage", "locked"))
	if stage == "locked" and _eligible(): stage = "eligible"
	var costs: Dictionary = COSTS.get("core" if stage == "eligible" else stage, {})
	var remaining := {}
	for item in costs:
		remaining[item] = int(costs[item]) - int(station.delivered.get("core" if stage == "eligible" else stage, {}).get(item, 0))
	return {"stage": stage, "remaining": remaining, "delivered": station.delivered.duplicate(true), "eligible": _eligible()}

func start() -> Dictionary:
	_ensure_state()
	if state.orbital_station.stage != "eligible": return _result(false, "空间站尚未解锁或已开始建设")
	state.orbital_station.stage = "core"
	return _result(true, "轨道空间站核心建设已开始")

func deliver(item_id: String, requested: int) -> Dictionary:
	_ensure_state()
	var stage := String(state.orbital_station.stage)
	if stage == "eligible": stage = "core"
	var costs: Dictionary = COSTS.get(stage, {})
	if requested < 1 or not costs.has(item_id): return _result(false, "当前阶段不需要该物资")
	var delivered: Dictionary = state.orbital_station.delivered.get(stage, {})
	var remaining := int(costs[item_id]) - int(delivered.get(item_id, 0))
	if remaining <= 0: return _result(false, "该物资已经交齐")
	var accepted := mini(requested, remaining)
	if item_id == "logistics_vessel":
		if int(state.portable_fleet.get(item_id, 0)) < accepted: return _result(false, "随身舰队载具不足")
		state.portable_fleet[item_id] -= accepted
	else:
		var paid := InventorySystem.new(state).try_remove(item_id, accepted)
		if not paid.ok: return paid
	deliver_from_buffer(item_id, accepted)
	return _result(true, "已交付 %s ×%d" % [item_id, accepted])

func deliver_quantum(item: String, requested: int) -> Dictionary:
	if requested < 1 or not state.quantum_network.get("enabled", false): return _result(false, "量子网络尚未启用")
	var need := int(snapshot().remaining.get(item, 0))
	var stock := int(state.quantum_network.inventory.get(item, "0"))
	var accepted := mini(requested, mini(need, stock))
	if accepted < 1: return _result(false, "量子库存或当前阶段剩余需求不足")
	state.quantum_network.inventory[item] = str(stock - accepted)
	deliver_from_buffer(item, accepted)
	return _result(true, "已从量子库存确认交付 %d 件" % accepted)

func deliver_from_buffer(item_id: String, requested: int) -> int:
	_ensure_state()
	var stage := String(state.orbital_station.stage)
	if stage == "eligible": stage = "core"
	var costs: Dictionary = COSTS.get(stage, {})
	if not costs.has(item_id) or requested < 1: return 0
	var delivered: Dictionary = state.orbital_station.delivered.get(stage, {})
	var accepted := mini(requested, maxi(0, int(costs[item_id]) - int(delivered.get(item_id, 0))))
	if accepted < 1: return 0
	state.orbital_station.stage = stage
	delivered[item_id] = int(delivered.get(item_id, 0)) + accepted
	state.orbital_station.delivered[stage] = delivered
	var complete := true
	for key in costs:
		if int(delivered.get(key, 0)) < int(costs[key]): complete = false
	if complete:
		var index := STAGES.find(stage)
		state.orbital_station.stage = STAGES[index + 1] if index + 1 < STAGES.size() else "operational"
	return accepted

func _ensure_state() -> void:
	if state.orbital_station.is_empty(): state.orbital_station = _initial_state()
	if state.orbital_station.stage == "locked" and _eligible():
		state.orbital_station.stage = "eligible"

func _eligible() -> bool:
	return state.save_mode == "normal" and float(state.progression_facts.get("produced", {}).get("universe_matrix", 0)) >= 1

static func _initial_state() -> Dictionary:
	return {"version": 1, "stage": "locked", "delivered": {"core": {}, "dock": {}, "showcase": {}}}

static func validate(data: Dictionary) -> Array:
	var errors := []
	var value: Variant = data.get("orbital_station", {})
	if not value is Dictionary: return ["轨道空间站状态必须是字典"]
	if value.is_empty(): return errors
	if value.keys().size() != 3 + (1 if value.has("presentation") else 0) or not value.has_all(["version", "stage", "delivered"]): errors.append("轨道空间站字段无效")
	if value.get("version") != 1: errors.append("轨道空间站版本无效")
	var stage: Variant = value.get("stage")
	if not stage is String or stage not in ["locked", "eligible", "core", "dock", "showcase", "operational"]: errors.append("轨道空间站阶段无效")
	if data.get("save_mode", "normal") == "speedrun" and stage != "locked": errors.append("速通存档不能建设本地空间站")
	var delivered: Variant = value.get("delivered")
	if not delivered is Dictionary: return errors + ["轨道空间站材料记录无效"]
	if delivered.size() != 3: errors.append("轨道空间站阶段材料记录无效")
	for stage_id in STAGES:
		var record: Variant = delivered.get(stage_id)
		if not record is Dictionary:
			errors.append("轨道空间站阶段材料记录无效")
			continue
		for item in record:
			var amount: Variant = record[item]
			if not COSTS[stage_id].has(item) or not (amount is int or amount is float) or not is_finite(float(amount)) or float(amount) != floorf(float(amount)) or float(amount) < 0 or float(amount) > float(COSTS[stage_id].get(item, 0)):
				errors.append("轨道空间站交付数量无效")
		if stage is String and stage in ["dock", "showcase", "operational"] and STAGES.find(stage_id) < STAGES.find(stage) or stage == "operational":
			for item in COSTS[stage_id]:
				if int(record.get(item, 0)) != int(COSTS[stage_id][item]): errors.append("已完成阶段材料不完整")
	return errors

static func _result(ok: bool, message: String) -> Dictionary:
	return {"ok": ok, "message": message}
