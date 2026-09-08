extends Node

const Cards = preload("res://scripts/rendering/CardRenderer.gd")
const Lines = preload("res://scripts/rendering/ConnectionRenderer.gd")
var failures := 0
var scene_ready_ms := 0.0

func _ready() -> void:
	scene_ready_ms = Time.get_ticks_usec() / 1000.0
	call_deferred("_run")

func _run() -> void:
	_test_monitor()
	_test_index()
	_test_changing_state()
	_test_canvas_candidates()
	for scale in PerformanceFixtures.SCALES:
		await _benchmark(scale)
	print("PERFORMANCE BUDGET TESTS PASSED" if failures == 0 else "PERFORMANCE BUDGET TESTS FAILED")
	get_tree().quit(0 if failures == 0 else 1)

func _test_monitor() -> void:
	var monitor := PerformanceSystem.new()
	monitor.record("ignored", 1)
	_expect(monitor.get_report().metrics.is_empty(), "monitor defaults off")
	monitor.start()
	for i in range(4000): monitor.record("bounded", float(i))
	var metric: Dictionary = monitor.get_report().metrics.bounded
	_expect(metric.samples == 3600 and metric.total_samples == 4000 and metric.max == 3999.0, "bounded ring retains latest measurements")
	monitor.stop()
	monitor.record("bounded", 9999)
	_expect(monitor.get_report().metrics.bounded.max == 3999.0, "stop freezes samples")
	var result := monitor.export_report("res://.godot/performance-tests")
	_expect(result.ok, "exports both report formats")
	if result.ok:
		var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(result.json_path))
		_expect(parsed is Dictionary and parsed.metrics.bounded.samples == 3600, "exported JSON is readable")
		_expect(FileAccess.get_file_as_string(result.path).contains("P95"), "human report includes percentiles")

func _test_index() -> void:
	var index := SpatialIndex.new()
	index.add_entity("negative", Vector2(-1, -1))
	index.add_entity("negative", Vector2(-257, -257))
	_expect(index.get_entity_count() == 1 and index.get_cell_count() == 1, "duplicate IDs replace old cells")
	_expect(index.get_entities_in_rect(Rect2(-258, -258, 2, 2)).has("negative"), "negative cell boundary query")
	index.update_entity("negative", Vector2.ZERO, Vector2(512, 512))
	_expect(not index.get_entities_in_rect(Rect2(-258, -258, 2, 2)).has("negative"), "move removes old candidates")
	index.remove_entity("negative", Vector2.ZERO)
	_expect(index.get_entity_count() == 0 and index.get_cell_count() == 0, "remove cleans cells using recorded location")

func _benchmark(scale: String) -> void:
	var monitor := PerformanceSystem.new()
	monitor.start({"fixture": scale, "fixture_version": 1, "ticks": 30, "stations": int(PerformanceFixtures.SCALES[scale]) / 16, "viewport": "1152x648", "measurement": "synthetic local trend; no universal time threshold"})
	monitor.record("engine_to_test_scene_ready_ms", scene_ready_ms)
	var started := monitor.begin()
	var state := PerformanceFixtures.create_factory(scale)
	monitor.game_state = state
	monitor.finish("fixture_create_ms", started)
	var naive := PerformanceFixtures.create_factory(scale)
	var engine := SimulationEngine.new(state)
	engine.performance_monitor = monitor
	var reference := SimulationEngine.new(naive)
	reference.optimize_queries = false
	for tick in range(30):
		started = monitor.begin()
		reference.update(SimulationEngine.FIXED_DELTA)
		monitor.finish("reference_update_ms", started)
		started = monitor.begin()
		engine.update(SimulationEngine.FIXED_DELTA)
		monitor.finish("optimized_update_ms", started)
	_expect(GameStateCodec.state_digest_payload(state) == GameStateCodec.state_digest_payload(naive), "%s monitored/optimized state equals reference after 30 ticks" % scale)
	started = monitor.begin()
	var json := JSON.stringify(GameStateCodec.to_persistent_dict(state), "", true, true)
	monitor.finish("serialize_ms", started)
	monitor.record("save_bytes", json.to_utf8_buffer().size())
	var file := FileAccess.open("res://.godot/performance-fixture.json", FileAccess.WRITE)
	started = monitor.begin()
	file.store_string(json)
	file.flush()
	monitor.finish("file_write_ms", started)
	file.close()
	var saves := SaveSystem.new("res://.godot/performance-saves/%s-%s" % [scale, Time.get_ticks_usec()])
	started = monitor.begin()
	var saved := saves.save_slot(0, state)
	monitor.finish("save_verified_ms", started)
	_expect(saved.get("ok", false), "%s validated save: %s" % [scale, saved.get("error", {})])
	if saved.get("ok", false):
		started = monitor.begin()
		var loaded := saves.load_slot(0)
		monitor.finish("load_verified_ms", started)
		_expect(loaded.get("ok", false), "%s loads generated save" % scale)
		if loaded.get("ok", false):
			_expect(GameStateCodec.state_digest_payload(loaded.state) == GameStateCodec.state_digest_payload(state), "%s save/load preserves state" % scale)
	if DisplayServer.get_name() != "headless":
		await _render_benchmark(state, monitor)
	monitor.stop()
	var result := monitor.export_report("res://.godot/performance-tests")
	_expect(result.ok, "%s report exported" % scale)
	print("PERFORMANCE REPORT %s %s" % [scale, result.get("path", "")])

func _render_benchmark(state: GameState, monitor: PerformanceSystem) -> void:
	var viewport := SubViewport.new()
	viewport.size = Vector2i(1152, 648)
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	add_child(viewport)
	var cards := Cards.new()
	cards.set_game_state(state)
	viewport.add_child(cards)
	var lines := Lines.new()
	lines.set_game_state(state)
	viewport.add_child(lines)
	var original := GameManager.performance_monitor
	GameManager.performance_monitor = monitor
	for optimized in [false, true]:
		cards.optimize_rendering = optimized
		lines.optimize_rendering = optimized
		cards.profile_prefix = "optimized_" if optimized else "reference_"
		lines.profile_prefix = cards.profile_prefix
		await RenderingServer.frame_post_draw
		for frame in range(30):
			var started := monitor.begin()
			await RenderingServer.frame_post_draw
			monitor.finish("optimized_frame_ms" if optimized else "reference_frame_ms", started)
	viewport.canvas_transform = Transform2D(Vector2(0.45, 0), Vector2(0, 0.45), Vector2(300, 200))
	await RenderingServer.frame_post_draw
	if OS.get_cmdline_user_args().has("--capture"):
		viewport.get_texture().get_image().save_png("res://.godot/task18-lod-%s.png" % state.buildings.size())
	GameManager.performance_monitor = original
	viewport.queue_free()
	await get_tree().process_frame

func _expect(condition: bool, message: String) -> void:
	if condition: print("PASS: " + message)
	else:
		failures += 1
		printerr("FAIL: " + message)

func _test_changing_state() -> void:
	var state := PerformanceFixtures.create_factory("small")
	var reference := PerformanceFixtures.create_factory("small")
	var engine := SimulationEngine.new(state)
	var naive := SimulationEngine.new(reference)
	naive.optimize_queries = false
	for turn in range(8):
		for candidate in [state, reference]:
			candidate.connections.values()[0]["priority"] = turn % 3
			candidate.connections.values()[0]["enabled"] = turn % 2 == 0
			candidate.buildings.fixture_0000["generation_factor"] = 0.0 if turn % 2 else 1.0
			candidate.buildings.fixture_0002["input_buffer_capacity"] = float(5 + turn)
			candidate.buildings.fixture_0002["recipe_id"] = "" if turn % 2 else "iron_ingot_recipe"
			candidate.buildings.fixture_0001["output_buffer"] = {"iron_ore": float(turn)}
		engine.update(SimulationEngine.FIXED_DELTA)
		naive.update(SimulationEngine.FIXED_DELTA)
		_expect(GameStateCodec.state_digest_payload(state) == GameStateCodec.state_digest_payload(reference), "changing power, inventory, priority, enabled, recipe, capacity stays equivalent %d" % turn)
	var index := state.get_spatial_index()
	state.buildings.fixture_0001.position = Vector2(-999, -999)
	state.get_spatial_index()
	_expect(index.get_entities_in_rect(Rect2(-1000, -1000, 2, 2)).has("fixture_0001"), "direct mutation refreshes spatial cache")
	state.buildings.erase("fixture_0001")
	state.get_spatial_index()
	_expect(not index.get_entities_in_rect(Rect2(-1000, -1000, 2, 2)).has("fixture_0001"), "deletion invalidates spatial cache")

func _test_canvas_candidates() -> void:
	var state := PerformanceFixtures.create_factory("medium")
	var viewport := SubViewport.new()
	viewport.size = Vector2i(1152, 648)
	add_child(viewport)
	var cards := Cards.new()
	cards.set_game_state(state)
	viewport.add_child(cards)
	for zoom in [0.45, 1.0, 1.8]:
		viewport.canvas_transform = Transform2D(Vector2(zoom, 0), Vector2(0, zoom), Vector2(300, 200))
		var expected: Array[String] = []
		var view := cards.world_view_rect().grow(8)
		for id in cards.get_visible_building_ids():
			if view.intersects(Rect2(state.buildings[id].position, Cards.CARD_SIZE)): expected.append(id)
		_expect(cards.get_draw_building_ids() == expected, "spatial draw candidates equal naive geometry at zoom %s" % zoom)
	viewport.free()
