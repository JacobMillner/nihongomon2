## UnitDefinition - Resource defining a unit's base stats and properties
@tool
class_name UnitDefinition
extends Resource

## Faction enum
enum Faction { PLAYER, ENEMY }

## Deployment tile type requirement
enum DeployType { GROUND, HIGH, ANY }

## Unit identification
@export var unit_name: String = "Unit"
@export var unit_id: String = "unit_base"
@export_multiline var description: String = ""

## Faction
@export var faction: Faction = Faction.PLAYER

## Base stats
@export_group("Stats")
@export var max_hp: int = 100
@export var attack: int = 10
@export var defense: int = 5
@export var attack_interval: float = 1.0  # Seconds between attacks

## Range and blocking
@export_group("Combat")
@export var attack_range: int = 1  # Grid cells
@export var block_count: int = 1  # How many enemies this unit can block (0 for ranged)
@export var is_ranged: bool = false

## Deployment
@export_group("Deployment")
@export var deploy_cost: int = 10  # DP cost
@export var deploy_type: DeployType = DeployType.GROUND
@export var redeploy_time: float = 70.0  # Seconds before redeployment

## Movement (for enemies)
@export_group("Movement")
@export var move_speed: float = 1.0  # Cells per second
@export var can_fly: bool = false
@export var is_unblockable: bool = false

## Visuals
@export_group("Visuals")
@export var model_scene: PackedScene
@export var icon: Texture2D
@export var color: Color = Color.WHITE

## Get the DP refund when retreating (typically 50%)
func get_retreat_refund() -> int:
	return int(deploy_cost * 0.5)
