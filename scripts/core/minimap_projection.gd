extends RefCounted
class_name MiniMapProjection
## Pure coordinate conversion shared by MiniMap and headless tests.


static func world_size() -> Vector2:
	return Vector2(MapManager.MAP_WIDTH, MapManager.MAP_HEIGHT) * MapManager.TILE_SIZE


static func world_to_minimap(world_position: Vector2, minimap_size: Vector2) -> Vector2:
	var normalized := world_position / world_size()
	return Vector2(
		clampf(normalized.x, 0.0, 1.0) * minimap_size.x,
		clampf(normalized.y, 0.0, 1.0) * minimap_size.y
	)


static func minimap_to_world(minimap_position: Vector2, minimap_size: Vector2) -> Vector2:
	if minimap_size.x <= 0.0 or minimap_size.y <= 0.0:
		return Vector2.ZERO
	var normalized := minimap_position / minimap_size
	return Vector2(
		clampf(normalized.x, 0.0, 1.0) * world_size().x,
		clampf(normalized.y, 0.0, 1.0) * world_size().y
	)


static func world_rect_to_minimap(world_rect: Rect2, minimap_size: Vector2) -> Rect2:
	var start := world_to_minimap(world_rect.position, minimap_size)
	var finish := world_to_minimap(world_rect.end, minimap_size)
	return Rect2(start, finish - start)
