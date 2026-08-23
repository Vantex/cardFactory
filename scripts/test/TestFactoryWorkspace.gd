extends Node

const CardRenderer = preload("res://scripts/rendering/CardRenderer.gd")
const ConnectionRenderer = preload("res://scripts/rendering/ConnectionRenderer.gd")

var _failures := 0

func _ready() -> void:
	print("FACTORY WORKSPACE TESTS STARTED")
	_test_explicit_building_costs()
	_test_existing_recipe_connection_rules()
	_test_connection_activity_contract()
	_test_renderer_geometry_contract()
	await _test_workspace_chrome_contract()
	await _test_main_scene_integration_contract()
	_test_canvas_input_contract()
	_test_real_production_loop()

	var state := GameState.new()
	_expect(state.construction_points == 12, "new workspaces start with 12 construction points")

	var miner: Dictionary = state.try_place_building("miner", Vector2(100, 100))
	_expect(miner.ok and state.construction_points == 11, "miner placement is atomic")
	_expect(state.buildings.size() == 1, "successful placement adds one building")
	_expect(state.get_building_display_name(miner.id) == "矿机", "building display names come from building data")

	var points_before_rejection: int = state.construction_points
	var buildings_before_rejection: int = state.buildings.size()
	_expect(not state.try_place_building("unknown_building", Vector2(240, 100)).ok, "unknown buildings are rejected")
	_expect(state.construction_points == points_before_rejection and state.buildings.size() == buildings_before_rejection, "unknown building rejection leaves state unchanged")

	state.construction_points = 0
	_expect(not state.try_place_building("smelter", Vector2(240, 100)).ok, "placements without points are rejected")
	_expect(state.construction_points == 0 and state.buildings.size() == buildings_before_rejection, "insufficient-point rejection leaves state unchanged")

	state.construction_points = points_before_rejection
	_expect(not state.try_place_building("miner", Vector2(100, 100)).ok, "overlapping placements are rejected")
	_expect(state.construction_points == points_before_rejection and state.buildings.size() == buildings_before_rejection, "overlap rejection leaves state unchanged")

	var smelter: Dictionary = state.try_place_building("smelter", Vector2(420, 100))
	_expect(smelter.ok, "smelter placement succeeds in free space")
	var connected: Dictionary = state.try_add_connection(miner.id, smelter.id)
	_expect(connected.ok, "compatible buildings connect")
	_expect(state.get_building(smelter.id).recipe_id == "iron_ingot_recipe", "connection auto-selects recipe")
	_expect(not state.try_add_connection(miner.id, miner.id).ok, "self connections are rejected")
	_expect(not state.try_add_connection(miner.id, smelter.id).ok, "duplicate connections are rejected")
	_expect(not state.try_add_connection(smelter.id, miner.id).ok, "incompatible connections are rejected")
	_expect(state.connections.size() == 1, "rejected connections leave existing connections unchanged")

	state.remove_building(miner.id)
	_expect(not state.buildings.has(miner.id) and state.connections.is_empty(), "removing a building cascades to its connections")

	if _failures > 0:
		printerr("FACTORY WORKSPACE TESTS FAILED")
		get_tree().quit(1)
		return

	print("FACTORY WORKSPACE TESTS PASSED")
	get_tree().quit(0)

func _test_workspace_chrome_contract() -> void:
	var workspace_script := load("res://scenes/ui/FactoryWorkspaceUI.gd") as Script
	_expect(workspace_script != null, "workspace UI script is available")
	if workspace_script == null:
		return

	var workspace := workspace_script.new() as CanvasLayer
	_expect(workspace != null, "workspace UI is a CanvasLayer")
	if workspace == null:
		return

	var placements: Array[String] = []
	var listener: Callable = func(building_type: String) -> void:
		placements.append(building_type)
	_expect(EventBus.has_signal("placement_requested"), "workspace placement event is available")
	if EventBus.has_signal("placement_requested"):
		EventBus.connect("placement_requested", listener)

	add_child(workspace)
	await get_tree().process_frame
	for path in ["TopBar", "ResourceRail", "InspectorPanel", "ConstructionDock", "Toast"]:
		_expect(workspace.get_node_or_null(path) != null, "workspace exposes %s" % path)
	workspace.call("_on_building_pressed", "miner")
	_expect(workspace.call("get_selected_building_type") == "miner", "dock enters placement mode")
	_expect(placements == ["miner"], "dock emits a placement request for miner")

	if EventBus.has_signal("placement_requested") and EventBus.is_connected("placement_requested", listener):
		EventBus.disconnect("placement_requested", listener)
	workspace.queue_free()

func _test_main_scene_integration_contract() -> void:
	GameManager.game_state = GameState.new()
	var main_scene := load("res://scenes/main/Main.tscn") as PackedScene
	_expect(main_scene != null, "main scene is available for workspace integration")
	if main_scene == null:
		return

	var main := main_scene.instantiate()
	add_child(main)
	await get_tree().process_frame

	var world_camera := main.get_node_or_null("WorldCamera") as Camera2D
	var card_renderer := main.get_node_or_null("CardRenderer")
	var connection_renderer := main.get_node_or_null("ConnectionRenderer")
	var input_handler := main.get_node_or_null("InputHandler")
	var workspace := main.get_node_or_null("FactoryWorkspaceUI")
	_expect(world_camera != null, "main scene exposes the named world camera")
	_expect(card_renderer != null and connection_renderer != null and input_handler != null and workspace != null, "main scene composes renderers, input, and workspace UI")
	_expect(main.get_node_or_null("HUD") == null and main.get_node_or_null("BuildingPanel") == null, "main scene no longer mounts legacy UI")
	_expect(GameManager.get_game_state().buildings.is_empty() and GameManager.get_game_state().connections.is_empty(), "main scene starts with an empty factory")

	if card_renderer != null and connection_renderer != null:
		_expect(card_renderer.get("_game_state") == GameManager.get_game_state() and connection_renderer.get("_game_state") == GameManager.get_game_state(), "main injects the active game state into both renderers")
	if input_handler != null and workspace != null:
		_expect(input_handler.call("_is_pointer_over_ui", Vector2(10, 10)), "main routes workspace hit testing into canvas input")
		workspace.call("_on_building_pressed", "miner")
		_expect(input_handler.call("get_mode_name") == "placing" and input_handler.get("placing_building_type") == "miner", "workspace placement requests enter real canvas placement mode")

		input_handler.call("_place_card", Vector2(320, 180))
		var placed_id: String = input_handler.get("selected_building_id")
		_expect(not placed_id.is_empty() and GameManager.get_game_state().buildings.size() == 1, "real canvas placement adds and selects the requested card")
		var resource_summary := workspace.get_node("ResourceRail/Summary") as Label
		_expect("POINTS  11" in resource_summary.text and "BUILDINGS  01" in resource_summary.text, "placing a card refreshes workspace resource totals immediately")
		var inspector_title := workspace.get_node("InspectorPanel/Title") as Label
		_expect(inspector_title.text == "矿机", "real canvas placement selects the new card in the workspace inspector")

		input_handler.set("selected_building_id", "")
		EventBus.card_selected.emit(placed_id)
		_expect(input_handler.get("selected_building_id") == placed_id and workspace.call("get_selected_building_type") == "miner", "card selection synchronizes input and workspace inspector")
		GameManager.get_game_state().remove_building(placed_id)
		_expect(input_handler.get("selected_building_id") == "" and workspace.call("get_selected_building_type") == "", "removing the selected card clears input and inspector selection")

		var pause_event := InputEventKey.new()
		pause_event.keycode = KEY_SPACE
		pause_event.pressed = true
		input_handler.call("_handle_key_press", pause_event)
		var speed_event := InputEventKey.new()
		speed_event.keycode = KEY_3
		speed_event.pressed = true
		input_handler.call("_handle_key_press", speed_event)
		_expect(GameManager.get_game_state().paused and is_equal_approx(GameManager.get_game_state().speed, 3.0), "workspace input controls write pause and speed to game state")

	main.queue_free()
	await get_tree().process_frame

func _test_real_production_loop() -> void:
	var state := GameState.new()
	var miner: Dictionary = state.try_place_building("miner", Vector2(100, 100))
	var smelter: Dictionary = state.try_place_building("smelter", Vector2(420, 100))
	var connection: Dictionary = state.try_add_connection(miner.get("id", ""), smelter.get("id", ""))
	_expect(miner.get("ok", false) and smelter.get("ok", false) and connection.get("ok", false), "real production loop can be constructed through atomic commands")
	if not miner.get("ok", false) or not smelter.get("ok", false) or not connection.get("ok", false):
		return

	var engine := SimulationEngine.new(state)
	engine.update(6.0)
	engine.update(0.5)
	var buffered_ore: float = state.get_building(smelter.id).get("input_buffer", {}).get("iron_ore", 0.0)
	_expect(buffered_ore >= 1.0, "belt update moves mined iron ore into the smelter")
	engine.update(0.5)
	var produced_ingots: float = state.get_building(smelter.id).get("output_buffer", {}).get("iron_ingot", 0.0)
	_expect(produced_ingots >= 1.0, "production update consumes ore and produces an iron ingot")

func _test_explicit_building_costs() -> void:
	var cost_cases := [
		{"building_type": "miner", "remaining_points": 11},
		{"building_type": "smelter", "remaining_points": 10},
		{"building_type": "assembling_machine_mk1", "remaining_points": 9},
		{"building_type": "power_generator", "remaining_points": 10},
	]
	for cost_case in cost_cases:
		var state := GameState.new()
		var result: Dictionary = state.try_place_building(cost_case.building_type, Vector2(100, 100))
		_expect(result.ok and state.construction_points == cost_case.remaining_points, "%s uses its configured construction cost" % cost_case.building_type)

	var unconfigured_state := GameState.new()
	var unconfigured_result: Dictionary = unconfigured_state.try_place_building("solar_panel", Vector2(100, 100))
	_expect(not unconfigured_result.ok and unconfigured_state.construction_points == 12 and unconfigured_state.buildings.is_empty(), "buildings without configured costs are rejected without state changes")

func _test_existing_recipe_connection_rules() -> void:
	var compatible_state := GameState.new()
	var compatible_miner: Dictionary = compatible_state.try_place_building("miner", Vector2(100, 100))
	var compatible_smelter: Dictionary = compatible_state.try_place_building("smelter", Vector2(420, 100))
	compatible_state.set_entity_recipe(compatible_smelter.id, "iron_ingot_recipe")
	compatible_state.get_building(compatible_smelter.id)["progress"] = 0.5
	var compatible_connection: Dictionary = compatible_state.try_add_connection(compatible_miner.id, compatible_smelter.id)
	_expect(compatible_connection.ok and compatible_state.get_building(compatible_smelter.id).recipe_id == "iron_ingot_recipe" and compatible_state.get_building(compatible_smelter.id).progress == 0.5, "compatible existing recipes are accepted without being rewritten")

	var incompatible_state := GameState.new()
	var incompatible_miner: Dictionary = incompatible_state.try_place_building("miner", Vector2(100, 100))
	var incompatible_smelter: Dictionary = incompatible_state.try_place_building("smelter", Vector2(420, 100))
	incompatible_state.set_entity_recipe(incompatible_smelter.id, "copper_ingot_recipe")
	incompatible_state.get_building(incompatible_smelter.id)["progress"] = 0.5
	var incompatible_connection: Dictionary = incompatible_state.try_add_connection(incompatible_miner.id, incompatible_smelter.id)
	_expect(not incompatible_connection.ok and incompatible_state.connections.is_empty() and incompatible_state.get_building(incompatible_smelter.id).recipe_id == "copper_ingot_recipe" and incompatible_state.get_building(incompatible_smelter.id).progress == 0.5, "incompatible existing recipes reject connections without state changes")

func _test_connection_activity_contract() -> void:
	var state := GameState.new()
	GameManager.game_state = state
	var source: Dictionary = state.try_place_building("miner", Vector2(100, 100))
	var target: Dictionary = state.try_place_building("smelter", Vector2(420, 100))
	var normal_result: Dictionary = state.try_add_connection(source.id, target.id)
	var normal_connection: Dictionary = state.connections[normal_result.id]
	_expect(normal_result.ok and normal_connection.get("active", false), "normally created connections are explicitly active")

	var disabled_id := state.add_connection({
		"source_id": source.id,
		"target_id": target.id,
		"item_id": "iron_ore",
		"active": false,
	})
	var defaulted_id := state.add_connection({
		"source_id": source.id,
		"target_id": target.id,
		"item_id": "iron_ore",
	})
	var disabled_connection: Dictionary = state.connections[disabled_id]
	var defaulted_connection: Dictionary = state.connections[defaulted_id]
	_expect(not disabled_connection.get("active", true), "explicitly inactive connections remain inactive")
	_expect(defaulted_connection.get("active", false), "directly added connections are explicitly active")

	var connection_renderer := ConnectionRenderer.new()
	_expect(connection_renderer.is_connection_active(normal_connection) and connection_renderer.is_connection_active(defaulted_connection) and not connection_renderer.is_connection_active(disabled_connection), "renderer follows normalized connection activity")
	connection_renderer.queue_free()

	var statistics := StatisticsSystem.new(state)
	_expect(is_equal_approx(statistics.get_logistics_efficiency(), 2.0 / 3.0), "statistics follows normalized connection activity")

func _test_renderer_geometry_contract() -> void:
	_expect(CardRenderer.CARD_SIZE == Vector2(232, 144), "card geometry is stable")
	_expect(CardRenderer.get_input_port_rect(Vector2.ZERO).has_point(Vector2(0, 72)), "input port hit area matches drawing")
	_expect(CardRenderer.get_output_port_rect(Vector2.ZERO).has_point(Vector2(232, 72)), "output port hit area matches drawing")
	_test_renderer_selection_contract()

func _test_renderer_selection_contract() -> void:
	var main_scene := load("res://scenes/main/Main.tscn") as PackedScene
	_expect(main_scene != null, "main scene is available for renderer selection")
	if main_scene == null:
		return
	var main := main_scene.instantiate()
	var card_renderer := main.get_node_or_null("CardRenderer")
	var input_handler := main.get_node_or_null("InputHandler")
	_expect(card_renderer != null and input_handler != null, "main wires card rendering and input together")
	if card_renderer == null or input_handler == null:
		main.queue_free()
		return
	input_handler.set("selected_building_id", "selected_card")
	_expect(card_renderer.has_method("is_building_selected"), "card renderer exposes selection state")
	if card_renderer.has_method("is_building_selected"):
		_expect(card_renderer.call("is_building_selected", "selected_card"), "input selection drives the card outline state")
	main.queue_free()

func _test_canvas_input_contract() -> void:
	var input_script := load("res://scripts/input/InputHandler.gd") as Script
	_expect(input_script != null, "canvas input script is available")
	if input_script == null:
		return

	var input_handler: Node = input_script.new()
	_expect(input_handler.has_method("get_mode_name"), "canvas input exposes its mode contract")
	_expect(input_handler.has_method("cancel_operation"), "canvas input exposes its cancellation contract")
	_expect(input_handler.has_method("complete_connection"), "canvas input exposes connection completion")
	if not input_handler.has_method("get_mode_name") or not input_handler.has_method("cancel_operation") or not input_handler.has_method("complete_connection"):
		input_handler.queue_free()
		return
	_expect(input_handler.call("get_mode_name") == "idle", "canvas input starts idle")
	input_handler.call("start_placing_card", "miner")
	_expect(input_handler.call("get_mode_name") == "placing", "placement mode starts")
	input_handler.call("cancel_operation")
	_expect(input_handler.call("get_mode_name") == "idle", "escape contract cancels")

	GameManager.game_state = GameState.new()
	var source: Dictionary = GameManager.get_game_state().try_place_building("miner", Vector2(100, 100))
	var target: Dictionary = GameManager.get_game_state().try_place_building("smelter", Vector2(420, 100))
	_expect(input_handler.call("_get_output_port_at_position", Vector2(332, 172)) == source.id, "visible card output port is clickable through input handling")
	input_handler.call("start_connection", source.id)
	_expect(input_handler.call("get_mode_name") == "connecting", "connection mode starts")
	_expect(input_handler.call("complete_connection", target.id), "legal connection completes through the input handler")
	_expect(input_handler.call("get_mode_name") == "idle" and GameManager.get_game_state().connections.size() == 1, "completed connection clears input state")
	var connection_renderer := ConnectionRenderer.new()
	_expect(connection_renderer.has_method("is_connection_active"), "connection renderer exposes activity semantics")
	if connection_renderer.has_method("is_connection_active"):
		_expect(connection_renderer.call("is_connection_active", GameManager.get_game_state().connections.values()[0]), "normally created connections animate by default")
	connection_renderer.queue_free()

	var main_scene := load("res://scenes/main/Main.tscn") as PackedScene
	_expect(main_scene != null, "main scene is available")
	if main_scene == null:
		return
	var main := main_scene.instantiate()
	var camera := main.get_node_or_null("WorldCamera") as Camera2D
	_expect(camera != null, "main scene provides a world camera")
	if camera != null:
		_expect(is_equal_approx(camera.get_meta("min_zoom", 0.0), 0.45) and is_equal_approx(camera.get_meta("max_zoom", 0.0), 1.8), "world camera exposes the 0.45 to 1.8 zoom range")
	main.queue_free()

	add_child(input_handler)
	var ui_state := {"pointer_over_ui": false}
	var ui_hit_test: Callable = func(_screen_position: Vector2) -> bool:
		return ui_state.pointer_over_ui
	input_handler.call("set_ui_hit_test", ui_hit_test)

	input_handler.call("_unhandled_input", _mouse_button_event(MOUSE_BUTTON_RIGHT, true, Vector2(320, 180)))
	_expect(input_handler.call("get_mode_name") == "panning", "right press starts panning on the world canvas")
	ui_state.pointer_over_ui = true
	input_handler.call("_unhandled_input", _mouse_button_event(MOUSE_BUTTON_RIGHT, false, Vector2(40, 80)))
	_expect(input_handler.call("get_mode_name") == "idle", "panning release over UI clears the active operation")

	input_handler.set("current_mode", 2)
	input_handler.set("dragging_building_id", "building_under_test")
	input_handler.call("_unhandled_input", _mouse_button_event(MOUSE_BUTTON_LEFT, false, Vector2(40, 80)))
	_expect(input_handler.call("get_mode_name") == "idle", "dragging release over UI finishes the active operation")
	input_handler.queue_free()

func _mouse_button_event(button_index: MouseButton, pressed: bool, position: Vector2) -> InputEventMouseButton:
	var event := InputEventMouseButton.new()
	event.button_index = button_index
	event.pressed = pressed
	event.position = position
	return event

func _expect(condition: bool, description: String) -> void:
	if condition:
		print("PASS: %s" % description)
		return

	_failures += 1
	printerr("FAIL: %s" % description)
