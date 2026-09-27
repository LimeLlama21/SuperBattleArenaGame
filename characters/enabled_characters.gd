class_name EnabledCharacters
extends RefCounted

## List of character IDs that are currently enabled and selectable by players.
## Specify which characters should actually be selectable in lobbies and character select.
## For the time being, all 8 built-in characters are enabled.
const ENABLED_CHARACTERS: Array[String] = [
	"poke",
	"crush",
	"asparsas",
	"reaper",
	"morrigan",
	"monkey",
	"silene",
	"artist"
]

## Returns a copy of the list of enabled character IDs (matching folder names / canonical keys)
static func get_enabled_characters() -> Array[String]:
	return ENABLED_CHARACTERS.duplicate()

## Returns true if the character ID is enabled and selectable
static func is_character_enabled(char_id: String) -> bool:
	return ENABLED_CHARACTERS.has(char_id.to_lower().strip_edges())

## Returns the list of enabled character IDs that are also registered in CharacterRegistry
static func get_available_enabled_characters() -> Array[String]:
	var result: Array[String] = []
	for char_id in ENABLED_CHARACTERS:
		var k = char_id.to_lower().strip_edges()
		if CharacterRegistry.has_character(k):
			result.append(k)
	return result
