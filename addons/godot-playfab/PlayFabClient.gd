@icon("res://addons/godot-playfab/icon.png")

extends PlayFab
class_name PlayFabClient

func _ready():
	super._ready()

# --- API Functions ---

# Retrieves the key-value store of custom title settings
func get_title_data(request_data: GetTitleDataRequest, callback: Callable):
	_post_with_session_auth(request_data, "/Client/GetTitleData", callback)

# Fetches the player's inventory, currencies, and virtual items
func get_user_inventory(request_data: GetUserInventoryRequest, callback: Callable):
	_post_with_session_auth(request_data, "/Client/GetUserInventory", callback)

# Executes a CloudScript function (like createNewCharacter) on the server
func execute_cloud_script(func_name: String, params: Dictionary, callback: Callable):
	var request = ExecuteCloudScriptRequest.new(func_name, params)
	_post_with_session_auth(request, "/Client/ExecuteCloudScript", callback)

# Updates custom data for a specific character
func update_character_data(char_id: String, data_dict: Dictionary, callback: Callable):
	var request = UpdateCharacterDataRequest.new(char_id, data_dict)
	_post_with_session_auth(request, "/Client/UpdateCharacterData", callback)
	
# Retrieves custom data for a specific character
func get_character_data(char_id: String, callback: Callable):
	var request = GetCharacterDataRequest.new(char_id)
	_post_with_session_auth(request, "/Client/GetCharacterData", callback)

# Fetches all characters owned by the current player
func get_all_users_characters(_params: Dictionary, callback: Callable):
	var request = GetAllUsersCharactersRequest.new()
	_post_with_session_auth(request, "/Client/GetAllUsersCharacters", callback)
	
# Deletes a specific character via Client API (if enabled in settings)
func delete_character(char_id: String, callback: Callable):
	var request = DeleteCharacterRequest.new(char_id)
	_post_with_session_auth(request, "/Client/DeleteCharacter", callback)

# Updates internal character data (Server-side/Private)
func update_character_internal_data(char_id: String, data_dict: Dictionary, callback: Callable):
	var request = UpdateCharacterInternalDataRequest.new(char_id, data_dict)
	_post_with_session_auth(request, "/Client/UpdateCharacterInternalData", callback)

# --- Request Classes ---

class GetUserInventoryRequest extends JsonSerializable:
	func dict_to_obj(_dict: Dictionary):
		return self

class ExecuteCloudScriptRequest extends JsonSerializable:
	var FunctionName: String
	var FunctionParameter: Dictionary
	func _init(n: String, p: Dictionary):
		FunctionName = n
		FunctionParameter = p

class UpdateCharacterDataRequest extends JsonSerializable:
	var CharacterId: String
	var Data: Dictionary
	func _init(id: String, data_dict: Dictionary):
		CharacterId = id
		Data = data_dict
		
class GetCharacterDataRequest extends JsonSerializable:
	var CharacterId: String
	func _init(id: String):
		CharacterId = id

class GetAllUsersCharactersRequest extends JsonSerializable:
	func _init():
		pass
	
class DeleteCharacterRequest extends JsonSerializable:
	var CharacterId: String
	func _init(id: String):
		CharacterId = id

class UpdateCharacterInternalDataRequest extends JsonSerializable:
	var CharacterId: String
	var Data: Dictionary
	func _init(id: String, data_dict: Dictionary):
		CharacterId = id
		Data = data_dict
