extends Node2D
## Root of the combat vertical slice.
##
## Wires up debug logging for the target dummy so combat is observable in
## the console (useful for headless/automated verification and for
## eyeballing damage numbers during playtesting before a real HUD exists).
## Also owns match-end handling: once either HQ is destroyed, the match is
## paused and the winner is logged. Instantiates the player's
## `EconomyController` and binds the GUI overlay to it. The Enemy team
## gets its own `EconomyController` plus an `EnemyAiController` driving it
## — the Enemy is always AI-controlled, there is no PvP/second-player mode.

const DUMMY_UNIT_SCENE := preload("res://scenes/units/dummy_unit.tscn")

@onready var _player_hq: Headquarters = get_node_or_null("PlayerHQ")
@onready var _enemy_hq: Headquarters = get_node_or_null("EnemyHQ")
@onready var _gui: GameGUI = get_node_or_null("GUILayer/GUI")

var _dummy: Unit = null
var _match_over: bool = false
var player_economy: EconomyController = null
var enemy_economy: EconomyController = null


func _ready() -> void:
	_dummy = _spawn_dummy_unit()
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


## Instantiates the target dummy at runtime (rather than in main.tscn) so
## this scene keeps working even if the dummy is ever removed from the
## saved scene file. Falls back to a bare CharacterBody2D + script if the
## packed scene is missing, and guarantees a visible placeholder either way.
func _spawn_dummy_unit() -> Unit:
	var dummy: Unit
	if DUMMY_UNIT_SCENE:
		dummy = DUMMY_UNIT_SCENE.instantiate()
	else:
		dummy = CharacterBody2D.new()
		dummy.set_script(load("res://scripts/units/dummy_unit.gd"))

	if not dummy.get_node_or_null("Silhouette") and not dummy.get_node_or_null("Placeholder"):
		var placeholder := ColorRect.new()
		placeholder.name = "Placeholder"
		placeholder.color = Color(1, 0, 0, 1)
		placeholder.size = Vector2(32, 32)
		placeholder.position = Vector2(-16, -16)
		placeholder.z_index = 10
		dummy.add_child(placeholder)

	add_child(dummy)
	dummy.global_position = Vector2(400, 300)
	return dummy


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
