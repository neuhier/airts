extends Camera2D
class_name CameraController
## Pans the gameplay camera via WASD/arrow keys and drag gestures, clamped so
## the viewport never shows past the map grid's pixel bounds (see
## `MapManager`). Both mouse buttons are supported because noVNC maps iPad
## drags to left-mouse events, while desktop playtesting traditionally uses
## right-mouse dragging.
##
## Zoom is expected to start at `Vector2(1.0, 1.0)` (set on the node in the
## editor / scene file) — this script only pans, it never changes zoom.

@export var pan_speed: float = 600.0

var _dragging: bool = false
var _mouse_drag_buttons := PackedInt32Array([MOUSE_BUTTON_LEFT, MOUSE_BUTTON_RIGHT])


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index in _mouse_drag_buttons:
		_dragging = event.pressed
	elif event is InputEventScreenTouch:
		_dragging = event.pressed
	elif event is InputEventMouseMotion and _dragging:
		position -= event.relative / zoom
		_clamp_to_map_bounds()
	elif event is InputEventScreenDrag:
		position -= event.relative / zoom
		_clamp_to_map_bounds()


func _process(delta: float) -> void:
	var input_dir := Vector2(
		Input.get_action_strength("ui_right") - Input.get_action_strength("ui_left"),
		Input.get_action_strength("ui_down") - Input.get_action_strength("ui_up")
	)
	if input_dir != Vector2.ZERO:
		position += input_dir.normalized() * pan_speed * delta / zoom
		_clamp_to_map_bounds()


## Keeps the camera's center within the map's pixel rectangle, accounting
## for the current viewport size and zoom so the visible area never shows
## territory outside the generated grid.
func _clamp_to_map_bounds() -> void:
	var map_size := Vector2(MapManager.MAP_WIDTH, MapManager.MAP_HEIGHT) * MapManager.TILE_SIZE
	var viewport_size := get_viewport_rect().size / zoom
	var half_viewport := viewport_size / 2.0

	# If the map is smaller than the viewport on an axis, lock the camera
	# to that axis' center instead of producing an inverted clamp range.
	var min_x := half_viewport.x
	var max_x := map_size.x - half_viewport.x
	var min_y := half_viewport.y
	var max_y := map_size.y - half_viewport.y

	position.x = clampf(position.x, min_x, max_x) if max_x >= min_x else map_size.x / 2.0
	position.y = clampf(position.y, min_y, max_y) if max_y >= min_y else map_size.y / 2.0
