extends RefCounted

const CAPACITY := preload("res://scripts/game/SourceEntityCapacitySystem.gd")
const SOURCE_EPSILON := 0.0001

static func extractors(state: GameState, site_id: String) -> Array:
	var result := []
	for building in state.buildings.values():
		if building.get("resource_site_id", "") != site_id: continue
		var definition := DataManager.get_building(String(building.get("type", "")))
		if definition.has("source_id") and definition.get("kind") == "extractor": result.append(building)
	return result

static func raw_amount(state: GameState, site: Dictionary) -> float:
	var item := String(site.get("item_id", ""))
	var amount := float(site.get("output_buffer", {}).get(item, 0))
	for building in extractors(state, String(site.get("id", ""))): amount += float(building.get("output_buffer", {}).get(item, 0))
	return amount

static func amount(state: GameState, site: Dictionary) -> float:
	return maxf(0, floorf(raw_amount(state, site) + SOURCE_EPSILON))

static func miner_count(state: GameState, site: Dictionary) -> float:
	var count := 0.0
	for building in extractors(state, String(site.get("id", ""))): count += maxf(1, floorf(float(building.get("machine_count", 1))))
	return count

static func extractor_type(item: String) -> String:
	return "dsp_water_pump" if item in ["water", "sulfuric_acid"] else ("dsp_oil_extractor" if item == "crude_oil" else "dsp_mining_machine")

static func manual_capacity(state: GameState, site: Dictionary) -> float:
	var entity := {"type": extractor_type(String(site.get("item_id", ""))), "machine_count": maxf(1, miner_count(state, site))}
	return minf(CAPACITY.buffer_limit(state, entity), maxf(60, CAPACITY.output_capacity(state, entity)))

static func add_manual(state: GameState, site: Dictionary, mined: float) -> void:
	var item := String(site.item_id)
	var buffer: Dictionary = site.get("output_buffer", {}).duplicate(true)
	buffer[item] = float(buffer.get(item, 0)) + mined
	site.output_buffer = buffer

# Each old building keeps its real buffer. The resource view sums these owners
# without copying or rounding their persisted stock.
static func take(state: GameState, site: Dictionary, requested: float) -> float:
	var available := raw_amount(state, site)
	if not is_finite(requested) or not is_finite(available) or requested <= 0 or requested > available: return 0
	var item := String(site.item_id)
	var consumed := 0.0
	var buffers: Array = [site]
	buffers.append_array(extractors(state, String(site.id)))
	var changes := []
	for owner in buffers:
		if consumed == requested: break
		var buffer: Dictionary = owner.get("output_buffer", {}).duplicate(true)
		var current := float(buffer.get(item, 0))
		if not is_finite(current) or current < 0: return 0
		if current == 0: continue
		var cumulative := consumed + current
		# Use the same cumulative sum as availability; repeated subtraction can
		# reject a full debit or leave a fractional remainder in an empty owner.
		buffer[item] = 0.0 if cumulative <= requested else current - (requested - consumed)
		changes.append({"owner": owner, "buffer": buffer})
		consumed = minf(requested, cumulative)
	if consumed != requested: return 0
	for change in changes: change.owner.output_buffer = change.buffer
	return requested
