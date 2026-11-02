## Smooth grid movement for a CharacterBody3D.
class_name GridMover
extends Node

signal step_started(from_cell: Vector2i, to_cell: Vector2i, cost: int)
signal step_finished(cell: Vector2i)
signal step_blocked(cell: Vector2i)

## Seconds to cross one grid cell. This is the pace knob: lower = faster.
## The player's walk animation playback rate is derived from this value, so the
## stride stays matched to the ground no matter how fast you set it.
@export var step_duration: float = 0.64

var cell := Vector2i.ZERO
var is_moving := false
var last_cost := 0
var last_target := Vector2i.ZERO

var _body: CharacterBody3D
var _walkable: Callable
var _from := Vector3.ZERO
var _to := Vector3.ZERO
var _elapsed := 0.0
var _move_time := 0.0


func setup(body: CharacterBody3D, start_cell: Vector2i, walkable: Callable) -> void:
	_body = body
	_walkable = walkable
	cell = start_cell
	last_target = start_cell
	is_moving = false
	_elapsed = 0.0
	_move_time = 0.0
	if is_instance_valid(_body):
		_body.global_position = Isometric.grid_to_world(cell)


func try_step(delta_cell: Vector2i) -> bool:
	if is_moving or delta_cell == Vector2i.ZERO:
		return false
	var target := cell + delta_cell
	var is_diagonal := delta_cell.x != 0 and delta_cell.y != 0

	if not _walkable.call(target):
		step_blocked.emit(target)
		return false

	if is_diagonal:
		var a := Vector2i(target.x, cell.y)
		var b := Vector2i(cell.x, target.y)
		if not (_walkable.call(a) or _walkable.call(b)):
			step_blocked.emit(a)
			return false
	else:
		for path_cell in Isometric.path_cells(cell, target):
			if path_cell == target:
				continue
			if not _walkable.call(path_cell):
				step_blocked.emit(path_cell)
				return false

	last_cost = Isometric.manhattan(delta_cell)
	last_target = target
	_from = Isometric.grid_to_world(cell)
	_to = Isometric.grid_to_world(target)
	# Time is based on true distance so diagonal steps move at the same speed
	# as straight ones (last_cost stays manhattan for the Steps economy).
	var travel := Vector2(delta_cell).length()
	_move_time = step_duration * maxf(travel, 0.001)
	_elapsed = 0.0
	is_moving = true

	step_started.emit(cell, target, last_cost)
	return true


func _physics_process(delta: float) -> void:
	if not is_moving:
		return
	_elapsed += delta
	var t := clampf(_elapsed / maxf(_move_time, 0.001), 0.0, 1.0)
	# Linear (constant velocity) interpolation: chaining cells stays perfectly
	# smooth. The old smoothstep eased to zero every cell and caused a stutter.
	var want := _from.lerp(_to, t)

	if is_instance_valid(_body):
		_body.global_position = want

	if t >= 1.0:
		if is_instance_valid(_body):
			_body.global_position = _to
		cell = last_target
		is_moving = false
		step_finished.emit(cell)
