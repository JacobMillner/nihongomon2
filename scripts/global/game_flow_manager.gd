## GameFlowManager - Controls game state and flow (Setup → Combat → Result)
extends Node

## Game states
enum GameState { SETUP, COMBAT, RESULT }

## Current state
var current_state: GameState = GameState.SETUP

## Deployment Points
var dp_current: float = 10.0
var dp_max: float = 99.0
var dp_regen_rate: float = 1.0  # DP per second

## Player life
var life_points: int = 3
var max_life_points: int = 3

## Result
var is_victory: bool = false

## Signals
signal state_changed(new_state: GameState)
signal dp_changed(current: float, maximum: float)
signal life_changed(current: int, maximum: int)
signal game_won
signal game_lost
signal unit_deployed(unit: Node)

func _ready() -> void:
	pass

func _process(delta: float) -> void:
	# Regenerate DP during combat
	if current_state == GameState.COMBAT:
		_regen_dp(delta)

## Initialize the game flow manager
func initialize(starting_dp: float = 10.0, starting_life: int = 3) -> void:
	dp_current = starting_dp
	life_points = starting_life
	max_life_points = starting_life
	current_state = GameState.SETUP
	is_victory = false
	
	dp_changed.emit(dp_current, dp_max)
	life_changed.emit(life_points, max_life_points)
	state_changed.emit(current_state)

## Change game state
func set_game_state(new_state: GameState) -> void:
	if current_state == new_state:
		return
	
	current_state = new_state
	state_changed.emit(new_state)
	print("GameFlowManager: State changed to %s" % GameState.keys()[new_state])

## Start combat phase
func start_combat() -> void:
	set_game_state(GameState.COMBAT)
	WaveManager.start_next_wave()

## Regenerate DP over time
func _regen_dp(delta: float) -> void:
	var old_dp := dp_current
	dp_current = minf(dp_current + dp_regen_rate * delta, dp_max)
	if int(dp_current) != int(old_dp):
		dp_changed.emit(dp_current, dp_max)

## Spend DP
func spend_dp(amount: int) -> bool:
	if dp_current >= amount:
		dp_current -= amount
		dp_changed.emit(dp_current, dp_max)
		return true
	return false

## Add DP (from retreating, etc.)
func add_dp(amount: int) -> void:
	dp_current = minf(dp_current + amount, dp_max)
	dp_changed.emit(dp_current, dp_max)

## Check if can afford
func can_afford(cost: int) -> bool:
	return dp_current >= cost

## Take life damage (enemy reached exit)
func take_life_damage(amount: int = 1) -> void:
	life_points -= amount
	life_changed.emit(life_points, max_life_points)
	
	if life_points <= 0:
		_on_defeat()

## Handle defeat
func _on_defeat() -> void:
	is_victory = false
	set_game_state(GameState.RESULT)
	game_lost.emit()
	print("GameFlowManager: DEFEAT!")

## Handle victory
func _on_victory() -> void:
	is_victory = true
	set_game_state(GameState.RESULT)
	game_won.emit()
	print("GameFlowManager: VICTORY!")

## Check if deployment is allowed
func can_deploy() -> bool:
	# In this prototype, allow deployment during both setup and combat
	return current_state != GameState.RESULT

## Deploy a unit at a cell
func deploy_unit(unit_scene: PackedScene, definition: UnitDefinition, cell: Vector3i, facing: int, container: Node) -> Node:
	if not can_deploy():
		return null
	
	# Check DP cost
	if not can_afford(definition.deploy_cost):
		print("GameFlowManager: Not enough DP!")
		return null
	
	# Check if cell is valid for deployment
	if not _is_valid_deployment_cell(cell, definition):
		print("GameFlowManager: Invalid deployment cell!")
		return null
	
	# Check if cell is occupied
	if UnitRegistry.is_cell_blocked_for_deployment(cell):
		print("GameFlowManager: Cell is occupied!")
		return null
	
	# Spend DP
	spend_dp(definition.deploy_cost)
	
	# Create unit
	var unit: PlayerUnit = unit_scene.instantiate() as PlayerUnit
	container.add_child(unit)
	unit.initialize(cell, definition, facing)
	
	# Connect retreat signal
	unit.retreated.connect(_on_unit_retreated.bind(unit, definition))
	
	unit_deployed.emit(unit)
	return unit

## Check if a cell is valid for deploying a specific unit type
func _is_valid_deployment_cell(cell: Vector3i, definition: UnitDefinition) -> bool:
	match definition.deploy_type:
		UnitDefinition.DeployType.GROUND:
			return MapManager.is_deployable_ground(cell)
		UnitDefinition.DeployType.HIGH:
			return MapManager.is_deployable_high(cell)
		UnitDefinition.DeployType.ANY:
			return MapManager.is_deployable_ground(cell) or MapManager.is_deployable_high(cell)
	return false

## Handle unit retreat
func _on_unit_retreated(unit: Node, definition: UnitDefinition) -> void:
	add_dp(definition.get_retreat_refund())

## Connect to WaveManager signals
func connect_wave_signals() -> void:
	WaveManager.enemy_reached_exit.connect(_on_enemy_reached_exit)
	WaveManager.all_waves_completed.connect(_on_all_waves_completed)

## Handle enemy reaching exit
func _on_enemy_reached_exit(enemy: Node) -> void:
	take_life_damage(1)

## Handle all waves completed
func _on_all_waves_completed() -> void:
	if life_points > 0:
		_on_victory()
