extends Node

const OUTPUT := preload("res://scripts/game/SourceResourceOutputSystem.gd")
const OWNER := preload("res://scripts/test/EffectQueryBehaviorRunner.gd")
const EXACT := preload("res://scripts/test/CapacityQueryBehaviorRunner.gd")
var errors := []
var rejected := 0
var saves := 0

func _ready() -> void:
	call_deferred("_run")

func _check(ok: bool, message: String) -> void:
	if not ok: errors.append(message)

func _state() -> GameState:
	var state := GameState.new()
	state.emit_canvas_events = false
	SourceGalaxySystem.new(state).initialize(240721, false)
	state.completed_technologies = DataManager.all_technologies.keys().filter(func(id): return String(id).begins_with("dsp_"))
	PlanetSystem.new(state).initialize_colonized_resource_sites()
	return state

func _run() -> void:
	var state := _state()
	var site: Dictionary = state.resource_sites.home_iron_ore_1
	state.construction_inventory.dsp_mining_machine = 1
	var installed := state.try_place_building("dsp_mining_machine", site.position)
	_check(installed.ok and state.construction_inventory.dsp_mining_machine == 0, "actual funded extractor")
	if not installed.ok: get_tree().quit(1); return
	var building: Dictionary = state.buildings[installed.id]
	building.output_buffer.iron_ore = 1.495
	site.output_buffer = {"iron_ore": 2.0}
	var before := OWNER._ownership(state)
	_check(OUTPUT.raw_amount(state, site) == 3.495 and OUTPUT.amount(state, site) == 3, "old fractional owner and integer view are separate")
	_check(OWNER._ownership(state) == before, "queries preserve complete raw and canonical state")
	for requested in [NAN, INF, -1.0, 0.0, 4.0]:
		_check(OUTPUT.take(state, site, requested) == 0 and OWNER._ownership(state) == before, "invalid take is atomic: " + str(requested))
		rejected += 1
	_check(OUTPUT.take(state, site, 2) == 2 and site.output_buffer.iron_ore == 0 and building.output_buffer.iron_ore == 1.495, "collecting manual stock preserves original fractional extractor buffer")
	var payload: Dictionary = JSON.parse_string(JSON.stringify(GameStateCodec.to_persistent_dict(state), "", true, true))
	_check(GameStateValidator.validate_persistent_dict(payload).is_empty(), "valid optional site cache")
	var bad_buffers := [null, [], true, 1, {"copper_ore": 1}, {"iron_ore": -1}, {"iron_ore": NAN}, {"iron_ore": INF}, {"iron_ore": "1"}, {"iron_ore": true}, {"iron_ore": 100000001}]
	for buffer in bad_buffers:
		var bad := payload.duplicate(true)
		bad.resource_sites[site.id].output_buffer = buffer
		_check(not GameStateValidator.validate_persistent_dict(bad).is_empty(), "invalid optional cache rejected: " + str(buffer))
		rejected += 1
	var legacy := GameState.new()
	PlanetSystem.new(legacy).initialize_colonized_resource_sites()
	var old_site: Dictionary = legacy.resource_sites.home_iron_1
	var tray_before := float(legacy.planet_inventory.get("iron_ore", 0))
	_check(SourceProgressionFacts.mine(legacy, old_site.id).ok and float(legacy.planet_inventory.iron_ore) == tray_before + 1 and not old_site.has("output_buffer"), "legacy empty-source mining retains actual tray destination")
	var full := _state()
	var full_site: Dictionary = full.resource_sites.home_iron_ore_1
	full.construction_inventory.dsp_mining_machine = 1
	var paid := full.try_place_building("dsp_mining_machine", full_site.position)
	var miner: Dictionary = full.buildings[paid.id]
	full_site.output_buffer = {"iron_ore": 180.0}
	miner.progress = 0.75
	miner.power_efficiency = 1.0
	var reserve := float(full_site.remaining)
	ProductionSystem.new(full).update(1.0 / 60)
	_check(OUTPUT.raw_amount(full, full_site) == 180 and full_site.remaining == reserve and miner.progress == 0, "automatic cycle stops at full shared cache")
	full_site.output_buffer.iron_ore = 2.0
	miner.output_buffer.iron_ore = 0.495
	full.construction_inventory.dsp_arc_smelter = 1
	var target := full.try_place_building("dsp_arc_smelter", full_site.position + Vector2(500, 0))
	_check(target.ok and full.set_entity_recipe(target.id, "dsp_iron_ingot"), "real paid smelter and recipe")
	if target.ok:
		full.buildings[target.id].power_efficiency = 1.0
		var belt := BeltSystem.new(full)
		var connection := belt.try_create_belt(paid.id, target.id, "iron_ore")
		_check(connection.ok, "real cache-connected belt")
		if connection.ok:
			belt.update(1.0 / 6)
			_check(OUTPUT.raw_amount(full, full_site) == 1.495 and full.buildings[target.id].input_buffer.iron_ore == 1 and miner.output_buffer.iron_ore == 0.495, "regular belt takes site output without losing original fraction")
	var special := _state()
	var special_site: Dictionary = special.resource_sites.home_iron_ore_1
	special.construction_inventory.dsp_mining_machine = 1
	var special_paid := special.try_place_building("dsp_mining_machine", special_site.position)
	var source: Dictionary = special.buildings[special_paid.id]
	source.power_efficiency = 1.0
	special_site.output_buffer = {"iron_ore": 5.0}
	var special_belt := BeltSystem.new(special)
	var hole := {"id": "controlled-hole", "type": BlackHoleSystem.TYPE, "black_hole_paused": false, "black_hole_activation_confirmed": true, "black_hole_ports": BlackHoleSystem.empty_ports()}
	var hole_connection := {"target_port_index": 0}
	special_belt._update_black_hole_connection(hole_connection, source, hole, "iron_ore", 2, 1)
	_check(OUTPUT.raw_amount(special, special_site) == 3 and hole.black_hole_ports[0].total_destroyed == "2", "controlled black-hole endpoint drains shared cache exactly")
	special.quantum_network = QuantumLogisticsSystem._initial()
	special.quantum_network.enabled = true
	var quantum_connection := {"id": "controlled-quantum", "planet_id": "home"}
	special_belt._update_quantum_connection(quantum_connection, source, "iron_ore", 2, 1)
	_check(OUTPUT.raw_amount(special, special_site) == 1 and special.quantum_network.inventory.iron_ore == "2", "controlled quantum endpoint drains shared cache exactly")
	var root := "res://.godot/task27-manual-boundaries-%d/" % OS.get_process_id()
	for row in [{"id": "fraction", "state": state}, {"id": "belt", "state": full}]:
		var canonical: Dictionary = JSON.parse_string(JSON.stringify(GameStateCodec.to_persistent_dict(row.state), "", true, true))
		var storage := SaveSystem.new(root + row.id + "/")
		var saved := storage.save_slot(0, row.state)
		var reopened := storage.load_recovery_source(0, "primary") if saved.ok else {}
		_check(saved.ok and reopened.get("ok", false) and EXACT._exact(GameStateCodec.to_persistent_dict(reopened.state), canonical), row.id + ": actual cache/fraction/belt primary roundtrip")
		if reopened.get("ok", false): saves += 1
	print("PARITY RESOURCE OUTPUT BOUNDARY TESTS: rejections=", rejected, "; primary=", saves, "; root=", root, "; errors=", errors)
	var passed := rejected == 16 and saves == 2 and errors.is_empty()
	if passed: print("PARITY RESOURCE OUTPUT BOUNDARY TESTS PASSED")
	get_tree().quit(0 if passed else 1)
