# scenes/main/Main.gd
extends Node2D

@onready var card_renderer: Node2D = $CardRenderer
@onready var connection_renderer: Node2D = $ConnectionRenderer
@onready var input_handler: Node2D = $InputHandler
@onready var factory_workspace_ui: CanvasLayer = $FactoryWorkspaceUI

var _synced_selected_building_id := ""

func _ready() -> void:
	var game_state := GameManager.get_game_state()
	card_renderer.set_game_state(game_state)
	card_renderer.set_input_handler(input_handler)
	connection_renderer.set_game_state(game_state)
	input_handler.set_ui_hit_test(factory_workspace_ui.is_pointer_over_ui)

	EventBus.card_placed.connect(_on_card_placed)
	EventBus.card_selected.connect(_on_card_selected)
	EventBus.card_removed.connect(_on_card_removed)
	EventBus.placement_requested.connect(_on_placement_requested)
	factory_workspace_ui.refresh_now()

func _process(_delta: float) -> void:
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
