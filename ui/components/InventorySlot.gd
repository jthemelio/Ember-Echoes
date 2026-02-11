extends PanelContainer

# --- UI References ---
@onready var icon = $Icon
@onready var border = $QualityBorder
@onready var count_label = $LabelsOverlay/CountLabel
@onready var quantity_label = $LabelsOverlay/QuantityLabel
@onready var timer = $Timer

# --- Data Variables ---
var item_data: ItemData = null

# Quality Colors based on your tiering system
const QUALITY_COLORS = {
	"Normal": Color.WHITE,
	"Tempered": Color(0.0, 1.0, 0.0), # Green
	"Infused": Color(0.0, 0.5, 1.0),   # Blue
	"Brilliant": Color(0.6, 0.2, 0.8), # Purple
	"Radiant": Color(1.0, 0.8, 0.0),   # Gold/Yellow
}

func _ready():
	# Ensure the slot is empty and grayed out by default
	if item_data == null:
		set_item(null)

# --- Item Logic ---
func set_item(data: ItemData):
	item_data = data
	
	if data == null:
		icon.texture = null
		border.modulate = Color(0.2, 0.2, 0.2, 0.8) # Dark grey for empty slots
		count_label.text = ""
		quantity_label.text = ""
		return

	# 1. Update Border Color with capitalization safety
	var q_key = data.quality.capitalize()
	border.modulate = QUALITY_COLORS.get(q_key, Color.WHITE)
	
	# 2. Update Icon via VisualResolver
	icon.texture = VisualResolver.load_icon(data.item_id)
	if icon.texture == null:
		# Fallback to a generic placeholder icon
		icon.texture = VisualResolver.load_icon("placeholder_" + data.item_type.to_lower())

	# 3. Update Labels (Level and Quantity)
	count_label.text = "+" + str(data.plus_level) if data.plus_level > 0 else ""
	quantity_label.text = str(data.amount) if data.amount > 1 else ""

# --- Input & Tooltip Signals ---
func _on_gui_input(event: InputEvent):
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT:
			if event.pressed:
				# Start the timer for mobile long-press or delay
				$Timer.start(0.5)
			else:
				# Stop timer and hide tooltip when button is released
				$Timer.stop()
				GlobalUI.hide_tooltip()
		
		# Right-click to Equip
		elif event.button_index == MOUSE_BUTTON_RIGHT and event.pressed:
			if item_data:
				var result = GameManager.can_equip(item_data)
				if result.get("ok", false):
					GameManager.equip_item(item_data)
				else:
					print("Cannot equip %s: %s" % [item_data.display_name, result.get("reason", "")])

func _on_timer_timeout():
	# Trigger tooltip after the set delay
	if item_data != null:
		GlobalUI.show_tooltip(item_data)

func _on_mouse_entered():
	if GlobalUI.equipment_tooltip == null:
		print("ERROR: Tooltip node not found! Is it in the scene tree?")
	else:
		print("Tooltip found: ", GlobalUI.equipment_tooltip.name)

func _on_mouse_exited():
	# Hide tooltip immediately when moving off the slot
	GlobalUI.hide_tooltip()
