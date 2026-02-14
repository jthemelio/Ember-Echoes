# material_tile_drag.gd — Assigned to each draggable material tile in the Artisan palette
# Shows the material tile as a drag preview (icon + tinted border) so it feels like
# grabbing the item and dropping it into the upgrade slot.
extends PanelContainer

const MATERIAL_COLORS = {
	"Comet": Color(0.4, 0.7, 1.0),
	"Wyrm_Sphere": Color(0.7, 0.3, 0.9),
	"ignis_plus_1": Color(1.0, 0.6, 0.2),
	"ignis_plus_2": Color(1.0, 0.5, 0.1),
	"ignis_plus_3": Color(1.0, 0.4, 0.05),
	"ignis_plus_4": Color(1.0, 0.3, 0.0),
	"ignis_plus_5": Color(0.9, 0.2, 0.0),
	"ignis_plus_6": Color(0.8, 0.1, 0.0),
}

const MATERIAL_DISPLAY_NAMES = {
	"Comet": "Comet",
	"Wyrm_Sphere": "Wyrm Sphere",
	"ignis_plus_1": "+1 Ignis",
	"ignis_plus_2": "+2 Ignis",
	"ignis_plus_3": "+3 Ignis",
	"ignis_plus_4": "+4 Ignis",
	"ignis_plus_5": "+5 Ignis",
	"ignis_plus_6": "+6 Ignis",
}

func _get_drag_data(_at_position: Vector2) -> Variant:
	var bid = get_meta("material_bid", "")
	if bid.is_empty():
		return null

	# Build a mini inventory-slot-style drag preview
	var mat_color = MATERIAL_COLORS.get(bid, Color(0.5, 0.5, 0.5))

	var preview_panel = PanelContainer.new()
	preview_panel.custom_minimum_size = Vector2(56, 56)
	var style = StyleBoxFlat.new()
	style.bg_color = Color(mat_color.r * 0.3, mat_color.g * 0.3, mat_color.b * 0.3, 0.95)
	style.set_corner_radius_all(6)
	style.border_color = mat_color
	style.set_border_width_all(2)
	style.shadow_color = Color(mat_color.r, mat_color.g, mat_color.b, 0.4)
	style.shadow_size = 6
	style.shadow_offset = Vector2(0, 2)
	preview_panel.add_theme_stylebox_override("panel", style)

	# Try to show the item icon
	var icon_tex = VisualResolver.load_icon(bid)
	if icon_tex:
		var icon_rect = TextureRect.new()
		icon_rect.texture = icon_tex
		icon_rect.expand_mode = 1  # EXPAND_IGNORE_SIZE
		icon_rect.stretch_mode = 5  # KEEP_ASPECT_CENTERED
		icon_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
		preview_panel.add_child(icon_rect)
	else:
		# Fallback: show material name
		var lbl = Label.new()
		lbl.text = MATERIAL_DISPLAY_NAMES.get(bid, bid)
		lbl.add_theme_font_size_override("font_size", 10)
		lbl.add_theme_color_override("font_color", mat_color)
		lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		preview_panel.add_child(lbl)

	set_drag_preview(preview_panel)
	return {"material_bid": bid}
