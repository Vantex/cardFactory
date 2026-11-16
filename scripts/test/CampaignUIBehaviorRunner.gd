extends RefCounted

const FIXTURE := "res://tests/fixtures/parity/behavior/task27-campaign-ui.json"
const REFERENCE := preload("res://scripts/test/ProgressionBehaviorRunner.gd")
const DOMAIN := preload("res://scripts/test/CampaignControlBehaviorRunner.gd")
const KEYS := ["commands:CampaignWorkspace.onClose", "commands:CampaignWorkspace.onNavigate", "commands:CampaignWorkspace.onSelectTask", "commands:GamePanels.onOpenCampaign", "workspaces:CampaignWorkspace"]
const MANAGER_FIELDS := ["game_state", "simulation_engine", "performance_monitor", "_save_system", "_current_slot", "_session_active", "_save_in_progress", "_autosave_interval", "_autosave_elapsed", "_offline_job", "_pure_wait", "_save_queue", "_inflight_digest", "_save_revision", "_save_status"]
var errors: Array[String] = []
var assertions: Array[String] = []

func run(fixture_override: Dictionary = {}, domain_fixture_override: Dictionary = {}) -> Dictionary:
	errors.clear()
	assertions.clear()
	var fixture := DSPOnlineParity.read_json(FIXTURE) if fixture_override.is_empty() else fixture_override
	var source := DSPOnlineParity.read_json(DSPOnlineParity.ROOT + "dsponline_source_catalog.json")
	if fixture.get("source_commit") != source.source.commit or not fixture.get("source_files") is Dictionary: return _reject("campaign UI provenance missing")
	for file in fixture.source_files:
		if fixture.source_files[file] != source.source.files.get(file): return _reject("campaign UI source drift")
	if not fixture.source_files.has("src/App.tsx") or not fixture.source_files.has("src/components/CampaignWorkspace.tsx"): return _reject("actual campaign callback source missing")
	var wanted := ["open", "technology", "planet_unlocked", "building_local", "building_remote", "select:mine_first_ore", "select:side_storage", "select:produce_universe_matrix", "select:unknown_campaign_task"]
	for task in source.catalog.campaign:
		if task.definition.has("navigation"): wanted.append("task:" + task.id)
	wanted.sort()
	if not fixture.get("cases") is Array: return _reject("campaign UI cases missing")
	var actual: Array = fixture.cases.map(func(row): return row.id)
	actual.sort()
	if wanted != actual: return _reject("campaign UI cases missing, duplicated or unknown")
	var domain_fixture := DSPOnlineParity.read_json(DOMAIN.FIXTURE) if domain_fixture_override.is_empty() else domain_fixture_override
	var domain: Dictionary = DOMAIN.new().run(domain_fixture)
	errors.append_array(domain.errors)
	assertions.append_array(domain.assertions)
	var tree: SceneTree = Engine.get_main_loop()
	await tree.process_frame
	if GameManager.is_save_in_progress(): return _reject("campaign UI cannot isolate an in-progress save")
	var original_manager := {}
	for field in MANAGER_FIELDS: original_manager[field] = GameManager.get(field)
	var original_processing := GameManager.is_processing()
	var original_settings := LocalSettings.values.duplicate(true)
	var original_path := LocalSettings.path
	var root := "res://.godot/task27-campaign-ui-%d" % Time.get_ticks_usec()
	DirAccess.make_dir_recursive_absolute(root)
	LocalSettings.path = root + "/settings.cfg"
	LocalSettings.values = SettingsSystem.DEFAULTS.duplicate(true)
	GameManager.set_process(false)
	GameManager.performance_monitor = PerformanceSystem.new()
	GameManager._save_queue = []
	GameManager.configure_save_system(SaveSystem.new(root + "/slots"))
	GameManager.replace_game_state(GameState.new())
	var viewport := SubViewport.new()
	viewport.size = Vector2i(1920, 1080)
	tree.root.add_child(viewport)
	var main: Node = load("res://scenes/main/Main.tscn").instantiate()
	viewport.add_child(main)
	await tree.process_frame
	_check(GameManager.start_new_game(0).ok, "formal campaign session starts in isolated save root")
	await tree.process_frame
	main.set_process(false)
	var shell: FactoryWorkspaceUI = main.get_node("FactoryWorkspaceUI")
	var handler: Node = main.get_node("InputHandler")
	var panel: Control = shell.get_node("CampaignWorkspace")
	panel._install_toggle()
	var tracking: Button = _button(panel, "跟踪所选任务")
	var route: Button = _button(panel, "前往目标")
	_check_nonempty_canvas_context(fixture, panel, shell, handler)
	for row in domain_fixture.cases:
		var state: GameState = REFERENCE.new()._state(row.input, "campaign-ui", row.id)
		GameManager.game_state = state
		panel.refresh_now()
		var index: int = panel._source_ids.find("dsp_" + String(row.targetId))
		if index < 0: continue
		panel._source_tasks.select(index)
		panel._refresh_source_detail()
		var tasks: Array = row.before.snapshot.chapters.reduce(func(rows, chapter): return rows + chapter.tasks, [])
		var source_task: Dictionary = tasks.filter(func(task): return task.id == row.targetId)[0]
		var disabled: bool = source_task.status in ["locked", "complete"]
		_check(tracking.disabled == disabled, row.id + ": formal task button matches actual source status")
		if not disabled:
			tracking.pressed.emit()
			var active: Variant = null if state.selected_source_objective.is_empty() else state.selected_source_objective.trim_prefix("dsp_")
			_check(active == row.expected.campaign.activeTaskId, row.id + ": formal tracking signal selects actual source task")
			_check(state.completed_objective_ids.size() == row.input.campaign.completedTaskIds.size(), row.id + ": tracking callback preserves task completion ownership")
	for row in fixture.cases:
		var state: GameState = REFERENCE.new()._state(row.input, "campaign-ui", row.id)
		GameManager.game_state = state
		handler.cancel_operation()
		handler.set_selected_entities([])
		handler.start_placing_card("dsp_arc_smelter")
		shell.show_exclusive_workspace("")
		panel.refresh_now()
		panel._toggle_button.pressed.emit()
		_check(panel.visible, row.id + ": formal open button shows campaign workspace")
		_check(handler.get_mode_name() != "placing" and handler.get_selected_entity_ids().is_empty(), row.id + ": actual source open clears canvas placement and selection")
		if row.action == "navigateFromCampaign":
			var navigation: Dictionary = row.args[0]
			if row.args.size() > 1:
				var index: int = panel._source_ids.find("dsp_" + String(row.args[1]))
				_check(index >= 0, row.id + ": formal route target exists")
				if index < 0: continue
				panel._source_tasks.select(index)
				panel._refresh_source_detail()
				route.pressed.emit()
			else: panel._navigate_source(navigation)
			_check(not panel.visible, row.id + ": navigation closes campaign")
			_check(state.active_planet_id == row.expected.activePlanetId, row.id + ": actual source route planet")
			var effects: Dictionary = row.expected.effects
			var calls: Array = row.expected.calls
			if effects.get("setRecipesOpen", false):
				var catalog: Control = shell.get_node("ProductionCatalogWorkspace")
				_check(catalog.visible and catalog.get("focus_item_id") == navigation.itemId, row.id + ": actual source recipe workspace and exact item focus")
				_check(catalog.details.text.contains(String(DataManager.get_item(navigation.itemId).get("name", navigation.itemId))), row.id + ": formal recipe details show the actual source target")
				if navigation.itemId == "iron_ore":
					var before := GameStateCodec.to_persistent_dict(state)
					_button(catalog, "确认预留并制造").pressed.emit()
					_check(catalog.target.selected < 0 and GameStateCodec.to_persistent_dict(state) == before, row.id + ": raw resource focus never manufactures an unrelated recipe")
			elif effects.get("setTechnologyOpen", false):
				_check(shell.get_node("TechnologyPanel").visible and shell.get_node("TechnologyPanel/Layout/Search").text == "dsp_" + navigation.techId, row.id + ": actual source technology focus")
			elif effects.get("setStarMapOpen", false):
				_check(shell.get_node("GalaxyMap").visible, row.id + ": actual source star map workspace")
			elif calls.any(func(call): return call[0] == "commandWorkspace"):
				var command: Array = calls.filter(func(call): return call[0] == "commandWorkspace")[0]
				var target: String = "DysonPanel" if command[1] == "dyson" else "GalacticExportWorkspace"
				_check(shell.get_node(target).visible, row.id + ": actual source command workspace " + target)
			elif effects.get("setPlacement") != null:
				_check(handler.get_mode_name() == "placing" and handler.placing_building_type == "dsp_" + effects.setPlacement, row.id + ": actual source missing-building placement")
			elif calls.any(func(call): return call[0] == "focusEntities"):
				var entity_id: String = row.expected.effects.setSelectedEntityIds[0]
				var source_entity: Dictionary = row.input.entities.filter(func(entity): return entity.id == entity_id)[0]
				var selected: Array = handler.get_selected_entity_ids()
				_check(selected.size() == 1 and state.buildings[selected[0]].type == "dsp_" + source_entity.buildingId, row.id + ": actual source existing-building focus")
			elif navigation.kind == "construction":
				var catalog: Control = shell.get_node("ProductionCatalogWorkspace")
				var focused := String(catalog.target_ids[catalog.target.selected]) if catalog.target.selected >= 0 else ""
				_check(catalog.visible and catalog.category.selected == 1 and focused.trim_prefix("dsp_") == navigation.constructionId, row.id + ": actual source construction tray target")
		elif row.action == "onSelectCampaignTask":
			var index: int = panel._source_ids.find("dsp_" + String(row.args[0]))
			if index >= 0:
				panel._source_tasks.select(index)
				panel._refresh_source_detail()
				if not tracking.disabled: tracking.pressed.emit()
				var active: Variant = null if state.selected_source_objective.is_empty() else state.selected_source_objective.trim_prefix("dsp_")
				_check(active == row.expected.campaign.activeTaskId, row.id + ": actual source selection callback")
		panel.get_node("Panel/Close").pressed.emit()
		_check(not panel.visible, row.id + ": formal close button hides campaign")
	GameManager.end_session()
	viewport.queue_free()
	await tree.process_frame
	for field in MANAGER_FIELDS: GameManager.set(field, original_manager[field])
	GameManager.set_process(original_processing)
	LocalSettings.values = original_settings
	LocalSettings.path = original_path
	for field in MANAGER_FIELDS: _check(GameManager.get(field) == original_manager[field], "campaign UI restores original manager field " + field)
	_check(GameManager.simulation_engine.game_state == GameManager.game_state and GameManager.performance_monitor.game_state == GameManager.game_state, "campaign UI restores coherent original engine and monitor ownership")
	var proofs := {}
	var claims := {}
	var keys := []
	for key in KEYS:
		claims[key] = {"assertions": assertions.duplicate(), "failures": errors.duplicate()}
		if errors.is_empty():
			keys.append(key)
			proofs[key] = {"suite": "task27-campaign-controls", "fixture": FIXTURE, "fixture_sha256": FileAccess.get_sha256(FIXTURE), "assertions": assertions.duplicate()}
	return {"errors": errors.duplicate(), "assertions": assertions.duplicate(), "verified_keys": keys, "proofs": proofs, "claims": claims}

func _check_nonempty_canvas_context(fixture: Dictionary, panel: Control, shell: FactoryWorkspaceUI, handler: Node) -> void:
	var row: Dictionary = fixture.cases.filter(func(value): return value.id == "building_local")[0]
	var state: GameState = REFERENCE.new()._state(row.input, "campaign-ui", "canvas-context")
	GameManager.game_state = state
	var entity_ids: Array = state.buildings.keys().filter(func(id): return state.buildings[id].planet_id == state.active_planet_id)
	_check(not entity_ids.is_empty(), "canvas context has an actual source local building")
	if entity_ids.is_empty(): return
	var selected := [entity_ids[0]]
	handler.cancel_operation()
	shell.show_exclusive_workspace("")
	_check(handler.set_selected_entities(selected) and handler.get_selected_entity_ids() == selected, "formal open has a nonempty actual building selection")
	_check(handler.start_connection(selected[0]) and handler.get_mode_name() == "connecting", "formal open has an active canvas connection")
	panel._toggle_button.pressed.emit()
	_check(panel.visible and handler.get_selected_entity_ids().is_empty() and shell._selected_entity_ids.is_empty() and handler.get_mode_name() == "idle", "formal open clears nonempty selection and active canvas connection")
	_check(handler.set_selected_entities(selected) and handler.get_selected_entity_ids() == selected, "formal navigation gets its own nonempty actual building selection after open")
	_check(handler.start_connection(selected[0]) and handler.get_mode_name() == "connecting", "formal navigation gets its own active canvas connection after open")
	var index: int = panel._source_ids.find("dsp_smelt_iron")
	_check(index >= 0, "formal recipe route exists for canvas reset")
	if index < 0: return
	panel._source_tasks.select(index)
	panel._refresh_source_detail()
	_button(panel, "前往目标").pressed.emit()
	_check(not panel.visible and handler.get_selected_entity_ids().is_empty() and shell._selected_entity_ids.is_empty() and handler.get_mode_name() == "idle", "formal navigation independently clears nonempty selection and active canvas connection")

func _check(ok: bool, message: String) -> void:
	assertions.append(message)
	if not ok: errors.append(message)

static func _button(node: Node, text: String) -> Button:
	for child in node.get_children():
		if child is Button and child.text == text: return child
		var found := _button(child, text)
		if found != null: return found
	return null

static func _reject(message: String) -> Dictionary:
	return {"errors": [message], "assertions": [], "verified_keys": [], "proofs": {}, "claims": {}}
