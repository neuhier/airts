extends Node2D
## Root of the combat vertical slice.
##
## Owns match-end handling: once either HQ is destroyed, the match is
## paused and the winner is logged. Instantiates the player's
## `EconomyController` and binds the GUI overlay to it. The Enemy team
## gets its own `EconomyController` plus an `EnemyAiController` driving it
## — the Enemy is always AI-controlled, there is no PvP/second-player mode.

@onready var _player_hq: Headquarters = get_node_or_null("PlayerHQ")
@onready var _enemy_hq: Headquarters = get_node_or_null("EnemyHQ")
@onready var _gui: GameGUI = get_node_or_null("GUILayer/GUI")

var _match_over: bool = false
var player_economy: EconomyController = null
var enemy_economy: EconomyController = null


func _ready() -> void:
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

	# Enemy gets its own controller too so it collects territory-based
	# passive income symmetrically. It never queues production (nothing
	# calls try_produce_*/try_build_module/try_queue_research on it), so
	# this is purely the income side, matching current scope.
	if _enemy_hq:
		enemy_economy = EconomyController.new()
		add_child(enemy_economy)
		enemy_economy.setup(Unit.Team.ENEMY, _enemy_hq)

		# The Enemy team is always AI-controlled — there is no way to play
		# as Enemy in this build, so wiring the AI here (rather than as an
		# optional node in main.tscn) guarantees every match has an active
		# opponent instead of a passive one.
		var enemy_ai := EnemyAiController.new()
		add_child(enemy_ai)
		enemy_ai.enemy_economy = enemy_economy


func _on_hq_destroyed(team: Unit.Team) -> void:
	if _match_over:
		return
	_match_over = true
	var winning_team_name := "Enemy" if team == Unit.Team.PLAYER else "Player"
	print("Match Over — Team %s wins" % winning_team_name)
	get_tree().paused = true
