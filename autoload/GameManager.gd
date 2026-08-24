# autoload/GameManager.gd
extends Node

var game_state: GameState
var simulation_engine: SimulationEngine

func _ready():
    replace_game_state(GameState.new())
    print("GameManager initialized")

func replace_game_state(new_state: GameState) -> void:
    game_state = new_state
    simulation_engine = SimulationEngine.new(game_state)

func get_game_state() -> GameState:
    return game_state

func get_simulation_engine() -> SimulationEngine:
    return simulation_engine

func _process(delta):
    simulation_engine.update(delta)
