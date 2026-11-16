extends RefCounted

const EXACT := preload("res://scripts/test/CapacityQueryBehaviorRunner.gd")
const OWNER := preload("res://scripts/test/EffectQueryBehaviorRunner.gd")
var errors: Array[String] = []
var saves := 0
var directory := ""
var gold: Dictionary

func run() -> Dictionary:
	errors.clear()
	saves = 0
	directory = "res://.godot/task27-item-input-persistence-%d/" % OS.get_process_id()
	gold = JSON.parse_string(FileAccess.get_file_as_string("res://tests/fixtures/parity/behavior/task27-item-input-capacity.json"))
	_station()
	_spray()
	_balanced()
	_pack_override()
	_native()
	return {"errors": errors.duplicate(), "saves": saves, "root": directory}

func _state() -> GameState:
	var state := GameState.new()
	state.emit_canvas_events = false
	SourceGalaxySystem.new(state).initialize(240721, false)
	state.initialize_new_game_home_inventory(true)
	return state

func _place(state: GameState, type: String, x: float) -> String:
	state.construction_inventory[type] = float(state.construction_inventory.get(type, 0)) + 1
	var before := float(state.construction_inventory[type])
	var placed := state.try_place_building(type, Vector2(x, 0))
	_check(placed.ok and state.construction_inventory[type] == before - 1, "actual building placement consumes one funded kit: " + type + ": " + JSON.stringify(placed))
	return String(placed.get("id", ""))

func _link(state: GameState, source: String, target: String, item: String) -> void:
	state.construction_inventory.conveyor_belt_mk1 = float(state.construction_inventory.get("conveyor_belt_mk1", 0)) + 1
	var before := float(state.construction_inventory.conveyor_belt_mk1)
	var linked := state.try_add_connection(source, target, item)
	_check(linked.ok and state.construction_inventory.conveyor_belt_mk1 == before - 1, "actual connection consumes funded belt: " + JSON.stringify(linked))
	for id in [source, target]: state.buildings[id].power_efficiency = 1.0

func _fund(state: GameState, source: String, item: String, amount: float) -> void:
	state.planet_inventory[item] = float(state.planet_inventory.get(item, 0)) + amount
	_check(InventorySystem.new(state).try_remove(item, amount).ok, "controlled source cargo removes the same amount from its tray")
	state.buildings[source].output_buffer[item] = amount

func _stock(state: GameState, id: String, maximum: int) -> void:
	var station := StationSystem.new(state)
	var source := StationSystem.is_source(String(state.buildings[id].type))
	var configured := station.configure_slots([id], 0, "iron_ore", "storage", 1000 if source else 100, 0.1, 1, "local")
	_check(configured.ok and (not source or station.set_slot_limits(id, 0, 0, maximum).ok), "actual station stock configuration: " + JSON.stringify(configured))

func _expected(id: String) -> float:
	var rows: Array = gold.cases.filter(func(row): return row.id == id)
	_check(rows.size() == 1, "one unique actual frozen capacity row: " + id)
	return float(rows[0].expected.getEntityItemInputCapacity) if rows.size() == 1 else -1.0

func _station() -> void:
	var state := _state()
	var source := _place(state, "dsp_storage_mk1", 1000)
	var target := _place(state, "dsp_planetary_logistics_station", 1400)
	if source.is_empty() or target.is_empty(): return
	_check(StorageBufferSystem.new(state).configure(source, "iron_ore").ok, "real storage item configuration")
	_stock(state, target, 1)
	_link(state, source, target, "iron_ore")
	_fund(state, source, "iron_ore", 2)
	var expected := _expected("slot-planetary_logistics_station-default-c0-s2-i0")
	_save(state, {target: {"iron_ore": expected}}, 0)
	BeltSystem.new(state).update(1)
	_check(state.buildings[target].input_buffer.get("iron_ore", 0) == expected and state.buildings[source].output_buffer.iron_ore == 2 - expected, "actual paid station belt stops at source maxStock1")
	var loaded := _save(state, {target: {"iron_ore": expected}}, 1)
	if loaded == null: return
	for id in [source, target]: loaded.buildings[id].power_efficiency = 1.0
	var before := OWNER._ownership(loaded)
	BeltSystem.new(loaded).update(1)
	_check(OWNER._ownership(loaded) == before, "full loaded station admits no additional cargo")

func _spray() -> void:
	var state := _state()
	state.completed_technologies.append("dsp_proliferator_1")
	state.source_buffer_limits = {"proliferator": 1}
	var source := _place(state, "dsp_storage_mk1", 1000)
	var target := _place(state, "dsp_arc_smelter", 1400)
	if source.is_empty() or target.is_empty(): return
	_check(state.set_entity_recipe(target, "dsp_iron_ingot"), "actual smelter iron recipe")
	state.construction_inventory.dsp_spray_coater = 1
	_check(ProliferatorSystem.new(state).configure(target, 1, "speed").ok and state.construction_inventory.dsp_spray_coater == 0, "actual spray module installation consumes its kit")
	_check(StorageBufferSystem.new(state).configure(source, "proliferator_mk1").ok, "actual storage spray item configuration")
	_link(state, source, target, "proliferator_mk1")
	_fund(state, source, "proliferator_mk1", 2)
	var expected := _expected("spray-arc_smelter-c1-t1-minimum-i1")
	_save(state, {target: {"proliferator_mk1": expected}}, 2)
	BeltSystem.new(state).update(1)
	_check(state.buildings[target].input_buffer.get("proliferator_mk1", 0) == expected and state.buildings[source].output_buffer.proliferator_mk1 == 2 - expected, "actual paid spray belt stops at configured one-item cap")
	var loaded := _save(state, {target: {"proliferator_mk1": expected}}, 3)
	if loaded != null:
		for id in [source, target]: loaded.buildings[id].power_efficiency = 1.0
		BeltSystem.new(loaded).update(1)
		_check(loaded.buildings[target].input_buffer.proliferator_mk1 == expected and loaded.buildings[source].output_buffer.proliferator_mk1 == 2 - expected and EXACT._exact(loaded.source_buffer_limits, {"proliferator": 1}), "actual spray cap and material ownership survive primary reload")
	var payload := GameStateCodec.to_persistent_dict(state)
	for bad in [0, 1.9, true, "1", 100000001]:
		var altered := payload.duplicate(true)
		altered.source_buffer_limits.proliferator = bad
		_check(not GameStateValidator.validate_persistent_dict(altered).is_empty(), "invalid optional spray buffer limit rejected by real save validator")

func _balanced() -> void:
	var state := _state()
	var source := _place(state, "dsp_splitter_4way", 1000)
	var first := _place(state, "dsp_planetary_logistics_station", 1400)
	var second := _place(state, "dsp_planetary_logistics_station", 1800)
	if source.is_empty() or first.is_empty() or second.is_empty(): return
	_check(StorageBufferSystem.new(state).configure(source, "iron_ore", "balanced").ok, "actual balanced splitter configuration")
	_stock(state, first, 1)
	_stock(state, second, 0)
	_link(state, source, first, "iron_ore")
	_link(state, source, second, "iron_ore")
	_fund(state, source, "iron_ore", 6)
	var cap := _expected("slot-planetary_logistics_station-default-c0-s2-i0")
	var other := _expected("slot-planetary_logistics_station-default-c0-s1-i0")
	_save(state, {first: {"iron_ore": cap}, second: {"iron_ore": other}}, 4)
	BeltSystem.new(state).update(1)
	_check(state.buildings[first].input_buffer.get("iron_ore", 0) == cap and state.buildings[second].input_buffer.get("iron_ore", 0) == 6 - cap and state.buildings[source].output_buffer.iron_ore == 0, "actual balanced allocation redistributes constrained share within the unique six-item source budget")
	_save(state, {first: {"iron_ore": cap}, second: {"iron_ore": other}}, 5)

func _pack_override() -> void:
	var original := ContentPackSystem.snapshot_catalog()
	var old_service := DataManager.content_pack_system
	var pack: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://tests/fixtures/parity/behavior/task27-content-pack-capacity.json"))
	var service := ContentPackSystem.new(directory + "pack/registry.json")
	DataManager.content_pack_system = service
	var registered := service.register_pack(pack.manifest)
	_check(registered.ok, "actual legal core capacity override pack registration")
	if registered.ok:
		var state := _state()
		state.content_packs = service.references()
		var source := _place(state, "dsp_splitter_4way", 1000)
		var target := _place(state, "dsp_planetary_logistics_station", 1400)
		if not source.is_empty() and not target.is_empty():
			_check(StorageBufferSystem.new(state).configure(source, "iron_ore").ok, "actual override source configuration")
			_stock(state, target, 0)
			_link(state, source, target, "iron_ore")
			var rows: Array = pack.cases.filter(func(row): return row.id == "planetary_logistics_station-c1-s0-iiron_ore")
			_check(rows.size() == 1, "one source pack capacity row")
			if rows.size() == 1:
				var expected: float = rows[0].expected.getEntityItemInputCapacity
				_fund(state, source, "iron_ore", expected + 2)
				_save(state, {target: {"iron_ore": expected}}, 6)
				BeltSystem.new(state).update(100)
				_check(state.buildings[target].input_buffer.get("iron_ore", 0) == expected and state.buildings[source].output_buffer.iron_ore == 2, "actual core override matched slot uses source output capacity for paid belt admission")
				_save(state, {target: {"iron_ore": expected}}, 7)
	ContentPackSystem.install_catalog(original)
	DataManager.content_pack_system = old_service

func _native() -> void:
	var state := _state()
	var source := _place(state, "dsp_storage_mk1", 1000)
	var target := _place(state, "planetary_logistics_station", 1400)
	if source.is_empty() or target.is_empty(): return
	_check(StorageBufferSystem.new(state).configure(source, "iron_ore").ok, "actual native compatibility source configuration")
	_stock(state, target, 1)
	_link(state, source, target, "iron_ore")
	_fund(state, source, "iron_ore", 2)
	var expected := float(state.buildings[target].get("input_buffer_capacity", DataManager.get_building("planetary_logistics_station").get("input_buffer_capacity", 60)))
	_save(state, {target: {"iron_ore": expected}}, 8)
	BeltSystem.new(state).update(1)
	_check(state.buildings[target].input_buffer.get("iron_ore", 0) == 2 and state.buildings[source].output_buffer.iron_ore == 0, "native belt keeps its existing physical input capacity")
	_save(state, {target: {"iron_ore": expected}}, 9)

func _save(state: GameState, queries: Dictionary, index: int) -> GameState:
	var persistent := GameStateCodec.to_persistent_dict(state)
	var before := OWNER._ownership(state)
	var storage := SaveSystem.new(directory + str(index) + "/")
	var saved := storage.save_slot(0, state)
	_check(saved.ok and OWNER._ownership(state) == before, "actual disk save preserves ownership: " + JSON.stringify(saved.get("error", {})))
	if not saved.ok: return null
	saves += 1
	var loaded := storage.load_recovery_source(0, "primary")
	_check(loaded.ok, "actual primary file passes digest reload")
	if not loaded.ok: return null
	_check(EXACT._exact(GameStateCodec.to_persistent_dict(loaded.state), persistent), "all persistent configuration and materials survive exact canonical disk round trip")
	for id in queries:
		for item in queries[id]: _check(loaded.state.get_entity_item_input_capacity(id, item) == queries[id][item], "real loaded per-item capacity is unchanged")
	return loaded.state

func _check(ok: bool, message: String) -> void:
	if not ok: errors.append(message)
