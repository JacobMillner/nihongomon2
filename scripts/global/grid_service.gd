## GridService - Autoload singleton for grid math utilities
## Handles cell ↔ world conversions, distance calculations, and neighbor queries
extends Node

## Cell size in world units (matches GridMap cell_size)
var cell_size: Vector3 = Vector3(1, 1, 1)

## Direction enum for unit facing
enum Direction { NORTH, EAST, SOUTH, WEST }

## Direction vectors for each cardinal direction (on XZ plane)
const DIRECTION_VECTORS := {
	Direction.NORTH: Vector3i(0, 0, -1),
	Direction.EAST: Vector3i(1, 0, 0),
	Direction.SOUTH: Vector3i(0, 0, 1),
	Direction.WEST: Vector3i(-1, 0, 0),
}

## Convert grid cell to world position (center of cell)
func cell_to_world(cell: Vector3i) -> Vector3:
	return Vector3(
		cell.x * cell_size.x + cell_size.x * 0.5,
		cell.y * cell_size.y + cell_size.y * 0.5,
		cell.z * cell_size.z + cell_size.z * 0.5
	)

## Convert world position to grid cell
func world_to_cell(pos: Vector3) -> Vector3i:
	return Vector3i(
		floori(pos.x / cell_size.x),
		floori(pos.y / cell_size.y),
		floori(pos.z / cell_size.z)
	)

## Calculate Manhattan distance between two cells (used for range checks)
func grid_distance(a: Vector3i, b: Vector3i) -> int:
	return absi(a.x - b.x) + absi(a.z - b.z)

## Calculate Chebyshev distance (diagonal movement allowed)
func grid_distance_chebyshev(a: Vector3i, b: Vector3i) -> int:
	return maxi(absi(a.x - b.x), absi(a.z - b.z))

## Get 4-directional neighbors (N, E, S, W)
func neighbors_4(cell: Vector3i) -> Array[Vector3i]:
	return [
		cell + DIRECTION_VECTORS[Direction.NORTH],
		cell + DIRECTION_VECTORS[Direction.EAST],
		cell + DIRECTION_VECTORS[Direction.SOUTH],
		cell + DIRECTION_VECTORS[Direction.WEST],
	]

## Get 8-directional neighbors (includes diagonals)
func neighbors_8(cell: Vector3i) -> Array[Vector3i]:
	var result: Array[Vector3i] = []
	for dx in range(-1, 2):
		for dz in range(-1, 2):
			if dx == 0 and dz == 0:
				continue
			result.append(cell + Vector3i(dx, 0, dz))
	return result

## Get direction from one cell to another (returns closest cardinal direction)
func get_direction_to(from_cell: Vector3i, to_cell: Vector3i) -> Direction:
	var delta := to_cell - from_cell
	if abs(delta.x) > abs(delta.z):
		return Direction.EAST if delta.x > 0 else Direction.WEST
	else:
		return Direction.SOUTH if delta.z > 0 else Direction.NORTH

## Get rotation (Y-axis) for a direction
func direction_to_rotation(dir: Direction) -> float:
	match dir:
		Direction.NORTH: return 0.0
		Direction.EAST: return -PI / 2.0
		Direction.SOUTH: return PI
		Direction.WEST: return PI / 2.0
	return 0.0

## Get cell in front of a position based on facing direction
func get_front_cell(cell: Vector3i, facing: Direction) -> Vector3i:
	return cell + DIRECTION_VECTORS[facing]

## Get cells within Manhattan distance range
func get_cells_in_range(center: Vector3i, range_val: int) -> Array[Vector3i]:
	var cells: Array[Vector3i] = []
	for dx in range(-range_val, range_val + 1):
		for dz in range(-range_val, range_val + 1):
			if absi(dx) + absi(dz) <= range_val:
				cells.append(center + Vector3i(dx, 0, dz))
	return cells

## Check if a cell is within range of another
func is_in_range(from_cell: Vector3i, to_cell: Vector3i, range_val: int) -> bool:
	return grid_distance(from_cell, to_cell) <= range_val
