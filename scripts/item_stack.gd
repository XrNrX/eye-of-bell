extends RefCounted
## A stack of identical items in one slot: an ItemDef plus how many. Every place an
## item can sit (hand, armour, backpack, quick slot, the cursor, a floor tile) holds
## an ItemStack or null. The ItemDef (a shared .tres) is never changed; only `count` is.
##
## Never put one ItemStack in two places: moving items moves the object, splitting
## makes a new one (take_one).

var def: Resource
var count := 1

## Only set on a thrown item lying on the floor: where it was thrown from, so picking
## it up can send it home. {"hero": hero_index, "where": "hand" or "quick", "index": n},
## or {} for "nowhere in particular". Cleared as soon as it is picked up.
var origin := {}

## A light (ItemDef.is_light): seconds of burning left, or -1 for a fresh one (all of ItemDef.burn_seconds). It only counts down while
## the light is lit, so a light put away keeps its time. A used light never stacks with fresh ones.
var burn_left := -1.0
## A light lying lit on a floor tile (it slipped from a hand): light_field.gd keeps it burning there until it is picked up.
var burning := false


static func of(item_def: Resource, n := 1) -> RefCounted:
	var s := new()
	s.def = item_def
	s.count = n
	return s


## Accepts an ItemDef (wrapped as a stack of 1), an ItemStack (returned as is) or
## null, so callers can pass whichever they have.
static func wrap(item) -> RefCounted:
	if item is Resource:  # An ItemDef (a Resource is also a RefCounted, so test this first).
		return of(item)
	return item


## Same kind of item, and a kind that stacks at all (max_stack > 1).
func can_stack_with(other: RefCounted) -> bool:
	if other == null or other.def != def or def.max_stack <= 1:
		return false
	return burn_left < 0.0 and other.burn_left < 0.0 and not burning and not other.burning  # Only fresh lights stack.


## A light's seconds of burning left (all of them if it is fresh).
func seconds_left() -> float:
	return def.burn_seconds if burn_left < 0.0 else burn_left


func room() -> int:
	return maxi(0, def.max_stack - count)


## Move as many of `other` into this stack as fit; returns how many moved.
func merge_from(other: RefCounted) -> int:
	if not can_stack_with(other):
		return 0
	var moved := mini(room(), other.count)
	count += moved
	other.count -= moved
	if origin != other.origin:
		origin = {}  # Pieces from different places: no single home any more.
	return moved


## Split one item off into a new stack of 1. The caller empties its slot if count hits 0.
func take_one() -> RefCounted:
	count -= 1
	return of(def, 1)


func label() -> String:
	return def.display_name if count <= 1 else "%s x%d" % [def.display_name, count]
