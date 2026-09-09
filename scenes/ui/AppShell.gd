class_name AppShell
extends CanvasLayer

var _start_menu: StartMenu
var _slots_panel: SaveSlotsPanel
var _workspace_ui: CanvasLayer
var _input_handler: Node
var _screen_name := "start"
var _offline_report: Control
var _settings: Control
var _settings_return := "start"
var _recovery: RecoveryWorkspace
var _pause_menu: PanelContainer
var _pause_message: Label
var _was_paused := false

func _ready() -> void:
	layer = 30
	_start_menu = StartMenu.new()
	_start_menu.name = "StartMenu"
	add_child(_start_menu)
	_slots_panel = SaveSlotsPanel.new()
	_slots_panel.name = "SaveSlotsPanel"
	add_child(_slots_panel)

	_workspace_ui = get_node_or_null("../FactoryWorkspaceUI") as CanvasLayer
	_input_handler = get_node_or_null("../InputHandler")
	_start_menu.new_game_requested.connect(_show_slots)
	_start_menu.continue_requested.connect(_continue_game)
	_start_menu.slots_requested.connect(_show_slots)
	_start_menu.settings_requested.connect(open_settings)
	_settings = preload("res://scenes/ui/SettingsWorkspace.gd").new()
	_settings.name = "SettingsWorkspace"
	add_child(_settings)
	_settings.dismissed.connect(close_settings)
	_slots_panel.new_game_requested.connect(_start_new_game)
	_slots_panel.continue_requested.connect(_continue_game)
	_slots_panel.delete_requested.connect(_delete_slot)
	_slots_panel.back_requested.connect(_show_start)
	_slots_panel.recovery_requested.connect(open_recovery)
	_recovery = RecoveryWorkspace.new()
	_recovery.name = "RecoveryWorkspace"
	add_child(_recovery)
	_recovery.dismissed.connect(func():
		if GameManager.is_session_active():
			_recovery.hide()
			_screen_name = "pause"
			_pause_menu.show()
			_focus_first.call_deferred(_pause_menu)
		else: _show_slots())
	_recovery.restore_requested.connect(func(slot: int, source: String):
		var result := GameManager.recover_game(slot, source)
		if not result.ok: _recovery.show_error(_error_message(result)))
	_create_pause_menu()
	GameManager.save_status_changed.connect(_on_save_status_changed)
	_offline_report = preload("res://scenes/ui/OfflineReportWorkspace.gd").new()
	_offline_report.name = "OfflineReportWorkspace"
	add_child(_offline_report)
	_offline_report.dismissed.connect(func(): _on_session_started(GameManager.get_current_slot(), false))
	_offline_report.return_requested.connect(func(): GameManager.end_session())
	GameManager.offline_updated.connect(_on_offline_updated)
	GameManager.session_started.connect(_on_session_started)
	GameManager.session_ended.connect(_show_start)
	if GameManager.is_session_active():
		_on_session_started(GameManager.get_current_slot(), false)
	else:
		_show_start()

func get_screen_name() -> String:
	return _screen_name

func show_error(message: String) -> void:
	if _screen_name == "slots":
		_slots_panel.show_error(message)
	else:
		_start_menu.show_error(message)

func return_to_menu() -> Dictionary:
	if not GameManager.is_session_active():
		_show_start()
		return {"ok": true, "skipped": true}
	var result := GameManager.save_current_game("return_to_menu")
	if not result.get("ok", false) or result.get("queued", false):
		EventBus.notice_requested.emit(_error_message(result), "error")
		return result
	GameManager.end_session()
	return result

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo and event.ctrl_pressed and event.keycode == KEY_S and _screen_name in ["game", "pause"]:
		GameManager.save_current_game()
		get_viewport().set_input_as_handled()
		return
	if _screen_name in ["pause", "recovery"]:
		if event.is_action_pressed("ui_cancel"):
			if _screen_name == "pause": close_pause_menu()
			else: _recovery.dismissed.emit()
			get_viewport().set_input_as_handled()
		return
	if _screen_name == "settings":
		if event.is_action_pressed("ui_cancel"):
			close_settings()
			get_viewport().set_input_as_handled()
		return
	if _screen_name in ["offline", "offline_report"]:
		return
	if not event.is_action_pressed("ui_cancel"):
		return
	if GameManager.is_session_active():
		if _workspace_ui != null and _workspace_ui.close_active_workspace():
			get_viewport().set_input_as_handled()
			return
		if _input_handler != null and _input_handler.call("get_mode_name") != "idle":
			_input_handler.call("cancel_operation")
		else:
			open_pause_menu()
	elif _screen_name == "slots":
		_show_start()
	get_viewport().set_input_as_handled()

func _show_start() -> void:
	if _recovery != null: _recovery.hide()
	if _pause_menu != null: _pause_menu.hide()
	if _settings != null: _settings.hide()
	if _offline_report != null: _offline_report.hide()
	_screen_name = "start"
	_set_gameplay_visible(false)
	_slots_panel.hide()
	_start_menu.show()
	_start_menu.clear_error()
	_start_menu.refresh_saves(GameManager.get_save_system().get_all_saves())
	_focus_first.call_deferred(_start_menu)

func _show_slots() -> void:
	if _recovery != null: _recovery.hide()
	if _pause_menu != null: _pause_menu.hide()
	_screen_name = "slots"
	_set_gameplay_visible(false)
	_start_menu.hide()
	_slots_panel.show_error("")
	_slots_panel.refresh_slots(GameManager.get_save_system().get_all_saves())
	_slots_panel.show()
	_focus_first.call_deferred(_slots_panel)

func _start_new_game(slot: int) -> void:
	var result := GameManager.start_new_game(slot)
	if not result.get("ok", false):
		_slots_panel.show_error(_error_message(result))

func _continue_game(slot: int) -> void:
	if GameManager.get_save_system().get_slot_info(slot).get("recovery_only", false):
		open_recovery(slot)
		return
	var result := GameManager.continue_game(slot)
	if result.get("ok", false):
		if result.get("recovered_from_backup", false):
			EventBus.notice_requested.emit("主存档损坏，已从最近备份恢复", "warning")
		return
	show_error(_error_message(result))

func _delete_slot(slot: int) -> void:
	var result := GameManager.get_save_system().delete_slot(slot)
	if result.get("ok", false):
		_slots_panel.refresh_slots(GameManager.get_save_system().get_all_saves())
		return
	_slots_panel.show_error(_error_message(result))

func _on_session_started(_slot: int, _is_new_game: bool) -> void:
	if _recovery != null: _recovery.hide()
	if _pause_menu != null: _pause_menu.hide()
	_screen_name = "game"
	_start_menu.hide()
	_slots_panel.hide()
	_set_gameplay_visible(true)
	EventBus.simulation_updated.emit()

func _set_gameplay_visible(is_visible: bool) -> void:
	if _workspace_ui != null:
		_workspace_ui.visible = is_visible
	if _input_handler != null:
		if not is_visible: _input_handler.reset_device_input()
		_input_handler.set_process_input(is_visible)
		_input_handler.set_process_unhandled_input(is_visible)
	for sibling_name in ["CardRenderer", "ConnectionRenderer"]:
		var sibling := get_node_or_null("../" + sibling_name) as CanvasItem
		if sibling != null:
			sibling.visible = is_visible

func _error_message(result: Dictionary) -> String:
	var error: Dictionary = result.get("error", {})
	var code := String(error.get("code", "unknown"))
	match code:
		"save_not_found":
			return "该槽位没有可继续的存档，请选择新游戏。"
		"invalid_json", "invalid_envelope", "digest_mismatch", "decode_failed":
			return "存档已损坏且没有可用备份，请选择其他槽位或删除该档。"
		"unsupported_future_version":
			return "该存档来自更新版本，请升级游戏后再尝试。"
		"storage_unavailable", "write_failed", "backup_failed", "replace_failed":
			return "本地存档目录不可写，请检查磁盘权限和可用空间。"
		"save_in_progress":
			return "存档正在写入，请稍后再试。"
		_:
			return String(error.get("message", "操作失败，请选择其他槽位后重试。"))

func _on_offline_updated(snapshot: Dictionary) -> void:
	_screen_name = "offline_report" if snapshot.get("phase") == "complete" else "offline"
	_start_menu.hide()
	_slots_panel.hide()
	_set_gameplay_visible(false)
	_offline_report.display(snapshot)
	if snapshot.get("phase") in ["complete", "error"]: _focus_first.call_deferred(_offline_report)

func open_settings() -> void:
	if _screen_name in ["offline", "offline_report", "settings"]: return
	_settings_return = _screen_name
	_screen_name = "settings"
	_start_menu.hide()
	_slots_panel.hide()
	_set_gameplay_visible(false)
	if _input_handler != null: _input_handler.cancel_operation()
	_settings.open()

func close_settings() -> void:
	_settings.hide()
	if _settings_return == "game" and GameManager.is_session_active():
		_on_session_started(GameManager.get_current_slot(), false)
		_focus_first.call_deferred(_workspace_ui)
	elif _settings_return == "slots": _show_slots()
	else: _show_start()

func _focus_first(root: Node) -> void:
	if not is_instance_valid(root): return
	for node in root.find_children("*", "BaseButton", true, false):
		if node.is_visible_in_tree() and not node.disabled:
			node.grab_focus()
			return

func open_recovery(slot: int) -> void:
	if _screen_name not in ["start", "slots", "pause"]: return
	_pause_menu.hide()
	_screen_name = "recovery"
	_start_menu.hide()
	_slots_panel.hide()
	_set_gameplay_visible(false)
	_recovery.open(slot)
	_recovery.content.get_child(0).grab_focus.call_deferred()

func _create_pause_menu() -> void:
	_pause_menu = PanelContainer.new()
	_pause_menu.name = "PauseMenu"
	_pause_menu.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(_pause_menu)
	var margin := MarginContainer.new()
	for side in ["left", "right", "top", "bottom"]: margin.add_theme_constant_override("margin_" + side, 24)
	_pause_menu.add_child(margin)
	var scroll := ScrollContainer.new()
	scroll.follow_focus = true
	margin.add_child(scroll)
	var content := VBoxContainer.new()
	content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(content)
	_pause_message = Label.new()
	_pause_message.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	content.add_child(_pause_message)
	for action in [["ResumeButton", "继续游戏", close_pause_menu], ["SaveButton", "立即保存 · Ctrl+S", func(): GameManager.save_current_game()], ["SnapshotButton", "创建恢复快照", func():
		var result := GameManager.create_recovery_snapshot()
		_pause_message.text = "恢复快照已创建" if result.ok else _error_message(result)], ["RecoveryButton", "管理恢复快照", func(): open_recovery(GameManager.get_current_slot())], ["ReturnButton", "保存并返回主菜单", return_to_menu]]:
		var button := Button.new()
		button.name = action[0]
		button.text = action[1]
		button.pressed.connect(action[2])
		content.add_child(button)
	_pause_menu.hide()

func open_pause_menu() -> void:
	if not GameManager.is_session_active() or _screen_name != "game": return
	_was_paused = GameManager.game_state.paused
	GameManager.game_state.paused = true
	_screen_name = "pause"
	_set_gameplay_visible(false)
	_pause_message.text = GameManager.get_save_status().message
	_pause_menu.show()
	_focus_first.call_deferred(_pause_menu)

func close_pause_menu() -> void:
	GameManager.game_state.paused = _was_paused
	_on_session_started(GameManager.get_current_slot(), false)

func _on_save_status_changed(status: Dictionary) -> void:
	_pause_message.text = status.message
