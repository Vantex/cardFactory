class_name SaveSystem
extends RefCounted

const SAVE_PATH := "user://saves/"
const MAX_SAVES := 10
const SAVE_FORMAT := "card_factory_save"

var _save_path: String
var _storage_available: bool

func _init(save_path: String = SAVE_PATH) -> void:
	_save_path = save_path.strip_edges().replace("\\", "/")
	if _save_path.is_empty():
		_save_path = SAVE_PATH
	if not _save_path.ends_with("/"):
		_save_path += "/"
	_storage_available = _ensure_save_directory()

func is_storage_available() -> bool:
	return _storage_available

func save_slot(slot: int, game_state: GameState, metadata_overrides: Dictionary = {}) -> Dictionary:
	var precondition := _validate_request(slot, game_state)
	if not precondition.is_empty():
		return precondition

	var state_payload := GameStateCodec.to_persistent_dict(game_state)
	var validation_errors := GameStateValidator.validate_persistent_dict(state_payload)
	if not validation_errors.is_empty():
		return _failure_from_validation(validation_errors)

	var digest := _digest_payload(_normalize_stored_digest_types(state_payload))
	var metadata := {
		"schema_version": GameState.SCHEMA_VERSION,
		"saved_at": maxf(wall_time(), float(metadata_overrides.get("offline_processed_until", 0.0))),
		"elapsed_time": game_state.elapsed_time,
		"active_planet": game_state.active_planet_id,
		"digest": digest,
	}
	var previous := _read_slot_file(_get_slot_path(slot))
	if previous.get("ok", false):
		metadata.saved_at = maxf(float(metadata.saved_at), float(previous.metadata.saved_at))
	if metadata_overrides.has("offline_receipt"):
		metadata["offline_receipt"] = String(metadata_overrides.offline_receipt)
	var envelope := {
		"format": SAVE_FORMAT,
		"metadata": metadata,
		"state": state_payload,
	}

	var temporary_path := _get_slot_path(slot, ".tmp")
	var primary_path := _get_slot_path(slot)
	var backup_path := _get_slot_path(slot, ".bak")
	_remove_if_exists(temporary_path)
	var write_error := _write_text(temporary_path, JSON.stringify(envelope, "\t", true, true))
	if write_error != OK:
		return _failure("write_failed", "无法写入临时存档")

	var verification := _read_slot_file(temporary_path)
	if not verification.get("ok", false) or _digest_payload(_normalize_stored_digest_types(GameStateCodec.to_persistent_dict(verification.state))) != digest:
		_remove_if_exists(temporary_path)
		return _failure("verification_failed", "临时存档写入后校验失败", verification.get("error", {}))

	var primary_was_rotated := false
	if FileAccess.file_exists(primary_path):
		var existing_primary := _read_slot_file(primary_path)
		if existing_primary.get("ok", false):
			_remove_if_exists(backup_path)
			var backup_error := _rename_file(primary_path, backup_path)
			if backup_error != OK:
				_remove_if_exists(temporary_path)
				return _failure("backup_failed", "无法轮换上一份有效存档")
			primary_was_rotated = true
		else:
			_remove_if_exists(primary_path)

	var replace_error := _rename_file(temporary_path, primary_path)
	if replace_error != OK:
		if primary_was_rotated:
			_copy_file(backup_path, primary_path)
		_remove_if_exists(temporary_path)
		return _failure("replace_failed", "无法用已验证临时档替换主档")

	var committed := _read_slot_file(primary_path)
	if not committed.get("ok", false) or _digest_payload(_normalize_stored_digest_types(GameStateCodec.to_persistent_dict(committed.state))) != digest:
		return _failure("verification_failed", "主档替换后校验失败，上一份有效备份仍保留")
	return _success({"slot": slot, "metadata": metadata.duplicate(true)})

func get_recovery_sources(slot: int) -> Array:
	var sources: Array = []
	for source in ["primary", "backup", "emergency"] + _snapshot_sources(slot):
		var result := load_recovery_source(slot, source)
		sources.append({"source": source, "valid": result.get("ok", false),
			"exists": result.get("error", {}).get("code", "") != "save_not_found",
			"metadata": result.get("metadata", {}), "error": result.get("error", {})})
	return sources

func load_recovery_source(slot: int, source: String) -> Dictionary:
	var slot_error := _validate_slot(slot)
	if not slot_error.is_empty(): return slot_error
	var suffix := _recovery_suffix(source)
	if suffix == "invalid": return _failure("invalid_source", "未知恢复来源")
	var result := _read_slot_file(_get_slot_path(slot, suffix))
	if result.get("ok", false):
		result["source"] = source
		result["slot"] = slot
		result["recovered_from_backup"] = source == "backup"
	return result

func save_emergency(slot: int, state: GameState, source: String = "emergency") -> Dictionary:
	var precondition := _validate_request(slot, state)
	if not precondition.is_empty(): return precondition
	var payload := GameStateCodec.to_persistent_dict(state)
	var errors := GameStateValidator.validate_persistent_dict(payload)
	if not errors.is_empty(): return _failure_from_validation(errors)
	var metadata := {"schema_version": GameState.SCHEMA_VERSION, "saved_at": wall_time(),
		"elapsed_time": state.elapsed_time, "active_planet": state.active_planet_id,
		"digest": _digest_payload(_normalize_stored_digest_types(payload))}
	var suffix := _recovery_suffix(source)
	if suffix == "invalid" or source in ["primary", "backup"]: return _failure("invalid_source", "未知恢复来源")
	var temporary := _get_slot_path(slot, suffix + ".tmp")
	var path := _get_slot_path(slot, suffix)
	if _write_text(temporary, JSON.stringify({"format": SAVE_FORMAT, "metadata": metadata, "state": payload}, "\t", true, true)) != OK:
		return _failure("emergency_write_failed", "紧急恢复点写入失败，原恢复点仍保留")
	if not _read_slot_file(temporary).get("ok", false):
		return _failure("emergency_verification_failed", "紧急恢复点校验失败")
	# Keep the previous recovery point until a verified replacement is ready.
	if _rename_file(temporary, path) != OK:
		return _failure("emergency_replace_failed", "紧急恢复点替换失败")
	return _success({"metadata": metadata})

func load_slot(slot: int) -> Dictionary:
	var slot_error := _validate_slot(slot)
	if not slot_error.is_empty():
		return slot_error
	if not _storage_available:
		return _failure("storage_unavailable", "本地存档目录不可用")

	var primary_path := _get_slot_path(slot)
	var backup_path := _get_slot_path(slot, ".bak")
	var primary_result := _read_slot_file(primary_path)
	if primary_result.get("ok", false):
		primary_result["slot"] = slot
		primary_result["recovered_from_backup"] = false
		return primary_result

	var backup_result := _read_slot_file(backup_path)
	if backup_result.get("ok", false):
		backup_result["slot"] = slot
		backup_result["recovered_from_backup"] = true
		backup_result["primary_error"] = primary_result.get("error", {}).duplicate(true)
		_restore_primary_from_backup(primary_path, backup_path)
		return backup_result

	if primary_result.get("error", {}).get("code") == "save_not_found":
		return _failure("save_not_found", "该槽位没有存档")
	return primary_result

func delete_slot(slot: int) -> Dictionary:
	var slot_error := _validate_slot(slot)
	if not slot_error.is_empty():
		return slot_error
	if not _storage_available:
		return _failure("storage_unavailable", "本地存档目录不可用")

	var snapshots := _snapshot_sources(slot)
	for source in snapshots:
		if _remove_snapshot(slot, source) != OK: return _failure("delete_failed", "无法删除恢复快照")
	var found := not snapshots.is_empty()
	for suffix in ["", ".bak", ".tmp", ".emergency", ".emergency.tmp", ".offline", ".offline.bak", ".offline.tmp"]:
		var path := _get_slot_path(slot, suffix)
		if not FileAccess.file_exists(path):
			continue
		found = true
		var remove_error := DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
		if remove_error != OK:
			return _failure("delete_failed", "无法删除槽位文件")
	if not found:
		return _failure("save_not_found", "该槽位没有存档")
	return _success({"slot": slot})

func get_slot_info(slot: int) -> Dictionary:
	var load_result := load_recovery_source(slot, "primary")
	if not load_result.get("ok", false):
		load_result = load_recovery_source(slot, "backup")
	if not load_result.get("ok", false):
		load_result = load_recovery_source(slot, "emergency")
	if not load_result.get("ok", false):
		for source in _snapshot_sources(slot):
			load_result = load_recovery_source(slot, source)
			if load_result.get("ok", false): break
	if not load_result.get("ok", false):
		for source in get_recovery_sources(slot):
			if source.get("exists", false): return {"slot": slot, "valid": false, "error": source.get("error", {})}
	if not load_result.get("ok", false):
		return {}
	var metadata: Dictionary = load_result.get("metadata", {}).duplicate(true)
	var state: GameState = load_result.get("state")
	metadata["slot"] = slot
	metadata["valid"] = true
	metadata["recovery_only"] = load_result.get("source", "primary") not in ["primary", "backup"]
	metadata["building_count"] = state.buildings.size()
	metadata["connection_count"] = state.connections.size()
	metadata["recovered_from_backup"] = load_result.get("recovered_from_backup", false)
	return metadata

func get_all_saves() -> Array:
	var saves: Array = []
	for slot in range(MAX_SAVES):
		var info := get_slot_info(slot)
		if not info.is_empty():
			saves.append(info)
	return saves

func has_save(slot: int) -> bool:
	return not get_slot_info(slot).is_empty()

# Compatibility wrappers for old callers. New session code uses structured slot results.
func save_game(slot: int, game_state: GameState) -> bool:
	return save_slot(slot, game_state).get("ok", false)

func load_game(slot: int, game_state: GameState) -> bool:
	var result := load_slot(slot)
	if not result.get("ok", false):
		return false
	var loaded_state: GameState = result["state"]
	game_state.install_state(loaded_state)
	return true

func delete_save(slot: int) -> bool:
	return delete_slot(slot).get("ok", false)

func get_save_info(slot: int) -> Dictionary:
	return get_slot_info(slot)

func validate_save(slot: int) -> bool:
	return load_slot(slot).get("ok", false)

func get_save_size(slot: int) -> int:
	var file_path := _get_slot_path(slot)
	if not FileAccess.file_exists(file_path):
		return 0
	var file := FileAccess.open(file_path, FileAccess.READ)
	if file == null:
		return 0
	var file_size := file.get_length()
	file.close()
	return file_size

# Online and compression services are explicitly outside the current single-player scope.
func sync_to_cloud(_slot: int) -> Error:
	return ERR_UNAVAILABLE

func backup_to_cloud(_slot: int) -> Error:
	return ERR_UNAVAILABLE

func restore_from_cloud(_slot: int) -> Error:
	return ERR_UNAVAILABLE

func compress_save(_slot: int) -> Error:
	return ERR_UNAVAILABLE

func decompress_save(_slot: int) -> Error:
	return ERR_UNAVAILABLE

func migrate_save(_from_slot: int, _to_slot: int) -> Error:
	return ERR_UNAVAILABLE

func _read_slot_file(path: String) -> Dictionary:
	if not FileAccess.file_exists(path):
		return _failure("save_not_found", "存档文件不存在")
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return _failure("read_failed", "无法读取存档文件")
	var text := file.get_as_text()
	file.close()
	var json := JSON.new()
	if json.parse(text) != OK:
		return _failure("invalid_json", "存档文件不是有效 JSON")
	if not json.data is Dictionary:
		return _failure("invalid_envelope", "存档根节点格式无效")

	var envelope: Dictionary = json.data
	var state_payload: Variant
	var metadata: Dictionary
	var has_envelope := envelope.has("state") or envelope.has("metadata") or envelope.has("format")
	if has_envelope:
		if envelope.get("format") != SAVE_FORMAT or not envelope.get("metadata") is Dictionary or not envelope.get("state") is Dictionary:
			return _failure("invalid_envelope", "存档封装格式无效")
		state_payload = envelope["state"]
		metadata = envelope["metadata"].duplicate(true)
		var metadata_error := _validate_metadata(metadata)
		if not metadata_error.is_empty():
			return metadata_error
	else:
		state_payload = envelope
		var legacy_version: Variant = envelope.get("schema_version", 0)
		metadata = {
			"schema_version": int(legacy_version) if legacy_version is int or legacy_version is float else 0,
			"saved_at": envelope.get("timestamp", 0.0),
			"elapsed_time": envelope.get("elapsed_time", 0.0),
			"active_planet": "home",
			"digest": "",
		}

	if has_envelope:
		var stored_version: Variant = state_payload.get("schema_version", 0)
		if not _is_integral_number(stored_version) or int(stored_version) < 0 or int(stored_version) > GameState.SCHEMA_VERSION:
			var version_result := SaveMigrationRegistry.migrate_to_current(state_payload)
			return _failure_from_validation(version_result.get("errors", []))
		var expected_stored_digest := String(metadata.get("digest", ""))
		var actual_stored_digest := _digest_payload(_normalize_stored_digest_types(state_payload))
		if expected_stored_digest.is_empty() or expected_stored_digest != actual_stored_digest:
			return _failure("digest_mismatch", "存档摘要校验失败")

	var migration_result := SaveMigrationRegistry.migrate_to_current(state_payload)
	if not migration_result.get("ok", false):
		return _failure_from_validation(migration_result.get("errors", []))
	var migrated_payload: Dictionary = migration_result["data"]
	var decoded_state := GameStateCodec.from_persistent_dict(migrated_payload)
	if decoded_state == null:
		return _failure("decode_failed", "存档状态无法恢复")

	var actual_digest := _digest_payload(migrated_payload)
	metadata["source_schema_version"] = metadata.get("schema_version", 0)
	metadata["schema_version"] = GameState.SCHEMA_VERSION
	metadata["elapsed_time"] = decoded_state.elapsed_time
	metadata["digest"] = actual_digest
	metadata["active_planet"] = decoded_state.active_planet_id
	return _success({"state": decoded_state, "metadata": metadata})

func _restore_primary_from_backup(primary_path: String, backup_path: String) -> void:
	var temporary_path := primary_path + ".tmp"
	_remove_if_exists(temporary_path)
	if _copy_file(backup_path, temporary_path) != OK:
		return
	if not _read_slot_file(temporary_path).get("ok", false):
		_remove_if_exists(temporary_path)
		return
	_remove_if_exists(primary_path)
	_rename_file(temporary_path, primary_path)

func _copy_file(source_path: String, destination_path: String) -> Error:
	var source := FileAccess.open(source_path, FileAccess.READ)
	if source == null:
		return FileAccess.get_open_error()
	var contents := source.get_buffer(source.get_length())
	source.close()
	var destination := FileAccess.open(destination_path, FileAccess.WRITE)
	if destination == null:
		return FileAccess.get_open_error()
	destination.store_buffer(contents)
	destination.flush()
	destination.close()
	return OK

func _write_text(path: String, contents: String) -> Error:
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		return FileAccess.get_open_error()
	file.store_string(contents)
	file.flush()
	file.close()
	return OK

func _rename_file(source_path: String, destination_path: String) -> Error:
	return DirAccess.rename_absolute(ProjectSettings.globalize_path(source_path), ProjectSettings.globalize_path(destination_path))

func _remove_if_exists(path: String) -> void:
	if FileAccess.file_exists(path):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(path))

func _get_slot_path(slot: int, suffix: String = "") -> String:
	return _save_path + "save_%d.json%s" % [slot, suffix]

func _validate_request(slot: int, game_state: GameState) -> Dictionary:
	var slot_error := _validate_slot(slot)
	if not slot_error.is_empty():
		return slot_error
	if not _storage_available:
		return _failure("storage_unavailable", "本地存档目录不可用")
	if game_state == null:
		return _failure("invalid_state", "没有可保存的游戏状态")
	return {}

func _validate_slot(slot: int) -> Dictionary:
	if slot < 0 or slot >= MAX_SAVES:
		return _failure("invalid_slot", "存档槽位必须在 0 到 %d 之间" % (MAX_SAVES - 1))
	return {}

func _validate_metadata(metadata: Dictionary) -> Dictionary:
	var schema_version: Variant = metadata.get("schema_version")
	if not _is_integral_number(schema_version) or int(schema_version) < 0:
		return _failure("invalid_metadata", "存档元数据版本无效")
	var saved_at: Variant = metadata.get("saved_at")
	if not _is_number(saved_at) or float(saved_at) < 0.0:
		return _failure("invalid_metadata", "存档保存时间无效")
	var elapsed_time: Variant = metadata.get("elapsed_time")
	if not _is_number(elapsed_time) or float(elapsed_time) < 0.0:
		return _failure("invalid_metadata", "存档游玩时长无效")
	var active_planet: Variant = metadata.get("active_planet")
	if (typeof(active_planet) != TYPE_STRING and typeof(active_planet) != TYPE_STRING_NAME) or String(active_planet).is_empty():
		return _failure("invalid_metadata", "存档活动行星无效")
	if typeof(metadata.get("digest")) != TYPE_STRING or String(metadata.get("digest")).is_empty():
		return _failure("invalid_metadata", "存档摘要元数据无效")
	return {}

func _ensure_save_directory() -> bool:
	var absolute_path := ProjectSettings.globalize_path(_save_path.trim_suffix("/"))
	if DirAccess.dir_exists_absolute(absolute_path):
		return true
	return DirAccess.make_dir_recursive_absolute(absolute_path) == OK

func _digest_payload(payload: Dictionary) -> String:
	return JSON.stringify(payload).sha256_text()

func _normalize_stored_digest_types(payload: Dictionary) -> Dictionary:
	var normalized := payload.duplicate(true)
	# JSON numbers decode as floats. Use that representation for belt integers;
	# existing successfully saved float-valued records retain their digest.
	var buildings: Variant = normalized.get("buildings")
	if buildings is Dictionary:
		for building in buildings.values():
			if building is Dictionary:
				for field in ["power_priority", "generation_priority", "stored_energy_mj"]:
					if _is_number(building.get(field)): building[field] = float(building[field])
	var connections: Variant = normalized.get("connections")
	if connections is Dictionary:
		for connection in connections.values():
			if connection is Dictionary:
				for field in ["priority", "parallel_count", "stack_size"]:
					if _is_integral_number(connection.get(field)):
						connection[field] = float(connection[field])
	LogisticsStateValidator.normalize_integer_fields(normalized)
	DysonStateValidator.normalize_integer_fields(normalized)
	EndgameStateValidator.normalize_integer_fields(normalized)
	for integer_field in ["schema_version", "next_id", "construction_points", "galaxy_seed"]:
		var field_value: Variant = normalized.get(integer_field)
		if _is_integral_number(field_value):
			normalized[integer_field] = int(field_value)
	var handcraft_queue_value: Variant = normalized.get("handcraft_queue")
	if handcraft_queue_value is Array:
		for job_value in handcraft_queue_value:
			if not job_value is Dictionary:
				continue
			for quantity_field in ["quantity_total", "quantity_remaining"]:
				var quantity_value: Variant = job_value.get(quantity_field)
				if _is_integral_number(quantity_value):
					job_value[quantity_field] = int(quantity_value)
	var technology_levels_value: Variant = normalized.get("technology_levels")
	if technology_levels_value is Dictionary:
		for technology_id_value in technology_levels_value:
			var level_value: Variant = technology_levels_value[technology_id_value]
			if _is_integral_number(level_value):
				technology_levels_value[technology_id_value] = int(level_value)
	var portable_fleet_value: Variant = normalized.get("portable_fleet")
	if portable_fleet_value is Dictionary:
		for fleet_item_id in portable_fleet_value:
			var fleet_amount: Variant = portable_fleet_value[fleet_item_id]
			if _is_integral_number(fleet_amount):
				portable_fleet_value[fleet_item_id] = int(fleet_amount)
	var resource_sites_value: Variant = normalized.get("resource_sites")
	if resource_sites_value is Dictionary:
		for site_id in resource_sites_value:
			var site: Variant = resource_sites_value[site_id]
			if not site is Dictionary:
				continue
			for reserve_field in ["capacity", "remaining"]:
				if _is_integral_number(site.get(reserve_field)):
					site[reserve_field] = int(site[reserve_field])
	return normalized

func _is_number(value: Variant) -> bool:
	return typeof(value) == TYPE_INT or typeof(value) == TYPE_FLOAT

func _is_integral_number(value: Variant) -> bool:
	return _is_number(value) and float(value) == floor(float(value))

func _success(values: Dictionary = {}) -> Dictionary:
	var result := {"ok": true, "error": {}}
	result.merge(values, true)
	return result

func _failure(code: String, message: String, cause: Dictionary = {}) -> Dictionary:
	var error := {"code": code, "source": "save_system", "message": message}
	if not cause.is_empty():
		error["cause"] = cause.duplicate(true)
	return {"ok": false, "error": error}

func _failure_from_validation(errors: Array) -> Dictionary:
	if errors.is_empty() or not errors[0] is Dictionary:
		return _failure("invalid_state", "存档状态校验失败")
	var first_error: Dictionary = errors[0]
	return _failure(String(first_error.get("code", "invalid_state")), String(first_error.get("message", "存档状态校验失败")), first_error)

func wall_time() -> float:
	return Time.get_unix_time_from_system()

func settlement_path(slot: int) -> String:
	return _get_slot_path(slot, ".offline") if _validate_slot(slot).is_empty() else ""
func _recovery_suffix(source: String) -> String:
	var fixed := {"primary": "", "backup": ".bak", "emergency": ".emergency"}
	if fixed.has(source): return fixed[source]
	var number := source.trim_prefix("snapshot_")
	if source.begins_with("snapshot_") and number.is_valid_int() and int(number) > 0 and str(int(number)) == number:
		return "." + source
	return "invalid"

func _snapshot_sources(slot: int) -> Array:
	var sources: Array = []
	if not _validate_slot(slot).is_empty(): return sources
	var directory := DirAccess.open(_save_path)
	if directory == null: return sources
	var prefix := "save_%d.json." % slot
	for file in directory.get_files():
		if not file.begins_with(prefix): continue
		var source := file.trim_prefix(prefix)
		if source.begins_with("snapshot_") and _recovery_suffix(source) != "invalid": sources.append(source)
	sources.sort()
	sources.reverse()
	return sources

func create_snapshot(slot: int, state: GameState) -> Dictionary:
	var id := int(wall_time() * 1000000)
	while FileAccess.file_exists(_get_slot_path(slot, ".snapshot_%d" % id)): id += 1
	var source := "snapshot_%d" % id
	var result := save_emergency(slot, state, source)
	if result.get("ok", false): result["source"] = source
	return result

func delete_snapshots(slot: int, sources: Array) -> Dictionary:
	if not _validate_slot(slot).is_empty(): return _validate_slot(slot)
	for source in sources:
		if not source is String or not source.begins_with("snapshot_") or _recovery_suffix(source) == "invalid":
			return _failure("invalid_source", "只能删除明确选择的恢复快照")
	var remaining := 0
	for candidate in get_recovery_sources(slot):
		if candidate.valid and not sources.has(candidate.source): remaining += 1
	if remaining == 0: return _failure("last_recovery_point", "不能删除最后一份有效恢复点")
	var deleted: Array = []
	for source in sources:
		if _remove_snapshot(slot, source) != OK:
			return _failure("delete_failed", "部分快照删除失败，请刷新检查", {"deleted": deleted})
		deleted.append(source)
	return _success({"deleted": deleted})

func _remove_snapshot(slot: int, source: String) -> Error:
	return DirAccess.remove_absolute(ProjectSettings.globalize_path(_get_slot_path(slot, _recovery_suffix(source))))
