extends Node

func _ready() -> void:
	var runner := preload("res://scripts/test/WorldQueryBehaviorRunner.gd")
	var result: Dictionary = runner.new().run()
	var fixture := DSPOnlineParity.read_json(runner.FIXTURE)
	var broken := fixture.duplicate(true)
	broken.source_files["src/game/galaxy.ts"] = "wrong"
	var rejected: Dictionary = runner.new().run(broken)
	if rejected.errors.is_empty() or not rejected.verified_keys.is_empty(): result.errors.append("world query source drift grants no keys")
	broken = fixture.duplicate(true)
	broken.cases.pop_back()
	rejected = runner.new().run(broken)
	if rejected.errors.is_empty() or not rejected.verified_keys.is_empty(): result.errors.append("world query missing boundary grants no keys")
	broken = fixture.duplicate(true)
	broken.cases.append(broken.cases[0].duplicate(true))
	rejected = runner.new().run(broken)
	if rejected.errors.is_empty() or not rejected.verified_keys.is_empty(): result.errors.append("world query duplicated boundary grants no keys")
	broken = fixture.duplicate(true)
	broken.cases[0].expected.planets[0].freeCapacity.pop_back()
	rejected = runner.new().run(broken)
	if rejected.errors.is_empty() or not rejected.verified_keys.is_empty(): result.errors.append("world query missing item capacity grants no keys")
	broken = fixture.duplicate(true)
	broken.cases[0].expected.planets[0].freeCapacity[0].value += 1
	rejected = runner.new().run(broken)
	if rejected.errors.is_empty() or rejected.verified_keys.has(runner.KEYS.capacity): result.errors.append("one wrong free capacity withholds its query key")
	broken = fixture.duplicate(true)
	broken.cases[0].expected.planets[0].requirements.reason += "wrong"
	rejected = runner.new().run(broken)
	if rejected.errors.is_empty() or rejected.verified_keys.has(runner.KEYS.requirements): result.errors.append("one wrong player reason withholds its requirements key")
	rejected = runner.new().run({}, func(id, state):
		if id == "fresh-240721-false": state.planet_inventory.iron_ore += 1)
	if rejected.errors.is_empty() or not rejected.verified_keys.is_empty(): result.errors.append("world query raw ownership mutation withholds all query keys")
	await _test_formal_query_consumers(fixture, result)
	for error in result.errors.slice(0, 12): printerr("FAIL: " + error)
	print("WORLD QUERY ERRORS: ", result.errors.size(), "; verified keys: ", result.verified_keys.size())
	if result.errors.is_empty(): print("PARITY WORLD QUERY TESTS PASSED")
	else: printerr("PARITY WORLD QUERY TESTS FAILED")
	get_tree().quit(0 if result.errors.is_empty() else 1)

func _test_formal_query_consumers(fixture: Dictionary, result: Dictionary) -> void:
	await get_tree().process_frame
	var viewport := SubViewport.new()
	viewport.size = Vector2i(1920, 1080)
	add_child(viewport)
	var panel := preload("res://scenes/ui/GalaxyMap.gd").new()
	viewport.add_child(panel)
	await get_tree().process_frame
	var probes := [
		["fresh-240721-false", "borealis", "boreal_giant"],
		["technology-240721-false", "helios", "ashen"],
		["unlocked-240721-false", "borealis", "frost"],
		["system-borealis-materials_epsilon", "borealis", "boreal_giant"],
		["system-borealis-materials_below", "borealis", "boreal_giant"],
		["colony-boreal_giant-exact-240721-false", "borealis", "boreal_giant"],
		["colony-boreal_giant-fleet_missing-240721-false", "borealis", "boreal_giant"],
		["colony-boreal_giant-remote_only-240721-false", "borealis", "boreal_giant"],
	]
	for probe in probes:
		var row: Dictionary = fixture.cases.filter(func(value): return value.id == probe[0])[0]
		var state: GameState = preload("res://scripts/test/WorldQueryBehaviorRunner.gd")._state(row.input)
		var before: Dictionary = preload("res://scripts/test/WorldQueryBehaviorRunner.gd")._ownership(state)
		var galaxy := GalaxySystem.new(state)
		panel.configure(state, galaxy, PlanetSystem.new(state, galaxy))
		panel._selected_system_id = probe[1]
		panel._selected_planet_id = probe[2]
		panel._refresh_details()
		var expected_system: Dictionary = row.expected.systems.filter(func(value): return value.id == probe[1])[0]
		var expected_planet: Dictionary = row.expected.planets.filter(func(value): return value.id == probe[2])[0]
		if panel._explore_button.disabled == expected_system.canExplore: result.errors.append(probe[0] + ": formal exploration button consumes actual source eligibility")
		if panel._colonize_button.disabled == expected_planet.canColonize: result.errors.append(probe[0] + ": formal colonization button consumes actual source eligibility")
		if galaxy.get_planet_summary(probe[2]).colonization.colonized != expected_planet.colonized: result.errors.append(probe[0] + ": formal planet summary consumes actual source ownership")
		if not panel._colonization_summary.text.contains(expected_planet.requirements.reason): result.errors.append(probe[0] + ": formal colonization details show actual source reason")
		if preload("res://scripts/test/WorldQueryBehaviorRunner.gd")._ownership(state) != before: result.errors.append(probe[0] + ": formal query UI preserves raw and canonical ownership")
	viewport.queue_free()
	await get_tree().process_frame
