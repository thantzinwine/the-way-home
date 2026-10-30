## Spawns the NPCs listed in a data file and answers "who is Ren standing next to?".
##
## Placement lives in res://data/npcs/family.txt so writers can add a character
## without touching a scene. Spawning also blocks the NPC's cell on the map, which is
## what stops Ren walking through people.
class_name NPCManager
extends Node

signal spawned(count: int)

const NPC_SCENE := preload("res://scenes/npcs/npc.tscn")

@export_file("*.txt") var npc_file := "res://data/npcs/family.txt"
@export var world_path: NodePath
@export var map_path: NodePath

var npcs: Array[NPC] = []

var _world: Node2D
var _map: MapBuilder
var _by_id := {}


## Spawns every NPC. Safe to call once, after the map is built.
func spawn_all() -> void:
	_world = get_node_or_null(world_path) as Node2D
	_map = get_node_or_null(map_path) as MapBuilder
	if _world == null or _map == null:
		push_error("NPCManager: world_path / map_path not set")
		return

	var text := FileAccess.get_file_as_string(npc_file)
	if text.is_empty():
		push_error("NPCManager: could not read %s" % npc_file)
		return

	for definition in parse(text):
		var npc := NPC_SCENE.instantiate() as NPC
		npc.name = "NPC_%s" % str(definition["id"]).capitalize()
		_world.add_child(npc)
		if not npc.setup(definition):
			npc.queue_free()
			continue
		_map.block_cell(npc.cell)
		npcs.append(npc)
		_by_id[npc.id] = npc

	spawned.emit(npcs.size())


## Parses the pipe-separated data file. Exposed so the tests can check it directly.
static func parse(text: String) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for raw_line in text.split("\n"):
		var line := raw_line.strip_edges()
		if line.is_empty() or line.begins_with("//"):
			continue
		var parts := line.split("|")
		if parts.size() < 5:
			push_warning("NPCManager: bad NPC line: %s" % line)
			continue

		var xy := parts[2].strip_edges().split(",")
		if xy.size() != 2:
			push_warning("NPCManager: bad cell in NPC line: %s" % line)
			continue

		out.append({
			"id": parts[0].strip_edges(),
			"name": parts[1].strip_edges(),
			"cell": Vector2i(int(xy[0]), int(xy[1])),
			"facing": parts[3].strip_edges(),
			"dialogue": parts[4].strip_edges(),
		})
	return out


func get_npc(id: String) -> NPC:
	return _by_id.get(id, null)


func npc_at(cell: Vector2i) -> NPC:
	for npc in npcs:
		if npc.cell == cell:
			return npc
	return null


## The NPC Ren can talk to from `from_cell`.
##
## Every neighbouring cell counts (including diagonals) but whoever Ren is facing
## wins, so the target matches what the player sees on screen.
func find_interactable(from_cell: Vector2i, facing: String) -> NPC:
	var best: NPC = null
	var best_score := -1
	for npc in npcs:
		var delta := npc.cell - from_cell
		if delta == Vector2i.ZERO:
			continue
		if maxi(absi(delta.x), absi(delta.y)) > 1:
			continue
		var score := 2 if Isometric.facing_name(delta) == facing else 1
		if score > best_score:
			best = npc
			best_score = score
	return best


## Display name for a speaker id used in dialogue files ("ren" included).
func display_name_for(id: String) -> String:
	if id == "ren":
		return "Ren"
	var npc := get_npc(id)
	return npc.display_name if npc != null else ""
