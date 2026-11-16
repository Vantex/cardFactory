extends Node

var _failures := 0

func _ready() -> void:
	var result: Dictionary = preload("res://scripts/test/ResearchCommandBehaviorRunner.gd").new().run()
	for error in result.errors: _check(false, error)
	await _test_formal_source_controls()
	await _test_formal_teaching_pause()
	if _failures == 0: print("PARITY RESEARCH COMMAND TESTS PASSED")
	else: printerr("PARITY RESEARCH COMMAND TESTS FAILED")
	get_tree().quit(0 if _failures == 0 else 1)

func _test_formal_source_controls() -> void:
	var state := GameState.new()
	SourceGalaxySystem.new(state).initialize(240721)
	state.completed_technologies = ["dsp_electromagnetism", "dsp_energy_matrix", "dsp_structure_matrix"]
	GameManager.replace_game_state(state)
	var main: Node = load("res://scenes/main/Main.tscn").instantiate()
	add_child(main)
	await get_tree().process_frame
	await get_tree().process_frame
	var panel := main.get_node("FactoryWorkspaceUI/TechnologyPanel") as Control
	var toggle := main.get_node("FactoryWorkspaceUI/TopBar/TechnologyButton") as Button
	toggle.pressed.emit()
	await get_tree().process_frame
	var action := _action(panel, "dsp_mining_speed_1")
	_check(action != null and action.text == "研究" and not action.disabled, "formal source row starts research")
	if action != null: action.pressed.emit()
	await get_tree().process_frame
	action = _action(panel, "dsp_mining_speed_2")
	_check(action != null and action.text == "排队", "formal source dependent offers queue intent")
	if action != null: action.pressed.emit()
	await get_tree().process_frame
	var pause := panel.get_node("Layout/CurrentActions/Pause") as Button
	var resume := panel.get_node("Layout/CurrentActions/Resume") as Button
	var cancel := panel.get_node("Layout/CurrentActions/Cancel") as Button
	pause.pressed.emit()
	await get_tree().process_frame
	_check(state.research_current_id.is_empty() and state.research_paused_id == "dsp_mining_speed_1" and state.research_queue == ["dsp_mining_speed_2"], "formal pause frees current ownership and retains waiting queue: current=%s paused=%s queue=%s" % [state.research_current_id, state.research_paused_id, state.research_queue])
	_check(not resume.disabled and cancel.disabled, "formal paused-only controls allow resume and disable current cancellation")
	action = _action(panel, "dsp_basic_logistics")
	_check(action != null and action.text == "研究", "formal source selection remains available alongside a paused project and waiting queue")
	if action != null: action.pressed.emit()
	await get_tree().process_frame
	_check(state.research_current_id == "dsp_basic_logistics" and state.research_paused_id == "dsp_mining_speed_1" and resume.disabled, "formal Main starts a second source technology without losing paused ownership")
	cancel.pressed.emit()
	await get_tree().process_frame
	_check(state.research_current_id.is_empty() and not resume.disabled, "formal cancellation leaves the dependent waiting and permits resuming its parent")
	action = _action(panel, "dsp_mining_speed_1")
	_check(action != null and action.text == "恢复" and not action.disabled, "formal paused row exposes actual resume intent")
	if action != null: action.pressed.emit()
	await get_tree().process_frame
	_check(state.research_current_id == "dsp_mining_speed_1" and state.research_paused_id.is_empty(), "formal paused row restores its authoritative project through Main")
	main.queue_free()
	await get_tree().process_frame

func _test_formal_teaching_pause() -> void:
	var state := GameState.new()
	state.planet_inventory.matrix_science_1 = 15.0
	var research := TechnologySystem.new(state)
	_check(research.start_research("factory_foundations") and research.pause_research(), "actual teaching research pause prepared")
	GameManager.replace_game_state(state)
	var main: Node = load("res://scenes/main/Main.tscn").instantiate()
	add_child(main)
	await get_tree().process_frame
	await get_tree().process_frame
	var panel := main.get_node("FactoryWorkspaceUI/TechnologyPanel") as Control
	var toggle := main.get_node("FactoryWorkspaceUI/TopBar/TechnologyButton") as Button
	toggle.pressed.emit()
	await get_tree().process_frame
	var action := _action(panel, "factory_foundations")
	var resume := panel.get_node("Layout/CurrentActions/Resume") as Button
	_check(action != null and action.disabled and not resume.disabled, "formal teaching current paused row has no ineffective queue action and keeps Resume")
	resume.pressed.emit()
	await get_tree().process_frame
	_check(state.research_current_id == "factory_foundations" and not state.research_paused, "formal teaching Resume preserves its original rules")
	main.queue_free()
	await get_tree().process_frame

func _action(panel: Control, id: String) -> Button:
	var catalog := panel.get_node("Layout/CatalogScroll/Catalog")
	var name := String(DataManager.get_technology(id).name)
	for row in catalog.get_children():
		if row.get_child_count() < 2: continue
		var label := row.get_child(0) as Label
		if label != null and label.text.get_slice("\n", 0).contains(name): return row.get_child(1) as Button
	return null

func _check(ok: bool, label: String) -> void:
	if not ok:
		_failures += 1
		printerr("FAIL: " + label)
