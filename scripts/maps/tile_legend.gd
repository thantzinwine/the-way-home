## Maps ASCII glyphs in data/maps/*.txt to atlas coordinates in tileset_iso.tres.
##
## Change the artwork, keep the glyphs - the maps stay valid.
class_name TileLegend
extends RefCounted

const GRASS := "."
const GRASS_FLOWERS := ","
const DIRT := "-"
const PAVEMENT := "_"
const ROAD := "="
const CROSSING := "x"
const WALL := "#"
const WATER := "~"

const ATLAS := {
	GRASS: Vector2i(0, 0),
	GRASS_FLOWERS: Vector2i(1, 0),
	DIRT: Vector2i(2, 0),
	PAVEMENT: Vector2i(3, 0),
	ROAD: Vector2i(0, 1),
	CROSSING: Vector2i(1, 1),
	WALL: Vector2i(2, 1),
	WATER: Vector2i(3, 1),
}

const FALLBACK := Vector2i(0, 0)


static func has_glyph(glyph: String) -> bool:
	return ATLAS.has(glyph)


static func atlas_coords(glyph: String) -> Vector2i:
	return ATLAS.get(glyph, FALLBACK)
