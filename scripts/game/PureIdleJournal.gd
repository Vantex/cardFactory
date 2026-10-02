class_name PureIdleJournal
extends OfflineSettlementJournal

func _init(save_system: SaveSystem, slot_id: int) -> void:
	super(save_system, slot_id)
	if not path.is_empty(): path += ".pure"

func _read(file_path: String) -> Dictionary:
	var file := FileAccess.open(file_path, FileAccess.READ)
	if file == null: return _failure("journal_missing")
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	if not parsed is Dictionary or not parsed.get("entry") is Dictionary: return _failure("journal_corrupt")
	var entry: Dictionary = parsed.entry
	if parsed.get("digest") != _digest(entry) or entry.get("version") != 1 or entry.get("slot") != slot or entry.get("phase") not in ["pending", "prepared"]: return _failure("journal_corrupt")
	for key in ["base_digest", "receipt"]:
		if not entry.get(key) is String or entry[key].length() != 64: return _failure("journal_corrupt")
	for key in ["base_time", "target_time", "actual_seconds"]:
		if not _number(entry.get(key)) or float(entry[key]) < 0: return _failure("journal_corrupt")
	if entry.target_time < entry.base_time or entry.get("mode") not in ["stable", "extreme"]: return _failure("journal_corrupt")
	if entry.phase == "prepared":
		if not entry.get("result") is Dictionary or not entry.get("report") is Dictionary or GameStateCodec.from_persistent_dict(entry.result) == null: return _failure("journal_corrupt")
		if entry.result.get("pure_idle", {}).get("last_receipt") != entry.receipt: return _failure("journal_corrupt")
	return {"ok": true, "entry": entry}
