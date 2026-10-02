class_name SourceProgressionFacts
extends RefCounted

const MATRICES := ["electromagnetic_matrix", "energy_matrix", "structure_matrix", "information_matrix", "gravity_matrix", "universe_matrix"]
const RARES := ["fire_ice", "kimberlite_ore", "fractal_silicon", "organic_crystal", "optical_grating_crystal", "spiniform_stalagmite_crystal", "unipolar_magnet"]

static func value(state: GameState, metric: Dictionary) -> float:
	var result := 0.0
	var produced: Dictionary = state.progression_facts.get("produced", {})
	match String(metric.get("kind", "")):
		"manual-mined": return float(state.progression_facts.get("manual_mined", 0))
		"produced": return float(produced.get(metric.get("itemId", ""), 0))
		"research": return float(int(state.completed_technologies.has("dsp_" + String(metric.get("techId", "")))))
		"exploration": return float(int(state.explored_system_ids.has(metric.get("systemId", ""))))
		"blueprint": return float(state.blueprint_library.size())
		"building", "miner", "spray-coater", "industrial-systems":
			var systems := {}
			var galaxy := GalaxySystem.new(state) if metric.kind == "industrial-systems" else null
			for building in state.buildings.values():
				var definition := DataManager.get_building(String(building.type))
				var kind := String(metric.kind)
				if kind == "building" and PowerGridSystem.kind_id(building) == metric.get("buildingId"): result += 1
				if kind == "miner" and definition.get("kind") == "extractor": result += 1
				if kind == "spray-coater" and building.get("spray_coater_installed", false): result = 1
				if kind == "industrial-systems": systems[galaxy.get_planet(building.planet_id).get("system_id", "")] = true
			return float(systems.size()) if metric.kind == "industrial-systems" else result
		"belt":
			for connection in state.connections.values():
				var tier := String(connection.get("tier", "conveyor_belt_mk1"))
				var rank := int(tier.trim_prefix("conveyor_belt_mk")) if tier.begins_with("conveyor_belt_mk") else int(tier)
				if rank >= int(metric.get("minimumTier", 1)): result += 1
		"station-trips":
			for building in state.buildings.values():
				if PowerGridSystem.kind_id(building) == metric.get("buildingId"): result += float(state.progression_facts.get("station_trips", {}).get(building.id, 0))
		"matrix-spectrum":
			for item in MATRICES:
				if float(produced.get(item, 0)) >= 1: result += 1
		"rare-resource":
			for item in RARES:
				if metric.get("excludeOrganic", false) and item == "organic_crystal": continue
				if float(produced.get(item, 0)) >= 1: return 1
		"power":
			var by_planet := {}
			for building in state.buildings.values():
				var key := String(building.planet_id)
				if not by_planet.has(key): by_planet[key] = {"consumption": 0.0, "supplied": 0.0, "generation": 0.0}
				by_planet[key].consumption += float(building.get("power_requested", 0))
				by_planet[key].supplied += float(building.get("power_requested", 0)) * float(building.get("power_efficiency", 0))
				by_planet[key].generation += float(building.get("power_output", 0))
			for metrics in by_planet.values():
				metrics["efficiency"] = float(metrics.supplied) / float(metrics.consumption) if float(metrics.consumption) > 0 else 0.0
				if float(metrics.get("consumption", 0)) > 0 and float(metrics.get("efficiency", 0)) >= 0.999 and (not metric.get("requireGeneration", false) or float(metrics.get("generation", 0)) > 0): return 1
		"dyson":
			var field: String = {"sails": "launched_sails", "rockets": "rockets_launched", "structure": "structure_points", "shell": "absorbed_sails"}.get(metric.get("measure"), "")
			for system in state.dyson_systems: result += float(DysonSphereSystem.new(state).get_summary(system).get(field, 0))
		"infinite-research":
			for progress in state.progression_facts.get("infinite_research", {}).values(): result += float(progress.get("level", 0))
		"exported": return float(state.galactic_exports.get("total_exported", 0))
		"galactic-score": return float(state.galactic_exports.get("score", 0))
		"endgame-mastery":
			var projects: Dictionary = state.galactic_exports.get("projects", {})
			if projects.size() < 4: return 0
			for project in projects.values():
				if int(project.get("level", 0)) < 1: return 0
			return 1
	return result

static func record_produced(state: GameState, item: String, amount: float) -> void:
	if not is_finite(amount) or amount <= 0: return
	if not state.progression_facts.has("produced"): state.progression_facts["produced"] = {}
	var produced: Dictionary = state.progression_facts.produced
	produced[item] = float(produced.get(item, 0)) + amount

static func mine(state: GameState, site_id: String) -> Dictionary:
	var site: Dictionary = state.resource_sites.get(site_id, {})
	if site.is_empty() or site.get("planet_id") != state.active_planet_id or DataManager.get_item(String(site.get("item_id", ""))).get("kind") != "solid": return {"ok": false, "message": "请选择当前行星的固体矿脉"}
	if not site.get("infinite", false) and float(site.get("remaining", 0)) < 1: return {"ok": false, "message": "矿脉已耗尽"}
	var result := InventorySystem.new(state).try_add_batch({String(site.item_id): 1.0})
	if not result.ok: return result
	if not site.get("infinite", false): site.remaining -= 1.0
	state.progression_facts["manual_mined"] = float(state.progression_facts.get("manual_mined", 0)) + 1
	record_produced(state, site.item_id, 1)
	return {"ok": true, "message": "已采集一份矿物"}

static func validate(data: Dictionary) -> Array:
	var errors := []
	var facts: Variant = data.get("progression_facts", {})
	if not facts is Dictionary: return ["领域进度记录必须是字典"]
	for key in facts:
		if not ["produced", "manual_mined", "station_trips", "infinite_research", "active_infinite", "infinite_paused", "infinite_auto"].has(key): errors.append("未知领域进度字段")
	for key in ["produced", "station_trips"]:
		var counts: Variant = facts.get(key, {})
		if not counts is Dictionary:
			errors.append("累计记录必须是字典")
			continue
		for id in counts:
			var amount: Variant = counts[id]
			if not id is String or id.is_empty() or (key == "produced" and DataManager.get_item(id).is_empty()): errors.append("累计记录标识无效")
			if not (amount is int or amount is float) or not is_finite(float(amount)) or float(amount) < 0: errors.append("累计记录数值无效")
	var mined: Variant = facts.get("manual_mined", 0)
	if not (mined is int or mined is float) or not is_finite(float(mined)) or float(mined) < 0 or float(mined) != floorf(float(mined)): errors.append("手动采矿数量无效")
	errors.append_array(InfiniteResearchSystem.validate(facts))
	if not errors.is_empty(): return errors
	var completed: Array = data.get("completed_technologies", []) if data.get("completed_technologies", []) is Array else []
	var stock_limit := 100000000 if completed.has("dsp_construction_capacity_2") else 500 if completed.has("dsp_construction_capacity_1") else 100
	if data.get("buildings", {}) is Dictionary:
		for building in data.get("buildings", {}).values():
			if building is Dictionary and building.get("construction_targets", {}) is Dictionary:
				for desired in building.get("construction_targets", {}).values():
					if (desired is int or desired is float) and float(desired) > stock_limit: errors.append("制造目标超过已解锁仓储上限")
	var active: Variant = facts.get("active_infinite", "")
	if active is String and not active.is_empty():
		if not data.get("completed_technologies", []).has("dsp_universe_matrix"): errors.append("无限研究缺少宇宙矩阵科技")
		if data.get("research_current_id", "") != "" or not data.get("research_queue", []).is_empty(): errors.append("有限和无限研究不能同时进行")
		if InfiniteResearchSystem.definitions().has(active) and int(facts.get("infinite_research", {}).get(active, {}).get("level", 0)) >= int(InfiniteResearchSystem.definitions()[active].maximum): errors.append("满级无限研究不能继续运行")
	var selected: Variant = data.get("selected_source_objective", "")
	if not selected is String: errors.append("选中任务必须是字符串")
	elif not selected.is_empty():
		var known := false
		for objective in ObjectiveSystem.load_catalog().objectives:
			if objective.id == selected and objective.has("source_id"): known = true
		if not known: errors.append("选中任务不存在")
	return errors

static func network_stock(state: GameState, item: String) -> float:
	var total := 0.0
	for planet in state.colonized_planet_ids: total += float(state.get_planet_inventory(planet).get(item, 0))
	for building in state.buildings.values():
		total += float(building.get("input_buffer", {}).get(item, 0)) + float(building.get("output_buffer", {}).get(item, 0))
	if state.cursor_payload.get("item_id") == item: total += float(state.cursor_payload.get("amount", 0))
	return floorf(total)
