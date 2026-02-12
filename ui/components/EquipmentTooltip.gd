extends PanelContainer

@onready var item_name = $MarginContainer/VBoxContainer/HBoxContainer/VBoxContainer/ItemName
@onready var item_type = $MarginContainer/VBoxContainer/HBoxContainer/VBoxContainer/ItemType
@onready var item_icon = $MarginContainer/VBoxContainer/HBoxContainer/ItemIcon
@onready var stats_label = $MarginContainer/VBoxContainer/HBoxContainer/VBoxContainer/StatsContent

func _ready():
	GlobalUI.equipment_tooltip = self
	
	visible = false
	
	mouse_filter = Control.MOUSE_FILTER_IGNORE

func _process(_delta):
	if visible:
		_follow_mouse_clamped()

func _follow_mouse_clamped():
	var mouse_pos = get_global_mouse_position()
	var viewport_size = get_viewport_rect().size
	var tooltip_size = get_combined_minimum_size() # Use minimum size for frame-accuracy
	
	var offset = Vector2(20, 20)
	var final_pos = mouse_pos + offset
	
	if final_pos.x + tooltip_size.x > viewport_size.x:
		final_pos.x = mouse_pos.x - tooltip_size.x - offset.x
	if final_pos.y + tooltip_size.y > viewport_size.y:
		final_pos.y = mouse_pos.y - tooltip_size.y - offset.y
		
	global_position = final_pos

func show_at_mouse(data: ItemData):
	if data == null: return

	# 1. Update content while invisible to prevent 'old data' flash
	visible = false
	_update_ui(data)
	
	# 2. Force layout to recalc so get_combined_minimum_size() is correct next frame
	force_update_transform()
	# Defer position-and-show so container minimum size has updated from the new text
	call_deferred("_show_positioned")

func _show_positioned():
	_follow_mouse_clamped()
	visible = true

func _update_ui(data: ItemData):
	# 1. Setup Quality Colors (Matching your InventorySlot system)
	var quality_colors = {
		"Normal": "#ffffff", 
		"Tempered": "#00ff00", 
		"Infused": "#0080ff", 
		"Brilliant": "#a033cc", 
		"Radiant": "#ffcc00"
	}
	var q_color = quality_colors.get(data.quality.capitalize(), "#ffffff")
	
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
