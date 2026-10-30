## Milestone 5 acceptance test: save / load.
##
## Loads the real main scene. Exits non-zero on failure.
##
## Run:  godot --headless --path . --script res://tests/test_milestone5.gd
extends SceneTree

var failures := 0
var checks := 0

var main: Node2D
var player: PlayerRen
var map: MapBuilder
var wallet: StepsWallet
var dialogue: DialogueRunner
var photos: PhotoManager
var save_mgr: SaveManager


func _initialize() -> void:
	_start.call_deferred()


func _start() -> void:
	main = load("res://scenes/main/main.tscn").instantiate()
	root.add_child(main)
	await process_frame
	await physics_frame

	player = main.player
	map = main.map
	wallet = main.steps
	dialogue = main.get_node("Dialogue")
	photos = main.get_node("Photos")
	save_mgr = main.get_node("Save")

	main.steps.set_steps(9999)

	# Start from a clean slot.
	save_mgr.delete_save()

	_test_has_save()
	_test_save_round_trip()
	_test_load_missing()
	_test_frozen_round_trip()
	_test_photo_round_trip()
	_test_delete_save()

	# Clean up.
	save_mgr.delete_save()

	print("\n--- %d/%d checks passed ---" % [checks - failures, checks])
	if failures > 0:
		print("RESULT: FAIL (%d)" % failures)
		quit(1)
	else:
		print("RESULT: PASS")
		quit(0)


# --- tests ---------------------------------------------------------------------

func _test_has_save() -> void:
	_check("no save on a fresh slot", not save_mgr.has_save())


func _test_save_round_trip() -> void:
	# Set up a known state.
	wallet.set_steps(42)
	dialogue.flags["mother_gift"] = true
	dialogue.flags["father_work"] = true
	player.mover.setup(player, Vector2i(5, 6), map.is_walkable)
	player.facing = "ne"
	photos.clear()
	photos.capture(Rect2(0, 0, 32, 24), "a subject", "a caption")
	wallet.set_steps(42)

	var saved := save_mgr.save_game()
	_check("save_game() succeeds", saved)
	_check("has_save() is true after saving", save_mgr.has_save())

	# Mutate everything.
	wallet.set_steps(7)
	dialogue.flags.clear()
	player.mover.setup(player, Vector2i(2, 2), map.is_walkable)
	player.facing = "s"
	photos.clear()

	var loaded := save_mgr.load_game()
	_check("load_game() succeeds", loaded)

	_check("Steps restored", wallet.steps == 42)
	_check("mother_gift flag restored", dialogue.has_flag("mother_gift"))
	_check("father_work flag restored", dialogue.has_flag("father_work"))
	_check("player cell restored", player.mover.cell == Vector2i(5, 6))
	_check("player facing restored", player.facing == "ne")
	_check("photo count restored", photos.count() == 1)
	var p := photos.get_photo(0)
	_check("photo subject restored", p != null and p.subject == "a subject")
	_check("photo caption restored", p != null and p.caption == "a caption")
	_check("photo texture restored", p != null and p.is_valid())


func _test_load_missing() -> void:
	save_mgr.delete_save()
	_check("load_game() fails with no save", not save_mgr.load_game())
	_check("has_save() false after delete", not save_mgr.has_save())


func _test_frozen_round_trip() -> void:
	wallet.set_steps(0)
	# Force some departure progress by ticking.
	for i in 5:
		wallet._process(0.1)
	var progress_before := wallet.departure_progress
	_check("wallet is frozen", wallet.frozen)
	_check("progress is positive", progress_before > 0.0)

	save_mgr.save_game()

	# Unfreeze and clear.
	wallet.grant(10, "test")
	_check("unfrozen after grant", not wallet.frozen)

	save_mgr.load_game()
	_check("frozen state restored", wallet.frozen)
	_check("balance restored to zero", wallet.steps == 0)
	_check("departure progress restored",
		absf(wallet.departure_progress - progress_before) < 0.001)


func _test_photo_round_trip() -> void:
	photos.clear()
	var photo := photos.capture(Rect2(0, 0, 16, 12), "roundtrip", "cap")
	_check("capture works", photo != null)
	save_mgr.save_game()

	photos.clear()
	_check("cleared before load", photos.count() == 0)
	save_mgr.load_game()
	_check("photo count restored", photos.count() == 1)
	var p := photos.get_photo(0)
	_check("restored photo is valid", p != null and p.is_valid())
	_check("restored photo size", p != null and p.size() == Vector2i(16, 12))


func _test_delete_save() -> void:
	save_mgr.save_game()
	_check("save exists before delete", save_mgr.has_save())
	save_mgr.delete_save()
	_check("save gone after delete", not save_mgr.has_save())


func _check(label: String, condition: bool) -> void:
	checks += 1
	if condition:
		print("  ok    %s" % label)
	else:
		failures += 1
		print("  FAIL  %s" % label)
