extends Node

var _failures := 0

func _ready() -> void:
	var result: Dictionary = preload("res://scripts/test/InfiniteResearchBehaviorRunner.gd").new().run()
	for error in result.errors: _check(false, error)
	await _formal_controls()
	print("INFINITE RESEARCH VERIFIED KEYS: ", result.verified_keys.size())
	if _failures == 0: print("PARITY INFINITE RESEARCH TESTS PASSED")
	else: printerr("PARITY INFINITE RESEARCH TESTS FAILED")
	get_tree().quit(0 if _failures == 0 else 1)

func _formal_controls() -> void:
	var fixture := DSPOnlineParity.read_json("res://tests/fixtures/parity/behavior/task27-infinite-research.json")
	var original_saves := GameManager.get_save_system()
	GameManager.configure_save_system(SaveSystem.new("res://.godot/task27-infinite-formal-%d/" % Time.get_ticks_usec()))
	GameManager.set_process(false)
	_check(GameManager.start_new_game(0).ok, "formal clean new game saves before controlled prerequisites")
	var state := GameManager.get_game_state()
	_check(state.progression_facts.get("infinite_auto", false) == fixture.source_initial_automatic, "actual clean new game uses frozen independent automation default")
	state.completed_technologies = fixture.cases[0].input.view.finite.completedTechIds.map(func(id): return "dsp_" + String(id))
	var main: Node = load("res://scenes/main/Main.tscn").instantiate()
	add_child(main)
	await get_tree().process_frame
	await get_tree().process_frame
	var panel := main.get_node("FactoryWorkspaceUI/TechnologyPanel") as TechnologyPanel
	main.get_node("FactoryWorkspaceUI/TopBar/TechnologyButton").pressed.emit()
	panel.get_node("Layout/InfiniteToggle").pressed.emit()
	await get_tree().process_frame
	var automatic := panel.get_node("Layout/InfiniteResearch/Automatic") as CheckBox
	_check(automatic.button_pressed == fixture.source_initial_automatic, "formal checkbox reflects authoritative automation")
	automatic.button_pressed = false
	_check(state.progression_facts.get("infinite_auto", false) == false, "formal checkbox changes automation immediately without selecting a target")
	var target := panel.find_child("Research_matrix_compression", true, false) as Button
	target.pressed.emit()
	await get_tree().process_frame
	var infinite := InfiniteResearchSystem.new(state)
	var pause := panel.get_node("Layout/CurrentActions/Pause") as Button
	var cancel := panel.get_node("Layout/CurrentActions/Cancel") as Button
	var resume := panel.get_node("Layout/CurrentActions/Resume") as Button
	_check(infinite.active() == "matrix_compression" and not pause.disabled and not cancel.disabled, "formal infinite selection enables global pause and cancel")
	_check(panel.get_node("Layout/Current").text.contains("矩阵压缩"), "formal current header shows the authoritative infinite target")
	_check(target.disabled, "formal current infinite row prevents redundant selection")
	pause.pressed.emit()
	await get_tree().process_frame
	_check(infinite.active().is_empty() and not state.progression_facts.get("infinite_auto", true), "formal global pause clears infinite selection and preserves automation")
	panel.call("navigate_to", "dsp_basic_logistics")
	await get_tree().process_frame
	var finite_row := panel.get_node("Layout/CatalogScroll/Catalog").get_child(0)
	(finite_row.get_child(1) as Button).pressed.emit()
	await get_tree().process_frame
	pause.pressed.emit()
	await get_tree().process_frame
	target.pressed.emit()
	await get_tree().process_frame
	_check(state.research_paused_id == "dsp_basic_logistics" and infinite.active() == "matrix_compression" and resume.disabled, "formal independent paused project retained while infinite target is active")
	cancel.pressed.emit()
	await get_tree().process_frame
	_check(infinite.active().is_empty() and not resume.disabled, "formal infinite cancellation allows finite resume")
	resume.pressed.emit()
	await get_tree().process_frame
	_check(state.research_current_id == "dsp_basic_logistics" and state.research_paused_id.is_empty(), "formal Main resumes the retained finite project")
	main.queue_free()
	await get_tree().process_frame
	GameManager.end_session()
	GameManager.configure_save_system(original_saves)
	GameManager.set_process(true)

func _check(ok: bool, label: String) -> void:
	if not ok:
		_failures += 1
		printerr("FAIL: " + label)
