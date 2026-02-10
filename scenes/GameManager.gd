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
		var target_scene = "res://scenes/pages/idleHome.tscn"
		get_tree().call_deferred("change_scene_to_file", target_scene)

func parse_playfab_item(pf_item: Dictionary) -> ItemData:
	var item = ItemData.new()
	
	item.instance_id = pf_item.get("ItemInstanceId", "")
	item.item_id = pf_item.get("ItemId", "")
	item.display_name = pf_item.get("DisplayName", "Unknown Item")
	
	var custom_data = pf_item.get("CustomData", {})
	item.item_class = pf_item.get("ItemClass", "")
	item.item_type = custom_data.get("Type", "")
	item.quality = custom_data.get("Quality", "Normal")
	
	item.level_req = int(custom_data.get("LevelReq", 0))
	item.str_req = int(custom_data.get("StrReq", 0))
	item.dex_req = int(custom_data.get("DexReq", 0))
	item.agi_req = int(custom_data.get("AgiReq", 0))
	item.price = int(custom_data.get("Price", 0))
	
	for stat_name in item.stats.keys():
		if custom_data.has(stat_name):
			item.stats[stat_name] = int(custom_data[stat_name])
			
	item.plus_level = int(custom_data.get("PlusLevel", 0))
	item.sockets = int(custom_data.get("Sockets", 0))
	item.current_dura = int(custom_data.get("CurrentDura", item.stats["MaxDura"]))
	
	return item
