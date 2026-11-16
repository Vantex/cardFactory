extends Node

const OUTPUT := preload("res://scripts/game/SourceResourceOutputSystem.gd")
const OWNER := preload("res://scripts/test/EffectQueryBehaviorRunner.gd")
const EXACT := preload("res://scripts/test/CapacityQueryBehaviorRunner.gd")
var errors := []
var mined := 0
var fluids := 0
var saves := 0

func _ready() -> void:
	call_deferred("_run")

func _check(ok: bool, message: String) -> void:
	if not ok: errors.append(message)

func _run() -> void:
	var fixture := "res://tests/fixtures/parity/behavior/task27-resource-manual.json"
	if FileAccess.get_sha256(fixture) != "11afe4304f7e0737df415d51470df56dfa41eb706b0ce6d874d0168b5cfcff9d":
		get_tree().quit(1)
		return
	GameManager.set_process(false)
	var root := "res://.godot/task27-manual-ui-%d/" % OS.get_process_id()
	GameManager.configure_save_system(SaveSystem.new(root + "session/"))
	var viewport := SubViewport.new()
	viewport.size = Vector2i(1920, 1080)
	get_tree().root.add_child(viewport)
	var main: Node = load("res://scenes/main/Main.tscn").instantiate()
	viewport.add_child(main)
	await get_tree().process_frame
	main.set_process(false)
	_check(GameManager.start_new_game(0).ok, "actual active gameplay session")
	var shell = main.get_node("FactoryWorkspaceUI")
	var panel = shell.get_node("ResourceWorkspace")
	var open_button: Button = shell.get_node("ResourceRail/OpenResources")
	var gold: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://tests/fixtures/parity/behavior/task27-resource-manual.json"))
	for row in gold.cases:
		if not String(row.id).begins_with("default-"): continue
		var state := GameState.new()
		SourceGalaxySystem.new(state).initialize(240721, false)
		state.explored_system_ids = SourceGalaxySystem.catalog().systems.keys()
		for explored in state.explored_system_ids: state.survey_progress_by_system[explored] = 1.0
		var planets := PlanetSystem.new(state)
		planets.ensure_colonized_planet_records(row.input.planet)
		state.set_active_planet(row.input.planet)
		planets.initialize_colonized_resource_sites()
		GameManager.replace_game_state(state)
		open_button.pressed.emit()
		var site: Dictionary = {}
		for id in panel.site_ids:
			if state.resource_sites[id].item_id == row.input.item:
				site = state.resource_sites[id]
				panel.target.select(panel.site_ids.find(id))
				panel.target.item_selected.emit(panel.target.selected)
				break
		_check(not site.is_empty() and panel.visible, row.id + ": actual active-planet resource selection")
		if site.is_empty(): continue
		var before := OWNER._ownership(state)
		var fluid: bool = DataManager.get_item(row.input.item).get("kind") == "fluid"
		_check(panel.mine_button.disabled == fluid, row.id + ": formal fluid guard")
		panel.mine_button.button_down.emit()
		if fluid:
			_check(OWNER._ownership(state) == before, row.id + ": disabled fluid signal preserves entire owner")
			fluids += 1
			continue
		_check(OUTPUT.raw_amount(state, site) == 1 and state.planet_inventory == before.raw.fields.planet_inventory, row.id + ": formal button mines into output, not tray")
		_check(panel.details.text.contains("输出 1.000"), row.id + ": real panel displays owned cache")
		await get_tree().create_timer(0.36).timeout
		_check(OUTPUT.raw_amount(state, site) == 2, row.id + ": actual 320ms hold timer")
		panel.mine_button.button_up.emit()
		before = OWNER._ownership(state)
		await get_tree().create_timer(0.34).timeout
		_check(OWNER._ownership(state) == before and panel._hold_timer.is_stopped(), row.id + ": release stops timer without stock changes")
		var tray_before := float(state.planet_inventory.get(row.input.item, 0))
		panel.collect_button.pressed.emit()
		_check(OUTPUT.raw_amount(state, site) == 0 and float(state.planet_inventory.get(row.input.item, 0)) == tray_before + 2, row.id + ": formal collection moves exact cache to active tray")
		_check(panel.details.text.contains("输出 0.000"), row.id + ": panel refresh after collection")
		var storage := SaveSystem.new(root + row.input.item + "/")
		var canonical: Dictionary = JSON.parse_string(JSON.stringify(GameStateCodec.to_persistent_dict(state), "", true, true))
		var saved := storage.save_slot(0, state)
		var loaded := storage.load_recovery_source(0, "primary") if saved.ok else {}
		_check(saved.ok and loaded.get("ok", false) and EXACT._exact(GameStateCodec.to_persistent_dict(loaded.state), canonical), row.id + ": actual formal-action primary full roundtrip")
		if loaded.get("ok", false): saves += 1
		mined += 1
		if row.input.item == "iron_ore":
			state.planet_tray_limits[state.active_planet_id] = 1000
			state.planet_inventory.iron_ore = 999.0
			site.output_buffer.iron_ore = 179.0
			panel.refresh_now()
			panel.collect_button.pressed.emit()
			_check(site.output_buffer.iron_ore == 178 and state.planet_inventory.iron_ore == 1000, "formal partial tray capacity retains remainder")
			state.construction_inventory.dsp_mining_machine = 3
			panel.install_count.value = 3
			panel.install_button.pressed.emit()
			_check(OUTPUT.miner_count(state, site) == 3 and state.construction_inventory.dsp_mining_machine == 0 and site.output_buffer.iron_ore == 178 and state.planet_inventory.iron_ore == 1000, "formal paid three-unit installation preserves real cache and tray")
			_check(panel.details.text.contains("自动设备 3"), "formal panel refreshes installed group count")
			site.interaction_locked = true
			panel.refresh_now()
			before = OWNER._ownership(state)
			panel.install_button.pressed.emit()
			_check(panel.install_button.disabled and OWNER._ownership(state) == before, "locked resource rejects formal installation without changes")
			site.interaction_locked = false
			panel.refresh_now()
			before = OWNER._ownership(state)
			panel.collect_button.pressed.emit()
			_check(OWNER._ownership(state) == before, "formal full tray rejection is atomic")
			GameManager._save_in_progress = true
			panel.mine_button.button_down.emit()
			GameManager._save_in_progress = false
			_check(OWNER._ownership(state) == before, "busy save rejects formal mining")
			panel.refresh_now()
			panel.mine_button.button_down.emit()
			panel.hide()
			before = OWNER._ownership(state)
			await get_tree().create_timer(0.34).timeout
			_check(OWNER._ownership(state) == before and panel._hold_timer.is_stopped(), "closing panel cancels hold")
			open_button.pressed.emit()
			panel.mine_button.button_down.emit()
			panel.notification(NOTIFICATION_WM_WINDOW_FOCUS_OUT)
			before = OWNER._ownership(state)
			await get_tree().create_timer(0.34).timeout
			_check(OWNER._ownership(state) == before and panel._hold_timer.is_stopped(), "window focus loss cancels hold")
			var replacement := state.copy_state()
			panel.mine_button.button_down.emit()
			var old := OWNER._ownership(state)
			GameManager.replace_game_state(replacement)
			before = OWNER._ownership(replacement)
			panel._hold_timer.timeout.emit()
			_check(OWNER._ownership(replacement) == before and OWNER._ownership(state) == old, "session replacement cancels stale hold")
	main.queue_free()
	viewport.queue_free()
	await get_tree().process_frame
	GameManager.end_session()
	print("PARITY RESOURCE OUTPUT UI TESTS: solid=", mined, "; fluids=", fluids, "; primary=", saves, "; root=", root, "; errors=", errors)
	var passed := mined == 13 and fluids == 3 and saves == 13 and errors.is_empty()
	if passed: print("PARITY RESOURCE OUTPUT UI TESTS PASSED")
	get_tree().quit(0 if passed else 1)
