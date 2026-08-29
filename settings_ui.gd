extends PanelContainer

signal settings_closed

@onready var window_mode_option: OptionButton = find_child("WindowModeOption", true, false)
@onready var vsync_check: CheckBox = find_child("VSyncCheck", true, false)
@onready var master_slider: HSlider = find_child("MasterSlider", true, false)
@onready var master_val_label: Label = find_child("MasterValLabel", true, false)
@onready var controls_container: VBoxContainer = find_child("ControlsContainer", true, false)
@onready var reset_controls_button: Button = find_child("ResetControlsButton", true, false)
@onready var close_button: Button = find_child("CloseButton", true, false)

var awaiting_rebind_action: String = ""
var awaiting_button: Button = null

const ACTION_LABELS: Dictionary = {
	"shoot": "Primary Attack",
	"ability_one": "Ability 1 (RMB)",
	"ability_two": "Ability 2 (Q)",
	"ability_three": "Ability 3 (E)",
	"ability_four": "Ultimate (R)",
	"dash": "Dash / Crash Down (Shift)",
	"jump": "Jump (Space)",
	"move_up": "Move Up / Forward (W)",
	"move_left": "Move Left (A)",
	"move_down": "Move Down / Back (S)",
	"move_right": "Move Right (D)"
}

func _ready() -> void:
	if window_mode_option:
		window_mode_option.clear()
		window_mode_option.add_item("Windowed", 0)
		window_mode_option.add_item("Exclusive Fullscreen", 1)
		window_mode_option.add_item("Borderless Window", 2)
		window_mode_option.item_selected.connect(_on_window_mode_selected)

	if vsync_check:
		vsync_check.toggled.connect(_on_vsync_toggled)

	if master_slider:
		master_slider.value_changed.connect(_on_master_volume_changed)

	if reset_controls_button:
		reset_controls_button.pressed.connect(_on_reset_controls_pressed)

	if close_button:
		close_button.pressed.connect(_on_close_pressed)

	_populate_controls_ui()
	_refresh_ui_from_settings()

func _refresh_ui_from_settings() -> void:
	if window_mode_option:
		window_mode_option.select(SettingsManager.current_settings.get("window_mode", 0))
	if vsync_check:
		vsync_check.button_pressed = SettingsManager.current_settings.get("vsync", true)
	if master_slider:
		var mv = SettingsManager.current_settings.get("master_volume", 1.0)
		master_slider.value = mv * 100.0
		if master_val_label:
			master_val_label.text = "%.0f%%" % (mv * 100.0)
	_refresh_binding_buttons()

func _populate_controls_ui() -> void:
	if not controls_container:
		return
	for child in controls_container.get_children():
		child.queue_free()

	for action in ACTION_LABELS.keys():
		var row = HBoxContainer.new()
		row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		
		var lbl = Label.new()
		lbl.text = ACTION_LABELS[action]
		lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		lbl.custom_minimum_size = Vector2(180, 0)
		row.add_child(lbl)
		
		var btn = Button.new()
		btn.custom_minimum_size = Vector2(160, 32)
		btn.text = SettingsManager.get_action_display_name(action)
		var current_action = action
		btn.pressed.connect(func(): _start_rebinding(current_action, btn))
		row.add_child(btn)
		
		controls_container.add_child(row)

func _refresh_binding_buttons() -> void:
	if not controls_container:
		return
	var idx = 0
	var actions = ACTION_LABELS.keys()
	for row in controls_container.get_children():
		if row is HBoxContainer and row.get_child_count() >= 2 and idx < actions.size():
			var btn = row.get_child(1) as Button
			if btn and awaiting_rebind_action != actions[idx]:
				btn.text = SettingsManager.get_action_display_name(actions[idx])
			idx += 1

func _start_rebinding(action: String, btn: Button) -> void:
	awaiting_rebind_action = action
	awaiting_button = btn
	btn.text = "[ Press Key or Mouse... ]"

func _input(event: InputEvent) -> void:
	if awaiting_rebind_action.is_empty():
		return
	
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_ESCAPE:
			# Cancel rebinding on Escape
			awaiting_rebind_action = ""
			_refresh_binding_buttons()
			get_viewport().set_input_as_handled()
			return
		
		SettingsManager.rebind_action(awaiting_rebind_action, event)
		awaiting_rebind_action = ""
		_refresh_binding_buttons()
		get_viewport().set_input_as_handled()
	elif event is InputEventMouseButton and event.pressed:
		SettingsManager.rebind_action(awaiting_rebind_action, event)
		awaiting_rebind_action = ""
		_refresh_binding_buttons()
		get_viewport().set_input_as_handled()

func _on_window_mode_selected(idx: int) -> void:
	SettingsManager.current_settings["window_mode"] = idx
	SettingsManager.apply_all_settings()
	SettingsManager.save_settings()

func _on_vsync_toggled(toggled_on: bool) -> void:
	SettingsManager.current_settings["vsync"] = toggled_on
	SettingsManager.apply_all_settings()
	SettingsManager.save_settings()

func _on_master_volume_changed(val: float) -> void:
	var norm_val = val / 100.0
	SettingsManager.current_settings["master_volume"] = norm_val
	if master_val_label:
		master_val_label.text = "%.0f%%" % val
	SettingsManager.apply_all_settings()
	SettingsManager.save_settings()

func _on_reset_controls_pressed() -> void:
	SettingsManager.reset_bindings_to_defaults()
	_refresh_binding_buttons()

func _on_close_pressed() -> void:
	hide()
	settings_closed.emit()
