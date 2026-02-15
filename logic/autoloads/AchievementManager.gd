# AchievementManager.gd — Tracks kill achievements, pet drops, and Wyrm Sphere claiming.
# Account-wide data persisted to PlayFab User Internal Data.
extends Node

# ───── Signals ─────
signal kill_achievement_updated(monster_id: String, kills: int)
signal achievement_claimed(monster_id: String, tier: int)
signal pet_obtained(pet_name: String)

# ───── Kill Tier Thresholds ─────
const KILL_TIERS := [100, 500, 1000, 2000, 5000]
const RARE_BONUS_PER_TIER := [0.01, 0.01, 0.01, 0.01, 0.01]  # +1% rare spawn bonus per tier

# Reward item per tier: first two tiers give Comets, remaining give Wyrm Spheres
const TIER_REWARDS := ["Comet", "Comet", "Wyrm_Sphere", "Wyrm_Sphere", "Wyrm_Sphere"]
const TIER_REWARD_NAMES := ["Comet", "Comet", "Wyrm Sphere", "Wyrm Sphere", "Wyrm Sphere"]

# ───── Pet Drop ─────
const PET_DROP_CHANCE: float = 1.0 / 4000.0  # 1 in 4000

# ───── State ─────
# monster_kills: { "Peacock": 142, "Pheasant": 55, ... }  (account-wide)
var monster_kills: Dictionary = {}

# claimed_tiers: { "Peacock": [0, 1], "Pheasant": [] }  (which tiers have been claimed)
var claimed_tiers: Dictionary = {}

# pets_obtained: { "Baby Peacock": true, "Baby Pheasant": true }
var pets_obtained: Dictionary = {}

# Dirty flag for batching saves
var _dirty: bool = false
var _save_timer: Timer = null

func _ready():
	# Connect to IdleCombatManager mob_slain signal
	var icm = get_node_or_null("/root/IdleCombatManager")
	if icm:
		icm.mob_slain.connect(_on_mob_slain)

	# Save timer -- persist dirty data every 30 seconds
	_save_timer = Timer.new()
	_save_timer.wait_time = 30.0
	_save_timer.one_shot = false
	_save_timer.timeout.connect(_save_if_dirty)
	add_child(_save_timer)
	_save_timer.start()

# ───── Data Loading (from PlayFab) ─────

func load_from_playfab(data: Variant) -> void:
	# Safety: if PlayFab stored it as a JSON string, parse it first
	if data is String:
		var parsed = JSON.parse_string(data)
		if parsed is Dictionary:
			data = parsed
		else:
			push_warning("AchievementManager: Failed to parse achievement data string")
			return
	if not (data is Dictionary):
		push_warning("AchievementManager: Invalid achievement data type: %s" % typeof(data))
		return
	monster_kills = data.get("monster_kills", {})
	claimed_tiers = data.get("claimed_tiers", {})
	pets_obtained = data.get("pets", {})
	# Ensure arrays for claimed_tiers + cast values to int (JSON may return floats)
	for key in claimed_tiers:
		if not (claimed_tiers[key] is Array):
			claimed_tiers[key] = []
		else:
			var int_arr: Array = []
			for v in claimed_tiers[key]:
				int_arr.append(int(v))
			claimed_tiers[key] = int_arr
	print("AchievementManager: Loaded %d monster kill records, %d claimed tier sets, %d pets" % [
		monster_kills.size(), claimed_tiers.size(), pets_obtained.size()])

func to_save_dict() -> Dictionary:
	return {
		"monster_kills": monster_kills,
		"claimed_tiers": claimed_tiers,
		"pets": pets_obtained,
	}

# ───── Kill Tracking ─────

func _on_mob_slain(mob_data: Dictionary) -> void:
	var mob_name = mob_data.get("name", "")
	if mob_name == "":
		return

	# Increment kill count
	if not monster_kills.has(mob_name):
		monster_kills[mob_name] = 0
	monster_kills[mob_name] += 1
	_dirty = true
	kill_achievement_updated.emit(mob_name, monster_kills[mob_name])

	# Pet drop roll
	if randf() < PET_DROP_CHANCE:
		var pet_name = "Baby " + mob_name
		if not pets_obtained.has(pet_name):
			pets_obtained[pet_name] = true
			_dirty = true
			pet_obtained.emit(pet_name)
			print("AchievementManager: PET DROP! %s" % pet_name)

# ───── Public API ─────

func get_monster_kills(monster_name: String) -> int:
	return monster_kills.get(monster_name, 0)

func get_current_tier(monster_name: String) -> int:
	## Returns the highest completed tier (0-based), or -1 if none reached
	var kills = get_monster_kills(monster_name)
	var tier := -1
	for i in range(KILL_TIERS.size()):
		if kills >= KILL_TIERS[i]:
			tier = i
	return tier

func get_claimed_tiers(monster_name: String) -> Array:
	return claimed_tiers.get(monster_name, [])

func is_tier_claimable(monster_name: String, tier_index: int) -> bool:
	var kills = get_monster_kills(monster_name)
	if tier_index < 0 or tier_index >= KILL_TIERS.size():
		return false
	if kills < KILL_TIERS[tier_index]:
		return false
	var ct = get_claimed_tiers(monster_name)
	return not ct.has(tier_index)

func claim_tier(monster_name: String, tier_index: int) -> void:
	if not is_tier_claimable(monster_name, tier_index):
		return

	if not claimed_tiers.has(monster_name):
		claimed_tiers[monster_name] = []
	claimed_tiers[monster_name].append(tier_index)
	_dirty = true
	achievement_claimed.emit(monster_name, tier_index)

	# Grant reward item locally
	var reward_bid = TIER_REWARDS[tier_index] if tier_index < TIER_REWARDS.size() else "Wyrm_Sphere"
	var reward_name = TIER_REWARD_NAMES[tier_index] if tier_index < TIER_REWARD_NAMES.size() else "Wyrm Sphere"
	var instance = ItemDatabase.create_instance_dict(reward_bid + "_Normal", "Normal")
	GameManager.add_to_bag(instance)
	GameManager.inventory_changed.emit()
	GameManager.sync_inventory_to_server()

	# Floating feedback
	GlobalUI.show_floating_text("+1 %s!" % reward_name, Color(0.4, 0.8, 1.0))

	# Call PlayFab to verify and persist the claim
	var args = {
		"monsterName": monster_name,
		"tierIndex": tier_index,
		"rewardItemId": reward_bid,
		"achievementData": to_save_dict()
	}
	PlayFabManager.client.execute_cloud_script("claimKillAchievement", args, _on_claim_result)
	print("AchievementManager: Claimed tier %d for %s — reward: %s" % [tier_index, monster_name, reward_name])

func _on_claim_result(result: Dictionary) -> void:
	var fn_result = result.get("data", {}).get("FunctionResult", {})
	if fn_result is Dictionary and fn_result.get("success", false):
		print("AchievementManager: Claim verified on server")
	else:
		push_warning("AchievementManager: Claim verification failed")

## Returns the extra rare spawn chance bonus for a given monster based on claimed tiers
func get_rare_bonus(monster_name: String) -> float:
	var ct = get_claimed_tiers(monster_name)
	var bonus := 0.0
	for tier_idx in ct:
		if tier_idx >= 0 and tier_idx < RARE_BONUS_PER_TIER.size():
			bonus += RARE_BONUS_PER_TIER[tier_idx]
	return bonus

## Returns all known monsters (from zones data)
func get_all_monsters() -> Array:
	var icm = get_node_or_null("/root/IdleCombatManager")
	if not icm:
		return []
	var all_mobs: Array = []
	for zone in icm.zones:
		var mobs = zone.get("mobs", [])
		for mob in mobs:
			all_mobs.append({
				"name": mob.get("name", ""),
				"id": mob.get("id", ""),
				"zone": zone.get("name", ""),
				"level": mob.get("level", 1),
			})
	return all_mobs

# ───── Persistence ─────

## Force an immediate save regardless of dirty flag (call before character switch / logout)
func force_save() -> void:
	_dirty = false
	var args = {
		"achievementData": to_save_dict()
	}
	PlayFabManager.client.execute_cloud_script("saveAchievements", args, _on_save_result)
	print("AchievementManager: Force-saved to PlayFab")

func _save_if_dirty() -> void:
	if not _dirty:
		return
	_dirty = false
	var args = {
		"achievementData": to_save_dict()
	}
	PlayFabManager.client.execute_cloud_script("saveAchievements", args, _on_save_result)

func _on_save_result(result: Dictionary) -> void:
	var fn_result = result.get("data", {}).get("FunctionResult", {})
	if fn_result is Dictionary and fn_result.get("success", false):
		print("AchievementManager: Data saved to PlayFab")
	else:
		push_warning("AchievementManager: Save failed, will retry")
		_dirty = true

func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_WINDOW_FOCUS_OUT or what == NOTIFICATION_APPLICATION_FOCUS_OUT:
		_save_if_dirty()
