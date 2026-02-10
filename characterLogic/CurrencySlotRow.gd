extends HBoxContainer

@export var currency_code: String = "GD" # The PlayFab code (e.g., "CM", "I1")
@onready var value_label = $Value
@onready var name_label = $Name

func _ready():
	# Set the name label once when it starts
	if name_label and CODE_TO_NAME.has(currency_code):
		name_label.text = CODE_TO_NAME[currency_code]
	update_display()
	
	if GameManager.has_signal("character_stats_updated"):
		GameManager.character_stats_updated.connect(update_display)

func update_display():
	var bank = GameManager.active_user_currencies
	if value_label:
		var amount = bank.get(currency_code, 0)
		value_label.text = str(amount)

const CODE_TO_NAME = {
	"GD": "Gold",
	"ET": "Echo Tokens",
	"CM": "Meteors",
	"WS": "Wyrm Spheres",
	"I1": "+1 Ignis Stones",
	"I2": "+2 Ignis Stones",
	"I3": "+3 Ignis Stones",
	"I4": "+4 Ignis Stones",
	"I5": "+5 Ignis Stones",
	"I6": "+6 Ignis Stones"
}
