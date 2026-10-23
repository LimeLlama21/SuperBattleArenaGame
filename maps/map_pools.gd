class_name MapPools
extends RefCounted

## MapPools - Data-driven map pool configuration by game mode.
## Reads maps/map_pools.json to determine valid maps for each mode.
## Trains has its own dedicated pool, while other modes share the standard arena pool.

const DATA_FILE_PATH: String = "res://maps/map_pools.json"

const DEFAULT_SHARED_POOL: Array[int] = [0, 1, 2, 3] # Colosseum, Chasm, Islands, Expanse
const DEFAULT_TRAINS_POOL: Array[int] = [4]          # Iron Triangle (Trains)

static var _cached_data: Dictionary = {}
static var _is_loaded: bool = false

## Loads the map pools configuration from maps/map_pools.json
static func load_pools_data() -> Dictionary:
	if _is_loaded and not _cached_data.is_empty():
		return _cached_data

	_cached_data = {
		"pools": {
			"standard": DEFAULT_SHARED_POOL.duplicate(),
			"trains": DEFAULT_TRAINS_POOL.duplicate()
		},
		"mode_pools": {
			"tdm": "standard",
			"dm": "standard",
			"bo5": "standard",
			"trains": "trains",
			"default": "standard"
		}
	}

	if FileAccess.file_exists(DATA_FILE_PATH):
		var file = FileAccess.open(DATA_FILE_PATH, FileAccess.READ)
		if file:
			var content = file.get_as_text()
			var json = JSON.new()
			var err = json.parse(content)
			if err == OK and json.data is Dictionary:
				var parsed: Dictionary = json.data
				if parsed.has("pools") and parsed["pools"] is Dictionary:
					_cached_data["pools"] = parsed["pools"]
				if parsed.has("mode_pools") and parsed["mode_pools"] is Dictionary:
					_cached_data["mode_pools"] = parsed["mode_pools"]
				# Also allow direct mode keys at root level if user defines "trains": [4]
				for key in ["trains", "tdm", "dm", "bo5", "default"]:
					if parsed.has(key) and parsed[key] is Array:
						_cached_data["pools"][key] = parsed[key]
						_cached_data["mode_pools"][key] = key

	_is_loaded = true
	return _cached_data

## Forces reloading the map pools from the JSON data file
static func reload() -> void:
	_is_loaded = false
	_cached_data.clear()
	load_pools_data()

## Returns the pool name associated with a game mode (e.g. "trains" or "standard")
static func get_pool_name_for_mode(mode_id: String) -> String:
	var data = load_pools_data()
	var mode_pools = data.get("mode_pools", {})
	var norm_mode = mode_id.to_lower().strip_edges()
	if mode_pools.has(norm_mode):
		return str(mode_pools[norm_mode])
	return str(mode_pools.get("default", "standard"))

## Returns array of map IDs (integers) valid for the specified game mode
static func get_pool_for_mode(mode_id: String) -> Array[int]:
	var data = load_pools_data()
	var pool_name = get_pool_name_for_mode(mode_id)
	var pools = data.get("pools", {})

	var raw_list = []
	if pools.has(pool_name):
		raw_list = pools[pool_name]
	elif pools.has(mode_id.to_lower()):
		raw_list = pools[mode_id.to_lower()]
	elif pool_name == "trains" or mode_id == "trains":
		raw_list = DEFAULT_TRAINS_POOL
	else:
		raw_list = DEFAULT_SHARED_POOL

	var result: Array[int] = []
	for item in raw_list:
		var mid = _normalize_map_id(item)
		if mid >= 0 and not result.has(mid):
			result.append(mid)

	if result.is_empty():
		return DEFAULT_TRAINS_POOL.duplicate() if (mode_id == "trains" or pool_name == "trains") else DEFAULT_SHARED_POOL.duplicate()
	return result

## Checks whether a map ID is valid for the given mode
static func is_map_valid_for_mode(map_id: int, mode_id: String) -> bool:
	var pool = get_pool_for_mode(mode_id)
	return pool.has(map_id)

## Returns all configured pool names
static func get_available_pools() -> Array[String]:
	var data = load_pools_data()
	var pools: Dictionary = data.get("pools", {})
	var names: Array[String] = []
	for k in pools.keys():
		names.append(str(k))
	return names

static func _normalize_map_id(val) -> int:
	if val is int or val is float:
		return int(val)
	if val is String:
		var s = val.strip_edges()
		if s.is_valid_int():
			return s.to_int()
		# Match by map name against MapRegistry.MAP_NAMES
		const MAP_NAMES = [
			"Colosseum",
			"The Jagged Chasm",
			"Shattered Archipelago",
			"The Great Expanse",
			"Iron Triangle (Trains)"
		]
		for i in range(MAP_NAMES.size()):
			if MAP_NAMES[i].to_lower() == s.to_lower() or s.to_lower() in MAP_NAMES[i].to_lower():
				return i
	return -1
