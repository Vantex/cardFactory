class_name ProductionPlanningSystem
extends RefCounted

# Port of DSPONLINE 1.0.46 planning.ts; see tests/fixtures/parity/NOTICE.md.
const EXCLUDED_RECIPES := ["matrix_research", "solar_sail_launch", "carrier_rocket_launch", "ray_power"]
var state: GameState
static var _recipe_order: Array = []
static var _supported_items: Array = []

func _init(game_state: GameState) -> void:
	state = game_state

func get_recipe_options(item_id: String) -> Array:
	var result := []
	for recipe in _source_recipes():
		var id := String(recipe.get("source_id", recipe.id))
		if id not in EXCLUDED_RECIPES and _net_output(recipe, item_id) > 0 and _unlocked(recipe): result.append(id)
	return result

func create_plan(item_id: String, target: float = 60.0, planet_id: String = "all") -> Dictionary:
	if not _valid_item(item_id) or not _finite(target) or not _valid_planet(planet_id): return _failure("计划物品、产量或行星无效")
	var id := state.generate_id("plan")
	# Apply the source load-time limit before our verified save validates the plan.
	var name := ("%s %d/min" % [DataManager.get_item(item_id).name, int(maxf(1, floorf(target + 0.5)))]).strip_edges().left(40)
	state.production_plans.append({"id": id, "name": name, "itemId": item_id, "targetPerMinute": maxf(0.01, target), "planetId": planet_id, "recipeSelections": {}, "createdAt": state.elapsed_time})
	return {"ok": true, "id": id, "message": "生产计划已创建"}

func update_plan(id: String, changes: Dictionary) -> Dictionary:
	var index := _plan_index(id)
	if index < 0: return _failure("生产计划不存在")
	for field in changes:
		if field not in ["name", "itemId", "targetPerMinute", "planetId"]: return _failure("计划字段无效")
	if changes.has("name") and not changes.name is String: return _failure("计划名称无效")
	if changes.has("itemId") and not _valid_item(changes.itemId): return _failure("计划物品无效")
	if changes.has("targetPerMinute") and not _finite(changes.targetPerMinute): return _failure("目标产量无效")
	if changes.has("planetId") and not _valid_planet(changes.planetId): return _failure("计划行星无效")
	var plan: Dictionary = state.production_plans[index].duplicate(true)
	if changes.has("itemId") and changes.itemId != plan.itemId: plan.recipeSelections = {}
	for field in changes: plan[field] = changes[field]
	plan.name = String(changes.get("name", plan.name)).strip_edges().left(40)
	if plan.name.is_empty(): plan.name = state.production_plans[index].name
	plan.targetPerMinute = maxf(0.01, float(plan.targetPerMinute))
	state.production_plans[index] = plan
	return {"ok": true, "message": "生产计划已更新"}

func set_recipe(id: String, item_id: String, recipe_id: String) -> Dictionary:
	var index := _plan_index(id)
	var recipe := _recipe(recipe_id)
	if index < 0 or recipe.is_empty() or _net_output(recipe, item_id) <= 0 or not _unlocked(recipe): return _failure("配方不可用于该计划")
	state.production_plans[index].recipeSelections[item_id] = recipe_id
	return {"ok": true, "message": "计划配方已设置"}

func remove_plan(id: String) -> Dictionary:
	var index := _plan_index(id)
	if index < 0: return _failure("生产计划不存在")
	state.production_plans.remove_at(index)
	return {"ok": true, "message": "生产计划已删除"}

func calculate(plan: Dictionary) -> Dictionary:
	var accumulated := {}
	_walk(plan, String(plan.itemId), maxf(0.01, float(plan.targetPerMinute)), 0, [], accumulated)
	var inventory := _inventory(String(plan.planetId))
	var rates := _production_rates(String(plan.planetId))
	var requirements := []
	for entry in accumulated.values():
		var item := String(entry.itemId)
		var recipe: Dictionary = entry.recipe
		var building_id := String(recipe.get("building_id", _extractor(item)))
		var building := DataManager.get_building(building_id)
		var amount := maxf(0.0001, _net_output(recipe, item)) if not recipe.is_empty() else 1.0
		var per_machine := float(building.get("speed", 1)) * 60.0
		if not recipe.is_empty(): per_machine *= amount / float(recipe.duration)
		elif DataManager.get_item(item).get("kind") == "solid": per_machine *= state.get_technology_effect_multiplier("mining_speed") * GameModeSystem.new(state).multiplier("mining")
		var required := float(entry.requiredPerMinute)
		var existing := float(rates.get(item, 0))
		var deficit := maxf(0, required - existing)
		var stock := float(inventory.get(item, 0))
		var additional := int(ceilf(deficit / maxf(0.0001, per_machine)))
		var logistics := required
		if not recipe.is_empty():
			logistics = 0
			for input in recipe.inputs: logistics += required / amount * float(input.amount)
		var row := {"itemId": item, "depth": entry.depth, "requiredPerMinute": required, "existingPerMinute": existing, "deficitPerMinute": deficit, "inventory": stock, "coverageMinutes": stock / deficit if deficit > 0.0001 else null, "source": entry.source, "buildingId": String(building.get("source_id", building_id)), "machinesRequired": required / maxf(0.0001, per_machine), "additionalMachines": additional, "powerDemandKw": additional * float(building.get("power_demand", 0)), "logisticsPerMinute": logistics}
		if not recipe.is_empty(): row.recipeId = recipe.get("source_id", recipe.id)
		requirements.append(row)
	var order := {}
	for index in range(requirements.size()): order[requirements[index].itemId] = index
	requirements.sort_custom(func(a, b):
		if a.depth != b.depth: return a.depth < b.depth
		if a.deficitPerMinute != b.deficitPerMinute: return a.deficitPerMinute > b.deficitPerMinute
		return order[a.itemId] < order[b.itemId])
	var limiting := requirements.duplicate()
	for index in range(requirements.size()): order[requirements[index].itemId] = index
	limiting.sort_custom(func(a, b):
		var left: float = INF if a.coverageMinutes == null else float(a.coverageMinutes)
		var right: float = INF if b.coverageMinutes == null else float(b.coverageMinutes)
		if left != right: return left < right
		if a.deficitPerMinute != b.deficitPerMinute: return a.deficitPerMinute > b.deficitPerMinute
		return order[a.itemId] < order[b.itemId])
	var result := {"plan": plan.duplicate(true), "requirements": requirements, "totalMachines": 0, "additionalMachines": 0, "totalPowerDemandKw": 0.0, "totalLogisticsPerMinute": 0.0, "limitingItemId": limiting[0].itemId if not limiting.is_empty() else null}
	for row in requirements:
		result.totalMachines += int(ceilf(row.machinesRequired))
		result.additionalMachines += row.additionalMachines
		result.totalPowerDemandKw += row.powerDemandKw
		result.totalLogisticsPerMinute += row.logisticsPerMinute
	return result

func _walk(plan: Dictionary, item: String, rate: float, depth: int, path: Array, accumulated: Dictionary) -> void:
	if rate <= 0.0001 or depth > 18: return
	var cycle := path.has(item)
	var recipe := {} if cycle else _selected_recipe(plan, item)
	var existing: Dictionary = accumulated.get(item, {})
	accumulated[item] = {"itemId": item, "depth": mini(int(existing.get("depth", depth)), depth), "requiredPerMinute": float(existing.get("requiredPerMinute", 0)) + rate, "recipe": existing.get("recipe", {}) if not existing.get("recipe", {}).is_empty() else recipe, "source": "recipe" if not recipe.is_empty() or existing.get("source") == "recipe" else "resource"}
	if recipe.is_empty() or cycle: return
	var next_path := path.duplicate()
	next_path.append(item)
	var cycles := rate / maxf(0.0001, _net_output(recipe, item))
	for input in recipe.inputs:
		if input.item_id != item: _walk(plan, input.item_id, cycles * float(input.amount), depth + 1, next_path, accumulated)

func _selected_recipe(plan: Dictionary, item: String) -> Dictionary:
	var selected := _recipe(String(plan.recipeSelections.get(item, "")))
	if not selected.is_empty() and _net_output(selected, item) > 0 and _unlocked(selected): return selected
	for site in state.resource_sites.values():
		if site.get("item_id") == item: return {}
	for profile in state.source_galaxy.get("profiles", {}).values():
		if profile.get("resourceIds", []).has(item): return {}
	for planet in SourceGalaxySystem.catalog().planets.values():
		if float(planet.get("orbitalYields", {}).get(item, 0)) > 0: return {}
	var options := get_recipe_options(item)
	return _recipe(options[0]) if not options.is_empty() else {}

func _inventory(planet: String) -> Dictionary:
	var totals := {}
	for id in state.planet_inventories:
		_add_inventory(totals, state.get_planet_inventory(id))
	# Frozen planning scopes equipment, but its statistics call still totals every
	# planet tray. Preserve that observable contract and explain it in the UI.
	var cargo := state.cursor_payload
	if cargo.get("item_id", "") != "": totals[cargo.item_id] = float(totals.get(cargo.item_id, 0)) + floorf(float(cargo.amount))
	for building in state.buildings.values():
		if planet != "all" and planet != building.get("planet_id", state.active_planet_id): continue
		_add_inventory(totals, building.get("input_buffer", {}))
		_add_inventory(totals, building.get("output_buffer", {}))
	return totals

static func _add_inventory(totals: Dictionary, buffer: Dictionary) -> void:
	for item in buffer: totals[item] = float(totals.get(item, 0)) + floorf(float(buffer[item]))

func _production_rates(planet: String) -> Dictionary:
	var rates := {}
	for building in state.buildings.values():
		var planet_id := String(building.get("planet_id", state.active_planet_id))
		if planet != "all" and planet != planet_id: continue
		var definition := DataManager.get_building(String(building.type))
		var recipe := DataManager.get_recipe(String(building.get("recipe_id", "")))
		if definition.get("kind") == "extractor":
			var item := String(building.get("output_item", "iron_ore"))
			rates[item] = float(rates.get(item, 0)) + float(building.get("last_production_per_minute", 0))
			continue
		if recipe.is_empty() or not (recipe.has("source_id") or recipe.has("source_content_pack")) or definition.get("kind") != "processor": continue
		var speed := SourceTechnologyEffects.multiplier(state, "production_speed") * GameModeSystem.new(state).multiplier("production") * SourceGalaxySystem.new(state).production_multiplier(planet_id, String(building.type))
		var spray := ProliferatorSystem.profile(building, recipe)
		var cycles := float(building.get("speed", definition.get("speed", 1))) * speed * float(spray.speed) * 60.0 / float(recipe.duration) * float(building.get("production_utilization", 0))
		for output in recipe.outputs: rates[output.item_id] = float(rates.get(output.item_id, 0)) + cycles * float(output.amount) * (1.0 + float(spray.bonus))
	for item in rates: rates[item] = floorf(float(rates[item]) * 100 + 0.5) / 100.0
	return rates

func _source_recipes() -> Array:
	# Preserve source catalog order; the first unlocked alternative is the source default.
	var result := []
	if _recipe_order.is_empty():
		var file := FileAccess.open("res://data/planning/source_recipe_order.json", FileAccess.READ)
		if file != null: _recipe_order = JSON.parse_string(file.get_as_text()).recipes
	for id in _recipe_order:
		var recipe := _recipe(String(id))
		if not recipe.is_empty(): result.append(recipe)
	for recipe in DataManager.all_recipes.values():
		if recipe.has("source_content_pack"): result.append(recipe)
	return result

static func _recipe(id: String) -> Dictionary:
	return get_recipe_definition(id)

static func get_recipe_definition(id: String) -> Dictionary:
	var custom := DataManager.get_recipe(id)
	if custom.has("source_content_pack"): return custom
	var recipe := DataManager.get_recipe("dsp_" + id)
	return recipe if recipe.get("source_id", "") == id else {}

static func get_building_definition(id: String) -> Dictionary:
	var exact := DataManager.get_building(id)
	if exact.has("source_content_pack"): return exact
	var building := DataManager.get_building("dsp_" + id)
	return building if building.get("source_id", "") == id else exact

func _unlocked(recipe: Dictionary) -> bool:
	var tech := String(recipe.get("required_source_technology", ""))
	return DataManager.source_technology_unlocked(state, tech)

static func _net_output(recipe: Dictionary, item: String) -> float:
	var amount := 0.0
	for output in recipe.get("outputs", []):
		if output.item_id == item: amount += float(output.amount)
	for input in recipe.get("inputs", []):
		if input.item_id == item: amount -= float(input.amount)
	return amount

static func _extractor(item: String) -> String:
	return "dsp_oil_extractor" if item == "crude_oil" else "dsp_water_pump" if item in ["water", "sulfuric_acid"] else "dsp_mining_machine"

func _plan_index(id: String) -> int:
	for index in range(state.production_plans.size()):
		if state.production_plans[index].id == id: return index
	return -1

static func _finite(value: Variant) -> bool:
	return (value is int or value is float) and is_finite(float(value))

static func _valid_item(value: Variant) -> bool:
	return value is String and get_supported_items().has(value)

static func get_supported_items() -> Array:
	if _supported_items.is_empty():
		var file := FileAccess.open("res://data/planning/source_recipe_order.json", FileAccess.READ)
		if file != null: _supported_items = JSON.parse_string(file.get_as_text()).items
	var result := _supported_items.filter(func(id): return not DataManager.get_item(id).is_empty())
	for item in DataManager.all_items.values():
		if item.has("source_content_pack") and item.id not in result: result.append(item.id)
	return result

static func _valid_planet(value: Variant) -> bool:
	return value is String and (value == "all" or SourceGalaxySystem.catalog().planets.has(value))

static func _failure(message: String) -> Dictionary:
	return {"ok": false, "message": message}

static func validate(value: Variant) -> Array:
	if not value is Array: return ["生产计划必须是数组"]
	var ids := {}
	for plan in value:
		if not plan is Dictionary or not plan.get("id") is String or not String(plan.get("id", "")).begins_with("plan_") or ids.has(plan.get("id")): return ["生产计划 ID 无效或重复"]
		ids[plan.id] = true
		if not plan.get("name") is String or String(plan.name).is_empty() or plan.name.length() > 40 or not _valid_item(plan.get("itemId")) or not _valid_planet(plan.get("planetId")): return ["生产计划名称或引用无效"]
		if not _finite(plan.get("targetPerMinute")) or float(plan.targetPerMinute) < 0.01 or not _finite(plan.get("createdAt")) or float(plan.createdAt) < 0: return ["生产计划数值无效"]
		if not plan.get("recipeSelections") is Dictionary: return ["计划配方集合无效"]
		for item in plan.recipeSelections:
			if not _valid_item(item) or not plan.recipeSelections[item] is String or _net_output(_recipe(plan.recipeSelections[item]), item) <= 0: return ["计划配方引用无效"]
	return []
