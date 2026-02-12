extends Node

signal character_stats_updated
signal equipment_changed
signal inventory_changed
signal changelog_updated          # Emitted when new changelog entries are detected

var active_character_stats: Dictionary = {}
var active_user_currencies: Dictionary = {}
var active_character_id: String = ""
var active_character_name: String = ""
var active_character_class: String = ""
var active_character_level: int = 1
var active_character_awakening: int = 0
var _saved_current_xp: int = 0  # Loaded from PlayFab, passed to IdleCombatManager on combat start

# ───── Internal Data Inventory (compact instance dicts) ─────
# Each entry is: { "uid", "bid", "q", "plus", "skt", "ench", "dura" }
var active_user_inventory: Array = []  # Inv_Bag contents

# ───── Equipment System (8 slots) ─────
# Values are compact instance dicts (or null if empty)
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

# ───── Settings / Preferences ─────
var show_afk_summary: bool = true  # Toggle for AFK rewards popup display

# ───── Lady Luck ─────
# Free roll status is fetched by lady_luck_shop.gd when the tab opens.
# LT and ET currency balances are available via active_user_currencies (loaded at login).

# ───── Changelog System ─────
# Array of dicts: [{v, date, title, changes[]}], newest first
var changelog_entries: Array = []
var last_seen_changelog_version: String = ""
var _changelog_poll_timer: Timer = null
const CHANGELOG_POLL_INTERVAL: float = 300.0  # 5 minutes

# Maps item Type (from PlayFab CustomData) to equipment slot
const TYPE_TO_SLOT: Dictionary = {
	"Blade": "Weapon", "Bow": "Weapon", "Wand": "Weapon",
	"Armor": "Armor", "Vestment": "Armor", "Coat": "Armor",
	"Hat": "Headgear", "Crown": "Headgear", "Helmet": "Headgear",
	"Ring": "Ring",
	"Necklace": "Necklace",
	"Boots": "Boots",
	"Shield": "Offhand", "Arrow": "Offhand",
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
var _inventory_ready: bool = false
var _achievements_ready: bool = false
var _changelog_ready: bool = false

func start_game_with_character(data: Dictionary):
	active_character_id = data.get("CharacterId", "")
	active_character_name = data.get("CharacterName", "")
	active_character_class = data.get("Class", "")
	active_character_level = int(data.get("Level", 1))
	active_character_awakening = int(data.get("AwakeningCount", 0))

	_stats_ready = false
	_currency_ready = false
	_title_data_ready = false
	_inventory_ready = false
	_achievements_ready = false
	_changelog_ready = false

	print("GameManager: Starting login for ", active_character_name)

	# 1. Fetch Character Stats
	PlayFabManager.client.get_character_statistics(active_character_id, func(result):
		var stats_dict = result.get("data", {}).get("CharacterStatistics", {})
		var new_stats = {"Strength": 0, "Agility": 0, "Vitality": 0, "Spirit": 0, "AvailableAttributePoints": 0}
		for key in stats_dict.keys():
			if new_stats.has(key):
				new_stats[key] = int(stats_dict[key])
			elif key == "Level":
				active_character_level = int(stats_dict[key])
			elif key == "CurrentXP":
				_saved_current_xp = int(stats_dict[key])

		active_character_stats = new_stats
		_stats_ready = true
		print("GameManager: Stats received. Level: %d, XP: %d" % [active_character_level, _saved_current_xp])
		_check_all_done()
	)

	# 2. Fetch User Currencies (still uses PlayFab native VirtualCurrency)
	var inventory_request = PlayFabManager.client.GetUserInventoryRequest.new()
	PlayFabManager.client.get_user_inventory(inventory_request, func(result):
		var inv_data = result.get("data", {})
		active_user_currencies = inv_data.get("VirtualCurrency", {})

		_currency_ready = true
		print("GameManager: Currencies received. Gold: ", active_user_currencies.get("GD", 0))
		_check_all_done()
	)

	# 3. Fetch Title Data (ZoneData, LootConfig, ItemCatalog, ChangeLog)
	var title_request = GetTitleDataRequest.new()
	title_request.Keys = ["ZoneData", "LootConfig", "ItemCatalog", "ChangeLog"]
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

		# Parse LootConfig -> LootManager
		if td.has("LootConfig"):
			var loot_config = JSON.parse_string(td["LootConfig"])
			if loot_config is Dictionary:
				LootManager.load_loot_config(loot_config)

		# Parse ItemCatalog -> ItemDatabase (catalog lookup) AND LootManager (flat list)
		if td.has("ItemCatalog"):
			var item_catalog = JSON.parse_string(td["ItemCatalog"])
			if item_catalog is Dictionary:
				ItemDatabase.load_catalog(item_catalog)
				LootManager.load_item_catalog(item_catalog)

		# Parse ChangeLog entries
		if td.has("ChangeLog"):
			var cl_json = JSON.parse_string(td["ChangeLog"])
			if cl_json is Array:
				changelog_entries = cl_json
				print("GameManager: ChangeLog loaded. %d entries" % cl_json.size())

		_title_data_ready = true
		_check_all_done()
	)

	# 4. Fetch Character Internal Data (Inv_Bag, Inv_Equipped)
	PlayFabManager.client.execute_cloud_script("getCharacterInventory", {
		"characterId": active_character_id
	}, func(result):
		var fn_result = result.get("data", {}).get("FunctionResult", {})
		if fn_result is Dictionary:
			# Parse Inv_Bag
			var bag_json = fn_result.get("bag", [])
			if bag_json is Array:
				active_user_inventory = bag_json
			else:
				active_user_inventory = []

			# Parse Inv_Equipped
			var eq_json = fn_result.get("equipped", {})
			if eq_json is Dictionary:
				for slot_name in equipped_items.keys():
					if eq_json.has(slot_name) and eq_json[slot_name] != null:
						equipped_items[slot_name] = eq_json[slot_name]
					else:
						equipped_items[slot_name] = null
			else:
				# Reset equipped
				for slot_name in equipped_items.keys():
					equipped_items[slot_name] = null

			print("GameManager: Inventory loaded. Bag: %d items, Equipped: %d slots" % [
				active_user_inventory.size(),
				_count_equipped()
			])
		else:
			print("GameManager: No inventory data found (new character?)")
			active_user_inventory = []
			for slot_name in equipped_items.keys():
				equipped_items[slot_name] = null

		_inventory_ready = true
		_check_all_done()
	)

	# 5. Fetch Account Achievements (User Internal Data)
	PlayFabManager.client.execute_cloud_script("loadAchievements", {}, func(result):
		var fn_result = result.get("data", {}).get("FunctionResult", {})
		if fn_result is Dictionary and fn_result.get("success", false):
			var ach_data = fn_result.get("data", {})
			var ach_mgr = get_node_or_null("/root/AchievementManager")
			if ach_mgr:
				ach_mgr.load_from_playfab(ach_data)
		else:
			print("GameManager: No achievement data found (new account?)")

		_achievements_ready = true
		_check_all_done()
	)

	# 6. Fetch Account Settings (last seen changelog version)
	PlayFabManager.client.execute_cloud_script("getAccountSettings", {}, func(result):
		var fn_result = result.get("data", {}).get("FunctionResult", {})
		if fn_result is Dictionary and fn_result.get("success", false):
			last_seen_changelog_version = fn_result.get("lastSeenChangelog", "")
			print("GameManager: Last seen changelog: '%s'" % last_seen_changelog_version)
		else:
			print("GameManager: No account settings found (new account?)")
			last_seen_changelog_version = ""

		_changelog_ready = true
		_check_all_done()
	)

func _count_equipped() -> int:
	var count = 0
	for slot_name in equipped_items:
		if equipped_items[slot_name] != null:
			count += 1
	return count

func _check_all_done():
	if _stats_ready and _currency_ready and _title_data_ready and _inventory_ready and _achievements_ready and _changelog_ready:
		# Start the changelog live-poll timer
		_start_changelog_poll()
		var target_scene = "res://ui/pages/idleHome.tscn"
		get_tree().call_deferred("change_scene_to_file", target_scene)

# ───── Equipment API ─────

func get_slot_for_item(item: ItemData) -> String:
	return TYPE_TO_SLOT.get(item.item_type, "")

func can_equip(item: ItemData) -> Dictionary:
	var slot = get_slot_for_item(item)
	if slot.is_empty():
		return {"ok": false, "reason": "Item type '%s' cannot be equipped" % item.item_type}

	# Arrow class check (Marksman only)
	if item.item_type == "Arrow" and item.item_class != "All_Classes":
		if active_character_class != item.item_class:
			return {"ok": false, "reason": "Arrows require %s class" % item.item_class}

	# Class-specific armor check (skip if item is All_Classes)
	if item.item_class != "All_Classes" and ARMOR_CLASS_REQ.has(item.item_type):
		var required_class = ARMOR_CLASS_REQ[item.item_type]
		if active_character_class != required_class:
			return {"ok": false, "reason": "%s requires %s class" % [item.item_type, required_class]}

	# Level requirement
	if item.level_req > active_character_level:
		return {"ok": false, "reason": "Requires level %d" % item.level_req}

	# Stat requirements -- use total stats (class base + invested), not just invested
	var class_base = StatCalculator.get_smart_allocated_stats(active_character_class, active_character_level)
	var total_str = int(class_base.get("Strength", 0)) + int(active_character_stats.get("Strength", 0))
	var total_agi = int(class_base.get("Agility", 0)) + int(active_character_stats.get("Agility", 0))

	if item.str_req > 0 and total_str < item.str_req:
		return {"ok": false, "reason": "Requires %d Strength" % item.str_req}
	if item.dex_req > 0 and total_agi < item.dex_req:
		return {"ok": false, "reason": "Requires %d Dexterity" % item.dex_req}
	if item.agi_req > 0 and total_agi < item.agi_req:
		return {"ok": false, "reason": "Requires %d Agility" % item.agi_req}

	return {"ok": true, "slot": slot}

func equip_item_by_uid(uid: String) -> bool:
	# Find the compact dict in bag by uid
	var bag_index = -1
	var instance_dict: Dictionary = {}
	for i in range(active_user_inventory.size()):
		if active_user_inventory[i] is Dictionary and active_user_inventory[i].get("uid", "") == uid:
			bag_index = i
			instance_dict = active_user_inventory[i]
			break

	if bag_index == -1:
		push_warning("GameManager: Item uid '%s' not found in bag" % uid)
		return false

	# Resolve to check requirements
	var item_data = ItemDatabase.resolve_instance(instance_dict)
	var check = can_equip(item_data)
	if not check.get("ok", false):
		push_warning("GameManager: Cannot equip %s -- %s" % [item_data.display_name, check.get("reason", "")])
		return false

	var slot = check["slot"]
	var old_equipped = equipped_items[slot]

	# ── Arrow / stackable equip logic (5 packs max in offhand) ──
	if item_data.is_stackable():
		var bag_amt = int(instance_dict.get("amt", 1))
		var bid = instance_dict.get("bid", "")
		var quality = instance_dict.get("q", "Normal")
		var equip_max = ItemDatabase.get_max_stack_amount(bid, quality)  # 5 * base_amount

		if old_equipped != null and old_equipped.get("bid", "") == bid and old_equipped.get("q", "") == quality:
			# Same arrow type already equipped — top up
			var current_equipped = int(old_equipped.get("amt", 0))
			var space = equip_max - current_equipped
			if space <= 0:
				push_warning("GameManager: Arrow slot full (%d/%d)" % [current_equipped, equip_max])
				return false
			var transfer = mini(space, bag_amt)
			old_equipped["amt"] = current_equipped + transfer
			if transfer >= bag_amt:
				active_user_inventory.remove_at(bag_index)
			else:
				instance_dict["amt"] = bag_amt - transfer
		else:
			# Different type or empty slot — swap
			if old_equipped != null:
				active_user_inventory.append(old_equipped)
			var transfer = mini(equip_max, bag_amt)
			var equip_dict = instance_dict.duplicate()
			equip_dict["amt"] = transfer
			equipped_items[slot] = equip_dict
			if transfer >= bag_amt:
				active_user_inventory.remove_at(bag_index)
			else:
				instance_dict["amt"] = bag_amt - transfer

		print("GameManager: Equipped arrows '%s' (%d) in slot '%s'" % [item_data.display_name, int(equipped_items[slot].get("amt", 0)), slot])
		equipment_changed.emit()
		inventory_changed.emit()
		sync_inventory_to_server()
		return true

	# ── Standard (non-stackable) equip logic ──
	# Move old equipped item back to bag (if any)
	if old_equipped != null:
		active_user_inventory.append(old_equipped)

	# Equip new item and remove from bag
	equipped_items[slot] = instance_dict
	active_user_inventory.remove_at(bag_index)

	print("GameManager: Equipped '%s' in slot '%s'" % [item_data.display_name, slot])
	equipment_changed.emit()
	inventory_changed.emit()

	# Persist to PlayFab
	sync_inventory_to_server()
	return true

# Legacy equip (from ItemData) -- resolves uid internally
func equip_item(item: ItemData) -> bool:
	if item.instance_id.is_empty():
		push_warning("GameManager: Cannot equip item without instance_id")
		return false
	return equip_item_by_uid(item.instance_id)

func unequip_slot(slot: String) -> ItemData:
	if not equipped_items.has(slot):
		return null
	var instance_dict = equipped_items[slot]
	if instance_dict == null:
		return null

	# Move to bag
	equipped_items[slot] = null
	active_user_inventory.append(instance_dict)

	var item_data = ItemDatabase.resolve_instance(instance_dict)
	print("GameManager: Unequipped '%s' from slot '%s'" % [item_data.display_name, slot])
	equipment_changed.emit()
	inventory_changed.emit()

	# Persist to PlayFab
	sync_inventory_to_server()
	return item_data

# ───── Resolved Equipment Access (for combat/stat calculations) ─────

func get_equipped_item_data(slot: String) -> ItemData:
	var instance_dict = equipped_items.get(slot)
	if instance_dict == null or not instance_dict is Dictionary:
		return null
	return ItemDatabase.resolve_instance(instance_dict)

func build_gear_data() -> Dictionary:
	var gd = {
		"WeaponAtk": 0, "RingAtk": 0, "ArmorDef": 0, "ShieldDef": 0,
		"P-Atk": 0, "P-Def": 0, "WeaponAccuracy": 0, "BootDodge": 0, "PlusDodge": 0
	}

	# Weapon slot
	var w = get_equipped_item_data("Weapon")
	if w:
		gd["WeaponAtk"] = (w.get_stat("MinAtk") + w.get_stat("MaxAtk")) / 2

	# Ring slot
	var r = get_equipped_item_data("Ring")
	if r:
		gd["RingAtk"] = (r.get_stat("MinAtk") + r.get_stat("MaxAtk")) / 2

	# Armor + Headgear + Necklace: contribute to ArmorDef
	for slot_name in ["Armor", "Headgear", "Necklace"]:
		var item = get_equipped_item_data(slot_name)
		if item:
			gd["ArmorDef"] += item.get_stat("Def")

	# Shield/Offhand
	var s = get_equipped_item_data("Offhand")
	if s and s.item_type == "Shield":
		gd["ShieldDef"] = s.get_stat("Def")

	# Boots: Dodge
	var b = get_equipped_item_data("Boots")
	if b:
		gd["BootDodge"] = b.get_stat("Dodge")

	# Plus-level bonuses from ALL equipped items
	for slot_name in equipped_items:
		var item = get_equipped_item_data(slot_name)
		if item and item.plus_level > 0:
			if slot_name in ["Weapon", "Ring"]:
				gd["P-Atk"] += item.plus_level
			else:
				gd["P-Def"] += item.plus_level

	return gd

func get_weapon_speed() -> int:
	var w = get_equipped_item_data("Weapon")
	if w:
		return w.get_stat("Speed")
	return 0

# ───── Material Helpers ─────

func get_total_material_count(currency_code: String) -> int:
	## Returns the total count of a material: currency balance + inventory item count.
	## currency_code: "CM" for Comets, "WS" for Wyrm Spheres
	var total = int(active_user_currencies.get(currency_code, 0))
	# Map currency code to inventory bid
	var bid_map = {"CM": "Comet", "WS": "Wyrm_Sphere"}
	var bid = bid_map.get(currency_code, "")
	if not bid.is_empty():
		for item in active_user_inventory:
			if item is Dictionary and item.get("bid", "") == bid:
				total += 1
	return total

func consume_material(currency_code: String) -> bool:
	## Consumes 1 material: prefers currency first, then removes an inventory item.
	## Returns true if consumed successfully.
	var currency_bal = int(active_user_currencies.get(currency_code, 0))
	if currency_bal > 0:
		active_user_currencies[currency_code] = currency_bal - 1
		return true
	# Fallback: remove from inventory
	var bid_map = {"CM": "Comet", "WS": "Wyrm_Sphere"}
	var bid = bid_map.get(currency_code, "")
	if not bid.is_empty():
		for i in range(active_user_inventory.size()):
			var item = active_user_inventory[i]
			if item is Dictionary and item.get("bid", "") == bid:
				active_user_inventory.remove_at(i)
				return true
	return false

# ───── Changelog Helpers ─────

func get_latest_changelog_version() -> String:
	if changelog_entries.is_empty():
		return ""
	return changelog_entries[0].get("v", "")

func has_unseen_changelog() -> bool:
	var latest = get_latest_changelog_version()
	if latest.is_empty():
		return false
	return latest != last_seen_changelog_version

func get_unseen_changelog_entries() -> Array:
	## Returns all entries newer than the last seen version.
	if last_seen_changelog_version.is_empty():
		# Never viewed -- show just the latest entry (not the entire history)
		if changelog_entries.size() > 0:
			return [changelog_entries[0]]
		return []

	var unseen: Array = []
	for entry in changelog_entries:
		if entry.get("v", "") == last_seen_changelog_version:
			break
		unseen.append(entry)
	return unseen

func mark_changelog_seen() -> void:
	var latest = get_latest_changelog_version()
	if latest.is_empty():
		return
	last_seen_changelog_version = latest
	# Persist to PlayFab (account-wide)
	PlayFabManager.client.execute_cloud_script("updateAccountSettings", {
		"lastSeenChangelog": latest
	}, func(result):
		var fn_result = result.get("data", {}).get("FunctionResult", {})
		if fn_result is Dictionary and fn_result.get("success", false):
			print("GameManager: Changelog marked as seen (v%s)" % latest)
		else:
			push_warning("GameManager: Failed to save changelog seen status")
	)

func _start_changelog_poll() -> void:
	if _changelog_poll_timer != null:
		return  # Already running
	_changelog_poll_timer = Timer.new()
	_changelog_poll_timer.wait_time = CHANGELOG_POLL_INTERVAL
	_changelog_poll_timer.one_shot = false
	_changelog_poll_timer.timeout.connect(_poll_changelog)
	add_child(_changelog_poll_timer)
	_changelog_poll_timer.start()
	print("GameManager: Changelog poll started (every %ds)" % int(CHANGELOG_POLL_INTERVAL))

func _poll_changelog() -> void:
	# Re-fetch only the ChangeLog key from Title Data
	var request = GetTitleDataRequest.new()
	request.Keys = ["ChangeLog"]
	PlayFabManager.client.get_title_data(request, func(result):
		var td = result.get("data", {}).get("Data", {})
		if not td.has("ChangeLog"):
			return
		var cl_json = JSON.parse_string(td["ChangeLog"])
		if not cl_json is Array:
			return

		var old_latest = get_latest_changelog_version()
		changelog_entries = cl_json
		var new_latest = get_latest_changelog_version()

		if new_latest != old_latest and not new_latest.is_empty():
			print("GameManager: New changelog detected! v%s -> v%s" % [old_latest, new_latest])
			changelog_updated.emit()
	)

# ───── Server Sync ─────

func sync_inventory_to_server() -> void:
	PlayFabManager.client.execute_cloud_script("syncInventory", {
		"characterId": active_character_id,
		"bag": active_user_inventory,
		"equipped": equipped_items
	}, func(result):
		var fn_result = result.get("data", {}).get("FunctionResult", {})
		if fn_result is Dictionary and fn_result.get("success", false):
			print("GameManager: Inventory synced to server")
		else:
			push_warning("GameManager: Inventory sync failed")
	)

func sync_character_progress_to_server() -> void:
	## Saves Level, CurrentXP, and AvailableAttributePoints to PlayFab Character Statistics.
	var xp_value = IdleCombatManager.current_xp if IdleCombatManager else 0
	var stats_array = [
		{"StatisticName": "Level", "Value": active_character_level},
		{"StatisticName": "CurrentXP", "Value": xp_value},
		{"StatisticName": "AvailableAttributePoints", "Value": int(active_character_stats.get("AvailableAttributePoints", 0))}
	]
	PlayFabManager.client.update_character_statistics(active_character_id, stats_array, func(result):
		if result.get("data", null) != null:
			print("GameManager: Progress synced (Level %d, XP %d)" % [active_character_level, xp_value])
		else:
			push_warning("GameManager: Progress sync failed: %s" % str(result))
	)
