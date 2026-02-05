extends HBoxContainer

signal stat_increased(stat_name)

@onready var name_label = $StatName
@onready var value_label = $StatValue
@onready var add_button = $AddButton

func update_display(stat_name: String, value: int, can_upgrade: bool):
	name_label.text = stat_name
	value_label.text = str(value)
	add_button.visible = can_upgrade

func _on_add_button_pressed():
	# Emit signal so the main menu knows to subtract a point and recalculate
	stat_increased.emit(name_label.text)
