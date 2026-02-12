extends Control
## Standalone demo — press F6 to preview the lightning effect at every quality tier.
## Uses the Unlucky_Bow icon so transparent areas show the lightning behind it.

const SLOT_SCENE = preload("res://ui/components/InventorySlot.tscn")
const QUALITIES = ["Normal", "Tempered", "Infused", "Brilliant", "Radiant"]
const QUALITY_HEX = {
	"Normal":    Color.WHITE,
	"Tempered":  Color(0.910, 0.788, 0.608),  # E8C99B — light bronze
	"Infused":   Color(0.784, 0.816, 0.863),  # C8D0DC — light silver
	"Brilliant": Color(0.659, 0.847, 0.941),  # A8D8F0 — light baby blue
	"Radiant":   Color(0.941, 0.722, 0.478),  # F0B87A — light orange
}

func _ready():
	# Dark background
	var bg = ColorRect.new()
	bg.color = Color(0.08, 0.08, 0.1)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(bg)

	# Scrollable wrapper so it never goes off screen
	var scroll = ScrollContainer.new()
	scroll.set_anchors_preset(Control.PRESET_FULL_RECT)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	add_child(scroll)

	# Centre everything inside the scroll
	var center = CenterContainer.new()
	center.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	center.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.add_child(center)

	var vbox = VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 20)
	center.add_child(vbox)

	# Title
	var title = Label.new()
	title.text = "Lightning Effect — Quality Tiers"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 20)
	vbox.add_child(title)

	# Row of slots — compact sizing
	var hbox = HBoxContainer.new()
	hbox.add_theme_constant_override("separation", 12)
	hbox.alignment = BoxContainer.ALIGNMENT_CENTER
	vbox.add_child(hbox)

	for quality in QUALITIES:
		var col = VBoxContainer.new()
		col.add_theme_constant_override("separation", 6)
		hbox.add_child(col)

		var slot = SLOT_SCENE.instantiate()
		slot.custom_minimum_size = Vector2(80, 80)
		col.add_child(slot)

		# Mock item data
		var item = ItemData.new()
		item.item_id = "Unlucky_Bow"
		item.display_name = "Unlucky Bow"
		item.item_type = "Bow"
		item.quality = quality
		slot.call_deferred("set_item", item)

		# Quality label
		var lbl = Label.new()
		lbl.text = quality
		lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		lbl.add_theme_font_size_override("font_size", 12)
		lbl.add_theme_color_override("font_color", QUALITY_HEX[quality])
		col.add_child(lbl)

	# Subtitle
	var sub = Label.new()
	sub.text = "Normal = no effect  |  Each tier adds more intense lightning"
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	sub.add_theme_font_size_override("font_size", 12)
	sub.add_theme_color_override("font_color", Color(0.45, 0.45, 0.5))
	vbox.add_child(sub)
