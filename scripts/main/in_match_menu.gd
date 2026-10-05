extends Control
class_name InMatchMenu

signal open_changed(is_open: bool)

var is_open := false

func toggle() -> void:
	is_open = not is_open
	visible = is_open
	open_changed.emit(is_open)
