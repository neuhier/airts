# Spec: Issue #1 — Fog of War

## 1. Goal

Implement team-specific fog of war for the player and the enemy bot. Terrain
starts hidden, remains visible in gray once explored, and is fully shown only
inside the observing team's current vision. Opposing units and structures are
visible only in currently visible areas.

## 2. Requirements

### 2.1 Visibility model

- Visibility is calculated separately for `Unit.Team.PLAYER` and
  `Unit.Team.ENEMY`.
- Every alive friendly combat unit and each alive headquarters contributes a
  circular vision area for its own team.
- A world position is currently visible when it lies within the vision radius
  of at least one alive friendly vision source.
- Terrain starts unexplored for each team. Unexplored tiles use an opaque
  black overlay, concealing terrain, enemies, and structures.
- A tile becomes permanently explored when it enters friendly vision. It uses
  a gray overlay whenever it is explored but outside current friendly vision.
- Current-vision tiles have no fog overlay. Enemies that leave all friendly
  vision areas are hidden again, including on explored gray terrain.
- This issue intentionally has no terrain/elevation line-of-sight blocking.
  Mountain and obstacle effects on vision belong to issue #19.

### 2.2 Vision-radius configuration

- Add a `vision_radius` value to every entry in `data/balance_default.json`'s
  `units` section.
- The default radius for every currently defined unit class is `150.0` world
  units. Individual classes must be independently configurable through this
  JSON value.
- `BalanceManager` must expose the configured value using its existing
  balance-data access pattern, with `150.0` as the safe fallback for missing
  or invalid values.
- `Unit` stores a `vision_radius` property sourced from the balance data after
  its `unit_class_id` is known.
- Headquarters also reveal vision. Their radius is `225.0` world units
  (1.5 times the default unit radius) for this milestone.

### 2.3 Player presentation

- Enemy combat units and the enemy headquarters are hidden when outside the
  player team's current vision and shown immediately when they enter it.
- Unexplored terrain is opaque black; explored terrain outside current vision
  is gray.
- Player-owned units and the player headquarters remain visible at all times.
- The player HUD, selection indicators, and camera remain visible and usable
  everywhere.
- Hidden enemies must not be selectable or focus-fire targets through
  `TouchInputController`.
- Existing enemy units already carrying a manual target must safely abandon
  that target once it is no longer visible to their team.

### 2.4 Enemy-bot behavior

- The enemy bot may consider only player units and structures currently
  visible to `Unit.Team.ENEMY` when choosing targets, squads, or attacks.
- Hidden player units must not be selected as new bot targets.
- The bot may continue completing a previously issued movement order, but it
  must not receive the hidden target's current position as new information.
- The visibility service is the single source of truth for both rendering and
  bot perception; do not maintain a separate bot-only visibility rule.

## 3. Constraints

- Preserve the existing procedural map, `MapManager` pathfinding, economy,
  unit production, and selection/movement controls.
- Keep per-frame work bounded for the current small number of units. Avoid
  creating one node or shader pass per map tile.
- Use the existing `team_player` and `team_enemy` groups as the authoritative
  source of active units and headquarters.
- Dead or invalid nodes must contribute no vision and must never cause errors.
- Keep the implementation compatible with Godot 4.3 and
  `godot4 --headless --path . --import`.

## 4. Architecture

### 4.1 `FogOfWarManager`

Add a `FogOfWarManager` node under `Main` (or a dedicated autoload only if
the existing project architecture requires global access). It owns the
team-specific visibility query:

```gdscript
func is_position_visible_to(team: Unit.Team, world_position: Vector2) -> bool
```

The manager gathers alive nodes in the requesting team's group, reads each
source's `vision_radius`, and returns true when any source covers the queried
position. It stores explored tiles separately for each team and draws a player
fog overlay: black when unexplored and gray when explored but not visible.

### 4.2 Unit and headquarters integration

- Extend `Unit` with exported/default `vision_radius` state and balance-data
  lookup by `unit_class_id`.
- Give `Headquarters` a non-zero fixed vision radius of `225.0`.
- Enemy-node visual visibility is set from the player team's visibility query.
- A `Node2D` fog overlay draws above the map and world entities but below the
  HUD: black for unexplored tiles and gray for explored-but-unseen tiles.
- Visibility state must be safe during scene startup, death, and node removal.

### 4.3 Input and AI integration

- `TouchInputController._find_enemy_unit_at()` filters candidates through
  `FogOfWarManager.is_position_visible_to(Unit.Team.PLAYER, position)`.
- `EnemyAiController` filters player candidates through the equivalent enemy
  visibility query before making a decision.
- Unit auto-acquisition and a manually assigned target must validate current
  team visibility before continuing pursuit/attack.

## 5. Implementation Steps

1. Add configurable `vision_radius: 150.0` entries for melee, ranged, mobile,
   and healer units in the default balance JSON; add fallback balance lookup.
2. Add unit/HQ vision-radius properties and initialize them safely.
3. Create `FogOfWarManager`, add it to `main.tscn`, and implement team-aware
   current-visibility queries from alive team-group members.
4. Track explored tiles separately per team and render black unexplored tiles
   plus gray explored-but-unseen tiles for the player.
5. Update enemy rendering so player-visible enemy nodes appear and all other
   enemy nodes hide without revealing them through gray fog.
6. Gate player targeting, unit targeting, and enemy AI decisions through the
   shared manager.
7. Add headless verification for visibility boundaries, multiple sources,
   dead sources, hidden-target rejection, and bot perception; remove any
   temporary verification script before committing if project convention
   requires it.
8. Run import validation and playtest black unexplored terrain, gray explored
   terrain, player scouting, enemy disappearance,
   headquarters vision, and bot behavior.

## 6. Success Criteria

1. Each current unit class reads its independently configurable
   `vision_radius` from the balance JSON; missing values safely use `150.0`.
2. A player unit or player HQ reveals nearby enemy units and the enemy HQ;
   they hide again after leaving all player vision sources.
3. The same rules apply symmetrically to the enemy team for bot perception.
4. Every tile starts black, becomes fully visible while in current vision, and
   becomes gray after exploration when it leaves current vision.
5. Hidden enemies cannot be selected, focus-fired, auto-targeted, or newly
   targeted by the bot.
6. Multiple allied sources combine their vision correctly; removing or
   destroying one source immediately removes only its contribution.
7. The project imports without errors using
   `godot4 --headless --path . --import`.
8. A manual playtest confirms that scouting reveals enemies, retreating loses
   sight of them, and the enemy bot does not react to unseen player units.
