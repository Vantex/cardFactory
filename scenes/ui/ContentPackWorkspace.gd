extends PanelContainer
signal dismissed
var editor: TextEdit
var path_input: LineEdit
var packs: OptionButton
var details: Label
var status: Label
var content: VBoxContainer
var export_dialog: FileDialog
var dialog: FileDialog

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	var margin := MarginContainer.new()
	for side in ["left", "right", "top", "bottom"]: margin.add_theme_constant_override("margin_" + side, 24)
	add_child(margin)
	var scroll := ScrollContainer.new()
	margin.add_child(scroll)
	content = VBoxContainer.new()
	content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	content.add_theme_constant_override("separation", 8)
	scroll.add_child(content)
	label("本地内容包 · 离线目录扩展")
	button("返回", func(): hide(); dismissed.emit())
	label("导入本地 JSON 文件，或粘贴内容。内容包不会运行代码。正在使用的工厂、存档和蓝图会阻止停用或移除。")
	path_input = LineEdit.new()
	path_input.placeholder_text = "本地 JSON 文件路径"
	content.add_child(path_input)
	button("选择本地 JSON 文件", func(): dialog.popup_centered_ratio(0.7))
	button("读取路径中的文件", read_path)
	editor = TextEdit.new()
	editor.name = "ContentPackJson"
	editor.custom_minimum_size = Vector2(500, 210)
	editor.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	content.add_child(editor)
	var template := button("生成可编辑模板", show_template)
	template.name = "ContentPackTemplate"
	button("导出 JSON 模板", func():
		show_template()
		export_dialog.popup_centered_ratio(0.7)).name = "ContentPackExportTemplate"
	button("校验内容", validate_editor).name = "ContentPackValidate"
	button("注册并尝试启用", register_editor).name = "ContentPackRegister"
	status = label("")
	packs = OptionButton.new()
	packs.name = "RegisteredContentPacks"
	packs.item_selected.connect(func(_index): refresh_details())
	content.add_child(packs)
	button("启用选中内容包", func(): mutate("enable"))
	button("停用选中内容包", func(): mutate("disable"))
	button("移除选中内容包", func(): mutate("remove"))
	details = label("")
	dialog = FileDialog.new()
	dialog.file_mode = FileDialog.FILE_MODE_OPEN_FILE
	dialog.access = FileDialog.ACCESS_FILESYSTEM
	dialog.filters = PackedStringArray(["*.json ; 内容包 JSON"])
	dialog.file_selected.connect(func(selected): path_input.text = selected; read_path())
	add_child(dialog)
	export_dialog = FileDialog.new()
	export_dialog.file_mode = FileDialog.FILE_MODE_SAVE_FILE
	export_dialog.access = FileDialog.ACCESS_FILESYSTEM
	export_dialog.current_file = "content-pack-template.json"
	export_dialog.filters = dialog.filters
	export_dialog.file_selected.connect(func(selected):
		var file := FileAccess.open(selected, FileAccess.WRITE)
		if file == null: status.text = "无法写入模板文件"; return
		file.store_string(editor.text)
		status.text = "模板已导出：" + selected)
	add_child(export_dialog)
	hide()

func label(value: String) -> Label:
	var node := Label.new()
	node.text = value
	node.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	content.add_child(node)
	return node

func button(value: String, action: Callable) -> Button:
	var node := Button.new()
	node.text = value
	node.pressed.connect(action)
	content.add_child(node)
	return node

func open() -> void:
	show()
	refresh()
	status.text = DataManager.content_pack_system.last_error

func selected_id() -> String:
	return String(packs.get_item_metadata(packs.selected)) if packs.selected >= 0 else ""

func refresh() -> void:
	var selected := selected_id()
	packs.clear()
	var ids: Array = DataManager.content_pack_system.registry.packs.keys()
	ids.sort()
	for id in ids:
		var pack: Dictionary = DataManager.content_pack_system.registry.packs[id]
		packs.add_item("%s · %s · %s" % [pack.manifest.name, pack.manifest.version, "启用" if pack.enabled else "停用"])
		packs.set_item_metadata(packs.item_count - 1, id)
		if id == selected: packs.select(packs.item_count - 1)
	refresh_details()

func refresh_details() -> void:
	var service := DataManager.content_pack_system
	var pack: Dictionary = service.registry.packs.get(selected_id(), {})
	if pack.is_empty():
		details.text = "尚无注册的本地内容包。"
		return
	var manifest: Dictionary = pack.manifest
	details.text = "%s · %s\n物品 %d · 建筑 %d · 配方 %d · 科技 %d · 传送带 %d\n依赖：%s\n%s" % [manifest.name, manifest.version, manifest.items.size(), manifest.buildings.size(), manifest.recipes.size(), manifest.technologies.size(), manifest.belts.size(), "、".join(manifest.dependencies), service.dependency_reason(manifest, service.registry.packs)]

func read_path() -> void:
	var file := FileAccess.open(path_input.text.strip_edges(), FileAccess.READ)
	if file == null or file.get_length() > 2097152:
		status.text = "无法读取文件，或文件超过 2 MB。"
		return
	editor.text = file.get_as_text()
	validate_editor()

func show_template() -> void:
	editor.text = JSON.stringify({"formatVersion": 2, "id": "my_content_pack", "name": "我的内容包", "version": "1.0.0", "dependencies": [], "items": [{"id": "sample_material", "name": "示例物料", "kind": "solid"}], "recipes": [{"id": "sample_recipe", "name": "示例加工", "buildingId": "assembling_machine_mk1", "duration": 1, "inputs": [{"itemId": "iron_ingot", "amount": 1}], "outputs": [{"itemId": "sample_material", "amount": 1}]}]}, "\t")
	status.text = "模板已生成，可编辑后校验并注册。"

func validate_editor() -> void:
	if editor.text.to_utf8_buffer().size() > 2097152: status.text = "内容超过 2 MB"; return
	var checked := DataManager.content_pack_system.validate_manifest(JSON.parse_string(editor.text))
	status.text = "内容校验通过" if checked.ok else "；".join(checked.errors)

func register_editor() -> void:
	if editor.text.to_utf8_buffer().size() > 2097152: status.text = "内容超过 2 MB"; return
	show_result(GameManager.mutate_content_pack("register", "", JSON.parse_string(editor.text)))

func mutate(action: String) -> void:
	show_result(GameManager.mutate_content_pack(action, selected_id()))

func show_result(result: Dictionary) -> void:
	status.text = String(result.get("message", result.get("error", {}).get("message", "操作失败")))
	refresh()