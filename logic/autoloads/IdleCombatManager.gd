# IdleCombatManager.gd — Idle combat simulation autoload
# Runs a 0.1s tick timer that simulates combat rounds.
# Uses a monster queue (max 25) with rare variant spawning.
# The UI listens to signals emitted here — this script has NO UI dependencies.
extends Node

# ───── Signals ─────
signal combat_tick_updated           # Emitted every tick with latest state
signal mob_slain(mob_data: Dictionary)  # Emitted when a mob reaches 0 HP (includes is_rare, xp, etc.)
signal hunt_completed                # Emitted when kills_this_hunt == hunt_target
signal player_died                   # Emitted when player HP reaches 0
signal player_respawned              # Emitted when player respawns after death timer
signal xp_gained(amount: int)        # Emitted when XP is awarded
signal mob_spawned                   # Emitted when a new mob spawns (timer or manual)
signal zone_changed                  # Emitted after changing zone/creature
signal zones_loaded                  # Emitted when zone data is loaded from PlayFab
signal afk_rewards_ready(rewards: Dictionary)  # Emitted with offline rewards to display

# ───── Constants ─────
const TICK_INTERVAL: float = 0.1     # 100ms per tick
const MAX_QUEUE_SIZE: int = 25       # Max monsters in queue
const MAX_ATTACKERS: int = 9         # Max monsters hitting player per tick
const SPAWN_INTERVAL: float = 10.0   # Seconds between natural spawns
const RARE_CHANCE: float = 0.05      # 5% chance for rare variant
const RARE_STAT_MULT: float = 2.0    # Rare mobs have 2x stats
const RARE_XP_MULT: int = 10         # Rare mobs give 10x XP
const RARE_LOOT_ROLLS: int = 10      # Rare mobs give 10 loot rolls
const MOB_ATTACK_INTERVAL: float = 1.0  # Default: mobs attack once per second
const DEATH_RESPAWN_TIME: float = 5.0 # Seconds before player respawns after death
const AFK_MAX_SECONDS: int = 7200    # 2 hours max AFK reward
const AFK_SAVE_PATH: String = "user://afk_timestamp.save"

# ───── Zone / Creature data (loaded from PlayFab Title Data) ─────
# Array of zone dicts: [{name, mobs: [{id, name, level, hp, minAttack, maxAttack, defense, dodge, magicDef, xp, isBoss}]}]
var zones: Array = []
var _zone_name_to_index: Dictionary = {}  # "Dual Town" -> 0

# ───── Current selection ─────
var current_zone_index: int = 0
var current_creature_index: int = 0
var current_zone: String = ""
var current_creature: String = ""

# ───── Monster queue ─────
# Each entry: {id, name, level, hp, max_hp, minAttack, maxAttack, defense, dodge, magicDef, xp, is_rare, is_boss}
var monster_queue: Array = []

# ───── Player state ─────
var player_hp: int = 0
var player_max_hp: int = 0

var kills_this_hunt: int = 0
var hunt_target: int = 25

var total_kills: int = 0
var total_deaths: int = 0

var current_xp: int = 0
var xp_to_next_level: int = 110

var combat_active: bool = false
var is_fighting_mode: bool = true  # true = Fighting, false = Mining
var is_dead: bool = false          # true during death respawn cooldown
var _death_timer: float = 0.0      # Counts down to 0 during death

# ───── Timers ─────
var tick_timer: Timer = null
var spawn_timer: Timer = null

# ───── Attack speed ─────
# Player attacks when _attack_cooldown reaches 0, then resets to attack_interval
var attack_interval: float = 1.0  # Seconds between player attacks (derived from weapon Speed)
var _attack_cooldown: float = 0.0 # Counts down each tick

# ───── Cached player combat stats ─────
var _player_min_atk: int = 1
var _player_max_atk: int = 5
var _arrow_atk_bonus: int = 0
var _player_p_atk: int = 0
var _player_def: int = 0
var _player_p_def: int = 0
var _player_m_atk: int = 0
var _player_dodge: int = 0
var _player_accuracy: int = 0

func _ready():
	tick_timer = Timer.new()
	tick_timer.wait_time = TICK_INTERVAL
	tick_timer.one_shot = false
	tick_timer.timeout.connect(_on_tick)
	add_child(tick_timer)

	spawn_timer = Timer.new()
	spawn_timer.wait_time = SPAWN_INTERVAL
	spawn_timer.one_shot = false
	spawn_timer.timeout.connect(_on_spawn_timer)
	add_child(spawn_timer)

	# Recalculate stats when equipment changes
	GameManager.equipment_changed.connect(_on_equipment_changed)

func _on_equipment_changed() -> void:
	_refresh_player_stats()
	combat_tick_updated.emit()

# ───── Zone Data Loading ─────

func load_zones_from_title_data(zone_array: Array) -> void:
	zones = zone_array
	_zone_name_to_index.clear()
	for i in range(zones.size()):
		var zone = zones[i]
		_zone_name_to_index[zone.get("name", "")] = i
	if zones.size() > 0:
		current_zone_index = 0
		current_zone = zones[0].get("name", "")
		var mobs = zones[0].get("mobs", [])
		if mobs.size() > 0:
			current_creature_index = 0
			current_creature = mobs[0].get("name", "")
	print("IdleCombatManager: Loaded %d zones" % zones.size())
	zones_loaded.emit()

# ───── Public API ─────

func get_zone_names() -> Array:
	var names: Array = []
	for zone in zones:
		names.append(zone.get("name", ""))
	return names

func get_creature_names(zone_name: String) -> Array:
	var names: Array = []
	var idx = _zone_name_to_index.get(zone_name, -1)
	if idx < 0:
		return names
	var mobs = zones[idx].get("mobs", [])
	for mob in mobs:
		names.append(mob.get("name", ""))
	return names

func get_creature_data_for(zone_name: String, creature_name: String) -> Dictionary:
	var idx = _zone_name_to_index.get(zone_name, -1)
	if idx < 0:
		return {}
	var mobs = zones[idx].get("mobs", [])
	for mob in mobs:
		if mob.get("name", "") == creature_name:
			return mob
	return {}

func change_zone(zone_name: String, creature_name: String) -> void:
	var idx = _zone_name_to_index.get(zone_name, -1)
	if idx < 0:
		push_warning("IdleCombatManager: Unknown zone '%s'" % zone_name)
		return
	var mobs = zones[idx].get("mobs", [])
	var creature_idx = -1
	for i in range(mobs.size()):
		if mobs[i].get("name", "") == creature_name:
			creature_idx = i
			break
	if creature_idx < 0:
		push_warning("IdleCombatManager: Unknown creature '%s' in zone '%s'" % [creature_name, zone_name])
		return

	current_zone_index = idx
	current_creature_index = creature_idx
	current_zone = zone_name
	current_creature = creature_name
	kills_this_hunt = 0
	monster_queue.clear()
	_spawn_mob_to_queue()
	zone_changed.emit()
	combat_tick_updated.emit()

func start_combat() -> void:
	if combat_active:
		return
	if zones.is_empty():
		push_warning("IdleCombatManager: No zones loaded, cannot start combat")
		return
	_refresh_player_stats()
	player_hp = player_max_hp  # Full heal on combat start
	if monster_queue.is_empty():
		_spawn_mob_to_queue()
	combat_active = true
	_attack_cooldown = attack_interval
	tick_timer.start()
	spawn_timer.start()
	combat_tick_updated.emit()

func stop_combat() -> void:
	combat_active = false
	tick_timer.stop()
	spawn_timer.stop()
	combat_tick_updated.emit()

func set_mode_fighting(fighting: bool) -> void:
	is_fighting_mode = fighting
	if fighting:
		start_combat()
	else:
		stop_combat()

func summon_monsters(count: int) -> void:
	var to_add = min(count, MAX_QUEUE_SIZE - monster_queue.size())
	for i in range(to_add):
		_spawn_mob_to_queue()
	combat_tick_updated.emit()

# ───── Primary target (first in queue) ─────

func get_primary_target() -> Dictionary:
	if monster_queue.is_empty():
		return {}
	return monster_queue[0]

# ───── Internal: Spawning ─────

func _get_current_creature_template() -> Dictionary:
	if zones.is_empty():
		return {}
	var mobs = zones[current_zone_index].get("mobs", [])
	if current_creature_index >= mobs.size():
		return {}
	return mobs[current_creature_index]

func _spawn_mob_to_queue() -> void:
	if monster_queue.size() >= MAX_QUEUE_SIZE:
		return
	var template = _get_current_creature_template()
	if template.is_empty():
		return

	# Check for achievement-based rare bonus
	var rare_chance = RARE_CHANCE
	var ach_mgr = get_node_or_null("/root/AchievementManager")
	if ach_mgr:
		rare_chance += ach_mgr.get_rare_bonus(template.get("name", ""))
	var is_rare = randf() < rare_chance
	var is_boss = template.get("isBoss", false)
	var mult = RARE_STAT_MULT if is_rare else 1.0

	var mob = {
		"id": template.get("id", ""),
		"name": template.get("name", "Unknown"),
		"level": template.get("level", 1),
		"hp": int(template.get("hp", 25) * mult),
		"max_hp": int(template.get("hp", 25) * mult),
		"minAttack": int(template.get("minAttack", 1) * mult),
		"maxAttack": int(template.get("maxAttack", 3) * mult),
		"defense": int(template.get("defense", 0) * mult),
		"dodge": template.get("dodge", 0),
		"magicDef": int(template.get("magicDef", 0) * mult),
		"xp": template.get("xp", 10) * (RARE_XP_MULT if is_rare else 1),
		"is_rare": is_rare,
		"is_boss": is_boss,
		"attack_cooldown": MOB_ATTACK_INTERVAL,  # Each mob has its own attack timer
	}
	monster_queue.append(mob)

func _on_spawn_timer() -> void:
	if not combat_active:
		return
	_spawn_mob_to_queue()
	mob_spawned.emit()
	combat_tick_updated.emit()

# ───── Internal: Stats ─────

func _refresh_player_stats() -> void:
	var invested = GameManager.active_character_stats
	var char_class = GameManager.active_character_class
	var level = GameManager.active_character_level

	# Combine class base stats + player-invested attribute points (same as Hero Tab)
	var class_base = StatCalculator.get_smart_allocated_stats(char_class, level)
	var total_stats = {
		"Strength": int(class_base.get("Strength", 0)) + int(invested.get("Strength", 0)),
		"Agility": int(class_base.get("Agility", 0)) + int(invested.get("Agility", 0)),
		"Vitality": int(class_base.get("Vitality", 0)) + int(invested.get("Vitality", 0)),
		"Spirit": int(class_base.get("Spirit", 0)) + int(invested.get("Spirit", 0)),
	}

	# Calculate base HP from combined stats
	var base = StatCalculator.calculate_base_stats(total_stats)
	var finals = StatCalculator.apply_multipliers(base, char_class, level)
	player_max_hp = finals.get("MaxHP", 50)

	# Add shield LifeBonus to max HP, or arrow ATK bonus
	var offhand = GameManager.get_equipped_item_data("Offhand")
	if offhand and offhand.item_type == "Shield":
		player_max_hp += offhand.get_stat("LifeBonus")
	elif offhand and offhand.item_type == "Arrow":
		# Arrows add flat ATK bonus on top of weapon damage
		_arrow_atk_bonus = offhand.get_stat("MinAtk")
	else:
		_arrow_atk_bonus = 0

	# Only heal to full on first combat start, not on mid-combat recalcs
	if player_hp <= 0 or player_hp > player_max_hp:
		player_hp = player_max_hp

	# Calculate combat details WITH gear (using combined stats)
	var gear_data = GameManager.build_gear_data()
	var combat = StatCalculator.calculate_combat_details(total_stats, gear_data)

	# For weapon-equipped players, use weapon's MinAtk/MaxAtk directly
	var weapon = GameManager.get_equipped_item_data("Weapon")
	if weapon and weapon.get_stat("MinAtk") > 0:
		_player_min_atk = weapon.get_stat("MinAtk")
		_player_max_atk = weapon.get_stat("MaxAtk")
	else:
		# No weapon: use attribute-based attack with a small range
		_player_min_atk = max(1, combat.get("TotalAtk", 1) - 2)
		_player_max_atk = max(1, combat.get("TotalAtk", 1) + 2)

	_player_p_atk = combat.get("P-Atk", 0)
	_player_def = combat.get("TotalDef", 0)
	_player_p_def = combat.get("P-Def", 0)
	_player_m_atk = combat.get("M-Atk", 0)
	_player_dodge = combat.get("TotalDodge", 0)
	_player_accuracy = combat.get("Accuracy", 0)

	# Attack speed: derived from weapon Speed stat
	# Weapons have Speed 0-12. Higher = faster.
	# Formula: base 1.5s, reduced by weapon speed. Min 0.3s.
	var weapon_speed = GameManager.get_weapon_speed()
	attack_interval = max(0.3, 1.5 - (weapon_speed * 0.1))

	# XP table
	xp_to_next_level = 100 + (level * 10)

# ───── Internal: Combat Tick ─────

func _on_tick() -> void:
	if not combat_active:
		return

	# --- Handle death respawn timer ---
	if is_dead:
		_death_timer -= TICK_INTERVAL
		if _death_timer <= 0.0:
			# Respawn: full HP, spawn a fresh mob, restart spawn timer
			is_dead = false
			_death_timer = 0.0
			player_hp = player_max_hp
			_attack_cooldown = attack_interval
			spawn_timer.start()
			if monster_queue.is_empty():
				_spawn_mob_to_queue()
			player_respawned.emit()
		combat_tick_updated.emit()
		return

	if monster_queue.is_empty():
		return

	# --- Player attack cooldown ---
	_attack_cooldown -= TICK_INTERVAL
	if _attack_cooldown <= 0.0:
		_attack_cooldown += attack_interval
		_player_attack()

	# --- Monsters attack player (up to MAX_ATTACKERS) ---
	# Each mob has its own attack_cooldown that ticks down independently.
	# Only the first MAX_ATTACKERS mobs in the queue can attack.
	var attacker_count = min(MAX_ATTACKERS, monster_queue.size())
	for i in range(attacker_count):
		var mob = monster_queue[i]
		mob["attack_cooldown"] = mob.get("attack_cooldown", MOB_ATTACK_INTERVAL) - TICK_INTERVAL
		if mob["attack_cooldown"] <= 0.0:
			mob["attack_cooldown"] += MOB_ATTACK_INTERVAL
			# This mob attacks now
			var mob_damage = StatCalculator.get_physical_hit(
				mob.get("minAttack", 1), mob.get("maxAttack", 3), 0,
				_player_def, _player_p_def
			)
			player_hp = max(0, player_hp - mob_damage)

	# --- Check player death ---
	if player_hp <= 0:
		total_deaths += 1
		is_dead = true
		_death_timer = DEATH_RESPAWN_TIME
		monster_queue.clear()  # Clear all enemies on death
		spawn_timer.stop()     # Stop spawning during death
		player_died.emit()

	combat_tick_updated.emit()

func _player_attack() -> void:
	if monster_queue.is_empty():
		return

	var mob = monster_queue[0]  # Primary target

	# Apply arrow ATK bonus if arrows are equipped
	var bonus_min = _arrow_atk_bonus if _arrow_atk_bonus > 0 else 0
	var bonus_max = bonus_min  # Arrows give flat bonus to both min and max

	var player_damage = StatCalculator.get_physical_hit(
		_player_min_atk + bonus_min, _player_max_atk + bonus_max, _player_p_atk,
		mob.get("defense", 0), 0
	)
	mob["hp"] = max(0, mob["hp"] - player_damage)

	# Consume an arrow if arrows are equipped
	if _arrow_atk_bonus > 0:
		_consume_arrow()

	if mob["hp"] <= 0:
		_on_mob_killed(mob)

func _consume_arrow() -> void:
	var offhand_dict = GameManager.equipped_items.get("Offhand")
	if offhand_dict == null:
		return
	var amt = int(offhand_dict.get("amt", 0))
	if amt <= 1:
		# Last arrow consumed — unequip
		GameManager.equipped_items["Offhand"] = null
		_arrow_atk_bonus = 0
		GameManager.equipment_changed.emit()
		GameManager.inventory_changed.emit()
		GameManager.sync_inventory_to_server()
		print("IdleCombatManager: Out of arrows!")
	else:
		offhand_dict["amt"] = amt - 1

func _on_mob_killed(mob: Dictionary) -> void:
	# Remove from queue
	monster_queue.erase(mob)

	# Track kills
	kills_this_hunt += 1
	total_kills += 1

	# Award XP
	var xp_reward = mob.get("xp", 10)
	current_xp += xp_reward
	xp_gained.emit(xp_reward)

	# Emit slain signal (LootManager will listen for loot rolling)
	mob_slain.emit(mob)

	# Check for level-up
	while current_xp >= xp_to_next_level:
		current_xp -= xp_to_next_level
		GameManager.active_character_level += 1
		# Award attribute points on level-up (5 per level)
		GameManager.active_character_stats["AvailableAttributePoints"] = \
			GameManager.active_character_stats.get("AvailableAttributePoints", 0) + 5
		_refresh_player_stats()
		GameManager.character_stats_updated.emit()

	# Check hunt completion
	if kills_this_hunt >= hunt_target:
		kills_this_hunt = 0
		hunt_completed.emit()

	# If queue is empty, spawn one immediately
	if monster_queue.is_empty():
		_spawn_mob_to_queue()

# ───── AFK / Offline Rewards ─────

func _notification(what: int) -> void:
	match what:
		NOTIFICATION_APPLICATION_FOCUS_OUT, NOTIFICATION_WM_WINDOW_FOCUS_OUT:
			# App lost focus (alt-tab, browser tab switch, mobile background)
			_save_afk_timestamp()
		NOTIFICATION_APPLICATION_FOCUS_IN, NOTIFICATION_WM_WINDOW_FOCUS_IN:
			# App regained focus
			_check_afk_rewards()

func _save_afk_timestamp() -> void:
	if not combat_active:
		return
	var file = FileAccess.open(AFK_SAVE_PATH, FileAccess.WRITE)
	if file:
		file.store_64(int(Time.get_unix_time_from_system()))
		file.close()
		print("IdleCombatManager: AFK timestamp saved")

func _check_afk_rewards() -> void:
	if not FileAccess.file_exists(AFK_SAVE_PATH):
		return
	var file = FileAccess.open(AFK_SAVE_PATH, FileAccess.READ)
	if not file:
		return
	var saved_time = file.get_64()
	file.close()

	# Delete the file so we don't process it again
	DirAccess.remove_absolute(AFK_SAVE_PATH)

	var now = int(Time.get_unix_time_from_system())
	var elapsed = now - saved_time
	if elapsed < 5:
		return  # Ignore very short absences (< 5 seconds)

	# Cap at 2 hours
	elapsed = min(elapsed, AFK_MAX_SECONDS)

	print("IdleCombatManager: Player was away for %d seconds" % elapsed)
	var rewards = _simulate_offline(elapsed)
	if rewards.get("total_kills", 0) > 0:
		afk_rewards_ready.emit(rewards)

func _simulate_offline(elapsed_seconds: int) -> Dictionary:
	var template = _get_current_creature_template()
	if template.is_empty():
		return {}

	var mob_hp = template.get("hp", 25)
	var mob_xp = template.get("xp", 10)
	var mob_level = template.get("level", 1)
	var mob_def = template.get("defense", 0)

	# Estimate average damage per attack
	var avg_player_atk = (_player_min_atk + _player_max_atk) / 2.0 + _player_p_atk
	var avg_damage_per_hit = max(1.0, avg_player_atk - mob_def)

	# Hits to kill one mob
	var hits_to_kill = max(1, ceili(float(mob_hp) / avg_damage_per_hit))

	# Time to kill one mob (attack_interval per hit)
	var time_per_kill = hits_to_kill * attack_interval

	# Total kills in elapsed time
	var total_kills = int(elapsed_seconds / max(0.1, time_per_kill))
	if total_kills <= 0:
		return {}

	# Calculate rare kills (5% chance)
	var rare_kills = int(total_kills * RARE_CHANCE)
	var normal_kills = total_kills - rare_kills

	# XP: normal + rare (10x)
	var total_xp = (normal_kills * mob_xp) + (rare_kills * mob_xp * RARE_XP_MULT)

	# Gold — use runtime lookup to avoid circular dependency (LootManager loads after us)
	var loot_mgr = get_node_or_null("/root/LootManager")
	var gold_mult = loot_mgr.gold_multiplier if loot_mgr else 8
	var total_gold = total_kills * mob_xp * gold_mult

	# Apply XP and level-ups
	current_xp += total_xp
	while current_xp >= xp_to_next_level:
		current_xp -= xp_to_next_level
		GameManager.active_character_level += 1
		xp_to_next_level = 100 + (GameManager.active_character_level * 10)

	total_kills += total_kills  # stat tracking
	kills_this_hunt = 0

	# Roll loot for all kills — runtime lookup to avoid circular dependency
	var loot_items: Array = []
	if loot_mgr:
		loot_items = loot_mgr.batch_roll_loot(mob_level, normal_kills, rare_kills)

	var rewards = {
		"elapsed_seconds": elapsed_seconds,
		"total_kills": normal_kills + rare_kills,
		"rare_kills": rare_kills,
		"total_xp": total_xp,
		"total_gold": total_gold,
		"loot_items": loot_items,
		"new_level": GameManager.active_character_level,
	}

	print("IdleCombatManager: Offline rewards -- %d kills, %d XP, %d gold, %d items" % [
		rewards["total_kills"], total_xp, total_gold, loot_items.size()
	])

	return rewards
