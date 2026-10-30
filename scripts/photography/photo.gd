## A single captured image plus its metadata.
##
## Kept as a RefCounted so the log can hold hundreds of them without bloating the
## scene tree, and so tests can inspect captures without touching any UI.
class_name Photo
extends RefCounted

var texture: ImageTexture
var caption := ""
var subject := ""
var taken_at := 0


func is_valid() -> bool:
	return texture != null and texture.get_image() != null


func size() -> Vector2i:
	if texture == null:
		return Vector2i.ZERO
	return texture.get_size()
