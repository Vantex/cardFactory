extends Node

const OWNER := preload("res://scripts/test/EffectQueryBehaviorRunner.gd")
const EXACT := preload("res://scripts/test/CapacityQueryBehaviorRunner.gd")
var errors := []

func _check(ok: bool, message: String) -> void:
	if not ok: errors.append(message)

func _ready() -> void:
	call_deferred("_run")

func _run() -> void:
	GameManager.set_process(false)
	GameManager.configure_save_system(SaveSystem.new("res://.godot/task27-mode-ui-%d/" % OS.get_process_id()))
	var viewport := SubViewport.new()
	viewport.size = Vector2i(1920, 1080)
	get_tree().root.add_child(viewport)
	var main: Node = load("res://scenes/main/Main.tscn").instantiate()
	viewport.add_child(main)
	await get_tree().process_frame
	main.set_process(false)
	var shell: AppShell = main.get_node("AppShell")
	var start_settings: Button = shell._start_menu.find_child("SettingsButton", true, false)
	_check(start_settings != null, "actual start menu settings button")
	if start_settings != null: start_settings.pressed.emit()
	var panel = shell._settings
	_check(not panel.resource_group.visible, "start menu has no saved-game mode controls")
	var initial := OWNER._ownership(GameManager.get_game_state())
	_check(not GameManager.set_resource_mode("infinite").ok, "manager rejects inactive session")
	_check(OWNER._ownership(GameManager.get_game_state()) == initial, "inactive request preserves owner")
	shell.close_settings()
	_check(GameManager.start_new_game(0).ok, "actual new session and primary save")
	await get_tree().process_frame
	var game_settings: Button = main.get_node("FactoryWorkspaceUI").find_child("SettingsButton", true, false)
	_check(game_settings != null, "actual gameplay settings button")
	if game_settings != null: game_settings.pressed.emit()
	_check(panel.resource_group.visible, "formal Main settings exposes active saved-game controls")
	var state: GameState = GameManager.get_game_state()
	var owner := OWNER._ownership(state)
	panel.resource_buttons.finite.pressed.emit()
	_check(not panel.resource_dialog.visible and OWNER._ownership(state) == owner, "same mode has no confirmation or mutation")
	panel.resource_buttons.infinite.pressed.emit()
	_check(panel.resource_dialog.visible and state.resource_mode == "finite", "mode button waits for confirmation")
	panel.resource_dialog.canceled.emit()
	_check(OWNER._ownership(state) == owner, "cancel preserves every raw and canonical field")
	panel.resource_buttons.infinite.pressed.emit()
	shell.close_settings()
	_check(not panel.resource_dialog.visible and panel._pending_resource_mode.is_empty() and OWNER._ownership(state) == owner, "closing settings cancels pending dialog")
	if game_settings != null: game_settings.pressed.emit()
	panel.resource_buttons.infinite.pressed.emit()
	panel.resource_dialog.confirmed.emit()
	var map: GalaxyMap = main.get_node("FactoryWorkspaceUI/GalaxyMap")
	var iron: Dictionary = state.resource_sites.home_iron_ore_1
	_check(map.game_state == state, "actual Main galaxy map owns active state")
	_check(map._resource_site_text([iron]).contains("无限"), "actual Main galaxy resource label reflects confirmed infinite mode")
	var changed := OWNER._ownership(state)
	owner.raw.fields.resource_mode = "infinite"
	owner.canonical.erase("resource_mode")
	changed.canonical.erase("resource_mode")
	_check(state.resource_mode == "infinite" and EXACT._exact(owner, changed), "confirmed mode changes only persistent mode")
	_check(GameManager.save_current_game("mode-ui").ok, "actual current session save after mode change")
	var loaded := GameManager.get_save_system().load_recovery_source(0, "primary")
	_check(loaded.ok and loaded.state.resource_mode == "infinite", "primary reopening retains formal UI mode")
	var before := OWNER._ownership(state)
	GameManager._save_in_progress = true
	panel.resource_buttons.finite.pressed.emit()
	panel.resource_dialog.confirmed.emit()
	GameManager._save_in_progress = false
	_check(OWNER._ownership(state) == before and panel.status.text.contains("保存"), "busy confirmation is rejected without mutation")
	panel.resource_buttons.finite.pressed.emit()
	var replacement := state.copy_state()
	GameManager.replace_game_state(replacement)
	var replacement_before := OWNER._ownership(replacement)
	panel.resource_dialog.confirmed.emit()
	_check(OWNER._ownership(replacement) == replacement_before and panel.status.text.contains("变化"), "stale dialog cannot alter replacement state")
	panel.resource_buttons.finite.pressed.emit()
	panel.resource_dialog.confirmed.emit()
	_check(replacement.resource_mode == "finite", "fresh finite confirmation succeeds")
	_check(map.game_state == replacement and map._resource_site_text([replacement.resource_sites.home_iron_ore_1]).contains("剩余"), "actual Main galaxy resource label returns to finite reserve")
	_check(GameManager.save_current_game("mode-ui-finite").ok, "actual finite switch save")
	loaded = GameManager.get_save_system().load_recovery_source(0, "primary")
	_check(loaded.ok and loaded.state.resource_mode == "finite", "finite primary reopening")
	viewport.queue_free()
	await get_tree().process_frame
	print("PARITY RESOURCE MODE UI TESTS: formal Main start/game buttons, same/cancel/close/confirm/busy/stale/session guards,3primary save operations; root: res://.godot/task27-mode-ui-%d/; errors=" % OS.get_process_id(), errors)
	if errors.is_empty(): print("PARITY RESOURCE MODE UI TESTS PASSED")
	get_tree().quit(0 if errors.is_empty() else 1)
