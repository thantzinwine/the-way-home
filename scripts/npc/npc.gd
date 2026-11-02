## A family member / townsperson Ren can talk to (3D).
class_name NPC
extends Node3D

# Model key -> FBX path. Walkers pick one via the WALKERS table.
const MODEL_PATHS := {
	"ch01": "res://assets/characters/ch01/ch01_walk.fbx",
	"aj": "res://assets/characters/aj/aj_walk.fbx",
	"mother": "res://assets/characters/mother/MOMWALK.fbx",
	"father": "res://assets/characters/father/NPC1 mALE WALK.fbx",
	"sister": "res://assets/characters/sister/SISTERWALK.fbx",
	"idle": "res://assets/characters/idle/idle.fbx",
}

# Forward speed baked into each model's walk clip (cells/sec at playback 1x).
const NATIVE_SPEEDS := {
	"ch01": 0.641,
	"aj": 0.521,
	"mother": 0.698,
	"father": 0.929,
	"sister": 0.698,
	"idle": 0.0,
}

# Walking NPCs: model, speed (cells/sec) and the two end points of the route.
const WALKERS := {
	"walker": {"model": "ch01", "speed": 1.56, "points": [Vector2i(24, 25), Vector2i(8, 3)]},
	"walker2": {"model": "mother", "speed": 1.35, "points": [Vector2i(2, 15), Vector2i(29, 15)]},
	"walker3": {"model": "father", "speed": 1.7, "points": [Vector2i(6, 10), Vector2i(26, 16)]},
	"walker4": {"model": "sister", "speed": 1.35, "points": [Vector2i(15, 2), Vector2i(15, 26)]},
	"walker5": {"model": "ch01", "speed": 1.5, "points": [Vector2i(29, 2), Vector2i(2, 26)]},
}

@onready var model: Node3D = $Model
@onready var name_label: Label3D = $NameLabel

var id := ""
var display_name := ""
var cell := Vector2i.ZERO
var facing := "s"
var dialogue_path := ""
var map: MapBuilder = null
var is_walker := false

# Walk behavior (for the walking NPC)
var walk_points: Array[Vector2i] = []
var walk_speed := 0.05  # cells per second (very slow walk)
var _walk_index := 0
var _walk_progress := 0.0
var _is_walking := false
var _path: Array[Vector2i] = []
var _path_index := 0
var _path_target := Vector2i.ZERO
var _stop_timer := 0.0
var _is_stopped := false
var _target_yaw := 0.0

var _anim_player: AnimationPlayer = null
var _walk_rate := 1.0


func setup(definition: Dictionary) -> bool:
	id = str(definition.get("id", ""))
	display_name = str(definition.get("name", id.capitalize()))
	cell = definition.get("cell", Vector2i.ZERO)
	facing = str(definition.get("facing", "s"))
	dialogue_path = str(definition.get("dialogue", ""))

	global_position = Isometric.grid_to_world(cell)
	_apply_facing_from_string(facing)
	_target_yaw = rotation.y

	if name_label != null:
		name_label.text = display_name

	# Walking NPC: configure the route BEFORE loading the model so the
	# animation rate is calculated from the real walk speed.
	var walker_def: Dictionary = WALKERS.get(id, {})
	if not walker_def.is_empty():
		is_walker = true
		walk_speed = float(walker_def.get("speed", 1.5))
		for p in walker_def.get("points", []):
			walk_points.append(p)
		_is_walking = true
		_walk_index = 0
		_walk_progress = 0.0
		cell = walk_points[0]
		global_position = Isometric.grid_to_world(cell)

	_load_model()

	return true


func _load_model() -> void:
	# Walkers pick their model from the route table; everyone else by id.
	var model_key := id
	var walker_def: Dictionary = WALKERS.get(id, {})
	if not walker_def.is_empty():
		model_key = str(walker_def.get("model", id))
	var fbx_path: String = MODEL_PATHS.get(model_key, "")
	var native_speed: float = NATIVE_SPEEDS.get(model_key, 1.0)

	if fbx_path == "":
		return
	var res = load(fbx_path)
	if res == null:
		return
	var inst = res.instantiate()
	if inst == null:
		return
	inst.name = "FBXModel"
	if model != null:
		model.add_child(inst)
	# find animation player
	for n in _all_nodes(self):
		if n is AnimationPlayer:
			_anim_player = n
			break
	if _anim_player == null:
		return
	# Loop every clip and remove baked forward travel from walk clips so the
	# character animates in place and never drifts/snaps at the loop point.
	for anim_name in _anim_player.get_animation_list():
		var a := _anim_player.get_animation(anim_name)
		if a == null:
			continue
		a.loop_mode = Animation.LOOP_LINEAR
		_strip_root_motion(a)

	# Walking NPC: play its walk clip in sync with its travel speed.
	if is_walker and _anim_player.has_animation("mixamo_com"):
		_walk_rate = clampf(walk_speed / maxf(native_speed, 0.05), 0.02, 6.0)
		_anim_player.speed_scale = _walk_rate
		_anim_player.play("mixamo_com")
	elif id == "grandmother" and _anim_player.has_animation("mixamo_com"):
		# idle.fbx ships a real idle loop - play it at normal speed.
		_anim_player.speed_scale = 1.0
		_anim_player.play("mixamo_com")
	elif _anim_player.has_animation("Take 001"):
		# Take 001 is the T-pose bind clip, so instead freeze the walk on a
		# neutral passing pose - no T-pose, no walking on the spot.
		if _anim_player.has_animation("mixamo_com"):
			var walk := _anim_player.get_animation("mixamo_com")
			_anim_player.play("mixamo_com")
			_anim_player.seek(walk.length * 0.25)
			_anim_player.pause()
		else:
			_anim_player.play("Take 001")
			_anim_player.pause()
	elif _anim_player.has_animation("mixamo_com"):
		_anim_player.speed_scale = 0.0
		_anim_player.play("mixamo_com")


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


## Forward speed baked into a walk clip, in cells per second.
func _native_walk_speed(anim_name: String) -> float:
	if _anim_player == null or not _anim_player.has_animation(anim_name):
		return 1.0
	var anim := _anim_player.get_animation(anim_name)
	var speed := 1.0
	for t in anim.get_track_count():
		if anim.track_get_type(t) != Animation.TYPE_POSITION_3D:
			continue
		if not str(anim.track_get_path(t)).ends_with("Hips"):
			continue
		var first: Vector3 = anim.track_get_key_value(t, 0)
		var last: Vector3 = anim.track_get_key_value(t, anim.track_get_key_count(t) - 1)
		var travelled := Vector2(last.x - first.x, last.z - first.z).length()
		if anim.length > 0.001 and travelled > 0.01:
			speed = travelled / anim.length
		break
	return maxf(speed, 0.05)




func _create_primitive_fallback(color: Color) -> void:
	var mi := MeshInstance3D.new()
	var cm := CapsuleMesh.new()
	cm.radius = 0.3
	cm.height = 1.2
	mi.mesh = cm
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mi.material_override = mat
	mi.position = Vector3(0, 0.6, 0)
	if model != null:
		model.add_child(mi)


func frames_path() -> String:
	return "res://assets/characters/%s/%s_frames.tres" % [id, id]


func portrait_path() -> String:
	return "res://assets/characters/%s/%s_portrait.png" % [id, id]


func face_toward(target_cell: Vector2i) -> void:
	var delta := target_cell - cell
	if delta == Vector2i.ZERO:
		return
	facing = Isometric.facing_name(delta)
	_apply_facing_delta(delta)


func is_talking_to(other_cell: Vector2i) -> bool:
	return Isometric.facing_name(other_cell - cell) == facing


func _apply_facing_from_string(f: String) -> void:
	match f:
		"n": rotation.y = PI
		"ne": rotation.y = -PI * 0.75
		"e": rotation.y = -PI * 0.5
		"se": rotation.y = -PI * 0.25
		"s": rotation.y = 0.0
		"sw": rotation.y = PI * 0.25
		"w": rotation.y = PI * 0.5
		"nw": rotation.y = PI * 0.75


func _apply_facing_delta(delta: Vector2i) -> void:
	if delta == Vector2i.ZERO:
		return
	rotation.y = Isometric.facing_yaw(delta)


func _process(delta: float) -> void:
	if not _is_walking or walk_points.size() < 2:
		return

	# Handle stop at destination
	if _is_stopped:
		_stop_timer -= delta
		# Freeze on the current walking pose while resting so the model never
		# snaps to a rest/T-pose.
		if _anim_player != null:
			_anim_player.speed_scale = 0.0
		if _stop_timer <= 0.0:
			_is_stopped = false
			_walk_index = (_walk_index + 1) % walk_points.size()
			_path = []
			_path_index = 0
		return

	var target_cell := walk_points[(_walk_index + 1) % walk_points.size()]

	# Compute path if needed
	if _path.is_empty() or _path_target != target_cell:
		_path = _find_path(cell, target_cell)
		_path_index = 0
		_path_target = target_cell
		if _path.is_empty():
			_is_stopped = true
			_stop_timer = 5.0
			return

	# Walk along path
	if _path_index >= _path.size():
		# reached destination
		_is_stopped = true
		_stop_timer = 10.0
		cell = target_cell
		global_position = Isometric.grid_to_world(cell)
		if _anim_player != null:
			_anim_player.speed_scale = 0.0
		return

	var next_cell := _path[_path_index]
	var from_pos := Isometric.grid_to_world(cell)
	var to_pos := Isometric.grid_to_world(next_cell)
	var step_dist := maxf(Vector2(next_cell - cell).length(), 0.001)
	_walk_progress += (walk_speed / step_dist) * delta

	# Turn toward the next cell.
	var delta_cell := next_cell - cell
	if delta_cell != Vector2i.ZERO:
		_target_yaw = Isometric.facing_yaw(delta_cell)

	if _walk_progress >= 1.0:
		_walk_progress = 0.0
		cell = next_cell
		_path_index += 1

	global_position = from_pos.lerp(to_pos, clampf(_walk_progress, 0.0, 1.0))
	rotation.y = lerp_angle(rotation.y, _target_yaw, clampf(delta * 10.0, 0.0, 1.0))

	# Play the walk clip at a rate matched to the travel speed.
	if _anim_player != null and _anim_player.has_animation("mixamo_com"):
		_anim_player.speed_scale = _walk_rate
		if not _anim_player.is_playing():
			_anim_player.play("mixamo_com")


func _find_path(from: Vector2i, to: Vector2i) -> Array[Vector2i]:
	# BFS pathfinding avoiding blocked cells
	var path: Array[Vector2i] = []
	if from == to:
		return path
	if map == null:
		path.append(to)
		return path

	var visited := {}
	var queue: Array[Vector2i] = [from]
	var came_from := {}
	visited[from] = true
	came_from[from] = from

	var found := false
	while not queue.is_empty():
		var current: Vector2i = queue.pop_front()
		if current == to:
			found = true
			break
		for dx in [-1, 0, 1]:
			for dy in [-1, 0, 1]:
				if dx == 0 and dy == 0:
					continue
				var neighbor: Vector2i = current + Vector2i(dx, dy)
				if visited.has(neighbor):
					continue
				if not map.is_walkable(neighbor):
					continue
				# Do not squeeze diagonally past a blocked corner.
				if dx != 0 and dy != 0:
					if not map.is_walkable(Vector2i(current.x + dx, current.y)):
						continue
					if not map.is_walkable(Vector2i(current.x, current.y + dy)):
						continue
				visited[neighbor] = true
				came_from[neighbor] = current
				queue.append(neighbor)

	if not found:
		return path

	# Reconstruct path
	var cur: Vector2i = to
	while cur != from:
		path.push_front(cur)
		cur = came_from[cur] as Vector2i
	return path


func _all_nodes(n: Node) -> Array:
	var out := [n]
	for c in n.get_children():
		out.append_array(_all_nodes(c))
	return out
