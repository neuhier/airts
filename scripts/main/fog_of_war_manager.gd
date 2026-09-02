extends Node2D
class_name FogOfWarManager
## Shared, team-specific line-of-sight model. It remembers explored tiles for
## both teams and renders the player team's current black/gray fog overlay.

const GROUP_NAME := "fog_of_war_manager"
const UNEXPLORED_COLOR := Color(0.0, 0.0, 0.0, 1.0)
const EXPLORED_COLOR := Color(0.32, 0.32, 0.32, 0.72)

var _explored_cells := {
	Unit.Team.PLAYER: {},
	Unit.Team.ENEMY: {},
}
var _visible_cells := {
	Unit.Team.PLAYER: {},
	Unit.Team.ENEMY: {},
}


func _ready() -> void:
	add_to_group(GROUP_NAME)
	queue_redraw()


func _process(_delta: float) -> void:
	_refresh_visibility()
	_update_enemy_presentation()
	queue_redraw()


## Returns whether at least one alive member of `team` can currently see this
## world position. Units and HQs both inherit `vision_radius` from Unit.
func is_position_visible_to(team: Unit.Team, world_position: Vector2) -> bool:
	var group_name := "team_player" if team == Unit.Team.PLAYER else "team_enemy"
	for node in get_tree().get_nodes_in_group(group_name):
		if node is Unit and node.is_alive():
			if node.global_position.distance_to(world_position) <= node.vision_radius:
				return true
	return false


func _refresh_visibility() -> void:
	for team in [Unit.Team.PLAYER, Unit.Team.ENEMY]:
		var visible: Dictionary = {}
		var group_name := "team_player" if team == Unit.Team.PLAYER else "team_enemy"
		for node in get_tree().get_nodes_in_group(group_name):
			if node is Unit and node.is_alive():
				_reveal_cells_in_radius(visible, node.global_position, node.vision_radius)
		_visible_cells[team] = visible
		var explored: Dictionary = _explored_cells[team]
		for cell in visible:
			explored[cell] = true


func _reveal_cells_in_radius(visible: Dictionary, center: Vector2, radius: float) -> void:
	var min_cell := MapManager.world_to_grid(center - Vector2(radius, radius))
	var max_cell := MapManager.world_to_grid(center + Vector2(radius, radius))
	for x in range(maxi(min_cell.x, 0), mini(max_cell.x, MapManager.MAP_WIDTH - 1) + 1):
		for y in range(maxi(min_cell.y, 0), mini(max_cell.y, MapManager.MAP_HEIGHT - 1) + 1):
			var cell := Vector2i(x, y)
			var cell_center := (Vector2(cell) + Vector2(0.5, 0.5)) * MapManager.TILE_SIZE
			if center.distance_to(cell_center) <= radius:
				visible[cell] = true


func _update_enemy_presentation() -> void:
	for node in get_tree().get_nodes_in_group("team_enemy"):
		if node is Unit:
			node.visible = node.is_alive() and is_position_visible_to(Unit.Team.PLAYER, node.global_position)


func _draw() -> void:
	var player_visible: Dictionary = _visible_cells[Unit.Team.PLAYER]
	var player_explored: Dictionary = _explored_cells[Unit.Team.PLAYER]
	var tile_size := Vector2(MapManager.TILE_SIZE, MapManager.TILE_SIZE)
	for x in range(MapManager.MAP_WIDTH):
		for y in range(MapManager.MAP_HEIGHT):
			var cell := Vector2i(x, y)
			if player_visible.has(cell):
				continue
			var fog_color := EXPLORED_COLOR if player_explored.has(cell) else UNEXPLORED_COLOR
			draw_rect(Rect2(Vector2(cell) * MapManager.TILE_SIZE, tile_size), fog_color, true)
