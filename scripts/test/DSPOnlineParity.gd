class_name DSPOnlineParity
extends RefCounted

const ROOT := "res://tests/fixtures/parity/"
const STATUSES := ["未实现", "实现中", "已验证", "在线排除"]

static func read_json(path: String) -> Dictionary:
	var parser := JSON.new()
	if parser.parse(FileAccess.get_file_as_string(path)) != OK or not parser.data is Dictionary: return {}
	return parser.data

static func validate(manifest: Dictionary, require_complete: bool = false, verified_behavior_keys: Array = []) -> Array[String]:
	var errors: Array[String] = []
	var source := read_json(ROOT + "dsponline_source_catalog.json")
	var cases := read_json(ROOT + "rule_cases.json")
	var exclusions := read_json(ROOT + "exclusions.json")
	if source.is_empty() or cases.is_empty() or exclusions.is_empty():
		return ["missing frozen catalog, rule cases or exclusions"]
	var expected_hash := FileAccess.get_file_as_string(ROOT + "dsponline_source_catalog.sha256").strip_edges()
	if FileAccess.get_sha256(ROOT + "dsponline_source_catalog.json") != expected_hash:
		errors.append("source checksum mismatch")
	if manifest.get("format_version") != 1 or manifest.get("source_commit") != source.get("source", {}).get("commit"):
		errors.append("manifest version or source commit mismatch")
	if not manifest.get("entries") is Array: return ["missing entries"]
	var expected := {}
	for category in source.get("catalog", {}):
		var entries: Array = source.catalog[category]
		if entries.size() != int(source.get("counts", {}).get(category, -1)): errors.append("source count mismatch: " + category)
		for entry in entries:
			var key: String = category + ":" + String(entry.id)
			if expected.has(key): errors.append("duplicate source key: " + key)
			expected[key] = entry
	var online: Dictionary = exclusions.get("online", {})
	var scope: Dictionary = exclusions.get("scope", {})
	for key in online:
		if not expected.has(key) or String(online[key].get("reason", "")).is_empty(): errors.append("invalid online whitelist key: " + key)
	for key in scope:
		if not expected.has(key) or scope[key].get("policy") != "desktop_chinese_only" or String(scope[key].get("reason", "")).is_empty(): errors.append("invalid scope exclusion: " + key)
	var seen := {}
	var seen_rules := {}
	var targets := _target_catalogs()
	for value in manifest.entries:
		if not value is Dictionary:
			errors.append("invalid row")
			continue
		var row: Dictionary = value
		var key := String(row.get("key", ""))
		if seen.has(key) or not expected.has(key) or scope.has(key):
			errors.append("duplicate, unknown or excluded row: " + key)
			continue
		seen[key] = true
		var category := String(row.get("category", ""))
		if key != category + ":" + String(row.get("source_id", "")) or row.get("source_definition") != key:
			errors.append("invalid source reference: " + key)
		var status := String(row.get("status", ""))
		if status not in STATUSES: errors.append("invalid status: " + key)
		if (status == "在线排除") != online.has(key): errors.append("unregistered online exclusion: " + key)
		if int(row.get("owner_task", 0)) < 20 or int(row.get("owner_task", 0)) > 26: errors.append("missing owner task: " + key)
		if String(row.get("gap", "")).is_empty() or row.get("manual_acceptance") != "manual:" + key or String(row.get("ui_entry", "")).is_empty(): errors.append("missing gap, manual acceptance or UI: " + key)
		var rule_id := String(row.get("rule_test", ""))
		if rule_id != "rule:" + key or not cases.has(rule_id):
			errors.append("missing rule case: " + key)
		else:
			seen_rules[rule_id] = true
			var rule: Dictionary = cases[rule_id]
			if rule.get("source_key") != key or rule.get("owner_task") != row.get("owner_task") or not rule.get("acceptance") is Array or rule.acceptance.is_empty(): errors.append("invalid rule case: " + key)
			if status == "已验证" and (not verified_behavior_keys.has(key) or not rule.get("behavior_verified", false)):
				errors.append("behavior evidence missing: " + key)
		if not row.get("target") is Dictionary or not row.target.get("ids") is Array:
			errors.append("missing explicit mapping: " + key)
			continue
		var mapping: Dictionary = row.target
		if status in ["实现中", "已验证"] and mapping.ids.is_empty(): errors.append("implemented row has no target: " + key)
		for id in mapping.ids:
			if mapping.get("category") == "file":
				if not id is String or not String(id).begins_with("scenes/") or not FileAccess.file_exists("res://" + String(id)): errors.append("missing target file: " + key)
			elif mapping.get("category") == "symbol":
				var parts := String(id).split("::")
				if parts.size() != 2 or not FileAccess.file_exists("res://" + parts[0]) or not FileAccess.get_file_as_string("res://" + parts[0]).contains("func " + parts[1] + "("):
					errors.append("missing target symbol: " + key)
			elif not targets.get(mapping.get("category", ""), {}).has(id): errors.append("missing target data: " + key)
		if require_complete and status != "在线排除" and status != "已验证": errors.append("unresolved parity: " + key)
	for key in expected:
		if not seen.has(key) and not scope.has(key): errors.append("unregistered missing row: " + key)
	for rule_id in cases:
		if not seen_rules.has(rule_id): errors.append("orphan rule case: " + rule_id)
	return errors

static func _target_catalogs() -> Dictionary:
	var progress := read_json("res://data/progression.json")
	var objectives := {}
	var achievements := {}
	for row in progress.get("objectives", []): objectives[row.id] = row
	for row in progress.get("achievements", []): achievements[row.id] = row
	return {"items": DataManager.get_all_items(), "recipes": DataManager.get_all_recipes(), "buildings": DataManager.get_all_buildings(), "technologies": DataManager.get_all_technologies(), "campaign": objectives, "achievements": achievements}
