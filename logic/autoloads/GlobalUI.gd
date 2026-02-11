extends Node

# This holds the reference to the actual Tooltip node (set by EquipmentTooltip._ready when in tree)
var equipment_tooltip = null

const TOOLTIP_SCENE = preload("res://ui/components/EquipmentTooltip.tscn")

# Use existing tooltip from the scene tree, or create one if we're in a scene that doesn't have it (e.g. Run Current Scene on Hunting Grounds)
func _get_or_create_tooltip() -> Control:
	if equipment_tooltip != null and is_instance_valid(equipment_tooltip):
		return equipment_tooltip
	# No tooltip in tree (e.g. running Hunting Grounds alone) — create and add one
	var tooltip = TOOLTIP_SCENE.instantiate()
	get_tree().root.add_child(tooltip)
	# EquipmentTooltip._ready() will set GlobalUI.equipment_tooltip = self when it runs
	return tooltip

func show_tooltip(item_data: ItemData):
	var tip = _get_or_create_tooltip()
	if tip:
		tip.show_at_mouse(item_data)

func hide_tooltip():
	if equipment_tooltip and is_instance_valid(equipment_tooltip):
		equipment_tooltip.visible = false
