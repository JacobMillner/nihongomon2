## MapManager - Parses GridMap tiles at runtime and categorizes cells by type
extends Node

## Tile type enum matching MeshLibrary item IDs
enum TileType {
	SPAWN = 0,
	END = 1,
	GROUND = 2,      # Deployable ground
	HAZARD = 3,      # Blocked
	RAMP = 4,
	DOODAD = 5,      # Blocked decoration
	PATH = 6,        # Enemy walkable
}

## Cell category sets
var walkable_cells: Array[Vector3i] = []
var deployable_ground_cells: Array[Vector3i] = []
var deployable_high_cells: Array[Vector3i] = []
var spawn_cells: Array[Vector3i] = []
var end_cells: Array[Vector3i] = []
var blocked_cells: Array[Vector3i] = []
var path_cells: Array[Vector3i] = []

## Dictionary for quick cell type lookup
var cell_types: Dictionary = {}  # Vector3i -> TileType

## Reference to the GridMap
var grid_map: GridMap

## Signal emitted when map is parsed
signal map_parsed

func _ready() -> void:
	pass

## Initialize with a GridMap reference and parse it
func initialize(p_grid_map: GridMap) -> void:
	grid_map = p_grid_map
	parse_grid_map()

## Parse the GridMap and categorize all cells
func parse_grid_map() -> void:
	if not grid_map:
		push_error("MapManager: No GridMap assigned")
		return
	
	# Clear existing data
	_clear_data()
	
	# Get all used cells from the GridMap
	var used_cells := grid_map.get_used_cells()
	
	for cell in used_cells:
		var tile_id := grid_map.get_cell_item(cell)
		if tile_id == GridMap.INVALID_CELL_ITEM:
			continue
		
		cell_types[cell] = tile_id
		_categorize_cell(cell, tile_id)
	
	print("MapManager: Parsed %d cells" % used_cells.size())
	print("  - Spawn cells: %d" % spawn_cells.size())
	print("  - End cells: %d" % end_cells.size())
	print("  - Path cells: %d" % path_cells.size())
	print("  - Walkable cells: %d" % walkable_cells.size())
	print("  - Deployable ground: %d" % deployable_ground_cells.size())
	
	map_parsed.emit()

## Clear all stored cell data
func _clear_data() -> void:
	walkable_cells.clear()
	deployable_ground_cells.clear()
	deployable_high_cells.clear()
	spawn_cells.clear()
	end_cells.clear()
	blocked_cells.clear()
	path_cells.clear()
	cell_types.clear()

## Categorize a cell based on its tile type
func _categorize_cell(cell: Vector3i, tile_id: int) -> void:
	match tile_id:
		TileType.SPAWN:
			spawn_cells.append(cell)
			walkable_cells.append(cell)
		TileType.END:
			end_cells.append(cell)
			walkable_cells.append(cell)
		TileType.GROUND:
			deployable_ground_cells.append(cell)
		TileType.PATH:
			path_cells.append(cell)
			walkable_cells.append(cell)
		TileType.RAMP:
			walkable_cells.append(cell)
		TileType.HAZARD, TileType.DOODAD:
			blocked_cells.append(cell)

## Check if a cell is walkable for enemies
func is_walkable(cell: Vector3i) -> bool:
	return cell in walkable_cells

## Check if a cell is deployable for ground units
func is_deployable_ground(cell: Vector3i) -> bool:
	return cell in deployable_ground_cells

## Check if a cell is deployable for high ground units
func is_deployable_high(cell: Vector3i) -> bool:
	return cell in deployable_high_cells

## Check if a cell is a spawn point
func is_spawn(cell: Vector3i) -> bool:
	return cell in spawn_cells

## Check if a cell is an end point
func is_end(cell: Vector3i) -> bool:
	return cell in end_cells

## Get the tile type at a cell
func get_tile_type(cell: Vector3i) -> int:
	return cell_types.get(cell, -1)

## Get all cells of a specific type
func get_cells_by_type(tile_type: TileType) -> Array[Vector3i]:
	var result: Array[Vector3i] = []
	for cell in cell_types:
		if cell_types[cell] == tile_type:
			result.append(cell)
	return result
