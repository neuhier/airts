extends RefCounted
class_name ResourceManager
## Global per-team resource economy.
##
## Implemented as a set of `static` members on a `RefCounted` class rather
## than an autoload singleton: it's reachable as `ResourceManager.foo()` from
## anywhere (Unit, EconomyController, GUI, headless verify scripts) without
## needing a node reference threaded through every caller, and it works
## identically whether the game runs via `main.tscn` or a bare
## `--script res://some_test.gd` SceneTree (no autoload-registration timing
## to worry about).

static var _amounts: Dictionary = {}


static func get_amount(team: Unit.Team) -> float:
	return _amounts.get(team, 0.0)


## Adds (or subtracts, for negative amounts) resources unconditionally.
## Used for passive income; ignores affordability by design.
static func add(team: Unit.Team, amount: float) -> void:
	_amounts[team] = get_amount(team) + amount


## Attempts to deduct `amount` from `team`'s account. Returns false (and
## leaves the balance untouched) if the team can't afford it.
static func try_spend(team: Unit.Team, amount: float) -> bool:
	if get_amount(team) < amount:
		return false
	_amounts[team] = get_amount(team) - amount
	return true


static func can_afford(team: Unit.Team, amount: float) -> bool:
	return get_amount(team) >= amount


## Clears all balances. Only meant for starting a fresh match / headless
## test isolation between cases — normal gameplay never needs to call this.
static func reset() -> void:
	_amounts = {}
