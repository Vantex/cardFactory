extends RefCounted

const CAPACITY := preload("res://scripts/test/CapacityQueryBehaviorRunner.gd")
const OWNER := preload("res://scripts/test/EffectQueryBehaviorRunner.gd")
var errors: Array[String] = []
var saves := 0
var root := ""

func run() -> Dictionary:
	errors.clear()
	saves = 0
	root = "res://.godot/task27-slot-capacity-persistence-%d/" % OS.get_process_id()
	var fixture := DSPOnlineParity.read_json("res://tests/fixtures/parity/behavior/task27-slot-capacity.json")
	var specifications := [["planetary_logistics_station", "default", 0], ["planetary_logistics_station", "minimum", 0], ["planetary_logistics_station", "default", 600], ["interstellar_logistics_station", "minimum", 0], ["orbital_collector", "minimum", 0], ["orbital_collector", "default", 1200]]
	for index in range(specifications.size()):
		var spec: Array = specifications[index]
		var setup := _setup(String(spec[0]), 2, String(spec[1]), int(spec[2]))
		if setup.id.is_empty(): continue
		var state: GameState = setup.state
		var id: String = setup.id
		var building: Dictionary = state.buildings[id]
		var expected := _expected(fixture, String(spec[0]), 2, String(spec[1]), int(spec[2]))
		_check(_query(state, id) == expected, "real paid station/collector slot follows frozen rated and stock limits")
		_check(StationSystem.new(state).logistics_snapshot(id).slots[0].capacity == expected, "real diagnostic snapshot uses the same capacity")
		if spec[0] == "orbital_collector":
			OrbitalCollectorSystem.new(state).update(1000000)
			_check(building.station.slots[0].amount == expected, "actual collector stops at global/stock capacity without overflowing")
		else:
			var stations := StationSystem.new(state)
			state.planet_inventory.iron_ore = float(state.planet_inventory.get("iron_ore", 0)) + expected + 100
			var funded := float(state.planet_inventory.iron_ore)
			_check(stations.transfer_cargo(id, 0, expected, true).ok, "actual deposit reaches rated slot boundary")
			_check(building.station.slots[0].amount == expected and state.planet_inventory.iron_ore == funded - expected, "deposit preserves actual tray/slot material ownership")
			var before := OWNER._ownership(state)
			_check(not stations.transfer_cargo(id, 0, 1, true).ok and OWNER._ownership(state) == before, "one over rated slot is atomically rejected")
			building.input_buffer.iron_ore = 7.0
			building.power_efficiency = 1.0
			LogisticsSystem.new(state)._bridge_buffers(building, [])
			_check(building.input_buffer.iron_ore == 7 and building.station.slots[0].amount == expected, "a full rated slot leaves buffered cargo owned by its input")
			if index == 0:
				state.source_buffer_limits = {"production": 1000, "logistics": 1000}
				expected = _expected(fixture, "planetary_logistics_station", 2, "minimum", 0)
				before = OWNER._ownership(state)
				LogisticsSystem.new(state)._bridge_buffers(building, [])
				_check(_query(state, id) == expected and building.station.slots[0].amount == 1200 and building.input_buffer.iron_ore == 7, "lowering rated capacity retains preexisting above-limit slot and buffered materials")
				_check(not stations.transfer_cargo(id, 0, 1, true).ok and OWNER._ownership(state) == before, "lowered capacity blocks new deposits without deleting existing ownership")
		_save(state, {id: expected}, index)
	_quantum_boundary(fixture)
	_dispatch_boundary(fixture)
	_low_configured_capacity(fixture)
	_reserved_low_capacity_delivery(fixture)
	_native_capacity_compatibility()
	return {"errors": errors.duplicate(), "saves": saves, "root": root}

func _setup(source_id: String, count: int, profile: String, maximum: int) -> Dictionary:
	var state := GameState.new()
	state.emit_canvas_events = false
	SourceGalaxySystem.new(state).initialize(240721, false)
	state.initialize_new_game_home_inventory(true)
	state.source_buffer_limits = {"production": 1000, "logistics": 1000} if profile == "minimum" else {"production": 1000000, "logistics": 1000000}
	if source_id == "orbital_collector":
		PlanetSystem.new(state).ensure_colonized_planet_records("giant")
		_check(state.set_active_planet("giant"), "funded source giant records are selectable")
	var type := "dsp_" + source_id
	state.construction_inventory[type] = count
	var placed := state.try_place_building(type, Vector2(1000, 0))
	_check(placed.ok, "actual paid placement: " + source_id + ": " + JSON.stringify(placed))
	if not placed.ok: return {"state": state, "id": ""}
	var stations := StationSystem.new(state)
	var stacked := stations.set_stack_target(placed.id, count)
	_check(stacked.ok and state.construction_inventory[type] == 0, "real slot stack consumes every construction kit")
	if source_id != "orbital_collector": _check(stations.configure_slots([placed.id], 0, "iron_ore", "storage", 1000.0 * count, 0.1, 1, "local").ok, "real station iron slot configured")
	_check(stations.set_slot_limits(placed.id, 0, 0, maximum).ok, "actual slot stock limit configured")
	return {"state": state, "id": placed.id}

func _expected(fixture: Dictionary, building: String, count: int, profile: String, maximum: int) -> float:
	var matches: Array = fixture.cases.filter(func(row): return row.input.building == building and row.input.count == count and row.input.profile == profile and row.input.maxStock == maximum)
	_check(matches.size() == 1, "real paid boundary has exactly one frozen source query")
	return float(matches[0].expected.getStationSlotCapacity) if matches.size() == 1 else -1.0

func _quantum_boundary(fixture: Dictionary) -> void:
	var setup := _setup("interstellar_logistics_station", 3, "minimum", 0)
	if setup.id.is_empty(): return
	var state: GameState = setup.state
	var id: String = setup.id
	state.completed_technologies.append("dsp_quantum_logistics_network")
	var station := StationSystem.new(state)
	_check(station.configure_slots([id], 0, "iron_ore", "demand", 3000, 0.1, 1, "remote").ok, "real quantum demand slot configured")
	var quantum := QuantumLogisticsSystem.new(state)
	_check(quantum.upgrade_station(id).ok and quantum.attach(id).ok, "actual tower upgrade and boundary attachment requested")
	_check(quantum.set_item_capacity("iron_ore", "10000").ok, "actual shared capacity configured")
	state.quantum_network.inventory.iron_ore = "10000"
	state.elapsed_time = 5.0
	quantum.update()
	var expected := _expected(fixture, "interstellar_logistics_station", 3, "minimum", 0)
	_check(state.buildings[id].station.slots[0].amount == expected and state.quantum_network.inventory.iron_ore == "9000", "five-second quantum download stops at rated1000, preserving shared remainder")
	var before := OWNER._ownership(state)
	quantum.update()
	_check(OWNER._ownership(state) == before, "repeated quantum boundary cannot download again")
	_save(state, {id: expected}, 6)

func _dispatch_boundary(fixture: Dictionary) -> void:
	var setup := _setup("planetary_logistics_station", 1, "default", 0)
	if setup.id.is_empty(): return
	var state: GameState = setup.state
	var source_id: String = setup.id
	state.construction_inventory.dsp_planetary_logistics_station = 1
	var placed := state.try_place_building("dsp_planetary_logistics_station", Vector2(1400, 0))
	_check(placed.ok and state.construction_inventory.dsp_planetary_logistics_station == 0, "second real dispatch endpoint consumes its kit")
	if not placed.ok: return
	var target_id: String = placed.id
	var stations := StationSystem.new(state)
	_check(stations.configure_slots([source_id], 0, "iron_ore", "supply", 1000, 0.1, 1, "local").ok and stations.configure_slots([target_id], 0, "iron_ore", "demand", 1000, 0.1, 1, "local").ok, "real supply and demand slots configured")
	state.planet_inventory.iron_ore = float(state.planet_inventory.get("iron_ore", 0)) + 700
	_check(stations.transfer_cargo(source_id, 0, 100, true).ok and stations.transfer_cargo(target_id, 0, 600, true).ok, "actual cargo deposits fill target to source-rated600")
	state.portable_fleet.logistics_drone = 1
	_check(stations.set_fleet_target(source_id, "logistics_drone", 1).ok and state.buildings[source_id].station.fleet.logistics_drone == 1, "actual one-drone ownership moves into source hangar")
	for id in [source_id, target_id]: state.buildings[id].power_efficiency = 1.0
	var source: Dictionary = state.buildings[source_id]
	var target: Dictionary = state.buildings[target_id]
	var logistics := LogisticsSystem.new(state)
	var before := OWNER._ownership(state)
	var dispatched := logistics._dispatch({"id": source_id, "index": 0, "slot": source.station.slots[0], "remote": false}, {"id": target_id, "index": 0, "slot": target.station.slots[0], "remote": false})
	_check(dispatched != "已派遣" and state.logistics_routes.is_empty() and OWNER._ownership(state) == before, "full rated demand rejects dispatch without cargo or drone ownership change")
	var expected := _expected(fixture, "planetary_logistics_station", 1, "default", 0)
	_save(state, {source_id: expected, target_id: expected}, 7)

static func _query(state: GameState, id: String) -> float:
	var building: Dictionary = state.buildings[id]
	return StationSystem.capacity_for(building.station.slots[0], state, building)

func _save(state: GameState, queries: Dictionary, index: int) -> void:
	var payload := GameStateCodec.to_persistent_dict(state)
	var before := OWNER._ownership(state)
	var storage := SaveSystem.new(root + str(index) + "/")
	var saved := storage.save_slot(0, state)
	_check(saved.ok and OWNER._ownership(state) == before, "real slot boundary save preserves raw ownership: " + JSON.stringify(saved.get("error", {})))
	if not saved.ok: return
	saves += 1
	var loaded := storage.load_recovery_source(0, "primary")
	_check(loaded.ok, "slot boundary actual primary digest reload")
	if not loaded.ok: return
	_check(CAPACITY._exact(GameStateCodec.to_persistent_dict(loaded.state), payload), "all slot materials, fleets and configuration survive actual file")
	for id in queries: _check(_query(loaded.state, id) == queries[id], "actual loaded slot retains frozen capacity")

func _check(ok: bool, message: String) -> void:
	if not ok: errors.append(message)

func _low_configured_capacity(fixture: Dictionary) -> void:
	var setup := _setup("planetary_logistics_station", 1, "default", 0)
	if setup.id.is_empty(): return
	var state: GameState = setup.state
	var id: String = setup.id
	var stations := StationSystem.new(state)
	_check(stations.configure_slots([id], 0, "iron_ore", "storage", 100, 0.1, 1, "local").ok, "legacy small source capacity is publicly configurable")
	_check(GameStateValidator.validate_persistent_dict(GameStateCodec.to_persistent_dict(state)).is_empty(), "low configured source slot is a legal prior save")
	var expected := _expected(fixture, "planetary_logistics_station", 1, "default", 0)
	state.planet_inventory.iron_ore = float(state.planet_inventory.get("iron_ore", 0)) + expected
	var funded := float(state.planet_inventory.iron_ore)
	_check(stations.transfer_cargo(id, 0, expected, true).ok and state.buildings[id].station.slots[0].amount == expected and state.planet_inventory.iron_ore == funded - expected, "source-rated deposit preserves cargo above legacy configured capacity")
	_check(state.buildings[id].station.slots[0].capacity == 100, "source deposit preserves the legacy configuration field")
	var before := OWNER._ownership(state)
	_check(not stations.transfer_cargo(id, 0, 1, true).ok and OWNER._ownership(state) == before, "legacy small capacity still obeys current source-rated admission limit")
	var invalid := GameStateCodec.to_persistent_dict(state)
	invalid.buildings[id].station.slots[0].amount = 1001.0
	_check(not GameStateValidator.validate_persistent_dict(invalid).is_empty(), "source absolute storage overflow is still rejected")
	_save(state, {id: expected}, 8)

func _reserved_low_capacity_delivery(fixture: Dictionary) -> void:
	var setup := _setup("planetary_logistics_station", 1, "default", 0)
	if setup.id.is_empty(): return
	var state: GameState = setup.state
	var source_id: String = setup.id
	state.construction_inventory.dsp_planetary_logistics_station = 1
	var placed := state.try_place_building("dsp_planetary_logistics_station", Vector2(1400, 0))
	_check(placed.ok, "low-capacity delivery target consumes a real construction kit")
	if not placed.ok: return
	var target_id: String = placed.id
	var stations := StationSystem.new(state)
	_check(stations.configure_slots([source_id], 0, "iron_ore", "supply", 100, 0.1, 1, "local").ok and stations.configure_slots([target_id], 0, "iron_ore", "demand", 100, 0.1, 1, "local").ok, "both real route endpoints retain low legacy capacities")
	state.planet_inventory.iron_ore = float(state.planet_inventory.get("iron_ore", 0)) + 200
	_check(stations.transfer_cargo(source_id, 0, 100, true).ok and stations.transfer_cargo(target_id, 0, 100, true).ok, "actual route cargo is funded from the tray")
	state.portable_fleet.logistics_drone = 1
	_check(stations.set_fleet_target(source_id, "logistics_drone", 1).ok, "real delivery drone transfers into the hangar")
	for id in [source_id, target_id]: state.buildings[id].power_efficiency = 1.0
	var source: Dictionary = state.buildings[source_id]
	var target: Dictionary = state.buildings[target_id]
	var logistics := LogisticsSystem.new(state)
	var dispatched := logistics._dispatch({"id": source_id, "index": 0, "slot": source.station.slots[0], "remote": false}, {"id": target_id, "index": 0, "slot": target.station.slots[0], "remote": false})
	_check(dispatched == "已派遣" and state.logistics_routes.size() == 1, "actual source-rated dispatch reserves cargo above legacy capacity")
	if state.logistics_routes.size() != 1: return
	_check(stations.set_slot_limits(target_id, 0, 0, 1).ok, "stock limit can decrease with a real outstanding reservation")
	var expected := _expected(fixture, "planetary_logistics_station", 1, "default", 0)
	_save(state, {source_id: expected, target_id: 1.0}, 9)
	var storage := SaveSystem.new(root + "9/")
	var loaded := storage.load_recovery_source(0, "primary")
	_check(loaded.ok, "real low-capacity reservation resumes from disk")
	if not loaded.ok: return
	state = loaded.state
	for id in [source_id, target_id]: state.buildings[id].power_efficiency = 1.0
	LogisticsSystem.new(state)._advance_routes(1000)
	_check(state.logistics_routes.is_empty() and state.buildings[source_id].station.slots[0].amount == 75 and state.buildings[target_id].station.slots[0].amount == 125 and state.buildings[source_id].station.fleet.logistics_drone == 1, "reserved cargo completes and returns its drone after lowering admission limits")
	_check(state.buildings[target_id].station.slots[0].capacity == 100 and _query(state, target_id) == 1, "completed reservation preserves low legacy field and new stock limit")
	_save(state, {source_id: expected, target_id: 1.0}, 10)

func _native_capacity_compatibility() -> void:
	var state := GameState.new()
	state.emit_canvas_events = false
	SourceGalaxySystem.new(state).initialize(240721, false)
	state.initialize_new_game_home_inventory(true)
	state.construction_inventory.planetary_logistics_station = 1
	var placed := state.try_place_building("planetary_logistics_station", Vector2(1000, 0))
	_check(placed.ok and state.construction_inventory.planetary_logistics_station == 0, "native compatibility station is placed with its real kit")
	if not placed.ok: return
	var id: String = placed.id
	var stations := StationSystem.new(state)
	_check(stations.configure_slots([id], 0, "iron_ore", "storage", 100, 0.1, 1, "local").ok, "native configured capacity remains supported")
	state.planet_inventory.iron_ore = float(state.planet_inventory.get("iron_ore", 0)) + 101
	_check(stations.transfer_cargo(id, 0, 100, true).ok and _query(state, id) == 100, "native admission follows its configured physical capacity")
	var before := OWNER._ownership(state)
	_check(not stations.transfer_cargo(id, 0, 1, true).ok and OWNER._ownership(state) == before, "native overflow remains atomically rejected")
	var invalid := GameStateCodec.to_persistent_dict(state)
	invalid.buildings[id].station.slots[0].amount = 101.0
	_check(not GameStateValidator.validate_persistent_dict(invalid).is_empty(), "native saved amount still cannot exceed its configured capacity")
	_save(state, {id: 100.0}, 11)
