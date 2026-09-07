class_name OfflineSettlementJournal
extends RefCounted

var storage: SaveSystem
var slot: int
var path: String

func _init(save_system: SaveSystem, slot_id: int) -> void:
	storage = save_system
	slot = slot_id
	path = storage.settlement_path(slot)

func read() -> Dictionary:
	if path.is_empty(): return _failure("invalid_slot")
	var primary := _read(path)
	if primary.ok: return primary
	var backup := _read(path + ".bak")
	if backup.ok: return backup
	if not FileAccess.file_exists(path) and not FileAccess.file_exists(path + ".bak"):
		return {"ok": true, "entry": {}}
	return _failure("journal_corrupt")

func write(entry: Dictionary) -> Dictionary:
	if path.is_empty(): return _failure("invalid_slot")
	var body := entry.duplicate(true)
	var envelope := {"entry": body, "digest": _digest(body)}
	storage._remove_if_exists(path + ".tmp")
	if storage._write_text(path + ".tmp", JSON.stringify(envelope, "", true, true)) != OK: return _failure("journal_write_failed")
	if not _read(path + ".tmp").ok: return _failure("journal_verification_failed")
	var rotated := false
	if FileAccess.file_exists(path):
		storage._remove_if_exists(path + ".bak")
		if storage._rename_file(path, path + ".bak") != OK: return _failure("journal_rotate_failed")
		rotated = true
	if storage._rename_file(path + ".tmp", path) != OK:
		if rotated: storage._copy_file(path + ".bak", path)
		return _failure("journal_replace_failed")
	return {"ok": true}

func clear() -> Dictionary:
	if path.is_empty(): return _failure("invalid_slot")
	for suffix in ["", ".tmp", ".bak"]:
		if FileAccess.file_exists(path + suffix) and DirAccess.remove_absolute(ProjectSettings.globalize_path(path + suffix)) != OK:
			return _failure("journal_delete_failed")
	return {"ok": true}

func _read(file_path: String) -> Dictionary:
	var file := FileAccess.open(file_path, FileAccess.READ)
	if file == null: return _failure("journal_missing")
	var json := JSON.new()
	if json.parse(file.get_as_text()) != OK: return _failure("journal_corrupt")
	var parsed: Variant = json.data
	if not parsed is Dictionary or not parsed.get("entry") is Dictionary: return _failure("journal_corrupt")
	var entry: Dictionary = parsed.entry
	if parsed.get("digest") != _digest(entry) or entry.get("version") != 1 or entry.get("slot") != slot or entry.get("phase") not in ["pending", "prepared"]:
		return _failure("journal_corrupt")
	for key in ["base_digest", "receipt"]:
		if not entry.get(key) is String or entry[key].length() != 64: return _failure("journal_corrupt")
	for key in ["base_time", "target_time", "actual_seconds"]:
		if not _number(entry.get(key)) or float(entry[key]) < 0: return _failure("journal_corrupt")
	if entry.target_time < entry.base_time or not _number(entry.get("ticks")) or float(entry.ticks) != floorf(float(entry.ticks)) or entry.ticks < 0 or entry.ticks > 7200:
		return _failure("journal_corrupt")
	if not entry.get("clock_rollback") is bool: return _failure("journal_corrupt")
	if entry.phase == "prepared":
		if not entry.get("result") is Dictionary or not entry.get("report") is Dictionary or GameStateCodec.from_persistent_dict(entry.result) == null:
			return _failure("journal_corrupt")
	entry.ticks = int(entry.ticks)
	return {"ok": true, "entry": entry}

static func _digest(value: Dictionary) -> String:
	return JSON.stringify(JSON.parse_string(JSON.stringify(value, "", true, true)), "", true, true).sha256_text()

static func _number(value: Variant) -> bool:
	return (value is int or value is float) and is_finite(float(value))

static func _failure(code: String) -> Dictionary:
	return {"ok": false, "error": {"code": code, "message": "离线事务记录不可用，原存档保留，请检查磁盘后重试"}}
