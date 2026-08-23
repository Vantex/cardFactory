# autoload/GameManager.gd
extends Node

var game_state: GameState
var simulation_engine: SimulationEngine

func _ready():
    game_state = GameState.new()
    simulation_engine = SimulationEngine.new(game_state)
    print("GameManager initialized")

func get_game_state() -> GameState:
    return game_state

func get_simulation_engine() -> SimulationEngine:
    return simulation_engine

func _process(delta):
    simulation_engine.update(delta)
