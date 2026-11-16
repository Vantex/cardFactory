extends RefCounted

const FIXTURE := "res://tests/fixtures/parity/behavior/task27-content-pack-high-capacity.json"
const CAPACITY := preload("res://scripts/test/CapacityQueryBehaviorRunner.gd")
const OWNER := preload("res://scripts/test/EffectQueryBehaviorRunner.gd")
const MANIFEST := {"formatVersion": 2, "id": "high_capacity_pack", "name": "高容量站保存回归", "version": "1.0.0", "buildingOverrides": [{"id": "planetary_logistics_station", "outputCapacity": 2000}, {"id": "interstellar_logistics_station", "outputCapacity": 3000}, {"id": "orbital_collector", "outputCapacity": 4000}]}
const FUNCTIONS := ["getEntityInputCapacity", "getEntityOutputCapacity", "getEntityItemInputCapacity", "getStationSlotCapacity"]
var errors: Array[String] = []
var saves := 0
var root := ""
var gold: Dictionary

func run() -> Dictionary:
	errors.clear()
	saves = 0
	root = "res://.godot/task27-high-capacity-%d/" % OS.get_process_id()
	gold = DSPOnlineParity.read_json(FIXTURE)
	var valid := _validate_gold()
	if not valid.is_empty(): return {"errors": valid, "saves": 0, "root": root}
	var original := ContentPackSystem.snapshot_catalog()
	var old_service := DataManager.content_pack_system
	var service := ContentPackSystem.new(root + "pack/registry.json")
	DataManager.content_pack_system = service
	var registered := service.register_pack(MANIFEST)
	_check(registered.ok, "actual legal high capacity pack registration")
	if registered.ok:
		_queries()
		_real_boundaries(service)
	ContentPackSystem.install_catalog(original)
	DataManager.content_pack_system = old_service
	return {"errors": errors.duplicate(), "saves": saves, "root": root}

func _validate_gold() -> Array[String]:
	var source := DSPOnlineParity.read_json(DSPOnlineParity.ROOT + "dsponline_source_catalog.json")
	var modules := CAPACITY.SOURCE_MODULES.duplicate()
	modules.append_array(["src/game/contentPacks.ts", "src/game/mods.ts"])
	var controls := preload("res://scripts/test/WorldControlBehaviorRunner.gd")
	if gold.get("source_commit") != source.source.commit or not gold.get("source_files") is Dictionary or not controls._same_ids(gold.source_files.keys(), modules): return ["high pack exact source provenance missing"]
	for file in modules:
		if gold.source_files[file] != source.source.files.get(file): return ["high pack source hash drift"]
	if not CAPACITY._exact(gold.get("source_environment"), {"DEV": false, "PROD": true, "MODE": "production"}) or not CAPACITY._exact(gold.get("manifest"), MANIFEST): return ["high pack manifest/environment changed"]
	var inputs := {}
	for building in ["planetary_logistics_station", "interstellar_logistics_station", "orbital_collector"]:
		for count in [1, 2, 3]:
			for maximum in [0, 59.9]:
				for item in ["iron_ore", "proliferator_mk1"]: inputs["%s-c%d-s%s-i%s" % [building, count, str(maximum), item]] = {"building": building, "count": count, "maxStock": maximum, "item": item}
	if not gold.get("cases") is Array: return ["high pack cases missing"]
	var ids := []
	for row in gold.cases:
		if not row is Dictionary: return ["high pack case malformed"]
		ids.append(row.get("id"))
	if not controls._same_ids(ids, inputs.keys()): return ["high pack case coverage missing/duplicated"]
	for row in gold.cases:
		if not CAPACITY._exact(row.get("input"), inputs[row.id]) or not row.get("expected") is Dictionary or not controls._same_ids(row.expected.keys(), FUNCTIONS): return ["high pack controlled input/output shape changed"]
		for function in FUNCTIONS:
			var value: Variant = row.expected[function]
			if not OWNER._number(value) or value < 0 or value > 100000000 or (function != "getStationSlotCapacity" and value != floorf(float(value))): return ["high pack expected output must be finite and bounded"]
	return []

func _queries() -> void:
	for row in gold.cases:
		var state := CAPACITY._state({"entity_kind": "building", "building": row.input.building, "kind": "station", "count": row.input.count, "production": 1000000, "logistics": 1000000})
		var id: String = state.buildings.keys()[0]
		state.buildings[id].station = {"slots": [{"item_id": "iron_ore", "max_stock": row.input.maxStock}]}
		var before := OWNER._ownership(state)
		var actual := _query(state, id, String(row.input.item))
		var repeated := _query(state, id, String(row.input.item))
		_check(CAPACITY._exact(actual, row.expected) and CAPACITY._exact(actual, repeated) and OWNER._ownership(state) == before, row.id + ": actual four high-capacity providers match frozen pack without ownership mutation")

static func _query(state: GameState, id: String, item: String) -> Dictionary:
	var b: Dictionary = state.buildings[id]
	return {"getEntityInputCapacity": state.get_entity_input_capacity(id), "getEntityOutputCapacity": state.get_entity_output_capacity(id), "getEntityItemInputCapacity": state.get_entity_item_input_capacity(id, item), "getStationSlotCapacity": StationSystem.capacity_for(b.station.slots[0], state, b)}

func _real_boundaries(service: ContentPackSystem) -> void:
	for source in ["planetary_logistics_station", "interstellar_logistics_station", "orbital_collector"]:
		var state := GameState.new()
		state.emit_canvas_events = false
		SourceGalaxySystem.new(state).initialize(240721, false)
		state.initialize_new_game_home_inventory(true)
		state.content_packs = service.references()
		if source == "orbital_collector":
			PlanetSystem.new(state).ensure_colonized_planet_records("giant")
			_check(state.set_active_planet("giant"), "controlled giant supports real funded collector placement")
		var type := "dsp_" + String(source)
		state.construction_inventory[type] = 1
		var placed := state.try_place_building(type, Vector2(1000, 0))
		_check(placed.ok and state.construction_inventory[type] == 0, "actual high-capacity station/collector consumes its funded kit")
		if not placed.ok: continue
		var id: String = placed.id
		var station := StationSystem.new(state)
		var matches: Array = gold.cases.filter(func(row): return row.input.building == source and row.input.count == 1 and row.input.maxStock == 0 and row.input.item == "iron_ore")
		_check(matches.size() == 1, "one actual source high slot capacity boundary")
		if matches.size() != 1: continue
		var expected: float = matches[0].expected.getStationSlotCapacity
		var amount := expected if source == "orbital_collector" else expected - 500
		if source == "orbital_collector":
			OrbitalCollectorSystem.new(state).update(1000000)
			_check(state.buildings[id].station.slots[0].amount == expected, "actual collector fills to source4000 above physical2000")
		else:
			_check(station.configure_slots([id], 0, "iron_ore", "storage", 1000, 0.1, 1, "local").ok, "source high-capacity station retains physical1000 configuration")
			state.planet_inventory.iron_ore = float(state.planet_inventory.get("iron_ore", 0)) + amount
			var funded := float(state.planet_inventory.iron_ore)
			_check(station.transfer_cargo(id, 0, amount, true).ok and state.buildings[id].station.slots[0].amount == amount and state.planet_inventory.iron_ore == funded - amount, "actual high-capacity deposit preserves funded material ownership")
		_check(StationSystem.capacity_for(state.buildings[id].station.slots[0], state, state.buildings[id]) == expected, "paid high-capacity slot equals actual source gold")
		_save(state, id, amount, expected)
		if source == "planetary_logistics_station":
			var bad := GameStateCodec.to_persistent_dict(state)
			for invalid in [2001, -1, true, "1500"]:
				var altered := bad.duplicate(true)
				altered.buildings[id].station.slots[0].amount = invalid
				_check(not GameStateValidator.validate_persistent_dict(altered).is_empty(), "high retained bound preserves finite/type/lower/upper validation")
			bad.buildings[id].station.slots[0].capacity = 1001
			_check(not GameStateValidator.validate_persistent_dict(bad).is_empty(), "physical source capacity still rejects1001")
			state.source_buffer_limits = {"logistics": 1000}
			_check(station.set_slot_limits(id, 0, 0, 1).ok, "actual lowered maxStock1 configuration")
			var before := OWNER._ownership(state)
			_check(not station.transfer_cargo(id, 0, 1, true).ok and OWNER._ownership(state) == before, "lowered admission atomically retains admitted1500 without new deposit")
			_save(state, id, amount, 1)

func _save(state: GameState, id: String, amount: float, capacity: float) -> void:
	var persistent := GameStateCodec.to_persistent_dict(state)
	var before := OWNER._ownership(state)
	var storage := SaveSystem.new(root + str(saves) + "/")
	var saved := storage.save_slot(0, state)
	_check(saved.ok and OWNER._ownership(state) == before, "actual high-capacity primary save retains raw ownership: " + JSON.stringify(saved.get("error", {})))
	if not saved.ok: return
	saves += 1
	var loaded := storage.load_recovery_source(0, "primary")
	_check(loaded.ok, "actual high-capacity file passes primary digest reload")
	if not loaded.ok: return
	_check(CAPACITY._exact(GameStateCodec.to_persistent_dict(loaded.state), persistent), "high-capacity persisted configuration and cargo survive exact disk roundtrip")
	var b: Dictionary = loaded.state.buildings[id]
	_check(b.station.slots[0].amount == amount and StationSystem.capacity_for(b.station.slots[0], loaded.state, b) == capacity, "loaded high stock and lowered admission remain valid")

func _check(ok: bool, message: String) -> void:
	if not ok: errors.append(message)
