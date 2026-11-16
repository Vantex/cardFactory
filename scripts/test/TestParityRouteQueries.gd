extends Node

func _ready() -> void:
	var runner := preload("res://scripts/test/RouteQueryBehaviorRunner.gd")
	var result: Dictionary = runner.new().run()
	result.errors.append_array(preload("res://scripts/test/EffectQueryBehaviorRunner.gd")._ownership_rejections())
	var fixture := DSPOnlineParity.read_json(runner.FIXTURE)
	_dispatch_guards(fixture, result.errors)
	result.errors.append_array(_paid_station_persistence())
	for kind in ["source", "module", "noncore_module", "extra_module", "missing", "duplicate", "fraction", "negative", "bool", "profile", "function", "policy", "station", "seed", "vessels", "unlocked"]:
		var broken := fixture.duplicate(true)
		match kind:
			"source": broken.source_files["src/game/engine.ts"] = "wrong"
			"module": broken.source_files.erase("src/game/galaxy.ts")
			"noncore_module": broken.source_files.erase("src/game/galaxyCatalog.ts")
			"extra_module": broken.source_files["src/game/unknown-route-module.ts"] = null
			"missing": broken.cases.pop_back()
			"duplicate": broken.cases.append(broken.cases[0].duplicate(true))
			"fraction": broken.cases[0].input.level = 5.0e-10
			"negative": broken.cases[0].input.level = -5.0e-10
			"bool": broken.cases[0].input.level = false
			"profile": broken.profiles[0].level = 5.0e-10
			"function": broken.cases[0].expected.erase("getInterstellarTripSeconds")
			"policy": broken.cases[0].input.options.routePolicy = "relay-required"
			"station": broken.cases[0].input.stations[0].count += 1
			"seed": broken.cases[0].input.seed = 42
			"vessels": broken.cases[0].input.vessels = 1.0 + 5.0e-10
			"unlocked": broken.cases[0].input.unlocked.pop_back()
		var rejected: Dictionary = runner.new().run(broken)
		if rejected.errors.is_empty() or not rejected.verified_keys.is_empty(): result.errors.append("route query " + kind + " drift withholds all keys")
	var broken := fixture.duplicate(true)
	broken.cases[0].expected.getInterstellarRouteEconomics.durationSeconds += 1
	var rejected: Dictionary = runner.new().run(broken)
	if rejected.errors.is_empty() or rejected.verified_keys != ["commands:engine.getInterstellarTripSeconds"]: result.errors.append("wrong route output withholds exactly route endpoint")
	rejected = runner.new().run({}, func(id, state):
		if id == "240721-false-relaxed-0-0-planet-home": state.research_queue.append("dsp_mining_speed_2"))
	if rejected.errors.is_empty() or not rejected.verified_keys.is_empty(): result.errors.append("raw mutation hidden by codec withholds both route queries")
	rejected = runner.new().run({}, func(id, state):
		if id == "240721-false-relaxed-0-0-planet-home": state.command_history.enabled = false)
	if rejected.errors.is_empty() or not rejected.verified_keys.is_empty(): result.errors.append("nested object mutation withholds all 2 query endpoints")
	_write_evidence(result)
	for error in result.errors.slice(0, 20): printerr("FAIL: " + error)
	print("ROUTE QUERY ERRORS: ", result.errors.size(), "; actual keys: ", result.verified_keys.size(), "; controlled states: ", fixture.cases.size())
	print("PARITY ROUTE QUERY TESTS PASSED" if result.errors.is_empty() else "PARITY ROUTE QUERY TESTS FAILED")
	get_tree().quit(0 if result.errors.is_empty() else 1)

func _write_evidence(result: Dictionary) -> void:
	var path := "res://.godot/task27-route-query-standalone-evidence.json"
	if DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://.godot")) != OK:
		result.errors.append("route query evidence directory creation failed")
		return
	var evidence := FileAccess.open(path, FileAccess.WRITE)
	if evidence == null:
		result.errors.append("route query evidence open failed")
		return
	result.standalone_checks = {"passed": result.errors.is_empty(), "rejections_checked": true, "dispatch_guards_checked": true, "scope": "Controlled query suite and three dispatch guards; no full behavior harness or registration."}
	evidence.store_string(JSON.stringify(result, "\t", true, true))
	var error := evidence.get_error()
	evidence.close()
	if error != OK: result.errors.append("route query evidence write failed")

func _dispatch_guards(fixture: Dictionary, errors: Array) -> void:
	var runner := preload("res://scripts/test/RouteQueryBehaviorRunner.gd")
	var count := 0
	for row in fixture.cases:
		if row.id not in ["240721-false-relaxed-0-0-policy-relay-required-4", "240721-false-relaxed-0-0-hubs-mode-transition", "240721-false-relaxed-0-0-hubs-elevator"]: continue
		count += 1
		var state := runner._state(row.input)
		state.completed_technologies.append_array(["dsp_interstellar_logistics", "dsp_space_warp"])
		for building in state.buildings.values(): building.power_efficiency = 1.0
		var source: Dictionary = state.buildings[row.input.source_id]
		var target: Dictionary = state.buildings[row.input.target_id]
		for building in [source, target]:
			building.station.fleet.logistics_vessel = 2
			building.station.fleet.space_warper = 8
			building.station.slots[0].merge({"item_id": "iron_ore", "min_load": 0.1, "route_policy": "relay-required", "warper_budget": 4}, true)
		source.station.slots[0].merge({"remote_mode": "supply", "amount": 500.0}, true)
		target.station.slots[0].merge({"remote_mode": "demand", "amount": 0.0}, true)
		var logistics := LogisticsSystem.new(state)
		var before := runner.OWNER._ownership(state)
		var dispatched := logistics._dispatch({"id": source.id, "index": 0, "slot": source.station.slots[0], "remote": true}, {"id": target.id, "index": 0, "slot": target.station.slots[0], "remote": true})
		var ok := false
		if row.id.ends_with("policy-relay-required-4"):
			var cargo := float(source.station.slots[0].amount) + float(target.station.slots[0].amount)
			var fleet := int(source.station.fleet.logistics_vessel) + int(target.station.fleet.logistics_vessel)
			var warpers := int(source.station.fleet.space_warper) + int(target.station.fleet.space_warper)
			var paid := 0
			for route in state.logistics_routes.values():
				cargo += float(route.amount)
				fleet += 1
				paid += int(route.warpers_per_vessel)
			ok = dispatched == "已派遣" and not state.logistics_routes.is_empty() and cargo == 500.0 and fleet == 4 and warpers + paid == 16
		else:
			ok = "无可用航线" in dispatched and state.logistics_routes.is_empty() and runner.OWNER._ownership(state) == before
		if not ok: errors.append("route dispatch guard failed: " + row.id)
		print("ROUTE QUERY DISPATCH GUARD ", row.id, ": passed=", ok)
	if count != 3: errors.append("all three actual route dispatch guards must execute")

func _paid_station_persistence() -> Array[String]:
	var errors: Array[String] = []
	var runner := preload("res://scripts/test/RouteQueryBehaviorRunner.gd")
	var fixture := DSPOnlineParity.read_json(runner.FIXTURE)
	var ids := ["240721-false-relaxed-0-0-planet-home", "240721-false-relaxed-0-0-planet-ashen", "240721-false-relaxed-0-0-vessels-1"]
	var root := "res://.godot/task27-paid-station-route-%d/" % OS.get_process_id()
	var saves := 0
	for index in range(ids.size()):
		var matches: Array = fixture.cases.filter(func(row): return row.id == ids[index])
		if matches.size() != 1:
			errors.append("paid route source row missing")
			continue
		var row: Dictionary = matches[0]
		var state := GameState.new()
		state.emit_canvas_events = false
		SourceGalaxySystem.new(state).initialize(int(row.input.seed), row.input.baseline)
		state.initialize_new_game_home_inventory(true)
		state.difficulty = row.input.difficulty
		state.explored_system_ids.assign(row.input.unlocked)
		for system in state.explored_system_ids: state.survey_progress_by_system[system] = 1.0
		var placed_ids := []
		for station in row.input.stations:
			if not state.colonized_planet_ids.has(station.planet): state.colonized_planet_ids.append(station.planet)
			if not state.planet_inventories.has(station.planet): state.planet_inventories[station.planet] = {}
			if not state.planet_viewports.has(station.planet): state.planet_viewports[station.planet] = {"position": Vector2.ZERO, "zoom": Vector2.ONE}
			if not state.set_active_planet(station.planet): errors.append("paid route planet selection failed")
			state.construction_inventory.dsp_interstellar_logistics_station = int(station.count)
			var placed := state.try_place_building("dsp_interstellar_logistics_station", Vector2(1000 + placed_ids.size() * 300, 0))
			if not placed.ok:
				errors.append("actual paid station placement failed: " + JSON.stringify(placed))
				continue
			var stacked := StationSystem.new(state).set_stack_target(placed.id, int(station.count))
			var building: Dictionary = state.buildings[placed.id]
			if not stacked.ok or state.construction_inventory.dsp_interstellar_logistics_station != 0 or building.has("machine_count") or StationSystem.stack_count(building) != int(station.count) or building.planet_id != station.planet: errors.append("paid route consumes all kits and retains authoritative stack count/planet")
			placed_ids.append(placed.id)
		if placed_ids.size() != 2: continue
		var actual := _paid_route_values(state, placed_ids, row)
		if not runner._exact(actual, row.expected.getInterstellarRouteEconomics): errors.append("paid station route disagrees with frozen source: " + row.id + " actual=" + JSON.stringify(actual))
		var payload := GameStateCodec.to_persistent_dict(state)
		var storage := SaveSystem.new(root + str(index) + "/")
		var before := runner.OWNER._ownership(state)
		var saved := storage.save_slot(0, state)
		if not saved.ok or runner.OWNER._ownership(state) != before:
			errors.append("paid station route disk save failed or mutates ownership: " + JSON.stringify(saved))
			continue
		saves += 1
		var loaded := storage.load_recovery_source(0, "primary")
		if not loaded.ok:
			errors.append("paid route primary digest reload failed")
			continue
		if not runner._exact(GameStateCodec.to_persistent_dict(loaded.state), payload): errors.append("paid route full canonical save differs")
		if not runner._exact(_paid_route_values(loaded.state, placed_ids, row), row.expected.getInterstellarRouteEconomics): errors.append("paid station stack count/source economics lost on reload: " + row.id)
	print("PAID STATION ROUTE SAVES: ", saves, "; errors: ", errors.size(), "; root: ", root)
	return errors

func _paid_route_values(state: GameState, ids: Array, row: Dictionary) -> Dictionary:
	var runner := preload("res://scripts/test/RouteQueryBehaviorRunner.gd")
	var service := InterstellarRouteSystem.new(state)
	var before := runner.OWNER._ownership(state)
	var options := {"route_policy": row.input.options.routePolicy, "warper_budget": int(row.input.options.warperBudget)}
	var values := service.query_economics(state.buildings[ids[0]], state.buildings[ids[1]], int(row.input.vessels), options)
	var repeated := service.query_economics(state.buildings[ids[0]], state.buildings[ids[1]], int(row.input.vessels), options)
	if values != repeated or runner.OWNER._ownership(state) != before: return {"ownership_changed": true}
	var result := {}
	for field in runner.FIELDS: result[field] = values[runner.FIELDS[field]]
	return result
