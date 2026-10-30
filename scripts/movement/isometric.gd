## Isometric grid mathematics.
##
## The map uses a diamond ("diamond down") isometric layout:
##   grid +x  ->  screen down-right
##   grid +y  ->  screen down-left
##
## Keeping every conversion in one place means the movement code, the map builder,
## the camera limits and any later pathfinding all agree on the same geometry.
class_name Isometric
extends RefCounted

## Size of one diamond tile in pixels.
const TILE_W := 64
const TILE_H := 32

const HALF_W := TILE_W / 2.0
const HALF_H := TILE_H / 2.0


## Centre of a grid cell in world space.
static func grid_to_world(cell: Vector2i) -> Vector2:
	return Vector2(
		(cell.x - cell.y) * HALF_W,
		(cell.x + cell.y) * HALF_H
	)


## Nearest grid cell for a world position.
static func world_to_grid(world_pos: Vector2) -> Vector2i:
	var a := world_pos.x / HALF_W
	var b := world_pos.y / HALF_H
	return Vector2i(
		roundi((a + b) * 0.5),
		roundi((b - a) * 0.5)
	)


## Converts an 8-way screen-space input direction into a grid delta.
##
## On a diamond grid the 8 compass directions are not evenly spaced:
##   - a single key (E/W/N/S) travels two cells along a grid axis,
##   - two keys together (NE/NW/SE/SW) travel one cell diagonally.
## Both are legitimate grid moves, every cell stays reachable, and
## Isometric.manhattan() reports the true cost (2 or 1).
static func input_to_grid(input_dir: Vector2i) -> Vector2i:
	if input_dir.x != 0 and input_dir.y != 0:
		# diagonal key pair -> one adjacent diamond cell
		return Vector2i(
			(input_dir.x + input_dir.y) / 2,
			(input_dir.y - input_dir.x) / 2
		)
	# single key -> two cells along one grid axis
	return Vector2i(input_dir.x + input_dir.y, input_dir.y - input_dir.x)


## Screen-space offset produced by a grid delta (used for facing selection).
static func grid_to_screen(delta: Vector2i) -> Vector2:
	return Vector2(delta.x - delta.y, (delta.x + delta.y) * 0.5)


## One of: n, ne, e, se, s, sw, w, nw. Matches the animation names in ren_frames.tres.
static func facing_name(delta: Vector2i) -> String:
	if delta == Vector2i.ZERO:
		return "s"
	const NAMES := ["e", "se", "s", "sw", "w", "nw", "n", "ne"]
	var dir := grid_to_screen(delta)
	var index := roundi(atan2(dir.y, dir.x) / (PI / 4.0))
	return NAMES[wrapi(index, 0, 8)]


## Distance travelled, in grid cells. This is what the Steps economy will charge for.
static func manhattan(delta: Vector2i) -> int:
	return absi(delta.x) + absi(delta.y)


## Cells crossed when travelling between two grid positions.
##
## Diagonal moves are resolved through BOTH adjacent cells so that a corner
## cannot be cut between two blocking props - and so that A->B and B->A test
## exactly the same set of cells (movement stays reversible).
static func path_cells(from_cell: Vector2i, to_cell: Vector2i) -> Array[Vector2i]:
	var cells: Array[Vector2i] = []
	if from_cell.x != to_cell.x and from_cell.y != to_cell.y:
		# Diagonal: both neighbours must be free (no corner-cutting).
		cells.append(Vector2i(to_cell.x, from_cell.y))
		cells.append(Vector2i(from_cell.x, to_cell.y))
	elif from_cell.x != to_cell.x:
		cells.append(Vector2i(to_cell.x, from_cell.y))
	elif from_cell.y != to_cell.y:
		cells.append(Vector2i(from_cell.x, to_cell.y))
	if from_cell != to_cell:
		cells.append(to_cell)
	# De-duplicate while preserving order.
	var seen := {}
	var unique: Array[Vector2i] = []
	for c in cells:
		if seen.has(c):
			continue
		seen[c] = true
		unique.append(c)
	return unique
