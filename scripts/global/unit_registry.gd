## UnitRegistry - Central system tracking unit occupancy and blocking relationships
extends Node

## All active units
var all_units: Array[Node] = []
var player_units: Array[Node] = []
var enemy_units: Array[Node] = []

## Grid occupancy tracking
var cell_occupants: Dictionary = {}  # Vector3i -> Array[Node]

## Blocking relationships
var blocking_pairs: Dictionary = {}  # blocker_unit -> Array[enemy_unit]
var blocked_by: Dictionary = {}      # enemy_unit -> blocker_unit

## Signals
signal unit_registered(unit: Node)
signal unit_unregistered(unit: Node)
signal unit_blocked(enemy: Node, blocker: Node)
signal unit_unblocked(enemy: Node)

func _ready() -> void:
	pass

## Register a unit in the system
func register_unit(unit: Node) -> void:
	if unit in all_units:
		return
	
	all_units.append(unit)
	
	if unit.has_method("get_faction"):
		var faction = unit.get_faction()
		if faction == 0:  # PLAYER
			player_units.append(unit)
		else:  # ENEMY
			enemy_units.append(unit)
	
	# Register cell occupancy
	if unit.has_method("get_grid_cell"):
		var cell: Vector3i = unit.get_grid_cell()
		_add_to_cell(unit, cell)
	
	unit_registered.emit(unit)

## Unregister a unit from the system
func unregister_unit(unit: Node) -> void:
	if unit not in all_units:
		return
	
	all_units.erase(unit)
	player_units.erase(unit)
	enemy_units.erase(unit)
	
	# Remove from cell occupancy
	if unit.has_method("get_grid_cell"):
		var cell: Vector3i = unit.get_grid_cell()
		_remove_from_cell(unit, cell)
	
	# Clear blocking relationships
	_clear_blocking(unit)
	
	unit_unregistered.emit(unit)

## Update a unit's cell position
func update_unit_cell(unit: Node, old_cell: Vector3i, new_cell: Vector3i) -> void:
	_remove_from_cell(unit, old_cell)
	_add_to_cell(unit, new_cell)

## Add a unit to a cell's occupant list
func _add_to_cell(unit: Node, cell: Vector3i) -> void:
	if cell not in cell_occupants:
		cell_occupants[cell] = []
	if unit not in cell_occupants[cell]:
		cell_occupants[cell].append(unit)

## Remove a unit from a cell's occupant list
func _remove_from_cell(unit: Node, cell: Vector3i) -> void:
	if cell in cell_occupants:
		cell_occupants[cell].erase(unit)
		if cell_occupants[cell].is_empty():
			cell_occupants.erase(cell)

## Get all units at a cell
func get_units_at_cell(cell: Vector3i) -> Array:
	return cell_occupants.get(cell, [])

## Get player unit at a cell (returns first one, or null)
func get_player_unit_at_cell(cell: Vector3i) -> Node:
	var units = get_units_at_cell(cell)
	for unit in units:
		if unit in player_units:
			return unit
	return null

## Get enemy units at a cell
func get_enemy_units_at_cell(cell: Vector3i) -> Array:
	var enemies: Array = []
	var units = get_units_at_cell(cell)
	for unit in units:
		if unit in enemy_units:
			enemies.append(unit)
	return enemies

## Check if a cell is occupied by a player unit
func is_cell_occupied_by_player(cell: Vector3i) -> bool:
	return get_player_unit_at_cell(cell) != null

## Check if a cell is blocked for deployment
func is_cell_blocked_for_deployment(cell: Vector3i) -> bool:
	return is_cell_occupied_by_player(cell)

## Establish a blocking relationship
func block_enemy(blocker: Node, enemy: Node) -> void:
	if blocker not in blocking_pairs:
		blocking_pairs[blocker] = []
	
	if enemy not in blocking_pairs[blocker]:
		blocking_pairs[blocker].append(enemy)
	
	blocked_by[enemy] = blocker
	unit_blocked.emit(enemy, blocker)

## Remove blocking relationship
func unblock_enemy(enemy: Node) -> void:
	if enemy not in blocked_by:
		return
	
	var blocker = blocked_by[enemy]
	if blocker in blocking_pairs:
		blocking_pairs[blocker].erase(enemy)
	
	blocked_by.erase(enemy)
	unit_unblocked.emit(enemy)

## Get the unit blocking an enemy
func get_blocker(enemy: Node) -> Node:
	return blocked_by.get(enemy, null)

## Get all enemies blocked by a unit
func get_blocked_enemies(blocker: Node) -> Array:
	return blocking_pairs.get(blocker, [])

## Get how many more enemies a blocker can block
func get_remaining_block_count(blocker: Node) -> int:
	if not blocker.has_method("get_block_count"):
		return 0
	var max_blocks: int = blocker.get_block_count()
	var current_blocks: int = get_blocked_enemies(blocker).size()
	return max_blocks - current_blocks

## Check if a blocker can block more enemies
func can_block_more(blocker: Node) -> bool:
	return get_remaining_block_count(blocker) > 0

## Clear all blocking relationships for a unit
func _clear_blocking(unit: Node) -> void:
	# If this unit was a blocker, release all blocked enemies
	if unit in blocking_pairs:
		for enemy in blocking_pairs[unit]:
			blocked_by.erase(enemy)
			unit_unblocked.emit(enemy)
		blocking_pairs.erase(unit)
	
	# If this unit was blocked, remove from blocker's list
	if unit in blocked_by:
		var blocker = blocked_by[unit]
		if blocker in blocking_pairs:
			blocking_pairs[blocker].erase(unit)
		blocked_by.erase(unit)

## Find a blocker for an enemy at/near a cell
func find_blocker_for_enemy(enemy: Node, cell: Vector3i) -> Node:
	# Check the cell and adjacent cells for player units that can block
	var cells_to_check := [cell]
	cells_to_check.append_array(GridService.neighbors_4(cell))
	
	for check_cell in cells_to_check:
		var player_unit := get_player_unit_at_cell(check_cell)
		if player_unit and can_block_more(player_unit):
			# Check if enemy is in block range (typically 1 cell)
			if GridService.grid_distance(check_cell, cell) <= 1:
				return player_unit
	
	return null

## Get all enemies in range of a player unit
func get_enemies_in_range(unit: Node, attack_range: int) -> Array:
	var result: Array = []
	var unit_cell: Vector3i = unit.get_grid_cell()
	
	for enemy in enemy_units:
		if not is_instance_valid(enemy):
			continue
		var enemy_cell: Vector3i = enemy.get_grid_cell()
		if GridService.grid_distance(unit_cell, enemy_cell) <= attack_range:
			result.append(enemy)
	
	return result

## Get all player units in range of an enemy
func get_player_units_in_range(enemy: Node, attack_range: int) -> Array:
	var result: Array = []
	var enemy_cell: Vector3i = enemy.get_grid_cell()
	
	for player_unit in player_units:
		if not is_instance_valid(player_unit):
			continue
		var unit_cell: Vector3i = player_unit.get_grid_cell()
		if GridService.grid_distance(enemy_cell, unit_cell) <= attack_range:
			result.append(player_unit)
	
	return result

## Clear all registry data
func clear() -> void:
	all_units.clear()
	player_units.clear()
	enemy_units.clear()
	cell_occupants.clear()
	blocking_pairs.clear()
	blocked_by.clear()
