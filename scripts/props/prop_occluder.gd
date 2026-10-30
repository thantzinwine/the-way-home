## Fades a prop's sprite out while it is hiding the player.
##
## Attached automatically by MapBuilder to every placed prop. Purely visual: it never
## touches collision or sorting, so the y-sort result stays correct - the building is
## still drawn in front, it just stops blocking the view.
extends Node

const FADE_SPEED := 5.0

## Alpha the sprite fades down to while it covers the player.
@export var min_alpha := 0.4

var _sprite: Sprite2D
var _local_rect := Rect2()
var _player: Node2D


func setup(sprite: Sprite2D) -> void:
	_sprite = sprite
	var texture_size := sprite.texture.get_size() * sprite.scale
	if sprite.centered:
		_local_rect = Rect2(sprite.position - texture_size * 0.5, texture_size)
	else:
		_local_rect = Rect2(sprite.position + sprite.offset, texture_size)


func _process(delta: float) -> void:
	if _sprite == null or not is_instance_valid(_sprite):
		return
	if _player == null or not is_instance_valid(_player):
		_player = get_tree().get_first_node_in_group("player") as Node2D
		if _player == null:
			return

	var overlapped := _local_rect.has_point(_player.global_position - _sprite.global_position)
	var player_behind := _player.global_position.y < _sprite.global_position.y
	var target_alpha := min_alpha if (overlapped and player_behind) else 1.0

	var color := _sprite.modulate
	color.a = move_toward(color.a, target_alpha, delta * FADE_SPEED)
	_sprite.modulate = color
