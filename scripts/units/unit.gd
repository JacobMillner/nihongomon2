## Unit - Base class for all units (player and enemy)
class_name Unit
extends Node3D

## Unit state enum
enum State { IDLE, MOVING, ATTACKING, BLOCKED, DEAD }

## Faction enum (matches UnitDefinition)
enum Faction { PLAYER, ENEMY }

## Unit definition resource
@export var definition: UnitDefinition

## Current grid position
var grid_cell: Vector3i = Vector3i.ZERO

## Facing direction
var facing: int = GridService.Direction.SOUTH

## Current state
var current_state: State = State.IDLE

## Current stats (modified from base)
var current_hp: int = 100
var current_attack: int = 10
var current_defense: int = 5

## Combat
var target: Unit = null
var attack_timer: float = 0.0

## Visual components
@onready var model_container: Node3D = $ModelContainer
@onready var health_bar: Node3D = $HealthBar if has_node("HealthBar") else null

## Signals
signal hp_changed(current: int, maximum: int)
signal state_changed(new_state: State)
signal died
signal attacked(target: Unit, damage: int)

func _ready() -> void:
	if definition:
		_apply_definition()
	
	# Register with UnitRegistry
	if Engine.has_singleton("UnitRegistry") or has_node("/root/UnitRegistry"):
		UnitRegistry.register_unit(self)

func _exit_tree() -> void:
	if Engine.has_singleton("UnitRegistry") or has_node("/root/UnitRegistry"):
		UnitRegistry.unregister_unit(self)

func _process(delta: float) -> void:
	if current_state == State.DEAD:
		return
	
	match current_state:
		State.IDLE:
			_process_idle(delta)
		State.ATTACKING:
			_process_attacking(delta)

## Apply definition stats to current stats
func _apply_definition() -> void:
	current_hp = definition.max_hp
	current_attack = definition.attack
	current_defense = definition.defense
	
	# Load model if specified
	if definition.model_scene and model_container:
		var model_instance = definition.model_scene.instantiate()
		model_container.add_child(model_instance)
	
	hp_changed.emit(current_hp, definition.max_hp)

## Process idle state (look for targets)
func _process_idle(delta: float) -> void:
	acquire_target()
	if target and is_instance_valid(target):
		set_state(State.ATTACKING)

## Process attacking state
func _process_attacking(delta: float) -> void:
	if not target or not is_instance_valid(target) or target.current_state == State.DEAD:
		target = null
		set_state(State.IDLE)
		return
	
	# Check if still in range
	if not is_in_range(target.grid_cell):
		target = null
		set_state(State.IDLE)
		return
	
	# Attack timer
	attack_timer -= delta
	if attack_timer <= 0:
		perform_attack()
		attack_timer = definition.attack_interval if definition else 1.0

## Set the unit's grid cell and update world position
func set_grid_cell(cell: Vector3i, update_visual: bool = true) -> void:
	var old_cell := grid_cell
	grid_cell = cell
	
	if update_visual:
		global_position = GridService.cell_to_world(cell)
	
	# Update registry
	if old_cell != cell:
		UnitRegistry.update_unit_cell(self, old_cell, cell)

## Get the current grid cell
func get_grid_cell() -> Vector3i:
	return grid_cell

## Get faction from definition
func get_faction() -> int:
	if definition:
		return definition.faction
	return Faction.PLAYER

## Get block count from definition
func get_block_count() -> int:
	if definition:
		return definition.block_count
	return 0

## Set facing direction
func set_facing(dir: int) -> void:
	facing = dir
	rotation.y = GridService.direction_to_rotation(dir)

## Set state
func set_state(new_state: State) -> void:
	if current_state == new_state:
		return
	current_state = new_state
	state_changed.emit(new_state)

## Check if a cell is within attack range
func is_in_range(cell: Vector3i) -> bool:
	var attack_range := definition.attack_range if definition else 1
	return GridService.is_in_range(grid_cell, cell, attack_range)

## Acquire a target (override in subclasses)
func acquire_target() -> void:
	pass  # Implemented in PlayerUnit and EnemyUnit

## Perform an attack on the current target
func perform_attack() -> void:
	if not target or not is_instance_valid(target):
		return
	
	var damage := calculate_damage(target)
	target.take_damage(damage, self)
	attacked.emit(target, damage)

## Calculate damage against a target
func calculate_damage(target_unit: Unit) -> int:
	var base_damage := current_attack
	var target_def := target_unit.current_defense
	# Simple damage formula: ATK - DEF (minimum 1)
	return maxi(base_damage - target_def, 1)

## Take damage from an attacker
func take_damage(amount: int, attacker: Unit = null) -> void:
	if current_state == State.DEAD:
		return
	
	current_hp -= amount
	hp_changed.emit(current_hp, definition.max_hp if definition else 100)
	
	if current_hp <= 0:
		die()

## Die
func die() -> void:
	set_state(State.DEAD)
	died.emit()
	
	# Cleanup after a short delay for death animation
	var tween := create_tween()
	tween.tween_property(self, "scale", Vector3.ZERO, 0.3)
	tween.tween_callback(queue_free)

## Initialize the unit at a cell with a definition
func initialize(cell: Vector3i, unit_def: UnitDefinition, face_dir: int = GridService.Direction.SOUTH) -> void:
	definition = unit_def
	_apply_definition()
	set_grid_cell(cell)
	set_facing(face_dir)
	set_state(State.IDLE)
