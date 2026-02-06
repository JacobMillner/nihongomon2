## EnemyUnit - Enemy units that follow paths and attack player units
class_name EnemyUnit
extends Unit

## Path following
var path: Array[Vector3i] = []
var path_index: int = 0
var move_progress: float = 0.0

## Movement
var is_moving: bool = false
var current_target_cell: Vector3i = Vector3i.ZERO

## Blocking
var blocker: Unit = null

## Signal when enemy reaches exit
signal reached_exit

func _ready() -> void:
	super._ready()

func _process(delta: float) -> void:
	if current_state == State.DEAD:
		return
	
	match current_state:
		State.MOVING:
			_process_moving(delta)
		State.BLOCKED:
			_process_blocked(delta)
		State.ATTACKING:
			_process_attacking(delta)
		State.IDLE:
			# Start moving if we have a path
			if path.size() > 0:
				set_state(State.MOVING)

## Process movement along the path
func _process_moving(delta: float) -> void:
	if path_index >= path.size():
		# Reached the end
		_on_reached_exit()
		return
	
	# Check for blockers
	var potential_blocker := _check_for_blocker()
	if potential_blocker:
		_get_blocked(potential_blocker)
		return
	
	# Move towards next cell
	var target_cell := path[path_index]
	var target_world := GridService.cell_to_world(target_cell)
	var move_speed := definition.move_speed if definition else 1.0
	
	var direction := (target_world - global_position).normalized()
	var distance := global_position.distance_to(target_world)
	var move_amount := move_speed * delta
	
	if move_amount >= distance:
		# Reached the cell
		global_position = target_world
		set_grid_cell(target_cell, false)
		path_index += 1
		
		# Update facing direction for next cell
		if path_index < path.size():
			var next_cell := path[path_index]
			facing = GridService.get_direction_to(target_cell, next_cell)
			rotation.y = GridService.direction_to_rotation(facing)
	else:
		# Keep moving
		global_position += direction * move_amount

## Process blocked state (attack the blocker)
func _process_blocked(delta: float) -> void:
	if not blocker or not is_instance_valid(blocker) or blocker.current_state == State.DEAD:
		_get_unblocked()
		return
	
	# Attack the blocker
	target = blocker
	attack_timer -= delta
	if attack_timer <= 0:
		perform_attack()
		attack_timer = definition.attack_interval if definition else 1.0

## Check for blockers at current position
func _check_for_blocker() -> Unit:
	if definition and definition.is_unblockable:
		return null
	
	# Check current cell and nearby cells for blockers
	var potential_blocker := UnitRegistry.find_blocker_for_enemy(self, grid_cell)
	return potential_blocker

## Get blocked by a player unit
func _get_blocked(blocking_unit: Unit) -> void:
	blocker = blocking_unit
	UnitRegistry.block_enemy(blocker, self)
	set_state(State.BLOCKED)
	target = blocker

## Get unblocked
func _get_unblocked() -> void:
	if blocker:
		UnitRegistry.unblock_enemy(self)
	blocker = null
	target = null
	set_state(State.MOVING)

## Override target acquisition - prioritize blocker, then nearest player unit
func acquire_target() -> void:
	# If blocked, target the blocker
	if blocker and is_instance_valid(blocker):
		target = blocker
		return
	
	var attack_range := definition.attack_range if definition else 1
	var player_units := UnitRegistry.get_player_units_in_range(self, attack_range)
	
	if player_units.is_empty():
		target = null
		return
	
	# Pick the closest player unit
	var best_target: Unit = null
	var best_distance: int = 999
	
	for player_unit in player_units:
		if not is_instance_valid(player_unit) or player_unit.current_state == State.DEAD:
			continue
		
		var dist := GridService.grid_distance(grid_cell, player_unit.grid_cell)
		if dist < best_distance:
			best_distance = dist
			best_target = player_unit
	
	target = best_target

## Set the path for this enemy to follow
func set_path(new_path: Array[Vector3i]) -> void:
	path = new_path
	path_index = 0
	
	if path.size() > 0:
		set_grid_cell(path[0])
		if path.size() > 1:
			facing = GridService.get_direction_to(path[0], path[1])
			rotation.y = GridService.direction_to_rotation(facing)

## Get path progress (0.0 to 1.0)
func get_path_progress() -> float:
	if path.size() <= 1:
		return 0.0
	return float(path_index) / float(path.size() - 1)

## Called when enemy reaches the exit
func _on_reached_exit() -> void:
	reached_exit.emit()
	set_state(State.DEAD)
	queue_free()

## Override die to handle unblocking
func die() -> void:
	if blocker:
		UnitRegistry.unblock_enemy(self)
	super.die()
