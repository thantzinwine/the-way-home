## The Steps economy.
##
## Owns Ren's balance, charges for movement, and runs the frozen state that begins
## when the balance reaches zero: the body stops working and a 24 hour Departure
## clock starts. Chapter 1 never kills Ren for this - the countdown is pressure, not
## a game over. (Later chapters decide what Departure actually means.)
##
## All numbers come from StepsConfig so balancing stays out of the code.
class_name StepsWallet
extends Node

signal changed(current: int, delta: int)
signal spent(amount: int, reason: String)
signal granted(amount: int, reason: String)
signal refused(required: int, available: int)
signal frozen_changed(is_frozen: bool)
signal departed

@export var config: StepsConfig

var steps := 0
var frozen := false

## 0.0 at freeze, 1.0 when the Departure window has elapsed.
var departure_progress := 0.0

var _initialised := false
var _departed_emitted := false


func _ready() -> void:
	if config == null:
		config = StepsConfig.new()
	if not _initialised:
		reset(config.starting_steps)


func _process(delta: float) -> void:
	if not frozen or _departed_emitted:
		return
	if config.departure_real_seconds <= 0.0:
		return
	departure_progress = minf(departure_progress + delta / config.departure_real_seconds, 1.0)
	if departure_progress >= 1.0:
		_departed_emitted = true
		departed.emit()


## Start over with a given balance (used on new game, and by the tests).
func reset(amount: int) -> void:
	_initialised = true
	steps = maxi(amount, 0)
	departure_progress = 0.0
	_departed_emitted = false
	var was_frozen := frozen
	frozen = steps <= 0
	changed.emit(steps, 0)
	if frozen != was_frozen:
		frozen_changed.emit(frozen)


func set_steps(amount: int) -> void:
	reset(amount)


func can_afford(amount: int) -> bool:
	return steps >= amount


## Steps a move of `cells` grid cells costs.
func cost_for_cells(cells: int) -> int:
	return maxi(cells, 0) * config.cost_per_cell


## Charges `amount`. Returns false and emits `refused` if the balance is too low.
func spend(amount: int, reason := "") -> bool:
	if amount <= 0:
		return true
	if not can_afford(amount):
		refused.emit(amount, steps)
		return false

	steps -= amount
	spent.emit(amount, reason)
	changed.emit(steps, -amount)

	if steps <= 0 and not frozen:
		frozen = true
		departure_progress = 0.0
		_departed_emitted = false
		frozen_changed.emit(frozen)
	return true


## Adds Steps (family support, earnings, rewards).
func grant(amount: int, reason := "") -> void:
	if amount <= 0:
		return
	steps += amount
	granted.emit(amount, reason)
	changed.emit(steps, amount)

	if steps > 0 and frozen:
		frozen = false
		departure_progress = 0.0
		_departed_emitted = false
		frozen_changed.emit(frozen)


## Restores a saved state (used by the save system). Emits the usual signals.
func restore(balance: int, was_frozen: bool, progress: float) -> void:
	steps = maxi(balance, 0)
	frozen = was_frozen and steps <= 0
	departure_progress = progress if frozen else 0.0
	_departed_emitted = false
	_initialised = true
	changed.emit(steps, 0)
	frozen_changed.emit(frozen)


## Seconds left before Departure, expressed in the story's time (24 hours), not real
## time. Returns 0 when not frozen.
func departure_time_left() -> float:
	if not frozen or _departed_emitted:
		return 0.0
	return float(config.departure_hours) * 3600.0 * (1.0 - departure_progress)


# --- persistence (wired into the full save system in Milestone 5) ---------------

func save_to_file(path: String) -> Error:
	var file := ConfigFile.new()
	file.set_value("steps", "balance", steps)
	return file.save(path)


func load_from_file(path: String) -> Error:
	var file := ConfigFile.new()
	var err := file.load(path)
	if err != OK:
		return err
	var balance: int = int(file.get_value("steps", "balance", config.starting_steps))
	reset(balance)
	return OK
