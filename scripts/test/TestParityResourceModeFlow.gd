extends Node

const OWNER := preload("res://scripts/test/EffectQueryBehaviorRunner.gd")
const EXACT := preload("res://scripts/test/CapacityQueryBehaviorRunner.gd")
const PAID := preload("res://scripts/test/ResourceMiningPersistenceRegression.gd")
var errors := []

func _ready() -> void:
	call_deferred("_run")

func _check(ok: bool, message: String) -> void:
	if not ok: errors.append(message)

func _run() -> void:
	var gold := preload("res://scripts/test/ResourceModeFixtureGuard.gd").load_fixture("flow")
	if gold.is_empty():
		get_tree().quit(1)
		return
	var stages := 0
	var saves := 0
	var panels := 0
	for row in gold.cases:
		var state := GameState.new()
		state.emit_canvas_events = false
		SourceGalaxySystem.new(state).initialize(240721, false)
		state.completed_technologies = DataManager.all_technologies.keys().filter(func(id): return String(id).begins_with("dsp_"))
		state.progression_facts.infinite_research = {"vein_utilization": {"level": 1, "invested": "0"}}
		state.explored_system_ids = SourceGalaxySystem.catalog().systems.keys()
		for explored in state.explored_system_ids: state.survey_progress_by_system[explored] = 1.0
		var planets := PlanetSystem.new(state)
		planets.ensure_colonized_planet_records(row.input.planet)
		state.set_active_planet(row.input.planet)
		planets.initialize_colonized_resource_sites()
		var selected: Dictionary = {}
		for site in planets.get_planet_resource_sites(row.input.planet):
			if site.item_id == row.input.item: selected = site; break
		_check(not selected.is_empty(), row.id + ": real seeded resource")
		if selected.is_empty(): continue
		_check(float(selected.capacity) == float(row.input.original_source_capacity), row.id + ": source initial reserve capacity")
		var position: Vector2 = selected.position
		var type := "dsp_" + String(row.input.extractor)
		state.construction_inventory[type] = 1
		var installed := state.try_place_building(type, position)
		_check(installed.ok and state.construction_inventory[type] == 0, row.id + ": actual paid count-one installation")
		if not installed.ok: continue
		state.construction_inventory.dsp_solar_panel = 100
		var power := PowerSystem.new(state)
		var built := 0
		while built < 100:
			var placed := state.try_place_building("dsp_solar_panel", position + Vector2(240 * built, 400))
			if not placed.ok: break
			built += 1
			power.update(1.0 / 60)
			if state.buildings[installed.id].power_efficiency == 1.0: break
		panels += built
		_check(state.buildings[installed.id].power_efficiency == 1.0, row.id + ": actual paid full power")
		var site: Dictionary = state.resource_sites[state.buildings[installed.id].resource_site_id]
		# Historical mode sequences use an explicit reserve capacity independent of new-game generation.
		site.capacity = row.input.capacity
		site.remaining = row.input.remaining
		site.depletion_remainder = row.input.remainder
		var index := 0
		for stage in row.stages:
			var raw := OWNER._ownership(state)
			_check(state.set_resource_mode(stage.mode), row.id + ": valid mode command")
			var changed := OWNER._ownership(state)
			raw.raw.fields.resource_mode = stage.mode
			raw.canonical.erase("resource_mode")
			changed.canonical.erase("resource_mode")
			_check(EXACT._exact(raw, changed), row.id + ": mode command preserves every other raw/canonical field")
			var engine := SimulationEngine.new(state)
			for tick in range(int(stage.ticks)): engine.update(1.0 / 60)
			errors.append_array(PAID.new()._differences(state, installed.id, stage.expected, row.id + "-" + str(index)))
			site = state.resource_sites[state.buildings[installed.id].resource_site_id]
			var query_owner := OWNER._ownership(state)
			var reserve: Variant = state.get_resource_reserve_snapshot(site)
			var actual_reserve: Dictionary = reserve.duplicate(true)
			var expected_reserve: Dictionary = stage.expected.reserve.duplicate(true)
			var ratio: Variant = actual_reserve.get("remainingRatio")
			actual_reserve.erase("remainingRatio")
			expected_reserve.erase("remainingRatio")
			var ratio_bytes := StreamPeerBuffer.new()
			if OWNER._number(ratio): ratio_bytes.put_double(float(ratio))
			_check(EXACT._exact(actual_reserve, expected_reserve), row.id + ": actual post-simulation reserve fields exact")
			_check(OWNER._number(ratio) and ratio_bytes.data_array.hex_encode() == stage.reserve_ratio_le_hex, row.id + ": reserve ratio exact original IEEE754 source bits")
			_check(OWNER._ownership(state) == query_owner, row.id + ": query preserves simulated owner")
			var storage := SaveSystem.new("res://.godot/task27-mode-flow-%d/%s/%d/" % [OS.get_process_id(), row.id, index])
			var payload: Dictionary = JSON.parse_string(JSON.stringify(GameStateCodec.to_persistent_dict(state), "", true, true))
			var saved := storage.save_slot(0, state)
			_check(saved.ok, row.id + ": actual stage primary save")
			if saved.ok:
				var loaded := storage.load_recovery_source(0, "primary")
				_check(loaded.ok and EXACT._exact(GameStateCodec.to_persistent_dict(loaded.state), payload), row.id + ": complete primary roundtrip")
				if loaded.ok: state = loaded.state; saves += 1
			stages += 1
			index += 1
	_check(gold.cases.size() == 48 and stages == 144 and saves == 144 and panels == 99, "complete controlled mode flow and paid/save counts")
	print("PARITY RESOURCE MODE FLOW TESTS: ", gold.cases.size(), "; stages=", stages, "; primary=", saves, "; paid_panels=", panels, "; root: res://.godot/task27-mode-flow-%d/; errors=" % OS.get_process_id(), errors.size(), "; first=", errors.slice(0, 15))
	if errors.is_empty(): print("PARITY RESOURCE MODE FLOW TESTS PASSED")
	get_tree().quit(0 if errors.is_empty() else 1)
