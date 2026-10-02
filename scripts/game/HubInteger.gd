class_name HubInteger
extends RefCounted

const MAX_DIGITS := 256

static func valid(value: Variant) -> bool:
	if not value is String or value.is_empty() or value.length() > MAX_DIGITS: return false
	if value.length() > 1 and value.begins_with("0"): return false
	for digit in value:
		if digit < "0" or digit > "9": return false
	return true

static func add(a: String, b: String) -> String:
	var total := DecimalCount.add(a, b)
	return total if total.length() <= MAX_DIGITS else "9".repeat(MAX_DIGITS)

static func subtract(a: String, b: String) -> String:
	return DecimalCount.subtract(a, b) if DecimalCount.compare(a, b) >= 0 else "0"

static func multiply(value: String, factor: int) -> String:
	if factor <= 0: return "0"
	var result := "0"
	var term := value
	while factor > 0:
		if factor % 2 == 1: result = add(result, term)
		factor = factor >> 1
		if factor > 0: term = add(term, term)
	return result

static func half(value: String) -> String:
	var result := ""
	var carry := 0
	for digit in value:
		var current := carry * 10 + int(digit)
		result += str(int(current / 2))
		carry = current % 2
	while result.length() > 1 and result.begins_with("0"): result = result.substr(1)
	return result

static func module_cost(base: String, existing: int, amount: int) -> String:
	if existing < 0 or amount <= 0 or base == "0": return "0"
	var tier := int(existing / 10)
	var price := base
	for index in range(mini(tier, 1024)):
		price = multiply(price, 2)
		if price == "9".repeat(MAX_DIGITS): return price
	var total := "0"
	var position := existing
	while amount > 0:
		var count := mini(amount, 10 - position % 10)
		total = add(total, multiply(price, count))
		if total == "9".repeat(MAX_DIGITS): return total
		position += count
		amount -= count
		price = multiply(price, 2)
	return total
