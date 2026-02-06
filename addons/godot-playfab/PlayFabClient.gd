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

class ExecuteCloudScriptRequest extends JsonSerializable:
	var FunctionName: String
	var FunctionParameter: Dictionary

	func _init(n: String, p: Dictionary):
		FunctionName = n
		FunctionParameter = p

func execute_cloud_script(func_name: String, params: Dictionary, callback: Callable):
	var request = ExecuteCloudScriptRequest.new(func_name, params)
	_post_with_session_auth(request, "/Client/ExecuteCloudScript", callback)

class UpdateCharacterStatisticsRequest extends JsonSerializable:
	var CharacterId: String
	var Statistics: Array # Array of Dictionaries: {"StatisticName": string, "Value": int}

	func _init(id: String, stats: Array):
		CharacterId = id
		Statistics = stats

# Updates character-specific statistics
func update_character_statistics(char_id: String, stats: Array, callback: Callable):
	var request = UpdateCharacterStatisticsRequest.new(char_id, stats)
	_post_with_session_auth(request, "/Client/UpdateCharacterStatistics", callback)

class UpdateCharacterDataRequest extends JsonSerializable:
	var CharacterId: String
	var Data: Dictionary # Keys and Values must both be Strings

	func _init(id: String, data_dict: Dictionary):
		CharacterId = id
		Data = data_dict
		
# Updates custom data for a specific character
func update_character_data(char_id: String, data_dict: Dictionary, callback: Callable):
	var request = UpdateCharacterDataRequest.new(char_id, data_dict)
	_post_with_session_auth(request, "/Client/UpdateCharacterData", callback)
	
class GetCharacterDataRequest extends JsonSerializable:
	var CharacterId: String

	func _init(id: String):
		CharacterId = id
		
# Retrieves custom data for a specific character
func get_character_data(char_id: String, callback: Callable):
	var request = GetCharacterDataRequest.new(char_id)
	_post_with_session_auth(request, "/Client/GetCharacterData", callback)

class GetAllUsersCharactersRequest extends JsonSerializable:
	# This request can be empty, but the class must exist for the SDK
	func _init():
		pass
		
# Fetches all characters owned by the current player
func get_all_users_characters(params: Dictionary, callback: Callable):
	var request = GetAllUsersCharactersRequest.new()
	_post_with_session_auth(request, "/Client/GetAllUsersCharacters", callback)
	
class DeleteCharacterRequest extends JsonSerializable:
	var CharacterId: String
	func _init(id: String):
		CharacterId = id

func delete_character(char_id: String, callback: Callable):
	var request = DeleteCharacterRequest.new(char_id)
	# Use session auth so PlayFab knows which player is requesting the delete
	_post_with_session_auth(request, "/Client/DeleteCharacter", callback)

class UpdateCharacterInternalDataRequest extends JsonSerializable:
	var CharacterId: String
	var Data: Dictionary

	func _init(id: String, data_dict: Dictionary):
		CharacterId = id
		Data = data_dict

# Add this function to the main body of PlayFabClient.gd
func update_character_internal_data(char_id: String, data_dict: Dictionary, callback: Callable):
	var request = UpdateCharacterInternalDataRequest.new(char_id, data_dict)
	# This uses the method from the PlayFab.gd file you just shared
	_post_with_session_auth(request, "/Client/UpdateCharacterInternalData", callback)
