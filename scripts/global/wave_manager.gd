## WaveManager - Controls wave lifecycle, spawns enemies on schedule
extends Node

## Wave definitions for the current level
var wave_definitions: Array[WaveDefinition] = []

## Current state
var current_wave_index: int = -1
var is_wave_active: bool = false
var wave_timer: float = 0.0

## Active spawn trackers
var active_spawners: Array[SpawnTracker] = []

## Living enemies count
var living_enemies: int = 0
var total_enemies_spawned: int = 0
var total_enemies_in_wave: int = 0

## Enemy scene to instantiate
var enemy_scene: PackedScene

## Parent node for spawned enemies
var enemy_container: Node

## Signals
signal wave_started(wave_index: int)
signal wave_completed(wave_index: int)
signal all_waves_completed
signal enemy_spawned(enemy: Node)
signal enemy_died(enemy: Node)
signal enemy_reached_exit(enemy: Node)

## Spawn tracker helper class
class SpawnTracker:
	var spawn_group: SpawnGroup
	var spawn_cell: Vector3i
	var enemies_spawned: int = 0
	var spawn_timer: float = 0.0
	var started: bool = false
	var completed: bool = false

func _ready() -> void:
	pass

func _process(delta: float) -> void:
	if not is_wave_active:
		return
	
	wave_timer += delta
	_process_spawners(delta)
	
	# Check wave completion
	if _is_wave_complete():
		_complete_wave()

## Initialize wave manager with wave data
func initialize(waves: Array[WaveDefinition], p_enemy_scene: PackedScene, p_container: Node) -> void:
	wave_definitions = waves
	enemy_scene = p_enemy_scene
	enemy_container = p_container
	current_wave_index = -1

## Start the next wave
func start_next_wave() -> void:
	current_wave_index += 1
	if current_wave_index >= wave_definitions.size():
		all_waves_completed.emit()
		return
	
	_start_wave(current_wave_index)

## Start a specific wave
func _start_wave(wave_index: int) -> void:
	var wave_def := wave_definitions[wave_index]
	
	# Reset wave state
	wave_timer = 0.0
	living_enemies = 0
	total_enemies_spawned = 0
	total_enemies_in_wave = wave_def.get_total_enemy_count()
	active_spawners.clear()
	
	# Create spawn trackers for each group
	for group in wave_def.spawn_groups:
		var tracker := SpawnTracker.new()
		tracker.spawn_group = group
		
		# Get spawn cell from MapManager
		if group.spawn_cell_index < MapManager.spawn_cells.size():
			tracker.spawn_cell = MapManager.spawn_cells[group.spawn_cell_index]
		elif MapManager.spawn_cells.size() > 0:
			tracker.spawn_cell = MapManager.spawn_cells[0]
		else:
			push_error("WaveManager: No spawn cells available!")
			continue
		
		active_spawners.append(tracker)
	
	is_wave_active = true
	wave_started.emit(wave_index)
	print("WaveManager: Started wave %d with %d enemies" % [wave_index + 1, total_enemies_in_wave])

## Process all active spawners
func _process_spawners(delta: float) -> void:
	for tracker in active_spawners:
		if tracker.completed:
			continue
		
		var group := tracker.spawn_group
		
		# Check if spawn should start
		if not tracker.started:
			if wave_timer >= group.start_time:
				tracker.started = true
				tracker.spawn_timer = 0.0
				_spawn_enemy(tracker)
			continue
		
		# Spawn timer
		tracker.spawn_timer += delta
		if tracker.spawn_timer >= group.interval and tracker.enemies_spawned < group.count:
			tracker.spawn_timer = 0.0
			_spawn_enemy(tracker)

## Spawn a single enemy from a tracker
func _spawn_enemy(tracker: SpawnTracker) -> void:
	if not enemy_scene or not enemy_container:
		push_error("WaveManager: Enemy scene or container not set")
		return
	
	var enemy: EnemyUnit = enemy_scene.instantiate() as EnemyUnit
	if not enemy:
		push_error("WaveManager: Failed to instantiate enemy")
		return
	
	enemy_container.add_child(enemy)
	
	# Initialize the enemy
	var enemy_def := tracker.spawn_group.enemy_definition
	enemy.initialize(tracker.spawn_cell, enemy_def)
	
	# Set path
	var path := PathManager.get_enemy_path(tracker.spawn_cell)
	enemy.set_path(path)
	
	# Connect signals
	enemy.died.connect(_on_enemy_died.bind(enemy))
	enemy.reached_exit.connect(_on_enemy_reached_exit.bind(enemy))
	
	# Start moving
	enemy.set_state(Unit.State.MOVING)
	
	tracker.enemies_spawned += 1
	total_enemies_spawned += 1
	living_enemies += 1
	
	if tracker.enemies_spawned >= tracker.spawn_group.count:
		tracker.completed = true
	
	enemy_spawned.emit(enemy)

## Check if current wave is complete
func _is_wave_complete() -> bool:
	# All enemies spawned and all dead
	if total_enemies_spawned >= total_enemies_in_wave and living_enemies <= 0:
		return true
	return false

## Complete the current wave
func _complete_wave() -> void:
	is_wave_active = false
	wave_completed.emit(current_wave_index)
	print("WaveManager: Wave %d completed!" % (current_wave_index + 1))

## Handle enemy death
func _on_enemy_died(enemy: Node) -> void:
	living_enemies -= 1
	enemy_died.emit(enemy)

## Handle enemy reaching exit
func _on_enemy_reached_exit(enemy: Node) -> void:
	living_enemies -= 1
	enemy_reached_exit.emit(enemy)

## Get current wave number (1-indexed for display)
func get_current_wave_number() -> int:
	return current_wave_index + 1

## Get total wave count
func get_total_wave_count() -> int:
	return wave_definitions.size()

## Check if all waves are complete
func is_all_waves_complete() -> bool:
	return current_wave_index >= wave_definitions.size() - 1 and not is_wave_active
