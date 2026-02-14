# material_drop_slot.gd — Assigned to the MaterialSlot PanelContainer in Artisan
# Acts as a drop target for material tiles. Provides visual hover feedback and
# delegates the actual drop to the parent artisan shop script.
extends PanelContainer

var _default_style: StyleBox = null
var _highlight_style: StyleBoxFlat = null

func _ready() -> void:
	# Build a highlight style for when a valid drag is hovering
	_highlight_style = StyleBoxFlat.new()
	_highlight_style.bg_color = Color(0.3, 0.5, 0.3, 0.8)
	_highlight_style.set_corner_radius_all(6)
	_highlight_style.border_color = Color(0.5, 1.0, 0.5, 0.8)
	_highlight_style.set_border_width_all(2)

func _can_drop_data(_at_position: Vector2, data: Variant) -> bool:
	var valid = data is Dictionary and data.has("material_bid")
	# Show/hide highlight based on whether the drag is valid
	if valid:
		if _default_style == null:
			_default_style = get_theme_stylebox("panel")
		add_theme_stylebox_override("panel", _highlight_style)
	return valid

func _drop_data(_at_position: Vector2, data: Variant) -> void:
	# Restore default style
	if _default_style:
		add_theme_stylebox_override("panel", _default_style)
		_default_style = null
	else:
		remove_theme_stylebox_override("panel")

	# Find the artisan shop parent to handle the drop
	var artisan = get_meta("_artisan", null)
	if artisan and artisan.has_method("_drop_material"):
		artisan._drop_material(_at_position, data)

func _notification(what: int) -> void:
	# Restore style when drag leaves without dropping
	if what == NOTIFICATION_DRAG_END:
		if _default_style:
			add_theme_stylebox_override("panel", _default_style)
			_default_style = null
		else:
			remove_theme_stylebox_override("panel")
