class_name CraftingPlanner
extends RefCounted

const MAX_STEPS := 512
const MAX_DEPTH := 64
var state: GameState
var planet_id: String

func _init(game_state: GameState, planet: String = "") -> void:
	state = game_state
	planet_id = state.active_planet_id if planet.is_empty() else planet

func plan(target: String, quantity: int, construction: bool = false) -> Dictionary:
	if quantity < 1 or quantity > 99: return _failure("数量必须为 1～99")
	var context := {"stock": state.get_planet_inventory(planet_id).duplicate(true), "work": {}, "reserved": {}, "steps": [], "missing": {}}
	var definition: Dictionary = DataManager.construction.get(target, {}) if construction else DataManager.get_recipe(target)
	if definition.is_empty(): return _failure("未知制造目标")
	if not DataManager.source_technology_unlocked(state, String(definition.get("required_source_technology", ""))): return _failure("科技未解锁：" + String(definition.required_source_technology))
	if not construction and (not can_handcraft(definition)): return _failure("该配方不能递归制造")
	var inputs: Dictionary = definition.costs if construction else _items(definition.inputs)
	var ok := true
	for item in inputs:
		if not _need(String(item), float(inputs[item]) * quantity, context, [target], 0): ok = false
	if not ok: return {"ok": false, "message": "材料不足、依赖成环或配方未解锁", "missing": context.missing}
	var outputs: Dictionary = {target: float(definition.output_amount) * quantity} if construction else _scale(_items(definition.outputs), quantity)
	context.steps.append({"recipe_id": target, "inputs": _scale(inputs, quantity), "outputs": outputs, "duration": float(quantity) if construction else float(definition.duration) * quantity, "construction": construction})
	var final_items: Dictionary = context.work.duplicate(true)
	if not construction:
		for item in outputs: final_items[item] = float(final_items.get(item, 0)) + outputs[item]
	var pending := pending_outputs(state, planet_id)
	for item in final_items:
		if float(state.get_planet_inventory(planet_id).get(item, 0)) - float(context.reserved.get(item, 0)) + final_items[item] + float(pending.items.get(item, 0)) > InventorySystem.MAX_PLANET_STACK:
			return _failure("副产物或目标物品库存容量不足：" + String(item))
	if construction and float(state.construction_inventory.get(construction_stock_id(target), 0)) + float(outputs[target]) + float(pending.kits.get(construction_stock_id(target), 0)) > 99: return _failure("施工件容量不足")
	var duration := 0.0
	for step in context.steps: duration += float(step.duration)
	return {"ok": true, "target": target, "quantity": quantity, "construction": construction, "planet_id": planet_id, "reserved": context.reserved, "steps": context.steps, "duration": duration, "final_items": final_items}

func _need(item: String, amount: float, context: Dictionary, stack: Array, depth: int) -> bool:
	if depth > MAX_DEPTH or context.steps.size() >= MAX_STEPS: return false
	var from_work := minf(amount, float(context.work.get(item, 0)))
	context.work[item] = float(context.work.get(item, 0)) - from_work
	amount -= from_work
	var from_stock := minf(amount, float(context.stock.get(item, 0)))
	context.stock[item] = float(context.stock.get(item, 0)) - from_stock
	context.reserved[item] = float(context.reserved.get(item, 0)) + from_stock
	amount -= from_stock
	if amount <= 0.0000001: return true
	var keys := DataManager.all_recipes.keys()
	keys.sort()
	for id in keys:
		var recipe: Dictionary = DataManager.all_recipes[id]
		if not String(id).begins_with("dsp_") or stack.has(id) or not can_handcraft(recipe): continue
		if not DataManager.source_technology_unlocked(state, String(recipe.get("required_source_technology", ""))): continue
		var output := float(_items(recipe.outputs).get(item, 0))
		if output <= 0: continue
		var trial := context.duplicate(true)
		var cycles := ceili(amount / output)
		var valid := true
		var next_stack := stack.duplicate()
		next_stack.append(id)
		for input in recipe.inputs:
			if not _need(String(input.item_id), float(input.amount) * cycles, trial, next_stack, depth + 1): valid = false
		if not valid: continue
		var outputs := _scale(_items(recipe.outputs), cycles)
		for produced in outputs: trial.work[produced] = float(trial.work.get(produced, 0)) + outputs[produced]
		trial.work[item] -= amount
		trial.steps.append({"recipe_id": id, "inputs": _scale(_items(recipe.inputs), cycles), "outputs": outputs, "duration": float(recipe.duration) * cycles, "construction": false})
		context.merge(trial, true)
		return true
	context.missing[item] = float(context.missing.get(item, 0)) + amount
	return false

static func _items(entries: Array) -> Dictionary:
	var result := {}
	for entry in entries: result[String(entry.item_id)] = float(entry.amount)
	return result

static func _scale(items: Dictionary, quantity: int) -> Dictionary:
	var result := {}
	for item in items: result[item] = float(items[item]) * quantity
	return result

static func _failure(message: String) -> Dictionary:
	return {"ok": false, "message": message, "missing": {}}

static func can_handcraft(recipe: Dictionary) -> bool:
	if recipe.is_empty() or recipe.get("operation", "production") != "production" or recipe.get("inputs", []).is_empty(): return false
	var building := DataManager.get_building(String(recipe.get("building_id", "")))
	return building.get("source_id", building.get("id", "")) != "energy_exchanger"

static func pending_outputs(game_state: GameState, planet: String) -> Dictionary:
	var items := {}
	var kits := {}
	for job in game_state.production_orders:
		if job.construction:
			kits[construction_stock_id(job.target)] = float(kits.get(construction_stock_id(job.target), 0)) + float(job.steps.back().outputs[job.target])
		if job.planet_id != planet: continue
		var final: Dictionary = job.work.duplicate(true)
		for index in range(int(job.step), job.steps.size()):
			var step: Dictionary = job.steps[index]
			for item in step.inputs: final[item] = float(final.get(item, 0)) - float(step.inputs[item])
			if not step.construction:
				for item in step.outputs: final[item] = float(final.get(item, 0)) + float(step.outputs[item])
		for item in final: items[item] = float(items.get(item, 0)) + maxf(float(final[item]), 0)
	return {"items": items, "kits": kits}

static func construction_stock_id(target: String) -> String:
	return target.trim_prefix("dsp_") if target in ["dsp_conveyor_belt_mk1", "dsp_conveyor_belt_mk2", "dsp_conveyor_belt_mk3"] else target
