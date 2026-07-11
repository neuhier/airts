extends Unit
class_name DummyUnit
## Stationary target dummy used for the combat vertical slice.
##
## Never moves and never attacks back; it exists purely so the player unit
## has something to walk up to and auto-attack. Later this will be replaced
## by real enemy units / the HQ building.


func _physics_process(_delta: float) -> void:
	# Intentionally does nothing: no movement, no attacking.
	pass
