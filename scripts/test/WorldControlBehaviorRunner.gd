extends RefCounted

const FIXTURE := "res://tests/fixtures/parity/behavior/task27-world-controls.json"
const SUITE := "task27-world-controls"
const KEYS := {"role": "commands:engine.setPlanetIndustryRole", "planetMetadata": "commands:engine.setPlanetDisplayMetadata", "systemName": "commands:engine.setStarSystemDisplayName", "limit": "commands:engine.setPlanetTrayItemLimit"}
const METADATA_STAGES := ["basic", "empty", "whitespace", "unicode_space", "control_characters", "exact", "overflow", "truncated_duplicate", "emoji_even", "emoji_odd", "emoji_collision", "replacement_collision", "capped_collision", "tags_only", "note_only", "non_string_tags"]
const NAME_STAGES := ["basic", "empty", "whitespace", "unicode_space", "control_characters", "exact", "overflow", "emoji_even", "emoji_odd"]
const LIMIT_STAGES := ["minimum", "maximum", "fractional", "too_low", "negative", "zero", "too_high", "repeat", "nonfinite", "nan", "negative_infinity"]
var errors: Array[String] = []
var claims := {}
var disk_saves := 0

func run(fixture_override: Dictionary = {}, save_round_trips: bool = true, after_command: Callable = Callable()) -> Dictionary:
	errors.clear()
	claims.clear()
	disk_saves = 0
	var fixture := DSPOnlineParity.read_json(FIXTURE) if fixture_override.is_empty() else fixture_override
	var source := DSPOnlineParity.read_json(DSPOnlineParity.ROOT + "dsponline_source_catalog.json")
	if fixture.get("source_commit") != source.source.commit or not fixture.get("source_files") is Dictionary: return _reject("world controls provenance missing")
	for file in ["src/game/engine.ts", "src/game/galaxy.ts", "src/game/storage.ts"]:
		if not fixture.source_files.has(file): return _reject("world controls source module missing")
	for file in fixture.source_files:
		if fixture.source_files[file] != source.source.files.get(file): return _reject("world controls source drift")
	var catalog := SourceGalaxySystem.catalog()
	var wanted := ["role-unknown", "metadata-unknown", "name-unknown", "limit-unknown"]
	for planet in catalog.planets:
		for role in SourceGalaxySystem.ROLES: wanted.append("role-" + planet + "-" + role)
		wanted.append("role-repeat-" + planet)
		wanted.append("role-invalid-" + planet)
		for stage in METADATA_STAGES: wanted.append("metadata-" + planet + "-" + stage)
		for stage in LIMIT_STAGES: wanted.append("limit-" + planet + "-" + stage)
	for system in catalog.systems:
		for stage in NAME_STAGES: wanted.append("name-" + system + "-" + stage)
	if not fixture.get("cases") is Array or not _same_ids(fixture.cases.map(func(row): return row.id), wanted): return _reject("world controls cases missing duplicated or unknown")
	var root := "res://.godot/task27-world-controls-%d-%d/" % [OS.get_process_id(), Time.get_ticks_usec()]
	for row in fixture.cases:
		for pair in [["expected_source_utf16", "expected"], ["repeated_source_utf16", "repeated"], ["loaded_source_utf16", "loaded_after"]]:
			if not row.get(pair[0]) is Dictionary or not _valid_unit_tree(row[pair[0]]): return _reject("world controls original source UTF16 evidence missing or invalid")
			var projected: Dictionary = _portable_unit_tree(row[pair[0]])
			if projected != {"planetMetadata": row[pair[1]].planetMetadata, "systemMetadata": row[pair[1]].systemMetadata}: return _reject("world controls portable projection disagrees with original source units")
		var state := _state(row.before)
		var kind: String = row.command.kind
		if not KEYS.has(kind): return _reject("unknown world control kind")
		var before := _untouched(state)
		_invoke(state, row.command)
		_check(kind, _domain(state) == row.expected, row.id + ": actual source portable command result; original UTF16 units retained in fixture")
		if after_command.is_valid(): after_command.call(row.id, state)
		_check(kind, _untouched(state) == before, row.id + ": complete unrelated persistent ownership retained")
		_invoke(state, row.command)
		_check(kind, _domain(state) == row.repeated, row.id + ": actual repeated source command result")
		_check(kind, _untouched(state) == before, row.id + ": repeated command preserves unrelated ownership")
		var decoded := GameStateCodec.from_persistent_dict(GameStateCodec.to_persistent_dict(state.copy_state()))
		_check(kind, decoded != null and _domain(decoded) == row.loaded_after, row.id + ": actual source storage migration agrees with local codec")
		if save_round_trips:
			var storage := SaveSystem.new(root + row.id + "/")
			var saved := storage.save_slot(0, state)
			_check(kind, saved.ok, row.id + ": actual disk save succeeds")
			_check(kind, _untouched(state) == before, row.id + ": saving preserves unrelated raw and persistent ownership")
			if saved.ok:
				disk_saves += 1
				var loaded := storage.load_recovery_source(0, "primary")
				_check(kind, loaded.ok and _domain(loaded.state) == row.loaded_after, row.id + ": verified disk reload matches actual source storage")
				_check(kind, loaded.ok and _same_value(_untouched(loaded.state).canonical, before.canonical), row.id + ": disk preserves all unrelated persistent ownership")
	var keys := []
	var proofs := {}
	for key in claims:
		if claims[key].failures.is_empty():
			keys.append(key)
			proofs[key] = {"suite": SUITE, "fixture": FIXTURE, "fixture_sha256": FileAccess.get_sha256(FIXTURE), "assertions": claims[key].assertions.duplicate()}
	return {"errors": errors.duplicate(), "verified_keys": keys, "proofs": proofs, "claims": claims.duplicate(true), "disk_saves": disk_saves}

static func _state(before: Dictionary) -> GameState:
	var state := GameState.new()
	SourceGalaxySystem.new(state).initialize(240721, false)
	state.source_galaxy.planetRoles = before.roles.duplicate(true)
	state.source_galaxy.planetMetadata = before.planetMetadata.duplicate(true)
	state.source_galaxy.systemMetadata = before.systemMetadata.duplicate(true)
	state.planet_tray_limits = before.limits.duplicate(true)
	return state

static func _invoke(state: GameState, command: Dictionary) -> void:
	var system := SourceGalaxySystem.new(state)
	match String(command.kind):
		"role": system.set_role(command.target, command.value)
		"planetMetadata": system.set_metadata(command.target, command.value.customName, command.value.note, command.value.tags)
		"systemName": system.set_metadata(command.target, command.value, "", [], true)
		"limit":
			var value: float = float(command.value) if command.value is int or command.value is float else INF if command.value == "Infinity" else -INF if command.value == "-Infinity" else NAN
			PlanetTraySystem.new(state).set_limit(command.target, value)

static func _domain(state: GameState) -> Dictionary:
	return {"roles": state.source_galaxy.planetRoles.duplicate(true), "planetMetadata": state.source_galaxy.planetMetadata.duplicate(true), "systemMetadata": state.source_galaxy.systemMetadata.duplicate(true), "limits": state.planet_tray_limits.duplicate(true)}

static func _untouched(state: GameState) -> Dictionary:
	var payload := GameStateCodec.to_persistent_dict(state.copy_state())
	for field in ["planetRoles", "planetMetadata", "systemMetadata"]: payload.source_galaxy.erase(field)
	payload.erase("planet_tray_limits")
	var raw := {}
	for property in state.get_property_list():
		if (int(property.usage) & PROPERTY_USAGE_SCRIPT_VARIABLE) == 0: continue
		var field: String = property.name
		if field in ["planet_tray_limits", "_source_catalog_cache"]: continue
		var value: Variant = state.get(field)
		raw[field] = value.duplicate(true) if value is Dictionary or value is Array else value
	for field in ["planetRoles", "planetMetadata", "systemMetadata"]: raw.source_galaxy.erase(field)
	return {"raw": raw, "canonical": payload}

static func _same_ids(actual: Array, expected: Array) -> bool:
	var left := actual.duplicate()
	var right := expected.duplicate()
	left.sort()
	right.sort()
	return left == right

static func _same_value(left: Variant, right: Variant) -> bool:
	if (left is int or left is float) and (right is int or right is float): return absf(float(left) - float(right)) <= 0.000000001
	if left is Dictionary and right is Dictionary:
		if left.size() != right.size(): return false
		for key in left:
			if not right.has(key) or not _same_value(left[key], right[key]): return false
		return true
	if left is Array and right is Array:
		if left.size() != right.size(): return false
		for index in range(left.size()):
			if not _same_value(left[index], right[index]): return false
		return true
	return left == right

static func _valid_unit_tree(value: Variant) -> bool:
	if value is Dictionary:
		if value.size() == 1 and value.has("utf16"):
			if not value.utf16 is Array: return false
			for unit in value.utf16:
				if not (unit is int or unit is float) or not is_finite(float(unit)) or float(unit) != floorf(float(unit)) or float(unit) < 0 or float(unit) > 65535: return false
			return true
		for entry in value.values():
			if not _valid_unit_tree(entry): return false
		return true
	if value is Array:
		for entry in value:
			if not _valid_unit_tree(entry): return false
		return true
	return false

static func _portable_unit_tree(value: Variant) -> Variant:
	if value is Dictionary:
		if value.size() == 1 and value.has("utf16"):
			var units: Array = value.utf16
			var text := ""
			var index := 0
			while index < units.size():
				var unit := int(units[index])
				if unit >= 55296 and unit <= 56319 and index + 1 < units.size() and int(units[index + 1]) >= 56320 and int(units[index + 1]) <= 57343:
					text += String.chr(65536 + ((unit - 55296) << 10) + int(units[index + 1]) - 56320)
					index += 2
				else:
					text += "�" if unit >= 55296 and unit <= 57343 else String.chr(unit)
					index += 1
			return text
		var result := {}
		for key in value: result[key] = _portable_unit_tree(value[key])
		return result
	if value is Array:
		var result := []
		for entry in value: result.append(_portable_unit_tree(entry))
		return result
	return value

func _check(kind: String, ok: bool, assertion: String) -> void:
	var key: String = KEYS[kind]
	if not claims.has(key): claims[key] = {"assertions": [], "failures": []}
	claims[key].assertions.append(assertion)
	if not ok:
		claims[key].failures.append(assertion)
		errors.append(key + ": " + assertion)

static func _reject(message: String) -> Dictionary:
	return {"errors": [message], "verified_keys": [], "proofs": {}, "claims": {}, "disk_saves": 0}
