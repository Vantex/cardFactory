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
		_test_semantic_deployment_validation(blueprint_script)
		_test_line_configuration_round_trip(blueprint_script, codec_script)
		_test_active_planet_capture_and_deployment(blueprint_script)
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
	state.emit_canvas_events = false
	_expect(blueprint_script.new(state).capture_selection([target_id, source_id]).blueprint == blueprint, "capture graph is independent of event delivery")
	_expect(blueprint.get("version", 0) == 1 and blueprint.entities.size() == 2 and blueprint.connections.size() == 1, "blueprint v1 captures selected entities and only internal connections")
	_expect(blueprint.entities[0].position == Vector2.ZERO and blueprint.entities[1].position == Vector2(400, 200), "captured positions are relative to the selection origin")
	_expect(blueprint.entities[0].configuration == {"output_item": "iron_ore"} and blueprint.entities[1].configuration == {"recipe_id": "iron_ingot_recipe"}, "capture preserves only production configuration")
	_expect(not blueprint.entities[0].has("id") and not blueprint.entities[0].has("progress") and not blueprint.entities[0].has("input_buffer") and not blueprint.entities[0].has("selected") and not blueprint.entities[0].has("node"), "capture excludes runtime state, IDs, selection, and node references")
	_expect(blueprint.connections[0].source == "entity_0" and blueprint.connections[0].target == "entity_1" and blueprint.connections[0].configuration.parallel_count == 2 and not blueprint.connections[0].has("id") and not blueprint.connections[0].has("total_transferred"), "internal connection uses local references and excludes runtime state")

func _test_transform_and_offset(blueprint_script: Script) -> void:
	var state := GameState.new()
	state.construction_inventory = {"miner": 4.0, "smelter": 4.0, "conveyor_belt_mk1": 4.0}
	_add_resource_site(state, "transform_iron", "iron_ore", Vector2(1000, 800))
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
	_add_resource_site(clockwise_state, "clockwise_iron", "iron_ore", Vector2(1000, 800))
	var clockwise: Dictionary = blueprint_script.new(clockwise_state).deploy(blueprint, Vector2(1000, 800), 1, false)
	var counter_state := GameState.new()
	counter_state.construction_inventory = {"miner": 1.0, "smelter": 1.0, "conveyor_belt_mk1": 1.0}
	_add_resource_site(counter_state, "counter_iron", "iron_ore", Vector2(1000, 800))
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
	_add_resource_site(commit_state, "commit_iron", "iron_ore", Vector2.ZERO)
	var commit_before := commit_state.copy_state()
	var reject_after_first_stage := func(stage: String, index: int) -> bool:
		return not (stage == "entity" and index == 0)
	var commit_failed: Dictionary = blueprint_script.new(commit_state).deploy(single, Vector2.ZERO, 0, false, reject_after_first_stage)
	_expect(not commit_failed.get("ok", true) and commit_failed.get("reason", "") == "commit_failed" and _same_authoritative_state(commit_state, commit_before), "a commit-stage failure restores buildings, connections, construction inventory, and the next ID")

func _test_repeated_paste(blueprint_script: Script) -> void:
	var state := GameState.new()
	state.construction_inventory = {"miner": 2.0}
	_add_resource_site(state, "paste_iron_1", "iron_ore", Vector2.ZERO)
	_add_resource_site(state, "paste_iron_2", "iron_ore", Vector2(400, 0))
	var blueprint := {"version": 1, "entities": [{"ref": "entity_0", "type": "miner", "position": Vector2.ZERO, "configuration": {}}], "connections": []}
	var system = blueprint_script.new(state)
	var first: Dictionary = system.deploy(blueprint, Vector2.ZERO)
	var second: Dictionary = system.deploy(blueprint, Vector2(400, 0))
	_expect(first.get("ok", false) and second.get("ok", false) and first.entity_ids[0] != second.entity_ids[0] and state.buildings.size() == 2 and state.construction_inventory.miner == 0.0, "repeated paste creates fresh IDs and charges each deployment")

func _test_semantic_deployment_validation(blueprint_script: Script) -> void:
	var invalid_output_state := GameState.new()
	invalid_output_state.construction_inventory = {"miner": 1.0}
	var invalid_output := {"version": 1, "entities": [{"ref": "entity_0", "type": "miner", "position": Vector2.ZERO, "configuration": {"output_item": "graphene"}}], "connections": []}
	var output_before := invalid_output_state.copy_state()
	var output_result: Dictionary = blueprint_script.new(invalid_output_state).deploy(invalid_output, Vector2.ZERO)
	_expect(not output_result.get("ok", true) and output_result.get("reason", "") == "invalid_reference" and _same_authoritative_state(invalid_output_state, output_before), "imported extractor output must belong to its building definition")

	var graph_state := GameState.new()
	graph_state.construction_inventory = {"miner": 1.0, "smelter": 1.0, "conveyor_belt_mk1": 2.0}
	var incompatible := {"version": 1, "entities": [{"ref": "source", "type": "miner", "position": Vector2.ZERO, "configuration": {"output_item": "iron_ore"}}, {"ref": "target", "type": "smelter", "position": Vector2(400, 0), "configuration": {"recipe_id": "copper_ingot_recipe"}}], "connections": [{"source": "source", "target": "target", "type": "conveyor_belt_mk1", "configuration": {"item_id": "iron_ore"}}]}
	var incompatible_before := graph_state.copy_state()
	var incompatible_result: Dictionary = blueprint_script.new(graph_state).deploy(incompatible, Vector2.ZERO)
	_expect(not incompatible_result.get("ok", true) and incompatible_result.get("reason", "") == "incompatible_connection" and _same_authoritative_state(graph_state, incompatible_before), "planned connections reject source/item/target recipe incompatibility atomically")
	var duplicate := incompatible.duplicate(true)
	duplicate.entities[1].configuration.recipe_id = "iron_ingot_recipe"
	duplicate.connections.append(duplicate.connections[0].duplicate(true))
	var duplicate_result: Dictionary = blueprint_script.new(graph_state).deploy(duplicate, Vector2.ZERO)
	_expect(not duplicate_result.get("ok", true) and duplicate_result.get("reason", "") == "duplicate_connection" and _same_authoritative_state(graph_state, incompatible_before), "planned graph rejects duplicate source-target edges without partial mutation")

	var byproduct_state := GameState.new()
	byproduct_state.completed_technologies = ["fluid_handling"]
	byproduct_state.construction_inventory = {"oil_refinery": 1.0, "fractionator": 1.0, "conveyor_belt_mk1": 1.0}
	var byproduct_blueprint := {"version": 1, "entities": [{"ref": "refinery", "type": "oil_refinery", "position": Vector2.ZERO, "configuration": {"recipe_id": "refined_oil_recipe", "output_item": "refined_oil"}}, {"ref": "fractionator", "type": "fractionator", "position": Vector2(400, 0), "configuration": {"recipe_id": "deuterium_recipe"}}], "connections": [{"source": "refinery", "target": "fractionator", "type": "conveyor_belt_mk1", "configuration": {"item_id": "hydrogen"}}]}
	var byproduct_result: Dictionary = blueprint_script.new(byproduct_state).deploy(byproduct_blueprint, Vector2.ZERO)
	_expect(byproduct_result.get("ok", false) and byproduct_state.connections.values()[0].item_id == "hydrogen", "processor connection preflight accepts any selected recipe byproduct")

	var locked_recipe_state := GameState.new()
	locked_recipe_state.construction_inventory = {"miner": 1.0, "graphene_facility": 1.0, "conveyor_belt_mk1": 1.0}
	var locked_recipe_blueprint := {"version": 1, "entities": [{"ref": "coal", "type": "miner", "position": Vector2.ZERO, "configuration": {"output_item": "coal"}}, {"ref": "graphene", "type": "graphene_facility", "position": Vector2(400, 0), "configuration": {}}], "connections": [{"source": "coal", "target": "graphene", "type": "conveyor_belt_mk1", "configuration": {"item_id": "coal"}}]}
	var locked_recipe_before := locked_recipe_state.copy_state()
	var locked_recipe_result: Dictionary = blueprint_script.new(locked_recipe_state).deploy(locked_recipe_blueprint, Vector2.ZERO)
	_expect(not locked_recipe_result.get("ok", true) and locked_recipe_result.get("reason", "") == "locked" and _same_authoritative_state(locked_recipe_state, locked_recipe_before), "auto-selected target recipes obey current technology unlocks atomically")

func _test_line_configuration_round_trip(blueprint_script: Script, codec_script: Script) -> void:
	var source_state := GameState.new()
	var source_id := _add_building(source_state, "miner", Vector2.ZERO, {"output_item": "iron_ore"})
	var target_id := _add_building(source_state, "smelter", Vector2(400, 0), {"recipe_id": "iron_ingot_recipe"})
	source_state.add_connection({"source_id": source_id, "target_id": target_id, "type": "conveyor_belt_mk2", "item_id": "iron_ore", "parallel_count": 2, "stack_size": 4, "priority": 2, "route_mode": "manual", "route_offset_y": 33.0, "monitor_enabled": true, "enabled": false, "current_flow": 19.0, "active": true, "in_transit": [{"amount": 1.0}], "total_transferred": 900.0})
	var capture: Dictionary = blueprint_script.new(source_state).capture_selection([source_id, target_id])
	var configuration: Dictionary = capture.blueprint.connections[0].configuration
	_expect(configuration == {"item_id": "iron_ore", "parallel_count": 2, "stack_size": 4, "priority": 2, "route_mode": "manual", "route_offset_y": 33.0, "monitor_enabled": true, "enabled": false}, "capture preserves every persistent Task 7 belt field and excludes runtime fields")
	var encoded: Dictionary = codec_script.new().encode(capture.blueprint)
	var decoded: Dictionary = codec_script.new().decode(encoded.get("text", ""))
	_expect(decoded.get("ok", false) and decoded.blueprint.connections[0].configuration == configuration, "restricted JSON round-trips the complete persistent line configuration")
	var target_state := GameState.new()
	target_state.construction_inventory = {"miner": 1.0, "smelter": 1.0, "conveyor_belt_mk2": 2.0}
	_add_resource_site(target_state, "line_iron", "iron_ore", Vector2.ZERO)
	var deployed: Dictionary = blueprint_script.new(target_state).deploy(decoded.blueprint, Vector2.ZERO)
	var deployed_line: Dictionary = target_state.connections[deployed.connection_ids[0]] if deployed.get("ok", false) else {}
	_expect(deployed.get("ok", false) and deployed_line.route_offset_y == 33.0 and deployed_line.monitor_enabled and not deployed_line.enabled and deployed_line.current_flow == 0.0 and not deployed_line.active and deployed_line.get("in_transit", []).is_empty(), "deployment restores persistent line configuration with fresh runtime state")

func _test_active_planet_capture_and_deployment(blueprint_script: Script) -> void:
	var state := GameState.new()
	state.explored_system_ids.append("borealis")
	state.colonized_planet_ids.append("frost")
	state.planet_inventories["frost"] = {}
	state.planet_viewports["frost"] = {"position": Vector2.ZERO, "zoom": Vector2.ONE}
	state.planet_metrics["frost"] = {}
	_add_resource_site(state, "frost_deploy_iron", "iron_ore", Vector2(900, 100), "frost")
	var home_source := _add_building(state, "miner", Vector2(100, 100), {"planet_id": "home", "output_item": "iron_ore"})
	var home_target := _add_building(state, "smelter", Vector2(500, 100), {"planet_id": "home", "recipe_id": "iron_ingot_recipe"})
	var frost_source := _add_building(state, "miner", Vector2(100, 100), {"planet_id": "frost", "output_item": "iron_ore"})
	var frost_target := _add_building(state, "smelter", Vector2(500, 100), {"planet_id": "frost", "recipe_id": "iron_ingot_recipe"})
	var home_belt := state.add_connection({"source_id": home_source, "target_id": home_target, "planet_id": "home", "type": "conveyor_belt_mk1", "item_id": "iron_ore"})
	state.add_connection({"source_id": frost_source, "target_id": frost_target, "planet_id": "frost", "type": "conveyor_belt_mk1", "item_id": "iron_ore"})
	_add_building(state, "miner", Vector2(900, 100), {"planet_id": "home"})
	_add_building(state, "smelter", Vector2(1300, 100), {"planet_id": "home"})
	state.set_active_planet("frost")
	var system = blueprint_script.new(state)
	var before := GameStateCodec.state_digest_payload(state)
	var inactive: Dictionary = system.capture_selection([home_source])
	var mixed: Dictionary = system.capture_selection([frost_source, home_target])
	var mixed_line: Dictionary = system.capture_selection([frost_source, home_belt])
	var construction_before_unknown := state.construction_inventory.duplicate(true)
	var next_id_before_unknown: int = state._next_id
	var mixed_unknown: Dictionary = system.capture_selection([frost_source, "unknown_id"])
	_expect(not inactive.get("ok", true) and inactive.get("reason", "") == "inactive_entity", "blueprint capture rejects an inactive building ID")
	_expect(not mixed.get("ok", true) and mixed.get("reason", "") == "inactive_entity", "blueprint capture rejects mixed-planet entity IDs atomically")
	_expect(not mixed_line.get("ok", true) and mixed_line.get("reason", "") == "inactive_entity", "blueprint capture rejects an inactive line ID mixed into the request")
	_expect(not mixed_unknown.get("ok", true) and mixed_unknown.get("reason", "") == "invalid_reference", "blueprint capture atomically rejects an unknown ID mixed with an active building")
	_expect(GameStateCodec.state_digest_payload(state) == before and state.construction_inventory == construction_before_unknown and state._next_id == next_id_before_unknown, "rejected unknown blueprint capture preserves the digest, construction inventory, and stable ID sequence")
	_expect(GameStateCodec.state_digest_payload(state) == before, "rejected inactive blueprint capture leaves the persisted digest unchanged")
	var captured: Dictionary = system.capture_selection([frost_source, frost_target])
	_expect(captured.get("ok", false) and captured.blueprint.connections.size() == 1, "blueprint capture accepts one complete active-planet graph")
	state.construction_inventory = {"miner": 1.0, "smelter": 1.0, "conveyor_belt_mk1": 1.0}
	var deployed: Dictionary = system.deploy(captured.get("blueprint", {}), Vector2(900, 100))
	var deployed_entities: Array = deployed.get("entity_ids", [])
	var deployed_connections: Array = deployed.get("connection_ids", [])
	_expect(deployed.get("ok", false), "blueprint deployment may overlap another planet on the active canvas")
	if deployed.get("ok", false):
		_expect(deployed_entities.all(func(entity_id): return state.buildings[entity_id].get("planet_id", "") == "frost") and deployed_connections.all(func(connection_id): return state.connections[connection_id].get("planet_id", "") == "frost"), "blueprint deployment assigns every new entity and line to the active planet")

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
	var non_string_identifier: Dictionary = codec.decode('{"version":1,"entities":[{"ref":true,"type":7,"position":[0,0],"configuration":{}}],"connections":[]}')
	var fractional_version: Dictionary = codec.decode('{"version":1.9,"entities":[],"connections":[]}')
	var fractional_count: Dictionary = codec.decode('{"version":1,"entities":[{"ref":"entity_0","type":"miner","position":[0,0],"configuration":{}},{"ref":"entity_1","type":"smelter","position":[400,0],"configuration":{}}],"connections":[{"source":"entity_0","target":"entity_1","type":"conveyor_belt_mk1","configuration":{"parallel_count":1.9}}]}')
	var huge_coordinate: Dictionary = codec.decode('{"version":1,"entities":[{"ref":"entity_0","type":"miner","position":[1000001,0],"configuration":{}}],"connections":[]}')
	var too_many_entities: Array = []
	for index in range(codec.MAX_ENTITIES + 1):
		too_many_entities.append({"ref": "entity_%d" % index, "type": "miner", "position": [index * 300, 0], "configuration": {}})
	var too_many: Dictionary = codec.decode(JSON.stringify({"version": 1, "entities": too_many_entities, "connections": []}))
	var long_text: Dictionary = codec.decode(" " .repeat(codec.MAX_TEXT_LENGTH + 1))
	_expect(not unknown_key.get("ok", true) and not non_string_identifier.get("ok", true) and not fractional_version.get("ok", true) and not fractional_count.get("ok", true) and not huge_coordinate.get("ok", true) and not too_many.get("ok", true) and not long_text.get("ok", true), "codec rejects non-string identifiers, unknown/fractional fields, and all configured limits")

func _test_workspace_intents_and_import(codec_script: Script) -> void:
	var workspace_script := load("res://scenes/ui/BlueprintWorkspace.gd")
	_expect(workspace_script != null, "blueprint workspace resource exists")
	if workspace_script == null:
		return
	var state := GameState.new()
	state.construction_inventory = {"miner": 1.0, "smelter": 1.0}
	_add_resource_site(state, "formal_iron", "iron_ore", Vector2(1000, 500))
	var selected_id := _add_building(state, "miner", Vector2(100, 100))
	var selected_second_id := _add_building(state, "smelter", Vector2(500, 100))
	GameManager.replace_game_state(state)
	var input_handler: Node = load("res://scripts/input/InputHandler.gd").new()
	add_child(input_handler)
	input_handler.set_selected_entities([selected_id, selected_second_id])
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
	_expect(captured.get("ok", false) and capture_intents == [[selected_id, selected_second_id]] and exported.get("ok", false) and imported.get("ok", false) and state.buildings == buildings_before, "workspace emits capture intent from the shared selection and import never auto-deploys")
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
	main.get_node("AppShell").call("_on_session_started", 0, true)
	await get_tree().process_frame
	var main_input: Node = main.get_node("InputHandler")
	var formal_workspace: Control = main.get_node("FactoryWorkspaceUI/BlueprintWorkspace")
	main_input.set_selected_entities([selected_id, selected_second_id])
	var capture_button := formal_workspace.get_node_or_null("Panel/Controls/Capture") as Button
	var rotate_cw_button := formal_workspace.get_node_or_null("Panel/Controls/RotateCW") as Button
	var rotate_ccw_button := formal_workspace.get_node_or_null("Panel/Controls/RotateCCW") as Button
	var mirror_button := formal_workspace.get_node_or_null("Panel/Controls/Mirror") as Button
	var export_button := formal_workspace.get_node_or_null("Panel/Controls/Export") as Button
	var import_button := formal_workspace.get_node_or_null("Panel/Controls/Import") as Button
	var deploy_button := formal_workspace.get_node_or_null("Panel/Controls/Deploy") as Button
	var toggle_button := main.get_node_or_null("FactoryWorkspaceUI/InspectorPanel/BlueprintToggle") as Button
	_expect(formal_workspace.size.x > 0.0 and formal_workspace.size.y > 0.0 and capture_button != null and rotate_cw_button != null and rotate_ccw_button != null and mirror_button != null and export_button != null and import_button != null and deploy_button != null and toggle_button != null and not formal_workspace.visible, "formal Main exposes a collapsed player-operable blueprint workspace and visible entry point")
	if toggle_button != null:
		var toggle_position := toggle_button.get_global_rect().get_center()
		var toggle_press := InputEventMouseButton.new()
		toggle_press.button_index = MOUSE_BUTTON_LEFT
		toggle_press.pressed = true
		toggle_press.position = toggle_position
		toggle_press.global_position = toggle_position
		viewport.push_input(toggle_press)
		var toggle_release := InputEventMouseButton.new()
		toggle_release.button_index = MOUSE_BUTTON_LEFT
		toggle_release.pressed = false
		toggle_release.position = toggle_position
		toggle_release.global_position = toggle_position
		viewport.push_input(toggle_release)
		await get_tree().process_frame
	_expect(formal_workspace.visible, "real viewport GUI dispatch opens the collapsed blueprint workspace")
	var workspace_rect := formal_workspace.get_global_rect()
	var protected_controls: Array[Control] = [main.get_node("FactoryWorkspaceUI/TopBar"), main.get_node("FactoryWorkspaceUI/ResourceRail"), main.get_node("FactoryWorkspaceUI/InspectorPanel"), main.get_node("FactoryWorkspaceUI/ConstructionDock"), main.get_node("FactoryWorkspaceUI/MiniMap")]
	var geometry_clear := true
	for protected in protected_controls:
		geometry_clear = geometry_clear and (not protected.visible or not workspace_rect.intersects(protected.get_global_rect(), false))
	_expect(geometry_clear, "formal blueprint workspace does not overlap existing workspace regions or MiniMap")
	var capture_press := InputEventMouseButton.new()
	capture_press.button_index = MOUSE_BUTTON_LEFT
	capture_press.pressed = true
	capture_press.position = capture_button.get_global_rect().get_center()
	capture_press.global_position = capture_press.position
	var pointer_motion := InputEventMouseMotion.new()
	pointer_motion.position = capture_press.position
	pointer_motion.global_position = capture_press.position
	viewport.push_input(pointer_motion)
	await get_tree().process_frame
	var hovered_control := viewport.gui_get_hovered_control()
	_expect(hovered_control == capture_button or capture_button.is_ancestor_of(hovered_control), "real gameplay GUI hover resolves to the unobstructed blueprint capture control")
	viewport.push_input(capture_press)
	var capture_release := InputEventMouseButton.new()
	capture_release.button_index = MOUSE_BUTTON_LEFT
	capture_release.pressed = false
	capture_release.position = capture_press.position
	capture_release.global_position = capture_release.position
	viewport.push_input(capture_release)
	await get_tree().process_frame
	_expect(not formal_workspace.get_draft().is_empty(), "real viewport GUI dispatch reaches the visible capture control")
	var original_preview: Array = formal_workspace.get_preview_positions()
	rotate_cw_button.pressed.emit()
	var clockwise_preview: Array = formal_workspace.get_preview_positions()
	rotate_ccw_button.pressed.emit()
	mirror_button.pressed.emit()
	var mirrored_preview: Array = formal_workspace.get_preview_positions()
	_expect(not original_preview.is_empty() and clockwise_preview != original_preview and mirrored_preview != original_preview and formal_workspace.get_preview_footprints().size() == 2, "formal controls change an actual transformed footprint preview")
	export_button.pressed.emit()
	var exported_clipboard: String = formal_workspace.get_last_export_text()
	formal_workspace.clear_draft()
	import_button.pressed.emit()
	_expect(not exported_clipboard.is_empty() and not formal_workspace.get_draft().is_empty(), "formal export/import controls round-trip the clipboard without deployment")
	main.get_node("WorldCamera").global_position = Vector2(1000, 500)
	deploy_button.pressed.emit()
	_expect(main_input.get_blueprint_workspace() != null and main.get_node_or_null("FactoryWorkspaceUI/MiniMap") != null and state.buildings.size() == 4, "formal deploy-at-camera control routes through Main into authoritative GameState")
	var workspace_ui := main.get_node("FactoryWorkspaceUI")
	var panel_point := capture_button.get_global_rect().get_center()
	var minimap := main.get_node("FactoryWorkspaceUI/MiniMap") as Control
	_expect(workspace_ui.is_pointer_over_ui(panel_point) and workspace_ui.is_pointer_over_ui(minimap.get_global_rect().get_center()), "workspace hit testing recognizes the visible blueprint panel and mini-map")
	state.buildings[selected_id]["output_item"] = "iron_ore"
	state.construction_inventory["conveyor_belt_mk1"] = 1.0
	var covered_world_point: Vector2 = main_input.call("_screen_to_world", panel_point)
	_add_building(state, "smelter", covered_world_point - Vector2(9, 72))
	var connections_before_release := state.connections.size()
	main_input.start_connection(selected_id)
	var covered_release := InputEventMouseButton.new()
	covered_release.button_index = MOUSE_BUTTON_LEFT
	covered_release.pressed = false
	covered_release.position = panel_point
	covered_release.global_position = panel_point
	viewport.push_input(covered_release)
	await get_tree().process_frame
	_expect(main_input.get_mode_name() == "idle" and state.connections.size() == connections_before_release, "release over the open blueprint workspace cancels without targeting the covered world input port")
	viewport.queue_free()
	workspace.queue_free()
	input_handler.queue_free()
	await get_tree().process_frame
	var decoded: Dictionary = codec_script.new().decode_library_entry(exported.get("text", ""))
	_expect(decoded.get("ok", false), "workspace export remains valid restricted blueprint library JSON")

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
	var dynamic_map: Control = minimap_script.new()
	dynamic_map.size = Vector2(200, 150)
	dynamic_map.set_camera(camera)
	world.add_child(dynamic_map)
	var negative_id := _add_building(state, "miner", Vector2(-5000, -4000))
	var far_id := _add_building(state, "smelter", Vector2(9000, 7000))
	var dynamic_bounds: Rect2 = dynamic_map.get_effective_world_rect()
	_expect(dynamic_bounds.has_point(state.buildings[negative_id].position) and dynamic_bounds.has_point(state.buildings[far_id].position), "mini-map expands live bounds for negative and far entities")
	var center_click := InputEventMouseButton.new()
	center_click.button_index = MOUSE_BUTTON_LEFT
	center_click.pressed = true
	center_click.position = Vector2(100, 75)
	dynamic_map._gui_input(center_click)
	_expect(camera.global_position.is_equal_approx(dynamic_bounds.get_center()), "mini-map navigation mapping uses the current derived bounds")
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

func _add_resource_site(state: GameState, site_id: String, item_id: String, position: Vector2, planet_id: String = "home") -> void:
	state.resource_sites[site_id] = {"id": site_id, "planet_id": planet_id, "item_id": item_id, "position": position, "capacity": 100.0, "remaining": 100.0, "infinite": false}

func _same_authoritative_state(left: GameState, right: GameState) -> bool:
	return left.buildings == right.buildings and left.connections == right.connections and left.construction_inventory == right.construction_inventory and left.planet_inventory == right.planet_inventory and left._next_id == right._next_id

func _expect(condition: bool, message: String) -> void:
	if condition:
		print("  PASS: ", message)
		return
	_failures += 1
	printerr("  FAIL: ", message)
