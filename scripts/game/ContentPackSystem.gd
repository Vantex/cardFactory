class_name ContentPackSystem
extends RefCounted

const FIELD_MAP := {"inputCapacity": "input_buffer_capacity", "outputCapacity": "output_buffer_capacity", "powerDemandKw": "power_demand", "powerGenerationKw": "power_generation", "powerChargeKw": "power_charge", "energyCapacityMj": "energy_capacity_mj", "stackLimit": "stack_limit", "speed": "speed"}
var registry := {"version": 1, "packs": {}}
var core: Dictionary
var aliases := {"items": {}, "buildings": {}, "recipes": {}, "technologies": {}}
var path: String
var last_error := ""

func _init(storage_path: String = "user://content_packs/registry.json") -> void:
	path = storage_path
	core = snapshot_catalog()
	for category in aliases:
		for id in core[category]: aliases[category][id] = id
		for id in core[category]:
			var source_id: String = core[category][id].get("source_id", "")
			if source_id != "": aliases[category][source_id] = id

static func snapshot_catalog() -> Dictionary:
	return {"items": DataManager.all_items.duplicate(true), "buildings": DataManager.all_buildings.duplicate(true), "recipes": DataManager.all_recipes.duplicate(true), "technologies": DataManager.all_technologies.duplicate(true), "construction": DataManager.construction.duplicate(true), "belts": DataManager.runtime_belts.duplicate(true)}

static func install_catalog(catalog: Dictionary) -> void:
	DataManager.all_items = catalog.items.duplicate(true)
	DataManager.all_buildings = catalog.buildings.duplicate(true)
	DataManager.all_recipes = catalog.recipes.duplicate(true)
	DataManager.all_technologies = catalog.technologies.duplicate(true)
	DataManager.construction = catalog.construction.duplicate(true)
	DataManager.runtime_belts = catalog.belts.duplicate(true)

func resolve(category: String, id: String) -> String:
	return String(aliases[category].get(id, id))

func validate_manifest(raw: Variant) -> Dictionary:
	var ids := {}
	for category in aliases: ids[category] = aliases[category]
	return ContentPackValidator.validate(raw, ids, registry.packs)

func active_order(packs: Dictionary) -> Array:
	var result := []
	var remaining := packs.keys()
	remaining.sort()
	for iteration in range(packs.size() + 1):
		var progress := false
		for id in remaining.duplicate():
			if not packs[id].enabled:
				remaining.erase(id)
				continue
			var ready := true
			for spec in packs[id].manifest.dependencies:
				var dependency := ContentPackValidator.dependency(spec)
				var provided: Dictionary = packs.get(dependency.id, {})
				if not result.has(dependency.id) or not provided.get("enabled", false) or not ContentPackValidator.satisfies(provided.get("manifest", {}).get("version", ""), dependency.range): ready = false
			if ready:
				result.append(id)
				remaining.erase(id)
				progress = true
		if not progress: break
	return result

func dependency_reason(manifest: Dictionary, packs: Dictionary) -> String:
	var order := active_order(packs)
	for spec in manifest.dependencies:
		var requirement := ContentPackValidator.dependency(spec)
		if not packs.has(requirement.id): return "缺少依赖：" + requirement.id
		if not order.has(requirement.id): return "依赖未启用或存在循环：" + requirement.id
		if not ContentPackValidator.satisfies(packs[requirement.id].manifest.version, requirement.range): return "依赖版本不匹配：" + requirement.id
	return ""

func references(requested: Variant = null) -> Array:
	var packs: Dictionary = registry.packs if requested == null else requested
	var result := []
	for id in active_order(packs): result.append({"id": id, "version": packs[id].manifest.version, "fingerprint": fingerprint(packs[id].manifest)})
	return result

func requirements_error(requirements: Variant) -> String:
	if not requirements is Array: return "内容包存档引用必须是数组"
	var seen := {}
	for requirement in requirements:
		if not requirement is Dictionary or requirement.size() != 3 or not ContentPackValidator.valid_id(requirement.get("id")) or ContentPackValidator.version(requirement.get("version")).is_empty() or not requirement.get("fingerprint") is String: return "内容包存档引用无效"
		if seen.has(requirement.id): return "重复的内容包存档引用"
		seen[requirement.id] = true
		var pack: Dictionary = registry.packs.get(requirement.id, {})
		if pack.is_empty(): return "缺少内容包：" + requirement.id + "@" + requirement.version
		if not active_order(registry.packs).has(requirement.id): return "内容包未启用：" + requirement.id
		if pack.manifest.version != requirement.version or fingerprint(pack.manifest) != requirement.fingerprint: return "内容包版本或指纹不匹配：" + requirement.id
	return ""

func register_pack(raw: Variant, enabled: bool = true, protected: Array = []) -> Dictionary:
	var checked := validate_manifest(raw)
	if not checked.ok: return fail("；".join(checked.errors))
	var manifest: Dictionary = checked.manifest
	if registry.packs.has(manifest.id):
		var guard := usage_reason(registry.packs[manifest.id].manifest, protected)
		if guard != "": return fail(guard)
	var next := registry.duplicate(true)
	var now := Time.get_unix_time_from_system() * 1000
	next.packs[manifest.id] = {"manifest": manifest, "enabled": false, "installedAt": registry.packs.get(manifest.id, {}).get("installedAt", now), "updatedAt": now}
	var reason := dependency_reason(manifest, next.packs)
	next.packs[manifest.id].enabled = enabled and reason.is_empty()
	var result := commit(next)
	if result.ok:
		result["enabled"] = next.packs[manifest.id].enabled
		result["message"] = "内容包已注册并启用" if result.enabled else "内容包已注册，等待依赖：" + reason
	return result

func set_enabled(id: String, enabled: bool, protected: Array = []) -> Dictionary:
	if not registry.packs.has(id): return fail("内容包不存在")
	if not enabled:
		var guard := usage_reason(registry.packs[id].manifest, protected)
		if guard != "": return fail(guard)
		guard = dependent_reason(id)
		if guard != "": return fail(guard)
	else:
		var reason := dependency_reason(registry.packs[id].manifest, registry.packs)
		if reason != "": return fail(reason)
	var next := registry.duplicate(true)
	next.packs[id].enabled = enabled
	next.packs[id].updatedAt = Time.get_unix_time_from_system() * 1000
	return commit(next)

func remove_pack(id: String, protected: Array = []) -> Dictionary:
	if not registry.packs.has(id): return fail("内容包不存在")
	var guard := usage_reason(registry.packs[id].manifest, protected)
	if guard == "": guard = dependent_reason(id)
	if guard != "": return fail(guard)
	var next := registry.duplicate(true)
	next.packs.erase(id)
	return commit(next)

func dependent_reason(id: String) -> String:
	for pack in registry.packs.values():
		if not pack.enabled: continue
		for spec in pack.manifest.dependencies:
			if ContentPackValidator.dependency(spec).id == id: return "仍被已启用内容包依赖：" + pack.manifest.id
	return ""

func usage_reason(manifest: Dictionary, protected: Array) -> String:
	var ids := {}
	for category in ["items", "buildings", "recipes", "technologies", "belts"]:
		for entry in manifest.get(category, []): ids[entry.id] = true
	for value in protected:
		if value is Dictionary:
			for requirement in value.get("content_packs", []):
				if requirement is Dictionary and requirement.get("id") == manifest.id: return "存档仍要求该内容包版本与指纹：" + manifest.id
		if uses(value, ids): return "内容包仍被工厂、存档、恢复点或蓝图引用：" + manifest.id
	return ""

static func uses(value: Variant, ids: Dictionary) -> bool:
	if value is String: return ids.has(value)
	if value is Array:
		for child in value:
			if uses(child, ids): return true
	elif value is Dictionary:
		for key in value:
			if key == "content_packs": continue
			if ids.has(key) and not ((value[key] is int or value[key] is float) and value[key] == 0): return true
			if uses(value[key], ids): return true
	return false

func amount_map(entries: Array) -> Dictionary:
	var result := {}
	for entry in entries:
		var id := resolve("items", entry.itemId)
		result[id] = float(result.get(id, 0)) + maxi(1, int(floorf(entry.amount)))
	return result

func build_catalog(packs: Dictionary) -> Dictionary:
	var catalog := core.duplicate(true)
	for id in active_order(packs):
		var manifest: Dictionary = packs[id].manifest
		for entry in manifest.items:
			catalog.items[entry.id] = {"id": entry.id, "name": entry.name.strip_edges().substr(0, 80), "kind": entry.get("kind", "solid"), "color": entry.get("color", "#6495ed"), "description": entry.get("description", manifest.name + " 提供的物品"), "source_content_pack": id}
		for entry in manifest.buildings:
			var definition := {"id": entry.id, "name": entry.name.strip_edges().substr(0, 80), "kind": "generator" if entry.get("kind") == "power" else "processor" if entry.get("kind", "machine") in ["machine", "miner"] else "storage" if entry.get("kind") == "station" else entry.kind, "source_kind": entry.get("kind", "machine"), "speed": maxf(0.01, entry.get("speed", 1)), "input_slots": 4, "output_slots": 4, "input_buffer_capacity": maxf(1, floorf(entry.get("inputCapacity", 100))), "output_buffer_capacity": maxf(1, floorf(entry.get("outputCapacity", 100))), "accepts": entry.get("accepts", "any"), "power_demand": entry.get("powerDemandKw", 0), "power_generation": entry.get("powerGenerationKw", 0), "description": entry.get("description", manifest.name + " 提供的建筑"), "required_source_technology": resolve("technologies", entry.get("requiredTechId", "")), "source_content_pack": id}
			catalog.buildings[entry.id] = definition
			if not entry.get("costs", []).is_empty(): catalog.construction[entry.id] = {"name": entry.name, "id": entry.id, "costs": amount_map(entry.costs), "output_amount": maxf(1, floorf(entry.get("outputAmount", 1))), "required_source_technology": resolve("technologies", entry.get("requiredTechId", ""))}
		for entry in manifest.buildingOverrides:
			var target := resolve("buildings", entry.id)
			for field in FIELD_MAP:
				if entry.has(field): catalog.buildings[target][FIELD_MAP[field]] = entry[field]
		for entry in manifest.recipes:
			var definition := {"id": entry.id, "name": entry.name.strip_edges().substr(0, 80), "building_id": resolve("buildings", entry.buildingId), "duration": maxf(0.05, entry.duration), "inputs": [], "outputs": [], "required_source_technology": resolve("technologies", entry.get("requiredTechId", "")), "source_content_pack": id}
			for direction in ["inputs", "outputs"]:
				for item in amount_map(entry[direction]): definition[direction].append({"item_id": item, "amount": amount_map(entry[direction])[item]})
			catalog.recipes[entry.id] = definition
		for entry in manifest.technologies:
			var prerequisites := []
			for parent in entry.get("prerequisites", []): prerequisites.append(resolve("technologies", parent))
			catalog.technologies[entry.id] = {"id": entry.id, "name": entry.name.strip_edges().substr(0, 80), "description": entry.get("summary", manifest.name + " 提供的科技"), "tier": "planetary", "duration": 1.0, "cost": amount_map(entry.get("costs", [])), "prerequisites": prerequisites, "unlocks": [], "source_content_pack": id, "source_research_bridge": true, "effects": {}}
		for entry in manifest.belts:
			catalog.belts[entry.id] = {"tier": entry.tier, "speed": entry.speed, "name": entry.name, "source_content_pack": id}
			catalog.construction[entry.id] = {"name": entry.name, "id": entry.id, "costs": amount_map(entry.costs), "output_amount": entry.get("outputAmount", 3), "required_source_technology": resolve("technologies", entry.get("requiredTechId", ""))}
	return catalog

func commit(next: Dictionary, persist: bool = true) -> Dictionary:
	var catalog := build_catalog(next.packs)
	var errors := DataManager.validate_catalog(catalog)
	if not errors.is_empty(): return fail("目录校验失败：" + String(errors[0].message))
	if persist:
		var saved := write_registry(next)
		if not saved.ok: return saved
	registry = next.duplicate(true)
	install_catalog(catalog)
	return {"ok": true, "message": "内容包目录已更新", "active_ids": active_order(registry.packs)}

func write_registry(next: Dictionary) -> Dictionary:
	var storage := SaveSystem.new(path.get_base_dir())
	var envelope := {"registry": next, "fingerprint": fingerprint(next)}
	if storage._write_text(path + ".tmp", JSON.stringify(envelope, "", true, true)) != OK: return fail("内容包注册表写入失败，原目录保留")
	var verified: Variant = JSON.parse_string(FileAccess.get_file_as_string(path + ".tmp"))
	if not verified is Dictionary or verified.get("fingerprint") != fingerprint(verified.get("registry", {})): return fail("内容包注册表写入校验失败")
	if FileAccess.file_exists(path):
		storage._remove_if_exists(path + ".bak")
		if storage._rename_file(path, path + ".bak") != OK: return fail("内容包注册表备份失败")
	if storage._rename_file(path + ".tmp", path) != OK:
		if FileAccess.file_exists(path + ".bak"): storage._copy_file(path + ".bak", path)
		return fail("内容包注册表替换失败")
	return {"ok": true}

func load_registry() -> Dictionary:
	if not FileAccess.file_exists(path) and not FileAccess.file_exists(path + ".bak"): return {"ok": true}
	for candidate in [path, path + ".bak"]:
		var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(candidate)) if FileAccess.file_exists(candidate) else null
		if not parsed is Dictionary or not parsed.get("registry") is Dictionary or parsed.get("fingerprint") != fingerprint(parsed.registry): continue
		var next: Dictionary = parsed.registry
		if next.get("version") != 1 or not next.get("packs") is Dictionary: continue
		var valid := true
		for id in next.packs:
			var pack: Variant = next.packs[id]
			if not pack is Dictionary or not pack.get("manifest") is Dictionary or pack.manifest.get("id") != id or not pack.get("enabled") is bool or not ContentPackValidator.numeric(pack.get("installedAt"), 0, 1000000000000000) or not ContentPackValidator.numeric(pack.get("updatedAt"), 0, 1000000000000000):
				valid = false
				break
			var checked := ContentPackValidator.validate(pack.manifest, aliases, next.packs)
			if not checked.ok:
				valid = false
				break
		if valid:
			var committed := commit(next, false)
			if committed.ok: return committed
	return fail("内容包注册表损坏；核心目录保留，依赖这些内容的存档暂不可加载")

func runtime_snapshot() -> Dictionary:
	return {"protocolVersion": 1, "registry": registry.duplicate(true), "fingerprint": fingerprint(registry)}

func apply_runtime_snapshot(snapshot: Variant) -> Dictionary:
	if not snapshot is Dictionary or snapshot.get("protocolVersion") != 1 or not snapshot.get("registry") is Dictionary or snapshot.get("fingerprint") != fingerprint(snapshot.registry): return fail("内容包运行快照版本或指纹无效")
	var next: Dictionary = snapshot.registry
	if next.get("version") != 1 or not next.get("packs") is Dictionary: return fail("内容包注册表结构无效")
	for id in next.packs:
		var pack: Variant = next.packs[id]
		if not pack is Dictionary or not pack.get("manifest") is Dictionary or pack.manifest.get("id") != id or not pack.get("enabled") is bool or not ContentPackValidator.numeric(pack.get("installedAt"), 0, 1000000000000000) or not ContentPackValidator.numeric(pack.get("updatedAt"), 0, 1000000000000000): return fail("内容包快照记录无效")
		if not ContentPackValidator.validate(pack.manifest, aliases, next.packs).ok: return fail("内容包快照定义未通过校验")
	return commit(next, false)

static func stable(value: Variant) -> String:
	if value is Dictionary:
		var keys: Array = value.keys()
		keys.sort()
		var parts := PackedStringArray()
		for key in keys: parts.append(JSON.stringify(key) + ":" + stable(value[key]))
		return "{" + ",".join(parts) + "}"
	if value is Array:
		var parts := PackedStringArray()
		for child in value: parts.append(stable(child))
		return "[" + ",".join(parts) + "]"
	if value is float and value == floorf(value) and absf(value) <= 9007199254740991: return str(int(value))
	return JSON.stringify(value)

static func fingerprint(value: Variant) -> String:
	var hash_value := 2166136261
	var characters := stable(value).to_utf16_buffer()
	for offset in range(0, characters.size(), 2): hash_value = ((hash_value ^ characters.decode_u16(offset)) * 16777619) & 0xffffffff
	return "%08x" % hash_value

static func fail(message: String) -> Dictionary:
	return {"ok": false, "error": {"code": "content_pack_error", "message": message}, "message": message}
