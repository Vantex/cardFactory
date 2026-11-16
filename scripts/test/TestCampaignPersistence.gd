extends Node

var errors: Array[String] = []

func _ready() -> void:
	var legacy := GameState.new()
	SourceGalaxySystem.new(legacy).initialize(240721, true)
	legacy.initialize_new_game_home_inventory()
	var service := SaveSystem.new("res://.godot/task27-campaign-legacy-%d" % Time.get_ticks_usec())
	var saved := service.save_slot(0, legacy)
	var loaded := service.load_slot(0) if saved.ok else {}
	_check(saved.ok and loaded.get("ok", false), "legacy native economy with source galaxy saves and loads")
	if loaded.get("ok", false):
		var state: GameState = loaded.state
		_check(state.selected_source_objective.is_empty(), "legacy native campaign retains empty source tracking after loading")
		state.add_building({"type": "power_generator", "position": Vector2.ZERO})
		var result := ProgressionSystem.new(state).evaluate()
		_check(result.completed_objectives.has("first_power") and state.unlocked_progression_ids.has("tutorial:mining"), "legacy native campaign continues its actual objective and reward")
	var custom_state := GameState.new()
	SourceGalaxySystem.new(custom_state).initialize(240721, true)
	custom_state.initialize_new_game_home_inventory(true)
	var custom := {"chapters": [], "objectives": [], "achievements": []}
	ProgressionSystem.new(custom_state, custom).evaluate()
	_check(custom_state.selected_source_objective == "dsp_mine_first_ore", "custom native catalog preserves source tracking it does not own")
	var switched := GameState.new()
	SourceGalaxySystem.new(switched).initialize(240721, true)
	switched.initialize_new_game_home_inventory()
	var engine := SimulationEngine.new(switched)
	switched.add_building({"type": "power_generator", "position": Vector2.ZERO})
	_check(ProgressionSystem.new(switched).select_objective("dsp_mine_first_ore"), "explicit source task selection enters the source campaign")
	engine.progression_system.evaluate()
	_check(not switched.completed_objective_ids.has("first_power") and not switched.unlocked_progression_ids.has("tutorial:mining"), "existing simulation progression refreshes its catalog after switching campaign domain")
	for error in errors: printerr("FAIL: " + error)
	if errors.is_empty(): print("CAMPAIGN PERSISTENCE TESTS PASSED")
	else: printerr("CAMPAIGN PERSISTENCE TESTS FAILED")
	get_tree().quit(0 if errors.is_empty() else 1)

func _check(ok: bool, message: String) -> void:
	if not ok: errors.append(message)
