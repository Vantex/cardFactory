extends Node

const CardRenderer = preload("res://scripts/rendering/CardRenderer.gd")
const ConnectionRenderer = preload("res://scripts/rendering/ConnectionRenderer.gd")

class UnhandledReleaseObserver:
	extends Node

	var release_count := 0

	func _unhandled_input(event: InputEvent) -> void:
		if event is InputEventMouseButton and not event.pressed:
			release_count += 1

var _failures := 0

func _ready() -> void:
	print("FACTORY WORKSPACE TESTS STARTED")
	var workspace_save_system := SaveSystem.new("res://.godot/test_saves/factory_workspace/")
	workspace_save_system.delete_slot(9)
	GameManager.configure_save_system(workspace_save_system)
	_expect(GameManager.start_new_game(9).get("ok") == true, "workspace integration tests run inside an explicit local session")
	_test_explicit_building_costs()
	_test_existing_recipe_connection_rules()
	_test_rectangle_overlap_contract()
	_test_connection_activity_contract()
	_test_renderer_geometry_contract()
	await _test_workspace_chrome_contract()
	await _test_workspace_live_content_and_actions()
	await _test_selection_and_placement_mode_alignment()
	await _test_main_scene_integration_contract()
	await _test_transformed_coordinate_connection_gestures()
	await _test_canvas_input_contract()
	_test_real_production_loop()

	var state := GameState.new()
	_expect(state.construction_inventory.get("miner") == 1.0 and state.construction_inventory.get("smelter") == 1.0, "new workspaces start with a real construction kit")

	var miner: Dictionary = state.try_place_building("miner", Vector2(100, 100))
	_expect(miner.ok and state.construction_inventory.get("miner") == 0.0, "miner placement atomically consumes its construction item")
	_expect(state.buildings.size() == 1, "successful placement adds one building")
	_expect(state.get_building_display_name(miner.id) == "矿机", "building display names come from building data")

	var inventory_before_rejection: Dictionary = state.construction_inventory.duplicate(true)
	var buildings_before_rejection: int = state.buildings.size()
	_expect(not state.try_place_building("unknown_building", Vector2(240, 100)).ok, "unknown buildings are rejected")
	_expect(state.construction_inventory == inventory_before_rejection and state.buildings.size() == buildings_before_rejection, "unknown building rejection leaves state unchanged")

	state.construction_inventory["smelter"] = 0.0
	_expect(not state.try_place_building("smelter", Vector2(240, 100)).ok, "placements without a matching construction item are rejected")
	_expect(state.construction_inventory.get("smelter") == 0.0 and state.buildings.size() == buildings_before_rejection, "missing construction-item rejection leaves state unchanged")

	state.construction_inventory["smelter"] = 1.0
	state.construction_inventory["miner"] = 1.0
	_expect(not state.try_place_building("miner", Vector2(100, 100)).ok, "overlapping placements are rejected")
	_expect(state.construction_inventory.get("miner") == 1.0 and state.buildings.size() == buildings_before_rejection, "overlap rejection preserves the construction item")

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

	workspace_save_system.delete_slot(9)
	if _failures > 0:
		printerr("FACTORY WORKSPACE TESTS FAILED")
		get_tree().quit(1)
		return

	print("FACTORY WORKSPACE TESTS PASSED")
	get_tree().quit(0)

func _test_workspace_chrome_contract() -> void:
	GameManager.replace_game_state(GameState.new())
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
	for path in ["TopBar/PauseButton", "TopBar/SpeedButtons/Speed1", "TopBar/SpeedButtons/Speed2", "TopBar/SpeedButtons/Speed3", "ResourceRail/Objective", "ResourceRail/Stock", "ResourceRail/Cursor", "ResourceRail/Handcraft", "ResourceRail/Production", "ResourceRail/Tips", "InspectorPanel/Details", "InspectorPanel/InputBuffers", "InspectorPanel/OutputBuffers", "InspectorPanel/StartConnectionButton", "InspectorPanel/DeleteButton", "ConstructionDock/Mode"]:
		_expect(workspace.get_node_or_null(path) != null, "workspace exposes live control %s" % path)
	var brand := workspace.get_node("TopBar/Brand") as Label
	var pause_button := workspace.get_node("TopBar/PauseButton") as Button
	var summary := workspace.get_node("ResourceRail/Summary") as Label
	var objective := workspace.get_node("ResourceRail/Objective") as Label
	var inspector_title := workspace.get_node("InspectorPanel/Title") as Label
	var inspector_details := workspace.get_node("InspectorPanel/Details") as Label
	var dock_points := workspace.get_node("ConstructionDock/Points") as Label
	var dock_buttons := workspace.get_node("ConstructionDock/BuildingButtons") as HBoxContainer
	_expect(brand.position == Vector2(14, 15) and pause_button.get_rect() == Rect2(132, 9, 64, 34), "top-bar children keep their authored positions instead of filling the panel")
	_expect(summary.position == Vector2(16, 14) and objective.position == Vector2(16, 76) and not summary.get_rect().intersects(objective.get_rect()), "resource-rail sections keep distinct non-overlapping rectangles")
	_expect(inspector_title.get_rect() == Rect2(18, 14, 250, 28) and inspector_details.get_rect() == Rect2(18, 46, 250, 76) and not inspector_title.get_rect().intersects(inspector_details.get_rect()), "inspector sections keep distinct non-overlapping rectangles")
	_expect(dock_points.position == Vector2(14, 12) and dock_buttons.get_rect() == Rect2(126, 13, 510, 64), "construction-dock labels and buttons keep separate authored regions")
	_expect(_controls_do_not_overlap(workspace.get_node("TopBar"), ["Brand", "PauseButton", "SpeedButtons", "Status"]), "all top-bar regions remain non-overlapping")
	_expect(_controls_do_not_overlap(workspace.get_node("ResourceRail"), ["Summary", "Objective", "Stock", "Cursor", "Handcraft", "Production", "Tips"]), "all resource-rail regions remain non-overlapping")
	_expect(_controls_do_not_overlap(workspace.get_node("InspectorPanel"), ["Title", "Details", "InputBuffers", "OutputBuffers", "RecipeHeading", "RecipeList", "StartConnectionButton", "DeleteButton"]), "all inspector regions remain non-overlapping")
	_expect(_controls_do_not_overlap(workspace.get_node("ConstructionDock"), ["Points", "Mode", "BuildingButtons"]), "all construction-dock regions remain non-overlapping")
	workspace.call("_on_building_pressed", "miner")
	_expect(workspace.call("get_selected_building_type") == "" and workspace.call("get_placement_building_type") == "miner", "dock enters placement mode without conflating selection")
	_expect(placements == ["miner"], "dock emits a placement request for miner")
	var miner_button := workspace.get_node_or_null("ConstructionDock/BuildingButtons/MinerButton") as Button
	_expect(miner_button != null and "Q" in miner_button.text and "已有 1 / 需要 1" in miner_button.text, "dock shows the miner shortcut and owned construction item")
	_expect(miner_button != null and not miner_button.tooltip_text.is_empty(), "dock exposes each building purpose")
	var mode_label := workspace.get_node_or_null("ConstructionDock/Mode") as Label
	_expect(mode_label != null and "矿机" in mode_label.text, "dock displays the current placement mode")

	if EventBus.has_signal("placement_requested") and EventBus.is_connected("placement_requested", listener):
		EventBus.disconnect("placement_requested", listener)
	workspace.queue_free()
	await get_tree().process_frame

func _test_workspace_live_content_and_actions() -> void:
	GameManager.game_state = GameState.new()
	GameManager.simulation_engine = SimulationEngine.new(GameManager.game_state)
	var main_scene := load("res://scenes/main/Main.tscn") as PackedScene
	var test_viewport := SubViewport.new()
	test_viewport.size = Vector2i(1152, 648)
	add_child(test_viewport)
	var main := main_scene.instantiate()
	test_viewport.add_child(main)
	await get_tree().process_frame

	var state := GameManager.get_game_state()
	var workspace := main.get_node("FactoryWorkspaceUI") as CanvasLayer
	var input_handler := main.get_node("InputHandler")
	var miner: Dictionary = state.try_place_building("miner", Vector2(260, 100))
	var smelter: Dictionary = state.try_place_building("smelter", Vector2(600, 100))
	state.planet_inventory["iron_ore"] = 6.0
	state.get_building(miner.id)["output_buffer"] = {"iron_ore": 4.0}
	state.get_building(smelter.id)["input_buffer"] = {"iron_ore": 2.0}
	state.get_building(miner.id)["status"] = "running"
	state.elapsed_time = 65.0
	EventBus.simulation_updated.emit()
	await get_tree().process_frame

	var metrics := workspace.get_node_or_null("TopBar/Status") as Label
	_expect(metrics != null and "RUN" in metrics.text and "1x" in metrics.text and "GEN 0" in metrics.text and "USE 60" in metrics.text and "BAL -60" in metrics.text and "KITS 03" in metrics.text and "BUILDINGS 02" in metrics.text and "LINKS 00" in metrics.text and "01:05" in metrics.text, "top bar displays live simulation, power, count, construction kit, and time state")
	var pause_button := workspace.get_node_or_null("TopBar/PauseButton") as Button
	if pause_button != null:
		pause_button.emit_signal("pressed")
	_expect(pause_button != null and state.paused and "继续" in pause_button.text, "pause button changes simulation state and visible control state")
	var speed_three := workspace.get_node_or_null("TopBar/SpeedButtons/Speed3") as Button
	if speed_three != null:
		speed_three.emit_signal("pressed")
	_expect(speed_three != null and is_equal_approx(state.speed, 3.0) and speed_three.button_pressed, "speed buttons change simulation speed and visible control state")

	var objective := workspace.get_node_or_null("ResourceRail/Objective") as Label
	var stock := workspace.get_node_or_null("ResourceRail/Stock") as Label
	var production := workspace.get_node_or_null("ResourceRail/Production") as Label
	var tips := workspace.get_node_or_null("ResourceRail/Tips") as Label
	_expect(objective != null and "连接" in objective.text, "resource rail displays the current beginner objective")
	_expect(stock != null and "行星托盘" in stock.text and "iron_ore" in stock.text and "6" in stock.text, "resource rail displays authoritative planet inventory")
	_expect(production != null and "运行 0" in production.text and "停电 1" in production.text, "resource rail distinguishes unpowered production from running buildings")
	_expect(tips != null and "操作提示" in tips.text and "Q/W/E/R/T" in tips.text, "resource rail displays concise controls")
	var empty_generator_id := state.add_building({
		"type": "power_generator",
		"position": Vector2(900, 400),
		"status": "idle",
		"recipe_id": "",
		"progress": 0.0,
		"input_buffer": {},
		"output_buffer": {},
		"speed": 1.0,
	})
	GameManager.get_simulation_engine().update(1.0 / 60.0)
	workspace.refresh_now()
	_expect("GEN 0" in metrics.text and "BAL -60" in metrics.text, "top bar reports actual fueled generation instead of static generator capacity")
	state.remove_building(empty_generator_id)

	input_handler.call("set_selected_entities", [smelter.id])
	await get_tree().process_frame
	var inspector_title := workspace.get_node("InspectorPanel/Title") as Label
	var details := workspace.get_node_or_null("InspectorPanel/Details") as Label
	var input_buffers := workspace.get_node_or_null("InspectorPanel/InputBuffers") as Label
	var output_buffers := workspace.get_node_or_null("InspectorPanel/OutputBuffers") as Label
	_expect(inspector_title.text == "熔炉" and details != null and "smelter" in details.text and "idle" in details.text and "0%" in details.text and "50" in details.text, "inspector displays selected identity, type, status, progress, and power")
	_expect(input_buffers != null and "iron_ore" in input_buffers.text and "2" in input_buffers.text and output_buffers != null, "inspector displays input and output buffers")
	var recipe_list := workspace.get_node("InspectorPanel/RecipeList") as GridContainer
	_expect(recipe_list.get_child_count() > 0, "smelter inspector exposes real recipe controls")
	if recipe_list.get_child_count() > 0:
		var first_recipe_control := recipe_list.get_child(0)
		workspace.refresh_now()
		_expect(recipe_list.get_child_count() > 0 and recipe_list.get_child(0) == first_recipe_control, "unchanged refresh does not rebuild recipe controls")
	else:
		_expect(false, "unchanged refresh does not rebuild recipe controls")
	input_handler.call("set_selected_entities", [])
	await get_tree().process_frame
	_expect(recipe_list.get_child_count() > 0, "clearing a building selection replaces machine recipes with handcraft controls")
	input_handler.call("set_selected_entities", [smelter.id])
	await get_tree().process_frame

	var toast := workspace.get_node("Toast") as Control
	var toast_message := workspace.get_node("Toast/Message") as Label
	input_handler.call("start_placing_card", "miner")
	input_handler.call("_unhandled_input", _mouse_button_event(MOUSE_BUTTON_LEFT, true, Vector2(260, 100)))
	_expect(toast.visible and toast_message.text == "建筑卡片重叠", "overlap failure reason is visible in Chinese")
	input_handler.call("start_connection", miner.id)
	_expect(input_handler.call("complete_connection", smelter.id), "notice fixture creates its first connection")
	input_handler.call("start_connection", miner.id)
	_expect(not input_handler.call("complete_connection", smelter.id) and toast_message.text == "连接已存在", "duplicate connection failure reason is visible in Chinese")
	input_handler.call("start_connection", miner.id)
	_expect(not input_handler.call("complete_connection", miner.id) and toast_message.text == "不能连接建筑自身", "self-connection failure reason is visible in Chinese")
	input_handler.call("start_connection", smelter.id)
	_expect(not input_handler.call("complete_connection", miner.id) and toast_message.text == "目标建筑无法接收源建筑输出", "incompatible connection failure reason is visible in Chinese")

	input_handler.call("set_selected_entities", [smelter.id])
	await get_tree().process_frame
	var start_button := workspace.get_node_or_null("InspectorPanel/StartConnectionButton") as Button
	if start_button != null:
		start_button.emit_signal("pressed")
	_expect(start_button != null and input_handler.call("get_mode_name") == "connecting" and input_handler.get("connecting_source_id") == smelter.id, "inspector start-connection action reaches the canvas input handler")
	input_handler.call("cancel_operation")
	var delete_button := workspace.get_node_or_null("InspectorPanel/DeleteButton") as Button
	if delete_button != null:
		delete_button.emit_signal("pressed")
	await get_tree().process_frame
	var delete_confirmation := workspace.get_node_or_null("DeleteConfirmation") as ConfirmationDialog
	_expect(delete_button != null and delete_confirmation != null and delete_confirmation.visible and state.buildings.has(smelter.id), "single-building inspector delete waits for explicit UI confirmation")
	if delete_confirmation != null:
		delete_confirmation.confirmed.emit()
	await get_tree().process_frame
	_expect(delete_button != null and not state.buildings.has(smelter.id) and inspector_title.text == "工厂概览", "inspector delete action removes the selected building and returns to overview")

	_expect(recipe_list.get_child_count() > 0, "deleted selection leaves handcraft controls instead of stale machine recipes")

	state.construction_inventory["smelter"] = 0.0
	input_handler.call("start_placing_card", "smelter")
	input_handler.call("_unhandled_input", _mouse_button_event(MOUSE_BUTTON_LEFT, true, Vector2(500, 300)))
	_expect(toast.visible and toast_message.text == "缺少熔炉施工件" and toast_message.get_theme_color("font_color") == Color("df7666"), "failed real placement displays the construction-inventory reason with error tone")
	_expect(not workspace.is_pointer_over_ui(toast.get_global_rect().get_center()), "visible toast does not block the world canvas")
	var hide_timer := workspace.get_node_or_null("Toast/HideTimer") as Timer
	_expect(hide_timer != null, "toast owns an auto-hide timer")
	if hide_timer != null:
		hide_timer.wait_time = 0.05
		hide_timer.start()
		await get_tree().create_timer(0.1).timeout
		_expect(not toast.visible, "toast automatically hides after its timer elapses")

	test_viewport.queue_free()
	await get_tree().process_frame

func _test_main_scene_integration_contract() -> void:
	GameManager.game_state = GameState.new()
	var main_scene := load("res://scenes/main/Main.tscn") as PackedScene
	_expect(main_scene != null, "main scene is available for workspace integration")
	if main_scene == null:
		return

	var test_viewport := SubViewport.new()
	test_viewport.size = Vector2i(1152, 648)
	add_child(test_viewport)
	var main := main_scene.instantiate()
	test_viewport.add_child(main)
	var release_observer := UnhandledReleaseObserver.new()
	test_viewport.add_child(release_observer)
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
	if workspace != null:
		var top_bar := workspace.get_node("TopBar") as Control
		var resource_rail := workspace.get_node("ResourceRail") as Control
		var inspector_panel := workspace.get_node("InspectorPanel") as Control
		var construction_dock := workspace.get_node("ConstructionDock") as Control
		_expect(top_bar.get_global_rect() == Rect2(0, 0, 1152, 52), "top bar occupies the fixed workspace header")
		_expect(resource_rail.get_global_rect() == Rect2(0, 52, 216, 504), "resource rail leaves header and dock unobstructed")
		_expect(inspector_panel.get_global_rect() == Rect2(866, 52, 286, 504), "inspector leaves header and dock unobstructed")
		_expect(construction_dock.get_global_rect() == Rect2(216, 556, 650, 92), "construction dock stays at the bottom of the workspace")
		_expect(not workspace.call("is_pointer_over_ui", Vector2(500, 300)) and workspace.call("is_pointer_over_ui", Vector2(500, 600)), "workspace hit testing keeps the center interactive and the dock blocked")

	if card_renderer != null and connection_renderer != null:
		_expect(card_renderer.get("_game_state") == GameManager.get_game_state() and connection_renderer.get("_game_state") == GameManager.get_game_state(), "main injects the active game state into both renderers")
	if input_handler != null and workspace != null:
		_expect(input_handler.call("_is_pointer_over_ui", Vector2(10, 10)), "main routes workspace hit testing into canvas input")
		workspace.call("_on_building_pressed", "miner")
		_expect(input_handler.call("get_mode_name") == "placing" and input_handler.get("placing_building_type") == "miner", "workspace placement requests enter real canvas placement mode")

		var placed_card_world_position: Vector2 = input_handler.call("_screen_to_world", Vector2(260, 120))
		input_handler.call("_place_card", placed_card_world_position)
		var placed_id: String = input_handler.get("selected_building_id")
		_expect(not placed_id.is_empty() and GameManager.get_game_state().buildings.size() == 1, "real canvas placement adds and selects the requested card")
		var resource_summary := workspace.get_node("ResourceRail/Summary") as Label
		_expect("KITS  04" in resource_summary.text and "BUILDINGS  01" in resource_summary.text, "placing a card refreshes workspace construction inventory immediately")
		var inspector_title := workspace.get_node("InspectorPanel/Title") as Label
		_expect(inspector_title.text == "矿机", "real canvas placement selects the new card in the workspace inspector")

		input_handler.set("selected_building_id", "")
		EventBus.card_selected.emit(placed_id)
		_expect(input_handler.get("selected_building_id") == placed_id and workspace.call("get_selected_building_type") == "miner", "card selection synchronizes input and workspace inspector")

		input_handler.call("set_selected_entities", [])
		var canvas_transform := test_viewport.get_canvas_transform()
		var card_screen_position: Vector2 = canvas_transform * (placed_card_world_position + Vector2(20, 20))
		var blank_screen_position := Vector2(700, 300)
		input_handler.call("_unhandled_input", _mouse_button_event(MOUSE_BUTTON_LEFT, true, card_screen_position))
		_expect(input_handler.get("selected_building_id") == placed_id, "real card click selects input")
		_expect(inspector_title.text == "矿机", "real card click synchronizes the workspace inspector")
		input_handler.call("_unhandled_input", _mouse_button_event(MOUSE_BUTTON_LEFT, true, blank_screen_position))
		await get_tree().process_frame
		_expect(input_handler.get("selected_building_id") == "" and workspace.call("get_selected_building_type") == "" and inspector_title.text == "工厂概览", "real blank canvas click clears input and workspace inspector selection")

		var state := GameManager.get_game_state()
		var covered_target_position: Vector2 = input_handler.call("_screen_to_world", Vector2(1000, 228))
		var covered_target: Dictionary = state.try_place_building("smelter", covered_target_position)
		var existing_connection: Dictionary = state.try_add_connection(placed_id, covered_target.id)
		_expect(covered_target.ok and existing_connection.ok and state.connections.size() == 1, "UI-release fixture creates one existing connection to a target covered by the inspector")
		var release_notices: Array[Dictionary] = []
		var release_notice_listener: Callable = func(message: String, tone: String) -> void:
			release_notices.append({"message": message, "tone": tone})
		EventBus.notice_requested.connect(release_notice_listener)
		var output_screen_position: Vector2 = canvas_transform * (placed_card_world_position + Vector2(232, 72))
		var inspector_panel := workspace.get_node("InspectorPanel") as Control
		test_viewport.push_input(_mouse_button_event(MOUSE_BUTTON_LEFT, true, output_screen_position))
		await get_tree().process_frame
		_expect(input_handler.call("get_mode_name") == "connecting", "a real output-port press starts a connection gesture")
		test_viewport.push_input(_mouse_motion_event(Vector2(1000, 300), Vector2(1000, 300) - output_screen_position, MOUSE_BUTTON_MASK_LEFT))
		await get_tree().process_frame
		var hovered_control := test_viewport.gui_get_hovered_control()
		_expect(hovered_control != null and (hovered_control == inspector_panel or inspector_panel.is_ancestor_of(hovered_control)), "the dragged pointer reaches a real inspector control")
		release_observer.release_count = 0
		test_viewport.push_input(_mouse_button_event(MOUSE_BUTTON_LEFT, false, Vector2(1000, 300)))
		await get_tree().process_frame
		var toast_message := workspace.get_node("Toast/Message") as Label
		var cancellation_count := 0
		var duplicate_count := 0
		for notice in release_notices:
			if notice.message == "连接已取消：请在输入端口释放":
				cancellation_count += 1
			elif notice.message == "连接已存在":
				duplicate_count += 1
		_expect(release_observer.release_count == 0, "an early-handled connection release never leaks into the unhandled-input phase")
		_expect(input_handler.call("get_mode_name") == "idle" and state.connections.size() == 1 and cancellation_count == 1 and duplicate_count == 0 and toast_message.text == "连接已取消：请在输入端口释放", "a release over the inspector cancels exactly once instead of retrying the covered existing connection")
		var pause_button_position := Vector2(164, 26)
		test_viewport.push_input(_mouse_button_event(MOUSE_BUTTON_LEFT, true, pause_button_position))
		test_viewport.push_input(_mouse_button_event(MOUSE_BUTTON_LEFT, false, pause_button_position))
		await get_tree().process_frame
		_expect(state.paused, "ordinary idle UI clicks remain available after adding the early-release guard")
		test_viewport.push_input(_mouse_button_event(MOUSE_BUTTON_LEFT, true, pause_button_position))
		test_viewport.push_input(_mouse_button_event(MOUSE_BUTTON_LEFT, false, pause_button_position))
		await get_tree().process_frame
		_expect(not state.paused, "a second ordinary UI click restores the prior pause state")
		if EventBus.notice_requested.is_connected(release_notice_listener):
			EventBus.notice_requested.disconnect(release_notice_listener)

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

	test_viewport.queue_free()
	await get_tree().process_frame

func _test_selection_and_placement_mode_alignment() -> void:
	GameManager.game_state = GameState.new()
	GameManager.simulation_engine = SimulationEngine.new(GameManager.game_state)
	var main_scene := load("res://scenes/main/Main.tscn") as PackedScene
	var test_viewport := SubViewport.new()
	test_viewport.size = Vector2i(1152, 648)
	add_child(test_viewport)
	var main := main_scene.instantiate()
	test_viewport.add_child(main)
	await get_tree().process_frame
	var state := GameManager.get_game_state()
	state.construction_inventory["miner"] = 2.0
	state.construction_inventory["smelter"] = 2.0
	var input_handler := main.get_node("InputHandler")
	var workspace := main.get_node("FactoryWorkspaceUI") as CanvasLayer
	var app_shell := main.get_node("AppShell")
	var miner: Dictionary = state.try_place_building("miner", Vector2(260, 100))
	EventBus.card_selected.emit(miner.id)
	workspace.call("_on_building_pressed", "smelter")
	await get_tree().process_frame
	_expect(input_handler.call("get_mode_name") == "placing" and input_handler.get("selected_building_id") == "" and workspace.call("get_selected_building_type") == "", "entering placement mode clears the old selection across input and inspector")
	_expect(workspace.has_method("get_placement_building_type") and workspace.call("get_placement_building_type") == "smelter", "construction dock tracks placement mode separately from selection")
	var delete_event := InputEventKey.new()
	delete_event.keycode = KEY_DELETE
	delete_event.pressed = true
	input_handler.call("_handle_key_press", delete_event)
	_expect(state.buildings.has(miner.id), "Delete in placement mode cannot remove the previously selected building")
	var escape_event := InputEventKey.new()
	escape_event.keycode = KEY_ESCAPE
	escape_event.pressed = true
	test_viewport.push_input(escape_event, true)
	await get_tree().process_frame
	var mode_label := workspace.get_node("ConstructionDock/Mode") as Label
	_expect(input_handler.call("get_mode_name") == "idle" and (not workspace.has_method("get_placement_building_type") or workspace.call("get_placement_building_type") == "") and "选择建筑" in mode_label.text, "Escape clears the real placement mode and its visible dock state")
	_expect(app_shell.call("get_screen_name") == "game" and GameManager.is_session_active(), "Escape consumed by an active canvas operation does not also leave the game session")
	test_viewport.push_input(escape_event, true)
	await get_tree().process_frame
	var returned_save: Dictionary = GameManager.get_save_system().load_slot(9)
	var returned_state: Variant = returned_save.get("state")
	_expect(app_shell.call("get_screen_name") == "start" and not GameManager.is_session_active(), "Escape from an idle canvas saves and returns to the start menu")
	_expect(returned_save.get("ok") == true and returned_state is GameState and returned_state.buildings.has(miner.id), "return-to-menu handshake persists the active factory before ending the session")
	_expect(GameManager.start_new_game(9).get("ok") == true, "workspace tests resume an explicit session after exercising return-to-menu")
	test_viewport.queue_free()
	await get_tree().process_frame

func _test_transformed_coordinate_connection_gestures() -> void:
	GameManager.game_state = GameState.new()
	GameManager.simulation_engine = SimulationEngine.new(GameManager.game_state)
	var main_scene := load("res://scenes/main/Main.tscn") as PackedScene
	_expect(main_scene != null, "main scene is available for transformed coordinate gestures")
	if main_scene == null:
		return

	var test_viewport := SubViewport.new()
	test_viewport.size = Vector2i(1152, 648)
	add_child(test_viewport)
	var main := main_scene.instantiate() as Node2D
	test_viewport.add_child(main)
	await get_tree().process_frame
	var world_camera := main.get_node("WorldCamera") as Camera2D
	if world_camera != null:
		world_camera.enabled = false
	test_viewport.canvas_transform = Transform2D(Vector2(1.02, 0), Vector2(0, 1.02), Vector2.ZERO)

	var state := GameManager.get_game_state()
	var input_handler := main.get_node("InputHandler")
	var workspace := main.get_node("FactoryWorkspaceUI") as CanvasLayer
	workspace.transform = Transform2D(Vector2(1.05, 0), Vector2(0, 1.05), Vector2(-150, 0))
	await get_tree().process_frame
	state.construction_inventory["miner"] = 2.0
	state.construction_inventory["smelter"] = 2.0

	var inspector_source: Dictionary = state.try_place_building("miner", Vector2(260, 100))
	var inspector_target: Dictionary = state.try_place_building("smelter", Vector2(800, 100))
	var existing_connection: Dictionary = state.try_add_connection(inspector_source.id, inspector_target.id)
	_expect(inspector_source.ok and inspector_target.ok and existing_connection.ok, "transformed inspector fixture creates one existing connection")
	var notices: Array[Dictionary] = []
	var notice_listener: Callable = func(message: String, tone: String) -> void:
		notices.append({"message": message, "tone": tone})
	EventBus.notice_requested.connect(notice_listener)

	# The literal points are the viewport positions of the real ports after the 1.02 canvas transform.
	test_viewport.push_input(_mouse_button_event(MOUSE_BUTTON_LEFT, true, Vector2(501.84, 175.44)), true)
	await get_tree().process_frame
	_expect(input_handler.call("get_mode_name") == "connecting", "transformed output press starts a real connection gesture")
	test_viewport.push_input(_mouse_motion_event(Vector2(825.18, 175.44), Vector2(323.34, 0), MOUSE_BUTTON_MASK_LEFT), true)
	await get_tree().process_frame
	test_viewport.push_input(_mouse_button_event(MOUSE_BUTTON_LEFT, false, Vector2(825.18, 175.44)), true)
	await get_tree().process_frame

	var cancellation_count := 0
	var duplicate_count := 0
	for notice in notices:
		if notice.message == "连接已取消：请在输入端口释放":
			cancellation_count += 1
		elif notice.message == "连接已存在":
			duplicate_count += 1
	_expect(input_handler.call("get_mode_name") == "idle" and state.connections.size() == 1 and cancellation_count == 1 and duplicate_count == 0, "transformed inspector release cancels exactly once without retrying its covered existing connection")

	main.transform = Transform2D(Vector2(1.12, 0), Vector2(0, 1.12), Vector2.ZERO)
	var world_source: Dictionary = state.try_place_building("miner", Vector2(260, 300))
	var world_target: Dictionary = state.try_place_building("smelter", Vector2(600, 300))
	_expect(world_source.ok and world_target.ok, "transformed world fixture creates a free port pair")
	# These literal viewport points include both the 1.02 canvas transform and the 1.12 world CanvasItem transform.
	test_viewport.push_input(_mouse_button_event(MOUSE_BUTTON_LEFT, true, Vector2(562.0608, 424.9728)), true)
	test_viewport.push_input(_mouse_motion_event(Vector2(695.6288, 424.9728), Vector2(133.568, 0), MOUSE_BUTTON_MASK_LEFT), true)
	test_viewport.push_input(_mouse_button_event(MOUSE_BUTTON_LEFT, false, Vector2(695.6288, 424.9728)), true)
	await get_tree().process_frame
	_expect(input_handler.call("get_mode_name") == "idle" and state.connections.size() == 2, "transformed release on a real world input port creates one connection")

	if EventBus.notice_requested.is_connected(notice_listener):
		EventBus.notice_requested.disconnect(notice_listener)
	test_viewport.queue_free()
	await get_tree().process_frame

func _test_real_production_loop() -> void:
	var state := GameState.new()
	var miner: Dictionary = state.try_place_building("miner", Vector2(100, 100))
	var smelter: Dictionary = state.try_place_building("smelter", Vector2(420, 100))
	var generator: Dictionary = state.try_place_building("power_generator", Vector2(740, 100))
	var connection: Dictionary = state.try_add_connection(miner.get("id", ""), smelter.get("id", ""))
	_expect(miner.get("ok", false) and smelter.get("ok", false) and generator.get("ok", false) and connection.get("ok", false), "real powered production loop can be constructed through atomic commands")
	if not miner.get("ok", false) or not smelter.get("ok", false) or not generator.get("ok", false) or not connection.get("ok", false):
		return

	var engine := SimulationEngine.new(state)
	for _tick in range(390):
		engine.update(1.0 / 60.0)
	var buffered_ore: float = state.get_building(smelter.id).get("input_buffer", {}).get("iron_ore", 0.0)
	_expect(buffered_ore >= 1.0, "belt update moves mined iron ore into the smelter")
	for _tick in range(70):
		engine.update(1.0 / 60.0)
	var produced_ingots: float = state.get_building(smelter.id).get("output_buffer", {}).get("iron_ingot", 0.0)
	_expect(produced_ingots >= 1.0, "production update consumes ore and produces an iron ingot")

func _test_explicit_building_costs() -> void:
	for building_type in ["miner", "smelter", "assembling_machine_mk1", "power_generator"]:
		var state := GameState.new()
		var result: Dictionary = state.try_place_building(building_type, Vector2(100, 100))
		_expect(result.ok and state.construction_inventory.get(building_type) == 0.0, "%s consumes exactly one matching construction item" % building_type)

	var unconfigured_state := GameState.new()
	var inventory_before := unconfigured_state.construction_inventory.duplicate(true)
	var unconfigured_result: Dictionary = unconfigured_state.try_place_building("solar_panel", Vector2(100, 100))
	_expect(not unconfigured_result.ok and unconfigured_state.construction_inventory == inventory_before and unconfigured_state.buildings.is_empty(), "buildings without configured construction items are rejected without state changes")

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

func _test_rectangle_overlap_contract() -> void:
	var partial_state := GameState.new()
	_expect(partial_state.try_place_building("miner", Vector2(100, 100)).ok, "overlap fixture places its first card")
	_expect(not partial_state.try_place_building("miner", Vector2(300, 180)).ok, "partial 232 by 144 card overlap is rejected")

	var containment_state := GameState.new()
	_expect(containment_state.try_place_building("miner", Vector2(100, 100)).ok, "containment fixture places its first card")
	_expect(not containment_state.try_place_building("miner", Vector2(120, 120)).ok, "contained card rectangle is rejected")

	var adjacent_state := GameState.new()
	adjacent_state.construction_inventory["miner"] = 2.0
	_expect(adjacent_state.try_place_building("miner", Vector2(100, 100)).ok, "adjacency fixture places its first card")
	_expect(adjacent_state.try_place_building("miner", Vector2(332, 100)).ok, "cards sharing an exact edge are legal")

	var zoom_independent_state := GameState.new()
	_expect(zoom_independent_state.try_place_building("miner", Vector2(100, 100)).ok, "zoom fixture places its first world-space card")
	var camera_zoom := Vector2(0.45, 0.45)
	var second_world_position := Vector2(300, 180)
	var displayed_position := second_world_position * camera_zoom
	_expect(displayed_position == Vector2(135, 81) and not zoom_independent_state.try_place_building("miner", second_world_position).ok, "overlap validation uses world positions independently of camera zoom")

func _test_connection_activity_contract() -> void:
	var state := GameState.new()
	GameManager.game_state = state
	var source: Dictionary = state.try_place_building("miner", Vector2(100, 100))
	var target: Dictionary = state.try_place_building("smelter", Vector2(420, 100))
	var normal_result: Dictionary = state.try_add_connection(source.id, target.id)
	var normal_connection: Dictionary = state.connections[normal_result.id]
	_expect(normal_result.ok and normal_connection.get("enabled", false) and not normal_connection.get("active", true), "new connections are enabled but idle before transfer")

	var disabled_id := state.add_connection({
		"source_id": source.id,
		"target_id": target.id,
		"item_id": "iron_ore",
		"enabled": false,
		"active": true,
	})
	var defaulted_id := state.add_connection({
		"source_id": source.id,
		"target_id": target.id,
		"item_id": "iron_ore",
	})
	var disabled_connection: Dictionary = state.connections[disabled_id]
	var defaulted_connection: Dictionary = state.connections[defaulted_id]
	_expect(not disabled_connection.get("enabled", true) and disabled_connection.get("active", false), "explicit connection permission and flow state are both preserved")
	_expect(defaulted_connection.get("enabled", false) and not defaulted_connection.get("active", true) and defaulted_connection.has("current_flow") and is_zero_approx(defaulted_connection.current_flow), "directly added connections default to enabled with an explicit idle flow")

	var connection_renderer := ConnectionRenderer.new()
	_expect(not connection_renderer.is_connection_active(normal_connection) and not connection_renderer.is_connection_active(defaulted_connection) and connection_renderer.is_connection_active(disabled_connection), "renderer follows current-frame activity instead of permission")
	connection_renderer.queue_free()

	var statistics := StatisticsSystem.new(state)
	_expect(is_equal_approx(statistics.get_logistics_efficiency(), 1.0 / 3.0), "statistics follows current-frame connection activity")

	var disabled_state := GameState.new()
	var disabled_source: Dictionary = disabled_state.try_place_building("miner", Vector2(100, 100))
	var disabled_target: Dictionary = disabled_state.try_place_building("smelter", Vector2(420, 100))
	var disabled_result: Dictionary = disabled_state.try_add_connection(disabled_source.id, disabled_target.id)
	var disabled_flow: Dictionary = disabled_state.connections[disabled_result.id]
	disabled_flow["enabled"] = false
	disabled_state.get_building(disabled_source.id)["output_buffer"] = {"iron_ore": 5.0}
	BeltSystem.new(disabled_state).update(1.0)
	_expect(is_equal_approx(disabled_state.get_building(disabled_source.id).output_buffer.iron_ore, 5.0) and disabled_state.get_building(disabled_target.id).input_buffer.is_empty() and not disabled_flow.get("active", true), "disabled connections transport no cargo and report no current flow")

	var idle_state := GameState.new()
	var idle_source: Dictionary = idle_state.try_place_building("miner", Vector2(100, 100))
	var idle_target: Dictionary = idle_state.try_place_building("smelter", Vector2(420, 100))
	var idle_result: Dictionary = idle_state.try_add_connection(idle_source.id, idle_target.id)
	var idle_flow: Dictionary = idle_state.connections[idle_result.id]
	BeltSystem.new(idle_state).update(1.0)
	_expect(idle_flow.get("enabled", false) and not idle_flow.get("active", true), "enabled connection remains idle when no cargo transfers")
	idle_state.get_building(idle_source.id)["output_buffer"] = {"iron_ore": 2.0}
	BeltSystem.new(idle_state).update(0.5)
	_expect(idle_flow.get("active", false) and idle_flow.get("current_flow", 0.0) > 0.0 and idle_state.get_building(idle_target.id).input_buffer.get("iron_ore", 0.0) > 0.0, "connection becomes active only in a frame that transfers cargo")
	var active_copy := idle_state.copy_state()
	_expect(active_copy.connections[idle_result.id].get("enabled", false) and active_copy.connections[idle_result.id].get("active", false) and active_copy.connections[idle_result.id].get("current_flow", 0.0) > 0.0, "state copy preserves an active connection frame")
	BeltSystem.new(idle_state).update(0.5)
	_expect(not idle_flow.get("active", true) and is_zero_approx(idle_flow.get("current_flow", -1.0)), "an enabled connection clears its previous activity when the next frame has no cargo")
	idle_state.get_building(idle_source.id)["output_buffer"] = {"iron_ore": 1.0}
	BeltSystem.new(idle_state).update(0.5)
	_expect(idle_flow.get("active", false), "pause fixture reactivates the connection before pausing")
	var paused_engine := SimulationEngine.new(idle_state)
	idle_state.paused = true
	paused_engine.update(0.5)
	_expect(not idle_flow.get("active", true) and is_zero_approx(idle_flow.get("current_flow", -1.0)), "pausing clears the previous frame's connection activity")
	var paused_copy := idle_state.copy_state()
	_expect(paused_copy.connections[idle_result.id].get("enabled", false) and not paused_copy.connections[idle_result.id].get("active", true) and is_zero_approx(paused_copy.connections[idle_result.id].get("current_flow", -1.0)), "state copy preserves cleared paused connection fields")

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
		_expect(not connection_renderer.call("is_connection_active", GameManager.get_game_state().connections.values()[0]), "new connections remain visually idle until cargo transfers")
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
	await get_tree().process_frame

	GameManager.game_state = GameState.new()
	GameManager.simulation_engine = SimulationEngine.new(GameManager.game_state)
	var gesture_handler: Node = input_script.new()
	add_child(gesture_handler)
	var gesture_ui_state := {"pointer_over_ui": false}
	gesture_handler.call("set_ui_hit_test", func(_position: Vector2) -> bool: return gesture_ui_state.pointer_over_ui)
	var gesture_notices: Array[Dictionary] = []
	var notice_listener: Callable = func(message: String, tone: String) -> void:
		gesture_notices.append({"message": message, "tone": tone})
	EventBus.notice_requested.connect(notice_listener)
	var gesture_source: Dictionary = GameManager.get_game_state().try_place_building("miner", Vector2(260, 100))
	var gesture_target: Dictionary = GameManager.get_game_state().try_place_building("smelter", Vector2(600, 100))
	gesture_handler.call("_unhandled_input", _mouse_button_event(MOUSE_BUTTON_LEFT, true, Vector2(492, 172)))
	gesture_handler.call("_unhandled_input", _mouse_motion_event(Vector2(540, 172), Vector2(48, 0), MOUSE_BUTTON_MASK_LEFT))
	gesture_handler.call("_unhandled_input", _mouse_button_event(MOUSE_BUTTON_LEFT, false, Vector2(600, 172)))
	_expect(GameManager.get_game_state().connections.size() == 1 and gesture_handler.call("get_mode_name") == "idle", "output press, pointer motion, and input release creates exactly one connection")
	gesture_handler.call("start_connection", gesture_source.id)
	gesture_handler.call("_unhandled_input", _mouse_motion_event(Vector2(760, 300), Vector2(40, 30), MOUSE_BUTTON_MASK_LEFT))
	gesture_handler.call("_unhandled_input", _mouse_button_event(MOUSE_BUTTON_LEFT, false, Vector2(760, 300)))
	_expect(gesture_handler.call("get_mode_name") == "idle" and gesture_notices[-1] == {"message": "连接已取消：请在输入端口释放", "tone": "error"}, "blank connection release cancels and publishes its failure result")
	gesture_handler.call("start_connection", gesture_source.id)
	gesture_ui_state.pointer_over_ui = true
	var supports_early_release := gesture_handler.has_method("_input")
	if supports_early_release:
		gesture_handler.call("_input", _mouse_button_event(MOUSE_BUTTON_LEFT, false, Vector2(1000, 300)))
	_expect(supports_early_release and gesture_handler.call("get_mode_name") == "idle" and gesture_notices[-1].message == "连接已取消：请在输入端口释放", "pending connection release is finalized before GUI can consume it")
	gesture_handler.call("start_connection", gesture_source.id)
	gesture_handler.call("_unhandled_input", _mouse_button_event(MOUSE_BUTTON_LEFT, false, Vector2(300, 80)))
	_expect(gesture_handler.call("get_mode_name") == "idle" and gesture_notices[-1].message == "连接已取消：请在输入端口释放", "UI connection release cancels and publishes its failure result")
	gesture_ui_state.pointer_over_ui = false
	gesture_handler.call("cancel_operation")

	var original_position: Vector2 = GameManager.get_game_state().get_building(gesture_source.id).position
	gesture_handler.call("_unhandled_input", _mouse_button_event(MOUSE_BUTTON_LEFT, true, original_position + Vector2(20, 20)))
	gesture_handler.call("_unhandled_input", _mouse_button_event(MOUSE_BUTTON_LEFT, false, original_position + Vector2(20, 20)))
	gesture_handler.call("_unhandled_input", _mouse_button_event(MOUSE_BUTTON_LEFT, true, Vector2(800, 320)))
	gesture_handler.call("_unhandled_input", _mouse_motion_event(Vector2(850, 360), Vector2(50, 40), MOUSE_BUTTON_MASK_LEFT))
	gesture_handler.call("_unhandled_input", _mouse_button_event(MOUSE_BUTTON_LEFT, false, Vector2(850, 360)))
	_expect(GameManager.get_game_state().get_building(gesture_source.id).position == original_position, "click-release followed by a blank drag cannot move the previously selected card")
	_expect(gesture_handler.get("dragging_building_id").is_empty(), "every release and blank press clears the current drag candidate")

	gesture_handler.call("_unhandled_input", _mouse_button_event(MOUSE_BUTTON_LEFT, true, original_position + Vector2(20, 20)))
	gesture_handler.call("_unhandled_input", _mouse_motion_event(original_position + Vector2(80, 70), Vector2(60, 50), MOUSE_BUTTON_MASK_LEFT))
	gesture_handler.call("_unhandled_input", _mouse_button_event(MOUSE_BUTTON_LEFT, false, original_position + Vector2(80, 70)))
	_expect(GameManager.get_game_state().get_building(gesture_source.id).position == original_position + Vector2(60, 50), "motion from the same card press still drags the card")
	if EventBus.notice_requested.is_connected(notice_listener):
		EventBus.notice_requested.disconnect(notice_listener)
	gesture_handler.queue_free()
	await get_tree().process_frame

func _mouse_button_event(button_index: MouseButton, pressed: bool, position: Vector2) -> InputEventMouseButton:
	var event := InputEventMouseButton.new()
	event.button_index = button_index
	event.pressed = pressed
	event.position = position
	event.global_position = position
	return event

func _controls_do_not_overlap(parent: Control, child_names: Array[String]) -> bool:
	var controls: Array[Control] = []
	for child_name in child_names:
		var control := parent.get_node_or_null(child_name) as Control
		if control == null or not control.visible:
			return false
		controls.append(control)
	for left_index in range(controls.size()):
		for right_index in range(left_index + 1, controls.size()):
			if controls[left_index].get_rect().intersects(controls[right_index].get_rect(), false):
				return false
	return true

func _mouse_motion_event(position: Vector2, relative: Vector2, button_mask: MouseButtonMask) -> InputEventMouseMotion:
	var event := InputEventMouseMotion.new()
	event.position = position
	event.relative = relative
	event.button_mask = button_mask
	event.global_position = position
	return event

func _expect(condition: bool, description: String) -> void:
	if condition:
		print("PASS: %s" % description)
		return

	_failures += 1
	printerr("FAIL: %s" % description)
