# scripts/test/TestGameplay.gd
extends Node

func _ready():
	print("=== 测试游戏玩法 ===")
	
	# 测试1: 放置矿机
	print("\n1. 放置矿机...")
	var miner_id = GameManager.get_game_state().add_building({
		"type": "miner",
		"position": Vector2(100, 200),
		"status": "idle",
		"output_item": "iron_ore",
		"output_rate": 60.0,
		"output_buffer": {}
	})
	print("矿机ID: ", miner_id)
	
	# 测试2: 放置熔炉
	print("\n2. 放置熔炉...")
	var smelter_id = GameManager.get_game_state().add_building({
		"type": "smelter",
		"position": Vector2(400, 200),
		"status": "idle",
		"recipe_id": "iron_ingot_recipe",
		"input_buffer": {},
		"output_buffer": {},
		"speed": 1.0
	})
	print("熔炉ID: ", smelter_id)
	
	# 测试3: 创建连接
	print("\n3. 创建连接...")
	var conn_id = GameManager.get_game_state().add_connection({
		"source_id": miner_id,
		"target_id": smelter_id,
		"item_id": "iron_ore",
		"flow_rate": 60.0
	})
	print("连接ID: ", conn_id)
	
	# 测试4: 模拟生产
	print("\n4. 模拟生产（3秒）...")
	for i in range(3):
		GameManager.get_simulation_engine().update(1.0)
		var miner = GameManager.get_game_state().get_building(miner_id)
		var smelter = GameManager.get_game_state().get_building(smelter_id)
		print("第", i+1, "秒 - 矿机铁矿石: ", snapped(miner.output_buffer.get("iron_ore", 0.0), 0.1), 
			  " 熔炉铁矿石: ", snapped(smelter.input_buffer.get("iron_ore", 0.0), 0.1),
			  " 熔炉铁锭: ", snapped(smelter.output_buffer.get("iron_ingot", 0.0), 0.1))
	
	# 测试5: 检查状态
	print("\n5. 最终状态:")
	print("建筑数量: ", GameManager.get_game_state().buildings.size())
	print("连接数量: ", GameManager.get_game_state().connections.size())
	
	print("\n=== 测试完成 ===")
