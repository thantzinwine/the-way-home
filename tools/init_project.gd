## One-time project bootstrap.
##
## Sets the input map and physics layer names using Godot's own serialiser, so
## project.godot always stays in the engine's canonical format.
##
## Run:  godot --headless --path . --script res://tools/init_project.gd
extends SceneTree


func _initialize() -> void:
	_add_action("move_up", [KEY_W, KEY_UP])
	_add_action("move_down", [KEY_S, KEY_DOWN])
	_add_action("move_left", [KEY_A, KEY_LEFT])
	_add_action("move_right", [KEY_D, KEY_RIGHT])

	# Reserved for later milestones (interaction / photography / menus).
	_add_action("interact", [KEY_E, KEY_SPACE])
	_add_action("take_photo", [KEY_F])
	_add_action("toggle_photo_log", [KEY_TAB])
	_add_action("toggle_debug", [KEY_F3])
	_add_action("toggle_grid_overlay", [KEY_G])
	_add_action("debug_grant_steps", [KEY_F5])
	_add_action("debug_drain_steps", [KEY_F6])
	_add_action("save_game", [KEY_F7])
	_add_action("load_game", [KEY_F8])
	_add_action("pause", [KEY_ESCAPE])

	ProjectSettings.set_setting("layer_names/2d_physics/layer_1", "world")
	ProjectSettings.set_setting("layer_names/2d_physics/layer_2", "player")
	ProjectSettings.set_setting("layer_names/2d_physics/layer_3", "props")

	var err := ProjectSettings.save()
	if err != OK:
		push_error("ProjectSettings.save failed: %d" % err)
		quit(1)
		return
	print("[init_project] input map + layer names written")
	quit(0)


func _add_action(action: StringName, keys: Array) -> void:
	var events: Array = []
	for k in keys:
		var ev := InputEventKey.new()
		ev.physical_keycode = k
		events.append(ev)
	ProjectSettings.set_setting("input/%s" % action, {"deadzone": 0.2, "events": events})
