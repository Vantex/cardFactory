extends Node

signal game_state_replaced(game_state: GameState)
signal session_started(slot: int, is_new_game: bool)
signal session_ended
signal save_completed(slot: int, reason: String, metadata: Dictionary)
signal save_requested(reason: String)
signal session_error(error: Dictionary)
signal offline_updated(snapshot: Dictionary)

const DEFAULT_AUTOSAVE_INTERVAL := 120.0

var game_state: GameState
var simulation_engine: SimulationEngine
var performance_monitor := PerformanceSystem.new()
var _save_system: SaveSystem
var _current_slot := -1
var _session_active := false
var _save_in_progress := false
var _autosave_interval := DEFAULT_AUTOSAVE_INTERVAL
var _autosave_elapsed := 0.0
var _offline_job: OfflineSettlementSystem

func _ready() -> void:
	get_tree().auto_accept_quit = false
	_save_system = SaveSystem.new()
	replace_game_state(GameState.new())
	print("GameManager initialized")

func replace_game_state(new_state: GameState) -> void:
	if new_state == null:
		return
	PlanetSystem.new(new_state).initialize_colonized_resource_sites()
	game_state = new_state
	simulation_engine = SimulationEngine.new(game_state)
	performance_monitor.game_state = game_state
	simulation_engine.performance_monitor = performance_monitor
	game_state_replaced.emit(game_state)

func get_game_state() -> GameState:
	return game_state

func get_simulation_engine() -> SimulationEngine:
	return simulation_engine

func configure_save_system(save_system: SaveSystem) -> void:
	if save_system != null:
		_save_system = save_system
		_offline_job = null

func get_save_system() -> SaveSystem:
	return _save_system

func start_new_game(slot: int) -> Dictionary:
	var new_state := GameState.new()
	new_state.initialize_new_game_home_inventory()
	PlanetSystem.new(new_state).initialize_colonized_resource_sites()
	var save_result := _save_system.save_slot(slot, new_state)
	if not save_result.get("ok", false):
		session_error.emit(save_result.get("error", {}))
		return save_result
	var cleared := OfflineSettlementJournal.new(_save_system, slot).clear()
	if not cleared.ok: return cleared
	_current_slot = slot
	_session_active = true
	_autosave_elapsed = 0.0
	_offline_job = null
	replace_game_state(new_state)
	session_started.emit(slot, true)
	return save_result

func continue_game(slot: int) -> Dictionary:
	if _offline_job != null and _offline_job.phase in ["simulating", "ready"]:
		return _failure("offline_busy", "请先完成或放弃当前离线结算")
	var candidate := OfflineSettlementSystem.new()
	var result := candidate.begin(_save_system, slot, _save_system.wall_time())
	if not result.ok:
		session_error.emit(result.get("error", {}))
		return result
	_offline_job = candidate
	_current_slot = slot
	if candidate.phase == "complete":
		_activate_offline_result()
	else:
		_session_active = false
		offline_updated.emit(candidate.get_snapshot())
	var response := candidate.load_info.duplicate(true)
	response["state"] = candidate.state
	response["pending"] = candidate.phase != "complete"
	return response

func _activate_offline_result() -> void:
	_session_active = true
	_autosave_elapsed = 0.0
	replace_game_state(_offline_job.state)
	session_started.emit(_current_slot, false)
	if not _offline_job.report.is_empty(): offline_updated.emit(_offline_job.get_snapshot())

func get_offline_snapshot() -> Dictionary:
	return _offline_job.get_snapshot() if _offline_job != null else {}

func discard_offline_settlement() -> Dictionary:
	if _offline_job == null: return _failure("no_offline_session", "没有待结算时间段")
	var result := _offline_job.discard()
	offline_updated.emit(_offline_job.get_snapshot())
	return result

func retry_offline_settlement() -> Dictionary:
	return continue_game(_current_slot)

func advance_offline_settlement() -> void:
	if _offline_job == null or _offline_job.phase in ["complete", "error"]: return
	_offline_job.advance()
	if _offline_job.phase == "ready":
		var result := _offline_job.commit()
		if result.ok:
			_activate_offline_result()
			return
		session_error.emit(result.get("error", {}))
	offline_updated.emit(_offline_job.get_snapshot())
func save_current_game(reason: String = "manual") -> Dictionary:
	if not _session_active or _current_slot < 0:
		return _failure("no_active_session", "当前没有可保存的游戏会话")
	if _save_in_progress:
		return _failure("save_in_progress", "已有存档写入正在进行")
	_save_in_progress = true
	save_requested.emit(reason)
	var started := performance_monitor.begin()
	var result := _save_system.save_slot(_current_slot, game_state)
	performance_monitor.finish("save_ms", started)
	_save_in_progress = false
	if result.get("ok", false):
		_autosave_elapsed = 0.0
		save_completed.emit(_current_slot, reason, result.get("metadata", {}))
	else:
		session_error.emit(result.get("error", {}))
	return result

func advance_autosave(delta: float) -> Dictionary:
	if not _session_active:
		return {"ok": true, "skipped": true, "reason": "no_active_session"}
	_autosave_elapsed += maxf(delta, 0.0)
	if _autosave_elapsed < _autosave_interval:
		return {"ok": true, "skipped": true, "reason": "not_due"}
	return save_current_game("autosave")

func prepare_to_quit() -> Dictionary:
	if not _session_active:
		return {"ok": true, "skipped": true, "reason": "no_active_session"}
	return save_current_game("exit")

func end_session() -> void:
	_offline_job = null
	_current_slot = -1
	_session_active = false
	_autosave_elapsed = 0.0
	session_ended.emit()

func is_session_active() -> bool:
	return _session_active

func get_current_slot() -> int:
	return _current_slot

func is_save_in_progress() -> bool:
	return _save_in_progress

func get_autosave_interval() -> float:
	return _autosave_interval

func set_autosave_interval(seconds: float) -> void:
	_autosave_interval = maxf(seconds, 1.0)
	_autosave_elapsed = minf(_autosave_elapsed, _autosave_interval)

func get_active_planet() -> String:
	return game_state.active_planet_id

func _process(delta: float) -> void:
	if _offline_job != null and _offline_job.phase in ["simulating", "ready"]:
		advance_offline_settlement()
		return
	if not _session_active:
		return
	if performance_monitor.enabled:
		performance_monitor.record("frame_interval_ms", delta * 1000.0)
		performance_monitor.record("static_memory_bytes", Performance.get_monitor(Performance.MEMORY_STATIC))
		performance_monitor.record("render_draw_calls", Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME))
		performance_monitor.record("simulation_backlog_ms", simulation_engine.get_pending_simulation_time() * 1000.0)
	var started := performance_monitor.begin()
	simulation_engine.update(delta)
	performance_monitor.finish("simulation_update_ms", started)
	advance_autosave(delta)

func _notification(what: int) -> void:
	if what != NOTIFICATION_WM_CLOSE_REQUEST:
		return
	var result := prepare_to_quit()
	if result.get("ok", false):
		get_tree().quit()

func _failure(code: String, message: String) -> Dictionary:
	return {
		"ok": false,
		"error": {"code": code, "source": "game_manager", "message": message},
	}
