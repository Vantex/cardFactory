class_name DecimalCount
extends RefCounted

static func valid(value: Variant) -> bool:
	if not value is String or value.is_empty() or value.length() > 128: return false
	if value.length() > 1 and value.begins_with("0"): return false
	for character in value:
		if character < "0" or character > "9": return false
	return true

static func compare(a: String, b: String) -> int:
	if a.length() != b.length(): return 1 if a.length() > b.length() else -1
	return 0 if a == b else 1 if a > b else -1

static func add(a: String, b: String) -> String:
	var result := ""
	var carry := 0
	var left := a.length() - 1
	var right := b.length() - 1
	while left >= 0 or right >= 0 or carry > 0:
		var digit := carry
		if left >= 0: digit += int(a[left])
		if right >= 0: digit += int(b[right])
		result = str(digit % 10) + result
		carry = int(digit / 10)
		left -= 1
		right -= 1
	return result if not result.is_empty() else "0"

static func subtract(a: String, b: String) -> String:
	assert(compare(a, b) >= 0)
	var result := ""
	var borrow := 0
	var right := b.length() - 1
	for left in range(a.length() - 1, -1, -1):
		var digit := int(a[left]) - borrow - (int(b[right]) if right >= 0 else 0)
		borrow = 1 if digit < 0 else 0
		if digit < 0: digit += 10
		result = str(digit) + result
		right -= 1
	while result.length() > 1 and result.begins_with("0"): result = result.substr(1)
	return result
