class_name EnabledModes
extends RefCounted

## Determines enabled game modes dynamically based on directory structure and configuration.
## All registered game modes are selectable UNLESS placed in "disabled_modes" or listed in DISABLED_MODES.

const MODES_BASE_PATH: String = "res://gamemodes"
const DISABLED_FOLDER_NAME: String = "disabled_modes"
const DISABLED_FOLDER_NAME_ALT: String = "Disabled modes"

## Canonical list of all known game mode IDs in priority order
const CANONICAL_MODES: Array[String] = [
	"tdm",
	"dm",
	"bo5",
	"trains"
]

## List of enabled modes. If empty, all non-disabled canonical modes are enabled.
const ENABLED_MODES: Array[String] = [
	"tdm",
	"dm",
	"bo5",
	"trains"
]

## List of explicitly disabled game mode IDs.
## Any mode ID added here will be disabled even if its script is present.
const DISABLED_MODES: Array[String] = []

## Name and file mappings for resolving mode identifiers
const MODE_NAME_MAPPINGS: Dictionary = {
	"tdm": "tdm",
	"team_deathmatch": "tdm",
	"team deathmatch": "tdm",
	"team-deathmatch": "tdm",
	"team_deathmatch.gd": "tdm",
	"dm": "dm",
	"deathmatch": "dm",
	"deathmatch.gd": "dm",
	"ffa": "dm",
	"bo5": "bo5",
	"best_of_five": "bo5",
	"best of five": "bo5",
	"best-of-five": "bo5",
	"best_of_five.gd": "bo5",
	"trains": "trains",
	"train": "trains",
	"trains.gd": "trains"
}

## Runtime overrides for dynamic toggling (e.g. testing or settings UI)
static var _runtime_overrides: Dictionary = {}

## Normalizes any mode string or file name to canonical mode ID (e.g. "team_deathmatch.gd" -> "tdm")
static func normalize_mode_id(mode_str: String) -> String:
	var s = mode_str.to_lower().strip_edges()
	if s.ends_with(".remap"):
		s = s.trim_suffix(".remap")
	if s.ends_with(".gdc"):
		s = s.trim_suffix(".gdc")
	if s.ends_with(".gd"):
		s = s.trim_suffix(".gd")
	if MODE_NAME_MAPPINGS.has(s):
		return MODE_NAME_MAPPINGS[s]
	return s

## Returns a list of mode IDs detected in the disabled modes folder
static func get_folder_disabled_modes() -> Array[String]:
	var disabled_list: Array[String] = []
	var search_dirs = [
		MODES_BASE_PATH + "/" + DISABLED_FOLDER_NAME,
		MODES_BASE_PATH + "/" + DISABLED_FOLDER_NAME_ALT,
		MODES_BASE_PATH + "/Disabled Modes",
		MODES_BASE_PATH + "/disabled modes"
	]
	
	for dpath in search_dirs:
		var dir = DirAccess.open(dpath)
		if dir:
			dir.list_dir_begin()
			var file_name = dir.get_next()
			while not file_name.is_empty():
				if not file_name.begins_with("."):
					var norm = normalize_mode_id(file_name)
					if CANONICAL_MODES.has(norm) and not disabled_list.has(norm):
						disabled_list.append(norm)
				file_name = dir.get_next()
			dir.list_dir_end()
	
	# Fallback check for ResourceLoader if virtual filesystem or exported pack
	var script_filenames = {
		"tdm": "team_deathmatch.gd",
		"dm": "deathmatch.gd",
		"bo5": "best_of_five.gd",
		"trains": "trains.gd"
	}
	for mid in CANONICAL_MODES:
		var sf = script_filenames.get(mid, mid + ".gd")
		for folder in [DISABLED_FOLDER_NAME, DISABLED_FOLDER_NAME_ALT]:
			if ResourceLoader.exists(MODES_BASE_PATH + "/" + folder + "/" + sf) \
					or ResourceLoader.exists(MODES_BASE_PATH + "/" + folder + "/" + mid + "/" + sf) \
					or ResourceLoader.exists(MODES_BASE_PATH + "/" + folder + "/" + mid + ".gd"):
				if not disabled_list.has(mid):
					disabled_list.append(mid)

	return disabled_list

## Returns true if the mode is disabled via runtime override, DISABLED_MODES, folder, or ENABLED_MODES exclusion
static func is_mode_disabled(mode_id: String) -> bool:
	var clean = normalize_mode_id(mode_id)
	if _runtime_overrides.has(clean):
		return not _runtime_overrides[clean]
	
	# Check explicit DISABLED_MODES list
	for d in DISABLED_MODES:
		if normalize_mode_id(d) == clean:
			return true
	
	# Check disabled modes subfolder
	if get_folder_disabled_modes().has(clean):
		return true
	
	# If ENABLED_MODES is explicitly specified, any canonical mode not listed is disabled
	if not ENABLED_MODES.is_empty():
		var found_enabled = false
		for e in ENABLED_MODES:
			if normalize_mode_id(e) == clean:
				found_enabled = true
				break
		if not found_enabled:
			return true
			
	return false

## Returns true if the mode is valid and enabled
static func is_mode_enabled(mode_id: String) -> bool:
	var clean = normalize_mode_id(mode_id)
	if not CANONICAL_MODES.has(clean):
		return false
	return not is_mode_disabled(clean)

## Returns a list of all currently enabled mode IDs in canonical order
static func get_enabled_modes() -> Array[String]:
	var result: Array[String] = []
	for m in CANONICAL_MODES:
		if is_mode_enabled(m):
			result.append(m)
	return result

## Returns a list of all currently disabled mode IDs in canonical order
static func get_disabled_modes() -> Array[String]:
	var result: Array[String] = []
	for m in CANONICAL_MODES:
		if is_mode_disabled(m):
			result.append(m)
	return result

## Programmatically enable or disable a mode at runtime
static func set_mode_enabled(mode_id: String, enabled: bool) -> void:
	var clean = normalize_mode_id(mode_id)
	_runtime_overrides[clean] = enabled

## Clear all runtime overrides
static func reset_overrides() -> void:
	_runtime_overrides.clear()
