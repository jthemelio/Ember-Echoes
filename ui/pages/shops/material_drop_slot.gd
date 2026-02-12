# material_drop_slot.gd — Assigned to the MaterialSlot PanelContainer in Artisan
# Acts as a drop target for material tiles. Delegates to the parent artisan shop script.
extends PanelContainer

func _can_drop_data(_at_position: Vector2, data: Variant) -> bool:
	if data is Dictionary and data.has("material_bid"):
		return true
	return false

func _drop_data(_at_position: Vector2, data: Variant) -> void:
	# Find the artisan shop parent to handle the drop
	var artisan = get_meta("_artisan", null)
	if artisan and artisan.has_method("_drop_material"):
		artisan._drop_material(_at_position, data)
