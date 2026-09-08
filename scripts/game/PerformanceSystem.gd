class_name PerformanceSystem
extends RefCounted

const MAX_SAMPLES := 3600
const MAX_METRICS := 48
var game_state: GameState
var enabled := false
var _samples: Dictionary = {}
var _counts: Dictionary = {}
var _cursor: Dictionary = {}
var _context: Dictionary = {}

func _init(state: GameState = null) -> void:
	game_state = state

func start(context: Dictionary = {}) -> void:
	_samples.clear()
	_counts.clear()
	_cursor.clear()
	_context = context.duplicate(true)
	_context.merge({"gpu": RenderingServer.get_video_adapter_name(), "os": OS.get_name(), "cpu": OS.get_processor_name(), "godot": Engine.get_version_info().string, "display": DisplayServer.get_name(), "renderer": RenderingServer.get_current_rendering_method()}, false)
	enabled = true

func stop() -> void:
	enabled = false

func begin() -> int:
	return Time.get_ticks_usec() if enabled else 0

func finish(metric: String, started: int) -> void:
	if enabled and started > 0:
		record(metric, float(Time.get_ticks_usec() - started) / 1000.0)

func record(metric: String, value: float) -> void:
	if not enabled or not is_finite(value) or value < 0.0:
		return
	if not _samples.has(metric):
		if _samples.size() >= MAX_METRICS: return
		_samples[metric] = []
		_counts[metric] = 0
		_cursor[metric] = 0
	var samples: Array = _samples[metric]
	if samples.size() < MAX_SAMPLES:
		samples.append(value)
	else:
		samples[int(_cursor[metric])] = value
		_cursor[metric] = (int(_cursor[metric]) + 1) % MAX_SAMPLES
	_counts[metric] += 1

func get_report() -> Dictionary:
	var metrics := {}
	for key in _samples:
		var values: Array = _samples[key].duplicate()
		values.sort()
		var total := 0.0
		for value in values: total += float(value)
		metrics[key] = {"samples": values.size(), "total_samples": _counts[key], "mean": total / values.size(), "p50": values[int((values.size() - 1) * 0.5)], "p95": values[int(ceil((values.size() - 1) * 0.95))], "max": values.back()}
	return {"version": 1, "enabled": enabled, "context": _context.duplicate(true), "sample_limit_per_metric": MAX_SAMPLES, "window": "latest samples per metric", "metrics": metrics, "buildings": game_state.buildings.size() if game_state != null else 0, "connections": game_state.connections.size() if game_state != null else 0, "notes": "Times are wall-clock durations. draw_submit_ms measures CPU command submission, not GPU time. frame_ms and frame_interval_ms include rendering, scheduling and vsync waits. Headless has no graphical FPS evidence. Monitoring never changes fixed ticks."}

func export_report(directory: String = "user://performance_reports") -> Dictionary:
	var absolute := ProjectSettings.globalize_path(directory)
	var error := DirAccess.make_dir_recursive_absolute(absolute)
	if error != OK: return {"ok": false, "message": "无法创建性能报告目录 (%s)" % error}
	var stem := absolute.path_join("performance_%s_%s" % [Time.get_unix_time_from_system(), Time.get_ticks_usec()])
	var report := get_report()
	var summary := "# 本地性能报告\n\n环境：%s\n\n%s\n\n| 指标 | 样本 | 平均 | P50 | P95 | 最大 |\n|---|---:|---:|---:|---:|---:|\n" % [JSON.stringify(report.context), report.notes]
	for key in report.metrics:
		var metric: Dictionary = report.metrics[key]
		summary += "| %s | %d / %d | %.3f | %.3f | %.3f | %.3f |\n" % [key, metric.samples, metric.total_samples, metric.mean, metric.p50, metric.p95, metric.max]
	for extension in ["json", "md"]:
		var file := FileAccess.open(stem + "." + extension, FileAccess.WRITE)
		if file == null: return {"ok": false, "message": "报告写入失败 (%s)" % FileAccess.get_open_error()}
		file.store_string(JSON.stringify(report, "\t") if extension == "json" else summary)
		file.flush()
		if file.get_error() != OK: return {"ok": false, "message": "报告写入未完成"}
		file.close()
	return {"ok": true, "path": stem + ".md", "json_path": stem + ".json"}

func use_web_workers() -> bool:
	return false
