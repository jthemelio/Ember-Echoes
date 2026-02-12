# ItemDatabase.gd — Resolves item templates (Title Data) + instance data into ItemData resources.
# Two modes:
#   1. parse_playfab_item()  — legacy: raw PlayFab inventory dict -> ItemData
#   2. resolve_instance()    — new: compact instance dict + catalog lookup -> ItemData
extends Node

# ───── Catalog Lookup (built from ItemCatalog Title Data) ─────
# Key = ItemId (e.g. "Steel_Ring_Tempered"), Value = full catalog entry dict
var _catalog_lookup: Dictionary = {}

# ───── Level Upgrade Paths (built at catalog load time) ─────
# Key = base_id (e.g. "Sprout_Bow"), Value = next_base_id (e.g. "Vanguard_Bow")
var _level_paths: Dictionary = {}

# Quality progression order
const QUALITY_ORDER: Array = ["Normal", "Tempered", "Infused", "Brilliant", "Radiant"]

# ───── Catalog Loading ─────

func load_catalog(catalog: Dictionary) -> void:
	_catalog_lookup.clear()
	# Index all known item categories from Title Data
	for category_key in ["armor", "weapons", "misc"]:
		var items = catalog.get(category_key, [])
		for item in items:
			var item_id = item.get("ItemId", "")
			if not item_id.is_empty():
				_catalog_lookup[item_id] = item
	print("ItemDatabase: Catalog indexed (%d entries)" % _catalog_lookup.size())
	_build_level_paths()

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

	if type in ["Blade", "Bow", "Wand", "Mageblade", "Arrow"]:
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
	item.base_amount = int(custom.get("Amount", 1))
	item.amount = int(instance.get("amt", item.base_amount))

	# Apply plus-level bonuses to stats (each +1 adds flat bonus)
	if item.plus_level > 0:
		# Weapons: +level adds to MinAtk and MaxAtk
		if type in ["Blade", "Bow", "Wand", "Mageblade", "Arrow"]:
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

# ───── Level Upgrade Path Builder ─────

func _build_level_paths() -> void:
	_level_paths.clear()
	# Group Normal-quality equippable items by Type
	var by_type: Dictionary = {}  # Type -> Array of { "bid": base_id, "level": LevelReq }
	for item_id in _catalog_lookup:
		var entry = _catalog_lookup[item_id]
		var cd = entry.get("CustomData", {})
		var quality = cd.get("Quality", "Normal")
		if quality != "Normal":
			continue
		var item_type = cd.get("Type", "")
		# Only equipable item types get upgrade paths (skip materials, arrows, etc.)
		if item_type in ["Material", "Arrow", "Item"]:
			continue
		var level = int(cd.get("LevelReq", 0))
		var bid = extract_base_id(item_id)
		if not by_type.has(item_type):
			by_type[item_type] = []
		by_type[item_type].append({"bid": bid, "level": level})

	# Sort each type by level and link sequential pairs
	for item_type in by_type:
		var items = by_type[item_type]
		items.sort_custom(func(a, b): return a["level"] < b["level"])
		for i in range(items.size() - 1):
			_level_paths[items[i]["bid"]] = items[i + 1]["bid"]

	print("ItemDatabase: Level upgrade paths built (%d entries)" % _level_paths.size())

# ───── Upgrade Helper Functions ─────

func get_next_level_base_id(current_bid: String) -> String:
	return _level_paths.get(current_bid, "")

func get_next_quality(current_quality: String) -> String:
	var idx = QUALITY_ORDER.find(current_quality)
	if idx < 0 or idx >= QUALITY_ORDER.size() - 1:
		return ""
	return QUALITY_ORDER[idx + 1]

func can_level_upgrade(instance_dict: Dictionary) -> bool:
	var bid = instance_dict.get("bid", "")
	return not get_next_level_base_id(bid).is_empty()

func can_quality_upgrade(instance_dict: Dictionary) -> bool:
	var quality = instance_dict.get("q", "Normal")
	return not get_next_quality(quality).is_empty()

func preview_level_upgrade(instance_dict: Dictionary) -> ItemData:
	## Returns an ItemData showing what the item would look like after a level upgrade.
	var bid = instance_dict.get("bid", "")
	var next_bid = get_next_level_base_id(bid)
	if next_bid.is_empty():
		return null
	# Create a temporary instance dict with the new base_id, keeping all instance data
	var preview = instance_dict.duplicate()
	preview["bid"] = next_bid
	preview["uid"] = ""  # Preview only, no real uid
	# Resolve durability from new template
	var item_data = resolve_instance(preview)
	item_data.current_dura = item_data.stats.get("MaxDura", 0)
	return item_data

func preview_quality_upgrade(instance_dict: Dictionary) -> ItemData:
	## Returns an ItemData showing what the item would look like after a quality upgrade.
	var quality = instance_dict.get("q", "Normal")
	var next_q = get_next_quality(quality)
	if next_q.is_empty():
		return null
	var preview = instance_dict.duplicate()
	preview["q"] = next_q
	preview["uid"] = ""
	var item_data = resolve_instance(preview)
	item_data.current_dura = item_data.stats.get("MaxDura", 0)
	return item_data

# ───── Catalog Helpers ─────

func get_base_amount(bid: String, quality: String) -> int:
	var catalog_key = bid + "_" + quality
	var template = _catalog_lookup.get(catalog_key, {})
	return int(template.get("CustomData", {}).get("Amount", 1))

func get_max_stack_amount(bid: String, quality: String) -> int:
	return ItemData.MAX_STACKS * get_base_amount(bid, quality)

# ───── Extract base item ID from a full catalog ItemId ─────
# e.g. "Steel_Ring_Normal" -> "Steel_Ring", "Unlucky_Bow_Tempered" -> "Unlucky_Bow"

static func extract_base_id(item_id: String) -> String:
	for q in ["_Normal", "_Tempered", "_Infused", "_Brilliant", "_Radiant"]:
		if item_id.ends_with(q):
			return item_id.substr(0, item_id.length() - q.length())
	return item_id

# ───── Create a compact instance dict from a catalog item ─────
# Used by LootManager and shops to create new item instances

static func create_instance_dict(catalog_item_id: String, quality: String, amount: int = 1) -> Dictionary:
	var bid = extract_base_id(catalog_item_id)
	var inst = {
		"uid": "i_" + str(randi()) + str(randi() % 10000),
		"bid": bid,
		"q": quality,
		"plus": 0,
		"skt": [],
		"ench": {},
		"dura": -1  # -1 means "use template MaxDura" (resolved on first load)
	}
	if amount > 1:
		inst["amt"] = amount
	return inst

# ───── LEGACY: Parse raw PlayFab inventory dict -> ItemData ─────
# Kept for backward compatibility during migration

func parse_playfab_item(pf_item: Dictionary) -> ItemData:
	var custom = pf_item.get("CustomData", {})
	var type = custom.get("Type", "Item")
	var item: ItemData

	if type in ["Blade", "Bow", "Wand", "Mageblade", "Arrow"]:
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
