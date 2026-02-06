## AttackRangeDisplay - Displays attack range indicators when placing units
extends Node3D

## The attack range indicator scene
var attack_range_scene: PackedScene = preload("res://entity/attack_range/attack_range.tscn")

## Pool of range indicator instances
var range_indicators: Array[Node3D] = []

## Currently displayed cells
var displayed_cells: Array[Vector3i] = []

## Height offset for indicators (on top of tiles)
const INDICATOR_Y_OFFSET: float = 1.02

## Is display active
var is_active: bool = false

func _ready() -> void:
	hide()

## Show attack range for a unit at a given cell with facing direction
func show_range(cell: Vector3i, facing: int, definition: UnitDefinition) -> void:
	if not definition:
		hide_range()
		return
	
	is_active = true
	show()
	
	# Get cells in attack range
	var attack_range := definition.attack_range
	var cells_in_range := _get_attack_cells(cell, facing, attack_range, definition.is_ranged)
	
	# Update display
	_update_indicators(cells_in_range)

## Hide all range indicators
func hide_range() -> void:
	is_active = false
	hide()
	for indicator in range_indicators:
		indicator.hide()
	displayed_cells.clear()

## Get cells that would be in attack range from a position
func _get_attack_cells(center: Vector3i, facing: int, attack_range: int, is_ranged: bool) -> Array[Vector3i]:
	var cells: Array[Vector3i] = []
	
	if is_ranged:
		# Ranged units can attack in all directions within range
		cells = GridService.get_cells_in_range(center, attack_range)
	else:
		# Melee units attack in front based on facing direction
		# For simplicity, show all cells in range but could be facing-based
		cells = GridService.get_cells_in_range(center, attack_range)
	
	# Remove the center cell (unit's own position)
	var center_idx := cells.find(center)
	if center_idx >= 0:
		cells.remove_at(center_idx)
	
	return cells

## Update the indicator display for given cells
func _update_indicators(cells: Array[Vector3i]) -> void:
	displayed_cells = cells
	
	# Ensure we have enough indicators
	while range_indicators.size() < cells.size():
		var indicator := attack_range_scene.instantiate() as Node3D
		add_child(indicator)
		range_indicators.append(indicator)
		# Scale down the sphere to fit in a cell
		indicator.scale = Vector3(0.8, 0.2, 0.8)
	
	# Position and show indicators for each cell
	for i in range(cells.size()):
		var indicator := range_indicators[i]
		var world_pos := GridService.cell_to_world(cells[i])
		world_pos.y = INDICATOR_Y_OFFSET
		indicator.global_position = world_pos
		indicator.show()
	
	# Hide unused indicators
	for i in range(cells.size(), range_indicators.size()):
		range_indicators[i].hide()

## Clear all indicators (for cleanup)
func clear_all() -> void:
	hide_range()
	for indicator in range_indicators:
		indicator.queue_free()
	range_indicators.clear()
