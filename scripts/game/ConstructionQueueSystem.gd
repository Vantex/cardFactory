class_name ConstructionQueueSystem
extends RefCounted

const MAX_ORDERS := 100
var state: GameState
func _init(value: GameState) -> void: state = value

func deploy_immediately(entry: Dictionary, position: Vector2, allow_overlap: bool = false) -> Dictionary:
	return state.command_history.execute(state, "立即部署蓝图", _deploy_immediately.bind(entry, position, allow_overlap))

func _deploy_immediately(entry: Dictionary, position: Vector2, allow_overlap: bool) -> Dictionary:
	var probe := state.copy_state()
	probe.emit_canvas_events = false
	probe.command_history.enabled = false
	var queue := ConstructionQueueSystem.new(probe)
	var queued := queue.enqueue(entry, position, allow_overlap)
	if not queued.ok: return queued
	var funded := queue.fund(queued.id)
	if not funded.ok: return funded
	if not funded.completed: return BlueprintLibrary.fail("施工件或载具不足；可改用排队部署")
	_publish(probe)
	return {"ok": true, "message": "蓝图和载具已原子部署"}

func enqueue(entry: Dictionary, position: Vector2, allow_overlap: bool = false) -> Dictionary:
	if state.construction_queue.size() >= MAX_ORDERS: return BlueprintLibrary.fail("施工队列已达 100 项")
	if not BlueprintStateValidator._definition(entry) or not CanvasNavigation.valid_point(position): return BlueprintLibrary.fail("蓝图定义或部署位置无效")
	var resolved := BlueprintLibrary.resolve(entry)
	if not resolved.ok: return resolved
	var encoded := BlueprintCodec.new().encode(resolved.blueprint)
	if not encoded.ok: return encoded
	var order := {"id": "", "name": String(entry.get("name", "施工蓝图")), "text": encoded.text, "rotation": int(entry.get("rotation", 0)), "mirrored": bool(entry.get("mirrored", false)), "planet_id": state.active_planet_id, "position": [position.x, position.y], "allow_overlap": allow_overlap, "reserved": {}, "fleet_reserved": {}, "fleet_targets": entry.get("fleet_targets", {}).duplicate(true), "placed": {}}
	var check := _preview(order)
	if not check.ok: return check
	order.id = state.generate_id("construction")
	state.construction_queue.append(order)
	if state.emit_canvas_events: EventBus.simulation_updated.emit()
	return {"ok": true, "id": order.id, "message": "已加入待建队列"}

func _preview(order: Dictionary) -> Dictionary:
	var probe := state.copy_state()
	probe.set_active_planet(order.planet_id)
	probe.command_history.enabled = false
	probe.emit_canvas_events = false
	var decoded := BlueprintCodec.new().decode(order.text)
	if not decoded.ok: return decoded
	for entity in decoded.blueprint.entities:
		probe.construction_inventory[entity.type] = 1000000.0
	probe.construction_inventory.dsp_spray_coater = 1000000.0
	for item in DataManager.belt_definitions(): probe.construction_inventory[item] = 10000000.0
	return BlueprintSystem.new(probe).deploy(decoded.blueprint, Vector2(order.position[0], order.position[1]), order.rotation, order.mirrored, Callable(), order.allow_overlap)

func fund(id: String, scope: String = "all") -> Dictionary:
	if scope not in ["all", "construction", "fleet"]: return BlueprintLibrary.fail("资助类型无效")
	var index := _index(id)
	if index < 0: return BlueprintLibrary.fail("施工订单不存在")
	var original: Dictionary = state.construction_queue[index]
	var check := {"ok": true, "cost": {}}
	if original.placed.is_empty():
		check = _preview(original)
		if not check.ok: return check
	var probe := state.copy_state()
	probe.command_history.enabled = false
	probe.emit_canvas_events = false
	var order: Dictionary = probe.construction_queue[index]
	var active := probe.active_planet_id
	probe.set_active_planet(order.planet_id)
	if scope != "fleet" and order.placed.is_empty():
		for item in order.reserved.keys():
			var excess := maxf(0, float(order.reserved[item]) - float(check.cost.get(item, 0)))
			if float(probe.construction_inventory.get(item, 0)) + excess > GameState.construction_capacity(item): return BlueprintLibrary.fail("返还施工件超过库存容量")
			probe.construction_inventory[item] = float(probe.construction_inventory.get(item, 0)) + excess
			order.reserved[item] -= excess
		for item in check.cost:
			var taken := minf(float(check.cost[item]) - float(order.reserved.get(item, 0)), floorf(float(probe.construction_inventory.get(item, 0))))
			order.reserved[item] = float(order.reserved.get(item, 0)) + taken
			probe.construction_inventory[item] = float(probe.construction_inventory.get(item, 0)) - taken
	var fleet_cost := {}
	var target_ids: Dictionary = order.placed if not order.placed.is_empty() else check.get("ref_to_id", {})
	for ref in order.fleet_targets:
		for item in order.fleet_targets[ref]:
			var missing := maxi(0, int(order.fleet_targets[ref][item]) - _owned_fleet(probe, String(target_ids.get(ref, "")), item))
			fleet_cost[item] = float(fleet_cost.get(item, 0)) + missing
	for item in order.fleet_reserved.keys():
		var excess := maxf(0, float(order.fleet_reserved[item]) - float(fleet_cost.get(item, 0)))
		if excess <= 0: continue
		var refunded := InventorySystem.new(probe).try_add(item, excess)
		if not refunded.ok: return refunded
		order.fleet_reserved[item] -= excess
	if scope != "construction":
		for item in fleet_cost:
			var taken := minf(float(fleet_cost[item]) - float(order.fleet_reserved.get(item, 0)), floorf(float(probe.planet_inventory.get(item, 0))))
			order.fleet_reserved[item] = float(order.fleet_reserved.get(item, 0)) + taken
			probe.planet_inventory[item] = float(probe.planet_inventory.get(item, 0)) - taken
	var funded := true
	for item in check.cost:
		if float(order.reserved.get(item, 0)) < float(check.cost[item]): funded = false
	if order.placed.is_empty() and funded:
		var inventory := probe.construction_inventory
		probe.construction_inventory = order.reserved.duplicate(true)
		var decoded := BlueprintCodec.new().decode(order.text)
		var deployed := BlueprintSystem.new(probe).deploy(decoded.blueprint, Vector2(order.position[0], order.position[1]), order.rotation, order.mirrored, Callable(), order.allow_overlap)
		if not deployed.ok: return deployed
		for item in probe.construction_inventory:
			inventory[item] = float(inventory.get(item, 0)) + float(probe.construction_inventory[item])
		probe.construction_inventory = inventory
		order.reserved = {}
		order.placed = deployed.ref_to_id
	var fleet_ready := true
	for item in fleet_cost:
		if float(order.fleet_reserved.get(item, 0)) < float(fleet_cost[item]): fleet_ready = false
	var completed: bool = not order.placed.is_empty() and fleet_ready
	if completed:
		for ref in order.fleet_targets:
			var building: Dictionary = probe.buildings.get(order.placed.get(ref, ""), {})
			if not building.has("station"): return BlueprintLibrary.fail("载具目标建筑已移除或不支持物流")
			for item in order.fleet_targets[ref]:
				var amount := maxi(0, int(order.fleet_targets[ref][item]) - _owned_fleet(probe, order.placed[ref], item))
				if _owned_fleet(probe, order.placed[ref], item) + amount > 999: return BlueprintLibrary.fail("载具目标容量不足")
				building.station.fleet[item] = int(building.station.fleet.get(item, 0)) + amount
		probe.construction_queue.remove_at(index)
	probe.sync_active_planet_inventory()
	probe.set_active_planet(active)
	_publish(probe)
	return {"ok": true, "message": "施工及载具补足完成" if completed else "已资助现有物资，等待补足", "completed": completed}

func cancel(id: String) -> Dictionary:
	var index := _index(id)
	if index < 0: return BlueprintLibrary.fail("施工订单不存在")
	var probe := state.copy_state()
	var order: Dictionary = probe.construction_queue[index]
	for item in order.reserved:
		var total := float(probe.construction_inventory.get(item, 0)) + float(order.reserved[item])
		if total > GameState.construction_capacity(item): return BlueprintLibrary.fail("施工库存无足够返还空间")
		probe.construction_inventory[item] = total
	var active := probe.active_planet_id
	probe.set_active_planet(order.planet_id)
	var fleet_refund := {}
	for item in order.fleet_reserved:
		if float(order.fleet_reserved[item]) > 0: fleet_refund[item] = order.fleet_reserved[item]
	if not fleet_refund.is_empty():
		var refund := InventorySystem.new(probe).try_add_batch(fleet_refund)
		if not refund.ok: return refund
	probe.sync_active_planet_inventory()
	probe.set_active_planet(active)
	probe.construction_queue.remove_at(index)
	_publish(probe)
	return {"ok": true, "message": "已取消并返还未消耗物资；已建建筑保留"}

func fund_all() -> void:
	for order in state.construction_queue.duplicate(true): fund(order.id)

func _owned_fleet(probe: GameState, id: String, item: String) -> int:
	var building: Dictionary = probe.buildings.get(id, {})
	var count := int(building.get("station", {}).get("fleet", {}).get(item, 0))
	for route in probe.logistics_routes.values():
		if route.get("owner_id", route.source_id) == id and route.vehicle == item: count += 1
	return count

func _index(id: String) -> int:
	for i in range(state.construction_queue.size()):
		if state.construction_queue[i].id == id: return i
	return -1

func _publish(probe: GameState) -> void:
	var new_buildings: Array = probe.buildings.keys().filter(func(id): return not state.buildings.has(id))
	var new_connections: Array = probe.connections.keys().filter(func(id): return not state.connections.has(id))
	state.buildings = probe.buildings
	state.connections = probe.connections
	state.construction_inventory = probe.construction_inventory
	state.planet_inventories = probe.planet_inventories
	state.planet_inventory = state.planet_inventories[state.active_planet_id]
	state.construction_queue = probe.construction_queue
	state._next_id = probe._next_id
	if state.emit_canvas_events:
		for id in new_buildings: EventBus.card_placed.emit(id, state.buildings[id].position)
		for id in new_connections: EventBus.connection_created.emit(id, state.connections[id].source_id, state.connections[id].target_id)
		EventBus.simulation_updated.emit()
