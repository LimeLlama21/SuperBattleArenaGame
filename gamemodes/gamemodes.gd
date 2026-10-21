class_name GameModes
extends RefCounted

const EnabledModesClass = preload("res://gamemodes/enabled_modes.gd")

const MODE_TDM: String = "tdm"
const MODE_DM: String = "dm"
const MODE_BO5: String = "bo5"
const MODE_TRAINS: String = "trains"
const DEFAULT_MODE: String = MODE_TDM

const TeamDeathmatchModeClass = preload("res://gamemodes/team_deathmatch.gd")
const DeathmatchModeClass = preload("res://gamemodes/deathmatch.gd")
const BestOfFiveModeClass = preload("res://gamemodes/best_of_five.gd")
const TrainsModeClass = preload("res://gamemodes/trains.gd")

const MODE_ORDER: Array[String] = [
	MODE_TDM,
	MODE_DM,
	MODE_BO5,
	MODE_TRAINS
]

const MODE_LABELS: Dictionary = {
	MODE_TDM: "Team Deathmatch (3v3v3)",
	MODE_DM: "Deathmatch (Free For All)",
	MODE_BO5: "Best of Five (3v3v3)",
	MODE_TRAINS: "Trains (3v3v3)"
}

## Ordered list of all registered game mode instances
static var _modes: Dictionary = {}

static func _init_modes() -> void:
	if not _modes.is_empty():
		return
	var tdm = TeamDeathmatchModeClass.new()
	var dm = DeathmatchModeClass.new()
	var bo5 = BestOfFiveModeClass.new()
	var trains = TrainsModeClass.new()
	_modes[MODE_TDM] = tdm
	_modes[MODE_DM] = dm
	_modes[MODE_BO5] = bo5
	_modes[MODE_TRAINS] = trains

## Retrieve a GameMode instance by identifier (e.g. "tdm", "dm", "bo5", "trains")
static func get_mode(mode_id: String) -> GameMode:
	_init_modes()
	if _modes.has(mode_id):
		return _modes[mode_id]
	return _modes[DEFAULT_MODE]

## Return array of all registered GameMode instances in UI order
static func get_all_modes() -> Array[GameMode]:
	_init_modes()
	var list: Array[GameMode] = [
		_modes[MODE_TDM],
		_modes[MODE_DM],
		_modes[MODE_BO5],
		_modes[MODE_TRAINS]
	]
	return list

## Return array of all enabled GameMode instances in UI order
static func get_enabled_modes() -> Array[GameMode]:
	_init_modes()
	var list: Array[GameMode] = []
	for opt in get_ui_options():
		if _modes.has(opt["id"]):
			list.append(_modes[opt["id"]])
	return list

## Check if a mode_id string is valid
static func is_valid_mode(mode_id: String) -> bool:
	_init_modes()
	return _modes.has(mode_id)

## Check if a mode_id string is enabled
static func is_mode_enabled(mode_id: String) -> bool:
	return EnabledModesClass.is_mode_enabled(mode_id)

## Returns option info for populating UI OptionButtons: Array of { "id": String, "label": String, "index": int }
## Dynamically excludes any modes that are disabled in EnabledModes.
static func get_ui_options() -> Array[Dictionary]:
	_init_modes()
	var options: Array[Dictionary] = []
	var enabled_ids = EnabledModesClass.get_enabled_modes()
	var idx = 0
	for mode_id in MODE_ORDER:
		if enabled_ids.has(mode_id):
			var label_str = MODE_LABELS.get(mode_id, mode_id)
			options.append({
				"id": mode_id,
				"label": label_str,
				"index": idx
			})
			idx += 1
	return options

## Convert an OptionButton index to a mode identifier
static func get_mode_id_from_index(index: int) -> String:
	var opts = get_ui_options()
	for opt in opts:
		if opt["index"] == index:
			return opt["id"]
	if not opts.is_empty():
		return opts[0]["id"]
	return DEFAULT_MODE

## Convert a mode identifier to OptionButton index
static func get_index_from_mode_id(mode_id: String) -> int:
	var opts = get_ui_options()
	for opt in opts:
		if opt["id"] == mode_id:
			return opt["index"]
	return 0
