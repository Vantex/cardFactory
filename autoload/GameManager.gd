extends Node

signal game_state_replaced(game_state: GameState)
signal session_started(slot: int, is_new_game: bool)
signal session_ended
signal save_completed(slot: int, reason: String, metadata: Dictionary)
signal session_error(error: Dictionary)

const DEFAULT_AUTOSAVE_INTERVAL := 120.0

var game_state: GameState
var simulation_engine: SimulationEngine
var _save_system: SaveSystem
var _current_slot := -1
var _session_active := false
var _save_in_progress := false
var _autosave_interval := DEFAULT_AUTOSAVE_INTERVAL
var _autosave_elapsed := 0.0

func _ready() -> void:
	get_tree().auto_accept_quit = false
	_save_system = SaveSystem.new()
	replace_game_state(GameState.new())
	print("GameManager initialized")

func replace_game_state(new_state: GameState) -> void:
	if new_state == null:
		return
	game_state = new_state
	simulation_engine = SimulationEngine.new(game_state)
	game_state_replaced.emit(game_state)

func get_game_state() -> GameState:
	return game_state

func get_simulation_engine() -> SimulationEngine:
	return simulation_engine

func configure_save_system(save_system: SaveSystem) -> void:
	if save_system != null:
		_save_system = save_system

func get_save_system() -> SaveSystem:
	return _save_system

func start_new_game(slot: int) -> Dictionary:
	var new_state := GameState.new()
	var save_result := _save_system.save_slot(slot, new_state)
	if not save_result.get("ok", false):
		session_error.emit(save_result.get("error", {}))
		return save_result
	_current_slot = slot
	_session_active = true
	_autosave_elapsed = 0.0
	replace_game_state(new_state)
	session_started.emit(slot, true)
	return save_result

func continue_game(slot: int) -> Dictionary:
	var load_result := _save_system.load_slot(slot)
	if not load_result.get("ok", false):
		session_error.emit(load_result.get("error", {}))
		return load_result
	var loaded_state: GameState = load_result.get("state")
	if loaded_state == null:
		var decode_failure := _failure("decode_failed", "存档未能创建完整游戏状态")
		session_error.emit(decode_failure["error"])
		return decode_failure
	_current_slot = slot
	_session_active = true
	_autosave_elapsed = 0.0
	replace_game_state(loaded_state)
	session_started.emit(slot, false)
	return load_result

func save_current_game(reason: String = "manual") -> Dictionary:
	if not _session_active or _current_slot < 0:
		return _failure("no_active_session", "当前没有可保存的游戏会话")
	if _save_in_progress:
		return _failure("save_in_progress", "已有存档写入正在进行")
	_save_in_progress = true
	var result := _save_system.save_slot(_current_slot, game_state)
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
	if not _session_active:
		return
	simulation_engine.update(delta)
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
