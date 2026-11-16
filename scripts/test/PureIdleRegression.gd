class_name PureIdleRegression
extends RefCounted

class ClockSave extends SaveSystem:
	var now := 1000.0
	func wall_time() -> float: return now

class PeriodicValidationJob extends PureIdleSimulationJob:
	func begin(source: GameState, wall_seconds: float, selected_mode: String = "stable") -> Dictionary:
		var begun := super.begin(source, wall_seconds, selected_mode)
		# Periodic arithmetic is independent of host speed; the real deadline is tested separately.
		if begun.ok: deadline_at = 9223372036854775807
		return begun

var failures := 0
func check(value: bool, message: String) -> void:
	if not value:
		failures += 1
		printerr("PURE IDLE: " + message)

func run() -> int:
	var state := SourceDysonRegression.new().fresh()
	var controller := state.add_building({"type": "dsp_time_warp_device", "position": Vector2.ZERO, "input_buffer": {}, "output_buffer": {}})
	var warp := TimeWarpSystem.new(state)
	warp.select_controller(controller)
	warp.set_enabled(true)
	check(PureIdleState.configure(state, true, "stable").ok, "valid normal warp enables pure idle")
	var storage := ClockSave.new("res://.godot/task26-pure-transactions/")
	PureIdleJournal.new(storage, 0).clear()
	var previous := storage.load_slot(0)
	if previous.ok: storage.now = maxf(storage.now, float(previous.metadata.saved_at) + 10)
	var saved := storage.save_slot(0, state)
	check(saved.ok, "pure idle checkpoint saved: " + str(saved))
	if not saved.ok: return failures
	storage.now += 2.0
	var interrupted := PureIdleSettlementSystem.new()
	check(interrupted.begin(storage, 0, storage.now).ok, "funded real time creates pending journal")
	var recovered := PureIdleSettlementSystem.new()
	check(recovered.begin(storage, 0, storage.now).ok, "pending journal resumes from exact saved origin")
	for step in range(300):
		recovered.advance(600, 100000)
		if recovered.phase == "ready": break
	check(recovered.phase == "ready", "unpowered warp falls back to exact one-times settlement")
	check(storage.load_slot(0).state.elapsed_time == state.elapsed_time, "uncommitted result leaves disk origin unchanged")
	recovered.save_writer = func(_slot, _state, _meta): return {"ok": false, "error": {"code": "test_disk_failure", "message": "模拟写入失败"}}
	check(not recovered.commit().ok and recovered.entry.phase == "prepared", "write failure preserves verified prepared result")
	var prepared := PureIdleSettlementSystem.new()
	check(prepared.begin(storage, 0, storage.now).ok and prepared.phase == "ready", "prepared journal restores candidate without replaying resources")
	check(prepared.commit().ok, "prepared result durably commits")
	var settled := storage.load_slot(0)
	check(settled.ok and absf(settled.state.elapsed_time - state.elapsed_time - 2.0) < 0.02, "saved elapsed time matches funded interval")
	var digest := OfflineSettlementSystem._state_digest(settled.state)
	check(prepared.commit().ok and OfflineSettlementSystem._state_digest(storage.load_slot(0).state) == digest, "repeated commit cannot duplicate production or time")
	var again := PureIdleSettlementSystem.new()
	check(again.begin(storage, 0, storage.now).ok and again.phase == "complete", "committed receipt removes stale journal without duplicate settlement")
	var invalid := GameStateCodec.to_persistent_dict(settled.state)
	invalid.pure_idle.carry_seconds = -1
	check(not GameStateValidator.validate_persistent_dict(invalid).is_empty(), "negative deferred wall budget rejected")
	state.save_mode = "speedrun"
	check(not PureIdleState.configure(state, true, "stable").ok, "speedrun cannot enable macro settlement")
	PureIdleJournal.new(storage, 0).clear()
	_test_periodic_validation()
	_test_deadline_budget()
	_test_configuration_budget(storage)
	return failures

func _test_periodic_validation() -> void:
	var state := SourceDysonRegression.new().fresh()
	var id := state.add_building({"type": "dsp_time_warp_device", "position": Vector2.ZERO, "input_buffer": {}, "output_buffer": {}})
	TimeWarpSystem.new(state).select_controller(id)
	TimeWarpSystem.new(state).set_enabled(true)
	for mode in ["stable", "extreme"]:
		var job := PeriodicValidationJob.new()
		check(job.begin(state, 650, mode).ok, "long funded " + mode + " interval begins")
		for step in range(500):
			job.advance(1000000, 600)
			if job.phase == "ready": break
		check(job.phase == "ready" and not job.partial and absf(job.settled_wall - 650) < 0.02, mode + " preserves real wall budget across macro buckets")
		check(job.validation_count == (2 if mode == "stable" else 1), mode + " observes the source ten-minute validation boundary")

func _test_deadline_budget() -> void:
	var state := SourceDysonRegression.new().fresh()
	var id := state.add_building({"type": "dsp_time_warp_device", "position": Vector2.ZERO, "input_buffer": {}, "output_buffer": {}})
	TimeWarpSystem.new(state).select_controller(id)
	TimeWarpSystem.new(state).set_enabled(true)
	var source := GameStateCodec.to_persistent_dict(state)
	for mode in ["stable", "extreme"]:
		var job := PureIdleSimulationJob.new()
		check(job.begin(state, 650, mode).ok, mode + " deadline job begins")
		var remaining := job.deadline_at - Time.get_ticks_usec()
		check(PureIdleSimulationJob.DEADLINE_USEC == 30000000 and remaining > 0 and remaining <= PureIdleSimulationJob.DEADLINE_USEC, mode + " retains the production thirty-second calculation ceiling")
		job.advance(1000000, 1)
		var candidate := GameStateCodec.to_persistent_dict(job.candidate)
		var settled := job.settled_wall
		check(job.exact_ticks == 1 and settled > 0 and settled < 650, mode + " deadline fixture has a real paid exact tick")
		job.deadline_at = Time.get_ticks_usec()
		job.advance(1000000, 600)
		check(job.phase == "ready" and job.partial and job.exact_ticks == 1 and job.settled_wall == settled and "30 秒" in job.reason, mode + " exhausted calculation budget preserves partial funded progress")
		check(GameStateCodec.to_persistent_dict(job.candidate) == candidate and GameStateCodec.to_persistent_dict(state) == source, mode + " budget stop neither replays a tick nor mutates the live origin")

func _test_configuration_budget(storage: SaveSystem) -> void:
	var previous_storage := GameManager.get_save_system()
	var previous_state := GameManager.game_state
	GameManager.configure_save_system(storage)
	check(GameManager.start_new_game(1).ok, "manager starts isolated pure-idle configuration slot")
	var state := SourceDysonRegression.new().fresh()
	var id := state.add_building({"type": "dsp_time_warp_device", "position": Vector2.ZERO, "input_buffer": {}, "output_buffer": {}})
	TimeWarpSystem.new(state).select_controller(id)
	TimeWarpSystem.new(state).set_enabled(true)
	GameManager.replace_game_state(state)
	check(GameManager.configure_pure_idle(true).ok, "manager enables and saves pure idle")
	GameManager._pure_wait = 3.5
	check(GameManager.configure_pure_idle(true, "extreme").ok and state.pure_idle.carry_seconds == 3.5 and storage.load_slot(1).state.pure_idle.carry_seconds == 3.5, "configuration change funds waiting time exactly once")
	GameManager.end_session()
	check(GameManager._pure_wait == 0, "session end clears runtime waiting clock")
	GameManager.configure_save_system(previous_storage)
	GameManager.replace_game_state(previous_state)
