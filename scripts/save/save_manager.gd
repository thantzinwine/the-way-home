## Central save/load for Chapter 1.
##
## Owns one slot (user://save_slot_1.json) plus the photo images that live
## alongside it (user://photos/). Everything else (wallet, dialogue flags,
## photo list, player cell) is gathered from and restored into the live systems,
## so no gameplay script needs to know about files.
class_name SaveManager
extends Node

const SAVE_PATH := "user://save_slot_1.json"
const PHOTO_DIR := "user://photos/"

@export var main_path: NodePath

var main: Node2D
var player: PlayerRen
var map: MapBuilder
var steps: StepsWallet
var dialogue: DialogueRunner
var photos: PhotoManager


func _ready() -> void:
	main = get_node_or_null(main_path) as Node2D
	if main == null:
		return
	player = main.get_node_or_null("World/Ren") as PlayerRen
	map = main.get_node_or_null("Map") as MapBuilder
	steps = main.get_node_or_null("Steps") as StepsWallet
	dialogue = main.get_node_or_null("Dialogue") as DialogueRunner
	photos = main.get_node_or_null("Photos") as PhotoManager


## Writes the current game state to disk. Returns true on success.
func save_game() -> bool:
	if main == null:
		return false

	# Make sure the photo directory exists.
	var global_photo_dir := ProjectSettings.globalize_path(PHOTO_DIR)
	DirAccess.make_dir_recursive_absolute(global_photo_dir)

	var photo_entries: Array = []
	for i in photos.photos.size():
		var p: Photo = photos.photos[i]
		var img_path := PHOTO_DIR + "photo_%d.png" % i
		if p.texture != null:
			var img := p.texture.get_image()
			if img != null:
				img.save_png(ProjectSettings.globalize_path(img_path))
		photo_entries.append({
			"subject": p.subject,
			"caption": p.caption,
			"taken_at": p.taken_at,
			"path": img_path,
		})

	var data := {
		"version": 1,
		"player": {
			"cell": [player.mover.cell.x, player.mover.cell.y],
			"facing": player.facing,
		},
		"steps": steps.steps,
		"frozen": steps.frozen,
		"departure_progress": steps.departure_progress,
		"flags": dialogue.flags.duplicate(true) if dialogue != null else {},
		"photos": photo_entries,
	}

	var json := JSON.stringify(data, "\t")
	var file := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if file == null:
		push_error("SaveManager: could not open %s for writing" % SAVE_PATH)
		return false
	file.store_string(json)
	file.close()
	return true


## Restores game state from disk. Returns true if a save was loaded.
func load_game() -> bool:
	if not FileAccess.file_exists(SAVE_PATH):
		return false

	var file := FileAccess.open(SAVE_PATH, FileAccess.READ)
	if file == null:
		return false
	var text := file.get_as_text()
	file.close()

	var parsed: Variant = JSON.parse_string(text)
	if typeof(parsed) != TYPE_DICTIONARY:
		push_error("SaveManager: save file is not a JSON object")
		return false
	var data: Dictionary = parsed

	# Steps.
	if steps != null:
		steps.restore(int(data.get("steps", 150)),
			bool(data.get("frozen", false)),
			float(data.get("departure_progress", 0.0)))

	# Dialogue flags.
	if dialogue != null:
		dialogue.flags = data.get("flags", {}).duplicate(true)

	# Player position.
	if player != null and map != null:
		var player_data: Dictionary = data.get("player", {})
		var cell_arr: Array = player_data.get("cell", [map.start_cell.x, map.start_cell.y])
		var cell := Vector2i(int(cell_arr[0]), int(cell_arr[1]))
		if not map.is_walkable(cell):
			cell = map.start_cell
		player.setup(cell, map.is_walkable, steps)
		player.facing = str(player_data.get("facing", "s"))
		player._play_idle()

	# Photos.
	if photos != null:
		photos.clear()
		for entry in data.get("photos", []):
			var e: Dictionary = entry
			var img_path := str(e.get("path", ""))
			var global_path := ProjectSettings.globalize_path(img_path)
			var tex: ImageTexture = null
			if FileAccess.file_exists(img_path):
				var img := Image.load_from_file(global_path)
				if img != null:
					tex = ImageTexture.create_from_image(img)
			var photo := Photo.new()
			photo.texture = tex
			photo.subject = str(e.get("subject", ""))
			photo.caption = str(e.get("caption", ""))
			photo.taken_at = int(e.get("taken_at", 0))
			photos.photos.append(photo)
		photos.captured.emit(photos.photos.back() if photos.photos.size() > 0 else null)

	return true


## Deletes the save slot (new game).
func delete_save() -> void:
	if FileAccess.file_exists(SAVE_PATH):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(SAVE_PATH))
	if photos != null:
		photos.clear()


func has_save() -> bool:
	return FileAccess.file_exists(SAVE_PATH)
