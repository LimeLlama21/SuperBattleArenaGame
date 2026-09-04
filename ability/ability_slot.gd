class_name AbilitySlot
extends PanelContainer

signal ability_hovered(slot: AbilitySlot)
signal ability_unhovered(slot: AbilitySlot)

@export var key_bind_text: String = "Q"
@export var slot_name: String = ""
@export var is_primary_fire: bool = false
@export var ability_title: String = ""
@export var ability_description: String = ""
@export var ability_stats: String = ""

var key_label: Label
var cd_label: Label
var charges_label: Label
var icon_label: Label
var icon_rect: TextureRect
var sweep_rect: ColorRect
var sweep_mat: ShaderMaterial

var normal_style: StyleBoxFlat
var active_style: StyleBoxFlat
var disabled_style: StyleBoxFlat
var cooldown_style: StyleBoxFlat
var primary_firing_style: StyleBoxFlat

func _init() -> void:
	custom_minimum_size = Vector2(78, 78)
	mouse_filter = Control.MOUSE_FILTER_PASS

func _ready() -> void:
	_create_styles()
	_build_ui()
	if not key_bind_text.is_empty() and key_label:
		key_label.text = key_bind_text
	mouse_entered.connect(_on_mouse_entered)
	mouse_exited.connect(_on_mouse_exited)

func _on_mouse_entered() -> void:
	ability_hovered.emit(self)

func _on_mouse_exited() -> void:
	ability_unhovered.emit(self)

func _create_styles() -> void:
	normal_style = StyleBoxFlat.new()
	normal_style.bg_color = Color(0.08, 0.10, 0.15, 0.90)
	normal_style.border_width_left = 2
	normal_style.border_width_top = 2
	normal_style.border_width_right = 2
	normal_style.border_width_bottom = 2
	normal_style.border_color = Color(0.28, 0.48, 0.70, 0.85)
	normal_style.corner_radius_top_left = 8
	normal_style.corner_radius_top_right = 8
	normal_style.corner_radius_bottom_right = 8
	normal_style.corner_radius_bottom_left = 8

	cooldown_style = normal_style.duplicate()
	cooldown_style.border_color = Color(0.20, 0.25, 0.32, 0.75)
	cooldown_style.bg_color = Color(0.04, 0.05, 0.08, 0.90)

	active_style = normal_style.duplicate()
	active_style.border_color = Color(0.35, 0.92, 1.0, 0.98)
	active_style.bg_color = Color(0.14, 0.22, 0.32, 0.95)

	disabled_style = normal_style.duplicate()
	disabled_style.border_color = Color(0.70, 0.25, 0.25, 0.85)
	disabled_style.bg_color = Color(0.12, 0.05, 0.05, 0.85)

	primary_firing_style = normal_style.duplicate()
	primary_firing_style.border_color = Color(0.50, 0.75, 1.0, 0.95)
	primary_firing_style.bg_color = Color(0.03, 0.04, 0.06, 0.98)

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
	var shader = load("res://ability/cooldown_radial.gdshader")
	if shader:
		sweep_mat = ShaderMaterial.new()
		sweep_mat.shader = shader
		sweep_rect.material = sweep_mat
	content.add_child(sweep_rect)

	# Ability Icon (Texture)
	icon_rect = TextureRect.new()
	icon_rect.anchors_preset = Control.PRESET_FULL_RECT
	icon_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	icon_rect.visible = false
	content.add_child(icon_rect)

	# Ability Icon (Glyph / Symbol / Emoji)
	icon_label = Label.new()
	icon_label.anchors_preset = Control.PRESET_FULL_RECT
	icon_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	icon_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	icon_label.add_theme_font_size_override("font_size", 24)
	icon_label.add_theme_color_override("font_color", Color(0.58, 0.86, 1.0, 0.90))
	icon_label.add_theme_color_override("font_outline_color", Color(0.0, 0.0, 0.0, 0.95))
	icon_label.add_theme_constant_override("outline_size", 4)
	icon_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	icon_label.visible = false
	content.add_child(icon_label)

	# Keybind badge (top-left)
	key_label = Label.new()
	key_label.text = key_bind_text
	key_label.position = Vector2(7, 4)
	key_label.size = Vector2(64, 18)
	key_label.add_theme_font_size_override("font_size", 13)
	key_label.add_theme_color_override("font_color", Color(0.88, 0.94, 1.0, 0.95))
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
	cd_label.add_theme_font_size_override("font_size", 24)
	cd_label.add_theme_color_override("font_color", Color(1.0, 1.0, 1.0, 1.0))
	cd_label.add_theme_color_override("font_outline_color", Color(0.0, 0.0, 0.0, 0.95))
	cd_label.add_theme_constant_override("outline_size", 5)
	cd_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	content.add_child(cd_label)

	# Charges badge (bottom-right)
	charges_label = Label.new()
	charges_label.anchors_preset = Control.PRESET_BOTTOM_RIGHT
	charges_label.anchor_left = 1.0
	charges_label.anchor_top = 1.0
	charges_label.anchor_right = 1.0
	charges_label.anchor_bottom = 1.0
	charges_label.offset_left = -34.0
	charges_label.offset_top = -24.0
	charges_label.offset_right = -5.0
	charges_label.offset_bottom = -2.0
	charges_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	charges_label.vertical_alignment = VERTICAL_ALIGNMENT_BOTTOM
	charges_label.add_theme_font_size_override("font_size", 14)
	charges_label.add_theme_color_override("font_color", Color(1.0, 0.88, 0.25, 1.0))
	charges_label.add_theme_color_override("font_outline_color", Color(0.0, 0.0, 0.0, 0.95))
	charges_label.add_theme_constant_override("outline_size", 4)
	charges_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	charges_label.visible = false
	content.add_child(charges_label)

	if is_primary_fire:
		if sweep_rect: sweep_rect.visible = false
		if cd_label: cd_label.visible = false
		if icon_label:
			icon_label.text = "⚔"
			icon_label.visible = true

func set_ability_icon(icon_val: Variant) -> void:
	if not icon_rect or not icon_label:
		return
	if icon_val is Texture2D:
		icon_rect.texture = icon_val
		icon_rect.visible = true
		icon_label.visible = false
	elif icon_val is String and not icon_val.is_empty():
		if icon_val.begins_with("res://"):
			var tex = load(icon_val)
			if tex is Texture2D:
				icon_rect.texture = tex
				icon_rect.visible = true
				icon_label.visible = false
				return
		icon_label.text = icon_val
		icon_label.visible = true
		icon_rect.visible = false
	else:
		if is_primary_fire:
			icon_label.text = "⚔"
			icon_label.visible = true
			icon_rect.visible = false
		else:
			icon_label.visible = false
			icon_rect.visible = false

func setup(key_text: String, slot_tag: String = "", is_primary: bool = false) -> void:
	key_bind_text = key_text
	slot_name = slot_tag
	is_primary_fire = is_primary
	if key_label:
		key_label.text = key_text
	if is_primary:
		if sweep_rect: sweep_rect.visible = false
		if cd_label: cd_label.visible = false
		if icon_label and icon_label.text.is_empty():
			icon_label.text = "⚔"
			icon_label.visible = true

func set_firing_state(is_firing: bool) -> void:
	if not is_primary_fire:
		return
	if is_firing:
		add_theme_stylebox_override("panel", primary_firing_style)
		if icon_label:
			icon_label.add_theme_color_override("font_color", Color(0.20, 0.45, 0.75, 0.95))
	else:
		add_theme_stylebox_override("panel", normal_style)
		if icon_label:
			icon_label.add_theme_color_override("font_color", Color(0.58, 0.86, 1.0, 0.90))

func set_cooldown_state(
	current_timer: float,
	max_cooldown: float,
	charges: int = -1,
	max_charges: int = -1,
	is_disabled: bool = false,
	is_active: bool = false,
	custom_text: String = ""
) -> void:
	# Primary fire has NO cd indicators (no number, no spinner)
	if is_primary_fire:
		if sweep_rect: sweep_rect.visible = false
		if cd_label: cd_label.visible = false
		if is_disabled:
			add_theme_stylebox_override("panel", disabled_style)
		elif is_active:
			add_theme_stylebox_override("panel", active_style)
		else:
			add_theme_stylebox_override("panel", normal_style)
		return

	# Calculate progress for radial sweep (1.0 = full cooldown, 0.0 = ready)
	var progress: float = 0.0
	if current_timer > 0.0 and max_cooldown > 0.0:
		progress = clamp(current_timer / max_cooldown, 0.0, 1.0)

	if sweep_mat:
		sweep_mat.set_shader_parameter("progress", progress)

	# Cooldown / State text display
	if not custom_text.is_empty():
		cd_label.text = custom_text
		cd_label.add_theme_font_size_override("font_size", 14 if custom_text.length() > 3 else 20)
		cd_label.visible = true
		if icon_label: icon_label.modulate = Color(1, 1, 1, 0.25)
	elif current_timer > 0.0:
		if current_timer >= 10.0:
			cd_label.text = "%d" % int(ceil(current_timer))
		else:
			cd_label.text = "%.1f" % current_timer
		cd_label.add_theme_font_size_override("font_size", 24)
		cd_label.visible = true
		if icon_label: icon_label.modulate = Color(1, 1, 1, 0.35)
	else:
		cd_label.text = ""
		cd_label.visible = false
		if icon_label: icon_label.modulate = Color(1, 1, 1, 1.0)

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
		key_label.add_theme_color_override("font_color", Color(0.88, 0.94, 1.0, 0.95))

func update_cooldown(
	current_timer: float,
	max_cooldown: float,
	charges: int = -1,
	max_charges: int = -1,
	is_disabled: bool = false,
	custom_text: String = ""
) -> void:
	set_cooldown_state(current_timer, max_cooldown, charges, max_charges, is_disabled, false, custom_text)

func set_active_state(active: bool) -> void:
	if active:
		add_theme_stylebox_override("panel", active_style)
		if key_label:
			key_label.add_theme_color_override("font_color", Color(0.4, 0.95, 1.0, 1.0))
	else:
		add_theme_stylebox_override("panel", normal_style)
		if key_label:
			key_label.add_theme_color_override("font_color", Color(0.88, 0.94, 1.0, 0.95))
