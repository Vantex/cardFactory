class_name StationPresentationSystem
extends RefCounted

const ANCHORS := [Rect2(-400, -170, 260, 180), Rect2(-45, -245, 250, 150), Rect2(155, 5, 230, 150), Rect2(-135, 120, 250, 140), Rect2(-470, 130, 210, 130), Rect2(300, -240, 220, 130)]
const METRICS := ["total-generation", "peak-throughput", "dyson-power", "explored-systems", "colonized-planets", "universe-matrix-produced", "solar-sails-launched", "carrier-rockets-launched"]
static var _catalog: Dictionary = {}
var state: GameState
func _init(value: GameState) -> void: state = value

static func catalog() -> Dictionary:
	if _catalog.is_empty(): _catalog = JSON.parse_string(FileAccess.get_file_as_string("res://data/station/decorations.json"))
	return _catalog

static func definition(id: String, kind: String = "decorations") -> Dictionary:
	for row in catalog()[kind]:
		if row.id == id: return row
	return {}

static func initial() -> Dictionary:
	return {"version": 1, "unlocked": [], "theme": "orbital_teal", "placements": [], "viewport": {"x": 0.0, "y": 0.0, "zoom": 1.0}, "profile": {"title": "我的轨道空间站", "motto": "让每一条生产线通向群星。", "featured_metrics": ["total-generation", "peak-throughput", "dyson-power"]}, "featured_achievements": []}

func snapshot() -> Dictionary:
	return state.orbital_station.get("presentation", initial()).duplicate(true)

func level() -> Dictionary:
	var reputation := StationContractSystem.economy_text(state.station_contracts.get("reputation", "0"))
	var levels: Array = catalog().levels
	for index in range(levels.size() - 1, -1, -1):
		if DecimalCount.compare(reputation, levels[index].reputation) >= 0: return levels[index]
	return levels[0]

func _mutable() -> Dictionary:
	if state.orbital_station.is_empty(): state.orbital_station = LocalSpaceStationSystem._initial_state()
	if not state.orbital_station.has("presentation"): state.orbital_station.presentation = initial()
	return state.orbital_station.presentation

func operational() -> bool:
	return state.save_mode == "normal" and state.orbital_station.get("stage") == "operational"

func purchase(id: String, theme: bool = false) -> Dictionary:
	var row := definition(id, "themes" if theme else "decorations")
	var license_id := "theme:" + id if theme else id
	if not operational() or row.is_empty() or snapshot().unlocked.has(license_id) or int(level().level) < int(row.minimumLevel): return result(false, "空间站未运行、声望不足或已拥有授权")
	var marks := StationContractSystem.economy_text(state.station_contracts.get("marks", "0"))
	if DecimalCount.compare(marks, row.markCost) < 0: return result(false, "轨道印记不足")
	if state.station_contracts.is_empty(): state.station_contracts = StationContractSystem._initial(StationContractSystem._wall_ms())
	state.station_contracts.marks = HubInteger.subtract(marks, row.markCost)
	_mutable().unlocked.append(license_id)
	return result(true, "永久授权已购买；移除装饰后仍可再次摆放")

func placement_check(id: String, placement: Dictionary, excluded_id: String = "") -> Dictionary:
	if not operational(): return result(false, "locked")
	var row := definition(id)
	if row.is_empty(): return result(false, "unknown")
	var current_level := level()
	if int(current_level.level) < int(row.minimumLevel): return result(false, "level")
	var config := snapshot()
	if row.markCost != "0" and not config.unlocked.has(id): return result(false, "collection")
	var count := 0
	for entry in config.placements:
		if entry.id == excluded_id: continue
		count += 1
		if not row.repeatable and entry.decoration_id == id: return result(false, "unique")
	if count >= int(current_level.placementLimit) or count >= 256: return result(false, "limit")
	if not SourceDysonEngineering.number(placement.get("x"), -1.0e15, 1.0e15) or not SourceDysonEngineering.number(placement.get("y"), -1.0e15, 1.0e15): return result(false, "position")
	if not SourceDysonEngineering.number(placement.get("rotation"), 0, 270, true) or not row.rotations.has(float(placement.rotation)): return result(false, "rotation")
	if not SourceDysonEngineering.number(placement.get("layer"), 0, 3, true) or not row.layers.has(float(placement.layer)): return result(false, "layer")
	if not SourceDysonEngineering.number(placement.get("variant"), 0, int(row.variantCount) - 1, true): return result(false, "variant")
	var swapped := int(placement.rotation) in [90, 270]
	var size := Vector2(float(row.height) if swapped else float(row.width), float(row.width) if swapped else float(row.height))
	var center := Vector2(float(placement.x), float(placement.y))
	if absf(center.x) + size.x / 2 > float(current_level.halfWidth) or absf(center.y) + size.y / 2 > float(current_level.halfHeight): return result(false, "position")
	var bounds := Rect2(center - size / 2, size)
	for anchor in ANCHORS:
		if bounds.intersects(anchor): return result(false, "anchor")
	return result(true, "ready")

func place(id: String, placement: Dictionary) -> Dictionary:
	var checked := placement_check(id, placement)
	if not checked.ok: return result(false, "无法摆放：" + checked.message)
	var entry := placement.duplicate(true)
	entry.id = state.generate_id("station_decor")
	entry.decoration_id = id
	_mutable().placements.append(entry)
	return result(true, "装饰已摆放")

func update_placement(id: String, patch: Dictionary) -> Dictionary:
	var config := snapshot()
	for entry in config.placements:
		if entry.id != id: continue
		var next: Dictionary = entry.duplicate(true)
		for key in patch:
			if key not in ["x", "y", "rotation", "layer", "variant"]: return result(false, "布局修改字段无效")
			next[key] = patch[key]
		var checked := placement_check(entry.decoration_id, next, id)
		if not checked.ok: return result(false, "无法移动：" + checked.message)
		var entries: Array = _mutable().placements
		for index in range(entries.size()):
			if entries[index].id == id: entries[index] = next
		return result(true, "装饰布局已更新")
	return result(false, "未找到装饰")

func remove(id: String) -> Dictionary:
	var entries: Array = snapshot().placements
	for index in range(entries.size()):
		if entries[index].id != id: continue
		_mutable().placements.remove_at(index)
		return result(true, "装饰已移除，永久授权保留")
	return result(false, "未找到装饰")

func set_theme(id: String) -> Dictionary:
	var row := definition(id, "themes")
	if state.save_mode != "normal" or row.is_empty() or int(level().level) < int(row.minimumLevel) or (row.markCost != "0" and not snapshot().unlocked.has("theme:" + id)): return result(false, "主题未解锁")
	_mutable().theme = id
	return result(true, "空间站主题已更新")

func set_viewport(x: float, y: float, zoom: float) -> Dictionary:
	if state.save_mode != "normal" or not is_finite(x) or not is_finite(y) or not is_finite(zoom): return result(false, "视图参数无效")
	_mutable().viewport = {"x": clampf(x, -20000, 20000), "y": clampf(y, -20000, 20000), "zoom": clampf(zoom, 0.2, 2.5)}
	return result(true, "展示视图已保存")

static func profile_text(value: String, maximum: int) -> String:
	var cleaned := ""
	for character in value:
		var code := character.unicode_at(0)
		if character in ["<", ">"] or code <= 8 or code in [11, 12] or (code >= 14 and code <= 31): continue
		cleaned += character
	return cleaned.strip_edges().left(maximum)

func set_profile(title: String, motto: String, metrics: Array) -> Dictionary:
	title = profile_text(title, 32)
	if state.save_mode != "normal" or title.is_empty(): return result(false, "空间站名称不能为空")
	var featured := []
	for metric in metrics:
		if metric in METRICS and not featured.has(metric) and featured.size() < 4: featured.append(metric)
	_mutable().profile = {"title": title, "motto": profile_text(motto, 96), "featured_metrics": featured}
	return result(true, "空间站名片已保存")

func set_featured_achievements(ids: Array) -> Dictionary:
	if state.save_mode != "normal": return result(false, "速通模式不使用本地空间站")
	var featured := []
	for id in ids:
		if state.completed_achievement_ids.has(id) and not featured.has(id) and featured.size() < 8: featured.append(id)
	_mutable().featured_achievements = featured
	return result(true, "空间站成就展示已更新")

static func validate(data: Dictionary) -> Array:
	var station: Variant = data.get("orbital_station", {})
	if not station is Dictionary or not station.has("presentation"): return []
	var config: Variant = station.presentation
	if not config is Dictionary or config.size() != 7 or config.get("version") != 1 or not config.get("unlocked") is Array or config.unlocked.size() > 512 or not config.get("placements") is Array or config.placements.size() > 256: return ["空间站展示结构无效"]
	var unlocked := {}
	for id in config.unlocked:
		if not id is String or unlocked.has(id) or definition(id.trim_prefix("theme:"), "themes" if id.begins_with("theme:") else "decorations").is_empty(): return ["空间站装饰授权无效"]
		unlocked[id] = true
	if not config.get("theme") is String or definition(config.theme, "themes").is_empty() or not config.get("viewport") is Dictionary: return ["空间站主题或视图无效"]
	for axis in ["x", "y"]:
		if not SourceDysonEngineering.number(config.viewport.get(axis), -20000, 20000): return ["展示视图坐标无效"]
	if not SourceDysonEngineering.number(config.viewport.get("zoom"), 0.2, 2.5): return ["展示视图缩放无效"]
	var profile: Variant = config.get("profile")
	if not profile is Dictionary or profile.size() != 3 or not profile.get("title") is String or profile.title.is_empty() or profile_text(profile.title, 32) != profile.title or not profile.get("motto") is String or profile_text(profile.motto, 96) != profile.motto or not profile.get("featured_metrics") is Array or profile.featured_metrics.size() > 4: return ["空间站名片无效"]
	var metrics := {}
	for id in profile.featured_metrics:
		if id not in METRICS or metrics.has(id): return ["展示指标重复或无效"]
		metrics[id] = true
	if not config.get("featured_achievements") is Array or config.featured_achievements.size() > 8 or not data.get("completed_achievement_ids", []) is Array: return ["展示成就结构无效"]
	var achievements := {}
	for id in config.featured_achievements:
		if not id is String or achievements.has(id) or not data.get("completed_achievement_ids", []).has(id): return ["展示成就尚未解锁"]
		achievements[id] = true
	var board: Variant = data.get("station_contracts", {})
	if not board is Dictionary: return ["展示经济无效"]
	var reputation: Variant = board.get("reputation", "0")
	if not HubInteger.valid(reputation) and not GalacticExportSystem._nonnegative_integer(reputation): return ["展示声望无效"]
	var probe := GameState.new()
	probe.orbital_station = station.duplicate(true)
	probe.station_contracts = board.duplicate(true)
	var model := StationPresentationSystem.new(probe)
	var theme := definition(config.theme, "themes")
	if int(model.level().level) < int(theme.minimumLevel) or (theme.markCost != "0" and not config.unlocked.has("theme:" + config.theme)): return ["展示主题未获授权"]
	var seen := {}
	for entry in config.placements:
		if not entry is Dictionary or entry.size() != 7 or not entry.get("id") is String or entry.id.is_empty() or entry.id.length() > 160 or seen.has(entry.id) or not entry.get("decoration_id") is String: return ["空间站摆放记录无效"]
		seen[entry.id] = true
		if not model.placement_check(entry.decoration_id, entry, entry.id).ok: return ["空间站摆放不满足等级或布局边界"]
	return []

static func result(ok: bool, code: String) -> Dictionary:
	var messages := {"locked": "空间站尚未建成", "unknown": "未找到该装饰", "level": "空间站声望等级不足", "collection": "请先购买永久授权", "limit": "已达到当前等级的摆放上限", "unique": "该纪念品只能摆放一件", "position": "位置超出甲板边界", "rotation": "该装饰不支持此旋转角度", "layer": "该装饰不支持此层级", "variant": "装饰变体编号无效", "anchor": "装饰不能覆盖功能区", "ready": "可以摆放"}
	return {"ok": ok, "code": code, "message": messages.get(code, code)}
