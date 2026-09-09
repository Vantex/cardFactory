class_name OfflineSettlementSystem
extends RefCounted

const MAX_SECONDS := 120.0
const MIN_SECONDS := 1.0
var storage: SaveSystem
var journal: OfflineSettlementJournal
var slot := -1
var phase := "idle"
var entry: Dictionary = {}
var base_state: GameState
var state: GameState
var engine: SimulationEngine
var ticks_done := 0
var report: Dictionary = {}
var error: Dictionary = {}
var load_info: Dictionary = {}
var save_writer: Callable

func begin(save_system: SaveSystem, slot_id: int, now: float) -> Dictionary:
	if not is_finite(now) or now < 0: return _fail("invalid_clock", "系统时间无效")
	storage = save_system
	slot = slot_id
	journal = OfflineSettlementJournal.new(storage, slot)
	var loaded := storage.load_slot(slot)
	if not loaded.ok: return _adopt_error(loaded)
	load_info = loaded.duplicate(true)
	base_state = loaded.state
	state = base_state.copy_state()
	var previous := journal.read()
	if not previous.ok: return _adopt_error(previous)
	var existing: Dictionary = previous.entry
	var base_time := float(loaded.metadata.saved_at)
	var digest := _state_digest(base_state)
	if not existing.is_empty():
		if loaded.metadata.get("offline_receipt", "") == existing.receipt:
			if now >= base_time and now - base_time < MIN_SECONDS:
				phase = "complete"
				report = existing.get("report", {}).duplicate(true)
				return {"ok": true, "already_applied": true}
		elif existing.base_digest == digest and float(existing.base_time) == base_time:
			entry = existing
			if entry.phase == "prepared":
				state = GameStateCodec.from_persistent_dict(entry.result)
				report = entry.report.duplicate(true)
				ticks_done = int(float(report.get("simulated_seconds", 0)) * 60)
				phase = "ready"
				return {"ok": true, "recovered": true}
			_start_replay()
			return {"ok": true, "recovered": true}
		elif base_time < float(existing.target_time):
			return _fail("offline_conflict", "槽位与离线起点不一致，未覆盖现有存档")
	var elapsed := maxf(now - base_time, 0) if base_time > 0 else 0.0
	if elapsed < MIN_SECONDS and now >= base_time and base_time > 0:
		phase = "complete"
		return {"ok": true, "skipped": true}
	entry = {"version": 1, "slot": slot, "phase": "pending", "base_digest": digest, "base_time": base_time, "target_time": maxf(now, base_time), "actual_seconds": elapsed, "ticks": int(floorf(minf(elapsed, MAX_SECONDS) * 60)), "clock_rollback": now < base_time}
	entry["receipt"] = OfflineSettlementJournal._digest(entry)
	var written := journal.write(entry)
	if not written.ok: return _adopt_error(written)
	_start_replay()
	return {"ok": true}

func _start_replay() -> void:
	state = base_state.copy_state()
	state.paused = false
	state.speed = 1.0
	engine = SimulationEngine.new(state)
	ticks_done = 0
	phase = "simulating" if int(entry.ticks) > 0 else "ready"
	if phase == "ready": _build_report(false)

func advance(max_ticks: int = 60, budget_usec: int = 8000) -> void:
	if phase != "simulating": return
	var started := Time.get_ticks_usec()
	var steps := 0
	var blocked := EventBus.is_blocking_signals()
	EventBus.set_block_signals(true)
	while ticks_done < int(entry.ticks) and steps < clampi(max_ticks, 1, 600):
		engine.update(SimulationEngine.FIXED_DELTA)
		ticks_done += 1
		steps += 1
		if Time.get_ticks_usec() - started >= maxi(budget_usec, 1): break
	EventBus.set_block_signals(blocked)
	if ticks_done == int(entry.ticks):
		phase = "ready"
		_build_report(false)

func discard() -> Dictionary:
	if phase not in ["simulating", "ready"] or entry.phase != "pending": return _fail("offline_not_discardable", "结果已进入提交阶段，不能放弃")
	state = base_state.copy_state()
	ticks_done = 0
	engine = SimulationEngine.new(state)
	_build_report(true)
	phase = "ready"
	return {"ok": true}

func commit() -> Dictionary:
	if phase == "complete": return {"ok": true, "already_applied": true}
	if phase != "ready": return _fail("offline_not_ready", "离线结算尚未完成")
	var loaded := storage.load_slot(slot)
	if not loaded.ok: return _adopt_error(loaded)
	if loaded.metadata.get("offline_receipt", "") == entry.receipt:
		state = loaded.state
		phase = "complete"
		return {"ok": true, "already_applied": true}
	if _state_digest(loaded.state) != entry.base_digest or float(loaded.metadata.saved_at) != float(entry.base_time):
		return _fail("offline_conflict", "槽位已被修改，离线结果未覆盖新存档")
	if entry.phase != "prepared":
		entry.phase = "prepared"
		entry["result"] = GameStateCodec.to_persistent_dict(state)
		entry["report"] = report.duplicate(true)
		var written := journal.write(entry)
		if not written.ok: return _adopt_error(written)
	var metadata := {"offline_receipt": entry.receipt, "offline_processed_until": entry.target_time}
	var saved: Dictionary = save_writer.call(slot, state, metadata) if save_writer.is_valid() else storage.save_slot(slot, state, metadata)
	if not saved.ok: return _adopt_error(saved)
	phase = "complete"
	return saved

func get_snapshot() -> Dictionary:
	return {"phase": phase, "ticks_done": ticks_done, "ticks_total": int(entry.get("ticks", 0)), "report": report.duplicate(true), "error": error.duplicate(true), "can_discard": phase in ["simulating", "ready"] and entry.get("phase") == "pending"}

func _build_report(discarded: bool) -> void:
	var produced: Dictionary = engine.statistics_system.get_recent_amounts().produced
	var technologies: Array = []
	for id in state.completed_technologies:
		if not base_state.completed_technologies.has(id): technologies.append(id)
	var objectives: Array = []
	for id in state.completed_objective_ids:
		if not base_state.completed_objective_ids.has(id): objectives.append(id)
	var blocked := {}
	for building in state.buildings.values():
		var status := String(building.get("status", "idle"))
		if status in ["blocked", "no_power", "no_fuel", "error"]:
			blocked[status] = int(blocked.get(status, 0)) + 1
	report = {"actual_seconds": entry.actual_seconds, "simulated_seconds": ticks_done / 60.0, "skipped_seconds": maxf(0, float(entry.actual_seconds) - ticks_done / 60.0), "cap_seconds": MAX_SECONDS, "discarded": discarded, "clock_rollback": entry.clock_rollback, "unknown_start_time": float(entry.base_time) == 0, "produced": produced, "technologies": technologies, "objectives": objectives, "blocked": blocked, "endgame_phase": state.endgame.phase}

static func _state_digest(game_state: GameState) -> String:
	return JSON.stringify(GameStateCodec.state_digest_payload(game_state)).sha256_text()

func _fail(code: String, message: String) -> Dictionary:
	return _adopt_error({"ok": false, "error": {"code": code, "message": message}})

func _adopt_error(result: Dictionary) -> Dictionary:
	phase = "error"
	error = result.get("error", {}).duplicate(true)
	return result
