class_name SourceTechnologyEffects
extends RefCounted

static func completed(state: GameState, id: String) -> bool:
	return state.completed_technologies.has("dsp_" + id)

static func multiplier(state: GameState, effect: String) -> float:
	var infinite := InfiniteResearchSystem.new(state)
	match effect:
		"production_speed": return 1.0 + infinite.level("matrix_compression") * 0.04
		"vein_consumption": return maxf(0, 1.0 - mini(infinite.level("vein_utilization"), 10) * 0.1)
		"dyson_power": return 1.0 + infinite.level("stellar_harnessing") * 0.05
		"resource_collection": return 1.0 + infinite.level("vein_utilization") * 0.1
		"research_speed":
			return (1.0 + 0.25 * (int(completed(state, "research_speed_1")) + int(completed(state, "research_speed_2")) + int(completed(state, "research_speed_3")))) * (1.0 + infinite.level("matrix_compression") * 0.1)
		"mining_speed":
			return (3.0 if completed(state, "mining_speed_3") else 2.0 if completed(state, "mining_speed_2") else 1.5 if completed(state, "mining_speed_1") else 1.0) * (1.0 + infinite.level("vein_utilization") * 0.1)
		"logistics_speed":
			return (1.0 + 0.5 * (int(completed(state, "logistics_engine_1")) + int(completed(state, "logistics_engine_2")))) * (1.0 + infinite.level("galactic_logistics") * 0.05)
		"logistics_capacity":
			return (1.0 + 0.5 * (int(completed(state, "logistics_capacity_1")) + int(completed(state, "logistics_capacity_2")))) * (1.0 + infinite.level("galactic_logistics") * 0.05)
		"sail_lifetime":
			return 1.0 + 0.5 * (int(completed(state, "solar_sail_life_1")) + int(completed(state, "solar_sail_life_2")))
		"ray_capacity":
			return (1.0 + 0.5 * (int(completed(state, "ray_transmission_1")) + int(completed(state, "ray_transmission_2")))) * (1.0 + infinite.level("stellar_harnessing") * 0.05)
		"sail_absorption":
			return (2.0 if completed(state, "dyson_absorption_1") else 1.0) * (1.0 + infinite.level("stellar_harnessing") * 0.05)
	return 1.0
