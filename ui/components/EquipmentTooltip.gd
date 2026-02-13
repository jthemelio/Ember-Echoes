extends PanelContainer

@onready var item_name = $MarginContainer/VBoxContainer/HBoxContainer/VBoxContainer/ItemName
@onready var item_type = $MarginContainer/VBoxContainer/HBoxContainer/VBoxContainer/ItemType
@onready var item_icon = $MarginContainer/VBoxContainer/HBoxContainer/ItemIcon
@onready var stats_label = $MarginContainer/VBoxContainer/HBoxContainer/VBoxContainer/StatsContent
@onready var action_btn: Button = $MarginContainer/VBoxContainer/ActionRow/ActionBtn

# Full-screen backdrop to catch outside clicks
var _backdrop: ColorRect = null

# Context state for the currently displayed item
var _current_data: ItemData = null
var _current_context: String = ""

func _ready():
	GlobalUI.equipment_tooltip = self
	visible = false
	# Tooltip itself stops clicks so tapping it doesn't dismiss
	mouse_filter = Control.MOUSE_FILTER_STOP

	# Connect action button
	action_btn.pressed.connect(_on_action_pressed)

	# Create a full-screen semi-transparent backdrop (sibling, inserted before self)
	_backdrop = ColorRect.new()
	_backdrop.name = "TooltipBackdrop"
	_backdrop.color = Color(0, 0, 0, 0.35)
	_backdrop.mouse_filter = Control.MOUSE_FILTER_STOP
	_backdrop.visible = false
	_backdrop.set_anchors_preset(Control.PRESET_FULL_RECT)
	# Defer adding so the parent tree is ready; insert before tooltip so it draws behind
	call_deferred("_insert_backdrop")

func _insert_backdrop():
	var p = get_parent()
	if p and _backdrop:
		var my_index = get_index()
		p.add_child(_backdrop)
		p.move_child(_backdrop, my_index)  # Place just before tooltip
		_backdrop.gui_input.connect(_on_backdrop_input)

func _on_backdrop_input(event: InputEvent):
	if event is InputEventMouseButton and event.pressed:
		# Any click on backdrop dismisses the tooltip
		dismiss()

func dismiss():
	visible = false
	if _backdrop:
		_backdrop.visible = false

func show_centered(data: ItemData, context: String = ""):
	if data == null:
		return

	_current_data = data
	_current_context = context

	# 1. Update content while invisible to prevent 'old data' flash
	visible = false
	_update_ui(data)
	_configure_action_button(data, context)

	# 2. Force layout recalc then defer positioning
	force_update_transform()
	call_deferred("_show_positioned_center")

func _show_positioned_center():
	var viewport_size = get_viewport_rect().size
	var tooltip_size = get_combined_minimum_size()
	# On desktop, constrain tooltip to 50% of viewport width; on mobile, 90%
	var max_pct = 0.50 if ScreenHelper.is_desktop() else 0.90
	var max_w = viewport_size.x * max_pct
	if tooltip_size.x > max_w:
		custom_minimum_size.x = max_w
		size.x = max_w
		tooltip_size.x = max_w
	global_position = (viewport_size - tooltip_size) * 0.5
	# Show backdrop first, then tooltip on top
	if _backdrop:
		_backdrop.visible = true
	visible = true

# ─── Action Button ───

func _configure_action_button(data: ItemData, context: String) -> void:
	action_btn.visible = false

	if context == "bag":
		# Check if the item is equippable and player meets requirements
		var check = GameManager.can_equip(data)
		if check.get("ok", false):
			action_btn.text = "Equip"
			action_btn.visible = true
	elif context == "money_bag":
		# Find the gold amount from the inventory dict
		var gold := 0
		for entry in GameManager.active_user_inventory:
			if entry is Dictionary and entry.get("uid", "") == data.instance_id:
				gold = int(entry.get("gold", 0))
				break
		action_btn.text = "Claim (%sg)" % GameManager.format_gold(gold)
		action_btn.visible = true
	elif context.begins_with("equipment:"):
		action_btn.text = "Unequip"
		action_btn.visible = true

func _on_action_pressed() -> void:
	if _current_data == null:
		return

	if _current_context == "bag":
		var ok = GameManager.equip_item(_current_data)
		if ok:
			GlobalUI.show_floating_text("%s equipped!" % _current_data.display_name, Color.WHITE)
	elif _current_context == "money_bag":
		# Grab gold amount before claiming (entry will be removed)
		var gold := 0
		for entry in GameManager.active_user_inventory:
			if entry is Dictionary and entry.get("uid", "") == _current_data.instance_id:
				gold = int(entry.get("gold", 0))
				break
		var ok = GameManager.claim_money_bag(_current_data.instance_id)
		if ok:
			GlobalUI.show_floating_text("+%sg" % GameManager.format_gold(gold), Color(1, 0.84, 0))
	elif _current_context.begins_with("equipment:"):
		var slot = _current_context.substr("equipment:".length())
		GameManager.unequip_slot(slot)
		GlobalUI.show_floating_text("%s unequipped!" % _current_data.display_name, Color.WHITE)

	dismiss()

# Border colours per quality tier (matching InventorySlot palette)
const TOOLTIP_BORDER_COLORS = {
	"Normal":    Color(0.35, 0.35, 0.38),
	"Tempered":  Color(0.910, 0.788, 0.608),
	"Infused":   Color(0.784, 0.816, 0.863),
	"Brilliant": Color(0.659, 0.847, 0.941),
	"Radiant":   Color(0.941, 0.722, 0.478),
}

func _update_ui(data: ItemData):
	# 1. Setup Quality Colors (matching border tier palette)
	var quality_colors = {
		"Normal": "#ffffff",
		"Tempered": "#e8c99b",
		"Infused": "#c8d0dc",
		"Brilliant": "#a8d8f0",
		"Radiant": "#f0b87a"
	}
	var q_color = quality_colors.get(data.quality.capitalize(), "#ffffff")
	
	# 1b. Style tooltip border + glow per quality
	var q_key = data.quality.capitalize()
	var b_color = TOOLTIP_BORDER_COLORS.get(q_key, Color(0.4, 0.4, 0.4))
	var style = get_theme_stylebox("panel").duplicate() as StyleBoxFlat
	style.border_color = b_color
	var bw = 1 if q_key == "Normal" else 2
	style.border_width_left = bw
	style.border_width_top = bw
	style.border_width_right = bw
	style.border_width_bottom = bw
	style.shadow_color = Color(b_color.r, b_color.g, b_color.b, 0.3)
	style.shadow_size = 0 if q_key == "Normal" else 5
	style.shadow_offset = Vector2(0, 0)
	add_theme_stylebox_override("panel", style)
	
	# 2. Basic Information (ItemData root)
	item_name.bbcode_enabled = true
	var plus_text = " (+%d)" % data.plus_level if data.plus_level > 0 else ""
	item_name.text = "[b][color=%s]%s%s[/color][/b]" % [q_color, data.display_name, plus_text]
	item_type.text = "Type: " + data.item_type
	
	item_icon.texture = VisualResolver.load_icon(data.item_id)

	# 3. Dynamic Body Text (Branching by Resource Type)
	var body = ""
	
	if data is WeaponData:
		if data.item_type == "Arrow":
			body += "[color=#ffcc66]ATK Bonus: +%d[/color]\n" % data.min_attack
			if data.amount > 0:
				var max_amt = data.max_amount()
				body += "Arrows: %d / %d\n" % [data.amount, max_amt]
		else:
			body += "[color=#ffcc66]Physical ATK: %d - %d[/color]\n" % [data.min_attack, data.max_attack]
			if data.magic_attack > 0:
				body += "[color=#4488ff]Magic ATK: %d[/color]\n" % data.magic_attack
			if data.get_stat("Speed") > 0:
				body += "Speed: %d\n" % data.get_stat("Speed")

	elif data is EquipmentData:
		if data.physical_defense > 0:
			body += "[color=#66ff66]Defense: %d[/color]\n" % data.physical_defense
		if data.magic_defense > 0:
			body += "[color=#4488ff]Magic Resist: %d[/color]\n" % data.magic_defense
		if data.get_stat("MagicAtk") > 0:
			body += "[color=#4488ff]Magic ATK: %d[/color]\n" % data.get_stat("MagicAtk")
		if data.get_stat("Dodge") > 0:
			body += "Dodge: %d\n" % data.get_stat("Dodge")
		if data.get_stat("LifeBonus") > 0:
			body += "[color=#66ff66]HP Bonus: %d[/color]\n" % data.get_stat("LifeBonus")

	# 4. Requirements section
	# Get the player's total stats (class base + invested) for comparison
	var char_class = GameManager.active_character_class
	var level = GameManager.active_character_level
	var invested = GameManager.active_character_stats
	var class_base = StatCalculator.get_smart_allocated_stats(char_class, level)
	var player_str = int(class_base.get("Strength", 0)) + int(invested.get("Strength", 0))
	var player_agi = int(class_base.get("Agility", 0)) + int(invested.get("Agility", 0))

	body += "\n"

	# Level requirement
	var lvl_color = "#ff4444" if level < data.level_req else "#aaaaaa"
	body += "[color=%s]Level: %d[/color]\n" % [lvl_color, data.level_req]

	# Stat requirements (only show non-zero, red if not met)
	if data.str_req > 0:
		var str_color = "#ff4444" if player_str < data.str_req else "#aaaaaa"
		body += "[color=%s]Strength: %d[/color]\n" % [str_color, data.str_req]
	if data.dex_req > 0:
		var dex_color = "#ff4444" if player_agi < data.dex_req else "#aaaaaa"
		body += "[color=%s]Dexterity: %d[/color]\n" % [dex_color, data.dex_req]
	if data.agi_req > 0:
		var agi_color = "#ff4444" if player_agi < data.agi_req else "#aaaaaa"
		body += "[color=%s]Agility: %d[/color]\n" % [agi_color, data.agi_req]

	# Durability
	body += "[color=#aaaaaa]Durability: %d / %d[/color]" % [data.current_dura, data.get_stat("MaxDura")]
	
	stats_label.bbcode_enabled = true
	stats_label.text = body
