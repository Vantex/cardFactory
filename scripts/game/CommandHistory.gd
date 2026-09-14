class_name CommandHistory
extends RefCounted

const LIMIT := 100
const TRANSIENT := ["status", "power_input", "power_output", "power_efficiency", "power_covered", "power_requested", "active", "current_flow"]
var undo_entries: Array = []
var redo_entries: Array = []
var enabled := true
var _depth := 0
var _group_before: Dictionary = {}
var _group_label := ""

func clear() -> void:
	undo_entries.clear()
	redo_entries.clear()
	_group_before.clear()
	_group_label = ""

func execute(state: GameState, label: String, action: Callable) -> Variant:
	if not enabled or _depth > 0 or not _group_before.is_empty(): return action.call()
	var before := snapshot(state)
	_depth += 1
	var result: Variant = action.call()
	_depth -= 1
	_record(label, before, snapshot(state))
	return result

func begin_group(state: GameState, label: String) -> void:
	if _group_before.is_empty():
		_group_before = snapshot(state)
		_group_label = label

func end_group(state: GameState) -> void:
	if _group_before.is_empty(): return
	# Drag spans simulation frames: only positions belong to this command.
	var after := _group_before.duplicate(true)
	for id in after.buildings:
		if state.buildings.has(id): after.buildings[id].position = state.buildings[id].position
	_record(_group_label, _group_before, after)
	_group_before = {}
	_group_label = ""

func _record(label: String, before: Dictionary, after: Dictionary) -> void:
	var changes: Array = []
	_diff(before, after, [], changes)
	if changes.is_empty(): return
	var guards := {}
	for change in changes:
		if change.path.size() == 3 and change.path[0] == "buildings" and change.path[2] in ["recipe_id", "type", "energy_mode", "fuel_item", "spray_coater_installed", "proliferator_tier", "proliferator_mode"]:
			var id: String = change.path[1]
			guards[id] = {"before": _runtime_guard(before.buildings[id]), "after": _runtime_guard(after.buildings[id])}
	undo_entries.append({"label": label, "guards": guards, "changes": changes, "before_digest": JSON.stringify(before).sha256_text(), "after_digest": JSON.stringify(after).sha256_text()})
	if undo_entries.size() > LIMIT: undo_entries.pop_front()
	redo_entries.clear()

func undo(state: GameState) -> Dictionary:
	return _replay(state, undo_entries, redo_entries, false)

func redo(state: GameState) -> Dictionary:
	return _replay(state, redo_entries, undo_entries, true)

func _replay(state: GameState, source: Array, destination: Array, forward: bool) -> Dictionary:
	if not _group_before.is_empty(): return {"ok": false, "message": "请先结束当前拖动"}
	if source.is_empty(): return {"ok": false, "message": "没有可重做的操作" if forward else "没有可撤销的操作"}
	var entry: Dictionary = source.back()
	var proposed := snapshot(state)
	for id in entry.guards:
		if not proposed.buildings.has(id) or _runtime_guard(proposed.buildings[id]) != entry.guards[id]["before" if forward else "after"]: return _conflict()
	for change in entry.changes:
		var path: Array = change.path
		var parent: Variant = proposed
		for key in path.slice(0, path.size() - 1):
			if not parent is Dictionary or not parent.has(key): return _conflict()
			parent = parent[key]
		var key: Variant = path.back()
		var from_present: bool = change.before_present if forward else change.after_present
		var to_present: bool = change.after_present if forward else change.before_present
		var from_value: Variant = change.before if forward else change.after
		var to_value: Variant = change.after if forward else change.before
		if _is_inventory_path(path):
			var amount := float(parent.get(key, 0)) + (float(to_value) if to_present else 0.0) - (float(from_value) if from_present else 0.0)
			if amount < -0.0000001: return _conflict()
			if amount <= 0: parent.erase(key)
			else: parent[key] = amount
		else:
			if parent.has(key) != from_present or (from_present and parent[key] != from_value): return _conflict()
			if to_present: parent[key] = _copy(to_value)
			else: parent.erase(key)
	for collection in ["buildings", "connections"]:
		var live: Dictionary = state.get(collection)
		for id in proposed[collection]:
			if not live.has(id): continue
			for key in TRANSIENT:
				if live[id].has(key): proposed[collection][id][key] = live[id][key]
	var trial := state.copy_state()
	trial.buildings = proposed.buildings
	trial.connections = proposed.connections
	trial.construction_inventory = proposed.construction_inventory
	trial.planet_inventories = proposed.planet_inventories
	trial.planet_inventory = trial.planet_inventories.get(trial.active_planet_id, {}).duplicate(true)
	if not GameStateValidator.validate_persistent_dict(GameStateCodec.to_persistent_dict(trial)).is_empty(): return _conflict()
	state.buildings = proposed.buildings
	state.connections = proposed.connections
	state.construction_inventory = proposed.construction_inventory
	state.planet_inventories = proposed.planet_inventories
	state.planet_inventory = state.planet_inventories.get(state.active_planet_id, {}).duplicate(true)
	source.pop_back()
	destination.append(entry)
	EventBus.simulation_updated.emit()
	return {"ok": true, "message": ("已重做：" if forward else "已撤销：") + String(entry.label)}

static func _conflict() -> Dictionary:
	return {"ok": false, "message": "设备运行状态或库存已变化，无法安全恢复该操作；工厂保持不变"}

static func snapshot(state: GameState) -> Dictionary:
	state.sync_active_planet_inventory()
	var result := {"buildings": state.buildings.duplicate(true), "connections": state.connections.duplicate(true), "construction_inventory": state.construction_inventory.duplicate(true), "planet_inventories": state.planet_inventories.duplicate(true)}
	for collection in ["buildings", "connections"]:
		for entity in result[collection].values():
			for key in TRANSIENT: entity.erase(key)
	return result

static func _diff(before: Dictionary, after: Dictionary, path: Array, changes: Array) -> void:
	var keys := before.keys()
	for key in after:
		if not keys.has(key): keys.append(key)
	keys.sort()
	for key in keys:
		var next := path.duplicate()
		next.append(key)
		var bp := before.has(key)
		var ap := after.has(key)
		if bp and ap and before[key] == after[key]: continue
		if bp and ap and before[key] is Dictionary and after[key] is Dictionary:
			_diff(before[key], after[key], next, changes)
		else:
			changes.append({"path": next, "before_present": bp, "after_present": ap, "before": _copy(before.get(key)), "after": _copy(after.get(key))})

static func _is_inventory_path(path: Array) -> bool:
	return (path[0] == "construction_inventory" and path.size() == 2) or (path[0] == "planet_inventories" and path.size() == 3)

static func _copy(value: Variant) -> Variant:
	return value.duplicate(true) if value is Dictionary or value is Array else value

static func _runtime_guard(building: Dictionary) -> Dictionary:
	var result := {}
	for key in ["progress", "input_buffer", "output_buffer", "fuel_remaining", "stored_energy_mj", "proliferator_points", "proliferator_bonus"]:
		result[key] = _copy(building.get(key))
	return result
