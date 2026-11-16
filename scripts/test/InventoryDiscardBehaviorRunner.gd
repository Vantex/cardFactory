extends RefCounted

const FIXTURE := "res://tests/fixtures/parity/behavior/task27-inventory-discard.json"
const KEYS := {"tray": "commands:engine.discardPlanetTrayItems", "construction": "commands:engine.discardConstructionInventory"}
const TRAY_STAGES := ["partial", "exact", "overshoot", "fractional_request", "negative", "zero", "below_one", "duplicates", "mixed_invalid", "empty"]
const CONSTRUCTION_STAGES := ["owned", "one", "zero", "missing", "fractional", "below_one", "negative", "nan", "infinity"]
var errors: Array[String] = []
var claims := {}
var disk_saves := 0

func run(fixture_override: Dictionary = {}, save_round_trips: bool = false, after_command: Callable = Callable()) -> Dictionary:
	errors.clear()
	claims.clear()
	disk_saves = 0
	var fixture := DSPOnlineParity.read_json(FIXTURE) if fixture_override.is_empty() else fixture_override
	var source := DSPOnlineParity.read_json(DSPOnlineParity.ROOT + "dsponline_source_catalog.json")
	if fixture.get("source_commit") != source.source.commit or not fixture.get("source_files") is Dictionary: return _reject("discard source provenance missing")
	for file in ["src/game/engine.ts", "src/game/content.ts", "src/game/storage.ts"]:
		if not fixture.source_files.has(file): return _reject("discard source module missing")
	for file in fixture.source_files:
		if fixture.source_files[file] != source.source.files.get(file): return _reject("discard source hash drift")
	var controls := preload("res://scripts/test/WorldControlBehaviorRunner.gd")
	if not fixture.get("items") is Array or not controls._same_ids(fixture.items, source.catalog.items.map(func(row): return row.id)): return _reject("discard item coverage incomplete")
	if not fixture.get("constructions") is Array or not controls._same_ids(fixture.constructions, source.catalog.construction.map(func(row): return row.id)): return _reject("discard construction coverage incomplete")
	if not fixture.get("planets") is Array or not controls._same_ids(fixture.planets, SourceGalaxySystem.catalog().planets.keys()): return _reject("discard planet coverage incomplete")
	var wanted := {}
	for item in fixture.items:
		for planet in ["home", "ashen"]:
			for stage in TRAY_STAGES: wanted["tray-%s-%s-%s" % [item, planet, stage]] = ["tray", planet, true]
	for planet in fixture.planets: wanted["tray-all-worlds-" + planet] = ["tray", planet, true]
	for stage in ["unknown_planet", "missing_remote", "empty_remote", "unknown_item", "no_owned_amount", "fractional_stock"]:
		wanted["tray-special-" + stage] = ["tray", "unknown_planet" if stage == "unknown_planet" else "home" if stage in ["unknown_item", "no_owned_amount", "fractional_stock"] else "ashen", true]
	for item in fixture.constructions:
		for stage in CONSTRUCTION_STAGES: wanted["construction-%s-%s" % [item, stage]] = ["construction", item, stage in ["owned", "one", "zero", "missing"]]
	wanted["construction-unknown"] = ["construction", "unknown_construction", true]
	if not fixture.get("cases") is Array or not controls._same_ids(fixture.cases.map(func(row): return row.get("id")), wanted.keys()): return _reject("discard cases missing duplicated or unknown")
	for row in fixture.cases:
		if not row.get("command") is Dictionary or row.command.get("kind") != wanted[row.id][0] or row.command.get("target") != wanted[row.id][1] or row.get("save_eligible") != wanted[row.id][2]: return _reject("discard command or save scope changed")
		if row.command.kind == "tray" and not row.command.get("requests") is Array: return _reject("discard request batch missing")
		if not _valid_numbers(row): return _reject("discard nonfinite marker malformed")
		for field in ["input", "expected", "repeated", "loaded_after"]:
			if not row.get(field) is Dictionary or not row[field].get("tray") is Dictionary or not row[field].get("planetTrays") is Dictionary or not row[field].get("construction") is Dictionary or not row[field].get("portableFleet") is Dictionary: return _reject("discard ownership evidence incomplete")
	var fractional: Dictionary = fixture.cases.filter(func(row): return row.id == "tray-special-fractional_stock")[0]
	if not controls._same_value(fractional.input.tray.iron_ore, 7.9) or fractional.expected.tray.iron_ore != 4 or fractional.repeated.tray.iron_ore != 1 or fractional.command.requests != [{"itemId": "iron_ore", "amount": 3.0}]: return _reject("declared fractional conservation adaptation changed")
	var root := "res://.godot/task27-inventory-discard-%d-%d/" % [OS.get_process_id(), Time.get_ticks_usec()]
	for row in fixture.cases:
		var state := _state(row.input, fixture.initial)
		var before := _untouched(state)
		var other_stock := _unselected(state, row.command)
		var original := _domain(state)
		_invoke(state, row.command, false)
		_check(row.command.kind, _same(_domain(state), original) and _same(_untouched(state), before), row.id + ": unconfirmed deletion changes no ownership")
		_invoke(state, row.command, true)
		if after_command.is_valid(): after_command.call(row.id, state)
		_check(row.command.kind, _same(_domain(state), _expected(row, "expected")), row.id + ": actual immutable source command ownership agrees")
		_check(row.command.kind, _same(_untouched(state), before) and _same(_unselected(state, row.command), other_stock), row.id + ": other stacks fleet entities targets and raw aliases retained")
		var repeated := state.copy_state()
		var repeated_before := _untouched(repeated)
		_invoke(repeated, row.command, true)
		_check(row.command.kind, _same(_domain(repeated), _expected(row, "repeated")), row.id + ": repeated deletion uses the remaining owned stock")
		_check(row.command.kind, _same(_untouched(repeated), repeated_before) and _same(_unselected(repeated, row.command), other_stock), row.id + ": repeat retains unrelated ownership")
		if not row.save_eligible: continue
		var persistent := GameStateCodec.to_persistent_dict(state.copy_state())
		var decoded := GameStateCodec.from_persistent_dict(persistent)
		_check(row.command.kind, decoded != null and _exact(GameStateCodec.to_persistent_dict(decoded.copy_state()), persistent), row.id + ": local codec preserves exact persistent command result")
		_check(row.command.kind, decoded != null and _same(_stored_domain(_domain(decoded)), _stored_domain(_expected(row, "loaded_after"))), row.id + ": raw source storage inventory ownership agrees with declared conservation adaptation")
		if save_round_trips:
			var storage := SaveSystem.new(root + row.id + "/")
			var saved := storage.save_slot(0, state)
			_check(row.command.kind, saved.ok, row.id + ": actual verified disk save succeeds " + str(saved.get("error", {})))
			_check(row.command.kind, _same(_untouched(state), before) and _same(_unselected(state, row.command), other_stock), row.id + ": saving leaves unrelated live ownership intact")
			if saved.ok:
				disk_saves += 1
				var loaded := storage.load_recovery_source(0, "primary")
				_check(row.command.kind, loaded.ok and _exact(GameStateCodec.to_persistent_dict(loaded.state.copy_state()), persistent), row.id + ": real disk reopening preserves exact persistent command result")
				_check(row.command.kind, loaded.ok and _same(_stored_domain(_domain(loaded.state)), _stored_domain(_expected(row, "loaded_after"))), row.id + ": disk reopening agrees with original source storage inventory ownership")
	var keys := []
	var proofs := {}
	for key in claims:
		if claims[key].failures.is_empty():
			keys.append(key)
			proofs[key] = {"suite": "task27-inventory-discard", "fixture": FIXTURE, "fixture_sha256": FileAccess.get_sha256(FIXTURE), "assertions": claims[key].assertions.duplicate()}
	return {"errors": errors.duplicate(), "verified_keys": keys, "proofs": proofs, "claims": claims.duplicate(true), "disk_saves": disk_saves}

static func _local_id(id: String) -> String:
	return id if id.begins_with("conveyor_belt_") or id.begins_with("sorter_") else "dsp_" + id

static func _state(input: Dictionary, initial: Dictionary) -> GameState:
	var state := GameState.new()
	SourceGalaxySystem.new(state).initialize(240721, false)
	state.source_galaxy = initial.galaxy.duplicate(true)
	state.explored_system_ids = initial.exploration.unlockedSystemIds.duplicate()
	state.colonized_planet_ids = initial.exploration.colonizedPlanetIds.duplicate()
	state.survey_progress_by_system = initial.exploration.surveyProgressBySystem.duplicate(true)
	state.active_planet_id = input.activePlanetId
	state.planet_inventory = input.tray.duplicate(true)
	state.planet_inventories = input.planetTrays.duplicate(true)
	state.planet_inventories[state.active_planet_id] = state.planet_inventory
	state.portable_fleet = input.portableFleet.duplicate(true)
	state.construction_inventory = {}
	for id in input.construction: state.construction_inventory[_local_id(id)] = _decode(input.construction[id])
	return state

static func _invoke(state: GameState, command: Dictionary, confirmed: bool) -> void:
	if command.kind == "construction":
		var system := ConstructionSystem.new(state)
		if system.has_method("discard_inventory"): system.call("discard_inventory", _local_id(command.target), confirmed)
	else:
		var system := PlanetTraySystem.new(state)
		var requests: Array = _decode(command.requests)
		if system.has_method("discard_batch"): system.call("discard_batch", command.target, requests, confirmed)
		else:
			for request in requests:
				if request.amount is int or request.amount is float: system.discard(command.target, request.itemId, float(request.amount), confirmed)

static func _domain(state: GameState) -> Dictionary:
	var construction := {}
	for id in state.construction_inventory:
		var amount: Variant = state.construction_inventory[id]
		if amount != 0: construction[String(id).trim_prefix("dsp_")] = _encode(amount)
	return {"activePlanetId": state.active_planet_id, "tray": state.planet_inventory.duplicate(true), "planetTrays": state.planet_inventories.duplicate(true), "portableFleet": state.portable_fleet.duplicate(true), "construction": construction}

static func _expected(row: Dictionary, field: String) -> Dictionary:
	var value: Dictionary = row[field].duplicate(true)
	for id in value.construction.keys():
		if (value.construction[id] is int or value.construction[id] is float) and value.construction[id] == 0: value.construction.erase(id)
	if row.id == "tray-special-fractional_stock":
		var remainder := float(row.input.tray.iron_ore) - floorf(float(row.input.tray.iron_ore))
		value.tray.iron_ore = float(value.tray.iron_ore) + remainder
		value.planetTrays.home.iron_ore = value.tray.iron_ore
	return value

static func _stored_domain(value: Dictionary) -> Dictionary:
	var result := value.duplicate(true)
	for planet in SourceGalaxySystem.catalog().planets:
		if not result.planetTrays.has(planet): result.planetTrays[planet] = {}
	return result

static func _unselected(state: GameState, command: Dictionary) -> Dictionary:
	var value := {"tray": state.planet_inventory.duplicate(true), "planetTrays": state.planet_inventories.duplicate(true), "construction": _encode(state.construction_inventory)}
	if command.kind == "construction": value.construction.erase(_local_id(command.target))
	else:
		var allowed := []
		for request in command.requests:
			if request.get("itemId") is String and DataManager.all_items.has(request.itemId): allowed.append(request.itemId)
		if command.target == state.active_planet_id:
			for item in allowed: value.tray.erase(item)
		if value.planetTrays.has(command.target):
			for item in allowed: value.planetTrays[command.target].erase(item)
	return value

static func _untouched(state: GameState) -> Dictionary:
	var excluded := ["planet_inventory", "planet_inventories", "construction_inventory", "_source_catalog_cache"]
	var persistent := GameStateCodec.to_persistent_dict(state.copy_state())
	for field in excluded: persistent.erase(field)
	var raw := {}
	for property in state.get_property_list():
		if (int(property.usage) & PROPERTY_USAGE_SCRIPT_VARIABLE) == 0 or property.name in excluded: continue
		var value: Variant = state.get(property.name)
		raw[property.name] = value.duplicate(true) if value is Dictionary or value is Array else value
	return {"raw": raw, "canonical": persistent}

static func _valid_numbers(value: Variant) -> bool:
	if value is Dictionary:
		if value.has("$number"): return value.size() == 1 and value["$number"] in ["NaN", "Infinity", "-Infinity"]
		for entry in value.values():
			if not _valid_numbers(entry): return false
	elif value is Array:
		for entry in value:
			if not _valid_numbers(entry): return false
	return true

static func _decode(value: Variant) -> Variant:
	if value is Dictionary:
		if value.has("$number"): return NAN if value["$number"] == "NaN" else INF if value["$number"] == "Infinity" else -INF
		var result := {}
		for key in value: result[key] = _decode(value[key])
		return result
	if value is Array: return value.map(func(entry): return _decode(entry))
	return value

static func _encode(value: Variant) -> Variant:
	if value is float and not is_finite(value): return {"$number": "NaN" if is_nan(value) else "Infinity" if value > 0 else "-Infinity"}
	if value is Dictionary:
		var result := {}
		for key in value: result[key] = _encode(value[key])
		return result
	if value is Array: return value.map(func(entry): return _encode(entry))
	return value

static func _same(left: Variant, right: Variant) -> bool:
	return preload("res://scripts/test/WorldControlBehaviorRunner.gd")._same_value(left, right)

static func _exact(left: Variant, right: Variant) -> bool:
	if left is Dictionary and right is Dictionary:
		if left.size() != right.size(): return false
		for key in left:
			if not right.has(key) or not _exact(left[key], right[key]): return false
		return true
	if left is Array and right is Array:
		if left.size() != right.size(): return false
		for index in range(left.size()):
			if not _exact(left[index], right[index]): return false
		return true
	return left == right

func _check(kind: String, ok: bool, assertion: String) -> void:
	var key: String = KEYS[kind]
	if not claims.has(key): claims[key] = {"assertions": [], "failures": []}
	claims[key].assertions.append(assertion)
	if not ok:
		claims[key].failures.append(assertion)
		errors.append(key + ": " + assertion)

static func _reject(message: String) -> Dictionary:
	return {"errors": [message], "verified_keys": [], "proofs": {}, "claims": {}, "disk_saves": 0}
