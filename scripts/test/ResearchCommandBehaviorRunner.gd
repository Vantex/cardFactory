extends RefCounted

const FIXTURE := "res://tests/fixtures/parity/behavior/task27-research-commands.json"
const COMPARATOR := preload("res://scripts/test/SpecialProductionBehaviorRunner.gd")
const CASES := ["select_resets_all_labs", "pause_resets_all_labs", "resume_resets_all_labs", "cancel_activates_queue", "select_settles_paid_boundary", "cancel_settles_paid_boundary", "queue_accepts_planned_parent", "remove_cascades_dependents", "select_alongside_paused", "cancel_paused_is_noop", "pause_idle_is_noop", "resume_idle_is_noop", "cancel_idle_is_noop", "select_current_is_noop", "select_completed_is_noop", "select_unknown_is_noop", "select_locked_is_noop", "select_queued_is_noop", "remove_missing_is_noop", "resume_alongside_current_is_noop", "resume_with_waiting_queue", "select_resumes_with_waiting_queue", "queue_uses_paused_parent", "pause_replaces_previous_paused", "cancel_skips_blocked_queue_head", "select_settles_active_paid_boundary", "resume_settles_paid_boundary", "tick_settles_paid_boundary", "cancel_settles_paid_queue_chain", "queued_paused_selection_waits"]
var errors: Array[String] = []

func run(fixture_override: Dictionary = {}) -> Dictionary:
	errors.clear()
	var fixture := DSPOnlineParity.read_json(FIXTURE) if fixture_override.is_empty() else fixture_override
	var source := DSPOnlineParity.read_json(DSPOnlineParity.ROOT + "dsponline_source_catalog.json")
	if fixture.get("source_commit") != source.source.commit or not fixture.get("source_files") is Dictionary: return _reject("research command provenance missing")
	for required in ["src/game/engine.ts", "src/game/storage.ts"]:
		if not fixture.source_files.has(required): return _reject("research command source module missing")
	for file in fixture.source_files:
		if fixture.source_files[file] != source.source.files.get(file): return _reject("research command source hash drift")
	var ids := []
	for row in fixture.get("cases", []): ids.append(row.id)
	if ids != CASES: return _reject("research command cases missing, duplicated or reordered")
	var save_root := "res://.godot/task27-research-command-saves-%d/" % Time.get_ticks_usec()
	for row in fixture.cases:
		var saves := SaveSystem.new(save_root + row.id)
		var prepared := _state(row)
		var state: GameState = prepared.state
		var labs: Array = prepared.labs
		_compare(row.input, state, labs, row.id + ": before command")
		var canonical_before := GameStateCodec.to_persistent_dict(state)
		_disk(saves, 0, state, labs, row.loaded_before, row.id + ": before command disk migration")
		_compare(row.input, state, labs, row.id + ": encoding and saving preserve live state")
		var changed := command(TechnologySystem.new(state), row.action)
		_check(changed == row.changed, row.id + ": actual command acceptance/no-op")
		_compare(row.expected, state, labs, row.id + ": after command")
		if not changed: _check(GameStateCodec.to_persistent_dict(state) == canonical_before, row.id + ": no-op preserves all persistent ownership")
		_disk(saves, 1, state, labs, row.loaded_after, row.id + ": after command disk migration")
		var copied := GameState.new()
		copied.copy_from(state)
		_check(COMPARATOR._difference(GameStateCodec.to_persistent_dict(copied), GameStateCodec.to_persistent_dict(state)).is_empty(), row.id + ": authoritative copy retains paused/current/queue ownership")
	_test_legacy_pause_and_validation()
	_test_live_pack_queue_protection()
	return {"errors": errors.duplicate()}

func _state(row: Dictionary) -> Dictionary:
	var state := GameState.new()
	SourceGalaxySystem.new(state).initialize(240721)
	for id in row.input.research.completedTechIds: state.completed_technologies.append("dsp_" + id)
	for id in row.input.campaign.completedTaskIds: state.completed_objective_ids.append("dsp_" + id)
	for id in row.input.campaign.rewardedTaskIds: state.claimed_progression_reward_ids.append("objective:dsp_" + id)
	state.construction_inventory.clear()
	for id in row.input.construction: state.construction_inventory[_construction_id(id)] = row.input.construction[id]
	var labs := []
	for index in range(row.input.labs.size()):
		var lab := state.add_building({"type": "dsp_matrix_lab", "recipe_id": "", "position": Vector2(200 + index * 200, 0), "speed": 1.0, "input_buffer": {}, "output_buffer": {}, "progress": 0.0})
		_check(state.set_entity_recipe(lab, "dsp_matrix_research"), row.id + ": actual lab configured")
		labs.append(lab)
	var research := TechnologySystem.new(state)
	for action in row.setup: _check(command(research, action), row.id + ": actual setup command")
	for id in row.input.research.progressByTech:
		var cost: Dictionary = row.input.research.progressByTech[id].duplicate(true)
		state.research_invested_costs["dsp_" + id] = cost
		var paid := 0.0
		for item in cost: paid += float(cost[item])
		state.research_progress["dsp_" + id] = paid * 3.0
	for index in range(labs.size()):
		state.buildings[labs[index]].progress = float(row.input.labs[index].progress) * 3.0
		state.buildings[labs[index]].input_buffer = row.input.labs[index].inputs.duplicate(true)
		state.buildings[labs[index]].output_buffer = row.input.labs[index].outputs.duplicate(true)
	return {"state": state, "labs": labs}

static func command(research: TechnologySystem, action: Array) -> bool:
	match action[0]:
		"select": return research.start_research("dsp_" + String(action[1]))
		"pause": return research.pause_research()
		"resume": return research.resume_research()
		"cancel": return research.cancel_research()
		"remove": return research.remove_from_queue("dsp_" + String(action[1]))
		"tick":
			research.update_source_labs(0.25)
			return true
	return false

func _compare(expected: Dictionary, state: GameState, labs: Array, label: String) -> void:
	var research := TechnologySystem.new(state)
	var selected := "" if state.research_paused else state.research_current_id.trim_prefix("dsp_")
	_check(selected == _nullable(expected.research.selectedTechId) and research.get_paused_research().trim_prefix("dsp_") == _nullable(expected.research.pausedTechId), label + ": current and paused ownership")
	_check(state.research_queue.map(func(id): return String(id).trim_prefix("dsp_")) == expected.research.queuedTechIds, label + ": complete dependency queue")
	var completed: Array = state.completed_technologies.map(func(id): return String(id).trim_prefix("dsp_"))
	var wanted: Array = expected.research.completedTechIds.duplicate()
	completed.sort()
	wanted.sort()
	_check(completed == wanted, label + ": finite completion set")
	var invested := {}
	for id in state.research_invested_costs:
		if not state.research_invested_costs[id].is_empty(): invested[String(id).trim_prefix("dsp_")] = state.research_invested_costs[id]
	_check(COMPARATOR._difference(invested, expected.research.progressByTech).is_empty(), label + ": all nonempty matrix investments retained")
	_check(COMPARATOR._difference(_positive_stock(state.construction_inventory), _positive_stock(expected.construction)).is_empty(), label + ": construction rewards exactly once")
	for index in range(labs.size()):
		var actual: Dictionary = state.buildings[labs[index]]
		_check(absf(float(actual.progress) / 3.0 - float(expected.labs[index].progress)) < 0.000000001, label + ": lab %d cycle phase" % index)
		_check(COMPARATOR._difference(actual.input_buffer, expected.labs[index].inputs).is_empty() and COMPARATOR._difference(actual.output_buffer, expected.labs[index].outputs).is_empty(), label + ": lab %d complete buffers" % index)

func _disk(saves: SaveSystem, slot: int, state: GameState, labs: Array, expected: Dictionary, label: String) -> void:
	var events := []
	var completion_observer := func(id): events.append(id)
	var queue_observer := func(queue): events.append(queue)
	EventBus.technology_research_completed.connect(completion_observer)
	EventBus.technology_research_queue_changed.connect(queue_observer)
	var canonical := GameStateCodec.to_persistent_dict(state)
	var saved := saves.save_slot(slot, state)
	var loaded := saves.load_slot(slot) if saved.ok else {}
	EventBus.technology_research_completed.disconnect(completion_observer)
	EventBus.technology_research_queue_changed.disconnect(queue_observer)
	_check(events.is_empty(), label + ": encoding and loading emit no live completion or queue events")
	_check(saved.ok and loaded.get("ok", false), label + ": real disk save and load; " + str(saved.get("error", {})))
	if not loaded.get("ok", false): return
	_check(COMPARATOR._difference(GameStateCodec.to_persistent_dict(loaded.state), canonical).is_empty(), label + ": complete canonical persistence roundtrip")
	_compare(expected, loaded.state, labs, label + ": actual frozen migration result")

func _test_legacy_pause_and_validation() -> void:
	var fixture := DSPOnlineParity.read_json(FIXTURE)
	var state: GameState = _state(fixture.cases[20]).state
	var research := TechnologySystem.new(state)
	var canonical := GameStateCodec.to_persistent_dict(state)
	var legacy := canonical.duplicate(true)
	legacy.erase("research_paused_id")
	legacy.research_current_id = state.research_paused_id
	legacy.research_paused = true
	var restored := GameStateCodec.from_persistent_dict(legacy)
	_check(restored != null and COMPARATOR._difference(GameStateCodec.to_persistent_dict(restored), canonical).is_empty(), "old schema v9 source pause flag migrates with its waiting dependent queue")
	if restored != null:
		_check(TechnologySystem.new(restored).resume_research() and restored.research_current_id == "dsp_mining_speed_1" and restored.research_queue == ["dsp_mining_speed_2"], "legacy paused source save resumes without losing dependent queue")
	for invalid in [17, "unknown_research", "factory_foundations"]:
		var payload := canonical.duplicate(true)
		payload.research_paused_id = invalid
		_check(GameStateCodec.from_persistent_dict(payload) == null, "invalid paused source reference rejected: " + str(invalid))
	var missing_cost := canonical.duplicate(true)
	missing_cost.research_invested_costs.erase(state.research_paused_id)
	_check(GameStateCodec.from_persistent_dict(missing_cost) == null, "paused source investment ownership required")
	var missing_parent := canonical.duplicate(true)
	missing_parent.completed_technologies.erase("dsp_energy_matrix")
	_check(GameStateCodec.from_persistent_dict(missing_parent) == null, "paused source prerequisites validated")
	_check(ContentPackSystem.uses({"research_paused_id": state.research_paused_id}, {state.research_paused_id: true}), "generic protected-state scanner includes the optional paused reference")
	_check(research.get_paused_research() == "dsp_mining_speed_1", "legacy validation leaves live state unchanged")
	var hybrid := GameState.new()
	hybrid.completed_technologies = ["dsp_electromagnetism"]
	hybrid.planet_inventory.matrix_science_1 = 15.0
	var hybrid_research := TechnologySystem.new(hybrid)
	_check(hybrid_research.start_research("dsp_basic_logistics") and hybrid_research.pause_research(), "hybrid source research paused")
	_check(hybrid_research.start_research("factory_foundations") and hybrid_research.pause_research(), "teaching research retains its independent legacy pause flag")
	var hybrid_payload := GameStateCodec.to_persistent_dict(hybrid)
	var hybrid_restored := GameStateCodec.from_persistent_dict(hybrid_payload)
	_check(hybrid_restored != null and COMPARATOR._difference(GameStateCodec.to_persistent_dict(hybrid_restored), hybrid_payload).is_empty(), "paused teaching and paused source research coexist in a valid save")
	if hybrid_restored != null:
		var service := TechnologySystem.new(hybrid_restored)
		_check(service.resume_research() and hybrid_restored.research_paused_id == "dsp_basic_logistics" and hybrid_restored.research_current_id == "factory_foundations", "teaching resume preserves the separate source pause")

func _test_live_pack_queue_protection() -> void:
	var old_catalog := ContentPackSystem.snapshot_catalog()
	var old_service := DataManager.content_pack_system
	var old_state := GameManager.get_game_state()
	var pack := {"formatVersion": 2, "id": "research_queue_guard", "name": "研究队列保护", "version": "1.0.0", "technologies": [{"id": "research_queue_child", "name": "队列子项", "summary": "只用于验证实时引用", "costs": [{"itemId": "electromagnetic_matrix", "amount": 2}], "prerequisites": ["mining_speed_1"]}]}
	var service := ContentPackSystem.new("res://.godot/task27-research-queue-pack-%d/registry.json" % Time.get_ticks_usec())
	DataManager.content_pack_system = service
	var registered := service.register_pack(pack)
	_check(registered.ok and registered.get("enabled", false), "real content pack research child registered")
	if registered.ok:
		var state := GameState.new()
		state.completed_technologies = ["dsp_electromagnetism", "dsp_energy_matrix"]
		var research := TechnologySystem.new(state)
		_check(research.start_research("dsp_mining_speed_1") and research.add_to_queue("research_queue_child") and research.cancel_research(), "actual source cancellation leaves a blocked custom dependent in the live queue")
		_check(state.research_queue == ["research_queue_child"] and GameStateCodec.to_persistent_dict(state).research_queue.is_empty(), "live blocked queue and source load-time canonical queue intentionally differ")
		GameManager.replace_game_state(state)
		var protected := GameManager.get_content_pack_protected_payloads()
		_check(protected.ok and ContentPackSystem.uses(protected.payloads, {"research_queue_child": true}), "formal protected payloads retain the live custom queue reference")
		var disabled := service.set_enabled(pack.id, false, protected.payloads)
		_check(not disabled.ok and service.registry.packs[pack.id].enabled, "actual content pack disable rejects a live blocked research reference")
		state.completed_technologies.append("dsp_mining_speed_1")
		research.update_research(0.0)
		_check(state.research_current_id == "research_queue_child", "custom dependent becomes active after its funded prerequisite completes")
		var lab := state.add_building({"type": "dsp_matrix_lab", "position": Vector2(200, 0), "input_buffer": {}, "output_buffer": {}})
		_check(state.set_entity_recipe(lab, "dsp_matrix_research"), "real lab selected for paid custom research")
		state.buildings[lab].input_buffer = {"electromagnetic_matrix": 2.0}
		for index in range(4): state.add_building({"type": "dsp_wind_turbine", "position": Vector2(index * 100, -100), "input_buffer": {}, "output_buffer": {}})
		var storage := SaveSystem.new("res://.godot/task27-paid-custom-research-%d/" % Time.get_ticks_usec())
		for payment in range(2):
			PowerSystem.new(state).update(3.0)
			research.update_source_labs(3.0)
			_check(state.research_invested_costs.research_queue_child.electromagnetic_matrix == payment + 1, "paid custom technology consumes exactly one actual matrix per cycle")
			_check(storage.save_slot(payment, state).ok and storage.load_slot(payment).ok, "partial and completed paid custom technology survive real save/load")
		_check(state.completed_technologies.has("research_queue_child") and state.buildings[lab].input_buffer.electromagnetic_matrix == 0, "paid custom research completes with conserved matrices")
	ContentPackSystem.install_catalog(old_catalog)
	DataManager.content_pack_system = old_service
	GameManager.replace_game_state(old_state)

static func _positive_stock(stock: Dictionary) -> Dictionary:
	var result := {}
	for id in stock:
		if float(stock[id]) > 0: result[String(id).trim_prefix("dsp_")] = stock[id]
	return result

static func _construction_id(id: String) -> String:
	return id if DataManager.belt_definitions().has(id) else "dsp_" + id

static func _nullable(value: Variant) -> String:
	return "" if value == null else String(value)

func _check(ok: bool, label: String) -> void:
	if not ok: errors.append(label)

func _reject(label: String) -> Dictionary:
	errors.append(label)
	return {"errors": errors.duplicate()}
