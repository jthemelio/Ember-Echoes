# material_tile_drag.gd — Assigned to each draggable material tile in the Artisan palette
extends PanelContainer

func _get_drag_data(_at_position: Vector2) -> Variant:
	var bid = get_meta("material_bid", "")
	if bid.is_empty():
		return null

	# Build a small preview label that follows the cursor
	var preview = Label.new()
	preview.text = bid.replace("_", " ").capitalize()
	preview.add_theme_font_size_override("font_size", 12)
	preview.add_theme_color_override("font_color", Color.WHITE)
	
	var preview_panel = PanelContainer.new()
	var style = StyleBoxFlat.new()
	style.bg_color = Color(0.2, 0.2, 0.2, 0.9)
	style.corner_radius_top_left = 4
	style.corner_radius_top_right = 4
	style.corner_radius_bottom_left = 4
	style.corner_radius_bottom_right = 4
	style.content_margin_left = 6
	style.content_margin_right = 6
	style.content_margin_top = 3
	style.content_margin_bottom = 3
	preview_panel.add_theme_stylebox_override("panel", style)
	preview_panel.add_child(preview)
	set_drag_preview(preview_panel)

	return {"material_bid": bid}
