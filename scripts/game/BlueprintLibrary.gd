class_name BlueprintLibrary
extends RefCounted

var state: GameState
func _init(value: GameState) -> void: state = value

func save_definition(title: String, blueprint: Dictionary, id: String = "", rotation: int = 0, mirrored: bool = false, overrides: Dictionary = {}, fleet_targets: Dictionary = {}) -> Dictionary:
	var encoded := BlueprintCodec.new().encode(blueprint)
	if not encoded.ok: return encoded
	if title.strip_edges().is_empty(): return fail("请输入蓝图名称")
	if not id.is_empty() and not state.blueprint_library.has(id): return fail("蓝图不存在")
	var entry := {"id": id, "name": title.strip_edges().left(32), "text": encoded.text, "rotation": posmod(rotation, 4), "mirrored": mirrored, "overrides": overrides.duplicate(true)}
	var resolved := resolve(entry)
	if not resolved.ok: return resolved
	entry.fleet_targets = fleet_targets.duplicate(true)
	if not BlueprintStateValidator._definition(entry): return fail("蓝图配置或载具目标无效")
	if id.is_empty():
		id = state.generate_id("blueprint")
		entry.id = id
	state.blueprint_library[id] = entry
	return {"ok": true, "id": id, "message": "蓝图已保存"}

func rename(id: String, title: String) -> Dictionary:
	if not state.blueprint_library.has(id) or title.strip_edges().is_empty(): return fail("蓝图或名称无效")
	state.blueprint_library[id].name = title.strip_edges().left(32)
	return {"ok": true, "message": "蓝图已重命名"}

func remove(id: String) -> Dictionary:
	if not state.blueprint_library.has(id): return fail("蓝图不存在")
	state.blueprint_library.erase(id)
	return {"ok": true, "message": "已删除蓝图；已排队的独立副本保留"}

static func resolve(entry: Dictionary) -> Dictionary:
	var decoded := BlueprintCodec.new().decode(String(entry.get("text", "")))
	if not decoded.ok: return decoded
	var blueprint: Dictionary = decoded.blueprint
	var refs := {}
	var overrides: Dictionary = entry.get("overrides", {})
	for source in overrides:
		if DataManager.get_recipe(String(source)).is_empty() or not overrides[source] is String or DataManager.get_recipe(overrides[source]).is_empty(): return fail("配方替换引用无效")
	for entity in blueprint.entities:
		var definition := DataManager.get_building(entity.type)
		if definition.is_empty(): return fail("蓝图建筑引用无效")
		var output: String = entity.configuration.get("output_item", "")
		if not output.is_empty() and DataManager.get_item(output).is_empty(): return fail("蓝图输出物品引用无效")
		var recipe_id: String = entity.configuration.get("recipe_id", "")
		if overrides.has(recipe_id):
			entity.configuration.recipe_id = overrides[recipe_id]
			entity.configuration.erase("output_item")
			recipe_id = overrides[recipe_id]
		if not recipe_id.is_empty() and not DataManager.is_recipe_supported_by_building(DataManager.get_recipe(recipe_id), entity.type): return fail("配方不适用于蓝图建筑")
		refs[entity.ref] = entity
	for connection in blueprint.connections:
		if not GameState.BELT_RATED_THROUGHPUT.has(connection.type): return fail("蓝图线路引用无效")
		var item: String = connection.configuration.get("item_id", "")
		if DataManager.get_item(item).is_empty(): return fail("蓝图线路物品无效")
		var source: Dictionary = refs[connection.source]
		var target: Dictionary = refs[connection.target]
		var outputs: Array = DataManager.get_recipe(source.configuration.get("recipe_id", "")).get("outputs", [])
		var inputs: Array = DataManager.get_recipe(target.configuration.get("recipe_id", "")).get("inputs", [])
		if not outputs.is_empty() and not outputs.any(func(row): return row.item_id == item): return fail("替换配方后输出与线路不兼容")
		if not inputs.is_empty() and not inputs.any(func(row): return row.item_id == item) and not item.begins_with("proliferator_"): return fail("替换配方后输入与线路不兼容")
	return {"ok": true, "blueprint": blueprint}

static func fail(message: String) -> Dictionary: return {"ok": false, "message": message}
