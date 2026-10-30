## Generates res://data/tileset_iso.tres from the placeholder tile atlas.
##
## The atlas is a 4x2 grid of 64x32 diamond tiles (see tools/generate_placeholder_art.py).
## Replacing the artwork only means re-running this script with the new texture:
## tile coordinates, physics shapes and the "walkable" custom data layer stay identical.
##
## Run:  godot --headless --path . --script res://tools/build_tileset.gd
extends SceneTree

const ATLAS_PATH := "res://assets/environments/tiles/iso_tiles_placeholder.png"
const OUT_PATH := "res://data/tileset_iso.tres"

const TILE_SIZE := Vector2i(64, 32)
const COLUMNS := 4
const ROWS := 2

## Tiles that block movement. Everything else is walkable.
const SOLID_TILES: Array[Vector2i] = [Vector2i(2, 1), Vector2i(3, 1)]

## Diamond covering the full 64x32 cell, in tile-local space (origin = tile centre).
const DIAMOND := [Vector2(0, -16), Vector2(32, 0), Vector2(0, 16), Vector2(-32, 0)]


func _initialize() -> void:
	var texture: Texture2D = load(ATLAS_PATH)
	if texture == null:
		push_error("Could not load %s" % ATLAS_PATH)
		quit(1)
		return

	var tile_set := TileSet.new()
	tile_set.tile_shape = TileSet.TILE_SHAPE_ISOMETRIC
	tile_set.tile_layout = TileSet.TILE_LAYOUT_DIAMOND_DOWN
	tile_set.tile_size = TILE_SIZE

	# Physics layer 0 -> world collision (layer 1).
	tile_set.add_physics_layer()
	tile_set.set_physics_layer_collision_layer(0, 1)
	tile_set.set_physics_layer_collision_mask(0, 0)

	# Custom data layer 0 -> "walkable", read by the movement code.
	tile_set.add_custom_data_layer()
	tile_set.set_custom_data_layer_name(0, "walkable")
	tile_set.set_custom_data_layer_type(0, TYPE_BOOL)

	var source := TileSetAtlasSource.new()
	source.texture = texture
	source.texture_region_size = TILE_SIZE
	tile_set.add_source(source, 0)

	for y in ROWS:
		for x in COLUMNS:
			var coords := Vector2i(x, y)
			source.create_tile(coords)

			var solid: bool = SOLID_TILES.has(coords)
			var data := source.get_tile_data(coords, 0)
			data.set_custom_data("walkable", not solid)

			if solid:
				data.add_collision_polygon(0)
				data.set_collision_polygon_points(0, 0, PackedVector2Array(DIAMOND))

	var err := ResourceSaver.save(tile_set, OUT_PATH)
	if err != OK:
		push_error("Failed to save %s: %d" % [OUT_PATH, err])
		quit(1)
		return

	print("[build_tileset] wrote %s (%d tiles, %d solid)" % [OUT_PATH, COLUMNS * ROWS, SOLID_TILES.size()])
	quit(0)
