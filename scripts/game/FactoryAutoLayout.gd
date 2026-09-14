class_name FactoryAutoLayout
extends RefCounted

const Geometry = preload("res://scripts/game/FactoryGeometry.gd")
const GAP := Vector2(100, 70)

static func plan(state: GameState, selected: Array = []) -> Dictionary:
	var ids: Array = state.buildings.keys().filter(func(id): return state.buildings[id].get("planet_id") == state.active_planet_id)
	ids.sort()
	var degrees := {}
	var layers := {}
	var edges := {}
	for id in ids:
		degrees[id] = 0
		layers[id] = 0
		edges[id] = []
	for link in state.connections.values():
		var source: String = link.get("source_id", "")
		var target: String = link.get("target_id", "")
		if degrees.has(source) and degrees.has(target) and not edges[source].has(target):
			edges[source].append(target)
			degrees[target] += 1
	var queue: Array = ids.filter(func(id): return degrees[id] == 0)
	var visited := {}
	while not queue.is_empty():
		queue.sort()
		var id: String = queue.pop_front()
		visited[id] = true
		for next in edges[id]:
			layers[next] = maxi(int(layers[next]), int(layers[id]) + 1)
			degrees[next] -= 1
			if degrees[next] == 0: queue.append(next)
	# Cycles share a deterministic column rather than recursing indefinitely.
	for id in ids:
		if not visited.has(id): layers[id] = 0
	var movable: Array = ids.filter(func(id): return (selected.is_empty() or selected.has(id)) and not state.buildings[id].get("interaction_locked", false))
	var occupied: Array[Rect2] = []
	for id in ids:
		if not movable.has(id): occupied.append(Geometry.card_rect(state.buildings[id].position).grow(20))
	var rows := {}
	var positions: Array = []
	for id in movable:
		var layer := int(layers[id])
		var row := int(rows.get(layer, 0))
		var location := Vector2(layer * (Geometry.CARD_SIZE.x + GAP.x), row * (Geometry.CARD_SIZE.y + GAP.y))
		var attempts := 0
		while occupied.any(func(rect): return rect.intersects(Geometry.card_rect(location).grow(20), false)):
			row += 1
			location.y = row * (Geometry.CARD_SIZE.y + GAP.y)
			attempts += 1
			if attempts > 10000: return {"ok": false, "message": "没有足够的布局空间"}
		rows[layer] = row + 1
		occupied.append(Geometry.card_rect(location).grow(20))
		positions.append({"id": id, "position": location})
	return {"ok": true, "positions": positions, "message": "布局预览已生成"}

static func apply(state: GameState, selected: Array = []) -> Dictionary:
	var result := plan(state, selected)
	if not result.ok: return result
	if result.positions.is_empty(): return {"ok": false, "message": "没有可布局的建筑"}
	return state.command_history.execute(state, "自动布局", state.try_move_entities.bind(result.positions))
