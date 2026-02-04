@icon("res://addons/godot-playfab/icon.png")

extends PlayFab
class_name PlayFabClient

func _ready():
	super._ready()

# Retrieves the key-value store of custom title settings
# @param request_data: GetTitleDataRequest
# @param callback: Callable
func get_title_data(request_data: GetTitleDataRequest, callback: Callable):
	_post_with_session_auth(request_data, "/Client/GetTitleData", callback)

# Add this class at the very bottom of PlayFabClient.gd or outside the main class
class GetUserInventoryRequest extends JsonSerializable:
	func dict_to_obj(dict: Dictionary):
		return self

# Updated function using the correct Type
func get_user_inventory(request_data: GetUserInventoryRequest, callback: Callable):
	_post_with_session_auth(request_data, "/Client/GetUserInventory", callback)
