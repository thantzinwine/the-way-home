## Builds the playable map from a plain-text layout.
##
## Why text: the tilemap data lives in version control as something a designer can
## read and edit, and the map can be rebuilt against new artwork at any time.
## The scene only needs an empty TileMapLayer and a parent for the props.
class_name MapBuilder
extends Node2D

signal built

const PROP_OCCLUDER := preload("res://scripts/props/prop_occluder.gd")

@export_file("*.txt") var map_file := "res://data/maps/test_neighborhood.txt"
@export var ground_path: NodePath
@export var props_parent_path: NodePath
@export var tileset: TileSet
@export var auto_build := false

var start_cell := Vector2i(2, 11)
var width := 0
var height := 0

var _ground: TileMapLayer
var _props_parent: Node
var _blocked := {}
var _built := false
var _map_rows: Array[String] = []
var _prop_rows: Array[String] = []
var _prop_count := 0
var _props: Array[Node] = []


func _ready() -> void:
	if auto_build:
		build()


func build() -> void:
	if _built:
		return

	_ground = get_node_or_null(ground_path) as TileMapLayer
	_props_parent = get_node_or_null(props_parent_path)
	if _ground == null:
		push_error("MapBuilder: ground_path does not point at a TileMapLayer")
		return
	if _props_parent == null:
		push_error("MapBuilder: props_parent_path does not point at a Node")
		return
	if tileset != null:
		_ground.tile_set = tileset

	var text := FileAccess.get_file_as_string(map_file)
	if text.is_empty():
		push_error("MapBuilder: could not read %s" % map_file)
		return

	_parse(text)
	_build_tiles()
	_build_props()

	_built = true
	built.emit()


func is_walkable(cell: Vector2i) -> bool:
	if cell.x < 0 or cell.y < 0 or cell.x >= width or cell.y >= height:
		return false
	if _blocked.has(cell):
		return false
	if _ground == null:
		return false
	var data := _ground.get_cell_tile_data(cell)
	if data == null:
		return false
	return bool(data.get_custom_data("walkable"))


## Blocks a cell at runtime (used by NPC placement). Does not remove tiles.
func block_cell(cell: Vector2i) -> void:
	_blocked[cell] = true


## World-space bounds of the map, used for the camera limits.
func get_world_rect() -> Rect2:
	if width == 0 or height == 0:
		return Rect2()
	var corners := [
		Isometric.grid_to_world(Vector2i(0, 0)),
		Isometric.grid_to_world(Vector2i(width - 1, 0)),
		Isometric.grid_to_world(Vector2i(0, height - 1)),
		Isometric.grid_to_world(Vector2i(width - 1, height - 1)),
	]
	var min_x: float = corners[0].x
	var max_x: float = corners[0].x
	var min_y: float = corners[0].y
	var max_y: float = corners[0].y
	for c in corners:
		min_x = minf(min_x, c.x)
		max_x = maxf(max_x, c.x)
		min_y = minf(min_y, c.y)
		max_y = maxf(max_y, c.y)
	const MARGIN := 160.0
	return Rect2(
		Vector2(min_x - MARGIN, min_y - MARGIN),
		Vector2((max_x - min_x) + MARGIN * 2.0, (max_y - min_y) + MARGIN * 2.0)
	)


func get_prop_count() -> int:
	return _prop_count


func get_props() -> Array[Node]:
	return _props


func get_blocked_cells() -> Dictionary:
	return _blocked


# --- internals -----------------------------------------------------------------

func _attach_occluder(instance: Node) -> void:
	var sprite := instance.get_node_or_null("Sprite") as Sprite2D
	if sprite == null:
		return
	var occluder := PROP_OCCLUDER.new()
	instance.add_child(occluder)
	occluder.setup(sprite)

func _parse(text: String) -> void:
	var section := ""
	for raw_line in text.split("\n"):
		var line := raw_line.strip_edges()
		if line.is_empty() or line.begins_with("//"):
			continue

		if line.begins_with("START"):
			var parts := line.split(" ", false)
			if parts.size() >= 2:
				var xy := parts[1].split(",")
				if xy.size() == 2:
					start_cell = Vector2i(int(xy[0]), int(xy[1]))
			continue
		if line == "MAP":
			section = "map"
			continue
		if line == "PROPS":
			section = "props"
			continue

		match section:
			"map":
				_map_rows.append(line)
				width = maxi(width, line.length())
			"props":
				_prop_rows.append(line)
			_:
				push_warning("MapBuilder: text outside of a MAP/PROPS section: %s" % line)

	height = _map_rows.size()


func _build_tiles() -> void:
	for y in height:
		var row: String = _map_rows[y]
		for x in row.length():
			var glyph := row[x]
			if TileLegend.has_glyph(glyph):
				_ground.set_cell(Vector2i(x, y), 0, TileLegend.atlas_coords(glyph))


func _build_props() -> void:
	for y in _prop_rows.size():
		var row: String = _prop_rows[y]
		for x in row.length():
			var glyph := row[x]
			var prop_id := PropLibrary.prop_id_for(glyph)
			if prop_id.is_empty():
				continue

			var scene := PropLibrary.scene_for(prop_id)
			if scene == null:
				push_warning("MapBuilder: no scene registered for '%s'" % prop_id)
				continue

			var cell := Vector2i(x, y)
			var instance := scene.instantiate()
			instance.position = Isometric.grid_to_world(cell)
			_props_parent.add_child(instance)
			_prop_count += 1
			_attach_occluder(instance)
			_props.append(instance)

			for offset in PropLibrary.footprint_for(prop_id):
				_blocked[cell + offset] = true
