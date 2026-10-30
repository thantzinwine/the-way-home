## Milestone 1 acceptance test.
##
## Loads the real main scene and verifies grid maths, map construction, movement,
## blocking, y-sorting and camera setup. Exits non-zero if anything fails.
##
## Run:  godot --headless --path . --script res://tests/test_milestone1.gd
extends SceneTree

var failures := 0
var checks := 0
var main: Node2D
var map: MapBuilder
var player: PlayerRen
var npcs: NPCManager


func _initialize() -> void:
	_start.call_deferred()


func _start() -> void:
	main = load("res://scenes/main/main.tscn").instantiate()
	root.add_child(main)
	await process_frame
	await physics_frame

	map = main.map
	player = main.player
	npcs = main.get_node("NPCs")
	# Milestone 1 is about movement; give Ren a balance that never runs dry so the
	# economy (Milestone 2) cannot interfere with these checks.
	main.steps.set_steps(9999)

	_test_grid_maths()
	_test_map()
	await _test_movement()
	await _test_blocking()
	_test_scene_graph()
	await _test_input_map()
	await _test_occlusion()
	await _test_walk_stress()
	_test_overlay()

	print("\n--- %d/%d checks passed ---" % [checks - failures, checks])
	if failures > 0:
		print("RESULT: FAIL (%d)" % failures)
		quit(1)
	else:
		print("RESULT: PASS")
		quit(0)


# --- tests ---------------------------------------------------------------------

func _test_grid_maths() -> void:
	_check("origin maps to (0,0)", Isometric.grid_to_world(Vector2i(0, 0)) == Vector2.ZERO)
	_check("grid +x -> down-right", Isometric.grid_to_world(Vector2i(1, 0)) == Vector2(32, 16))
	_check("grid +y -> down-left", Isometric.grid_to_world(Vector2i(0, 1)) == Vector2(-32, 16))
	_check("world->grid roundtrip", Isometric.world_to_grid(Isometric.grid_to_world(Vector2i(7, 3))) == Vector2i(7, 3))
	_check("screen right -> grid (1,-1)", Isometric.input_to_grid(Vector2i(1, 0)) == Vector2i(1, -1))
	_check("screen left -> grid (-1,1)", Isometric.input_to_grid(Vector2i(-1, 0)) == Vector2i(-1, 1))
	_check("screen up -> grid (-1,-1)", Isometric.input_to_grid(Vector2i(0, -1)) == Vector2i(-1, -1))
	_check("screen down -> grid (1,1)", Isometric.input_to_grid(Vector2i(0, 1)) == Vector2i(1, 1))
	_check("screen up-right -> grid (0,-1) one cell", Isometric.input_to_grid(Vector2i(1, -1)) == Vector2i(0, -1))
	_check("screen down-right -> grid (1,0) one cell", Isometric.input_to_grid(Vector2i(1, 1)) == Vector2i(1, 0))
	_check("screen up-left -> grid (-1,0) one cell", Isometric.input_to_grid(Vector2i(-1, -1)) == Vector2i(-1, 0))
	_check("screen down-left -> grid (0,1) one cell", Isometric.input_to_grid(Vector2i(-1, 1)) == Vector2i(0, 1))
	_check("single key costs 2", Isometric.manhattan(Isometric.input_to_grid(Vector2i(1, 0))) == 2)
	_check("key pair costs 1", Isometric.manhattan(Isometric.input_to_grid(Vector2i(1, -1))) == 1)
	_check("facing of grid +x is se", Isometric.facing_name(Vector2i(1, 0)) == "se")
	_check("facing of grid +y is sw", Isometric.facing_name(Vector2i(0, 1)) == "sw")
	_check("facing of grid -x is nw", Isometric.facing_name(Vector2i(-1, 0)) == "nw")
	_check("facing of grid -y is ne", Isometric.facing_name(Vector2i(0, -1)) == "ne")
	_check("cost of diagonal step is 2", Isometric.manhattan(Vector2i(1, -1)) == 2)
	_check("cost of axis step is 1", Isometric.manhattan(Vector2i(0, 1)) == 1)


func _test_map() -> void:
	_check("map parsed 16x14", map.width == 16 and map.height == 14)
	_check("props placed", map.get_prop_count() == 15)
	_check("start cell walkable", map.is_walkable(map.start_cell))
	_check("border wall blocked", not map.is_walkable(Vector2i(0, 0)))
	_check("out of bounds blocked", not map.is_walkable(Vector2i(-1, 5)))
	_check("house footprint blocked", not map.is_walkable(Vector2i(3, 2)))
	_check("house back row blocked", not map.is_walkable(Vector2i(3, 1)))
	_check("road walkable", map.is_walkable(Vector2i(3, 7)))
	_check("pavement walkable", map.is_walkable(Vector2i(3, 5)))
	_check("crossing walkable", map.is_walkable(Vector2i(5, 6)))
	_check("tile custom data readable", map.is_walkable(Vector2i(7, 7)))


func _test_movement() -> void:
	player.input_enabled = false
	var start := player.mover.cell

	var accepted := player.mover.try_step(Vector2i(1, 0))
	_check("single-cell step accepted", accepted)
	_check("mover reports moving", player.mover.is_moving)
	_check("step cost is 1", player.mover.last_cost == 1)
	_check("second step rejected while moving", not player.mover.try_step(Vector2i(1, 0)))

	await _wait_until(func() -> bool: return not player.mover.is_moving)
	var expected := start + Vector2i(1, 0)
	_check("grid cell updated", player.mover.cell == expected)
	_check("body snapped to cell centre",
		player.global_position.is_equal_approx(Isometric.grid_to_world(expected)))

	# screen-right is a two-cell diagonal move on the diamond grid; cost must be 2.
	# Tested from open road so the route is genuinely walkable.
	player.mover.setup(player, Vector2i(3, 7), map.is_walkable)
	var from := player.mover.cell
	var diagonal := player.mover.try_step(Isometric.input_to_grid(Vector2i(1, 0)))
	_check("diagonal step accepted on open road", diagonal)
	if diagonal:
		_check("diagonal step costs 2", player.mover.last_cost == 2)
		await _wait_until(func() -> bool: return not player.mover.is_moving)
		_check("diagonal landing cell",
			player.mover.cell == from + Vector2i(1, -1))
		_check("diagonal landing matches grid space",
			player.global_position.is_equal_approx(Isometric.grid_to_world(from + Vector2i(1, -1))))

	# a diagonal whose route crosses an obstruction must be refused
	player.mover.setup(player, Vector2i(5, 10), map.is_walkable)
	_check("diagonal into house refused",
		not player.mover.try_step(Vector2i(-1, -1)))


func _test_blocking() -> void:
	player.mover.setup(player, Vector2i(1, 1), map.is_walkable)
	var before := player.mover.cell
	var blocked := player.mover.try_step(Vector2i(-1, -1))  # straight into the border wall
	_check("step into wall rejected", not blocked)
	_check("cell unchanged after block", player.mover.cell == before)
	_check("still not moving after block", not player.mover.is_moving)

	var blocked_by_prop := player.mover.try_step(Vector2i(2, 1))  # into the house footprint
	_check("step into house rejected", not blocked_by_prop)


func _test_scene_graph() -> void:
	var world: Node2D = main.get_node("World")
	_check("world y-sort enabled", world.y_sort_enabled)

	var ground := world.get_node("Ground") as TileMapLayer
	_check("ground is a TileMapLayer", ground != null)
	_check("ground draws behind (z_index < 0)", ground.z_index < 0)

	var sortable := 0
	for child in world.get_children():
		if child is PlayerRen:
			sortable += 1
		elif child is Node2D and child.name != "Ground":
			sortable += 1
	_check("player and props share the y-sorted parent",
		sortable == map.get_prop_count() + 1 + npcs.npcs.size())

	var cam := player.get_node_or_null("Camera2D") as Camera2D
	_check("camera present", cam != null)
	_check("camera limits applied", cam.limit_right > cam.limit_left and cam.limit_bottom > cam.limit_top)
	_check("camera is current", cam.is_current())

	_check("sprite has 16 animations", player.sprite.sprite_frames.get_animation_names().size() == 16)
	_check("sprite frame is 48x64", player.sprite.sprite_frames.get_frame_texture("idle_s", 0).get_size() == Vector2(48, 64))


# --- helpers -------------------------------------------------------------------

func _test_input_map() -> void:
	for action in ["move_up", "move_down", "move_left", "move_right",
			"interact", "take_photo", "toggle_debug", "pause"]:
		_check("input action '%s' exists" % action, InputMap.has_action(action))

	var facings := {}
	for dir in [Vector2i(1, 0), Vector2i(1, 1), Vector2i(0, 1), Vector2i(-1, 1),
			Vector2i(-1, 0), Vector2i(-1, -1), Vector2i(0, -1), Vector2i(1, -1)]:
		facings[Isometric.facing_name(Isometric.input_to_grid(dir))] = true
	_check("all 8 facings reachable from input", facings.size() == 8)

	player.mover.setup(player, Vector2i(3, 7), map.is_walkable)
	player.input_enabled = true

	Input.action_press("move_right")
	await _wait_frames(3)
	_check("keyboard input starts a step", player.mover.is_moving)
	_check("facing follows input (east)", player.facing == "e")
	_check("walk animation playing", player.sprite.animation.begins_with("walk_"))
	Input.action_release("move_right")

	await _wait_until(func() -> bool: return not player.mover.is_moving)
	await _wait_frames(2)
	_check("input moved the player east", player.mover.cell == Vector2i(4, 6))
	_check("idle animation restored", player.sprite.animation == "idle_e")

	player.input_enabled = false


func _test_walk_stress() -> void:
	player.input_enabled = false

	# Repositioning mid-step must cancel the step instead of letting the body glide
	# on to the old target (this made the character look stuck / misaligned).
	player.mover.setup(player, Vector2i(3, 7), map.is_walkable)
	player.mover.try_step(Vector2i(1, -1))
	await _wait_frames(2)
	player.mover.setup(player, Vector2i(7, 7), map.is_walkable)
	await _wait_frames(20)
	_check("setup cancels an in-flight step", player.mover.cell == Vector2i(7, 7)
		and not player.mover.is_moving)
	_check("body sits exactly on the repositioned cell",
		player.global_position.is_equal_approx(Isometric.grid_to_world(Vector2i(7, 7))))

	player.mover.setup(player, Vector2i(7, 7), map.is_walkable)
	var directions := [
		Vector2i(1, 0), Vector2i(0, 1), Vector2i(-1, 0), Vector2i(0, -1),
		Vector2i(1, -1), Vector2i(1, 1), Vector2i(-1, 1), Vector2i(-1, -1),
	]
	var accepted := 0
	var off_grid := 0
	for i in 60:
		if player.mover.try_step(directions[i % directions.size()]):
			await _wait_until(func() -> bool: return not player.mover.is_moving)
			accepted += 1
			if not player.global_position.is_equal_approx(
					Isometric.grid_to_world(player.mover.cell)):
				off_grid += 1

	_check("stress walk completed many steps", accepted >= 20)
	_check("body never left the grid while walking", off_grid == 0)


func _test_overlay() -> void:
	var overlay: GridOverlay = main.get_node("GridOverlay")
	_check("grid overlay present", overlay != null)
	# 48 border walls + 4 houses (6 cells each) + stall (6 cells) + 4 trees, 3 poles,
	# 1 crate, 2 signs (1 cell each) + 4 NPCs = 92.
	_check("overlay counts every blocked cell", overlay.blocked_cell_count() == 91)
	_check("overlay hidden by default", not overlay.show_overlay)
	overlay.toggle()
	_check("overlay toggles on", overlay.show_overlay)
	overlay.toggle()
	_check("overlay toggles off", not overlay.show_overlay)

	player.mover.setup(player, Vector2i(1, 1), map.is_walkable)
	player.mover.try_step(Vector2i(-1, -1))  # refused -> signal -> overlay flash
	_check("refused step flashes the cell", overlay.flash_count() > 0)


func _test_occlusion() -> void:
	var house: Node2D = null
	for prop in map.get_props():
		if prop.name.begins_with("House"):
			house = prop
			break
	_check("house prop present", house != null)
	if house == null:
		return

	var sprite := house.get_node("Sprite") as Sprite2D
	player.mover.setup(player, Vector2i(3, 1), map.is_walkable)
	await _wait_frames(30)
	_check("house fades while hiding the player", sprite.modulate.a < 0.9)

	player.mover.setup(player, Vector2i(3, 7), map.is_walkable)
	await _wait_frames(40)
	_check("house opaque again once clear", sprite.modulate.a > 0.95)


func _wait_frames(count: int) -> void:	for i in count:
		await physics_frame


func _wait_until(predicate: Callable, max_frames := 600) -> void:
	var frames := 0
	while not predicate.call() and frames < max_frames:
		await physics_frame
		frames += 1


func _check(label: String, condition: bool) -> void:
	checks += 1
	if condition:
		print("  ok    %s" % label)
	else:
		failures += 1
		print("  FAIL  %s" % label)
