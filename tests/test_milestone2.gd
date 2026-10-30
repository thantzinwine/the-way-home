## Milestone 2 acceptance test: Steps economy, costs, HUD and the frozen state.
##
## Loads the real main scene so the checks run against the same wiring the player
## gets. Exits non-zero on failure.
##
## Run:  godot --headless --path . --script res://tests/test_milestone2.gd
extends SceneTree

var failures := 0
var checks := 0

var main: Node2D
var map: MapBuilder
var player: PlayerRen
var wallet: StepsWallet
var hud: HUD

var spent_events: Array[int] = []
var refused_events: Array = []
var frozen_events: Array[bool] = []
var move_refusals: Array = []


func _initialize() -> void:
	_start.call_deferred()


func _start() -> void:
	main = load("res://scenes/main/main.tscn").instantiate()
	root.add_child(main)
	await process_frame
	await physics_frame

	map = main.map
	player = main.player
	wallet = main.get_node("Steps")
	hud = main.get_node("HUD")

	wallet.spent.connect(func(amount: int, _reason: String) -> void: spent_events.append(amount))
	wallet.refused.connect(func(required: int, available: int) -> void:
		refused_events.append([required, available]))
	wallet.frozen_changed.connect(func(is_frozen: bool) -> void: frozen_events.append(is_frozen))
	player.move_refused.connect(func(reason: String, cost: int) -> void:
		move_refusals.append([reason, cost]))

	_test_config()
	_test_balance_and_spending()
	await _test_movement_costs()
	await _test_zero_steps()
	await _test_recovery()
	_test_persistence()
	await _test_departure_clock()
	await _test_hud()

	print("\n--- %d/%d checks passed ---" % [checks - failures, checks])
	if failures > 0:
		print("RESULT: FAIL (%d)" % failures)
		quit(1)
	else:
		print("RESULT: PASS")
		quit(0)


# --- tests ---------------------------------------------------------------------

func _test_config() -> void:
	_check("wallet has a config resource", wallet.config != null)
	_check("config is the tunable resource", wallet.config is StepsConfig)
	_check("starting balance comes from config",
		wallet.config.starting_steps == 150)
	_check("cost is 1 Step per cell", wallet.config.cost_per_cell == 1)
	_check("fresh wallet starts at the configured balance", wallet.steps == 150)
	_check("fresh wallet is not frozen", not wallet.frozen)


func _test_balance_and_spending() -> void:
	wallet.set_steps(100)
	spent_events.clear()
	refused_events.clear()

	_check("spend returns true when affordable", wallet.spend(12, "test"))
	_check("balance is reduced", wallet.steps == 88)
	_check("spend emits amount", spent_events.size() == 1 and spent_events[0] == 12)
	_check("can_afford reports true", wallet.can_afford(88))
	_check("can_afford reports false above balance", not wallet.can_afford(89))

	_check("cost of a 1 cell move", wallet.cost_for_cells(1) == 1)
	_check("cost of a 2 cell move", wallet.cost_for_cells(2) == 2)
	_check("cost of a 0 cell move", wallet.cost_for_cells(0) == 0)

	wallet.set_steps(5)
	_check("overspending is refused", not wallet.spend(6, "test"))
	_check("refused reports the shortfall", refused_events.size() == 1
		and refused_events[0] == [6, 5])
	_check("balance untouched after refusal", wallet.steps == 5)

	wallet.grant(20, "test")
	_check("grant adds Steps", wallet.steps == 25)


func _test_movement_costs() -> void:
	wallet.set_steps(50)
	player.input_enabled = true
	player.mover.setup(player, Vector2i(3, 7), map.is_walkable)

	# move_right is a two-cell step on the diamond grid, but every move now costs
	# one Step regardless of how many cells it crosses.
	Input.action_press("move_right")
	await _wait_frames(3)
	Input.action_release("move_right")
	await _wait_until(func() -> bool: return not player.mover.is_moving)
	await _wait_frames(2)

	_check("a move costs one Step", wallet.steps == 49)
	_check("two-cell move landed east", player.mover.cell == Vector2i(4, 6))


func _test_zero_steps() -> void:
	frozen_events.clear()
	wallet.set_steps(0)
	_check("balance of zero freezes Ren", wallet.frozen)
	_check("freeze emits a change", frozen_events.has(true))
	await _wait_frames(2)
	_check("HUD shows the frozen banner", hud.frozen_panel.visible)
	_check("Departure clock starts at 24 hours",
		wallet.departure_time_left() > 23.0 * 3600.0
		and wallet.departure_time_left() <= 24.0 * 3600.0)

	# Frozen: pressing a direction must not move Ren.
	var before := player.mover.cell
	move_refusals.clear()
	Input.action_press("move_right")
	await _wait_frames(8)
	Input.action_release("move_right")
	await _wait_frames(2)

	_check("frozen Ren cannot move", player.mover.cell == before)
	_check("refusal is reported as 'frozen'",
		move_refusals.size() > 0 and move_refusals[0][0] == "frozen")
	_check("balance stays at zero", wallet.steps == 0)


func _test_recovery() -> void:
	wallet.grant(10, "family")
	_check("receiving Steps unfreezes Ren", not wallet.frozen)
	await _wait_frames(2)
	_check("HUD hides the frozen banner", not hud.frozen_panel.visible)
	_check("Departure clock is cleared", wallet.departure_time_left() == 0.0)

	# An unaffordable move is refused while still positive. With a flat cost of 1
	# Step per move, any positive balance can afford any move, so the refusal now
	# happens only in the frozen state (tested in _test_zero_steps). Here we check
	# that a move drains the last Step and freezes Ren.
	wallet.set_steps(1)
	player.mover.setup(player, Vector2i(3, 7), map.is_walkable)
	var before := player.mover.cell
	move_refusals.clear()
	Input.action_press("move_right")
	await _wait_frames(8)
	Input.action_release("move_right")
	await _wait_until(func() -> bool: return not player.mover.is_moving)
	await _wait_frames(2)

	_check("the last affordable move is accepted", player.mover.cell != before)
	_check("the last Step is spent", wallet.steps == 0)
	_check("Ren freezes when the balance hits zero", wallet.frozen)

	# A further move is refused as 'frozen'.
	before = player.mover.cell
	move_refusals.clear()
	Input.action_press("move_right")
	await _wait_frames(8)
	Input.action_release("move_right")
	await _wait_frames(2)

	_check("a move is refused once frozen", player.mover.cell == before)
	_check("the refusal is reported as 'frozen'",
		move_refusals.size() > 0 and move_refusals[0][0] == "frozen")


func _test_persistence() -> void:
	var path := "user://test_steps_balance.cfg"
	wallet.set_steps(77)
	_check("balance saves", wallet.save_to_file(path) == OK)

	wallet.set_steps(5)
	_check("balance loads", wallet.load_from_file(path) == OK)
	_check("loaded balance matches", wallet.steps == 77)

	DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
	_check("loading a missing save is reported", wallet.load_from_file(path) != OK)


func _test_departure_clock() -> void:
	wallet.set_steps(0)
	var first := wallet.departure_time_left()
	await _wait_frames(20)
	var second := wallet.departure_time_left()
	_check("Departure clock counts down", second < first)
	_check("clock stays within 24 hours", second <= 24.0 * 3600.0 and second > 0.0)
	_check("clock formats as hh:mm:ss", hud.format_clock(86399.0) == "23:59:59")
	_check("clock clamps at zero", hud.format_clock(-5.0) == "00:00:00")


func _test_hud() -> void:
	wallet.set_steps(0)
	await _wait_frames(2)
	_check("HUD shows the balance", hud.steps_value.text == "0")
	_check("HUD warns on an empty balance",
		hud.steps_value.get_theme_color("font_color").r > 0.9
		and hud.steps_value.get_theme_color("font_color").g < 0.5)

	wallet.set_steps(7)
	await _wait_frames(2)
	_check("HUD shows a low balance", hud.steps_value.text == "7")
	_check("HUD uses the warning colour",
		hud.steps_value.get_theme_color("font_color").g > 0.6)

	wallet.set_steps(120)
	await _wait_frames(2)
	_check("HUD shows a healthy balance", hud.steps_value.text == "120")
	_check("HUD cost hint mentions the per-cell price",
		hud.cost_hint.text.contains("1 Step"))


# --- helpers -------------------------------------------------------------------

func _wait_frames(count: int) -> void:
	for i in count:
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
