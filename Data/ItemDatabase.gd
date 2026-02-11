# ItemDatabase.gd (Updated Parser)
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

	# CORE MAPPING
	item.item_id = pf_item.get("ItemId", "")
	item.instance_id = pf_item.get("ItemInstanceId", "") # ADD THIS LINE
	item.display_name = pf_item.get("DisplayName", "Unknown")
	item.quality = custom.get("Quality", "Normal")
	item.sell_value = int(custom.get("Price", 0))
	item.max_durability = int(custom.get("MaxDura", 0))
	item.level_requirement = int(custom.get("LevelReq", 0))
	
	return item
