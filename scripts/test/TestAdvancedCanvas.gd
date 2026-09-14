extends Node

const CardRendererScript = preload("res://scripts/rendering/CardRenderer.gd")
const ConnectionRendererScript = preload("res://scripts/rendering/ConnectionRenderer.gd")
const InputHandlerScript = preload("res://scripts/input/InputHandler.gd")
const WorkspaceScript = preload("res://scenes/ui/FactoryWorkspaceUI.gd")

var _failures := 0

func _ready() -> void:
	print("ADVANCED CANVAS TESTS STARTED")
	await _test_shared_selection_and_reverse_marquee()
	await _test_real_main_preserves_shared_selection()
	_test_atomic_batch_move()
	_test_atomic_batch_delete_rollback()
	await _test_confirmed_atomic_batch_delete()
	_test_connection_removal_transactions()
	_test_belt_configuration_and_throughput()
	_test_belt_priority_controls_contention()
	_test_legacy_v2_defaults_and_persistence()
	_test_connected_network_results_preserve_runtime_state()
	await _test_active_planet_projection_and_input_guards()
	await _test_advanced_inspector_and_renderer_contract()
	if _failures > 0:
		printerr("ADVANCED CANVAS TESTS FAILED")
		get_tree().quit(1)
		return
	print("ADVANCED CANVAS TESTS PASSED")
	get_tree().quit(0)

func _test_shared_selection_and_reverse_marquee() -> void:
	var state := GameState.new()
	var left_id := _add_building(state, "left", "miner", Vector2(100, 100))
	var right_id := _add_building(state, "right", "smelter", Vector2(420, 100))
	GameManager.replace_game_state(state)
	var input_handler := InputHandlerScript.new()
	add_child(input_handler)
	await get_tree().process_frame
	_expect(input_handler.has_method("set_selected_entities") and input_handler.has_method("toggle_entity_selection") and input_handler.has_method("select_entities_in_rect"), "input exposes one session selection collection")
	if not input_handler.has_method("set_selected_entities") or not input_handler.has_method("toggle_entity_selection") or not input_handler.has_method("select_entities_in_rect"):
		input_handler.queue_free()
		await get_tree().process_frame
		return
	input_handler.call("set_selected_entities", [left_id])
	input_handler.call("toggle_entity_selection", right_id)
	_expect(input_handler.call("get_selected_entity_ids") == [left_id, right_id], "Ctrl-style toggling adds an entity to the shared selection")
	input_handler.call("toggle_entity_selection", left_id)
	_expect(input_handler.call("get_selected_entity_ids") == [right_id], "Ctrl-style toggling removes an entity from the shared selection")
	input_handler.call("select_entities_in_rect", Vector2(700, 300), Vector2(50, 50), false)
	_expect(input_handler.call("get_selected_entity_ids") == [left_id, right_id], "a marquee dragged from bottom-right to top-left selects both cards")
	var renderer := CardRendererScript.new()
	renderer.set_game_state(state)
	renderer.set_input_handler(input_handler)
	_expect(renderer.is_building_selected(left_id) and renderer.is_building_selected(right_id), "card renderer consumes the same selection collection")
	renderer.queue_free()
	input_handler.queue_free()
	await get_tree().process_frame

func _test_real_main_preserves_shared_selection() -> void:
	var state := GameState.new()
	var source_id := _add_building(state, "main_source", "miner", Vector2(100, 100))
	var target_id := _add_building(state, "main_target", "smelter", Vector2(500, 100))
	var belt_id := state.add_connection({"source_id": source_id, "target_id": target_id, "type": "conveyor_belt_mk1", "item_id": "iron_ore"})
	GameManager.replace_game_state(state)
	var main_scene := load("res://scenes/main/Main.tscn") as PackedScene
	var viewport := SubViewport.new()
	viewport.size = Vector2i(1152, 648)
	add_child(viewport)
	var main := main_scene.instantiate()
	viewport.add_child(main)
	await get_tree().process_frame
	var input_handler := main.get_node("InputHandler")
	var workspace := main.get_node("FactoryWorkspaceUI")
	var connection_renderer := main.get_node("ConnectionRenderer")
	var title := workspace.get_node("InspectorPanel/Title") as Label
	input_handler.call("set_selected_entities", [source_id, target_id])
	await get_tree().process_frame
	await get_tree().process_frame
	_expect(input_handler.call("get_selected_entity_ids") == [source_id, target_id] and "已选择 2 项" in title.text, "real Main keeps the inspector on the shared multi-selection after legacy synchronization")
	input_handler.call("set_selected_entities", [belt_id])
	EventBus.card_selected.emit("")
	await get_tree().process_frame
	_expect(input_handler.call("get_selected_entity_ids") == [belt_id] and "线路" in title.text and connection_renderer.call("is_connection_selected", belt_id), "real Main keeps a selected line shared by input, renderer, and inspector")
	var replacement := GameState.new()
	_add_building(replacement, "main_source", "miner", Vector2(100, 100))
	_add_building(replacement, "main_target", "smelter", Vector2(500, 100))
	replacement.add_connection({"source_id": source_id, "target_id": target_id, "type": "conveyor_belt_mk1", "item_id": "iron_ore"})
	GameManager.replace_game_state(replacement)
	await get_tree().process_frame
	_expect(input_handler.call("get_selected_entity_ids").is_empty() and title.text == "工厂概览", "replacing GameState clears session selection even when the new save reuses the same entity IDs")
	viewport.queue_free()
	await get_tree().process_frame

func _test_atomic_batch_move() -> void:
	var state := GameState.new()
	var movable_id := _add_building(state, "movable", "miner", Vector2(100, 100))
	var locked_id := _add_building(state, "locked", "smelter", Vector2(420, 100))
	state.buildings[locked_id]["interaction_locked"] = true
	_expect(state.has_method("try_move_entities"), "GameState exposes an authoritative atomic batch move command")
	if not state.has_method("try_move_entities"):
		return
	var rejected: Dictionary = state.call("try_move_entities", [
		{"id": movable_id, "position": Vector2(200, 180)},
		{"id": locked_id, "position": Vector2(520, 180)},
	])
	_expect(not rejected.get("ok", true) and state.buildings[movable_id].position == Vector2(100, 100) and state.buildings[locked_id].position == Vector2(420, 100), "a locked member rejects a batch move without moving any card")
	state.buildings[locked_id]["interaction_locked"] = false
	var observed_snapshots: Array = []
	var observer := func(_entity_id: String, _position: Vector2) -> void:
		observed_snapshots.append([state.buildings[movable_id].position, state.buildings[locked_id].position])
	EventBus.entity_moved.connect(observer)
	var accepted: Dictionary = state.call("try_move_entities", [
		{"id": movable_id, "position": Vector2(200, 180)},
		{"id": locked_id, "position": Vector2(520, 180)},
	])
	EventBus.entity_moved.disconnect(observer)
	_expect(accepted.get("ok", false) and accepted.get("success", 0) == 2 and state.buildings[movable_id].position == Vector2(200, 180) and state.buildings[locked_id].position == Vector2(520, 180), "a valid batch move commits every card together")
	_expect(observed_snapshots == [[Vector2(200, 180), Vector2(520, 180)], [Vector2(200, 180), Vector2(520, 180)]], "batch move observers only see the fully committed authoritative positions")

func _test_atomic_batch_delete_rollback() -> void:
	var state := GameState.new()
	state.construction_inventory = {"miner": 0.0, "smelter": 0.0, "conveyor_belt_mk1": 0.0}
	state.planet_inventory = {"iron_ore": 998.5}
	var first_id := _add_building(state, "rollback_first", "miner", Vector2.ZERO)
	var second_id := _add_building(state, "rollback_second", "smelter", Vector2(400, 0))
	state.buildings[first_id]["output_buffer"] = {"iron_ore": 0.3}
	state.buildings[second_id]["input_buffer"] = {"iron_ore": 0.3}
	state.add_connection({"source_id": first_id, "target_id": second_id, "type": "conveyor_belt_mk1", "item_id": "iron_ore"})
	var buildings_before := state.buildings.duplicate(true)
	var connections_before := state.connections.duplicate(true)
	var planet_before := state.planet_inventory.duplicate(true)
	var construction_before := state.construction_inventory.duplicate(true)
	var removal_events: Array[String] = []
	var card_observer := func(entity_id: String) -> void:
		removal_events.append(entity_id)
	EventBus.card_removed.connect(card_observer)
	var result := state.try_remove_entities([first_id, second_id])
	EventBus.card_removed.disconnect(card_observer)
	_expect(not result.get("ok", true) and result.get("reason", "") == "planet_inventory_full" and state.buildings == buildings_before and state.connections == connections_before and state.planet_inventory == planet_before and state.construction_inventory == construction_before and removal_events.is_empty(), "a failed batch delete rolls back every building, line, inventory, and removal event")

func _test_confirmed_atomic_batch_delete() -> void:
	var state := GameState.new()
	state.construction_inventory = {"miner": 0.0, "smelter": 0.0}
	var first_id := _add_building(state, "first", "miner", Vector2(100, 100))
	var second_id := _add_building(state, "second", "smelter", Vector2(420, 100))
	GameManager.replace_game_state(state)
	var host := Node2D.new()
	add_child(host)
	var input_handler := InputHandlerScript.new()
	input_handler.name = "InputHandler"
	host.add_child(input_handler)
	var workspace := WorkspaceScript.new()
	workspace.name = "FactoryWorkspaceUI"
	host.add_child(workspace)
	await get_tree().process_frame

	_expect(input_handler.has_method("set_selected_entities") and workspace.has_method("set_selected_entities"), "workspace and input can share a multi-selection")
	if input_handler.has_method("set_selected_entities"):
		input_handler.call("set_selected_entities", [first_id, second_id])
	workspace.call("_on_delete_pressed")
	var confirmation := workspace.get_node_or_null("DeleteConfirmation") as ConfirmationDialog
	_expect(state.buildings.size() == 2 and confirmation != null and confirmation.visible, "delete requests leave authoritative state untouched until explicit UI confirmation")
	var observed_snapshots: Array = []
	var observer := func(_entity_id: String) -> void:
		observed_snapshots.append([state.buildings.size(), state.construction_inventory.get("miner", 0.0), state.construction_inventory.get("smelter", 0.0)])
	EventBus.card_removed.connect(observer)
	if confirmation != null:
		confirmation.confirmed.emit()
	EventBus.card_removed.disconnect(observer)
	_expect(state.buildings.is_empty() and state.construction_inventory.get("miner", 0.0) == 1.0 and state.construction_inventory.get("smelter", 0.0) == 1.0, "confirmed multi-delete atomically refunds and removes every selected building")
	_expect(observed_snapshots == [[0, 1.0, 1.0], [0, 1.0, 1.0]], "batch delete observers only see the fully committed authoritative removals and refunds")
	host.queue_free()
	await get_tree().process_frame

func _test_connection_removal_transactions() -> void:
	var state := GameState.new()
	state.construction_inventory = {"miner": 0.0, "smelter": 0.0, "conveyor_belt_mk1": 1.0}
	var source_id := _add_building(state, "economic_source", "miner", Vector2.ZERO)
	var target_id := _add_building(state, "economic_target", "smelter", Vector2(400, 0))
	state.buildings[source_id]["output_item"] = "iron_ore"
	var add_result := state.try_add_connection(source_id, target_id)
	var belt_id := String(add_result.get("id", ""))
	state.construction_inventory["conveyor_belt_mk1"] = GameState.BELT_MAX_INVENTORY
	var has_transaction := state.has_method("try_remove_connection")
	var remove_result: Dictionary = state.call("try_remove_connection", belt_id) if has_transaction else {}
	_expect(has_transaction and not remove_result.get("ok", true) and remove_result.get("reason", "") == "construction_inventory_full" and state.connections.has(belt_id) and state.construction_inventory.conveyor_belt_mk1 == GameState.BELT_MAX_INVENTORY, "economic line removal preflights a full construction inventory without mutation")
	var building_result := state.remove_building(source_id)
	_expect(not building_result.get("ok", true) and state.buildings.has(source_id) and state.connections.has(belt_id) and state.construction_inventory.conveyor_belt_mk1 == GameState.BELT_MAX_INVENTORY, "single-building removal includes connected line refunds in one atomic preflight")

	var raw_state := GameState.new()
	raw_state.construction_inventory = {"conveyor_belt_mk1": 0.0}
	var raw_source_id := _add_building(raw_state, "raw_source", "miner", Vector2.ZERO)
	var raw_target_id := _add_building(raw_state, "raw_target", "smelter", Vector2(400, 0))
	var raw_belt_id := raw_state.add_connection({"source_id": raw_source_id, "target_id": raw_target_id, "type": "conveyor_belt_mk1", "item_id": "iron_ore"})
	raw_state.remove_connection(raw_belt_id)
	_expect(not raw_state.connections.has(raw_belt_id) and raw_state.construction_inventory.conveyor_belt_mk1 == 0.0, "raw fixture connection removal cannot mint an unconsumed construction piece")

func _test_belt_configuration_and_throughput() -> void:
	var state := GameState.new()
	state.construction_inventory = {
		"conveyor_belt_mk1": 3.0,
		"conveyor_belt_mk2": 4.0,
		"conveyor_belt_mk3": 0.0,
	}
	var source_id := _add_building(state, "source", "miner", Vector2.ZERO)
	var target_id := _add_building(state, "target", "smelter", Vector2(400, 0))
	state.buildings[source_id]["output_item"] = "iron_ore"
	state.buildings[source_id]["output_buffer"] = {"iron_ore": 200.0}
	state.buildings[target_id]["input_buffer_capacity"] = 200.0
	var add_result := state.try_add_connection(source_id, target_id)
	var belt_id := String(add_result.get("id", ""))
	state.connections[belt_id]["active"] = true
	state.connections[belt_id]["current_flow"] = 7.0
	state.connections[belt_id]["total_transferred"] = 33.0
	_expect(state.has_method("try_configure_belt") and state.has_method("get_belt_configuration"), "GameState exposes validated belt configuration commands")
	if not state.has_method("try_configure_belt") or not state.has_method("get_belt_configuration"):
		return
	var invalid_before := state.copy_state()
	var invalid: Dictionary = state.call("try_configure_belt", belt_id, {"parallel_count": 5, "stack_size": 3, "priority": 9, "route_mode": "random"})
	_expect(not invalid.get("ok", true) and state.connections[belt_id] == invalid_before.connections[belt_id] and state.construction_inventory == invalid_before.construction_inventory, "invalid belt values are rejected without partial changes")
	var invalid_cases := [
		[{"tier": "conveyor_belt_mk4"}, "invalid_tier"],
		[{"parallel_count": 0}, "invalid_parallel_count"],
		[{"stack_size": 3}, "invalid_stack_size"],
		[{"priority": 3}, "invalid_priority"],
		[{"route_mode": "random"}, "invalid_route_mode"],
		[{"route_offset_y": INF}, "invalid_route_offset_y"],
		[{"monitor_enabled": "true"}, "invalid_toggle"],
		[{"enabled": 1}, "invalid_toggle"],
	]
	for invalid_case in invalid_cases:
		var connection_before: Dictionary = state.connections[belt_id].duplicate(true)
		var inventory_before: Dictionary = state.construction_inventory.duplicate(true)
		var rejected: Dictionary = state.call("try_configure_belt", belt_id, invalid_case[0])
		_expect(not rejected.get("ok", true) and rejected.get("reason", "") == invalid_case[1] and state.connections[belt_id] == connection_before and state.construction_inventory == inventory_before, "belt configuration explicitly rejects %s without mutation" % invalid_case[1])
	var inventory_before_total := float(state.construction_inventory.conveyor_belt_mk1) + float(state.construction_inventory.conveyor_belt_mk2) + 1.0
	var configured: Dictionary = state.call("try_configure_belt", belt_id, {"tier": "conveyor_belt_mk2", "parallel_count": 2, "stack_size": 4, "priority": 2, "route_mode": "upper", "monitor_enabled": true, "enabled": true})
	var config: Dictionary = state.call("get_belt_configuration", belt_id)
	_expect(configured.get("ok", false) and config.get("rated_throughput") == 20.0 and config.get("effective_throughput") == 160.0, "Mk.II throughput is 20 items/s times two parallels times stack four")
	_expect(state.construction_inventory.get("conveyor_belt_mk1") == 3.0 and state.construction_inventory.get("conveyor_belt_mk2") == 2.0, "tier and parallel adjustment refunds old pieces and consumes installed pieces")
	_expect(inventory_before_total == float(state.construction_inventory.conveyor_belt_mk1) + float(state.construction_inventory.conveyor_belt_mk2) + 2.0, "construction inventory plus installed belt pieces remains conserved")
	_expect(state.connections[belt_id].get("active") == true and state.connections[belt_id].get("current_flow") == 7.0 and state.connections[belt_id].get("total_transferred") == 33.0, "belt configuration leaves runtime flow and cumulative statistics untouched")
	var inventory_before_pure := state.construction_inventory.duplicate(true)
	state.call("try_configure_belt", belt_id, {"priority": 1, "route_mode": "lower", "monitor_enabled": false, "enabled": false, "stack_size": 2})
	_expect(state.construction_inventory == inventory_before_pure, "pure belt configuration does not alter construction inventory")
	state.call("try_configure_belt", belt_id, {"enabled": true, "stack_size": 4})
	BeltSystem.new(state).update(0.5)
	_expect(is_equal_approx(state.buildings[source_id].output_buffer.iron_ore, 120.0) and is_equal_approx(state.buildings[target_id].input_buffer.iron_ore, 80.0), "BeltSystem transports cargo at the configured effective throughput")

func _test_belt_priority_controls_contention() -> void:
	var state := GameState.new()
	var source_id := _add_building(state, "priority_source", "miner", Vector2.ZERO)
	var low_target_id := _add_building(state, "priority_low", "smelter", Vector2(400, -100))
	var high_target_id := _add_building(state, "priority_high", "smelter", Vector2(400, 100))
	state.buildings[source_id]["output_buffer"] = {"iron_ore": 5.0}
	state.buildings[low_target_id]["input_buffer_capacity"] = 10.0
	state.buildings[high_target_id]["input_buffer_capacity"] = 10.0
	var low_id := state.add_connection({"source_id": source_id, "target_id": low_target_id, "type": "conveyor_belt_mk1", "item_id": "iron_ore", "priority": 0})
	var high_id := state.add_connection({"source_id": source_id, "target_id": high_target_id, "type": "conveyor_belt_mk1", "item_id": "iron_ore", "priority": 2})
	BeltSystem.new(state).update(1.0)
	_expect(state.buildings[high_target_id].input_buffer.get("iron_ore", 0.0) == 5.0 and state.buildings[low_target_id].input_buffer.get("iron_ore", 0.0) == 0.0, "higher numeric belt priority wins limited source inventory contention")
	state.buildings[source_id]["output_buffer"] = {"iron_ore": 5.0}
	state.buildings[low_target_id]["input_buffer"] = {}
	state.buildings[high_target_id]["input_buffer"] = {}
	state.try_configure_belt(low_id, {"priority": 1})
	state.try_configure_belt(high_id, {"priority": 1})
	BeltSystem.new(state).update(1.0)
	_expect(state.buildings[low_target_id].input_buffer.get("iron_ore", 0.0) == 5.0 and state.buildings[high_target_id].input_buffer.get("iron_ore", 0.0) == 0.0, "equal-priority belt contention uses stable connection ID order")

func _test_legacy_v2_defaults_and_persistence() -> void:
	var state := GameState.new()
	var source_id := _add_building(state, "source", "miner", Vector2.ZERO)
	var target_id := _add_building(state, "target", "smelter", Vector2(400, 0))
	state.buildings[source_id]["output_item"] = "iron_ore"
	var belt_id := state.add_connection({"source_id": source_id, "target_id": target_id, "type": "conveyor_belt_mk1", "item_id": "iron_ore"})
	_expect(state.has_method("get_belt_configuration"), "legacy line defaults are exposed through the authoritative state")
	if not state.has_method("get_belt_configuration"):
		return
	var defaults: Dictionary = state.call("get_belt_configuration", belt_id)
	_expect(defaults.get("parallel_count") == 1 and defaults.get("stack_size") == 1 and defaults.get("priority") == 0 and defaults.get("route_mode") == "auto" and defaults.get("route_offset_y") == 0.0 and not defaults.get("monitor_enabled", true) and defaults.get("enabled", false), "old schema-v2 lines receive deterministic compatible defaults")
	state.construction_inventory["conveyor_belt_mk2"] = 2.0
	state.call("try_configure_belt", belt_id, {"tier": "conveyor_belt_mk2", "parallel_count": 2, "stack_size": 2, "priority": 1, "route_mode": "manual", "route_offset_y": 24.0, "monitor_enabled": true, "enabled": false})
	var payload := GameStateCodec.to_persistent_dict(state)
	_expect(not payload.has("selected_entity_ids"), "workspace selection remains absent from schema-v2 persistence")
	var restored := GameStateCodec.from_persistent_dict(payload)
	var restored_config: Dictionary = restored.call("get_belt_configuration", belt_id) if restored != null else {}
	_expect(restored != null and restored.get_state_version() == 9 and restored_config.get("tier") == "conveyor_belt_mk2" and restored_config.get("parallel_count") == 2 and restored_config.get("stack_size") == 2 and restored_config.get("route_mode") == "manual" and restored_config.get("route_offset_y") == 24.0 and restored_config.get("enabled") == false, "new line fields round-trip through the current schema version")
	var legacy_state := GameState.new()
	var legacy_source_id := _add_building(legacy_state, "legacy_source", "miner", Vector2.ZERO)
	var legacy_target_id := _add_building(legacy_state, "legacy_target", "smelter", Vector2(400, 0))
	var legacy_belt_id := legacy_state.add_connection({"source_id": legacy_source_id, "target_id": legacy_target_id, "type": "conveyor_belt_mk1", "item_id": "iron_ore"})
	var legacy_payload := GameStateCodec.to_persistent_dict(legacy_state)
	legacy_payload.connections[legacy_belt_id].erase("construction_accounted")
	for tier in ["conveyor_belt_mk1", "conveyor_belt_mk2", "conveyor_belt_mk3"]:
		legacy_payload.construction_inventory.erase(tier)
	var legacy_without_belt_inventory := GameStateCodec.from_persistent_dict(legacy_payload)
	var parallel_result: Dictionary = legacy_without_belt_inventory.try_configure_belt(legacy_belt_id, {"parallel_count": 2}) if legacy_without_belt_inventory != null else {}
	var parallel_config: Dictionary = legacy_without_belt_inventory.get_belt_configuration(legacy_belt_id) if legacy_without_belt_inventory != null else {}
	_expect(legacy_without_belt_inventory != null and parallel_result.get("ok", false) and parallel_config.get("parallel_count") == 2 and legacy_without_belt_inventory.construction_inventory.get("conveyor_belt_mk1", -1.0) == 0.0, "an old v2 missing-key Mk.I line consumes the same deterministic compatibility inventory when adding a parallel")
	if legacy_without_belt_inventory != null:
		legacy_without_belt_inventory.remove_connection(legacy_belt_id)
	_expect(legacy_without_belt_inventory != null and not legacy_without_belt_inventory.connections.has(legacy_belt_id) and legacy_without_belt_inventory.construction_inventory.get("conveyor_belt_mk1", -1.0) == 2.0, "removing the upgraded old v2 line refunds both installed pieces without losing the compatibility baseline")

func _test_connected_network_results_preserve_runtime_state() -> void:
	var state := GameState.new()
	state.construction_inventory = {"conveyor_belt_mk1": 8.0, "conveyor_belt_mk2": 8.0, "conveyor_belt_mk3": 8.0}
	for spec in [["a", Vector2(0, 0)], ["b", Vector2(300, 0)], ["c", Vector2(600, 0)], ["x", Vector2(0, 300)], ["y", Vector2(300, 300)]]:
		_add_building(state, spec[0], "miner" if spec[0] in ["a", "x"] else "smelter", spec[1])
	var template_id := state.add_connection({"source_id": "a", "target_id": "b", "type": "conveyor_belt_mk2", "item_id": "iron_ore", "parallel_count": 2, "stack_size": 2, "priority": 2, "route_mode": "manual", "route_offset_y": 64.0, "monitor_enabled": true, "enabled": false, "active": true, "current_flow": 5.0, "total_transferred": 40.0, "in_transit": [{"amount": 3.0}]})
	var chained_id := state.add_connection({"source_id": "b", "target_id": "c", "type": "conveyor_belt_mk1", "item_id": "iron_ore", "route_mode": "manual", "route_offset_y": -32.0, "active": true, "current_flow": 6.0, "total_transferred": 21.0, "in_transit": [{"amount": 2.0}]})
	var isolated_id := state.add_connection({"source_id": "x", "target_id": "y", "type": "conveyor_belt_mk1", "item_id": "iron_ore"})
	_expect(state.has_method("apply_belt_configuration_to_network"), "GameState exposes structured connected-network synchronization")
	if not state.has_method("apply_belt_configuration_to_network"):
		return
	var result_value: Variant = state.call("apply_belt_configuration_to_network", template_id)
	var result: Dictionary = result_value if result_value is Dictionary else {}
	var chained_config: Dictionary = state.call("get_belt_configuration", chained_id)
	_expect(result.get("ok", false) and result.get("results", []).size() == 2 and result.get("success", 0) == 1 and result.get("skipped", 0) == 1 and result.get("failed", 0) == 0, "network synchronization returns one structured result per connected line")
	_expect(chained_config.get("tier") == "conveyor_belt_mk2" and chained_config.get("parallel_count") == 2 and chained_config.get("stack_size") == 2 and chained_config.get("route_mode") == "manual" and chained_config.get("route_offset_y") == 64.0, "network synchronization copies a manual template offset across actual shared endpoints")
	_expect(state.connections[isolated_id].get("type") == "conveyor_belt_mk1", "network synchronization does not touch a disconnected line")
	_expect(state.connections[chained_id].get("active") == true and state.connections[chained_id].get("current_flow") == 6.0 and state.connections[chained_id].get("total_transferred") == 21.0 and state.connections[chained_id].get("in_transit") == [{"amount": 2.0}], "network synchronization preserves flow, cumulative statistics, and in-transit cargo")
	var missing_template: Dictionary = state.call("apply_belt_configuration_to_network", "")
	_expect(not missing_template.get("ok", true) and missing_template.get("failed", 0) == 1, "network commands require an explicit valid template line")

func _test_active_planet_projection_and_input_guards() -> void:
	var state := GameState.new()
	state.explored_system_ids.append("borealis")
	state.colonized_planet_ids.append("frost")
	state.planet_inventories["frost"] = {}
	state.planet_viewports["frost"] = {"position": Vector2.ZERO, "zoom": Vector2.ONE}
	state.planet_metrics["frost"] = {}
	var home_source := _add_building(state, "home_source", "miner", Vector2(100, 100), "home")
	var home_target := _add_building(state, "home_target", "smelter", Vector2(500, 100), "home")
	state.buildings[home_source]["output_item"] = "iron_ore"
	state.buildings[home_target]["recipe_id"] = "iron_ingot_recipe"
	var home_belt := state.add_connection({"source_id": home_source, "target_id": home_target, "planet_id": "home", "type": "conveyor_belt_mk1", "item_id": "iron_ore"})
	var frost_source := _add_building(state, "frost_source", "miner", Vector2(100, 100), "frost")
	var frost_target := _add_building(state, "frost_target", "smelter", Vector2(500, 100), "frost")
	state.buildings[frost_source]["output_item"] = "iron_ore"
	state.buildings[frost_target]["recipe_id"] = "iron_ingot_recipe"
	var frost_belt := state.add_connection({"source_id": frost_source, "target_id": frost_target, "planet_id": "frost", "type": "conveyor_belt_mk1", "item_id": "iron_ore"})
	state.set_active_planet("frost")
	GameManager.replace_game_state(state)
	var viewport := SubViewport.new()
	viewport.size = Vector2i(1152, 648)
	add_child(viewport)
	var main: Node = load("res://scenes/main/Main.tscn").instantiate()
	viewport.add_child(main)
	await get_tree().process_frame
	var card_renderer: Node = main.get_node("CardRenderer")
	var connection_renderer: Node = main.get_node("ConnectionRenderer")
	var input_handler: Node = main.get_node("InputHandler")
	var mini_map: Node = main.get_node("FactoryWorkspaceUI/MiniMap")
	var has_projection_api := card_renderer.has_method("get_visible_building_ids") and connection_renderer.has_method("get_visible_connection_ids")
	_expect(has_projection_api, "renderers expose their active-planet projections")
	if has_projection_api:
		_expect(card_renderer.call("get_visible_building_ids") == [frost_source, frost_target], "cards project only the active planet")
		_expect(connection_renderer.call("get_visible_connection_ids") == [frost_belt], "belts project only the active planet")
	_expect(mini_map.call("get_visible_entity_ids") == [frost_source, frost_target], "mini-map markers project only the active planet")
	_expect(String(input_handler.call("_get_building_at_position", Vector2(110, 110)).get("id", "")) == frost_source, "building hit testing ignores an overlapping inactive card")
	_expect(input_handler.call("_get_connection_at_position", Vector2(416, 189)) == frost_belt, "connection hit testing ignores an overlapping inactive line")
	var before := GameStateCodec.state_digest_payload(state)
	input_handler.call("set_selected_entities", [home_source])
	_expect(input_handler.call("get_selected_entity_ids").is_empty(), "direct selection rejects an inactive building ID")
	input_handler.set("selected_building_id", home_source)
	_expect(String(input_handler.get("selected_building_id")).is_empty() and input_handler.call("get_selected_entity_ids").is_empty(), "legacy primary selection rejects an inactive building ID")
	input_handler.call("select_entities_in_rect", Vector2(50, 50), Vector2(750, 300), false)
	_expect(input_handler.call("get_selected_entity_ids") == [frost_source, frost_target], "box selection includes only active-planet cards")
	input_handler.call("set_selected_entities", [])
	var delete_rejected := input_handler.has_method("request_delete") and not bool(input_handler.call("request_delete", home_source))
	_expect(delete_rejected, "input rejects deleting an inactive building")
	var move_rejected := input_handler.has_method("request_move_entities") and not bool(input_handler.call("request_move_entities", [{"id": home_source, "position": Vector2(900, 900)}]))
	_expect(move_rejected and state.buildings[home_source].position == Vector2(100, 100), "input rejects dragging an inactive building")
	input_handler.call("start_connection", home_source)
	_expect(input_handler.call("get_mode_name") == "idle", "input rejects starting a connection from an inactive building")
	var line_start_digest := GameStateCodec.state_digest_payload(state)
	var construction_before_line_start := state.construction_inventory.duplicate(true)
	var next_id_before_line_start: int = state._next_id
	var line_started := bool(input_handler.call("start_connection", frost_belt))
	_expect(not line_started and input_handler.call("get_mode_name") == "idle" and String(input_handler.get("connecting_source_id")).is_empty(), "input rejects an active connection ID as a connection source without changing mode")
	_expect(GameStateCodec.state_digest_payload(state) == line_start_digest and state.construction_inventory == construction_before_line_start and state._next_id == next_id_before_line_start, "rejected connection-line source preserves the digest, construction inventory, and stable ID sequence")
	input_handler.call("cancel_operation")
	input_handler.call("start_connection", frost_source)
	var cross_active_rejected := not bool(input_handler.call("complete_connection", home_target))
	_expect(cross_active_rejected and not state.connections.has("connection_from_inactive"), "input rejects completing a connection through an inactive target ID")
	EventBus.delete_building_requested.emit(home_source)
	await get_tree().process_frame
	_expect(state.buildings.has(home_source), "Main rejects a stale inactive delete intent")
	_expect(GameStateCodec.state_digest_payload(state) == before, "all inactive input attempts leave the persisted digest unchanged")
	_expect(home_belt != frost_belt, "fixture owns distinct stable line IDs on both planets")
	viewport.queue_free()
	await get_tree().process_frame

func _test_advanced_inspector_and_renderer_contract() -> void:
	var state := GameState.new()
	state.construction_inventory = {"conveyor_belt_mk1": 4.0}
	var source_id := _add_building(state, "source", "miner", Vector2(100, 100))
	var target_id := _add_building(state, "target", "smelter", Vector2(500, 100))
	var belt_id := state.add_connection({"source_id": source_id, "target_id": target_id, "type": "conveyor_belt_mk1", "item_id": "iron_ore", "parallel_count": 2, "stack_size": 4, "priority": 2, "route_mode": "manual", "route_offset_y": 42.0, "monitor_enabled": true, "enabled": false})
	GameManager.replace_game_state(state)
	var host := Node2D.new()
	add_child(host)
	var input_handler := InputHandlerScript.new()
	input_handler.name = "InputHandler"
	host.add_child(input_handler)
	var connection_renderer := ConnectionRendererScript.new()
	connection_renderer.name = "ConnectionRenderer"
	connection_renderer.set_game_state(state)
	host.add_child(connection_renderer)
	var workspace := WorkspaceScript.new()
	workspace.name = "FactoryWorkspaceUI"
	host.add_child(workspace)
	await get_tree().process_frame
	if input_handler.has_method("set_selected_entities"):
		input_handler.call("set_selected_entities", [belt_id])
	workspace.refresh_now()
	var title := workspace.get_node_or_null("InspectorPanel/Title") as Label
	var details := workspace.get_node_or_null("InspectorPanel/Details") as Label
	_expect(title != null and details != null and "线路" in title.text and "Mk.I" in details.text and "10" in details.text and "并联 2" in details.text and "堆叠 4" in details.text and "偏移 42" in details.text and "禁用" in details.text, "manual single-line inspector displays its complete effective configuration including route offset")
	var belt_controls := workspace.get_node_or_null("InspectorPanel/RecipeScroll/RecipeList") as GridContainer
	var enabled_button: Button
	if belt_controls != null:
		for child in belt_controls.get_children():
			if child is Button and child.text == "启停":
				enabled_button = child
				break
	if enabled_button != null:
		enabled_button.pressed.emit()
	_expect(belt_controls != null and belt_controls.visible and belt_controls.get_node_or_null("ParallelCount") != null and enabled_button != null and state.connections[belt_id].enabled, "single-line inspector exposes direct parallel input and routes commands through authoritative state")
	_expect(connection_renderer.has_method("is_connection_selected") and connection_renderer.call("is_connection_selected", belt_id), "connection renderer consumes the same selection collection")
	if input_handler.has_method("set_selected_entities"):
		input_handler.call("set_selected_entities", [])
	await get_tree().process_frame
	_expect(title != null and title.text == "工厂概览" and workspace.call("get_selected_building_type") == "", "clearing the shared selection clears the workspace mirror and inspector")
	if input_handler.has_method("set_selected_entities"):
		input_handler.call("set_selected_entities", [source_id])
	workspace.refresh_now()
	_expect(details != null and "可移动" in details.text, "single-building inspector displays its current interaction lock state")
	if input_handler.has_method("set_selected_entities"):
		input_handler.call("set_selected_entities", [source_id, target_id])
	workspace.refresh_now()
	var multi_controls := workspace.get_node_or_null("InspectorPanel/RecipeScroll/RecipeList") as GridContainer
	var lock_button: Button
	var unlock_button: Button
	if multi_controls != null:
		for child in multi_controls.get_children():
			if child is Button and child.text == "锁定":
				lock_button = child
			elif child is Button and child.text == "解锁":
				unlock_button = child
	_expect(multi_controls != null and multi_controls.visible and lock_button != null and unlock_button != null, "all-building multi-selection exposes shared lock and unlock commands")
	if lock_button != null:
		lock_button.pressed.emit()
	_expect(state.is_entity_interaction_locked(source_id) and state.is_entity_interaction_locked(target_id) and "锁定 2" in details.text, "multi-selection lock command updates every selected building through GameState")
	if unlock_button != null:
		unlock_button.pressed.emit()
	_expect(not state.is_entity_interaction_locked(source_id) and not state.is_entity_interaction_locked(target_id), "multi-selection unlock command updates every selected building through GameState")
	var second_target_id := _add_building(state, "second_target", "smelter", Vector2(500, 300))
	var second_belt_id := state.add_connection({"source_id": source_id, "target_id": second_target_id, "type": "conveyor_belt_mk1", "item_id": "iron_ore", "priority": 0, "route_mode": "auto", "monitor_enabled": false, "enabled": true})
	if input_handler.has_method("set_selected_entities"):
		input_handler.call("set_selected_entities", [belt_id, second_belt_id])
	workspace.refresh_now()
	var belt_batch_buttons: Dictionary = {}
	if multi_controls != null:
		for child in multi_controls.get_children():
			if child is Button:
				belt_batch_buttons[child.text] = child
	_expect(multi_controls != null and multi_controls.visible and belt_batch_buttons.has("优先级") and belt_batch_buttons.has("路由切换") and belt_batch_buttons.has("监控开关") and belt_batch_buttons.has("启停"), "all-belt multi-selection exposes the shared configuration command intersection")
	var batch_enabled_button := belt_batch_buttons.get("启停") as Button
	if batch_enabled_button != null:
		batch_enabled_button.pressed.emit()
	_expect(not state.connections[belt_id].enabled and not state.connections[second_belt_id].enabled, "multi-line enable command atomically configures every selected belt through GameState")
	if input_handler.has_method("set_selected_entities"):
		input_handler.call("set_selected_entities", [source_id, target_id, belt_id])
	workspace.refresh_now()
	var recipe_list := workspace.get_node_or_null("InspectorPanel/RecipeScroll/RecipeList") as Control
	_expect(title != null and "已选择 3 项" in title.text and details != null and "建筑 2" in details.text and "线路 1" in details.text and "可移动 2" in details.text, "multi-selection inspector shows a summary preview")
	_expect(recipe_list != null and not recipe_list.visible, "multi-selection hides commands that are not shared by every selected entity")
	var panel := workspace.get_node_or_null("InspectorPanel") as Control
	var delete_button := workspace.get_node_or_null("InspectorPanel/DeleteButton") as Button
	_expect(delete_button != null and delete_button.disabled and "无共同批量命令" in details.text, "mixed building and line selection exposes no partial-set batch commands")
	input_handler.call("_delete_selected")
	var confirmation := workspace.get_node_or_null("DeleteConfirmation") as ConfirmationDialog
	_expect(confirmation != null and not confirmation.visible and state.buildings.size() == 3, "Delete never silently consumes only the building subset of a mixed selection")
	_expect(panel != null and delete_button != null and Rect2(Vector2.ZERO, panel.size).encloses(delete_button.get_rect()), "advanced inspector controls remain inside the existing panel")
	host.queue_free()
	await get_tree().process_frame

func _add_building(state: GameState, id: String, type: String, position: Vector2, planet_id: String = "home") -> String:
	state.buildings[id] = {
		"id": id,
		"type": type,
		"planet_id": planet_id,
		"position": position,
		"status": "idle",
		"recipe_id": "",
		"progress": 0.0,
		"input_buffer": {},
		"output_buffer": {},
		"speed": 1.0,
	}
	return id

func _expect(condition: bool, description: String) -> void:
	if condition:
		print("PASS: %s" % description)
		return
	_failures += 1
	printerr("FAIL: %s" % description)
