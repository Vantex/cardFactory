extends RefCounted

var failures: Array[String] = []

func run() -> Dictionary:
	failures.clear()
	var profiles := [{"production": 1000000, "logistics": 1000000}, {"production": 1000, "logistics": 1000}, {"production": 100000000, "logistics": 100000000}, {"production": 1000, "logistics": 100000000}, {"production": 100000000, "logistics": 1000}]
	var root := "res://.godot/task27-capacity-entity-persistence-%d/" % OS.get_process_id()
	var saves := 0
	for index in range(profiles.size()):
		var state := GameState.new()
		SourceGalaxySystem.new(state).initialize(240721, false)
		state.initialize_new_game_home_inventory(true)
		PlanetSystem.new(state).initialize_colonized_resource_sites()
		state.source_buffer_limits = profiles[index].duplicate(true)
		var site_id := ""
		for id in state.resource_sites:
			if state.resource_sites[id].planet_id == "home" and state.resource_sites[id].item_id == "iron_ore":
				site_id = id
				break
		_check(not site_id.is_empty(), "actual source home iron site exists")
		if site_id.is_empty(): continue
		var origin: Vector2 = state.resource_sites[site_id].position
		var ids := []
		for specification in [["dsp_mining_machine", origin + Vector2(-130, -90)], ["dsp_mining_machine", origin + Vector2(130, -90)], ["dsp_mining_machine", origin + Vector2(-130, 70)], ["dsp_arc_smelter", origin + Vector2(700, 0)], ["dsp_storage_mk1", origin + Vector2(1000, 0)], ["dsp_planetary_logistics_station", origin + Vector2(1300, 0)]]:
			var type: String = specification[0]
			state.construction_inventory[type] = float(state.construction_inventory.get(type, 0)) + 1
			var stock_before: float = state.construction_inventory[type]
			var placed := state.try_place_building(type, specification[1])
			_check(placed.ok, "actual paid kit placement " + type + ": " + placed.get("reason", ""))
			if not placed.ok: continue
			_check(state.construction_inventory[type] == stock_before - 1, "each placement consumes its actual kit")
			ids.append(placed.id)
			if type == "dsp_mining_machine": _check(state.buildings[placed.id].resource_site_id == site_id, "paid extractor binds actual iron site")
		if ids.size() != 6: continue
		state.construction_inventory.dsp_planetary_logistics_station += 1
		var before_stack: float = state.construction_inventory.dsp_planetary_logistics_station
		var stacked := StationSystem.new(state).set_stack_target(ids[5], 2)
		_check(stacked.ok and state.construction_inventory.dsp_planetary_logistics_station == before_stack - 1, "real station stacking consumes its second construction kit")
		var queries := {}
		for id in ids + [site_id]: queries[id] = _query(state, id)
		_check(queries[site_id] == {"limit": profiles[index].production, "input": 0, "output": 540}, "three actual miners aggregate to frozen count3 source capacity")
		_check(queries[ids[3]] == {"limit": profiles[index].production, "input": 120, "output": 120}, "actual smelter uses frozen source capacity")
		_check(queries[ids[4]] == {"limit": profiles[index].logistics, "input": 600, "output": 600}, "actual storage selects frozen source logistics limit")
		_check(queries[ids[5]] == {"limit": profiles[index].logistics, "input": mini(1200, profiles[index].logistics), "output": mini(1200, profiles[index].logistics)}, "actual paid stack2 station follows frozen source count2 capacity and logistics limit")
		var payload := GameStateCodec.to_persistent_dict(state)
		var decoded := GameStateCodec.from_persistent_dict(payload)
		_check(decoded != null, "entity-carrying state validates and decodes")
		if decoded == null: continue
		for id in queries: _check(_query(decoded, id) == queries[id], "codec retains source query for " + id)
		var before: Dictionary = preload("res://scripts/test/EffectQueryBehaviorRunner.gd")._ownership(state)
		var storage := SaveSystem.new(root + str(index) + "/")
		var saved := storage.save_slot(0, state)
		_check(saved.ok, "entity capacity disk save: " + JSON.stringify(saved.get("error", {})))
		_check(preload("res://scripts/test/EffectQueryBehaviorRunner.gd")._ownership(state) == before, "actual save preserves all ownership")
		if not saved.ok: continue
		saves += 1
		var loaded := storage.load_recovery_source(0, "primary")
		_check(loaded.ok, "digest-verified actual file reload")
		if not loaded.ok: continue
		_check(_same(GameStateCodec.to_persistent_dict(loaded.state), payload), "full canonical entity state survives file")
		for id in queries: _check(_query(loaded.state, id) == queries[id], "disk retains source query for " + id)
		loaded.state.source_buffer_limits.production = 2000
		_check(state.source_buffer_limits.production == profiles[index].production, "loaded config has independent ownership")
	return {"errors": failures.duplicate(), "saves": saves, "root": root}

static func _query(state: GameState, id: String) -> Dictionary:
	return {"limit": state.get_entity_buffer_limit(id), "input": state.get_entity_input_capacity(id), "output": state.get_entity_output_capacity(id)}

static func _same(left: Variant, right: Variant) -> bool:
	if (left is int or left is float) and (right is int or right is float): return left == right
	if left is Dictionary and right is Dictionary:
		if left.size() != right.size(): return false
		for key in left:
			if not right.has(key) or not _same(left[key], right[key]): return false
		return true
	if left is Array and right is Array:
		if left.size() != right.size(): return false
		for index in range(left.size()):
			if not _same(left[index], right[index]): return false
		return true
	return left == right

func _check(ok: bool, message: String) -> void:
	if not ok: failures.append(message)
