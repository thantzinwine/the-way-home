## Entry point for the 3D prototype.
class_name MainRoot
extends Node3D

@onready var map: MapBuilder = $Map
@onready var world: Node3D = $World
@onready var player: PlayerRen = $World/Ren
@onready var camera: Camera3D = $World/Camera3D
@onready var overlay: GridOverlay = $GridOverlay
@onready var steps: StepsWallet = $Steps
@onready var hud: HUD = $HUD
@onready var npcs: NPCManager = $NPCs
@onready var dialogue: DialogueRunner = $Dialogue
@onready var interaction: InteractionSystem = $Interaction
@onready var dialogue_box: DialogueBox = $DialogueBox
@onready var photos: PhotoManager = $Photos
@onready var photo_mode: PhotoMode = $PhotoMode
@onready var photo_log: PhotoLog = $PhotoLog
@onready var save_manager: SaveManager = $Save
@onready var debug_label: Label = $DebugLayer/DebugLabel
@onready var hint_label: Label = $DebugLayer/HintLabel

var steps_taken := 0
var cells_travelled := 0

var cam_yaw := deg_to_rad(45.0)
var cam_pitch := deg_to_rad(-35.0)
var cam_distance := 20.0
var _rotating := false
var _cam_pos := Vector3.ZERO


func _ready() -> void:
	map.build()
	npcs.spawn_all()
	player.setup(map.start_cell, map.is_walkable, steps)
	player.step_taken.connect(_on_step_taken)
	player.mover.step_blocked.connect(_on_step_blocked)
	if camera != null:
		camera.projection = Camera3D.PROJECTION_ORTHOGONAL
		camera.size = 24.0
		camera.make_current()
	_cam_pos = player.global_position

	debug_label.visible = false
	hint_label.text = "WASD move  E talk  F photo  Tab album  G grid  F3 debug  F5/F6 steps  F7 save  F8 load  RMB drag orbit  wheel zoom"


func _on_step_blocked(cell: Vector2i) -> void:
	if overlay != null:
		overlay.flash(cell)


func _on_step_taken(_from_cell: Vector2i, _to_cell: Vector2i, cost: int) -> void:
	steps_taken += 1
	cells_travelled += cost


func _physics_process(delta: float) -> void:
	# Fixed camera: ground plane does not move when player walks.
	if camera != null:
		var center := Vector3(16.0, 0.0, 14.0)
		var rot := Basis.from_euler(Vector3(cam_pitch, cam_yaw, 0))
		camera.global_position = center + rot * Vector3(0, 0, cam_distance)
		camera.look_at(center + Vector3(0, 0.5, 0), Vector3.UP)

	if Input.is_action_just_pressed("toggle_grid_overlay"):
		if overlay != null:
			overlay.toggle()
	if Input.is_action_just_pressed("toggle_debug"):
		debug_label.visible = not debug_label.visible
	if Input.is_action_just_pressed("debug_grant_steps"):
		steps.grant(50, "debug")
	if Input.is_action_just_pressed("debug_drain_steps"):
		steps.set_steps(0)
	if Input.is_action_just_pressed("save_game"):
		if save_manager.save_game():
			hud.show_toast("Game saved.", false)
		else:
			hud.show_toast("Save failed.", true)
	if Input.is_action_just_pressed("load_game"):
		if save_manager.load_game():
			hud.show_toast("Game loaded.", false)
		else:
			hud.show_toast("No save to load.", true)
	if debug_label.visible:
		debug_label.text = "\n".join([
			"cell      %s" % mover_cell(),
			"facing    %s" % player.facing,
			"moving    %s" % player.mover.is_moving,
			"last cost %d" % player.mover.last_cost,
			"steps %d / cells %d" % [steps_taken, cells_travelled],
			"balance   %d (frozen %s)" % [steps.steps, steps.frozen],
			"npcs      %d" % npcs.npcs.size(),
			"dialogue  %s" % ("active" if dialogue.active else "idle"),
		])


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		if mb.button_index == MOUSE_BUTTON_RIGHT:
			_rotating = mb.pressed
		elif mb.button_index == MOUSE_BUTTON_WHEEL_UP:
			camera.size = clampf(camera.size - 1.0, 4.0, 40.0)
		elif mb.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			camera.size = clampf(camera.size + 1.0, 4.0, 40.0)
	elif event is InputEventMouseMotion and _rotating:
		var mm := event as InputEventMouseMotion
		cam_yaw -= mm.relative.x * 0.005
		cam_pitch = clampf(cam_pitch - mm.relative.y * 0.005, deg_to_rad(-75.0), deg_to_rad(-10.0))


func mover_cell() -> Vector2i:
	return player.mover.cell
