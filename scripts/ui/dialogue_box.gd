## The on-screen presentation of a running conversation.
##
## It listens to DialogueRunner's signals and handles the typewriter, portraits,
## choice highlighting and the "E · Talk to ..." prompt. All input polling happens
## here so the runner stays pure. The box never advances the conversation on its own
## without the runner's permission.
class_name DialogueBox
extends CanvasLayer

const CHARS_PER_SECOND := 52.0
const INPUT_LOCK_MS := 160

@export var runner_path: NodePath
@export var player_path: NodePath

@onready var panel: Control = $Root/Panel
@onready var portrait: TextureRect = $Root/Panel/Margin/VBox/Header/Portrait
@onready var name_label: Label = $Root/Panel/Margin/VBox/Header/NameBox/Name
@onready var text_label: Label = $Root/Panel/Margin/VBox/Text
@onready var choices_box: VBoxContainer = $Root/Panel/Margin/VBox/Choices
@onready var hint_label: Label = $Root/Panel/Margin/VBox/Hint
@onready var prompt: Label = $Root/Prompt

var runner: DialogueRunner
var player: PlayerRen

var _full_text := ""
var _reveal := 0.0
var _typing := false
var _locked_until := 0
var _selected := 0
var _choices: Array = []
var _choice_labels: Array[Label] = []


func _ready() -> void:
	runner = get_node_or_null(runner_path) as DialogueRunner
	player = get_node_or_null(player_path) as PlayerRen

	panel.visible = false
	prompt.visible = false

	if runner != null:
		runner.started.connect(_on_started)
		runner.line_shown.connect(_on_line)
		runner.choices_shown.connect(_on_choices)
		runner.finished.connect(_on_finished)


func show_prompt(text: String) -> void:
	prompt.text = text
	prompt.visible = not text.is_empty()


func _process(delta: float) -> void:
	if runner == null:
		return

	if _typing:
		_reveal += delta * CHARS_PER_SECOND
		text_label.visible_characters = int(_reveal)
		if _reveal >= float(_full_text.length()):
			_finish_typing()

	if not runner.active:
		return

	if Time.get_ticks_msec() < _locked_until:
		return

	if Input.is_action_just_pressed("interact"):
		_on_confirm()

	if not _choices.is_empty():
		if Input.is_action_just_pressed("ui_up"):
			_move_selection(-1)
		elif Input.is_action_just_pressed("ui_down"):
			_move_selection(1)


func _on_started(_npc: NPC) -> void:
	_locked_until = Time.get_ticks_msec() + INPUT_LOCK_MS
	panel.visible = true


func _on_line(_who: String, display_name: String, text: String) -> void:
	name_label.text = display_name
	name_label.visible = not display_name.is_empty()

	if display_name.is_empty():
		portrait.visible = false
	else:
		portrait.visible = true
		var path := portrait_path_for(_who)
		if ResourceLoader.exists(path):
			portrait.texture = load(path)
		else:
			portrait.texture = null

	text_label.text = text
	_full_text = text
	_reveal = 0.0
	_typing = true
	text_label.visible_characters = 0

	_clear_choices()
	hint_label.text = "E  continue"


func portrait_path_for(who: String) -> String:
	return "res://assets/characters/%s/%s_portrait.png" % [who, who]


func _on_choices(choices: Array) -> void:
	_clear_choices()
	_choices = choices
	_selected = 0

	for i in choices.size():
		var choice: Dictionary = choices[i]
		var label := Label.new()
		label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		label.add_theme_font_size_override("font_size", 15)
		label.add_theme_color_override("font_color", Color(0.9, 0.86, 0.74, 0.95))
		label.text = "  " + str(choice.get("text", ""))
		choices_box.add_child(label)
		_choice_labels.append(label)

	_refresh_selection()
	hint_label.text = "↑↓  choose      E  confirm"


func _clear_choices() -> void:
	for child in choices_box.get_children():
		child.queue_free()
	_choices = []
	_choice_labels = []
	_selected = 0


func _refresh_selection() -> void:
	for i in _choice_labels.size():
		var label: Label = _choice_labels[i]
		if i == _selected:
			label.text = "▸ " + str(_choices[i].get("text", "")).substr(2)
			label.add_theme_color_override("font_color", Color(0.98, 0.8, 0.46))
		else:
			label.text = "  " + str(_choices[i].get("text", ""))
			label.add_theme_color_override("font_color", Color(0.9, 0.86, 0.74, 0.95))


func _move_selection(delta: int) -> void:
	if _choices.is_empty():
		return
	_selected = wrapi(_selected + delta, 0, _choices.size())
	_refresh_selection()


func _on_confirm() -> void:
	if _typing:
		_finish_typing()
		return
	if not _choices.is_empty():
		runner.choose(_selected)
		return
	runner.advance()


func _finish_typing() -> void:
	_typing = false
	_reveal = float(_full_text.length())
	text_label.visible_characters = -1


func _on_finished() -> void:
	panel.visible = false
	prompt.visible = false
	_clear_choices()
	_typing = false
