class_name StationPresentationPanel
extends VBoxContainer

var summary: Label
var feedback: Label
var decorations: OptionButton
var themes: OptionButton
var placements: OptionButton
var x: SpinBox
var y: SpinBox
var angle_choice: OptionButton
var layer: SpinBox
var variant: SpinBox
var zoom: SpinBox
var title_field: LineEdit
var motto: LineEdit
var metrics: Array = []
var achievements: Array = []
var preview: LayoutPreview
var signature := ""
var elapsed := 0.0

func model() -> StationPresentationSystem: return StationPresentationSystem.new(GameManager.get_game_state())
func selected(node: OptionButton) -> String: return String(node.get_item_metadata(node.selected)) if node.selected >= 0 else ""

func _ready() -> void:
	add_theme_constant_override("separation", 12)
	label("空间站展厅 · 永久装饰授权与主题")
	summary = label("")
	preview = LayoutPreview.new()
	preview.panel = self
	preview.name = "StationLayoutPreview"
	preview.clip_contents = true
	preview.custom_minimum_size = Vector2(0, 360)
	preview.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	preview.tooltip_text = "点击甲板填入摆放坐标；灰色区域是功能区，不能覆盖。"
	add_child(preview)
	decorations = OptionButton.new()
	decorations.name = "DecorationChoice"
	for row in StationPresentationSystem.catalog().decorations:
		decorations.add_item("%s · 印记 %s · 等级 %d" % [row.name, row.markCost, int(row.minimumLevel)])
		decorations.set_item_metadata(decorations.item_count - 1, row.id)
	add_child(decorations)
	button("购买所选装饰永久授权", func(): action(model().purchase(selected(decorations))))
	label("位置 X / Y（点击甲板可填入）；旋转、层级、变体")
	label("位置 X")
	x = spin(-20000, 20000, "DecorationX")
	label("位置 Y")
	y = spin(-20000, 20000, "DecorationY")
	label("旋转角度")
	angle_choice = OptionButton.new()
	for angle in [0, 90, 180, 270]:
		angle_choice.add_item(str(angle) + "°")
		angle_choice.set_item_metadata(angle_choice.item_count - 1, angle)
	add_child(angle_choice)
	label("层级（0 为甲板，1～3 为物件与覆盖层）")
	layer = spin(0, 3, "DecorationLayer")
	layer.value = 1
	label("变体编号（从 0 开始）")
	variant = spin(0, 5, "DecorationVariant")
	button("摆放所选装饰", func(): action(model().place(selected(decorations), position_data())))
	placements = OptionButton.new()
	placements.name = "StationPlacements"
	add_child(placements)
	button("读取选中装饰位置", load_placement)
	button("移动选中装饰并保存", func(): action(model().update_placement(selected(placements), position_data())))
	button("移除选中装饰（保留授权）", func(): action(model().remove(selected(placements))))
	themes = OptionButton.new()
	for row in StationPresentationSystem.catalog().themes:
		themes.add_item("%s · 印记 %s · 等级 %d" % [row.name, row.markCost, int(row.minimumLevel)])
		themes.set_item_metadata(themes.item_count - 1, row.id)
	add_child(themes)
	button("购买所选主题永久授权", func(): action(model().purchase(selected(themes), true)))
	button("应用所选空间站主题", func(): action(model().set_theme(selected(themes))))
	label("展厅缩放")
	zoom = spin(0.2, 2.5, "StationDisplayZoom")
	zoom.step = 0.1
	zoom.value = model().snapshot().viewport.zoom
	button("保存展厅缩放并居中", func(): action(model().set_viewport(0, 0, zoom.value)))
	label("空间站名称与签名")
	title_field = LineEdit.new()
	title_field.name = "StationTitle"
	title_field.max_length = 32
	title_field.text = model().snapshot().profile.title
	add_child(title_field)
	motto = LineEdit.new()
	motto.max_length = 96
	motto.text = model().snapshot().profile.motto
	add_child(motto)
	label("名片指标（最多四项）")
	for pair in [["总发电", "total-generation"], ["峰值吞吐", "peak-throughput"], ["戴森功率", "dyson-power"], ["已探索恒星系", "explored-systems"], ["已殖民行星", "colonized-planets"], ["白矩阵产量", "universe-matrix-produced"], ["太阳帆发射", "solar-sails-launched"], ["火箭发射", "carrier-rockets-launched"]]:
		var check := CheckBox.new()
		check.text = pair[0]
		check.set_meta("metric", pair[1])
		check.button_pressed = model().snapshot().profile.featured_metrics.has(pair[1])
		metrics.append(check)
		add_child(check)
	button("保存空间站名片", func():
		var chosen := []
		for check in metrics:
			if check.button_pressed: chosen.append(check.get_meta("metric"))
		action(model().set_profile(title_field.text, motto.text, chosen)))
	label("成就展示（最多八项，需已解锁）")
	for definition in ObjectiveSystem.new().catalog.get("achievements", []):
		var check := CheckBox.new()
		check.text = definition.get("name", definition.id)
		check.set_meta("achievement", definition.id)
		achievements.append(check)
		add_child(check)
	button("保存空间站成就展示", func():
		var chosen := []
		for check in achievements:
			if check.button_pressed: chosen.append(check.get_meta("achievement"))
		action(model().set_featured_achievements(chosen)))
	feedback = label("")
	GameManager.game_state_replaced.connect(func(_state): reset_profile())
	reset_profile()

func label(value: String) -> Label:
	var node := Label.new()
	node.text = value
	node.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	add_child(node)
	return node
func button(value: String, callback: Callable) -> void:
	var node := Button.new()
	node.text = value
	node.pressed.connect(callback)
	add_child(node)
func spin(minimum: float, maximum: float, node_name: String) -> SpinBox:
	var node := SpinBox.new()
	node.min_value = minimum
	node.max_value = maximum
	node.name = node_name
	add_child(node)
	return node
func position_data() -> Dictionary:
	return {"x": x.value, "y": y.value, "rotation": int(angle_choice.get_item_metadata(angle_choice.selected)), "layer": int(layer.value), "variant": int(variant.value)}
func action(outcome: Dictionary) -> void:
	feedback.text = outcome.message
	refresh()
func load_placement() -> void:
	for entry in model().snapshot().placements:
		if entry.id != selected(placements): continue
		x.value = entry.x
		y.value = entry.y
		angle_choice.select(int(entry.rotation) / 90)
		layer.value = entry.layer
		variant.value = entry.variant
func refresh() -> void:
	var current := model()
	var config := current.snapshot()
	var rank := current.level()
	summary.text = "%s · %s\n等级 %d：%s · 摆放 %d / %d · 印记 %s" % [config.profile.title, config.profile.motto, int(rank.level), rank.title, config.placements.size(), int(rank.placementLimit), StationContractSystem.economy_text(GameManager.get_game_state().station_contracts.get("marks", "0"))]
	var next_signature := JSON.stringify(config.placements)
	if next_signature != signature:
		var previous := selected(placements)
		placements.clear()
		for entry in config.placements:
			placements.add_item("%s · (%.0f, %.0f)" % [StationPresentationSystem.definition(entry.decoration_id).name, entry.x, entry.y])
			placements.set_item_metadata(placements.item_count - 1, entry.id)
			if entry.id == previous: placements.select(placements.item_count - 1)
		signature = next_signature
	for check in achievements: check.disabled = not GameManager.get_game_state().completed_achievement_ids.has(check.get_meta("achievement"))
	preview.queue_redraw()
func _process(delta: float) -> void:
	if not is_visible_in_tree(): return
	elapsed += delta
	if elapsed >= 0.5:
		elapsed = 0
		refresh()

class LayoutPreview extends Control:
	var panel: StationPresentationPanel
	func scale_factor() -> float:
		var rank := panel.model().level()
		return minf(size.x / (float(rank.halfWidth) * 2 + 80), size.y / (float(rank.halfHeight) * 2 + 80)) * float(panel.model().snapshot().viewport.zoom)
	func _draw() -> void:
		if panel == null: return
		var config := panel.model().snapshot()
		var theme := StationPresentationSystem.definition(config.theme, "themes")
		draw_rect(Rect2(Vector2.ZERO, size), Color(theme.background))
		var scale := scale_factor()
		var origin := size / 2 - Vector2(config.viewport.x, config.viewport.y) * scale
		var rank := panel.model().level()
		var extent := Vector2(rank.halfWidth, rank.halfHeight) * scale
		draw_rect(Rect2(origin - extent, extent * 2), Color(theme.accent), false, 2)
		for anchor in StationPresentationSystem.ANCHORS: draw_rect(Rect2(origin + anchor.position * scale, anchor.size * scale), Color(0.35, 0.4, 0.4, 0.5))
		var entries: Array = config.placements.duplicate()
		entries.sort_custom(func(a, b): return int(a.layer) < int(b.layer))
		for entry in entries:
			var definition := StationPresentationSystem.definition(entry.decoration_id)
			var center := origin + Vector2(entry.x, entry.y) * scale
			var bounds := Vector2(definition.height, definition.width) if int(entry.rotation) in [90, 270] else Vector2(definition.width, definition.height)
			bounds *= scale
			draw_rect(Rect2(center - bounds / 2, bounds), Color(Color(definition.color), 0.3))
			draw_rect(Rect2(center - bounds / 2, bounds), Color(definition.color), false, 2)
			draw_string(ThemeDB.fallback_font, center + Vector2(-8, 6), definition.glyph, HORIZONTAL_ALIGNMENT_LEFT, -1, 20, Color(definition.color))
	func _gui_input(event: InputEvent) -> void:
		if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
			var config := panel.model().snapshot()
			var position: Vector2 = (event.position - size / 2) / scale_factor() + Vector2(config.viewport.x, config.viewport.y)
			panel.x.value = position.x
			panel.y.value = position.y
			accept_event()

func reset_profile() -> void:
	var config := model().snapshot()
	title_field.text = config.profile.title
	motto.text = config.profile.motto
	zoom.value = config.viewport.zoom
	for check in metrics: check.button_pressed = config.profile.featured_metrics.has(check.get_meta("metric"))
	for check in achievements: check.button_pressed = config.featured_achievements.has(check.get_meta("achievement"))
	signature = ""
	refresh()
