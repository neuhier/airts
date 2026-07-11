extends RefCounted
class_name UpgradeManager
## Tracks permanent, global per-team-per-class stat multipliers unlocked via
## the Upgrade-Labor research queue.
##
## Static-only, same rationale as `ResourceManager` (see there): reachable
## from anywhere without threading a node reference through every caller.
## `Unit` reads these multipliers once in `_ready()` (as its "baseline" for
## units produced after the research completes) and `UpgradeManager` also
## pushes the multiplier retroactively onto every currently-alive unit of
## that class/team when a research completes (see `apply_upgrade`).

enum StatType { DAMAGE, HP, SPEED }

## unit_class_id (String, e.g. "melee") -> StatType -> multiplier (float).
## Missing entries default to 1.0 (no bonus).
static var _multipliers: Dictionary = {}


static func _key(team: Unit.Team, unit_class_id: String, stat: StatType) -> String:
	return "%d:%s:%d" % [team, unit_class_id, stat]


static func get_multiplier(team: Unit.Team, unit_class_id: String, stat: StatType) -> float:
	return _multipliers.get(_key(team, unit_class_id, stat), 1.0)


## Called once a research order finishes. Bumps the stored multiplier by
## `bonus_fraction` (e.g. 0.2 for +20%) and immediately re-applies the new
## multiplier to every currently-alive unit of `unit_class_id` on `team` —
## this is what makes the upgrade retroactive instead of only affecting
## units produced afterwards.
static func apply_upgrade(team: Unit.Team, unit_class_id: String, stat: StatType, bonus_fraction: float) -> void:
	var key := _key(team, unit_class_id, stat)
	var new_multiplier: float = _multipliers.get(key, 1.0) * (1.0 + bonus_fraction)
	_multipliers[key] = new_multiplier
	_reapply_to_existing_units(team, unit_class_id, stat, new_multiplier)


static func _reapply_to_existing_units(team: Unit.Team, unit_class_id: String, stat: StatType, multiplier: float) -> void:
	# `get_nodes_in_group` requires a SceneTree; fetch it from the main loop
	# so this static function doesn't need a Node/tree reference threaded in.
	var tree := Engine.get_main_loop() as SceneTree
	if tree == null:
		return
	var group_name := "team_player" if team == Unit.Team.PLAYER else "team_enemy"
	for node in tree.get_nodes_in_group(group_name):
		if node is Unit and node.unit_class_id == unit_class_id:
			node.apply_stat_multiplier(stat, multiplier)


## Clears all multipliers. Only meant for headless test isolation between
## cases — normal gameplay never needs to call this.
static func reset() -> void:
	_multipliers = {}
