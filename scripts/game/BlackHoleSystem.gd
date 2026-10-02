class_name BlackHoleSystem
extends RefCounted

const TYPE := "dsp_micro_black_hole_connector"
const PORT_COUNT := 3

var state: GameState

static func empty_ports() -> Array:
	return [{"index": 0, "item_id": "", "total_destroyed": "0"}, {"index": 1, "item_id": "", "total_destroyed": "0"}, {"index": 2, "item_id": "", "total_destroyed": "0"}]

func _init(game_state: GameState) -> void:
	state = game_state

func set_paused(id: String, paused: bool, confirm_activation: bool = false) -> Dictionary:
	var building: Dictionary = state.buildings.get(id, {})
	if building.get("type") != TYPE or building.get("interaction_locked", false): return {"ok": false, "message": "请选择未锁定的微型黑洞连接器"}
	if not paused and not building.get("black_hole_activation_confirmed", false) and not confirm_activation: return {"ok": false, "message": "首次启动必须确认不可逆的物资销毁"}
	building.black_hole_paused = paused
	if not paused and confirm_activation: building.black_hole_activation_confirmed = true
	return {"ok": true, "message": "黑洞已暂停" if paused else "黑洞已启动，输入物资会永久销毁"}

static func record_transfer(building: Dictionary, port: int, item_id: String, amount: int) -> bool:
	if building.get("type") != TYPE or building.get("black_hole_paused", true) or not building.get("black_hole_activation_confirmed", false) or port < 0 or port >= PORT_COUNT or DataManager.get_item(item_id).is_empty() or amount <= 0: return false
	var totals: Array = building.get("black_hole_ports", [])
	if totals.size() != PORT_COUNT: return false
	var entry: Dictionary = totals[port]
	if entry.get("index") != port or not _decimal_valid(entry.get("total_destroyed")): return false
	entry.item_id = item_id
	entry.total_destroyed = _add_decimal(entry.total_destroyed, amount)
	return true

static func _add_decimal(value: String, amount: int) -> String:
	var output := ""
	var carry := amount
	for index in range(value.length() - 1, -1, -1):
		carry += int(value.substr(index, 1))
		output = str(carry % 10) + output
		carry = int(carry / 10)
	while carry > 0:
		output = str(carry % 10) + output
		carry = int(carry / 10)
	return output

static func _decimal_valid(value: Variant) -> bool:
	if not value is String or value.is_empty() or value.length() > 256 or (value.length() > 1 and value.begins_with("0")): return false
	for index in range(value.length()):
		if value.unicode_at(index) < 48 or value.unicode_at(index) > 57: return false
	return true

static func validate(data: Dictionary) -> Array:
	var errors := []
	var buildings: Variant = data.get("buildings", {})
	var connections: Variant = data.get("connections", {})
	if not buildings is Dictionary or not connections is Dictionary: return errors
	for building in buildings.values():
		if not building is Dictionary: continue
		if building.get("type") != TYPE:
			if building.has("black_hole_ports") or building.has("black_hole_paused") or building.has("black_hole_activation_confirmed"): errors.append("非黑洞设备含销毁状态")
			continue
		if not building.get("black_hole_paused", true) is bool or not building.get("black_hole_activation_confirmed", false) is bool: errors.append("黑洞启停状态无效")
		if building.get("black_hole_paused", true) == false and not building.get("black_hole_activation_confirmed", false): errors.append("黑洞未确认即启动")
		var ports: Variant = building.get("black_hole_ports", empty_ports())
		if not ports is Array or ports.size() != PORT_COUNT:
			errors.append("黑洞端口记录无效")
			continue
		for index in range(PORT_COUNT):
			var entry: Variant = ports[index]
			if not entry is Dictionary or entry.size() != 3 or entry.get("index") != index or not entry.get("item_id") is String or (not String(entry.get("item_id")).is_empty() and DataManager.get_item(entry.item_id).is_empty()) or not _decimal_valid(entry.get("total_destroyed")): errors.append("黑洞端口记录无效")
	var occupied := {}
	for connection in connections.values():
		if not connection is Dictionary: continue
		for field in ["black_hole_credit", "quantum_credit"]:
			if not connection.has(field): continue
			var credit: Variant = connection[field]
			if not (credit is int or credit is float) or not is_finite(float(credit)) or float(credit) < 0 or float(credit) > 1: errors.append("线路整件传输余数无效")
		var target: Dictionary = buildings.get(connection.get("target_id", ""), {})
		if target.get("type") == TYPE:
			var port: Variant = connection.get("target_port_index")
			if not (port is int or port is float) or not is_finite(float(port)) or float(port) != floorf(float(port)) or int(port) < 0 or int(port) >= PORT_COUNT:
				errors.append("黑洞连接端口无效")
				continue
			var key := str(connection.target_id) + ":" + str(int(port))
			if occupied.has(key): errors.append("黑洞输入端口重复占用")
			occupied[key] = true
	return errors
