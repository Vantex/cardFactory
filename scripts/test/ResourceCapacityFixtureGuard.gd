extends RefCounted

const FIXTURE := "res://tests/fixtures/parity/behavior/task27-resource-initial-capacity.json"
const SHA256 := "5bec2f902e4e452253a8678e8d85bbb2af478c7a7548a274ab7e46facad0170c"
const EXACT := preload("res://scripts/test/CapacityQueryBehaviorRunner.gd")

static func validation_errors(value: Variant) -> Array:
	var bytes := FileAccess.get_file_as_string(FIXTURE)
	if bytes.sha256_text() != SHA256: return ["initial capacity frozen bytes drift"]
	var reference: Variant = JSON.parse_string(bytes)
	if not value is Dictionary or not EXACT._exact(value, reference): return ["initial capacity input/output drift"]
	var catalog := DSPOnlineParity.read_json(DSPOnlineParity.ROOT + "dsponline_source_catalog.json")
	if value.get("source_commit") != catalog.get("source", {}).get("commit"): return ["initial capacity source commit drift"]
	for file in value.source_files:
		if value.source_files[file] != catalog.source.files.get(file): return ["initial capacity source hash drift"]
	return []

static func load_fixture() -> Dictionary:
	var value := DSPOnlineParity.read_json(FIXTURE)
	var errors := validation_errors(value)
	for error in errors: printerr("FAIL: " + error)
	return value if errors.is_empty() else {}

static func rejection_errors() -> Dictionary:
	var value := load_fixture()
	if value.is_empty(): return {"errors": ["initial capacity original fixture rejected"], "rejected": 0}
	var errors := []
	var rejected := 0
	for kind in ["commit", "source", "module", "missing", "duplicate", "id", "seed", "baseline", "source_seed", "vein", "vein_id", "planet", "item", "position", "capacity", "remaining", "snapshot", "empty", "shape"]:
		var broken := value.duplicate(true)
		match kind:
			"commit": broken.source_commit = "wrong"
			"source": broken.source_files["src/game/engine.ts"] = "wrong"
			"module": broken.source_files.erase("src/game/galaxyCatalog.ts")
			"missing": broken.cases.pop_back()
			"duplicate": broken.cases.append(broken.cases[0].duplicate(true))
			"id": broken.cases[0].id = "wrong"
			"seed": broken.cases[0].input.seed = true
			"baseline": broken.cases[0].input.preserve_baseline = 1
			"source_seed": broken.cases[0].source_seed += 1
			"vein": broken.cases[0].veins.pop_back()
			"vein_id": broken.cases[0].veins[0].id = "wrong"
			"planet": broken.cases[0].veins[0].planet = "wrong"
			"item": broken.cases[0].veins[0].item = "wrong"
			"position": broken.cases[0].veins[0].position = {}
			"capacity": broken.cases[0].veins[0].initial_capacity = false
			"remaining": broken.cases[0].veins[0].initial_remaining = null
			"snapshot": broken.cases[0].veins[0].snapshot.remainingRatio = 0.5
			"empty": broken.cases = []
			"shape": broken = {}
		if validation_errors(broken).is_empty(): errors.append("initial capacity accepts drift " + kind)
		else: rejected += 1
	return {"errors": errors, "rejected": rejected}
