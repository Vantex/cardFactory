class_name InventorySystem
extends RefCounted

const MAX_PLANET_STACK := 999.0
const MAX_CURSOR_STACK := 999.0
const AMOUNT_EPSILON := 0.0000001

var game_state: GameState

func _init(state: GameState) -> void:
	game_state = state

func get_planet_inventory(planet_id: String = "") -> Dictionary:
	return game_state.planet_inventory if planet_id.is_empty() else game_state.get_planet_inventory(planet_id)

func try_add(item_id: String, amount: float, planet_id: String = "") -> Dictionary:
	var error := _validate_item_amount(item_id, amount)
	if not error.is_empty():
		return error
	if not can_add_batch({item_id: amount}, planet_id):
		return _failure("库存容量不足")
	var inventory := get_planet_inventory(planet_id)
	inventory[item_id] = float(inventory.get(item_id, 0.0)) + amount
	return _success("物资已加入行星托盘")

func try_remove(item_id: String, amount: float, planet_id: String = "") -> Dictionary:
	var error := _validate_item_amount(item_id, amount)
	if not error.is_empty():
		return error
	if not can_remove_batch({item_id: amount}, planet_id):
		return _failure("行星托盘物资不足")
	_remove_without_validation(item_id, amount, planet_id)
	return _success("物资已从行星托盘取出")

func try_pick_up(item_id: String, amount: float) -> Dictionary:
	var error := _validate_item_amount(item_id, amount)
	if not error.is_empty():
		return error
	var cursor_item := String(game_state.cursor_payload.get("item_id", ""))
	var cursor_amount := float(game_state.cursor_payload.get("amount", 0.0))
	if not cursor_item.is_empty() and cursor_item != item_id:
		return _failure("光标正在持有其他物资")
	if cursor_amount + amount > MAX_CURSOR_STACK + AMOUNT_EPSILON:
		return _failure("光标载荷超过上限")
	if not can_remove_batch({item_id: amount}):
		return _failure("行星托盘物资不足")
	_remove_without_validation(item_id, amount)
	game_state.cursor_payload = {"item_id": item_id, "amount": cursor_amount + amount}
	return _success("物资已拿到光标")

func try_put_down(amount: float) -> Dictionary:
	var item_id := String(game_state.cursor_payload.get("item_id", ""))
	var cursor_amount := float(game_state.cursor_payload.get("amount", 0.0))
	if item_id.is_empty() or cursor_amount <= AMOUNT_EPSILON:
		return _failure("光标没有物资")
	var error := _validate_item_amount(item_id, amount)
	if not error.is_empty():
		return error
	if amount > cursor_amount + AMOUNT_EPSILON:
		return _failure("光标物资不足")
	if not can_add_batch({item_id: amount}):
		return _failure("行星托盘容量不足")
	game_state.planet_inventory[item_id] = float(game_state.planet_inventory.get(item_id, 0.0)) + amount
	var remaining := maxf(cursor_amount - amount, 0.0)
	game_state.cursor_payload = {"item_id": "", "amount": 0.0} if remaining <= AMOUNT_EPSILON else {"item_id": item_id, "amount": remaining}
	return _success("光标物资已放回行星托盘")

func can_add_batch(items: Dictionary, planet_id: String = "") -> bool:
	var inventory := get_planet_inventory(planet_id)
	for item_key in items:
		var item_id := String(item_key)
		var amount := float(items[item_key])
		if not _validate_item_amount(item_id, amount).is_empty():
			return false
		if float(inventory.get(item_id, 0.0)) + amount > PlanetTraySystem.new(game_state).limit(planet_id) + AMOUNT_EPSILON:
			return false
	return true

func can_remove_batch(items: Dictionary, planet_id: String = "") -> bool:
	var inventory := get_planet_inventory(planet_id)
	for item_key in items:
		var item_id := String(item_key)
		var amount := float(items[item_key])
		if not _validate_item_amount(item_id, amount).is_empty():
			return false
		if float(inventory.get(item_id, 0.0)) + AMOUNT_EPSILON < amount:
			return false
	return true

func try_add_batch(items: Dictionary, planet_id: String = "") -> Dictionary:
	if items.is_empty() or not can_add_batch(items, planet_id):
		return _failure("行星托盘容量不足或物资数量无效")
	var inventory := get_planet_inventory(planet_id)
	for item_key in items:
		var item_id := String(item_key)
		inventory[item_id] = float(inventory.get(item_id, 0.0)) + float(items[item_key])
	return _success("批量物资已加入行星托盘")

func try_remove_batch(items: Dictionary, planet_id: String = "") -> Dictionary:
	if items.is_empty() or not can_remove_batch(items, planet_id):
		return _failure("行星托盘物资不足或数量无效")
	for item_key in items:
		_remove_without_validation(String(item_key), float(items[item_key]), planet_id)
	return _success("批量物资已从行星托盘取出")

func try_supply_recipe(building_id: String, batches: int = 1) -> Dictionary:
	var building: Dictionary = game_state.buildings.get(building_id, {})
	if building.is_empty() or String(building.get("planet_id", "")) != game_state.active_planet_id or batches <= 0:
		return _failure("只能向当前行星建筑投料")
	var recipe := DataManager.get_recipe(String(building.get("recipe_id", "")))
	if recipe.is_empty() or not DataManager.is_recipe_supported_by_building(recipe, String(building.get("type", ""))):
		return _failure("请先选择有效配方")
	var required: Dictionary = {}
	for ingredient in recipe.get("inputs", []):
		var item_id := String(ingredient.item_id)
		required[item_id] = float(required.get(item_id, 0.0)) + float(ingredient.amount) * batches
	var buffer: Dictionary = building.get("input_buffer", {}).duplicate(true)
	var definition := DataManager.get_building(String(building.get("type", "")))
	var capacity := float(building.get("input_buffer_capacity", definition.get("input_buffer_capacity", 60.0)))
	for item_id in required:
		if float(buffer.get(item_id, 0.0)) + float(required[item_id]) > capacity + AMOUNT_EPSILON:
			return _failure("建筑输入容量不足")
	if not try_remove_batch(required).get("ok", false):
		return _failure("行星托盘材料不足")
	for item_id in required:
		buffer[item_id] = float(buffer.get(item_id, 0.0)) + float(required[item_id])
	building["input_buffer"] = buffer
	return _success("已投入配方材料")

func try_collect_output(building_id: String, item_id: String = "", amount: float = 0.0) -> Dictionary:
	var building: Dictionary = game_state.buildings.get(building_id, {})
	if building.is_empty() or String(building.get("planet_id", "")) != game_state.active_planet_id:
		return _failure("只能收取当前行星建筑产物")
	var site: Dictionary = game_state.resource_sites.get(String(building.get("resource_site_id", "")), {})
	var definition := DataManager.get_building(String(building.get("type", "")))
	if not game_state.source_galaxy.is_empty() and definition.has("source_id") and definition.get("kind") == "extractor" and site.has("output_buffer") and item_id.is_empty() and amount == 0:
		return try_collect_resource_output(String(site.id))
	var buffer: Dictionary = building.get("output_buffer", {}).duplicate(true)
	var items := buffer.duplicate(true)
	if not item_id.is_empty():
		if not _validate_item_amount(item_id, amount).is_empty() or float(buffer.get(item_id, 0.0)) + AMOUNT_EPSILON < amount:
			return _failure("建筑产物不足")
		items = {item_id: amount}
	if not try_add_batch(items).get("ok", false):
		return _failure("没有可收取产物或托盘容量不足")
	for key in items:
		var remaining := float(buffer[key]) - float(items[key])
		if remaining <= AMOUNT_EPSILON:
			buffer.erase(key)
		else:
			buffer[key] = remaining
	building["output_buffer"] = buffer
	return _success("产物已收进行星托盘")

func try_collect_resource_output(site_id: String) -> Dictionary:
	var site: Dictionary = game_state.resource_sites.get(site_id, {})
	if game_state.source_galaxy.is_empty() or site.is_empty():
		return _failure("请选择源版资源点")
	var item := String(site.item_id)
	var output := preload("res://scripts/game/SourceResourceOutputSystem.gd")
	# Whole-unit collection keeps legal native fractions with their original owners.
	var available := floorf(output.raw_amount(game_state, site))
	var inventory := get_planet_inventory()
	var free := floorf(maxf(0, PlanetTraySystem.new(game_state).limit() - float(inventory.get(item, 0))))
	var moved := minf(available, free)
	if moved < 1: return _failure("没有可收取产物或托盘容量不足")
	if output.take(game_state, site, moved) != moved: return _failure("资源输出不足")
	inventory[item] = float(inventory.get(item, 0)) + moved
	return {"ok": true, "amount": moved, "message": "矿脉产物已收进行星托盘"}

func _remove_without_validation(item_id: String, amount: float, planet_id: String = "") -> void:
	var inventory := get_planet_inventory(planet_id)
	var remaining := maxf(float(inventory.get(item_id, 0.0)) - amount, 0.0)
	if remaining <= AMOUNT_EPSILON:
		inventory.erase(item_id)
	else:
		inventory[item_id] = remaining

func _validate_item_amount(item_id: String, amount: float) -> Dictionary:
	if item_id.is_empty():
		return _failure("物资 ID 不能为空")
	if amount <= 0.0 or is_nan(amount) or is_inf(amount):
		return _failure("物资数量必须是有限正数")
	return {}

func _success(message: String) -> Dictionary:
	return {"ok": true, "message": message}

func _failure(message: String) -> Dictionary:
	return {"ok": false, "message": message}
