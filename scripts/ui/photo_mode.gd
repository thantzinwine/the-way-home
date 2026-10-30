## Camera viewfinder overlay.
##
## Toggled with F. While it is open Ren can still walk (so the frame can be
## repositioned) but talking is disabled; Space/E takes a photo and F/Esc closes.
## The viewfinder rectangle is also the region that gets captured.
class_name PhotoMode
extends CanvasLayer

const VIEWFINDER := Vector2i(420, 280)

@export var player_path: NodePath
@export var npc_manager_path: NodePath
@export var map_path: NodePath
@export var photo_manager_path: NodePath
@export var photo_log_path: NodePath

@onready var frame: Control = $Root/Frame
@onready var subject_label: Label = $Root/Subject
@onready var hint: Label = $Root/Hint

var player: PlayerRen
var npcs: NPCManager
var map: MapBuilder
var photos: PhotoManager
var log_ui: PhotoLog

var active := false


func _ready() -> void:
	player = get_node_or_null(player_path) as PlayerRen
	npcs = get_node_or_null(npc_manager_path) as NPCManager
	map = get_node_or_null(map_path) as MapBuilder
	photos = get_node_or_null(photo_manager_path) as PhotoManager
	log_ui = get_node_or_null(photo_log_path) as PhotoLog

	visible = false
	frame.custom_minimum_size = Vector2(VIEWFINDER)


func toggle() -> void:
	active = not active
	visible = active


func _process(_delta: float) -> void:
	if not active:
		return
	_update_subject()


func _unhandled_input(event: InputEvent) -> void:
	if not active:
		return
	if event.is_action_pressed("interact"):
		_capture()
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("take_photo") or event.is_action_pressed("pause"):
		toggle()
		get_viewport().set_input_as_handled()


func _capture() -> void:
	if photos == null:
		return
	var rect := _viewfinder_rect()
	var subject := _subject_name()
	var photo := photos.capture(rect, subject, subject)
	if photo != null and log_ui != null:
		log_ui.flash_latest()


func _viewfinder_rect() -> Rect2:
	var vp := get_viewport().get_visible_rect().size
	var pos := (vp - Vector2(VIEWFINDER)) * 0.5
	return Rect2(pos, Vector2(VIEWFINDER))


func _update_subject() -> void:
	var name := _subject_name()
	subject_label.text = name if not name.is_empty() else "—"
	subject_label.modulate = Color(0.98, 0.86, 0.5) if not name.is_empty() else Color(0.7, 0.7, 0.7, 0.7)


func _subject_name() -> String:
	if map == null:
		return ""
	var vp := get_viewport().get_visible_rect().size
	var centre := vp * 0.5
	# Convert the viewfinder centre to a grid cell using the player's camera? We
	# approximate with the player's cell, which is what the camera follows.
	if player == null:
		return ""
	var cell := player.mover.cell
	# Check NPCs on the player's cell and its neighbours.
	if npcs != null:
		for npc in npcs.npcs:
			var d := npc.cell - cell
			if maxi(absi(d.x), absi(d.y)) <= 1:
				return npc.display_name
	# The Steps sign is a prop, not an NPC; detect it by name in the prop list.
	for prop in map.get_props():
		if not str(prop.name).begins_with("StepsSign") and not str(prop.name).begins_with("Sign"):
			continue
		var prop_cell := Isometric.world_to_grid(prop.position)
		var d := prop_cell - cell
		if maxi(absi(d.x), absi(d.y)) <= 1:
			return "the Steps sign"
	return ""
