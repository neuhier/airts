extends Node2D
class_name TouchInputController
## Selection + move-command controller for the vertical slice.
##
## Single tap on an own unit selects just that unit (replacing any previous
## selection). Double-tap on an own unit (same unit, within a short time and
## distance window) selects nearby own units of the same type. A single tap
## on empty ground moves the current selection; double-tapping empty ground
## clears it. Tapping
## directly on an enemy unit or the enemy HQ instead sends the selection
## into a focus-fire order on that specific target, overriding automatic
## nearest-target acquisition. Tapping with no selection has no effect.
## Enemy units and both HQs are never selectable or directly movable
## (though the enemy HQ can be focus-fired, see above).

## Screen-space hit radius (world units) for "did this tap land on a unit".
@export var selection_tap_radius: float = 24.0
## Time window for a second tap on the same unit to count as a double-tap.
@export var double_tap_window: float = 0.3
## Max screen-space distance (px) between the two taps of a double-tap.
@export var double_tap_max_distance: float = 20.0
## World-space radius around the double-tapped unit for group selection.
@export var group_select_radius: float = 150.0

var selected_units: Array[Unit] = []

var _last_tap_unit: Unit = null
var _last_tap_screen_position: Vector2 = Vector2.ZERO
var _last_tap_time: float = -INF
var _last_empty_tap_screen_position: Vector2 = Vector2.ZERO
var _last_empty_tap_time: float = -INF


func _unhandled_input(event: InputEvent) -> void:
	var tap_position: Variant = _tap_screen_position(event)
	if tap_position == null:
		return
	_handle_tap(tap_position)


## Returns the screen position of a completed tap/click, or null if the
## event is not a "press" we care about. Supports both real touch input
## (mobile/tablet) and mouse clicks (editor/desktop testing).
func _tap_screen_position(event: InputEvent) -> Variant:
	if event is InputEventScreenTouch and event.pressed:
		return event.position
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		return event.position
	return null


## Converts a raw screen/viewport position into world space, taking the
## active Camera2D's position/zoom into account (canvas_transform already
## reflects whichever camera is currently active).
func _screen_to_world(screen_position: Vector2) -> Vector2:
	return get_viewport().canvas_transform.affine_inverse() * screen_position


func _handle_tap(screen_position: Vector2) -> void:
	var world_position := _screen_to_world(screen_position)
	var tapped_unit := _find_own_unit_at(world_position)

	if tapped_unit:
		if _is_double_tap(tapped_unit, screen_position):
			_select_matching_units_around(tapped_unit)
		else:
			_select_single(tapped_unit)
		_last_tap_unit = tapped_unit
		_last_tap_screen_position = screen_position
		_last_tap_time = _now()
		_last_empty_tap_time = -INF
		return

	# Enemy targets keep their focus-fire behavior when there is an active
	# selection. The second empty-map tap of a double-tap clears selection;
	# otherwise an empty-map tap issues the usual move command.
	_last_tap_unit = null
	_last_tap_time = -INF
	var tapped_enemy := _find_enemy_unit_at(world_position)
	if tapped_enemy and not selected_units.is_empty():
		_last_empty_tap_time = -INF
		_command_selected_units_to_attack(tapped_enemy)
		return
	if _is_empty_map_double_tap(screen_position):
		_set_selection([])
		_last_empty_tap_time = -INF
		return
	_last_empty_tap_screen_position = screen_position
	_last_empty_tap_time = _now()
	if not selected_units.is_empty():
		_command_selected_units_to(world_position)


func _is_double_tap(tapped_unit: Unit, screen_position: Vector2) -> bool:
	if tapped_unit != _last_tap_unit:
		return false
	if _now() - _last_tap_time > double_tap_window:
		return false
	return screen_position.distance_to(_last_tap_screen_position) <= double_tap_max_distance


func _is_empty_map_double_tap(screen_position: Vector2) -> bool:
	if _now() - _last_empty_tap_time > double_tap_window:
		return false
	return screen_position.distance_to(_last_empty_tap_screen_position) <= double_tap_max_distance


func _now() -> float:
	return Time.get_ticks_msec() / 1000.0


## Returns the nearest own, alive, selectable unit within
## `selection_tap_radius` of the given world position, or null.
## "Own" = member of the "team_player" group; HQs are explicitly excluded
## from selection even though they share the team group for targeting
## purposes.
func _find_own_unit_at(world_position: Vector2) -> Unit:
	var nearest: Unit = null
	var nearest_dist := INF
	for node in get_tree().get_nodes_in_group("team_player"):
		if node is Headquarters:
			continue
		if node is Unit and node.is_alive():
			var dist := world_position.distance_to(node.global_position)
			if dist <= selection_tap_radius and dist < nearest_dist:
				nearest = node
				nearest_dist = dist
	return nearest


## Returns the nearest alive enemy unit (including the enemy HQ) within
## `selection_tap_radius` of the given world position, or null. Unlike
## `_find_own_unit_at`, HQs are intentionally included here — the player
## can directly focus-fire the enemy HQ.
func _find_enemy_unit_at(world_position: Vector2) -> Unit:
	var nearest: Unit = null
	var nearest_dist := INF
	for node in get_tree().get_nodes_in_group("team_enemy"):
		if node is Unit and node.is_alive():
			var dist := world_position.distance_to(node.global_position)
			if dist <= selection_tap_radius and dist < nearest_dist:
				nearest = node
				nearest_dist = dist
	return nearest


func _select_single(unit: Unit) -> void:
	_set_selection([unit])


func _select_matching_units_around(center_unit: Unit) -> void:
	var group: Array[Unit] = []
	var unit_script: Script = center_unit.get_script()
	for node in get_tree().get_nodes_in_group("team_player"):
		if node is Headquarters:
			continue
		if node is Unit and node.is_alive():
			if node.get_script() == unit_script and node.global_position.distance_to(center_unit.global_position) <= group_select_radius:
				group.append(node)
	_set_selection(group)


func _set_selection(units: Array[Unit]) -> void:
	for unit in selected_units:
		if is_instance_valid(unit):
			unit.set_selected(false)
	selected_units = units
	for unit in selected_units:
		unit.set_selected(true)


func _command_selected_units_to(world_position: Vector2) -> void:
	for unit in selected_units:
		if is_instance_valid(unit) and unit.is_alive():
			unit.set_move_target(world_position)


func _command_selected_units_to_attack(target_unit: Unit) -> void:
	for unit in selected_units:
		if is_instance_valid(unit) and unit.is_alive():
			unit.attack_target(target_unit)
