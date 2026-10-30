## Captures reference screenshots of the Milestone 1 prototype.
##
## Must run with a rendering backend (not --headless):
##   godot --path . --script res://tests/capture_screenshot.gd
extends SceneTree

const SHOTS := [
	{"name": "01_spawn", "cell": Vector2i(2, 11), "facing": "ne"},
	{"name": "02_crossing", "cell": Vector2i(5, 7), "facing": "se"},
	{"name": "03_houses", "cell": Vector2i(5, 5), "facing": "nw"},
	{"name": "04_behind_house", "cell": Vector2i(3, 1), "facing": "se"},
]

var main: Node2D


func _initialize() -> void:
	_capture.call_deferred()


func _capture() -> void:
	root.size = Vector2i(1280, 720)
	main = load("res://scenes/main/main.tscn").instantiate()
	root.add_child(main)

	for i in 30:
		await process_frame

	var player: PlayerRen = main.player
	var cam := player.get_node("Camera2D") as Camera2D

	for shot in SHOTS:
		player.mover.setup(player, shot["cell"], main.map.is_walkable)
		player.facing = shot["facing"]
		player._play_idle()
		cam.reset_smoothing()
		for i in 12:
			await process_frame
		await RenderingServer.frame_post_draw

		var image := root.get_texture().get_image()
		var path := "res://tests/screenshot_%s.png" % shot["name"]
		var err := image.save_png(path)
		print("[capture] %s -> %s (err %d)" % [shot["name"], path, err])

	# Final shot: mid-step, to show movement is interpolated rather than snapped.
	player.mover.setup(player, Vector2i(3, 7), main.map.is_walkable)
	player.input_enabled = true
	Input.action_press("move_right")
	for i in 6:
		await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://tests/screenshot_05_walking.png")
	Input.action_release("move_right")
	print("[capture] 05_walking -> res://tests/screenshot_05_walking.png")
	print("[capture] mid-step position: %s (target would be %s)" % [
		player.global_position, Isometric.grid_to_world(Vector2i(4, 6))])

	# Debug overlay shot.
	var debug_label: Label = main.get_node("DebugLayer/DebugLabel")
	debug_label.visible = true
	for i in 6:
		await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://tests/screenshot_06_debug.png")
	print("[capture] 06_debug -> res://tests/screenshot_06_debug.png")

	# Walkable-grid overlay shot.
	debug_label.visible = false
	player.mover.setup(player, Vector2i(6, 7), main.map.is_walkable)
	player.facing = "se"
	player._play_idle()
	cam.reset_smoothing()
	var overlay: GridOverlay = main.get_node("GridOverlay")
	overlay.toggle()
	for i in 20:
		await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://tests/screenshot_07_grid.png")
	print("[capture] 07_grid -> res://tests/screenshot_07_grid.png")

	# HUD: healthy balance.
	overlay.toggle()
	var wallet: StepsWallet = main.get_node("Steps")
	wallet.set_steps(96)
	for i in 8:
		await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://tests/screenshot_08_hud.png")
	print("[capture] 08_hud -> res://tests/screenshot_08_hud.png")

	# HUD: frozen state with the Departure clock.
	wallet.set_steps(0)
	for i in 20:
		await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://tests/screenshot_09_frozen.png")
	print("[capture] 09_frozen -> res://tests/screenshot_09_frozen.png")

	# Dialogue: talking to Daw Mya.
	wallet.set_steps(9999)
	player.mover.setup(player, Vector2i(3, 11), main.map.is_walkable)
	player.facing = "e"
	player.input_enabled = true
	for i in 10:
		await process_frame
	var mother: NPC = main.get_node("NPCs").get_npc("mother")
	main.get_node("Interaction").begin(mother)
	for i in 12:
		await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://tests/screenshot_10_dialogue.png")
	print("[capture] 10_dialogue -> res://tests/screenshot_10_dialogue.png")

	# Close the conversation so the viewfinder isn't covered.
	var dlg: DialogueRunner = main.get_node("Dialogue")
	if dlg.active:
		dlg.finish_now()
	for i in 6:
		await process_frame

	# Photo mode.
	main.get_node("PhotoMode").toggle()
	for i in 12:
		await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://tests/screenshot_11_photo_mode.png")
	print("[capture] 11_photo_mode -> res://tests/screenshot_11_photo_mode.png")

	quit(0)
