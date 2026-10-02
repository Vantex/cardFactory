class_name SourceGalaxySystem
extends RefCounted

const DEFAULT_SEED := 240721
const ROLES := ["auto", "mining", "smelting", "manufacturing", "chemical", "research", "logistics", "power"]
const LEGACY_COSTS := {"home": [], "ashen": [], "giant": [], "frost": [{"itemId": "titanium_ingot", "amount": 2}], "boreal_giant": [{"itemId": "titanium_alloy", "amount": 10}, {"itemId": "logistics_drone", "amount": 5}], "magnetar": [{"itemId": "space_warper", "amount": 4}, {"itemId": "processor", "amount": 20}]}
static var _catalog: Dictionary = {}
var state: GameState

func _init(game_state: GameState) -> void:
	state = game_state

static func catalog() -> Dictionary:
	if _catalog.is_empty():
		var file := FileAccess.open("res://data/galaxy/source_catalog.json", FileAccess.READ)
		if file != null: _catalog = JSON.parse_string(file.get_as_text())
	return _catalog

static func hash_text(value: String) -> int:
	var hashed := 2166136261
	for index in range(value.length()):
		var code := value.unicode_at(index)
		if code > 65535:
			hashed = ((hashed ^ (55296 + ((code - 65536) >> 10))) * 16777619) & 0xffffffff
			code = 56320 + ((code - 65536) & 1023)
		hashed = ((hashed ^ code) * 16777619) & 0xffffffff
	return hashed

static func seeded_unit(seed: int, key: String) -> float:
	var value := ((seed ^ hash_text(key)) + 0x6d2b79f5) & 0xffffffff
	value = ((value ^ (value >> 15)) * (value | 1)) & 0xffffffff
	value = (value ^ ((value + (((value ^ (value >> 7)) * (value | 61)) & 0xffffffff)) & 0xffffffff)) & 0xffffffff
	return float((value ^ (value >> 14)) & 0xffffffff) / 4294967296.0

static func jitter(seed: int, key: String, amplitude: float) -> float:
	return 1.0 + (seeded_unit(seed, key) * 2.0 - 1.0) * amplitude

static func rounded(value: float) -> float:
	return floorf(value * 100.0 + 0.5) / 100.0

static func create(seed: int = DEFAULT_SEED, baseline: bool = false) -> Dictionary:
	seed = maxi(1, absi(seed) if seed != 0 else DEFAULT_SEED)
	var source := catalog()
	var systems := {}
	for id in source.systems:
		var definition: Dictionary = source.systems[id]
		var star: Dictionary = source.stars[definition.defaultStarClassId]
		var position: Dictionary = source.positions[id]
		var x := 0.0 if id == "helios" else rounded(float(position.x) + (0.0 if baseline else (seeded_unit(seed, id + ":x") * 2.0 - 1.0) * 0.7))
		var y := 0.0 if id == "helios" else rounded(float(position.y) + (0.0 if baseline else (seeded_unit(seed, id + ":y") * 2.0 - 1.0) * 0.7))
		systems[id] = {"systemId": id, "starClassId": star.id, "starTypeName": star.name, "luminosity": rounded(float(star.luminosity) * (1.0 if baseline else jitter(seed, id + ":luminosity", 0.06))), "massMultiplier": rounded(float(star.massMultiplier) * (1.0 if baseline else jitter(seed, id + ":mass", 0.04))), "radiusMultiplier": rounded(float(star.radiusMultiplier) * (1.0 if baseline else jitter(seed, id + ":radius", 0.04))), "positionX": x, "positionY": y, "distanceFromOriginLy": rounded(sqrt(x * x + y * y))}
	var profiles := {}
	var roles := {}
	for id in source.planets:
		var planet: Dictionary = source.planets[id]
		var pool: Array = source.pools[id]
		var template_id: String = planet.defaultTemplateId if baseline or pool.size() < 2 else pool[int(floorf(seeded_unit(seed, id + ":template") * pool.size())) % pool.size()]
		var template: Dictionary = source.templates[template_id]
		var climate := 1.0 if baseline else jitter(seed, id + ":climate", 0.12)
		var resources := 1.0 if baseline else jitter(seed, id + ":resources", 0.2)
		var rares: Array = template.rareResourcePool.duplicate()
		rares.sort_custom(func(a, b): return seeded_unit(seed, "%s:rare:%s" % [id, a]) < seeded_unit(seed, "%s:rare:%s" % [id, b]))
		rares = rares.slice(0, int(template.rareResourceCount))
		var resource_ids: Array = template.resourceIds.duplicate()
		resource_ids.append_array(rares)
		if id in ["pelagic", "dune", "prairie"] and not resource_ids.has("crude_oil"): resource_ids.append("crude_oil")
		var yields := {}
		var source_yields: Dictionary = {"hydrogen": 1.0, "deuterium": 0.2, "fire_ice": 0.5} if id == "giant" else template.orbitalYields
		for item in source_yields: yields[item] = rounded(float(source_yields[item]) * (1.0 if baseline else jitter(seed, "%s:orbit:%s" % [id, item], 0.14)))
		var costs: Array = LEGACY_COSTS.get(id, template.colonyCost).duplicate(true)
		if not LEGACY_COSTS.has(id) and not baseline:
			for cost in costs: cost.amount = maxi(1, int(floorf(float(cost.amount) * jitter(seed, "%s:colony:%s" % [id, cost.itemId], 0.12) + 0.5)))
		var survey := 0 if id in ["home", "ashen", "giant"] else int(template.surveyDurationSeconds)
		profiles[id] = {"planetId": id, "templateId": template_id, "climateName": template.name, "resourceIds": resource_ids, "rareResourceIds": rares, "oceanType": template.oceanType, "orbitalYields": yields, "windMultiplier": rounded(float(template.windMultiplier) * climate), "solarMultiplier": rounded(float(template.solarMultiplier) * (1.0 if baseline else jitter(seed, id + ":solar", 0.1))), "geothermalMultiplier": rounded(float(template.geothermalMultiplier) * climate), "miningMultiplier": rounded(float(template.miningMultiplier) * resources), "orbitalYieldMultiplier": rounded((1.0 if id == "giant" else float(template.orbitalYieldMultiplier)) * resources), "reserveScale": rounded(float(template.reserveScale) * resources), "travelTimeMultiplier": rounded(float(template.travelTimeMultiplier) * (1.0 if baseline else jitter(seed, id + ":travel", 0.08))), "tidalLocked": bool(template.get("tidalLocked", false)), "sulfuricOcean": template.oceanType == "sulfuric-acid", "specialization": template.specialization, "specializationName": "轨道窗口 · 采集器 +15%" if id == "giant" else template.specializationName, "productionSpeedMultiplier": 1.15 if id == "giant" else template.productionSpeedMultiplier, "colonyCost": costs, "surveyDurationSeconds": survey if baseline else maxi(0, int(floorf(survey * jitter(seed, id + ":survey", 0.1) + 0.5)))}
		roles[id] = "auto"
	return {"seed": seed, "profiles": profiles, "systemProfiles": systems, "planetRoles": roles, "planetMetadata": {}, "systemMetadata": {}}

func initialize(seed: int = DEFAULT_SEED, baseline: bool = false) -> void:
	state.source_galaxy = create(seed, baseline)
	state._source_catalog_cache = {}
	state.galaxy_seed = int(state.source_galaxy.seed)

func profile(planet: String) -> Dictionary:
	return state.source_galaxy.get("profiles", {}).get(planet, {}).duplicate(true)

func orbital_yields(planet: String) -> Dictionary:
	return profile(planet).get("orbitalYields", {}).duplicate(true) if not state.source_galaxy.is_empty() else OrbitalCollectorSystem.YIELDS.get(planet, {}).duplicate(true)

func reserve(planet: String, item: String, id: String) -> int:
	var rare: bool = item in ["kimberlite_ore", "fractal_silicon", "optical_grating_crystal", "spiniform_stalagmite_crystal", "unipolar_magnet", "organic_crystal"]
	var oil := 2.4 if planet == "dune" else 1.5 if planet == "prairie" else 1.15 if planet == "pelagic" else 1.0
	var base := 420000.0 * oil if item == "crude_oil" else 36000.0 if rare else 240000.0
	return maxi(1, int(floorf(base * float(profile(planet).get("reserveScale", 1.0)) * jitter(state.galaxy_seed, id + ":" + item, 0.16))))

func solar_multiplier(planet: String) -> float:
	var data := profile(planet)
	var system: String = catalog().planets.get(planet, {}).get("systemId", "")
	return rounded(float(data.get("solarMultiplier", 0)) * float(state.source_galaxy.get("systemProfiles", {}).get(system, {}).get("luminosity", 1)) * (1.25 if data.get("tidalLocked", false) else 1.0))

func production_multiplier(planet: String, building_type: String) -> float:
	var data := profile(planet)
	if data.is_empty(): return 1.0
	var building := DataManager.get_building(building_type)
	var id := String(building.get("source_id", building_type))
	var specialization: String = data.specialization
	var applies: bool = specialization == "balanced" or (specialization == "smelting" and building.get("family") == "smelter") or (specialization == "chemical" and building.get("family") == "chemical") or (specialization == "research" and id == "matrix_lab") or (specialization == "particle" and id in ["miniature_particle_collider", "fractionator"]) or (specialization == "logistics" and (id == "orbital_collector" or id.contains("logistics_station")))
	return float(data.productionSpeedMultiplier) if applies else 1.0

func set_role(planet: String, role: String) -> Dictionary:
	if not state.source_galaxy.get("profiles", {}).has(planet) or role not in ROLES: return {"ok": false, "message": "行星或工业角色无效"}
	state.source_galaxy.planetRoles[planet] = role
	return {"ok": true, "message": "行星工业角色已更新"}

func set_metadata(id: String, name: String, note: String = "", tags: Array = [], system: bool = false) -> Dictionary:
	var field := "systemMetadata" if system else "planetMetadata"
	var ids := "systemProfiles" if system else "profiles"
	if not state.source_galaxy.get(ids, {}).has(id): return {"ok": false, "message": "星区目标不存在"}
	var value := {"customName": name.strip_edges()}
	if not system: value.merge({"note": note.strip_edges(), "tags": tags.duplicate()})
	if not _metadata(value, system): return {"ok": false, "message": "名称最多 32 字，备注最多 240 字，标签最多 8 个且每个 16 字"}
	state.source_galaxy[field][id] = value
	return {"ok": true, "message": "本地星区说明已更新"}

static func _metadata(value: Variant, system: bool) -> bool:
	if not value is Dictionary or not value.get("customName", "") is String or value.get("customName", "").length() > 32: return false
	for key in value:
		if key not in (["customName"] if system else ["customName", "note", "tags"]): return false
	if system: return true
	if not value.get("note", "") is String or value.get("note", "").length() > 240 or not value.get("tags", []) is Array or value.get("tags", []).size() > 8: return false
	for tag in value.get("tags", []):
		if not tag is String or tag.strip_edges().is_empty() or tag.length() > 16: return false
	return true

static func validate(data: Dictionary) -> Array:
	var value: Variant = data.get("source_galaxy", {})
	if not value is Dictionary: return ["源星区档案必须是字典"]
	if value.is_empty(): return []
	if value.size() != 6 or not value.get("seed") is float and not value.get("seed") is int or float(value.get("seed", 0)) != float(data.get("galaxy_seed", -1)): return ["源星区种子无效"]
	for field in ["profiles", "systemProfiles", "planetRoles", "planetMetadata", "systemMetadata"]:
		if not value.get(field) is Dictionary: return ["源星区集合无效"]
	for id in value.planetMetadata:
		if not catalog().planets.has(id) or not _metadata(value.planetMetadata[id], false): return ["行星本地说明无效"]
	for id in value.systemMetadata:
		if not catalog().systems.has(id) or not _metadata(value.systemMetadata[id], true): return ["恒星本地说明无效"]
	if value.profiles.size() != catalog().planets.size() or value.systemProfiles.size() != catalog().systems.size() or value.planetRoles.size() != catalog().planets.size(): return ["源星区档案数量无效"]
	for id in catalog().planets:
		var profile_data: Variant = value.profiles.get(id)
		if not profile_data is Dictionary or profile_data.get("planetId") != id or not catalog().templates.has(profile_data.get("templateId")) or value.planetRoles.get(id) not in ROLES: return ["源行星档案引用无效"]
		if catalog().templates[profile_data.templateId].kind != catalog().planets[id].kind: return ["源行星生态类型无效"]
		for field in ["windMultiplier", "solarMultiplier", "geothermalMultiplier", "miningMultiplier", "orbitalYieldMultiplier", "reserveScale", "travelTimeMultiplier", "productionSpeedMultiplier", "surveyDurationSeconds"]:
			if not _number(profile_data.get(field), 0, 1000): return ["源行星工业数值无效"]
		for field in ["resourceIds", "rareResourceIds", "colonyCost"]:
			if not profile_data.get(field) is Array: return ["源行星资源集合无效"]
		for item in profile_data.resourceIds + profile_data.rareResourceIds:
			if not item is String or DataManager.get_item(item).is_empty(): return ["源行星资源引用无效"]
		for cost in profile_data.colonyCost:
			if not cost is Dictionary or DataManager.get_item(str(cost.get("itemId", ""))).is_empty() or not _number(cost.get("amount"), 1, 1000000): return ["源行星殖民成本无效"]
		if not profile_data.get("orbitalYields") is Dictionary: return ["源轨道资源集合无效"]
		for item in profile_data.orbitalYields:
			if item not in OrbitalCollectorSystem.ITEMS or not _number(profile_data.orbitalYields[item], 0, 100): return ["源轨道资源数值无效"]
		for field in ["tidalLocked", "sulfuricOcean"]:
			if not profile_data.get(field) is bool: return ["源行星生态开关无效"]
		for field in ["climateName", "oceanType", "specialization", "specializationName"]:
			if not profile_data.get(field) is String: return ["源行星生态说明无效"]
	for id in catalog().systems:
		var system: Variant = value.systemProfiles.get(id)
		if not system is Dictionary or system.get("systemId") != id or not catalog().stars.has(system.get("starClassId")) or not system.get("starTypeName") is String: return ["源恒星档案引用无效"]
		for field in ["luminosity", "massMultiplier", "radiusMultiplier", "distanceFromOriginLy"]:
			if not _number(system.get(field), 0, 1000): return ["源恒星物理数值无效"]
		for field in ["positionX", "positionY"]:
			if not _number(system.get(field), -1000, 1000): return ["源恒星位置无效"]
	return []

static func _number(value: Variant, minimum: float, maximum: float) -> bool:
	return (value is int or value is float) and is_finite(float(value)) and float(value) >= minimum and float(value) <= maximum
