extends Node

func _ready() -> void:
	var runner := preload("res://scripts/test/EffectQueryBehaviorRunner.gd")
	var result: Dictionary = runner.new().run()
	result.errors.append_array(preload("res://scripts/test/EffectQueryBehaviorRunner.gd")._ownership_rejections())
	var fixture := DSPOnlineParity.read_json(runner.FIXTURE)
	for kind in ["source", "missing", "duplicate", "input", "sub_epsilon", "negative_epsilon", "recipe"]:
		var broken := fixture.duplicate(true)
		match kind:
			"source": broken.source_files["src/game/engine.ts"] = "wrong"
			"missing": broken.cases.pop_back()
			"duplicate": broken.cases.append(broken.cases[0].duplicate(true))
			"input": broken.cases[0].input.levels.vein_utilization = 0.5
			"sub_epsilon": broken.cases[0].input.levels.vein_utilization = 5.0e-10
			"negative_epsilon": broken.cases[0].input.levels.vein_utilization = -5.0e-10
			"recipe": broken.cases[0].expected.getRecipeSpeedMultiplier.pop_back()
		var rejected: Dictionary = runner.new().run(broken)
		if rejected.errors.is_empty() or not rejected.verified_keys.is_empty(): result.errors.append("effect " + kind + " drift withholds all keys")
	var broken := fixture.duplicate(true)
	broken.cases[0].expected.getMiningSpeedMultiplier += 1
	var rejected: Dictionary = runner.new().run(broken)
	if rejected.errors.is_empty() or rejected.verified_keys.size() != 7 or rejected.verified_keys.has("commands:engine.getMiningSpeedMultiplier"): result.errors.append("incorrect source mining output withholds exactly its endpoint")
	rejected = runner.new().run({}, func(_id, state): state.planet_inventory.iron_ore = float(state.planet_inventory.get("iron_ore", 0)) + 1)
	if rejected.errors.is_empty() or not rejected.verified_keys.is_empty(): result.errors.append("query inventory mutation withholds every endpoint")
	rejected = runner.new().run({}, func(id, state):
		if id == "relaxed-none": state.command_history.enabled = false)
	if rejected.errors.is_empty() or not rejected.verified_keys.is_empty(): result.errors.append("nested object mutation withholds all 8 query endpoints")
	for error in result.errors.slice(0, 20): printerr("FAIL: " + error)
	print("EFFECT QUERY ERRORS: ", result.errors.size(), "; actual keys: ", result.verified_keys.size(), "; states: ", fixture.cases.size())
	print("PARITY EFFECT QUERY TESTS PASSED" if result.errors.is_empty() else "PARITY EFFECT QUERY TESTS FAILED")
	get_tree().quit(0 if result.errors.is_empty() else 1)
