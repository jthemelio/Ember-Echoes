extends HBoxContainer

signal stat_increased(stat_name)

# Add these so you can set "Strength" in the Inspector
@export var stat_name_display: String = "Strength"

@onready var name_label = $StatName
@onready var value_label = $StatValue
@onready var add_button = $AddButton

func _ready():
	# This ensures the name is set even before PlayFab data arrives
	name_label.text = stat_name_display

func update_display(stat_name: String, value: int, can_upgrade: bool):
	name_label.text = stat_name
	value_label.text = str(value)
	if add_button:
		add_button.visible = can_upgrade

func _on_add_button_pressed():
	stat_increased.emit(name_label.text)
