class_name CanvasNavigation
extends RefCounted

var state: GameState
func _init(value: GameState) -> void: state = value

func save_bookmark(title: String, position: Vector2, zoom: float, id: String = "") -> Dictionary:
	if not valid_point(position) or not is_finite(zoom) or title.strip_edges().is_empty(): return BlueprintLibrary.fail("书签名称或镜头无效")
	var entry := {"id": id, "name": title.strip_edges().left(28), "planet_id": state.active_planet_id, "position": [roundf(position.x), roundf(position.y)], "zoom": snappedf(clampf(zoom, 0.1, 2.5), 0.01)}
	return _save(state.canvas_bookmarks, entry, "bookmark", 24)

func save_region(title: String, rect: Rect2, color: Color, id: String = "") -> Dictionary:
	if not valid_point(rect.position) or not valid_point(rect.end) or rect.size.x <= 0 or rect.size.y <= 0 or title.strip_edges().is_empty(): return BlueprintLibrary.fail("区域名称或矩形无效")
	var entry := {"id": id, "name": title.strip_edges().left(28), "planet_id": state.active_planet_id, "rect": [rect.position.x, rect.position.y, rect.size.x, rect.size.y], "color": color.to_html(true)}
	return _save(state.canvas_regions, entry, "region", 48)

func _save(collection: Array, entry: Dictionary, prefix: String, limit: int) -> Dictionary:
	if not entry.id.is_empty():
		for i in range(collection.size()):
			if collection[i].id == entry.id:
				collection[i] = entry
				return {"ok": true, "id": entry.id, "message": "标记已更新"}
		return BlueprintLibrary.fail("标记不存在")
	entry.id = state.generate_id(prefix)
	collection.append(entry)
	if collection.size() > limit: collection.pop_front()
	return {"ok": true, "id": entry.id, "message": "标记已保存"}

func rename(id: String, title: String) -> Dictionary:
	if title.strip_edges().is_empty(): return BlueprintLibrary.fail("名称不能为空")
	for collection in [state.canvas_regions, state.canvas_bookmarks]:
		for entry in collection:
			if entry.id == id:
				entry.name = title.strip_edges().left(28)
				return {"ok": true, "message": "标记已重命名"}
	return BlueprintLibrary.fail("标记不存在")

func remove(id: String) -> Dictionary:
	for collection in [state.canvas_regions, state.canvas_bookmarks]:
		for i in range(collection.size()):
			if collection[i].id == id:
				collection.remove_at(i)
				return {"ok": true, "message": "标记已删除"}
	return BlueprintLibrary.fail("标记不存在")

static func valid_point(value: Vector2) -> bool:
	return is_finite(value.x) and is_finite(value.y) and absf(value.x) <= BlueprintCodec.MAX_COORDINATE and absf(value.y) <= BlueprintCodec.MAX_COORDINATE
