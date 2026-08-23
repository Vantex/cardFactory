extends Node

var _failures := 0

func _ready() -> void:
	print("BASELINE TESTS STARTED")

	var game_state := GameState.new()
	var simulation_engine := SimulationEngine.new(game_state)
	var statistics = simulation_engine.get_statistics()

	_expect(statistics is Dictionary, "get_statistics() returns a Dictionary")
	if statistics is Dictionary:
		for key in ["total_buildings", "total_connections", "elapsed_time", "production", "consumption"]:
			_expect(statistics.has(key), "statistics contains %s" % key)

	if _failures > 0:
		printerr("BASELINE TESTS FAILED")
		get_tree().quit(1)
		return

	print("BASELINE TESTS PASSED")
	get_tree().quit(0)

func _expect(condition: bool, description: String) -> void:
	if condition:
		print("PASS: %s" % description)
		return

	_failures += 1
	printerr("FAIL: %s" % description)
