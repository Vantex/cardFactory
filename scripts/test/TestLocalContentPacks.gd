extends Node
var failures := 0
func check(condition: bool, message: String) -> void:
	if not condition:
		failures += 1
		printerr("CONTENT PACK: " + message)

func _ready() -> void:
	failures += PureIdleRegression.new().run()
	_test_tray_and_copy()
	_test_remote_station_configuration()
	var saved_catalog := ContentPackSystem.snapshot_catalog()
	var saved_service := DataManager.content_pack_system
	var service := ContentPackSystem.new("res://.godot/task26-content-packs/registry.json")
	DataManager.content_pack_system = service
	_test_source_gold(service)
	var pack := {"formatVersion": 2, "id": "local_test_pack", "name": "本地测试包", "version": "1.2.0", "items": [{"id": "local_test_item", "name": "新物品"}], "buildings": [{"id": "local_test_machine", "name": "新机器", "kind": "machine", "powerDemandKw": 200, "costs": [{"itemId": "iron_ingot", "amount": 1}], "inputCapacity": 100, "outputCapacity": 100}, {"id": "local_test_power", "name": "新电站", "kind": "power", "powerGenerationKw": 100, "costs": [{"itemId": "iron_ingot", "amount": 1}]}], "recipes": [{"id": "local_test_recipe", "name": "新配方", "buildingId": "local_test_machine", "duration": 1, "inputs": [{"itemId": "iron_ingot", "amount": 1}], "outputs": [{"itemId": "local_test_item", "amount": 2}]}], "belts": [{"id": "local_test_belt", "name": "四级带", "tier": 4, "speed": 100, "costs": [{"itemId": "iron_ingot", "amount": 1}]}], "technologies": [{"id": "local_test_tech", "name": "免费科技", "costs": []}]}
	var registered := service.register_pack(pack)
	check(registered.ok, "v2 package installs runtime catalog: " + str(registered))
	if registered.ok:
		var state := GameState.new()
		state.content_packs = service.references()
		state.construction_inventory.local_test_machine = 1.0
		var placed := ConstructionSystem.new(state).try_place_building("local_test_machine", Vector2.ZERO)
		check(placed.ok, "custom construction piece places real machine")
		if placed.ok:
			state.set_entity_recipe(placed.id, "local_test_recipe")
			state.buildings[placed.id].input_buffer = {"iron_ingot": 3.0}
			state.buildings[placed.id].power_efficiency = 1.0
			ProductionSystem.new(state).update(1.0)
			check(state.buildings[placed.id].output_buffer.get("local_test_item", 0) == 2 and state.buildings[placed.id].input_buffer.iron_ingot == 2, "custom recipe consumes real inputs and emits defined outputs")
		var power_id := state.add_building({"type": "local_test_power", "position": Vector2(1000, 0), "input_buffer": {}, "output_buffer": {}})
		var power := PowerSystem.new(state)
		power.update(0)
		check(power_id != "" and power.total_generation == 100 and power.total_consumption == 200 and state.buildings[placed.id].power_efficiency == 0.5, "custom power and demand participate in the real grid")
		check(DataManager.belt_definitions().get("local_test_belt") == 100, "custom belt speed enters runtime throughput catalog")
		_test_buffer_transport(service)
		check(TechnologySystem.new(state).start_research("local_test_tech") and state.completed_technologies.has("local_test_tech"), "empty-cost custom technology completes immediately")
		var payload := GameStateCodec.to_persistent_dict(state)
		check(GameStateValidator.validate_persistent_dict(payload).is_empty(), "custom state validates with exact runtime requirements: " + str(GameStateValidator.validate_persistent_dict(payload)))
		check(not service.set_enabled(pack.id, false, [payload]).ok, "live or saved custom entity protects disable")
		check(not service.remove_pack(pack.id, [{"blueprint_library": [{"buildings": [{"type": "local_test_machine"}]}]}]).ok, "nested blueprint protects removal")
		var storage := SaveSystem.new("res://.godot/task26-content-pack-saves/")
		check(storage.save_slot(0, state).ok and storage.load_slot(0).ok, "custom definitions survive real disk round trip")
		var bad := payload.duplicate(true)
		bad.content_packs[0].fingerprint = "stale"
		check(not GameStateValidator.validate_persistent_dict(bad).is_empty(), "changed manifest fingerprint rejects save")
		var dependent := {"formatVersion": 1, "id": "local_dependent", "name": "依赖包", "version": "1.0.0", "dependencies": ["local_test_pack@^1.1.0"], "items": [{"id": "dependent_item", "name": "依赖物品"}]}
		check(service.register_pack(dependent).ok, "satisfied version range activates dependent")
		check(not service.set_enabled(pack.id, false).ok, "enabled dependency blocks provider disable")
		check(service.set_enabled(dependent.id, false).ok, "leaf package can disable")
		check(service.set_enabled(pack.id, false).ok, "unused provider can disable")
		check(not storage.load_slot(0).ok, "disabled required package rejects save before installation")
		check(service.set_enabled(pack.id, true).ok and storage.load_slot(0).ok, "reenabling exact manifest restores save access")
	var conflict := pack.duplicate(true)
	conflict.id = "local_conflict"
	check(not service.register_pack(conflict).ok, "registered IDs and belt tiers cannot conflict")
	var unknown := pack.duplicate(true)
	unknown.recipes[0].inputs[0].itemId = "not_registered"
	check(not service.validate_manifest(unknown).ok, "unknown references rejected")
	var cycle := {"formatVersion": 1, "id": "local_cycle", "name": "循环包", "version": "1.0.0", "technologies": [{"id": "cycle_aa", "name": "甲", "prerequisites": ["cycle_bb"]}, {"id": "cycle_bb", "name": "乙", "prerequisites": ["cycle_aa"]}]}
	check(not service.validate_manifest(cycle).ok, "technology cycles rejected")
	check(ContentPackValidator.satisfies("0.8.0", "^0.2.0") and not ContentPackValidator.satisfies("1.0.0", "^0.2.0"), "source caret retains same-major rule including zero")
	check(ContentPackValidator.satisfies("1.2.3", "~1.2.0") and not ContentPackValidator.satisfies("1.3.0", "~1.2.0"), "source tilde retains same minor")
	var missing := {"formatVersion": 1, "id": "local_waiting", "name": "等待依赖", "version": "1.0.0", "dependencies": ["missing_package@>=1.0.0"]}
	var waiting := service.register_pack(missing)
	check(waiting.ok and not waiting.enabled, "valid package registers disabled while dependency absent")
	ContentPackSystem.install_catalog(saved_catalog)
	var reloaded := ContentPackSystem.new(service.path)
	var stored_registry: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(service.path))
	check(stored_registry.fingerprint == ContentPackSystem.fingerprint(stored_registry.registry), "registry fingerprint survives JSON number normalization: " + str(stored_registry.fingerprint) + " / " + ContentPackSystem.fingerprint(stored_registry.registry))
	for id in stored_registry.registry.packs:
		var manifest_check := ContentPackValidator.validate(stored_registry.registry.packs[id].manifest, reloaded.aliases, stored_registry.registry.packs)
		check(manifest_check.ok, "registry manifest " + id + ": " + str(manifest_check))
	var restored := reloaded.load_registry()
	check(restored.ok and reloaded.registry.packs.has(pack.id), "device registry survives validated disk reload: " + str(restored))
	var snapshot := reloaded.runtime_snapshot()
	check(reloaded.apply_runtime_snapshot(snapshot).ok, "validated runtime snapshot rebuilds the same catalog")
	snapshot.fingerprint = "tampered"
	check(not reloaded.apply_runtime_snapshot(snapshot).ok, "runtime snapshot rejects a stale fingerprint")
	ContentPackSystem.install_catalog(saved_catalog)
	DataManager.content_pack_system = saved_service
	if failures == 0: print("LOCAL CONTENT PACK TESTS PASSED")
	else: printerr("LOCAL CONTENT PACK TESTS FAILED: " + str(failures))
	get_tree().quit(0 if failures == 0 else 1)

func _test_tray_and_copy() -> void:
	var old := GameState.new()
	check(PlanetTraySystem.new(old).limit() == 999, "legacy saves preserve 999 tray rule")
	var state := GameState.new()
	SourceGalaxySystem.new(state).initialize(42, true)
	var tray := PlanetTraySystem.new(state)
	check(tray.limit() == 1000000, "new source galaxy uses one-million tray capacity")
	state.planet_inventory.iron_ingot = 2000.0
	check(tray.set_limit("home", 1000).ok and state.planet_inventory.iron_ingot == 2000 and not InventorySystem.new(state).can_add_batch({"iron_ingot": 1}), "lowering tray capacity retains goods and stops further deposits")
	check(GameStateValidator.validate_persistent_dict(GameStateCodec.to_persistent_dict(state)).is_empty(), "over-limit retained goods remain valid saved state")
	check(not tray.discard("home", "iron_ingot", 20, false).ok and state.planet_inventory.iron_ingot == 2000, "discard requires explicit confirmation")
	check(tray.discard("home", "iron_ingot", 20, true).ok and state.planet_inventory.iron_ingot == 1980, "confirmed discard removes only requested goods")
	GameModeSystem.new(state).configure_new_game("speedrun", "hard")
	state.speedrun_state.elapsed_active_seconds = 123.0
	var saves := SaveSystem.new("res://.godot/task26-copy-saves/")
	for slot in [0, 1]:
		if not saves.get_slot_info(slot).is_empty(): saves.delete_slot(slot)
	check(saves.save_slot(0, state).ok, "speedrun source saves")
	var source_digest: String = saves.load_slot(0).metadata.digest
	var copied := saves.copy_speedrun_to_normal(0, 1)
	var normal := saves.load_slot(1)
	check(copied.ok and normal.ok and normal.state.save_mode == "normal" and normal.state.speedrun_state.is_empty() and normal.state.difficulty == "hard" and normal.state.planet_inventory.iron_ingot == 1980, "one-way speedrun copy preserves factory, stock and difficulty")
	check(saves.load_slot(0).metadata.digest == source_digest and not saves.copy_speedrun_to_normal(0, 1).ok and not saves.copy_speedrun_to_normal(1, 2).ok, "copy protects source, occupied target and reverse conversion")
	var statistics := StatisticsSystem.new(state)
	statistics.record_produced("iron_ingot", 2)
	statistics.update(1)
	var industry := GalacticExportSystem.new(state).industry_snapshot(statistics)
	check(industry.networkInventory == 1980 and industry.totalProductionPerMinute > 0, "galactic industry snapshot derives real stored goods and production samples")

func _test_remote_station_configuration() -> void:
	var state := SourceDysonRegression.new().fresh()
	state.colonized_planet_ids.append("ashen")
	state.planet_inventories.ashen = {"space_warper": 5.0}
	state.planet_viewports.ashen = {"position": Vector2.ZERO, "zoom": Vector2.ONE}
	state.planet_metrics.ashen = {}
	state.completed_technologies.append("dsp_quantum_logistics_network")
	var id := state.add_building({"type": "dsp_interstellar_logistics_station", "planet_id": "ashen", "position": Vector2.ZERO, "input_buffer": {}, "output_buffer": {}, "station": StationSystem.empty_station("dsp_interstellar_logistics_station")})
	check(not StationSystem.new(state).configure_slots([id], 0, "iron_ingot", "supply", 1000, 0.1, 0).ok, "local configuration still protects inactive planet")
	var remote := StationSystem.new(state, true)
	check(remote.configure_slots([id], 0, "iron_ingot", "supply", 1000, 0.1, 0).ok and state.active_planet_id == "home", "global management configures owned station without changing active planet")
	check(remote.transfer_fleet(id, "space_warper", 3, true).ok and state.planet_inventories.ashen.space_warper == 2 and state.planet_inventory.get("space_warper", 0) == 0, "remote warper transfer debits station-owning planet")
	var upgrades := QuantumLogisticsSystem.new(state).upgrade_all("helios")
	check(upgrades.changed == [id] and state.buildings[id].station.tier == 2, "system-wide Mk.II command upgrades real eligible station")
	var before := GameStateCodec.to_persistent_dict(state)
	var diagnostic := remote.logistics_snapshot(id)
	check(diagnostic.local_cargo_capacity == 25 and diagnostic.local_trip_seconds == 8 and diagnostic.slots[0].minimum_remote_cargo == 10 and GameStateCodec.to_persistent_dict(state) == before, "station diagnostics derive cargo and minimum loads without mutation")
	state.construction_inventory.dsp_interstellar_logistics_station = 2.0
	check(remote.set_stack_target(id, 3).ok and state.construction_inventory.dsp_interstellar_logistics_station == 0 and state.buildings[id].station.slots[0].capacity == 3000 and StationSystem.fleet_capacity(state.buildings[id], "logistics_drone") == 150, "station stack consumes real pieces and scales slot and hangar capacity")
	check(remote.configure_slots([id], 0, "iron_ingot", "demand", 3000, 0.1, 0, "remote").ok, "stacked station config retains its rated capacity")
	state.progression_facts.infinite_research = {"galactic_logistics": {"level": 2, "invested": "0"}}
	var quantum := QuantumLogisticsSystem.new(state)
	check(quantum.attach(id).ok, "stacked station can attach")
	state.quantum_network = QuantumLogisticsSystem._initial()
	state.quantum_network.enabled = true
	quantum.deposit("iron_ingot", 10000)
	state.elapsed_time = 5
	quantum.update()
	check(state.buildings[id].station.slots[0].amount == 1512, "quantum throughput uses three real towers and two actual infinite-research levels")
	check(not remote.set_stack_target(id, 1).ok and state.buildings[id].station.slots[0].amount == 1512, "stack shrink cannot delete excess held cargo")
	var storage := SaveSystem.new("res://.godot/task26-stack-saves/")
	var saved := storage.save_slot(0, state)
	var loaded := storage.load_slot(0)
	check(saved.ok and loaded.ok and loaded.state.buildings[id].station_stack_count == 3, "stacked station persists with canonical digest: " + str(saved.get("error", {})))

func _test_source_gold(service: ContentPackSystem) -> void:
	var gold: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://tests/fixtures/parity/behavior/task26-content-packs.json"))
	for row in gold.cases: check(service.validate_manifest(row.input).ok == row.valid, "manifest validity matches frozen source " + row.id)
	for row in gold.ranges: check(ContentPackValidator.satisfies(row.actual, row.range) == row.result, "version range matches frozen source " + row.actual + " " + row.range)
	check(ContentPackSystem.fingerprint({"version": 1, "packs": {}}) == gold.empty_registry_fingerprint, "empty registry fingerprint matches frozen UTF-16 FNV encoding")

func _test_buffer_transport(service: ContentPackSystem) -> void:
	var pack := {"formatVersion": 2, "id": "buffer_test_pack", "name": "缓存测试", "version": "1.0.0", "buildings": [{"id": "local_splitter", "name": "分流器", "kind": "splitter", "costs": [{"itemId": "iron_ingot", "amount": 1}], "inputCapacity": 100, "outputCapacity": 100}, {"id": "local_storage", "name": "仓储", "kind": "storage", "costs": [{"itemId": "iron_ingot", "amount": 1}], "inputCapacity": 100, "outputCapacity": 100}, {"id": "local_generic_station", "name": "单物品站", "kind": "station", "costs": [{"itemId": "iron_ingot", "amount": 1}], "inputCapacity": 100, "outputCapacity": 100}]}
	check(service.register_pack(pack).ok, "custom storage, splitter and generic station register")
	var state := GameState.new()
	state.content_packs = service.references()
	state.construction_inventory.conveyor_belt_mk1 = 4.0
	state.construction_inventory.local_test_belt = 1.0
	var ids := []
	for index in range(3):
		var type := "local_splitter" if index == 0 else "local_storage" if index == 1 else "local_generic_station"
		state.construction_inventory[type] = 1.0
		var placed := ConstructionSystem.new(state).try_place_building(type, Vector2(index * 500, 0))
		check(placed.ok, "custom buffer construction places " + type + ": " + str(placed))
		if not placed.ok: return
		ids.append(placed.id)
		check(StorageBufferSystem.new(state).configure(placed.id, "iron_ingot").ok, "buffer config accepts one real item")
		state.buildings[placed.id].power_efficiency = 1.0
	state.buildings[ids[0]].input_buffer.iron_ingot = 12.0
	ProductionSystem.new(state).update(1)
	check(state.buildings[ids[0]].output_buffer.iron_ingot == 12 and state.buildings[ids[0]].input_buffer.iron_ingot == 0, "buffer transfer creates no stock")
	var a := state.try_add_connection(ids[0], ids[1], "iron_ingot")
	var b := state.try_add_connection(ids[0], ids[2], "iron_ingot")
	check(a.ok and b.ok, "configured buffers form real belt connections")
	if not a.ok or not b.ok: return
	BeltSystem.new(state).update(1)
	check(state.buildings[ids[1]].input_buffer.iron_ingot == 6 and state.buildings[ids[2]].input_buffer.iron_ingot == 6 and state.buildings[ids[0]].output_buffer.iron_ingot == 0, "balanced splitter fairly shares one source budget")
	check(state.try_configure_belt(a.id, {"tier": "local_test_belt"}).ok and state.construction_inventory.local_test_belt == 0, "custom tier change spends its own real belt and refunds old tier")
	state.buildings[ids[0]].output_buffer.iron_ingot = 80.0
	BeltSystem.new(state).update(1)
	var slow: float = state.get_belt_configuration(b.id).effective_throughput
	check(state.connections[a.id].current_flow == 80 - slow and state.connections[b.id].current_flow == slow, "fair allocation redistributes unused slow-belt budget to custom 100-per-second tier")
	check(not StorageBufferSystem.new(state).configure(ids[0], "copper_ingot").ok, "buffer item rebind rejects attached belts")
	check(GameStateValidator.validate_persistent_dict(GameStateCodec.to_persistent_dict(state)).is_empty(), "custom buffers and belts validate for persistence")
