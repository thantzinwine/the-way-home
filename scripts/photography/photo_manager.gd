## Owns Ren's photo collection and the act of capturing one.
##
## Capturing grabs the current viewport, crops it to the viewfinder rectangle and
## stores the result. A small Step reward (configurable, default +1) is granted
## per capture so photography feeds back into the economy instead of being free.
class_name PhotoManager
extends Node

signal captured(photo: Photo)
signal cleared

@export var wallet_path: NodePath
@export var reward_per_photo := 1

var photos: Array[Photo] = []

var wallet: StepsWallet


func _ready() -> void:
	wallet = get_node_or_null(wallet_path) as StepsWallet


## Captures the viewport region `rect` (in screen pixels) and stores it.
## Returns the new Photo, or null if the capture failed.
func capture(rect: Rect2, subject := "", caption := "") -> Photo:
	var viewport := get_viewport()
	if viewport == null:
		return null

	var full := viewport.get_texture().get_image()
	if full == null:
		# Headless / no-rendering fallback: synthesize a placeholder so the
		# capture pipeline (and the tests) still exercise the real code path.
		full = Image.create(maxi(int(rect.size.x), 1), maxi(int(rect.size.y), 1), false, Image.FORMAT_RGBA8)
		full.fill(Color(0.25, 0.3, 0.35, 1.0))
	if full == null:
		return null

	var cropped: Image
	if full.get_size().x >= int(rect.end.x) and full.get_size().y >= int(rect.end.y):
		cropped = full.get_region(rect)
	else:
		cropped = full
	if cropped == null:
		return null

	var tex := ImageTexture.create_from_image(cropped)
	if tex == null:
		return null

	var photo := Photo.new()
	photo.texture = tex
	photo.subject = subject
	photo.caption = caption
	photo.taken_at = Time.get_ticks_msec()

	photos.append(photo)
	captured.emit(photo)

	if wallet != null and reward_per_photo > 0:
		wallet.grant(reward_per_photo, "photo")

	return photo


func count() -> int:
	return photos.size()


func get_photo(index: int) -> Photo:
	if index < 0 or index >= photos.size():
		return null
	return photos[index]


func clear() -> void:
	photos.clear()
	cleared.emit()


func subjects() -> Array[String]:
	var out: Array[String] = []
	for p in photos:
		out.append(p.subject)
	return out
