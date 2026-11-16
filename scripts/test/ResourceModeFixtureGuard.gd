extends RefCounted

const FIXTURES := {
	"query": ["res://tests/fixtures/parity/behavior/task27-resource-reserve-query.json", "b63d6a2fb9ecdff26a1545459f914f270e7cc76f7a9decaa35773682484e0ed0"],
	"flow": ["res://tests/fixtures/parity/behavior/task27-resource-mode-flow.json", "10fbef7b7480f9c85d3b25aca2a1c6d274bce74f996484e3b69e0a189a035421"],
	"manual": ["res://tests/fixtures/parity/behavior/task27-manual-reserve.json", "8412eab41eb16b9a41529a2f2f6d2d0fd3de2e23c3099c0c5cdb2bd14c1473c5"],
}

static func validation_errors(value: Variant, label: String) -> Array:
	if not FIXTURES.has(label) or not value is Dictionary: return ["resource mode fixture shape or label"]
	if JSON.stringify(value, "", true, true).sha256_text() != FIXTURES[label][1]: return ["resource mode frozen input/output drift"]
	var catalog := DSPOnlineParity.read_json(DSPOnlineParity.ROOT + "dsponline_source_catalog.json")
	if value.get("source_commit") != catalog.get("source", {}).get("commit"): return ["resource mode source commit drift"]
	for file in value.source_files:
		if value.source_files[file] != catalog.source.files.get(file): return ["resource mode source hash drift"]
	return []

static func load_fixture(label: String) -> Dictionary:
	if not FIXTURES.has(label): return {}
	var value := DSPOnlineParity.read_json(FIXTURES[label][0])
	var errors := validation_errors(value, label)
	for error in errors: printerr("FAIL: " + error)
	return value if errors.is_empty() else {}

static func rejection_errors() -> Dictionary:
	var errors := []
	var rejected := 0
	for label in FIXTURES:
		var value := load_fixture(label)
		if value.is_empty():
			errors.append(label + ": original frozen fixture rejected")
			continue
		for kind in ["commit", "source", "module", "missing", "duplicate", "row", "id", "input", "remaining", "expected", "empty", "shape"]:
			var broken := value.duplicate(true)
			match kind:
				"commit": broken.source_commit = "wrong"
				"source": broken.source_files["src/game/engine.ts"] = "wrong"
				"module": broken.source_files.erase("src/game/galaxyCatalog.ts")
				"missing": broken.cases.pop_back()
				"duplicate": broken.cases.append(broken.cases[0].duplicate(true))
				"row": broken.cases[0] = []
				"id": broken.cases[0].id = "wrong"
				"input": broken.cases[0].input = {}
				"remaining": broken.cases[0].input.remaining = true
				"expected":
					if label == "flow": broken.cases[0].stages[0].expected.output = true
					else: broken.cases[0].expected = {}
				"empty": broken.cases = []
				"shape": broken = {}
			if validation_errors(broken, label).is_empty(): errors.append(label + ": accepts drift " + kind)
			else: rejected += 1
	return {"errors": errors, "rejected": rejected}
