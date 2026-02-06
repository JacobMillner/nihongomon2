## WaveDefinition - Resource defining a single wave of enemies
@tool
class_name WaveDefinition
extends Resource

## Wave identification
@export var wave_name: String = "Wave 1"
@export var wave_number: int = 1

## Spawn groups in this wave
@export var spawn_groups: Array[SpawnGroup] = []

## Get total enemy count in this wave
func get_total_enemy_count() -> int:
	var total := 0
	for group in spawn_groups:
		total += group.count
	return total
