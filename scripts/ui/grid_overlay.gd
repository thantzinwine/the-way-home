## Walkable grid overlay (3D).
class_name GridOverlay
extends Node3D

const FLASH_TIME := 0.55

@export var map_path: NodePath
@export var player_path: NodePath

var show_overlay := true

var _map: MapBuilder
var _player: PlayerRen
var _flashes := {}
var _overlay_root: Node3D
var _flash_root: Node3D


func _ready() -> void:
	_map = get_node_or_null(map_path) as MapBuilder
	_player = get_node_or_null(player_path) as PlayerRen
	_overlay_root = Node3D.new()
	_overlay_root.visible = show_overlay
	add_child(_overlay_root)
	_flash_root = Node3D.new()
	add_child(_flash_root)


func toggle() -> void:
	show_overlay = not show_overlay
	_overlay_root.visible = show_overlay
	if show_overlay:
		_rebuild_overlay()


func flash(cell: Vector2i) -> void:
	_flashes[cell] = FLASH_TIME
	_spawn_flash(cell)


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
	if not _flashes.is_empty():
		for cell in _flashes.keys():
			_flashes[cell] -= delta
			if _flashes[cell] <= 0.0:
				_flashes.erase(cell)
	for child in _flash_root.get_children():
		var t: float = child.get_meta("t", 0.0) - delta
		if t <= 0.0:
			child.queue_free()
		else:
			child.set_meta("t", t)
			var mi := child as MeshInstance3D
			if mi != null and mi.material_override is StandardMaterial3D:
				(mi.material_override as StandardMaterial3D).albedo_color.a = clampf(t / FLASH_TIME, 0.0, 1.0) * 0.6


func _rebuild_overlay() -> void:
	for c in _overlay_root.get_children():
		c.queue_free()
	if _map == null:
		return
	for y in _map.height:
		for x in _map.width:
			var cell := Vector2i(x, y)
			if not _map.is_walkable(cell):
				_add_plane(cell, Color(0.9, 0.28, 0.22, 0.35), _overlay_root)
	if _player != null:
		_add_plane(_player.mover.cell, Color(1.0, 0.95, 0.55, 0.5), _overlay_root)


func _add_plane(cell: Vector2i, color: Color, parent: Node3D) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var pm := PlaneMesh.new()
	pm.size = Vector2(0.95, 0.95)
	mi.mesh = pm
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mi.material_override = mat
	mi.position = Isometric.grid_to_world(cell) + Vector3(0, 0.02, 0)
	parent.add_child(mi)
	return mi


func _spawn_flash(cell: Vector2i) -> void:
	var mi := _add_plane(cell, Color(0.95, 0.25, 0.2, 0.6), _flash_root)
	mi.set_meta("t", FLASH_TIME)
