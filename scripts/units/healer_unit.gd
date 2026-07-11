extends Unit
class_name HealerUnit
## Healer class: currently a pure stat variant (no actual healing ability
## yet — that lands in a later milestone). Behaves exactly like any other
## `Unit`: auto-targets and auto-attacks enemies in range like the other
## classes, so it's still useful in a fight while the race-specific support
## ability is pending.


func _ready() -> void:
	# Healer-specific defaults; still overridable per-instance in the editor.
	if attack_range <= 0.0:
		attack_range = 90.0
	unit_class_id = "healer"
	super._ready()
