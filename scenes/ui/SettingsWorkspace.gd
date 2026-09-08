extends PanelContainer

signal dismissed
var theme_choice: OptionButton
var font_scale: HSlider
var density_choice: OptionButton
var invert_zoom: CheckButton
var cursor_speed: HSlider
var status: Label
var font_label: Label
var resolution_label: Label

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	var scroll := ScrollContainer.new()
	scroll.name = "Scroll"
	scroll.follow_focus = true
	add_child(scroll)
	var content := VBoxContainer.new()
	content.name = "Content"
	content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	content.add_theme_constant_override("separation", 12)
	scroll.add_child(content)
	_label(content, "本机设置 · 不随存档切换")
	resolution_label = _label(content, "")
	get_viewport().size_changed.connect(_refresh_resolution)
	LocalSettings.changed.connect(_refresh_resolution)
	_refresh_resolution()
	theme_choice = _choice(content, "主题", ["暗色", "亮色"])
	font_label = _label(content, "字号")
	font_scale = _slider(content, 0.8, 2.0, 0.05)
	font_scale.value_changed.connect(func(value: float): font_label.text = "字号：%d%%" % roundi(value * 100))
	density_choice = _choice(content, "界面密度", ["紧凑", "舒适（较大控件间距）"])
	invert_zoom = CheckButton.new()
	invert_zoom.text = "反转滚轮缩放"
	content.add_child(invert_zoom)
	_label(content, "手柄光标速度")
	cursor_speed = _slider(content, 0.5, 2.0, 0.1)
	_label(content, "Tab / 方向键导航，Enter / 手柄 A 确认，Escape / B 返回。\nF6 / 手柄 Y 在界面与画布之间切换焦点。画布方向键 / 左摇杆移动光标，Enter / A 选择或放置，M / 左摇杆按下移动选中建筑，C / 右摇杆按下连线，Delete / X 请求删除；LB / RB 缩放，右摇杆平移。")
	status = _label(content, "")
	_button(content, "开始性能监测（清空上次采样）", func():
		GameManager.performance_monitor.start({"viewport": str(get_viewport().get_visible_rect().size), "scope": "interactive session"})
		status.text = "监测已开启；返回工厂操作后，停止并导出报告。每项最多保留 3600 个样本。")
	_button(content, "停止并导出性能报告", func():
		GameManager.performance_monitor.stop()
		var result := GameManager.performance_monitor.export_report()
		status.text = "报告已保存：" + result.path if result.ok else result.message)
	_button(content, "保存并应用", apply_preferences)
	_button(content, "恢复默认设置", func(): _show_values(SettingsSystem.DEFAULTS))
	_button(content, "返回", func(): hide(); dismissed.emit())
	hide()

func open() -> void:
	_show_values(LocalSettings.values)
	status.text = LocalSettings.load_error
	show()
	theme_choice.grab_focus()

func _show_values(settings: Dictionary) -> void:
	theme_choice.select(0 if settings.theme == "dark" else 1)
	font_scale.value = settings.font_scale
	font_label.text = "字号：%d%%" % roundi(font_scale.value * 100)
	density_choice.select(0 if settings.density == "compact" else 1)
	invert_zoom.button_pressed = settings.invert_zoom
	cursor_speed.value = settings.cursor_speed

func apply_preferences() -> void:
	var result := LocalSettings.update_preferences({"theme": "dark" if theme_choice.selected == 0 else "light", "font_scale": font_scale.value, "density": "compact" if density_choice.selected == 0 else "comfortable", "invert_zoom": invert_zoom.button_pressed, "cursor_speed": cursor_speed.value})
	status.text = "已保存到本机" if result.ok else result.message

func _label(parent: Node, text: String) -> Label:
	var label := Label.new()
	label.text = text
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	parent.add_child(label)
	return label

func _choice(parent: Node, title: String, choices: Array) -> OptionButton:
	_label(parent, title)
	var choice := OptionButton.new()
	for text in choices: choice.add_item(text)
	parent.add_child(choice)
	return choice

func _slider(parent: Node, low: float, high: float, increment: float) -> HSlider:
	var slider := HSlider.new()
	slider.min_value = low
	slider.max_value = high
	slider.step = increment
	slider.custom_minimum_size.y = 44
	parent.add_child(slider)
	return slider

func _button(parent: Node, title: String, callback: Callable) -> void:
	var button := Button.new()
	button.text = title
	button.pressed.connect(callback)
	parent.add_child(button)

func _refresh_resolution() -> void:
	var viewport_size := get_viewport().get_visible_rect().size
	var layout := DesktopLayout.metrics(viewport_size, LocalSettings.values)
	resolution_label.text = "当前窗口 %d × %d · 自动界面比例 %.0f%%\n字号在自动比例上叠加；调整窗口后自动更新。" % [viewport_size.x, viewport_size.y, float(layout.automatic_scale) * 100]
