extends RefCounted
class_name VisionMap
## Tile-based sight calculation shared by FogOfWar and headless tests.
## A mountain occupied by the viewer increases its radius; intermediate
## mountain tiles block the ray, producing a shadow on the far side.

enum VisibilityState { UNEXPLORED, EXPLORED, VISIBLE }

const DEFAULT_BASE_VISION_RADIUS := 6.0
const DEFAULT_MOUNTAIN_VISION_MULTIPLIER := 1.75


static func calculate_visible_world_positions(
	observer_positions: Array[Vector2],
	terrain: Dictionary,
	base_radius: float,
	mountain_vision_multiplier: float
) -> Dictionary:
	var observer_tiles: Array[Vector2i] = []
	for position in observer_positions:
		var tile := MapManager.world_to_grid(position)
		if not observer_tiles.has(tile):
			observer_tiles.append(tile)
	return calculate_visible_tiles(observer_tiles, terrain, base_radius, mountain_vision_multiplier)


static func get_visible_world_area(visible_tiles: Dictionary) -> float:
	return visible_tiles.size() * MapManager.TILE_SIZE * MapManager.TILE_SIZE


static func calculate_visible_tiles(
	observer_tiles: Array[Vector2i],
	terrain: Dictionary,
	base_radius: float,
	mountain_vision_multiplier: float
) -> Dictionary:
	var visible := {}
	for origin in observer_tiles:
		var radius := base_radius
		if terrain.get(origin, MapManager.TerrainType.GROUND) == MapManager.TerrainType.MOUNTAIN:
			radius *= mountain_vision_multiplier
		_add_visible_from(origin, radius, terrain, visible)
	return visible


static func _add_visible_from(origin: Vector2i, radius: float, terrain: Dictionary, visible: Dictionary) -> void:
	var grid_radius := int(ceil(radius))
	for y in range(max(0, origin.y - grid_radius), min(MapManager.MAP_HEIGHT, origin.y + grid_radius + 1)):
		for x in range(max(0, origin.x - grid_radius), min(MapManager.MAP_WIDTH, origin.x + grid_radius + 1)):
			var target := Vector2i(x, y)
			if Vector2(origin).distance_to(Vector2(target)) > radius:
				continue
			if has_line_of_sight(origin, target, terrain):
				visible[target] = true


static func has_line_of_sight(origin: Vector2i, target: Vector2i, terrain: Dictionary) -> bool:
	var delta := target - origin
	var steps := maxi(absi(delta.x), absi(delta.y))
	if steps <= 1:
		return true

	# Sample every crossed grid interval. The origin and destination are
	# deliberately excluded: a unit can see out from its own mountain, and
	# the face of a target mountain remains visible while tiles behind it do not.
	for step in range(1, steps):
		var progress := float(step) / float(steps)
		var sample := Vector2(origin).lerp(Vector2(target), progress)
		var cell := Vector2i(roundi(sample.x), roundi(sample.y))
		if terrain.get(cell, MapManager.TerrainType.GROUND) == MapManager.TerrainType.MOUNTAIN:
			return false
	return true


static func get_visibility_state(tile: Vector2i, visible: Dictionary, explored: Dictionary) -> VisibilityState:
	if visible.has(tile):
		return VisibilityState.VISIBLE
	if explored.has(tile):
		return VisibilityState.EXPLORED
	return VisibilityState.UNEXPLORED
