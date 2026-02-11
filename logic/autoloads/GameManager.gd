extends Node

signal character_stats_updated
signal equipment_changed

var active_character_stats: Dictionary = {}
var active_user_currencies: Dictionary = {}
var active_user_inventory: Array = []
var active_character_id: String = ""
var active_character_name: String = ""
var active_character_class: String = ""
var active_character_level: int = 1
var active_character_awakening: int = 0

# ───── Equipment System (8 slots) ─────
# Row 1: Headgear, Armor, Ring, Necklace
# Row 2: Boots, Weapon, Offhand, Backpack
var equipped_items: Dictionary = {
	"Headgear": null,   # Hat -- Def, MagicAtk, MagicDef
	"Armor": null,      # Armor / Vestment / Coat -- Def, MagicDef
	"Ring": null,       # Ring -- MinAtk, MaxAtk
	"Necklace": null,   # Necklace -- Def
	"Boots": null,      # Boots -- Dodge
	"Weapon": null,     # Blade / Bow / Wand -- MinAtk, MaxAtk, Speed
	"Offhand": null,    # Shield / Arrows / 2nd Weapon (Twin-Soul)
	"Backpack": null,   # Future: inventory expansion
}

# Maps item Type (from PlayFab CustomData) to equipment slot
const TYPE_TO_SLOT: Dictionary = {
	"Blade": "Weapon", "Bow": "Weapon", "Wand": "Weapon",
	"Armor": "Armor", "Vestment": "Armor", "Coat": "Armor",
	"Hat": "Headgear",
	"Ring": "Ring",
	"Necklace": "Necklace",
	"Boots": "Boots",
	"Shield": "Offhand",
}

# Maps armor Type to required class
const ARMOR_CLASS_REQ: Dictionary = {
	"Vestment": "Wuxia",
	"Armor": "Twin-Soul",
	"Coat": "Marksman",
}

var _stats_ready: bool = false
var _currency_ready: bool = false
var _title_data_ready: bool = false

func start_game_with_character(data: Dictionary):
	active_character_id = data.get("CharacterId", "")
	active_character_name = data.get("CharacterName", "")
	active_character_class = data.get("Class", "")
	active_character_level = int(data.get("Level", 1))
	active_character_awakening = int(data.get("AwakeningCount", 0))

	_stats_ready = false
	_currency_ready = false
	_title_data_ready = false

	print("GameManager: Starting login for ", active_character_name)

	# 1. Fetch Stats
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

	# 2. Fetch Inventory
	var inventory_request = PlayFabManager.client.GetUserInventoryRequest.new()
	PlayFabManager.client.get_user_inventory(inventory_request, func(result):
		var inv_data = result.get("data", {})
		active_user_currencies = inv_data.get("VirtualCurrency", {})
		active_user_inventory = inv_data.get("Inventory", [])

		_currency_ready = true
		print("GameManager: Inventory received. Items found: ", active_user_inventory.size())
		_check_all_done()
	)

	# 3. Fetch Title Data (ZoneData, LootConfig, ItemCatalog)
	var title_request = GetTitleDataRequest.new()
	title_request.Keys = ["ZoneData", "LootConfig", "ItemCatalog"]
	PlayFabManager.client.get_title_data(title_request, func(result):
		var td = result.get("data", {}).get("Data", {})
		print("GameManager: Title Data received. Keys: ", td.keys())

		# Parse ZoneData -> IdleCombatManager
		if td.has("ZoneData"):
			var zone_json = JSON.parse_string(td["ZoneData"])
			if zone_json is Array:
				IdleCombatManager.load_zones_from_title_data(zone_json)
			else:
				push_warning("GameManager: ZoneData is not a valid Array")

		# Parse LootConfig and ItemCatalog -> LootManager (Phase C)
		# LootManager will be wired here once it exists
		if td.has("LootConfig"):
			var loot_config = JSON.parse_string(td["LootConfig"])
			if loot_config is Dictionary:
				LootManager.load_loot_config(loot_config)

		if td.has("ItemCatalog"):
			var item_catalog = JSON.parse_string(td["ItemCatalog"])
			if item_catalog is Dictionary:
				LootManager.load_item_catalog(item_catalog)

		_title_data_ready = true
		_check_all_done()
	)

func _check_all_done():
	if _stats_ready and _currency_ready and _title_data_ready:
		var target_scene = "res://ui/pages/idleHome.tscn"
		get_tree().call_deferred("change_scene_to_file", target_scene)

# ───── Equipment API ─────

func get_slot_for_item(item: ItemData) -> String:
	return TYPE_TO_SLOT.get(item.item_type, "")

func can_equip(item: ItemData) -> Dictionary:
	var slot = get_slot_for_item(item)
	if slot.is_empty():
		return {"ok": false, "reason": "Item type '%s' cannot be equipped" % item.item_type}

	# Class-specific armor check
	if ARMOR_CLASS_REQ.has(item.item_type):
		var required_class = ARMOR_CLASS_REQ[item.item_type]
		if active_character_class != required_class:
			return {"ok": false, "reason": "%s requires %s class" % [item.item_type, required_class]}

	# Level requirement
	if item.level_req > active_character_level:
		return {"ok": false, "reason": "Requires level %d" % item.level_req}

	# Stat requirements
	var stats = active_character_stats
	if item.str_req > 0 and stats.get("Strength", 0) < item.str_req:
		return {"ok": false, "reason": "Requires %d Strength" % item.str_req}
	if item.dex_req > 0 and stats.get("Agility", 0) < item.dex_req:
		return {"ok": false, "reason": "Requires %d Dexterity" % item.dex_req}
	if item.agi_req > 0 and stats.get("Agility", 0) < item.agi_req:
		return {"ok": false, "reason": "Requires %d Agility" % item.agi_req}

	return {"ok": true, "slot": slot}

func equip_item(item: ItemData) -> bool:
	var check = can_equip(item)
	if not check.get("ok", false):
		push_warning("GameManager: Cannot equip %s -- %s" % [item.display_name, check.get("reason", "")])
		return false

	var slot = check["slot"]
	var old_item = equipped_items[slot]

	# Swap: put old item back to inventory (conceptually)
	equipped_items[slot] = item
	print("GameManager: Equipped '%s' in slot '%s'" % [item.display_name, slot])

	equipment_changed.emit()
	return true

func unequip_slot(slot: String) -> ItemData:
	if not equipped_items.has(slot):
		return null
	var item = equipped_items[slot]
	equipped_items[slot] = null
	if item:
		print("GameManager: Unequipped '%s' from slot '%s'" % [item.display_name, slot])
	equipment_changed.emit()
	return item

func build_gear_data() -> Dictionary:
	var gd = {
		"WeaponAtk": 0, "RingAtk": 0, "ArmorDef": 0, "ShieldDef": 0,
		"P-Atk": 0, "P-Def": 0, "WeaponAccuracy": 0, "BootDodge": 0, "PlusDodge": 0
	}

	# Weapon slot: use average of MinAtk/MaxAtk
	var w = equipped_items["Weapon"]
	if w:
		gd["WeaponAtk"] = (w.get_stat("MinAtk") + w.get_stat("MaxAtk")) / 2

	# Ring slot: MinAtk/MaxAtk contribute to RingAtk
	var r = equipped_items["Ring"]
	if r:
		gd["RingAtk"] = (r.get_stat("MinAtk") + r.get_stat("MaxAtk")) / 2

	# Armor + Headgear + Necklace: contribute to ArmorDef
	for slot_name in ["Armor", "Headgear", "Necklace"]:
		var item = equipped_items[slot_name]
		if item:
			gd["ArmorDef"] += item.get_stat("Def")

	# Shield/Offhand
	var s = equipped_items["Offhand"]
	if s and s.item_type == "Shield":
		gd["ShieldDef"] = s.get_stat("Def")

	# Boots: Dodge
	var b = equipped_items["Boots"]
	if b:
		gd["BootDodge"] = b.get_stat("Dodge")

	# Plus-level bonuses from ALL equipped items
	for slot_name in equipped_items:
		var item = equipped_items[slot_name]
		if item and item.plus_level > 0:
			if slot_name in ["Weapon", "Ring"]:
				gd["P-Atk"] += item.plus_level
			else:
				gd["P-Def"] += item.plus_level

	return gd

func get_weapon_speed() -> int:
	var w = equipped_items["Weapon"]
	if w:
		return w.get_stat("Speed")
	return 0
