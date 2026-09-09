extends Node

var failures := 0
var root_path := "res://.godot/task20-%d-%d/" % [OS.get_process_id(), Time.get_ticks_usec()]

class FaultStorage extends SaveSystem:
	var fail_primary := false
	var writes := 0
	var fail_replace := false
	func _rename_file(from: String, to: String) -> Error:
		if fail_replace and from.ends_with(".json.tmp"): return ERR_CANT_CREATE
		return super._rename_file(from, to)
	func _write_text(path: String, contents: String) -> Error:
		if path.ends_with(".tmp") and not path.ends_with(".emergency.tmp"):
			writes += 1
			if fail_primary: return ERR_CANT_CREATE
		return super._write_text(path, contents)

func _ready() -> void:
	GameManager.set_process(false)
	var storage := FaultStorage.new(root_path)
	GameManager.configure_save_system(storage)
	check(GameManager.start_new_game(0).ok, "initial save")
	if not storage.has_method("get_recovery_sources") or not GameManager.has_method("get_save_status"):
		check(false, "recovery inspection and save status are required")
	else:
		_test_reentrant_save(storage)
		_test_recovery(storage)
		_test_order_and_failures(storage)
		_test_snapshots(storage)
	GameManager.end_session()
	if failures == 0: print("SAVE RECOVERY TESTS PASSED")
	else: printerr("SAVE RECOVERY TESTS FAILED")
	get_tree().quit(0 if failures == 0 else 1)

func _test_reentrant_save(storage: SaveSystem) -> void:
	var calls := []
	var handler := func(_reason: String):
		if not calls.is_empty(): return
		calls.append(GameManager.save_current_game("autosave"))
		GameManager.game_state.elapsed_time = 44.0
		calls.append(GameManager.save_current_game("manual"))
	GameManager.save_requested.connect(handler)
	var before: int = storage.writes
	var result: Dictionary = GameManager.save_current_game("manual")
	GameManager.save_requested.disconnect(handler)
	check(result.ok and calls.size() == 2 and calls[0].get("queued", false), "overlap is queued, never reported durable early")
	check(storage.writes - before == 2, "identical in-flight request coalesces; changed state writes next")
	check(storage.load_slot(0).state.elapsed_time == 44.0, "latest queued revision is durable")
	check(GameManager.get_save_status().phase == "saved", "saved status follows verified write")

func _test_recovery(storage: SaveSystem) -> void:
	GameManager.game_state.elapsed_time = 55.0
	check(GameManager.save_current_game().ok, "second revision creates backup")
	var primary := FileAccess.get_file_as_string(root_path + "save_0.json")
	var sources: Array = storage.get_recovery_sources(0)
	check(sources.size() >= 3, "primary backup and emergency are individually inspectable")
	check(FileAccess.get_file_as_string(root_path + "save_0.json") == primary, "inspection never promotes or rewrites a source")
	storage.fail_primary = true
	GameManager.game_state.elapsed_time = 66.0
	var failed: Dictionary = GameManager.save_current_game()
	check(not failed.ok and GameManager.get_save_status().phase == "failed", "write failure stays visible")
	check(FileAccess.get_file_as_string(root_path + "save_0.json") == primary, "failed save retains primary")
	check(storage.load_recovery_source(0, "emergency").get("ok", false), "failed normal write retains a verified emergency point")
	var current: GameState = GameManager.game_state
	check(not GameManager.recover_game(0, "backup").ok and GameManager.game_state == current, "failed restore keeps authoritative session")
	storage.fail_primary = false
	check(GameManager.recover_game(0, "backup").ok, "explicit backup restore succeeds")
	check(GameManager.game_state.elapsed_time == 44.0, "restore uses selected source, not newer primary")
	check(GameManager.save_current_game().ok, "restored state can save again")
	check(not storage.load_recovery_source(0, "../invalid").ok, "recovery source cannot escape fixed slot paths")

func check(condition: bool, message: String) -> void:
	if not condition:
		failures += 1
		printerr("FAIL: " + message)
	else: print("PASS: " + message)

func _test_order_and_failures(storage: SaveSystem) -> void:
	GameManager.game_state.elapsed_time = 77.0
	var invoked := []
	var handler := func(_reason: String):
		if not invoked.is_empty(): return
		invoked.append(true)
		GameManager.game_state.elapsed_time = 88.0
		GameManager.save_current_game()
		GameManager.game_state.elapsed_time = 77.0
		GameManager.save_current_game()
	GameManager.save_requested.connect(handler)
	check(GameManager.save_current_game().ok, "A B A requests drain")
	GameManager.save_requested.disconnect(handler)
	check(storage.load_slot(0).state.elapsed_time == 77.0, "returning to an in-flight value does not discard the latest request")
	storage.fail_replace = true
	GameManager.game_state.elapsed_time = 99.0
	check(not GameManager.prepare_to_quit().ok and GameManager.is_session_active(), "replace failure blocks quit without ending session")
	check(storage.load_slot(0).state.elapsed_time == 77.0, "replace failure leaves last verified revision recoverable")
	storage.fail_replace = false
	storage.fail_primary = true
	GameManager.game_state.elapsed_time = 100.0
	GameManager.save_current_game()
	check(storage.load_recovery_source(0, "emergency").state.elapsed_time == 100.0, "subsequent emergency write can replace a prior recovery point")
	var count: int = storage.writes
	GameManager.advance_autosave(0.1)
	check(storage.writes == count, "failed autosave does not retry every frame")
	storage.fail_primary = false
	check(GameManager.recover_game(0, "emergency").ok, "emergency source can restore and commit")
	check(GameManager.game_state.elapsed_time == 100.0, "emergency restore preserves latest recoverable progress")
	var raw := FileAccess.get_file_as_string(root_path + "save_0.json")
	var file := FileAccess.open(root_path + "save_0.json", FileAccess.WRITE)
	file.store_string("{broken")
	file.close()
	storage.get_all_saves()
	check(FileAccess.get_file_as_string(root_path + "save_0.json") == "{broken", "listing corrupt primary leaves it untouched")
	file = FileAccess.open(root_path + "save_0.json", FileAccess.WRITE)
	file.store_string(raw)
	file.close()

func _test_snapshots(storage: SaveSystem) -> void:
	var primary := FileAccess.get_file_as_string(root_path + "save_0.json")
	var created: Dictionary = GameManager.create_recovery_snapshot()
	check(created.ok, "manual snapshot creates a separately verified source")
	if not created.ok: return
	check(FileAccess.get_file_as_string(root_path + "save_0.json") == primary, "snapshot creation does not rotate primary")
	var selected := String(created.source)
	check(storage.load_recovery_source(0, selected).state.elapsed_time == 100.0, "manual snapshot preserves exact selected state")
	GameManager.game_state.elapsed_time = 111.0
	check(GameManager.save_current_game().ok and GameManager.recover_game(0, selected).ok, "manual snapshot restores over newer primary")
	check(GameManager.game_state.elapsed_time == 100.0, "manual snapshot restore rolls back only by explicit selection")
	check(not storage.delete_snapshots(0, [selected, "primary"]).ok and storage.load_recovery_source(0, selected).ok, "invalid batch is rejected before deleting any snapshot")
	check(storage.delete_snapshots(0, [selected]).ok, "selected snapshot can be deleted while primary remains")
	var only := storage.create_snapshot(4, GameState.new())
	check(only.ok and not storage.delete_snapshots(4, [only.source]).ok, "last valid snapshot is protected even without primary")
	check(storage.get_slot_info(4).get("valid", false), "snapshot-only slot remains discoverable")
