extends Node

const FIXTURE := "res://tests/fixtures/parity/behavior/task27-planning.json"
const SYSTEM := "res://scripts/game/ProductionPlanningSystem.gd"
var _failures := 0

func _ready() -> void:
	print("PRODUCTION PLANNING TESTS STARTED")
	if not FileAccess.file_exists(SYSTEM):
		_expect(false, "source production planning has a runnable implementation")
	else:
		var script := load(SYSTEM)
		var fixture := DSPOnlineParity.read_json(FIXTURE)
		var source := DSPOnlineParity.read_json(DSPOnlineParity.ROOT + "dsponline_source_catalog.json")
		_expect(fixture.source_commit == source.source.commit, "planning frozen revision")
		for file in fixture.source_files: _expect(fixture.source_files[file] == source.source.files.get(file), "planning source hash: " + String(file))
		for row in fixture.cases:
			var state := _state_from_input(row.input)
			var system: RefCounted = script.new(state)
			var before := GameStateCodec.to_persistent_dict(state)
			var options: Array = system.get_recipe_options(row.plan.itemId)
			_expect(options == row.options, row.id + ": unlocked ordered recipe options")
			var result: Dictionary = system.calculate(row.plan)
			_expect(_same(result, row.result), row.id + ": complete frozen calculation; " + _difference(result, row.result))
			_expect(GameStateCodec.to_persistent_dict(state) == before, row.id + ": query does not mutate ownership")
		var commands := GameState.new()
		commands._next_id = int(fixture.command_initial_id)
		var service: RefCounted = script.new(commands)
		for row in fixture.commands:
			var result: Dictionary
			match row.operation:
				"create": result = service.create_plan(row.args[0], float(row.args[1]), row.args[2])
				"update": result = service.update_plan(row.args[0], row.args[1])
				"recipe": result = service.set_recipe(row.args[0], row.args[1], row.args[2])
				"remove": result = service.remove_plan(row.args[0])
			_expect(result.get("ok", false) == row.changed and _same(commands.get("production_plans"), row.plans) and commands._next_id == int(row.next_id), "frozen plan command: " + row.operation)
		_test_persistence_and_rejections(script)
		_test_live_factory(script)
		await _test_content_pack_planning()
		await _test_formal_controls()
	if _failures > 0:
		printerr("PRODUCTION PLANNING TESTS FAILED")
		get_tree().quit(1)
	else:
		print("PRODUCTION PLANNING TESTS PASSED")
		get_tree().quit(0)

func _state_from_input(input: Dictionary) -> GameState:
	return PlanningBehaviorRunner.make_state(input)

func _test_content_pack_planning() -> void:
	var fixture := DSPOnlineParity.read_json("res://tests/fixtures/parity/behavior/task27-planning-packs.json")
	var source := DSPOnlineParity.read_json(DSPOnlineParity.ROOT + "dsponline_source_catalog.json")
	_expect(fixture.source_commit == source.source.commit and fixture.cases.size() == 4, "four frozen content-pack planning cases including prefix-distinct IDs")
	for file in fixture.source_files: _expect(fixture.source_files[file] == source.source.files.get(file), "planning pack source hash: " + String(file))
	var saved_catalog := ContentPackSystem.snapshot_catalog()
	var saved_service := DataManager.content_pack_system
	var panel := ProductionPlanningPanel.new()
	add_child(panel)
	await get_tree().process_frame
	var packs := ContentPackSystem.new("res://.godot/task27-planning-packs-%d/registry.json" % Time.get_ticks_usec())
	DataManager.content_pack_system = packs
	var installed := packs.register_pack(fixture.manifest)
	_expect(installed.ok, "install actual planning content pack: " + str(installed))
	if installed.ok:
		_expect(ProductionPlanningSystem.get_supported_items().has("planning_product"), "plan picker includes active custom item")
		panel.refresh_now()
		var picker := panel.get_node("Layout/Item") as OptionButton
		var listed := false
		for index in range(picker.item_count): listed = listed or picker.get_item_metadata(index) == "planning_product"
		_expect(listed, "existing formal picker refreshes after content pack activation")
		var original_state := GameManager.game_state
		var presentation_state: GameState
		for row in fixture.cases:
			var state := GameState.new()
			SourceGalaxySystem.new(state).initialize(240721)
			PlanetSystem.new(state).initialize_colonized_resource_sites()
			state.planet_inventories = row.input.planet_inventories.duplicate(true)
			state.planet_inventory = state.planet_inventories.home
			state.sync_active_planet_inventory()
			state.content_packs = packs.references()
			for id in row.input.completed_technologies: state.completed_technologies.append(id if DataManager.get_technology(id).has("source_content_pack") else "dsp_" + id)
			for entity in row.input.machines:
				state.add_building({"id": entity.id, "type": entity.buildingId, "planet_id": entity.planetId, "position": Vector2(entity.position.x, entity.position.y), "recipe_id": entity.recipeId, "input_buffer": entity.inputs.duplicate(), "output_buffer": entity.outputs.duplicate(), "production_utilization": entity.utilization})
			state._next_id = int(row.input.next_id)
			var planner := ProductionPlanningSystem.new(state)
			var created := planner.create_plan(row.plan.itemId, row.plan.targetPerMinute, row.plan.planetId)
			_expect(created.ok and _same(state.production_plans, [row.plan]), row.id + ": create custom target with source identity")
			_expect(_same(planner.get_recipe_options(row.plan.itemId), row.options), row.id + ": custom recipe technology gate")
			var before := GameStateCodec.to_persistent_dict(state)
			var actual := planner.calculate(row.plan)
			_expect(_same(actual, row.result), row.id + ": frozen custom requirements; " + _difference(actual, row.result))
			_expect(GameStateCodec.to_persistent_dict(state) == before, row.id + ": custom calculation is read only")
			if created.ok:
				var selected := planner.set_recipe(created.id, "planning_product", "planning_recipe")
				_expect(selected.ok == (row.id in ["unlocked", "half-utilized"]), row.id + ": explicit custom recipe selection")
				var payload := GameStateCodec.to_persistent_dict(state)
				_expect(GameStateCodec.from_persistent_dict(payload) != null, row.id + ": custom plan survives validated codec")
				_expect(not packs.set_enabled(fixture.manifest.id, false, [payload]).ok and not packs.remove_pack(fixture.manifest.id, [payload]).ok, row.id + ": saved plan protects content pack")
				var saves := SaveSystem.new("res://.godot/task27-planning-pack-saves-%d/" % Time.get_ticks_usec())
				var saved := saves.save_slot(0, state)
				var loaded := saves.load_slot(0) if saved.ok else {}
				_expect(saved.ok and loaded.get("ok", false) and loaded.state.production_plans == state.production_plans, row.id + ": custom plan verified disk round trip")
			if row.id == "half-utilized": presentation_state = state
		GameManager.game_state = presentation_state
		panel.refresh_now()
		var custom_row := panel.get_node_or_null("Layout/Plans/Plan_0")
		_expect(custom_row != null and _row_text(custom_row).contains("计划机器"), "formal custom requirement renders its runtime building name")
		for index in range(picker.item_count):
			if picker.get_item_metadata(index) == "planning_product": picker.select(index)
		panel.get_node("Layout/Create").pressed.emit()
		_expect(presentation_state.production_plans.size() == 2 and presentation_state.production_plans[1].itemId == "planning_product", "formal create button accepts custom target")
		for index in range(picker.item_count):
			if picker.get_item_metadata(index) == "planning_long_name": picker.select(index)
		panel.get_node("Layout/Create").pressed.emit()
		var long_plan: Dictionary = presentation_state.production_plans.back()
		_expect(long_plan.itemId == "planning_long_name" and long_plan.name == fixture.nameNormalization.persisted.name, "formal creation normalizes long item name to frozen load limit")
		var long_saves := SaveSystem.new("res://.godot/task27-planning-long-name-%d/" % Time.get_ticks_usec())
		var long_saved := long_saves.save_slot(0, presentation_state)
		var long_loaded := long_saves.load_slot(0) if long_saved.ok else {}
		_expect(long_saved.ok and long_loaded.get("ok", false) and long_loaded.state.production_plans == presentation_state.production_plans, "legal long item name preserves verified disk saving and every plan")
		GameManager.game_state = original_state
		_expect(packs.set_enabled(fixture.manifest.id, false, []).ok and not ProductionPlanningSystem.get_supported_items().has("planning_product"), "disabled pack disappears from plan picker")
		_expect(packs.set_enabled(fixture.manifest.id, true, []).ok and ProductionPlanningSystem.get_supported_items().has("planning_product"), "reenabled pack restores plan picker")
	panel.queue_free()
	await get_tree().process_frame
	ContentPackSystem.install_catalog(saved_catalog)
	DataManager.content_pack_system = saved_service

func _test_persistence_and_rejections(script: Script) -> void:
	var state := GameState.new()
	var system: RefCounted = script.new(state)
	var result: Dictionary = system.create_plan("iron_ingot", 60, "all")
	_expect(result.get("ok", false), "create a real persisted plan")
	var before_unsupported := GameStateCodec.to_persistent_dict(state)
	_expect(not system.set_recipe(result.id, "iron_ingot", "iron_ingot_recipe").ok and GameStateCodec.to_persistent_dict(state) == before_unsupported, "native legacy recipe outside runtime source content is rejected atomically")
	var payload := GameStateCodec.to_persistent_dict(state)
	var restored := GameStateCodec.from_persistent_dict(payload)
	_expect(restored != null and restored.get("production_plans") == state.get("production_plans"), "plans survive schema v9 save round trip")
	var legacy := GameStateCodec.to_persistent_dict(GameState.new())
	_expect(not legacy.has("production_plans") and GameStateCodec.from_persistent_dict(legacy).get("production_plans").is_empty(), "legacy saves default to no plans")
	for changes in [{"targetPerMinute": NAN}, {"targetPerMinute": INF}, {"itemId": "absent"}, {"planetId": "absent"}]:
		_expect(not system.update_plan(result.id, changes).ok and GameStateCodec.to_persistent_dict(state) == payload, "invalid plan edit is atomic")
	for bad in ["wrong type", [{"id": "broken"}], state.get("production_plans") + state.get("production_plans")]:
		var damaged := payload.duplicate(true)
		damaged.production_plans = bad
		_expect(GameStateCodec.from_persistent_dict(damaged) == null, "invalid plan save rejected")

func _test_live_factory(script: Script) -> void:
	var state := GameState.new()
	SourceGalaxySystem.new(state).initialize(240721)
	state.initialize_new_game_home_inventory(true)
	var wind := state.try_place_building("dsp_wind_turbine", Vector2.ZERO)
	var smelter := state.try_place_building("dsp_arc_smelter", Vector2(300, 0))
	_expect(wind.ok and smelter.ok, "planning live fixture uses real placement")
	if not smelter.ok: return
	var id := String(smelter.get("building_id", smelter.get("id", "")))
	if id.is_empty(): id = state.buildings.keys().filter(func(key): return state.buildings[key].type == "dsp_arc_smelter")[0]
	state.set_entity_recipe(id, "dsp_iron_ingot")
	state.buildings[id].input_buffer = {"iron_ore": 10.0}
	var engine := SimulationEngine.new(state)
	engine.update(0.5)
	var system: RefCounted = script.new(state)
	var created: Dictionary = system.create_plan("iron_ingot", 120, "all")
	var result: Dictionary = system.calculate(state.get("production_plans")[0])
	_expect(created.ok and result.requirements[0].existingPerMinute > 0, "real powered factory contributes current production to plan")
	state.buildings[id].input_buffer = {}
	engine.update(1.0 / 60.0)
	result = system.calculate(state.get("production_plans")[0])
	_expect(result.requirements[0].existingPerMinute == 0, "blocked factory stops contributing current production")
	var saved := GameStateCodec.to_persistent_dict(state)
	_expect(not saved.buildings[id].has("production_utilization") and not saved.buildings[id].has("last_production_per_minute"), "live query metrics are runtime only")

func _test_formal_controls() -> void:
	var state := GameState.new()
	GameManager.game_state = state
	var workspace := CodexWorkspace.new()
	add_child(workspace)
	workspace.show()
	await get_tree().process_frame
	var tab := workspace.get_node_or_null("Layout/Tabs/Planning") as Button
	_expect(tab != null, "formal analysis workspace exposes production planning")
	if tab != null:
		tab.pressed.emit()
		await get_tree().process_frame
		var panel := workspace.get_node("Layout/Content/PlanningPanel")
		var create := panel.get_node("Layout/Create") as Button
		create.pressed.emit()
		_expect(state.get("production_plans").size() == 1, "formal create button commits a real plan")
		var row := panel.get_node("Layout/Plans/Plan_0")
		var rate := row.get_node("Target") as SpinBox
		rate.value = 120
		_expect(state.get("production_plans")[0].targetPerMinute == 120, "formal target edit updates the stored plan")
		var name_input := row.get_node("Name") as LineEdit
		name_input.text = "  测试计划  "
		name_input.text_submitted.emit(name_input.text)
		_expect(state.production_plans[0].name == "测试计划", "formal name edit trims and persists")
		row = panel.get_node("Layout/Plans/Plan_0")
		name_input = row.get_node("Name") as LineEdit
		name_input.grab_focus()
		await get_tree().process_frame
		name_input.text = "  失焦保存计划  "
		create.grab_focus()
		await get_tree().process_frame
		_expect(state.production_plans[0].name == "失焦保存计划", "actual focus loss commits name without Enter")
		row = panel.get_node("Layout/Plans/Plan_0")
		var previous_summary := _row_text(row)
		state.get_planet_inventory("home")["iron_ingot"] = 99.0
		create.grab_focus()
		await get_tree().create_timer(1.1).timeout
		EventBus.simulation_updated.emit()
		await get_tree().process_frame
		await get_tree().process_frame
		row = panel.get_node("Layout/Plans/Plan_0")
		_expect(_row_text(row) != previous_summary and _row_text(row).contains("库存 99"), "focused button does not freeze live inventory summary")
		var unsupported := []
		for i in range(panel.get_node("Layout/Item").item_count):
			if panel.get_node("Layout/Item").get_item_metadata(i) in ["rubber", "circuit", "chip", "gravity_lens", "matrix_science_1"]: unsupported.append(panel.get_node("Layout/Item").get_item_metadata(i))
		_expect(unsupported.is_empty(), "formal source plan choices exclude unsupported native items: " + str(unsupported))
		row = panel.get_node("Layout/Plans/Plan_0")
		name_input = row.get_node("Name") as LineEdit
		name_input.grab_focus()
		await get_tree().process_frame
		name_input.text = "研究期间的草稿"
		state.completed_technologies.append("dsp_basic_logistics")
		EventBus.simulation_updated.emit()
		await get_tree().create_timer(1.1).timeout
		_expect(is_instance_valid(name_input) and name_input.has_focus() and name_input.text == "研究期间的草稿", "research refresh preserves focused name draft")
		workspace.hide()
		await get_tree().process_frame
		_expect(state.production_plans[0].name == "研究期间的草稿", "closing analysis commits focused name draft")
		workspace.show()
		await get_tree().process_frame
		row = panel.get_node("Layout/Plans/Plan_0")
		var item := row.get_node("Item") as OptionButton
		for i in range(item.item_count):
			if item.get_item_metadata(i) == "copper_ingot":
				item.item_selected.emit(i)
				break
		_expect(state.production_plans[0].itemId == "copper_ingot", "formal item edit changes target")
		row = panel.get_node("Layout/Plans/Plan_0")
		var scope := row.get_node("Scope") as OptionButton
		for i in range(scope.item_count):
			if scope.get_item_metadata(i) == "ashen":
				scope.item_selected.emit(i)
				break
		_expect(state.production_plans[0].planetId == "ashen", "formal scope edit changes equipment scope")
		row = panel.get_node("Layout/Plans/Plan_0")
		(row.get_node("Delete") as Button).pressed.emit()
		_expect(state.get("production_plans").is_empty(), "formal delete button removes the plan")
		for tech in DataManager.get_all_technologies(): state.completed_technologies.append(tech)
		ProductionPlanningSystem.new(state).create_plan("hydrogen", 60, "all")
		panel.refresh_now()
		row = panel.get_node("Layout/Plans/Plan_0")
		var recipe := row.get_node("Recipe_hydrogen") as OptionButton
		for i in range(recipe.item_count):
			if recipe.get_item_metadata(i) == "plasma_refining":
				recipe.item_selected.emit(i)
				break
		_expect(state.production_plans[0].recipeSelections.get("hydrogen") == "plasma_refining", "formal alternative recipe selector persists selection")
	workspace.queue_free()
	await get_tree().process_frame

func _same(actual: Variant, expected: Variant) -> bool:
	return PlanningBehaviorRunner.same(actual, expected)

func _row_text(row: Node) -> String:
	var result := ""
	for child in row.get_children():
		if child is Label: result += child.text
	return result

func _expect(ok: bool, message: String) -> void:
	if ok: print("PASS: " + message.split("\n")[0])
	else:
		_failures += 1
		printerr("FAIL: " + message)

func _difference(actual: Variant, expected: Variant, path: String = "result") -> String:
	if _same(actual, expected): return ""
	if actual is Dictionary and expected is Dictionary:
		for key in expected:
			if not actual.has(key): return path + "." + key + " missing"
			if not _same(actual[key], expected[key]): return _difference(actual[key], expected[key], path + "." + key)
	if actual is Array and expected is Array and actual.size() == expected.size():
		for i in range(actual.size()):
			if not _same(actual[i], expected[i]): return _difference(actual[i], expected[i], path + "[%d]" % i)
	return "%s actual=%s expected=%s" % [path, str(actual), str(expected)]
