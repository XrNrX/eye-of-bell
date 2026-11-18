extends RefCounted
## Small shared helpers for the per-system save_state() / load_state() / validate_state() functions (docs/code_review.md S1):
## cells and item stacks to and from plain JSON data, and the shape checks the validators use. Pure static functions with no
## node references, so any system can preload it (save_game.gd gathers the systems' states, and itself preloads nothing of
## theirs). A save holds only JSON types, so every number comes back from a file as a float: convert with int() on the way in.

const ItemStack := preload("res://scripts/item_stack.gd")


static func cell_to_data(cell: Vector2i) -> Array:
	return [cell.x, cell.y]


static func data_to_cell(data) -> Vector2i:
	return Vector2i(int(data[0]), int(data[1]))


static func stack_to_data(stack):
	if stack == null:
		return null
	var d := {"def": stack.def.resource_path, "count": stack.count}
	if not stack.origin.is_empty():
		d["origin"] = stack.origin.duplicate()
	if stack.burn_left >= 0.0:  # A light that has burned a while (a fresh one has none).
		d["burn"] = stack.burn_left
	if stack.burning:
		d["burning"] = true      # Lying lit on the floor (light_field.gd lights it again).
	return d


## Rebuild an ItemStack from saved data, or null if it's empty or its item no longer exists.
static func data_to_stack(data) -> RefCounted:
	if not (data is Dictionary) or not ResourceLoader.exists(str(data.get("def", ""))):
		return null
	var stack: RefCounted = ItemStack.of(load(data.def), maxi(1, int(data.get("count", 1))))
	var o = data.get("origin")
	if o is Dictionary and o.has("hero"):
		stack.origin = {"hero": int(o.hero), "where": str(o.where), "index": int(o.index)}
	stack.burn_left = float(data.get("burn", -1.0))
	stack.burning = bool(data.get("burning", false))
	return stack


# --------------------------------------------------------------------------
# Shape checks (validate_state). Each returns "" when fine, or a sentence about what is wrong.
# --------------------------------------------------------------------------

static func is_number(v) -> bool:
	return typeof(v) == TYPE_INT or typeof(v) == TYPE_FLOAT


static func is_cell(v) -> bool:
	return v is Array and v.size() == 2 and is_number(v[0]) and is_number(v[1])


## A saved stack: nothing, or a dictionary (an item that no longer exists is skipped on load, not refused).
static func is_stack(v) -> bool:
	return v == null or (v is Dictionary and v.get("def") is String and (not v.has("count") or is_number(v.count)))


## `d[key]` must be there and be of the named kind: "number", "string", "array", "dict", "cell", "stack".
static func need(d: Dictionary, key: String, kind: String, where := "save") -> String:
	if not d.has(key):
		return "The %s has no '%s'." % [where, key]
	return kind_error(d[key], kind, "%s '%s'" % [where, key])


## Like `need`, but a key that is missing is fine (an older save): only one that is there must be right.
static func maybe(d: Dictionary, key: String, kind: String, where := "save") -> String:
	return need(d, key, kind, where) if d.has(key) else ""


static func kind_error(v, kind: String, what: String) -> String:
	var ok := false
	match kind:
		"number": ok = is_number(v)
		"string": ok = v is String
		"array": ok = v is Array
		"dict": ok = v is Dictionary
		"cell": ok = is_cell(v)
		"stack": ok = is_stack(v)
	return "" if ok else "The %s is damaged." % what


## Every element of `list` must pass `test` (a Callable taking the element and returning "" or a problem).
static func each(list: Array, test: Callable) -> String:
	for e in list:
		var problem: String = test.call(e)
		if problem != "":
			return problem
	return ""
