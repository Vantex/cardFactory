class_name StationSystem
extends RefCounted

const TYPES := ["planetary_logistics_station", "interstellar_logistics_station"]
const FLEET_ITEMS := ["logistics_drone", "logistics_vessel", "space_warper"]
var game_state: GameState

func _init(state: GameState) -> void:
	game_state = state

static func empty_station() -> Dictionary:
	var slots: Array = []
	for i in range(4):
		slots.append({"item_id": "", "mode": "storage", "capacity": 100.0, "min_load": 0.1, "priority": 0, "amount": 0.0, "cursor": 0})
	return {"enabled": true, "slots": slots, "fleet": {"logistics_drone": 0, "logistics_vessel": 0, "space_warper": 0}}

func get_station_info(id: String) -> Dictionary:
	return game_state.buildings.get(id, {}).get("station", {}).duplicate(true)

func has_route(id: String) -> bool:
	for route in game_state.logistics_routes.values():
		if route.source_id == id or route.target_id == id:
			return true
	return false

func configure_slots(ids: Array, index: int, item: String, mode: String, capacity: float, min_load: float, priority: int) -> Dictionary:
	if ids.is_empty() or index < 0 or index >= 4 or (item != "" and DataManager.get_item(item).is_empty()) or mode not in ["supply", "demand", "storage"]:
		return result(false, "槽位、物品或模式无效")
	if not is_finite(capacity) or capacity < 1 or capacity > 999 or not is_finite(min_load) or min_load < 0.01 or min_load > 1 or priority < 0 or priority > 2:
		return result(false, "容量、最低装载或优先级无效")
	var seen := {}
	for id in ids:
		if seen.has(id) or not _editable(id):
			return result(false, "只能配置当前行星未锁定的物流站")
		seen[id] = true
		var slot: Dictionary = game_state.buildings[id].station.slots[index]
		if has_route(id):
			return result(false, "请等待关联航线返航后再配置")
		if slot.amount > capacity or (slot.item_id != item and slot.amount > 0):
			return result(false, "请先取空槽位物资")
		for other_index in range(4):
			if other_index != index and item != "" and game_state.buildings[id].station.slots[other_index].item_id == item:
				return result(false, "同站物品不能重复配置")
		if slot.item_id != item:
			var building: Dictionary = game_state.buildings[id]
			if float(building.input_buffer.get(slot.item_id, 0)) > 0 or float(building.output_buffer.get(slot.item_id, 0)) > 0:
				return result(false, "请先清空该物品的输入和输出缓存")
			for connection in game_state.get_connections_for_building(id):
				if connection.item_id == slot.item_id:
					return result(false, "请先拆除该物品线路")
	for id in ids:
		var slot: Dictionary = game_state.buildings[id].station.slots[index]
		slot.merge({"item_id": item, "mode": mode, "capacity": capacity, "min_load": min_load, "priority": priority}, true)
	return result(true, "物流槽位已配置")

func transfer_cargo(id: String, index: int, amount: float, deposit: bool) -> Dictionary:
	if not _editable(id) or index < 0 or index >= 4 or not is_finite(amount) or amount <= 0:
		return result(false, "物流转移参数无效")
	var slot: Dictionary = game_state.buildings[id].station.slots[index]
	var inventory := InventorySystem.new(game_state)
	if slot.item_id == "":
		return result(false, "请先配置物品")
	if deposit:
		if float(slot.amount) + amount + reserved(id, index) > float(slot.capacity):
			return result(false, "槽位容量不足（含在途预留）")
		var removed := inventory.try_remove(slot.item_id, amount)
		if not removed.ok:
			return removed
		slot.amount += amount
	else:
		if float(slot.amount) < amount:
			return result(false, "槽位库存不足")
		var added := inventory.try_add(slot.item_id, amount)
		if not added.ok:
			return added
		slot.amount -= amount
	return result(true, "货物已转移")

func transfer_fleet(id: String, item: String, count: int, deposit: bool) -> Dictionary:
	if not _editable(id) or item not in FLEET_ITEMS or count <= 0:
		return result(false, "载具转移参数无效")
	var building: Dictionary = game_state.buildings[id]
	if building.type == TYPES[0] and item != "logistics_drone":
		return result(false, "行星站仅支持运输机")
	var fleet: Dictionary = building.station.fleet
	var inventory := InventorySystem.new(game_state)
	if deposit:
		var occupied := int(fleet[item])
		for route in game_state.logistics_routes.values():
			if route.source_id == id and route.vehicle == item:
				occupied += 1
		if occupied + count > 999:
			return result(false, "机库容量不足")
		var removed := inventory.try_remove(item, count)
		if not removed.ok:
			return removed
		fleet[item] += count
	else:
		if int(fleet[item]) < count:
			return result(false, "停泊载具或翘曲器不足")
		var added := inventory.try_add(item, count)
		if not added.ok:
			return added
		fleet[item] -= count
	return result(true, "载具/翘曲器已转移")

func reserved(id: String, index: int) -> float:
	var amount := 0.0
	for route in game_state.logistics_routes.values():
		if route.target_id == id and int(route.target_slot) == index:
			amount += float(route.amount)
	return amount

func _editable(id: String) -> bool:
	var b: Dictionary = game_state.buildings.get(id, {})
	return b.has("station") and b.get("planet_id", "") == game_state.active_planet_id and not b.get("interaction_locked", false)

static func result(ok: bool, message: String) -> Dictionary:
	return {"ok": ok, "message": message}




func set_enabled(ids: Array, enabled: bool) -> Dictionary:
	if ids.is_empty():
		return result(false, "请选择物流站")
	for id in ids:
		if not _editable(id):
			return result(false, "只能控制当前行星未锁定的物流站")
	for id in ids:
		game_state.buildings[id].station.enabled = enabled
	return result(true, "已启用调度" if enabled else "已停发，现有航线继续送达和返航")
