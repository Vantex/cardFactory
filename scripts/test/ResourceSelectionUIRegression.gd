extends RefCounted

var errors: Array[String] = []

func run(tree: SceneTree) -> Dictionary:
	errors.clear()
	await tree.process_frame
	var fixture := DSPOnlineParity.read_json(preload("res://scripts/test/ResourcePlacementRegression.gd").FIXTURE)
	var validation := preload("res://scripts/test/ResourcePlacementRegression.gd").validation_errors(fixture)
	if not validation.is_empty(): return {"errors": validation, "selections": 0, "rebindings": 0, "rejections": 0, "saves": 0, "root": ""}
	var exact := preload("res://scripts/test/CapacityQueryBehaviorRunner.gd")
	var owner := preload("res://scripts/test/EffectQueryBehaviorRunner.gd")
	var old_state: GameState = GameManager.get_game_state()
	var old_save: SaveSystem = GameManager._save_system
	var old_process := GameManager.is_processing()
	var save_root := "res://.godot/task27-resource-selection-ui-%d/" % OS.get_process_id()
	GameManager.set_process(false)
	GameManager.configure_save_system(SaveSystem.new(save_root + "session/"))
	var viewport := SubViewport.new()
	viewport.size = Vector2i(1920, 1080)
	tree.root.add_child(viewport)
	var main: Node = load("res://scenes/main/Main.tscn").instantiate()
	viewport.add_child(main)
	await tree.process_frame
	main.set_process(false)
	var workspace: FactoryWorkspaceUI = main.get_node("FactoryWorkspaceUI")
	var selections := 0
	var rebindings := 0
	var saves := 0
	var rejected := 0
	for row in fixture.cases:
		var state := GameState.new()
		SourceGalaxySystem.new(state).initialize(240721, false)
		state.completed_technologies = DataManager.all_technologies.keys().filter(func(id): return String(id).begins_with("dsp_"))
		state.explored_system_ids = SourceGalaxySystem.catalog().systems.keys()
		for explored in state.explored_system_ids: state.survey_progress_by_system[explored] = 1.0
		var planets := PlanetSystem.new(state)
		planets.ensure_colonized_planet_records(row.input.planet)
		state.set_active_planet(row.input.planet)
		planets.initialize_colonized_resource_sites()
		var type := "dsp_" + String(row.input.extractor)
		var allowed: Array = DataManager.get_building(type).extraction.items
		var target: Dictionary = {}
		var initial: Dictionary = {}
		for site in planets.get_planet_resource_sites(row.input.planet):
			if site.item_id == row.input.item: target = site
			elif initial.is_empty() and allowed.has(site.item_id): initial = site
		if target.is_empty():
			errors.append(row.id + ": actual seeded resource missing")
			continue
		if initial.is_empty(): initial = target
		state.construction_inventory[type] = 1
		var placed := state.try_place_building(type, initial.position)
		if not placed.ok:
			errors.append(row.id + ": paid legal initial placement failed")
			continue
		if not state.move_entity(placed.id, target.position):
			errors.append(row.id + ": actual move command failed")
			continue
		GameManager.replace_game_state(state)
		workspace.set_selected_building(placed.id)
		var button := _button(workspace, row.input.item)
		if button == null:
			errors.append(row.id + ": formal Inspector resource button absent or duplicated")
			continue
		button.pressed.emit()
		if state.buildings[placed.id].output_item != row.expected.resource or state.buildings[placed.id].resource_site_id != target.id or state.construction_inventory[type] != 0:
			errors.append(row.id + ": actual Inspector signal did not select the exact source resource without kit duplication")
			continue
		selections += 1
		if initial.item_id != target.item_id: rebindings += 1
		for other in allowed:
			if other == row.input.item or not planets.find_nearest_resource_site(row.input.planet, other, target.position).is_empty(): continue
			var unavailable := _button(workspace, other)
			if unavailable == null:
				errors.append(row.id + ": formal unavailable resource button missing")
				break
			var before := owner._ownership(state)
			unavailable.pressed.emit()
			if owner._ownership(state) != before: errors.append(row.id + ": rejected Inspector target mutates raw/canonical ownership")
			else: rejected += 1
			break
		var canonical := GameStateCodec.to_persistent_dict(state)
		var before := owner._ownership(state)
		var storage := SaveSystem.new(save_root + str(saves) + "/")
		var saved := storage.save_slot(0, state)
		if not saved.ok or owner._ownership(state) != before:
			errors.append(row.id + ": actual post-Inspector save failed or mutates owner: " + JSON.stringify(saved.get("error", {})))
			continue
		var loaded := storage.load_recovery_source(0, "primary")
		if not loaded.ok or not exact._exact(GameStateCodec.to_persistent_dict(loaded.state), canonical):
			errors.append(row.id + ": post-Inspector primary configuration/materials roundtrip failed")
			continue
		saves += 1
	main.queue_free()
	viewport.queue_free()
	await tree.process_frame
	GameManager.replace_game_state(old_state)
	GameManager.configure_save_system(old_save)
	GameManager.set_process(old_process)
	print("RESOURCE FORMAL SELECTION UI: ", selections, "; changed binding: ", rebindings, "; atomic rejected selection: ", rejected, "; actual saves: ", saves, "; errors: ", JSON.stringify(errors), "; root: ", save_root)
	return {"errors": errors.duplicate(), "selections": selections, "rebindings": rebindings, "rejections": rejected, "saves": saves, "root": save_root}

func _button(workspace: FactoryWorkspaceUI, item: String) -> Button:
	var name := String(DataManager.get_item(item).get("name", item))
	var matches: Array[Button] = []
	for child in workspace._recipe_list.get_children():
		if child is Button and child.text in [name, "✓ " + name]: matches.append(child)
	return matches[0] if matches.size() == 1 else null
