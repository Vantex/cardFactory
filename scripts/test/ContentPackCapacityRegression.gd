extends RefCounted

const FIXTURE := "res://tests/fixtures/parity/behavior/task27-content-pack-capacity.json"
const CAPACITY := preload("res://scripts/test/CapacityQueryBehaviorRunner.gd")
const OWNER := preload("res://scripts/test/EffectQueryBehaviorRunner.gd")
const MANIFEST := {"formatVersion": 2, "id": "item_input_capacity_pack", "name": "输入容量对照包", "version": "1.0.0", "items": [], "buildings": [], "recipes": [], "technologies": [], "belts": [], "buildingOverrides": [{"id": "planetary_logistics_station", "inputCapacity": 200, "outputCapacity": 300}, {"id": "arc_smelter", "inputCapacity": 50, "outputCapacity": 70}, {"id": "storage_mk1", "inputCapacity": 80, "outputCapacity": 90}]}
const FUNCTIONS := ["getEntityInputCapacity", "getEntityOutputCapacity", "getEntityItemInputCapacity"]
var errors: Array[String] = []

func run() -> Array[String]:
	errors.clear()
	var gold := DSPOnlineParity.read_json(FIXTURE)
	var catalog := DSPOnlineParity.read_json(DSPOnlineParity.ROOT + "dsponline_source_catalog.json")
	var modules := CAPACITY.SOURCE_MODULES.duplicate()
	modules.append_array(["src/game/contentPacks.ts", "src/game/mods.ts"])
	var controls := preload("res://scripts/test/WorldControlBehaviorRunner.gd")
	if gold.get("source_commit") != catalog.source.commit or not gold.get("source_files") is Dictionary or not controls._same_ids(gold.source_files.keys(), modules): return ["capacity override exact source provenance missing"]
	for file in modules:
		if gold.source_files[file] != catalog.source.files.get(file): return ["capacity override source hash drift"]
	if not CAPACITY._exact(gold.get("source_environment"), {"DEV": false, "PROD": true, "MODE": "production"}) or not CAPACITY._exact(gold.get("manifest"), MANIFEST): return ["capacity override controlled manifest/environment changed"]
	var inputs := {}
	for building in ["planetary_logistics_station", "arc_smelter", "storage_mk1"]:
		for count in [1, 2, 3]:
			for maximum in [0, 59.9]:
				for item in ["iron_ore", "proliferator_mk1"]: inputs["%s-c%d-s%s-i%s" % [building, count, str(maximum), item]] = {"building": building, "count": count, "maxStock": maximum, "item": item}
	if not gold.get("cases") is Array: return ["capacity override cases missing"]
	var ids := []
	for row in gold.cases:
		if not row is Dictionary: return ["capacity override case malformed"]
		ids.append(row.get("id"))
	if not controls._same_ids(ids, inputs.keys()): return ["capacity override coverage missing/duplicated"]
	for row in gold.cases:
		if not CAPACITY._exact(row.get("input"), inputs[row.id]) or not row.get("expected") is Dictionary or not controls._same_ids(row.expected.keys(), FUNCTIONS): return ["capacity override input/output shape changed"]
		for function in FUNCTIONS:
			var value: Variant = row.expected[function]
			if not OWNER._number(value) or value < 0 or value > 100000000 or value != floorf(float(value)): return ["capacity override output must be a finite bounded integer"]
	var saved_catalog := ContentPackSystem.snapshot_catalog()
	var saved_service := DataManager.content_pack_system
	var service := ContentPackSystem.new("res://.godot/task27-capacity-pack-%d/registry.json" % OS.get_process_id())
	DataManager.content_pack_system = service
	var registered := service.register_pack(MANIFEST)
	if not registered.ok: errors.append("actual controlled capacity override registration failed")
	else:
		for row in gold.cases:
			var kind := "station" if row.input.building == "planetary_logistics_station" else "storage" if row.input.building == "storage_mk1" else "machine"
			var state := CAPACITY._state({"entity_kind": "building", "building": row.input.building, "kind": kind, "count": row.input.count, "production": 1000000, "logistics": 1000000})
			var id: String = state.buildings.keys()[0]
			state.buildings[id].station = {"slots": [{"item_id": "iron_ore", "max_stock": row.input.maxStock}]}
			var before := OWNER._ownership(state)
			var actual := _query(state, id, String(row.input.item))
			var repeated := _query(state, id, String(row.input.item))
			if not CAPACITY._exact(actual, row.expected) or not CAPACITY._exact(actual, repeated) or OWNER._ownership(state) != before: errors.append(row.id + ": actual core capacity override differs or mutates ownership")
	ContentPackSystem.install_catalog(saved_catalog)
	DataManager.content_pack_system = saved_service
	return errors.duplicate()

static func _query(state: GameState, id: String, item: String) -> Dictionary:
	return {"getEntityInputCapacity": state.get_entity_input_capacity(id), "getEntityOutputCapacity": state.get_entity_output_capacity(id), "getEntityItemInputCapacity": state.get_entity_item_input_capacity(id, item)}
