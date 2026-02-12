extends HBoxContainer

@export var currency_code: String = "GD" # The PlayFab code (e.g., "CM", "I1")
@onready var value_label = $Value
@onready var name_label = $Name

# Materials use inventory counts, not PlayFab currencies
const MATERIAL_BID_MAP = {
	"CM": "Comet",
	"WS": "Wyrm_Sphere",
	"I1": "ignis_plus_1",
	"I2": "ignis_plus_2",
	"I3": "ignis_plus_3",
	"I4": "ignis_plus_4",
	"I5": "ignis_plus_5",
	"I6": "ignis_plus_6",
}

func _ready():
	# Set the name label once when it starts
	if name_label and CODE_TO_NAME.has(currency_code):
		name_label.text = CODE_TO_NAME[currency_code]
	update_display()
	
	if GameManager.has_signal("character_stats_updated"):
		GameManager.character_stats_updated.connect(update_display)
	if GameManager.has_signal("inventory_changed"):
		GameManager.inventory_changed.connect(update_display)

func update_display():
	if not value_label:
		return
	# Material codes read from inventory, everything else from currencies
	if MATERIAL_BID_MAP.has(currency_code):
		var bid = MATERIAL_BID_MAP[currency_code]
		value_label.text = str(GameManager.get_material_count(bid))
	else:
		var amount = GameManager.active_user_currencies.get(currency_code, 0)
		value_label.text = str(amount)

const CODE_TO_NAME = {
	"GD": "Gold",
	"ET": "Echo Tokens",
	"CM": "Comets",
	"WS": "Wyrm Spheres",
	"I1": "+1 Ignis Stones",
	"I2": "+2 Ignis Stones",
	"I3": "+3 Ignis Stones",
	"I4": "+4 Ignis Stones",
	"I5": "+5 Ignis Stones",
	"I6": "+6 Ignis Stones"
}
