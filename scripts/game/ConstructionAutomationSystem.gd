class_name ConstructionAutomationSystem
extends RefCounted

var state: GameState
func _init(game_state: GameState) -> void:
	state = game_state

func queue(target: String, quantity: int, construction: bool = false, planet_id: String = "", center_id: String = "") -> Dictionary:
	if not center_id.is_empty():
		var center: Dictionary = state.buildings.get(center_id, {})
		var planet := state.active_planet_id if planet_id.is_empty() else planet_id
		if PowerGridSystem.kind_id(center) != "construction_center" or center.get("planet_id") != planet: return {"ok": false, "message": "制造中心不存在或不属于目标行星"}
	if state.production_orders.size() >= 64: return {"ok": false, "message": "制造队列已满"}
	var plan := CraftingPlanner.new(state, planet_id).plan(target, quantity, construction)
	if not plan.ok: return plan
	var reservation := {}
	for item in plan.reserved:
		if float(plan.reserved[item]) > 0: reservation[item] = plan.reserved[item]
	var inventory := InventorySystem.new(state)
	if not inventory.can_remove_batch(reservation, plan.planet_id): return {"ok": false, "message": "材料已变化，请重新预览"}
	var removed := inventory.try_remove_batch(reservation, plan.planet_id)
	if not removed.ok: return removed
	var job := {"id": state.generate_id("manufacture"), "planet_id": plan.planet_id, "target": target, "center_id": center_id, "construction": construction, "quantity": float(quantity), "steps": plan.steps, "step": 0.0, "progress": 0.0, "work": reservation, "paused": false, "status": "queued"}
	state.production_orders.append(job)
	return {"ok": true, "message": "材料已预留，开始递归制造", "id": job.id}

func configure_center(id: String, target: String, desired: int) -> Dictionary:
	var building: Dictionary = state.buildings.get(id, {})
	if DataManager.get_building(String(building.get("type", ""))).get("source_id") != "construction_center" or not DataManager.construction.has(target) or desired < 0 or desired > 99:
		return {"ok": false, "message": "无效制造中心或目标数量"}
	if building.get("interaction_locked", false): return {"ok": false, "message": "制造中心已锁定"}
	var targets: Dictionary = building.get("construction_targets", {})
	if desired == 0: targets.erase(target)
	else: targets[target] = float(desired)
	building["construction_targets"] = targets
	return {"ok": true, "message": "目标库存已更新"}

func update(delta: float) -> void:
	if delta <= 0: return
	var ids := state.buildings.keys()
	ids.sort()
	for id in ids:
		var building: Dictionary = state.buildings[id]
		if building.get("automation_paused", false) or not building.has("construction_targets"): continue
		if state.production_orders.any(func(job): return job.center_id == id): continue
		for target in building.construction_targets:
			var pending := 0.0
			for job in state.production_orders:
				if job.target == target and job.construction: pending += float(job.steps.back().outputs[job.target])
			var missing := int(building.construction_targets[target] - state.construction_inventory.get(CraftingPlanner.construction_stock_id(target), 0) - pending)
			if missing > 0:
				var result := queue(target, 1, true, String(building.planet_id), id)
				building["automation_status"] = result.message
				break
	for job in state.production_orders.duplicate():
		if job.paused: continue
		var factor := 1.0
		if not String(job.center_id).is_empty():
			var center: Dictionary = state.buildings.get(job.center_id, {})
			if center.get("automation_paused", false):
				job.status = "paused"
				continue
			factor = float(center.get("power_efficiency", 0)) if float(center.get("power_requested", 0)) > 0 else 0.0
		if factor <= 0:
			job.status = "no_power"
			continue
		job.progress += delta * factor
		while int(job.step) < job.steps.size():
			var step: Dictionary = job.steps[int(job.step)]
			if job.progress + 0.0000001 < float(step.duration): break
			for item in step.inputs: job.work[item] = maxf(float(job.work.get(item, 0)) - float(step.inputs[item]), 0)
			var statistics := StatisticsSystem.new(state)
			for item in step.inputs: statistics.record_consumed(item, step.inputs[item], "", job.planet_id)
			if not step.construction:
				for item in step.outputs: statistics.record_produced(item, step.outputs[item], "", job.planet_id)
				for item in step.outputs: job.work[item] = float(job.work.get(item, 0)) + float(step.outputs[item])
			job.progress = maxf(job.progress - float(step.duration), 0)
			job.step += 1.0
		job.status = "running"
		if int(job.step) == job.steps.size(): _deliver(job)

func _deliver(job: Dictionary) -> void:
	var items := {}
	for item in job.work:
		if float(job.work[item]) > 0: items[item] = job.work[item]
	var inventory := InventorySystem.new(state)
	var outputs: Dictionary = job.steps.back().outputs
	if not inventory.can_add_batch(items, job.planet_id):
		job.status = "output_full"
		return
	if job.construction and float(state.construction_inventory.get(CraftingPlanner.construction_stock_id(job.target), 0)) + float(outputs[job.target]) > 99:
		job.status = "output_full"
		return
	inventory.try_add_batch(items, job.planet_id)
	if job.construction: state.construction_inventory[CraftingPlanner.construction_stock_id(job.target)] = float(state.construction_inventory.get(CraftingPlanner.construction_stock_id(job.target), 0)) + float(outputs[job.target])
	state.production_orders.erase(job)

static func validate(orders: Variant, planets: Dictionary, buildings: Variant = null) -> Array[String]:
	var errors: Array[String] = []
	if not orders is Array or orders.size() > 64: return ["无效递归制造队列"]
	var ids := {}
	for job in orders:
		if not job is Dictionary or not job.get("id") is String or ids.has(job.get("id")) or not planets.has(job.get("planet_id")):
			errors.append("无效制造任务标识或行星")
			continue
		ids[job.id] = true
		if not job.get("steps") is Array or job.steps.is_empty() or job.steps.size() > 513 or not job.get("work") is Dictionary or not job.get("paused") is bool or not job.get("construction") is bool or not job.get("center_id") is String or not job.get("target") is String or not job.get("status") is String:
			errors.append("无效制造任务结构")
			continue
		if buildings is Dictionary and not job.center_id.is_empty():
			var center: Dictionary = buildings.get(job.center_id, {})
			if PowerGridSystem.kind_id(center) != "construction_center" or center.get("planet_id") != job.planet_id:
				errors.append("制造中心引用无效")
				continue
		for key in ["step", "progress", "quantity"]:
			if not (job.get(key) is float or job.get(key) is int) or not is_finite(float(job[key])) or float(job[key]) < 0: errors.append("无效制造任务进度")
		if not errors.is_empty(): continue
		if float(job.step) != floorf(job.step) or int(job.step) > job.steps.size() or float(job.quantity) < 1 or float(job.quantity) > 99 or float(job.quantity) != floorf(job.quantity): errors.append("制造进度越界")
		var last: Variant = job.steps.back()
		if not last is Dictionary or last.get("recipe_id") != job.target or last.get("construction") != job.construction:
			errors.append("制造目标与最终工序不一致")
			continue
		for item in job.work:
			if DataManager.get_item(item).is_empty() or not (job.work[item] is int or job.work[item] is float) or not is_finite(float(job.work[item])) or float(job.work[item]) < 0: errors.append("无效在制材料")
		for step in job.steps:
			if not step is Dictionary or not step.get("inputs") is Dictionary or not step.get("outputs") is Dictionary or not step.get("construction") is bool or not (step.get("duration") is float or step.get("duration") is int) or not is_finite(float(step.duration)) or float(step.duration) <= 0:
				errors.append("无效制造工序")
				continue
			var definition: Dictionary = DataManager.construction.get(step.get("recipe_id"), {}) if step.construction else DataManager.get_recipe(String(step.get("recipe_id", "")))
			if definition.is_empty() or (not step.construction and not CraftingPlanner.can_handcraft(definition)):
				errors.append("未知或不允许手动制造的配方")
				continue
			var cycles := float(step.duration) if step.construction else float(step.duration) / float(definition.duration)
			if cycles < 1 or cycles > 100000000 or not is_equal_approx(cycles, roundf(cycles)):
				errors.append("制造批次无效")
				continue
			var expected_inputs: Dictionary = definition.costs if step.construction else CraftingPlanner._items(definition.inputs)
			var expected_outputs: Dictionary = {step.recipe_id: definition.output_amount} if step.construction else CraftingPlanner._items(definition.outputs)
			if step.inputs != CraftingPlanner._scale(expected_inputs, int(roundf(cycles))) or step.outputs != CraftingPlanner._scale(expected_outputs, int(roundf(cycles))): errors.append("制造工序与配方不一致")
	return errors

func cancel(id: String) -> Dictionary:
	for job in state.production_orders:
		if job.id != id: continue
		if job.construction and int(job.step) == job.steps.size():
			_deliver(job)
			return {"ok": not state.production_orders.has(job), "message": "成品需要施工件库存空间才能交付"}
		var returned := {}
		for item in job.work:
			if float(job.work[item]) > 0: returned[item] = job.work[item]
		var inventory := InventorySystem.new(state)
		if not returned.is_empty() and not inventory.can_add_batch(returned, job.planet_id): return {"ok": false, "message": "托盘不足以收回在制材料"}
		if not returned.is_empty(): inventory.try_add_batch(returned, job.planet_id)
		state.production_orders.erase(job)
		return {"ok": true, "message": "已取消并退回当前在制材料"}
	return {"ok": false, "message": "制造任务不存在"}
