extends Unit
class_name MeleeUnit
## Basic melee class: short range, high(er) damage. Player-controlled units
## in the vertical slice use this class; the touch controller commands its
## `move_target` directly via `Unit.set_move_target()`.


func _ready() -> void:
	# Melee-specific defaults; still overridable per-instance in the editor.
	if attack_range <= 0.0:
		attack_range = 48.0
	super._ready()
