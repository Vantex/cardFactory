extends PanelContainer

const OUTPUT := preload("res://scripts/game/SourceResourceOutputSystem.gd")
const RESERVE := preload("res://scripts/game/SourceResourceReserveSystem.gd")

var target: OptionButton
var details: Label
var mine_button: Button
var collect_button: Button
var install_count: SpinBox
var install_button: Button
var status: Label
var site_ids: Array[String] = []
var _state: GameState
var _planet := ""
var _hold_state: GameState
var _hold_site := ""
var _hold_timer: Timer
var _refresh_elapsed := 0.0

func _ready() -> void:
	position = Vector2(240, 90)
	size = Vector2(540, 410)
	z_index = 7
	var content := VBoxContainer.new()
	add_child(content)
	var title := Label.new()
	title.text = "矿脉采集与输出"
	content.add_child(title)
	target = OptionButton.new()
	target.name = "ResourceTarget"
	target.item_selected.connect(func(_index): _stop_mining(); refresh_now())
	content.add_child(target)
	details = Label.new()
	details.name = "ResourceDetails"
	details.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	content.add_child(details)
	mine_button = Button.new()
	mine_button.name = "ManualMine"
	mine_button.text = "按住采集（每次一份）"
	mine_button.button_down.connect(_begin_mining)
	mine_button.button_up.connect(_stop_mining)
	content.add_child(mine_button)
	collect_button = Button.new()
	collect_button.name = "CollectResourceOutput"
	collect_button.text = "收取输出到当前行星托盘"
	collect_button.pressed.connect(_collect)
	content.add_child(collect_button)
	var installation := HBoxContainer.new()
	content.add_child(installation)
	install_count = SpinBox.new()
	install_count.name = "InstallMinerCount"
	install_count.min_value = 1
	install_count.max_value = 100000000
	install_count.value = 1
	install_count.step = 1
	installation.add_child(install_count)
	install_button = Button.new()
	install_button.name = "InstallMiner"
	install_button.text = "安装采集设备"
	install_button.pressed.connect(_install)
	installation.add_child(install_button)
	status = Label.new()
	status.name = "ResourceStatus"
	status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	content.add_child(status)
	var close := Button.new()
	close.name = "CloseResources"
	close.text = "返回工厂"
	close.pressed.connect(hide)
	content.add_child(close)
	_hold_timer = Timer.new()
	_hold_timer.wait_time = 0.32
	_hold_timer.timeout.connect(_mine_once)
	add_child(_hold_timer)
	visibility_changed.connect(func():
		_stop_mining()
		if visible: refresh_now())
	GameManager.game_state_replaced.connect(func(_next): _stop_mining(); refresh_now())
	GameManager.session_ended.connect(_stop_mining)
	hide()
	refresh_now()

func _process(delta: float) -> void:
	if not visible: return
	_refresh_elapsed += delta
	if _refresh_elapsed >= 0.2:
		_refresh_elapsed = 0.0
		refresh_now()
	if not _hold_site.is_empty() and not _can_act(): _stop_mining()

func _input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and not event.pressed: _stop_mining()
	if event is InputEventKey and event.keycode == KEY_ESCAPE: _stop_mining()

func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_WINDOW_FOCUS_OUT: _stop_mining()

func refresh_now() -> void:
	if target == null: return
	var state := GameManager.get_game_state()
	if state != _state or state.active_planet_id != _planet:
		_stop_mining()
		_state = state
		_planet = state.active_planet_id
		var previous := selected_site_id()
		site_ids.clear()
		target.clear()
		var ids := state.resource_sites.keys()
		ids.sort()
		for id in ids:
			var site: Dictionary = state.resource_sites[id]
			if site.get("planet_id") != _planet: continue
			site_ids.append(id)
			target.add_item(String(DataManager.get_item(site.item_id).get("name", site.item_id)))
		if site_ids.has(previous): target.select(site_ids.find(previous))
	var site: Dictionary = state.resource_sites.get(selected_site_id(), {})
	var active := _can_act() and not site.is_empty()
	mine_button.disabled = not active or DataManager.get_item(String(site.get("item_id", ""))).get("kind") != "solid"
	collect_button.disabled = not active or OUTPUT.raw_amount(state, site) < 1
	var type := OUTPUT.extractor_type(String(site.get("item_id", "")))
	install_button.disabled = not active or state.source_galaxy.is_empty() or site.get("interaction_locked", false)
	install_button.tooltip_text = "已有施工件 %.0f；安装数量 %.0f" % [float(state.construction_inventory.get(type, 0)), install_count.value]
	if site.is_empty():
		details.text = "当前行星没有可操作的资源点"
		return
	var reserve: Dictionary = RESERVE.snapshot(state, site)
	var stock := float(state.planet_inventory.get(site.item_id, 0))
	details.text = "%s\n%s\n输出 %.3f / 手采上限 %.0f · 自动设备 %.0f\n当前托盘 %.3f / %.0f\n%s" % [
		DataManager.get_item(site.item_id).get("name", site.item_id),
		"无限储量" if reserve.infinite else "储量 %.0f / %.0f" % [reserve.remaining, reserve.capacity],
		OUTPUT.raw_amount(state, site), OUTPUT.manual_capacity(state, site), OUTPUT.miner_count(state, site),
		stock, PlanetTraySystem.new(state).limit(),
		"流体需要自动采集设备" if DataManager.get_item(site.item_id).get("kind") == "fluid" else "手采和自动采矿共用输出；托盘空间不足时部分收取"]

func selected_site_id() -> String:
	return site_ids[target.selected] if target != null and target.selected >= 0 and target.selected < site_ids.size() else ""

func _can_act() -> bool:
	if not visible or not GameManager.is_session_active() or GameManager.is_save_in_progress() or GameManager.get_game_state() != _state: return false
	if GameManager._offline_job != null and GameManager._offline_job.phase in ["simulating", "ready"]: return false
	return _state.active_planet_id == _planet

func _begin_mining() -> void:
	_stop_mining()
	refresh_now()
	if not _can_act() or mine_button.disabled: return
	_hold_state = _state
	_hold_site = selected_site_id()
	_mine_once()
	if not _hold_site.is_empty(): _hold_timer.start()

func _mine_once() -> void:
	if not _can_act() or _hold_state != _state or _hold_site != selected_site_id():
		_stop_mining()
		return
	var result := SourceProgressionFacts.mine(_state, _hold_site, 1)
	status.text = result.message
	if not result.ok: _stop_mining()
	get_parent().refresh_now()
	refresh_now()

func _stop_mining() -> void:
	if _hold_timer != null: _hold_timer.stop()
	_hold_state = null
	_hold_site = ""

func _collect() -> void:
	_stop_mining()
	refresh_now()
	if not _can_act() or collect_button.disabled: return
	var result := InventorySystem.new(_state).try_collect_resource_output(selected_site_id())
	status.text = result.message
	get_parent().refresh_now()
	refresh_now()

func _install() -> void:
	_stop_mining()
	refresh_now()
	if not _can_act() or install_button.disabled: return
	var result: Dictionary = preload("res://scripts/game/SourceMinerSystem.gd").new(_state).install(selected_site_id(), install_count.value)
	status.text = result.message
	get_parent().refresh_now()
	refresh_now()
