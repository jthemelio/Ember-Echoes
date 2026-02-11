class_name VisualResolver

const ITEM_ICON_ROOT := "res://assets/icons/items/"

static func get_icon_path(item_id: String) -> String:
	return ITEM_ICON_ROOT + item_id + ".png"

static func load_icon(item_id: String) -> Texture2D:
	var path = get_icon_path(item_id)
	if FileAccess.file_exists(path):
		return load(path)
	return null
