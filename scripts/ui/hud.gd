## Minimal, atmospheric HUD for Milestone 2.
##
## Shows the Steps balance, the cost of travel, floating + / - feedback, a refusal
## toast and the frozen/Departure banner. It only reads the wallet, so the economy
## stays testable without any UI attached.
class_name HUD
extends CanvasLayer

const TOAST_COOLDOWN := 0.9

@export var wallet_path: NodePath
@export var player_path: NodePath

@onready var steps_value: Label = $Root/StepsPanel/VBox/ValueRow/Value
@onready var cost_hint: Label = $Root/StepsPanel/VBox/CostHint
@onready var steps_panel: PanelContainer = $Root/StepsPanel
@onready var frozen_panel: PanelContainer = $Root/FrozenPanel
@onready var frozen_clock: Label = $Root/FrozenPanel/VBox/Clock
@onready var toast: Label = $Root/Toast
@onready var root: Control = $Root

var wallet: StepsWallet
var player: PlayerRen

var _last_toast_time := -100.0


func _ready() -> void:
	wallet = get_node_or_null(wallet_path) as StepsWallet
	player = get_node_or_null(player_path) as PlayerRen
	toast.modulate.a = 0.0
	frozen_panel.visible = false

	if wallet != null:
		wallet.changed.connect(_on_changed)
		wallet.frozen_changed.connect(_on_frozen_changed)
		cost_hint.text = "%d Step per cell" % wallet.config.cost_per_cell
		_on_changed(wallet.steps, 0)
		_on_frozen_changed(wallet.frozen)
	if player != null:
		player.move_refused.connect(_on_move_refused)


func _process(_delta: float) -> void:
	if wallet == null or not frozen_panel.visible:
		return
	if wallet.departure_progress >= 1.0:
		frozen_clock.text = "Departure"
		return
	frozen_clock.text = "Departure in %s" % format_clock(wallet.departure_time_left())


## 24 in-game hours -> "23:58:41".
static func format_clock(seconds: float) -> String:
	var total := int(maxf(seconds, 0.0))
	return "%02d:%02d:%02d" % [total / 3600, (total % 3600) / 60, total % 60]


func _on_changed(current: int, delta: int) -> void:
	steps_value.text = str(current)

	var colour := Color(0.96, 0.94, 0.85, 1.0)
	if current <= 0:
		colour = Color(0.95, 0.42, 0.34, 1.0)
	elif wallet != null and current <= wallet.config.low_steps_threshold:
		colour = Color(0.96, 0.76, 0.38, 1.0)
	steps_value.add_theme_color_override("font_color", colour)

	if delta > 0:
		_popup("+%d" % delta, Color(0.55, 0.88, 0.55))
	elif delta < 0:
		var warn := current <= 0
		_popup("%d" % delta, Color(0.96, 0.5, 0.38) if warn else Color(0.94, 0.86, 0.62))


func _on_frozen_changed(is_frozen: bool) -> void:
	frozen_panel.visible = is_frozen
	if is_frozen:
		_toast("Your body has frozen. 24 hours until Departure.", true)
	else:
		_toast("Your Steps returned. You can move again.", false)


func _on_move_refused(reason: String, cost: int) -> void:
	match reason:
		"frozen":
			_toast("You cannot move. Your body is frozen.", true)
		"steps":
			_toast("Not enough Steps - that move costs %d." % cost, true)


func _popup(text: String, colour: Color) -> void:
	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", 18)
	label.add_theme_color_override("font_color", colour)
	label.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.7))
	label.add_theme_constant_override("shadow_offset_x", 1)
	label.add_theme_constant_override("shadow_offset_y", 1)
	label.position = steps_panel.position + Vector2(steps_panel.size.x + 14.0, 10.0)
	root.add_child(label)

	var tween := create_tween()
	tween.set_parallel(true)
	tween.tween_property(label, "position:y", label.position.y - 24.0, 0.9) \
		.set_ease(Tween.EASE_OUT)
	tween.tween_property(label, "modulate:a", 0.0, 0.45).set_delay(0.45)
	tween.chain().tween_callback(label.queue_free)


func show_toast(text: String, urgent := false) -> void:
	_toast(text, urgent)


func _toast(text: String, urgent: bool) -> void:
	var now := Time.get_ticks_msec() / 1000.0
	if now - _last_toast_time < TOAST_COOLDOWN:
		return
	_last_toast_time = now

	toast.text = text
	toast.add_theme_color_override(
		"font_color",
		Color(0.98, 0.55, 0.46) if urgent else Color(0.88, 0.93, 0.82)
	)
	toast.modulate.a = 0.0

	var tween := create_tween()
	tween.tween_property(toast, "modulate:a", 1.0, 0.15)
	tween.tween_interval(1.4)
	tween.tween_property(toast, "modulate:a", 0.0, 0.5)
