extends PanelContainer

# --- UI References ---
@onready var icon = $Icon
@onready var border = $QualityBorder
@onready var count_label = $LabelsOverlay/CountLabel
@onready var quantity_label = $LabelsOverlay/QuantityLabel
@onready var timer = $Timer

# --- Data Variables ---
var item_data: ItemData = null

# --- Slot mode ---
# When set, right-click unequips from this slot instead of equipping.
var equipment_slot_name: String = ""  # e.g. "Weapon", "Armor" — empty = bag mode

# --- Select mode (for bulk sell) ---
var select_mode: bool = false
var is_selected: bool = false
signal slot_tapped(slot: PanelContainer)  # Emitted on left-click in select mode

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
		self_modulate = Color(0.3, 0.3, 0.3, 1.0)    # Dim the slot panel
		count_label.text = ""
		quantity_label.text = ""
		return

	# 1. Update Border Color with capitalization safety
	var q_key = data.quality.capitalize()
	var q_color = QUALITY_COLORS.get(q_key, Color.WHITE)
	border.modulate = q_color

	# Tint the slot panel with the quality color so items are visible even without icons
	self_modulate = q_color
	
	# 2. Update Icon via VisualResolver
	icon.texture = VisualResolver.load_icon(data.item_id)
	if icon.texture == null:
		# Fallback to a generic placeholder icon
		icon.texture = VisualResolver.load_icon("placeholder_" + data.item_type.to_lower())

	# 3. Update Labels (Level and Quantity)
	count_label.text = "+" + str(data.plus_level) if data.plus_level > 0 else ""
	if data.is_stackable() and data.amount > 0:
		quantity_label.text = "x%d" % data.amount
	elif data.amount > 1:
		quantity_label.text = str(data.amount)
	else:
		quantity_label.text = ""

	# 4. Show item name in count label if no icon loaded (temporary until we have icons)
	if icon.texture == null:
		count_label.text = data.display_name
		count_label.add_theme_font_size_override("font_size", 9)

# --- Input & Tooltip Signals ---
func _on_gui_input(event: InputEvent):
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT:
			if event.pressed:
				if select_mode:
					# In select mode: toggle selection on tap
					slot_tapped.emit(self)
					return
				# Start the timer for mobile long-press or delay
				$Timer.start(0.5)
			else:
				# Stop timer and hide tooltip when button is released
				$Timer.stop()
				GlobalUI.hide_tooltip()
		
		# Right-click: Equip (bag mode) or Unequip (equipment slot mode)
		elif event.button_index == MOUSE_BUTTON_RIGHT and event.pressed:
			if select_mode:
				return  # Disable equip/unequip in select mode
			if item_data:
				if equipment_slot_name != "":
					# Equipment slot mode -- unequip
					GameManager.unequip_slot(equipment_slot_name)
				else:
					# Bag mode -- equip
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
