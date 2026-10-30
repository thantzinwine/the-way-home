## The photo album. Toggled with Tab.
##
## Shows a grid of thumbnails; the selected photo is previewed large with its
## subject and capture time. Arrow keys move the selection, Tab/Esc closes.
class_name PhotoLog
extends CanvasLayer

@export var photo_manager_path: NodePath

@onready var panel: Control = $Root/Panel
@onready var grid: GridContainer = $Root/Panel/Margin/VBox/Grid
@onready var preview: TextureRect = $Root/Panel/Margin/VBox/PreviewRow/Preview
@onready var caption_label: Label = $Root/Panel/Margin/VBox/PreviewRow/Caption
@onready var count_label: Label = $Root/Panel/Margin/VBox/Header/Count

var photos: PhotoManager
var _selected := 0
var active := false


func _ready() -> void:
	photos = get_node_or_null(photo_manager_path) as PhotoManager
	visible = false
	panel.visible = false
	if photos != null:
		photos.captured.connect(func(_p: Photo) -> void: _refresh())
		photos.cleared.connect(func() -> void: _refresh())


func toggle() -> void:
	active = not active
	visible = active
	panel.visible = active
	if active:
		_selected = maxi(photos.count() - 1, 0)
		_refresh()


func is_open() -> bool:
	return active


func flash_latest() -> void:
	# Briefly highlight that a photo was added (no-op beyond refresh).
	_refresh()


func _process(_delta: float) -> void:
	if not active:
		return
	if Input.is_action_just_pressed("ui_left"):
		_move(-1)
	elif Input.is_action_just_pressed("ui_right"):
		_move(1)
	elif Input.is_action_just_pressed("ui_up"):
		_move(-4)
	elif Input.is_action_just_pressed("ui_down"):
		_move(4)
	elif Input.is_action_just_pressed("toggle_photo_log") or Input.is_action_just_pressed("pause"):
		toggle()


func _move(delta: int) -> void:
	if photos == null or photos.count() == 0:
		return
	_selected = clampi(_selected + delta, 0, photos.count() - 1)
	_refresh()


func _refresh() -> void:
	for child in grid.get_children():
		child.queue_free()

	if photos == null:
		return

	count_label.text = "%d photo%s" % [photos.count(), "" if photos.count() == 1 else "s"]

	for i in photos.count():
		var btn := TextureRect.new()
		btn.custom_minimum_size = Vector2(96, 72)
		btn.expand_mode = 1
		btn.stretch_mode = 5
		var p := photos.get_photo(i)
		if p != null:
			btn.texture = p.texture
		if i == _selected:
			btn.modulate = Color(1, 1, 1, 1)
		else:
			btn.modulate = Color(0.7, 0.7, 0.7, 1)
		grid.add_child(btn)

	if photos.count() == 0:
		preview.texture = null
		caption_label.text = "No photos yet. Press F, then Space to capture."
		return

	var p := photos.get_photo(_selected)
	if p == null:
		return
	preview.texture = p.texture
	var when := ""
	caption_label.text = "%s" % (p.subject if not p.subject.is_empty() else "untitled")
	if not p.caption.is_empty() and p.caption != p.subject:
		caption_label.text += "  -  " + p.caption
