## SpawnGroup - A group of enemies to spawn in a wave
@tool
class_name SpawnGroup
extends Resource

## The enemy definition to spawn
@export var enemy_definition: UnitDefinition

## Which spawn cell to use (index into MapManager.spawn_cells)
@export var spawn_cell_index: int = 0

## Number of enemies to spawn
@export var count: int = 1

## Time between spawns (seconds)
@export var interval: float = 2.0

## Start time offset from wave start (seconds)
@export var start_time: float = 0.0
