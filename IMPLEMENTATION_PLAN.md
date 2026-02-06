# Grid-Based Tower Defense (Arknights-Like) — Implementation Plan
**Engine:** Godot 4  
**Core System:** 3D GridMap (grid is the source of truth)

---

## 1. Project Goal

Create an Arknights-like, grid-based tower defense game using Godot 4 where:

- Levels are authored by **painting tiles in a GridMap**
- Enemies follow predefined **lane paths** from spawn → exit
- Players deploy **units during a setup phase** onto fixed tiles
- Combat is **real-time and automatic**
- Enemies can be **blocked** and can **attack player units**
- All movement, ranges, and combat logic are measured in **GridMap units**

The game emphasizes positioning, lane control, blocking, range templates, and wave management—mirroring the core feel of *Arknights*.

---

## 2. Core Design Principles

### Grid Is Truth
- All gameplay logic uses `Vector3i` grid cells
- World coordinates are used **only** for visuals and animation
- Distance = GridMap units (not meters)

### Unified Unit System
- Player units and enemies share the same `Unit` base class
- Differences are driven by:
  - Faction (Player / Enemy)
  - Movement behavior
  - Deployment rules
  - Targeting priorities

### Arknights-Inspired Rules
- Units have facing direction, block count, attack ranges, and roles
- Enemies advance along lanes and stop when blocked
- Blocking is **intentional lane control**, not dynamic re-pathing
- Waves are scripted and predictable

---

## 3. Scene & System Overview

### Core Scenes
- `Main.tscn`  
  Entry point, loads level and UI

- `Level.tscn`  
  Contains:
  - `GridMap`
  - `MapManager`
  - `PathManager`

- `Unit.tscn`  
  Base unit scene (player + enemy)

- `PlayerUnit.tscn`  
  Inherits from `Unit`

- `EnemyUnit.tscn`  
  Inherits from `Unit`

- `DeploymentCursor.tscn`  
  Handles grid-based placement preview

---

## 4. Autoload / Manager Systems

### GridService
Utility singleton for grid math.

Responsibilities:
- Cell ↔ world conversions
- Grid distance calculations
- Neighbor queries

Key APIs:
- `cell_to_world(cell: Vector3i) -> Vector3`
- `world_to_cell(pos: Vector3) -> Vector3i`
- `grid_distance(a: Vector3i, b: Vector3i) -> int`
- `neighbors_4(cell: Vector3i) -> Array[Vector3i]`

---

### MapManager
Parses GridMap tiles at runtime.

Responsibilities:
- Scan GridMap on load
- Categorize cells by tile type

Tracked Sets:
- `walkable_cells`
- `deployable_ground_cells`
- `deployable_high_cells`
- `spawn_cells`
- `end_cells`
- `blocked_cells`

---

### PathManager
Handles enemy navigation.

Responsibilities:
- Build grid-based AStar graph from walkable cells
- Precompute paths from spawn → end
- Return paths as `Array[Vector3i]`

Key Rules:
- Enemies **do not reroute around blockers**
- Blocking is a gameplay mechanic

---

## 5. GridMap Tile Taxonomy

MeshLibrary item types (IDs or metadata):

| Tile Type | Purpose |
|----------|--------|
| PATH | Enemy walkable lane |
| SPAWN | Enemy entry |
| END | Enemy exit |
| DEPLOY_GROUND | Player ground unit placement |
| DEPLOY_HIGH | Player ranged/high-ground placement |
| BLOCKED | Walls / obstacles |

Everything is painted directly in the GridMap.

---

## 6. Unified Unit System

### Base `Unit` Class
Shared by enemies and player units.

Core Properties:
- `grid_cell: Vector3i`
- `facing: Direction (N/E/S/W)`
- `faction: Player | Enemy`
- `stats: UnitStats`
- `state: Idle | Moving | Attacking | Blocked | Dead`
- `target: Unit`

Core Methods:
- `set_grid_cell(cell)`
- `take_damage(amount, type)`
- `is_in_range(cell) -> bool`
- `acquire_target()`
- `perform_attack()`
- `die()`

---

### Player Units
- Stationary once deployed
- Have:
  - Deployment cost
  - Tile restrictions (ground / high)
  - Facing direction
  - Block count
- Automatically attack enemies in range

---

### Enemy Units
- Follow predefined grid paths
- Stop when blocked
- Attack blocking units
- Reach exit → damage player life

---

## 7. Grid-Based Blocking & Occupancy

### UnitRegistry / GridOccupancy
Central system tracking:

- Which units occupy which grid cells
- Player units vs enemies
- Blocking relationships

Blocking Rules:
- Player units have `block_count`
- Enemies become **blocked** when entering engagement range
- Blocked enemies stop moving and attack the blocker
- No dynamic path rerouting (Arknights-style)

---

## 8. Deployment Phase (Setup Phase)

### Flow
1. Game starts in `SETUP` phase
2. Player selects a unit
3. Deployment cursor snaps to grid
4. Validate placement:
   - Correct tile type
   - Cell unoccupied
   - Sufficient deployment points
5. Player chooses facing direction
6. Unit is placed and registered

### Deployment Points (DP)
- `dp_current`
- `dp_max`
- `dp_regen_rate`
- Units cost DP to deploy

---

## 9. Combat System (Grid-Based)

### Ranges
All attack ranges are measured in grid units.

Examples:
- Melee: range 1
- Ranged: range 3
- AoE: radius measured in grid cells

Distance Calculation:
- Manhattan distance (`abs(dx) + abs(dz)`)

### Targeting
- Player units prioritize enemies closest to exit
- Enemies prioritize blockers or nearest player unit

---

## 10. Wave System

### WaveDefinition (Resource / Data)
Each wave contains multiple spawn groups.

SpawnGroup:
- `spawn_cell`
- `enemy_type`
- `count`
- `interval`
- `start_time`

### WaveManager Responsibilities
- Control wave lifecycle
- Spawn enemies on schedule
- Track living enemies
- Signal wave completion

Wave ends when:
- All enemies are spawned
- All enemies are dead or exited

---

## 11. Game Flow State Machine

States:
- `SETUP`
- `COMBAT`
- `RESULT`

Rules:
- Deployment allowed only in SETUP (initial design)
- Combat runs automatically
- Loss when life points reach zero

---

## 12. Unit Definitions

Use `UnitDefinition` Resources:
- Cost
- HP / ATK / DEF
- Attack range
- Block count
- Deployment tile type
- Targeting rules

Example Archetypes:
- Vanguard (cheap, blocks 2)
- Defender (high HP, blocks 3)
- Sniper (high tile, ranged)
- Basic melee enemy
- Ranged enemy

---

## 13. Implementation Order (Milestones)

1. GridMap parsing (MapManager)
2. Grid utilities (GridService)
3. Pathfinding (PathManager)
4. Unit base + registry
5. Enemy path movement
6. Deployment system
7. Blocking logic
8. Combat + targeting
9. Wave system
10. Win/Lose flow
11. Arknights polish (range templates, elevation, skills)

---

## 14. Cursor Task List

Generate:
1. `GridService.gd`
2. `MapManager.gd`
3. `PathManager.gd`
4. `UnitDefinition.gd`
5. `Unit.gd`
6. `PlayerUnit.gd`
7. `EnemyUnit.gd`
8. `UnitRegistry.gd`
9. `WaveDefinition.gd`
10. `WaveManager.gd`
11. `GameFlowManager.gd`

---

## 15. Future Extensions
- Skills (manual / auto trigger)
- Elevation-based range rules
- Special enemies (fliers, unblockable)
- Tile effects (slow, damage, buffs)
- Multiple exits and split lanes

---

**This document is the authoritative design spec for implementation.**
