extends Control
class_name MiniMap
## Lightweight custom-drawn minimap. Terrain/Fog of War is represented by
## a 60x90 texture (one pixel per map tile); dynamic units and the camera
## viewport are drawn as a small overlay.

const REFRESH_INTERVAL := 0.15
const MAP_RECT := Rect2(0.0, 0.0, 130.0, 195.0)

const GROUND_COLOR := Color(0.18, 0.35, 0.16, 1.0)
const MOUNTAIN_COLOR := Color(0.45, 0.42, 0.38, 1.0)
const OBSTACLE_COLOR := Color(0.08, 0.08, 0.1, 1.0)
const UNEXPLORED_COLOR := Color(0.01, 0.015, 0.02, 1.0)

var _camera: CameraController = null
var _fog: FogOfWar = null
var _map_texture: ImageTexture = null
var _refresh_time := 0.0

@onready var _hit_area: Control = %MapHitArea


func _ready() -> void:
	MapManager.generate()
	_hit_area.gui_input.connect(_on_map_gui_input)
	_rebuild_map_texture()
	queue_redraw()


func bind_world(camera: CameraController, fog: FogOfWar) -> void:
	_camera = camera
	_fog = fog
	_rebuild_map_texture()
	queue_redraw()


func _process(delta: float) -> void:
	_refresh_time -= delta
	if _refresh_time > 0.0:
		return
	_refresh_time = REFRESH_INTERVAL
	_rebuild_map_texture()
	queue_redraw()


func _rebuild_map_texture() -> void:
	var image := Image.create(MapManager.MAP_WIDTH, MapManager.MAP_HEIGHT, false, Image.FORMAT_RGBA8)
	for y in range(MapManager.MAP_HEIGHT):
		for x in range(MapManager.MAP_WIDTH):
			var tile := Vector2i(x, y)
			var color := _terrain_color(MapManager.map_grid.get(tile, MapManager.TerrainType.GROUND))
			if _fog:
				var visibility := _fog.get_tile_visibility(tile)
				if visibility == VisionMap.VisibilityState.UNEXPLORED:
					color = UNEXPLORED_COLOR
				elif visibility == VisionMap.VisibilityState.EXPLORED:
					color = color.darkened(0.68)
			else:
				color = UNEXPLORED_COLOR
			image.set_pixel(x, y, color)
	if _map_texture:
		_map_texture.update(image)
	else:
		_map_texture = ImageTexture.create_from_image(image)


func _terrain_color(terrain: MapManager.TerrainType) -> Color:
	match terrain:
		MapManager.TerrainType.MOUNTAIN:
			return MOUNTAIN_COLOR
		MapManager.TerrainType.OBSTACLE:
			return OBSTACLE_COLOR
		_:
			return GROUND_COLOR


func _draw() -> void:
	draw_rect(MAP_RECT.grow(2.0), Color(0.9, 0.92, 0.96, 0.8), false, 2.0)
	if _map_texture:
		draw_texture_rect(_map_texture, MAP_RECT, false)
	_draw_units("team_player", Unit.TEAM_COLORS[Unit.Team.PLAYER], false)
	_draw_units("team_enemy", Unit.TEAM_COLORS[Unit.Team.ENEMY], true)
	_draw_camera_viewport()


func _draw_units(group: String, color: Color, respect_fog: bool) -> void:
	for node in get_tree().get_nodes_in_group(group):
		if not (node is Unit) or not node.is_alive():
			continue
		if respect_fog and _fog and not _fog.is_world_position_visible(node.global_position):
			continue
		var point := MiniMapProjection.world_to_minimap(node.global_position, MAP_RECT.size)
		if node is Headquarters:
			draw_rect(Rect2(point - Vector2(3.0, 3.0), Vector2(6.0, 6.0)), color, true)
		else:
			draw_circle(point, 2.0, color)


func _draw_camera_viewport() -> void:
	if _camera == null:
		return
	var world_view_size := _camera.get_viewport_rect().size / _camera.zoom
	var world_view := Rect2(_camera.global_position - world_view_size / 2.0, world_view_size)
	var minimap_view := MiniMapProjection.world_rect_to_minimap(world_view, MAP_RECT.size)
	minimap_view = minimap_view.intersection(MAP_RECT)
	draw_rect(minimap_view, Color(1.0, 1.0, 1.0, 0.9), false, 1.0)


func _on_map_gui_input(event: InputEvent) -> void:
	var local_position: Variant = null
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		local_position = event.position
	elif event is InputEventScreenTouch and event.pressed:
		local_position = event.position
	elif event is InputEventMouseMotion and event.button_mask & MOUSE_BUTTON_MASK_LEFT:
		local_position = event.position
	elif event is InputEventScreenDrag:
		local_position = event.position
	if local_position == null or _camera == null:
		return
	_camera.center_on_world_position(MiniMapProjection.minimap_to_world(local_position, MAP_RECT.size))
	_hit_area.accept_event()
	queue_redraw()
