class_name StorageBufferSystem
extends RefCounted
var state: GameState
func _init(game_state: GameState) -> void: state = game_state
func configure(id: String, item: String, mode: String = "balanced") -> Dictionary:
	var building: Dictionary = state.buildings.get(id, {})
	var definition := DataManager.get_building(building.get("type", ""))
	if definition.get("kind") not in ["storage", "splitter"] or building.get("planet_id") != state.active_planet_id or building.get("interaction_locked", false) or DataManager.get_item(item).is_empty() or mode not in ["balanced", "priority"]: return {"ok": false, "message": "仓储或分流器配置无效"}
	var accepts: String = definition.get("accepts", "any")
	if accepts != "any" and DataManager.get_item(item).get("kind", "solid") != accepts: return {"ok": false, "message": "物品类型不被该设备接收"}
	if building.get("stored_item", "") != item:
		if not state.get_connections_for_building(id).is_empty(): return {"ok": false, "message": "更换物品前请先拆除线路"}
		for direction in ["input_buffer", "output_buffer"]:
			for amount in building.get(direction, {}).values():
				if float(amount) > 0: return {"ok": false, "message": "更换物品前请先清空缓存"}
	building.stored_item = item
	building.distribution_mode = mode
	return {"ok": true, "message": "物品与分流方式已配置"}