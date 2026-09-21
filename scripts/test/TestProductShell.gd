extends Node

var failures := 0
var root_path := "res://.godot/task17-tests-%d-%d" % [OS.get_process_id(), Time.get_ticks_usec()]

func _ready() -> void:
	DirAccess.make_dir_recursive_absolute(root_path)
	_test_preferences()
	await _test_product_ui()
	if failures == 0:
		print("PRODUCT SHELL TESTS PASSED")
		get_tree().quit(0)
	else:
		printerr("PRODUCT SHELL TESTS FAILED")
		get_tree().quit(1)

func _expect(ok: bool, message: String) -> void:
	if not ok:
		failures += 1
		printerr("PRODUCT: " + message)

func _test_preferences() -> void:
	var settings := SettingsSystem.new(root_path + "/preferences.cfg")
	_expect(settings.load_preferences() and settings.values == SettingsSystem.DEFAULTS, "missing device file uses defaults")
	var state := GameState.new()
	var before := JSON.stringify(GameStateCodec.to_persistent_dict(state))
	_expect(settings.update_preferences({"theme": "light", "font_scale": 2.0, "density": "comfortable", "invert_zoom": true}).ok, "valid device preferences persist")
	var copy := SettingsSystem.new(settings.path)
	_expect(copy.load_preferences() and copy.values == settings.values, "device preferences survive restart")
	_expect(JSON.stringify(GameStateCodec.to_persistent_dict(state)) == before, "device preferences never enter game state")
	for patch in [{"font_scale": 0.79}, {"font_scale": 2.01}, {"font_scale": NAN}, {"theme": "invalid"}, {"language": "en"}, {"cursor_speed": 99}]:
		_expect(not settings.update_preferences(patch).ok and settings.values == copy.values, "invalid preferences are rejected atomically")
	settings.path = root_path + "/missing/sub/settings.cfg"
	_expect(not settings.update_preferences({"theme": "dark"}).ok and settings.values == copy.values, "write failure keeps applied values")
	var file := FileAccess.open(root_path + "/broken.cfg", FileAccess.WRITE)
	file.store_string("[device]\nversion=1\nfont_scale=\"invalid\"\n")
	file.close()
	settings.path = root_path + "/broken.cfg"
	_expect(not settings.load_preferences() and settings.values == copy.values, "corrupt device settings preserve current values")
	settings.free()
	copy.free()

func _frames(count: int = 4) -> void:
	for i in range(count): await get_tree().process_frame

func _test_product_ui() -> void:
	var original_values := LocalSettings.values.duplicate()
	var original_path := LocalSettings.path
	var original_save := GameManager.get_save_system()
	var original_state := GameManager.get_game_state()
	LocalSettings.path = root_path + "/ui.cfg"
	LocalSettings.values = SettingsSystem.DEFAULTS.duplicate()
	GameManager.set_process(false)
	GameManager.end_session()
	GameManager.configure_save_system(SaveSystem.new(root_path + "/slots"))
	var viewport := SubViewport.new()
	viewport.size = Vector2i(1920, 1080)
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	add_child(viewport)
	var main: Node = load("res://scenes/main/Main.tscn").instantiate()
	viewport.add_child(main)
	await _frames()
	var shell: AppShell = main.get_node("AppShell")
	var workspace: FactoryWorkspaceUI = main.get_node("FactoryWorkspaceUI")
	var handler: Node = main.get_node("InputHandler")
	var settings: Control = shell.get_node("SettingsWorkspace")
	shell.get_node("StartMenu/Layout/Card/Content/Actions/SettingsButton").pressed.emit()
	_expect(settings.visible and shell.get_screen_name() == "settings" and not handler.is_processing_input(), "menu settings entry blocks canvas")
	settings.theme_choice.select(1)
	settings.font_scale.value = 2.0
	settings.apply_preferences()
	await _frames()
	_expect(settings.theme_choice.get_theme_font_size("font_size") == roundi(16 * DesktopLayout.metrics(Vector2(viewport.size), LocalSettings.values).font_scale), "200 percent font reaches actual controls")
	await _capture(viewport, "settings-large-font")
	_expect(LocalSettings.values.theme == "light" and LocalSettings.values.font_scale == 2.0, "formal settings controls apply preferences")
	LocalSettings.update_preferences({"theme": "dark", "font_scale": 1.0, "density": "compact"})
	shell.close_settings()
	_expect(shell.get_screen_name() == "start", "settings returns to original screen")
	_expect(GameManager.start_new_game(0).ok, "formal session starts")
	workspace.get_node("TopBar/SaveButton").pressed.emit()
	_expect(GameManager.get_save_status().phase == "saved", "top bar saves through the coordinator")
	shell.open_pause_menu()
	_expect(shell.get_screen_name() == "pause" and GameManager.game_state.paused and not handler.is_processing_input(), "pause menu pauses simulation and blocks canvas")
	var shortcut := InputEventKey.new()
	shortcut.keycode = KEY_S
	shortcut.ctrl_pressed = true
	shortcut.pressed = true
	shell._unhandled_input(shortcut)
	_expect(GameManager.get_save_status().phase == "saved", "Ctrl+S works in pause menu")
	await _capture(viewport, "task20-pause")
	shell.close_pause_menu()
	_expect(shell.get_screen_name() == "game", "pause menu returns to factory")
	GameManager.end_session()
	shell.open_recovery(0)
	_expect(shell.get_screen_name() == "recovery", "formal recovery entry is reachable")
	var recovery: Control = shell.get_node("RecoveryWorkspace")
	_expect(not recovery.find_child("Restore_primary", true, false).disabled, "valid primary can be selected")
	_expect(recovery.find_child("Restore_emergency", true, false).disabled, "missing emergency cannot be selected")
	await _frames()
	await _capture(viewport, "task20-recovery")
	recovery.dismissed.emit()
	_expect(shell.get_screen_name() == "slots", "recovery returns to slot list")
	_expect(GameManager.start_new_game(0).ok, "resume session after recovery UI checks")
	var preferences := LocalSettings.values.duplicate()
	_expect(GameManager.start_new_game(1).ok and LocalSettings.values == preferences, "switching slots preserves device preferences")
	var power_id := GameManager.game_state.add_building({"type": "solar_panel", "position": Vector2(2500, 2500)})
	handler.set_selected_entities([power_id])
	await _frames()
	var power_panel: Control = workspace.get_node("InspectorPanel/PowerConfiguration")
	_expect(power_panel.visible, "selected building exposes power configuration")
	power_panel.grid.item_selected.emit(1)
	_expect(GameManager.game_state.buildings[power_id].power_grid_id == "grid-b", "formal grid control updates the selected building")
	power_panel.use_priority.item_selected.emit(2)
	_expect(GameManager.game_state.buildings[power_id].power_priority == 3, "formal priority control updates authoritative state")
	power_panel.grid.grab_focus()
	await _frames()
	await _capture(viewport, "task21-power")
	workspace.show_exclusive_workspace("ProductionCatalogWorkspace")
	var catalog: Control = workspace.get_node("ProductionCatalogWorkspace")
	_expect(catalog.visible and catalog.target_ids.size() == 80, "formal production catalog exposes all frozen recipes")
	GameManager.game_state.planet_inventory["iron_ore"] = 10.0
	GameManager.game_state.sync_active_planet_inventory()
	catalog.target.select(catalog.target_ids.find("dsp_gear"))
	catalog.quantity.value = 3
	catalog._preview()
	_expect(catalog.preview.ok, "formal recursive preview resolves ore into gears")
	catalog.find_child("QueueCraft", true, false).pressed.emit()
	_expect(GameManager.game_state.production_orders.size() == 1, "formal confirmation reserves one manufacturing order")
	await _frames()
	await _capture(viewport, "task22-production-1920x1080")
	catalog.hide()
	workspace.open_command_palette()
	await _frames()
	var palette: CommandPalette = workspace.get_node("CommandPalette")
	_expect(palette.visible and palette.search.has_focus() and palette.entries.size() > 10, "command palette opens with keyboard search focus")
	_expect(workspace.is_pointer_over_ui(palette.global_position + Vector2(20, 20)), "command palette blocks canvas pointer input")
	palette.search.text = "自动布局"
	palette._filter()
	_expect(palette.filtered.size() == 1, "command palette filters desktop actions")
	await _capture(viewport, "task23-commands-1920x1080")
	workspace.show_exclusive_workspace("TechnologyPanel")
	_expect(not palette.visible, "workspace navigation closes command palette")
	workspace.get_node("TechnologyPanel").hide()
	await _test_blueprint_persistence_ui(viewport, workspace)
	handler.set_selected_entities([])
	var station_id := GameManager.get_game_state().add_building({"type": "planetary_logistics_station", "position": Vector2(3000, 3000), "station": StationSystem.empty_station()})
	await _frames()
	var resolution_state := JSON.stringify(GameStateCodec.to_persistent_dict(GameManager.get_game_state()))
	for viewport_size in [Vector2i(1152, 648), Vector2i(1000, 600), Vector2i(1920, 1080), Vector2i(2560, 1440), Vector2i(3840, 2160), Vector2i(2560, 1080)]:
		viewport.size = viewport_size
		for scale in [0.8, 1.0, 2.0]:
			LocalSettings.update_preferences({"font_scale": scale})
			await _frames(2)
			var layout := DesktopLayout.metrics(Vector2(viewport_size), LocalSettings.values)
			_expect(is_equal_approx(workspace.get_node("ResourceRail").size.x, layout.left_width), "resolution changes sidebar width")
			_expect(workspace.get_node("TopBar/PauseButton").get_theme_font_size("font_size") == roundi(16 * float(layout.font_scale)), "automatic scale composes with font preference")
			_expect(LocalSettings.values.font_scale == scale, "automatic resolution adaptation does not overwrite preference")
			for name in ["TopBar", "ResourceRail", "InspectorPanel", "ConstructionDock"]:
				var panel: Control = workspace.get_node(name)
				if not panel.visible: continue
				_expect(panel.size.x <= viewport_size.x + 1 and panel.size.y <= viewport_size.y + 1, "panel fits viewport: " + name)
				if panel.reflow: _expect(_no_overlap(panel), "reflowed controls do not overlap: " + name)
			_expect(workspace.get_node("MiniMap").visible, "font preferences preserve minimap access")
			if scale == 2.0: await _capture(viewport, "factory-%dx%d" % [viewport_size.x, viewport_size.y])
			for name in FactoryWorkspaceUI.WORKSPACES:
				workspace.show_exclusive_workspace(name)
				if name == "StationPanel": workspace.get_node(name).open_stations([station_id])
				await _frames(2)
				var panel: Control = workspace.get_node(name)
				_expect(panel.size.x <= viewport_size.x + 1 and panel.size.y <= viewport_size.y + 1, "workspace stays within viewport: " + name)
				_expect(workspace.close_active_workspace(), "workspace has return path: " + name)
	_expect(JSON.stringify(GameStateCodec.to_persistent_dict(GameManager.get_game_state())) == resolution_state, "resolution and font changes leave game state unchanged")
	LocalSettings.update_preferences({"theme": "dark", "font_scale": 1.0, "density": "compact"})
	viewport.size = Vector2i(1920, 1080)
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	await _frames()
	handler.focus_canvas()
	_expect(handler.canvas_focused and viewport.gui_get_focus_owner() == null, "canvas focus releases interface focus")
	var before_cursor: Vector2 = handler.cursor_screen
	var key := InputEventKey.new()
	key.pressed = true
	key.keycode = KEY_RIGHT
	handler._accessible_input(key)
	_expect(handler.cursor_screen.x > before_cursor.x, "keyboard moves virtual canvas cursor")
	var button := InputEventJoypadButton.new()
	button.pressed = true
	button.button_index = JOY_BUTTON_B
	handler._accessible_input(button)
	_expect(not handler.canvas_focused and viewport.gui_get_focus_owner() != null, "gamepad back restores interface focus")
	await _test_desktop_commands(main, handler)
	shell.open_settings()
	_expect(not handler.is_processing_input() and not handler.canvas_focused, "opening settings resets in-flight device input")
	shell.close_settings()
	GameManager.end_session()
	GameManager.configure_save_system(original_save)
	GameManager.replace_game_state(original_state)
	GameManager.set_process(true)
	viewport.queue_free()
	await _frames()
	LocalSettings.path = original_path
	LocalSettings.values = original_values
	LocalSettings.changed.emit()

func _no_overlap(panel: Control) -> bool:
	var rects: Array[Rect2] = []
	for child in panel.get_children():
		if not child is Control or child is ScrollBar or not child.visible: continue
		for rect in rects:
			if rect.intersects(child.get_rect(), false): return false
		rects.append(child.get_rect())
	return true

func _test_desktop_commands(main: Node, handler: Node) -> void:
	var workspace: FactoryWorkspaceUI = main.get_node("FactoryWorkspaceUI")
	var state := GameState.new()
	PlanetSystem.new(state).initialize_colonized_resource_sites()
	state.construction_inventory = {"smelter": 3.0}
	GameManager.replace_game_state(state)
	await _frames()
	handler.focus_canvas()
	handler.start_placing_card("smelter")
	var button := InputEventJoypadButton.new()
	button.pressed = true
	button.button_index = JOY_BUTTON_A
	handler._accessible_input(button)
	_expect(state.buildings.size() == 1 and state.construction_inventory.smelter == 2, "gamepad placement uses construction inventory exactly once")
	var id: String = state.buildings.keys()[0]
	var old_position: Vector2 = state.buildings[id].position
	handler.set_selected_entities([id])
	button.button_index = JOY_BUTTON_LEFT_STICK
	handler._accessible_input(button)
	var key := InputEventKey.new()
	key.pressed = true
	key.keycode = KEY_RIGHT
	handler._accessible_input(key)
	button.button_index = JOY_BUTTON_A
	handler._accessible_input(button)
	_expect(state.buildings[id].position != old_position and handler.current_mode == handler.Mode.IDLE, "desktop cursor moves and confirms actual building")
	var screen: Vector2 = handler.get_global_transform_with_canvas() * (Vector2(state.buildings[id].position) + Vector2(100, 70))
	old_position = state.buildings[id].position
	var mouse := InputEventMouseButton.new()
	mouse.button_index = MOUSE_BUTTON_LEFT
	mouse.pressed = true
	mouse.position = screen
	handler._unhandled_input(mouse)
	var motion := InputEventMouseMotion.new()
	motion.button_mask = MOUSE_BUTTON_MASK_LEFT
	motion.position = screen + Vector2(20, 20)
	handler._unhandled_input(motion)
	mouse.pressed = false
	mouse.position = motion.position
	handler._input(mouse)
	_expect(state.buildings[id].position != old_position, "existing mouse drag remains available")
	handler.set_selected_entities([id])
	handler.focus_canvas()
	button.button_index = JOY_BUTTON_X
	handler._accessible_input(button)
	var confirmation: ConfirmationDialog = workspace.get_node("DeleteConfirmation")
	_expect(confirmation.visible and state.buildings.has(id), "gamepad destructive command opens confirmation without deleting")
	button.button_index = JOY_BUTTON_Y
	_expect(not handler._accessible_input(button) and confirmation.visible, "canvas focus shortcut cannot bypass confirmation")
	confirmation.hide()
	_expect(state.buildings.has(id), "canceling confirmation preserves building")
	state.buildings[id].recipe_id = "iron_ingot_recipe"
	var target := state.add_building({"type": "assembling_machine_mk1", "position": Vector2(state.buildings[id].position) + Vector2(300, 0), "recipe_id": "gear_recipe"})
	button.button_index = JOY_BUTTON_RIGHT_STICK
	handler._accessible_input(button)
	handler.cursor_screen = handler.get_global_transform_with_canvas() * (Vector2(state.buildings[target].position) + Vector2(100, 70))
	button.button_index = JOY_BUTTON_A
	handler._accessible_input(button)
	_expect(state.connections.size() == 1, "gamepad connection invokes compatible belt command")

func _test_blueprint_persistence_ui(viewport: SubViewport, workspace: FactoryWorkspaceUI) -> void:
	workspace.show_exclusive_workspace("BlueprintWorkspace")
	var blueprint: BlueprintWorkspace = workspace.get_node("BlueprintWorkspace")
	var state := GameManager.game_state
	var definition := {"version": 1, "entities": [{"ref": "entity_0", "type": "smelter", "position": Vector2.ZERO, "configuration": {"recipe_id": "iron_ingot_recipe"}}], "connections": []}
	blueprint.accept_capture_result({"ok": true, "blueprint": definition})
	var controls: Control = blueprint.library_controls
	controls.title.text = "桌面冶炼蓝图"
	_click_named_action(controls, "保存为新蓝图")
	_expect(state.blueprint_library.size() == 1, "formal library save writes authoritative definition")
	blueprint.rotate_preview()
	_click_named_action(controls, "更新所选蓝图（含名称与变换）")
	_expect(state.blueprint_library.values()[0].rotation == 1, "formal update persists preview transform")
	var camera: Camera2D = viewport.get_camera_2d()
	camera.global_position = Vector2(7000, 0)
	state.construction_inventory.smelter = 0.0
	_click_named_action(controls, "排队部署到相机")
	_expect(state.construction_queue.size() == 1, "formal queue action creates a ghost order")
	state.construction_inventory.smelter = 1.0
	_click_named_action(controls, "资助所选订单")
	_expect(state.construction_queue.is_empty() and state.buildings.values().any(func(b): return b.position == Vector2(7000, 0)), "formal fund action places paid building")
	var navigation: Control = blueprint.get_node("Panel/NavigationControls")
	navigation.title.text = "主厂书签"
	_click_named_action(navigation, "保存当前镜头书签")
	camera.global_position = Vector2.ZERO
	_click_named_action(navigation, "定位标记（可跨行星）")
	_expect(camera.global_position == Vector2(7000, 0) and state.canvas_bookmarks.size() == 1, "formal bookmark restores camera")
	await _frames()
	controls.title.grab_focus()
	await _frames()
	await _capture(viewport, "task24-blueprint-library-1920x1080")
	blueprint.hide()

func _click_named_action(root: Node, text: String) -> void:
	for button in root.find_children("*", "Button", true, false):
		if button.text == text:
			button.pressed.emit()
			return
	_expect(false, "missing formal action " + text)

func _capture(viewport: SubViewport, label: String) -> void:
	if not OS.get_cmdline_user_args().has("--capture"): return
	await RenderingServer.frame_post_draw
	var image := viewport.get_texture().get_image()
	if image != null: image.save_png("res://.godot/task17-" + label + ".png")
