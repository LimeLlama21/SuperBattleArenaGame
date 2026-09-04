extends Node

const SETTINGS_FILE: String = "user://settings.json"

const DEFAULT_BINDINGS: Dictionary = {
	"shoot": {"type": "mouse", "button_index": 1},
	"ability_one": {"type": "mouse", "button_index": 2},
	"ability_two": {"type": "key", "physical_keycode": KEY_Q},
	"ability_three": {"type": "key", "physical_keycode": KEY_E},
	"ability_four": {"type": "key", "physical_keycode": KEY_R},
	"dash": {"type": "key", "physical_keycode": KEY_SHIFT},
	"jump": {"type": "key", "physical_keycode": KEY_SPACE},
	"move_up": {"type": "key", "physical_keycode": KEY_W},
	"move_left": {"type": "key", "physical_keycode": KEY_A},
	"move_down": {"type": "key", "physical_keycode": KEY_S},
	"move_right": {"type": "key", "physical_keycode": KEY_D}
}

const DEFAULT_CAST_MODES: Dictionary = {
	"shoot": "press",
	"dash": "press",
	"ability_one": "release",
	"ability_two": "release",
	"ability_three": "release",
	"ability_four": "release"
}

const DEFAULT_DASH_DIRECTION_MODE: String = "smart" # "smart" (movement unless mouse within 30 deg), "mouse", "movement"

var current_settings: Dictionary = {
	"window_mode": 0, # 0 = Windowed, 1 = Fullscreen, 2 = Borderless
	"vsync": true,
	"master_volume": 1.0,
	"sfx_volume": 1.0,
	"music_volume": 0.8,
	"bindings": {},
	"cast_modes": {},
	"dash_direction_mode": "smart"
}

func _ready() -> void:
	load_settings()

func load_settings() -> void:
	if FileAccess.file_exists(SETTINGS_FILE):
		var file = FileAccess.open(SETTINGS_FILE, FileAccess.READ)
		if file:
			var json = JSON.new()
			var parse_res = json.parse(file.get_as_text())
			if parse_res == OK and json.data is Dictionary:
				var data = json.data
				for k in data.keys():
					current_settings[k] = data[k]
	apply_all_settings()

func save_settings() -> void:
	var file = FileAccess.open(SETTINGS_FILE, FileAccess.WRITE)
	if file:
		file.store_string(JSON.stringify(current_settings, "\t"))

func apply_all_settings() -> void:
	# Apply Video
	var wm = current_settings.get("window_mode", 0)
	if wm == 1:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_EXCLUSIVE_FULLSCREEN)
	elif wm == 2:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)
	else:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)

	var vsync = current_settings.get("vsync", true)
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_ENABLED if vsync else DisplayServer.VSYNC_DISABLED)

	# Apply Audio
	var mv = current_settings.get("master_volume", 1.0)
	AudioServer.set_bus_volume_db(0, linear_to_db(max(0.0001, mv)))

	# Apply Keybindings
	var saved_bindings = current_settings.get("bindings", {})
	for action in DEFAULT_BINDINGS.keys():
		var b_info = saved_bindings.get(action, DEFAULT_BINDINGS[action])
		_apply_binding(action, b_info)

func _apply_binding(action: String, b_info: Dictionary) -> void:
	if not InputMap.has_action(action):
		InputMap.add_action(action)
	InputMap.action_erase_events(action)
	
	if b_info.get("type") == "mouse":
		var ev = InputEventMouseButton.new()
		ev.button_index = b_info.get("button_index", 1) as MouseButton
		InputMap.action_add_event(action, ev)
	elif b_info.get("type") == "key":
		var ev = InputEventKey.new()
		ev.physical_keycode = b_info.get("physical_keycode", KEY_SPACE) as Key
		InputMap.action_add_event(action, ev)

func rebind_action(action: String, event: InputEvent) -> void:
	var b_info: Dictionary = {}
	if event is InputEventMouseButton:
		b_info = {"type": "mouse", "button_index": event.button_index}
	elif event is InputEventKey:
		b_info = {"type": "key", "physical_keycode": event.physical_keycode if event.physical_keycode != 0 else event.keycode}
	else:
		return

	if not current_settings.has("bindings"):
		current_settings["bindings"] = {}
	current_settings["bindings"][action] = b_info
	_apply_binding(action, b_info)
	save_settings()

func reset_bindings_to_defaults() -> void:
	if not current_settings.has("bindings"):
		current_settings["bindings"] = {}
	for action in DEFAULT_BINDINGS.keys():
		current_settings["bindings"][action] = DEFAULT_BINDINGS[action]
		_apply_binding(action, DEFAULT_BINDINGS[action])
	save_settings()

func get_action_display_name(action: String) -> String:
	var events = InputMap.action_get_events(action)
	if events.is_empty():
		return "[ Unbound ]"
	var ev = events[0]
	if ev is InputEventMouseButton:
		if ev.button_index == MOUSE_BUTTON_LEFT:
			return "LMB (Left Click)"
		elif ev.button_index == MOUSE_BUTTON_RIGHT:
			return "RMB (Right Click)"
		elif ev.button_index == MOUSE_BUTTON_MIDDLE:
			return "MMB (Middle Click)"
		else:
			return "Mouse Btn " + str(ev.button_index)
	elif ev is InputEventKey:
		var code = ev.physical_keycode if ev.physical_keycode != 0 else ev.keycode
		return OS.get_keycode_string(code)
	return ev.as_text()

# --- Cast Mode Configuration ---

func get_cast_mode(action: String) -> String:
	var modes = current_settings.get("cast_modes", {})
	if modes is Dictionary and modes.has(action):
		return modes[action]
	return DEFAULT_CAST_MODES.get(action, "press")

func set_cast_mode(action: String, mode: String) -> void:
	if not (current_settings.get("cast_modes") is Dictionary):
		current_settings["cast_modes"] = {}
	current_settings["cast_modes"][action] = mode
	save_settings()

func set_all_cast_modes(mode: String) -> void:
	if not (current_settings.get("cast_modes") is Dictionary):
		current_settings["cast_modes"] = {}
	for action in DEFAULT_CAST_MODES.keys():
		current_settings["cast_modes"][action] = mode
	save_settings()

func reset_cast_modes_to_defaults() -> void:
	if not (current_settings.get("cast_modes") is Dictionary):
		current_settings["cast_modes"] = {}
	for action in DEFAULT_CAST_MODES.keys():
		current_settings["cast_modes"][action] = DEFAULT_CAST_MODES[action]
	save_settings()

func is_cast_on_press(action: String) -> bool:
	return get_cast_mode(action) == "press"

func is_cast_on_release(action: String) -> bool:
	return get_cast_mode(action) == "release"

# --- Dash Direction Mode Configuration ---

func get_dash_direction_mode() -> String:
	return current_settings.get("dash_direction_mode", DEFAULT_DASH_DIRECTION_MODE)

func set_dash_direction_mode(mode: String) -> void:
	current_settings["dash_direction_mode"] = mode
	save_settings()

func reset_dash_direction_mode() -> void:
	current_settings["dash_direction_mode"] = DEFAULT_DASH_DIRECTION_MODE
	save_settings()

