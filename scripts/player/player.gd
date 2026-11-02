## Ren - player controller (3D).
class_name PlayerRen
extends CharacterBody3D

signal step_taken(from_cell: Vector2i, to_cell: Vector2i, cost: int)
signal move_refused(reason: String, cost: int)

@onready var mover: GridMover = $GridMover

var input_enabled := true
var facing := "s"
var wallet: StepsWallet

var _anim_player: AnimationPlayer = null
var _is_walking := false
var _walk_anim := ""
var _target_yaw := 0.0
var _walk_rate := 1.0

# How far the Mixamo walk clip travels per second at playback speed 1.0.
# Used to keep the leg cadence locked to the grid speed.
const NATIVE_WALK_SPEED := 0.5208


func setup(start_cell: Vector2i, walkable: Callable, economy: StepsWallet = null) -> void:
	wallet = economy
	mover.setup(self, start_cell, walkable)
	global_position = Isometric.grid_to_world(start_cell)
	_target_yaw = rotation.y
	for n in _all_nodes(self):
		if n is AnimationPlayer:
			_anim_player = n
			break
	# Detect available animations
	if _anim_player != null:
		if _anim_player.has_animation("mixamo_com"):
			_walk_anim = "mixamo_com"
		elif _anim_player.has_animation("Take 001"):
			_walk_anim = "Take 001"
		# Loop every clip so the walk cycle is seamless.
		for anim_name in _anim_player.get_animation_list():
			var anim := _anim_player.get_animation(anim_name)
			if anim != null:
				anim.loop_mode = Animation.LOOP_LINEAR
		# The Mixamo clip has its forward travel baked into the Hips track.
		# Left in, that makes the model drift and snap back on every loop, so we
		# flatten the horizontal component and move the body with the grid instead.
		if _walk_anim != "":
			_strip_root_motion(_anim_player.get_animation(_walk_anim))
		# Play the walk clip faster when the grid speed is faster, slower when
		# slower, so the feet always match the ground. Changing step_duration on
		# the GridMover keeps both in sync automatically.
		var grid_speed := 1.0 / maxf(mover.step_duration, 0.01)
		_walk_rate = grid_speed / NATIVE_WALK_SPEED
		_anim_player.speed_scale = _walk_rate
		if _walk_anim != "":
			# Start on a still frame of the walk so the character never shows a
			# T-pose (Take 001 is the bind pose) while standing around.
			_anim_player.play(_walk_anim)
			_anim_player.pause()


func _strip_root_motion(anim: Animation) -> void:
	if anim == null:
		return
	for t in anim.get_track_count():
		if anim.track_get_type(t) != Animation.TYPE_POSITION_3D:
			continue
		if not str(anim.track_get_path(t)).ends_with("Hips"):
			continue
		var base: Vector3 = anim.track_get_key_value(t, 0)
		for i in anim.track_get_key_count(t):
			var v: Vector3 = anim.track_get_key_value(t, i)
			v.x = base.x
			v.z = base.z
			anim.track_set_key_value(t, i, v)



func face_toward(other_cell: Vector2i) -> void:
	var delta := other_cell - mover.cell
	if delta == Vector2i.ZERO:
		return
	facing = Isometric.facing_name(delta)
	_target_yaw = Isometric.facing_yaw(delta)


func _ready() -> void:
	mover.step_finished.connect(_on_step_finished)
	mover.step_blocked.connect(_on_step_blocked)


func _physics_process(delta: float) -> void:
	# Ease the turn instead of snapping between 45-degree facings.
	rotation.y = lerp_angle(rotation.y, _target_yaw, clampf(delta * 14.0, 0.0, 1.0))
	if not input_enabled:
		return
	if mover.is_moving:
		_set_walking(true)
		return

	var input_dir := Vector2i(
		roundi(Input.get_axis("move_left", "move_right")),
		roundi(Input.get_axis("move_up", "move_down"))
	)

	if input_dir == Vector2i.ZERO:
		_set_walking(false)
		return

	var delta_cell := Isometric.input_to_grid(input_dir)
	facing = Isometric.facing_name(delta_cell)
	_target_yaw = Isometric.facing_yaw(delta_cell)

	var step_cost := 0

	if wallet != null:
		if wallet.frozen:
			move_refused.emit("frozen", 0)
			_set_walking(false)
			return
		step_cost = wallet.config.cost_per_cell
		if not wallet.can_afford(step_cost):
			move_refused.emit("steps", step_cost)
			_set_walking(false)
			return

	if mover.try_step(delta_cell):
		if wallet != null:
			wallet.spend(step_cost, "move")
		step_taken.emit(mover.cell, mover.last_target, mover.last_cost)
		_set_walking(true)
	else:
		_set_walking(false)


func _set_walking(walk: bool) -> void:
	if _anim_player == null:
		return
	if walk:
		if _walk_anim != "":
			_anim_player.speed_scale = _walk_rate
			if _anim_player.current_animation != _walk_anim or not _anim_player.is_playing():
				_anim_player.play(_walk_anim)
		_is_walking = true
	else:
		# Freeze on the current stride rather than switching to the T-pose
		# bind clip or a rest pose.
		if _is_walking and _anim_player.is_playing():
			_anim_player.pause()
		_is_walking = false


func _on_step_finished(_cell: Vector2i) -> void:
	var has_input := (
		Input.get_axis("move_left", "move_right") != 0.0
		or Input.get_axis("move_up", "move_down") != 0.0
	)
	if not has_input:
		_set_walking(false)


func _on_step_blocked(_cell: Vector2i) -> void:
	_set_walking(false)


func _all_nodes(n: Node) -> Array:
	var out := [n]
	for c in n.get_children():
		out.append_array(_all_nodes(c))
	return out
