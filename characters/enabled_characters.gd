class_name EnabledCharacters
extends RefCounted

## Determines enabled characters dynamically based on directory structure.
## All characters in res://characters/ are selectable UNLESS placed in "Disabled characters".

const CHARACTERS_BASE_PATH: String = "res://characters"
const DISABLED_FOLDER_NAME: String = "Disabled characters"

# Subfolders directly inside res://characters/ that are not character kits
const EXCLUDED_FOLDERS: Array[String] = [
	"disabled characters",
	"leveling"
]

## Returns a list of character IDs located in the Disabled characters folder
static func get_disabled_characters() -> Array[String]:
	var disabled_list: Array[String] = []
	var disabled_dir_path = CHARACTERS_BASE_PATH + "/" + DISABLED_FOLDER_NAME
	var dir = DirAccess.open(disabled_dir_path)
	if dir:
		dir.list_dir_begin()
		var file_name = dir.get_next()
		while not file_name.is_empty():
			if dir.current_is_dir() and not file_name.begins_with("."):
				var norm = file_name.to_lower()
				if not disabled_list.has(norm):
					disabled_list.append(norm)
			file_name = dir.get_next()
		dir.list_dir_end()
	
	# Fallback check if dir scanning returns empty (e.g. export or virtual FS)
	if disabled_list.is_empty():
		if ResourceLoader.exists(CHARACTERS_BASE_PATH + "/" + DISABLED_FOLDER_NAME + "/reaper/reaper_data.gd") \
				or ResourceLoader.exists(CHARACTERS_BASE_PATH + "/" + DISABLED_FOLDER_NAME + "/reaper/reaper.tscn") \
				or ResourceLoader.exists(CHARACTERS_BASE_PATH + "/" + DISABLED_FOLDER_NAME + "/reaper/reaper.gd"):
			disabled_list.append("reaper")
	return disabled_list

## Returns true if the character ID is in the Disabled characters folder
static func is_character_disabled(char_id: String) -> bool:
	var clean = char_id.to_lower().strip_edges()
	if clean == "cleo":
		clean = "cleodolinda"
	if clean == "asparsas":
		clean = "aspara"
	return get_disabled_characters().has(clean)

## Returns a list of enabled character IDs (all characters in characters/ not in Disabled characters)
static func get_enabled_characters() -> Array[String]:
	var disabled = get_disabled_characters()
	var enabled_list: Array[String] = []
	
	# 1. Discover subdirectories directly under res://characters/
	var dir = DirAccess.open(CHARACTERS_BASE_PATH)
	if dir:
		dir.list_dir_begin()
		var file_name = dir.get_next()
		while not file_name.is_empty():
			if dir.current_is_dir() and not file_name.begins_with("."):
				var norm = file_name.to_lower()
				if not EXCLUDED_FOLDERS.has(norm) and not disabled.has(norm):
					if not enabled_list.has(norm):
						enabled_list.append(norm)
			file_name = dir.get_next()
		dir.list_dir_end()
	
	# 2. Also ensure canonical built-ins from CharacterRegistry are present if not disabled
	var canonical = ["poke", "crush", "aspara", "morrigan", "monkey", "silene", "artist", "cleodolinda"]
	for k in canonical:
		if not disabled.has(k) and not enabled_list.has(k):
			enabled_list.append(k)

	# 3. Filter out any disabled characters or aliases
	var final_list: Array[String] = []
	for k in enabled_list:
		if k == "asparsas":
			k = "aspara"
		if k == "cleo":
			k = "cleodolinda"
		if not disabled.has(k) and not final_list.has(k):
			final_list.append(k)
	return final_list

## Returns true if the character ID is enabled and selectable
static func is_character_enabled(char_id: String) -> bool:
	var clean = char_id.to_lower().strip_edges()
	if clean == "cleo":
		clean = "cleodolinda"
	if clean == "asparsas":
		clean = "aspara"
	
	if is_character_disabled(clean):
		return false
	
	var enabled = get_enabled_characters()
	if enabled.has(clean):
		return true
	
	if CharacterRegistry.has_character(clean):
		return not is_character_disabled(clean)
	
	return false

## Returns the list of enabled character IDs that are also registered in CharacterRegistry
static func get_available_enabled_characters() -> Array[String]:
	var result: Array[String] = []
	for char_id in get_enabled_characters():
		var k = char_id.to_lower().strip_edges()
		if CharacterRegistry.has_character(k):
			result.append(k)
	return result
