extends Node

var failures := 0

func _ready() -> void:
	var evidence_path := "res://.godot/task27-parity-evidence.json"
	if FileAccess.file_exists(evidence_path): _expect(DirAccess.remove_absolute(ProjectSettings.globalize_path(evidence_path)) == OK, "previous evidence invalidated before this run")
	var path := DSPOnlineParity.ROOT + "dsponline_single_player_manifest.json"
	var complete := false
	var force_harness_failure := false
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--parity-manifest="): path = argument.trim_prefix("--parity-manifest=")
		if argument == "--parity-require-complete": complete = true
		if argument == "--parity-force-harness-failure": force_harness_failure = true
	var manifest := DSPOnlineParity.read_json(path)
	var behavior: Dictionary = await ParityBehaviorRunner.new().run()
	_expect(behavior.errors.is_empty(), "source behavior: " + str(behavior.errors.slice(0, 8)))
	var errors := DSPOnlineParity.validate(manifest, complete, behavior.verified_keys, behavior.proofs)
	_expect(errors.is_empty(), "parity registration: " + str(errors.slice(0, 5)))
	if force_harness_failure: _expect(false, "injected harness failure must invalidate evidence")
	if not complete and not force_harness_failure and not manifest.is_empty(): _test_rejections(manifest, behavior)
	if not complete and not force_harness_failure: await _test_behavior_rejections(manifest, behavior)
	print("PARITY BEHAVIOR KEYS PASSED: ", behavior.verified_keys.size())
	if failures == 0:
		behavior.harness = {"passed": true, "failures": 0, "rejections_checked": not complete, "manifest": path, "manifest_sha256": FileAccess.get_sha256(path)}
		var report := FileAccess.open(evidence_path, FileAccess.WRITE)
		_expect(report != null, "completed evidence report opened")
		if report != null:
			report.store_string(JSON.stringify(behavior, "\t"))
			var write_error := report.get_error()
			report.close()
			_expect(write_error == OK, "completed evidence report written")
			if write_error != OK: DirAccess.remove_absolute(ProjectSettings.globalize_path(evidence_path))
	if failures == 0:
		print("DSPONLINE PARITY TESTS PASSED")
	else:
		printerr("DSPONLINE PARITY TESTS FAILED")
	get_tree().quit(0 if failures == 0 else 1)

func _test_rejections(manifest: Dictionary, behavior: Dictionary) -> void:
	var broken := manifest.duplicate(true)
	broken.entries[0].status = "实现中"
	_expect(not DSPOnlineParity.validate(broken, true, behavior.verified_keys, behavior.proofs).is_empty(), "release mode refuses a constructed unresolved row")
	broken = manifest.duplicate(true)
	broken.entries.pop_back()
	_expect(_rejects(broken, behavior, "unregistered missing row"), "missing catalog row rejected")
	broken = manifest.duplicate(true)
	broken.entries.append(broken.entries[0])
	_expect(_rejects(broken, behavior, "duplicate, unknown or excluded row"), "duplicate ID rejected")
	broken = manifest.duplicate(true)
	broken.entries[0].rule_test = "absent"
	_expect(_rejects(broken, behavior, "missing rule case"), "missing rule case rejected")
	broken = manifest.duplicate(true)
	broken.entries[0].status = "在线排除"
	_expect(_rejects(broken, behavior, "unregistered online exclusion"), "unapproved exclusion rejected")
	broken = manifest.duplicate(true)
	broken.entries[0].status = "已验证"
	_expect(not DSPOnlineParity.validate(broken).is_empty(), "paper-only verified claim rejected")
	broken = manifest.duplicate(true)
	broken.entries[0].target = {"category": "items", "ids": ["nonexistent_item"]}
	_expect(_rejects(broken, behavior, "missing target data"), "nonexistent target rejected")
	broken = manifest.duplicate(true)
	broken.source_commit = "wrong"
	_expect(_rejects(broken, behavior, "manifest version or source commit mismatch"), "wrong source revision rejected")
	broken = manifest.duplicate(true)
	broken.entries[0].erase("gap")
	_expect(_rejects(broken, behavior, "missing gap, manual acceptance or UI"), "unexplained gap rejected")

func _rejects(manifest: Dictionary, behavior: Dictionary, message: String) -> bool:
	return DSPOnlineParity.validate(manifest, false, behavior.verified_keys, behavior.proofs).any(func(error): return message in error)

func _test_behavior_rejections(manifest: Dictionary, behavior: Dictionary) -> void:
	_expect(preload("res://scripts/test/ResourceManualBehaviorRunner.gd").rejection_errors().is_empty(), "resource manual six fixture drift cases withhold keys and proofs")
	var belts := ParityBehaviorRunner.new().run_belts()
	_expect(belts.errors.is_empty() and belts.verified_keys == behavior.verified_keys.filter(func(key): return key.begins_with("belts:")), "isolated belt keys match the actual full positive run")
	for key in belts.verified_keys:
		_expect(belts.proofs[key] == behavior.proofs[key] and belts.claims[key] == behavior.claims[key], "isolated belt assertions and fixture match the full run: " + key)
	_expect(not belts.has("implementation_sha256") and not DSPOnlineParity.validate(manifest, false, belts.verified_keys, belts.proofs).is_empty(), "isolated domain results cannot masquerade as full parity evidence")
	var fixture := DSPOnlineParity.read_json(ParityBehaviorRunner.FIXTURE)
	var broken := fixture.duplicate(true)
	broken.source_commit = "wrong"
	var rejected: Dictionary = ParityBehaviorRunner.new().run_belts(broken)
	_expect(not rejected.errors.is_empty() and rejected.verified_keys.is_empty(), "wrong behavior revision grants no keys")
	broken = fixture.duplicate(true)
	broken.source_files["src/game/content.ts"] = "wrong"
	rejected = ParityBehaviorRunner.new().run_belts(broken)
	_expect(not rejected.errors.is_empty() and rejected.verified_keys.is_empty(), "behavior source hash drift grants no keys")
	broken = fixture.duplicate(true)
	broken.belt_cases = []
	rejected = ParityBehaviorRunner.new().run_belts(broken)
	_expect(not rejected.errors.is_empty() and not rejected.verified_keys.any(func(key): return key.begins_with("belts:")), "missing belt cases grant no belt keys")
	broken = fixture.duplicate(true)
	broken.belt_cases[0].capacity += 1
	rejected = ParityBehaviorRunner.new().run_belts(broken)
	_expect(not rejected.errors.is_empty() and not rejected.verified_keys.has("belts:conveyor_belt_mk1") and rejected.verified_keys.size() == 2, "one failed assertion withholds its whole key")
	var planning_fixture := DSPOnlineParity.read_json(PlanningBehaviorRunner.FIXTURE)
	planning_fixture.commands[0].plans[0].targetPerMinute += 1
	var planning_rejected := PlanningBehaviorRunner.new().run(planning_fixture)
	_expect(not planning_rejected.errors.is_empty() and not planning_rejected.verified_keys.has(PlanningBehaviorRunner.KEYS.create), "failed source plan command withholds its key")
	var production_fixture := DSPOnlineParity.read_json(RecipeBehaviorRunner.FIXTURE)
	production_fixture.cases[0].expected.outputs.iron_ingot += 1
	var production_rejected := RecipeBehaviorRunner.new().run(production_fixture)
	_expect(not production_rejected.errors.is_empty() and not production_rejected.verified_keys.has("recipes:iron_ingot"), "failed material conversion withholds its recipe key")
	var dedicated_script := preload("res://scripts/test/SpecialProductionBehaviorRunner.gd")
	var dedicated_fixture := DSPOnlineParity.read_json(dedicated_script.FIXTURE)
	var broken_dedicated := dedicated_fixture.duplicate(true)
	broken_dedicated.source_files["src/game/engine.ts"] = "wrong"
	var dedicated_rejected: Dictionary = dedicated_script.new().run(broken_dedicated)
	_expect(not dedicated_rejected.errors.is_empty() and dedicated_rejected.verified_keys.is_empty(), "dedicated source drift grants no recipe keys")
	broken_dedicated = dedicated_fixture.duplicate(true)
	broken_dedicated.cases.pop_back()
	dedicated_rejected = dedicated_script.new().run(broken_dedicated)
	_expect(not dedicated_rejected.errors.is_empty() and dedicated_rejected.verified_keys.is_empty(), "missing dedicated stage grants no recipe keys")
	broken_dedicated = dedicated_fixture.duplicate(true)
	broken_dedicated.cases.back().stage = "powered"
	dedicated_rejected = dedicated_script.new().run(broken_dedicated)
	_expect(not dedicated_rejected.errors.is_empty() and dedicated_rejected.verified_keys.is_empty(), "duplicate dedicated stage grants no recipe keys")
	broken_dedicated = dedicated_fixture.duplicate(true)
	for row in broken_dedicated.cases:
		if row.id == "accumulator_charge" and row.stage == "powered": row.expected.subject.outputs.charged_accumulator += 1
	dedicated_rejected = dedicated_script.new().run(broken_dedicated)
	_expect(not dedicated_rejected.errors.is_empty() and not dedicated_rejected.verified_keys.has("recipes:accumulator_charge") and dedicated_rejected.verified_keys.size() == 6, "one failed dedicated conversion withholds exactly its recipe key")
	var finite_script := preload("res://scripts/test/FiniteResearchBehaviorRunner.gd")
	var finite_fixture := DSPOnlineParity.read_json(finite_script.FIXTURE)
	var broken_finite := finite_fixture.duplicate(true)
	broken_finite.source_files["src/game/engine.ts"] = "wrong"
	var finite_rejected: Dictionary = finite_script.new().run(broken_finite)
	_expect(not finite_rejected.errors.is_empty() and finite_rejected.verified_keys.is_empty(), "finite research source drift grants no technology keys")
	broken_finite = finite_fixture.duplicate(true)
	broken_finite.cases.pop_back()
	finite_rejected = finite_script.new().run(broken_finite)
	_expect(not finite_rejected.errors.is_empty() and finite_rejected.verified_keys.is_empty(), "missing finite research stage grants no technology keys")
	broken_finite = finite_fixture.duplicate(true)
	broken_finite.cases.append(broken_finite.cases[0].duplicate(true))
	finite_rejected = finite_script.new().run(broken_finite)
	_expect(not finite_rejected.errors.is_empty() and finite_rejected.verified_keys.is_empty(), "duplicate finite research stage grants no technology keys")
	broken_finite = finite_fixture.duplicate(true)
	for row in broken_finite.cases:
		if row.id == "basic_logistics" and row.stage == "last_payment": row.expected.research.progressByTech.basic_logistics.electromagnetic_matrix += 1
	finite_rejected = finite_script.new().run(broken_finite)
	_expect(not finite_rejected.errors.is_empty() and not finite_rejected.verified_keys.has("technologies:basic_logistics") and finite_rejected.verified_keys.size() == 75, "one failed finite payment withholds exactly its technology key")
	var command_script := preload("res://scripts/test/ResearchCommandBehaviorRunner.gd")
	var command_fixture := DSPOnlineParity.read_json(command_script.FIXTURE)
	var broken_commands := command_fixture.duplicate(true)
	broken_commands.source_files["src/game/storage.ts"] = "wrong"
	_expect(not command_script.new().run(broken_commands).errors.is_empty(), "research command source migration drift rejected")
	broken_commands = command_fixture.duplicate(true)
	broken_commands.cases.pop_back()
	_expect(not command_script.new().run(broken_commands).errors.is_empty(), "missing research command transition rejected")
	broken_commands = command_fixture.duplicate(true)
	broken_commands.cases[0].expected.labs[0].progress = 0.5
	_expect(not command_script.new().run(broken_commands).errors.is_empty(), "incorrect research command cycle output rejected")
	var infinite_script := preload("res://scripts/test/InfiniteResearchBehaviorRunner.gd")
	var infinite_fixture := DSPOnlineParity.read_json(infinite_script.FIXTURE)
	var broken_infinite := infinite_fixture.duplicate(true)
	broken_infinite.source_files["src/game/infiniteResearch.ts"] = "wrong"
	var infinite_rejected: Dictionary = infinite_script.new().run(broken_infinite)
	_expect(not infinite_rejected.errors.is_empty() and infinite_rejected.verified_keys.is_empty(), "infinite budget source drift grants no keys")
	broken_infinite = infinite_fixture.duplicate(true)
	broken_infinite.budgets.pop_back()
	infinite_rejected = infinite_script.new().run(broken_infinite)
	_expect(not infinite_rejected.errors.is_empty() and infinite_rejected.verified_keys.is_empty(), "missing infinite budget boundary grants no keys")
	broken_infinite = infinite_fixture.duplicate(true)
	broken_infinite.cases[0].expected.labs[0].progress = 0.9
	infinite_rejected = infinite_script.new().run(broken_infinite)
	_expect(not infinite_rejected.errors.is_empty() and infinite_rejected.verified_keys.is_empty(), "incorrect infinite phase withholds all related command keys")
	var unknown := behavior.duplicate(true)
	var boundary_script := preload("res://scripts/test/ResearchBoundaryBehaviorRunner.gd")
	var boundary_fixture := DSPOnlineParity.read_json(boundary_script.FIXTURE)
	var broken_boundaries := boundary_fixture.duplicate(true)
	broken_boundaries.source_files["src/game/storage.ts"] = "wrong"
	var boundary_rejected: Dictionary = boundary_script.new().run(broken_boundaries)
	_expect(not boundary_rejected.errors.is_empty() and boundary_rejected.verified_keys.is_empty(), "research boundary source migration drift grants no keys")
	broken_boundaries = boundary_fixture.duplicate(true)
	broken_boundaries.cases.pop_back()
	boundary_rejected = boundary_script.new().run(broken_boundaries)
	_expect(not boundary_rejected.errors.is_empty() and boundary_rejected.verified_keys.is_empty(), "missing research boundary case grants no keys")
	broken_boundaries = boundary_fixture.duplicate(true)
	broken_boundaries.cases.append(broken_boundaries.cases[0].duplicate(true))
	boundary_rejected = boundary_script.new().run(broken_boundaries)
	_expect(not boundary_rejected.errors.is_empty() and boundary_rejected.verified_keys.is_empty(), "duplicate research boundary case grants no keys")
	broken_boundaries = boundary_fixture.duplicate(true)
	broken_boundaries.cases[0].pure_expected.labs[0].progress += 0.1
	boundary_rejected = boundary_script.new().run(broken_boundaries)
	_expect(not boundary_rejected.errors.is_empty() and boundary_rejected.verified_keys.is_empty(), "incorrect pure boundary phase withholds both endpoint keys")
	var control_script := preload("res://scripts/test/ResearchControlBehaviorRunner.gd")
	var control_fixture := DSPOnlineParity.read_json(control_script.FIXTURE)
	var broken_controls := control_fixture.duplicate(true)
	broken_controls.source_files["src/game/storage.ts"] = "wrong"
	var control_rejected: Dictionary = control_script.new().run(broken_controls)
	_expect(not control_rejected.errors.is_empty() and control_rejected.verified_keys.is_empty(), "research control source drift grants no keys")
	broken_controls = control_fixture.duplicate(true)
	broken_controls.cases.pop_back()
	control_rejected = control_script.new().run(broken_controls)
	_expect(not control_rejected.errors.is_empty() and control_rejected.verified_keys.is_empty(), "missing research control case grants no keys")
	broken_controls = control_fixture.duplicate(true)
	broken_controls.cases.append(broken_controls.cases[0].duplicate(true))
	control_rejected = control_script.new().run(broken_controls)
	_expect(not control_rejected.errors.is_empty() and control_rejected.verified_keys.is_empty(), "duplicate research control case grants no keys")
	broken_controls = control_fixture.duplicate(true)
	broken_controls.cases[0].expected.labs[0].progress += 0.1
	control_rejected = control_script.new().run(broken_controls)
	_expect(not control_rejected.errors.is_empty() and control_rejected.verified_keys.is_empty(), "incorrect control output withholds all five endpoint keys")
	var progression_script := preload("res://scripts/test/ProgressionBehaviorRunner.gd")
	var progression_fixture := DSPOnlineParity.read_json(progression_script.FIXTURE)
	var broken_progression := progression_fixture.duplicate(true)
	broken_progression.source_files["src/game/storage.ts"] = "wrong"
	var progression_rejected: Dictionary = progression_script.new().run(broken_progression)
	_expect(not progression_rejected.errors.is_empty() and progression_rejected.verified_keys.is_empty(), "progression source migration drift grants no keys")
	broken_progression = progression_fixture.duplicate(true)
	broken_progression.cases.pop_back()
	progression_rejected = progression_script.new().run(broken_progression)
	_expect(not progression_rejected.errors.is_empty() and progression_rejected.verified_keys.is_empty(), "missing progression case grants no keys")
	broken_progression = progression_fixture.duplicate(true)
	broken_progression.cases.append(broken_progression.cases[0].duplicate(true))
	progression_rejected = progression_script.new().run(broken_progression)
	_expect(not progression_rejected.errors.is_empty() and progression_rejected.verified_keys.is_empty(), "duplicate progression case grants no keys")
	broken_progression = progression_fixture.duplicate(true)
	broken_progression.reward_resume_cases.pop_back()
	progression_rejected = progression_script.new().run(broken_progression)
	_expect(not progression_rejected.errors.is_empty() and progression_rejected.verified_keys.is_empty(), "missing loaded pending reward sequence grants no keys")
	broken_progression = progression_fixture.duplicate(true)
	broken_progression.reward_resume_cases.append(broken_progression.reward_resume_cases[0].duplicate(true))
	progression_rejected = progression_script.new().run(broken_progression)
	_expect(not progression_rejected.errors.is_empty() and progression_rejected.verified_keys.is_empty(), "duplicate loaded pending reward sequence grants no keys")
	broken_progression = progression_fixture.duplicate(true)
	broken_progression.cases[2].expected.construction.conveyor_belt_mk1 += 1
	var resume_id: String = broken_progression.reward_resume_cases[0].id
	var resume_item: String = broken_progression.reward_resume_cases[0].release_requests[0].itemId
	broken_progression.reward_resume_cases[0].expected.tray[resume_item] += 1
	progression_rejected = progression_script.new().run(broken_progression)
	_expect(not progression_rejected.errors.is_empty() and not progression_rejected.verified_keys.has("campaign:mine_first_ore"), "incorrect progression reward withholds its definition key")
	_expect(not progression_rejected.verified_keys.has("campaign:" + resume_id), "incorrect loaded pending reward withholds its definition key")
	var query_script := preload("res://scripts/test/ResearchQueryBehaviorRunner.gd")
	var campaign_ui_script := preload("res://scripts/test/CampaignUIBehaviorRunner.gd")
	var campaign_ui_fixture := DSPOnlineParity.read_json(campaign_ui_script.FIXTURE)
	var broken_campaign_ui := campaign_ui_fixture.duplicate(true)
	broken_campaign_ui.source_files["src/App.tsx"] = "wrong"
	var campaign_ui_rejected: Dictionary = await campaign_ui_script.new().run(broken_campaign_ui)
	_expect(not campaign_ui_rejected.errors.is_empty() and campaign_ui_rejected.verified_keys.is_empty(), "actual campaign callback source drift grants no keys")
	broken_campaign_ui = campaign_ui_fixture.duplicate(true)
	broken_campaign_ui.cases.pop_back()
	campaign_ui_rejected = await campaign_ui_script.new().run(broken_campaign_ui)
	_expect(not campaign_ui_rejected.errors.is_empty() and campaign_ui_rejected.verified_keys.is_empty(), "missing campaign route case grants no keys")
	broken_campaign_ui = campaign_ui_fixture.duplicate(true)
	broken_campaign_ui.cases.append(broken_campaign_ui.cases[0].duplicate(true))
	campaign_ui_rejected = await campaign_ui_script.new().run(broken_campaign_ui)
	_expect(not campaign_ui_rejected.errors.is_empty() and campaign_ui_rejected.verified_keys.is_empty(), "duplicate campaign route case grants no keys")
	broken_campaign_ui = campaign_ui_fixture.duplicate(true)
	broken_campaign_ui.cases.filter(func(row): return row.id == "planet_unlocked")[0].expected.activePlanetId = "home"
	campaign_ui_rejected = await campaign_ui_script.new().run(broken_campaign_ui)
	_expect(not campaign_ui_rejected.errors.is_empty() and campaign_ui_rejected.verified_keys.is_empty(), "incorrect campaign destination withholds all five workspace callback keys")
	var campaign_domain_fixture := DSPOnlineParity.read_json(preload("res://scripts/test/CampaignControlBehaviorRunner.gd").FIXTURE)
	var broken_campaign_domain := campaign_domain_fixture.duplicate(true)
	broken_campaign_domain.cases.filter(func(row): return row.id == "network_split_short")[0].before.deficits.filter(func(row): return row.id == "smelt_iron")[0].items[0].amount += 1
	campaign_ui_rejected = await campaign_ui_script.new().run({}, broken_campaign_domain)
	_expect(not campaign_ui_rejected.errors.is_empty() and campaign_ui_rejected.verified_keys.is_empty(), "incorrect actual network deficit withholds all five campaign keys")
	var query_fixture := DSPOnlineParity.read_json(query_script.FIXTURE)
	var broken_queries := query_fixture.duplicate(true)
	broken_queries.source_files["src/game/engine.ts"] = "wrong"
	var query_rejected: Dictionary = query_script.new().run(broken_queries)
	_expect(not query_rejected.errors.is_empty() and query_rejected.verified_keys.is_empty(), "research query source drift grants no keys")
	broken_queries = query_fixture.duplicate(true)
	broken_queries.cases.pop_back()
	query_rejected = query_script.new().run(broken_queries)
	_expect(not query_rejected.errors.is_empty() and query_rejected.verified_keys.is_empty(), "missing research query state grants no keys")
	broken_queries = query_fixture.duplicate(true)
	broken_queries.cases[0].expected.technologies.pop_back()
	query_rejected = query_script.new().run(broken_queries)
	_expect(not query_rejected.errors.is_empty() and query_rejected.verified_keys.is_empty(), "missing research query technology grants no keys")
	broken_queries = query_fixture.duplicate(true)
	broken_queries.cases[0].expected.active = not broken_queries.cases[0].expected.active
	query_rejected = query_script.new().run(broken_queries)
	_expect(not query_rejected.errors.is_empty() and not query_rejected.verified_keys.has(query_script.KEYS.active) and query_rejected.verified_keys.size() == 3, "incorrect active query withholds exactly its key")
	var blocked_state: GameState = query_script._state(query_fixture.cases[8].input)
	var blocked_canonical := GameStateCodec.to_persistent_dict(blocked_state)
	_expect(blocked_state.research_queue == ["dsp_mining_speed_2"] and blocked_canonical.research_queue.is_empty(), "raw blocked query queue is absent from canonical save")
	var mutate_raw_queue := func(id: String, state: GameState):
		if id == "blocked_queue_after_cancel": state.research_queue.clear()
	query_rejected = query_script.new().run(query_fixture, mutate_raw_queue)
	_expect(not query_rejected.errors.is_empty() and query_rejected.verified_keys.is_empty(), "query raw ownership mutation withholds all query keys despite equal canonical save")
	var world_command_script := preload("res://scripts/test/WorldCommandBehaviorRunner.gd")
	var world_command_fixture := DSPOnlineParity.read_json(world_command_script.FIXTURE)
	var broken_world_commands := world_command_fixture.duplicate(true)
	broken_world_commands.source_files["src/game/engine.ts"] = "wrong"
	var world_command_rejected: Dictionary = world_command_script.new().run(broken_world_commands)
	_expect(not world_command_rejected.errors.is_empty() and world_command_rejected.verified_keys.is_empty(), "world command source drift grants no keys")
	broken_world_commands = world_command_fixture.duplicate(true)
	broken_world_commands.cases.pop_back()
	world_command_rejected = world_command_script.new().run(broken_world_commands)
	_expect(not world_command_rejected.errors.is_empty() and world_command_rejected.verified_keys.is_empty(), "missing actual world command grants no keys")
	broken_world_commands = world_command_fixture.duplicate(true)
	broken_world_commands.surveys.filter(func(row): return row.stage == "overshoot")[0].clock = {"numerator": 1, "denominator": 60}
	world_command_rejected = world_command_script.new().run(broken_world_commands)
	_expect(not world_command_rejected.errors.is_empty() and world_command_rejected.verified_keys.is_empty(), "unexpected world survey clock grants no keys")
	broken_world_commands = world_command_fixture.duplicate(true)
	broken_world_commands.surveys[0].trace[0].exploration.missions = []
	world_command_rejected = world_command_script.new().run(broken_world_commands, false, func(id, state):
		if id in ["colonize-boreal_giant-ready-240721-false", "active-ashen-computed-240721-false"]:
			state.planet_inventories.home.iron_ore = float(state.planet_inventories.home.get("iron_ore", 0)) + 1
			state.research_queue.append("dsp_electromagnetic_matrix"))
	_expect(not world_command_rejected.errors.is_empty() and world_command_rejected.verified_keys.is_empty(), "wrong source survey and raw alias/unrelated drift withhold all three world command keys")
	var discard_script := preload("res://scripts/test/InventoryDiscardBehaviorRunner.gd")
	var discard_fixture := DSPOnlineParity.read_json(discard_script.FIXTURE)
	for discard_kind in ["source", "missing", "duplicate", "save_scope", "marker"]:
		var discard_case := discard_fixture.duplicate(true)
		match discard_kind:
			"source": discard_case.source_files["src/game/engine.ts"] = "wrong"
			"missing": discard_case.cases.pop_back()
			"duplicate": discard_case.cases.append(discard_case.cases[0].duplicate(true))
			"save_scope": discard_case.cases[0].save_eligible = false
			"marker": discard_case.cases[0].input.construction.wind_turbine = {"$number": "invalid"}
		var discard_check: Dictionary = discard_script.new().run(discard_case)
		_expect(not discard_check.errors.is_empty() and discard_check.verified_keys.is_empty(), "inventory discard " + discard_kind + " rejection withholds all keys")
	var broken_discard := discard_fixture.duplicate(true)
	broken_discard.cases[0].expected.tray.iron_ore += 1
	var discard_rejected: Dictionary = discard_script.new().run(broken_discard, false, func(id, state):
		if id in ["tray-iron_ore-home-partial", "construction-wind_turbine-owned"]:
			state.portable_fleet.logistics_drone += 1
			state.research_queue.append("dsp_electromagnetic_matrix"))
	_expect(not discard_rejected.errors.is_empty() and discard_rejected.verified_keys.is_empty(), "wrong source discard result and unrelated ownership drift withhold both keys")
	var effect_script := preload("res://scripts/test/EffectQueryBehaviorRunner.gd")
	_expect(effect_script._ownership_rejections().is_empty(), "all nine nested history and spatial ownership mutations are detected")
	var effect_fixture := DSPOnlineParity.read_json(effect_script.FIXTURE)
	for effect_kind in ["source", "missing", "duplicate", "input", "sub_epsilon", "negative_epsilon", "recipe"]:
		var effect_case := effect_fixture.duplicate(true)
		match effect_kind:
			"source": effect_case.source_files["src/game/engine.ts"] = "wrong"
			"missing": effect_case.cases.pop_back()
			"duplicate": effect_case.cases.append(effect_case.cases[0].duplicate(true))
			"input": effect_case.cases[0].input.levels.vein_utilization = 0.5
			"sub_epsilon": effect_case.cases[0].input.levels.vein_utilization = 5.0e-10
			"negative_epsilon": effect_case.cases[0].input.levels.vein_utilization = -5.0e-10
			"recipe": effect_case.cases[0].expected.getRecipeSpeedMultiplier.pop_back()
		var effect_check: Dictionary = effect_script.new().run(effect_case)
		_expect(not effect_check.errors.is_empty() and effect_check.verified_keys.is_empty(), "effect query " + effect_kind + " drift grants no keys")
	var broken_effect := effect_fixture.duplicate(true)
	broken_effect.cases[0].expected.getMiningSpeedMultiplier += 1
	var effect_rejected: Dictionary = effect_script.new().run(broken_effect)
	_expect(not effect_rejected.errors.is_empty() and effect_rejected.verified_keys.size() == 7 and not effect_rejected.verified_keys.has("commands:engine.getMiningSpeedMultiplier"), "wrong mining effect withholds exactly its endpoint")
	effect_rejected = effect_script.new().run({}, func(_id, state): state.planet_inventory.iron_ore = float(state.planet_inventory.get("iron_ore", 0)) + 1)
	_expect(not effect_rejected.errors.is_empty() and effect_rejected.verified_keys.is_empty(), "query inventory mutation withholds all effect endpoints")
	_expect(preload("res://scripts/test/ItemInputCapacityBehaviorRunner.gd").rejection_errors().is_empty(), "all29 per-item input capacity source/input/output/ownership rejection cases pass")
	_expect(preload("res://scripts/test/SlotCapacityBehaviorRunner.gd").rejection_errors().is_empty(), "all25 station slot capacity source/input/output/ownership rejection cases pass")
	_expect(preload("res://scripts/test/CapacityQueryBehaviorRunner.gd").rejection_errors().is_empty(), "all24 capacity source/input/output/ownership rejection cases pass")
	_expect(preload("res://scripts/test/SailLifetimeBehaviorRunner.gd").rejection_errors().is_empty(), "all 20 sail lifetime source/input/output/ownership rejection cases pass")
	var scalar_script := preload("res://scripts/test/LogisticsScalarBehaviorRunner.gd")
	var scalar_fixture := DSPOnlineParity.read_json(scalar_script.FIXTURE)
	for scalar_kind in ["source", "missing", "duplicate", "sub_epsilon", "negative_epsilon", "bool", "levels", "function"]:
		var scalar_case := scalar_fixture.duplicate(true)
		match scalar_kind:
			"source": scalar_case.source_files["src/game/engine.ts"] = "wrong"
			"missing": scalar_case.cases.pop_back()
			"duplicate": scalar_case.cases.append(scalar_case.cases[0].duplicate(true))
			"sub_epsilon": scalar_case.cases[0].input.level = 5.0e-10
			"negative_epsilon": scalar_case.cases[0].input.level = -5.0e-10
			"bool": scalar_case.cases[0].input.level = false
			"levels": scalar_case.levels[0] = 5.0e-10
			"function": scalar_case.cases[0].expected.erase("getPlanetaryTripSeconds")
		var scalar_check: Dictionary = scalar_script.new().run(scalar_case)
		_expect(not scalar_check.errors.is_empty() and scalar_check.verified_keys.is_empty(), "logistics scalar " + scalar_kind + " drift grants no keys")
	var broken_scalar := scalar_fixture.duplicate(true)
	broken_scalar.cases[0].expected.getInterstellarCargoCapacity += 1
	var scalar_rejected: Dictionary = scalar_script.new().run(broken_scalar)
	_expect(not scalar_rejected.errors.is_empty() and scalar_rejected.verified_keys.size() == 2 and not scalar_rejected.verified_keys.has("commands:engine.getInterstellarCargoCapacity"), "wrong remote cargo capacity withholds exactly its endpoint")
	scalar_rejected = scalar_script.new().run({}, func(id, state):
		if id == "standard-0-0": state.research_queue.append("dsp_mining_speed_2"))
	_expect(not scalar_rejected.errors.is_empty() and scalar_rejected.verified_keys.is_empty(), "raw blocked queue mutation withholds all logistics scalar queries")
	var route_script := preload("res://scripts/test/RouteQueryBehaviorRunner.gd")
	var route_fixture := DSPOnlineParity.read_json(route_script.FIXTURE)
	for route_kind in ["source", "noncore_module", "extra_module", "missing", "duplicate", "input", "function"]:
		var route_case := route_fixture.duplicate(true)
		match route_kind:
			"source": route_case.source_files["src/game/engine.ts"] = "wrong"
			"noncore_module": route_case.source_files.erase("src/game/galaxyCatalog.ts")
			"extra_module": route_case.source_files["src/game/unknown-route-module.ts"] = null
			"missing": route_case.cases.pop_back()
			"duplicate": route_case.cases.append(route_case.cases[0].duplicate(true))
			"input": route_case.cases[0].input.level = 5.0e-10
			"function": route_case.cases[0].expected.erase("getInterstellarTripSeconds")
		var route_check: Dictionary = route_script.new().run(route_case)
		_expect(not route_check.errors.is_empty() and route_check.verified_keys.is_empty(), "route query " + route_kind + " drift grants no keys")
	var broken_route := route_fixture.duplicate(true)
	broken_route.cases[0].expected.getInterstellarRouteEconomics.durationSeconds += 1
	var route_rejected: Dictionary = route_script.new().run(broken_route)
	_expect(not route_rejected.errors.is_empty() and route_rejected.verified_keys == ["commands:engine.getInterstellarTripSeconds"], "wrong route output withholds exactly its endpoint")
	route_rejected = route_script.new().run({}, func(id, state):
		if id == "240721-false-relaxed-0-0-planet-home": state.research_queue.append("dsp_mining_speed_2"))
	_expect(not route_rejected.errors.is_empty() and route_rejected.verified_keys.is_empty(), "raw queue mutation withholds both route queries")
	route_rejected = route_script.new().run({}, func(id, state):
		if id == "240721-false-relaxed-0-0-planet-home": state.command_history.enabled = false)
	_expect(not route_rejected.errors.is_empty() and route_rejected.verified_keys.is_empty(), "nested history mutation withholds both route queries in full harness")
	unknown.verified_keys.append("commands:unknown")
	_expect(_rejects(manifest, unknown, "unknown, excluded or duplicate behavior key"), "unknown behavior key rejected")
	for row in manifest.entries:
		if row.status != "已验证" or not behavior.proofs.has(row.key): continue
		var partial := behavior.duplicate(true)
		partial.proofs[row.key].assertions.pop_back()
		_expect(_rejects(manifest, partial, "behavior fixture drift or missing assertions"), "partial assertion proof rejected: " + row.key)
		var drift := behavior.duplicate(true)
		drift.proofs[row.key].fixture_sha256 = "wrong"
		_expect(_rejects(manifest, drift, "behavior fixture drift or missing assertions"), "stale fixture proof rejected: " + row.key)
		break

func _expect(ok: bool, message: String) -> void:
	if ok: print("PASS: " + message)
	else:
		failures += 1
		printerr("FAIL: " + message)
