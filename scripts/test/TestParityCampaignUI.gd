extends Node

func _ready() -> void:
	await get_tree().process_frame
	GameManager.set_process(false)
	var root := "res://.godot/task27-campaign-session-%d" % Time.get_ticks_usec()
	DirAccess.make_dir_recursive_absolute(root)
	GameManager.configure_save_system(SaveSystem.new(root + "/slots"))
	var started := GameManager.start_new_game(4)
	var original_state := GameManager.game_state
	var original_engine := GameManager.simulation_engine
	var original_monitor := GameManager.performance_monitor
	var original_save := GameManager.get_save_system()
	GameManager._autosave_elapsed = 17.5
	GameManager._pure_wait = 0.125
	original_monitor.start({"scope": "campaign session isolation"})
	original_monitor.record("isolation_ms", 7.0)
	var original_report := original_monitor.get_report()
	var original_revision := GameManager._save_revision
	var original_status := GameManager.get_save_status()
	var original_payload := GameStateCodec.to_persistent_dict(original_state)
	var original_offline := OfflineSettlementSystem.new()
	GameManager._offline_job = original_offline
	var result: Dictionary = await preload("res://scripts/test/CampaignUIBehaviorRunner.gd").new().run()
	if not started.ok: result.errors.append("isolation precondition: actual original session starts")
	if GameManager.game_state != original_state: result.errors.append("isolation: original game state identity restored")
	if GameManager.simulation_engine != original_engine or GameManager.simulation_engine.game_state != original_state: result.errors.append("isolation: original engine identity and owned state restored")
	if GameManager.performance_monitor != original_monitor or original_monitor.game_state != original_state or original_monitor.get_report() != original_report: result.errors.append("isolation: original performance monitor and samples preserved")
	if GameManager.get_save_system() != original_save: result.errors.append("isolation: original save root restored")
	if not GameManager.is_session_active() or GameManager.get_current_slot() != 4: result.errors.append("isolation: original active session and slot restored")
	if GameManager._autosave_elapsed != 17.5 or GameManager._pure_wait != 0.125: result.errors.append("isolation: original session timers restored")
	if GameManager._save_revision != original_revision or GameManager.get_save_status() != original_status: result.errors.append("isolation: original save revision and status restored")
	if GameManager._offline_job != original_offline: result.errors.append("isolation: original offline service identity restored")
	if GameStateCodec.to_persistent_dict(original_state) != original_payload: result.errors.append("isolation: original persisted state preserved")
	if not GameManager.save_current_game("campaign isolation resume").ok: result.errors.append("isolation: original session can actually save after runner")
	for error in result.errors: printerr("FAIL: " + error)
	if result.errors.is_empty(): print("PARITY CAMPAIGN UI TESTS PASSED")
	else: printerr("PARITY CAMPAIGN UI TESTS FAILED")
	get_tree().quit(0 if result.errors.is_empty() else 1)
