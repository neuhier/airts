extends Node
## Autoload singleton (see project.godot [autoload]) — the global balance
## database. Seeds a mutable `user://balance.json` from the checked-in
## `res://data/balance_default.json` template on first run, then reads all
## tunable numbers (unit stats, building costs, global constants) from
## that local copy for the rest of the session.

const TEMPLATE_PATH := "res://data/balance_default.json"
const USER_PATH := "user://balance.json"

var _data: Dictionary = {}


func _ready() -> void:
	_ensure_user_file_exists()
	_load_from_user_file()


## Copies the packed template into user:// on first run only. `res://` is
## read-only once exported, so the template itself is never modified.
func _ensure_user_file_exists() -> void:
	if FileAccess.file_exists(USER_PATH):
		return
	var template := FileAccess.open(TEMPLATE_PATH, FileAccess.READ)
	if template == null:
		push_error("BalanceManager: could not open template at %s (err %d)" % [TEMPLATE_PATH, FileAccess.get_open_error()])
		return
	var contents := template.get_as_text()
	template.close()

	var user_file := FileAccess.open(USER_PATH, FileAccess.WRITE)
	if user_file == null:
		push_error("BalanceManager: could not create %s (err %d)" % [USER_PATH, FileAccess.get_open_error()])
		return
	user_file.store_string(contents)
	user_file.close()


## Parses `user://balance.json` into `_data`. Falls back to parsing the
## read-only template directly (in-memory only, no write-back) on any
## failure, so a corrupted user file degrades to defaults instead of
## crashing.
func _load_from_user_file() -> void:
	var file := FileAccess.open(USER_PATH, FileAccess.READ)
	if file == null:
		push_error("BalanceManager: could not open %s (err %d) — falling back to template." % [USER_PATH, FileAccess.get_open_error()])
		_load_from_template()
		return

	var text := file.get_as_text()
	file.close()

	var json := JSON.new()
	var parse_error := json.parse(text)
	if parse_error != OK:
		push_error("BalanceManager: malformed JSON in %s at line %d: %s — falling back to template." % [USER_PATH, json.get_error_line(), json.get_error_message()])
		_load_from_template()
		return

	if typeof(json.data) != TYPE_DICTIONARY:
		push_error("BalanceManager: %s did not parse to a Dictionary — falling back to template." % USER_PATH)
		_load_from_template()
		return

	_data = json.data as Dictionary


func _load_from_template() -> void:
	var template := FileAccess.open(TEMPLATE_PATH, FileAccess.READ)
	if template == null:
		push_error("BalanceManager: could not open fallback template at %s (err %d) — balance data unavailable." % [TEMPLATE_PATH, FileAccess.get_open_error()])
		_data = {}
		return
	var text := template.get_as_text()
	template.close()

	var json := JSON.new()
	if json.parse(text) != OK or typeof(json.data) != TYPE_DICTIONARY:
		push_error("BalanceManager: fallback template at %s is also malformed — balance data unavailable." % TEMPLATE_PATH)
		_data = {}
		return
	_data = json.data as Dictionary


## Global mechanic value (e.g. "territory_income_pool"). Returns
## `default_value` if the "global" section or the field is missing.
func get_global_value(field: String, default_value: Variant = null) -> Variant:
	var section: Dictionary = _data.get("global", {})
	return section.get(field, default_value)


## Per-unit-class metric (e.g. get_unit_value("melee", "damage", 10.0)).
## Returns `default_value` if the "units" section, the unit_class_id, or
## the field is missing.
func get_unit_value(unit_class_id: String, field: String, default_value: Variant = null) -> Variant:
	var units: Dictionary = _data.get("units", {})
	var entry: Dictionary = units.get(unit_class_id, {})
	return entry.get(field, default_value)


## Per-building metric (e.g. get_building_value("upgrade_lab", "cost", 150.0)).
## Returns `default_value` if the "buildings" section, the building_id, or
## the field is missing.
func get_building_value(building_id: String, field: String, default_value: Variant = null) -> Variant:
	var buildings: Dictionary = _data.get("buildings", {})
	var entry: Dictionary = buildings.get(building_id, {})
	return entry.get(field, default_value)


## Per-research-order metric (e.g. get_research_value("melee_damage", "cost", 100.0)).
## Returns `default_value` if the "research" section, the research_id, or
## the field is missing. Only cost/duration are externalized here — the
## stat/bonus/unit_class_id fields stay in `RESEARCH_CONFIG` since they
## define *what* the research does, not a tunable balance number.
func get_research_value(research_id: String, field: String, default_value: Variant = null) -> Variant:
	var research: Dictionary = _data.get("research", {})
	var entry: Dictionary = research.get(research_id, {})
	return entry.get(field, default_value)
