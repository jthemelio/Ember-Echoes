extends Node

signal character_stats_updated

var active_character_stats: Dictionary = {}
var active_user_currencies: Dictionary = {} 
var active_user_inventory: Array = [] # <--- ADDED: This stores your items
var active_character_id: String = ""
var active_character_name: String = ""
var active_character_class: String = ""
var active_character_level: int = 1
var active_character_awakening: int = 0 

var _stats_ready: bool = false
var _currency_ready: bool = false

func start_game_with_character(data: Dictionary):
	active_character_id = data.get("CharacterId", "")
	active_character_name = data.get("CharacterName", "")
	active_character_class = data.get("Class", "") 
	active_character_level = int(data.get("Level", 1))
	active_character_awakening = int(data.get("AwakeningCount", 0))
	
	_stats_ready = false
	_currency_ready = false
	
	print("GameManager: Starting login for ", active_character_name)

	# 2. Fetch Stats
	PlayFabManager.client.get_character_statistics(active_character_id, func(result):
		var stats_dict = result.get("data", {}).get("CharacterStatistics", {})
		var new_stats = {"Strength": 0, "Agility": 0, "Vitality": 0, "Spirit": 0, "AvailableAttributePoints": 0}
		for key in stats_dict.keys():
			if new_stats.has(key): new_stats[key] = int(stats_dict[key])
		
		active_character_stats = new_stats
		_stats_ready = true 
		print("GameManager: Stats received.")
		_check_all_done()
	)

	# 3. Fetch Inventory
	var inventory_request = PlayFabManager.client.GetUserInventoryRequest.new()
	PlayFabManager.client.get_user_inventory(inventory_request, func(result):
		var inv_data = result.get("data", {})
		active_user_currencies = inv_data.get("VirtualCurrency", {})
		
		# UPDATED: Correctly store the inventory items array from PlayFab
		active_user_inventory = inv_data.get("Inventory", []) 
		
		_currency_ready = true 
		print("GameManager: Inventory received. Items found: ", active_user_inventory.size())
		_check_all_done()
	)

func _check_all_done():
	if _stats_ready and _currency_ready:
		var target_scene = "res://ui/pages/idleHome.tscn"
		get_tree().call_deferred("change_scene_to_file", target_scene)
