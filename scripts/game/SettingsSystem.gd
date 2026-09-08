class_name SettingsSystem
extends Node

signal changed

const DEFAULTS := {"theme": "dark", "font_scale": 1.0, "density": "compact", "invert_zoom": false, "cursor_speed": 1.0}
var values: Dictionary = DEFAULTS.duplicate()
var path := "user://device_settings.cfg"
var load_error := ""

func _init(storage_path: String = "user://device_settings.cfg") -> void:
	path = storage_path

func _ready() -> void:
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--device-settings="): path = argument.trim_prefix("--device-settings=")
	load_preferences()

func validate(candidate: Dictionary) -> bool:
	if candidate.size() != DEFAULTS.size(): return false
	for key in DEFAULTS:
		if not candidate.has(key): return false
	return candidate.theme in ["dark", "light"] and candidate.density in ["compact", "comfortable"] and candidate.invert_zoom is bool and _in_range(candidate.font_scale, 0.8, 2.0) and _in_range(candidate.cursor_speed, 0.5, 2.0)

func _in_range(value: Variant, minimum: float, maximum: float) -> bool:
	return (value is int or value is float) and is_finite(float(value)) and float(value) >= minimum and float(value) <= maximum

func load_preferences() -> bool:
	var config := ConfigFile.new()
	var error := config.load(path)
	if error == ERR_FILE_NOT_FOUND: return true
	var candidate := {}
	if error == OK and config.get_value("device", "version", 0) == 1:
		for key in DEFAULTS: candidate[key] = config.get_value("device", key, DEFAULTS[key])
	if error != OK or not validate(candidate):
		load_error = "设备设置损坏或版本不兼容，已保留默认设置。"
		return false
	values = candidate
	load_error = ""
	changed.emit()
	return true

func update_preferences(patch: Dictionary) -> Dictionary:
	var candidate := values.duplicate()
	for key in patch:
		if not DEFAULTS.has(key): return {"ok": false, "message": "未知的设备设置"}
		candidate[key] = patch[key]
	if not validate(candidate): return {"ok": false, "message": "设置值超出允许范围"}
	var config := ConfigFile.new()
	config.set_value("device", "version", 1)
	for key in candidate: config.set_value("device", key, candidate[key])
	if config.save(path + ".tmp") != OK: return {"ok": false, "message": "设备设置无法写入，请检查目录权限。"}
	var check := ConfigFile.new()
	if check.load(path + ".tmp") != OK: return {"ok": false, "message": "设备设置写入校验失败"}
	var backup := path + ".bak"
	if FileAccess.file_exists(path):
		if FileAccess.file_exists(backup) and DirAccess.remove_absolute(backup) != OK:
			return {"ok": false, "message": "设备设置备份无法更新"}
		if DirAccess.rename_absolute(path, backup) != OK: return {"ok": false, "message": "设备设置无法备份"}
	if DirAccess.rename_absolute(path + ".tmp", path) != OK:
		if FileAccess.file_exists(backup): DirAccess.rename_absolute(backup, path)
		return {"ok": false, "message": "设备设置无法替换，原设置保留"}
	values = candidate
	load_error = ""
	changed.emit()
	return {"ok": true}
