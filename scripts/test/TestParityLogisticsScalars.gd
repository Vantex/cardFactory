extends Node

func _ready() -> void:
	var runner := preload("res://scripts/test/LogisticsScalarBehaviorRunner.gd")
	var result: Dictionary = runner.new().run()
	result.errors.append_array(preload("res://scripts/test/EffectQueryBehaviorRunner.gd")._ownership_rejections())
	var fixture := DSPOnlineParity.read_json(runner.FIXTURE)
	for kind in ["source", "missing", "duplicate", "sub_epsilon", "negative_epsilon", "bool", "levels", "function"]:
		var broken := fixture.duplicate(true)
		match kind:
			"source": broken.source_files["src/game/engine.ts"] = "wrong"
			"missing": broken.cases.pop_back()
			"duplicate": broken.cases.append(broken.cases[0].duplicate(true))
			"sub_epsilon": broken.cases[0].input.level = 5.0e-10
			"negative_epsilon": broken.cases[0].input.level = -5.0e-10
			"bool": broken.cases[0].input.level = false
			"levels": broken.levels[0] = 5.0e-10
			"function": broken.cases[0].expected.erase("getPlanetaryTripSeconds")
		var rejected: Dictionary = runner.new().run(broken)
		if rejected.errors.is_empty() or not rejected.verified_keys.is_empty(): result.errors.append("logistics scalar " + kind + " drift withholds all keys")
	var broken := fixture.duplicate(true)
	broken.cases[0].expected.getInterstellarCargoCapacity += 1
	var rejected: Dictionary = runner.new().run(broken)
	if rejected.errors.is_empty() or rejected.verified_keys.size() != 2 or rejected.verified_keys.has("commands:engine.getInterstellarCargoCapacity"): result.errors.append("incorrect interstellar capacity withholds exactly its endpoint")
	rejected = runner.new().run({}, func(id, state):
		if id == "standard-0-0": state.research_queue.append("dsp_mining_speed_2"))
	if rejected.errors.is_empty() or not rejected.verified_keys.is_empty(): result.errors.append("raw queue mutation hidden by codec withholds every scalar query")
	rejected = runner.new().run({}, func(id, state):
		if id == "standard-0-0": state._spatial_index.add_entity("query-injected", Vector2(900, 100)))
	if rejected.errors.is_empty() or not rejected.verified_keys.is_empty(): result.errors.append("nested object mutation withholds all 3 query endpoints")
	for error in result.errors.slice(0, 20): printerr("FAIL: " + error)
	print("LOGISTICS SCALAR ERRORS: ", result.errors.size(), "; actual keys: ", result.verified_keys.size(), "; states: ", fixture.cases.size())
	print("PARITY LOGISTICS SCALAR TESTS PASSED" if result.errors.is_empty() else "PARITY LOGISTICS SCALAR TESTS FAILED")
	get_tree().quit(0 if result.errors.is_empty() else 1)
