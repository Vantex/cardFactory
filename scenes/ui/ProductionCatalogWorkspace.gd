class_name ProductionCatalogWorkspace
extends PanelContainer

var category: OptionButton
var target: OptionButton
var quantity: SpinBox
var center_quantity: SpinBox
var details: Label
var queue_status: Label
var target_ids: Array[String] = []
var preview: Dictionary = {}
var refresh_time := 0.0
var focus_item_id := ""
var discard_button: Button
var discard_dialog: ConfirmationDialog
var _discard_target := ""
var _discard_state: GameState

func _ready() -> void:
	position = Vector2(240, 90)
	size = Vector2(600, 480)
	z_index = 7
	var scroll := ScrollContainer.new()
	add_child(scroll)
	var content := VBoxContainer.new()
	content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(content)
	var title := Label.new()
	title.text = "完整生产与递归制造"
	content.add_child(title)
	category = OptionButton.new()
	category.name = "Category"
	category.add_item("生产配方")
	category.add_item("施工设备")
	category.item_selected.connect(func(_index): _populate())
	content.add_child(category)
	target = OptionButton.new()
	target.name = "Target"
	target.item_selected.connect(func(_index):
		focus_item_id = ""
		_preview())
	content.add_child(target)
	quantity = SpinBox.new()
	quantity.name = "Quantity"
	quantity.min_value = 1
	quantity.max_value = 99
	quantity.prefix = "制造批次 "
	quantity.value_changed.connect(func(_value): _preview())
	content.add_child(quantity)
	details = Label.new()
	details.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	content.add_child(details)
	_button(content, "重新预览材料", _preview)
	_button(content, "确认预留并制造", _queue)
	_button(content, "放置已拥有的施工件", _place)
	discard_button = Button.new()
	discard_button.name = "DiscardConstructionInventory"
	discard_button.text = "永久丢弃所选施工件…"
	discard_button.pressed.connect(_request_discard)
	content.add_child(discard_button)
	discard_dialog = ConfirmationDialog.new()
	discard_dialog.name = "DiscardConstructionConfirmation"
	discard_dialog.title = "确认永久丢弃施工件"
	discard_dialog.ok_button_text = "永久丢弃"
	discard_dialog.confirmed.connect(_confirm_discard)
	discard_dialog.canceled.connect(_clear_discard)
	add_child(discard_dialog)
	center_quantity = SpinBox.new()
	center_quantity.name = "CenterTarget"
	center_quantity.min_value = 0
	center_quantity.max_value = 100000000
	center_quantity.value = 10
	center_quantity.prefix = "持续目标库存 "
	content.add_child(center_quantity)
	_button(content, "设置所选制造中心的目标库存", _set_center)
	_button(content, "清除所选制造中心的当前目标", _clear_center_target)
	_button(content, "暂停 / 恢复所选制造中心", _pause_center)
	_button(content, "暂停 / 恢复本行星制造任务", _pause_jobs)
	_button(content, "取消首个任务并退回在制材料", _cancel_first)
	queue_status = Label.new()
	queue_status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	content.add_child(queue_status)
	_button(content, "返回工厂", hide)
	_populate()
	hide()

func _button(parent: Node, text: String, action: Callable) -> void:
	var button := Button.new()
	button.text = text
	if text == "确认预留并制造": button.name = "QueueCraft"
	button.pressed.connect(action)
	parent.add_child(button)

func _populate() -> void:
	focus_item_id = ""
	target.clear()
	target_ids.clear()
	var definitions: Dictionary = DataManager.construction if category.selected == 1 else DataManager.all_recipes
	var keys := definitions.keys()
	keys.sort()
	for id in keys:
		if not String(id).begins_with("dsp_"): continue
		target_ids.append(id)
		target.add_item(String(definitions[id].name))
	_preview()

func _preview() -> void:
	_refresh_discard()
	if target_ids.is_empty(): return
	if target.selected < 0:
		preview = {"ok": false, "message": "请采集该资源，或在已有生产设备中取得物品"}
		details.text = "%s\n%s" % [DataManager.get_item(focus_item_id).get("name", focus_item_id), preview.message]
		return
	var id := target_ids[maxi(target.selected, 0)]
	preview = CraftingPlanner.new(GameManager.game_state).plan(id, int(quantity.value), category.selected == 1)
	if preview.ok:
		details.text = "共 %d 道工序，预计 %.1f 秒\n需要预留：%s\n完成后的物品：%s" % [preview.steps.size(), preview.duration, _items_text(preview.reserved), _items_text(preview.steps.back().outputs)]
	else:
		details.text = "%s\n缺口：%s" % [preview.get("message", "不可制造"), _items_text(preview.get("missing", {}))]
	if not focus_item_id.is_empty(): details.text = String(DataManager.get_item(focus_item_id).get("name", focus_item_id)) + "\n" + details.text

	if category.selected == 1:
		var pending := DataManager.building_pending_reason(id)
		if not pending.is_empty(): details.text += "\n" + pending

func _queue() -> void:
	if target_ids.is_empty() or target.selected < 0: return
	var result := ConstructionAutomationSystem.new(GameManager.game_state).queue(target_ids[maxi(target.selected, 0)], int(quantity.value), category.selected == 1)
	EventBus.notice_requested.emit(result.message, "success" if result.ok else "error")
	_preview()

func _place() -> void:
	if category.selected != 1 or target_ids.is_empty() or target.selected < 0: return
	var id := target_ids[maxi(target.selected, 0)]
	if DataManager.get_building(id).is_empty():
		EventBus.notice_requested.emit("传送带已计入线路施工库存；连接建筑或在线路检查器中切换对应等级", "info")
		return
	get_parent()._on_building_pressed(id)
	hide()

func _refresh_discard() -> void:
	if discard_button == null: return
	discard_button.disabled = true
	if category.selected != 1 or target.selected < 0 or target.selected >= target_ids.size() or GameManager.game_state == null: return
	var amount := ConstructionSystem.new(GameManager.game_state).get_owned_count(CraftingPlanner.construction_stock_id(target_ids[target.selected]))
	discard_button.disabled = not is_finite(amount) or floorf(amount) < 1

func _request_discard() -> void:
	_refresh_discard()
	if discard_button.disabled: return
	_discard_target = target_ids[target.selected]
	_discard_state = GameManager.game_state
	var amount := ConstructionSystem.new(_discard_state).get_owned_count(CraftingPlanner.construction_stock_id(_discard_target))
	var automated := _discard_state.buildings.values().any(func(building): return float(building.get("construction_targets", {}).get(_discard_target, 0)) > 0)
	discard_dialog.dialog_text = "确认永久丢弃%s施工件库存 ×%.0f？不返还材料，无法恢复。已放置建筑和制造目标会保留。%s" % [DataManager.construction[_discard_target].name, floorf(amount), "制造中心仍会按目标继续生产。" if automated else ""]
	discard_dialog.popup_centered()

func _confirm_discard() -> void:
	if _discard_state == null or _discard_state != GameManager.game_state or _discard_target.is_empty():
		_clear_discard()
		EventBus.notice_requested.emit("工厂会话已变化，未执行丢弃", "error")
		return
	var result := ConstructionSystem.new(_discard_state).discard_inventory(_discard_target, true)
	_clear_discard()
	EventBus.notice_requested.emit(result.message, "success" if result.ok else "error")
	_preview()
	get_parent().refresh_now()

func _clear_discard() -> void:
	_discard_state = null
	_discard_target = ""

func _set_center() -> void:
	if category.selected != 1 or target_ids.is_empty(): return
	var ids: Array = get_parent()._current_selected_building_ids()
	if ids.size() != 1:
		EventBus.notice_requested.emit("请先选中一台建筑制造中心", "error")
		return
	var result := ConstructionAutomationSystem.new(GameManager.game_state).configure_center(ids[0], target_ids[maxi(target.selected, 0)], int(center_quantity.value))
	EventBus.notice_requested.emit(result.message, "success" if result.ok else "error")

func _pause_jobs() -> void:
	var jobs: Array = GameManager.game_state.production_orders.filter(func(job): return job.planet_id == GameManager.game_state.active_planet_id)
	var pause := jobs.any(func(job): return not job.paused)
	for job in jobs: job.paused = pause

func _cancel_first() -> void:
	for job in GameManager.game_state.production_orders:
		if job.planet_id == GameManager.game_state.active_planet_id:
			var result := ConstructionAutomationSystem.new(GameManager.game_state).cancel(job.id)
			EventBus.notice_requested.emit(result.message, "success" if result.ok else "error")
			return

func _process(delta: float) -> void:
	if not visible: return
	refresh_time += delta
	if refresh_time < 0.25: return
	refresh_time = 0
	_refresh_discard()
	var lines: Array[String] = []
	for job in GameManager.game_state.production_orders:
		var definition: Dictionary = DataManager.construction.get(job.target, {}) if job.construction else DataManager.get_recipe(job.target)
		lines.append("%s · 工序 %d/%d · %s" % [definition.get("name", job.target), int(job.step), job.steps.size(), "已暂停" if job.paused else {"queued": "排队", "running": "加工中", "output_full": "库存已满，等待交付", "no_power": "等待供电"}.get(job.status, job.status)])
	queue_status.text = "制造队列为空" if lines.is_empty() else "\n".join(lines)

func _items_text(items: Dictionary) -> String:
	var labels: Array[String] = []
	for id in items:
		if float(items[id]) <= 0: continue
		var definition: Dictionary = DataManager.get_item(id)
		if definition.is_empty(): definition = DataManager.construction.get(id, {})
		labels.append("%s × %.0f" % [definition.get("name", id), items[id]])
	return "、".join(labels) if not labels.is_empty() else "无"

func _pause_center() -> void:
	for id in get_parent()._current_selected_building_ids():
		var building: Dictionary = GameManager.game_state.buildings[id]
		if PowerGridSystem.kind_id(building) == "construction_center": building.automation_paused = not building.get("automation_paused", false)

func _clear_center_target() -> void:
	if category.selected != 1 or target_ids.is_empty(): return
	var ids: Array = get_parent()._current_selected_building_ids()
	if ids.size() != 1: return
	var result := ConstructionAutomationSystem.new(GameManager.game_state).configure_center(ids[0], target_ids[maxi(target.selected, 0)], 0)
	EventBus.notice_requested.emit(result.message, "success" if result.ok else "error")

func navigate_to(navigation: Dictionary) -> void:
	var id := ""
	focus_item_id = ""
	if navigation.get("kind") == "recipe":
		category.select(0)
		for recipe in DataManager.all_recipes.values():
			if recipe.has("source_id") and recipe.get("outputs", []).any(func(output): return output.item_id == navigation.itemId):
				id = recipe.id
				break
	else:
		category.select(1)
		var source_id := String(navigation.get("buildingId", navigation.get("constructionId", "")))
		id = source_id if DataManager.construction.has(source_id) else "dsp_" + source_id
	_populate()
	if target_ids.has(id): target.select(target_ids.find(id))
	if navigation.get("kind") == "recipe":
		focus_item_id = String(navigation.itemId)
		if id.is_empty(): target.select(-1)
	_preview()
