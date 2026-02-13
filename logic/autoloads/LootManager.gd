# LootManager.gd — Client-side loot rolling with batched PlayFab verification
# Loads LootConfig and ItemCatalog from PlayFab Title Data.
# On mob kill: rolls loot locally ("ghost loot") as compact instance dicts, shows it immediately.
# Every HEARTBEAT_INTERVAL seconds: sends a batch report to PlayFab CloudScript for verification.
extends Node

# ───── Signals ─────
signal loot_dropped(item_data: ItemData)  # Emitted when ghost loot is rolled
signal gold_earned(amount: int)           # Emitted when gold is awarded
signal batch_verified(result: Dictionary) # Emitted when PlayFab confirms a batch

# ───── Configuration (loaded from PlayFab LootConfig) ─────
var global_item_chance: float = 0.02
var gold_multiplier: int = 8
var level_range: int = 5
var quality_chances: Dictionary = {
	"Normal": 0.80,
	"Tempered": 0.15,
	"Infused": 0.04,
	"Brilliant": 0.009,
	"Radiant": 0.001
}

# ───── Item catalog (loaded from PlayFab ItemCatalog) ─────
# Combined flat array of all catalog entries (armor[] + weapons[])
var _all_items: Array = []

# ───── Heartbeat ─────
const HEARTBEAT_INTERVAL: float = 10.0  # Seconds between batch reports
var _heartbeat_timer: Timer = null

# ───── Pending data (accumulated between heartbeats) ─────
var _pending_kills: Dictionary = {}      # mob_id -> {count, rareCount}
var _pending_items: Array = []           # Array of compact instance dicts to persist
var _pending_gold: int = 0
var _pending_xp: int = 0

func _ready():
	_heartbeat_timer = Timer.new()
	_heartbeat_timer.wait_time = HEARTBEAT_INTERVAL
	_heartbeat_timer.one_shot = false
	_heartbeat_timer.timeout.connect(_send_batch_report)
	add_child(_heartbeat_timer)

	# Connect to combat signals
	IdleCombatManager.mob_slain.connect(_on_mob_slain)

# ───── Data Loading ─────

func load_loot_config(config: Dictionary) -> void:
	global_item_chance = config.get("global_item_chance", 0.02)
	gold_multiplier = config.get("gold_multiplier", 8)
	level_range = config.get("level_range", 5)
	var qc = config.get("quality_chances", {})
	if not qc.is_empty():
		quality_chances = qc
	print("LootManager: Config loaded (item_chance=%.2f%%, gold_mult=%d)" % [global_item_chance * 100, gold_multiplier])

func load_item_catalog(catalog: Dictionary) -> void:
	_all_items.clear()
	for category_key in ["armor", "weapons", "misc"]:
		var items = catalog.get(category_key, [])
		_all_items.append_array(items)
	print("LootManager: Catalog loaded (%d total items)" % _all_items.size())

	# Start heartbeat once we have data
	if not _heartbeat_timer.is_stopped():
		_heartbeat_timer.stop()
	_heartbeat_timer.start()

# ───── Mob Kill Handler ─────

func _on_mob_slain(mob_data: Dictionary) -> void:
	var mob_id = mob_data.get("id", "")
	var mob_xp = mob_data.get("xp", 0)
	var mob_level = mob_data.get("level", 1)
	var is_rare = mob_data.get("is_rare", false)
	var loot_rolls = IdleCombatManager.RARE_LOOT_ROLLS if is_rare else 1

	# Track kills for batch report
	if not _pending_kills.has(mob_id):
		_pending_kills[mob_id] = {"count": 0, "rareCount": 0}
	if is_rare:
		_pending_kills[mob_id]["rareCount"] += 1
	else:
		_pending_kills[mob_id]["count"] += 1

	# Award gold
	var gold = mob_xp * gold_multiplier
	_pending_gold += gold
	gold_earned.emit(gold)

	# Track XP for batch report
	_pending_xp += mob_xp

	# Roll loot
	for i in range(loot_rolls):
		_roll_loot(mob_level)

	# Roll rare material drops (independent of normal loot)
	_roll_rare_materials()

# ───── Rare Material Drop Rates ─────
const COMET_DROP_CHANCE: float = 1.0 / 400.0     # 1 in 400
const WYRM_SPHERE_DROP_CHANCE: float = 1.0 / 4000.0  # 1 in 4000

func _roll_rare_materials() -> void:
	# Comet drop
	if randf() < COMET_DROP_CHANCE:
		var instance = ItemDatabase.create_instance_dict("Comet_Normal", "Normal")
		instance["dura"] = 0
		GameManager.add_to_bag(instance)
		_pending_items.append(instance.duplicate())
		var item_data = ItemDatabase.resolve_instance(instance)
		loot_dropped.emit(item_data)
		GlobalUI.show_comet_effect("Comet")
		print("LootManager: Rare drop -- Comet!")

	# Wyrm Sphere drop
	if randf() < WYRM_SPHERE_DROP_CHANCE:
		var instance = ItemDatabase.create_instance_dict("Wyrm_Sphere_Normal", "Normal")
		instance["dura"] = 0
		GameManager.add_to_bag(instance)
		_pending_items.append(instance.duplicate())
		var item_data = ItemDatabase.resolve_instance(instance)
		loot_dropped.emit(item_data)
		GlobalUI.show_comet_effect("Wyrm Sphere", true)
		print("LootManager: Rare drop -- Wyrm Sphere!")

# ───── Loot Rolling Algorithm ─────

func _roll_loot(mob_level: int) -> void:
	# Step 1: Roll global item chance (2%)
	if randf() > global_item_chance:
		return  # No drop

	if _all_items.is_empty():
		return  # No catalog loaded

	# Step 2: Filter to Normal quality items within level range
	# We pick a base item, then roll quality separately
	var eligible: Array = []
	for item in _all_items:
		var cd = item.get("CustomData", {})
		var item_level = int(cd.get("LevelReq", 0))
		var item_quality = cd.get("Quality", "Normal")
		# Only consider Normal quality as base pool (avoid duplicate rolls from Tempered variants)
		if item_quality != "Normal":
			continue
		# Exclude non-droppable types from mob loot
		var item_type = cd.get("Type", "")
		if item_type in ["Material", "Arrow", "MoneyBag", "Consumable", "Scroll", "Chest"]:
			continue
		if abs(item_level - mob_level) <= level_range:
			eligible.append(item)

	if eligible.is_empty():
		return

	# Step 3: Pick a random base item from eligible pool
	var base_item = eligible[randi() % eligible.size()]
	var base_item_id = base_item.get("ItemId", "")  # e.g. "Steel_Ring_Normal"

	# Step 4: Roll quality tier
	var quality = _roll_quality()

	# Step 5: Create compact instance dict
	var instance_dict = ItemDatabase.create_instance_dict(base_item_id, quality)

	# Step 6: Resolve to ItemData and set durability from template if not set
	var item_data = ItemDatabase.resolve_instance(instance_dict)
	if instance_dict.get("dura", -1) == -1:
		instance_dict["dura"] = item_data.stats.get("MaxDura", 0)

	# Step 7: Add to bag and pending report
	GameManager.add_to_bag(instance_dict)
	_pending_items.append(instance_dict.duplicate())
	loot_dropped.emit(item_data)

func _roll_quality() -> String:
	var roll = randf()
	var cumulative = 0.0
	for quality_name in ["Normal", "Tempered", "Infused", "Brilliant", "Radiant"]:
		cumulative += quality_chances.get(quality_name, 0.0)
		if roll <= cumulative:
			return quality_name
	return "Normal"

# ───── Batch Report to PlayFab ─────

func _send_batch_report() -> void:
	if _pending_kills.is_empty():
		return  # Nothing to report

	var kills_array: Array = []
	for mob_id in _pending_kills:
		var entry = _pending_kills[mob_id]
		kills_array.append({
			"mobId": mob_id,
			"count": entry["count"],
			"rareCount": entry["rareCount"]
		})

	var args = {
		"characterId": GameManager.active_character_id,
		"zone": IdleCombatManager.current_zone,
		"kills": kills_array,
		"claimedItems": _pending_items.duplicate(),
		"claimedGold": _pending_gold,
		"claimedXP": _pending_xp,
		"elapsedSeconds": HEARTBEAT_INTERVAL
	}

	print("LootManager: Sending batch report (%d kill entries, %d items, %d gold, %d XP)" % [
		kills_array.size(), _pending_items.size(), _pending_gold, _pending_xp
	])

	PlayFabManager.client.execute_cloud_script("batchKillReport", args, _on_batch_verified)
	_reset_pending()

func _on_batch_verified(result: Dictionary) -> void:
	var fn_result = result.get("data", {}).get("FunctionResult", {})
	if fn_result is Dictionary and fn_result.get("success", false):
		print("LootManager: Batch verified (%d kills confirmed)" % fn_result.get("totalKillsVerified", 0))
		batch_verified.emit(fn_result)
	else:
		var error = "Unknown error"
		if fn_result is Dictionary:
			error = fn_result.get("error", "Unknown error")
		push_warning("LootManager: Batch rejected -- %s" % error)

func _reset_pending() -> void:
	_pending_kills.clear()
	_pending_items.clear()
	_pending_gold = 0
	_pending_xp = 0

# ───── Utility for offline batch rolling ─────

func batch_roll_loot(mob_level: int, kill_count: int, rare_count: int) -> Array:
	var items: Array = []
	var total_rolls = kill_count + (rare_count * IdleCombatManager.RARE_LOOT_ROLLS)
	var before_size = GameManager.active_user_inventory.size()
	for i in range(total_rolls):
		_roll_loot(mob_level)
	# Collect any new items added to inventory
	for j in range(before_size, GameManager.active_user_inventory.size()):
		var instance_dict = GameManager.active_user_inventory[j]
		items.append(ItemDatabase.resolve_instance(instance_dict))
	return items
