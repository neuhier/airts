extends CharacterBody2D
class_name Unit
## Base class for all combat units (melee, ranged, mobile) across all races.
##
## Handles the shared unit loop: move toward a commanded point, auto-acquire
## the nearest enemy inside attack range, and auto-attack on a cooldown.
## Race-specific subclasses only need to override the exported stats and,
## later, hook into `_on_died` / `_on_took_damage` for special abilities
## (healing, recycling, brood-spawning, etc.).

enum Team { PLAYER, ENEMY }

## Single source of truth for each team's color, applied to every unit's
## and HQ's `Silhouette` node (see `_ready()`) and reused at reduced alpha
## by `TerritoryVisualizer` for the resource-area polygons, so a team's
## color is consistent everywhere it appears.
const TEAM_COLORS := {
	Team.PLAYER: Color(0.15, 0.45, 0.95, 1.0),
	Team.ENEMY: Color(0.9, 0.15, 0.15, 1.0),
}

@export var team: Team = Team.PLAYER
@export var max_hp: float = 100.0
@export var damage: float = 10.0
@export var attack_range: float = 48.0
@export var attack_cooldown: float = 1.0
@export var move_speed: float = 150.0
## Flat damage reduction applied to every incoming hit (see `take_damage()`).
## Sourced from `BalanceManager` per unit_class_id in `_ready()`, same as
## move_speed/max_hp/damage — this `@export` value is only the design-time
## default/fallback.
@export var armor: float = 0.0
## Distance to the move target below which the unit is considered "arrived".
@export var arrival_threshold: float = 4.0
## Radius within which an idle unit (no manual command in progress)
## automatically notices and pursues the nearest enemy, even if that enemy
## is currently outside `attack_range`. Independent of `attack_range` so
## units can "aggro" from further away than they can actually hit.
@export var aggro_range: float = 200.0
## Circular world-space area this unit reveals for its team. Combat units
## load this from BalanceManager by unit_class_id; HQs use their own fixed value.
@export var vision_radius: float = 150.0

## Identifies this unit's class for the Upgrade-Labor system (e.g. "melee",
## "ranged", "mobile", "healer"). Set by subclasses in `_ready()` before
## calling `super._ready()`. Empty string = not upgradeable (e.g. HQ).
var unit_class_id: String = ""

var hp: float
var move_target: Vector2

## Design-time base stats, captured before any upgrade multiplier is
## applied. `UpgradeManager` multipliers are always relative to these, so
## repeated re-application (retroactive upgrades) never compounds.
var _base_damage: float
var _base_max_hp: float
var _base_move_speed: float

## Current pathfound waypoints (world-space) toward whatever destination
## `_move_towards()` was last called with. Recomputed whenever the
## destination changes or the next waypoint is reached, so units route
## around OBSTACLE cells and prefer GROUND over MOUNTAIN instead of
## walking in a straight line through terrain.
var _path: PackedVector2Array = PackedVector2Array()
var _path_destination: Vector2 = Vector2.ZERO

var _attack_timer: float = 0.0
var _current_target: Unit = null
## True from `set_move_target()` until the unit arrives at `move_target`.
## Overrides auto-target acquisition so a fresh move order isn't immediately
## re-locked into attacking whatever enemy happens to still be in range.
var _commanded_move: bool = false
## Manually-assigned focus-fire target (via `attack_target()`). Overrides
## automatic nearest-target acquisition until it dies/becomes invalid or a
## new command (`set_move_target` / `attack_target`) replaces it.
var manual_target: Unit = null

signal died(unit: Unit)
signal hp_changed(unit: Unit, hp: float, max_hp: float)

@onready var _hp_bar: ProgressBar = get_node_or_null("HPBar")
@onready var _selection_ring: Node2D = get_node_or_null("SelectionRing")
@onready var _silhouette: Polygon2D = get_node_or_null("Silhouette")


func _ready() -> void:
	if _silhouette:
		_silhouette.color = TEAM_COLORS[team]

	# Balance-sourced stats: overwrites the @export design-time defaults
	# with BalanceManager's data before _base_* is captured below, so both
	# UpgradeManager's multipliers and the terrain speed/range modifiers
	# end up relative to the balance-driven baseline rather than the old
	# hardcoded one. Each @export value is passed through as that lookup's
	# own fallback, so a missing/partial balance file degrades gracefully
	# instead of zeroing out a stat.
	if unit_class_id != "":
		move_speed = BalanceManager.get_unit_value(unit_class_id, "move_speed", move_speed) as float
		max_hp = BalanceManager.get_unit_value(unit_class_id, "max_hp", max_hp) as float
		damage = BalanceManager.get_unit_value(unit_class_id, "damage", damage) as float
		armor = BalanceManager.get_unit_value(unit_class_id, "armor", armor) as float
		vision_radius = BalanceManager.get_unit_value(unit_class_id, "vision_radius", vision_radius) as float

	_base_damage = damage
	_base_max_hp = max_hp
	_base_move_speed = move_speed
	_base_attack_range = attack_range

	# Newly-produced units start with whatever multipliers have already
	# been researched for their team/class (baseline application, see
	# spec 4: "als Basiswert auf alle zukünftig produzierten Einheiten").
	if unit_class_id != "":
		damage = _base_damage * UpgradeManager.get_multiplier(team, unit_class_id, UpgradeManager.StatType.DAMAGE)
		max_hp = _base_max_hp * UpgradeManager.get_multiplier(team, unit_class_id, UpgradeManager.StatType.HP)
		move_speed = _base_move_speed * UpgradeManager.get_multiplier(team, unit_class_id, UpgradeManager.StatType.SPEED)

	hp = max_hp
	move_target = global_position
	add_to_group(_team_group())
	_update_hp_bar()


## Mountain terrain modifiers, applied/removed live as a unit crosses tile
## boundaries (see `_apply_terrain_modifiers()`), always relative to the
## unit's current design-time base stats — so they compose correctly with
## `UpgradeManager` multipliers instead of overwriting them.
const _MOUNTAIN_SPEED_MULTIPLIER := 0.6
const _MOUNTAIN_ATTACK_RANGE_BONUS := 150.0

var _base_attack_range: float
var _on_mountain: bool = false


func _physics_process(delta: float) -> void:
	_apply_terrain_modifiers()

	if manual_target and (not is_instance_valid(manual_target) or not manual_target.is_alive() or not _is_target_visible(manual_target)):
		manual_target = null

	if manual_target:
		_current_target = manual_target
		var dist := global_position.distance_to(manual_target.global_position)
		if dist <= attack_range:
			velocity = Vector2.ZERO
			_try_attack(delta)
		else:
			_move_towards(manual_target.global_position)
	elif _commanded_move:
		# A fresh move order always takes priority over auto-attack, even
		# if an enemy is already sitting inside attack_range — otherwise
		# the unit would instantly re-lock onto it and never move.
		_current_target = null
		_move_towards_target()
		if global_position.distance_to(move_target) <= arrival_threshold:
			_commanded_move = false
	else:
		_current_target = _find_target_in_range()
		if _current_target:
			velocity = Vector2.ZERO
			_try_attack(delta)
		else:
			# Nothing in attack range — check for a nearby enemy to
			# automatically aggro and chase, otherwise idle at move_target.
			var aggro_target := _find_nearest_enemy_in_range(aggro_range)
			if aggro_target:
				_current_target = aggro_target
				_move_towards(aggro_target.global_position)
			else:
				_move_towards_target()
	move_and_slide()


## Called by the input layer (touch controller) to command this unit to a
## new world position. Cancels the current attack lock so the unit starts
## moving immediately. Also cancels any manual focus-fire target — a fresh
## move command always takes priority.
## True while the unit has no player/AI-issued command in progress (no
## active move order, no manual attack-target). Used by `EnemyAiController`
## to find units it's free to group into an assault squad — a unit that's
## mid-command or auto-chasing an aggro target isn't "idle" even though
## nothing set an explicit state machine field for it.
func is_idle() -> bool:
	return not _commanded_move and manual_target == null


func set_move_target(world_position: Vector2) -> void:
	move_target = world_position
	manual_target = null
	_commanded_move = true
	_current_target = null
	_attack_timer = 0.0


## Called by the input layer to focus-fire a specific enemy unit (or HQ),
## overriding automatic nearest-target acquisition. The unit walks to the
## target and attacks it exclusively until it dies or a new command
## (`set_move_target` / `attack_target`) replaces this order.
func attack_target(target_unit: Unit) -> void:
	manual_target = target_unit


## Toggles the optional `SelectionRing` child node. Purely visual — has no
## gameplay effect. Units without a `SelectionRing` node (e.g. `Headquarters`)
## silently no-op.
func set_selected(is_selected: bool) -> void:
	if _selection_ring:
		_selection_ring.visible = is_selected


## Called by `UpgradeManager` when a research order for this unit's
## class/team completes, applying the (already-cumulative) multiplier
## retroactively to this specific alive instance. Multipliers are always
## relative to the unit's original design-time base stat, so calling this
## multiple times with different multipliers never compounds incorrectly.
## HP is scaled proportionally on both `max_hp` and current `hp` so a
## damaged unit keeps the same HP percentage after the upgrade.
func apply_stat_multiplier(stat: UpgradeManager.StatType, multiplier: float) -> void:
	match stat:
		UpgradeManager.StatType.DAMAGE:
			damage = _base_damage * multiplier
		UpgradeManager.StatType.HP:
			var hp_fraction := hp / max_hp if max_hp > 0.0 else 1.0
			max_hp = _base_max_hp * multiplier
			hp = max_hp * hp_fraction
			hp_changed.emit(self, hp, max_hp)
			_update_hp_bar()
		UpgradeManager.StatType.SPEED:
			move_speed = _base_move_speed * multiplier


func take_damage(amount: float) -> void:
	if not is_alive():
		return
	var mitigated: float = max(amount - armor, 0.0)
	hp = max(hp - mitigated, 0.0)
	hp_changed.emit(self, hp, max_hp)
	_update_hp_bar()
	if hp <= 0.0:
		_die()


func is_alive() -> bool:
	return hp > 0.0


func _team_group() -> String:
	return "team_player" if team == Team.PLAYER else "team_enemy"


func _enemy_group() -> String:
	return "team_enemy" if team == Team.PLAYER else "team_player"


## Nearest living enemy within attack_range, or null if none is in reach.
func _find_target_in_range() -> Unit:
	return _find_nearest_enemy_in_range(attack_range)


## Nearest living enemy within `radius`, or null if none is that close.
## Shared by both auto-attack (`attack_range`) and auto-aggro
## (`aggro_range`) since they're the same "closest enemy within X" query.
func _find_nearest_enemy_in_range(radius: float) -> Unit:
	var nearest: Unit = null
	var nearest_dist := INF
	for node in get_tree().get_nodes_in_group(_enemy_group()):
		if node is Unit and node != self and node.is_alive() and _is_target_visible(node):
			var dist := global_position.distance_to(node.global_position)
			if dist <= radius and dist < nearest_dist:
				nearest = node
				nearest_dist = dist
	return nearest


## Combat decisions obey the same team-specific visibility rules used by the
## player presentation and enemy bot. Missing manager is treated as visible so
## isolated/headless unit tests remain safe before Main has initialized.
func _is_target_visible(target: Unit) -> bool:
	var fog := get_tree().get_first_node_in_group(FogOfWarManager.GROUP_NAME) as FogOfWarManager
	return fog == null or fog.is_position_visible_to(team, target.global_position)


func _try_attack(delta: float) -> void:
	_attack_timer -= delta
	if _attack_timer <= 0.0:
		_attack_timer = attack_cooldown
		_current_target.take_damage(damage)


## Checks the terrain tile the unit currently stands on and toggles the
## mountain speed penalty / range bonus accordingly. Cheap no-op when
## nothing changed (`_on_mountain` only flips at tile-boundary crossings).
func _apply_terrain_modifiers() -> void:
	var is_mountain := MapManager.get_terrain_at(global_position) == MapManager.TerrainType.MOUNTAIN
	if is_mountain == _on_mountain:
		return
	_on_mountain = is_mountain
	if is_mountain:
		move_speed = _base_move_speed * _MOUNTAIN_SPEED_MULTIPLIER
		attack_range = _base_attack_range + _MOUNTAIN_ATTACK_RANGE_BONUS
	else:
		move_speed = _base_move_speed
		attack_range = _base_attack_range


func _move_towards_target() -> void:
	_move_towards(move_target)


func _move_towards(destination: Vector2) -> void:
	if destination.distance_to(_path_destination) > arrival_threshold or _path.is_empty():
		_path = MapManager.find_path(global_position, destination)
		_path_destination = destination

	# Drop waypoints the unit has already reached (including a stale first
	# waypoint at/near its own current position).
	while _path.size() > 0 and global_position.distance_to(_path[0]) <= arrival_threshold:
		_path.remove_at(0)

	if _path.is_empty():
		velocity = Vector2.ZERO
		return

	var to_waypoint := _path[0] - global_position
	if to_waypoint.length() <= arrival_threshold and _path.size() == 1 and destination.distance_to(_path_destination) <= arrival_threshold:
		# Final waypoint reached and it matches the commanded destination.
		velocity = Vector2.ZERO
		return
	velocity = to_waypoint.normalized() * move_speed


func _update_hp_bar() -> void:
	if _hp_bar:
		_hp_bar.max_value = max_hp
		_hp_bar.value = hp


func _die() -> void:
	died.emit(self)
	queue_free()
