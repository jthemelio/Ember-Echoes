extends Node

# This holds the reference to the actual Tooltip node
var equipment_tooltip = null

func show_tooltip(item_data: ItemData):
	if equipment_tooltip:
		equipment_tooltip.show_at_mouse(item_data)

func hide_tooltip():
	if equipment_tooltip:
		equipment_tooltip.visible = false
