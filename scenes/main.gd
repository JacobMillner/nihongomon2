extends Node3D

## Main game controller script
## Ties together all the systems and handles player input

@onready var grid_map: GridMap = $GridMap
@onready var camera: Camera3D = $Camera3D

## Unit scenes
var player_unit_scene: PackedScene = preload("res://scenes/units/player_unit.tscn")
var enemy_unit_scene: PackedScene = preload("res://scenes/units/enemy_unit.tscn")
var deployment_cursor_scene: PackedScene = preload("res://scenes/ui/deployment_cursor.tscn")
var attack_range_display_scene: PackedScene = preload("res://scenes/ui/attack_range_display.tscn")

## Unit definitions (player roster)
var unit_roster: Array[UnitDefinition] = []
var basic_enemy_def: UnitDefinition

## Deployment cursor instance
var deployment_cursor: Node3D = null

## Attack range display instance
var attack_range_display: Node3D = null

## Currently selected unit for deployment
var selected_unit_index: int = -1

## Container nodes
var units_container: Node3D
var enemies_container: Node3D

## UI Label for debug info
var debug_label: Label

func _ready() -> void:
	# Create container nodes
	units_container = Node3D.new()
	units_container.name = "Units"
	add_child(units_container)
	
	enemies_container = Node3D.new()
	enemies_container.name = "Enemies"
	add_child(enemies_container)
	
	# Load unit definitions
	_load_unit_definitions()
	
	# Create attack range display
	attack_range_display = attack_range_display_scene.instantiate()
	add_child(attack_range_display)
	
	# Create deployment cursor
	deployment_cursor = deployment_cursor_scene.instantiate()
	add_child(deployment_cursor)
	deployment_cursor.deployment_confirmed.connect(_on_deployment_confirmed)
	deployment_cursor.deployment_cancelled.connect(_on_deployment_cancelled)
	deployment_cursor.cursor_moved.connect(_on_cursor_moved)
	deployment_cursor.cursor_rotated.connect(_on_cursor_rotated)
	
	# Create debug UI
	_create_debug_ui()
	
	# Initialize systems (wait a frame for autoloads)
	call_deferred("_initialize_systems")

func _initialize_systems() -> void:
	# Initialize MapManager
	MapManager.initialize(grid_map)
	
	# Initialize PathManager
	PathManager.initialize(MapManager)
	
	# Initialize GameFlowManager
	GameFlowManager.initialize(20.0, 3)  # 20 DP, 3 lives
	GameFlowManager.connect_wave_signals()
	GameFlowManager.state_changed.connect(_on_game_state_changed)
	GameFlowManager.dp_changed.connect(_on_dp_changed)
	GameFlowManager.life_changed.connect(_on_life_changed)
	GameFlowManager.game_won.connect(_on_game_won)
	GameFlowManager.game_lost.connect(_on_game_lost)
	
	# Create test wave
	var test_waves := _create_test_waves()
	WaveManager.initialize(test_waves, enemy_unit_scene, enemies_container)
	WaveManager.wave_started.connect(_on_wave_started)
	WaveManager.wave_completed.connect(_on_wave_completed)
	
	# Update initial UI
	_update_debug_ui()
	
	print("=== Tower Defense Prototype Ready ===")
	print("Controls:")
	print("  1, 2, 3 - Select unit to deploy")
	print("  WASD - Move cursor / Left Click - Move cursor")
	print("  Enter/Space/Left Click - Place unit")
	print("  Q / E - Rotate facing direction")
	print("  Escape/Right Click - Cancel deployment")
	print("  Tab - Start combat")

func _load_unit_definitions() -> void:
	# Load player units
	var vanguard := load("res://data/units/vanguard.tres") as UnitDefinition
	var defender := load("res://data/units/defender.tres") as UnitDefinition
	var sniper := load("res://data/units/sniper.tres") as UnitDefinition
	
	if vanguard:
		unit_roster.append(vanguard)
	if defender:
		unit_roster.append(defender)
	if sniper:
		unit_roster.append(sniper)
	
	# Load enemy
	basic_enemy_def = load("res://data/units/basic_enemy.tres") as UnitDefinition

func _create_test_waves() -> Array[WaveDefinition]:
	var waves: Array[WaveDefinition] = []
	
	# Wave 1 - 3 basic enemies
	var wave1 := WaveDefinition.new()
	wave1.wave_name = "Wave 1"
	wave1.wave_number = 1
	
	var group1 := SpawnGroup.new()
	group1.enemy_definition = basic_enemy_def
	group1.spawn_cell_index = 0
	group1.count = 3
	group1.interval = 3.0
	group1.start_time = 0.0
	wave1.spawn_groups.append(group1)
	waves.append(wave1)
	
	# Wave 2 - 5 basic enemies, faster spawn
	var wave2 := WaveDefinition.new()
	wave2.wave_name = "Wave 2"
	wave2.wave_number = 2
	
	var group2 := SpawnGroup.new()
	group2.enemy_definition = basic_enemy_def
	group2.spawn_cell_index = 0
	group2.count = 5
	group2.interval = 2.0
	group2.start_time = 0.0
	wave2.spawn_groups.append(group2)
	waves.append(wave2)
	
	# Wave 3 - 7 basic enemies
	var wave3 := WaveDefinition.new()
	wave3.wave_name = "Wave 3"
	wave3.wave_number = 3
	
	var group3 := SpawnGroup.new()
	group3.enemy_definition = basic_enemy_def
	group3.spawn_cell_index = 0
	group3.count = 7
	group3.interval = 1.5
	group3.start_time = 0.0
	wave3.spawn_groups.append(group3)
	waves.append(wave3)
	
	return waves

func _input(event: InputEvent) -> void:
	# Unit selection hotkeys
	if event.is_action_pressed("deploy_unit_1") and unit_roster.size() > 0:
		_select_unit_for_deployment(0)
	elif event.is_action_pressed("deploy_unit_2") and unit_roster.size() > 1:
		_select_unit_for_deployment(1)
	elif event.is_action_pressed("deploy_unit_3") and unit_roster.size() > 2:
		_select_unit_for_deployment(2)
	
	# Start combat
	if event.is_action_pressed("start_combat"):
		if GameFlowManager.current_state == GameFlowManager.GameState.SETUP:
			GameFlowManager.start_combat()

func _select_unit_for_deployment(index: int) -> void:
	if not GameFlowManager.can_deploy():
		return
	
	if index >= unit_roster.size():
		return
	
	selected_unit_index = index
	var definition := unit_roster[index]
	
	print("Selected: %s (Cost: %d DP, Range: %d)" % [definition.unit_name, definition.deploy_cost, definition.attack_range])
	deployment_cursor.activate(definition, camera)

func _on_deployment_confirmed(cell: Vector3i, facing: int) -> void:
	if selected_unit_index < 0 or selected_unit_index >= unit_roster.size():
		return
	
	var definition := unit_roster[selected_unit_index]
	var unit := GameFlowManager.deploy_unit(player_unit_scene, definition, cell, facing, units_container)
	
	if unit:
		print("Deployed %s at %s" % [definition.unit_name, cell])
	
	selected_unit_index = -1
	attack_range_display.hide_range()

func _on_deployment_cancelled() -> void:
	selected_unit_index = -1
	attack_range_display.hide_range()
	print("Deployment cancelled")

func _on_cursor_moved(cell: Vector3i, facing: int, definition: UnitDefinition) -> void:
	if definition:
		attack_range_display.show_range(cell, facing, definition)

func _on_cursor_rotated(cell: Vector3i, facing: int, definition: UnitDefinition) -> void:
	if definition:
		attack_range_display.show_range(cell, facing, definition)

func _create_debug_ui() -> void:
	var canvas := CanvasLayer.new()
	canvas.name = "DebugUI"
	add_child(canvas)
	
	debug_label = Label.new()
	debug_label.name = "DebugLabel"
	debug_label.position = Vector2(10, 10)
	debug_label.add_theme_font_size_override("font_size", 18)
	canvas.add_child(debug_label)

func _update_debug_ui() -> void:
	if not debug_label:
		return
	
	var state_name := "SETUP" if GameFlowManager.current_state == GameFlowManager.GameState.SETUP else (
		"COMBAT" if GameFlowManager.current_state == GameFlowManager.GameState.COMBAT else "RESULT"
	)
	
	var text := "=== Tower Defense ===\n"
	text += "State: %s\n" % state_name
	text += "DP: %d / %d\n" % [int(GameFlowManager.dp_current), int(GameFlowManager.dp_max)]
	text += "Lives: %d / %d\n" % [GameFlowManager.life_points, GameFlowManager.max_life_points]
	text += "\n"
	text += "Wave: %d / %d\n" % [WaveManager.get_current_wave_number(), WaveManager.get_total_wave_count()]
	text += "Enemies: %d alive\n" % WaveManager.living_enemies
	text += "\n"
	text += "--- Roster ---\n"
	for i in range(unit_roster.size()):
		var def := unit_roster[i]
		text += "[%d] %s (%d DP, Range: %d)\n" % [i + 1, def.unit_name, def.deploy_cost, def.attack_range]
	
	if GameFlowManager.current_state == GameFlowManager.GameState.SETUP:
		text += "\nPress TAB to start!"
	
	debug_label.text = text

func _process(_delta: float) -> void:
	_update_debug_ui()

func _on_game_state_changed(_new_state: int) -> void:
	_update_debug_ui()

func _on_dp_changed(_current: float, _maximum: float) -> void:
	_update_debug_ui()

func _on_life_changed(_current: int, _maximum: int) -> void:
	_update_debug_ui()

func _on_wave_started(wave_index: int) -> void:
	print("Wave %d started!" % (wave_index + 1))
	_update_debug_ui()

func _on_wave_completed(wave_index: int) -> void:
	print("Wave %d completed!" % (wave_index + 1))
	_update_debug_ui()
	
	# Auto-start next wave after delay
	if wave_index < WaveManager.get_total_wave_count() - 1:
		await get_tree().create_timer(2.0).timeout
		WaveManager.start_next_wave()

func _on_game_won() -> void:
	print("=== VICTORY! ===")
	_update_debug_ui()

func _on_game_lost() -> void:
	print("=== DEFEAT! ===")
	_update_debug_ui()
