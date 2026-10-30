## Generates a SpriteFrames resource for every character from its placeholder sheet.
##
## Sheet layout (must be preserved by final art):
##   frame size 48x64, origin at the feet (24, 62)
##   rows    = 8 facings, clockwise from north: n, ne, e, se, s, sw, w, nw
##   columns = idle, walk_1, walk_2, walk_3, walk_4
##
## Files in:  res://assets/characters/<id>/<id>_sheet_placeholder.png
## Files out: res://assets/characters/<id>/<id>_frames.tres
##
## Run:  godot --headless --path . --script res://tools/build_character_frames.gd
extends SceneTree

const CHARACTERS := ["ren", "mother", "father", "grandmother", "sister"]

const FRAME_SIZE := Vector2i(48, 64)
const IDLE_COLUMN := 0
const WALK_COLUMNS := 4

const FACINGS := ["n", "ne", "e", "se", "s", "sw", "w", "nw"]


func _initialize() -> void:
	var failures := 0
	for char_id in CHARACTERS:
		if not _build(char_id):
			failures += 1
	quit(0 if failures == 0 else 1)


func _build(char_id: String) -> bool:
	var sheet_path := "res://assets/characters/%s/%s_sheet_placeholder.png" % [char_id, char_id]
	var out_path := "res://assets/characters/%s/%s_frames.tres" % [char_id, char_id]

	var sheet: Texture2D = load(sheet_path)
	if sheet == null:
		push_error("Could not load %s" % sheet_path)
		return false

	var frames := SpriteFrames.new()
	frames.remove_animation("default")

	for row in FACINGS.size():
		var facing: String = FACINGS[row]

		var idle := "idle_%s" % facing
		frames.add_animation(idle)
		frames.set_animation_speed(idle, 1.0)
		frames.set_animation_loop(idle, true)
		frames.add_frame(idle, _at(sheet, row, IDLE_COLUMN))

		var walk := "walk_%s" % facing
		frames.add_animation(walk)
		frames.set_animation_speed(walk, 10.0)
		frames.set_animation_loop(walk, true)
		for i in WALK_COLUMNS:
			frames.add_frame(walk, _at(sheet, row, 1 + i))

	var err := ResourceSaver.save(frames, out_path)
	if err != OK:
		push_error("Failed to save %s: %d" % [out_path, err])
		return false

	print("[build_character_frames] wrote %s (%d animations)" % [out_path, frames.get_animation_names().size()])
	return true


func _at(sheet: Texture2D, row: int, column: int) -> AtlasTexture:
	var tex := AtlasTexture.new()
	tex.atlas = sheet
	tex.region = Rect2(column * FRAME_SIZE.x, row * FRAME_SIZE.y, FRAME_SIZE.x, FRAME_SIZE.y)
	return tex
