## Grid mathematics for the 3D world.
class_name Isometric
extends RefCounted

const CELL := 1.0

static func grid_to_world(cell: Vector2i) -> Vector3:
	return Vector3(cell.x * CELL, 0.0, cell.y * CELL)

static func world_to_grid(world_pos: Vector3) -> Vector2i:
	return Vector2i(roundi(world_pos.x / CELL), roundi(world_pos.z / CELL))

static func input_to_grid(input_dir: Vector2i) -> Vector2i:
	return input_dir

static func grid_to_screen(delta: Vector2i) -> Vector2:
	return Vector2(delta.x, -delta.y)

static func facing_name(delta: Vector2i) -> String:
	if delta == Vector2i.ZERO:
		return "s"
	const NAMES := ["e", "se", "s", "sw", "w", "nw", "n", "ne"]
	var dir := grid_to_screen(delta)
	var index := roundi(atan2(dir.y, dir.x) / (PI / 4.0))
	return NAMES[wrapi(index, 0, 8)]

static func manhattan(delta: Vector2i) -> int:
	return absi(delta.x) + absi(delta.y)

static func path_cells(from_cell: Vector2i, to_cell: Vector2i) -> Array[Vector2i]:
	var cells: Array[Vector2i] = []
	if from_cell.x != to_cell.x and from_cell.y != to_cell.y:
		cells.append(Vector2i(to_cell.x, from_cell.y))
		cells.append(Vector2i(from_cell.x, to_cell.y))
	elif from_cell.x != to_cell.x:
		cells.append(Vector2i(to_cell.x, from_cell.y))
	elif from_cell.y != to_cell.y:
		cells.append(Vector2i(from_cell.x, to_cell.y))
	if from_cell != to_cell:
		cells.append(to_cell)
	var seen := {}
	var unique: Array[Vector2i] = []
	for c in cells:
		if seen.has(c):
			continue
		seen[c] = true
		unique.append(c)
	return unique

static func facing_yaw(delta: Vector2i) -> float:
	if delta == Vector2i.ZERO:
		return 0.0
	return atan2(float(delta.x), float(delta.y))
