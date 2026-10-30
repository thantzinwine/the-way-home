## Smooth grid movement for a CharacterBody2D.
##
## The node owns "which cell am I on" and animates the body towards the next cell.
## Walkability is injected as a Callable so the mover never needs to know whether
## the world is a tilemap, a navmesh or a test stub.
class_name GridMover
extends Node

signal step_started(from_cell: Vector2i, to_cell: Vector2i, cost: int)
signal step_finished(cell: Vector2i)
signal step_blocked(cell: Vector2i)

## Seconds spent per grid cell of travel.
@export var step_duration: float = 0.18

var cell := Vector2i.ZERO
var is_moving := false
## Grid cost of the most recent successful step (distance in cells).
var last_cost := 0
var last_target := Vector2i.ZERO

var _body: CharacterBody2D
var _walkable: Callable
var _from := Vector2.ZERO
var _to := Vector2.ZERO
var _elapsed := 0.0
var _move_time := 0.0


func setup(body: CharacterBody2D, start_cell: Vector2i, walkable: Callable) -> void:
	_body = body
	_walkable = walkable
	cell = start_cell
	last_target = start_cell
	# Cancel any step in flight: a reposition must win over the animation target,
	# otherwise the body keeps gliding to the old destination after being reset.
	is_moving = false
	_elapsed = 0.0
	_move_time = 0.0
	if is_instance_valid(_body):
		_body.velocity = Vector2.ZERO
		_body.global_position = Isometric.grid_to_world(cell)


## Attempts one step. Returns false (and emits step_blocked) if the destination
## or any cell along the way is not walkable, or if a step is already in progress.
##
## Diagonal moves allow corner-cutting: the target must be walkable and at least
## one of the two adjacent cells must be free (so a single wall doesn't block the
## diagonal, but a solid corner still does).
func try_step(delta_cell: Vector2i) -> bool:
	if is_moving or delta_cell == Vector2i.ZERO:
		return false

	var target := cell + delta_cell
	var is_diagonal := delta_cell.x != 0 and delta_cell.y != 0

	# Target must always be walkable.
	if not _walkable.call(target):
		step_blocked.emit(target)
		return false

	if is_diagonal:
		var a := Vector2i(target.x, cell.y)
		var b := Vector2i(cell.x, target.y)
		# Corner-cutting allowed: at least one adjacent cell must be free.
		if not (_walkable.call(a) or _walkable.call(b)):
			step_blocked.emit(a)
			return false
	else:
		# Axis-aligned: every cell along the way must be free.
		for path_cell in Isometric.path_cells(cell, target):
			if path_cell == target:
				continue
			if not _walkable.call(path_cell):
				step_blocked.emit(path_cell)
				return false

	last_cost = Isometric.manhattan(target - cell)
	last_target = target
	_from = Isometric.grid_to_world(cell)
	_to = Isometric.grid_to_world(target)
	_move_time = step_duration * float(last_cost) * 0.75
	_elapsed = 0.0
	is_moving = true

	step_started.emit(cell, target, last_cost)
	return true


func _physics_process(delta: float) -> void:
	if not is_moving:
		return

	_elapsed += delta
	var t := clampf(_elapsed / maxf(_move_time, 0.001), 0.0, 1.0)
	var eased := t * t * (3.0 - 2.0 * t)  # smoothstep
	var want := _from.lerp(_to, eased)

	# The grid is the single source of truth: walkability is validated in try_step(),
	# so the body is positioned directly instead of being pushed through move_and_slide().
	# Sliding around a collider would leave the body off-grid, which is what made the
	# character appear stuck between props whose collider was larger than their cells.
	if is_instance_valid(_body):
		_body.velocity = Vector2.ZERO
		_body.global_position = want

	if t >= 1.0:
		if is_instance_valid(_body):
			_body.global_position = _to
		cell = last_target
		is_moving = false
		step_finished.emit(cell)
