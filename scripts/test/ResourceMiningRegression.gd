extends RefCounted

const FIXTURES := {
	"default": "res://tests/fixtures/parity/behavior/task27-mining-default.json",
	"live60": "res://tests/fixtures/parity/behavior/task27-mining-live60.json",
}
const CANONICAL := {
	"default": "18d64758777350750630f3988430c3288dd3d9611c55c8b49edae8df9eadb5c4",
	"live60": "0fc7858d09fc20151f17482f05f9fba1e7b94c0cbf08b3c745ea0c0d1a8241fe",
}

func run() -> Dictionary:
	var errors := []
	var cases := 0
	for mode in ["default", "live60"]:
		var fixture := DSPOnlineParity.read_json(FIXTURES[mode])
		var validation := validation_errors(fixture, mode)
		if not validation.is_empty():
			errors.append_array(validation)
			continue
		var differences := 0
		var failures := []
		var by_field := {}
		for row in fixture.cases:
			var state := GameState.new()
			state.emit_canvas_events = false
			SourceGalaxySystem.new(state).initialize(240721, false)
			state.completed_technologies = DataManager.all_technologies.keys().filter(func(id): return String(id).begins_with("dsp_"))
			state.progression_facts.infinite_research = {"vein_utilization": {"level": int(row.input.level), "invested": "0"}}
			var planets := PlanetSystem.new(state)
			planets.ensure_colonized_planet_records(row.input.planet)
			state.set_active_planet(row.input.planet)
			planets.initialize_colonized_resource_sites()
			var site: Dictionary = {}
			for candidate in planets.get_planet_resource_sites(row.input.planet):
				if candidate.item_id == row.input.item:
					site = candidate
					break
			if site.is_empty():
				differences += 1
				if failures.size() < 12: failures.append({"id": row.id, "reason": "actual resource site missing"})
				continue
			var type := "dsp_" + String(row.input.extractor)
			state.construction_inventory[type] = 1
			var placed := state.try_place_building(type, site.position)
			if not placed.ok or state.construction_inventory[type] != 0:
				differences += 1
				if failures.size() < 12: failures.append({"id": row.id, "reason": "actual paid count-one placement failed"})
				continue
			var building: Dictionary = state.buildings[placed.id]
			site = state.resource_sites[building.resource_site_id]
			# Counts, power, resource mode and reserves are controlled numeric inputs.
			# Actual grouped commands and public resource-mode acceptance are separate.
			building.machine_count = row.input.count
			building.power_efficiency = 0.0 if row.input.stage == "unpowered" else 1.0
			building.output_buffer = {row.input.item: row.input.output}
			building.progress = row.input.progress
			site.remaining = row.input.remaining
			site.capacity = row.input.capacity
			site.depletion_remainder = row.input.remainder
			site.infinite = site.infinite or row.input.mode == "infinite"
			var production := ProductionSystem.new(state, StatisticsSystem.new(state))
			if mode == "live60":
				for tick in range(int(row.input.fixed_ticks)): production.update(1.0 / 60)
			else:
				var remaining := float(row.input.seconds)
				while remaining > 0.0000001:
					var step := minf(1.0, remaining)
					production.update(step)
					remaining -= step
			var actual := {
				"output": building.output_buffer.get(row.input.item, 0),
				"progress": building.progress,
				"remaining": site.remaining,
				"remainder": site.depletion_remainder,
				"power_factor": building.power_efficiency,
				"utilization": building.get("production_utilization", 0),
				"production_rate": building.get("last_production_per_minute", 0),
				"total_produced": state.progression_facts.get("produced", {}).get(row.input.item, 0),
			}
			var mismatches := []
			for field in actual:
				if not numbers_match(actual[field], row.expected[field]):
					mismatches.append(field)
					by_field[field] = int(by_field.get(field, 0)) + 1
			if not mismatches.is_empty():
				differences += 1
				if failures.size() < 12: failures.append({"id": row.id, "fields": mismatches, "actual": actual, "expected": row.expected})
		print("RESOURCE MINING ", mode, " DIFFERENCES: ", differences, "/", fixture.cases.size(), "; by field: ", JSON.stringify(by_field), "; examples: ", JSON.stringify(failures))
		if differences > 0: errors.append("source mining " + mode + " numeric mismatches: " + str(differences))
		cases += fixture.cases.size() - differences
	return {"errors": errors, "cases": cases}

static func numbers_match(actual: Variant, expected: Variant) -> bool:
	return preload("res://scripts/test/EffectQueryBehaviorRunner.gd")._number(actual) and absf(float(actual) - float(expected)) <= 0.00001

static func validation_errors(fixture: Dictionary, mode: String) -> Array[String]:
	if not CANONICAL.has(mode): return ["unknown mining cadence"]
	# Pin all input/output values, numeric types, shapes and the complete case grid.
	# The digests bind the independently repeated frozen-source exports.
	if JSON.stringify(fixture, "", true, true).sha256_text() != CANONICAL[mode]: return ["mining frozen corpus changed: " + mode]
	var source := DSPOnlineParity.read_json(DSPOnlineParity.ROOT + "dsponline_source_catalog.json")
	if fixture.source_commit != source.source.commit: return ["mining frozen source commit drift"]
	var exact := preload("res://scripts/test/CapacityQueryBehaviorRunner.gd")
	if not preload("res://scripts/test/WorldControlBehaviorRunner.gd")._same_ids(fixture.source_files.keys(), exact.SOURCE_MODULES): return ["mining source module set drift"]
	for file in exact.SOURCE_MODULES:
		if fixture.source_files[file] != source.source.files.get(file): return ["mining frozen source hash drift"]
	if fixture.cases.size() != 5760: return ["mining full case grid missing"]
	return []

static func rejection_errors() -> Dictionary:
	var errors := []
	var rejections := 0
	for invalid in [true, false, "0", null, NAN, INF, -INF, 0.00002]:
		if numbers_match(invalid, 0): errors.append("mining numeric comparison accepts invalid provider value")
	if not numbers_match(0, 0) or not numbers_match(0.0, 0): errors.append("mining numeric comparison rejects valid numeric zero")
	for mode in ["default", "live60"]:
		var fixture := DSPOnlineParity.read_json(FIXTURES[mode])
		for kind in ["commit", "source", "module", "environment", "resources", "counts", "levels", "modes", "seconds", "stages", "missing", "duplicate", "row", "id", "item", "planet", "entity", "extractor", "count_bool", "count_fraction", "level", "mode", "stage", "remaining", "capacity", "remainder", "output", "progress", "output_shape", "output_bool", "returned_progress", "reserve"]:
			var broken := fixture.duplicate(true)
			match kind:
				"commit": broken.source_commit = "wrong"
				"source": broken.source_files["src/game/engine.ts"] = "wrong"
				"module": broken.source_files.erase("src/game/galaxyCatalog.ts")
				"environment": broken.source_environment.DEV = true
				"resources": broken.resources.pop_back()
				"counts": broken.counts[0] = true
				"levels": broken.levels.pop_back()
				"modes": broken.modes[0] = "unknown"
				"seconds": broken.seconds[0] = 0.5
				"stages": broken.stages.pop_back()
				"missing": broken.cases.pop_back()
				"duplicate": broken.cases.append(broken.cases[0].duplicate(true))
				"row": broken.cases[0] = []
				"id": broken.cases[0].id = "missing"
				"item": broken.cases[0].input.item = "water"
				"planet": broken.cases[0].input.planet = "giant"
				"entity": broken.cases[0].input.entity = "missing"
				"extractor": broken.cases[0].input.extractor = "water_pump"
				"count_bool": broken.cases[0].input.count = true
				"count_fraction": broken.cases[0].input.count = 1.0000000005
				"level": broken.cases[0].input.level = 2
				"mode": broken.cases[0].input.mode = "infinite"
				"stage": broken.cases[0].input.stage = "depleted"
				"remaining": broken.cases[0].input.remaining = -1
				"capacity": broken.cases[0].input.capacity = "100"
				"remainder": broken.cases[0].input.remainder = 0.5
				"output": broken.cases[0].input.output = false
				"progress": broken.cases[0].input.progress = null
				"output_shape": broken.cases[0].expected.extra = 0
				"output_bool": broken.cases[0].expected.output = false
				"returned_progress": broken.cases[0].expected.progress += 0.0000000005
				"reserve": broken.cases[0].expected.reserve.remaining = null
			if validation_errors(broken, mode).is_empty(): errors.append("mining " + mode + " accepts " + kind + " corpus drift")
			else: rejections += 1
	return {"errors": errors, "rejections": rejections}
