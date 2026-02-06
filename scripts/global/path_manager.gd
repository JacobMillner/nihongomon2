## PathManager - Handles enemy navigation using A* pathfinding
## Builds grid-based navigation graph from walkable cells
extends Node

## Reference to MapManager for cell data
var map_manager: Node

## AStar3D instance for pathfinding
var astar: AStar3D

## Mapping from cell to AStar point ID
var cell_to_id: Dictionary = {}  # Vector3i -> int
var id_to_cell: Dictionary = {}  # int -> Vector3i

## Precomputed paths from each spawn to each end
var cached_paths: Dictionary = {}  # "spawn_x,y,z->end_x,y,z" -> Array[Vector3i]

## Signal when paths are built
signal paths_ready

func _ready() -> void:
	astar = AStar3D.new()

## Initialize the path manager with map data
func initialize(p_map_manager: Node) -> void:
	map_manager = p_map_manager
	build_navigation_graph()
	precompute_paths()
	paths_ready.emit()

## Build the A* navigation graph from walkable cells
func build_navigation_graph() -> void:
	astar.clear()
	cell_to_id.clear()
	id_to_cell.clear()
	
	# Add all walkable cells as points
	var point_id := 0
	for cell in map_manager.walkable_cells:
		var world_pos := GridService.cell_to_world(cell)
		astar.add_point(point_id, world_pos)
		cell_to_id[cell] = point_id
		id_to_cell[point_id] = cell
		point_id += 1
	
	# Connect adjacent walkable cells
	for cell in map_manager.walkable_cells:
		var current_id: int = cell_to_id[cell]
		var neighbors := GridService.neighbors_4(cell)
		
		for neighbor in neighbors:
			if neighbor in cell_to_id:
				var neighbor_id: int = cell_to_id[neighbor]
				if not astar.are_points_connected(current_id, neighbor_id):
					astar.connect_points(current_id, neighbor_id, true)
	
	print("PathManager: Built graph with %d points" % astar.get_point_count())

## Precompute paths from all spawns to all ends
func precompute_paths() -> void:
	cached_paths.clear()
	
	for spawn_cell in map_manager.spawn_cells:
		for end_cell in map_manager.end_cells:
			var path := find_path(spawn_cell, end_cell)
			if path.size() > 0:
				var key := _make_path_key(spawn_cell, end_cell)
				cached_paths[key] = path
				print("PathManager: Cached path from %s to %s (%d cells)" % [spawn_cell, end_cell, path.size()])

## Generate a cache key for a spawn->end path
func _make_path_key(from_cell: Vector3i, to_cell: Vector3i) -> String:
	return "%d,%d,%d->%d,%d,%d" % [from_cell.x, from_cell.y, from_cell.z, to_cell.x, to_cell.y, to_cell.z]

## Find a path between two cells
func find_path(from_cell: Vector3i, to_cell: Vector3i) -> Array[Vector3i]:
	if from_cell not in cell_to_id or to_cell not in cell_to_id:
		return []
	
	var from_id: int = cell_to_id[from_cell]
	var to_id: int = cell_to_id[to_cell]
	
	var world_path := astar.get_point_path(from_id, to_id)
	var grid_path: Array[Vector3i] = []
	
	for world_pos in world_path:
		grid_path.append(GridService.world_to_cell(world_pos))
	
	return grid_path

## Get a cached path from spawn to end
func get_cached_path(spawn_cell: Vector3i, end_cell: Vector3i) -> Array[Vector3i]:
	var key := _make_path_key(spawn_cell, end_cell)
	if key in cached_paths:
		# Return a copy to avoid modification
		var path: Array[Vector3i] = []
		path.assign(cached_paths[key])
		return path
	return []

## Get the path for an enemy spawning at a given spawn cell
## Automatically finds the closest/default end cell
func get_enemy_path(spawn_cell: Vector3i) -> Array[Vector3i]:
	if map_manager.end_cells.is_empty():
		push_error("PathManager: No end cells defined")
		return []
	
	# For now, use the first end cell (can be expanded for multiple exits)
	var end_cell: Vector3i = map_manager.end_cells[0]
	return get_cached_path(spawn_cell, end_cell)

## Check if a path exists between two cells
func has_path(from_cell: Vector3i, to_cell: Vector3i) -> bool:
	if from_cell not in cell_to_id or to_cell not in cell_to_id:
		return false
	
	var from_id: int = cell_to_id[from_cell]
	var to_id: int = cell_to_id[to_cell]
	
	# Get the connected component of from_id
	var id_path := astar.get_id_path(from_id, to_id)
	return id_path.size() > 0
