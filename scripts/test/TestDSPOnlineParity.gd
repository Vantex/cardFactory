extends Node

var failures := 0

func _ready() -> void:
	var path := DSPOnlineParity.ROOT + "dsponline_single_player_manifest.json"
	var complete := false
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--parity-manifest="): path = argument.trim_prefix("--parity-manifest=")
		if argument == "--parity-require-complete": complete = true
	var manifest := DSPOnlineParity.read_json(path)
	var errors := DSPOnlineParity.validate(manifest, complete)
	_expect(errors.is_empty(), "parity registration: " + str(errors.slice(0, 5)))
	if not complete and not manifest.is_empty(): _test_rejections(manifest)
	if failures == 0:
		print("DSPONLINE PARITY TESTS PASSED")
	else:
		printerr("DSPONLINE PARITY TESTS FAILED")
	get_tree().quit(0 if failures == 0 else 1)

func _test_rejections(manifest: Dictionary) -> void:
	_expect(not DSPOnlineParity.validate(manifest, true).is_empty(), "release mode refuses documented gaps")
	var broken := manifest.duplicate(true)
	broken.entries.pop_back()
	_expect(not DSPOnlineParity.validate(broken).is_empty(), "missing catalog row rejected")
	broken = manifest.duplicate(true)
	broken.entries.append(broken.entries[0])
	_expect(not DSPOnlineParity.validate(broken).is_empty(), "duplicate ID rejected")
	broken = manifest.duplicate(true)
	broken.entries[0].rule_test = "absent"
	_expect(not DSPOnlineParity.validate(broken).is_empty(), "missing rule case rejected")
	broken = manifest.duplicate(true)
	broken.entries[0].status = "在线排除"
	_expect(not DSPOnlineParity.validate(broken).is_empty(), "unapproved exclusion rejected")
	broken = manifest.duplicate(true)
	broken.entries[0].status = "已验证"
	_expect(not DSPOnlineParity.validate(broken).is_empty(), "paper-only verified claim rejected")
	broken = manifest.duplicate(true)
	broken.entries[0].target = {"category": "items", "ids": ["nonexistent_item"]}
	_expect(not DSPOnlineParity.validate(broken).is_empty(), "nonexistent target rejected")
	broken = manifest.duplicate(true)
	broken.source_commit = "wrong"
	_expect(not DSPOnlineParity.validate(broken).is_empty(), "wrong source revision rejected")
	broken = manifest.duplicate(true)
	broken.entries[0].erase("gap")
	_expect(not DSPOnlineParity.validate(broken).is_empty(), "unexplained gap rejected")

func _expect(ok: bool, message: String) -> void:
	if ok: print("PASS: " + message)
	else:
		failures += 1
		printerr("FAIL: " + message)
