extends Node2D
## Root of the combat vertical slice.
##
## Wires up debug logging for the target dummy so combat is observable in
## the console (useful for headless/automated verification and for
## eyeballing damage numbers during playtesting before a real HUD exists).
## Also owns match-end handling: once either HQ is destroyed, the match is
## paused and the winner is logged. Instantiates the player's
## `EconomyController` (the enemy stays passive — HQ income only, no
## production — per current scope) and binds the GUI overlay to it.

@onready var _dummy: Unit = get_node_or_null("DummyUnit")
@onready var _player_hq: Headquarters = get_node_or_null("PlayerHQ")
@onready var _enemy_hq: Headquarters = get_node_or_null("EnemyHQ")
@onready var _gui: GameGUI = get_node_or_null("GUI")

var _match_over: bool = false
var player_economy: EconomyController = null


func _ready() -> void:
	if _dummy:
		_dummy.hp_changed.connect(_on_dummy_hp_changed)
		_dummy.died.connect(_on_dummy_died)
	if _player_hq:
		_player_hq.hq_destroyed.connect(_on_hq_destroyed)
	if _enemy_hq:
		_enemy_hq.hq_destroyed.connect(_on_hq_destroyed)

	if _player_hq:
		player_economy = EconomyController.new()
		add_child(player_economy)
		player_economy.setup(Unit.Team.PLAYER, _player_hq)
		if _gui:
			_gui.bind_economy(player_economy)


func _on_dummy_hp_changed(_unit: Unit, hp: float, max_hp: float) -> void:
	print("Dummy HP: %.0f / %.0f" % [hp, max_hp])


func _on_dummy_died(_unit: Unit) -> void:
	print("Dummy destroyed.")


func _on_hq_destroyed(team: Unit.Team) -> void:
	if _match_over:
		return
	_match_over = true
	var winning_team_name := "Enemy" if team == Unit.Team.PLAYER else "Player"
	print("Match Over — Team %s wins" % winning_team_name)
	get_tree().paused = true
