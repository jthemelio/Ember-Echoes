# ItemDatabase.gd — Single canonical factory: PlayFab JSON -> ItemData / EquipmentData / WeaponData
extends Node

func parse_playfab_item(pf_item: Dictionary) -> ItemData:
	var custom = pf_item.get("CustomData", {})
	var type = custom.get("Type", "Item")
	var item: ItemData

	if type in ["Blade", "Mageblade"]:
		item = WeaponData.new()
		item.min_attack = int(custom.get("MinAtk", 0))
		item.max_attack = int(custom.get("MaxAtk", 0))
		item.magic_attack = int(custom.get("MagicAtk", 0))
		item.strength_req = int(custom.get("StrReq", 0))
		item.dexterity_req = int(custom.get("DexReq", 0))
	elif type in ["Armor", "Necklace", "Coat"]:
		item = EquipmentData.new()
		item.physical_defense = int(custom.get("Def", 0))
		item.magic_defense = int(custom.get("MagicDef", 0))
	else:
		item = ItemData.new()

	# Core identity
	item.item_id = pf_item.get("ItemId", "")
	item.instance_id = pf_item.get("ItemInstanceId", "")
	item.display_name = pf_item.get("DisplayName", "Unknown")
	item.item_class = pf_item.get("ItemClass", "")
	item.item_type = type
	item.quality = custom.get("Quality", "Normal")

	# Requirements
	item.level_req = int(custom.get("LevelReq", 0))
	item.str_req = int(custom.get("StrReq", 0))
	item.dex_req = int(custom.get("DexReq", 0))
	item.agi_req = int(custom.get("AgiReq", 0))

	# Economy
	item.price = int(custom.get("Price", 0))

	# Universal stats dict (drives tooltip display and combat math)
	for stat_name in item.stats.keys():
		if custom.has(stat_name):
			item.stats[stat_name] = int(custom[stat_name])

	# Instance data
	item.plus_level = int(custom.get("PlusLevel", 0))
	item.sockets = int(custom.get("Sockets", 0))
	item.current_dura = int(custom.get("CurrentDura", item.stats["MaxDura"]))

	return item
