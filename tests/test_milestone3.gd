## Milestone 3 acceptance test: NPCs, interaction and branching dialogue.
##
## Loads the real main scene. Exits non-zero on failure.
##
## Run:  godot --headless --path . --script res://tests/test_milestone3.gd
extends SceneTree

var failures := 0
var checks := 0

var main: Node2D
var map: MapBuilder
var player: PlayerRen
var npcs: NPCManager
var dialogue: DialogueRunner
var interaction: InteractionSystem
var box: DialogueBox
var wallet: StepsWallet

var lines_seen: Array = []
var choices_seen: Array = []
var finished_count := 0
var started_count := 0


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
	dialogue = main.get_node("Dialogue")
	interaction = main.get_node("Interaction")
	box = main.get_node("DialogueBox")
	wallet = main.steps

	main.steps.set_steps(9999)

	dialogue.started.connect(func(_npc: NPC) -> void: started_count += 1)
	dialogue.line_shown.connect(func(who: String, name: String, text: String) -> void:
		lines_seen.append([who, name, text]))
	dialogue.choices_shown.connect(func(choices: Array) -> void:
		choices_seen.append(choices.duplicate(true)))
	dialogue.finished.connect(func() -> void: finished_count += 1)

	_test_npc_data()
	_test_npc_spawn()
	_test_walkability()
	_test_interaction_detection()
	await _test_dialogue_flow()
	await _test_once_flags()
	await _test_frozen_variant()
	_test_data_integrity()
	_test_portraits()

	print("\n--- %d/%d checks passed ---" % [checks - failures, checks])
	if failures > 0:
		print("RESULT: FAIL (%d)" % failures)
		quit(1)
	else:
		print("RESULT: PASS")
		quit(0)


# --- tests ---------------------------------------------------------------------

func _test_npc_data() -> void:
	var text := FileAccess.get_file_as_string("res://data/npcs/family.txt")
	var defs := NPCManager.parse(text)
	_check("family file parses 4 NPCs", defs.size() == 4)

	var ids: Array = []
	for d in defs:
		ids.append(d.id)
	_check("mother is present", ids.has("mother"))
	_check("father is present", ids.has("father"))
	_check("grandmother is present", ids.has("grandmother"))
	_check("sister is present", ids.has("sister"))

	var mother: Dictionary = _def(defs, "mother")
	_check("mother's cell is (4,11)", mother.cell == Vector2i(4, 11))
	_check("mother faces north", mother.facing == "n")

	var sister: Dictionary = _def(defs, "sister")
	_check("sister's cell is (7,8)", sister.cell == Vector2i(7, 8))


func _test_npc_spawn() -> void:
	_check("4 NPCs spawned", npcs.npcs.size() == 4)
	_check("every NPC has sprite frames", _all_have_frames())
	_check("mother is in the World (y-sorted parent)",
		npcs.get_npc("mother").get_parent() == main.world)


func _test_walkability() -> void:
	for npc in npcs.npcs:
		_check("cell of %s is blocked" % npc.id, not map.is_walkable(npc.cell))

	player.mover.setup(player, Vector2i(3, 11), map.is_walkable)
	var before := player.mover.cell
	var blocked := player.mover.try_step(Vector2i(1, 0))
	_check("stepping onto an NPC is refused", not blocked)
	_check("cell unchanged after the refusal", player.mover.cell == before)


func _test_interaction_detection() -> void:
	player.mover.setup(player, Vector2i(3, 11), map.is_walkable)
	player.facing = "e"
	player.input_enabled = true

	var found := npcs.find_interactable(player.mover.cell, player.facing)
	_check("mother is found when Ren faces her", found != null and found.id == "mother")

	found = npcs.find_interactable(Vector2i(2, 11), "e")
	_check("mother is not found from two cells away",
		found == null or found.id != "mother")

	interaction._process(0.0)
	_check("interaction.target is the mother",
		interaction.target != null and interaction.target.id == "mother")
	_check("the prompt names her",
		box.prompt.visible and box.prompt.text.contains("Daw Mya"))


func _test_dialogue_flow() -> void:
	player.mover.setup(player, Vector2i(3, 11), map.is_walkable)
	player.facing = "e"
	player.input_enabled = true

	lines_seen.clear()
	choices_seen.clear()
	finished_count = 0
	started_count = 0

	var mother := npcs.get_npc("mother")
	var ok := interaction.begin(mother)
	_check("begin() starts a conversation", ok and dialogue.active)
	_check("Ren stops moving during dialogue", not player.input_enabled)
	_check("Ren faces the mother", player.facing == "se")
	_check("the mother faces Ren",
		Isometric.facing_name(player.mover.cell - mother.cell) == mother.facing)

	_check("started signal fired", started_count == 1)
	_check("first line is spoken by Daw Mya",
		lines_seen.size() >= 1 and lines_seen[0][1] == "Daw Mya")
	_check("first line mentions the kettle",
		lines_seen.size() >= 1 and lines_seen[0][2].contains("kettle"))
	_check("the panel is visible", box.panel.visible)
	_check("the portrait is set", box.portrait.visible)

	for i in 2:
		dialogue.advance()
	_check("all three lines have been shown", lines_seen.size() == 3)

	dialogue.advance()
	_check("choices are offered", choices_seen.size() == 1)
	_check("three choices on first visit", choices_seen[0].size() == 3)

	var texts: Array = _choice_texts(choices_seen[0])
	_check("'Ask her for Steps' is offered", texts.has("Ask her for Steps"))
	_check("'Ask about the Departure sign' is offered",
		texts.has("Ask about the Departure sign"))

	var before := wallet.steps
	dialogue.choose(0)
	_check("Steps were granted", wallet.steps == before + 25)
	_check("the mother's gift flag is set", dialogue.has_flag("mother_gift"))

	for i in 5:
		dialogue.advance()
	_check("the follow-up line is shown", _any_line_contains("people can see you"))
	_check("conversation ended", finished_count == 1)
	_check("dialogue is no longer active", not dialogue.active)
	_check("Ren can move again", player.input_enabled)
	_check("the panel is hidden", not box.panel.visible)


func _test_once_flags() -> void:
	player.mover.setup(player, Vector2i(3, 11), map.is_walkable)
	player.facing = "e"
	player.input_enabled = true

	lines_seen.clear()
	choices_seen.clear()
	finished_count = 0

	var mother := npcs.get_npc("mother")
	interaction.begin(mother)
	_check("re-talking starts a conversation", dialogue.active)

	for i in 2:
		dialogue.advance()
	dialogue.advance()
	_check("choices shown again", choices_seen.size() == 1)

	var texts: Array = _choice_texts(choices_seen[0])
	_check("the Steps choice is gone after the gift", not texts.has("Ask her for Steps"))
	_check("two choices remain", choices_seen[0].size() == 2)

	var bye_index := texts.find("Say you have to go")
	if bye_index < 0:
		bye_index = choices_seen[0].size() - 1
	dialogue.choose(bye_index)
	for i in 3:
		dialogue.advance()
	_check("conversation ended cleanly", finished_count == 1)


func _test_frozen_variant() -> void:
	wallet.set_steps(0)
	player.mover.setup(player, Vector2i(3, 11), map.is_walkable)
	player.facing = "e"
	player.input_enabled = true

	lines_seen.clear()
	choices_seen.clear()
	finished_count = 0

	var mother := npcs.get_npc("mother")
	var ok := interaction.begin(mother)
	_check("frozen Ren can still talk to his mother", ok and dialogue.active)

	for i in 2:
		dialogue.advance()
	dialogue.advance()
	_check("the frozen choice is offered",
		choices_seen.size() == 1
		and _choice_texts(choices_seen[0]).has("Tell her your body has stopped"))

	dialogue.choose(0)
	_check("frozen help grants 30 Steps", wallet.steps == 30)
	_check("Ren is unfrozen", not wallet.frozen)

	for i in 6:
		dialogue.advance()
	_check("the follow-up line mentions the sky", _any_line_contains("sky"))
	_check("frozen conversation ended", finished_count == 1)

	wallet.set_steps(9999)


func _test_data_integrity() -> void:
	for npc in npcs.npcs:
		var data: Dictionary = _load_json(npc.dialogue_path)
		_check("%s dialogue parses" % npc.id, not data.is_empty())
		if data.is_empty():
			continue

		var nodes: Dictionary = data.get("nodes", {})
		_check("%s has a start node" % npc.id, nodes.has(str(data.get("start", ""))))

		var valid_conditions := ["", "always", "frozen", "not_frozen", "low_steps"]
		var valid_effects := ["grant_steps", "set_flag"]
		for node_id in nodes.keys():
			var node: Dictionary = nodes[node_id]
			for line in node.get("lines", []):
				_check("%s/%s line has who+text" % [npc.id, node_id],
					line.has("who") and line.has("text"))
			var goto := str(node.get("goto", ""))
			if not goto.is_empty():
				_check("%s/%s goto resolves" % [npc.id, node_id], nodes.has(goto))
			for choice in node.get("choices", []):
				var cg := str(choice.get("goto", ""))
				if not cg.is_empty():
					_check("%s/%s choice goto resolves" % [npc.id, node_id],
						nodes.has(cg))
				_check("%s/%s choice condition valid" % [npc.id, node_id],
					valid_conditions.has(str(choice.get("if", ""))))
				for eff in choice.get("effects", []):
					_check("%s/%s choice effect valid" % [npc.id, node_id],
						valid_effects.has(str(eff.get("type", ""))))
			for eff in node.get("effects", []):
				_check("%s/%s node effect valid" % [npc.id, node_id],
					valid_effects.has(str(eff.get("type", ""))))

	_check("family file has 4 entries", NPCManager.parse(
		FileAccess.get_file_as_string("res://data/npcs/family.txt")).size() == 4)


func _test_portraits() -> void:
	for npc in npcs.npcs:
		var path := npc.portrait_path()
		_check("%s has a portrait file" % npc.id, ResourceLoader.exists(path))
	_check("Ren has a portrait file",
		ResourceLoader.exists("res://assets/characters/ren/ren_portrait.png"))


# --- helpers -------------------------------------------------------------------

func _def(defs: Array, id: String) -> Dictionary:
	for d in defs:
		if d.id == id:
			return d
	return {}


func _all_have_frames() -> bool:
	for npc in npcs.npcs:
		if npc.sprite.sprite_frames == null:
			return false
	return true


func _choice_texts(choices: Array) -> Array:
	var out: Array = []
	for c in choices:
		out.append(c.text)
	return out


func _any_line_contains(needle: String) -> bool:
	for line in lines_seen:
		if str(line[2]).contains(needle):
			return true
	return false


func _load_json(path: String) -> Dictionary:
	var text := FileAccess.get_file_as_string(path)
	if text.is_empty():
		return {}
	var parsed: Variant = JSON.parse_string(text)
	if typeof(parsed) != TYPE_DICTIONARY:
		return {}
	return parsed


func _check(label: String, condition: bool) -> void:
	checks += 1
	if condition:
		print("  ok    %s" % label)
	else:
		failures += 1
		print("  FAIL  %s" % label)
