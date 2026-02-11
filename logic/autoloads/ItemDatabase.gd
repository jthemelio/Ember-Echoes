# ItemDatabase.gd — Resolves item templates (Title Data) + instance data into ItemData resources.
# Two modes:
#   1. parse_playfab_item()  — legacy: raw PlayFab inventory dict -> ItemData
#   2. resolve_instance()    — new: compact instance dict + catalog lookup -> ItemData
extends Node

# ───── Catalog Lookup (built from ItemCatalog Title Data) ─────
# Key = ItemId (e.g. "Steel_Ring_Tempered"), Value = full catalog entry dict
var _catalog_lookup: Dictionary = {}

# ───── Catalog Loading ─────

func load_catalog(catalog: Dictionary) -> void:
	_catalog_lookup.clear()
	var armor = catalog.get("armor", [])
	var weapons = catalog.get("weapons", [])
	for item in armor:
		var item_id = item.get("ItemId", "")
		if not item_id.is_empty():
			_catalog_lookup[item_id] = item
	for item in weapons:
		var item_id = item.get("ItemId", "")
		if not item_id.is_empty():
			_catalog_lookup[item_id] = item
	print("ItemDatabase: Catalog indexed (%d entries)" % _catalog_lookup.size())

# ───── NEW: Resolve compact instance dict -> ItemData ─────
# Instance format: { "uid": "i_abc", "bid": "Steel_Ring", "q": "Normal", "plus": 0, "skt": [], "ench": {}, "dura": 28 }
# Resolves base stats from catalog entry: bid + "_" + q  (e.g. "Steel_Ring_Normal")

func resolve_instance(instance: Dictionary) -> ItemData:
	var bid: String = instance.get("bid", "")
	var quality: String = instance.get("q", "Normal")
	var catalog_key: String = bid + "_" + quality

	var template = _catalog_lookup.get(catalog_key, {})
	if template.is_empty():
		push_warning("ItemDatabase: No catalog entry for '%s'" % catalog_key)
		# Return a minimal ItemData so UI doesn't crash
		var fallback = ItemData.new()
		fallback.instance_id = instance.get("uid", "")
		fallback.item_id = bid
		fallback.display_name = bid.replace("_", " ")
		fallback.quality = quality
		return fallback

	# Parse template stats (same logic as parse_playfab_item)
	var custom = template.get("CustomData", {})
	var type = custom.get("Type", "Item")
	var item: ItemData

	if type in ["Blade", "Bow", "Wand", "Mageblade"]:
		item = WeaponData.new()
		item.min_attack = int(custom.get("MinAtk", 0))
		item.max_attack = int(custom.get("MaxAtk", 0))
		item.magic_attack = int(custom.get("MagicAtk", 0))
		item.strength_req = int(custom.get("StrReq", 0))
		item.dexterity_req = int(custom.get("DexReq", 0))
	elif type in ["Armor", "Vestment", "Coat", "Necklace", "Hat", "Crown", "Helmet", "Boots", "Ring", "Shield"]:
		item = EquipmentData.new()
		item.physical_defense = int(custom.get("Def", 0))
		item.magic_defense = int(custom.get("MagicDef", 0))
	else:
		item = ItemData.new()

	# Core identity (from template)
	item.item_id = bid
	item.instance_id = instance.get("uid", "")
	item.display_name = template.get("DisplayName", bid.replace("_", " "))
	item.item_class = template.get("ItemClass", "")
	item.item_type = type
	item.quality = quality

	# Requirements (from template)
	item.level_req = int(custom.get("LevelReq", 0))
	item.str_req = int(custom.get("StrReq", 0))
	item.dex_req = int(custom.get("DexReq", 0))
	item.agi_req = int(custom.get("AgiReq", 0))

	# Economy (from template)
	item.price = int(custom.get("Price", 0))

	# Universal stats dict (from template)
	for stat_name in item.stats.keys():
		if custom.has(stat_name):
			item.stats[stat_name] = int(custom[stat_name])

	# ── Instance-specific data (from the compact dict) ──
	item.plus_level = int(instance.get("plus", 0))
	item.current_dura = int(instance.get("dura", item.stats.get("MaxDura", 0)))
	item.sockets = instance.get("skt", []).size()
	item.socket_gems = instance.get("skt", [])
	item.enchantments = instance.get("ench", {})

	# Apply plus-level bonuses to stats (each +1 adds flat bonus)
	if item.plus_level > 0:
		# Weapons: +level adds to MinAtk and MaxAtk
		if type in ["Blade", "Bow", "Wand", "Mageblade"]:
			item.stats["MinAtk"] += item.plus_level
			item.stats["MaxAtk"] += item.plus_level
		# Armor: +level adds to Def
		else:
			item.stats["Def"] += item.plus_level

	# Apply enchantment bonuses to stats
	for ench_stat in item.enchantments:
		if item.stats.has(ench_stat):
			item.stats[ench_stat] += int(item.enchantments[ench_stat])

	return item

# ───── Extract base item ID from a full catalog ItemId ─────
# e.g. "Steel_Ring_Normal" -> "Steel_Ring", "Unlucky_Bow_Tempered" -> "Unlucky_Bow"

static func extract_base_id(item_id: String) -> String:
	for q in ["_Normal", "_Tempered", "_Infused", "_Brilliant", "_Radiant"]:
		if item_id.ends_with(q):
			return item_id.substr(0, item_id.length() - q.length())
	return item_id

# ───── Create a compact instance dict from a catalog item ─────
# Used by LootManager and shops to create new item instances

static func create_instance_dict(catalog_item_id: String, quality: String) -> Dictionary:
	var bid = extract_base_id(catalog_item_id)
	return {
		"uid": "i_" + str(randi()) + str(randi() % 10000),
		"bid": bid,
		"q": quality,
		"plus": 0,
		"skt": [],
		"ench": {},
		"dura": -1  # -1 means "use template MaxDura" (resolved on first load)
	}

# ───── LEGACY: Parse raw PlayFab inventory dict -> ItemData ─────
# Kept for backward compatibility during migration

func parse_playfab_item(pf_item: Dictionary) -> ItemData:
	var custom = pf_item.get("CustomData", {})
	var type = custom.get("Type", "Item")
	var item: ItemData

	if type in ["Blade", "Bow", "Wand", "Mageblade"]:
		item = WeaponData.new()
		item.min_attack = int(custom.get("MinAtk", 0))
		item.max_attack = int(custom.get("MaxAtk", 0))
		item.magic_attack = int(custom.get("MagicAtk", 0))
		item.strength_req = int(custom.get("StrReq", 0))
		item.dexterity_req = int(custom.get("DexReq", 0))
	elif type in ["Armor", "Vestment", "Coat", "Necklace", "Hat", "Crown", "Helmet", "Boots", "Ring", "Shield"]:
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

	# Universal stats dict
	for stat_name in item.stats.keys():
		if custom.has(stat_name):
			item.stats[stat_name] = int(custom[stat_name])

	# Instance data
	item.plus_level = int(custom.get("PlusLevel", 0))
	item.sockets = int(custom.get("Sockets", 0))
	item.current_dura = int(custom.get("CurrentDura", item.stats["MaxDura"]))

	return item
