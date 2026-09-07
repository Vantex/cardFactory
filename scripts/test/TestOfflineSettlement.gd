extends Node

var failures := 0
var root_path := "res://.godot/task16-tests-%d-%d" % [OS.get_process_id(), Time.get_ticks_usec()]

class TestStorage extends SaveSystem:
	var clock := 1000.0
	var fail_save := false
	var fail_journal := false
	var fail_replace := false
	func wall_time() -> float: return clock
	func save_slot(slot: int, state: GameState, options: Dictionary = {}) -> Dictionary:
		if fail_save: return {"ok": false, "error": {"code": "write_failed", "message": "injected save failure"}}
		return super.save_slot(slot, state, options)
	func _rename_file(source: String, target: String) -> Error:
		if fail_replace and source.ends_with(".json.tmp") and target.ends_with(".json"): return ERR_CANT_CREATE
		return super._rename_file(source, target)
	func _write_text(path: String, text: String) -> Error:
		if fail_journal and path.contains(".offline"): return ERR_CANT_CREATE
		return super._write_text(path, text)

func _ready() -> void:
	_test_exact_replay()
	_test_recovery_and_receipts()
	_test_limits_and_discard()
	_test_boundaries()
	_test_legacy_and_corruption()
	await _test_formal_ui()
	if failures > 0:
		printerr("OFFLINE SETTLEMENT TESTS FAILED")
		get_tree().quit(1)
	else:
		print("OFFLINE SETTLEMENT TESTS PASSED")
		get_tree().quit(0)

func _storage(name: String) -> TestStorage:
	return TestStorage.new(root_path + "/" + name)

func _factory() -> GameState:
	var state := GameState.new()
	PlanetSystem.new(state).initialize_colonized_resource_sites()
	state.add_building({"type": "power_generator", "position": Vector2.ZERO, "fuel_item": "coal", "fuel_remaining": 100.0, "input_buffer": {}, "output_buffer": {}})
	state.add_building({"type": "smelter", "position": Vector2(300, 0), "recipe_id": "iron_ingot_recipe", "input_buffer": {"iron_ore": 20.0}, "output_buffer": {}})
	return state

func _drain(job: OfflineSettlementSystem) -> void:
	for i in range(20):
		if job.phase != "simulating": break
		job.advance(600, 100000000)
	_expect(job.phase in ["ready", "complete"], "bounded offline simulation completes")

func _online(state: GameState, ticks: int) -> GameState:
	var copy := state.copy_state()
	var engine := SimulationEngine.new(copy)
	var blocked := EventBus.is_blocking_signals()
	EventBus.set_block_signals(true)
	for i in range(ticks): engine.update(1.0 / 60)
	EventBus.set_block_signals(blocked)
	return copy

func _same(a: GameState, b: GameState) -> bool:
	return _equivalent(GameStateCodec.to_persistent_dict(a), GameStateCodec.to_persistent_dict(b))

func _equivalent(a: Variant, b: Variant) -> bool:
	if (a is int or a is float) and (b is int or b is float):
		return absf(float(a) - float(b)) <= 0.000000001
	if a is Dictionary and b is Dictionary:
		if a.size() != b.size(): return false
		for key in a:
			if not b.has(key) or not _equivalent(a[key], b[key]): return false
		return true
	if a is Array and b is Array:
		if a.size() != b.size(): return false
		for i in range(a.size()):
			if not _equivalent(a[i], b[i]): return false
		return true
	return a == b
func _test_exact_replay() -> void:
	var save := _storage("exact")
	var state := _factory()
	_expect(save.save_slot(0, state).ok, "fixture saves")
	var before := GameStateCodec.to_persistent_dict(state)
	save.clock = 1010.5
	var job := OfflineSettlementSystem.new()
	_expect(job.begin(save, 0, save.clock).ok and job.phase == "simulating", "continue creates pending offline transaction")
	job.advance(7, 1000000)
	_expect(job.ticks_done == 7 and _same(save.load_slot(0).state, state), "partial replay leaves original slot untouched")
	_drain(job)
	_expect(_same(job.state, _online(state, 630)), "offline replay matches exact online ticks including partial second")
	_expect(GameStateCodec.to_persistent_dict(state) == before, "working copy cannot mutate caller state")
	_expect(not job.report.produced.is_empty(), "report records actual production")
	_expect(job.commit().ok and _same(save.load_slot(0).state, job.state), "validated result commits atomically")
	var committed := GameStateCodec.to_persistent_dict(job.state)
	_expect(job.commit().ok and _equivalent(GameStateCodec.to_persistent_dict(save.load_slot(0).state), committed), "duplicate commit grants nothing")
	var repeated := OfflineSettlementSystem.new()
	_expect(repeated.begin(save, 0, save.clock).ok and repeated.phase == "complete" and _same(repeated.state, job.state), "same interval is applied once after restart")
	_expect(not EventBus.is_blocking_signals(), "offline replay restores global signals")
	save.clock = 1001
	var after_receipt_rollback := OfflineSettlementSystem.new()
	_expect(after_receipt_rollback.begin(save, 0, save.clock).ok and after_receipt_rollback.report.clock_rollback, "clock rollback after an existing receipt is reported")
	_expect(after_receipt_rollback.commit().ok and save.load_slot(0).metadata.saved_at == 1010.5, "receipt rollback keeps monotonic save time")

func _test_recovery_and_receipts() -> void:
	var save := _storage("recovery")
	var base := _factory()
	save.save_slot(0, base)
	save.clock = 1005
	var interrupted := OfflineSettlementSystem.new()
	interrupted.begin(save, 0, save.clock)
	interrupted.advance(30, 100000000)
	var recovered := OfflineSettlementSystem.new()
	_expect(recovered.begin(save, 0, 1008).ok and recovered.ticks_done == 0 and recovered.entry.target_time == 1005, "interruption restarts verified base with original target")
	_drain(recovered)
	save.fail_save = true
	_expect(not recovered.commit().ok and _same(save.load_slot(0).state, base), "save failure preserves original slot")
	var prepared := OfflineSettlementJournal.new(save, 0).read()
	_expect(prepared.ok and prepared.entry.phase == "prepared", "result is durable before main slot replacement")
	save.fail_save = false
	var failed_replace := OfflineSettlementSystem.new()
	failed_replace.begin(save, 0, save.clock)
	save.fail_replace = true
	_expect(not failed_replace.commit().ok and _same(save.load_slot(0).state, base), "failed replacement after backup rotation restores base")
	save.fail_replace = false
	var resumed := OfflineSettlementSystem.new()
	_expect(resumed.begin(save, 0, save.clock).ok and resumed.phase == "ready", "prepared transaction resumes without resimulation")
	_expect(_same(resumed.state, _online(base, 300)) and resumed.commit().ok, "prepared recovery commits exact result")
	var again := OfflineSettlementSystem.new()
	_expect(again.begin(save, 0, save.clock).ok and again.phase == "complete", "crash after replacement before acknowledgement cannot replay receipt")
	var file := FileAccess.open(save.settlement_path(0).trim_suffix(".offline"), FileAccess.WRITE)
	file.store_string("{broken")
	file.close()
	var backup_recovery := OfflineSettlementSystem.new()
	_expect(backup_recovery.begin(save, 0, save.clock).ok and backup_recovery.phase == "ready", "base backup plus prepared journal recovers committed result")
	_expect(backup_recovery.commit().ok and _same(backup_recovery.state, resumed.state), "backup recovery preserves unique material ownership")
	var conflict_save := _storage("conflict")
	conflict_save.save_slot(0, base)
	conflict_save.clock = 1010
	var stale := OfflineSettlementSystem.new()
	stale.begin(conflict_save, 0, conflict_save.clock)
	_drain(stale)
	var edited := base.copy_state()
	edited.planet_inventory["coal"] = 5.0
	conflict_save.save_slot(0, edited)
	_expect(not stale.commit().ok and _same(conflict_save.load_slot(0).state, edited), "stale offline result cannot overwrite newer slot")
	var journal_failure := _storage("journal_failure")
	journal_failure.save_slot(0, base)
	journal_failure.fail_journal = true
	var failed := OfflineSettlementSystem.new()
	_expect(not failed.begin(journal_failure, 0, 1010).ok and _same(journal_failure.load_slot(0).state, base), "journal write failure starts no simulation")

func _test_limits_and_discard() -> void:
	var save := _storage("limits")
	var base := _factory()
	save.save_slot(0, base)
	save.clock = 900
	var rollback := OfflineSettlementSystem.new()
	_expect(rollback.begin(save, 0, save.clock).ok and rollback.phase == "ready", "clock rollback never becomes positive time")
	_expect(rollback.commit().ok and rollback.report.clock_rollback and _same(rollback.state, base), "rollback grants nothing")
	_expect(save.load_slot(0).metadata.saved_at == 1000, "rollback cannot lower persisted time boundary")
	save.clock = 1000.5
	var short_gap := OfflineSettlementSystem.new()
	_expect(short_gap.begin(save, 0, save.clock).ok and short_gap.phase == "complete", "subsecond reopen is not replayed")
	save.clock = 10000
	var long_gap := OfflineSettlementSystem.new()
	long_gap.begin(save, 0, save.clock)
	_expect(long_gap.entry.ticks == 7200, "long offline is capped at 120 seconds")
	long_gap.advance(15, 100000000)
	_expect(long_gap.discard().ok and long_gap.commit().ok and _same(long_gap.state, base), "discard abandons all uncommitted gains")
	_expect(long_gap.report.discarded and long_gap.report.simulated_seconds == 0 and long_gap.report.skipped_seconds == 9000, "discard report describes full skipped period")
	var no_retry := OfflineSettlementSystem.new()
	_expect(no_retry.begin(save, 0, save.clock).ok and no_retry.phase == "complete", "discarded interval cannot be farmed on reopen")
	save.clock += 200
	var capped := OfflineSettlementSystem.new()
	capped.begin(save, 0, save.clock)
	_drain(capped)
	_expect(capped.report.simulated_seconds == 120 and capped.report.skipped_seconds == 80, "cap reports actual simulated and skipped time")
	_expect(capped.report.blocked.has("no_fuel") and capped.report.produced.get("iron_ingot", 0) == 20, "offline report reflects depleted fuel and finite input production")
	var cap_commit := capped.commit()
	if not cap_commit.ok: print("CAP COMMIT ", cap_commit)
	_expect(cap_commit.ok, "capped replay commits")
	_expect(_same(capped.state, _online(base, 7200)), "capped replay remains exact")

func _test_boundaries() -> void:
	var save := _storage("boundaries")
	var state := _factory()
	state.planet_inventory["matrix_science_1"] = 10.0
	state.sync_active_planet_inventory()
	state.add_building({"type": "matrix_lab", "position": Vector2(600, 0), "input_buffer": {}, "output_buffer": {}})
	_expect(TechnologySystem.new(state).start_research("factory_foundations"), "fixture starts real research")
	state.research_progress.factory_foundations = 9.95
	_expect(save.save_slot(0, state).ok, "research boundary saves")
	save.clock = 1002
	var job := OfflineSettlementSystem.new()
	job.begin(save, 0, save.clock)
	_drain(job)
	_expect(job.state.completed_technologies.has("factory_foundations") and job.report.technologies.has("factory_foundations"), "offline completion crosses real technology boundary")
	_expect(_same(job.state, _online(state, 120)), "research and production timing equals online simulation")
	state = _factory()
	state.completed_technologies = ["factory_foundations", "fluid_handling", "advanced_materials", "interstellar_logistics", "dyson_engineering"]
	var dyson := DysonSphereSystem.new(state)
	var orbit: String = dyson.create_orbit("helios").id
	state.dyson_systems.helios.orbits[orbit].cohorts = [{"count": 1, "expires_tick": 30}]
	state.dyson_systems.helios.sails_launched = 1
	var a := _station(state, Vector2(600, 0))
	var b := _station(state, Vector2(900, 0))
	var stations := StationSystem.new(state)
	stations.configure_slots([a], 0, "iron_ore", "supply", 100, 0.1, 1)
	stations.configure_slots([b], 0, "iron_ore", "demand", 100, 0.1, 1)
	state.planet_inventory = {"iron_ore": 40.0, "logistics_drone": 1.0}
	state.sync_active_planet_inventory()
	stations.transfer_cargo(a, 0, 40, true)
	stations.transfer_fleet(a, "logistics_drone", 1, true)
	SimulationEngine.new(state).update(1.0 / 60)
	_expect(state.logistics_routes.size() == 1, "fixture owns actual in-flight cargo")
	var traffic := _storage("traffic")
	_expect(traffic.save_slot(0, state).ok, "in-flight boundary saves")
	traffic.clock = 1020
	var flight := OfflineSettlementSystem.new()
	flight.begin(traffic, 0, traffic.clock)
	_drain(flight)
	_expect(_same(flight.state, _online(state, 1200)), "offline sail decay and in-flight logistics exactly match online")
	_expect(DysonSphereSystem.new(flight.state).get_summary("helios").expired_sails == 1, "offline sails expire on their exact tick")

func _station(state: GameState, position: Vector2) -> String:
	state.construction_inventory["planetary_logistics_station"] = 1.0
	var result := state.try_place_building("planetary_logistics_station", position)
	_expect(result.ok, "logistics station fixture places")
	return String(result.get("id", ""))

func _test_formal_ui() -> void:
	var original_save := GameManager.get_save_system()
	var original_state := GameManager.get_game_state()
	var save := _storage("ui")
	GameManager.set_process(false)
	GameManager.end_session()
	GameManager.configure_save_system(save)
	var base := _factory()
	save.save_slot(0, base)
	save.clock = 1005
	var viewport := SubViewport.new()
	viewport.size = Vector2i(1152, 648)
	add_child(viewport)
	var main: Node = load("res://scenes/main/Main.tscn").instantiate()
	viewport.add_child(main)
	await get_tree().process_frame
	var shell: Node = main.get_node("AppShell")
	var result := GameManager.continue_game(0)
	var panel: Control = shell.get_node("OfflineReportWorkspace")
	_expect(result.ok and result.pending and not GameManager.is_session_active() and panel.visible, "formal continue shows offline workspace before installing state")
	_expect(not main.get_node("InputHandler").is_processing_input(), "offline workspace disables factory input")
	panel.discard_button.pressed.emit()
	GameManager.advance_offline_settlement()
	_expect(GameManager.is_session_active() and panel.visible and panel.close_button.visible and GameManager.get_game_state().elapsed_time == base.elapsed_time, "formal discard commits boundary and shows report")
	panel.close_button.pressed.emit()
	_expect(not panel.visible and shell.get_screen_name() == "game", "report close returns to factory")
	GameManager.end_session()
	save.save_slot(1, base)
	save.clock += 5
	GameManager.continue_game(1)
	save.fail_save = true
	for i in range(301):
		GameManager.advance_offline_settlement()
		if GameManager.get_offline_snapshot().get("phase") == "error": break
	_expect(not GameManager.is_session_active() and panel.retry_button.visible and _same(save.load_slot(1).state, base), "formal write failure keeps session inactive and exposes retry")
	save.fail_save = false
	panel.retry_button.pressed.emit()
	GameManager.advance_offline_settlement()
	_expect(GameManager.is_session_active() and panel.close_button.visible and GameManager.get_game_state().elapsed_time > base.elapsed_time, "formal retry commits prepared result and opens report")
	panel.close_button.pressed.emit()
	GameManager.end_session()
	GameManager.configure_save_system(original_save)
	GameManager.replace_game_state(original_state)
	GameManager.set_process(true)
	viewport.queue_free()
	await get_tree().process_frame

func _expect(condition: bool, message: String) -> void:
	if not condition:
		failures += 1
		printerr("OFFLINE: " + message)

func _test_legacy_and_corruption() -> void:
	var save := _storage("legacy")
	var base := _factory()
	var primary := save.settlement_path(0).trim_suffix(".offline")
	var file := FileAccess.open(primary, FileAccess.WRITE)
	file.store_string(JSON.stringify(GameStateCodec.to_persistent_dict(base), "", true, true))
	file.close()
	var legacy := OfflineSettlementSystem.new()
	_expect(legacy.begin(save, 0, 1000).ok and legacy.phase == "ready" and legacy.report.unknown_start_time, "legacy save without timestamp grants no historic gains")
	_expect(legacy.commit().ok and _same(legacy.state, base) and save.load_slot(0).metadata.saved_at == 1000, "legacy continue establishes durable time boundary")
	for suffix in ["", ".bak"]:
		file = FileAccess.open(save.settlement_path(0) + suffix, FileAccess.WRITE)
		file.store_string("{corrupt")
		file.close()
	var corrupt := OfflineSettlementSystem.new()
	_expect(not corrupt.begin(save, 0, 1010).ok and _same(save.load_slot(0).state, base), "corrupt journal never overwrites valid base")
	_expect(save.delete_slot(0).ok and not FileAccess.file_exists(save.settlement_path(0)), "slot deletion removes its offline transaction files")