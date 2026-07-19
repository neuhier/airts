extends RefCounted
class_name MapManager
## Procedural, horizontally-mirrored terrain grid (static, like
## `ResourceManager` — reachable as `MapManager.foo()` without a node
## reference, and works identically in headless test scripts).
##
## Mirroring the left half onto the right half guarantees both teams'
## starting territory is tactically symmetric, matching the mirrored-HQ
## layout in `main.tscn`.

enum TerrainType { GROUND, MOUNTAIN, OBSTACLE }

## 3:2 vertical aspect ratio (taller than wide) — Player spawns at the
## bottom, Enemy at the top, mirrored across the horizontal midline.
const MAP_WIDTH := 60
const MAP_HEIGHT := 90
## World-space size of one grid cell — must match the scale units actually
## move at (see `main.tscn`'s 1000x800 play area) for grid lookups from
## `global_position` to line up with the generated terrain.
const TILE_SIZE := 25.0

## HQ spawn rows (extreme top / mirrored extreme bottom) forced to GROUND
## regardless of noise, so a base never generates inside an impassable
## obstacle or a slowing mountain.
const _BASE_CLEAR_ROWS := 3

static var map_grid: Dictionary = {}  # Vector2i -> TerrainType
static var _generated: bool = false

## Terrain weight scale applied to MOUNTAIN cells — pathfinding treats
## crossing a mountain tile as this many times more "expensive" than
## GROUND, so it's preferred only when it's meaningfully shorter.
const _MOUNTAIN_WEIGHT_SCALE := 2.5

static var astar := AStarGrid2D.new()


## Generates (once) the mirrored terrain grid. Safe to call multiple times
## — subsequent calls are no-ops unless `force` is true (used by headless
## tests that need a fresh map between cases).
static func generate(seed_value: int = 0, force: bool = false) -> void:
	if _generated and not force:
		return
	map_grid.clear()

	var noise := FastNoiseLite.new()
	noise.seed = seed_value
	noise.noise_type = FastNoiseLite.TYPE_PERLIN
	# Default frequency (0.01) keeps get_noise_2d() output within a tiny
	# band around 0 for integer grid coords, so OBSTACLE's < -0.2 threshold
	# was effectively unreachable. A higher frequency spreads the sampled
	# range across roughly [-1, 1] so all three terrain types actually
	# appear.
	noise.frequency = 0.15

	for y in range(MAP_HEIGHT / 2):
		for x in range(MAP_WIDTH):
			var sampled := _sample_terrain(noise, x, y)
			var pos := Vector2i(x, y)
			var mirrored_pos := Vector2i(x, MAP_HEIGHT - 1 - y)
			map_grid[pos] = sampled
			map_grid[mirrored_pos] = sampled

	_force_clear_base_columns()
	_generated = true
	setup_pathfinding()


static func _sample_terrain(noise: FastNoiseLite, x: int, y: int) -> TerrainType:
	var value := noise.get_noise_2d(x, y)
	if value < -0.2:
		return TerrainType.OBSTACLE
	elif value > 0.3:
		return TerrainType.MOUNTAIN
	return TerrainType.GROUND


static func _force_clear_base_columns() -> void:
	for y in range(_BASE_CLEAR_ROWS):
		for x in range(MAP_WIDTH):
			map_grid[Vector2i(x, y)] = TerrainType.GROUND
			map_grid[Vector2i(x, MAP_HEIGHT - 1 - y)] = TerrainType.GROUND


## Builds `astar` from the current `map_grid`: OBSTACLE cells are marked
## solid (impassable), MOUNTAIN cells get a higher weight scale so a path
## avoids them unless the detour would be longer, GROUND is left at the
## default weight.
static func setup_pathfinding() -> void:
	astar.region = Rect2i(0, 0, MAP_WIDTH, MAP_HEIGHT)
	astar.cell_size = Vector2(TILE_SIZE, TILE_SIZE)
	astar.default_compute_heuristic = AStarGrid2D.HEURISTIC_EUCLIDEAN
	astar.default_estimate_heuristic = AStarGrid2D.HEURISTIC_EUCLIDEAN
	astar.diagonal_mode = AStarGrid2D.DIAGONAL_MODE_NEVER
	astar.update()

	for x in range(MAP_WIDTH):
		for y in range(MAP_HEIGHT):
			var pos := Vector2i(x, y)
			var terrain: TerrainType = map_grid.get(pos, TerrainType.GROUND)
			match terrain:
				TerrainType.OBSTACLE:
					astar.set_point_solid(pos, true)
				TerrainType.MOUNTAIN:
					astar.set_point_weight_scale(pos, _MOUNTAIN_WEIGHT_SCALE)
				TerrainType.GROUND:
					astar.set_point_weight_scale(pos, 1.0)


## Converts a world-space position (e.g. `unit.global_position`) to the
## grid cell it falls in.
static func world_to_grid(world_position: Vector2) -> Vector2i:
	return Vector2i(int(floor(world_position.x / TILE_SIZE)), int(floor(world_position.y / TILE_SIZE)))


## Waypoint list (world-space) from `from_world` to `to_world`, routed
## around OBSTACLE cells and preferring GROUND over MOUNTAIN via `astar`'s
## weight scale. Falls back to a direct line if either endpoint sits
## outside the grid or on a solid cell (e.g. a unit standing exactly on an
## obstacle's edge) so units never get permanently stuck with no path at
## all.
## Named `find_path` rather than `get_path` — the latter collides with
## `Resource.get_path()` (inherited by every script/class, including this
## one via RefCounted), which Godot resolves first and would raise
## "Invalid call to function 'get_path'" since that builtin takes no args.
static func find_path(from_world: Vector2, to_world: Vector2) -> PackedVector2Array:
	if not _generated:
		generate()
	var from_id := world_to_grid(from_world)
	var to_id := world_to_grid(to_world)
	if not astar.is_in_boundsv(from_id) or not astar.is_in_boundsv(to_id) \
			or astar.is_point_solid(from_id) or astar.is_point_solid(to_id):
		return PackedVector2Array([to_world])
	var path := astar.get_point_path(from_id, to_id)
	# AStarGrid2D waypoints are grid-cell centers, so the final one is only
	# approximately `to_world`. Snap it to the exact requested destination
	# so units actually arrive where commanded rather than stopping short
	# by up to half a tile.
	if path.size() > 0:
		path[path.size() - 1] = to_world
	return path


## Terrain at `world_position`, defaulting to GROUND for any position
## outside the generated grid (e.g. before `generate()` has run).
static func get_terrain_at(world_position: Vector2) -> TerrainType:
	if not _generated:
		generate()
	return map_grid.get(world_to_grid(world_position), TerrainType.GROUND)
