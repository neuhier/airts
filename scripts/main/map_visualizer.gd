extends Node2D
class_name MapVisualizer
## Draws `MapManager.map_grid` as flat-colored tiles so the procedural
## terrain is actually visible (previously data-only). Drawn once — the
## grid never changes after `MapManager.generate()` runs — so this uses
## `_ready()` + a single `queue_redraw()` rather than redrawing every frame
## like `TerritoryVisualizer` (whose underlying data changes constantly).

@export var ground_color := Color(0.18, 0.35, 0.16, 1.0)
@export var mountain_color := Color(0.45, 0.42, 0.38, 1.0)
@export var obstacle_color := Color(0.08, 0.08, 0.1, 1.0)
@export var grid_line_color := Color(0, 0, 0, 0.08)


func _ready() -> void:
	MapManager.generate()
	queue_redraw()


func _draw() -> void:
	var tile := MapManager.TILE_SIZE
	for coords in MapManager.map_grid:
		var terrain: MapManager.TerrainType = MapManager.map_grid[coords]
		var color := ground_color
		match terrain:
			MapManager.TerrainType.MOUNTAIN:
				color = mountain_color
			MapManager.TerrainType.OBSTACLE:
				color = obstacle_color
		var rect := Rect2(Vector2(coords) * tile, Vector2(tile, tile))
		draw_rect(rect, color, true)
		draw_rect(rect, grid_line_color, false)
