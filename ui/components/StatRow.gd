extends HBoxContainer

signal stat_increased(stat_name)
signal stat_decreased(stat_name) # New signal for decreasing

@export var stat_name_display: String = "Strength"

@onready var name_label = $StatName
@onready var value_label = $StatValue
@onready var add_button = $AddButton
@onready var minus_button = $MinusButton

func _ready():
	name_label.text = stat_name_display

# Updated to handle the visibility of the minus button
func update_display(stat_name: String, value: int, can_upgrade: bool, can_downgrade: bool):
	name_label.text = stat_name
	value_label.text = str(value)
	
	if add_button:
		add_button.visible = can_upgrade
	
	if minus_button:
		# Only show minus if there are pending points to remove
		minus_button.visible = can_downgrade

func _on_add_button_pressed():
	stat_increased.emit(name_label.text)

func _on_minus_button_pressed():
	stat_decreased.emit(name_label.text) # Emit the decrease signal
