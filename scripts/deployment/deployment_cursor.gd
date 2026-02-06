## DeploymentCursor - Handles grid-based placement preview for deploying units
extends Node3D

## The unit definition currently selected for deployment
var selected_definition: UnitDefinition = null

## Current grid cell the cursor is on
var current_cell: Vector3i = Vector3i.ZERO

## Current facing direction
var facing: int = GridService.Direction.SOUTH

## Is cursor visible/active
var is_active: bool = false

## Visual components
@onready var cursor_mesh: MeshInstance3D = $CursorMesh
@onready var direction_indicator: Node3D = $DirectionIndicator

## Colors
var valid_color: Color = Color(0, 1, 0, 0.5)
var invalid_color: Color = Color(1, 0, 0, 0.5)

## Camera for raycasting
var camera: Camera3D

## Height offset to display cursor above tiles
const CURSOR_Y_OFFSET: float = 1.05

## Signals
signal deployment_confirmed(cell: Vector3i, facing: int)
signal deployment_cancelled
signal cursor_moved(cell: Vector3i, facing: int, definition: UnitDefinition)
signal cursor_rotated(cell: Vector3i, facing: int, definition: UnitDefinition)

func _ready() -> void:
	hide()
	set_process_input(false)

func _input(event: InputEvent) -> void:
	if not is_active:
		return
	
	# Mouse movement - update cursor position
	if event is InputEventMouseMotion:
		_update_cursor_from_mouse(event.position)
	
	# WASD keyboard movement
	if event.is_action_pressed("cursor_up"):
		_move_cursor(Vector3i(0, 0, -1))
	elif event.is_action_pressed("cursor_down"):
		_move_cursor(Vector3i(0, 0, 1))
	elif event.is_action_pressed("cursor_left"):
		_move_cursor(Vector3i(-1, 0, 0))
	elif event.is_action_pressed("cursor_right"):
		_move_cursor(Vector3i(1, 0, 0))
	
	# Rotation input
	if event.is_action_pressed("rotate_cw"):
		_rotate_facing(1)
	elif event.is_action_pressed("rotate_ccw"):
		_rotate_facing(-1)
	
	# Confirm deployment (Enter or Left Click or Space)
	if event.is_action_pressed("confirm_deploy"):
		_try_confirm_deployment()
	elif event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		_try_confirm_deployment()
	
	# Cancel deployment (Escape or Right Click)
	if event.is_action_pressed("cancel_deploy"):
		_cancel_deployment()
	elif event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_RIGHT and event.pressed:
		_cancel_deployment()

## Try to confirm deployment if valid
func _try_confirm_deployment() -> void:
	if _is_valid_placement():
		deployment_confirmed.emit(current_cell, facing)
		deactivate()

## Cancel deployment
func _cancel_deployment() -> void:
	deployment_cancelled.emit()
	deactivate()

## Move cursor by a cell offset
func _move_cursor(offset: Vector3i) -> void:
	current_cell += offset
	_update_cursor_position()
	_update_cursor_visual()
	cursor_moved.emit(current_cell, facing, selected_definition)

## Activate the cursor with a unit definition
func activate(definition: UnitDefinition, p_camera: Camera3D) -> void:
	selected_definition = definition
	camera = p_camera
	is_active = true
	facing = GridService.Direction.SOUTH
	
	# Start at first deployable cell or center of map
	_find_starting_cell()
	
	show()
	set_process_input(true)
	_update_cursor_position()
	_update_cursor_visual()
	_update_direction_indicator()
	cursor_moved.emit(current_cell, facing, selected_definition)

## Find a good starting cell for the cursor
func _find_starting_cell() -> void:
	if MapManager.deployable_ground_cells.size() > 0:
		current_cell = MapManager.deployable_ground_cells[0]
	else:
		current_cell = Vector3i.ZERO

## Deactivate the cursor
func deactivate() -> void:
	selected_definition = null
	is_active = false
	hide()
	set_process_input(false)

## Update cursor position from mouse
func _update_cursor_from_mouse(mouse_pos: Vector2) -> void:
	if not camera:
		return
	
	# Raycast from camera to ground plane (Y = 1.0 for top of tiles)
	var from := camera.project_ray_origin(mouse_pos)
	var dir := camera.project_ray_normal(mouse_pos)
	
	# Intersect with Y = 1.0 plane (top of 1x1x1 tiles)
	if abs(dir.y) < 0.001:
		return
	
	var t := (1.0 - from.y) / dir.y
	if t < 0:
		return
	
	var hit_point := from + dir * t
	var new_cell := GridService.world_to_cell(hit_point)
	new_cell.y = 0  # Keep on ground level
	
	if new_cell != current_cell:
		current_cell = new_cell
		_update_cursor_position()
		_update_cursor_visual()
		cursor_moved.emit(current_cell, facing, selected_definition)

## Update cursor world position
func _update_cursor_position() -> void:
	var world_pos := GridService.cell_to_world(current_cell)
	# Offset Y to sit on top of tiles
	world_pos.y = CURSOR_Y_OFFSET
	global_position = world_pos

## Rotate facing direction
func _rotate_facing(direction: int) -> void:
	facing = (facing + direction) % 4
	if facing < 0:
		facing += 4
	_update_direction_indicator()
	cursor_rotated.emit(current_cell, facing, selected_definition)

## Update the direction indicator visual
func _update_direction_indicator() -> void:
	if direction_indicator:
		direction_indicator.rotation.y = GridService.direction_to_rotation(facing)

## Update cursor visual based on validity
func _update_cursor_visual() -> void:
	var is_valid := _is_valid_placement()
	
	if cursor_mesh and cursor_mesh.material_override:
		var mat := cursor_mesh.material_override as StandardMaterial3D
		if mat:
			mat.albedo_color = valid_color if is_valid else invalid_color

## Check if current placement is valid
func _is_valid_placement() -> bool:
	if not selected_definition:
		return false
	
	# Check if cell is valid for this unit type
	var is_valid_cell := false
	match selected_definition.deploy_type:
		UnitDefinition.DeployType.GROUND:
			is_valid_cell = MapManager.is_deployable_ground(current_cell)
		UnitDefinition.DeployType.HIGH:
			is_valid_cell = MapManager.is_deployable_high(current_cell)
		UnitDefinition.DeployType.ANY:
			is_valid_cell = MapManager.is_deployable_ground(current_cell) or MapManager.is_deployable_high(current_cell)
	
	if not is_valid_cell:
		return false
	
	# Check if cell is occupied
	if UnitRegistry.is_cell_blocked_for_deployment(current_cell):
		return false
	
	# Check if can afford
	if not GameFlowManager.can_afford(selected_definition.deploy_cost):
		return false
	
	return true

## Get current state for external queries
func get_current_cell() -> Vector3i:
	return current_cell

func get_facing() -> int:
	return facing

func get_selected_definition() -> UnitDefinition:
	return selected_definition
