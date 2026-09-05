class_name HandcraftSystem
extends RefCounted

const AMOUNT_EPSILON := 0.0000001
const MAX_CONSTRUCTION_STACK := 99.0
const RECIPES := {
	"handcraft_gear": {
		"name": "齿轮",
		"inputs": {"iron_ingot": 1.0},
		"outputs": {"gear": 1.0},
		"output_target": "planet",
		"duration": 0.5,
	},
	"handcraft_miner": {
		"name": "矿机施工件",
		"inputs": {"gear": 1.0, "iron_ingot": 2.0},
		"outputs": {"miner": 1.0},
		"output_target": "construction",
		"duration": 1.0,
	},
	"handcraft_smelter": {
		"name": "熔炉施工件",
		"inputs": {"iron_ingot": 3.0, "stone": 2.0},
		"outputs": {"smelter": 1.0},
		"output_target": "construction",
		"duration": 1.5,
	},
	"handcraft_assembler": {
		"name": "制造台施工件",
		"inputs": {"copper_ingot": 2.0, "gear": 2.0, "iron_ingot": 4.0},
		"outputs": {"assembling_machine_mk1": 1.0},
		"output_target": "construction",
		"duration": 2.0,
	},
	"handcraft_generator": {
		"name": "发电机施工件",
		"inputs": {"copper_ingot": 2.0, "gear": 1.0, "iron_ingot": 4.0},
		"outputs": {"power_generator": 1.0},
		"output_target": "construction",
		"duration": 2.0,
	},
	"handcraft_matrix_lab": {
		"name": "矩阵研究站施工件",
		"inputs": {"circuit": 2.0, "copper_ingot": 2.0, "iron_ingot": 4.0},
		"outputs": {"matrix_lab": 1.0},
		"output_target": "construction",
		"duration": 3.0,
	},
	"handcraft_logistics_drone": {
		"name": "物流运输机",
		"inputs": {"gear": 2.0, "processor": 1.0, "titanium_alloy": 2.0},
		"outputs": {"logistics_drone": 1.0},
		"output_target": "planet",
		"duration": 2.0,
	},
	"handcraft_logistics_vessel": {
		"name": "物流飞船",
		"inputs": {"gear": 4.0, "processor": 2.0, "titanium_alloy": 4.0},
		"outputs": {"logistics_vessel": 1.0},
		"output_target": "planet",
		"duration": 4.0,
	},
}

var game_state: GameState

func _init(state: GameState) -> void:
	game_state = state

func preview_craft(recipe_id: String, quantity: int) -> Dictionary:
	if not RECIPES.has(recipe_id):
		return {"ok": false, "message": "未知手工配方", "required": {}, "missing": {}, "upstream": {}}
	if quantity <= 0:
		return {"ok": false, "message": "制造数量必须是正整数", "required": {}, "missing": {}, "upstream": {}}
	var recipe: Dictionary = RECIPES[recipe_id]
	var required := _scale_items(recipe.get("inputs", {}), quantity)
	var missing: Dictionary = {}
	for item_key in required:
		var item_id := String(item_key)
		var shortage := float(required[item_key]) - float(game_state.planet_inventory.get(item_id, 0.0))
		if shortage > AMOUNT_EPSILON:
			missing[item_id] = shortage
	var upstream: Dictionary = {}
	for missing_key in missing:
		var upstream_recipe_id := _find_planet_output_recipe(String(missing_key))
		if upstream_recipe_id.is_empty():
			continue
		var upstream_recipe: Dictionary = RECIPES[upstream_recipe_id]
		var output_amount := float(upstream_recipe.get("outputs", {}).get(missing_key, 1.0))
		var upstream_quantity := int(ceil(float(missing[missing_key]) / output_amount))
		upstream[String(missing_key)] = {
			"recipe_id": upstream_recipe_id,
			"quantity": upstream_quantity,
			"inputs": _scale_items(upstream_recipe.get("inputs", {}), upstream_quantity),
		}
	return {
		"ok": true,
		"recipe_id": recipe_id,
		"quantity": quantity,
		"required": required,
		"missing": missing,
		"upstream": upstream,
		"can_queue": missing.is_empty() and _can_reserve_output(recipe, quantity),
	}

func queue_craft(recipe_id: String, quantity: int) -> Dictionary:
	var preview := preview_craft(recipe_id, quantity)
	if not preview.get("ok", false):
		return {"ok": false, "message": preview.get("message", "手工配方不可用")}
	if not preview.get("missing", {}).is_empty():
		return {"ok": false, "message": "手工制造材料不足", "missing": preview.get("missing", {}).duplicate(true)}
	var recipe: Dictionary = RECIPES[recipe_id]
	if not _can_reserve_output(recipe, quantity, game_state.active_planet_id):
		return {"ok": false, "message": "制造输出库存容量不足"}
	var inventory := InventorySystem.new(game_state)
	var reservation := inventory.try_remove_batch(preview.get("required", {}))
	if not reservation.get("ok", false):
		return {"ok": false, "message": "手工制造材料预留失败"}
	var job := {
		"id": game_state.generate_id("craft"),
		"planet_id": game_state.active_planet_id,
		"recipe_id": recipe_id,
		"quantity_total": quantity,
		"quantity_remaining": quantity,
		"progress": 0.0,
	}
	game_state.handcraft_queue.append(job)
	return {"ok": true, "message": "已加入手工制造队列", "id": job.id}

func update(delta: float) -> void:
	var remaining_delta := maxf(delta, 0.0)
	while remaining_delta > AMOUNT_EPSILON and not game_state.handcraft_queue.is_empty():
		var job: Dictionary = game_state.handcraft_queue[0]
		var recipe_id := String(job.get("recipe_id", ""))
		if not RECIPES.has(recipe_id):
			return
		var recipe: Dictionary = RECIPES[recipe_id]
		var duration := maxf(float(recipe.get("duration", 0.0)), AMOUNT_EPSILON)
		var progress := clampf(float(job.get("progress", 0.0)), 0.0, duration)
		var time_to_completion := maxf(duration - progress, 0.0)
		var consumed_time := minf(remaining_delta, time_to_completion)
		progress += consumed_time
		remaining_delta -= consumed_time
		job["progress"] = progress
		game_state.handcraft_queue[0] = job
		if progress + AMOUNT_EPSILON < duration:
			return
		var planet_id := String(job.get("planet_id", game_state.active_planet_id))
		if not _can_deliver_one(recipe, planet_id):
			return
		_deliver_one(recipe, planet_id)
		job["quantity_remaining"] = int(job.get("quantity_remaining", 0)) - 1
		job["progress"] = 0.0
		if int(job["quantity_remaining"]) <= 0:
			game_state.handcraft_queue.pop_front()
		else:
			game_state.handcraft_queue[0] = job

func get_recipe(recipe_id: String) -> Dictionary:
	return RECIPES.get(recipe_id, {}).duplicate(true)

func get_recipe_ids() -> Array:
	var recipe_ids: Array = RECIPES.keys()
	recipe_ids.sort()
	return recipe_ids

func _scale_items(items: Dictionary, quantity: int) -> Dictionary:
	var scaled: Dictionary = {}
	var item_ids: Array = items.keys()
	item_ids.sort()
	for item_key in item_ids:
		scaled[String(item_key)] = float(items[item_key]) * quantity
	return scaled

func _find_planet_output_recipe(item_id: String) -> String:
	for recipe_id in get_recipe_ids():
		var recipe: Dictionary = RECIPES[recipe_id]
		if recipe.get("output_target", "") == "planet" and recipe.get("outputs", {}).has(item_id):
			return String(recipe_id)
	return ""

func _can_reserve_output(recipe: Dictionary, quantity: int, planet_id: String = "") -> bool:
	var target := String(recipe.get("output_target", ""))
	var outputs: Dictionary = recipe.get("outputs", {})
	for item_key in outputs:
		var item_id := String(item_key)
		var resolved_planet_id := game_state.active_planet_id if planet_id.is_empty() else planet_id
		var current := float(game_state.construction_inventory.get(item_id, 0.0)) if target == "construction" else float(game_state.get_planet_inventory(resolved_planet_id).get(item_id, 0.0))
		var reserved := _reserved_output(target, item_id, resolved_planet_id)
		var limit := MAX_CONSTRUCTION_STACK if target == "construction" else InventorySystem.MAX_PLANET_STACK
		if current + reserved + float(outputs[item_key]) * quantity > limit + AMOUNT_EPSILON:
			return false
	return true

func _reserved_output(target: String, item_id: String, planet_id: String) -> float:
	var reserved := 0.0
	for job_value in game_state.handcraft_queue:
		var job: Dictionary = job_value
		var recipe: Dictionary = RECIPES.get(String(job.get("recipe_id", "")), {})
		if recipe.get("output_target", "") != target:
			continue
		if target == "planet" and String(job.get("planet_id", "")) != planet_id:
			continue
		reserved += float(recipe.get("outputs", {}).get(item_id, 0.0)) * int(job.get("quantity_remaining", 0))
	return reserved

func _can_deliver_one(recipe: Dictionary, planet_id: String) -> bool:
	var target := String(recipe.get("output_target", ""))
	var outputs: Dictionary = recipe.get("outputs", {})
	if target == "planet":
		return InventorySystem.new(game_state).can_add_batch(outputs, planet_id)
	for item_key in outputs:
		if float(game_state.construction_inventory.get(item_key, 0.0)) + float(outputs[item_key]) > MAX_CONSTRUCTION_STACK + AMOUNT_EPSILON:
			return false
	return true

func _deliver_one(recipe: Dictionary, planet_id: String) -> void:
	var outputs: Dictionary = recipe.get("outputs", {})
	if recipe.get("output_target", "") == "planet":
		InventorySystem.new(game_state).try_add_batch(outputs, planet_id)
		return
	for item_key in outputs:
		var item_id := String(item_key)
		game_state.construction_inventory[item_id] = float(game_state.construction_inventory.get(item_id, 0.0)) + float(outputs[item_key])
