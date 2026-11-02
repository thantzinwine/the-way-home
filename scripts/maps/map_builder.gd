## Builds the playable map from a plain-text layout (3D).
class_name MapBuilder
extends Node3D

signal built

@export_file("*.txt") var map_file := "res://data/maps/test_neighborhood.txt"
@export var ground_path: NodePath
@export var props_parent_path: NodePath
@export var tileset: TileSet
@export var auto_build := false

var start_cell := Vector2i(2, 11)
var width := 0
var height := 0

var _ground: Node3D
var _props_parent: Node3D
var _blocked := {}
var _built := false
var _map_rows: Array[String] = []
var _prop_rows: Array[String] = []
var _prop_count := 0
var _props: Array[Node] = []
var _tile_walkable := {}


func _ready() -> void:
	if auto_build:
		build()


func build() -> void:
	if _built:
		return
	_ground = get_node_or_null(ground_path) as Node3D
	_props_parent = get_node_or_null(props_parent_path) as Node3D
	if _ground == null or _props_parent == null:
		push_error("MapBuilder: paths not set")
		return
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
	if not _tile_walkable.has(cell):
		return false
	return bool(_tile_walkable[cell])


func block_cell(cell: Vector2i) -> void:
	_blocked[cell] = true


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
	var min_z: float = corners[0].z
	var max_z: float = corners[0].z
	for c in corners:
		min_x = minf(min_x, c.x)
		max_x = maxf(max_x, c.x)
		min_z = minf(min_z, c.z)
		max_z = maxf(max_z, c.z)
	const MARGIN := 2.0
	return Rect2(Vector2(min_x - MARGIN, min_z - MARGIN), Vector2((max_x - min_x) + MARGIN * 2.0, (max_z - min_z) + MARGIN * 2.0))


func get_prop_count() -> int:
	return _prop_count


func get_props() -> Array[Node]:
	return _props


func get_blocked_cells() -> Dictionary:
	return _blocked


func _tile_color(glyph: String) -> Color:
	match glyph:
		".": return Color(0.35, 0.55, 0.30)
		",": return Color(0.40, 0.60, 0.32)
		"-": return Color(0.55, 0.45, 0.30)
		"_": return Color(0.60, 0.60, 0.55)
		"=": return Color(0.30, 0.30, 0.32)
		"x": return Color(0.45, 0.45, 0.40)
		"#": return Color(0.40, 0.38, 0.36)
		"~": return Color(0.25, 0.40, 0.60)
		_: return Color(0.35, 0.55, 0.30)


func _tile_walkable_glyph(glyph: String) -> bool:
	return glyph != "#" and glyph != "~"


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
				pass
	height = _map_rows.size()


func _build_tiles() -> void:
	for y in height:
		var row: String = _map_rows[y]
		for x in row.length():
			var glyph := row[x]
			var cell := Vector2i(x, y)
			_tile_walkable[cell] = _tile_walkable_glyph(glyph)
			var mi := MeshInstance3D.new()
			var pm := PlaneMesh.new()
			pm.size = Vector2(1.0, 1.0)
			mi.mesh = pm
			var mat := StandardMaterial3D.new()
			mat.albedo_color = _tile_color(glyph)
			mi.material_override = mat
			mi.position = Isometric.grid_to_world(cell)
			_ground.add_child(mi)


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
				continue
			var cell := Vector2i(x, y)
			var instance := scene.instantiate()
			instance.position = Isometric.grid_to_world(cell)
			_props_parent.add_child(instance)
			_prop_count += 1
			_props.append(instance)
			for offset in PropLibrary.footprint_for(prop_id):
				_blocked[cell + offset] = true
