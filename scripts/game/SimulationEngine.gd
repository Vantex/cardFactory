class_name SimulationEngine
extends RefCounted

const FIXED_DELTA := 1.0 / 60.0
const MAX_STEPS_PER_FRAME := 10
const STEP_EPSILON := 0.0000001
const PHASE_ORDER := ["dyson_decay", "power", "production", "handcraft", "belt", "logistics", "dyson_launch", "galaxy", "research", "endgame", "progression", "statistics"]

var game_state: GameState
var performance_monitor: PerformanceSystem
var optimize_queries := true
var production_system: ProductionSystem
var belt_system: BeltSystem
var power_system: PowerSystem
var statistics_system: StatisticsSystem
var handcraft_system: HandcraftSystem
var technology_system: TechnologySystem
var galaxy_system: GalaxySystem
var logistics_system: LogisticsSystem
var dyson_system: DysonSphereSystem
var endgame_system: EndgameSystem
var progression_system: ProgressionSystem

var _accumulator := 0.0
var _last_step_count := 0

func _init(state: GameState) -> void:
	game_state = state
	statistics_system = StatisticsSystem.new(state)
	production_system = ProductionSystem.new(state, statistics_system)
	belt_system = BeltSystem.new(state, statistics_system)
	power_system = PowerSystem.new(state, statistics_system)
	handcraft_system = HandcraftSystem.new(state)
	technology_system = TechnologySystem.new(state)
	galaxy_system = GalaxySystem.new(state)
	logistics_system = LogisticsSystem.new(state, statistics_system)
	dyson_system = DysonSphereSystem.new(state, statistics_system)
	endgame_system = EndgameSystem.new(state)
	progression_system = ProgressionSystem.new(state)

func update(delta: float) -> void:
	belt_system.optimize_queries = optimize_queries
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
	var started := performance_monitor.begin() if performance_monitor != null else 0
	var phase_started := started
	game_state.elapsed_time += FIXED_DELTA
	dyson_system.begin_tick()
	if performance_monitor != null and performance_monitor.enabled:
		performance_monitor.finish("phase_dyson_decay_ms", phase_started)
		phase_started = performance_monitor.begin()
	power_system.update(FIXED_DELTA)
	if performance_monitor != null and performance_monitor.enabled:
		performance_monitor.finish("phase_power_ms", phase_started)
		phase_started = performance_monitor.begin()
	production_system.update(FIXED_DELTA)
	if performance_monitor != null and performance_monitor.enabled:
		performance_monitor.finish("phase_production_ms", phase_started)
		phase_started = performance_monitor.begin()
	handcraft_system.update(FIXED_DELTA)
	if performance_monitor != null and performance_monitor.enabled:
		performance_monitor.finish("phase_handcraft_ms", phase_started)
		phase_started = performance_monitor.begin()
	belt_system.update(FIXED_DELTA)
	if performance_monitor != null and performance_monitor.enabled:
		performance_monitor.finish("phase_belt_ms", phase_started)
		phase_started = performance_monitor.begin()
	logistics_system.update(FIXED_DELTA)
	if performance_monitor != null and performance_monitor.enabled:
		performance_monitor.finish("phase_logistics_ms", phase_started)
		phase_started = performance_monitor.begin()
	dyson_system.update_launches(FIXED_DELTA)
	if performance_monitor != null and performance_monitor.enabled:
		performance_monitor.finish("phase_dyson_launch_ms", phase_started)
		phase_started = performance_monitor.begin()
	galaxy_system.update_exploration(FIXED_DELTA)
	if performance_monitor != null and performance_monitor.enabled:
		performance_monitor.finish("phase_galaxy_ms", phase_started)
		phase_started = performance_monitor.begin()
	_update_research(FIXED_DELTA)
	if performance_monitor != null and performance_monitor.enabled:
		performance_monitor.finish("phase_research_ms", phase_started)
		phase_started = performance_monitor.begin()
	endgame_system.update_tick()
	if performance_monitor != null and performance_monitor.enabled:
		performance_monitor.finish("phase_endgame_ms", phase_started)
		phase_started = performance_monitor.begin()
	progression_system.evaluate()
	if performance_monitor != null and performance_monitor.enabled:
		performance_monitor.finish("phase_progression_ms", phase_started)
		phase_started = performance_monitor.begin()
	statistics_system.update(FIXED_DELTA)
	if performance_monitor != null and performance_monitor.enabled:
		performance_monitor.finish("phase_statistics_ms", phase_started)
		phase_started = performance_monitor.begin()
	if performance_monitor != null: performance_monitor.finish("fixed_tick_ms", started)

func _update_research(delta: float) -> void:
	technology_system.update_research(delta, _has_powered_research_lab())

func _has_powered_research_lab() -> bool:
	var building_ids := game_state.buildings.keys()
	if not optimize_queries: building_ids.sort()
	for building_id_value in building_ids:
		var building: Dictionary = game_state.buildings[building_id_value]
		if String(building.get("type", "")) == "matrix_lab" and float(building.get("power_efficiency", 0.0)) > 0.0:
			return true
	return false

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
