extends Unit
class_name MobileUnit
## Mobile class: fast, melee-range harasser. Pure stat variant of the base
## `Unit` — no special behaviour needed.


func _ready() -> void:
	# Mobile-specific defaults; still overridable per-instance in the editor.
	if attack_range <= 0.0:
		attack_range = 40.0
	unit_class_id = "mobile"
	super._ready()
