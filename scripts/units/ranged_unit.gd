extends Unit
class_name RangedUnit
## Ranged class: long attack range, low HP/damage. Stands still and fires
## once a target enters range — this is already the base `Unit` behaviour
## (`velocity = ZERO` while a target is in `attack_range`), so no new
## `_physics_process` logic is needed here; the long range alone produces
## the ranged playstyle.


func _ready() -> void:
	# Ranged-specific defaults; still overridable per-instance in the editor.
	if attack_range <= 0.0:
		attack_range = 160.0
	super._ready()
