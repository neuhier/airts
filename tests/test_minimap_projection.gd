extends SceneTree

var _failures := 0


func _init() -> void:
	_test_corners()
	_test_round_trip()
	_test_viewport_projection()
	if _failures == 0:
		print("MiniMapProjection tests passed")
	quit(_failures)


func _test_corners() -> void:
	var minimap_size := Vector2(130, 195)
	_expect(MiniMapProjection.world_to_minimap(Vector2.ZERO, minimap_size) == Vector2.ZERO, "world origin maps to minimap origin")
	_expect(MiniMapProjection.world_to_minimap(MiniMapProjection.world_size(), minimap_size) == minimap_size, "world extent maps to minimap extent")


func _test_round_trip() -> void:
	var minimap_size := Vector2(130, 195)
	var world_point := Vector2(375, 1687.5)
	var projected := MiniMapProjection.world_to_minimap(world_point, minimap_size)
	var restored := MiniMapProjection.minimap_to_world(projected, minimap_size)
	_expect(restored.is_equal_approx(world_point), "minimap navigation round-trips world coordinates")


func _test_viewport_projection() -> void:
	var minimap_size := Vector2(130, 195)
	var world_rect := Rect2(Vector2(250, 500), Vector2(1000, 800))
	var projected := MiniMapProjection.world_rect_to_minimap(world_rect, minimap_size)
	_expect(projected.position.is_equal_approx(Vector2(21.666666, 43.333332)), "viewport origin projects correctly")
	_expect(projected.size.is_equal_approx(Vector2(86.66667, 69.333336)), "viewport size projects correctly")


func _expect(condition: bool, message: String) -> void:
	if condition:
		return
	_failures += 1
	push_error("MiniMapProjection test failed: %s" % message)
