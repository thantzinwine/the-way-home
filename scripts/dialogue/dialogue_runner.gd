## Runs a branching conversation from a JSON file.
##
## The runner owns conversation *state* only - which node, which line, which choices
## are allowed and what they do. It never touches the screen, so conversations can be
## tested headlessly and the box can be restyled without risk.
##
## File shape (see data/dialogue/*.json):
##   { "start": "node_id",
##     "nodes": { "node_id": {
##         "lines":   [ {"who": "mother", "text": "..."} ],
##         "choices": [ {"text", "goto", "once", "if"} ],
##         "effects": [ {"type": "grant_steps", "amount": 25} ],
##         "goto": "next_node_id",
##         "once": "flag_name"
##     } } }
##
## A node with no choices and no goto ends the conversation. `once` flags live for the
## session (the save system picks them up in Milestone 5).
class_name DialogueRunner
extends Node

signal started(npc: NPC)
signal line_shown(who: String, display_name: String, text: String)
signal choices_shown(choices: Array)
signal finished

## Protects against a data file that loops nodes without ever showing a line.
const MAX_HOPS := 64

@export var wallet_path: NodePath
@export var npc_manager_path: NodePath

var active := false
var current_npc: NPC
var flags := {}

var wallet: StepsWallet
var npcs: NPCManager

var _data := {}
var _nodes := {}
var _node_id := ""
var _lines: Array = []
var _index := 0
var _choices: Array = []
var _cache := {}


func _ready() -> void:
	wallet = get_node_or_null(wallet_path) as StepsWallet
	npcs = get_node_or_null(npc_manager_path) as NPCManager


## Begins a conversation. Returns false if the NPC's file is missing or broken.
func start(npc: NPC) -> bool:
	var data := _load_dialogue(npc.dialogue_path)
	if data.is_empty():
		push_error("DialogueRunner: no dialogue for '%s' (%s)" % [npc.id, npc.dialogue_path])
		return false

	_data = data
	_nodes = data.get("nodes", {})
	current_npc = npc
	active = true
	_choices = []
	started.emit(npc)
	_enter(str(data.get("start", "")))
	return true


## Moves to the next line, then to the choices / next node.
func advance() -> void:
	if not active:
		return
	if _index + 1 < _lines.size():
		_index += 1
		_emit_line()
		return
	_after_lines()


## Picks one of the currently offered choices.
func choose(index: int) -> bool:
	if not active or _choices.is_empty():
		return false
	if index < 0 or index >= _choices.size():
		return false

	var choice: Dictionary = _choices[index]
	_choices = []
	var once := str(choice.get("once", ""))
	if not once.is_empty():
		flags[once] = true
	_apply_effects(choice.get("effects", []))
	_enter(str(choice.get("goto", "")))
	return true


func current_line() -> Dictionary:
	if _index < 0 or _index >= _lines.size():
		return {}
	return _lines[_index]


func finish_now() -> void:
	_finish()


func line_index() -> int:
	return _index


func line_count() -> int:
	return _lines.size()


func has_flag(flag: String) -> bool:
	return flags.has(flag)


## Speaker name for a "who" id in a dialogue file.
func display_name_for(who: String) -> String:
	match who:
		"narrator":
			return ""
		"ren":
			return "Ren"
	if npcs != null:
		var found := npcs.display_name_for(who)
		if not found.is_empty():
			return found
	return who.capitalize()


# --- internals -----------------------------------------------------------------

func _enter(node_id: String, hops := 0) -> void:
	if node_id.is_empty() or not _nodes.has(node_id) or hops > MAX_HOPS:
		_finish()
		return

	var node: Dictionary = _nodes[node_id]
	_node_id = node_id

	var once := str(node.get("once", ""))
	if not once.is_empty():
		flags[once] = true
	_apply_effects(node.get("effects", []))

	_lines = node.get("lines", [])
	_index = 0
	_choices = []

	if _lines.is_empty():
		_after_lines(hops)
		return
	_emit_line()


func _after_lines(hops := 0) -> void:
	var node: Dictionary = _nodes.get(_node_id, {})
	_choices = _visible_choices(node.get("choices", []))
	if not _choices.is_empty():
		choices_shown.emit(_choices)
		return
	_enter(str(node.get("goto", "")), hops + 1)


func _emit_line() -> void:
	var line: Dictionary = _lines[_index]
	var who := str(line.get("who", "narrator"))
	line_shown.emit(who, display_name_for(who), str(line.get("text", "")))


func _visible_choices(list: Array) -> Array:
	var out: Array = []
	for choice in list:
		var once := str(choice.get("once", ""))
		if not once.is_empty() and flags.has(once):
			continue
		if not _condition_met(str(choice.get("if", ""))):
			continue
		out.append(choice)
	return out


## Tiny condition language for dialogue data: frozen / not_frozen / low_steps.
func _condition_met(condition: String) -> bool:
	match condition:
		"", "always":
			return true
		"frozen":
			return wallet != null and wallet.frozen
		"not_frozen":
			return wallet == null or not wallet.frozen
		"low_steps":
			return wallet != null and not wallet.frozen \
				and wallet.steps <= wallet.config.low_steps_threshold
	push_warning("DialogueRunner: unknown condition '%s'" % condition)
	return true


func _apply_effects(effects: Array) -> void:
	for effect in effects:
		match str(effect.get("type", "")):
			"grant_steps":
				if wallet != null:
					wallet.grant(int(effect.get("amount", 0)), "dialogue")
			"set_flag":
				flags[str(effect.get("flag", ""))] = true
			"":
				pass
			_:
				push_warning("DialogueRunner: unknown effect '%s'" % effect.get("type", ""))


func _finish() -> void:
	if not active:
		return
	active = false
	_lines = []
	_index = 0
	_choices = []
	_node_id = ""
	finished.emit()


func _load_dialogue(path: String) -> Dictionary:
	if path.is_empty():
		return {}
	if _cache.has(path):
		return _cache[path]

	var text := FileAccess.get_file_as_string(path)
	if text.is_empty():
		return {}
	var parsed: Variant = JSON.parse_string(text)
	if typeof(parsed) != TYPE_DICTIONARY:
		push_error("DialogueRunner: %s is not a JSON object" % path)
		return {}
	_cache[path] = parsed
	return parsed
