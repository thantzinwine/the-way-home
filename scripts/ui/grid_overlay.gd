## Draws the walkable grid over the world.
##
## Answers the two things a player cannot infer from the art alone:
##   * exactly which cells an obstacle occupies (red diamonds = blocked),
##   * which cells can be walked onto (faint outline = walkable).
## Also flashes the cell that refused a step, so a blocked move is never silent.
##
## Toggled with G. The grid itself is drawn at ground level (below the props, so roofs
## stay clean); the refusal flash is drawn on a child layer above everything.
class_name GridOverlay
extends Node2D

const DIAMOND := [
	Vector2(0, -16), Vector2(32, 0), Vector2(0, 16), Vector2(-32, 0)
]
const FLASH_TIME := 0.55
const WALKABLE_OUTLINE := Color(1, 1, 1, 0.10)
const BLOCKED_FILL := Color(0.90, 0.28, 0.22, 0.18)
const BLOCKED_OUTLINE := Color(0.95, 0.42, 0.32, 0.8)
const PLAYER_OUTLINE := Color(1.0, 0.95, 0.55, 0.9)

@export var map_path: NodePath
@export var player_path: NodePath

var show_overlay := false

var _map: MapBuilder
var _player: PlayerRen
var _flashes := {}
var _last_cell := Vector2i(99999, 99999)
var _flash_layer: Node2D


func _ready() -> void:
	_map = get_node_or_null(map_path) as MapBuilder
	_player = get_node_or_null(player_path) as PlayerRen

	# Separate canvas item so the "blocked" pulse stays visible even when the cell
	# sits behind a building.
	_flash_layer = Node2D.new()
	_flash_layer.name = "FlashLayer"
	_flash_layer.z_as_relative = false
	_flash_layer.z_index = 200
	_flash_layer.draw.connect(_draw_flashes)
	add_child(_flash_layer)


func toggle() -> void:
	show_overlay = not show_overlay
	queue_redraw()


## Briefly highlight a cell that refused a step.
func flash(cell: Vector2i) -> void:
	_flashes[cell] = FLASH_TIME
	_flash_layer.queue_redraw()


func flash_count() -> int:
	return _flashes.size()


func blocked_cell_count() -> int:
	if _map == null:
		return 0
	var count := 0
	for y in _map.height:
		for x in _map.width:
			if not _map.is_walkable(Vector2i(x, y)):
				count += 1
	return count


func _process(delta: float) -> void:
	var redraw := show_overlay

	if not _flashes.is_empty():
		for cell in _flashes.keys():
			_flashes[cell] -= delta
			if _flashes[cell] <= 0.0:
				_flashes.erase(cell)
		_flash_layer.queue_redraw()

	if _player != null and _player.mover.cell != _last_cell:
		_last_cell = _player.mover.cell
		redraw = true

	if redraw:
		queue_redraw()


func _draw() -> void:
	if _map == null:
		return
	if not show_overlay:
		return

	for y in _map.height:
		for x in _map.width:
			var cell := Vector2i(x, y)
			var points := _cell_points(cell)
			if _map.is_walkable(cell):
				draw_polyline(_closed(points), WALKABLE_OUTLINE, 1.0)
			else:
				draw_colored_polygon(points, BLOCKED_FILL)
				draw_polyline(_closed(points), BLOCKED_OUTLINE, 1.0)

	if _player != null:
		draw_polyline(_closed(_cell_points(_player.mover.cell)), PLAYER_OUTLINE, 2.0)


func _draw_flashes() -> void:
	for cell in _flashes:
		var alpha: float = clampf(_flashes[cell] / FLASH_TIME, 0.0, 1.0)
		var points := _cell_points(cell)
		_flash_layer.draw_colored_polygon(points, Color(0.95, 0.25, 0.2, 0.34 * alpha))
		_flash_layer.draw_polyline(_closed(points), Color(1.0, 0.45, 0.35, alpha), 2.5)


func _cell_points(cell: Vector2i) -> PackedVector2Array:
	var centre := Isometric.grid_to_world(cell)
	var points := PackedVector2Array()
	for offset in DIAMOND:
		points.append(centre + offset)
	return points


func _closed(points: PackedVector2Array) -> PackedVector2Array:
	var out := points.duplicate()
	out.append(points[0])
	return out
