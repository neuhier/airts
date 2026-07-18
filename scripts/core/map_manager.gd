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

const MAP_WIDTH := 40
const MAP_HEIGHT := 40
## World-space size of one grid cell — must match the scale units actually
## move at (see `main.tscn`'s 1000x800 play area) for grid lookups from
## `global_position` to line up with the generated terrain.
const TILE_SIZE := 25.0

## HQ spawn columns (extreme left / mirrored extreme right) forced to
## GROUND regardless of noise, so a base never generates inside an
## impassable obstacle or a slowing mountain.
const _BASE_CLEAR_COLUMNS := 3

static var map_grid: Dictionary = {}  # Vector2i -> TerrainType
static var _generated: bool = false


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

	for x in range(MAP_WIDTH / 2):
		for y in range(MAP_HEIGHT):
			var sampled := _sample_terrain(noise, x, y)
			var pos := Vector2i(x, y)
			var mirrored_pos := Vector2i(MAP_WIDTH - 1 - x, y)
			map_grid[pos] = sampled
			map_grid[mirrored_pos] = sampled

	_force_clear_base_columns()
	_generated = true


static func _sample_terrain(noise: FastNoiseLite, x: int, y: int) -> TerrainType:
	var value := noise.get_noise_2d(x, y)
	if value < -0.2:
		return TerrainType.OBSTACLE
	elif value > 0.3:
		return TerrainType.MOUNTAIN
	return TerrainType.GROUND


static func _force_clear_base_columns() -> void:
	for x in range(_BASE_CLEAR_COLUMNS):
		for y in range(MAP_HEIGHT):
			map_grid[Vector2i(x, y)] = TerrainType.GROUND
			map_grid[Vector2i(MAP_WIDTH - 1 - x, y)] = TerrainType.GROUND


## Converts a world-space position (e.g. `unit.global_position`) to the
## grid cell it falls in.
static func world_to_grid(world_position: Vector2) -> Vector2i:
	return Vector2i(int(floor(world_position.x / TILE_SIZE)), int(floor(world_position.y / TILE_SIZE)))


## Terrain at `world_position`, defaulting to GROUND for any position
## outside the generated grid (e.g. before `generate()` has run).
static func get_terrain_at(world_position: Vector2) -> TerrainType:
	if not _generated:
		generate()
	return map_grid.get(world_to_grid(world_position), TerrainType.GROUND)
