extends Node

const FIXED_DELTA := 1.0 / 60.0

var _failures := 0

func _ready() -> void:
	print("STATISTICS CODEX TESTS STARTED")
	_test_completed_recipes_record_real_production_and_consumption()
	_test_statistics_are_frame_rate_independent()
	_test_game_state_persistence_excludes_statistics_history()
	_test_windows_are_bounded_and_use_their_covered_samples()
	_test_building_rates_keep_buildings_isolated()
	_test_invalid_record_amounts_do_not_pollute_rates()
	_test_belts_record_successful_transfers()
	_test_statistics_panel_uses_the_engine_statistics_service()
	_test_production_diagnostics_report_stable_reasons_without_mutating_state()
	_test_recipe_graph_indexes_catalog_and_reports_upstream_risks()
	await _test_formal_codex_workspace_uses_live_services_and_real_controls()
	await _test_diagnostic_locate_routes_through_main_without_mutating_factory()
	if _failures > 0:
		printerr("STATISTICS CODEX TESTS FAILED")
		get_tree().quit(1)
		return
	print("STATISTICS CODEX TESTS PASSED")
	get_tree().quit(0)

func _test_completed_recipes_record_real_production_and_consumption() -> void:
	var state := _make_powered_smelter_state()
	var engine := SimulationEngine.new(state)
	_run_seconds(engine, 2.0)
	if not engine.statistics_system.has_method("get_item_rates"):
		_expect(false, "statistics exposes fixed-window item rates")
		return
	var rates: Dictionary = engine.statistics_system.get_item_rates("iron_ingot", 60)
	_expect(rates["produced_per_minute"] > 0.0, "completed recipes contribute real production")
	_expect(rates["consumed_per_minute"] > 0.0, "completed recipes contribute real consumption")
	_expect(is_equal_approx(rates["net_per_minute"], rates["produced_per_minute"] - rates["consumed_per_minute"]), "net rate is production minus consumption")

func _test_statistics_are_frame_rate_independent() -> void:
	var sixty_engine := SimulationEngine.new(_make_powered_smelter_state())
	var ten_engine := SimulationEngine.new(_make_powered_smelter_state())
	for _step in range(60):
		sixty_engine.update(FIXED_DELTA)
	for _step in range(10):
		ten_engine.update(0.1)
	_expect(sixty_engine.statistics_system.get_statistics_summary() == ten_engine.statistics_system.get_statistics_summary(), "60x1/60 and 10x0.1 produce identical statistics summaries")

func _test_game_state_persistence_excludes_statistics_history() -> void:
	var state := _make_powered_smelter_state()
	_run_seconds(SimulationEngine.new(state), 1.0)
	var serialized := GameStateCodec.to_persistent_dict(state)
	_expect(not _contains_key(serialized, "statistics_history"), "direct GameState serialization excludes statistics history")

func _test_windows_are_bounded_and_use_their_covered_samples() -> void:
	var stats := StatisticsSystem.new(GameState.new())
	for second in range(601):
		stats.record_produced("iron_ingot", float(second + 1))
		stats.update(1.0)
	_expect(stats.get_history_size() == 600, "statistics history is bounded")
	_expect(stats.get_item_rates("iron_ingot", 60)["produced_per_minute"] > stats.get_item_rates("iron_ingot", 600)["produced_per_minute"], "windows read only their covered samples")
	_expect(stats.get_item_rates("unknown", 60)["produced_per_minute"] == 0.0, "empty items return zero rates")

func _test_building_rates_keep_buildings_isolated() -> void:
	var state := GameState.new()
	_add_building(state, "solar_a", "solar_panel")
	_add_building(state, "solar_b", "solar_panel")
	_add_building(state, "fast_smelter", "smelter", {"recipe_id": "iron_ingot_recipe", "speed": 2.0, "input_buffer": {"iron_ore": 10.0}})
	_add_building(state, "slow_smelter", "smelter", {"recipe_id": "iron_ingot_recipe", "input_buffer": {"iron_ore": 10.0}})
	var engine := SimulationEngine.new(state)
	_run_seconds(engine, 1.0)
	if not engine.statistics_system.has_method("get_building_item_rates"):
		_expect(false, "statistics exposes per-building fixed-window rates")
		return
	var fast_rates: Dictionary = engine.statistics_system.get_building_item_rates("fast_smelter", "iron_ingot", 60)
	var slow_rates: Dictionary = engine.statistics_system.get_building_item_rates("slow_smelter", "iron_ingot", 60)
	_expect(fast_rates["produced_per_minute"] > slow_rates["produced_per_minute"], "per-building rates do not combine separate producers")

func _test_invalid_record_amounts_do_not_pollute_rates() -> void:
	var stats := StatisticsSystem.new(GameState.new())
	stats.record_produced("iron_ingot", NAN, "smelter")
	stats.record_consumed("iron_ingot", INF, "smelter")
	stats.record_transferred("iron_ingot", -1.0, "belt")
	stats.record_produced("iron_ingot", 0.0, "smelter")
	stats.record_produced("iron_ingot", 2.0, "smelter")
	stats.update(1.0)
	var rates := stats.get_item_rates("iron_ingot", 60)
	_expect(is_finite(rates["produced_per_minute"]) and rates["produced_per_minute"] == 120.0, "NaN, INF, zero, and negative amounts are ignored")
	_expect(rates["consumed_per_minute"] == 0.0 and rates["transferred_per_minute"] == 0.0, "invalid amounts leave every event category unpolluted")

func _test_belts_record_successful_transfers() -> void:
	var state := GameState.new()
	_add_building(state, "solar", "solar_panel")
	_add_building(state, "source", "storage", {"output_buffer": {"iron_ore": 10.0}})
	_add_building(state, "target", "smelter")
	_add_connection(state, "ore_belt", "source", "target", 10.0, "iron_ore")
	var engine := SimulationEngine.new(state)
	_run_seconds(engine, 1.0)
	_expect(engine.statistics_system.get_item_rates("iron_ore", 60)["transferred_per_minute"] > 0.0, "belt statistics include only successful real transfers")

func _test_statistics_panel_uses_the_engine_statistics_service() -> void:
	GameManager.replace_game_state(GameState.new())
	var shared_statistics := GameManager.get_simulation_engine().statistics_system
	var panel_script := load("res://scenes/ui/StatisticsPanel.gd")
	var panel: Variant = panel_script.new()
	add_child(panel)
	_expect(panel.stats_system == shared_statistics, "statistics panel uses the engine-owned statistics service")
	var history_size := shared_statistics.get_history_size()
	if panel.has_method("refresh_now"):
		panel.refresh_now()
	_expect(shared_statistics.get_history_size() == history_size, "statistics panel refresh does not advance statistics outside the simulation phase")
	panel.queue_free()

func _test_production_diagnostics_report_stable_reasons_without_mutating_state() -> void:
	var state := GameState.new()
	_add_building(state, "no_recipe_machine", "smelter", {"position": Vector2(1.0, 2.0)})
	_add_building(state, "no_power_machine", "smelter", {"recipe_id": "iron_ingot_recipe", "power_efficiency": 0.0})
	_add_building(state, "missing_input_machine", "smelter", {"recipe_id": "iron_ingot_recipe", "power_efficiency": 1.0})
	_add_building(state, "output_full_machine", "smelter", {"recipe_id": "iron_ingot_recipe", "power_efficiency": 1.0, "input_buffer": {"iron_ore": 1.0}, "output_buffer": {"iron_ingot": 24.0}})
	_add_building(state, "belt_source", "storage", {"output_buffer": {"iron_ore": 1.0}})
	_add_building(state, "empty_belt_source", "storage")
	_add_building(state, "belt_target", "smelter", {"input_buffer": {"iron_ore": 24.0}})
	_add_connection(state, "blocked_belt", "belt_source", "belt_target", 10.0, "iron_ore")
	_add_connection(state, "empty_source_belt", "empty_belt_source", "belt_target", 10.0, "iron_ore")
	_add_connection(state, "disabled_belt", "belt_source", "belt_target", 10.0, "iron_ore")
	state.connections["disabled_belt"]["enabled"] = false
	var before := GameStateCodec.state_digest_payload(state)
	var diagnostics := ProductionDiagnostics.new(state)
	var entries: Array = diagnostics.get_all_diagnostics()
	var unpowered_state := GameState.new()
	_add_building(unpowered_state, "unpowered_miner", "miner")
	SimulationEngine.new(unpowered_state).update(FIXED_DELTA)
	var unpowered_entries: Array = ProductionDiagnostics.new(unpowered_state).get_all_diagnostics()
	var codes := entries.map(func(entry): return entry["code"])
	_expect(codes.has("no_recipe"), "configurable machines diagnose missing recipes")
	_expect(codes.has("no_power"), "powered machines diagnose a zero power ratio")
	_expect(unpowered_entries.any(func(entry): return entry["entity_id"] == "unpowered_miner" and entry["code"] == "no_power"), "unpowered extractors diagnose the real simulation power state")
	_expect(codes.has("missing_input"), "recipes diagnose their first missing input")
	_expect(codes.has("output_full"), "recipes diagnose full output buffers")
	_expect(codes.has("belt_blocked"), "belts diagnose a full target buffer")
	_expect(codes.has("belt_disabled"), "disabled belts remain distinguishable from congestion")
	_expect(not entries.any(func(entry): return entry["entity_id"] == "empty_source_belt" and entry["code"] == "belt_blocked"), "empty sources do not report target congestion")
	var entity_ids := entries.map(func(entry): return entry["entity_id"])
	var sorted_entity_ids := entity_ids.duplicate()
	sorted_entity_ids.sort()
	_expect(entity_ids == sorted_entity_ids, "diagnostics are stably sorted by entity id")
	var no_recipe: Dictionary = entries.filter(func(entry): return entry["entity_id"] == "no_recipe_machine")[0]
	_expect(no_recipe["building_id"] == "no_recipe_machine" and no_recipe["planet_id"] == "home" and no_recipe["world_position"] == Vector2(1.0, 2.0), "building diagnostics carry stable location metadata")
	_expect(GameStateCodec.state_digest_payload(state) == before, "diagnostic queries do not mutate game state")

func _test_recipe_graph_indexes_catalog_and_reports_upstream_risks() -> void:
	var original_items := DataManager.get_all_items()
	var original_recipes := DataManager.get_all_recipes()
	var original_buildings := DataManager.get_all_buildings()
	var graph := RecipeGraph.new(original_items, original_recipes, original_buildings)
	original_recipes["iron_ingot_recipe"]["duration"] = 999.0
	_expect(graph.get_producers("iron_ingot").has("iron_ingot_recipe"), "items reverse-map to producer recipes")
	_expect(graph.get_recipe_buildings("iron_ingot_recipe").has("smelter"), "recipes map to supported buildings")
	var two_layers: Dictionary = graph.build_upstream_chain("matrix_science_1", 2)
	var full_chain: Dictionary = graph.build_upstream_chain("matrix_science_1", -1)
	_expect(two_layers["max_depth"] == 2, "two-layer chains stop at the requested depth")
	_expect(full_chain["nodes"].size() >= two_layers["nodes"].size(), "full chains include the two-layer view")
	_expect(is_equal_approx(float(graph.get_theoretical_rate_per_minute("iron_ingot_recipe", "iron_ingot")), 60.0), "recipe graph calculates output amount per duration per minute")
	_expect(float(graph.get_theoretical_rate_per_minute("iron_ingot_recipe", "iron_ingot")) != 1.0 / 999.0 * 60.0, "recipe graph owns a deep-copied catalog index")
	var cycle_graph := RecipeGraph.new({}, {
		"a_recipe": {"id": "a_recipe", "building_id": "machine", "inputs": [{"item_id": "b", "amount": 1}], "outputs": [{"item_id": "a", "amount": 1}], "duration": 1.0},
		"b_recipe": {"id": "b_recipe", "building_id": "machine", "inputs": [{"item_id": "a", "amount": 1}], "outputs": [{"item_id": "b", "amount": 1}], "duration": 1.0},
	}, {"machine": {"id": "machine"}})
	_expect(not cycle_graph.build_upstream_chain("a", -1)["cycles"].is_empty(), "upstream DFS returns catalog cycles instead of recursing forever")
	var gap_graph := RecipeGraph.new({}, {"target_recipe": {"id": "target_recipe", "building_id": "machine", "inputs": [{"item_id": "unmade", "amount": 1}], "outputs": [{"item_id": "target", "amount": 1}], "duration": 1.0}}, {"machine": {"id": "machine"}})
	_expect(gap_graph.build_upstream_chain("target", -1)["gaps"].has("unmade"), "upstream chains report inputs with no producer")
	_expect(DataManager.get_all_items() == original_items and DataManager.get_all_recipes()["iron_ingot_recipe"]["duration"] != 999.0 and DataManager.get_all_buildings() == original_buildings, "catalog query results are deep copies")

func _test_formal_codex_workspace_uses_live_services_and_real_controls() -> void:
	var state := GameState.new()
	_add_building(state, "missing_input_machine", "smelter", {
		"position": Vector2(180.0, 220.0),
		"recipe_id": "iron_ingot_recipe",
		"power_efficiency": 1.0,
	})
	GameManager.replace_game_state(state)
	var statistics := GameManager.get_simulation_engine().statistics_system
	statistics.record_produced("iron_ingot", 4.0, "missing_input_machine")
	statistics.record_consumed("iron_ingot", 1.0, "missing_input_machine")
	statistics.record_transferred("iron_ingot", 2.0)
	statistics.update(1.0)

	var viewport := SubViewport.new()
	viewport.size = Vector2i(1152, 648)
	add_child(viewport)
	var main: Node = load("res://scenes/main/Main.tscn").instantiate()
	viewport.add_child(main)
	await get_tree().process_frame
	await get_tree().process_frame
	main.get_node("AppShell").call("_on_session_started", 0, true)
	await get_tree().process_frame

	var workspace := main.get_node_or_null("FactoryWorkspaceUI/CodexWorkspace") as Control
	var analysis_button := main.get_node_or_null("FactoryWorkspaceUI/TopBar/AnalysisButton") as Button
	_expect(workspace != null and not workspace.visible and analysis_button != null, "formal Main mounts a collapsed codex workspace with an analysis entry")
	if workspace == null:
		viewport.queue_free()
		await get_tree().process_frame
		return

	var statistics_tab := workspace.get_node_or_null("Layout/Tabs/Statistics") as Button
	var diagnostics_tab := workspace.get_node_or_null("Layout/Tabs/Diagnostics") as Button
	var codex_tab := workspace.get_node_or_null("Layout/Tabs/Codex") as Button
	var statistics_panel := workspace.get_node_or_null("Layout/Content/StatisticsPanel") as Control
	var diagnostics_panel := workspace.get_node_or_null("Layout/Content/DiagnosticsPanel") as Control
	var codex_panel := workspace.get_node_or_null("Layout/Content/CodexPanel") as Control
	var statistics_search := workspace.get_node_or_null("Layout/Content/StatisticsPanel/Search") as LineEdit
	var statistics_window := workspace.get_node_or_null("Layout/Content/StatisticsPanel/Window") as OptionButton
	var statistics_scroll := workspace.get_node_or_null("Layout/Content/StatisticsPanel/ResultsScroll") as ScrollContainer
	var diagnostics_search := workspace.get_node_or_null("Layout/Content/DiagnosticsPanel/Search") as LineEdit
	var diagnostics_scroll := workspace.get_node_or_null("Layout/Content/DiagnosticsPanel/ResultsScroll") as ScrollContainer
	var codex_search := workspace.get_node_or_null("Layout/Content/CodexPanel/Search") as LineEdit
	var chain_depth := workspace.get_node_or_null("Layout/Content/CodexPanel/ChainDepth") as OptionButton
	var codex_scroll := workspace.get_node_or_null("Layout/Content/CodexPanel/ResultsScroll") as ScrollContainer
	_expect(statistics_tab != null and diagnostics_tab != null and codex_tab != null, "codex exposes statistics, diagnostics, and recipe codex tabs")
	_expect(statistics_panel != null and diagnostics_panel != null and codex_panel != null, "codex tabs own three real content views")
	_expect(statistics_search != null and statistics_window != null and statistics_scroll != null, "statistics exposes real search, fixed windows, and scrolling")
	_expect(diagnostics_search != null and diagnostics_scroll != null and codex_search != null and chain_depth != null and codex_scroll != null, "diagnostics and recipe codex expose real search, chain depth, and scrolling")
	if analysis_button == null or statistics_tab == null or diagnostics_tab == null or codex_tab == null:
		viewport.queue_free()
		await get_tree().process_frame
		return

	analysis_button.pressed.emit()
	await get_tree().process_frame
	_expect(workspace.visible and statistics_panel.visible and not diagnostics_panel.visible and not codex_panel.visible, "analysis entry opens the statistics view first")
	var windows: Array = []
	for index in range(statistics_window.item_count):
		windows.append(statistics_window.get_item_metadata(index))
	_expect(windows == [60, 300, 600], "statistics window control exposes 60, 300, and 600 seconds")
	var statistics_rows := statistics_scroll.get_node_or_null("Results") as VBoxContainer
	var iron_row := _find_row_by_meta(statistics_rows, "item_id", "iron_ingot")
	_expect(iron_row != null and String(iron_row.get_node("Rates").text).contains("生产") and String(iron_row.get_node("Rates").text).contains("消耗") and String(iron_row.get_node("Rates").text).contains("净值") and String(iron_row.get_node("Rates").text).contains("吞吐"), "statistics rows render live production, consumption, net, and throughput rates")
	statistics_search.text = "不存在的物品"
	statistics_search.text_changed.emit(statistics_search.text)
	await get_tree().process_frame
	_expect((statistics_scroll.get_node("Results") as VBoxContainer).get_child_count() == 0, "statistics search filters the live result list")
	statistics_search.text = ""
	statistics_search.text_changed.emit(statistics_search.text)

	diagnostics_tab.pressed.emit()
	await get_tree().process_frame
	var diagnostic_rows := diagnostics_scroll.get_node_or_null("Results") as VBoxContainer
	_expect(diagnostics_panel.visible and _find_row_by_meta(diagnostic_rows, "entity_id", "missing_input_machine") != null, "diagnostics tab renders real ProductionDiagnostics entries")
	diagnostics_search.text = "不存在的诊断"
	diagnostics_search.text_changed.emit(diagnostics_search.text)
	await get_tree().process_frame
	_expect((diagnostics_scroll.get_node("Results") as VBoxContainer).get_child_count() == 0, "diagnostics search removes non-matching real entries")
	diagnostics_search.text = "missing_input"
	diagnostics_search.text_changed.emit(diagnostics_search.text)
	await get_tree().process_frame
	_expect(_find_row_by_meta(diagnostics_scroll.get_node("Results") as VBoxContainer, "entity_id", "missing_input_machine") != null, "diagnostics search filters stable diagnostic fields")

	codex_tab.pressed.emit()
	await get_tree().process_frame
	var depths: Array = []
	for index in range(chain_depth.item_count):
		depths.append(chain_depth.get_item_metadata(index))
	var codex_rows := codex_scroll.get_node_or_null("Results") as VBoxContainer
	_expect(codex_panel.visible and depths == [2, -1] and _find_row_by_meta(codex_rows, "item_id", "matrix_science_1") != null, "recipe codex renders the real graph with two-layer and full-chain controls")
	codex_search.text = "不存在的资料"
	codex_search.text_changed.emit(codex_search.text)
	await get_tree().process_frame
	_expect((codex_scroll.get_node("Results") as VBoxContainer).get_child_count() == 0, "recipe codex search removes non-matching real rows")
	codex_search.text = "matrix_science_1"
	codex_search.text_changed.emit(codex_search.text)
	await get_tree().process_frame
	var filtered_codex_rows := codex_scroll.get_node("Results") as VBoxContainer
	_expect(filtered_codex_rows.get_child_count() == 1 and _find_row_by_meta(filtered_codex_rows, "item_id", "matrix_science_1") != null, "recipe codex search retains the matching real catalog row")
	var two_layer_row := _find_row_by_meta(filtered_codex_rows, "item_id", "matrix_science_1")
	var two_layer_detail := String(two_layer_row.get_node("Details").text) if two_layer_row != null else ""
	_expect(two_layer_detail.contains("circuit_recipe") and not two_layer_detail.contains("copper_ingot_recipe"), "two-layer control renders shallow chain identities without deeper smelting recipes")
	_expect(two_layer_detail.contains("支持建筑：矩阵研究站"), "recipe codex renders RecipeGraph-supported buildings for the matrix recipe")
	chain_depth.select(1)
	chain_depth.item_selected.emit(1)
	await get_tree().process_frame
	var full_chain_rows := codex_scroll.get_node("Results") as VBoxContainer
	var full_chain_row := _find_row_by_meta(full_chain_rows, "item_id", "matrix_science_1")
	var full_chain_detail := String(full_chain_row.get_node("Details").text) if full_chain_row != null else ""
	_expect(full_chain_detail != two_layer_detail and full_chain_detail.contains("copper_ingot_recipe") and full_chain_detail.contains("iron_ore") and full_chain_detail.contains("支持建筑：熔炉") and full_chain_detail.contains("→"), "full-chain control reveals deeper recipe, item, relationship, and supported-building details")
	chain_depth.select(0)
	chain_depth.item_selected.emit(0)
	await get_tree().process_frame
	var restored_two_layer_row := _find_row_by_meta(codex_scroll.get_node("Results") as VBoxContainer, "item_id", "matrix_science_1")
	var restored_two_layer_detail := String(restored_two_layer_row.get_node("Details").text) if restored_two_layer_row != null else ""
	_expect(restored_two_layer_detail == two_layer_detail and not restored_two_layer_detail.contains("copper_ingot_recipe"), "selecting the two-layer option restores the shallow real chain details")
	codex_search.text = ""
	codex_search.text_changed.emit(codex_search.text)
	await get_tree().process_frame
	var codex_bar := codex_scroll.get_v_scroll_bar()
	var desired_scroll := minf(36.0, maxf(codex_bar.max_value - codex_bar.page, 0.0))
	codex_scroll.scroll_vertical = int(desired_scroll)
	await get_tree().process_frame
	var retained_scroll := codex_scroll.scroll_vertical
	analysis_button.pressed.emit()
	analysis_button.pressed.emit()
	await get_tree().process_frame
	_expect(retained_scroll > 0 and codex_scroll.scroll_vertical == retained_scroll, "closing and reopening preserves an actual recipe codex scroll position")

	var technology_button := main.get_node_or_null("FactoryWorkspaceUI/TopBar/TechnologyButton") as Button
	var campaign_button := main.get_node_or_null("FactoryWorkspaceUI/InspectorPanel/CampaignToggle") as Button
	var blueprint_button := main.get_node_or_null("FactoryWorkspaceUI/InspectorPanel/BlueprintToggle") as Button
	var technology := main.get_node_or_null("FactoryWorkspaceUI/TechnologyPanel") as Control
	var campaign := main.get_node_or_null("FactoryWorkspaceUI/CampaignWorkspace") as Control
	var blueprint := main.get_node_or_null("FactoryWorkspaceUI/BlueprintWorkspace") as Control
	var exclusivity_controls_present := technology_button != null and campaign_button != null and blueprint_button != null and technology != null and campaign != null and blueprint != null
	_expect(exclusivity_controls_present, "all four formal workspace entries are player-operable")
	if exclusivity_controls_present:
		for toggle in [technology_button, campaign_button, blueprint_button, analysis_button]:
			toggle.pressed.emit()
			await get_tree().process_frame
			_expect(_visible_workspace_count([technology, campaign, blueprint, workspace]) == 1, "opening a formal workspace hides the other three")

	statistics_tab.pressed.emit()
	statistics_search.text = ""
	statistics_search.text_changed.emit(statistics_search.text)
	var replacement_state := GameState.new()
	GameManager.replace_game_state(replacement_state)
	var replacement_statistics := GameManager.get_simulation_engine().statistics_system
	replacement_statistics.record_produced("copper_ingot", 3.0)
	replacement_statistics.update(1.0)
	EventBus.simulation_updated.emit()
	await get_tree().process_frame
	var replacement_rows := statistics_scroll.get_node("Results") as VBoxContainer
	_expect(_find_row_by_meta(replacement_rows, "item_id", "iron_ingot") == null and _find_row_by_meta(replacement_rows, "item_id", "copper_ingot") != null, "visible statistics rebinds to the replacement simulation and drops old history")

	viewport.queue_free()
	await get_tree().process_frame

func _test_diagnostic_locate_routes_through_main_without_mutating_factory() -> void:
	var state := GameState.new()
	_add_building(state, "belt_source", "storage", {"output_buffer": {"iron_ore": 3.0}})
	_add_building(state, "locatable_smelter", "smelter", {
		"position": Vector2(210.0, 260.0),
		"recipe_id": "iron_ingot_recipe",
		"power_efficiency": 1.0,
		"progress": 0.37,
		"input_buffer": {},
		"output_buffer": {"iron_ingot": 2.0},
	})
	_add_connection(state, "configured_belt", "belt_source", "locatable_smelter", 12.0, "iron_ore")
	state.connections["configured_belt"].merge({
		"tier": "conveyor_belt_mk2",
		"parallel_count": 2,
		"stack_size": 4,
		"priority": 1,
		"route_mode": "upper",
		"monitor_enabled": true,
	}, true)
	GameManager.replace_game_state(state)
	var before_recipe := String(state.buildings["locatable_smelter"]["recipe_id"])
	var before_input: Dictionary = state.buildings["locatable_smelter"]["input_buffer"].duplicate(true)
	var before_output: Dictionary = state.buildings["locatable_smelter"]["output_buffer"].duplicate(true)
	var before_progress := float(state.buildings["locatable_smelter"]["progress"])
	var before_connections := state.connections.duplicate(true)

	var viewport := SubViewport.new()
	viewport.size = Vector2i(1152, 648)
	add_child(viewport)
	var main: Node = load("res://scenes/main/Main.tscn").instantiate()
	viewport.add_child(main)
	await get_tree().process_frame
	main.get_node("AppShell").call("_on_session_started", 0, true)
	await get_tree().process_frame
	var analysis_button := main.get_node("FactoryWorkspaceUI/TopBar/AnalysisButton") as Button
	var diagnostics_tab := main.get_node("FactoryWorkspaceUI/CodexWorkspace/Layout/Tabs/Diagnostics") as Button
	analysis_button.pressed.emit()
	diagnostics_tab.pressed.emit()
	await get_tree().process_frame
	var results := main.get_node("FactoryWorkspaceUI/CodexWorkspace/Layout/Content/DiagnosticsPanel/ResultsScroll/Results") as VBoxContainer
	var row := _find_row_by_meta(results, "entity_id", "locatable_smelter")
	var locate := row.get_node_or_null("Locate") as Button if row != null else null
	_expect(locate != null, "a real missing-input diagnostic exposes a locate action")
	if locate != null:
		locate.pressed.emit()
		await get_tree().process_frame
	var input_handler := main.get_node("InputHandler")
	var camera := main.get_node("WorldCamera") as Camera2D
	_expect(input_handler.get_selected_entity_ids() == ["locatable_smelter"] and camera.global_position == Vector2(210.0, 260.0), "diagnostic locate moves the real camera and establishes one authoritative selection")
	var building: Dictionary = state.buildings["locatable_smelter"]
	_expect(String(building["recipe_id"]) == before_recipe and building["input_buffer"] == before_input and building["output_buffer"] == before_output and is_equal_approx(float(building["progress"]), before_progress) and state.connections == before_connections, "diagnostic locate leaves recipe, buffers, progress, and line configuration unchanged")
	viewport.queue_free()
	await get_tree().process_frame

func _find_row_by_meta(container: Container, key: String, value: String) -> Control:
	if container == null:
		return null
	for child in container.get_children():
		if child is Control and String(child.get_meta(key, "")) == value:
			return child as Control
	return null

func _visible_workspace_count(workspaces: Array) -> int:
	var count := 0
	for workspace in workspaces:
		if workspace != null and workspace.visible:
			count += 1
	return count

func _make_powered_smelter_state() -> GameState:
	var state := GameState.new()
	_add_building(state, "solar", "solar_panel")
	_add_building(state, "smelter", "smelter", {
		"recipe_id": "iron_ingot_recipe",
		"speed": 2.0,
		"input_buffer": {"iron_ore": 10.0},
	})
	_add_building(state, "consumer", "assembling_machine_mk1", {
		"recipe_id": "circuit_recipe",
		"input_buffer": {"iron_ingot": 10.0, "copper_ingot": 10.0},
	})
	return state

func _add_building(state: GameState, id: String, type: String, overrides: Dictionary = {}) -> void:
	var definition := DataManager.get_building(type)
	var building := {
		"id": id,
		"type": type,
		"position": Vector2.ZERO,
		"status": "idle",
		"recipe_id": "",
		"progress": 0.0,
		"input_buffer": {},
		"output_buffer": {},
		"speed": definition.get("speed", 1.0),
	}
	building.merge(overrides, true)
	state.buildings[id] = building

func _add_connection(state: GameState, id: String, source_id: String, target_id: String, flow_rate: float, item_id: String) -> void:
	state.connections[id] = {
		"id": id,
		"source_id": source_id,
		"target_id": target_id,
		"item_id": item_id,
		"flow_rate": flow_rate,
		"enabled": true,
		"active": false,
		"current_flow": 0.0,
	}

func _run_seconds(engine: SimulationEngine, seconds: float) -> void:
	var tick_count := int(round(seconds / FIXED_DELTA))
	for _tick in range(tick_count):
		engine.update(FIXED_DELTA)

func _contains_key(value: Variant, key: String) -> bool:
	if value is Dictionary:
		for value_key in value:
			if String(value_key) == key or _contains_key(value[value_key], key):
				return true
	elif value is Array:
		for entry in value:
			if _contains_key(entry, key):
				return true
	return false

func _expect(condition: bool, description: String) -> void:
	if condition:
		print("PASS: %s" % description)
		return
	_failures += 1
	printerr("FAIL: %s" % description)
