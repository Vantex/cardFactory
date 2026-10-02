class_name InterstellarRouteSystem
extends RefCounted

var state: GameState
var galaxy: GalaxySystem

func _init(game_state: GameState) -> void:
	state = game_state
	galaxy = GalaxySystem.new(state)

func economics(source: Dictionary, target: Dictionary, count: int = 1, options: Dictionary = {}) -> Dictionary:
	var ap := galaxy.get_planet(source.planet_id)
	var bp := galaxy.get_planet(target.planet_id)
	var warp: bool = ap.system_id != bp.system_id
	var budget := clampi(int(options.get("warper_budget", 2)), 1, 4)
	var path := _path(source, target, String(options.get("route_policy", "relay-preferred")), budget) if warp else {}
	var environment := (_environment(source) + _environment(target)) / 2.0
	var speed := state.get_technology_effect_multiplier("logistics_speed") * GameModeSystem.new(state).multiplier("logistics")
	var orbit := maxf(1, absf(float(ap.orbit) - float(bp.orbit)))
	var duration := float(path.get("duration", 12.0 / speed * environment * 4.0)) if warp else 30.0 / speed * environment * (0.9 + orbit * 0.1)
	duration = SourceGalaxySystem.rounded(duration)
	var ids: Array = path.get("ids", [])
	var waypoints: Array = ids.slice(1, ids.size() - 1) if ids.size() > 2 else []
	var hops := maxi(1, ids.size() - 1) if warp and not ids.is_empty() else budget if warp else 0
	var vessels := maxi(1, count)
	var cargo := roundf(100.0 * state.get_technology_effect_multiplier("logistics_capacity")) * vessels
	var power := _rated_power(source) + _rated_power(target) + (900.0 * hops if warp else 240.0) * vessels
	for id in waypoints: power += _rated_power(state.buildings[id])
	power = SourceGalaxySystem.rounded(power)
	var distance := float(path.get("distance", galaxy.get_system_distance(ap.system_id, bp.system_id))) if warp else 0.0
	return {"distance_ly": SourceGalaxySystem.rounded(distance), "orbit_span": orbit, "requires_warp": warp, "duration": duration, "cargo_per_trip": cargo, "throughput_per_minute": SourceGalaxySystem.rounded(cargo * 60.0 / maxf(1, duration)), "warpers_per_trip": hops * vessels, "warpers_per_vessel": hops, "power_kw": power, "energy_mj_per_trip": SourceGalaxySystem.rounded(power * duration / 1000.0), "available": not warp or not path.is_empty(), "kind": "local" if not warp else "relay" if not waypoints.is_empty() else "direct", "waypoint_ids": waypoints, "hop_count": hops, "max_leg_distance_ly": SourceGalaxySystem.rounded(float(path.get("max_leg", distance)))}

func _path(source: Dictionary, target: Dictionary, policy: String, budget: int) -> Dictionary:
	var endpoints := [galaxy.get_planet(source.planet_id).system_id, galaxy.get_planet(target.planet_id).system_id]
	var hubs := {}
	for station in state.buildings.values():
		if SystemHubLogisticsSystem.is_elevator(station) or station.get("station", {}).has("mode_transition"): continue
		if station.type != "dsp_interstellar_logistics_station" or station.id in [source.id, target.id] or not station.get("station", {}).get("hub_enabled", false): continue
		var system: String = galaxy.get_planet(station.planet_id).system_id
		if system in endpoints or not state.explored_system_ids.has(system): continue
		var previous: Dictionary = hubs.get(system, {})
		var priority := int(station.station.get("hub_priority", 1))
		if previous.is_empty() or priority > int(previous.station.get("hub_priority", 1)) or (priority == int(previous.station.get("hub_priority", 1)) and String(station.id) < String(previous.id)): hubs[system] = station
	var candidates: Array = []
	_visit([source], hubs.values(), target, policy, budget, candidates)
	candidates.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		if a.score != b.score: return a.score < b.score
		if a.ids.size() != b.ids.size(): return a.ids.size() < b.ids.size()
		return ":".join(a.ids) < ":".join(b.ids))
	return candidates[0] if not candidates.is_empty() else {}

func _visit(stations: Array, remaining: Array, target: Dictionary, policy: String, budget: int, candidates: Array) -> void:
	var used := stations.size() - 1
	if used >= budget: return
	if policy != "relay-required" or stations.size() > 1:
		var chain := stations + [target]
		var result := {"ids": [], "duration": 0.0, "distance": 0.0, "max_leg": 0.0, "score": 0.0}
		var bonus := 0.0
		for index in range(chain.size()):
			result.ids.append(chain[index].id)
			if index > 0:
				var leg := _leg(chain[index - 1], chain[index])
				result.duration += leg.duration
				result.distance += leg.distance
				result.max_leg = maxf(result.max_leg, leg.distance)
			if index > 0 and index < chain.size() - 1: bonus += int(chain[index].station.get("hub_priority", 1)) * 0.025
		result.score = result.duration * maxf(0.85, 1.0 - bonus)
		candidates.append(result)
	if policy == "direct" or used + 1 >= budget: return
	for hub in remaining:
		if float(_leg(stations[-1], hub).distance) > 18.0: continue
		var others := remaining.duplicate()
		others.erase(hub)
		_visit(stations + [hub], others, target, policy, budget, candidates)

func _leg(source: Dictionary, target: Dictionary) -> Dictionary:
	var distance := galaxy.get_system_distance(galaxy.get_planet(source.planet_id).system_id, galaxy.get_planet(target.planet_id).system_id)
	var speed := state.get_technology_effect_multiplier("logistics_speed") * GameModeSystem.new(state).multiplier("logistics")
	var penalty := 1.0 + (distance - 12.0) / 14.0 if distance > 12.0 else 1.0
	return {"distance": distance, "duration": 12.0 / speed * (_environment(source) + _environment(target)) / 2.0 * (0.75 + distance / 24.0) * penalty}

func _environment(building: Dictionary) -> float:
	return float(galaxy.get_planet(building.planet_id).get("travel_multiplier", 1.0))

func _rated_power(building: Dictionary) -> float:
	return float(DataManager.get_building(building.type).get("power_demand", 0)) * maxf(1, float(building.get("machine_count", 1)))

func hub_power(ids: Array) -> float:
	var factor := 1.0
	for id in ids: factor = minf(factor, float(state.buildings.get(id, {}).get("power_efficiency", 0)))
	return factor
