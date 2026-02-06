## PlayerUnit - Player-controlled units that are deployed on the grid
class_name PlayerUnit
extends Unit

## Retreat signal
signal retreated

func _ready() -> void:
	super._ready()

## Override target acquisition - prioritize enemies closest to exit
func acquire_target() -> void:
	var attack_range := definition.attack_range if definition else 1
	var enemies := UnitRegistry.get_enemies_in_range(self, attack_range)
	
	if enemies.is_empty():
		target = null
		return
	
	# Sort by progress along path (closest to exit first)
	# For now, just pick the first valid enemy
	var best_target: Unit = null
	var best_progress: float = -1.0
	
	for enemy in enemies:
		if not is_instance_valid(enemy) or enemy.current_state == State.DEAD:
			continue
		
		# If enemy has path progress, use that
		if enemy.has_method("get_path_progress"):
			var progress: float = enemy.get_path_progress()
			if progress > best_progress:
				best_progress = progress
				best_target = enemy
		else:
			# Fallback: just use first valid enemy
			if best_target == null:
				best_target = enemy
	
	target = best_target

## Retreat the unit (remove from battle, refund some DP)
func retreat() -> void:
	retreated.emit()
	UnitRegistry.unregister_unit(self)
	queue_free()

## Check if this unit can block enemies
func can_block() -> bool:
	if definition:
		return definition.block_count > 0
	return false

## Get the units this player unit is currently blocking
func get_blocked_enemies() -> Array:
	return UnitRegistry.get_blocked_enemies(self)
