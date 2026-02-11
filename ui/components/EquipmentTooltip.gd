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
		body += "[color=#ffcc66]Physical ATK: %d - %d[/color]\n" % [data.min_attack, data.max_attack]
		if data.magic_attack > 0:
			body += "[color=#4488ff]Magic ATK: %d[/color]\n" % data.magic_attack
		if data.strength_req > 0 or data.dexterity_req > 0:
			body += "[i]Req: STR %d | DEX %d[/i]\n" % [data.strength_req, data.dexterity_req]
			
	elif data is EquipmentData:
		body += "[color=#66ff66]Defense: %d[/color]\n" % data.physical_defense
		if data.magic_defense > 0:
			body += "[color=#4488ff]Magic Resist: %d[/color]\n" % data.magic_defense
	
	# 4. Footer (Durability and Requirements)
	body += "\n[color=#aaaaaa]Level Required: %d[/color]\n" % data.level_req
	body += "[color=#aaaaaa]Durability: %d / %d[/color]" % [data.current_dura, data.get_stat("MaxDura")]
	
	stats_label.bbcode_enabled = true
	stats_label.text = body
