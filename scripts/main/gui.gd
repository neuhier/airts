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
const UNIT_TEXTURES := {
	"melee": preload("res://assets/ui/nieobie/unit-melee.svg"),
	"ranged": preload("res://assets/ui/nieobie/unit-ranged.svg"),
	"mobile": preload("res://assets/ui/nieobie/unit-mobile.svg"),
	"healer": preload("res://assets/ui/nieobie/unit-healer.svg"),
}
const QUEUE_TEXTURES := {
	"melee": preload("res://assets/ui/nieobie/unit-melee.svg"),
	"ranged": preload("res://assets/ui/nieobie/unit-ranged.svg"),
	"mobile": preload("res://assets/ui/nieobie/unit-mobile.svg"),
	"healer": preload("res://assets/ui/nieobie/unit-healer.svg"),
}
const RESEARCH_TEXTURE := preload("res://assets/ui/nieobie/module-upgrade.svg")
const RESOURCE_COIN_TEXTURE := preload("res://assets/ui/nieobie/resource-coin.svg")

var economy: EconomyController = null

@onready var _resource_label: Label = %ResourceLabel
@onready var _hq_button: Button = %HQProduceButton
@onready var _queue_visualizer: HBoxContainer = %QueueVisualizer
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
var _queue_signature := ""

@onready var _refresh_timer: Timer = %RefreshTimer


func _ready() -> void:
	%UnitMenuToggle.pressed.connect(_toggle_unit_menu)
	%ExtensionMenuToggle.pressed.connect(_toggle_extension_menu)
	_hq_button.pressed.connect(func(): economy.try_produce_hq_unit())
	for unit_class_id in _module_unit_buttons:
		var button: Button = _module_unit_buttons[unit_class_id]
		button.pressed.connect(func(): economy.try_produce_module_unit(unit_class_id))
	for module_id in _module_build_buttons:
		var button: Button = _module_build_buttons[module_id]
		button.pressed.connect(func(): economy.try_build_module(module_id))

	_build_research_buttons()

	_refresh_timer.timeout.connect(_refresh)
	$UnitPanel.visible = false
	$ExtensionPanel.visible = false


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventScreenTouch and event.pressed and event.position.x <= 32.0:
		_toggle_unit_menu()
		get_viewport().set_input_as_handled()
	elif event is InputEventScreenTouch and event.pressed and event.position.x >= get_viewport_rect().size.x - 32.0:
		_toggle_extension_menu()
		get_viewport().set_input_as_handled()


func _toggle_unit_menu() -> void:
	$UnitPanel.visible = not $UnitPanel.visible
	if $UnitPanel.visible:
		$ExtensionPanel.visible = false


func _toggle_extension_menu() -> void:
	$ExtensionPanel.visible = not $ExtensionPanel.visible
	if $ExtensionPanel.visible:
		$UnitPanel.visible = false


## Must be called once by whoever instantiates the GUI (see `main.gd`) to
## bind it to the player's economy state — mirrors `EconomyController.setup`.
func bind_economy(p_economy: EconomyController) -> void:
	economy = p_economy
	_refresh()
	_refresh_build_queue()


func _build_research_buttons() -> void:
	for research_id in EconomyController.RESEARCH_CONFIG:
		var button := Button.new()
		button.flat = true
		button.icon = RESEARCH_TEXTURE
		button.expand_icon = false
		button.pressed.connect(func(): economy.try_queue_research(research_id))
		_research_buttons_container.add_child(button)
		_research_buttons[research_id] = button


func _refresh() -> void:
	if economy == null:
		return

	_resource_label.text = "%.0f" % economy.get_resources()
	_refresh_build_queue()

	_refresh_hq_button()
	for unit_class_id in _module_unit_buttons:
		_refresh_module_unit_button(_module_unit_buttons[unit_class_id], unit_class_id)

	for module_id in _module_build_buttons:
		_refresh_module_button(module_id)

	for research_id in _research_buttons:
		_refresh_research_button(research_id)


## Rebuilds the queue-slot buttons (one per queued item) from scratch.
## Each button shows its unit-class icon and, when
## clicked, cancels that specific queue slot (refunding its cost).
func _refresh_build_queue() -> void:
	var queued_items := economy.get_all_unit_queue_items()
	var signature := str(queued_items)
	if signature == _queue_signature:
		return
	_queue_signature = signature
	for child in _queue_visualizer.get_children():
		child.queue_free()
	for queued_entry in queued_items:
		var item: Dictionary = queued_entry.item
		var unit_class_id: String = item.get("unit_class_id", "")
		var slot := Button.new()
		slot.flat = true
		slot.icon = QUEUE_TEXTURES.get(unit_class_id)
		slot.expand_icon = true
		slot.custom_minimum_size = Vector2(28, 28)
		slot.modulate.a = 0.75 if queued_entry.active else 0.25
		slot.tooltip_text = "%s — Klicken zum Abbrechen" % UNIT_LABELS.get(unit_class_id, unit_class_id)
		slot.pressed.connect(_on_queue_item_clicked.bind(queued_entry.queue_id, queued_entry.index))
		_queue_visualizer.add_child(slot)


func _on_queue_item_clicked(queue_id: String, index: int) -> void:
	economy.cancel_unit_queue_item(queue_id, index)


func _refresh_hq_button() -> void:
	var config: Dictionary = EconomyController.UNIT_CONFIG["melee"]
	_hq_button.disabled = not economy.can_afford_unit("melee")
	_set_button_price(_hq_button, config.cost)


func _refresh_module_unit_button(button: Button, unit_class_id: String) -> void:
	var config: Dictionary = EconomyController.UNIT_CONFIG[unit_class_id]
	var unlocked := economy.is_unit_class_unlocked(unit_class_id)
	button.disabled = not unlocked or not economy.can_afford_unit(unit_class_id)
	_set_button_price(button, config.cost)


func _refresh_module_button(module_id: String) -> void:
	var button: Button = _module_build_buttons[module_id]
	var config: Dictionary = EconomyController.MODULE_CONFIG[module_id]
	if economy.is_module_built(module_id):
		button.text = "✓"
		button.disabled = true
		_hide_button_price(button)
	else:
		button.text = ""
		button.disabled = not economy.can_afford_module(module_id)
		_set_button_price(button, config.cost)
	button.tooltip_text = config.label


func _refresh_research_button(research_id: String) -> void:
	var button: Button = _research_buttons[research_id]
	var config: Dictionary = EconomyController.RESEARCH_CONFIG[research_id]
	var lab_built := economy.is_lab_built()
	var status := ""
	if lab_built and economy.get_lab_queue_size() > 0:
		status = " [Wartet...]"
	button.text = ""
	button.tooltip_text = config.label
	button.disabled = not lab_built or not economy.can_afford_research(research_id)
	_set_button_price(button, config.cost, status != "")


func _set_button_price(button: Button, amount: float, is_waiting := false) -> void:
	var price_display := button.get_node_or_null("PriceDisplay") as HBoxContainer
	if price_display == null:
		price_display = HBoxContainer.new()
		price_display.name = "PriceDisplay"
		price_display.mouse_filter = Control.MOUSE_FILTER_IGNORE
		price_display.alignment = BoxContainer.ALIGNMENT_CENTER
		price_display.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
		price_display.position = Vector2(-30.0, -18.0)
		price_display.size = Vector2(60.0, 16.0)

		var coin := TextureRect.new()
		coin.name = "CoinIcon"
		coin.custom_minimum_size = Vector2(12.0, 12.0)
		coin.texture = RESOURCE_COIN_TEXTURE
		coin.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		coin.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		coin.mouse_filter = Control.MOUSE_FILTER_IGNORE
		price_display.add_child(coin)

		var label := Label.new()
		label.name = "Amount"
		label.add_theme_font_size_override("font_size", 12)
		label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		price_display.add_child(label)
		button.add_child(price_display)
		button.mouse_entered.connect(_set_price_visibility.bind(button, true))
		button.mouse_exited.connect(_set_price_visibility.bind(button, false))

	var amount_label := price_display.get_node("Amount") as Label
	amount_label.text = "%.0f%s" % [amount, " …" if is_waiting else ""]
	price_display.modulate.a = 0.45 if button.disabled else 1.0
	price_display.visible = button.is_hovered()


func _hide_button_price(button: Button) -> void:
	var price_display := button.get_node_or_null("PriceDisplay") as HBoxContainer
	if price_display:
		price_display.visible = false


func _set_price_visibility(button: Button, is_visible: bool) -> void:
	var price_display := button.get_node_or_null("PriceDisplay") as HBoxContainer
	if price_display:
		price_display.visible = is_visible
