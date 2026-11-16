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
	shell.get_node("StartMenu/Layout/Card/Content/Actions/ContentPacksButton").pressed.emit()
	var packs: Control = shell.get_node("ContentPackWorkspace")
	_expect(packs.visible and shell.get_screen_name() == "packs" and not handler.is_processing_input(), "formal content-pack menu blocks canvas input")
	packs.find_child("ContentPackTemplate", true, false).pressed.emit()
	packs.find_child("ContentPackValidate", true, false).pressed.emit()
	_expect(packs.status.text == "内容校验通过", "formal content-pack template validates against source aliases")
	await _frames()
	await _capture(viewport, "task26-content-packs-1920x1080")
	shell.close_content_packs()
	_expect(shell.get_screen_name() == "start", "content-pack workspace returns to menu")
	_expect(GameManager.start_new_game(0).ok, "formal session starts")
	await _frames()
	_expect(workspace._construction_stock.text == "施工件 13" and workspace._resource_summary.text.contains("KITS  13"), "formal desktop shows all 13 source building kits")
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
	await _test_task25_workspaces(viewport, workspace)
	await _test_task27_planning(viewport, workspace)
	await _test_task26_workspaces(viewport, workspace)
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

func _test_task27_planning(viewport: SubViewport, workspace: FactoryWorkspaceUI) -> void:
	var state := GameManager.get_game_state()
	var plans_before := state.production_plans.duplicate(true)
	workspace.get_node("TopBar/AnalysisButton").pressed.emit()
	var analysis: Control = workspace.get_node("CodexWorkspace")
	analysis.get_node("Layout/Tabs/Planning").pressed.emit()
	await _frames()
	var panel: Control = analysis.get_node("Layout/Content/PlanningPanel")
	var create: Button = panel.get_node("Layout/Create")
	create.pressed.emit()
	await _frames()
	_expect(analysis.visible and panel.visible and state.production_plans.size() == plans_before.size() + 1, "formal analysis menu creates a production plan")
	_expect(workspace.is_pointer_over_ui(create.global_position + create.size * 0.5), "planning controls block canvas pointer input")
	_expect(create.size.x > 80 and create.size.y > 20 and Rect2(Vector2.ZERO, Vector2(viewport.size)).has_point(create.global_position + create.size * 0.5), "planning create button is visible and usable at 1080p")
	await _capture(viewport, "task27-planning-1920x1080")
	var original_size := viewport.size
	var original_scale: float = LocalSettings.values.font_scale
	viewport.size = Vector2i(1000, 600)
	LocalSettings.update_preferences({"font_scale": 2.0})
	await _frames()
	_expect(create.size.x > 80 and panel.size.x > 200, "planning layout remains usable with a small window and large font")
	await _capture(viewport, "task27-planning-1000x600-large-font")
	viewport.size = original_size
	LocalSettings.update_preferences({"font_scale": original_scale})
	state.production_plans = plans_before
	analysis.hide()
	await _frames()

func _test_task25_workspaces(viewport: SubViewport, workspace: FactoryWorkspaceUI) -> void:
	var state := GameManager.get_game_state()
	workspace.show_exclusive_workspace("TechnologyPanel")
	var panel: TechnologyPanel = workspace.get_node("TechnologyPanel")
	await _frames()
	_expect(panel.get_node("Layout/CatalogScroll/Catalog").get_child_count() > 50, "complete active technology tree appears in formal workspace")
	panel.navigate_to("dsp_mining_speed_1")
	await _frames()
	_expect(panel.get_node("Layout/CatalogScroll/Catalog").get_child_count() == 1, "technology search narrows to a stable source ID")
	state.completed_technologies.append("dsp_universe_matrix")
	panel.get_node("Layout/InfiniteToggle").pressed.emit()
	var infinite: Control = panel.get_node("Layout/InfiniteResearch")
	_expect(infinite.visible and infinite.find_child("Research_matrix_compression", true, false) != null, "infinite research controls open from technology workspace")
	infinite.find_child("Research_matrix_compression", true, false).pressed.emit()
	_expect(InfiniteResearchSystem.new(state).active() == "matrix_compression", "infinite research button selects authoritative target")
	await _frames()
	await _capture(viewport, "task25-technology-1920x1080")
	InfiniteResearchSystem.new(state).cancel()
	state.completed_technologies.erase("dsp_universe_matrix")
	workspace.show_exclusive_workspace("CampaignWorkspace")
	var campaign: CampaignWorkspace = workspace.get_node("CampaignWorkspace")
	await _frames()
	var tasks: OptionButton = campaign.get_node("Panel/SourceTasks")
	_expect(tasks.item_count == 32, "formal campaign lists all source tasks")
	var search: LineEdit = campaign.get_node("Panel/SourceSearch")
	search.text = "采集第一份矿石"
	search.text_changed.emit(search.text)
	await _frames()
	_expect(tasks.item_count == 1, "campaign search filters source task content")
	search.text = ""
	campaign._navigate_source({"kind": "technology", "techId": "mining_speed_1"})
	_expect(panel.visible and campaign.get_node("Panel/SourceSearch") != null, "campaign technology navigation opens the formal technology workspace")
	workspace.show_exclusive_workspace("CampaignWorkspace")
	await _frames()
	await _capture(viewport, "task25-campaign-1920x1080")
	campaign.hide()

func _test_task26_workspaces(viewport: SubViewport, workspace: FactoryWorkspaceUI) -> void:
	var state := GameManager.get_game_state()
	workspace.show_exclusive_workspace("GalaxyMap")
	var galaxy: GalaxyMap = workspace.get_node("GalaxyMap")
	await _frames()
	_expect(galaxy.galaxy_system.get_all_system_ids().size() == 8 and galaxy.get_node("Margin/Columns/DetailsPane").visible, "new-game formal galaxy exposes all source systems")
	_expect(galaxy.get_node("Margin").size.y > galaxy.size.y * 0.8 and galaxy.get_node("Margin/Columns/SystemPane/SystemScroll").size.y > 300 and galaxy.get_node("Margin/Columns/DetailsPane/DetailsScroll").size.y > 300, "formal galaxy uses full workspace height for readable lists and details")
	var controls: Control = galaxy.find_child("SourceWorldControls", true, false)
	_expect(controls != null and controls.visible, "formal galaxy exposes local industry and metadata controls")
	galaxy.find_child("PlanetLocalName", true, false).text = "产品母星"
	galaxy.find_child("PlanetLocalNote", true, false).text = "源星区工业基地"
	galaxy.find_child("SavePlanetMetadata", true, false).pressed.emit()
	_expect(state.source_galaxy.planetMetadata.get(galaxy.get_selected_planet_id(), {}).get("customName") == "产品母星", "formal metadata action commits the selected planet's local name")
	await _frames()
	var tray_limit: SpinBox = galaxy.find_child("PlanetTrayLimit", true, false)
	tray_limit.value = 2000000
	galaxy.find_child("SavePlanetTrayLimit", true, false).pressed.emit()
	_expect(PlanetTraySystem.new(state).limit(galaxy.get_selected_planet_id()) == 2000000, "formal star map adjusts saved per-item tray limit")
	await _capture(viewport, "task26-galaxy-1920x1080")
	galaxy.hide()
	state.completed_technologies.append_array(["dsp_interstellar_logistics", "dsp_quantum_logistics_network"])
	state.construction_inventory.dsp_interstellar_logistics_station = 1.0
	var placed := ConstructionSystem.new(state).try_place_building("dsp_interstellar_logistics_station", Vector2(8000, 8000))
	_expect(placed.ok, "product fixture places a real source logistics station")
	if placed.ok:
		workspace.show_exclusive_workspace("StationPanel")
		var panel: Control = workspace.get_node("StationPanel")
		panel.open_stations([placed.id])
		_expect(panel.slot_choice.item_count == 5, "formal station panel exposes its fifth source slot")
		_click_named_action(panel, "升级首站 Mk.II（需量子科技，无材料成本）")
		_click_named_action(panel, "挂接首站量子网络")
		_expect(state.buildings[placed.id].station.quantum_mode == "transitioning", "formal station controls upgrade and queue authoritative quantum attachment")
		await _frames()
		await _capture(viewport, "task26-station-1920x1080")
		panel.hide()
	state.progression_facts["produced"] = {"universe_matrix": 1.0}
	workspace.show_exclusive_workspace("LocalSpaceStationWorkspace")
	var orbital: Control = workspace.get_node("LocalSpaceStationWorkspace")
	await _frames()
	_click_named_action(orbital, "开始建设空间站核心")
	_expect(not state.orbital_station.is_empty(), "formal orbital station control starts the single save-owned station")
	var required: String = DataManager.get_building(OrbitalCargoTerminalSystem.TYPE).required_source_technology
	if not state.completed_technologies.has("dsp_" + required): state.completed_technologies.append("dsp_" + required)
	state.construction_inventory[OrbitalCargoTerminalSystem.TYPE] = 1.0
	var terminal := ConstructionSystem.new(state).try_place_building(OrbitalCargoTerminalSystem.TYPE, Vector2(8800, 8000))
	_expect(terminal.ok, "product fixture constructs an orbital cargo terminal")
	orbital.refresh()
	_click_named_action(orbital, "货运终端 → 当前建设阶段")
	if terminal.ok: _expect(state.buildings[terminal.id].orbital_cargo_binding.get("kind") == "construction", "formal terminal binding targets authoritative station construction")
	await _capture(viewport, "task26-orbital-1920x1080")
	var orbital_scroll: ScrollContainer = orbital.get_child(0)
	orbital_scroll.scroll_vertical = 100000
	await _frames()
	await _capture(viewport, "task26-cargo-1920x1080")
	for stage in LocalSpaceStationSystem.STAGES:
		for item in LocalSpaceStationSystem.COSTS[stage]: LocalSpaceStationSystem.new(state).deliver_from_buffer(item, int(LocalSpaceStationSystem.COSTS[stage][item]))
	var contract_service := StationContractSystem.new(state)
	var history_offer: Dictionary = contract_service.snapshot().board.offers[0]
	_expect(contract_service.accept(history_offer.id).ok, "product fixture accepts actual generated contract")
	var history_contract: Dictionary = state.station_contracts.accepted[0]
	for entry in history_contract.requirements: entry.delivered = entry.amount
	history_contract.status = "claimable"
	orbital.refresh()
	for index in range(orbital._contract_choice.item_count):
		if orbital._contract_choice.get_item_metadata(index) == history_offer.id: orbital._contract_choice.select(index)
	_click_named_action(orbital, "领取已完成合同奖励")
	_click_named_action(orbital, "展示选中已完成合同")
	_expect(state.station_contracts.get("featured_id") == history_offer.id, "formal history selection features a completed contract")
	_click_named_action(orbital, "取消精选合同展示")
	_expect(state.station_contracts.featured_id == "", "formal featured contract can be cleared")
	state.station_contracts.marks = "10000"
	state.station_contracts.reputation = "5000"
	var presentation: Control = orbital.find_child("StationPresentation", true, false)
	for index in range(presentation.decorations.item_count):
		if presentation.decorations.get_item_metadata(index) == "cargo_crate": presentation.decorations.select(index)
	presentation.x.value = -750
	presentation.y.value = 400
	_click_named_action(presentation, "购买所选装饰永久授权")
	_click_named_action(presentation, "摆放所选装饰")
	_expect(state.orbital_station.presentation.placements.size() == 1 and state.station_contracts.marks == "9970", "formal exhibit license and layout use actual marks and saved state")
	presentation.title_field.text = "产品轨道展厅"
	_click_named_action(presentation, "保存空间站名片")
	_expect(state.orbital_station.presentation.profile.title == "产品轨道展厅", "formal station profile saved")
	await _frames()
	orbital_scroll.scroll_vertical = maxi(0, int(presentation.position.y) - 12)
	await _frames()
	await _capture(viewport, "task26-station-exhibit-1920x1080")
	orbital_scroll.scroll_vertical = 0
	orbital.hide()
	state.completed_technologies.append("dsp_system_space_station_engineering")
	state.construction_inventory[SystemSpaceStationSystem.TYPE] = 1.0
	var platform := ConstructionSystem.new(state).try_place_building(SystemSpaceStationSystem.TYPE, Vector2(9500, 8000))
	_expect(platform.ok, "formal fixture constructs system station platform")
	workspace.show_exclusive_workspace("SystemSpaceStationWorkspace")
	var system_station: Control = workspace.get_node("SystemSpaceStationWorkspace")
	await _frames()
	_click_named_action(system_station, "开始建设并锁定研究折扣")
	_expect(state.system_space_stations.get("helios", {}).get("status") == "building", "formal system station button starts saved construction")
	await _capture(viewport, "task26-system-station-1920x1080")
	var hub: Dictionary = state.system_space_stations.helios
	for requirement in SystemSpaceStationSystem.requirements(int(hub.cost_multiplier_basis_points)):
		if DecimalCount.compare(requirement.required, hub.construction_buffer.get(requirement.item_id, "0")) > 0: hub.construction_buffer[requirement.item_id] = requirement.required
	SystemSpaceStationSystem.apply_buffer(hub)
	state.completed_technologies.append_array(["dsp_quantum_logistics_network", "dsp_orbital_multi_cargo_bus"])
	var elevator_id := state.add_building({"type": SystemHubLogisticsSystem.STATION_TYPE, "position": Vector2(10500, 8000), "station": StationSystem.empty_station(SystemHubLogisticsSystem.STATION_TYPE), "input_buffer": {}, "output_buffer": {}})
	system_station.refresh_systems()
	for index in range(system_station.elevator_station.item_count):
		if system_station.elevator_station.get_item_metadata(index) == elevator_id: system_station.elevator_station.select(index)
	_click_named_action(system_station, "升级所选站为 Mk.II")
	_click_named_action(system_station, "切换为太空电梯")
	SystemHubLogisticsSystem.new(state).update()
	_expect(SystemHubLogisticsSystem.is_elevator(state.buildings[elevator_id]), "formal elevator upgrade and switch commands")
	for index in range(system_station.output_item.item_count):
		if system_station.output_item.get_item_metadata(index) == "iron_ingot": system_station.output_item.select(index)
	system_station.policy_reserve.text = "100"
	system_station.policy_target.text = "200"
	system_station.policy_enabled.button_pressed = true
	_click_named_action(system_station, "保存跨系供需策略")
	_expect(hub.item_policies.get("iron_ingot", {}).get("target") == "200", "formal policy controls update authoritative hub")
	state.planet_inventory.space_warper = 3.0
	system_station.amount.value = 3
	_click_named_action(system_station, "按交付数量装入全局翘曲器")
	_expect(state.galactic_hub_network.warpers == "3" and state.planet_inventory.get("space_warper", 0) == 0, "formal global warper loading pays inventory")
	var hub_scroll: ScrollContainer = system_station.get_child(0)
	hub_scroll.scroll_vertical = 100000
	await _frames()
	await _capture(viewport, "task26-hub-policy-1920x1080")
	hub_scroll.scroll_vertical = 0
	system_station.hide()
	workspace.show_exclusive_workspace("GalacticExportWorkspace")
	await _frames()
	await _capture(viewport, "task26-exports-1920x1080")
	workspace.get_node("GalacticExportWorkspace").hide()
	state.completed_technologies.append_array(["dsp_dyson_swarm", "dsp_dyson_sphere_program", "dsp_dyson_shell"])
	workspace.show_exclusive_workspace("DysonPanel")
	var dyson: Control = workspace.get_node("DysonPanel")
	await _frames()
	_click_named_action(dyson, "创建太阳帆轨道")
	_click_named_action(dyson, "创建标准壳层")
	_expect(DysonSphereSystem.new(state).get_summary("helios").get("frames") == 8, "formal Dyson standard-layer action creates eight real frames")
	_click_named_action(dyson, "暂停全局发射计划")
	_expect(not state.dyson_engineering.get("enabled", true), "formal global launch pause changes the saved schedule")
	await _capture(viewport, "task26-dyson-1920x1080")
	dyson.hide()
	var completed := {}
	for tech in state.completed_technologies: completed[tech] = true
	state.completed_technologies = completed.keys()
	state.completed_technologies.append("dsp_time_warp_engineering")
	var warp_id := state.add_building({"type": "dsp_time_warp_device", "position": Vector2(11000, 8000), "input_buffer": {}, "output_buffer": {}})
	TimeWarpSystem.new(state).select_controller(warp_id)
	TimeWarpSystem.new(state).set_enabled(true)
	state.paused = false
	workspace.show_exclusive_workspace("EndgameWorkspace")
	var endgame: Control = workspace.get_node("EndgameWorkspace")
	endgame.find_child("PureIdleToggle", true, false).pressed.emit()
	_expect(state.pure_idle.get("enabled", false), "formal pure-idle toggle enters durable normal-mode settlement: " + endgame.status.text)
	workspace.show_exclusive_workspace("EndgameWorkspace")
	await _frames()
	endgame.get_child(0).ensure_control_visible(endgame.find_child("PureIdleToggle", true, false))
	await _frames()
	await _capture(viewport, "task26-pure-idle-1920x1080")
	endgame.find_child("PureIdleToggle", true, false).pressed.emit()
	_expect(not state.pure_idle.get("enabled", true), "formal pure-idle toggle stops and preserves unsettled time: " + endgame.status.text)
	endgame.hide()
