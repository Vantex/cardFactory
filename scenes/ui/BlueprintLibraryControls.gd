extends VBoxContainer

var workspace: BlueprintWorkspace
var title: LineEdit
var saved: OptionButton
var orders: OptionButton
var overlap: CheckBox
var summary: Label
var source_recipe: OptionButton
var target_recipe: OptionButton
var fleet_station: OptionButton
var fleet_item: OptionButton
var fleet_count: SpinBox
var selected_id := ""
var fleet_targets := {}
var _signature := ""

func _ready() -> void:
	_label("持久蓝图库与施工")
	title = LineEdit.new()
	title.name = "BlueprintName"
	title.placeholder_text = "蓝图名称"
	add_child(title)
	saved = OptionButton.new()
	saved.name = "SavedBlueprints"
	add_child(saved)
	saved.item_selected.connect(_load_selected)
	_button("保存为新蓝图", func(): _save(true))
	_button("更新所选蓝图（含名称与变换）", func(): _save(false))
	_button("删除所选蓝图", _remove)
	_label("配方替换：先选择原配方，再选择新配方")
	source_recipe = OptionButton.new()
	target_recipe = OptionButton.new()
	for recipe_id in DataManager.all_recipes:
		var recipe := DataManager.get_recipe(recipe_id)
		for picker in [source_recipe, target_recipe]:
			picker.add_item(recipe.get("name", recipe_id))
			picker.set_item_metadata(picker.item_count - 1, recipe_id)
	add_child(source_recipe)
	add_child(target_recipe)
	_button("应用配方替换到草稿", _replace_recipe)
	_label("载具目标（有物流站的蓝图）")
	fleet_station = OptionButton.new()
	add_child(fleet_station)
	fleet_item = OptionButton.new()
	for item in StationSystem.FLEET_ITEMS:
		fleet_item.add_item(DataManager.get_item(item).get("name", item))
		fleet_item.set_item_metadata(fleet_item.item_count - 1, item)
	add_child(fleet_item)
	fleet_count = SpinBox.new()
	fleet_count.max_value = 999
	add_child(fleet_count)
	_button("设置载具目标", _set_fleet)
	overlap = CheckBox.new()
	overlap.text = "允许复用配置一致的重叠建筑"
	add_child(overlap)
	_button("排队部署到相机", _queue)
	orders = OptionButton.new()
	orders.name = "ConstructionOrders"
	add_child(orders)
	_button("资助所选订单", func(): _fund("all"))
	_button("仅资助施工件", func(): _fund("construction"))
	_button("仅资助载具", func(): _fund("fleet"))
	_button("资助全部订单", func(): ConstructionQueueSystem.new(GameManager.game_state).fund_all(); refresh())
	_button("取消所选订单并返还预留", _cancel)
	summary = Label.new()
	summary.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	add_child(summary)
	refresh()

func _process(_delta: float) -> void:
	if not is_visible_in_tree(): return
	var signature := JSON.stringify(GameManager.game_state.blueprint_library) + JSON.stringify(GameManager.game_state.construction_queue) + str(workspace.get_draft())
	if signature != _signature:
		_signature = signature
		refresh()

func refresh() -> void:
	var order_id := _selected(orders)
	saved.clear()
	saved.add_item("选择已保存蓝图")
	saved.set_item_metadata(0, "")
	for id in GameManager.game_state.blueprint_library:
		saved.add_item(GameManager.game_state.blueprint_library[id].name)
		saved.set_item_metadata(saved.item_count - 1, id)
		if id == selected_id: saved.select(saved.item_count - 1)
	orders.clear()
	var lines: Array[String] = []
	for order in GameManager.game_state.construction_queue:
		orders.add_item(order.name + (" · 待建" if order.placed.is_empty() else " · 等待载具"))
		orders.set_item_metadata(orders.item_count - 1, order.id)
		if order.id == order_id: orders.select(orders.item_count - 1)
		lines.append("%s：施工件预留 %s，载具预留 %s" % [order.name, _amount_text(order.reserved), _amount_text(order.fleet_reserved)])
	fleet_station.clear()
	for entity in workspace.get_draft().get("entities", []):
		if entity.type in StationSystem.TYPES:
			fleet_station.add_item(DataManager.get_building(entity.type).name + " %d" % (fleet_station.item_count + 1))
			fleet_station.set_item_metadata(fleet_station.item_count - 1, entity.ref)
	if summary != null: summary.text = "运行时每秒自动尝试补足；暂停时可手动资助。\n" + "\n".join(lines)

func _entry() -> Dictionary:
	var encoded := BlueprintCodec.new().encode(workspace.get_draft())
	if not encoded.ok: return {}
	return {"name": title.text.strip_edges() if not title.text.strip_edges().is_empty() else "施工蓝图", "text": encoded.text, "rotation": workspace._rotation_quarters, "mirrored": workspace._mirrored, "overrides": {}, "fleet_targets": fleet_targets.duplicate(true)}

func _save(as_new: bool) -> void:
	var result := BlueprintLibrary.new(GameManager.game_state).save_definition(title.text, workspace.get_draft(), "" if as_new else selected_id, workspace._rotation_quarters, workspace._mirrored, {}, fleet_targets)
	if result.ok: selected_id = result.id
	_show(result)

func _load_selected(_index: int) -> void:
	selected_id = _selected(saved)
	if selected_id.is_empty(): return
	var entry: Dictionary = GameManager.game_state.blueprint_library[selected_id]
	var result := BlueprintLibrary.resolve(entry)
	if not result.ok: _show(result); return
	workspace.accept_capture_result(result)
	selected_id = entry.id
	workspace._rotation_quarters = int(entry.rotation)
	workspace._mirrored = entry.mirrored
	title.text = entry.name
	fleet_targets = entry.get("fleet_targets", {}).duplicate(true)
	workspace.queue_redraw()
	refresh()

func _remove() -> void:
	_show(BlueprintLibrary.new(GameManager.game_state).remove(selected_id))
	selected_id = ""
	refresh()

func _replace_recipe() -> void:
	var entry := _entry()
	if entry.is_empty(): return
	entry.overrides = {_selected(source_recipe): _selected(target_recipe)}
	var result := BlueprintLibrary.resolve(entry)
	if result.ok:
		workspace._draft = result.blueprint.duplicate(true)
		workspace.queue_redraw()
	_show({"ok": result.ok, "message": "草稿配方已替换；保存以保留" if result.ok else result.message})

func _set_fleet() -> void:
	var ref := _selected(fleet_station)
	if ref.is_empty(): _show(BlueprintLibrary.fail("草稿没有物流站")); return
	var candidate := fleet_targets.duplicate(true)
	if not candidate.has(ref): candidate[ref] = {}
	candidate[ref][_selected(fleet_item)] = int(fleet_count.value)
	var entry := _entry()
	entry.fleet_targets = candidate
	if not BlueprintStateValidator._definition(entry): _show(BlueprintLibrary.fail("该物流站不支持此载具目标")); return
	fleet_targets = candidate
	_show({"ok": true, "message": "载具目标已设置；保存或排队以保留"})

func _queue() -> void:
	var camera := get_viewport().get_camera_2d()
	if camera == null: return
	_show(ConstructionQueueSystem.new(GameManager.game_state).enqueue(_entry(), camera.global_position, overlap.button_pressed))

func _fund(scope: String) -> void:
	_show(ConstructionQueueSystem.new(GameManager.game_state).fund(_selected(orders), scope))

func _cancel() -> void:
	_show(ConstructionQueueSystem.new(GameManager.game_state).cancel(_selected(orders)))

func _show(result: Dictionary) -> void:
	EventBus.notice_requested.emit(result.get("message", ""), "success" if result.get("ok", false) else "error")
	refresh()

func _selected(picker: OptionButton) -> String:
	return String(picker.get_item_metadata(picker.selected)) if picker != null and picker.selected >= 0 else ""

func _amount_text(amounts: Dictionary) -> String:
	var lines: Array[String] = []
	for item in amounts:
		lines.append("%s × %d" % [DataManager.get_item(item).get("name", DataManager.get_building(item).get("name", item)), amounts[item]])
	return "、".join(lines) if not lines.is_empty() else "无"

func _label(text: String) -> void:
	var label := Label.new()
	label.text = text
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	add_child(label)

func _button(text: String, action: Callable) -> void:
	var button := Button.new()
	button.text = text
	button.pressed.connect(action)
	add_child(button)
