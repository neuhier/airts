extends Node
class_name EnemyAiController
## Basic scripted opponent for the Enemy team (spawns at the top of the
## 3:2 map, see `main.tscn`). Periodically spends resources on HQ unit
## production, then groups idle units into a squad and marches them at
## the Player HQ using the same `set_move_target()` path every player
## move-order already goes through (so AI units get AStarGrid2D routing
## for free).

@export var enemy_economy: EconomyController
@export var player_hq_position := Vector2.ZERO

var action_timer := 0.0
const ACTION_INTERVAL := 3.0
const ATTACK_SQUAD_SIZE := 4


func _ready() -> void:
	if player_hq_position == Vector2.ZERO:
		var map_pixel_width := MapManager.MAP_WIDTH * MapManager.TILE_SIZE
		var map_pixel_height := MapManager.MAP_HEIGHT * MapManager.TILE_SIZE
		# Player HQ sits at the bottom of the map (see main.tscn).
		player_hq_position = Vector2(map_pixel_width / 2.0, map_pixel_height - 256.0)


func _process(delta: float) -> void:
	action_timer += delta
	if action_timer >= ACTION_INTERVAL:
		action_timer = 0.0
		_spend_resources()
		_launch_hq_assault()


func _spend_resources() -> void:
	if enemy_economy == null:
		return
	if enemy_economy.can_afford_unit("melee"):
		enemy_economy.try_produce_hq_unit()


func _launch_hq_assault() -> void:
	var enemy_units := get_tree().get_nodes_in_group("team_enemy")

	var idle_units: Array = []
	for unit in enemy_units:
		if unit is Unit and unit.is_alive() and unit.is_idle():
			idle_units.append(unit)

	if idle_units.size() >= ATTACK_SQUAD_SIZE:
		for unit in idle_units:
			unit.set_move_target(player_hq_position)
