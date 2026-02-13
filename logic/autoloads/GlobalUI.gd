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

func show_tooltip(item_data: ItemData, context: String = ""):
	var tip = _get_or_create_tooltip()
	if tip:
		tip.show_centered(item_data, context)

func hide_tooltip():
	if equipment_tooltip and is_instance_valid(equipment_tooltip):
		equipment_tooltip.dismiss()

# ─── Floating Feedback Text ───

const FloatingTextScript = preload("res://ui/components/FloatingText.gd")

func show_floating_text(msg: String, color: Color = Color.WHITE) -> void:
	var lbl = Label.new()
	lbl.set_script(FloatingTextScript)
	lbl.text = msg
	lbl.add_theme_color_override("font_color", color)

	# Place at top-center of viewport, slightly below the top edge
	var vp_size = get_tree().root.get_visible_rect().size
	lbl.position = Vector2(vp_size.x * 0.5 - 100, vp_size.y * 0.25)
	lbl.size = Vector2(200, 30)

	get_tree().root.add_child(lbl)

# ─── Comet Drop Screen Effect ───

var _comet_effect_script: GDScript = null

func _get_comet_script() -> GDScript:
	if _comet_effect_script == null:
		_comet_effect_script = load("res://ui/components/CometDropEffect.gd") as GDScript
	return _comet_effect_script

func show_comet_effect(item_name: String, is_wyrm: bool = false) -> void:
	print("GlobalUI: show_comet_effect called for '%s' (wyrm=%s)" % [item_name, str(is_wyrm)])
	var script = _get_comet_script()
	if script == null:
		push_warning("GlobalUI: CometDropEffect script not found!")
		return
	var overlay = ColorRect.new()
	overlay.set_script(script)
	overlay.setup(item_name, is_wyrm)
	get_tree().root.add_child(overlay)
	print("GlobalUI: Comet overlay added to root")
