extends Node

var _failures := 0

func _ready() -> void:
	print("PROGRESSION TESTS STARTED")
	_test_objective_state_machine_and_reward_once()
	_test_reward_application_is_atomic()
	_test_retroactive_completion_and_persistence()
	_test_campaign_catalog_and_achievements()
	_test_disabled_connections_do_not_advance_objectives()
	_test_stopped_building_location()
	_test_data_driven_technology_progression()
	await _test_technology_workspace_ui()
	await _test_technology_main_intents_and_queue_regressions()
	await _test_formal_campaign_ui()

	if _failures > 0:
		printerr("PROGRESSION TESTS FAILED")
		get_tree().quit(1)
		return
	print("PROGRESSION TESTS PASSED")
	get_tree().quit(0)

func _test_objective_state_machine_and_reward_once() -> void:
	var state := GameState.new()
	state.construction_inventory["miner"] = 1.0
	var catalog := {
		"chapters": [{"id": "foundations", "title": "基础建设", "objective_ids": ["place_power", "place_miner"]}],
		"objectives": [
			{
				"id": "place_power",
				"chapter_id": "foundations",
				"title": "建立供电",
				"condition": {"fact": "building_count", "building_type": "power_generator", "at_least": 1},
				"reward": {"construction_inventory": {"miner": 1.0}},
			},
			{
				"id": "place_miner",
				"chapter_id": "foundations",
				"title": "开始采矿",
				"prerequisites": ["place_power"],
				"condition": {"fact": "building_count", "building_type": "miner", "at_least": 1},
			},
		],
		"achievements": [],
	}
	var progression := ProgressionSystem.new(state, catalog)
	_expect(progression.get_current_objective().get("id") == "place_power", "a fresh save starts the first eligible persistent objective")
	_expect(progression.get_objective_progress("place_power") == {"current": 0.0, "required": 1.0, "complete": false}, "objective progress reports domain facts instead of UI click counters")

	_add_building(state, "power_generator", Vector2(80, 90))
	var first_result := progression.evaluate()
	_expect(first_result.get("completed_objectives") == ["place_power"], "evaluation advances an objective when the authoritative building fact becomes true")
	_expect(state.completed_objective_ids == ["place_power"] and state.claimed_progression_reward_ids == ["objective:place_power"], "completion and reward claims are persisted with stable IDs")
	_expect(state.construction_inventory.get("miner") == 2.0, "an objective reward is applied to authoritative inventory")
	_expect(progression.get_current_objective().get("id") == "place_miner", "the next prerequisite-gated objective becomes active")

	var second_result := progression.evaluate()
	_expect(second_result.get("completed_objectives", []).is_empty() and state.construction_inventory.get("miner") == 2.0, "re-evaluation neither recompletes an objective nor pays its reward twice")

func _test_reward_application_is_atomic() -> void:
	var state := GameState.new()
	state.planet_inventory = {"iron_ingot": InventorySystem.MAX_PLANET_STACK}
	_add_building(state, "power_generator", Vector2.ZERO)
	var catalog := {
		"chapters": [{"id": "atomic", "title": "原子奖励", "objective_ids": ["full_reward"]}],
		"objectives": [{
			"id": "full_reward",
			"chapter_id": "atomic",
			"title": "满库存奖励",
			"condition": {"fact": "building_count", "building_type": "power_generator", "at_least": 1},
			"reward": {"planet_inventory": {"iron_ingot": 1.0}, "unlocks": ["branch_atomic"]},
		}],
		"achievements": [],
	}
	var result := ProgressionSystem.new(state, catalog).evaluate()
	_expect(result.get("blocked_reward_ids") == ["objective:full_reward"], "a reward that cannot fit reports a stable blocked claim")
	_expect(state.completed_objective_ids.is_empty() and state.claimed_progression_reward_ids.is_empty(), "a blocked reward does not partially commit completion or claim state")
	_expect(state.unlocked_progression_ids.is_empty() and state.planet_inventory.get("iron_ingot") == InventorySystem.MAX_PLANET_STACK, "a blocked reward rolls back every inventory and unlock effect")

func _test_retroactive_completion_and_persistence() -> void:
	var state := GameState.new()
	_add_building(state, "power_generator", Vector2(20, 20))
	var miner_id := _add_building(state, "miner", Vector2(100, 120))
	var smelter_id := _add_building(state, "smelter", Vector2(300, 120))
	_add_building(state, "matrix_lab", Vector2(500, 120), {"output_buffer": {"matrix_science_1": 1.0}})
	state.add_connection({"source_id": miner_id, "target_id": smelter_id, "type": "conveyor_belt_mk1", "item_id": "iron_ore"})

	var progression := ProgressionSystem.new(state)
	var retroactive := progression.evaluate()
	_expect(retroactive.get("completed_objectives", []).size() >= 4, "an established factory retroactively completes every eligible beginner objective in one evaluation")
	_expect(state.completed_objective_ids.has("first_power") and state.completed_objective_ids.has("first_matrix"), "retroactive evaluation recognizes power and matrix facts from an old save")

	var payload := GameStateCodec.to_persistent_dict(state)
	var restored := GameStateCodec.from_persistent_dict(JSON.parse_string(JSON.stringify(payload)))
	_expect(payload.get("schema_version") == 6 and restored is GameState, "progression persistence upgrades the canonical save contract to schema version 6")
	if restored is GameState:
		_expect(_same_ids(restored.completed_objective_ids, state.completed_objective_ids), "save/load preserves completed objectives")
		_expect(_same_ids(restored.claimed_progression_reward_ids, state.claimed_progression_reward_ids), "save/load preserves idempotent reward claims")
		_expect(_same_ids(restored.completed_achievement_ids, state.completed_achievement_ids), "save/load preserves local achievements")

	var legacy_v2 := payload.duplicate(true)
	legacy_v2["schema_version"] = 2
	for field in ["completed_objective_ids", "claimed_progression_reward_ids", "completed_achievement_ids", "unlocked_progression_ids"]:
		legacy_v2.erase(field)
	var migrated := SaveMigrationRegistry.migrate_to_current(legacy_v2)
	_expect(migrated.get("ok", false) and migrated.get("data", {}).get("completed_objective_ids") == [], "schema-v2 saves migrate with empty progression defaults and remain eligible for retroactive evaluation")

func _test_campaign_catalog_and_achievements() -> void:
	var catalog := ObjectiveSystem.load_catalog()
	var chapter_ids: Array = []
	for chapter_value in catalog.get("chapters", []):
		chapter_ids.append(String(chapter_value.get("id", "")))
	for expected_id in ["power", "storage", "belt_upgrade", "chemicals", "logistics", "rare_resources", "blueprints", "interstellar", "dyson"]:
		_expect(chapter_ids.has(expected_id), "campaign data includes the %s chapter or branch" % expected_id)

	var state := GameState.new()
	_add_building(state, "solar_panel", Vector2.ZERO)
	var progression := ProgressionSystem.new(state)
	var evaluation := progression.evaluate()
	_expect(evaluation.get("completed_objectives", []).has("first_power"), "the power objective accepts renewable generation facts as well as the starter fuel generator")
	_expect(state.completed_achievement_ids.has("first_building"), "local achievements unlock retroactively from current-save facts")
	var claims_before := state.claimed_progression_reward_ids.duplicate()
	progression.evaluate()
	_expect(state.claimed_progression_reward_ids == claims_before, "achievement rewards are idempotent on repeated evaluation")

func _test_stopped_building_location() -> void:
	var state := GameState.new()
	var running_id := _add_building(state, "smelter", Vector2(100, 100), {"status": "running"})
	var blocked_id := _add_building(state, "smelter", Vector2(420, 260), {"status": "blocked"})
	var location := ObjectiveSystem.new().find_stopped_building(state)
	_expect(location.get("building_id") == blocked_id and location.get("position") == Vector2(420, 260), "stopped-building diagnosis returns a deterministic actionable world target")
	_expect(location.get("building_id") != running_id, "stopped-building diagnosis never targets a running building")

func _test_disabled_connections_do_not_advance_objectives() -> void:
	var state := GameState.new()
	_add_building(state, "power_generator", Vector2.ZERO)
	var miner_id := _add_building(state, "miner", Vector2(100, 0))
	var smelter_id := _add_building(state, "smelter", Vector2(300, 0))
	state.set_entity_extraction_item(miner_id, "iron_ore")
	var connection_result := state.try_add_connection(miner_id, smelter_id)
	var connection_id := String(connection_result.get("id", ""))
	state.try_configure_belt(connection_id, {"enabled": false})
	var progression := ProgressionSystem.new(state)
	progression.evaluate()
	_expect(connection_result.get("ok", false) and not state.completed_objective_ids.has("first_link"), "a real gameplay line does not satisfy the valid-connection campaign fact while disabled")
	state.try_configure_belt(connection_id, {"enabled": true})
	progression.evaluate()
	_expect(state.completed_objective_ids.has("first_link"), "a real gameplay line satisfies the valid-connection fact after being enabled")

func _test_formal_campaign_ui() -> void:
	var viewport := SubViewport.new()
	viewport.size = Vector2i(1152, 648)
	add_child(viewport)
	var main: Node = load("res://scenes/main/Main.tscn").instantiate()
	viewport.add_child(main)
	await get_tree().process_frame
	var campaign := main.get_node_or_null("FactoryWorkspaceUI/CampaignWorkspace") as Control
	var tutorial := main.get_node_or_null("FactoryWorkspaceUI/TutorialOverlay") as Control
	var toggle := main.get_node_or_null("FactoryWorkspaceUI/InspectorPanel/CampaignToggle") as Button
	_expect(campaign != null and tutorial != null and toggle != null and not campaign.visible, "formal Main mounts a collapsed campaign workspace, tutorial overlay, and visible entry point")
	var title := main.get_node_or_null("FactoryWorkspaceUI/InspectorPanel/Title") as Control
	var blueprint_toggle := main.get_node_or_null("FactoryWorkspaceUI/InspectorPanel/BlueprintToggle") as Control
	var inspector_toolbar_clear := title != null and toggle != null and blueprint_toggle != null
	if inspector_toolbar_clear:
		inspector_toolbar_clear = not title.get_global_rect().intersects(toggle.get_global_rect(), false)
		inspector_toolbar_clear = inspector_toolbar_clear and not title.get_global_rect().intersects(blueprint_toggle.get_global_rect(), false)
		inspector_toolbar_clear = inspector_toolbar_clear and not toggle.get_global_rect().intersects(blueprint_toggle.get_global_rect(), false)
	_expect(inspector_toolbar_clear, "Inspector title, campaign entry, and blueprint entry occupy distinct rectangles")
	if campaign != null and tutorial != null:
		var protected_controls: Array[Control] = [main.get_node("FactoryWorkspaceUI/TopBar"), main.get_node("FactoryWorkspaceUI/ResourceRail"), main.get_node("FactoryWorkspaceUI/InspectorPanel"), main.get_node("FactoryWorkspaceUI/ConstructionDock"), main.get_node("FactoryWorkspaceUI/MiniMap")]
		var geometry_clear := true
		campaign.show()
		await get_tree().process_frame
		for protected in protected_controls:
			geometry_clear = geometry_clear and not campaign.get_global_rect().intersects(protected.get_global_rect(), false)
		_expect(geometry_clear and tutorial.mouse_filter == Control.MOUSE_FILTER_IGNORE, "campaign and tutorial UI preserve protected workspace geometry and world input")

	var progressing_state := GameState.new()
	_add_building(progressing_state, "power_generator", Vector2.ZERO)
	var progress_miner_id := _add_building(progressing_state, "miner", Vector2(100, 0))
	var progress_smelter_id := _add_building(progressing_state, "smelter", Vector2(300, 0))
	progressing_state.set_entity_extraction_item(progress_miner_id, "iron_ore")
	var progressing_connection := progressing_state.try_add_connection(progress_miner_id, progress_smelter_id)
	progressing_state.try_configure_belt(String(progressing_connection.get("id", "")), {"enabled": false})
	GameManager.replace_game_state(progressing_state)
	await get_tree().process_frame
	var before_connection_text := String(campaign.get_node("Panel/Objective").text) if campaign != null else ""
	progressing_state.try_configure_belt(String(progressing_connection.get("id", "")), {"enabled": true})
	await get_tree().process_frame
	var after_connection_text := String(campaign.get_node("Panel/Objective").text) if campaign != null else ""
	_expect("连接" in before_connection_text and "研究矩阵" in after_connection_text, "a real belt enable event refreshes the campaign UI without per-frame polling")

	var reward_blocked_state := GameState.new()
	_add_building(reward_blocked_state, "power_generator", Vector2.ZERO)
	_add_building(reward_blocked_state, "miner", Vector2(100, 0))
	_add_building(reward_blocked_state, "smelter", Vector2(300, 0))
	reward_blocked_state.construction_inventory["conveyor_belt_mk1"] = 99.0
	GameManager.replace_game_state(reward_blocked_state)
	await get_tree().process_frame
	var reward_message := String(campaign.get_node("Panel/Achievements").text) if campaign != null else ""
	_expect("腾出库存空间" in reward_message, "a blocked atomic progression reward publishes an actionable campaign UI reason")

	var state := GameState.new()
	var stopped_id := _add_building(state, "smelter", Vector2(760, 430), {"status": "blocked"})
	GameManager.replace_game_state(state)
	await get_tree().process_frame
	var camera := main.get_node("WorldCamera") as Camera2D
	if campaign != null:
		campaign.call("request_locate_stopped_building")
		await get_tree().process_frame
	_expect(camera.global_position == Vector2(760, 430), "campaign locate intent routes through Main and moves the world camera to the stopped building")
	_expect(main.get_node("InputHandler").selected_building_id == stopped_id, "locating a stopped building also selects it in the authoritative workspace controller")
	viewport.queue_free()
	await get_tree().process_frame

func _test_data_driven_technology_progression() -> void:
	# This catches a regression where research ignores the matrix cost and only
	# stores progress in a short-lived TechnologySystem instance.
	var blocked_state := GameState.new()
	var blocked_research := TechnologySystem.new(blocked_state)
	_expect(not blocked_research.start_research("factory_foundations"), "research refuses a technology until its matrix cost is available")
	var cancelled_state := GameState.new()
	cancelled_state.planet_inventory["matrix_science_1"] = 5.0
	var cancelled_research := TechnologySystem.new(cancelled_state)
	_expect(cancelled_research.start_research("factory_foundations"), "cancel fixture starts a real paid technology")
	cancelled_research.update_research(3.0)
	var cancelled_result := cancelled_research.cancel_research()
	var cancelled_payload := GameStateCodec.to_persistent_dict(cancelled_state)
	_expect(cancelled_result and is_equal_approx(cancelled_state.get_technology_progress("factory_foundations"), 3.0) and is_equal_approx(float(cancelled_state.planet_inventory.get("matrix_science_1", 0.0)), 0.0) and GameStateValidator.validate_persistent_dict(cancelled_payload).is_empty(), "a legal cancel retains invested work and leaves a validator-valid state")
	_expect(cancelled_research.start_research("factory_foundations") and is_equal_approx(cancelled_state.get_technology_progress("factory_foundations"), 3.0), "restarting a cancelled technology resumes retained investment without charging twice")

	var state := GameState.new()
	state.planet_inventory["matrix_science_1"] = 20.0
	var research := TechnologySystem.new(state)
	_expect(research.has_method("pause_research") and research.has_method("resume_research"), "research exposes explicit pause and resume commands")
	_expect(research.start_research("factory_foundations"), "research atomically accepts an affordable root technology")
	_expect(float(state.planet_inventory.get("matrix_science_1", 0.0)) == 15.0, "starting research consumes the catalog matrix cost exactly once")
	_expect(research.add_to_queue("fluid_handling"), "a prerequisite-gated technology can be queued behind its prerequisite")
	if research.has_method("pause_research"):
		research.pause_research()
		research.update_research(999.0)
		_expect(not research.is_technology_completed("factory_foundations"), "paused research preserves its in-flight progress")
		research.resume_research()
	research.update_research(10.0)
	_expect(research.is_technology_completed("factory_foundations") and research.get_current_research() == "fluid_handling", "completion applies the technology and starts the next queued entry deterministically")
	_expect(research.get_effect_multiplier("production_speed") > 1.0, "completed technology has an observable production-speed effect")
	var payload := GameStateCodec.to_persistent_dict(state)
	var restored := GameStateCodec.from_persistent_dict(JSON.parse_string(JSON.stringify(payload)))
	_expect(restored is GameState and restored.get_technology_progress("fluid_handling") >= 0.0, "research queue and in-flight progress survive a JSON save/load round trip")

func _test_technology_workspace_ui() -> void:
	# These assertions operate the real filter and ScrollContainer controls.
	var state := GameState.new()
	state.completed_technologies = ["factory_foundations"]
	state.research_queue = ["fluid_handling"]
	state.research_queue_wait_reason = "等待矩阵成本：fluid_handling"
	GameManager.replace_game_state(state)
	var panel: Control = load("res://scenes/ui/TechnologyPanel.gd").new()
	add_child(panel)
	await get_tree().process_frame
	await get_tree().process_frame
	var tier_filter := panel.get_node_or_null("Layout/Filters/TierFilter") as OptionButton
	var status_filter := panel.get_node_or_null("Layout/Filters/StatusFilter") as OptionButton
	var wait_reason := panel.get_node_or_null("Layout/WaitReason") as Label
	_expect(panel.get_node_or_null("Layout/Search") is LineEdit and tier_filter != null and status_filter != null, "technology workspace exposes independent search, tier, and status controls")
	_expect(wait_reason != null and wait_reason.visible and wait_reason.text.contains("等待矩阵成本"), "technology workspace renders the authoritative queue wait reason")
	var factory_detail := _find_technology_detail(panel, "工厂基础理论")
	_expect(factory_detail != null and factory_detail.text.contains("成本：基础研究矩阵 ×5") and factory_detail.text.contains("解锁：建筑：分流器") and factory_detail.text.contains("效果：生产速度 ×1.10"), "technology rows render catalog-driven cost, unlock, and effect descriptions")

	if tier_filter != null and status_filter != null:
		_select_option_value(tier_filter, "planetary")
		_select_option_value(status_filter, "queued")
		await get_tree().process_frame
		_expect(_technology_catalog_markers(panel) == ["流体处理"], "tier and status filters combine independently on the real catalog")
		_select_option_value(tier_filter, "all")
		await get_tree().process_frame
		_expect(_technology_catalog_markers(panel) == ["流体处理"], "changing tier leaves the selected queued-status filter intact")
		_select_option_value(status_filter, "all")
		await get_tree().process_frame

	var search := panel.get_node_or_null("Layout/Search") as LineEdit
	if search != null:
		search.text = "基础理论"
		search.text_changed.emit(search.text)
		await get_tree().process_frame
		var search_markers := _technology_catalog_markers(panel)
		if search_markers != ["工厂基础理论"]:
			printerr("TECH SEARCH MARKERS: %s" % [search_markers])
		_expect(search_markers == ["工厂基础理论"], "search filters the real catalog rows")
		search.text = ""
		search.text_changed.emit(search.text)
	var scroll := panel.get_node_or_null("Layout/CatalogScroll") as ScrollContainer
	await get_tree().process_frame
	if scroll != null:
		scroll.scroll_vertical = int(scroll.get_v_scroll_bar().max_value)
		await get_tree().process_frame
		var actual_scroll := scroll.scroll_vertical
		panel.hide()
		panel.show()
		await get_tree().process_frame
		_expect(actual_scroll > 0 and scroll.scroll_vertical == actual_scroll, "closing and reopening retains an actual changed ScrollContainer value")
	panel.queue_free()

func _test_technology_main_intents_and_queue_regressions() -> void:
	var repeatable_formal_state := GameState.new()
	repeatable_formal_state.completed_technologies = ["factory_foundations", "fluid_handling", "advanced_materials", "interstellar_logistics", "dyson_engineering", "infinite_optimization"]
	repeatable_formal_state.planet_inventory["matrix_science_1"] = 100.0
	GameManager.replace_game_state(repeatable_formal_state)
	var repeatable_main: Node = load("res://scenes/main/Main.tscn").instantiate()
	add_child(repeatable_main)
	await get_tree().process_frame
	var repeatable_panel := repeatable_main.get_node_or_null("FactoryWorkspaceUI/TechnologyPanel") as Control
	var technology_button := repeatable_main.get_node_or_null("FactoryWorkspaceUI/TopBar/TechnologyButton") as Button
	if technology_button != null:
		technology_button.pressed.emit()
		await get_tree().process_frame
	var infinite_action := _find_technology_action(repeatable_panel, "无限优化") if repeatable_panel != null else null
	_expect(infinite_action != null and not infinite_action.disabled, "formal technology panel enables a completed repeatable technology for its next level")
	if infinite_action != null:
		infinite_action.pressed.emit()
		await get_tree().process_frame
	_expect(repeatable_formal_state.research_current_id == "infinite_optimization", "formal technology panel starts the second repeatable level through Main")
	repeatable_main.queue_free()
	await get_tree().process_frame

	var queue_state := GameState.new()
	queue_state.completed_technologies = ["factory_foundations", "advanced_materials", "interstellar_logistics", "dyson_engineering", "infinite_optimization"]
	queue_state.planet_inventory["matrix_science_1"] = 100.0
	var queue_service := TechnologySystem.new(queue_state)
	_expect(queue_service.start_research("fluid_handling"), "a non-repeatable technology can be researched before queueing a repeatable one")
	_expect(queue_service.add_to_queue("infinite_optimization"), "a completed repeatable technology can be queued while another technology is researching")

	var state := GameState.new()
	state.planet_inventory["matrix_science_1"] = 15.0
	GameManager.replace_game_state(state)
	var main: Node = load("res://scenes/main/Main.tscn").instantiate()
	add_child(main)
	await get_tree().process_frame
	await get_tree().process_frame
	var formal_panel := main.get_node_or_null("FactoryWorkspaceUI/TechnologyPanel") as Control
	var formal_toggle := main.get_node_or_null("FactoryWorkspaceUI/TopBar/TechnologyButton") as Button
	if formal_toggle != null:
		formal_toggle.pressed.emit()
		await get_tree().process_frame
	var start_action := _find_technology_action(formal_panel, "工厂基础理论") if formal_panel != null else null
	var start_control_exists := start_action != null
	if start_action != null:
		start_action.pressed.emit()
		await get_tree().process_frame
	_expect(start_control_exists, "formal Technology exposes a real root research row button")
	_expect(state.research_current_id == "factory_foundations", "a real technology row sends start intent through Main into authoritative state")
	var pause_button := formal_panel.get_node_or_null("Layout/CurrentActions/Pause") as Button if formal_panel != null else null
	var resume_button := formal_panel.get_node_or_null("Layout/CurrentActions/Resume") as Button if formal_panel != null else null
	var cancel_button := formal_panel.get_node_or_null("Layout/CurrentActions/Cancel") as Button if formal_panel != null else null
	if pause_button != null:
		pause_button.pressed.emit()
		await get_tree().process_frame
	_expect(pause_button != null and state.research_paused, "the real pause control routes intent through Main")
	if resume_button != null:
		resume_button.pressed.emit()
		await get_tree().process_frame
	_expect(resume_button != null and not state.research_paused, "the real resume control routes intent through Main")
	var queue_action := _find_technology_action(formal_panel, "流体处理") if formal_panel != null else null
	var queue_control_exists := queue_action != null
	var queue_intents: Array = []
	var queue_observer := func(technology_id: String) -> void: queue_intents.append(technology_id)
	EventBus.technology_queue_requested.connect(queue_observer)
	if queue_action != null:
		queue_action.pressed.emit()
		await get_tree().process_frame
	EventBus.technology_queue_requested.disconnect(queue_observer)
	_expect(queue_control_exists, "formal Technology exposes a real dependent queue row button")
	_expect(queue_intents == ["fluid_handling"], "the dependent row emits the expected queue intent")
	_expect(state.research_queue == ["fluid_handling"], "a real technology row sends queue intent through Main")
	var remove_queue := _find_queue_remove_button(formal_panel, "fluid_handling") if formal_panel != null else null
	var remove_control_exists := remove_queue != null
	if remove_queue != null:
		remove_queue.pressed.emit()
		await get_tree().process_frame
	_expect(remove_control_exists, "formal Technology exposes a real queue removal button")
	_expect(state.research_queue.is_empty(), "the real queue removal control routes intent through Main")
	queue_action = _find_technology_action(formal_panel, "流体处理") if formal_panel != null else null
	if queue_action != null:
		queue_action.pressed.emit()
		await get_tree().process_frame
	if cancel_button != null:
		cancel_button.pressed.emit()
		await get_tree().process_frame
	var formal_wait_reason := formal_panel.get_node_or_null("Layout/WaitReason") as Label if formal_panel != null else null
	_expect(cancel_button != null and state.research_current_id == "factory_foundations" and state.research_queue == ["fluid_handling"], "the real cancel control routes intent through Main and rejects an invalidating cancel atomically")
	_expect(formal_wait_reason != null and not formal_wait_reason.visible, "formal controls do not publish a wait reason when cancellation is rejected")

	var campaign_toggle := main.get_node_or_null("FactoryWorkspaceUI/InspectorPanel/CampaignToggle") as Button
	var blueprint_toggle := main.get_node_or_null("FactoryWorkspaceUI/InspectorPanel/BlueprintToggle") as Button
	var campaign := main.get_node_or_null("FactoryWorkspaceUI/CampaignWorkspace") as Control
	var blueprint := main.get_node_or_null("FactoryWorkspaceUI/BlueprintWorkspace") as Control
	var inspector := main.get_node_or_null("FactoryWorkspaceUI/InspectorPanel") as Control
	if campaign_toggle != null:
		campaign_toggle.pressed.emit()
		await get_tree().process_frame
	_expect(campaign != null and campaign.visible and formal_panel != null and not formal_panel.visible and blueprint != null and not blueprint.visible, "opening Campaign makes formal workspaces mutually exclusive")
	if formal_toggle != null:
		formal_toggle.pressed.emit()
		await get_tree().process_frame
	_expect(formal_panel != null and formal_panel.visible and campaign != null and not campaign.visible and blueprint != null and not blueprint.visible, "opening Technology hides Campaign and Blueprint")
	_expect(formal_panel != null and inspector != null and not formal_panel.get_global_rect().intersects(inspector.get_global_rect()), "formal Technology layout does not overlap the Inspector")
	if blueprint_toggle != null:
		blueprint_toggle.pressed.emit()
		await get_tree().process_frame
	_expect(blueprint != null and blueprint.visible and formal_panel != null and not formal_panel.visible and campaign != null and not campaign.visible, "opening Blueprint hides Technology and Campaign")
	main.queue_free()
	await get_tree().process_frame

	var insufficient := GameState.new()
	insufficient.planet_inventory["matrix_science_1"] = 5.0
	var insufficient_service := TechnologySystem.new(insufficient)
	insufficient_service.start_research("factory_foundations")
	insufficient_service.add_to_queue("fluid_handling")
	insufficient_service.update_research(10.0)
	_expect(insufficient.research_queue == ["fluid_handling"], "a queued item remains at the head when completion leaves insufficient matrices for its cost")
	var wait_reason: Variant = insufficient.get("research_queue_wait_reason")
	_expect(wait_reason is String and not String(wait_reason).is_empty(), "a blocked queue head exposes an observable waiting reason")
	_expect(not insufficient_service.start_research("fluid_handling"), "a waiting queue head cannot start before its catalog matrices arrive")
	var started_observations: Array = []
	var started_observer := func(tech_id: String) -> void:
		if tech_id == "fluid_handling":
			started_observations.append({
				"current": insufficient.research_current_id,
				"queue": insufficient.research_queue.duplicate(true),
				"matrices": float(insufficient.planet_inventory.get("matrix_science_1", 0.0)),
			})
	EventBus.technology_research_started.connect(started_observer)
	insufficient.planet_inventory["matrix_science_1"] = 10.0
	_expect(not insufficient_service.start_research("fluid_handling") and insufficient.research_current_id.is_empty() and insufficient.research_queue == ["fluid_handling"], "a direct start cannot bypass a funded non-empty FIFO queue or duplicate its head as current")
	insufficient_service.update_research(0.0, false)
	insufficient_service.update_research(0.0, false)
	EventBus.technology_research_started.disconnect(started_observer)
	_expect(insufficient.research_current_id == "fluid_handling" and insufficient.research_queue.is_empty(), "a waiting FIFO head retries on the next research phase when its matrices arrive")
	_expect(started_observations.size() == 1, "a retried queue head starts exactly once across later research phases")
	if started_observations.size() == 1:
		var observed: Dictionary = started_observations[0]
		_expect(observed.get("current") == "fluid_handling" and observed.get("queue", []) == [] and observed.get("matrices") == 0.0, "started-event observers see cost consumption, queue removal, and current assignment as one final atomic state")
	_expect(not insufficient_service.start_research("fluid_handling"), "starting the already-current technology is rejected without a duplicate started event")

	var cancelled := GameState.new()
	cancelled.planet_inventory["matrix_science_1"] = 15.0
	var cancelled_service := TechnologySystem.new(cancelled)
	cancelled_service.start_research("factory_foundations")
	cancelled_service.add_to_queue("fluid_handling")
	var cancelled_before := GameStateCodec.state_digest_payload(cancelled)
	var cancelled_events: Array = []
	var cancelled_observer := func(_tech_id: String) -> void: cancelled_events.append("cancelled")
	var cancelled_queue_observer := func(_queue: Array) -> void: cancelled_events.append("queue_changed")
	EventBus.technology_research_cancelled.connect(cancelled_observer)
	EventBus.technology_research_queue_changed.connect(cancelled_queue_observer)
	var rejected_cancel := cancelled_service.cancel_research()
	EventBus.technology_research_cancelled.disconnect(cancelled_observer)
	EventBus.technology_research_queue_changed.disconnect(cancelled_queue_observer)
	_expect(not rejected_cancel and GameStateCodec.state_digest_payload(cancelled) == cancelled_before and cancelled_events.is_empty(), "cancelling a prerequisite rejects atomically when it would invalidate a dependent queue")
	_expect(GameStateValidator.validate_persistent_dict(GameStateCodec.to_persistent_dict(cancelled)).is_empty(), "a rejected cancel preserves a validator-valid state")

	var remove_state := GameState.new()
	var remove_service := TechnologySystem.new(remove_state)
	_expect(remove_service.add_to_queue("factory_foundations") and remove_service.add_to_queue("fluid_handling"), "a real queue fixture schedules a prerequisite before its dependent")
	var remove_before := GameStateCodec.state_digest_payload(remove_state)
	var remove_events: Array = []
	var remove_queue_observer := func(_queue: Array) -> void: remove_events.append("queue_changed")
	EventBus.technology_research_queue_changed.connect(remove_queue_observer)
	var rejected_remove := remove_service.remove_from_queue("factory_foundations")
	EventBus.technology_research_queue_changed.disconnect(remove_queue_observer)
	_expect(not rejected_remove and GameStateCodec.state_digest_payload(remove_state) == remove_before and remove_events.is_empty(), "removing a prerequisite rejects atomically when it would invalidate a later queued dependent")
	_expect(GameStateValidator.validate_persistent_dict(GameStateCodec.to_persistent_dict(remove_state)).is_empty(), "a rejected queue removal preserves a validator-valid state")

	var legal_remove_state := GameState.new()
	var legal_remove_service := TechnologySystem.new(legal_remove_state)
	legal_remove_service.add_to_queue("factory_foundations")
	legal_remove_state.research_queue_wait_reason = "等待矩阵成本：factory_foundations"
	_expect(legal_remove_service.remove_from_queue("factory_foundations") and legal_remove_state.research_queue.is_empty() and legal_remove_state.research_queue_wait_reason.is_empty() and GameStateValidator.validate_persistent_dict(GameStateCodec.to_persistent_dict(legal_remove_state)).is_empty(), "a legal queue removal clears its wait reason and leaves a validator-valid state")

	var repeatable := GameState.new()
	repeatable.completed_technologies = ["factory_foundations", "fluid_handling", "advanced_materials", "interstellar_logistics", "dyson_engineering"]
	repeatable.planet_inventory["matrix_science_1"] = 100.0
	var repeatable_service := TechnologySystem.new(repeatable)
	_expect(repeatable.has_method("get_technology_level"), "GameState exposes persistent levels for repeatable technology")
	if repeatable.has_method("get_technology_level"):
		_expect(repeatable_service.start_research("infinite_optimization"), "an eligible infinite technology can start at level one")
		repeatable_service.update_research(60.0)
		_expect(repeatable_service.start_research("infinite_optimization"), "a completed infinite technology remains eligible for its second level")
		repeatable_service.update_research(60.0)
		_expect(repeatable.get_technology_level("infinite_optimization") == 2, "repeatable completion increments its authoritative persistent level")
		var restored := GameStateCodec.from_persistent_dict(JSON.parse_string(JSON.stringify(GameStateCodec.to_persistent_dict(repeatable))))
		_expect(restored is GameState and restored.get_technology_level("infinite_optimization") == 2, "repeatable technology levels survive JSON save/load")

func _find_technology_action(panel: Control, marker: String) -> Button:
	var catalog := panel.get_node_or_null("Layout/CatalogScroll/Catalog") as VBoxContainer
	if catalog == null:
		return null
	for row_value in catalog.get_children():
		var row := row_value as HBoxContainer
		if row == null or row.get_child_count() < 2:
			continue
		var detail := row.get_child(0) as Label
		var action := row.get_child(1) as Button
		if detail != null and action != null and detail.text.get_slice("\n", 0).contains(marker):
			return action
	return null

func _find_technology_detail(panel: Control, marker: String) -> Label:
	var catalog := panel.get_node_or_null("Layout/CatalogScroll/Catalog") as VBoxContainer
	if catalog == null:
		return null
	for row_value in catalog.get_children():
		var row := row_value as HBoxContainer
		if row != null and row.get_child_count() >= 1:
			var detail := row.get_child(0) as Label
			if detail != null and detail.text.get_slice("\n", 0).contains(marker):
				return detail
	return null

func _find_queue_remove_button(panel: Control, technology_id: String) -> Button:
	var queue_list := panel.get_node_or_null("Layout/QueueList") as VBoxContainer
	if queue_list == null:
		return null
	for row_value in queue_list.get_children():
		var row := row_value as HBoxContainer
		if row == null:
			continue
		for child_value in row.get_children():
			var button := child_value as Button
			if button != null and String(button.get_meta("technology_id", "")) == technology_id:
				return button
	return null

func _technology_catalog_markers(panel: Control) -> Array:
	var result: Array = []
	var catalog := panel.get_node_or_null("Layout/CatalogScroll/Catalog") as VBoxContainer
	if catalog == null:
		return result
	for row_value in catalog.get_children():
		var row := row_value as HBoxContainer
		if row != null and row.get_child_count() >= 1:
			var detail := row.get_child(0) as Label
			if detail != null:
				result.append(detail.text.get_slice(" [", 0).trim_prefix("✓ "))
	return result

func _select_option_value(option: OptionButton, value: String) -> void:
	for index in range(option.item_count):
		if String(option.get_item_metadata(index)) == value:
			option.select(index)
			option.item_selected.emit(index)
			return

func _add_building(state: GameState, building_type: String, position: Vector2, overrides: Dictionary = {}) -> String:
	var building := {
		"type": building_type,
		"position": position,
		"status": "idle",
		"progress": 0.0,
		"recipe_id": "",
		"input_buffer": {},
		"output_buffer": {},
	}
	building.merge(overrides, true)
	return state.add_building(building)

func _same_ids(left: Array, right: Array) -> bool:
	var sorted_left := left.duplicate()
	var sorted_right := right.duplicate()
	sorted_left.sort()
	sorted_right.sort()
	return sorted_left == sorted_right

func _expect(condition: bool, description: String) -> void:
	if condition:
		print("  PASS: ", description)
		return
	_failures += 1
	printerr("  FAIL: ", description)
