class_name ProductionPlanningPanel
extends ScrollContainer

var _items: OptionButton
var _target: SpinBox
var _scope: OptionButton
var _plans: VBoxContainer
var _feedback: Label
var _refresh_pending := false
var _last_refresh_ms := 0
var _item_catalog_signature := ""

func _ready() -> void:
	var layout := VBoxContainer.new()
	layout.name = "Layout"
	layout.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	set_meta("device_horizontal_scroll_mode", ScrollContainer.SCROLL_MODE_DISABLED)
	add_child(layout)
	var help := Label.new()
	help.text = "分析目标产量、上游缺口、追加设备和功耗。"
	help.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	layout.add_child(help)
	_items = OptionButton.new()
	_items.name = "Item"
	layout.add_child(_items)
	_refresh_item_catalog()
	_target = SpinBox.new()
	_target.name = "Target"
	_target.min_value = 0.01
	_target.max_value = 1000000000
	_target.step = 0.01
	_target.value = 60
	_target.suffix = "/min"
	layout.add_child(_target)
	_scope = OptionButton.new()
	_scope.name = "Scope"
	_scope.tooltip_text = "按行星筛选生产设备；库存统计包含所有行星托盘。"
	_scope.add_item("所有行星")
	_scope.set_item_metadata(0, "all")
	for id in SourceGalaxySystem.catalog().planets:
		_scope.add_item(String(SourceGalaxySystem.catalog().planets[id].name))
		_scope.set_item_metadata(_scope.item_count - 1, id)
	layout.add_child(_scope)
	var create := Button.new()
	create.name = "Create"
	create.text = "创建生产计划"
	create.pressed.connect(_create_plan)
	layout.add_child(create)
	_feedback = Label.new()
	_feedback.name = "Feedback"
	_feedback.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	layout.add_child(_feedback)
	_plans = VBoxContainer.new()
	_plans.name = "Plans"
	layout.add_child(_plans)
	GameManager.game_state_replaced.connect(func(_state): _schedule_refresh())
	EventBus.simulation_updated.connect(func(_a = null, _b = null, _c = null): _schedule_refresh())
	visibility_changed.connect(func():
		if is_visible_in_tree(): _schedule_refresh())
	refresh_now()

func _refresh_item_catalog() -> void:
	var ids := ProductionPlanningSystem.get_supported_items()
	ids.sort()
	var entries := []
	for id in ids: entries.append([id, DataManager.get_item(id).name])
	var signature := JSON.stringify(entries)
	if signature == _item_catalog_signature: return
	_item_catalog_signature = signature
	var selected := String(_items.get_item_metadata(_items.selected)) if _items.selected >= 0 else "iron_ingot"
	_items.clear()
	for entry in entries:
		_items.add_item(String(entry[1]))
		_items.set_item_metadata(_items.item_count - 1, entry[0])
		if entry[0] == "iron_ingot": _items.select(_items.item_count - 1)
	for index in range(_items.item_count):
		if _items.get_item_metadata(index) == selected:
			_items.select(index)
			break

func refresh_now() -> void:
	_refresh_pending = false
	_last_refresh_ms = Time.get_ticks_msec()
	if _plans == null: return
	_refresh_item_catalog()
	var state := GameManager.get_game_state()
	if state == null: return
	var system := ProductionPlanningSystem.new(state)
	var retained := []
	for index in range(state.production_plans.size()):
		var plan: Dictionary = state.production_plans[index]
		var signature := JSON.stringify([state.get_instance_id(), plan.id, plan.itemId, plan.planetId, plan.recipeSelections, state.completed_technologies, DataManager.all_recipes.size(), _item_catalog_signature], "", true)
		var existing: VBoxContainer = null
		for child in _plans.get_children():
			if child.get_meta("plan_signature", "") == signature:
				existing = child
			elif child.get_meta("plan_id", "") == plan.id and child.get_meta("state_instance", 0) == state.get_instance_id():
				var focus := get_viewport().gui_get_focus_owner()
				if focus is LineEdit and child.is_ancestor_of(focus): existing = child
		if existing != null:
			retained.append(existing)
			_plans.move_child(existing, index)
			_update_row(existing, plan, system.calculate(plan))
			continue
		var row := VBoxContainer.new()
		row.name = "Plan_%d" % index
		row.set_meta("plan_signature", signature)
		row.set_meta("plan_id", plan.id)
		row.set_meta("state_instance", state.get_instance_id())
		_plans.add_child(row)
		retained.append(row)
		var name_input := LineEdit.new()
		name_input.name = "Name"
		name_input.text = plan.name
		name_input.max_length = 40
		name_input.text_submitted.connect(func(_text): _commit_name(plan.id, name_input, state.get_instance_id()))
		name_input.focus_exited.connect(func(): _commit_name(plan.id, name_input, state.get_instance_id()))
		row.add_child(name_input)
		var item_choice := OptionButton.new()
		item_choice.name = "Item"
		for i in range(_items.item_count):
			item_choice.add_item(_items.get_item_text(i))
			item_choice.set_item_metadata(i, _items.get_item_metadata(i))
			if _items.get_item_metadata(i) == plan.itemId: item_choice.select(i)
		item_choice.item_selected.connect(func(i): _apply(system.update_plan(plan.id, {"itemId": item_choice.get_item_metadata(i)})))
		row.add_child(item_choice)
		var scope_choice := OptionButton.new()
		scope_choice.name = "Scope"
		scope_choice.tooltip_text = _scope.tooltip_text
		for i in range(_scope.item_count):
			scope_choice.add_item(_scope.get_item_text(i))
			scope_choice.set_item_metadata(i, _scope.get_item_metadata(i))
			if _scope.get_item_metadata(i) == plan.planetId: scope_choice.select(i)
		scope_choice.item_selected.connect(func(i): _apply(system.update_plan(plan.id, {"planetId": scope_choice.get_item_metadata(i)})))
		row.add_child(scope_choice)
		var target := SpinBox.new()
		target.name = "Target"
		target.min_value = 0.01
		target.max_value = 1000000000
		target.step = 0.01
		target.value = plan.targetPerMinute
		target.suffix = "/min"
		target.value_changed.connect(func(value): _apply(system.update_plan(plan.id, {"targetPerMinute": value}), false))
		row.add_child(target)
		var remove := Button.new()
		remove.name = "Delete"
		remove.text = "删除计划"
		remove.pressed.connect(func(): _apply(system.remove_plan(plan.id)))
		row.add_child(remove)
		var result := system.calculate(plan)
		var summary := Label.new()
		summary.name = "Summary"
		summary.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		summary.text = "追加 %d 台 · 功耗 %.2f kW · 物流 %.2f/min\n瓶颈：%s" % [result.additionalMachines, result.totalPowerDemandKw, result.totalLogisticsPerMinute, DataManager.get_item(String(result.limitingItemId)).get("name", "无")]
		row.add_child(summary)
		for requirement in result.requirements:
			var detail := Label.new()
			detail.set_meta("requirement_item", requirement.itemId)
			detail.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			var coverage := "无缺口" if requirement.coverageMinutes == null else "%.2f 分钟" % requirement.coverageMinutes
			detail.text = "%s · 需求 %.2f/min · 现有 %.2f/min · 缺口 %.2f/min\n库存 %.0f · 支撑 %s · 追加 %d 台 %s" % [DataManager.get_item(requirement.itemId).name, requirement.requiredPerMinute, requirement.existingPerMinute, requirement.deficitPerMinute, requirement.inventory, coverage, requirement.additionalMachines, ProductionPlanningSystem.get_building_definition(requirement.buildingId).name]
			row.add_child(detail)
			var options := system.get_recipe_options(requirement.itemId)
			if options.size() < 2: continue
			var choice := OptionButton.new()
			choice.name = "Recipe_" + requirement.itemId
			for id in options:
				choice.add_item(String(ProductionPlanningSystem.get_recipe_definition(id).name))
				choice.set_item_metadata(choice.item_count - 1, id)
				if id == requirement.get("recipeId", ""): choice.select(choice.item_count - 1)
			choice.item_selected.connect(func(selected): _apply(system.set_recipe(plan.id, requirement.itemId, choice.get_item_metadata(selected))))
			row.add_child(choice)
	for child in _plans.get_children():
		if child not in retained:
			_plans.remove_child(child)
			child.queue_free()
	for index in range(retained.size()):
		retained[index].name = "Plan_%d" % index
		_plans.move_child(retained[index], index)

func _commit_name(id: String, input: LineEdit, state_instance: int) -> void:
	var state := GameManager.get_game_state()
	if state == null or state.get_instance_id() != state_instance: return
	for plan in state.production_plans:
		if plan.id == id:
			if input.text != plan.name: _apply(ProductionPlanningSystem.new(state).update_plan(id, {"name": input.text}), false)
			return

func _update_row(row: VBoxContainer, plan: Dictionary, result: Dictionary) -> void:
	var name_input := row.get_node("Name") as LineEdit
	if not name_input.has_focus(): name_input.text = plan.name
	var target := row.get_node("Target") as SpinBox
	if not target.get_line_edit().has_focus(): target.set_value_no_signal(plan.targetPerMinute)
	row.get_node("Summary").text = "追加 %d 台 · 功耗 %.2f kW · 物流 %.2f/min\n瓶颈：%s" % [result.additionalMachines, result.totalPowerDemandKw, result.totalLogisticsPerMinute, DataManager.get_item(String(result.limitingItemId)).get("name", "无")]
	for detail in row.get_children():
		if not detail.has_meta("requirement_item"): continue
		for requirement in result.requirements:
			if requirement.itemId != detail.get_meta("requirement_item"): continue
			var coverage := "无缺口" if requirement.coverageMinutes == null else "%.2f 分钟" % requirement.coverageMinutes
			detail.text = "%s · 需求 %.2f/min · 现有 %.2f/min · 缺口 %.2f/min\n库存 %.0f · 支撑 %s · 追加 %d 台 %s" % [DataManager.get_item(requirement.itemId).name, requirement.requiredPerMinute, requirement.existingPerMinute, requirement.deficitPerMinute, requirement.inventory, coverage, requirement.additionalMachines, ProductionPlanningSystem.get_building_definition(requirement.buildingId).name]

func _create_plan() -> void:
	var state := GameManager.get_game_state()
	if state == null: return
	_apply(ProductionPlanningSystem.new(state).create_plan(_items.get_item_metadata(_items.selected), _target.value, _scope.get_item_metadata(_scope.selected)))

func _apply(result: Dictionary, refresh: bool = true) -> void:
	_feedback.text = String(result.message)
	if refresh: refresh_now()
	else: _schedule_refresh()

func _schedule_refresh() -> void:
	if _refresh_pending or not is_visible_in_tree(): return
	# Existing rows update labels without replacing focused controls or drafts.
	_refresh_pending = true
	var wait_ms := maxi(0, 1000 - (Time.get_ticks_msec() - _last_refresh_ms))
	if wait_ms > 0: get_tree().create_timer(wait_ms / 1000.0).timeout.connect(refresh_now, CONNECT_ONE_SHOT)
	else: call_deferred("refresh_now")
