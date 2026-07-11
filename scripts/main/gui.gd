extends Control
class_name GameGUI
## Minimal economy HUD for the player: resource readout, unit-production
## buttons (HQ melee + unlocked module queues), module-build buttons, and
## the Upgrade-Labor's research buttons.
##
## Polls `EconomyController` on a short timer rather than reacting to every
## individual signal — the number of read-only bits (resources, per-queue
## sizes, unlock flags) is small and this keeps the button-state logic in
## one place instead of scattered across a dozen signal handlers.

const UNIT_LABELS := {
	"melee": "Melee",
	"ranged": "Ranged",
	"mobile": "Mobile",
	"healer": "Healer",
}

## Module id -> the human-facing verb shown before it's built.
const MODULE_BUILD_LABELS := {
	"ranged_module": "Schützen-Anbau bauen",
	"mobile_module": "Fuhrpark bauen",
	"healer_module": "Heiler-Heiligtum bauen",
	"upgrade_lab": "Upgrade-Labor bauen",
}

var economy: EconomyController = null

@onready var _resource_label: Label = %ResourceLabel
@onready var _hq_button: Button = %HQProduceButton
@onready var _module_unit_buttons: Dictionary = {
	"ranged": %RangedProduceButton,
	"mobile": %MobileProduceButton,
	"healer": %HealerProduceButton,
}
@onready var _module_build_buttons: Dictionary = {
	"ranged_module": %RangedModuleButton,
	"mobile_module": %MobileModuleButton,
	"healer_module": %HealerModuleButton,
	"upgrade_lab": %UpgradeLabButton,
}
@onready var _research_buttons_container: GridContainer = %ResearchButtonsContainer

var _research_buttons: Dictionary = {}

@onready var _refresh_timer: Timer = %RefreshTimer


func _ready() -> void:
	_hq_button.pressed.connect(func(): economy.try_produce_hq_unit())
	for unit_class_id in _module_unit_buttons:
		var button: Button = _module_unit_buttons[unit_class_id]
		button.pressed.connect(func(): economy.try_produce_module_unit(unit_class_id))
	for module_id in _module_build_buttons:
		var button: Button = _module_build_buttons[module_id]
		button.pressed.connect(func(): economy.try_build_module(module_id))

	_build_research_buttons()

	_refresh_timer.timeout.connect(_refresh)


## Must be called once by whoever instantiates the GUI (see `main.gd`) to
## bind it to the player's economy state — mirrors `EconomyController.setup`.
func bind_economy(p_economy: EconomyController) -> void:
	economy = p_economy
	_refresh()


func _build_research_buttons() -> void:
	for research_id in EconomyController.RESEARCH_CONFIG:
		var button := Button.new()
		button.pressed.connect(func(): economy.try_queue_research(research_id))
		_research_buttons_container.add_child(button)
		_research_buttons[research_id] = button


func _refresh() -> void:
	if economy == null:
		return

	_resource_label.text = "Ressourcen: %.0f" % economy.get_resources()

	_refresh_hq_button()
	for unit_class_id in _module_unit_buttons:
		_refresh_module_unit_button(_module_unit_buttons[unit_class_id], unit_class_id)

	for module_id in _module_build_buttons:
		_refresh_module_button(module_id)

	for research_id in _research_buttons:
		_refresh_research_button(research_id)


func _refresh_hq_button() -> void:
	var config: Dictionary = EconomyController.UNIT_CONFIG["melee"]
	_hq_button.text = "%s (%.0f) [x%d]" % [UNIT_LABELS["melee"], config.cost, economy.get_hq_queue_size()]
	_hq_button.disabled = not economy.can_afford_unit("melee")


func _refresh_module_unit_button(button: Button, unit_class_id: String) -> void:
	var config: Dictionary = EconomyController.UNIT_CONFIG[unit_class_id]
	var unlocked := economy.is_unit_class_unlocked(unit_class_id)
	var queue_size := economy.get_module_queue_size(unit_class_id) if unlocked else 0
	if unlocked:
		button.text = "%s (%.0f) [x%d]" % [UNIT_LABELS[unit_class_id], config.cost, queue_size]
	else:
		button.text = "%s: [Inaktiv]" % UNIT_LABELS[unit_class_id]
	button.disabled = not unlocked or not economy.can_afford_unit(unit_class_id)


func _refresh_module_button(module_id: String) -> void:
	var button: Button = _module_build_buttons[module_id]
	var config: Dictionary = EconomyController.MODULE_CONFIG[module_id]
	if economy.is_module_built(module_id):
		button.text = "%s: [Aktiv]" % config.label
		button.disabled = true
	else:
		button.text = "%s (%.0f)" % [MODULE_BUILD_LABELS[module_id], config.cost]
		button.disabled = not economy.can_afford_module(module_id)


func _refresh_research_button(research_id: String) -> void:
	var button: Button = _research_buttons[research_id]
	var config: Dictionary = EconomyController.RESEARCH_CONFIG[research_id]
	var lab_built := economy.is_lab_built()
	var status := ""
	if lab_built and economy.get_lab_queue_size() > 0:
		status = " [Wartet...]"
	button.text = "%s%s" % [config.label, status]
	button.disabled = not lab_built or not economy.can_afford_research(research_id)
