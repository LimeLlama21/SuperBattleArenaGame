class_name PlayerHUD
extends CanvasLayer

@onready var hud_container: Control = $HUDContainer
@onready var status_cc_label: Label = $HUDContainer/StatusCCLabel
@onready var ability_tooltip: PanelContainer = $HUDContainer/AbilityTooltip
@onready var tooltip_title: Label = $HUDContainer/AbilityTooltip/VBox/TitleLabel
@onready var tooltip_stats: Label = $HUDContainer/AbilityTooltip/VBox/StatsLabel
@onready var tooltip_desc: Label = $HUDContainer/AbilityTooltip/VBox/DescLabel

@onready var char_name_label: Label = $HUDContainer/MainBar/HealthContainer/Margin/VBox/HeaderRow/CharNameLabel
@onready var firing_box: ColorRect = $HUDContainer/MainBar/HealthContainer/Margin/VBox/HeaderRow/FiringBox
@onready var health_bar: ProgressBar = $HUDContainer/MainBar/HealthContainer/Margin/VBox/HealthBarStack/HealthBar
@onready var shield_bar: ProgressBar = $HUDContainer/MainBar/HealthContainer/Margin/VBox/HealthBarStack/ShieldBar
@onready var gray_health_bar: ProgressBar = $HUDContainer/MainBar/HealthContainer/Margin/VBox/HealthBarStack/GrayHealthBar
@onready var health_label: Label = $HUDContainer/MainBar/HealthContainer/Margin/VBox/HealthBarStack/HealthLabel

@onready var slot_lmb: AbilitySlot = $HUDContainer/MainBar/AbilityBar/SlotLMB
@onready var slot_rmb: AbilitySlot = $HUDContainer/MainBar/AbilityBar/SlotRMB
@onready var slot_shift: AbilitySlot = $HUDContainer/MainBar/AbilityBar/SlotShift
@onready var slot_q: AbilitySlot = $HUDContainer/MainBar/AbilityBar/SlotQ
@onready var slot_e: AbilitySlot = $HUDContainer/MainBar/AbilityBar/SlotE
@onready var slot_r: AbilitySlot = $HUDContainer/MainBar/AbilityBar/SlotR

@onready var spectator_panel: PanelContainer = $SpectatorPanel
@onready var spectator_label: Label = $SpectatorPanel/VBox/SpectatorLabel

var slots_by_key: Dictionary = {}

func _ready() -> void:
	slots_by_key = {
		"LMB": slot_lmb,
		"RMB": slot_rmb,
		"SHIFT": slot_shift,
		"Q": slot_q,
		"E": slot_e,
		"R": slot_r
	}
	for slot_key in slots_by_key:
		var slot = slots_by_key[slot_key]
		if slot:
			if not slot.ability_hovered.is_connected(_on_ability_hovered):
				slot.ability_hovered.connect(_on_ability_hovered)
			if not slot.ability_unhovered.is_connected(_on_ability_unhovered):
				slot.ability_unhovered.connect(_on_ability_unhovered)
	if ability_tooltip:
		ability_tooltip.hide()

func setup_character_ui(character_name: String, ability_ui_configs: Dictionary) -> void:
	if char_name_label:
		char_name_label.text = character_name.to_upper()
	
	for slot_key in slots_by_key:
		var slot = slots_by_key[slot_key]
		if not slot:
			continue
		var config = ability_ui_configs.get(slot_key, {})
		var title = config.get("name", slot_key)
		var desc = config.get("description", "")
		var stats = config.get("stats", "")
		var icon_val = config.get("icon", null)
		
		slot.ability_title = "%s  [%s]" % [title.to_upper(), slot.key_bind_text]
		slot.ability_description = desc
		slot.ability_stats = stats
		slot.set_ability_icon(icon_val)

func get_slot(slot_key: String) -> AbilitySlot:
	return slots_by_key.get(slot_key, null)

func update_health(current: float, max_val: float, shield: float = 0.0, gray_health: float = 0.0) -> void:
	var total_display_max = max(max_val, current + shield + gray_health)
	if gray_health_bar:
		gray_health_bar.max_value = total_display_max
		gray_health_bar.value = current + shield + gray_health
	if shield_bar:
		shield_bar.max_value = total_display_max
		shield_bar.value = current + shield
	if health_bar:
		health_bar.max_value = total_display_max
		health_bar.value = current
	if health_label:
		if shield > 0.0:
			health_label.text = "%d / %d HP (+%d)" % [int(ceil(current)), int(ceil(max_val)), int(ceil(shield))]
		else:
			health_label.text = "%d / %d HP" % [int(ceil(current)), int(ceil(max_val))]

func set_firing_indicator(is_firing: bool) -> void:
	if firing_box:
		firing_box.color = Color(0.12, 0.12, 0.15, 0.95) if is_firing else Color(0.58, 0.60, 0.65, 0.95)
	if slot_lmb:
		slot_lmb.set_firing_state(is_firing)

func update_ability_cooldown(slot_key: String, current_cd: float, max_cd: float, charges: int = -1, max_charges: int = -1, is_disabled: bool = false, custom_text: String = "") -> void:
	var slot = slots_by_key.get(slot_key)
	if slot:
		slot.update_cooldown(current_cd, max_cd, charges, max_charges, is_disabled, custom_text)

func set_ability_active(slot_key: String, is_active: bool) -> void:
	var slot = slots_by_key.get(slot_key)
	if slot:
		slot.set_active_state(is_active)

func set_status_text(text: String) -> void:
	if status_cc_label:
		status_cc_label.text = text

func _on_ability_hovered(slot: AbilitySlot) -> void:
	if not ability_tooltip:
		return
	if tooltip_title:
		tooltip_title.text = slot.ability_title
	if tooltip_stats:
		tooltip_stats.text = slot.ability_stats
		tooltip_stats.visible = not slot.ability_stats.is_empty()
	if tooltip_desc:
		tooltip_desc.text = slot.ability_description
	ability_tooltip.show()

func _on_ability_unhovered(_slot: AbilitySlot) -> void:
	if ability_tooltip:
		ability_tooltip.hide()
