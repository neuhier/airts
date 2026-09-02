extends Node
class_name FogOfWarManager
## Shared, team-specific line-of-sight model. Terrain remains permanently
## visible; only opposing units and structures are hidden when outside the
## player's current vision.

const GROUP_NAME := "fog_of_war_manager"


func _ready() -> void:
	add_to_group(GROUP_NAME)


func _process(_delta: float) -> void:
	_update_enemy_presentation()


## Returns whether at least one alive member of `team` can currently see this
## world position. Units and HQs both inherit `vision_radius` from Unit.
func is_position_visible_to(team: Unit.Team, world_position: Vector2) -> bool:
	var group_name := "team_player" if team == Unit.Team.PLAYER else "team_enemy"
	for node in get_tree().get_nodes_in_group(group_name):
		if node is Unit and node.is_alive():
			if node.global_position.distance_to(world_position) <= node.vision_radius:
				return true
	return false


func _update_enemy_presentation() -> void:
	for node in get_tree().get_nodes_in_group("team_enemy"):
		if node is Unit:
			node.visible = node.is_alive() and is_position_visible_to(Unit.Team.PLAYER, node.global_position)
