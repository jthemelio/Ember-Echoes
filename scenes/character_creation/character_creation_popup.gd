extends Control

signal character_confirmed(data)

@onready var name_input = $CenterContainer/PanelContainer/MarginContainer/VBoxContainer/InsertName

func _on_class_button_pressed(c_name):
	var d = {"CharacterName": name_input.text, "Class": c_name, "Level": 1}
	character_confirmed.emit(d)
	queue_free()
	
func _on_marksman_pressed(): _on_class_button_pressed("Marksman")
func _on_twin_soul_pressed(): _on_class_button_pressed("Twin-Soul")
func _on_wuxia_pressed(): _on_class_button_pressed("Wuxia")
func _on_juggernaut_pressed(): _on_class_button_pressed("Juggernaut")
