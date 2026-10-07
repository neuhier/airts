extends Node2D
class_name FogOfWar
## Player-facing, three-state Fog of War:
## - never explored: opaque black
## - explored but not currently visible: dimmed
## - currently visible: no overlay

const REFRESH_INTERVAL := 0.15

@export var unexplored_color := Color(0.015, 0.02, 0.025, 1.0)
@export var explored_color := Color(0.015, 0.02, 0.025, 0.72)

var _visible_tiles: Dictionary = {}
var _explored_tiles: Dictionary = {}
var _refresh_time := 0.0


func _ready() -> void:
	MapManager.generate()
	_refresh_visibility()
	queue_redraw()


func _process(delta: float) -> void:
	_refresh_time -= delta
	if _refresh_time > 0.0:
		return
	_refresh_time = REFRESH_INTERVAL
	_refresh_visibility()
	queue_redraw()


func _refresh_visibility() -> void:
	var observer_positions: Array[Vector2] = []
	for node in get_tree().get_nodes_in_group("team_player"):
		if node is Unit and node.is_alive():
			observer_positions.append(node.global_position)

	var base_radius := float(BalanceManager.get_global_value("base_vision_radius", VisionMap.DEFAULT_BASE_VISION_RADIUS))
	var mountain_multiplier := float(BalanceManager.get_global_value(
		"mountain_vision_bonus", VisionMap.DEFAULT_MOUNTAIN_VISION_MULTIPLIER
	))
	base_radius = maxf(base_radius, 0.0)
	mountain_multiplier = maxf(mountain_multiplier, 1.0)
	_visible_tiles = VisionMap.calculate_visible_world_positions(
		observer_positions, MapManager.map_grid, base_radius, mountain_multiplier
	)
	for tile in _visible_tiles:
		_explored_tiles[tile] = true

	_update_enemy_visibility()


func _update_enemy_visibility() -> void:
	for node in get_tree().get_nodes_in_group("team_enemy"):
		if node is Unit:
			node.visible = is_world_position_visible(node.global_position)


func is_world_position_visible(world_position: Vector2) -> bool:
	return _visible_tiles.has(MapManager.world_to_grid(world_position))


func get_tile_visibility(tile: Vector2i) -> VisionMap.VisibilityState:
	return VisionMap.get_visibility_state(tile, _visible_tiles, _explored_tiles)


func _draw() -> void:
	var tile_size := MapManager.TILE_SIZE
	# Merge adjacent tiles with the same hidden state into scanline spans.
	# The map has 5,400 tiles, but a typical frame needs only a few hundred
	# rectangles this way.
	for y in range(MapManager.MAP_HEIGHT):
		var x := 0
		while x < MapManager.MAP_WIDTH:
			var tile := Vector2i(x, y)
			var state := get_tile_visibility(tile)
			if state == VisionMap.VisibilityState.VISIBLE:
				x += 1
				continue
			var run_start := x
			x += 1
			while x < MapManager.MAP_WIDTH and get_tile_visibility(Vector2i(x, y)) == state:
				x += 1
			var color := explored_color if state == VisionMap.VisibilityState.EXPLORED else unexplored_color
			var rect := Rect2(
				Vector2(run_start * tile_size, y * tile_size),
				Vector2((x - run_start) * tile_size, tile_size)
			)
			draw_rect(rect, color, true)
