class_name SimulationEngine
extends RefCounted

const FIXED_DELTA := 1.0 / 60.0
const MAX_STEPS_PER_FRAME := 10
const STEP_EPSILON := 0.0000001
const PHASE_ORDER := ["power", "production", "belt", "research", "statistics"]

var game_state: GameState
var production_system: ProductionSystem
var belt_system: BeltSystem
var power_system: PowerSystem
var statistics_system: StatisticsSystem
var handcraft_system: HandcraftSystem

var _accumulator := 0.0
var _last_step_count := 0

func _init(state: GameState) -> void:
	game_state = state
	production_system = ProductionSystem.new(state)
	belt_system = BeltSystem.new(state)
	power_system = PowerSystem.new(state)
	statistics_system = StatisticsSystem.new(state)
	handcraft_system = HandcraftSystem.new(state)

func update(delta: float) -> void:
	_last_step_count = 0
	if game_state.paused:
		belt_system.clear_flow_state()
		game_state.simulation_budget["current_steps"] = 0
		return

	_accumulator += maxf(delta, 0.0) * game_state.speed
	while _accumulator + STEP_EPSILON >= FIXED_DELTA and _last_step_count < MAX_STEPS_PER_FRAME:
		_run_fixed_tick()
		_accumulator = maxf(_accumulator - FIXED_DELTA, 0.0)
		_last_step_count += 1
	game_state.simulation_budget["current_steps"] = _last_step_count
	if _last_step_count > 0:
		EventBus.simulation_updated.emit()

func _run_fixed_tick() -> void:
	game_state.elapsed_time += FIXED_DELTA
	power_system.update(FIXED_DELTA)
	production_system.update(FIXED_DELTA)
	handcraft_system.update(FIXED_DELTA)
	belt_system.update(FIXED_DELTA)
	_update_research(FIXED_DELTA)
	statistics_system.update(FIXED_DELTA)

func _update_research(_delta: float) -> void:
	# Authoritative research state is introduced by the dedicated research task.
	pass

func get_pending_simulation_time() -> float:
	return _accumulator

func get_last_step_count() -> int:
	return _last_step_count

func get_phase_order() -> Array:
	return PHASE_ORDER.duplicate()

func toggle_pause() -> void:
	game_state.paused = not game_state.paused

func set_speed(new_speed: float) -> void:
	game_state.speed = clampf(new_speed, 0.5, 4.0)

func get_power_info() -> Dictionary:
	return power_system.get_power_info()

func get_statistics() -> Dictionary:
	return statistics_system.get_statistics_summary()
