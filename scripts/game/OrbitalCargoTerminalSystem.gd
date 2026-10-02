class_name OrbitalCargoTerminalSystem
extends RefCounted

const TYPE := "dsp_orbital_cargo_terminal"
const PORT_COUNT := 4
const UPLOAD_PER_MINUTE := 20000.0
var state: GameState

func _init(game_state: GameState) -> void:
	state = game_state

static func initialize(building: Dictionary) -> void:
	if not building.has("orbital_cargo_ports"): building.orbital_cargo_ports = ["", "", "", ""]
	if not building.has("orbital_cargo_binding"): building.orbital_cargo_binding = {}
	if not building.has("orbital_cargo_progress"): building.orbital_cargo_progress = 0.0
	if not building.has("orbital_cargo_total"): building.orbital_cargo_total = "0"
	if not building.has("orbital_cargo_cursor"): building.orbital_cargo_cursor = 0

func bind_target(id: String, binding: Dictionary) -> Dictionary:
	var building: Dictionary = state.buildings.get(id, {})
	if state.save_mode != "normal" or building.get("type") != TYPE or building.get("planet_id") != state.active_planet_id or building.get("interaction_locked", false): return StationSystem.result(false, "请选择当前行星未锁定的轨道货运终端")
	if not _valid_binding(binding): return StationSystem.result(false, "空间站建设阶段或合同目标不可用")
	building.orbital_cargo_binding = binding.duplicate(true)
	building.orbital_cargo_progress = 0.0
	return StationSystem.result(true, "货运终端目标已更新，缓存物资保留")

func _valid_binding(binding: Dictionary) -> bool:
	if binding.is_empty(): return true
	if binding.get("kind") == "construction": return LocalSpaceStationSystem.new(state).snapshot().stage in ["eligible", "core", "dock", "showcase"]
	if binding.get("kind") == "contract":
		for contract in state.station_contracts.get("accepted", []):
			if contract.id == binding.get("contract_id") and contract.status in ["accepted", "claimable"]: return true
	return false

func remaining(building: Dictionary, item: String) -> int:
	var binding: Dictionary = building.get("orbital_cargo_binding", {})
	if state.save_mode != "normal" or not state.colonized_planet_ids.has(building.planet_id): return 0
	if binding.get("kind") == "construction": return int(LocalSpaceStationSystem.new(state).snapshot().remaining.get(item, 0))
	if binding.get("kind") == "contract": return StationContractSystem.new(state).remaining(String(binding.get("contract_id", "")), item, "terminal", building.planet_id)
	return 0

func resolve_port(id: String, item: String) -> int:
	var building: Dictionary = state.buildings.get(id, {})
	if building.get("type") != TYPE or building.get("interaction_locked", false) or remaining(building, item) < 1: return -1
	var ports: Array = building.orbital_cargo_ports
	var matching := ports.find(item)
	return matching if matching >= 0 else ports.find("")

func clear_check(id: String, index: int) -> Dictionary:
	var building: Dictionary = state.buildings.get(id, {})
	if building.get("type") != TYPE or building.get("planet_id") != state.active_planet_id or building.get("interaction_locked", false) or index < 0 or index >= PORT_COUNT: return {"ok": false, "message": "轨道货运端口不可修改"}
	var item: String = building.orbital_cargo_ports[index]
	var links := []
	for connection in state.connections.values():
		if connection.target_id == id and int(connection.get("target_port_index", -1)) == index: links.append(connection.id)
	var reused := false
	for other in range(PORT_COUNT):
		if other != index and building.orbital_cargo_ports[other] == item: reused = true
	var buffered := 0.0 if reused or item.is_empty() else float(building.input_buffer.get(item, 0))
	return {"ok": true, "requires_confirmation": not links.is_empty() or buffered > 0, "item": item, "links": links, "buffered": buffered, "message": "端口 %d：%d 条线路，%.1f 件缓存；清空后返还线路施工件和缓存物资" % [index + 1, links.size(), buffered]}

func clear_port(id: String, index: int, confirmed: bool = false) -> Dictionary:
	var check := clear_check(id, index)
	if not check.ok: return check
	if check.requires_confirmation and not confirmed: return StationSystem.result(false, "该端口仍有线路或缓存，请确认清空")
	var candidate := state.copy_state()
	candidate.emit_canvas_events = false
	if check.buffered > 0:
		var refunded := InventorySystem.new(candidate).try_add(check.item, float(check.buffered))
		if not refunded.ok: return refunded
	for link in check.links:
		var removed := candidate._try_remove_connection_command(link)
		if not removed.ok: return removed
	candidate.buildings[id].orbital_cargo_ports[index] = ""
	if check.buffered > 0: candidate.buildings[id].input_buffer.erase(check.item)
	state.install_state(candidate)
	if state.emit_canvas_events:
		for link in check.links: EventBus.connection_removed.emit(link)
	return StationSystem.result(true, "端口已清空，线路和缓存已返还")

func update(delta: float) -> void:
	if state.save_mode != "normal" or state.paused or delta <= 0 or not is_finite(delta): return
	var ids := state.buildings.keys()
	ids.sort()
	for id in ids:
		var building: Dictionary = state.buildings[id]
		if building.type != TYPE: continue
		var binding: Dictionary = building.orbital_cargo_binding
		if not _valid_binding(binding):
			building.orbital_cargo_binding = {}
			building.orbital_cargo_progress = 0.0
			continue
		if binding.is_empty(): continue
		var power := clampf(float(building.get("power_efficiency", 0)), 0, 1)
		var requests := []
		var seen := {}
		for index in range(PORT_COUNT):
			var item: String = building.orbital_cargo_ports[index]
			if item.is_empty() or seen.has(item): continue
			seen[item] = true
			var available := mini(int(floorf(float(building.input_buffer.get(item, 0)))), remaining(building, item))
			if available > 0: requests.append({"item": item, "port": index, "available": available, "planned": 0})
		if power <= 0 or requests.is_empty(): continue
		var accrued := float(building.orbital_cargo_progress) + UPLOAD_PER_MINUTE * delta * power / 60.0
		var budget := int(floorf(accrued + 1e-9))
		building.orbital_cargo_progress = clampf(accrued - budget, 0, 0.999999999)
		var cursor := int(building.orbital_cargo_cursor) % PORT_COUNT
		while budget > 0:
			var active: Array = requests.filter(func(row): return row.available > 0)
			if active.is_empty(): break
			var minimum := int(active[0].available)
			for row in active: minimum = mini(minimum, int(row.available))
			var rounds := mini(int(budget / active.size()), minimum)
			if rounds > 0:
				for row in active:
					row.available -= rounds
					row.planned += rounds
				budget -= rounds * active.size()
				var last := cursor
				for offset in range(PORT_COUNT):
					var port := (cursor + offset) % PORT_COUNT
					for row in active:
						if row.port == port: last = port
				cursor = _next_port(active, last)
				continue
			var start := cursor
			for offset in range(PORT_COUNT):
				if budget < 1: break
				var port := (start + offset) % PORT_COUNT
				for row in active:
					if row.port != port or row.available < 1: continue
					row.available -= 1
					row.planned += 1
					budget -= 1
					cursor = _next_port(active, port)
		var uploaded := 0
		for row in requests:
			var accepted := LocalSpaceStationSystem.new(state).deliver_from_buffer(row.item, int(row.planned)) if binding.kind == "construction" else StationContractSystem.new(state).deliver_from_buffer(binding.contract_id, row.item, int(row.planned), "terminal", building.planet_id)
			building.input_buffer[row.item] = float(building.input_buffer.get(row.item, 0)) - accepted
			uploaded += accepted
		building.orbital_cargo_cursor = cursor
		building.orbital_cargo_total = DecimalCount.add(building.orbital_cargo_total, str(uploaded))
		if not _valid_binding(binding): building.orbital_cargo_binding = {}

static func _next_port(active: Array, last: int) -> int:
	for offset in range(PORT_COUNT):
		var port := (last + offset + 1) % PORT_COUNT
		for row in active:
			if row.port == port and row.available > 0: return port
	return (last + 1) % PORT_COUNT

static func validate(data: Dictionary) -> Array:
	var errors := []
	var buildings: Variant = data.get("buildings", {})
	var connections: Variant = data.get("connections", {})
	if not buildings is Dictionary or not connections is Dictionary: return errors
	for building in buildings.values():
		if not building is Dictionary: continue
		if building.get("type") != TYPE:
			for field in ["orbital_cargo_ports", "orbital_cargo_binding", "orbital_cargo_progress", "orbital_cargo_total", "orbital_cargo_cursor"]:
				if building.has(field): errors.append("非货运终端含轨道上传状态")
			continue
		var ports: Variant = building.get("orbital_cargo_ports")
		if not ports is Array or ports.size() != PORT_COUNT:
			errors.append("货运终端端口列表无效")
			continue
		for item in ports:
			if not item is String or (not item.is_empty() and DataManager.get_item(item).is_empty()): errors.append("货运终端物品无效")
		var binding: Variant = building.get("orbital_cargo_binding")
		if not binding is Dictionary or (not binding.is_empty() and (binding.get("kind") not in ["construction", "contract"] or (binding.get("kind") == "contract" and not binding.get("contract_id") is String))): errors.append("货运终端绑定无效")
		if not LogisticsStateValidator._number(building.get("orbital_cargo_progress"), 0, 1) or not LogisticsStateValidator._integer(building.get("orbital_cargo_cursor"), 0, 3) or not BlackHoleSystem._decimal_valid(building.get("orbital_cargo_total")): errors.append("货运终端累计值无效")
	for connection in connections.values():
		if not connection is Dictionary: continue
		var target: Dictionary = buildings.get(connection.get("target_id", ""), {})
		if target.get("type") != TYPE: continue
		var index: Variant = connection.get("target_port_index")
		if not LogisticsStateValidator._integer(index, 0, 3) or not target.get("orbital_cargo_ports") is Array or target.orbital_cargo_ports.size() != PORT_COUNT: errors.append("货运终端连接端口无效")
		elif target.orbital_cargo_ports[int(index)] != connection.get("item_id"): errors.append("货运终端连接物品与端口不符")
	return errors
