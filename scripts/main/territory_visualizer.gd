extends Node2D
class_name TerritoryVisualizer
## Draws each team's territory (convex hull of their alive units) as a
## semi-transparent polygon, mirroring `EconomyController.get_units_polygon_area()`
## so the visual matches exactly what passive income is computed from.

@export var player_color := Color(0.0, 0.5, 1.0, 0.15)
@export var enemy_color := Color(1.0, 0.1, 0.1, 0.15)


func _process(_delta: float) -> void:
	queue_redraw()


func _draw() -> void:
	draw_team_territory(Unit.Team.PLAYER, player_color)
	draw_team_territory(Unit.Team.ENEMY, enemy_color)


func draw_team_territory(team: Unit.Team, color: Color) -> void:
	var group := "team_player" if team == Unit.Team.PLAYER else "team_enemy"
	var units := get_tree().get_nodes_in_group(group)
	if units.size() < 3:
		return

	var points: PackedVector2Array = []
	for u in units:
		if u is Unit and u.is_alive():
			points.append(u.global_position)

	if points.size() >= 3:
		var hull := Geometry2D.convex_hull(points)
		draw_colored_polygon(hull, color)
