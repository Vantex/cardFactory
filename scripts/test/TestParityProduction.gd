extends Node

var _failures := 0

func _ready() -> void:
	print("PARITY PRODUCTION TESTS STARTED")
	var fixture := DSPOnlineParity.read_json("res://tests/fixtures/parity/behavior/task27-production.json")
	var source := DSPOnlineParity.read_json(DSPOnlineParity.ROOT + "dsponline_source_catalog.json")
	_expect(fixture.get("source_commit") == source.source.commit and fixture.get("cases", []).size() == 73, "73 frozen material-conversion cases")
	for file in fixture.source_files: _expect(fixture.source_files[file] == source.source.files.get(file), "production source hash: " + String(file))
	for row in fixture.cases:
		_check_conversion(row, source)
	var industrial := DSPOnlineParity.read_json("res://tests/fixtures/parity/behavior/task27-industrial.json")
	_expect(industrial.get("source_commit") == source.source.commit and industrial.get("cases", []).size() == 12, "12 frozen industrial planet cases")
	for file in industrial.source_files: _expect(industrial.source_files[file] == source.source.files.get(file), "industrial source hash: " + String(file))
	for row in industrial.cases:
		var adapted: Dictionary = row.duplicate(true)
		adapted.id = row.recipe_id
		_check_conversion(adapted, source, row.id)
	if _failures > 0:
		printerr("PARITY PRODUCTION TESTS FAILED")
		get_tree().quit(1)
	else:
		print("PARITY PRODUCTION TESTS PASSED")
		get_tree().quit(0)

func _check_conversion(row: Dictionary, source: Dictionary, label: String = "") -> void:
		if label.is_empty(): label = row.id
		var state := GameState.new()
		SourceGalaxySystem.new(state).initialize(240721)
		for tech in source.catalog.technologies: state.completed_technologies.append("dsp_" + tech.id)
		var building_id := state.add_building({"type": "dsp_" + row.input.buildingId, "recipe_id": "dsp_" + row.id, "position": Vector2.ZERO, "planet_id": row.input.planetId, "speed": DataManager.get_building("dsp_" + row.input.buildingId).speed, "input_buffer": row.input.inputs.duplicate(true), "output_buffer": row.input.outputs.duplicate(true), "power_efficiency": 1.0})
		var system := ProductionSystem.new(state)
		var remaining := float(row.seconds)
		while remaining > 0.0000001:
			var delta := minf(1.0 / 60.0, remaining)
			system.update(delta)
			remaining -= delta
		var building: Dictionary = state.buildings[building_id]
		_expect(PlanningBehaviorRunner.same(building.input_buffer, row.expected.inputs), label + ": source input consumption; actual=" + str(building.input_buffer) + " expected=" + str(row.expected.inputs))
		_expect(PlanningBehaviorRunner.same(building.output_buffer, row.expected.outputs), label + ": source output conversion; actual=" + str(building.output_buffer) + " expected=" + str(row.expected.outputs))
		var normalized_phase := float(building.get("progress", 0)) / float(DataManager.get_recipe("dsp_" + row.id).duration)
		_expect(absf(normalized_phase - float(row.expected.progress)) <= float(row.phase_rounding_bound), label + ": normalized source phase within source rounding bound; actual=" + str(normalized_phase) + " expected=" + str(row.expected.progress))

func _expect(ok: bool, message: String) -> void:
	if ok: print("PASS: " + message.split(";")[0])
	else:
		_failures += 1
		printerr("FAIL: " + message)
