extends RefCounted

const FIXTURE := "res://tests/fixtures/parity/behavior/task27-resource-install.json"
const SHA := "367aedf59ee0af33d412064289a0937c1888defcc813f2d36ce168ee3f36931d"
const KEY := "commands:engine.installMiner"
const OUTPUT := preload("res://scripts/game/SourceResourceOutputSystem.gd")
const OWNER := preload("res://scripts/test/EffectQueryBehaviorRunner.gd")
var errors := []
var assertions := []

func run(fixture_override: Dictionary = {}, save_roundtrips: bool = false) -> Dictionary:
	errors.clear()
	assertions.clear()
	if FileAccess.get_sha256(FIXTURE) != SHA: return _reject("resource install fixture drift")
	var original := DSPOnlineParity.read_json(FIXTURE)
	var fixture := original if fixture_override.is_empty() else fixture_override
	if JSON.stringify(fixture, "", true, true) != JSON.stringify(original, "", true, true): return _reject("resource install source/input/output drift")
	var catalog := DSPOnlineParity.read_json(DSPOnlineParity.ROOT + "dsponline_source_catalog.json")
	if fixture.source_commit != catalog.source.commit or fixture.cases.size() != 703: return _reject("resource install provenance/coverage drift")
	for file in fixture.source_files:
		if fixture.source_files[file] != catalog.source.files.get(file): return _reject("resource install source module drift")
	if not FileAccess.file_exists("res://scripts/game/SourceMinerSystem.gd"): return _reject("source grouped miner installation is unavailable")
	var system = load("res://scripts/game/SourceMinerSystem.gd")
	var checked := {}
	var saves := 0
	var root := "res://.godot/task27-resource-install-%d/" % OS.get_process_id()
	for row in fixture.cases:
		if checked.has(row.id): return _reject("resource install duplicate case")
		checked[row.id] = true
		var state := GameState.new()
		state.emit_canvas_events = false
		SourceGalaxySystem.new(state).initialize(240721, false)
		state.completed_technologies = DataManager.all_technologies.keys().filter(func(id): return String(id).begins_with("dsp_"))
		state.explored_system_ids = SourceGalaxySystem.catalog().systems.keys()
		for explored in state.explored_system_ids: state.survey_progress_by_system[explored] = 1.0
		var planets := PlanetSystem.new(state)
		for planet in [row.input.planet, row.input.active]: planets.ensure_colonized_planet_records(planet)
		state.set_active_planet(row.input.active)
		planets.initialize_colonized_resource_sites()
		var site: Dictionary = {}
		for candidate in planets.get_planet_resource_sites(row.input.planet):
			if candidate.item_id == row.input.item: site = state.resource_sites[candidate.id]; break
		_check(not site.is_empty(), row.id + ": actual resource point")
		if site.is_empty(): continue
		site.output_buffer = {row.input.item: 7.0}
		site.progress = 0.25
		site.interaction_locked = row.input.locked
		var type := "dsp_" + String(row.input.extractor)
		state.construction_inventory[type] = row.input.funding
		var current: Variant = _decode(row.input.current)
		if not (current is int or current is float) or current != 0:
			state.add_building({"type": type, "position": site.position, "planet_id": site.planet_id, "resource_site_id": site.id, "output_item": row.input.item, "machine_count": current, "status": "idle", "recipe_id": "", "input_buffer": {}, "output_buffer": {}, "progress": 0.25, "speed": DataManager.get_building(type).speed})
		var target := String(site.id)
		if row.input.entity_kind in ["missing", "wrong-kind"]: target = "not-a-resource-point"
		elif row.input.entity_kind == "no-resource": site.item_id = ""
		var before := OWNER._ownership(state)
		var result: Dictionary = system.new(state).install(target, _decode(row.input.requested))
		var after := OWNER._ownership(state)
		_check(result.ok == not row.returned_original, row.id + ": public success/rejection matches frozen command")
		var stock := float(site.output_buffer.get(row.input.item, 0))
		for building in OUTPUT.extractors(state, String(site.id)): stock += float(building.output_buffer.get(row.input.item, 0))
		var actual := {"count": _count(state, site), "construction": state.construction_inventory[type], "output": stock, "progress": site.progress, "remaining": site.remaining, "remainder": site.get("depletion_remainder", 0), "active": state.active_planet_id}
		# Source ocean reserves are zero in native state and remain zero, rather than manufacturing stock.
		for field in ["count", "construction", "output", "progress", "active"]:
			_check(JSON.stringify(_encode(actual[field])) == JSON.stringify(row.expected[field]), row.id + ": frozen " + field)
		_check(site.remaining == before.raw.fields.resource_sites[site.id].remaining and site.get("depletion_remainder", 0) == before.raw.fields.resource_sites[site.id].get("depletion_remainder", 0), row.id + ": reserve and carry unchanged")
		if row.returned_original: _check(JSON.stringify(_encode(before), "", true, true) == JSON.stringify(_encode(after), "", true, true), row.id + ": rejected command preserves every raw and canonical owner")
		var old_fields: Dictionary = before.raw.fields.duplicate(true)
		var new_fields: Dictionary = after.raw.fields.duplicate(true)
		for fields in [old_fields, new_fields]:
			fields.erase("buildings")
			fields.erase("_next_id")
			fields.construction_inventory.erase(type)
		_check(JSON.stringify(_encode(old_fields), "", true, true) == JSON.stringify(_encode(new_fields), "", true, true), row.id + ": unrelated persistent fields unchanged")
		var old_buildings: Dictionary = before.raw.fields.buildings
		for id in old_buildings:
			var old_building: Dictionary = old_buildings[id].duplicate(true)
			var new_building: Dictionary = after.raw.fields.buildings[id].duplicate(true)
			for building in [old_building, new_building]: building.erase("machine_count")
			_check(JSON.stringify(_encode(old_building), "", true, true) == JSON.stringify(_encode(new_building), "", true, true), row.id + ": existing buffer/configuration retained " + id)
		if save_roundtrips and (row.input.current is int or row.input.current is float) and (row.input.requested is int or row.input.requested is float) and row.input.current == 0 and row.input.requested == 3 and row.input.funding == 3 and not row.input.locked and row.input.entity_kind == "vein" and not String(row.id).begins_with("remote-"):
			var storage := SaveSystem.new(root + row.id + "/")
			var saved := storage.save_slot(0, state)
			var reopened := storage.load_recovery_source(0, "primary") if saved.ok else {}
			_check(saved.ok and reopened.get("ok", false) and preload("res://scripts/test/CapacityQueryBehaviorRunner.gd")._exact(GameStateCodec.to_persistent_dict(reopened.state), JSON.parse_string(JSON.stringify(GameStateCodec.to_persistent_dict(state), "", true, true))), row.id + ": actual paid group primary roundtrip " + JSON.stringify(saved.get("error", {})))
			if reopened.get("ok", false): saves += 1
	var keys := [KEY] if errors.is_empty() and checked.size() == 703 else []
	var proofs := {}
	if not keys.is_empty(): proofs[KEY] = {"suite": "task27-resource-install", "fixture": FIXTURE, "fixture_sha256": SHA, "assertions": assertions.duplicate()}
	return {"errors": errors.duplicate(), "verified_keys": keys, "proofs": proofs, "claims": {KEY: {"assertions": assertions.duplicate(), "failures": errors.duplicate()}}, "cases": checked.size(), "saves": saves}

static func _count(state: GameState, site: Dictionary) -> Variant:
	var count := 0.0
	for building in OUTPUT.extractors(state, String(site.id)): count += float(building.get("machine_count", 1))
	return count

static func _decode(value: Variant) -> Variant:
	if value is Dictionary and value.has("$number"):
		return NAN if value["$number"] == "NaN" else INF
	return value

static func _encode(value: Variant) -> Variant:
	if value is float and not is_finite(value): return {"$number": "NaN" if is_nan(value) else "Infinity"}
	if value is Dictionary:
		var result := {}
		for key in value: result[key] = _encode(value[key])
		return result
	if value is Array: return value.map(_encode)
	return value

func _check(ok: bool, label: String) -> void:
	assertions.append(label)
	if not ok: errors.append(label)

func _reject(message: String) -> Dictionary:
	return {"errors": [message], "verified_keys": [], "proofs": {}, "claims": {}, "cases": 0, "saves": 0}
