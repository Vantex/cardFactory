class_name CommandPalette
extends PanelContainer

var search: LineEdit
var results: ItemList
var entries: Array = []
var filtered: Array = []

func _ready() -> void:
	position = Vector2(240, 80)
	size = Vector2(600, 430)
	z_index = 10
	var box := VBoxContainer.new()
	add_child(box)
	var title := Label.new()
	title.text = "命令面板 · Ctrl+K"
	box.add_child(title)
	search = LineEdit.new()
	search.name = "Search"
	search.placeholder_text = "搜索操作、建筑或实体 ID"
	search.text_changed.connect(func(_value): _filter())
	search.gui_input.connect(_search_input)
	search.text_submitted.connect(func(_value): execute_selected())
	box.add_child(search)
	results = ItemList.new()
	results.name = "Results"
	results.size_flags_vertical = Control.SIZE_EXPAND_FILL
	results.item_activated.connect(func(_index): execute_selected())
	box.add_child(results)
	var close := Button.new()
	close.text = "返回工厂"
	close.pressed.connect(hide)
	box.add_child(close)
	hide()

func open(commands: Array) -> void:
	entries = commands
	search.text = ""
	_filter()
	show()
	search.grab_focus()

func _filter() -> void:
	filtered.clear()
	results.clear()
	for entry in entries:
		if not search.text.strip_edges().is_empty() and not String(entry.label).to_lower().contains(search.text.strip_edges().to_lower()): continue
		filtered.append(entry)
		results.add_item(entry.label)
	if not filtered.is_empty(): results.select(0)

func execute_selected() -> void:
	var selected := results.get_selected_items()
	if selected.is_empty() or filtered.is_empty(): return
	var action: Callable = filtered[selected[0]].action
	hide()
	action.call()

func _input(event: InputEvent) -> void:
	if visible and event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE:
		hide()
		get_viewport().set_input_as_handled()

func _search_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and event.keycode in [KEY_DOWN, KEY_UP] and not filtered.is_empty():
		var selected := results.get_selected_items()
		var index := selected[0] if not selected.is_empty() else 0
		results.select(clampi(index + (1 if event.keycode == KEY_DOWN else -1), 0, filtered.size() - 1))
		results.ensure_current_is_visible()
		search.accept_event()
