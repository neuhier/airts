extends Unit
class_name Headquarters
## Per-team win-condition building.
##
## Stationary and non-attacking: it exists purely as a destructible target
## that ends the match when reduced to 0 HP. It still lives in the regular
## team group so units auto-target it exactly like any other `Unit` (see
## `Unit._find_target_in_range()` — no special-case logic needed there).

signal hq_destroyed(team: Unit.Team)


func _ready() -> void:
	move_speed = 0.0
	attack_range = 0.0
	damage = 0.0
	if max_hp <= 0.0:
		max_hp = 1000.0
	super._ready()


func _die() -> void:
	hq_destroyed.emit(team)
	super._die()
