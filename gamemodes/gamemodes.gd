class_name GameModes
extends RefCounted

const MODE_TDM: String = "tdm"
const MODE_DM: String = "dm"
const MODE_BO5: String = "bo5"
const DEFAULT_MODE: String = MODE_TDM

## Ordered list of all registered game mode instances
static var _modes: Dictionary = {}

static func _init_modes() -> void:
	if not _modes.is_empty():
		return
	var tdm = TeamDeathmatchMode.new()
	var dm = DeathmatchMode.new()
	var bo5 = BestOfFiveMode.new()
	_modes[MODE_TDM] = tdm
	_modes[MODE_DM] = dm
	_modes[MODE_BO5] = bo5

## Retrieve a GameMode instance by identifier (e.g. "tdm", "dm", "bo5")
static func get_mode(mode_id: String) -> GameMode:
	_init_modes()
	if _modes.has(mode_id):
		return _modes[mode_id]
	return _modes[DEFAULT_MODE]

## Return array of all GameMode instances in UI order
static func get_all_modes() -> Array[GameMode]:
	_init_modes()
	var list: Array[GameMode] = [
		_modes[MODE_TDM],
		_modes[MODE_DM],
		_modes[MODE_BO5]
	]
	return list

## Check if a mode_id string is valid
static func is_valid_mode(mode_id: String) -> bool:
	_init_modes()
	return _modes.has(mode_id)

## Returns option info for populating UI OptionButtons: Array of { "id": String, "label": String, "index": int }
static func get_ui_options() -> Array[Dictionary]:
	return [
		{"id": MODE_TDM, "label": "Team Deathmatch (3v3v3)", "index": 0},
		{"id": MODE_DM, "label": "Deathmatch (Free For All)", "index": 1},
		{"id": MODE_BO5, "label": "Best of Five (3v3v3)", "index": 2}
	]

## Convert an OptionButton index to a mode identifier
static func get_mode_id_from_index(index: int) -> String:
	match index:
		1:
			return MODE_DM
		2:
			return MODE_BO5
		_:
			return MODE_TDM

## Convert a mode identifier to OptionButton index
static func get_index_from_mode_id(mode_id: String) -> int:
	match mode_id:
		MODE_DM:
			return 1
		MODE_BO5:
			return 2
		_:
			return 0
