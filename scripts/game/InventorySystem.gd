class_name InventorySystem
extends RefCounted

const MAX_PLANET_STACK := 999.0
const MAX_CURSOR_STACK := 999.0
const AMOUNT_EPSILON := 0.0000001

var game_state: GameState

func _init(state: GameState) -> void:
	game_state = state

func try_add(item_id: String, amount: float) -> Dictionary:
	var error := _validate_item_amount(item_id, amount)
	if not error.is_empty():
		return error
	if not can_add_batch({item_id: amount}):
		return _failure("库存容量不足")
	game_state.planet_inventory[item_id] = float(game_state.planet_inventory.get(item_id, 0.0)) + amount
	return _success("物资已加入行星托盘")

func try_remove(item_id: String, amount: float) -> Dictionary:
	var error := _validate_item_amount(item_id, amount)
	if not error.is_empty():
		return error
	if not can_remove_batch({item_id: amount}):
		return _failure("行星托盘物资不足")
	_remove_without_validation(item_id, amount)
	return _success("物资已从行星托盘取出")

func try_pick_up(item_id: String, amount: float) -> Dictionary:
	var error := _validate_item_amount(item_id, amount)
	if not error.is_empty():
		return error
	var cursor_item := String(game_state.cursor_payload.get("item_id", ""))
	var cursor_amount := float(game_state.cursor_payload.get("amount", 0.0))
	if not cursor_item.is_empty() and cursor_item != item_id:
		return _failure("光标正在持有其他物资")
	if cursor_amount + amount > MAX_CURSOR_STACK + AMOUNT_EPSILON:
		return _failure("光标载荷超过上限")
	if not can_remove_batch({item_id: amount}):
		return _failure("行星托盘物资不足")
	_remove_without_validation(item_id, amount)
	game_state.cursor_payload = {"item_id": item_id, "amount": cursor_amount + amount}
	return _success("物资已拿到光标")

func try_put_down(amount: float) -> Dictionary:
	var item_id := String(game_state.cursor_payload.get("item_id", ""))
	var cursor_amount := float(game_state.cursor_payload.get("amount", 0.0))
	if item_id.is_empty() or cursor_amount <= AMOUNT_EPSILON:
		return _failure("光标没有物资")
	var error := _validate_item_amount(item_id, amount)
	if not error.is_empty():
		return error
	if amount > cursor_amount + AMOUNT_EPSILON:
		return _failure("光标物资不足")
	if not can_add_batch({item_id: amount}):
		return _failure("行星托盘容量不足")
	game_state.planet_inventory[item_id] = float(game_state.planet_inventory.get(item_id, 0.0)) + amount
	var remaining := maxf(cursor_amount - amount, 0.0)
	game_state.cursor_payload = {"item_id": "", "amount": 0.0} if remaining <= AMOUNT_EPSILON else {"item_id": item_id, "amount": remaining}
	return _success("光标物资已放回行星托盘")

func can_add_batch(items: Dictionary) -> bool:
	for item_key in items:
		var item_id := String(item_key)
		var amount := float(items[item_key])
		if not _validate_item_amount(item_id, amount).is_empty():
			return false
		if float(game_state.planet_inventory.get(item_id, 0.0)) + amount > MAX_PLANET_STACK + AMOUNT_EPSILON:
			return false
	return true

func can_remove_batch(items: Dictionary) -> bool:
	for item_key in items:
		var item_id := String(item_key)
		var amount := float(items[item_key])
		if not _validate_item_amount(item_id, amount).is_empty():
			return false
		if float(game_state.planet_inventory.get(item_id, 0.0)) + AMOUNT_EPSILON < amount:
			return false
	return true

func try_add_batch(items: Dictionary) -> Dictionary:
	if items.is_empty() or not can_add_batch(items):
		return _failure("行星托盘容量不足或物资数量无效")
	for item_key in items:
		var item_id := String(item_key)
		game_state.planet_inventory[item_id] = float(game_state.planet_inventory.get(item_id, 0.0)) + float(items[item_key])
	return _success("批量物资已加入行星托盘")

func try_remove_batch(items: Dictionary) -> Dictionary:
	if items.is_empty() or not can_remove_batch(items):
		return _failure("行星托盘物资不足或数量无效")
	for item_key in items:
		_remove_without_validation(String(item_key), float(items[item_key]))
	return _success("批量物资已从行星托盘取出")

func _remove_without_validation(item_id: String, amount: float) -> void:
	var remaining := maxf(float(game_state.planet_inventory.get(item_id, 0.0)) - amount, 0.0)
	if remaining <= AMOUNT_EPSILON:
		game_state.planet_inventory.erase(item_id)
	else:
		game_state.planet_inventory[item_id] = remaining

func _validate_item_amount(item_id: String, amount: float) -> Dictionary:
	if item_id.is_empty():
		return _failure("物资 ID 不能为空")
	if amount <= 0.0 or is_nan(amount) or is_inf(amount):
		return _failure("物资数量必须是有限正数")
	return {}

func _success(message: String) -> Dictionary:
	return {"ok": true, "message": message}

func _failure(message: String) -> Dictionary:
	return {"ok": false, "message": message}
