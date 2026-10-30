## Ren - player controller.
##
## Reads 8-way input, converts it to a grid delta, asks the GridMover to animate it
## and keeps the directional animation in sync. All the geometry lives in Isometric,
## all the interpolation lives in GridMover, so this script stays about intent.
class_name PlayerRen
extends CharacterBody2D

signal step_taken(from_cell: Vector2i, to_cell: Vector2i, cost: int)
signal move_refused(reason: String, cost: int)

@onready var sprite: AnimatedSprite2D = $Sprite
@onready var mover: GridMover = $GridMover

## Disabled while dialogue / menus own the input.
var input_enabled := true
var facing := "s"
## Charged by the Steps economy; null means movement is free (used by some tests).
var wallet: StepsWallet


func setup(start_cell: Vector2i, walkable: Callable, economy: StepsWallet = null) -> void:
	wallet = economy
	mover.setup(self, start_cell, walkable)
	global_position = Isometric.grid_to_world(start_cell)
	_play_idle()


## Turns Ren to face a grid cell (used when starting a conversation).
func face_toward(other_cell: Vector2i) -> void:
	var delta := other_cell - mover.cell
	if delta == Vector2i.ZERO:
		return
	facing = Isometric.facing_name(delta)
	_play_idle()


func _ready() -> void:
	mover.step_finished.connect(_on_step_finished)
	mover.step_blocked.connect(_on_step_blocked)


func _physics_process(_delta: float) -> void:
	if not input_enabled:
		return
	if mover.is_moving:
		return

	var input_dir := Vector2i(
		roundi(Input.get_axis("move_left", "move_right")),
		roundi(Input.get_axis("move_up", "move_down"))
	)

	if input_dir == Vector2i.ZERO:
		_play_idle()
		return

	var delta_cell := Isometric.input_to_grid(input_dir)
	facing = Isometric.facing_name(delta_cell)
	var step_cost := 0

	if wallet != null:
		if wallet.frozen:
			move_refused.emit("frozen", 0)
			_play_idle()
			return
		# Every move costs one Step, in every direction: the cost is per move, not
		# per cell, so the eight compass directions all price the same.
		step_cost = wallet.config.cost_per_cell
		if not wallet.can_afford(step_cost):
			move_refused.emit("steps", step_cost)
			_play_idle()
			return

	if mover.try_step(delta_cell):
		_play("walk_%s" % facing)
		if wallet != null:
			wallet.spend(step_cost, "move")
		step_taken.emit(mover.cell, mover.last_target, mover.last_cost)
	else:
		# Keep facing the blocked direction, but stand still.
		_play_idle()


func _play_idle() -> void:
	_play("idle_%s" % facing)


func _play(anim: String) -> void:
	if sprite.animation != anim:
		sprite.play(anim)
	elif not sprite.is_playing():
		sprite.play(anim)


func _on_step_finished(_cell: Vector2i) -> void:
	var has_input := (
		Input.get_axis("move_left", "move_right") != 0.0
		or Input.get_axis("move_up", "move_down") != 0.0
	)
	if not has_input:
		_play_idle()


func _on_step_blocked(_cell: Vector2i) -> void:
	_play_idle()
