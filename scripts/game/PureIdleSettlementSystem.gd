class_name PureIdleSettlementSystem
extends RefCounted

var storage: SaveSystem
var journal: PureIdleJournal
var slot := -1
var phase := "idle"
var entry: Dictionary = {}
var base_state: GameState
var state: GameState
var job: PureIdleSimulationJob
var report: Dictionary = {}
var error: Dictionary = {}
var load_info: Dictionary = {}
var save_writer: Callable

func begin(save_system: SaveSystem, slot_id: int, now: float) -> Dictionary:
	if not is_finite(now) or now < 0: return _fail("invalid_clock", "系统时间无效")
	storage = save_system
	slot = slot_id
	journal = PureIdleJournal.new(storage, slot)
	var loaded := storage.load_slot(slot)
	if not loaded.ok: return _adopt_error(loaded)
	load_info = loaded.duplicate(true)
	base_state = loaded.state
	state = base_state.copy_state()
	var previous := journal.read()
	if not previous.ok: return _adopt_error(previous)
	var existing: Dictionary = previous.entry
	var base_time := float(loaded.metadata.saved_at)
	var digest := OfflineSettlementSystem._state_digest(base_state)
	if not existing.is_empty():
		if base_state.pure_idle.get("last_receipt", "") == existing.receipt:
			var cleared := journal.clear()
			if not cleared.ok: return _adopt_error(cleared)
		elif existing.base_digest == digest and float(existing.base_time) == base_time:
			entry = existing
			if entry.phase == "prepared":
				state = GameStateCodec.from_persistent_dict(entry.result)
				report = entry.report.duplicate(true)
				phase = "ready"
				return {"ok": true, "recovered": true}
			return _start()
		else: return _fail("pure_idle_conflict", "纯挂机起点已改变，未覆盖存档")
	if not base_state.pure_idle.get("enabled", false) or not base_state.time_warp.get("enabled", false): return _fail("pure_idle_disabled", "纯挂机尚未启用")
	var seconds := maxf(now - base_time, 0) + float(base_state.pure_idle.get("carry_seconds", 0)) if base_time > 0 else 0.0
	if seconds < SimulationEngine.FIXED_DELTA:
		phase = "complete"
		return {"ok": true, "skipped": true}
	entry = {"version": 1, "slot": slot, "phase": "pending", "base_digest": digest, "base_time": base_time, "target_time": maxf(now, base_time), "actual_seconds": seconds, "mode": base_state.pure_idle.mode}
	entry["receipt"] = OfflineSettlementJournal._digest(entry)
	var written := journal.write(entry)
	if not written.ok: return _adopt_error(written)
	return _start()

func _start() -> Dictionary:
	job = PureIdleSimulationJob.new()
	base_state.paused = false
	var started := job.begin(base_state, float(entry.actual_seconds), entry.mode)
	if not started.ok: return _fail("pure_idle_not_ready", started.message)
	phase = "simulating"
	return {"ok": true}

func advance(max_ticks: int = 600, budget_usec: int = 8000) -> void:
	if phase != "simulating": return
	job.advance(budget_usec, max_ticks)
	if job.phase != "ready": return
	state = job.candidate
	report = job.summary()
	report["actual_seconds"] = entry.actual_seconds
	report["simulated_seconds"] = job.settled_simulation
	report["remaining_seconds"] = maxf(0, float(entry.actual_seconds) - job.settled_wall)
	report["discarded"] = false
	_finish()

func _finish() -> void:
	state.pure_idle = base_state.pure_idle.duplicate(true)
	state.pure_idle.carry_seconds = float(report.remaining_seconds)
	state.pure_idle.last_receipt = entry.receipt
	state.pure_idle.report = report.duplicate(true)
	phase = "ready"

func discard() -> Dictionary:
	if phase not in ["simulating", "ready"] or entry.phase != "pending": return _fail("pure_idle_not_discardable", "已准备提交的结果不能放弃")
	state = base_state.copy_state()
	report = {"actual_seconds": entry.actual_seconds, "settled_wall_seconds": 0.0, "simulated_seconds": 0.0, "remaining_seconds": 0.0, "discarded": true, "mode": entry.mode}
	_finish()
	return {"ok": true}

func commit() -> Dictionary:
	if phase == "complete": return {"ok": true, "already_applied": true}
	if phase != "ready": return _fail("pure_idle_not_ready", "纯挂机结算尚未完成")
	var loaded := storage.load_slot(slot)
	if not loaded.ok: return _adopt_error(loaded)
	if loaded.state.pure_idle.get("last_receipt", "") == entry.receipt:
		state = loaded.state
		phase = "complete"
		return {"ok": true, "already_applied": true}
	if OfflineSettlementSystem._state_digest(loaded.state) != entry.base_digest or float(loaded.metadata.saved_at) != float(entry.base_time): return _fail("pure_idle_conflict", "槽位已改变，纯挂机结果未覆盖新存档")
	if entry.phase != "prepared":
		entry.phase = "prepared"
		entry["result"] = GameStateCodec.to_persistent_dict(state)
		entry["report"] = report.duplicate(true)
		var written := journal.write(entry)
		if not written.ok: return _adopt_error(written)
	var metadata := {"offline_processed_until": entry.target_time}
	var saved: Dictionary = save_writer.call(slot, state, metadata) if save_writer.is_valid() else storage.save_slot(slot, state, metadata)
	if not saved.ok: return _adopt_error(saved)
	phase = "complete"
	return saved

func get_snapshot() -> Dictionary:
	return {"kind": "pure_idle", "phase": phase, "report": report.duplicate(true) if phase in ["complete", "ready"] else job.summary() if job != null else {}, "error": error.duplicate(true), "can_discard": phase in ["simulating", "ready"] and entry.get("phase") == "pending"}

func _fail(code: String, message: String) -> Dictionary:
	return _adopt_error({"ok": false, "error": {"code": code, "message": message}})

func _adopt_error(result: Dictionary) -> Dictionary:
	phase = "error"
	error = result.get("error", {}).duplicate(true)
	return result
