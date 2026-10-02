class_name StationContractSystem
extends RefCounted

const ACCEPT_LIMIT := 3
const HISTORY_LIMIT := 48
const DAY_MS := 86400000
const OFFSET_MS := 28800000
const CANDIDATES := {
	"titanium_alloy": {"weight": 4, "tech": "titanium_alloy", "kind": "industrial"},
	"processor": {"weight": 3, "tech": "processor", "kind": "industrial"},
	"particle_container": {"weight": 6, "tech": "miniature_particle_collider", "kind": "industrial"},
	"titanium_glass": {"weight": 5, "tech": "information_matrix", "kind": "industrial"},
	"particle_broadband": {"weight": 8, "tech": "information_matrix", "kind": "industrial"},
	"plastic": {"weight": 2, "tech": "basic_chemical_engineering", "kind": "industrial"},
	"space_warper": {"weight": 12, "tech": "space_warp", "kind": "advanced"},
	"frame_material": {"weight": 10, "tech": "dyson_sphere_program", "kind": "dyson"},
	"solar_sail": {"weight": 5, "tech": "dyson_swarm", "kind": "dyson"},
	"small_carrier_rocket": {"weight": 45, "tech": "vertical_launching_silo", "kind": "dyson"},
	"quantum_chip": {"weight": 14, "tech": "quantum_chip", "kind": "advanced"},
	"antimatter_fuel_rod": {"weight": 40, "tech": "artificial_star", "kind": "advanced"},
	"universe_matrix": {"weight": 60, "tech": "universe_matrix", "kind": "advanced"},
}
const UNITS := {"P1": 18000, "P2": 48000, "P3": 120000}
const REWARDS := {"P1": [45, 30, 20, 15], "P2": [120, 80, 65, 40], "P3": [300, 200, 180, 120]}

var state: GameState

func _init(game_state: GameState) -> void:
	state = game_state

func unlocked() -> bool:
	return LocalSpaceStationSystem.new(state).snapshot().stage in ["showcase", "operational"]

func snapshot(now_ms: int = -1) -> Dictionary:
	var now := _wall_ms() if now_ms < 0 else now_ms
	var board := state.station_contracts.duplicate(true) if not state.station_contracts.is_empty() else _initial(now)
	if unlocked(): _advance_board(board, now)
	return {"unlocked": unlocked(), "board": board}

func accept(contract_id: String, now_ms: int = -1) -> Dictionary:
	if not unlocked(): return _result(false, "空间站船坞尚未建成")
	var board := _mutable_board(now_ms)
	if board.accepted.size() >= ACCEPT_LIMIT: return _result(false, "同时最多接受三个合同")
	for index in range(board.offers.size()):
		var contract: Dictionary = board.offers[index]
		if contract.id != contract_id or board.settled_ids.has(contract_id): continue
		board.offers.remove_at(index)
		contract.status = "accepted"
		board.accepted.append(contract)
		return _result(true, "合同已接受")
	return _result(false, "合同不存在或已经结算")

func deliver(contract_id: String, item_id: String, requested: int, planet_id: String = "") -> Dictionary:
	if not unlocked() or requested < 1 or not CANDIDATES.has(item_id): return _result(false, "合同交付参数无效")
	var board := _mutable_board(-1)
	var origin := state.active_planet_id if planet_id.is_empty() else planet_id
	if origin != state.active_planet_id: return _result(false, "只能从当前行星托盘手动交付")
	var amount := mini(requested, remaining(contract_id, item_id, "terminal", origin))
	if amount < 1: return _result(false, "合同不接受该物资、渠道或来源行星")
	var paid := InventorySystem.new(state).try_remove(item_id, amount, origin)
	if not paid.ok: return paid
	deliver_from_buffer(contract_id, item_id, amount, "terminal", origin)
	return _result(true, "已交付 %s ×%d" % [item_id, amount])

func deliver_quantum(contract_id: String, item: String, requested: int) -> Dictionary:
	if not unlocked() or requested < 1 or not state.quantum_network.get("enabled", false): return _result(false, "量子网络尚未启用")
	_mutable_board(-1)
	var stock := int(state.quantum_network.inventory.get(item, "0"))
	var amount := mini(requested, mini(stock, remaining(contract_id, item, "quantum")))
	if amount < 1: return _result(false, "量子库存或合同剩余需求不足")
	state.quantum_network.inventory[item] = str(stock - amount)
	deliver_from_buffer(contract_id, item, amount, "quantum")
	return _result(true, "已从量子库存确认交付 %d 件" % amount)

func remaining(contract_id: String, item: String, channel: String, origin: String = "") -> int:
	var total := 0
	for contract in state.station_contracts.get("accepted", []):
		if contract.id != contract_id or contract.status != "accepted": continue
		for entry in contract.requirements:
			if _accepts(entry, item, channel, origin): total += maxi(0, int(entry.amount) - int(entry.delivered))
	return total

func deliver_from_buffer(contract_id: String, item: String, requested: int, channel: String, origin: String = "") -> int:
	var left := maxi(0, requested)
	for contract in state.station_contracts.get("accepted", []):
		if contract.id != contract_id or contract.status != "accepted": continue
		for entry in contract.requirements:
			if not _accepts(entry, item, channel, origin): continue
			var moved := mini(left, maxi(0, int(entry.amount) - int(entry.delivered)))
			entry.delivered += moved
			left -= moved
		var complete := true
		for entry in contract.requirements:
			if int(entry.delivered) < int(entry.amount): complete = false
		if complete: contract.status = "claimable"
	return requested - left

static func _accepts(entry: Dictionary, item: String, channel: String, origin: String) -> bool:
	if entry.item != item or channel not in ["terminal", "quantum"]: return false
	if channel == "quantum": return true
	return entry.channel != "quantum" and (entry.source_planet_ids.is_empty() or entry.source_planet_ids.has(origin))

func claim(contract_id: String) -> Dictionary:
	var board := _mutable_board(-1)
	for contract in board.accepted:
		if contract.id == contract_id and contract.status == "claimable":
			_settle(board, contract, "completed")
			return _result(true, "合同完成，轨道印记和声望已结算")
	return _result(false, "合同尚未完成")

func abandon(contract_id: String) -> Dictionary:
	var board := _mutable_board(-1)
	for contract in board.accepted:
		if contract.id == contract_id:
			_settle(board, contract, "completed" if contract.status == "claimable" else "abandoned")
			return _result(true, "合同已结算")
	return _result(false, "没有该已接受合同")

func _mutable_board(now_ms: int) -> Dictionary:
	var now := _wall_ms() if now_ms < 0 else now_ms
	if state.station_contracts.is_empty(): state.station_contracts = _initial(now)
	_advance_board(state.station_contracts, now)
	return state.station_contracts

func _advance_board(board: Dictionary, now_ms: int) -> void:
	var day := maxi(int(board.task_day), day_index(maxi(now_ms, int(board.last_confirmed_ms))))
	board.last_confirmed_ms = maxi(int(board.last_confirmed_ms), now_ms)
	if day > int(board.task_day):
		board.task_day = day
		for contract in board.accepted.duplicate():
			if int(contract.expires_day) <= day: _settle(board, contract, "completed" if contract.status == "claimable" else "expired")
		board.offers.clear()
	if board.offers.is_empty():
		for slot in range(4): board.offers.append(_create_offer(day, slot))

func _create_offer(day: int, slot: int) -> Dictionary:
	var available := []
	var produced: Dictionary = state.progression_facts.get("produced", {})
	for item in CANDIDATES:
		if float(produced.get(item, 0)) > 0 or state.completed_technologies.has("dsp_" + String(CANDIDATES[item].tech)): available.append(item)
	if available.is_empty(): available = ["titanium_alloy", "processor"]
	var planets: Array = state.colonized_planet_ids.filter(func(id): return GalaxySystem.new(state).get_planet(id).kind != "gas_giant")
	var templates := ["advanced", "quantum", "dyson"] if state.quantum_network.get("enabled", false) else ["advanced", "dyson", "combination"]
	if slot != 3:
		templates = ["single", "combination", "dyson"]
		if not planets.is_empty(): templates.append("origin")
		if planets.size() > 1: templates.append("multi-origin")
		if state.quantum_network.get("enabled", false): templates.append("quantum")
	var roll := _index(day, slot, "difficulty", 10)
	var difficulty := "P3" if slot == 3 or roll == 9 else "P2" if roll >= 5 else "P1"
	var template: String = templates[_index(day, slot, "template", templates.size())]
	var pool := available.duplicate()
	if template == "dyson": pool = available.filter(func(item: String): return CANDIDATES[item].kind == "dyson")
	if template in ["advanced", "quantum"]: pool = available.filter(func(item: String): return CANDIDATES[item].kind == "advanced")
	if template == "combination": pool = available.filter(func(item: String): return CANDIDATES[item].kind == "industrial")
	var count := 1 if template in ["single", "origin"] else 2 if template != "combination" or difficulty == "P1" else 3
	if template == "dyson": count = mini(2, maxi(1, pool.size()))
	if template == "quantum": count = 2 if difficulty == "P3" else 1
	if pool.is_empty(): pool = available.duplicate()
	var selected := _rotate_pick(pool, count, day, slot, "origin:item" if template == "origin" else "multi:items" if template == "multi-origin" else template)
	var origins := _rotate_pick(planets, 2 if template == "multi-origin" else 1, day, slot, "multi:planets" if template == "multi-origin" else "origin:planet")
	var requirements := []
	for index in range(origins.size() if template == "multi-origin" else selected.size()):
		var item: String = selected[index % selected.size()]
		var weight := int(CANDIDATES[item].weight)
		var multiplier := 1.0 if template in ["single", "origin"] else 0.65 if template == "multi-origin" else 0.7 if template in ["combination", "quantum"] else 0.8
		var amount := maxi(100, int(floorf(float(UNITS[difficulty]) * multiplier / weight / 100.0)) * 100)
		requirements.append({"item": item, "amount": amount, "delivered": 0, "channel": "terminal" if template in ["origin", "multi-origin"] else "quantum" if template == "quantum" else "any", "source_planet_ids": [origins[index]] if template in ["origin", "multi-origin"] else [], "weight": weight})
	var reward: Array = REWARDS[difficulty]
	var special := 2 if slot == 3 else 1
	return {"id": "station-contract-v1-%d-%d-%d-%s" % [state.galaxy_seed, day, slot, template], "slot": slot, "task_day": day, "expires_day": day + 3, "template": template, "difficulty": difficulty, "status": "offered", "requirements": requirements, "reward": [reward[0] * special, reward[1] * special, reward[2] * special, reward[3] * special]}

func _index(day: int, slot: int, key: String, count: int) -> int:
	if count <= 1: return 0
	var hashed := SourceGalaxySystem.hash_text("%d|%d|%d|1|%s" % [state.galaxy_seed, day, slot, key])
	return (hashed ^ (hashed >> 16)) % count

func _rotate_pick(values: Array, count: int, day: int, slot: int, key: String) -> Array:
	if values.is_empty() or count < 1: return []
	var start := _index(day, slot, key, values.size())
	var step := 1 + _index(day, slot, key + ":step", values.size() - 1) if values.size() > 1 else 1
	var selected := []
	var seen := {}
	for cursor in range(values.size() * 2):
		if selected.size() >= mini(count, values.size()): break
		var index := (start + cursor * step) % values.size()
		if seen.has(index): continue
		seen[index] = true
		selected.append(values[index])
	for index in range(values.size()):
		if selected.size() >= mini(count, values.size()): break
		if not seen.has(index): selected.append(values[index])
	return selected

func _settle(board: Dictionary, contract: Dictionary, reason: String) -> void:
	if board.settled_ids.has(contract.id): return
	var weighted := 0
	var total_weight := 0
	for requirement in contract.requirements:
		weighted += int(floorf(10000.0 * int(requirement.delivered) / maxi(1, int(requirement.amount)))) * int(requirement.weight)
		total_weight += int(requirement.weight)
	var basis := int(floorf(float(weighted) / maxi(1, total_weight)))
	var completed := reason == "completed" and basis == 10000
	board.marks = HubInteger.add(economy_text(board.marks), str(int(floorf(float(contract.reward[0]) * basis / 10000.0)) + (int(contract.reward[2]) if completed else 0)))
	board.reputation = HubInteger.add(economy_text(board.reputation), str(int(floorf(float(contract.reward[1]) * basis / 10000.0)) + (int(contract.reward[3]) if completed else 0)))
	if completed: board.completed += 1
	contract.status = "settled"
	contract["settlement_reason"] = reason
	contract["completion_basis_points"] = basis
	board.settled_ids.append(contract.id)
	if board.settled_ids.size() > 4096: board.settled_ids.pop_front()
	board.accepted.erase(contract)
	board.history.push_front(contract)
	if board.history.size() > HISTORY_LIMIT: board.history.resize(HISTORY_LIMIT)
	if board.get("featured_id", "") != "" and not board.history.any(func(entry): return entry.id == board.featured_id): board.featured_id = ""

static func _initial(now_ms: int) -> Dictionary:
	return {"version": 1, "task_day": day_index(now_ms), "last_confirmed_ms": now_ms, "offers": [], "accepted": [], "history": [], "settled_ids": [], "marks": "0", "reputation": "0", "completed": 0}

static func day_index(now_ms: int) -> int:
	return int(floorf(float(maxi(0, now_ms) + OFFSET_MS) / DAY_MS))

static func _wall_ms() -> int:
	return int(Time.get_unix_time_from_system() * 1000.0)

static func validate(data: Dictionary) -> Array:
	var value: Variant = data.get("station_contracts", {})
	if not value is Dictionary: return ["空间站合同板必须是字典"]
	if value.is_empty(): return []
	var errors := []
	if value.size() != 10 + (1 if value.has("featured_id") else 0) or value.get("version") != 1: errors.append("空间站合同板版本或字段无效")
	for field in ["marks", "reputation"]:
		if not HubInteger.valid(value.get(field)) and not (GalacticExportSystem._nonnegative_integer(value.get(field)) and float(value[field]) <= 9007199254740991): errors.append("合同经济必须为 256 位以内精确整数")
	for field in ["task_day", "last_confirmed_ms", "completed"]:
		if not GalacticExportSystem._nonnegative_integer(value.get(field)): errors.append("空间站合同板累计值无效")
	for field in ["offers", "accepted", "history", "settled_ids"]:
		if not value.get(field) is Array: return errors + ["空间站合同集合无效"]
	if value.offers.size() > 4 or value.accepted.size() > ACCEPT_LIMIT or value.history.size() > HISTORY_LIMIT or value.settled_ids.size() > 4096: errors.append("空间站合同集合超限")
	var seen := {}
	for field in ["offers", "accepted", "history"]:
		for contract in value[field]:
			if not contract is Dictionary or not contract.get("id") is String or seen.has(contract.get("id")) or contract.get("status") not in (["offered"] if field == "offers" else ["accepted", "claimable"] if field == "accepted" else ["settled"]) or not contract.get("requirements") is Array or not contract.get("reward") is Array:
				errors.append("空间站合同记录无效")
				continue
			seen[contract.id] = true
			if not contract.get("template") in ["single", "combination", "dyson", "origin", "multi-origin", "quantum", "advanced"] or not UNITS.has(contract.get("difficulty")) or not GalacticExportSystem._nonnegative_integer(contract.get("slot")) or float(contract.get("slot", 99)) > 3 or not GalacticExportSystem._nonnegative_integer(contract.get("task_day")) or not GalacticExportSystem._nonnegative_integer(contract.get("expires_day")) or float(contract.get("expires_day", 0)) < float(contract.get("task_day", 0)): errors.append("空间站合同模板或期限无效")
			if contract.requirements.is_empty() or contract.requirements.size() > 6 or contract.reward.size() != 4: errors.append("空间站合同材料或奖励数量无效")
			for reward in contract.reward:
				if not GalacticExportSystem._nonnegative_integer(reward) or float(reward) > 1000000: errors.append("空间站合同奖励无效")
			for requirement in contract.requirements:
				if not requirement is Dictionary or not CANDIDATES.has(requirement.get("item")) or not GalacticExportSystem._nonnegative_integer(requirement.get("amount")) or float(requirement.get("amount", 0)) < 1 or float(requirement.get("amount", 0)) > 1000000 or not GalacticExportSystem._nonnegative_integer(requirement.get("delivered")) or float(requirement.get("delivered", 0)) > float(requirement.get("amount", 0)):
					errors.append("空间站合同材料无效")
					continue
				if requirement.get("channel") not in ["any", "terminal", "quantum"] or not GalacticExportSystem._nonnegative_integer(requirement.get("weight")) or int(requirement.get("weight", 0)) != int(CANDIDATES[requirement.item].weight) or not requirement.get("source_planet_ids") is Array:
					errors.append("空间站合同渠道无效")
					continue
				if requirement.source_planet_ids.size() > 4: errors.append("空间站合同来源超限")
				for origin in requirement.source_planet_ids:
					if not origin is String or not SourceGalaxySystem.catalog().planets.has(origin): errors.append("空间站合同来源无效")
	for id in value.settled_ids:
		if not id is String or id.is_empty() or id.length() > 180: errors.append("空间站合同结算标识无效")
	if value.has("featured_id"):
		if not value.featured_id is String or (value.featured_id != "" and not value.history.any(func(contract): return contract is Dictionary and contract.get("id") == value.featured_id and contract.get("settlement_reason") == "completed")): errors.append("精选合同必须来自已完成历史")
	if data.get("save_mode", "normal") == "speedrun": errors.append("速通存档不能保留空间站合同")
	return errors

static func _result(ok: bool, message: String) -> Dictionary:
	return {"ok": ok, "message": message}

static func economy_text(value: Variant) -> String:
	return value if value is String else str(int(value))

func set_featured(contract_id: String) -> Dictionary:
	if not unlocked(): return _result(false, "空间站合同尚未解锁")
	var board := _mutable_board(-1)
	if contract_id != "" and not board.history.any(func(contract): return contract.id == contract_id and contract.get("settlement_reason") == "completed"): return _result(false, "只能展示已完成的历史合同")
	board.featured_id = contract_id
	return _result(true, "精选合同已更新")
