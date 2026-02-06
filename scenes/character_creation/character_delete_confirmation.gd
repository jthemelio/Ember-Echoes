extends Control

signal deletion_confirmed(char_id)

# Based on your screenshot, this is the correct path
@onready var delete_input = $PanelContainer/VBoxContainer/DeleteInput
var character_id_to_delete: String = ""

func _ready():
	if delete_input:
		delete_input.grab_focus()

func _on_confirm_button_pressed():
	if delete_input.text.to_upper() == "DELETE":
		deletion_confirmed.emit(character_id_to_delete)
		queue_free()
	else:
		delete_input.text = ""
		delete_input.placeholder_text = "Type DELETE to confirm"

func _on_cancel_button_pressed():
	queue_free()
