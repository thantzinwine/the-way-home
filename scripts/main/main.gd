## Entry point for the Milestone 1 prototype.
##
## Responsibilities: build the map, spawn Ren on a valid cell, wire the camera to the
## map bounds and expose a debug overlay. Gameplay lives in the player/movement scripts.
extends Node2D

@onready var map: MapBuilder = $Map
@onready var world: Node2D = $World
@onready var player: PlayerRen = $World/Ren
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


func _ready() -> void:
	map.build()
	npcs.spawn_all()
	player.setup(map.start_cell, map.is_walkable, steps)
	# Ren must be drawn on top of props/NPCs that share his Y, so he never
	# vanishes behind a building or a person standing on the same row. Y-sort
	# still puts genuinely-behind props in front; only exact ties go to Ren.
	player.reparent(world, true)
	world.move_child(player, world.get_child_count() - 1)
	player.step_taken.connect(_on_step_taken)
	player.mover.step_blocked.connect(_on_step_blocked)
	_apply_camera_limits()

	debug_label.visible = false
	hint_label.text = "WASD move  E talk  F photo  Tab album  G grid  F3 debug  F5/F6 steps  F7 save  F8 load"


func _on_step_blocked(cell: Vector2i) -> void:
	overlay.flash(cell)


func _on_step_taken(_from_cell: Vector2i, _to_cell: Vector2i, cost: int) -> void:
	steps_taken += 1
	cells_travelled += cost


func _apply_camera_limits() -> void:
	var cam := player.get_node_or_null("Camera2D") as Camera2D
	if cam == null:
		push_warning("Main: player has no Camera2D")
		return
	var rect := map.get_world_rect()
	cam.limit_left = int(rect.position.x)
	cam.limit_top = int(rect.position.y)
	cam.limit_right = int(rect.end.x)
	cam.limit_bottom = int(rect.end.y)
	cam.make_current()


func _process(_delta: float) -> void:
	if Input.is_action_just_pressed("toggle_grid_overlay"):
		overlay.toggle()
	if Input.is_action_just_pressed("toggle_debug"):
		debug_label.visible = not debug_label.visible
	# Prototype-only controls so the economy can be exercised by hand.
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
	if not debug_label.visible:
		return

	debug_label.text = "\n".join([
		"cell      %s" % mover_cell(),
		"facing    %s" % player.facing,
		"moving    %s" % player.mover.is_moving,
		"last cost %d" % player.mover.last_cost,
		"steps %d / cells %d" % [steps_taken, cells_travelled],
		"balance   %d (frozen %s)" % [steps.steps, steps.frozen],
		"npcs      %d" % npcs.npcs.size(),
		"dialogue  %s" % ("active" if dialogue.active else "idle"),
		"talk to   %s" % (npcs.find_interactable(player.mover.cell, player.facing).id if npcs.find_interactable(player.mover.cell, player.facing) else "-"),
	])


func mover_cell() -> Vector2i:
	return player.mover.cell
