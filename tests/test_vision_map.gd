extends SceneTree

var _failures := 0


func _init() -> void:
	_test_base_radius()
	_test_mountain_vision_bonus()
	_test_mountain_occlusion()
	_test_visible_world_area()
	_test_three_state_visibility()
	if _failures == 0:
		print("VisionMap tests passed")
	quit(_failures)


func _test_base_radius() -> void:
	var origin := Vector2i(10, 10)
	var visible := VisionMap.calculate_visible_tiles([origin], {}, 2.0, 2.0)
	_expect(visible.has(origin), "observer tile is visible")
	_expect(visible.has(Vector2i(12, 10)), "tile at base radius is visible")
	_expect(not visible.has(Vector2i(13, 10)), "tile beyond base radius is hidden")


func _test_mountain_vision_bonus() -> void:
	var origin := Vector2i(10, 10)
	var terrain := {origin: MapManager.TerrainType.MOUNTAIN}
	var visible := VisionMap.calculate_visible_tiles([origin], terrain, 2.0, 2.0)
	_expect(visible.has(Vector2i(14, 10)), "mountain multiplier extends vision radius")


func _test_mountain_occlusion() -> void:
	var origin := Vector2i(10, 10)
	var mountain := Vector2i(11, 10)
	var terrain := {mountain: MapManager.TerrainType.MOUNTAIN}
	_expect(VisionMap.has_line_of_sight(origin, mountain, terrain), "blocking mountain face remains visible")
	_expect(not VisionMap.has_line_of_sight(origin, Vector2i(12, 10), terrain), "mountain hides the tile directly behind it")
	_expect(VisionMap.has_line_of_sight(origin, Vector2i(10, 12), terrain), "mountain does not block unrelated sight rays")


func _test_visible_world_area() -> void:
	var same_tile_positions: Array[Vector2] = [Vector2(251, 251), Vector2(260, 260)]
	var visible := VisionMap.calculate_visible_world_positions(same_tile_positions, {}, 1.0, 1.0)
	_expect(visible.size() == 5, "overlapping observers do not double-count visible tiles")
	var expected_area := 5.0 * MapManager.TILE_SIZE * MapManager.TILE_SIZE
	_expect(is_equal_approx(VisionMap.get_visible_world_area(visible), expected_area), "visible income area equals unique tile area")


func _test_three_state_visibility() -> void:
	var tile := Vector2i(4, 4)
	var visible := {}
	var explored := {}
	_expect(VisionMap.get_visibility_state(tile, visible, explored) == VisionMap.VisibilityState.UNEXPLORED, "new tiles start unexplored")
	explored[tile] = true
	_expect(VisionMap.get_visibility_state(tile, visible, explored) == VisionMap.VisibilityState.EXPLORED, "remembered tiles remain explored")
	visible[tile] = true
	_expect(VisionMap.get_visibility_state(tile, visible, explored) == VisionMap.VisibilityState.VISIBLE, "current visibility takes precedence")


func _expect(condition: bool, message: String) -> void:
	if condition:
		return
	_failures += 1
	push_error("VisionMap test failed: %s" % message)
