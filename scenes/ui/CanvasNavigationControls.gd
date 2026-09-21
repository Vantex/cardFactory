extends VBoxContainer

var title: LineEdit
var markers: OptionButton
var tint: ColorPickerButton
var coordinates: Array[SpinBox] = []
var _signature := ""

func _ready() -> void:
	var heading := Label.new()
	heading.text = "区域与镜头书签"
	add_child(heading)
	title = LineEdit.new()
	title.placeholder_text = "区域或书签名称"
	add_child(title)
	markers = OptionButton.new()
	markers.name = "NavigationMarkers"
	markers.item_selected.connect(_select)
	add_child(markers)
	var grid := GridContainer.new()
	grid.columns = 2
	add_child(grid)
	for label_text in ["横坐标", "纵坐标", "宽度", "高度"]:
		var label := Label.new()
		label.text = label_text
		grid.add_child(label)
		var field := SpinBox.new()
		field.min_value = -100000 if coordinates.size() < 2 else 1
		field.max_value = 100000
		field.value = 600 if coordinates.size() == 2 else 300 if coordinates.size() == 3 else 0
		grid.add_child(field)
		coordinates.append(field)
	tint = ColorPickerButton.new()
	tint.color = Color(0.38, 0.71, 0.68, 0.25)
	add_child(tint)
	_button("保存当前镜头书签", func(): _bookmark(false))
	_button("用当前镜头更新所选书签", func(): _bookmark(true))
	_button("用所选建筑范围填入矩形", _selection_bounds)
	_button("创建区域", func(): _region(false))
	_button("更新所选区域矩形与颜色", func(): _region(true))
	_button("重命名标记", func(): _show(CanvasNavigation.new(GameManager.game_state).rename(_id(), title.text)))
	_button("定位标记（可跨行星）", _navigate)
	_button("删除标记", func(): _show(CanvasNavigation.new(GameManager.game_state).remove(_id())))
	refresh()

func _process(_delta: float) -> void:
	if not is_visible_in_tree(): return
	var signature := str(GameManager.game_state.canvas_regions) + str(GameManager.game_state.canvas_bookmarks)
	if _signature != signature:
		_signature = signature
		refresh()

func refresh() -> void:
	var old := _id()
	markers.clear()
	for collection in [GameManager.game_state.canvas_bookmarks, GameManager.game_state.canvas_regions]:
		for entry in collection:
			markers.add_item(entry.name + " · " + String(entry.planet_id))
			markers.set_item_metadata(markers.item_count - 1, entry.id)
			if entry.id == old: markers.select(markers.item_count - 1)

func _entry() -> Dictionary:
	for collection in [GameManager.game_state.canvas_bookmarks, GameManager.game_state.canvas_regions]:
		for entry in collection:
			if entry.id == _id(): return entry
	return {}

func _select(_index: int) -> void:
	var entry := _entry()
	if entry.is_empty(): return
	title.text = entry.name
	if entry.has("rect"):
		for i in range(4): coordinates[i].value = entry.rect[i]
		tint.color = Color.html(entry.color)

func _bookmark(update: bool) -> void:
	var camera := get_viewport().get_camera_2d()
	if camera == null: return
	_show(CanvasNavigation.new(GameManager.game_state).save_bookmark(title.text, camera.global_position, camera.zoom.x, _id() if update else ""))

func _region(update: bool) -> void:
	var rect := Rect2(coordinates[0].value, coordinates[1].value, coordinates[2].value, coordinates[3].value)
	_show(CanvasNavigation.new(GameManager.game_state).save_region(title.text, rect, tint.color, _id() if update else ""))

func _selection_bounds() -> void:
	var main := _main()
	if main == null: return
	var selected: Array = main.get_node("InputHandler").get_selected_entity_ids()
	var bounds := Rect2()
	var found := false
	for id in selected:
		var building: Dictionary = GameManager.game_state.buildings.get(id, {})
		if building.is_empty(): continue
		var rect := FactoryGeometry.card_rect(building.position)
		bounds = bounds.merge(rect) if found else rect
		found = true
	if not found: _show(BlueprintLibrary.fail("请选择建筑以获取区域范围")); return
	var values := [bounds.position.x, bounds.position.y, bounds.size.x, bounds.size.y]
	for i in range(4): coordinates[i].value = values[i]

func _navigate() -> void:
	var entry := _entry()
	var main := _main()
	if entry.is_empty() or main == null: return
	var result: Dictionary = main.try_travel_to_planet(entry.planet_id)
	if not result.ok: _show(result); return
	var camera: Camera2D = main.get_node("WorldCamera")
	if entry.has("rect"):
		camera.global_position = Vector2(entry.rect[0] + entry.rect[2] / 2, entry.rect[1] + entry.rect[3] / 2)
	else:
		camera.global_position = Vector2(entry.position[0], entry.position[1])
		camera.zoom = Vector2.ONE * float(entry.zoom)
	camera.force_update_scroll()
	main._save_planet_viewport(entry.planet_id)
	_show({"ok": true, "message": "已定位到 " + String(entry.name)})

func _main() -> Node:
	var node := get_parent()
	while node != null:
		if node.has_method("try_travel_to_planet"): return node
		node = node.get_parent()
	return null

func _id() -> String:
	return String(markers.get_item_metadata(markers.selected)) if markers != null and markers.selected >= 0 else ""

func _show(result: Dictionary) -> void:
	EventBus.notice_requested.emit(result.get("message", ""), "success" if result.get("ok", false) else "error")
	refresh()

func _button(text: String, action: Callable) -> void:
	var button := Button.new()
	button.text = text
	button.pressed.connect(action)
	add_child(button)
