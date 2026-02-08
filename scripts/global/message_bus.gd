extends Node

signal game_started
signal game_state_changed(new_state: int)
signal dp_changed(current: float, maximum: float)
signal life_changed(current: int, maximum: int)
signal game_won
signal game_lost
signal unit_deployed(unit: Node)
signal wave_started(wave_index: int)
signal wave_completed(wave_index: int)
signal all_waves_completed
signal enemy_reached_exit(enemy: Node)
signal enemy_spawned(enemy: Node)
signal enemy_died(enemy: Node)
