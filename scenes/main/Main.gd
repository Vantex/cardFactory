# scenes/main/Main.gd
extends Node2D

@onready var card_renderer: Node2D = $CardRenderer
@onready var connection_renderer: Node2D = $ConnectionRenderer
@onready var input_handler: Node2D = $InputHandler
@onready var factory_workspace_ui: CanvasLayer = $FactoryWorkspaceUI
@onready var blueprint_workspace: Control = $FactoryWorkspaceUI/BlueprintWorkspace
@onready var mini_map: Control = $FactoryWorkspaceUI/MiniMap

var _synced_selected_building_id := ""

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

	EventBus.card_placed.connect(_on_card_placed)
	EventBus.card_selected.connect(_on_card_selected)
	EventBus.card_removed.connect(_on_card_removed)
	EventBus.placement_requested.connect(_on_placement_requested)
	EventBus.start_connection_requested.connect(_on_start_connection_requested)
	EventBus.delete_building_requested.connect(_on_delete_building_requested)
	EventBus.pause_toggled_requested.connect(_on_pause_toggled_requested)
	EventBus.speed_requested.connect(_on_speed_requested)
	factory_workspace_ui.refresh_now()

func _on_game_state_replaced(new_state: GameState) -> void:
	card_renderer.set_game_state(new_state)
	connection_renderer.set_game_state(new_state)
	input_handler.cancel_operation()
	if input_handler.has_method("set_selected_entities"):
		input_handler.set_selected_entities([])
	else:
		input_handler.selected_building_id = ""
	_synced_selected_building_id = ""
	factory_workspace_ui.set_selected_building("")
	EventBus.simulation_updated.emit()

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
	var result := state.remove_building(building_id)
	EventBus.notice_requested.emit(String(result.get("message", "拆除命令失败")), "success" if result.get("ok", false) else "error")

func _on_pause_toggled_requested() -> void:
	var state := GameManager.get_game_state()
	state.paused = not state.paused
	EventBus.simulation_updated.emit()

func _on_speed_requested(speed: float) -> void:
	GameManager.get_game_state().speed = speed
	EventBus.simulation_updated.emit()

func _on_blueprint_capture_intent(entity_ids: Array) -> void:
	blueprint_workspace.accept_capture_result(GameManager.get_game_state().capture_blueprint(entity_ids))

func _on_blueprint_deployment_intent(position: Vector2, rotation_quarters: int, mirrored: bool) -> void:
	var result := GameManager.get_game_state().try_deploy_blueprint(blueprint_workspace.get_draft(), position, rotation_quarters, mirrored)
	blueprint_workspace.accept_deployment_result(result)
