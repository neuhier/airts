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

@export var team: Team = Team.PLAYER
@export var max_hp: float = 100.0
@export var damage: float = 10.0
@export var attack_range: float = 48.0
@export var attack_cooldown: float = 1.0
@export var move_speed: float = 150.0
## Distance to the move target below which the unit is considered "arrived".
@export var arrival_threshold: float = 4.0

var hp: float
var move_target: Vector2

var _attack_timer: float = 0.0
var _current_target: Unit = null
## Manually-assigned focus-fire target (via `attack_target()`). Overrides
## automatic nearest-target acquisition until it dies/becomes invalid or a
## new command (`set_move_target` / `attack_target`) replaces it.
var _forced_target: Unit = null

signal died(unit: Unit)
signal hp_changed(unit: Unit, hp: float, max_hp: float)

@onready var _hp_bar: ProgressBar = get_node_or_null("HPBar")
@onready var _selection_ring: Node2D = get_node_or_null("SelectionRing")


func _ready() -> void:
	hp = max_hp
	move_target = global_position
	add_to_group(_team_group())
	_update_hp_bar()


func _physics_process(delta: float) -> void:
	if _forced_target and (not is_instance_valid(_forced_target) or not _forced_target.is_alive()):
		_forced_target = null

	if _forced_target:
		_current_target = _forced_target
		var dist := global_position.distance_to(_forced_target.global_position)
		if dist <= attack_range:
			velocity = Vector2.ZERO
			_try_attack(delta)
		else:
			_move_towards(_forced_target.global_position)
	else:
		_current_target = _find_target_in_range()
		if _current_target:
			velocity = Vector2.ZERO
			_try_attack(delta)
		else:
			_move_towards_target()
	move_and_slide()


## Called by the input layer (touch controller) to command this unit to a
## new world position. Cancels the current attack lock so the unit starts
## moving immediately. Also cancels any manual focus-fire target — a fresh
## move command always takes priority.
func set_move_target(world_position: Vector2) -> void:
	move_target = world_position
	_forced_target = null


## Called by the input layer to focus-fire a specific enemy unit (or HQ),
## overriding automatic nearest-target acquisition. The unit walks to the
## target and attacks it exclusively until it dies or a new command
## (`set_move_target` / `attack_target`) replaces this order.
func attack_target(target_unit: Unit) -> void:
	_forced_target = target_unit


## Toggles the optional `SelectionRing` child node. Purely visual — has no
## gameplay effect. Units without a `SelectionRing` node (e.g. `Headquarters`)
## silently no-op.
func set_selected(is_selected: bool) -> void:
	if _selection_ring:
		_selection_ring.visible = is_selected


func take_damage(amount: float) -> void:
	if not is_alive():
		return
	hp = max(hp - amount, 0.0)
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
	var nearest: Unit = null
	var nearest_dist := INF
	for node in get_tree().get_nodes_in_group(_enemy_group()):
		if node is Unit and node != self and node.is_alive():
			var dist := global_position.distance_to(node.global_position)
			if dist <= attack_range and dist < nearest_dist:
				nearest = node
				nearest_dist = dist
	return nearest


func _try_attack(delta: float) -> void:
	_attack_timer -= delta
	if _attack_timer <= 0.0:
		_attack_timer = attack_cooldown
		_current_target.take_damage(damage)


func _move_towards_target() -> void:
	_move_towards(move_target)


func _move_towards(destination: Vector2) -> void:
	var to_target := destination - global_position
	if to_target.length() <= arrival_threshold:
		velocity = Vector2.ZERO
		return
	velocity = to_target.normalized() * move_speed


func _update_hp_bar() -> void:
	if _hp_bar:
		_hp_bar.max_value = max_hp
		_hp_bar.value = hp


func _die() -> void:
	died.emit(self)
	queue_free()
