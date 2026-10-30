## A family member / townsperson Ren can talk to.
##
## NPCs are static: they own a grid cell, block it, and turn to face whoever is
## speaking to them. Their art and dialogue come from the data file that spawned them,
## so adding a character is a line of data plus an art sheet - no code changes.
class_name NPC
extends CharacterBody2D

@onready var sprite: AnimatedSprite2D = $Sprite

var id := ""
var display_name := ""
var cell := Vector2i.ZERO
var facing := "s"
var dialogue_path := ""


## Returns false (after warning) if the character art cannot be found.
func setup(definition: Dictionary) -> bool:
	id = str(definition.get("id", ""))
	display_name = str(definition.get("name", id.capitalize()))
	cell = definition.get("cell", Vector2i.ZERO)
	facing = str(definition.get("facing", "s"))
	dialogue_path = str(definition.get("dialogue", ""))

	global_position = Isometric.grid_to_world(cell)

	var frames := load(frames_path()) as SpriteFrames
	if frames == null:
		push_warning("NPC '%s': no sprite frames at %s" % [id, frames_path()])
		return false
	sprite.sprite_frames = frames

	if not sprite.sprite_frames.has_animation("idle_%s" % facing):
		facing = "s"
	sprite.play("idle_%s" % facing)
	return true


func frames_path() -> String:
	return "res://assets/characters/%s/%s_frames.tres" % [id, id]


func portrait_path() -> String:
	return "res://assets/characters/%s/%s_portrait.png" % [id, id]


## Turns to look at a grid cell (used when Ren starts a conversation).
func face_toward(target_cell: Vector2i) -> void:
	var delta := target_cell - cell
	if delta == Vector2i.ZERO:
		return
	facing = Isometric.facing_name(delta)
	sprite.play("idle_%s" % facing)


func is_talking_to(other_cell: Vector2i) -> bool:
	return Isometric.facing_name(other_cell - cell) == facing
