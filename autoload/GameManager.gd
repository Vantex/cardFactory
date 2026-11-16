extends Node

signal game_state_replaced(game_state: GameState)
signal session_started(slot: int, is_new_game: bool)
signal session_ended
signal save_completed(slot: int, reason: String, metadata: Dictionary)
signal save_preparing(reason: String)
signal save_requested(reason: String)
signal save_status_changed(status: Dictionary)
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
var _offline_job: RefCounted
var _pure_wait := 0.0
var _save_queue: Array[Dictionary] = []
var _inflight_digest := ""
var _save_revision := 0
var _save_status := {"phase": "idle", "message": "尚未保存", "revision": 0}

func get_save_status() -> Dictionary:
	return _save_status.duplicate(true)

func _set_save_status(phase: String, message: String) -> void:
	_save_status = {"phase": phase, "message": message, "revision": _save_revision}
	save_status_changed.emit(get_save_status())

func recover_game(slot: int, source: String) -> Dictionary:
	if _save_in_progress or (_offline_job != null and _offline_job.phase in ["simulating", "ready"]):
		return _failure("session_busy", "请先完成当前保存或离线结算")
	var loaded := _save_system.load_recovery_source(slot, source)
	if not loaded.get("ok", false): return loaded
	var previous := OfflineSettlementJournal.new(_save_system, slot).read()
	if not previous.get("ok", false): return previous
	var boundary := maxf(_save_system.wall_time(), float(previous.get("entry", {}).get("target_time", 0)))
	var saved := _commit_state(slot, loaded.state, "recovery", {"offline_processed_until": boundary})
	if not saved.get("ok", false):
		_set_save_status("failed", String(saved.error.message))
		return saved
	var pure_clear := PureIdleJournal.new(_save_system, slot).clear()
	if not pure_clear.ok: return pure_clear
	_pure_wait = 0.0
	_current_slot = slot
	_session_active = true
	_offline_job = null
	_autosave_elapsed = 0
	replace_game_state(loaded.state)
	_set_save_status("saved", "已从%s恢复并保存；过去的离线时间不再补算" % {"primary": "主档", "backup": "备份", "emergency": "紧急恢复点"}.get(source, source))
	session_started.emit(slot, false)
	return saved


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
	if _save_in_progress: return
	if save_system != null:
		_save_system = save_system
		_pure_wait = 0.0
		_offline_job = null

func get_save_system() -> SaveSystem:
	return _save_system

func start_new_game(slot: int, mode_id: String = "normal", difficulty_id: String = "standard") -> Dictionary:
	if _save_in_progress: return _failure("save_in_progress", "请等待保存完成")
	if _offline_job != null and _offline_job.phase in ["simulating", "ready"]: return _failure("offline_busy", "请先完成当前结算")
	var new_state := GameState.new()
	new_state.content_packs = DataManager.content_pack_system.references()
	if not GameModeSystem.new(new_state).configure_new_game(mode_id, difficulty_id): return _failure("invalid_game_mode", "新游戏模式或难度无效")
	SourceGalaxySystem.new(new_state).initialize(randi(), false)
	new_state.initialize_new_game_home_inventory(true)
	PlanetSystem.new(new_state).initialize_colonized_resource_sites()
	var save_result := _commit_state(slot, new_state, "new_game")
	if not save_result.get("ok", false):
		session_error.emit(save_result.get("error", {}))
		return save_result
	var pure_cleared := PureIdleJournal.new(_save_system, slot).clear()
	if not pure_cleared.ok: return pure_cleared
	var cleared := OfflineSettlementJournal.new(_save_system, slot).clear()
	if not cleared.ok: return cleared
	_current_slot = slot
	_session_active = true
	_autosave_elapsed = 0.0
	_offline_job = null
	_pure_wait = 0.0
	replace_game_state(new_state)
	session_started.emit(slot, true)
	return save_result

func continue_game(slot: int) -> Dictionary:
	if _save_in_progress: return _failure("save_in_progress", "请等待保存完成")
	if _offline_job != null and _offline_job.phase in ["simulating", "ready"]:
		return _failure("offline_busy", "请先完成或放弃当前离线结算")
	var loaded := _save_system.load_slot(slot)
	if not loaded.ok: return loaded
	var candidate: RefCounted = PureIdleSettlementSystem.new() if loaded.state.pure_idle.get("enabled", false) and loaded.state.time_warp.get("enabled", false) else OfflineSettlementSystem.new()
	candidate.save_writer = _save_offline_state
	var result: Dictionary = candidate.begin(_save_system, slot, _save_system.wall_time())
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
	var response: Dictionary = candidate.load_info.duplicate(true)
	response["state"] = candidate.state
	response["pending"] = candidate.phase != "complete"
	return response

func _activate_offline_result() -> void:
	_session_active = true
	_pure_wait = 0.0
	_autosave_elapsed = 0.0
	replace_game_state(_offline_job.state)
	session_started.emit(_current_slot, false)
	if not _offline_job.report.is_empty(): offline_updated.emit(_offline_job.get_snapshot())

func get_offline_snapshot() -> Dictionary:
	return _offline_job.get_snapshot() if _offline_job != null else {}

func discard_offline_settlement() -> Dictionary:
	if _offline_job == null: return _failure("no_offline_session", "没有待结算时间段")
	var result: Dictionary = _offline_job.discard()
	offline_updated.emit(_offline_job.get_snapshot())
	return result

func retry_offline_settlement() -> Dictionary:
	return continue_game(_current_slot)

func advance_offline_settlement() -> void:
	if _offline_job == null or _offline_job.phase in ["complete", "error"]: return
	_offline_job.advance()
	if _offline_job.phase == "ready":
		var result: Dictionary = _offline_job.commit()
		if result.ok:
			_activate_offline_result()
			return
		session_error.emit(result.get("error", {}))
	offline_updated.emit(_offline_job.get_snapshot())
func save_current_game(reason: String = "manual") -> Dictionary:
	if not _session_active or _current_slot < 0:
		return _failure("no_active_session", "当前没有可保存的游戏会话")
	if not game_state.pure_idle.is_empty() and _pure_wait > 0:
		game_state.pure_idle.carry_seconds += _pure_wait
		_pure_wait = 0.0
	save_preparing.emit(reason)
	return _commit_state(_current_slot, game_state, reason)

func _save_offline_state(slot: int, state: GameState, metadata: Dictionary) -> Dictionary:
	return _commit_state(slot, state, "offline", metadata)

func _commit_state(slot: int, state: GameState, reason: String, metadata: Dictionary = {}) -> Dictionary:
	var snapshot := state.copy_state()
	var digest := JSON.stringify([slot, GameStateCodec.to_persistent_dict(snapshot), metadata]).sha256_text()
	if _save_in_progress:
		if _inflight_digest.is_empty(): return _failure("save_in_progress", "存档事务正在提交")
		if (_save_queue.is_empty() and digest != _inflight_digest) or (not _save_queue.is_empty() and _save_queue.back().digest != digest):
			_save_revision += 1
			_save_queue.append({"slot": slot, "state": snapshot, "metadata": metadata.duplicate(true), "digest": digest, "reason": reason, "revision": _save_revision})
		return {"ok": true, "queued": true, "durable": false}
	_save_revision += 1
	_save_queue.append({"slot": slot, "state": snapshot, "metadata": metadata.duplicate(true), "digest": digest, "reason": reason, "revision": _save_revision})
	_save_in_progress = true
	var result: Dictionary = {}
	while not _save_queue.is_empty():
		var request: Dictionary = _save_queue.pop_front()
		_inflight_digest = request.digest
		_set_save_status("saving", "正在保存…")
		save_requested.emit(request.reason)
		var started := performance_monitor.begin()
		result = _save_system.save_slot(request.slot, request.state, request.metadata)
		performance_monitor.finish("save_ms", started)
		if not result.get("ok", false):
			var latest: Dictionary = _save_queue.back() if not _save_queue.is_empty() else request
			var emergency := _save_system.save_emergency(latest.slot, latest.state) if reason not in ["recovery", "new_game"] else {"ok": false}
			result["emergency_saved"] = emergency.get("ok", false)
			_save_queue.clear()
			_autosave_elapsed = 0.0
			_set_save_status("failed", String(result.error.message) + ("；已保留紧急恢复点" if result.emergency_saved else "；请检查磁盘权限或空间"))
			session_error.emit(result.error)
			break
		_autosave_elapsed = 0.0
		save_completed.emit(request.slot, request.reason, result.get("metadata", {}))
	_inflight_digest = ""
	_save_in_progress = false
	if result.get("ok", false): _set_save_status("saved", "已保存")
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
	if _save_in_progress: return
	_offline_job = null
	_pure_wait = 0.0
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

func set_resource_mode(mode: Variant, expected_state: GameState = null) -> Dictionary:
	if not _session_active or _save_in_progress or (_offline_job != null and _offline_job.phase in ["simulating", "ready"]):
		return _failure("session_busy", "请先进入存档并完成当前保存或结算")
	if expected_state != null and expected_state != game_state:
		return _failure("stale_session", "当前存档已变化，请重新确认")
	if not game_state.set_resource_mode(mode):
		return _failure("invalid_resource_mode", "资源模式无效")
	EventBus.simulation_updated.emit()
	return {"ok": true, "mode": game_state.resource_mode}

func configure_pure_idle(enabled: bool, mode: String = "stable") -> Dictionary:
	if not _session_active or _save_in_progress: return _failure("session_busy", "当前无法修改纯挂机")
	if enabled and simulation_engine.get_pending_simulation_time() + SimulationEngine.STEP_EPSILON >= SimulationEngine.FIXED_DELTA: return _failure("simulation_pending", "请等待模拟积压处理完成")
	var before := game_state.pure_idle.duplicate(true)
	var before_wait := _pure_wait
	var result := PureIdleState.configure(game_state, enabled, mode)
	if not result.ok: return result
	if enabled and not before.get("enabled", false):
		game_state.pure_idle.carry_seconds += simulation_engine.get_pending_simulation_time() / TimeWarpSystem.new(game_state).effective_multiplier()
	var saved := save_current_game("pure_idle_config")
	if not saved.ok:
		game_state.pure_idle = before
		_pure_wait = before_wait
		return saved
	_pure_wait = 0.0
	if enabled and not before.get("enabled", false): replace_game_state(game_state)
	return result

func _process(delta: float) -> void:
	if _offline_job != null and _offline_job.phase in ["simulating", "ready"]:
		advance_offline_settlement()
		return
	if not _session_active:
		return
	if game_state.pure_idle.get("enabled", false) and game_state.time_warp.get("enabled", false) and not game_state.paused:
		_pure_wait += maxf(delta, 0)
		if _pure_wait >= PureIdleSimulationJob.BUCKET_SECONDS:
			game_state.pure_idle.carry_seconds += _pure_wait
			_pure_wait = 0.0
			var saved := save_current_game("pure_idle_checkpoint")
			if saved.ok: continue_game(_current_slot)
		return
	if performance_monitor.enabled:
		performance_monitor.record("frame_interval_ms", delta * 1000.0)
		performance_monitor.record("static_memory_bytes", Performance.get_monitor(Performance.MEMORY_STATIC))
		performance_monitor.record("render_draw_calls", Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME))
		performance_monitor.record("simulation_backlog_ms", simulation_engine.get_pending_simulation_time() * 1000.0)
	var started := performance_monitor.begin()
	simulation_engine.update(delta)
	GameModeSystem.new(game_state).update_active_time(delta)
	performance_monitor.finish("simulation_update_ms", started)
	advance_autosave(delta)

func _notification(what: int) -> void:
	if what != NOTIFICATION_WM_CLOSE_REQUEST:
		return
	var result := prepare_to_quit()
	if result.get("ok", false) and not result.get("queued", false):
		get_tree().quit()

func _failure(code: String, message: String) -> Dictionary:
	return {
		"ok": false,
		"error": {"code": code, "source": "game_manager", "message": message},
	}

func create_recovery_snapshot() -> Dictionary:
	if not _session_active or _save_in_progress: return _failure("session_busy", "当前无法创建快照")
	save_preparing.emit("snapshot")
	_save_in_progress = true
	var result := _save_system.create_snapshot(_current_slot, game_state.copy_state())
	_save_in_progress = false
	if not result.get("ok", false): session_error.emit(result.error)
	return result

func get_content_pack_protected_payloads() -> Dictionary:
	var payloads := [GameStateCodec.to_persistent_dict(game_state)]
	# Source loading can remove blocked queue entries; the live session still owns them.
	payloads.append({"research_current_id": game_state.research_current_id, "research_paused_id": game_state.research_paused_id, "research_queue": game_state.research_queue.duplicate()})
	var directory := DirAccess.open(_save_system._save_path)
	if directory != null:
		for file_name in directory.get_files():
			if not file_name.begins_with("save_") or not ".json" in file_name or file_name.ends_with(".tmp"): continue
			var raw: Variant = JSON.parse_string(FileAccess.get_file_as_string(_save_system._save_path.path_join(file_name)))
			if not raw is Dictionary: return {"ok": false, "message": "存在无法读取的存档或恢复记录，先处理该文件", "payloads": payloads}
			payloads.append(raw.get("state", raw.get("entry", {}).get("result", raw)))
	return {"ok": true, "payloads": payloads}

func mutate_content_pack(action: String, id: String = "", manifest: Variant = null) -> Dictionary:
	if _save_in_progress or (_offline_job != null and _offline_job.phase in ["simulating", "ready"]): return _failure("session_busy", "请先完成保存或结算")
	var protected := get_content_pack_protected_payloads()
	var service := DataManager.content_pack_system
	if not protected.ok and (action != "register" or (manifest is Dictionary and service.registry.packs.has(manifest.get("id", "")))): return ContentPackSystem.fail(protected.message)
	var old_registry := service.registry.duplicate(true)
	var old_catalog := ContentPackSystem.snapshot_catalog()
	var result: Dictionary
	match action:
		"register": result = service.register_pack(manifest, true, protected.payloads)
		"enable": result = service.set_enabled(id, true, protected.payloads)
		"disable": result = service.set_enabled(id, false, protected.payloads)
		"remove": result = service.remove_pack(id, protected.payloads)
		_: return _failure("unknown_content_action", "未知内容包操作")
	if not result.ok: return result
	var candidate := game_state.copy_state()
	candidate.content_packs = service.references()
	for building in candidate.buildings.values():
		var previous: Dictionary = old_catalog.buildings.get(building.type, {})
		var current := DataManager.get_building(building.type)
		if previous.get("speed", 1) != current.get("speed", 1): building.speed = float(building.get("speed", previous.get("speed", 1))) * float(current.get("speed", 1)) / maxf(0.01, float(previous.get("speed", 1)))
	var validation := GameStateValidator.validate_persistent_dict(GameStateCodec.to_persistent_dict(candidate))
	var saved: Dictionary = _commit_state(_current_slot, candidate, "content_pack") if _session_active and validation.is_empty() else {"ok": validation.is_empty()}
	if not saved.ok:
		var restored := service.commit(old_registry)
		if not restored.ok: return ContentPackSystem.fail("目录已更新，但存档与注册表回滚失败，请保留当前会话并检查磁盘")
		return ContentPackSystem.fail("内容包操作未应用到存档，原目录已恢复：" + str(validation if not validation.is_empty() else saved.get("error", {})))
	replace_game_state(candidate)
	return result
