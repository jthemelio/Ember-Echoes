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
	var quality_colors = {"Normal": "#ffffff", "Tempered": "#00ff00", "Infused": "#0080ff", "Brilliant": "#a033cc", "Radiant": "#ffcc00"}
	var q_color = quality_colors.get(data.quality.capitalize(), "#ffffff")
	
	item_name.bbcode_enabled = true
	item_name.text = "[b][color=%s]%s (+%d)[/color][/b]" % [q_color, data.display_name, data.plus_level]
	item_type.text = "Type: " + data.item_type
	
	var icon_path = "res://assets/icons/" + data.item_id + ".png"
	item_icon.texture = load(icon_path) if FileAccess.file_exists(icon_path) else null

	var body = "[color=#ff4444]Class: %s[/color]\n" % data.item_class
	if data.get_stat("MinAtk") > 0:
		body += "Attack: %d - %d\n" % [data.get_stat("MinAtk"), data.get_stat("MaxAtk")]
	if data.get_stat("MagicAtk") > 0:
		body += "[color=#4488ff]Magic Atk: +%d[/color]\n" % data.get_stat("MagicAtk")
	
	body += "Dura.: %d / %d" % [data.current_dura, data.get_stat("MaxDura")]
	stats_label.bbcode_enabled = true
	stats_label.text = body
