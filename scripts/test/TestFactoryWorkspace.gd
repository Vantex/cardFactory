extends Node

var _failures := 0

func _ready() -> void:
	print("FACTORY WORKSPACE TESTS STARTED")
	_test_explicit_building_costs()
	_test_existing_recipe_connection_rules()

	var state := GameState.new()
	_expect(state.construction_points == 12, "new workspaces start with 12 construction points")

	var miner: Dictionary = state.try_place_building("miner", Vector2(100, 100))
	_expect(miner.ok and state.construction_points == 11, "miner placement is atomic")
	_expect(state.buildings.size() == 1, "successful placement adds one building")
	_expect(state.get_building_display_name(miner.id) == "矿机", "building display names come from building data")

	var points_before_rejection: int = state.construction_points
	var buildings_before_rejection: int = state.buildings.size()
	_expect(not state.try_place_building("unknown_building", Vector2(240, 100)).ok, "unknown buildings are rejected")
	_expect(state.construction_points == points_before_rejection and state.buildings.size() == buildings_before_rejection, "unknown building rejection leaves state unchanged")

	state.construction_points = 0
	_expect(not state.try_place_building("smelter", Vector2(240, 100)).ok, "placements without points are rejected")
	_expect(state.construction_points == 0 and state.buildings.size() == buildings_before_rejection, "insufficient-point rejection leaves state unchanged")

	state.construction_points = points_before_rejection
	_expect(not state.try_place_building("miner", Vector2(100, 100)).ok, "overlapping placements are rejected")
	_expect(state.construction_points == points_before_rejection and state.buildings.size() == buildings_before_rejection, "overlap rejection leaves state unchanged")

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

	if _failures > 0:
		printerr("FACTORY WORKSPACE TESTS FAILED")
		get_tree().quit(1)
		return

	print("FACTORY WORKSPACE TESTS PASSED")
	get_tree().quit(0)

func _test_explicit_building_costs() -> void:
	var cost_cases := [
		{"building_type": "miner", "remaining_points": 11},
		{"building_type": "smelter", "remaining_points": 10},
		{"building_type": "assembling_machine_mk1", "remaining_points": 9},
		{"building_type": "power_generator", "remaining_points": 10},
	]
	for cost_case in cost_cases:
		var state := GameState.new()
		var result: Dictionary = state.try_place_building(cost_case.building_type, Vector2(100, 100))
		_expect(result.ok and state.construction_points == cost_case.remaining_points, "%s uses its configured construction cost" % cost_case.building_type)

	var unconfigured_state := GameState.new()
	var unconfigured_result: Dictionary = unconfigured_state.try_place_building("solar_panel", Vector2(100, 100))
	_expect(not unconfigured_result.ok and unconfigured_state.construction_points == 12 and unconfigured_state.buildings.is_empty(), "buildings without configured costs are rejected without state changes")

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

func _expect(condition: bool, description: String) -> void:
	if condition:
		print("PASS: %s" % description)
		return

	_failures += 1
	printerr("FAIL: %s" % description)
