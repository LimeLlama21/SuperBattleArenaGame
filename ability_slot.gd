class_name AbilitySlot
extends PanelContainer

@export var key_bind_text: String = "Q"
@export var slot_name: String = ""

var key_label: Label
var cd_label: Label
var charges_label: Label
var sweep_rect: ColorRect
var sweep_mat: ShaderMaterial

var normal_style: StyleBoxFlat
var active_style: StyleBoxFlat
var disabled_style: StyleBoxFlat
var cooldown_style: StyleBoxFlat

func _init() -> void:
	custom_minimum_size = Vector2(56, 56)
	mouse_filter = Control.MOUSE_FILTER_IGNORE

func _ready() -> void:
	_create_styles()
	_build_ui()
	if not key_bind_text.is_empty() and key_label:
		key_label.text = key_bind_text

func _create_styles() -> void:
	normal_style = StyleBoxFlat.new()
	normal_style.bg_color = Color(0.08, 0.1, 0.14, 0.85)
	normal_style.border_width_left = 2
	normal_style.border_width_top = 2
	normal_style.border_width_right = 2
	normal_style.border_width_bottom = 2
	normal_style.border_color = Color(0.28, 0.45, 0.65, 0.85)
	normal_style.corner_radius_top_left = 6
	normal_style.corner_radius_top_right = 6
	normal_style.corner_radius_bottom_right = 6
	normal_style.corner_radius_bottom_left = 6

	cooldown_style = normal_style.duplicate()
	cooldown_style.border_color = Color(0.2, 0.25, 0.32, 0.7)
	cooldown_style.bg_color = Color(0.05, 0.06, 0.09, 0.85)

	active_style = normal_style.duplicate()
	active_style.border_color = Color(0.3, 0.9, 1.0, 0.95)
	active_style.bg_color = Color(0.12, 0.18, 0.26, 0.9)

	disabled_style = normal_style.duplicate()
	disabled_style.border_color = Color(0.7, 0.25, 0.25, 0.85)
	disabled_style.bg_color = Color(0.12, 0.05, 0.05, 0.85)

	add_theme_stylebox_override("panel", normal_style)

func _build_ui() -> void:
	# Root container
	var content = Control.new()
	content.anchors_preset = Control.PRESET_FULL_RECT
	content.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(content)

	# Radial sweep overlay ColorRect
	sweep_rect = ColorRect.new()
	sweep_rect.anchors_preset = Control.PRESET_FULL_RECT
	sweep_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var shader = load("res://cooldown_radial.gdshader")
	if shader:
		sweep_mat = ShaderMaterial.new()
		sweep_mat.shader = shader
		sweep_rect.material = sweep_mat
	content.add_child(sweep_rect)

	# Keybind badge (top-left)
	key_label = Label.new()
	key_label.text = key_bind_text
	key_label.position = Vector2(5, 3)
	key_label.size = Vector2(46, 16)
	key_label.add_theme_font_size_override("font_size", 11)
	key_label.add_theme_color_override("font_color", Color(0.85, 0.92, 1.0, 0.9))
	key_label.add_theme_color_override("font_shadow_color", Color(0.0, 0.0, 0.0, 0.8))
	key_label.add_theme_constant_override("shadow_offset_x", 1)
	key_label.add_theme_constant_override("shadow_offset_y", 1)
	key_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	content.add_child(key_label)

	# Cooldown number (center)
	cd_label = Label.new()
	cd_label.anchors_preset = Control.PRESET_FULL_RECT
	cd_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	cd_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	cd_label.add_theme_font_size_override("font_size", 17)
	cd_label.add_theme_color_override("font_color", Color(1.0, 1.0, 1.0, 1.0))
	cd_label.add_theme_color_override("font_outline_color", Color(0.0, 0.0, 0.0, 0.95))
	cd_label.add_theme_constant_override("outline_size", 4)
	cd_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	content.add_child(cd_label)

	# Charges badge (bottom-right)
	charges_label = Label.new()
	charges_label.anchors_preset = Control.PRESET_BOTTOM_RIGHT
	charges_label.anchor_left = 1.0
	charges_label.anchor_top = 1.0
	charges_label.anchor_right = 1.0
	charges_label.anchor_bottom = 1.0
	charges_label.offset_left = -26.0
	charges_label.offset_top = -18.0
	charges_label.offset_right = -4.0
	charges_label.offset_bottom = -2.0
	charges_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	charges_label.vertical_alignment = VERTICAL_ALIGNMENT_BOTTOM
	charges_label.add_theme_font_size_override("font_size", 12)
	charges_label.add_theme_color_override("font_color", Color(1.0, 0.88, 0.25, 1.0))
	charges_label.add_theme_color_override("font_outline_color", Color(0.0, 0.0, 0.0, 0.95))
	charges_label.add_theme_constant_override("outline_size", 3)
	charges_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	charges_label.visible = false
	content.add_child(charges_label)

func setup(key_text: String, slot_tag: String = "") -> void:
	key_bind_text = key_text
	slot_name = slot_tag
	if key_label:
		key_label.text = key_text

func set_cooldown_state(
	current_timer: float,
	max_cooldown: float,
	charges: int = -1,
	max_charges: int = -1,
	is_disabled: bool = false,
	is_active: bool = false,
	custom_text: String = ""
) -> void:
	# Calculate progress for radial sweep (1.0 = full cooldown, 0.0 = ready)
	var progress: float = 0.0
	if current_timer > 0.0 and max_cooldown > 0.0:
		progress = clamp(current_timer / max_cooldown, 0.0, 1.0)

	if sweep_mat:
		sweep_mat.set_shader_parameter("progress", progress)

	# Cooldown / State text display
	if not custom_text.is_empty():
		cd_label.text = custom_text
		cd_label.add_theme_font_size_override("font_size", 12 if custom_text.length() > 3 else 16)
		cd_label.visible = true
	elif current_timer > 0.0:
		if current_timer >= 10.0:
			cd_label.text = "%d" % int(ceil(current_timer))
		else:
			cd_label.text = "%.1f" % current_timer
		cd_label.add_theme_font_size_override("font_size", 17)
		cd_label.visible = true
	else:
		cd_label.text = ""
		cd_label.visible = false

	# Charges badge
	if max_charges > 1 and charges >= 0:
		charges_label.text = "%d" % charges
		charges_label.visible = true
	else:
		charges_label.visible = false

	# Border and styling state
	if is_disabled:
		add_theme_stylebox_override("panel", disabled_style)
		key_label.add_theme_color_override("font_color", Color(0.7, 0.4, 0.4, 0.8))
	elif is_active:
		add_theme_stylebox_override("panel", active_style)
		key_label.add_theme_color_override("font_color", Color(0.4, 0.95, 1.0, 1.0))
	elif current_timer > 0.0:
		add_theme_stylebox_override("panel", cooldown_style)
		key_label.add_theme_color_override("font_color", Color(0.6, 0.65, 0.75, 0.7))
	else:
		add_theme_stylebox_override("panel", normal_style)
		key_label.add_theme_color_override("font_color", Color(0.85, 0.92, 1.0, 0.9))
