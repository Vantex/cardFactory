extends RefCounted

const OUTPUT := preload("res://scripts/game/SourceResourceOutputSystem.gd")
const MAX_COUNT := 100000000
const MAX_SAFE_INTEGER := 9007199254740991.0
var state: GameState

func _init(game_state: GameState) -> void:
	state = game_state

func install(site_id: String, requested: Variant = 1) -> Dictionary:
	var site: Dictionary = state.resource_sites.get(site_id, {})
	if state.source_galaxy.is_empty() or site.is_empty() or not DataManager.all_items.has(String(site.get("item_id", ""))): return _failure("请选择有效的源版资源点")
	if site.get("interaction_locked", false): return _failure("资源点配置已锁定")
	if not _safe_integer(requested) or requested < 1: return _failure("新增数量必须是正安全整数")
	var groups := OUTPUT.extractors(state, site_id)
	var current := 0.0
	for group in groups:
		var count: Variant = group.get("machine_count", 1)
		if group.get("interaction_locked", false): return _failure("采集设备配置已锁定")
		if not _safe_integer(count) or count < 0: return _failure("原有设备数量无效")
		current += float(count)
	if not _safe_integer(current) or not _safe_integer(current + requested): return _failure("设备数量超出安全整数范围")
	if current + requested > MAX_COUNT: return _failure("采集设备最多安装一亿台；旧超限数量保留")
	var type := OUTPUT.extractor_type(String(site.item_id))
	var stock: Variant = state.construction_inventory.get(type, 0)
	if not (stock is int or stock is float) or not is_finite(float(stock)) or stock < requested: return _failure("采集设备施工件不足")
	# A source vein is one group. Add paid units to its existing native carrier
	# without replacing real output buffers, phase, connections or other carriers.
	if not groups.is_empty():
		groups[0].machine_count = float(groups[0].get("machine_count", 1)) + requested
	else:
		var definition := DataManager.get_building(type)
		state.add_building({"type": type, "position": site.position, "planet_id": site.planet_id, "resource_site_id": site_id, "output_item": site.item_id, "machine_count": requested, "status": "idle", "recipe_id": "", "input_buffer": {}, "output_buffer": {}, "progress": float(site.get("progress", 0)), "speed": definition.get("speed", 1.0)})
	state.construction_inventory[type] = float(stock) - requested
	return {"ok": true, "message": "已安装 %d 台%s" % [int(requested), DataManager.get_building(type).get("name", type)], "amount": requested}

static func _safe_integer(value: Variant) -> bool:
	return (value is int or value is float) and is_finite(float(value)) and float(value) == floorf(float(value)) and absf(float(value)) <= MAX_SAFE_INTEGER

func _failure(message: String) -> Dictionary:
	return {"ok": false, "message": message}
