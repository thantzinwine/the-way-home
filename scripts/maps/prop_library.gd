## Registry of placeable objects: ASCII glyph -> scene + collision footprint.
##
## Adding a new prop is one entry here plus one .tscn - the map builder and the
## map text files need no changes.
##
## Footprints are the grid cells the prop's base occupies (its ground-floor
## footprint, not its roof or canopy), so the walkable grid matches where the
## prop actually stands. Single-cell props (tree trunk, pole, crate, sign) block
## only their anchor cell - you can walk under a canopy or past a sign.
class_name PropLibrary
extends RefCounted

## glyph -> prop id
const GLYPHS := {
	"T": "tree",
	"P": "pole",
	"C": "crate",
	"S": "stall",
	"G": "sign",
	"H": "house",
}

## prop id -> scene path + the cells it occupies, relative to the anchor cell.
## The anchor cell is the object's visual base (bottom-centre of its sprite).
const PROPS := {
	"tree": {
		"scene": "res://scenes/props/tree.tscn",
		"footprint": [Vector2i(0, 0)],
	},
	"pole": {
		"scene": "res://scenes/props/utility_pole.tscn",
		"footprint": [Vector2i(0, 0)],
	},
	"crate": {
		"scene": "res://scenes/props/crate.tscn",
		"footprint": [Vector2i(0, 0)],
	},
	"stall": {
		"scene": "res://scenes/props/vendor_stall.tscn",
		# The counter is ~4 cells wide; the original single cell under-covered it.
		"footprint": [
			Vector2i(-1, -1), Vector2i(0, -1), Vector2i(1, -1),
			Vector2i(-1, 0), Vector2i(0, 0), Vector2i(1, 0),
		],
	},
	"sign": {
		"scene": "res://scenes/props/steps_sign.tscn",
		"footprint": [Vector2i(0, 0)],
	},
	"house": {
		"scene": "res://scenes/props/house.tscn",
		# Ground-floor footprint (the base, not the roof or the stairs): shifted
		# left because the house body sits left of its sprite centre.
		"footprint": [
			Vector2i(-2, -1), Vector2i(-2, 0),
			Vector2i(-1, -2), Vector2i(-1, -1), Vector2i(-1, 0),
			Vector2i(0, -1),
		],
	},
}


static func prop_id_for(glyph: String) -> String:
	return GLYPHS.get(glyph, "")


static func scene_for(prop_id: String) -> PackedScene:
	var entry: Dictionary = PROPS.get(prop_id, {})
	if entry.is_empty():
		return null
	return load(entry["scene"]) as PackedScene


static func footprint_for(prop_id: String) -> Array:
	var entry: Dictionary = PROPS.get(prop_id, {})
	return entry.get("footprint", [Vector2i.ZERO])
