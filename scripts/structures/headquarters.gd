extends Unit
class_name Headquarters
## Per-team win-condition building and economy anchor.
##
## Stationary and non-attacking: it exists purely as a destructible target
## that ends the match when reduced to 0 HP. It still lives in the regular
## team group so units auto-target it exactly like any other `Unit` (see
## `Unit._find_target_in_range()` — no special-case logic needed there).
##
## Also generates its team's passive base income (+`income_per_second`,
## starting immediately at t=0) for as long as it's alive — losing your HQ
## cuts off the economy, which is the intended stakes-raising side effect
## of destroying it even before the match-over HP-reaches-0 threshold.

signal hq_destroyed(team: Unit.Team)

@export var income_per_second: float = 5.0


func _ready() -> void:
	move_speed = 0.0
	attack_range = 0.0
	damage = 0.0
	vision_radius = 225.0
	if max_hp <= 0.0:
		max_hp = 1000.0
	super._ready()


func _process(delta: float) -> void:
	if is_alive():
		ResourceManager.add(team, income_per_second * delta)


## Overrides `Unit._physics_process()` (which unconditionally calls
## `move_and_slide()`) to a no-op. The HQ never moves, but calling
## `move_and_slide()` on a stationary `CharacterBody2D` still runs Godot's
## overlap-recovery step whenever another body intersects its collision
## shape — which was shoving the HQ itself away ("HQ dragging" glitch) any
## time a unit walked into it. Skipping physics entirely keeps the HQ's
## collision shape intact for combat/targeting while freezing its
## transform, exactly like `DummyUnit` already does.
func _physics_process(_delta: float) -> void:
	pass


func _die() -> void:
	hq_destroyed.emit(team)
	super._die()
