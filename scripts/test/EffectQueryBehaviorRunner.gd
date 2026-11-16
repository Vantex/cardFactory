extends RefCounted

const FIXTURE := "res://tests/fixtures/parity/behavior/task27-effect-queries.json"
const FUNCTIONS := ["getMiningSpeedMultiplier", "getInfiniteResourceCollectionSpeedMultiplier", "getVeinConsumptionMultiplier", "getLogisticsSpeedMultiplier", "getRayReceiverCapacityKw", "getDysonSailAbsorptionMultiplier", "getIndustrialEfficiencyMultiplier", "getRecipeSpeedMultiplier"]
const FINITE := ["research_speed_1", "research_speed_2", "research_speed_3", "mining_speed_1", "mining_speed_2", "mining_speed_3", "logistics_engine_1", "logistics_engine_2", "ray_transmission_1", "ray_transmission_2", "dyson_absorption_1"]
const INFINITE := ["matrix_compression", "vein_utilization", "galactic_logistics", "stellar_harnessing"]
const LEVELS := [1, 2, 9, 10, 11, 99, 999, 1000]
var errors: Array[String] = []
var claims := {}

func run(fixture_override: Dictionary = {}, after_queries: Callable = Callable()) -> Dictionary:
	errors.clear()
	claims.clear()
	var fixture := DSPOnlineParity.read_json(FIXTURE) if fixture_override.is_empty() else fixture_override
	var source := DSPOnlineParity.read_json(DSPOnlineParity.ROOT + "dsponline_source_catalog.json")
	if fixture.get("source_commit") != source.source.commit or not fixture.get("source_files") is Dictionary: return _reject("effect query provenance missing")
	for file in ["src/game/engine.ts", "src/game/content.ts", "src/game/endgame.ts", "src/game/difficulty.ts"]:
		if not fixture.source_files.has(file): return _reject("effect query source module missing")
	for file in fixture.source_files:
		if fixture.source_files[file] != source.source.files.get(file): return _reject("effect query source hash drift")
	if fixture.get("functions") != FUNCTIONS or fixture.get("infinite") != INFINITE: return _reject("effect endpoint or independent infinite coverage missing")
	var recipes: Array = source.catalog.recipes.map(func(row): return row.id)
	recipes.append_array(["unknown_recipe", ""])
	var controls := preload("res://scripts/test/WorldControlBehaviorRunner.gd")
	if not fixture.get("recipes") is Array or not controls._same_ids(fixture.recipes, recipes): return _reject("effect recipe IDs missing or duplicated")
	var expected_inputs := _inputs(source.catalog.technologies.map(func(row): return row.id))
	if not fixture.get("cases") is Array or not controls._same_ids(fixture.cases.map(func(row): return row.get("id")), expected_inputs.keys()): return _reject("effect query cases missing or duplicated")
	for row in fixture.cases:
		if not row.get("input") is Dictionary or not row.input.get("completed") is Array: return _reject("effect query controlled input missing: " + row.id)
		var declared: Dictionary = expected_inputs[row.id]
		if row.input.size() != declared.size() or row.input.get("difficulty") != declared.difficulty or not _levels_match(row.input.get("levels"), declared.levels) or not controls._same_ids(row.input.completed, declared.completed): return _reject("effect query controlled input changed: " + row.id)
		if not row.get("expected") is Dictionary: return _reject("effect query expected output missing")
		for function in FUNCTIONS:
			if function == "getRecipeSpeedMultiplier": continue
			if not _number(row.expected.get(function)): return _reject("effect query expected scalar malformed")
		if not row.expected.get("getRecipeSpeedMultiplier") is Array or not controls._same_ids(row.expected.getRecipeSpeedMultiplier.map(func(value): return value.get("id")), recipes): return _reject("effect query recipe output rows incomplete")
		for recipe in row.expected.getRecipeSpeedMultiplier:
			if not _number(recipe.get("value")): return _reject("effect query recipe value malformed")
		if not _number(row.expected.get("undefinedRecipeSpeed")): return _reject("effect query omitted recipe output missing")
	for row in fixture.cases:
		var state := _state(row.input)
		var before := _ownership(state)
		var difficulty := GameModeSystem.new(state)
		var actual := {
			"getMiningSpeedMultiplier": SourceTechnologyEffects.multiplier(state, "mining_speed") * difficulty.multiplier("mining"),
			"getInfiniteResourceCollectionSpeedMultiplier": SourceTechnologyEffects.multiplier(state, "resource_collection"),
			"getVeinConsumptionMultiplier": SourceTechnologyEffects.multiplier(state, "vein_consumption"),
			"getLogisticsSpeedMultiplier": SourceTechnologyEffects.multiplier(state, "logistics_speed") * difficulty.multiplier("logistics"),
			"getRayReceiverCapacityKw": DysonSphereSystem.new(state).receiver_capacity("dsp_ray_receiver"),
			"getDysonSailAbsorptionMultiplier": SourceTechnologyEffects.multiplier(state, "sail_absorption"),
			"getIndustrialEfficiencyMultiplier": SourceTechnologyEffects.multiplier(state, "production_speed"),
		}
		for function in actual: _check(function, _same(actual[function], row.expected[function]), row.id + ": actual effect and difficulty providers match source")
		for recipe in row.expected.getRecipeSpeedMultiplier:
			var value := SourceTechnologyEffects.multiplier(state, "research_speed" if recipe.id == "matrix_research" else "production_speed") * difficulty.multiplier("production")
			_check("getRecipeSpeedMultiplier", _same(value, recipe.value), row.id + ": recipe " + recipe.id + " uses actual research or production provider")
		_check("getRecipeSpeedMultiplier", _same(SourceTechnologyEffects.multiplier(state, "production_speed") * difficulty.multiplier("production"), row.expected.undefinedRecipeSpeed), row.id + ": omitted recipe uses ordinary production effect")
		if after_queries.is_valid(): after_queries.call(row.id, state)
		var unchanged := _ownership(state) == before
		for function in FUNCTIONS: _check(function, unchanged, row.id + ": queries preserve all raw and canonical state")
	var keys := []
	var proofs := {}
	for key in claims:
		if claims[key].failures.is_empty():
			keys.append(key)
			proofs[key] = {"suite": "task27-effect-queries", "fixture": FIXTURE, "fixture_sha256": FileAccess.get_sha256(FIXTURE), "assertions": claims[key].assertions.duplicate()}
	keys.sort()
	return {"errors": errors.duplicate(), "verified_keys": keys, "proofs": proofs, "claims": claims.duplicate(true)}

static func _inputs(technologies: Array) -> Dictionary:
	var stages := [{"id": "none", "completed": [], "levels": {}}, {"id": "all_finite", "completed": technologies, "levels": {}}]
	for id in FINITE: stages.append({"id": "finite-" + id, "completed": [id], "levels": {}})
	stages.append({"id": "noncontiguous_finite", "completed": ["research_speed_1", "research_speed_3", "mining_speed_1", "mining_speed_3", "ray_transmission_2", "logistics_engine_2"], "levels": {}})
	for id in INFINITE:
		for level in LEVELS: stages.append({"id": "infinite-%s-%d" % [id, level], "completed": [], "levels": {id: level}})
	var combined := [{"matrix_compression": 1, "vein_utilization": 9, "galactic_logistics": 11, "stellar_harnessing": 99}, {"matrix_compression": 999, "vein_utilization": 10, "galactic_logistics": 2, "stellar_harnessing": 1000}, {"matrix_compression": 1000, "vein_utilization": 1000, "galactic_logistics": 1000, "stellar_harnessing": 1000}]
	for index in range(combined.size()): stages.append({"id": "combined-" + str(index), "completed": technologies, "levels": combined[index]})
	var result := {}
	for difficulty in ["relaxed", "standard", "hard"]:
		for stage in stages:
			var levels := {}
			for id in INFINITE: levels[id] = stage.levels.get(id, 0)
			result[difficulty + "-" + stage.id] = {"difficulty": difficulty, "completed": stage.completed, "levels": levels}
	return result

static func _state(input: Dictionary) -> GameState:
	var state := GameState.new()
	state.difficulty = input.difficulty
	state.completed_technologies = input.completed.map(func(id): return "dsp_" + String(id))
	state.progression_facts["infinite_research"] = {}
	for id in input.levels: state.progression_facts.infinite_research[id] = {"level": int(input.levels[id]), "invested": "0"}
	return state

static func _ownership(state: GameState) -> Dictionary:
	return {"raw": _raw_fields(state, {}), "canonical": GameStateCodec.to_persistent_dict(state.copy_state())}

static func _raw_fields(object: RefCounted, seen: Dictionary) -> Dictionary:
	var identity := str(object.get_instance_id())
	if seen.has(identity): return {"reference": identity}
	seen[identity] = true
	var fields := {}
	for property in object.get_property_list():
		if (int(property.usage) & PROPERTY_USAGE_SCRIPT_VARIABLE) == 0: continue
		var value: Variant = object.get(property.name)
		if value is RefCounted: fields[property.name] = _raw_fields(value, seen)
		else: fields[property.name] = value.duplicate(true) if value is Dictionary or value is Array else value
	return {"instance_id": identity, "fields": fields}

static func _ownership_rejections() -> Array[String]:
	var failures: Array[String] = []
	for kind in ["enabled", "undo", "redo", "group", "depth", "spatial_clear", "spatial_move", "history_replace", "spatial_replace"]:
		var state := GameState.new()
		state.command_history.undo_entries.append({"label": "undo sentinel", "changes": [{"path": ["buildings", "sentinel", "position"], "before": Vector2.ZERO, "after": Vector2.ONE}]})
		state.command_history.redo_entries.append({"label": "redo sentinel", "changes": []})
		state.command_history._group_before = {"buildings": {"sentinel": {"position": Vector2.ONE}}}
		state.command_history._group_label = "nonempty group"
		state._spatial_index.add_entity("sentinel", Vector2(300, 500))
		var before := _ownership(state)
		if _ownership(state) != before: failures.append("unchanged nested ownership is stable: " + kind)
		match kind:
			"enabled": state.command_history.enabled = false
			"undo": state.command_history.undo_entries.clear()
			"redo": state.command_history.redo_entries.clear()
			"group": state.command_history._group_before.buildings.sentinel.position = Vector2.ZERO
			"depth": state.command_history._depth += 1
			"spatial_clear": state._spatial_index.clear()
			"spatial_move": state._spatial_index.update_entity("sentinel", Vector2(300, 500), Vector2(900, 100))
			"history_replace": state.command_history = CommandHistory.new()
			"spatial_replace": state._spatial_index = SpatialIndex.new()
		if _ownership(state) == before: failures.append("nested ownership mutation must be rejected: " + kind)
	return failures

static func _number(value: Variant) -> bool:
	return (value is int or value is float) and is_finite(float(value))

static func _levels_match(value: Variant, expected: Dictionary) -> bool:
	if not value is Dictionary or value.size() != expected.size(): return false
	for id in expected:
		var level: Variant = value.get(id)
		if not _number(level) or level < 0 or level > 1000 or floorf(float(level)) != float(level) or float(level) != float(expected[id]): return false
	return true

static func _same(left: float, right: float) -> bool:
	return absf(left - right) <= maxf(1.0, absf(right)) * 1.0e-12

func _check(function: String, ok: bool, assertion: String) -> void:
	var key := "commands:engine." + function
	if not claims.has(key): claims[key] = {"assertions": [], "failures": []}
	claims[key].assertions.append(assertion)
	if not ok:
		claims[key].failures.append(assertion)
		errors.append(key + ": " + assertion)

func _reject(message: String) -> Dictionary:
	return {"errors": [message], "verified_keys": [], "proofs": {}, "claims": {}}
