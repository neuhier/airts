extends Node2D
class_name EconomyController
## Owns one team's entire macro/economy state: the always-active HQ melee
## queue, the buildable expansion modules (each with its own independent
## `TimedQueue`), and the Upgrade-Labor's research queue.
##
## Deliberately decoupled from any physical "module building" node on the
## map (per design decision: modules are data/GUI-only, not separate
## objects placed next to the HQ) — `unlocked_modules` and the per-class
## `module_queues` dictionary are the only state that represents them.
## Only ever instantiated for the human player in this milestone; the enemy
## stays passive (HQ income only, no production) per current scope.

## unit_class_id -> { cost, duration, scene }
const UNIT_CONFIG := {
	"melee": {"cost": 50.0, "duration": 4.0, "scene": preload("res://scenes/units/melee_unit.tscn")},
	"ranged": {"cost": 75.0, "duration": 6.0, "scene": preload("res://scenes/units/ranged_unit.tscn")},
	"mobile": {"cost": 90.0, "duration": 8.0, "scene": preload("res://scenes/units/mobile_unit.tscn")},
	"healer": {"cost": 80.0, "duration": 7.0, "scene": preload("res://scenes/units/healer_unit.tscn")},
}

## module_id -> { cost, unlocks, label }. `unlocks` is either a
## `UNIT_CONFIG` key (module grants that unit's queue) or the literal
## string "lab" (module grants the research queue instead of a unit queue).
const MODULE_CONFIG := {
	"ranged_module": {"cost": 150.0, "unlocks": "ranged", "label": "Schützen-Anbau"},
	"mobile_module": {"cost": 200.0, "unlocks": "mobile", "label": "Fuhrpark"},
	"healer_module": {"cost": 175.0, "unlocks": "healer", "label": "Heiler-Heiligtum"},
	"upgrade_lab": {"cost": 150.0, "unlocks": "lab", "label": "Upgrade-Labor"},
}

## research_id -> { cost, duration, unit_class_id, stat, bonus, label }
const RESEARCH_CONFIG := {
	"melee_damage": {"cost": 100.0, "duration": 10.0, "unit_class_id": "melee", "stat": UpgradeManager.StatType.DAMAGE, "bonus": 0.2, "label": "Melee Schlagkraft (+20%)"},
	"melee_hp": {"cost": 120.0, "duration": 12.0, "unit_class_id": "melee", "stat": UpgradeManager.StatType.HP, "bonus": 0.2, "label": "Melee HP (+20%)"},
	"melee_speed": {"cost": 80.0, "duration": 8.0, "unit_class_id": "melee", "stat": UpgradeManager.StatType.SPEED, "bonus": 0.15, "label": "Melee Tempo (+15%)"},
	"ranged_damage": {"cost": 100.0, "duration": 10.0, "unit_class_id": "ranged", "stat": UpgradeManager.StatType.DAMAGE, "bonus": 0.2, "label": "Ranged Schlagkraft (+20%)"},
	"ranged_hp": {"cost": 120.0, "duration": 12.0, "unit_class_id": "ranged", "stat": UpgradeManager.StatType.HP, "bonus": 0.2, "label": "Ranged HP (+20%)"},
	"ranged_speed": {"cost": 80.0, "duration": 8.0, "unit_class_id": "ranged", "stat": UpgradeManager.StatType.SPEED, "bonus": 0.15, "label": "Ranged Tempo (+15%)"},
	"mobile_damage": {"cost": 100.0, "duration": 10.0, "unit_class_id": "mobile", "stat": UpgradeManager.StatType.DAMAGE, "bonus": 0.2, "label": "Mobile Schlagkraft (+20%)"},
	"mobile_hp": {"cost": 120.0, "duration": 12.0, "unit_class_id": "mobile", "stat": UpgradeManager.StatType.HP, "bonus": 0.2, "label": "Mobile HP (+20%)"},
	"mobile_speed": {"cost": 80.0, "duration": 8.0, "unit_class_id": "mobile", "stat": UpgradeManager.StatType.SPEED, "bonus": 0.15, "label": "Mobile Tempo (+15%)"},
	"healer_damage": {"cost": 100.0, "duration": 10.0, "unit_class_id": "healer", "stat": UpgradeManager.StatType.DAMAGE, "bonus": 0.2, "label": "Healer Schlagkraft (+20%)"},
	"healer_hp": {"cost": 120.0, "duration": 12.0, "unit_class_id": "healer", "stat": UpgradeManager.StatType.HP, "bonus": 0.2, "label": "Healer HP (+20%)"},
	"healer_speed": {"cost": 80.0, "duration": 8.0, "unit_class_id": "healer", "stat": UpgradeManager.StatType.SPEED, "bonus": 0.15, "label": "Healer Tempo (+15%)"},
}

var team: Unit.Team = Unit.Team.PLAYER
var hq: Headquarters = null

## Always active from the start — the HQ's own melee-only production queue.
var hq_queue: TimedQueue = TimedQueue.new()
## Populated lazily as modules are built: unit_class_id -> TimedQueue.
var module_queues: Dictionary = {}
## Always exists, but only usable once the "upgrade_lab" module is built.
var lab_queue: TimedQueue = TimedQueue.new()

var unlocked_modules: Dictionary = {}

## Shared passive-income pool (resources/sec) split between teams by their
## relative territory (convex-hull area of their own units).
const TERRITORY_INCOME_POOL := 100.0
## Fixed area cap a team's hull is normalized against — reaching/exceeding
## this claims the team's full share of the pool. Roughly the visible
## playfield (see project.godot 1000x800 minus the 250px left GUI sidebar).
const MAX_TERRITORY_AREA := 600000.0


func _ready() -> void:
	add_child(hq_queue)
	add_child(lab_queue)
	hq_queue.item_completed.connect(_on_unit_item_completed)
	hq_queue.item_cancelled.connect(_on_unit_item_cancelled)
	lab_queue.item_completed.connect(_on_research_item_completed)
	lab_queue.item_cancelled.connect(_on_research_item_cancelled)


## Last computed territory income rate (resources/sec), exposed read-only
## for the GUI's HUD readout — kept in sync every `_process()` tick rather
## than recomputed on demand so the HUD never triggers an extra convex-hull
## calculation of its own.
var territory_income_rate: float = 0.0


func _process(delta: float) -> void:
	var units := get_tree().get_nodes_in_group("team_player" if team == Unit.Team.PLAYER else "team_enemy")
	var area := get_units_polygon_area(units)
	var share: float = clamp(area / MAX_TERRITORY_AREA, 0.0, 1.0)
	territory_income_rate = TERRITORY_INCOME_POOL * share
	ResourceManager.add(team, territory_income_rate * delta)


## Convex-hull area (Shoelace formula) of `units`' current positions. Fewer
## than 3 units can't form a polygon, so territory income is 0 until a
## team has at least a triangle of units alive.
func get_units_polygon_area(units: Array) -> float:
	if units.size() < 3:
		return 0.0

	var points: PackedVector2Array = []
	for u in units:
		if u is Unit and u.is_alive():
			points.append(u.global_position)
	if points.size() < 3:
		return 0.0

	var hull := Geometry2D.convex_hull(points)
	var area := 0.0
	var num_vertices := hull.size()
	for i in range(num_vertices):
		var j := (i + 1) % num_vertices
		area += hull[i].cross(hull[j])
	return abs(area) * 0.5


## Must be called right after instantiation (no constructor args in Godot
## node scripts) to bind this controller to a team and its HQ. `hq` is used
## as the spawn anchor for produced units.
func setup(p_team: Unit.Team, p_hq: Headquarters) -> void:
	team = p_team
	hq = p_hq


# --- Unit production -------------------------------------------------------

## Queues a MeleeUnit in the HQ's own queue if affordable. Returns false
## (no state change) if not.
func try_produce_hq_unit() -> bool:
	return _try_enqueue_unit(hq_queue, "melee")


## Queues a unit in the module queue for `unit_class_id` (ranged/mobile/
## healer) if that module has been built and the order is affordable.
func try_produce_module_unit(unit_class_id: String) -> bool:
	var queue: TimedQueue = module_queues.get(unit_class_id)
	if queue == null:
		return false
	return _try_enqueue_unit(queue, unit_class_id)


func _try_enqueue_unit(queue: TimedQueue, unit_class_id: String) -> bool:
	var config: Dictionary = UNIT_CONFIG[unit_class_id]
	if not ResourceManager.try_spend(team, config.cost):
		return false
	queue.enqueue({"duration": config.duration, "unit_class_id": unit_class_id})
	return true


func _on_unit_item_completed(item: Dictionary) -> void:
	_spawn_unit(item.get("unit_class_id"))


func _on_unit_item_cancelled(item: Dictionary) -> void:
	var config: Dictionary = UNIT_CONFIG[item.get("unit_class_id")]
	ResourceManager.add(team, config.cost)


func _spawn_unit(unit_class_id: String) -> void:
	var config: Dictionary = UNIT_CONFIG[unit_class_id]
	var scene: PackedScene = config.scene
	var instance: Unit = scene.instantiate()
	instance.team = team
	instance.position = _spawn_position()
	# Units live as direct children of whatever node owns this controller
	# (in `main.tscn`, that's `Main` — the same parent all hand-placed
	# starting units already use), so no extra container node is required.
	get_parent().add_child(instance)


## Minimum distance from the HQ's center a unit may spawn at — must clear
## the HQ's own collision shape (18px half-extent) plus a unit's collision
## radius, or Godot's move_and_slide() overlap-recovery pass will nudge the
## HQ itself apart from the newly-spawned unit ("HQ dragging" glitch).
const _MIN_SPAWN_DISTANCE_FROM_HQ := 50.0
const _SPAWN_JITTER_SPREAD := 20.0

func _spawn_position() -> Vector2:
	if hq == null:
		return Vector2.ZERO
	var direction := Vector2(1, 0) if team == Unit.Team.PLAYER else Vector2(-1, 0)
	var base_offset := direction * _MIN_SPAWN_DISTANCE_FROM_HQ + Vector2(0, 30)
	# Random jitter so simultaneously-spawned units don't overlap exactly
	# (which would fling them apart), without ever landing back inside the
	# HQ's own collision shape.
	var jitter := Vector2(
		randf_range(-_SPAWN_JITTER_SPREAD, _SPAWN_JITTER_SPREAD),
		randf_range(-_SPAWN_JITTER_SPREAD, _SPAWN_JITTER_SPREAD)
	)
	return hq.global_position + base_offset + jitter


# --- Expansion modules -------------------------------------------------------

## Attempts to build `module_id` (one of `MODULE_CONFIG`'s keys). Returns
## false if already built or unaffordable. Building grants either a new
## independent unit-production queue (ranged/mobile/healer) or the research
## queue (upgrade_lab) — see `MODULE_CONFIG.unlocks`.
func try_build_module(module_id: String) -> bool:
	if is_module_built(module_id):
		return false
	var config: Dictionary = MODULE_CONFIG[module_id]
	if not ResourceManager.try_spend(team, config.cost):
		return false
	unlocked_modules[module_id] = true

	var unlocks: String = config.unlocks
	if unlocks != "lab":
		var queue := TimedQueue.new()
		add_child(queue)
		queue.item_completed.connect(_on_unit_item_completed)
		queue.item_cancelled.connect(_on_unit_item_cancelled)
		module_queues[unlocks] = queue
	return true


func is_module_built(module_id: String) -> bool:
	return unlocked_modules.get(module_id, false)


func is_lab_built() -> bool:
	return is_module_built("upgrade_lab")


## True once the module that unlocks `unit_class_id`'s queue has been built
## (i.e. whether `try_produce_module_unit(unit_class_id)` can ever succeed).
func is_unit_class_unlocked(unit_class_id: String) -> bool:
	return module_queues.has(unit_class_id)


# --- Upgrade-Labor / research -------------------------------------------------

## Queues `research_id` (one of `RESEARCH_CONFIG`'s keys) in the lab's
## research queue if the lab is built and the order is affordable.
func try_queue_research(research_id: String) -> bool:
	if not is_lab_built():
		return false
	var config: Dictionary = RESEARCH_CONFIG[research_id]
	if not ResourceManager.try_spend(team, config.cost):
		return false
	lab_queue.enqueue({
		"duration": config.duration,
		"unit_class_id": config.unit_class_id,
		"stat": config.stat,
		"bonus": config.bonus,
		"research_id": research_id,
	})
	return true


func _on_research_item_completed(item: Dictionary) -> void:
	UpgradeManager.apply_upgrade(team, item.get("unit_class_id"), item.get("stat"), item.get("bonus"))


func _on_research_item_cancelled(item: Dictionary) -> void:
	var config: Dictionary = RESEARCH_CONFIG[item.get("research_id")]
	ResourceManager.add(team, config.cost)


# --- Read-only state for the GUI -------------------------------------------

func get_resources() -> float:
	return ResourceManager.get_amount(team)


## Total passive income/sec: flat HQ income + this team's current
## territory share. Used by the HUD's real-time income readout.
func get_total_income_rate() -> float:
	var hq_income := hq.income_per_second if hq and hq.is_alive() else 0.0
	return hq_income + territory_income_rate


func get_hq_queue_size() -> int:
	return hq_queue.size()


## Read-only snapshot of `hq_queue.queue` for the GUI's queue visualizer.
func get_hq_queue() -> Array[Dictionary]:
	return hq_queue.queue


## Cancels the HQ queue item at `index`, refunding its cost.
func cancel_hq_queue_item(index: int) -> void:
	hq_queue.cancel_queue_item(index)


func get_module_queue_size(unit_class_id: String) -> int:
	var queue: TimedQueue = module_queues.get(unit_class_id)
	return queue.size() if queue else 0


func get_lab_queue_size() -> int:
	return lab_queue.size()


func can_afford_unit(unit_class_id: String) -> bool:
	return ResourceManager.can_afford(team, UNIT_CONFIG[unit_class_id].cost)


func can_afford_module(module_id: String) -> bool:
	return ResourceManager.can_afford(team, MODULE_CONFIG[module_id].cost)


func can_afford_research(research_id: String) -> bool:
	return ResourceManager.can_afford(team, RESEARCH_CONFIG[research_id].cost)
