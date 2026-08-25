extends Node

const INVENTORY_SCRIPT_PATH := "res://scripts/game/InventorySystem.gd"
const CONSTRUCTION_SCRIPT_PATH := "res://scripts/game/ConstructionSystem.gd"
const HANDCRAFT_SCRIPT_PATH := "res://scripts/game/HandcraftSystem.gd"

var _failures := 0
var _inventory_script: Script
var _construction_script: Script
var _handcraft_script: Script

func _ready() -> void:
	print("INVENTORY CONSTRUCTION TESTS STARTED")
	_test_domain_scripts_exist()
	_test_authoritative_starter_state()
	if _domain_scripts_ready():
		_test_planet_inventory_is_atomic_and_bounded()
		_test_cursor_payload_preserves_ownership()
		_test_construction_consumes_and_refunds_real_items()
		_test_handcraft_preview_queue_and_persistence()
		_test_legacy_points_migrate_into_construction_inventory()
		await _test_workspace_inventory_contract()
	if _failures > 0:
		printerr("INVENTORY CONSTRUCTION TESTS FAILED")
		get_tree().quit(1)
		return
	print("INVENTORY CONSTRUCTION TESTS PASSED")
	get_tree().quit(0)

func _test_domain_scripts_exist() -> void:
	_expect(ResourceLoader.exists(INVENTORY_SCRIPT_PATH), "planet inventory has a dedicated domain system")
	_expect(ResourceLoader.exists(CONSTRUCTION_SCRIPT_PATH), "construction inventory has a dedicated domain system")
	_expect(ResourceLoader.exists(HANDCRAFT_SCRIPT_PATH), "handcraft queues have a dedicated domain system")
	if ResourceLoader.exists(INVENTORY_SCRIPT_PATH):
		_inventory_script = load(INVENTORY_SCRIPT_PATH) as Script
	if ResourceLoader.exists(CONSTRUCTION_SCRIPT_PATH):
		_construction_script = load(CONSTRUCTION_SCRIPT_PATH) as Script
	if ResourceLoader.exists(HANDCRAFT_SCRIPT_PATH):
		_handcraft_script = load(HANDCRAFT_SCRIPT_PATH) as Script

func _test_authoritative_starter_state() -> void:
	var state := GameState.new()
	for property_name in ["planet_inventory", "construction_inventory", "cursor_payload", "handcraft_queue"]:
		_expect(_has_property(state, property_name), "GameState persists %s as authoritative state" % property_name)
	_expect(not _has_property(state, "construction_points"), "new states no longer expose abstract construction points")
	if not _has_property(state, "construction_inventory"):
		return
	var construction_inventory: Dictionary = state.get("construction_inventory")
	for building_type in ["miner", "smelter", "assembling_machine_mk1", "power_generator", "matrix_lab"]:
		_expect(float(construction_inventory.get(building_type, 0.0)) >= 1.0, "starter construction inventory contains one %s" % building_type)
	_expect(state.get("cursor_payload") == {"item_id": "", "amount": 0.0}, "new cursor payload starts empty")
	_expect(state.get("handcraft_queue") == [], "new handcraft queue starts empty")
	var lab_recipe: Dictionary = HandcraftSystem.RECIPES.get("handcraft_matrix_lab", {})
	_expect(lab_recipe.get("outputs", {}).get("matrix_lab", 0.0) == 1.0, "the first research building has a conserved handcraft construction recipe")
	var smelter_id := state.add_building({"type": "smelter", "position": Vector2.ZERO, "recipe_id": "", "input_buffer": {}, "output_buffer": {}})
	_expect(not state.set_entity_recipe(smelter_id, "circuit_recipe"), "a building rejects a catalog recipe assigned to another machine")
	state.get_building(smelter_id)["recipe_id"] = "circuit_recipe"
	var invalid_recipe_errors := GameStateValidator.validate_persistent_dict(GameStateCodec.to_persistent_dict(state))
	_expect(_has_error_code(invalid_recipe_errors, "invalid_building_recipe"), "save validation rejects a mismatched building recipe")
	var legacy_v2_state := GameState.new()
	var legacy_assembler_id := legacy_v2_state.add_building({"type": "assembler", "position": Vector2.ZERO, "recipe_id": "circuit_recipe", "input_buffer": {}, "output_buffer": {}})
	var legacy_v2_payload := GameStateCodec.to_persistent_dict(legacy_v2_state)
	_expect(not _has_error_code(GameStateValidator.validate_persistent_dict(legacy_v2_payload), "invalid_building_recipe") and GameStateCodec.from_persistent_dict(legacy_v2_payload) != null, "a baseline schema-v2 assembler save remains loadable without migration")
	var invalid_fuel_state := GameState.new()
	var invalid_generator_id := invalid_fuel_state.add_building({"type": "power_generator", "position": Vector2.ZERO, "recipe_id": "", "input_buffer": {}, "output_buffer": {}, "fuel_item": "iron_ore", "fuel_remaining": 30.0})
	var invalid_fuel_errors := GameStateValidator.validate_persistent_dict(GameStateCodec.to_persistent_dict(invalid_fuel_state))
	_expect(_has_error_code(invalid_fuel_errors, "invalid_fuel_item"), "save validation rejects fuel outside the generator catalog rule")

func _test_planet_inventory_is_atomic_and_bounded() -> void:
	var state := GameState.new()
	state.set("planet_inventory", {"iron_ingot": 5.0})
	var inventory: RefCounted = _inventory_script.new(state)
	var removed: Dictionary = inventory.try_remove("iron_ingot", 2.0)
	_expect(removed.get("ok", false) and state.get("planet_inventory").get("iron_ingot") == 3.0, "taking planet items removes the exact requested amount")
	var before_failure: Dictionary = state.get("planet_inventory").duplicate(true)
	_expect(not inventory.try_remove("iron_ingot", 4.0).get("ok", false), "taking more than available is rejected")
	_expect(state.get("planet_inventory") == before_failure, "failed planet withdrawal is atomic")
	_expect(inventory.try_add("iron_ingot", 996.0).get("ok", false), "planet inventory accepts an amount up to its item cap")
	var full_inventory: Dictionary = state.get("planet_inventory").duplicate(true)
	_expect(not inventory.try_add("iron_ingot", 1.0).get("ok", false), "planet inventory rejects an item-stack overflow")
	_expect(state.get("planet_inventory") == full_inventory, "overflow rejection leaves planet inventory unchanged")
	_expect(not inventory.try_add("iron_ingot", 0.0).get("ok", false) and not inventory.try_remove("iron_ingot", -1.0).get("ok", false), "zero and negative inventory commands are rejected")

func _test_cursor_payload_preserves_ownership() -> void:
	var state := GameState.new()
	state.set("planet_inventory", {"iron_ingot": 5.0, "gear": 1.0})
	var inventory: RefCounted = _inventory_script.new(state)
	_expect(inventory.try_pick_up("iron_ingot", 2.0).get("ok", false), "planet items can move into the cursor payload")
	_expect(state.get("planet_inventory").get("iron_ingot") == 3.0 and state.get("cursor_payload") == {"item_id": "iron_ingot", "amount": 2.0}, "picking up transfers ownership without duplication")
	var inventory_before_mismatch: Dictionary = state.get("planet_inventory").duplicate(true)
	var cursor_before_mismatch: Dictionary = state.get("cursor_payload").duplicate(true)
	_expect(not inventory.try_pick_up("gear", 1.0).get("ok", false), "a cursor holding one item type rejects a different item")
	_expect(state.get("planet_inventory") == inventory_before_mismatch and state.get("cursor_payload") == cursor_before_mismatch, "cursor type rejection is atomic")
	_expect(inventory.try_put_down(2.0).get("ok", false), "cursor items can return to the planet tray")
	_expect(state.get("planet_inventory").get("iron_ingot") == 5.0 and state.get("cursor_payload") == {"item_id": "", "amount": 0.0}, "putting down returns every owned item exactly once")

func _test_construction_consumes_and_refunds_real_items() -> void:
	var state := GameState.new()
	state.set("planet_inventory", {})
	state.set("construction_inventory", {"miner": 1.0, "smelter": 1.0, "assembling_machine_mk1": 0.0, "power_generator": 0.0})
	var construction: RefCounted = _construction_script.new(state)
	var miner_result: Dictionary = construction.try_place_building("miner", Vector2(100, 100))
	_expect(miner_result.get("ok", false) and state.get("construction_inventory").get("miner") == 0.0, "placing a building consumes one matching construction item")
	var count_before_missing := state.buildings.size()
	_expect(not construction.try_place_building("miner", Vector2(420, 100)).get("ok", false), "placement without the matching construction item is rejected")
	_expect(state.buildings.size() == count_before_missing and state.get("construction_inventory").get("miner") == 0.0, "missing-item placement leaves buildings and inventory unchanged")
	state.get("construction_inventory")["miner"] = 1.0
	_expect(not construction.try_place_building("miner", Vector2(100, 100)).get("ok", false), "overlap is checked before construction inventory is consumed")
	_expect(state.get("construction_inventory").get("miner") == 1.0, "overlap rejection preserves the construction item")

	var miner_id := String(miner_result.get("id", ""))
	state.get_building(miner_id)["output_buffer"] = {"iron_ore": 2.0}
	var smelter_result: Dictionary = construction.try_place_building("smelter", Vector2(420, 100))
	var connection_result := state.try_add_connection(miner_id, String(smelter_result.get("id", "")))
	_expect(connection_result.get("ok", false), "construction removal fixture creates a dependent connection")
	var removal: Dictionary = construction.try_remove_building(miner_id)
	_expect(removal.get("ok", false), "building removal succeeds when all refunds fit")
	_expect(not state.buildings.has(miner_id) and state.connections.is_empty(), "building removal still cascades to dependent connections")
	_expect(state.get("construction_inventory").get("miner") == 2.0 and state.get("planet_inventory").get("iron_ore") == 2.0, "removal refunds the construction item and buffered materials")

	var capped_state := GameState.new()
	capped_state.set("planet_inventory", {"iron_ore": 999.0})
	capped_state.set("construction_inventory", {"miner": 1.0, "smelter": 0.0, "assembling_machine_mk1": 0.0, "power_generator": 0.0})
	var capped_construction: RefCounted = _construction_script.new(capped_state)
	var capped_miner: Dictionary = capped_construction.try_place_building("miner", Vector2.ZERO)
	capped_state.get_building(String(capped_miner.get("id", "")))["output_buffer"] = {"iron_ore": 1.0}
	var capped_before: Dictionary = GameStateCodec.state_digest_payload(capped_state)
	_expect(not capped_construction.try_remove_building(String(capped_miner.get("id", ""))).get("ok", false), "removal is rejected when a buffered-material refund would overflow")
	_expect(GameStateCodec.state_digest_payload(capped_state) == capped_before, "failed removal cannot delete a building, connection, item, or construction piece")
	_expect(capped_state.remove_entities([String(capped_miner.get("id", ""))]) == 0, "batch removal counts only buildings that were actually removed")
	_expect(GameStateCodec.state_digest_payload(capped_state) == capped_before, "failed batch removal preserves the same atomic state")

	var fuel_state := GameState.new()
	fuel_state.set("planet_inventory", {"coal": 10.0})
	fuel_state.set("construction_inventory", {"miner": 0.0, "smelter": 0.0, "assembling_machine_mk1": 0.0, "power_generator": 1.0})
	var fuel_construction: RefCounted = _construction_script.new(fuel_state)
	var generator_result: Dictionary = fuel_construction.try_place_building("power_generator", Vector2.ZERO)
	var generator_id := String(generator_result.get("id", ""))
	_expect(generator_result.get("ok", false) and fuel_state.get("planet_inventory").get("coal", 0.0) == 0.0, "generator startup fuel transfers out of the planet inventory")
	_expect(float(fuel_state.get_building(generator_id).get("fuel_remaining", 0.0)) == 300.0, "ten conserved coal units become exactly three hundred seconds of startup fuel")
	_expect(fuel_construction.try_remove_building(generator_id).get("ok", false), "a fueled generator can be safely dismantled")
	_expect(fuel_state.get("planet_inventory").get("coal", 0.0) == 10.0, "dismantling refunds the generator's unburned startup fuel")

func _test_handcraft_preview_queue_and_persistence() -> void:
	var state := GameState.new()
	state.set("planet_inventory", {"iron_ingot": 3.0})
	state.set("construction_inventory", {"miner": 0.0, "smelter": 0.0, "assembling_machine_mk1": 0.0, "power_generator": 0.0})
	var handcraft: RefCounted = _handcraft_script.new(state)
	var preview: Dictionary = handcraft.preview_craft("handcraft_miner", 2)
	_expect(preview.get("required") == {"gear": 2.0, "iron_ingot": 4.0}, "handcraft preview reports the literal total input requirement")
	_expect(preview.get("missing") == {"gear": 2.0, "iron_ingot": 1.0}, "handcraft preview reports exact missing materials")
	_expect(preview.get("upstream", {}).get("gear", {}).get("recipe_id") == "handcraft_gear", "handcraft preview identifies an upstream recipe for a missing craftable item")
	var before_failure: Dictionary = GameStateCodec.state_digest_payload(state)
	_expect(not handcraft.queue_craft("handcraft_miner", 2).get("ok", false), "handcraft queue rejects insufficient direct materials")
	_expect(GameStateCodec.state_digest_payload(state) == before_failure, "failed handcraft queueing does not reserve partial materials")

	state.set("planet_inventory", {"iron_ingot": 4.0, "gear": 2.0})
	var queued: Dictionary = handcraft.queue_craft("handcraft_miner", 2)
	_expect(queued.get("ok", false), "a valid batch enters the persistent handcraft queue")
	_expect(state.get("planet_inventory").get("iron_ingot", 0.0) == 0.0 and state.get("planet_inventory").get("gear", 0.0) == 0.0, "queueing reserves the full batch input atomically")
	_expect(state.get("handcraft_queue").size() == 1 and state.get("handcraft_queue")[0].get("quantity_remaining") == 2, "one batch is represented by one persistent queue job")
	if not queued.get("ok", false) or state.get("handcraft_queue").is_empty():
		return
	handcraft.update(0.5)
	var round_trip := GameStateCodec.from_persistent_dict(GameStateCodec.to_persistent_dict(state))
	_expect(round_trip != null and round_trip.get("handcraft_queue")[0].get("progress") == 0.5, "save/load preserves partial handcraft progress")
	if round_trip == null:
		return
	var loaded_handcraft: RefCounted = _handcraft_script.new(round_trip)
	loaded_handcraft.update(0.5)
	_expect(round_trip.get("construction_inventory").get("miner") == 1.0 and round_trip.get("handcraft_queue")[0].get("quantity_remaining") == 1, "resumed handcraft completes exactly one reserved unit")
	loaded_handcraft.update(1.0)
	_expect(round_trip.get("construction_inventory").get("miner") == 2.0 and round_trip.get("handcraft_queue").is_empty(), "resumed batch completes without duplicating or losing outputs")

	var paused_state := GameState.new()
	paused_state.set("planet_inventory", {"iron_ingot": 2.0, "gear": 1.0})
	paused_state.set("construction_inventory", {"miner": 0.0, "smelter": 0.0, "assembling_machine_mk1": 0.0, "power_generator": 0.0})
	var paused_handcraft: RefCounted = _handcraft_script.new(paused_state)
	paused_handcraft.queue_craft("handcraft_miner", 1)
	paused_state.paused = true
	var paused_engine := SimulationEngine.new(paused_state)
	paused_engine.update(1.0)
	_expect(paused_state.get("handcraft_queue")[0].get("progress") == 0.0, "paused simulation does not advance handcraft jobs")
	paused_state.paused = false
	for _tick in range(60):
		paused_engine.update(1.0 / 60.0)
	_expect(paused_state.get("handcraft_queue").is_empty() and paused_state.get("construction_inventory").get("miner") == 1.0, "fixed simulation ticks advance handcraft jobs after resume")

func _test_legacy_points_migrate_into_construction_inventory() -> void:
	var legacy_v1 := {
		"schema_version": 1,
		"next_id": 1,
		"elapsed_time": 0.0,
		"construction_points": 7,
		"completed_technologies": [],
		"buildings": {},
		"connections": {},
	}
	var migration: Dictionary = SaveMigrationRegistry.migrate_to_current(legacy_v1)
	_expect(migration.get("ok", false), "version-one construction-point saves migrate to the current schema")
	if not migration.get("ok", false):
		return
	var migrated: Dictionary = migration.get("data", {})
	_expect(not migrated.has("construction_points"), "legacy construction points are removed after migration")
	_expect(migrated.get("construction_inventory", {}).get("legacy_credit") == 7.0, "legacy construction value is preserved as migration-only construction credit")
	_expect(migrated.get("planet_inventory") is Dictionary and migrated.get("cursor_payload") == {"item_id": "", "amount": 0.0} and migrated.get("handcraft_queue") == [], "migration installs every new authoritative inventory field")

func _test_workspace_inventory_contract() -> void:
	var state := GameState.new()
	if not _has_property(state, "planet_inventory"):
		return
	state.set("planet_inventory", {"gear": 2.0, "iron_ingot": 7.0})
	state.set("cursor_payload", {"item_id": "gear", "amount": 2.0})
	state.set("construction_inventory", {"miner": 1.0, "smelter": 0.0, "assembling_machine_mk1": 0.0, "power_generator": 0.0, "matrix_lab": 1.0})
	GameManager.replace_game_state(state)
	var workspace_script := load("res://scenes/ui/FactoryWorkspaceUI.gd") as Script
	var workspace := workspace_script.new() as CanvasLayer
	add_child(workspace)
	await get_tree().process_frame
	var stock := workspace.get_node_or_null("ResourceRail/Stock") as Label
	var cursor := workspace.get_node_or_null("ResourceRail/Cursor") as Label
	var queue := workspace.get_node_or_null("ResourceRail/Handcraft") as Label
	var miner_button := workspace.get_node_or_null("ConstructionDock/BuildingButtons/MinerButton") as Button
	var matrix_lab_button := workspace.get_node_or_null("ConstructionDock/BuildingButtons/MatrixLabButton") as Button
	var handcraft_quantity := workspace.get_node_or_null("InspectorPanel/HandcraftQuantity") as SpinBox
	var recipe_list := workspace.get_node_or_null("InspectorPanel/RecipeList") as GridContainer
	_expect(stock != null and "行星托盘" in stock.text and "iron_ingot 7.0" in stock.text, "resource rail displays the authoritative planet tray")
	_expect(cursor != null and "gear 2.0" in cursor.text, "resource rail displays the cursor payload")
	_expect(queue != null and "手工队列" in queue.text, "resource rail displays persistent handcraft queue status")
	_expect(miner_button != null and "已有 1 / 需要 1" in miner_button.text and not miner_button.disabled, "construction dock displays owned and required building items")
	_expect(matrix_lab_button != null and "T" in matrix_lab_button.text and "已有 1 / 需要 1" in matrix_lab_button.text and not matrix_lab_button.disabled, "construction dock exposes the playable research-station construction item")
	_expect(handcraft_quantity != null, "empty inspector exposes a handcraft batch quantity control")
	var miner_craft_button: Button
	if recipe_list != null:
		for child in recipe_list.get_children():
			if child is Button and "矿机施工件" in child.text:
				miner_craft_button = child
				break
	if handcraft_quantity != null and miner_craft_button != null:
		handcraft_quantity.value = 2.0
		miner_craft_button.pressed.emit()
		_expect(state.get("handcraft_queue").size() == 1 and state.get("handcraft_queue")[0].get("quantity_total") == 2, "handcraft UI queues the selected batch quantity")
		_expect(state.get("planet_inventory").get("iron_ingot", 0.0) == 3.0 and state.get("planet_inventory").get("gear", 0.0) == 0.0, "handcraft UI atomically reserves the selected batch materials")
	else:
		_expect(false, "handcraft batch controls include a miner construction recipe")
	var miner_id := state.add_building({
		"type": "miner",
		"position": Vector2.ZERO,
		"status": "idle",
		"recipe_id": "",
		"progress": 0.0,
		"input_buffer": {},
		"output_buffer": {},
		"speed": 1.0,
	})
	workspace.set_selected_building(miner_id)
	var copper_resource_button: Button
	for child in recipe_list.get_children():
		if child is Button and "铜矿石" in child.text:
			copper_resource_button = child
			break
	if copper_resource_button != null:
		copper_resource_button.pressed.emit()
	_expect(copper_resource_button != null and state.get_building(miner_id).get("output_item", "") == "copper_ore", "extractor inspector switches a miner to the copper branch needed by the science chain")
	var refinery_id := state.add_building({"type": "oil_refinery", "position": Vector2(320, 0), "status": "idle", "recipe_id": "refined_oil_recipe", "progress": 0.0, "input_buffer": {}, "output_buffer": {}, "speed": 1.0})
	workspace.set_selected_building(refinery_id)
	var hydrogen_output_button: Button
	for child in recipe_list.get_children():
		if child is Button and "输出：氢" in child.text:
			hydrogen_output_button = child
			break
	if hydrogen_output_button != null:
		hydrogen_output_button.pressed.emit()
	_expect(hydrogen_output_button != null and state.get_building(refinery_id).get("output_item", "") == "hydrogen", "processor inspector selects a byproduct for the next formal connection")
	state.get("construction_inventory")["miner"] = 0.0
	state.get("construction_inventory")["legacy_credit"] = 7.0
	workspace.refresh_now()
	_expect(miner_button != null and not miner_button.disabled and "旧额度 7 / 需要 1" in miner_button.text, "legacy construction credit is visible when it enables a migrated building")
	state.get("construction_inventory").erase("legacy_credit")
	workspace.refresh_now()
	_expect(miner_button != null and miner_button.disabled and "缺少" in miner_button.tooltip_text, "construction dock disables missing pieces and exposes a material reason")
	workspace.queue_free()
	await get_tree().process_frame

func _domain_scripts_ready() -> bool:
	return _inventory_script != null and _construction_script != null and _handcraft_script != null

func _has_property(object: Object, property_name: String) -> bool:
	for property_info in object.get_property_list():
		if String(property_info.get("name", "")) == property_name:
			return true
	return false

func _has_error_code(errors: Array, code: String) -> bool:
	for error_value in errors:
		if error_value.get("code", "") == code:
			return true
	return false

func _expect(condition: bool, description: String) -> void:
	if condition:
		print("PASS: %s" % description)
		return
	_failures += 1
	printerr("FAIL: %s" % description)
