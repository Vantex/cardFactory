# scenes/main/Main.gd
extends Node2D

@onready var card_renderer: Node2D = $CardRenderer
@onready var connection_renderer: Node2D = $ConnectionRenderer
@onready var input_handler: Node2D = $InputHandler
@onready var factory_workspace_ui: CanvasLayer = $FactoryWorkspaceUI
@onready var blueprint_workspace: Control = $FactoryWorkspaceUI/BlueprintWorkspace
@onready var mini_map: Control = $FactoryWorkspaceUI/MiniMap
@onready var campaign_workspace: Control = $FactoryWorkspaceUI/CampaignWorkspace
@onready var codex_workspace: Control = $FactoryWorkspaceUI/CodexWorkspace
@onready var galaxy_map: Control = $FactoryWorkspaceUI/GalaxyMap

var _synced_selected_building_id := ""
var _progression_system: ProgressionSystem
var _last_blocked_reward_signature := ""
var _progression_evaluation_queued := false
var _technology_system: TechnologySystem
var _planet_system: PlanetSystem
var _galaxy_system: GalaxySystem

func _ready() -> void:
	GameManager.game_state_replaced.connect(_on_game_state_replaced)
	var game_state := GameManager.get_game_state()
	card_renderer.set_game_state(game_state)
	card_renderer.set_input_handler(input_handler)
	connection_renderer.set_game_state(game_state)
	input_handler.set_ui_hit_test(factory_workspace_ui.is_pointer_over_ui)
	input_handler.set_blueprint_workspace(blueprint_workspace)
	blueprint_workspace.set_input_handler(input_handler)
	input_handler.blueprint_capture_requested.connect(blueprint_workspace.request_capture)
	input_handler.blueprint_deployment_requested.connect(blueprint_workspace.request_deployment)
	blueprint_workspace.capture_intent.connect(_on_blueprint_capture_intent)
	blueprint_workspace.deployment_intent.connect(_on_blueprint_deployment_intent)
	mini_map.set_camera($WorldCamera)
	campaign_workspace.locate_requested.connect(_on_locate_requested)
	codex_workspace.locate_requested.connect(_on_locate_requested)
	_progression_system = ProgressionSystem.new(game_state)
	_technology_system = TechnologySystem.new(game_state)
	_galaxy_system = GalaxySystem.new(game_state)
	_planet_system = PlanetSystem.new(game_state, _galaxy_system)
	galaxy_map.configure(game_state, _galaxy_system, _planet_system)
	galaxy_map.explore_requested.connect(_on_galaxy_explore_requested)
	galaxy_map.colonize_requested.connect(_on_galaxy_colonize_requested)
	galaxy_map.travel_requested.connect(_on_galaxy_travel_requested)

	EventBus.card_placed.connect(_on_card_placed)
	EventBus.card_selected.connect(_on_card_selected)
	EventBus.card_removed.connect(_on_card_removed)
	EventBus.placement_requested.connect(_on_placement_requested)
	EventBus.start_connection_requested.connect(_on_start_connection_requested)
	EventBus.delete_building_requested.connect(_on_delete_building_requested)
	EventBus.pause_toggled_requested.connect(_on_pause_toggled_requested)
	EventBus.speed_requested.connect(_on_speed_requested)
	EventBus.card_placed.connect(_on_progression_fact_changed)
	EventBus.card_removed.connect(_on_progression_fact_changed)
	EventBus.connection_created.connect(_on_progression_fact_changed)
	EventBus.connection_removed.connect(_on_progression_fact_changed)
	EventBus.connection_configuration_changed.connect(_on_progression_fact_changed)
	EventBus.production_completed.connect(_on_progression_item_produced)
	EventBus.technology_research_completed.connect(_on_progression_fact_changed)
	EventBus.technology_start_requested.connect(_on_technology_start_requested)
	EventBus.technology_queue_requested.connect(_on_technology_queue_requested)
	EventBus.technology_pause_requested.connect(_on_technology_pause_requested)
	EventBus.technology_resume_requested.connect(_on_technology_resume_requested)
	EventBus.technology_cancel_requested.connect(_on_technology_cancel_requested)
	EventBus.technology_remove_queue_requested.connect(_on_technology_remove_queue_requested)
	factory_workspace_ui.refresh_now()
	_evaluate_progression(true)

func _on_game_state_replaced(new_state: GameState) -> void:
	_technology_system = TechnologySystem.new(new_state)
	_galaxy_system = GalaxySystem.new(new_state)
	_planet_system = PlanetSystem.new(new_state, _galaxy_system)
	galaxy_map.configure(new_state, _galaxy_system, _planet_system)
	card_renderer.set_game_state(new_state)
	connection_renderer.set_game_state(new_state)
	input_handler.cancel_operation()
	if input_handler.has_method("set_selected_entities"):
		input_handler.set_selected_entities([])
	else:
		input_handler.selected_building_id = ""
	_synced_selected_building_id = ""
	_progression_system = ProgressionSystem.new(new_state)
	factory_workspace_ui.set_selected_building("")
	_apply_planet_viewport(new_state.active_planet_id)
	EventBus.simulation_updated.emit()
	_evaluate_progression(true)

func _process(_delta: float) -> void:
	var placement_building_type: String = input_handler.placing_building_type if input_handler.get_mode_name() == "placing" else ""
	factory_workspace_ui.set_placement_mode(placement_building_type)
	var selected_building_id: String = input_handler.selected_building_id
	if selected_building_id == _synced_selected_building_id:
		return
	_synced_selected_building_id = selected_building_id
	factory_workspace_ui.set_selected_building(selected_building_id)

func _on_card_placed(card_id: String, _position: Vector2) -> void:
	if input_handler.get_mode_name() == "placing":
		input_handler.selected_building_id = card_id
		_synced_selected_building_id = card_id
		factory_workspace_ui.set_selected_building(card_id)
		return
	factory_workspace_ui.refresh_now()

func _on_card_selected(card_id: String) -> void:
	if card_id.is_empty() and input_handler.has_method("get_selected_entity_ids"):
		var shared_selection: Array = input_handler.get_selected_entity_ids()
		if not shared_selection.is_empty():
			factory_workspace_ui.set_selected_entities(shared_selection)
			return
	input_handler.selected_building_id = card_id
	_synced_selected_building_id = card_id
	factory_workspace_ui.set_selected_building(card_id)

func _on_card_removed(card_id: String) -> void:
	if input_handler.selected_building_id != card_id:
		factory_workspace_ui.refresh_now()
		return
	input_handler.selected_building_id = ""
	_synced_selected_building_id = ""
	input_handler.cancel_operation()
	factory_workspace_ui.set_selected_building("")

func _on_placement_requested(building_type: String) -> void:
	input_handler.start_placing_card(building_type)
	_synced_selected_building_id = ""
	factory_workspace_ui.set_selected_building("")
	factory_workspace_ui.set_placement_mode(building_type)

func _on_start_connection_requested(building_id: String) -> void:
	input_handler.start_connection(building_id)

func _on_delete_building_requested(building_id: String) -> void:
	var state := GameManager.get_game_state()
	if not input_handler.call("_is_active_entity", building_id):
		EventBus.notice_requested.emit("只能删除活动行星建筑", "error")
		return
	var result := state.remove_building(building_id)
	EventBus.notice_requested.emit(String(result.get("message", "拆除命令失败")), "success" if result.get("ok", false) else "error")

func _on_pause_toggled_requested() -> void:
	var state := GameManager.get_game_state()
	state.paused = not state.paused
	EventBus.simulation_updated.emit()

func _on_speed_requested(speed: float) -> void:
	GameManager.get_game_state().speed = speed
	EventBus.simulation_updated.emit()

func _on_technology_start_requested(tech_id: String) -> void:
	_technology_system.start_research(tech_id)

func _on_technology_queue_requested(tech_id: String) -> void:
	_technology_system.add_to_queue(tech_id)

func _on_technology_pause_requested() -> void:
	_technology_system.pause_research()

func _on_technology_resume_requested() -> void:
	_technology_system.resume_research()

func _on_technology_cancel_requested() -> void:
	_technology_system.cancel_research()

func _on_technology_remove_queue_requested(tech_id: String) -> void:
	_technology_system.remove_from_queue(tech_id)

func _on_blueprint_capture_intent(entity_ids: Array) -> void:
	blueprint_workspace.accept_capture_result(GameManager.get_game_state().capture_blueprint(entity_ids))

func _on_blueprint_deployment_intent(position: Vector2, rotation_quarters: int, mirrored: bool) -> void:
	var result := GameManager.get_game_state().try_deploy_blueprint(blueprint_workspace.get_draft(), position, rotation_quarters, mirrored)
	blueprint_workspace.accept_deployment_result(result)

func _on_galaxy_explore_requested(system_id: String) -> void:
	var result := _galaxy_system.try_explore_system(system_id)
	EventBus.notice_requested.emit(String(result.get("message", "勘探命令失败")), "success" if result.get("ok", false) else "error")
	galaxy_map.refresh_now()
	factory_workspace_ui.refresh_now()

func _on_galaxy_colonize_requested(planet_id: String) -> void:
	var result := _planet_system.try_colonize_planet(planet_id)
	EventBus.notice_requested.emit(String(result.get("message", "殖民命令失败")), "success" if result.get("ok", false) else "error")
	galaxy_map.refresh_now()
	factory_workspace_ui.refresh_now()

func _on_galaxy_travel_requested(planet_id: String) -> void:
	var result := try_travel_to_planet(planet_id)
	EventBus.notice_requested.emit(String(result.get("message", "旅行命令失败")), "success" if result.get("ok", false) else "error")
	galaxy_map.refresh_now()

func _evaluate_progression(publish_snapshot: bool = false) -> void:
	if _progression_system == null or _progression_system.game_state != GameManager.get_game_state():
		_progression_system = ProgressionSystem.new(GameManager.get_game_state())
	var result := _progression_system.evaluate()
	var blocked_reward_ids: Array = result.get("blocked_reward_ids", [])
	var blocked_signature := JSON.stringify(blocked_reward_ids)
	if not blocked_reward_ids.is_empty() and blocked_signature != _last_blocked_reward_signature:
		EventBus.notice_requested.emit("进度奖励暂无法领取，请先腾出库存空间", "warning")
	_last_blocked_reward_signature = blocked_signature if not blocked_reward_ids.is_empty() else ""
	if publish_snapshot or not result.get("completed_objectives", []).is_empty() or not result.get("completed_achievements", []).is_empty() or not blocked_reward_ids.is_empty():
		result["snapshot"] = _progression_system.get_campaign_snapshot()
		EventBus.progression_updated.emit(result)
		factory_workspace_ui.refresh_now()

func _on_progression_fact_changed(_arg_1 = null, _arg_2 = null, _arg_3 = null) -> void:
	_queue_progression_evaluation()

func _on_progression_item_produced(_building_id: String, item_id: String, _amount: int) -> void:
	if _progression_system == null or _progression_system.game_state != GameManager.get_game_state():
		_progression_system = ProgressionSystem.new(GameManager.get_game_state())
	if _progression_system.has_pending_item_fact(item_id):
		_queue_progression_evaluation()

func _queue_progression_evaluation() -> void:
	if _progression_evaluation_queued:
		return
	_progression_evaluation_queued = true
	call_deferred("_flush_progression_evaluation")

func _flush_progression_evaluation() -> void:
	_progression_evaluation_queued = false
	_evaluate_progression(true)

func _on_locate_requested(building_id: String, world_position: Vector2) -> void:
	var state := GameManager.get_game_state()
	if not state.buildings.has(building_id):
		return
	var target_planet_id := String(state.buildings[building_id].get("planet_id", ""))
	if not state.colonized_planet_ids.has(target_planet_id):
		EventBus.notice_requested.emit("诊断目标所在行星尚未殖民", "error")
		return
	if target_planet_id != state.active_planet_id:
		var travel_result := try_travel_to_planet(target_planet_id)
		if not travel_result.get("ok", false):
			EventBus.notice_requested.emit(String(travel_result.get("message", "无法前往诊断目标")), "error")
			return
	$WorldCamera.global_position = world_position
	$WorldCamera.force_update_scroll()
	if input_handler.has_method("set_selected_entities"):
		input_handler.set_selected_entities([building_id])
	else:
		input_handler.selected_building_id = building_id
	_synced_selected_building_id = building_id
	factory_workspace_ui.set_selected_building(building_id)
	EventBus.card_selected.emit(building_id)

func try_travel_to_planet(planet_id: String) -> Dictionary:
	var state := GameManager.get_game_state()
	if _planet_system == null or _planet_system.game_state != state:
		_galaxy_system = GalaxySystem.new(state)
		_planet_system = PlanetSystem.new(state, _galaxy_system)
		galaxy_map.configure(state, _galaxy_system, _planet_system)
	var source_planet_id := state.active_planet_id
	var had_source_viewport := state.planet_viewports.has(source_planet_id)
	var source_viewport_before: Dictionary = state.planet_viewports.get(source_planet_id, {}).duplicate(true)
	_save_planet_viewport(source_planet_id)
	var result := _planet_system.try_set_active_planet(planet_id)
	if not result.get("ok", false):
		if had_source_viewport:
			state.planet_viewports[source_planet_id] = source_viewport_before
		else:
			state.planet_viewports.erase(source_planet_id)
		return result
	input_handler.cancel_operation()
	input_handler.set_selected_entities([])
	_synced_selected_building_id = ""
	if factory_workspace_ui.has_method("cancel_transient_operations"):
		factory_workspace_ui.call("cancel_transient_operations")
	_apply_planet_viewport(planet_id)
	_refresh_active_planet_projection()
	EventBus.active_planet_changed.emit(planet_id)
	return result

func _save_planet_viewport(planet_id: String) -> void:
	GameManager.get_game_state().planet_viewports[planet_id] = {"position": $WorldCamera.global_position, "zoom": $WorldCamera.zoom}

func _apply_planet_viewport(planet_id: String) -> void:
	var viewport_data: Dictionary = GameManager.get_game_state().planet_viewports.get(planet_id, {})
	if viewport_data.is_empty():
		return
	$WorldCamera.global_position = Vector2(viewport_data.get("position", Vector2.ZERO))
	$WorldCamera.zoom = Vector2(viewport_data.get("zoom", Vector2.ONE))
	$WorldCamera.force_update_scroll()

func _refresh_active_planet_projection() -> void:
	card_renderer.queue_redraw()
	connection_renderer.queue_redraw()
	input_handler.queue_redraw()
	mini_map.queue_redraw()
	factory_workspace_ui.set_selected_entities([])
	factory_workspace_ui.refresh_now()
	if campaign_workspace.has_method("refresh_now"):
		campaign_workspace.call("refresh_now")
	if codex_workspace.has_method("refresh_now"):
		codex_workspace.call("refresh_now")
	galaxy_map.refresh_now()
