## Glues Ren, the NPCs and the dialogue runner together.
##
## Every frame it asks "who can Ren talk to right now?" and shows a prompt; pressing
## the interact key opens the conversation. While a conversation runs it keeps the
## prompt hidden and hands control to the dialogue box.
class_name InteractionSystem
extends Node

@export var player_path: NodePath
@export var npc_manager_path: NodePath
@export var dialogue_path: NodePath
@export var dialogue_box_path: NodePath
@export var photo_mode_path: NodePath

var player: PlayerRen
var npcs: NPCManager
var dialogue: DialogueRunner
var box: DialogueBox
var photo_mode: PhotoMode

var target: NPC


func _ready() -> void:
	player = get_node_or_null(player_path) as PlayerRen
	npcs = get_node_or_null(npc_manager_path) as NPCManager
	dialogue = get_node_or_null(dialogue_path) as DialogueRunner
	box = get_node_or_null(dialogue_box_path) as DialogueBox
	photo_mode = get_node_or_null(photo_mode_path) as PhotoMode

	if dialogue != null:
		dialogue.finished.connect(_on_finished)


func _process(_delta: float) -> void:
	if player == null or npcs == null or dialogue == null or box == null:
		return

	if dialogue.active:
		target = null
		box.show_prompt("")
		return

	if photo_mode != null and photo_mode.active:
		target = null
		box.show_prompt("")
		return

	if player.mover.is_moving or not player.input_enabled:
		target = null
		box.show_prompt("")
		return

	target = npcs.find_interactable(player.mover.cell, player.facing)
	if target == null:
		box.show_prompt("")
		return

	box.show_prompt("E  ·  Talk to %s" % target.display_name)

	if Input.is_action_just_pressed("interact"):
		begin(target)


## Opens a conversation with a specific NPC. Exposed so tests can drive it directly
## without simulating key presses.
func begin(npc: NPC) -> bool:
	if npc == null or dialogue.active:
		return false

	player.input_enabled = false
	player.face_toward(npc.cell)
	npc.face_toward(player.mover.cell)

	box.show_prompt("")
	var ok := dialogue.start(npc)
	if not ok:
		player.input_enabled = true
	return ok


## Convenience used by the tests and debug tooling.
func try_interact() -> bool:
	if target == null:
		return false
	return begin(target)


func _on_finished() -> void:
	if player != null:
		player.input_enabled = true
	target = null
