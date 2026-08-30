extends Node

var _failures := 0

func _ready() -> void:
	print("BLUEPRINT TESTS STARTED")
	var blueprint_script := load("res://scripts/game/BlueprintSystem.gd")
	var codec_script := load("res://scripts/game/BlueprintCodec.gd")
	_expect(blueprint_script != null, "blueprint system resource exists")
	_expect(codec_script != null, "blueprint codec resource exists")
	if blueprint_script != null and codec_script != null:
		_test_capture_and_schema(blueprint_script)
		_test_transform_and_offset(blueprint_script)
		_test_atomic_deployment_failures(blueprint_script)
		_test_repeated_paste(blueprint_script)
		_test_restricted_codec(codec_script)
		await _test_workspace_intents_and_import(codec_script)
		await _test_minimap_navigation_is_presentational()
	if _failures > 0:
		printerr("BLUEPRINT TESTS FAILED")
		get_tree().quit(1)
		return
	print("BLUEPRINT TESTS PASSED")
	get_tree().quit(0)

func _test_capture_and_schema(blueprint_script: Script) -> void:
	var state := GameState.new()
	var source_id := _add_building(state, "miner", Vector2(300, 250), {
		"output_item": "iron_ore",
		"progress": 0.75,
		"input_buffer": {"coal": 9.0},
		"selected": true,
	})
	var target_id := _add_building(state, "smelter", Vector2(700, 450), {
		"recipe_id": "iron_ingot_recipe",
		"output_buffer": {"iron_ingot": 12.0},
	})
	var external_id := _add_building(state, "matrix_lab", Vector2(1100, 450))
	state.add_connection({
		"source_id": source_id,
		"target_id": target_id,
		"type": "conveyor_belt_mk2",
		"item_id": "iron_ore",
		"parallel_count": 2,
		"stack_size": 4,
		"total_transferred": 88.0,
	})
	state.add_connection({"source_id": target_id, "target_id": external_id, "type": "conveyor_belt_mk1", "item_id": "iron_ingot"})
	var result: Dictionary = blueprint_script.new(state).capture_selection([target_id, source_id])
	_expect(result.get("ok", false), "selection capture succeeds for selected buildings")
	if not result.get("ok", false):
		return
	var blueprint: Dictionary = result.blueprint
	_expect(blueprint.get("version", 0) == 1 and blueprint.entities.size() == 2 and blueprint.connections.size() == 1, "blueprint v1 captures selected entities and only internal connections")
	_expect(blueprint.entities[0].position == Vector2.ZERO and blueprint.entities[1].position == Vector2(400, 200), "captured positions are relative to the selection origin")
	_expect(blueprint.entities[0].configuration == {"output_item": "iron_ore"} and blueprint.entities[1].configuration == {"recipe_id": "iron_ingot_recipe"}, "capture preserves only production configuration")
	_expect(not blueprint.entities[0].has("id") and not blueprint.entities[0].has("progress") and not blueprint.entities[0].has("input_buffer") and not blueprint.entities[0].has("selected") and not blueprint.entities[0].has("node"), "capture excludes runtime state, IDs, selection, and node references")
	_expect(blueprint.connections[0].source == "entity_0" and blueprint.connections[0].target == "entity_1" and blueprint.connections[0].configuration.parallel_count == 2 and not blueprint.connections[0].has("id") and not blueprint.connections[0].has("total_transferred"), "internal connection uses local references and excludes runtime state")

func _test_transform_and_offset(blueprint_script: Script) -> void:
	var state := GameState.new()
	state.construction_inventory = {"miner": 4.0, "smelter": 4.0, "conveyor_belt_mk1": 4.0}
	var blueprint := {
		"version": 1,
		"entities": [
			{"ref": "entity_0", "type": "miner", "position": Vector2.ZERO, "configuration": {"output_item": "iron_ore"}},
			{"ref": "entity_1", "type": "smelter", "position": Vector2(400, 200), "configuration": {"recipe_id": "iron_ingot_recipe"}},
		],
		"connections": [{"source": "entity_0", "target": "entity_1", "type": "conveyor_belt_mk1", "configuration": {"item_id": "iron_ore", "parallel_count": 1}}],
	}
	var deployed: Dictionary = blueprint_script.new(state).deploy(blueprint, Vector2(1000, 800), 1, true)
	_expect(deployed.get("ok", false) and deployed.get("entity_ids", []).size() == 2, "rotated and mirrored blueprint deploys atomically")
	if not deployed.get("ok", false):
		return
	var first: Dictionary = state.buildings[deployed.entity_ids[0]]
	var second: Dictionary = state.buildings[deployed.entity_ids[1]]
	_expect(first.position == Vector2(1000, 800) and second.position == Vector2(1200, 1200), "clockwise rotation in Godot coordinates, mirror, and paste offset produce literal target positions")
	_expect(state.connections.size() == 1 and state.construction_inventory == {"miner": 3.0, "smelter": 3.0, "conveyor_belt_mk1": 3.0}, "successful deployment recreates the line and deducts the complete construction cost once")
	var clockwise_state := GameState.new()
	clockwise_state.construction_inventory = {"miner": 1.0, "smelter": 1.0, "conveyor_belt_mk1": 1.0}
	var clockwise: Dictionary = blueprint_script.new(clockwise_state).deploy(blueprint, Vector2(1000, 800), 1, false)
	var counter_state := GameState.new()
	counter_state.construction_inventory = {"miner": 1.0, "smelter": 1.0, "conveyor_belt_mk1": 1.0}
	var counter: Dictionary = blueprint_script.new(counter_state).deploy(blueprint, Vector2(1000, 800), -1, false)
	_expect(clockwise.get("ok", false) and clockwise_state.buildings[clockwise.entity_ids[1]].position == Vector2(800, 1200), "clockwise rotation follows Godot's y-down coordinate system")
	_expect(counter.get("ok", false) and counter_state.buildings[counter.entity_ids[1]].position == Vector2(1200, 400), "counterclockwise rotation is the inverse quarter turn")

func _test_atomic_deployment_failures(blueprint_script: Script) -> void:
	var overlap_state := GameState.new()
	overlap_state.construction_inventory = {"miner": 2.0}
	_add_building(overlap_state, "miner", Vector2(500, 500))
	var single := {"version": 1, "entities": [{"ref": "entity_0", "type": "miner", "position": Vector2.ZERO, "configuration": {}}], "connections": []}
	var overlap_before := overlap_state.copy_state()
	var overlap: Dictionary = blueprint_script.new(overlap_state).deploy(single, Vector2(500, 500))
	_expect(not overlap.get("ok", true) and overlap.get("reason", "") == "overlap" and _same_authoritative_state(overlap_state, overlap_before), "overlap rejects the whole deployment without deduction")

	var materials_state := GameState.new()
	materials_state.construction_inventory = {"miner": 1.0, "smelter": 0.0, "conveyor_belt_mk1": 1.0}
	var pair := {
		"version": 1,
		"entities": [
			{"ref": "entity_0", "type": "miner", "position": Vector2.ZERO, "configuration": {}},
			{"ref": "entity_1", "type": "smelter", "position": Vector2(400, 0), "configuration": {"recipe_id": "iron_ingot_recipe"}},
		],
		"connections": [{"source": "entity_0", "target": "entity_1", "type": "conveyor_belt_mk1", "configuration": {"item_id": "iron_ore"}}],
	}
	var materials_before := materials_state.copy_state()
	var missing: Dictionary = blueprint_script.new(materials_state).deploy(pair, Vector2.ZERO)
	_expect(not missing.get("ok", true) and missing.get("reason", "") == "missing_materials" and _same_authoritative_state(materials_state, materials_before), "missing construction materials roll back entities, connections, IDs, and inventory")

	var invalid_state := GameState.new()
	invalid_state.construction_inventory = {"miner": 5.0, "conveyor_belt_mk1": 5.0}
	var invalid := single.duplicate(true)
	invalid.connections = [{"source": "entity_0", "target": "missing", "type": "conveyor_belt_mk1", "configuration": {}}]
	var invalid_before := invalid_state.copy_state()
	var invalid_result: Dictionary = blueprint_script.new(invalid_state).deploy(invalid, Vector2.ZERO)
	_expect(not invalid_result.get("ok", true) and invalid_result.get("reason", "") == "invalid_reference" and _same_authoritative_state(invalid_state, invalid_before), "an invalid local reference causes full rollback")

	var unlock_state := GameState.new()
	unlock_state.construction_inventory = {"splitter": 1.0}
	var locked_blueprint := {"version": 1, "entities": [{"ref": "entity_0", "type": "splitter", "position": Vector2.ZERO, "configuration": {}}], "connections": []}
	var locked_before := unlock_state.copy_state()
	var locked: Dictionary = blueprint_script.new(unlock_state).deploy(locked_blueprint, Vector2.ZERO)
	_expect(not locked.get("ok", true) and locked.get("reason", "") == "locked" and _same_authoritative_state(unlock_state, locked_before), "technology-locked content rejects deployment without mutation")

	var commit_state := GameState.new()
	commit_state.construction_inventory = {"miner": 1.0}
	var commit_before := commit_state.copy_state()
	var reject_after_first_stage := func(stage: String, index: int) -> bool:
		return not (stage == "entity" and index == 0)
	var commit_failed: Dictionary = blueprint_script.new(commit_state).deploy(single, Vector2.ZERO, 0, false, reject_after_first_stage)
	_expect(not commit_failed.get("ok", true) and commit_failed.get("reason", "") == "commit_failed" and _same_authoritative_state(commit_state, commit_before), "a commit-stage failure restores buildings, connections, construction inventory, and the next ID")

func _test_repeated_paste(blueprint_script: Script) -> void:
	var state := GameState.new()
	state.construction_inventory = {"miner": 2.0}
	var blueprint := {"version": 1, "entities": [{"ref": "entity_0", "type": "miner", "position": Vector2.ZERO, "configuration": {}}], "connections": []}
	var system = blueprint_script.new(state)
	var first: Dictionary = system.deploy(blueprint, Vector2.ZERO)
	var second: Dictionary = system.deploy(blueprint, Vector2(400, 0))
	_expect(first.get("ok", false) and second.get("ok", false) and first.entity_ids[0] != second.entity_ids[0] and state.buildings.size() == 2 and state.construction_inventory.miner == 0.0, "repeated paste creates fresh IDs and charges each deployment")

func _test_restricted_codec(codec_script: Script) -> void:
	var codec = codec_script.new()
	var blueprint := {
		"version": 1,
		"entities": [{"ref": "entity_0", "type": "miner", "position": Vector2(20, -30), "configuration": {"output_item": "iron_ore"}}],
		"connections": [],
	}
	var encoded: Dictionary = codec.encode(blueprint)
	var decoded: Dictionary = codec.decode(encoded.get("text", ""))
	_expect(encoded.get("ok", false) and decoded.get("ok", false) and decoded.blueprint == blueprint, "restricted JSON round-trips blueprint v1 without runtime values")
	var unknown_key: Dictionary = codec.decode('{"version":1,"entities":[],"connections":[],"runtime_inventory":{}}')
	var fractional_version: Dictionary = codec.decode('{"version":1.9,"entities":[],"connections":[]}')
	var fractional_count: Dictionary = codec.decode('{"version":1,"entities":[{"ref":"entity_0","type":"miner","position":[0,0],"configuration":{}},{"ref":"entity_1","type":"smelter","position":[400,0],"configuration":{}}],"connections":[{"source":"entity_0","target":"entity_1","type":"conveyor_belt_mk1","configuration":{"parallel_count":1.9}}]}')
	var huge_coordinate: Dictionary = codec.decode('{"version":1,"entities":[{"ref":"entity_0","type":"miner","position":[1000001,0],"configuration":{}}],"connections":[]}')
	var too_many_entities: Array = []
	for index in range(codec.MAX_ENTITIES + 1):
		too_many_entities.append({"ref": "entity_%d" % index, "type": "miner", "position": [index * 300, 0], "configuration": {}})
	var too_many: Dictionary = codec.decode(JSON.stringify({"version": 1, "entities": too_many_entities, "connections": []}))
	var long_text: Dictionary = codec.decode(" " .repeat(codec.MAX_TEXT_LENGTH + 1))
	_expect(not unknown_key.get("ok", true) and not fractional_version.get("ok", true) and not fractional_count.get("ok", true) and not huge_coordinate.get("ok", true) and not too_many.get("ok", true) and not long_text.get("ok", true), "codec rejects unknown/fractional fields and enforces coordinate, entity-count, and text limits")

func _test_workspace_intents_and_import(codec_script: Script) -> void:
	var workspace_script := load("res://scenes/ui/BlueprintWorkspace.gd")
	_expect(workspace_script != null, "blueprint workspace resource exists")
	if workspace_script == null:
		return
	var state := GameState.new()
	state.construction_inventory = {"miner": 1.0}
	var selected_id := _add_building(state, "miner", Vector2(100, 100))
	GameManager.replace_game_state(state)
	var input_handler: Node = load("res://scripts/input/InputHandler.gd").new()
	add_child(input_handler)
	input_handler.set_selected_entities([selected_id])
	var workspace: Control = workspace_script.new()
	workspace.set_input_handler(input_handler)
	add_child(workspace)
	await get_tree().process_frame
	var codec = codec_script.new()
	var encoded: Dictionary = codec.encode({"version": 1, "entities": [{"ref": "entity_0", "type": "miner", "position": Vector2.ZERO, "configuration": {}}], "connections": []})
	var imported: Dictionary = workspace.import_text(encoded.get("text", ""))
	var capture_intents: Array = []
	if workspace.has_signal("capture_intent"):
		workspace.capture_intent.connect(func(entity_ids: Array) -> void: capture_intents.append(entity_ids))
	var captured: Dictionary = workspace.capture_selection()
	var exported: Dictionary = workspace.export_text()
	var buildings_before := state.buildings.duplicate(true)
	_expect(captured.get("ok", false) and capture_intents == [[selected_id]] and exported.get("ok", false) and imported.get("ok", false) and state.buildings == buildings_before, "workspace emits capture intent from the shared selection and import never auto-deploys")
	var deployment_intents: Array = []
	workspace.deployment_intent.connect(func(position: Vector2, _rotation: int, _mirrored: bool) -> void: deployment_intents.append(position))
	var deployment: Dictionary = workspace.request_deployment(Vector2(600, 100))
	_expect(deployment_intents == [Vector2(600, 100)] and deployment.get("pending", false) and state.buildings == buildings_before, "workspace deployment is intent-only and cannot mutate authoritative state directly")
	var viewport := SubViewport.new()
	viewport.size = Vector2i(1152, 648)
	add_child(viewport)
	var main: Node = load("res://scenes/main/Main.tscn").instantiate()
	viewport.add_child(main)
	await get_tree().process_frame
	var main_input: Node = main.get_node("InputHandler")
	main_input.set_selected_entities([selected_id])
	main_input.request_blueprint_capture()
	main_input.request_blueprint_deployment(Vector2(600, 100))
	_expect(main_input.get_blueprint_workspace() != null and main.get_node_or_null("FactoryWorkspaceUI/MiniMap") != null and state.buildings.size() == 2, "formal Main mounts blueprint/minimap UI and controller applies intents through GameState")
	viewport.queue_free()
	workspace.queue_free()
	input_handler.queue_free()
	await get_tree().process_frame
	var decoded: Dictionary = codec_script.new().decode(exported.get("text", ""))
	_expect(decoded.get("ok", false), "workspace export remains valid restricted blueprint JSON")

func _test_minimap_navigation_is_presentational() -> void:
	var minimap_script := load("res://scenes/ui/MiniMap.gd")
	var spatial_script := load("res://scripts/utils/SpatialIndex.gd")
	var state := GameState.new()
	var building_id := _add_building(state, "miner", Vector2(800, 600))
	GameManager.replace_game_state(state)
	var spatial_index = spatial_script.new()
	spatial_index.add_entity(building_id, Vector2(800, 600))
	var has_live_spatial_index := state.has_method("get_spatial_index")
	_expect(has_live_spatial_index, "authoritative state exposes a derived live spatial index")
	var viewport := SubViewport.new()
	viewport.size = Vector2i(1000, 800)
	add_child(viewport)
	var world := Node2D.new()
	viewport.add_child(world)
	var camera := Camera2D.new()
	camera.global_position = Vector2(200, 160)
	world.add_child(camera)
	camera.make_current()
	var minimap: Control = minimap_script.new()
	minimap.size = Vector2(200, 150)
	minimap.set_camera(camera)
	if not has_live_spatial_index:
		minimap.set_spatial_index(spatial_index)
	minimap.set_world_rect(Rect2(Vector2.ZERO, Vector2(2000, 1500)))
	world.add_child(minimap)
	await get_tree().process_frame
	var late_id := _add_building(state, "smelter", Vector2(1200, 900))
	_expect(minimap.get_visible_entity_ids().has(late_id), "mini-map refreshes its derived spatial index after live state changes")
	var before := state.copy_state()
	minimap.add_region("assembly", Rect2(600, 400, 500, 400), Color.CYAN)
	minimap.add_bookmark("ore", Vector2(800, 600))
	var click := InputEventMouseButton.new()
	click.button_index = MOUSE_BUTTON_LEFT
	click.pressed = true
	click.position = Vector2(100, 75)
	minimap._gui_input(click)
	_expect(camera.global_position == Vector2(1000, 750), "mini-map click maps local coordinates to the live camera")
	var motion := InputEventMouseMotion.new()
	motion.button_mask = MOUSE_BUTTON_MASK_LEFT
	motion.position = Vector2(150, 100)
	minimap._gui_input(motion)
	_expect(camera.global_position == Vector2(1500, 1000), "mini-map drag continuously moves the live camera")
	var navigated: bool = minimap.navigate_to_bookmark("ore")
	_expect(camera.global_position == Vector2(800, 600) and navigated, "mini-map click/drag and bookmarks navigate the live camera")
	_expect(minimap.get_visible_entity_ids().has(building_id), "mini-map queries the supplied live spatial index")
	_expect(_same_authoritative_state(state, before), "regions and bookmarks do not change production or authoritative simulation state")
	viewport.queue_free()
	await get_tree().process_frame

func _add_building(state: GameState, building_type: String, position: Vector2, extra: Dictionary = {}) -> String:
	var data := {
		"type": building_type,
		"position": position,
		"status": "idle",
		"recipe_id": "",
		"progress": 0.0,
		"input_buffer": {},
		"output_buffer": {},
	}
	data.merge(extra, true)
	return state.add_building(data)

func _same_authoritative_state(left: GameState, right: GameState) -> bool:
	return left.buildings == right.buildings and left.connections == right.connections and left.construction_inventory == right.construction_inventory and left.planet_inventory == right.planet_inventory and left._next_id == right._next_id

func _expect(condition: bool, message: String) -> void:
	if condition:
		print("  PASS: ", message)
		return
	_failures += 1
	printerr("  FAIL: ", message)
