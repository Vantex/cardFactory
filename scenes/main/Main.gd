# scenes/main/Main.gd
extends Node2D

@onready var card_renderer: Node2D = $CardRenderer
@onready var connection_renderer: Node2D = $ConnectionRenderer
@onready var input_handler: Node2D = $InputHandler
@onready var hud: CanvasLayer = $HUD
@onready var building_panel: PanelContainer = $BuildingPanel

func _ready():
	print("Main scene ready!")
	
	# 测试数据加载
	print("Items: ", DataManager.all_items.size())
	print("Buildings: ", DataManager.all_buildings.size())
	print("Recipes: ", DataManager.all_recipes.size())
	
	# 连接信号
	EventBus.card_selected.connect(_on_card_selected)
	
	# 自动放置测试建筑
	_place_initial_buildings()

func _place_initial_buildings():
	# 放置矿机
	var miner_id = GameManager.get_game_state().add_building({
		"type": "miner",
		"position": Vector2(100, 200),
		"status": "idle",
		"output_item": "iron_ore",
		"output_rate": 60.0,
		"output_buffer": {}
	})
	print("Placed miner at (100, 200)")
	
	# 放置熔炉
	var smelter_id = GameManager.get_game_state().add_building({
		"type": "smelter",
		"position": Vector2(400, 200),
		"status": "idle",
		"recipe_id": "iron_ingot_recipe",
		"input_buffer": {},
		"output_buffer": {},
		"speed": 1.0
	})
	print("Placed smelter at (400, 200)")
	
	# 创建连接
	GameManager.get_game_state().add_connection({
		"source_id": miner_id,
		"target_id": smelter_id,
		"item_id": "iron_ore",
		"flow_rate": 60.0
	})
	print("Created connection: miner -> smelter")

func _on_card_selected(card_id: String):
	print("Card selected: ", card_id)
	if building_panel:
		building_panel.update_building_info(card_id)
