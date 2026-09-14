extends Node

var failures := 0
func expect(ok: bool, message: String) -> void:
	if not ok:
		failures += 1
		printerr("EDITING: " + message)

func _ready() -> void:
	var state := GameState.new()
	var placed := state.try_place_building("smelter", Vector2(1000, 0))
	expect(placed.ok, "fixture places a real paid building")
	var id: String = placed.id
	var next_id := state._next_id
	expect(state.command_history.undo(state).ok and not state.buildings.has(id) and state.construction_inventory.smelter == 1, "undo construction restores its kit")
	expect(state._next_id == next_id, "undo never rewinds ID allocation")
	expect(state.command_history.redo(state).ok and state.buildings.has(id), "redo restores the same stable building ID")
	state.try_move_entities([{"id": id, "position": Vector2(1400, 0)}])
	state.elapsed_time = 12.0
	state.buildings[id].input_buffer.iron_ore = 2.0
	expect(state.command_history.undo(state).ok and state.buildings[id].position == Vector2(1000, 0), "position undo remains possible after production changes")
	expect(state.elapsed_time == 12 and state.buildings[id].input_buffer.iron_ore == 2, "history preserves live time and materials")
	state.try_move_entities([{"id": id, "position": Vector2(1800, 0)}])
	expect(state.command_history.redo_entries.is_empty(), "new edit clears the abandoned redo branch")
	state.command_history.clear()
	state.try_remove_entities([id])
	state.planet_inventory.gear = 7.0
	expect(state.command_history.undo(state).ok and state.buildings[id].input_buffer.iron_ore == 2 and state.planet_inventory.gear == 7, "undo demolition pays refunds back without rewinding unrelated inventory")
	state.command_history.clear()
	state.set_entity_recipe(id, "iron_ingot_recipe")
	state.buildings[id].progress = 0.5
	var before := GameStateCodec.to_persistent_dict(state)
	expect(not state.command_history.undo(state).ok and GameStateCodec.to_persistent_dict(state) == before, "conflicting running recipe refuses history without mutation")
	var count := state.command_history.undo_entries.size()
	state.try_place_building("missing_type", Vector2.ZERO)
	expect(state.command_history.undo_entries.size() == count, "failed commands do not create history")
	var loaded := GameStateCodec.from_persistent_dict(GameStateCodec.to_persistent_dict(state))
	expect(loaded != null and loaded.command_history.undo_entries.is_empty(), "session history does not persist through load")
	_test_layout()
	_test_connections_and_drag()
	await _test_continuous_input()
	if failures == 0: print("EDITING HISTORY TESTS PASSED")
	else: printerr("EDITING HISTORY TESTS FAILED")
	get_tree().quit(0 if failures == 0 else 1)

func _test_layout() -> void:
	var state := GameState.new()
	state.construction_inventory.smelter = 3.0
	var a: String = state.try_place_building("smelter", Vector2(1000, 0)).id
	var b: String = state.try_place_building("smelter", Vector2(1400, 0)).id
	var fixed: String = state.try_place_building("smelter", Vector2.ZERO).id
	state.buildings[fixed].interaction_locked = true
	state.command_history.clear()
	var plan := FactoryAutoLayout.plan(state)
	expect(plan == FactoryAutoLayout.plan(state), "layout is deterministic")
	expect(FactoryAutoLayout.apply(state).ok and state.command_history.undo_entries.size() == 1, "automatic layout is one history command")
	expect(state.buildings[fixed].position == Vector2.ZERO, "automatic layout preserves locked cards")
	expect(not FactoryGeometry.card_rect(state.buildings[a].position).intersects(FactoryGeometry.card_rect(state.buildings[b].position)), "automatic layout separates movable cards")
	expect(state.command_history.undo(state).ok and state.buildings[a].position == Vector2(1000, 0), "layout can be undone")

func _test_connections_and_drag() -> void:
	var state := GameState.new()
	state.construction_inventory = {"smelter": 1.0, "assembling_machine_mk1": 2.0, "conveyor_belt_mk1": 9000.0}
	var a: String = state.try_place_building("smelter", Vector2.ZERO).id
	var b: String = state.try_place_building("assembling_machine_mk1", Vector2(400, 0)).id
	var c: String = state.try_place_building("assembling_machine_mk1", Vector2(800, 0)).id
	state.set_entity_recipe(a, "iron_ingot_recipe")
	state.buildings[a].output_item = "iron_ingot"
	state.command_history.clear()
	var pairs := [{"source_id": a, "target_id": b}, {"source_id": a, "target_id": c}]
	var before := GameStateCodec.to_persistent_dict(state)
	expect(state.preview_connections(pairs).ok and before == GameStateCodec.to_persistent_dict(state) and state.command_history.undo_entries.is_empty(), "preview does not mutate IDs, inventory or history")
	expect(state.try_add_connections(pairs).ok and state.connections.size() == 2 and state.command_history.undo_entries.size() == 1, "confirmed connections share one command")
	var ids := state.connections.keys()
	expect(state.command_history.undo(state).ok and state.connections.is_empty() and state.construction_inventory.conveyor_belt_mk1 == 9000, "connection undo refunds paid kits")
	expect(state.command_history.redo(state).ok and state.connections.keys() == ids, "connection redo keeps IDs")
	expect(state.try_configure_belt(ids[0], {"parallel_count": 4096}).ok, "4096 parallels accepted with paid kits")
	state.connections[ids[0]].total_transferred = 77.0
	expect(state.command_history.undo(state).ok and state.connections[ids[0]].parallel_count == 1 and state.connections[ids[0]].total_transferred == 77, "configuration undo preserves cumulative flow")
	expect(state.command_history.redo(state).ok and state.connections[ids[0]].parallel_count == 4096, "configuration redo restores count")
	var loaded := GameStateCodec.from_persistent_dict(GameStateCodec.to_persistent_dict(state))
	expect(loaded != null and loaded.connections[ids[0]].parallel_count == 4096, "maximum parallels survive save round trip")
	before = GameStateCodec.to_persistent_dict(state)
	expect(not state.try_adjust_belt_lanes(ids, 1).ok and before == GameStateCodec.to_persistent_dict(state), "batch crossing maximum rejects all changes")
	expect(not state.try_adjust_belt_lanes(ids, -1).ok and before == GameStateCodec.to_persistent_dict(state), "batch crossing minimum rejects all changes")
	state.construction_inventory.conveyor_belt_mk1 = 0.0
	before = GameStateCodec.to_persistent_dict(state)
	expect(not state.try_configure_belts(ids, {"parallel_count": 4096}).ok and before == GameStateCodec.to_persistent_dict(state), "insufficient batch kits reject atomically")
	state.command_history.clear()
	state.command_history.begin_group(state, "拖动建筑")
	state.move_entity(a, Vector2(1000, 0))
	state.buildings[a].output_buffer.iron_ore = 12.0
	state.planet_inventory.gear = 3.0
	state.move_entity(a, Vector2(1200, 0))
	state.command_history.end_group(state)
	expect(state.command_history.undo_entries.size() == 1 and state.command_history.undo(state).ok and state.buildings[a].position == Vector2.ZERO, "multi-frame drag is one reversible command")
	expect(state.buildings[a].output_buffer.iron_ore == 12 and state.planet_inventory.gear == 3, "drag undo never rewinds production during the drag")

func _test_continuous_input() -> void:
	var state := GameState.new()
	state.construction_inventory = {"smelter": 1.0, "assembling_machine_mk1": 2.0, "conveyor_belt_mk1": 10.0}
	var a: String = state.try_place_building("smelter", Vector2.ZERO).id
	var b: String = state.try_place_building("assembling_machine_mk1", Vector2(400, 0)).id
	var c: String = state.try_place_building("assembling_machine_mk1", Vector2(800, 0)).id
	state.set_entity_recipe(a, "iron_ingot_recipe")
	GameManager.replace_game_state(state)
	GameManager.set_process(false)
	var handler := preload("res://scripts/input/InputHandler.gd").new()
	add_child(handler)
	await get_tree().process_frame
	state.command_history.clear()
	expect(handler.start_continuous_connection(a) and handler.append_connection_candidate(b) and handler.append_connection_candidate(c), "continuous mode accepts compatible targets")
	expect(state.connections.is_empty() and not handler.append_connection_candidate(a), "invalid candidate reports failure without committing earlier candidates")
	var back := InputEventKey.new()
	back.keycode = KEY_BACKSPACE
	back.pressed = true
	handler._handle_key_press(back)
	expect(handler.connection_candidates.size() == 1, "Backspace removes latest candidate")
	handler.cancel_operation()
	expect(state.connections.is_empty() and handler.connection_candidates.is_empty() and state.command_history.undo_entries.is_empty(), "cancel leaves no connection or history")
	handler.start_continuous_connection(a)
	handler.append_connection_candidate(b)
	expect(handler.confirm_connection_candidates() and state.connections.size() == 1 and not handler.continuous_connect, "Enter confirmation commits candidate and exits mode")
	var undo := InputEventKey.new()
	undo.keycode = KEY_Z
	undo.ctrl_pressed = true
	undo.pressed = true
	handler._handle_key_press(undo)
	expect(state.connections.is_empty(), "Ctrl+Z uses shared history")
	undo.shift_pressed = true
	handler._handle_key_press(undo)
	expect(state.connections.size() == 1, "Ctrl+Shift+Z redoes shared history")
	handler.queue_free()
	await get_tree().process_frame
