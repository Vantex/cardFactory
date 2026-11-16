extends RefCounted

const FIXTURE := "res://tests/fixtures/parity/behavior/task27-special-production.json"
const SUITE := "task27-dedicated-production"
const STAGES := {
	"matrix_research": ["powered", "starved", "blocked", "unpowered"],
	"solar_sail_launch": ["powered", "starved", "blocked", "locked", "unpowered"],
	"carrier_rocket_launch": ["powered", "starved", "blocked", "locked", "unpowered"],
	"ray_power": ["powered", "starved", "locked"],
	"critical_photon": ["powered", "starved", "blocked", "locked", "near_full", "output_epsilon", "epsilon_completion", "fractional_output"],
	"accumulator_charge": ["powered", "starved", "blocked", "locked", "cycle_boundary", "partial_cell", "near_full", "negligible_cell", "output_epsilon", "epsilon_completion", "fractional_input", "fractional_output"],
	"accumulator_discharge": ["powered", "starved", "blocked", "locked", "cycle_boundary", "partial_cell", "near_full", "negligible_cell", "output_epsilon", "epsilon_completion", "fractional_input", "fractional_output"],
}
var errors: Array[String] = []
var claims := {}

func run(fixture_override: Dictionary = {}) -> Dictionary:
	errors.clear()
	claims.clear()
	var fixture := DSPOnlineParity.read_json(FIXTURE) if fixture_override.is_empty() else fixture_override
	var source := DSPOnlineParity.read_json(DSPOnlineParity.ROOT + "dsponline_source_catalog.json")
	if fixture.get("source_commit") != source.source.commit or not fixture.get("source_files") is Dictionary or not fixture.source_files.has("src/game/engine.ts") or not fixture.source_files.has("src/game/content.ts"):
		return _rejected("dedicated simulation source provenance missing")
	for file in fixture.source_files:
		if fixture.source_files[file] != source.source.files.get(file): return _rejected("dedicated source hash drift")
	if fixture.get("cases", []).size() != 49: return _rejected("dedicated simulation cases incomplete")
	var seen := {}
	for row in fixture.cases:
		if not STAGES.has(row.id) or not STAGES[row.id].has(row.stage) or seen.has(row.id + ":" + row.stage): return _rejected("duplicate or unknown dedicated simulation case")
		seen[row.id + ":" + row.stage] = true
	var definitions := {}
	for row in source.catalog.recipes: definitions[row.id] = row.definition
	for id in STAGES:
		var key: String = "recipes:" + id
		var recipe := DataManager.get_recipe("dsp_" + id)
		var definition: Dictionary = definitions[id]
		_check(key, recipe.get("source_id") == id and recipe.get("building_id") == "dsp_" + definition.buildingId, "exact source recipe identity and primary machine")
		_check(key, recipe.get("duration") == definition.duration and recipe.get("required_source_technology", "") == definition.get("requiredTechId", ""), "source duration and technology prerequisite")
		_check(key, RecipeBehaviorRunner._amounts(recipe.inputs, false) == RecipeBehaviorRunner._amounts(definition.inputs, true) and RecipeBehaviorRunner._amounts(recipe.outputs, false) == RecipeBehaviorRunner._amounts(definition.outputs, true), "complete source material definition")
	for row in fixture.cases:
		var key: String = "recipes:" + row.id
		var setup := _state(row, key)
		var state: GameState = setup.state
		var subject: String = setup.subject
		var simulation := SimulationEngine.new(state)
		var ticks := roundi(float(row.seconds) * 60)
		for tick in range(ticks): simulation.update(1.0 / 60.0)
		var actual: Dictionary = state.buildings[subject]
		var expected: Dictionary = row.expected.subject
		var label: String = row.stage
		_materials(row, actual, expected, key)
		var duration := float(DataManager.get_recipe(actual.recipe_id).duration)
		var phase := float(actual.get("progress", 0)) / duration
		if row.id in ["solar_sail_launch", "carrier_rocket_launch"]: phase = float(actual.dyson.progress) / duration
		if row.id in ["accumulator_charge", "accumulator_discharge"]:
			var stored := float(actual.get("stored_energy_mj", 0))
			phase = (stored if row.id == "accumulator_charge" else 90.0 - stored) / 90.0 if stored > PowerGridSystem.SOURCE_ENERGY_EPSILON else 0.0
			_check(key, is_equal_approx(stored, float(expected.storedEnergyMj)), label + ": partial cell energy conserved")
			_check(key, absf(float(actual.progress) / duration - float(expected.progress)) <= float(row.phase_rounding_bound), label + ": visible conversion phase follows stored energy")
		_check(key, absf(phase - float(expected.progress)) <= float(row.phase_rounding_bound), label + ": normalized phase within source rounding bound", "actual=" + str(phase) + " expected=" + str(expected.progress))
		for fields in [["powerOutputKw", "power_output"], ["powerInputKw", "power_input"], ["productionRate", "last_production_per_minute"], ["utilization", "production_utilization"]]:
			if expected.has(fields[0]): _check(key, is_equal_approx(float(actual.get(fields[1], 0)), float(expected[fields[0]])), label + ": " + fields[0], "actual=" + str(actual.get(fields[1], 0)) + " expected=" + str(expected[fields[0]]))
		if setup.has("peer"):
			for fields in [["powerOutputKw", "power_output"], ["productionRate", "last_production_per_minute"], ["utilization", "production_utilization"]]:
				_check(key, is_equal_approx(float(state.buildings[setup.peer].get(fields[1], 0)), float(row.expected.peer.get(fields[0], 0))), label + ": active peer " + fields[0])
		if row.id == "critical_photon" and row.stage == "blocked": _check(key, actual.status == "blocked", "blocked: full photon buffer has blocked status")
		if row.id == "matrix_research":
			var current := "" if row.expected.research.selectedTechId == null else "dsp_" + String(row.expected.research.selectedTechId)
			var selected := "" if state.research_paused else state.research_current_id
			_check(key, selected == current and PlanningBehaviorRunner.same(state.research_invested_costs.get("dsp_basic_logistics", {}), row.expected.research.progressByTech.get("basic_logistics", {})), label + ": selected finite research and actual invested matrices")
		if row.id in ["solar_sail_launch", "carrier_rocket_launch"]:
			var summary := DysonSphereSystem.new(state).get_summary(row.input.system_id)
			var sails := 0
			for orbit in row.expected.orbits: sails += int(orbit.sailsInOrbit)
			_check(key, int(summary.live_sails) == sails and int(summary.structure_points) == int(row.expected.dyson_plan.structurePoints), label + ": ammo reaches actual stellar material ledger")
		var payload := GameStateCodec.to_persistent_dict(state)
		var restored := GameStateCodec.from_persistent_dict(payload)
		_check(key, restored != null and GameStateCodec.to_persistent_dict(restored) == payload, label + ": validated partial-cycle save round trip")
		if row.stage in ["powered", "cycle_boundary", "partial_cell", "negligible_cell", "epsilon_completion", "fractional_input", "fractional_output"]: _resume(row, key, ticks, payload)
	var keys: Array[String] = []
	var proofs := {}
	for key in claims:
		if claims[key].failures.is_empty():
			keys.append(key)
			proofs[key] = {"suite": SUITE, "fixture": FIXTURE, "fixture_sha256": FileAccess.get_sha256(FIXTURE), "assertions": claims[key].assertions.duplicate()}
	keys.sort()
	return {"errors": errors.duplicate(), "verified_keys": keys, "proofs": proofs, "claims": claims.duplicate(true)}

func _materials(row: Dictionary, actual: Dictionary, expected: Dictionary, key: String) -> void:
	var inputs: Dictionary = actual.input_buffer.duplicate(true)
	var outputs: Dictionary = actual.output_buffer.duplicate(true)
	if row.stage in ["fractional_input", "fractional_output"]:
		var initial: Dictionary = row.input.subject.inputs if row.stage == "fractional_input" else row.input.subject.outputs
		var buffer: Dictionary = inputs if row.stage == "fractional_input" else outputs
		for item in initial:
			var before_fraction := float(initial[item]) - floorf(float(initial[item]))
			var after_fraction := float(buffer.get(item, 0)) - floorf(float(buffer.get(item, 0)))
			_check(key, absf(before_fraction - after_fraction) <= 0.000000000001, row.stage + ": owned transport fraction conserved: " + String(item))
			buffer[item] = floorf(float(buffer.get(item, 0)))
		_check(key, _difference(inputs, expected.inputs).is_empty() and _difference(outputs, expected.outputs).is_empty(), row.stage + ": whole cell projection matches unchanged source gold")
	else:
		_check(key, _difference(inputs, expected.inputs).is_empty() and _difference(outputs, expected.outputs).is_empty(), row.stage + ": exact material consumption and output", "actual=" + str([actual.input_buffer, actual.output_buffer]) + " expected=" + str([expected.inputs, expected.outputs]))

func _state(row: Dictionary, key: String) -> Dictionary:
	var state := GameState.new()
	SourceGalaxySystem.new(state).initialize(240721)
	PlanetSystem.new(state).initialize_colonized_resource_sites()
	for tech in row.input.completed_technologies: state.completed_technologies.append("dsp_" + tech)
	for index in range(int(row.input.wind_count)): state.add_building({"type": "dsp_wind_turbine", "position": Vector2(index * 100, -100), "input_buffer": {}, "output_buffer": {}})
	if row.input.consumer != null:
		var consumer: Dictionary = row.input.consumer
		for index in range(int(consumer.machineCount)):
			state.add_building({"type": "dsp_arc_smelter", "recipe_id": "dsp_" + consumer.recipeId, "position": Vector2(index * 100, 100), "speed": 1.0, "input_buffer": {"iron_ore": float(consumer.inputs.iron_ore) / float(consumer.machineCount)}, "output_buffer": {}, "progress": 0.0})
	var source: Dictionary = row.input.subject
	var building := {"type": "dsp_" + source.buildingId, "recipe_id": "", "position": Vector2(200, 0), "speed": 1.0, "input_buffer": {}, "output_buffer": {}, "progress": 0.0}
	var subject := state.add_building(building)
	var recipe := DataManager.get_recipe("dsp_" + source.recipeId)
	var prerequisite := "dsp_" + String(recipe.get("required_source_technology", ""))
	var temporarily_unlocked := not state.completed_technologies.has(prerequisite) and prerequisite != "dsp_"
	if temporarily_unlocked: state.completed_technologies.append(prerequisite)
	if row.id == "accumulator_discharge": _check(key, state.set_energy_mode(subject, "discharge"), row.stage + ": actual discharge command selected")
	else: _check(key, state.set_entity_recipe(subject, "dsp_" + source.recipeId), row.stage + ": actual dedicated recipe command selected")
	if temporarily_unlocked: state.completed_technologies.erase(prerequisite)
	if row.input.get("mode_transition") is Dictionary:
		var transition: Dictionary = row.input.mode_transition
		building.energy_mode = transition.before.energyMode
		building.recipe_id = "dsp_" + transition.before.recipeId
		building.input_buffer = transition.before.inputs.duplicate(true)
		building.output_buffer = transition.before.outputs.duplicate(true)
		building.stored_energy_mj = float(transition.before.storedEnergyMj)
		building.progress = float(transition.before.progress) * float(recipe.duration)
		_check(key, state.set_energy_mode(subject, transition.requested_mode), row.stage + ": actual negligible cell mode transition")
		_check(key, building.input_buffer == source.inputs and building.output_buffer == source.outputs and building.progress == 0, row.stage + ": transition clears source buffers and phase")
	building.input_buffer = source.inputs.duplicate(true)
	building.output_buffer = source.outputs.duplicate(true)
	if row.id in ["accumulator_charge", "accumulator_discharge"]: building.stored_energy_mj = float(source.get("storedEnergyMj", 0))
	var dyson := DysonSphereSystem.new(state)
	if row.id in ["ray_power", "critical_photon"]:
		var system := SourceDysonEngineering.new(state).ensure(row.input.system_id)
		system.source_plan.structure_points = int(row.input.dyson_plan.structurePoints)
		system.rockets_launched = int(row.input.dyson_plan.structurePoints)
	if row.id in ["solar_sail_launch", "carrier_rocket_launch"]:
		var orbit := dyson.create_orbit(row.input.system_id)
		_check(key, orbit.ok, row.stage + ": real local stellar orbit")
		var target: String = orbit.id
		if row.id == "carrier_rocket_launch":
			var layer := SourceDysonEngineering.new(state).standard_layer(row.input.system_id, orbit.id, 3)
			_check(key, layer.ok, row.stage + ": real local standard rocket layer")
			target = layer.id
		_check(key, dyson.configure_launcher(subject, target).ok, row.stage + ": actual launcher configured")
		_check(key, SourceDysonEngineering.new(state).configure_schedule(row.input.dyson_engineering.launchMode, row.input.dyson_engineering.launchThrottle, row.input.dyson_engineering.launchEnabled).ok, row.stage + ": actual global launch schedule")
	if row.id == "matrix_research":
		var research := TechnologySystem.new(state)
		_check(key, research.start_research("dsp_basic_logistics"), row.stage + ": actual finite research selected")
		if row.input.research.selectedTechId == null: _check(key, research.pause_research(), row.stage + ": actual finite research paused")
	var result := {"state": state, "subject": subject}
	if row.input.get("peer") is Dictionary:
		var peer: Dictionary = row.input.peer
		var peer_id := state.add_building({"type": "dsp_" + peer.buildingId, "recipe_id": "", "position": Vector2(400, 0), "speed": 1.0, "input_buffer": {}, "output_buffer": {}, "progress": 0.0})
		_check(key, state.set_entity_recipe(peer_id, "dsp_" + peer.recipeId), row.stage + ": actual peer power recipe command")
		result.peer = peer_id
	return result

func _resume(row: Dictionary, key: String, ticks: int, expected_payload: Dictionary) -> void:
	var setup := _state(row, key)
	var state: GameState = setup.state
	var simulation := SimulationEngine.new(state)
	var halfway := ticks / 2
	for tick in range(halfway): simulation.update(1.0 / 60.0)
	var before := GameStateCodec.to_persistent_dict(state)
	var saves := SaveSystem.new("res://.godot/task27-special-saves-%d/" % Time.get_ticks_usec())
	var saved := saves.save_slot(0, state)
	var loaded := saves.load_slot(0) if saved.ok else {}
	_check(key, saved.ok and loaded.get("ok", false), row.stage + ": real mid-cycle disk save and load")
	if not loaded.get("ok", false): return
	var resumed: GameState = loaded.state
	var saved_difference := _difference(GameStateCodec.to_persistent_dict(resumed), before)
	_check(key, saved_difference.is_empty(), row.stage + ": saved partial state preserves all persistent ownership", saved_difference)
	var replay := SimulationEngine.new(resumed)
	for tick in range(ticks - halfway): replay.update(1.0 / 60.0)
	var replay_difference := _difference(GameStateCodec.to_persistent_dict(resumed), expected_payload)
	_check(key, replay_difference.is_empty(), row.stage + ": disk resume equals uninterrupted persistent simulation", replay_difference)

static func _difference(actual: Variant, expected: Variant, path: String = "state") -> String:
	if actual is Dictionary and expected is Dictionary:
		if actual.size() != expected.size(): return path + ": different keys"
		for field in expected:
			if not actual.has(field): return path + ": missing " + str(field)
			var difference := _difference(actual[field], expected[field], path + "." + str(field))
			if not difference.is_empty(): return difference
	elif actual is Array and expected is Array:
		if actual.size() != expected.size(): return path + ": different lengths"
		for index in range(expected.size()):
			var difference := _difference(actual[index], expected[index], path + "[" + str(index) + "]")
			if not difference.is_empty(): return difference
	elif (actual is float or actual is int) and (expected is float or expected is int):
		# JSON changes number types and may round the last binary digit.
		if actual == expected or absf(float(actual) - float(expected)) <= minf(0.000000001, 0.00000000000001 * maxf(1.0, absf(float(expected)))): return ""
		return path + ": actual=" + str(actual) + " expected=" + str(expected)
	elif actual != expected:
		return path + ": actual=" + str(actual) + " (type " + str(typeof(actual)) + ") expected=" + str(expected) + " (type " + str(typeof(expected)) + ")"
	return ""

static func _rejected(message: String) -> Dictionary:
	return {"errors": [message], "verified_keys": [], "proofs": {}, "claims": {}}

func _check(key: String, ok: bool, assertion: String, detail: String = "") -> void:
	if not claims.has(key): claims[key] = {"assertions": [], "failures": []}
	claims[key].assertions.append(assertion)
	if not ok:
		claims[key].failures.append(assertion)
		errors.append(key + ": " + assertion + ("; " + detail if not detail.is_empty() else ""))
