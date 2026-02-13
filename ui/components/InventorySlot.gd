extends PanelContainer

# --- UI References ---
@onready var icon = $Icon
@onready var border = $QualityBorder
@onready var count_label = $LabelsOverlay/CountLabel
@onready var quantity_label = $LabelsOverlay/QuantityLabel
@onready var timer = $Timer
@onready var lightning = $LightningEffect
@onready var border_glow = $BorderGlow

# --- Data Variables ---
var item_data: ItemData = null

# --- Slot mode ---
# When set, right-click unequips from this slot instead of equipping.
var equipment_slot_name: String = ""  # e.g. "Weapon", "Armor" — empty = bag mode

# --- Warehouse flag (set by InventoryGrid when offset >= 40) ---
var is_warehouse: bool = false

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

# Border glow shader + per-tier settings
const BORDER_SHADER = preload("res://assets/shaders/quality_border.gdshader")
const BORDER_SETTINGS = {
	"Normal":    { "color": Color(0.35, 0.35, 0.38), "border_width": 0.02,  "glow_size": 0.02, "glow_intensity": 0.1  },
	"Tempered":  { "color": Color(0.910, 0.788, 0.608), "border_width": 0.025, "glow_size": 0.08, "glow_intensity": 0.3 },
	"Infused":   { "color": Color(0.784, 0.816, 0.863), "border_width": 0.025, "glow_size": 0.1,  "glow_intensity": 0.35 },
	"Brilliant": { "color": Color(0.659, 0.847, 0.941), "border_width": 0.03,  "glow_size": 0.12, "glow_intensity": 0.4  },
	"Radiant":   { "color": Color(0.941, 0.722, 0.478), "border_width": 0.03,  "glow_size": 0.15, "glow_intensity": 0.5  },
}

# Lightning shader + per-tier settings (intensity scales up each tier)
const LIGHTNING_SHADER = preload("res://assets/shaders/lightning_web.gdshader")
const LIGHTNING_SETTINGS = {
	"Tempered":  { "color": Color(0.910, 0.788, 0.608), "intensity": 0.35, "density": 4.0, "speed": 1.0, "bolt_width": 0.065, "flicker": 0.25 },
	"Infused":   { "color": Color(0.784, 0.816, 0.863), "intensity": 0.5,  "density": 5.0, "speed": 1.3, "bolt_width": 0.08,  "flicker": 0.3  },
	"Brilliant": { "color": Color(0.659, 0.847, 0.941), "intensity": 0.8,  "density": 6.0, "speed": 1.7, "bolt_width": 0.1,   "flicker": 0.4  },
	"Radiant":   { "color": Color(0.941, 0.722, 0.478), "intensity": 1.2,  "density": 7.5, "speed": 2.2, "bolt_width": 0.13,  "flicker": 0.5  },
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
		lightning.visible = false
		border_glow.visible = false
		count_label.text = ""
		quantity_label.text = ""
		# Uniform empty slot style: faint grey with thin white border
		self_modulate = Color(0.75, 0.75, 0.75, 1.0)
		var empty_style = StyleBoxFlat.new()
		empty_style.bg_color = Color(0.92, 0.91, 0.90, 1.0)
		empty_style.set_corner_radius_all(6)
		empty_style.border_color = Color.WHITE
		empty_style.set_border_width_all(1)
		add_theme_stylebox_override("panel", empty_style)
		return

	# 1. Configure quality border glow
	_configure_border(data.quality)

	# Set panel background per quality tier:
	# Normal: soft grey, Non-Normal: dark so lightning/glow effects pop
	self_modulate = Color.WHITE
	if data.quality == "Normal":
		var normal_style = StyleBoxFlat.new()
		normal_style.bg_color = Color(0.88, 0.87, 0.85, 1.0)
		normal_style.set_corner_radius_all(6)
		add_theme_stylebox_override("panel", normal_style)
	else:
		var dark_style = StyleBoxFlat.new()
		dark_style.bg_color = Color(0.10, 0.10, 0.12, 1.0)
		dark_style.set_corner_radius_all(6)
		add_theme_stylebox_override("panel", dark_style)
	
	# 2. Update Icon via VisualResolver
	icon.texture = VisualResolver.load_icon(data.item_id)
	if icon.texture == null:
		# Fallback to a generic placeholder icon
		icon.texture = VisualResolver.load_icon("placeholder_" + data.item_type.to_lower())

	# 2b. Configure lightning effect behind the icon
	_configure_lightning(data.quality)

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

# --- Border Glow ---
func _configure_border(quality: String):
	var q_key = quality.capitalize()
	if not BORDER_SETTINGS.has(q_key):
		border_glow.visible = false
		return

	var s = BORDER_SETTINGS[q_key]
	if not border_glow.material is ShaderMaterial:
		border_glow.material = ShaderMaterial.new()
		border_glow.material.shader = BORDER_SHADER

	var mat := border_glow.material as ShaderMaterial
	mat.set_shader_parameter("border_color", s["color"])
	mat.set_shader_parameter("border_width", s["border_width"])
	mat.set_shader_parameter("glow_size", s["glow_size"])
	mat.set_shader_parameter("glow_intensity", s["glow_intensity"])
	border_glow.visible = true

# --- Lightning Effect ---
func _configure_lightning(quality: String):
	var q_key = quality.capitalize()
	if not LIGHTNING_SETTINGS.has(q_key):
		lightning.visible = false
		return

	var s = LIGHTNING_SETTINGS[q_key]
	if not lightning.material is ShaderMaterial:
		lightning.material = ShaderMaterial.new()
		lightning.material.shader = LIGHTNING_SHADER

	var mat := lightning.material as ShaderMaterial
	mat.set_shader_parameter("lightning_color", s["color"])
	mat.set_shader_parameter("intensity", s["intensity"])
	mat.set_shader_parameter("density", s["density"])
	mat.set_shader_parameter("speed", s["speed"])
	mat.set_shader_parameter("bolt_width", s["bolt_width"])
	mat.set_shader_parameter("flicker_strength", s["flicker"])
	lightning.visible = true

# --- Money Bag Claim ---
func _claim_money_bag() -> void:
	if item_data == null or not item_data.item_id.begins_with("money_bag_"):
		return
	GameManager.claim_money_bag(item_data.instance_id)

# --- Input & Tooltip Signals ---
func _on_gui_input(event: InputEvent):
	if event is InputEventMouseButton and event.pressed:
		if event.button_index == MOUSE_BUTTON_LEFT:
			if select_mode:
				# In select mode: toggle selection on tap
				slot_tapped.emit(self)
				return
			# Single click/tap shows tooltip centered on screen with context
			if item_data != null:
				var ctx := ""
				if item_data.item_id.begins_with("money_bag_"):
					ctx = "money_bag"
				elif equipment_slot_name != "":
					ctx = "equipment:" + equipment_slot_name
				else:
					ctx = "bag"
				GlobalUI.show_tooltip(item_data, ctx)

		# Right-click: Equip / Unequip / Claim (context-dependent)
		elif event.button_index == MOUSE_BUTTON_RIGHT:
			if select_mode:
				return  # Disable actions in select mode
			if item_data:
				# Money bag -- right-click to claim gold
				if item_data.item_id.begins_with("money_bag_"):
					_claim_money_bag()
				elif equipment_slot_name != "":
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
	# Legacy timer -- no longer used for tooltip delay
	pass

func _on_mouse_entered():
	pass  # Tooltip now shown on click, not hover

func _on_mouse_exited():
	pass  # Tooltip dismissed by clicking outside, not by mouse exit
