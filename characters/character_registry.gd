class_name CharacterRegistry
extends RefCounted

const CharacterDataClass = preload("res://characters/character_data.gd")

# Registry storage: key -> { "data": CharacterData, "scene": PackedScene }
static var _registry: Dictionary = {}
static var _initialized: bool = false

static func _ensure_initialized() -> void:
	if _initialized:
		return
	_initialized = true
	
	# Pre-register built-in character factory functions / scenes
	_register_builtin("poke", "res://characters/poke/poke_data.gd", "res://characters/poke/poke.tscn")
	_register_builtin("crush", "res://characters/crush/crush_data.gd", "res://characters/crush/crush.tscn")
	_register_builtin("asparsas", "res://characters/asparsas/asparsas_data.gd", "res://characters/asparsas/asparsas.tscn")
	_register_builtin("reaper", "res://characters/reaper/reaper_data.gd", "res://characters/reaper/reaper.tscn")
	_register_builtin("morrigan", "res://characters/morrigan/morrigan_data.gd", "res://characters/morrigan/morrigan.tscn")
	_register_builtin("monkey", "res://characters/monkey/monkey_data.gd", "res://characters/monkey/monkey.tscn")
	_register_builtin("silene", "res://characters/silene/silene_data.gd", "res://characters/silene/silene.tscn")

static func _register_builtin(key: String, data_script_path: String, scene_path: String) -> void:
	var data: CharacterData = null
	if ResourceLoader.exists(data_script_path):
		var script = load(data_script_path)
		if script and script.has_method("create"):
			data = script.create()
	var scene: PackedScene = null
	if ResourceLoader.exists(scene_path):
		scene = load(scene_path) as PackedScene
	
	_registry[key.to_lower()] = {
		"data": data,
		"scene": scene,
		"data_script": data_script_path,
		"scene_path": scene_path
	}

static func register_character(key: String, data: CharacterData, scene: PackedScene = null) -> void:
	_ensure_initialized()
	_registry[key.to_lower()] = {
		"data": data,
		"scene": scene
	}

static func has_character(key: String) -> bool:
	_ensure_initialized()
	return _registry.has(key.to_lower())

static func get_character_data(key: String) -> CharacterData:
	_ensure_initialized()
	var entry = _registry.get(key.to_lower())
	if entry:
		var d = entry.get("data")
		if d:
			return d
		# Fallback: recreate via script if needed
		var s_path = entry.get("data_script", "")
		if not s_path.is_empty() and ResourceLoader.exists(s_path):
			var scr = load(s_path)
			if scr and scr.has_method("create"):
				var created = scr.create()
				entry["data"] = created
				return created
	return null

static func get_character_scene(key: String) -> PackedScene:
	_ensure_initialized()
	var entry = _registry.get(key.to_lower())
	if entry:
		var sc = entry.get("scene")
		if sc:
			return sc
		var s_path = entry.get("scene_path", "")
		if not s_path.is_empty() and ResourceLoader.exists(s_path):
			var loaded = load(s_path) as PackedScene
			entry["scene"] = loaded
			return loaded
	# Fallback to universal player scene if no custom scene is assigned
	if ResourceLoader.exists("res://player/player.tscn"):
		return load("res://player/player.tscn") as PackedScene
	return null

static func get_all_character_keys() -> Array[String]:
	_ensure_initialized()
	var unique_keys: Array[String] = []
	var canonical = ["poke", "crush", "asparsas", "reaper", "morrigan", "monkey", "silene"]
	for k in canonical:
		if _registry.has(k) and not unique_keys.has(k):
			unique_keys.append(k)
	for k in _registry.keys():
		if not unique_keys.has(k):
			unique_keys.append(k)
	return unique_keys

static func get_display_name(key: String) -> String:
	var k = key.to_lower()
	var data = get_character_data(k)
	if data and not data.display_name.is_empty():
		return data.display_name
	if data and not data.character_name.is_empty():
		return data.character_name
	
	match k:
		"poke": return "Arash"
		"crush": return "Heracles"
		"asparsas": return "Urvashi"
		"reaper": return "Keres"
		"morrigan": return "Morrigan"
		"monkey": return "The Great Sage"
		"silene": return "Saint Silene"
		_: return key.capitalize()

static func create_player_instance(key: String) -> BasePlayer:
	_ensure_initialized()
	var scene = get_character_scene(key)
	var player: BasePlayer = null
	if scene:
		player = scene.instantiate() as BasePlayer
	if not player and ResourceLoader.exists("res://player/player.tscn"):
		var base_sc = load("res://player/player.tscn") as PackedScene
		player = base_sc.instantiate() as BasePlayer
	
	if player:
		var data = get_character_data(key)
		if data:
			player.load_character_data(data)
	return player
