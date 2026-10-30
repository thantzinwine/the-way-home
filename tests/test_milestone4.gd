## Milestone 4 acceptance test: photography (capture, log, rewards).
##
## Loads the real main scene. Exits non-zero on failure.
##
## Run:  godot --headless --path . --script res://tests/test_milestone4.gd
extends SceneTree

var failures := 0
var checks := 0

var main: Node2D
var player: PlayerRen
var photos: PhotoManager
var photo_mode: PhotoMode
var photo_log: PhotoLog
var wallet: StepsWallet
var npcs: NPCManager


func _initialize() -> void:
	_start.call_deferred()


func _start() -> void:
	main = load("res://scenes/main/main.tscn").instantiate()
	root.add_child(main)
	await process_frame
	await physics_frame

	player = main.player
	photos = main.get_node("Photos")
	photo_mode = main.get_node("PhotoMode")
	photo_log = main.get_node("PhotoLog")
	wallet = main.steps
	npcs = main.get_node("NPCs")

	main.steps.set_steps(9999)

	_test_photo_manager()
	_test_capture_reward()
	_test_photo_log()
	_test_photo_mode()
	_test_subject_detection()

	print("\n--- %d/%d checks passed ---" % [checks - failures, checks])
	if failures > 0:
		print("RESULT: FAIL (%d)" % failures)
		quit(1)
	else:
		print("RESULT: PASS")
		quit(0)


# --- tests ---------------------------------------------------------------------

func _test_photo_manager() -> void:
	_check("photo manager starts empty", photos.count() == 0)

	var rect := Rect2(100, 100, 200, 150)
	var photo := photos.capture(rect, "test subject", "a caption")
	_check("capture returns a photo", photo != null)
	_check("photo is valid", photo != null and photo.is_valid())
	_check("photo texture is set", photo != null and photo.texture != null)
	_check("photo size matches the crop", photo != null and photo.size() == Vector2i(200, 150))
	_check("subject is recorded", photo != null and photo.subject == "test subject")
	_check("caption is recorded", photo != null and photo.caption == "a caption")
	_check("count is 1", photos.count() == 1)
	_check("get_photo(0) returns it", photos.get_photo(0) == photo)
	_check("get_photo(-1) is null", photos.get_photo(-1) == null)
	_check("get_photo(99) is null", photos.get_photo(99) == null)

	# A second capture appends.
	var photo2 := photos.capture(Rect2(0, 0, 64, 64))
	_check("second capture succeeds", photo2 != null)
	_check("count is 2", photos.count() == 2)
	_check("subjects() lists both", photos.subjects().size() == 2)

	# clear() empties the collection.
	photos.clear()
	_check("clear() empties the log", photos.count() == 0)


func _test_capture_reward() -> void:
	photos.clear()
	var before := wallet.steps
	photos.capture(Rect2(0, 0, 32, 32), "reward test")
	_check("capture grants a Step reward", wallet.steps == before + photos.reward_per_photo)


func _test_photo_log() -> void:
	photos.clear()
	_check("log starts closed", not photo_log.is_open())
	_check("panel hidden when closed", not photo_log.panel.visible)

	photo_log.toggle()
	_check("toggle opens the log", photo_log.is_open())
	_check("panel visible when open", photo_log.panel.visible)

	# Add a photo and refresh.
	photos.capture(Rect2(0, 0, 48, 36), "a subject")
	photo_log._refresh()
	_check("log shows the count", photo_log.count_label.text.contains("1"))

	photo_log.toggle()
	_check("toggle closes the log", not photo_log.is_open())


func _test_photo_mode() -> void:
	_check("photo mode starts inactive", not photo_mode.active)
	_check("photo mode node is hidden", not photo_mode.visible)

	photo_mode.toggle()
	_check("toggle activates photo mode", photo_mode.active)
	_check("viewfinder becomes visible", photo_mode.visible)
	_check("frame has the right size",
		photo_mode.frame.custom_minimum_size == Vector2(PhotoMode.VIEWFINDER))

	# Movement stays enabled in photo mode.
	_check("Ren can still move in photo mode", player.input_enabled)

	photo_mode.toggle()
	_check("toggle deactivates photo mode", not photo_mode.active)


func _test_subject_detection() -> void:
	# Standing next to the mother, the subject should be her name.
	player.mover.setup(player, Vector2i(3, 11), main.map.is_walkable)
	player.facing = "e"
	photo_mode.active = true
	photo_mode._update_subject()
	var subject := photo_mode._subject_name()
	_check("subject detection returns a non-empty string next to an NPC",
		not subject.is_empty())
	_check("the mother is detected", subject == "Daw Mya")

	# Far from everyone, subject is empty.
	player.mover.setup(player, Vector2i(1, 1), main.map.is_walkable)
	photo_mode._update_subject()
	_check("no subject in an empty area",
		photo_mode._subject_name().is_empty())

	photo_mode.active = false


func _check(label: String, condition: bool) -> void:
	checks += 1
	if condition:
		print("  ok    %s" % label)
	else:
		failures += 1
		print("  FAIL  %s" % label)
