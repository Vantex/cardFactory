extends Node
var failures := 0
func expect(ok: bool, message: String) -> void:
	if not ok:
		failures += 1
		printerr("BLUEPRINT PERSISTENCE: " + message)

func _ready() -> void:
	var state := GameState.new()
	var bp := {"version": 1, "entities": [{"ref": "entity_0", "type": "smelter", "position": Vector2.ZERO, "configuration": {"recipe_id": "iron_ingot_recipe"}}], "connections": []}
	var library := BlueprintLibrary.new(state)
	var saved := library.save_definition("冶炼区", bp)
	expect(saved.ok, "save library definition")
	if not saved.ok: get_tree().quit(1); return
	var id: String = saved.id
	library.rename(id, "铁块")
	expect(state.blueprint_library[id].name == "铁块", "rename authoritative library")
	var queue := ConstructionQueueSystem.new(state)
	var enqueued := queue.enqueue(state.blueprint_library[id], Vector2(1000, 0))
	expect(enqueued.ok and state.buildings.is_empty(), "queue creates non-running ghost without a building")
	if not enqueued.ok: get_tree().quit(1); return
	state.construction_inventory.smelter = 0.0
	expect(queue.fund(enqueued.id).ok and state.buildings.is_empty(), "missing kits do not produce free buildings")
	var loaded := GameStateCodec.from_persistent_dict(GameStateCodec.to_persistent_dict(state))
	expect(loaded != null and loaded.blueprint_library == state.blueprint_library and loaded.construction_queue == state.construction_queue, "library and pending order survive codec round trip")
	var disk := SaveSystem.new("res://.godot/blueprint-persistence-%d/" % Time.get_ticks_usec())
	var written := disk.save_slot(0, state)
	var reopened := disk.load_slot(0) if written.ok else {}
	expect(written.ok and reopened.get("ok", false), "integer blueprint transforms and pending orders pass actual disk verification")
	if reopened.get("ok", false):
		expect(preload("res://scripts/test/SpecialProductionBehaviorRunner.gd")._difference(GameStateCodec.to_persistent_dict(reopened.state), GameStateCodec.to_persistent_dict(state)).is_empty(), "complete disk state preserves library and pending order allowing JSON number representation")
	library.remove(id)
	state.construction_inventory.smelter = 1.0
	var funded := queue.fund(enqueued.id)
	expect(funded.ok and funded.completed and state.buildings.size() == 1 and state.construction_queue.is_empty() and state.construction_inventory.smelter == 0, "funding independent snapshot pays kit once after library deletion")
	var encoded := BlueprintCodec.new().encode(bp)
	var entry := {"name": "复用", "text": encoded.text, "rotation": 0, "mirrored": false}
	expect(not queue.enqueue(entry, Vector2(1000, 0)).ok, "default overlap rejected")
	var reuse := queue.enqueue(entry, Vector2(1000, 0), true)
	expect(reuse.ok, "explicit exact overlap can reuse compatible building")
	if reuse.ok: expect(queue.fund(reuse.id).ok and state.buildings.size() == 1, "reuse does not duplicate building or charge a second kit")
	var pending := queue.enqueue(entry, Vector2(1500, 0))
	state.construction_inventory.smelter = 1.0
	# Two-building order demonstrates partial escrow and cancellation.
	bp.entities.append({"ref": "entity_1", "type": "smelter", "position": Vector2(400, 0), "configuration": {"recipe_id": "iron_ingot_recipe"}})
	entry.text = BlueprintCodec.new().encode(bp).text
	var partial := queue.enqueue(entry, Vector2(2200, 0))
	expect(partial.ok and queue.fund(partial.id).ok and state.construction_inventory.smelter == 0, "partial funding reserves only owned kits")
	expect(queue.cancel(partial.id).ok and state.construction_inventory.smelter == 1, "cancel returns exact unconsumed escrow")
	expect(not queue.cancel(partial.id).ok and state.construction_inventory.smelter == 1, "repeat cancellation cannot mint kits")
	queue.cancel(pending.id)
	var nav := CanvasNavigation.new(state)
	var bookmark := nav.save_bookmark("主厂", Vector2(33, 44), 1.2)
	var region := nav.save_region("冶炼区", Rect2(0, 0, 600, 300), Color.CYAN)
	expect(bookmark.ok and region.ok, "navigation records created")
	for i in range(26): nav.save_bookmark("镜头%d" % i, Vector2(i, 0), 1)
	for i in range(50): nav.save_region("区域%d" % i, Rect2(i, 0, 300, 200), Color.CYAN)
	expect(state.canvas_bookmarks.size() == 24 and state.canvas_regions.size() == 48, "frozen bookmark and region limits retain newest")
	loaded = GameStateCodec.from_persistent_dict(GameStateCodec.to_persistent_dict(state))
	expect(loaded != null and loaded.canvas_regions == state.canvas_regions and loaded.canvas_bookmarks == state.canvas_bookmarks, "navigation survives save")
	var corrupt := GameStateCodec.to_persistent_dict(state)
	corrupt.canvas_bookmarks[0].zoom = INF
	expect(GameStateCodec.from_persistent_dict(corrupt) == null, "invalid persisted viewport rejected")
	_test_fleet_and_transforms()
	_test_recipe_and_automatic_funding()
	_test_legacy_digest()
	if failures == 0: print("BLUEPRINT PERSISTENCE TESTS PASSED")
	else: printerr("BLUEPRINT PERSISTENCE TESTS FAILED")
	get_tree().quit(0 if failures == 0 else 1)

func _test_legacy_digest() -> void:
	var path := "res://.godot/legacy-blueprint-dyson-%d/" % Time.get_ticks_usec()
	var service := SaveSystem.new(path)
	var file := FileAccess.open(path + "save_1.json", FileAccess.WRITE)
	expect(file != null, "legacy digest fixture destination opens")
	if file == null: return
	file.store_string(FileAccess.get_file_as_string("res://tests/fixtures/task27-legacy-blueprint-dyson-save.json"))
	file.close()
	var loaded := service.load_slot(1)
	expect(loaded.ok, "previously successful float blueprint/orbit disk keeps its original digest")
	if loaded.ok:
		expect(loaded.state.blueprint_library.size() == 1 and DysonSphereSystem.new(loaded.state).get_summary("helios").launched_sails == 1, "legacy verified disk preserves blueprint and launched sail ownership")

func _test_fleet_and_transforms() -> void:
	var state := GameState.new()
	var bp := {"version": 1, "entities": [{"ref": "station", "type": "planetary_logistics_station", "position": Vector2.ZERO, "configuration": {}}], "connections": []}
	var library := BlueprintLibrary.new(state)
	var saved := library.save_definition("运输站", bp, "", 3, true, {}, {"station": {"logistics_drone": 2}})
	expect(saved.ok, "valid station fleet targets saved")
	if not saved.ok: return
	var entry: Dictionary = state.blueprint_library[saved.id]
	var exported := BlueprintCodec.new().encode_library_entry(entry)
	var imported := BlueprintCodec.new().decode_library_entry(exported.text)
	expect(imported.ok and imported.entry.rotation == 3 and imported.entry.mirrored and imported.entry.fleet_targets.station.logistics_drone == 2, "portable library preserves transform and fleet targets")
	var queue := ConstructionQueueSystem.new(state)
	var unchanged := GameStateCodec.to_persistent_dict(state)
	expect(not queue.deploy_immediately(entry, Vector2(4000, 0)).ok and GameStateCodec.to_persistent_dict(state) == unchanged, "immediate deployment refuses missing kits and fleet atomically")
	var order := queue.enqueue(entry, Vector2(4000, 0))
	expect(order.ok, "station queue preflight")
	if not order.ok: return
	state.construction_inventory.planetary_logistics_station = 1.0
	var funded := queue.fund(order.id, "construction")
	expect(funded.ok and not funded.completed and state.buildings.size() == 1 and state.construction_queue.size() == 1, "construction completes independently while waiting for fleet")
	var station_id: String = state.buildings.keys()[0]
	state.planet_inventory.logistics_drone = 1.0
	queue.fund(order.id, "fleet")
	expect(state.planet_inventory.logistics_drone == 0 and state.buildings[station_id].station.fleet.logistics_drone == 0, "partial fleet funding owns reserved vehicle exactly once")
	var restored := GameStateCodec.from_persistent_dict(GameStateCodec.to_persistent_dict(state))
	expect(restored != null and restored.construction_queue[0].fleet_reserved.logistics_drone == 1, "waiting fleet reservation survives save")
	if restored != null:
		expect(ConstructionQueueSystem.new(restored).cancel(order.id).ok and restored.planet_inventory.logistics_drone == 1 and restored.buildings.size() == 1, "cancel waiting fleet refunds escrow and keeps paid building")
	state.planet_inventory.logistics_drone = 1.0
	expect(queue.fund(order.id).completed and state.buildings[station_id].station.fleet.logistics_drone == 2 and state.construction_queue.is_empty(), "fleet completion installs paid vehicles once")
	var reuse := queue.enqueue(entry, Vector2(4000, 0), true)
	expect(reuse.ok and queue.fund(reuse.id).completed and state.buildings[station_id].station.fleet.logistics_drone == 2, "reused station fleet target credits already installed vehicles")
	var invalid := entry.duplicate(true)
	invalid.fleet_targets.station.logistics_vessel = 1
	expect(not queue.enqueue(invalid, Vector2(5000, 0)).ok, "incompatible planetary station fleet rejected")
	var corrupt := GameStateCodec.to_persistent_dict(state)
	corrupt.blueprint_library[saved.id].text = "{}"
	expect(GameStateCodec.from_persistent_dict(corrupt) == null, "malformed persisted library rejected")

func _test_recipe_and_automatic_funding() -> void:
	var state := GameState.new()
	var bp := {"version": 1, "entities": [{"ref": "smelter", "type": "smelter", "position": Vector2.ZERO, "configuration": {"recipe_id": "iron_ingot_recipe"}}], "connections": []}
	var library := BlueprintLibrary.new(state)
	var saved := library.save_definition("铜冶炼", bp, "", 1, true, {"iron_ingot_recipe": "copper_ingot_recipe"})
	expect(saved.ok, "compatible recipe override accepted")
	if not saved.ok: return
	var restored := GameStateCodec.from_persistent_dict(GameStateCodec.to_persistent_dict(state))
	expect(restored != null and BlueprintLibrary.resolve(restored.blueprint_library[saved.id]).blueprint.entities[0].configuration.recipe_id == "copper_ingot_recipe", "recipe override survives persistence and resolves")
	expect(not library.save_definition("无效", bp, "", 0, false, {"iron_ingot_recipe": "gear_recipe"}).ok, "incompatible recipe override rejected")
	var queue := ConstructionQueueSystem.new(state)
	expect(queue.enqueue(state.blueprint_library[saved.id], Vector2(6000, 0)).ok, "queue overridden blueprint")
	state.construction_inventory.smelter = 1.0
	var engine := SimulationEngine.new(state)
	state.paused = true
	for i in range(61): engine.update(SimulationEngine.FIXED_DELTA)
	expect(state.buildings.is_empty(), "paused simulation does not auto-fund")
	state.paused = false
	for i in range(60): engine.update(SimulationEngine.FIXED_DELTA)
	expect(state.construction_queue.is_empty() and state.buildings.size() == 1 and state.buildings.values()[0].recipe_id == "copper_ingot_recipe" and state.construction_inventory.smelter == 0, "one simulated second funds exact recipe and kit")
	var nav := CanvasNavigation.new(state)
	var region := nav.save_region("区域", Rect2(0, 0, 100, 100), Color.RED)
	expect(nav.save_region("调整", Rect2(10, 20, 200, 300), Color.BLUE, region.id).ok and state.canvas_regions[0].rect == [10.0, 20.0, 200.0, 300.0], "region geometry and color update")
	expect(nav.rename(region.id, "新名称").ok and state.canvas_regions[0].name == "新名称", "region rename")
	var corrupt := GameStateCodec.to_persistent_dict(state)
	corrupt.canvas_regions[0].rect = [99999, 0, 100, 100]
	expect(GameStateCodec.from_persistent_dict(corrupt) == null, "persisted region endpoint obeys command bounds")
	expect(nav.remove(region.id).ok and state.canvas_regions.is_empty(), "region removal")
