extends MarginContainer

@onready var hp_row = $ScrollContent/ContentVBox/StatsCard/Margin/VBox/HPRow
@onready var str_row = $ScrollContent/ContentVBox/StatsCard/Margin/VBox/StrRow
@onready var agi_row = $ScrollContent/ContentVBox/StatsCard/Margin/VBox/AgiRow
@onready var vit_row = $ScrollContent/ContentVBox/StatsCard/Margin/VBox/VitRow
@onready var spi_row = $ScrollContent/ContentVBox/StatsCard/Margin/VBox/SpiRow
@onready var name_label = $ScrollContent/ContentVBox/ProfileCard/Margin/VBox/CharName
@onready var level_label = $ScrollContent/ContentVBox/ProfileCard/Margin/VBox/HBoxContainer/LevelLabel
@onready var class_label = $ScrollContent/ContentVBox/ProfileCard/Margin/VBox/HBoxContainer/ClassLabel
@onready var equipment_grid = $ScrollContent/ContentVBox/ProfileCard/Margin/VBox/Equipment

# ─── Equipment Slots (InventorySlot instances) ───
@onready var equip_slots: Dictionary = {
	"Headgear": $ScrollContent/ContentVBox/ProfileCard/Margin/VBox/Equipment/HeadgearSlot,
	"Armor": $ScrollContent/ContentVBox/ProfileCard/Margin/VBox/Equipment/ArmorSlot,
	"Ring": $ScrollContent/ContentVBox/ProfileCard/Margin/VBox/Equipment/RingSlot,
	"Necklace": $ScrollContent/ContentVBox/ProfileCard/Margin/VBox/Equipment/NecklaceSlot,
	"Boots": $ScrollContent/ContentVBox/ProfileCard/Margin/VBox/Equipment/BootsSlot,
	"Weapon": $ScrollContent/ContentVBox/ProfileCard/Margin/VBox/Equipment/WeaponSlot,
	"Offhand": $ScrollContent/ContentVBox/ProfileCard/Margin/VBox/Equipment/OffhandSlot,
	"Backpack": $ScrollContent/ContentVBox/ProfileCard/Margin/VBox/Equipment/BackpackSlot,
}

# Slot label names shown when empty
const SLOT_LABELS := {
	"Headgear": "Head",
	"Armor": "Armor",
	"Ring": "Ring",
	"Necklace": "Neck",
	"Boots": "Boots",
	"Weapon": "Weapon",
	"Offhand": "Offhand",
	"Backpack": "Pack",
}

# --- Sub-stats VBox (populated dynamically below SpiRow) ---
@onready var stats_vbox = $ScrollContent/ContentVBox/StatsCard/Margin/VBox
@onready var content_vbox = $ScrollContent/ContentVBox
var _sub_stats_container: VBoxContainer = null

# --- Skills / Passives Card (built dynamically) ---
var _skills_card: PanelContainer = null
var _skills_content_vbox: VBoxContainer = null
var _skills_btn: Button = null
var _passives_btn: Button = null
var _skills_list_vbox: VBoxContainer = null
var _showing_skills: bool = true  # true = Skills tab, false = Passives tab

# UI elements for bulk submission
@onready var points_box = $ScrollContent/ContentVBox/StatsCard/Margin/VBox/HBoxContainer
@onready var points_label = $ScrollContent/ContentVBox/StatsCard/Margin/VBox/HBoxContainer/PointsLabel
@onready var ok_button = $ScrollContent/ContentVBox/StatsCard/Margin/VBox/HBoxContainer/OkButton

var pending_stats = {"Strength": 0, "Agility": 0, "Vitality": 0, "Spirit": 0}
var total_pending_cost = 0

func _ready():
	# Connect stat row signals
	str_row.stat_increased.connect(_on_stat_increase_requested)
	agi_row.stat_increased.connect(_on_stat_increase_requested)
	vit_row.stat_increased.connect(_on_stat_increase_requested)
	spi_row.stat_increased.connect(_on_stat_increase_requested)
	
	str_row.stat_decreased.connect(_on_stat_decrease_requested)
	agi_row.stat_decreased.connect(_on_stat_decrease_requested)
	vit_row.stat_decreased.connect(_on_stat_decrease_requested)
	spi_row.stat_decreased.connect(_on_stat_decrease_requested)
	
	if ok_button and not ok_button.pressed.is_connected(_on_ok_button_pressed):
		ok_button.pressed.connect(_on_ok_button_pressed)
	
	GameManager.character_stats_updated.connect(update_hero_ui)
	GameManager.equipment_changed.connect(_refresh_equipment_slots)
	GameManager.equipment_changed.connect(update_hero_ui)
	
	# Set equipment slot mode on each slot so right-click unequips
	for slot_name in equip_slots:
		var slot_node = equip_slots[slot_name]
		if slot_node:
			slot_node.equipment_slot_name = slot_name
	
	# Keep equipment slots square when the grid fills available width
	equipment_grid.resized.connect(_enforce_square_equip_slots)
	call_deferred("_enforce_square_equip_slots")

	# Create sub-stats container (inserted after SpiRow but before HBoxContainer)
	_sub_stats_container = VBoxContainer.new()
	_sub_stats_container.name = "SubStatsContainer"
	_sub_stats_container.add_theme_constant_override("separation", 2)
	# Insert after SpiRow (index 4 in VBox: HP=0,Str=1,Agi=2,Vit=3,Spi=4)
	stats_vbox.add_child(_sub_stats_container)
	stats_vbox.move_child(_sub_stats_container, spi_row.get_index() + 1)

	# Build Skills/Passives card (replaces CurrenciesCard)
	_build_skills_card()

	# Connect SkillManager signals
	SkillManager.skill_equipped_changed.connect(_refresh_skills_card)
	SkillManager.skill_catalog_loaded.connect(_refresh_skills_card)

	# Desktop responsive: adapt grid columns
	_adapt_for_desktop()

	# Since GameManager now pre-fetches during login, we usually don't need to fetch here
	update_hero_ui()

func _adapt_for_desktop() -> void:
	if not ScreenHelper.is_desktop():
		return
	# Equipment grid: 4 columns is fine on desktop since we cap content width,
	# but we can go to 5 if there's room
	if equipment_grid:
		equipment_grid.columns = ScreenHelper.grid_columns(4, 4)

func update_hero_ui():
	var invested = GameManager.active_character_stats
	var char_class = GameManager.active_character_class
	var level = GameManager.active_character_level
	var awaken_count = GameManager.active_character_awakening
	
	if name_label:
		name_label.text = GameManager.active_character_name
	if level_label:
		level_label.text = "Level %d" % level
	if class_label:
		class_label.text = char_class

	# Refresh equipment slot visuals
	_refresh_equipment_slots()
	
	# --- Existing Stat Logic ---
	var base = StatCalculator.get_smart_allocated_stats(char_class, level)
	var total_str = int(base.get("Strength", 0) + invested.get("Strength", 0)) + pending_stats["Strength"]
	var total_agi = int(base.get("Agility", 0) + invested.get("Agility", 0)) + pending_stats["Agility"]
	var total_vit = int(base.get("Vitality", 0) + invested.get("Vitality", 0)) + pending_stats["Vitality"]
	var total_spi = int(base.get("Spirit", 0) + invested.get("Spirit", 0)) + pending_stats["Spirit"]
	
	var totals_dict = {"Strength": total_str, "Agility": total_agi, "Vitality": total_vit, "Spirit": total_spi}
	var base_vitals = StatCalculator.calculate_base_stats(totals_dict)
	var final_vitals = StatCalculator.apply_multipliers(base_vitals, char_class, level)
	
	var points_available = int(invested.get("AvailableAttributePoints", 0))
	var points_remaining = points_available - total_pending_cost
	var can_up = points_remaining > 0 and awaken_count > 0
	
	if points_box:
		points_box.visible = (points_remaining > 0 or total_pending_cost > 0)
		if points_label:
			points_label.text = "Available Points: " + str(points_remaining)
			
	if ok_button:
		ok_button.visible = total_pending_cost > 0
	
	if hp_row:
		var current_hp = int(invested.get("CurrentHP", final_vitals.MaxHP))
		hp_row.update_hp(str(current_hp), str(int(final_vitals.MaxHP)))
		
	if str_row: str_row.update_display("Strength", total_str, can_up, pending_stats["Strength"] > 0)
	if agi_row: agi_row.update_display("Agility", total_agi, can_up, pending_stats["Agility"] > 0)
	if vit_row: vit_row.update_display("Vitality", total_vit, can_up, pending_stats["Vitality"] > 0)
	if spi_row: spi_row.update_display("Spirit", total_spi, can_up, pending_stats["Spirit"] > 0)

	# ─── Sub-Stats (Combat Details) ───
	_refresh_sub_stats(totals_dict)

# ─── Sub-Stats Section ───

func _refresh_sub_stats(totals_dict: Dictionary) -> void:
	if not _sub_stats_container:
		return
	# Clear previous sub-stat labels
	for child in _sub_stats_container.get_children():
		child.queue_free()

	# ── Dark inner card for contrast ──
	var inner_card = PanelContainer.new()
	var card_style = StyleBoxFlat.new()
	card_style.bg_color = Color(0.12, 0.11, 0.14, 0.95)
	card_style.set_corner_radius_all(8)
	card_style.content_margin_left = 14
	card_style.content_margin_right = 14
	card_style.content_margin_top = 12
	card_style.content_margin_bottom = 12
	inner_card.add_theme_stylebox_override("panel", card_style)
	_sub_stats_container.add_child(inner_card)

	var inner_vbox = VBoxContainer.new()
	inner_vbox.add_theme_constant_override("separation", 6)
	inner_card.add_child(inner_vbox)

	# Heading
	var heading = Label.new()
	heading.text = "Combat Stats"
	heading.add_theme_font_size_override("font_size", 15)
	heading.add_theme_color_override("font_color", Color(0.85, 0.75, 0.55))
	inner_vbox.add_child(heading)

	# Thin gold separator line
	var sep = HSeparator.new()
	sep.add_theme_constant_override("separation", 4)
	sep.add_theme_stylebox_override("separator", _make_separator_line(Color(0.55, 0.45, 0.25, 0.5)))
	inner_vbox.add_child(sep)

	# Get combat details from gear
	var gear_data = GameManager.build_gear_data()
	var combat = StatCalculator.calculate_combat_details(totals_dict, gear_data)

	# Weapon min/max attack for display
	var weapon = GameManager.get_equipped_item_data("Weapon")
	var wep_min = 0
	var wep_max = 0
	if weapon:
		wep_min = weapon.get_stat("MinAtk")
		wep_max = weapon.get_stat("MaxAtk")

	var weapon_speed = GameManager.get_weapon_speed()
	var speed_ratio = clampf(float(weapon_speed) / 256.0, 0.0, 1.0)
	var atk_interval = 1.5 - (speed_ratio * 0.75)

	# Build rows: [label, value, highlight]
	# highlight = true for key offensive/defensive stats
	var rows: Array = [
		["Attack", "%d – %d" % [wep_min + combat.get("P-Atk", 0), wep_max + combat.get("P-Atk", 0)] if weapon else "—", true],
		["P-Atk Bonus", "+%d" % combat.get("P-Atk", 0), false],
		["Defense", str(combat.get("TotalDef", 0)), true],
		["P-Def Bonus", "+%d" % combat.get("P-Def", 0), false],
		["Magic Atk", str(combat.get("M-Atk", 0)), true],
		["Accuracy", str(combat.get("Accuracy", 0)), false],
		["Dodge", str(combat.get("TotalDodge", 0)), false],
		["Atk Speed", "%.2fs" % atk_interval, true],
	]

	for row_data in rows:
		var hbox = HBoxContainer.new()
		hbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL

		var lbl_name = Label.new()
		lbl_name.text = row_data[0]
		lbl_name.add_theme_font_size_override("font_size", 13)
		lbl_name.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		if row_data[2]:
			lbl_name.add_theme_color_override("font_color", Color(0.82, 0.78, 0.72))
		else:
			lbl_name.add_theme_color_override("font_color", Color(0.55, 0.53, 0.50))
		hbox.add_child(lbl_name)

		var lbl_val = Label.new()
		lbl_val.text = str(row_data[1])
		lbl_val.add_theme_font_size_override("font_size", 13)
		lbl_val.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		lbl_val.size_flags_horizontal = Control.SIZE_SHRINK_END
		if row_data[2]:
			lbl_val.add_theme_color_override("font_color", Color(0.95, 0.92, 0.85))
		else:
			lbl_val.add_theme_color_override("font_color", Color(0.65, 0.62, 0.58))
		hbox.add_child(lbl_val)

		inner_vbox.add_child(hbox)

func _make_separator_line(color: Color) -> StyleBoxFlat:
	var sb = StyleBoxFlat.new()
	sb.bg_color = color
	sb.content_margin_top = 1
	sb.content_margin_bottom = 1
	return sb

# ═══════════════════════════════════════════
# Skills / Passives Card
# ═══════════════════════════════════════════

func _build_skills_card() -> void:
	_skills_card = PanelContainer.new()
	_skills_card.name = "SkillsCard"
	_skills_card.size_flags_horizontal = Control.SIZE_FILL
	content_vbox.add_child(_skills_card)

	var margin = MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 16)
	margin.add_theme_constant_override("margin_top", 16)
	margin.add_theme_constant_override("margin_right", 16)
	margin.add_theme_constant_override("margin_bottom", 16)
	_skills_card.add_child(margin)

	_skills_content_vbox = VBoxContainer.new()
	_skills_content_vbox.add_theme_constant_override("separation", 8)
	margin.add_child(_skills_content_vbox)

	# Title
	var title_lbl = Label.new()
	title_lbl.text = "Skills & Passives"
	title_lbl.add_theme_font_size_override("font_size", 18)
	title_lbl.add_theme_color_override("font_color", Color(0.85, 0.75, 0.55))
	_skills_content_vbox.add_child(title_lbl)

	# Toggle buttons row
	var toggle_row = HBoxContainer.new()
	toggle_row.add_theme_constant_override("separation", 8)
	_skills_content_vbox.add_child(toggle_row)

	_skills_btn = Button.new()
	_skills_btn.text = "Skills"
	_skills_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_skills_btn.pressed.connect(_on_toggle_skills)
	toggle_row.add_child(_skills_btn)

	_passives_btn = Button.new()
	_passives_btn.text = "Passives"
	_passives_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_passives_btn.pressed.connect(_on_toggle_passives)
	toggle_row.add_child(_passives_btn)

	# Content area
	_skills_list_vbox = VBoxContainer.new()
	_skills_list_vbox.add_theme_constant_override("separation", 6)
	_skills_content_vbox.add_child(_skills_list_vbox)

	_refresh_skills_card()

func _on_toggle_skills() -> void:
	_showing_skills = true
	_refresh_skills_card()

func _on_toggle_passives() -> void:
	_showing_skills = false
	_refresh_skills_card()

func _refresh_skills_card() -> void:
	if not _skills_list_vbox:
		return
	# Clear previous content
	for child in _skills_list_vbox.get_children():
		child.queue_free()

	# Style toggle buttons (active = gold tint, inactive = default)
	if _skills_btn:
		var active_style = StyleBoxFlat.new()
		active_style.bg_color = Color(0.35, 0.28, 0.15, 0.9)
		active_style.border_color = Color(0.85, 0.75, 0.55)
		active_style.set_border_width_all(1)
		active_style.set_corner_radius_all(4)

		var inactive_style = StyleBoxFlat.new()
		inactive_style.bg_color = Color(0.15, 0.15, 0.18, 0.8)
		inactive_style.border_color = Color(0.4, 0.4, 0.4)
		inactive_style.set_border_width_all(1)
		inactive_style.set_corner_radius_all(4)

		_skills_btn.add_theme_stylebox_override("normal", active_style if _showing_skills else inactive_style)
		_passives_btn.add_theme_stylebox_override("normal", inactive_style if _showing_skills else active_style)

	var char_class = GameManager.active_character_class
	var level = GameManager.active_character_level

	if _showing_skills:
		_populate_skills_list(char_class, level)
	else:
		_populate_passives_list(char_class, level)

func _populate_skills_list(char_class: String, level: int) -> void:
	var all_skills = SkillManager.get_skills_for_class(char_class)
	if all_skills.is_empty():
		var empty_lbl = Label.new()
		empty_lbl.text = "No skills available for this class."
		empty_lbl.add_theme_font_size_override("font_size", 12)
		empty_lbl.add_theme_color_override("font_color", Color(0.6, 0.6, 0.6))
		_skills_list_vbox.add_child(empty_lbl)
		return

	for skill in all_skills:
		var unlocked = level >= skill.get("unlockLevel", 999)
		var is_equipped = SkillManager.equipped_skill_id == skill.get("id", "")
		_create_skill_row(skill, unlocked, is_equipped)

func _populate_passives_list(char_class: String, level: int) -> void:
	var all_passives = SkillManager.get_passives_for_class(char_class)
	if all_passives.is_empty():
		var empty_lbl = Label.new()
		empty_lbl.text = "No passives available for this class."
		empty_lbl.add_theme_font_size_override("font_size", 12)
		empty_lbl.add_theme_color_override("font_color", Color(0.6, 0.6, 0.6))
		_skills_list_vbox.add_child(empty_lbl)
		return

	for passive in all_passives:
		var unlocked = level >= passive.get("unlockLevel", 999)
		_create_passive_row(passive, unlocked)

func _create_skill_row(skill: Dictionary, unlocked: bool, is_equipped: bool) -> void:
	var card = PanelContainer.new()
	var style = StyleBoxFlat.new()
	if is_equipped:
		style.bg_color = Color(0.2, 0.25, 0.15, 0.9)
		style.border_color = Color(0.85, 0.75, 0.55)
		style.set_border_width_all(2)
	elif unlocked:
		style.bg_color = Color(0.12, 0.12, 0.15, 0.8)
		style.border_color = Color(0.4, 0.4, 0.45)
		style.set_border_width_all(1)
	else:
		style.bg_color = Color(0.08, 0.08, 0.1, 0.6)
		style.border_color = Color(0.25, 0.25, 0.28)
		style.set_border_width_all(1)
	style.set_corner_radius_all(6)
	style.content_margin_left = 10
	style.content_margin_right = 10
	style.content_margin_top = 8
	style.content_margin_bottom = 8
	card.add_theme_stylebox_override("panel", style)
	_skills_list_vbox.add_child(card)

	var hbox = HBoxContainer.new()
	hbox.add_theme_constant_override("separation", 8)
	card.add_child(hbox)

	# Skill info (left side)
	var info_vbox = VBoxContainer.new()
	info_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	info_vbox.add_theme_constant_override("separation", 2)
	hbox.add_child(info_vbox)

	var name_lbl = Label.new()
	name_lbl.text = skill.get("name", "Unknown")
	name_lbl.add_theme_font_size_override("font_size", 14)
	name_lbl.add_theme_color_override("font_color", Color(0.95, 0.95, 0.95) if unlocked else Color(0.5, 0.5, 0.5))
	info_vbox.add_child(name_lbl)

	var desc_lbl = Label.new()
	desc_lbl.text = skill.get("desc", "")
	desc_lbl.add_theme_font_size_override("font_size", 11)
	desc_lbl.add_theme_color_override("font_color", Color(0.7, 0.7, 0.7) if unlocked else Color(0.4, 0.4, 0.4))
	desc_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	info_vbox.add_child(desc_lbl)

	var meta_lbl = Label.new()
	meta_lbl.text = "CD: %ds  |  Lv. %d" % [int(skill.get("cooldown", 0)), skill.get("unlockLevel", 0)]
	meta_lbl.add_theme_font_size_override("font_size", 10)
	meta_lbl.add_theme_color_override("font_color", Color(0.55, 0.55, 0.55))
	info_vbox.add_child(meta_lbl)

	# Action button (right side) — fixed width so it doesn't shift with text
	if unlocked:
		var btn = Button.new()
		if is_equipped:
			btn.text = "Unequip"
			btn.pressed.connect(func(): SkillManager.unequip_skill(); _refresh_skills_card())
		else:
			btn.text = "Equip"
			btn.pressed.connect(func(): SkillManager.equip_skill(skill.get("id", "")); _refresh_skills_card())
		btn.custom_minimum_size = Vector2(80, 36)
		btn.size_flags_horizontal = Control.SIZE_SHRINK_END
		btn.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		hbox.add_child(btn)
	else:
		var lock_lbl = Label.new()
		lock_lbl.text = "Locked"
		lock_lbl.add_theme_font_size_override("font_size", 11)
		lock_lbl.add_theme_color_override("font_color", Color(0.4, 0.35, 0.3))
		lock_lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		hbox.add_child(lock_lbl)

func _create_passive_row(passive: Dictionary, unlocked: bool) -> void:
	var card = PanelContainer.new()
	var style = StyleBoxFlat.new()
	if unlocked:
		style.bg_color = Color(0.15, 0.2, 0.15, 0.8)
		style.border_color = Color(0.5, 0.7, 0.4)
		style.set_border_width_all(1)
	else:
		style.bg_color = Color(0.08, 0.08, 0.1, 0.6)
		style.border_color = Color(0.25, 0.25, 0.28)
		style.set_border_width_all(1)
	style.set_corner_radius_all(6)
	style.content_margin_left = 10
	style.content_margin_right = 10
	style.content_margin_top = 8
	style.content_margin_bottom = 8
	card.add_theme_stylebox_override("panel", style)
	_skills_list_vbox.add_child(card)

	var hbox = HBoxContainer.new()
	hbox.add_theme_constant_override("separation", 8)
	card.add_child(hbox)

	var info_vbox = VBoxContainer.new()
	info_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	info_vbox.add_theme_constant_override("separation", 2)
	hbox.add_child(info_vbox)

	var name_lbl = Label.new()
	name_lbl.text = passive.get("name", "Unknown")
	name_lbl.add_theme_font_size_override("font_size", 14)
	name_lbl.add_theme_color_override("font_color", Color(0.95, 0.95, 0.95) if unlocked else Color(0.5, 0.5, 0.5))
	info_vbox.add_child(name_lbl)

	var desc_lbl = Label.new()
	desc_lbl.text = passive.get("desc", "")
	desc_lbl.add_theme_font_size_override("font_size", 11)
	desc_lbl.add_theme_color_override("font_color", Color(0.7, 0.7, 0.7) if unlocked else Color(0.4, 0.4, 0.4))
	desc_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	info_vbox.add_child(desc_lbl)

	var unlock_lbl = Label.new()
	unlock_lbl.text = "Lv. %d" % passive.get("unlockLevel", 0)
	unlock_lbl.add_theme_font_size_override("font_size", 10)
	unlock_lbl.add_theme_color_override("font_color", Color(0.55, 0.55, 0.55))
	info_vbox.add_child(unlock_lbl)

	# Status indicator
	var status_lbl = Label.new()
	if unlocked:
		status_lbl.text = "Active"
		status_lbl.add_theme_color_override("font_color", Color(0.5, 0.8, 0.4))
	else:
		status_lbl.text = "Locked"
		status_lbl.add_theme_color_override("font_color", Color(0.4, 0.35, 0.3))
	status_lbl.add_theme_font_size_override("font_size", 11)
	status_lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	hbox.add_child(status_lbl)

# ─── Equipment Slot Population ───

func _refresh_equipment_slots() -> void:
	for slot_name in equip_slots:
		var slot_node = equip_slots[slot_name]
		if not slot_node or not is_instance_valid(slot_node):
			continue

		var item_data = GameManager.get_equipped_item_data(slot_name)
		if item_data:
			slot_node.set_item(item_data)
		else:
			# Empty slot -- show placeholder with slot label
			slot_node.set_item(null)
			# Set the count label to show slot name as a hint
			var count_lbl = slot_node.get_node_or_null("LabelsOverlay/CountLabel")
			if count_lbl:
				count_lbl.text = SLOT_LABELS.get(slot_name, slot_name)
				count_lbl.add_theme_font_size_override("font_size", 10)
				count_lbl.add_theme_color_override("font_color", Color(0.5, 0.5, 0.5))

func _enforce_square_equip_slots():
	var cols: int = equipment_grid.columns
	var h_sep: int = equipment_grid.get_theme_constant("h_separation")
	var grid_w: float = equipment_grid.size.x
	# Cap to content width minus card padding so we never size for the full viewport
	var max_grid_w := ScreenHelper.get_content_width() - 48.0
	if grid_w <= 0.0 or grid_w > max_grid_w:
		grid_w = max_grid_w
	if grid_w <= 0.0:
		return
	var slot_w: float = (grid_w - h_sep * (cols - 1)) / float(cols)
	if slot_w <= 0.0:
		return
	for slot_name in equip_slots:
		var slot = equip_slots[slot_name]
		if slot:
			slot.custom_minimum_size = Vector2(slot_w, slot_w)

func _on_stat_increase_requested(stat_name: String):
	var points_available = int(GameManager.active_character_stats.get("AvailableAttributePoints", 0))
	if total_pending_cost < points_available:
		pending_stats[stat_name] += 1
		total_pending_cost += 1
		update_hero_ui()

func _on_stat_decrease_requested(stat_name: String):
	if pending_stats[stat_name] > 0:
		pending_stats[stat_name] -= 1
		total_pending_cost -= 1
		update_hero_ui()

func _on_ok_button_pressed():
	if total_pending_cost <= 0: return
	
	var stats_to_send = pending_stats.duplicate()
	var char_id = GameManager.active_character_id
	
	# Optimistic local update
	GameManager.active_character_stats["AvailableAttributePoints"] -= total_pending_cost
	
	pending_stats = {"Strength": 0, "Agility": 0, "Vitality": 0, "Spirit": 0}
	total_pending_cost = 0
	update_hero_ui() 

	# FIX: Sending every variation of ID to satisfy the CloudScript
	var params = {
		"CharacterId": char_id,
		"characterId": char_id,
		"character_id": char_id,
		"statsToIncrease": stats_to_send
	}
	
	PlayFabManager.client.execute_cloud_script("bulkIncreaseAttributes", params, func(result):
		var data = {}
		if result.has("FunctionResult"):
			data = result.FunctionResult
		elif result.has("data") and result.data.has("FunctionResult"):
			data = result.data.FunctionResult
			
		if data.get("success", false):
			var server_stats = data.get("newStats", {})
			for stat_name in server_stats.keys():
				GameManager.active_character_stats[stat_name] = int(server_stats[stat_name])
			
			update_hero_ui()
			print("HeroTab: Sync complete. Points: ", GameManager.active_character_stats["AvailableAttributePoints"])
		else:
			fetch_character_stats_from_playfab()
			print("HeroTab: Server sync failed. If points revert, CharacterId is missing in CloudScript.")
	)

func fetch_character_stats_from_playfab():
	var char_id = GameManager.active_character_id
	PlayFabManager.client.get_character_statistics(char_id, func(result):
		var stats_dict = result.get("data", {}).get("CharacterStatistics", {})
		var new_stats = {"Strength": 0, "Agility": 0, "Vitality": 0, "Spirit": 0, "AvailableAttributePoints": 0}
		for key in stats_dict.keys():
			var val = stats_dict[key]
			if new_stats.has(key): new_stats[key] = int(val)
			elif key == "Level": GameManager.active_character_level = int(val)
			elif key == "AwakeningCount": GameManager.active_character_awakening = int(val)
		
		GameManager.active_character_stats = new_stats
		update_hero_ui()
	)

# deposit_material_to_bank removed — all materials are now inventory items only.
# No PlayFab currency deposit needed; materials stay in inventory and are
# counted directly via GameManager.get_material_count().
