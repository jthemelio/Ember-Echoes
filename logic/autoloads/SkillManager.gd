# SkillManager.gd — Autoload for Skills & Passives system
# Loads skill catalog from PlayFab TitleData, tracks equipped skill per character,
# manages cooldowns during combat, and applies passive stat bonuses.
extends Node

# ───── Signals ─────
signal skill_catalog_loaded           # Emitted when catalog is fetched and parsed
signal skill_used(skill: Dictionary)  # Emitted when an active skill fires
signal skill_equipped_changed         # Emitted when equipped skill changes
signal cooldown_updated(remaining: float, total: float)  # For UI cooldown display

# ───── Catalog Data ─────
# Loaded from PlayFab TitleData["SkillCatalog"]
# Structure: { "Marksman": { "skills": [...], "passives": [...] }, ... }
var catalog: Dictionary = {}

# ───── Per-Character State ─────
var equipped_skill_id: String = ""     # Currently equipped active skill ID
var _cooldown_timer: float = 0.0       # Remaining cooldown in seconds
var _cooldown_total: float = 0.0       # Total cooldown of equipped skill
var _auto_skill_enabled: bool = true   # Whether skill auto-fires in idle combat

# ───── Constants ─────
const TITLE_DATA_KEY := "SkillCatalog"

func _ready() -> void:
	set_process(false)  # Only process when combat is active and skill is equipped

func _process(delta: float) -> void:
	if _cooldown_timer > 0.0:
		_cooldown_timer -= delta
		cooldown_updated.emit(_cooldown_timer, _cooldown_total)
		if _cooldown_timer <= 0.0:
			_cooldown_timer = 0.0
			if _auto_skill_enabled:
				_auto_use_skill()

# ═══════════════════════════════════════════
# Catalog Loading
# ═══════════════════════════════════════════

func load_catalog_from_title_data(title_data: Dictionary) -> void:
	"""Called by GameManager after fetching TitleData."""
	if title_data.has(TITLE_DATA_KEY):
		var json_str = title_data[TITLE_DATA_KEY]
		var parsed = JSON.parse_string(json_str)
		if parsed is Dictionary:
			catalog = parsed
			print("SkillManager: Catalog loaded. Classes: ", catalog.keys())
		else:
			push_warning("SkillManager: SkillCatalog is not a valid Dictionary")
	else:
		push_warning("SkillManager: No SkillCatalog in TitleData")
	skill_catalog_loaded.emit()

# ═══════════════════════════════════════════
# Skill Queries
# ═══════════════════════════════════════════

func get_skills_for_class(char_class: String) -> Array:
	"""Returns the list of active skill definitions for a class."""
	if catalog.has(char_class):
		return catalog[char_class].get("skills", [])
	return []

func get_passives_for_class(char_class: String) -> Array:
	"""Returns the list of passive definitions for a class."""
	if catalog.has(char_class):
		return catalog[char_class].get("passives", [])
	return []

func get_unlocked_skills(char_class: String, level: int) -> Array:
	"""Returns skills that the character has unlocked (level >= unlockLevel)."""
	var all_skills = get_skills_for_class(char_class)
	var unlocked: Array = []
	for skill in all_skills:
		if level >= skill.get("unlockLevel", 999):
			unlocked.append(skill)
	return unlocked

func get_unlocked_passives(char_class: String, level: int) -> Array:
	"""Returns passives that the character has unlocked."""
	var all_passives = get_passives_for_class(char_class)
	var unlocked: Array = []
	for passive in all_passives:
		if level >= passive.get("unlockLevel", 999):
			unlocked.append(passive)
	return unlocked

func get_equipped_skill() -> Dictionary:
	"""Returns the full skill data dict for the currently equipped skill, or empty."""
	if equipped_skill_id.is_empty():
		return {}
	var char_class = GameManager.active_character_class
	for skill in get_skills_for_class(char_class):
		if skill.get("id", "") == equipped_skill_id:
			return skill
	return {}

# ═══════════════════════════════════════════
# Equip / Unequip
# ═══════════════════════════════════════════

func equip_skill(skill_id: String) -> void:
	"""Equip an active skill by ID. Pass "" to unequip."""
	equipped_skill_id = skill_id
	_cooldown_timer = 0.0
	var skill = get_equipped_skill()
	_cooldown_total = skill.get("cooldown", 0.0)
	skill_equipped_changed.emit()
	sync_to_server()
	if skill_id.is_empty():
		set_process(false)
	print("SkillManager: Equipped skill -> '%s'" % skill_id)

func unequip_skill() -> void:
	equip_skill("")

# ═══════════════════════════════════════════
# Skill Usage (Combat Integration)
# ═══════════════════════════════════════════

func try_use_skill() -> bool:
	"""Attempt to use the equipped skill. Returns true if it fired."""
	if equipped_skill_id.is_empty():
		return false
	if _cooldown_timer > 0.0:
		return false
	var skill = get_equipped_skill()
	if skill.is_empty():
		return false

	# Fire the skill
	_cooldown_timer = skill.get("cooldown", 5.0)
	_cooldown_total = _cooldown_timer
	skill_used.emit(skill)
	print("SkillManager: Used skill '%s' (cd: %.1fs)" % [skill.get("name", "?"), _cooldown_timer])
	return true

func _auto_use_skill() -> void:
	"""Called automatically when cooldown expires during combat."""
	if not IdleCombatManager.combat_active:
		return
	try_use_skill()

func start_combat_processing() -> void:
	"""Called by IdleCombatManager when combat starts."""
	if not equipped_skill_id.is_empty():
		set_process(true)
		_cooldown_timer = 0.0  # Ready to fire immediately

func stop_combat_processing() -> void:
	"""Called by IdleCombatManager when combat stops."""
	set_process(false)
	_cooldown_timer = 0.0

# ═══════════════════════════════════════════
# Passive Stat Bonuses
# ═══════════════════════════════════════════

func get_passive_bonuses(char_class: String, level: int) -> Dictionary:
	"""Returns a dictionary of stat bonuses from all unlocked passives.
	Format: { "Accuracy": { "flat": 0, "percent": 10 }, "Damage": { ... } }"""
	var bonuses: Dictionary = {}
	for passive in get_unlocked_passives(char_class, level):
		var effect = passive.get("effect", {})
		var stat = effect.get("stat", "")
		var type = effect.get("type", "flat")
		var value = effect.get("value", 0)
		if stat.is_empty():
			continue
		if not bonuses.has(stat):
			bonuses[stat] = {"flat": 0, "percent": 0}
		bonuses[stat][type] += value
	return bonuses

# ═══════════════════════════════════════════
# Server Sync
# ═══════════════════════════════════════════

func sync_to_server() -> void:
	"""Persists equipped skill to PlayFab character data."""
	PlayFabManager.client.execute_cloud_script("syncSkillData", {
		"characterId": GameManager.active_character_id,
		"equippedSkill": equipped_skill_id,
	}, func(result):
		var fn = result.get("data", {}).get("FunctionResult", {})
		if fn is Dictionary and fn.get("success", false):
			print("SkillManager: Skill data synced")
		else:
			push_warning("SkillManager: Skill sync failed")
	)

func load_from_server(char_data: Dictionary) -> void:
	"""Called during character load to restore equipped skill from server data."""
	var skill_id = char_data.get("equippedSkill", "")
	if skill_id is String and not skill_id.is_empty():
		equipped_skill_id = skill_id
		var skill = get_equipped_skill()
		_cooldown_total = skill.get("cooldown", 0.0)
		print("SkillManager: Loaded equipped skill '%s' from server" % skill_id)
	else:
		equipped_skill_id = ""
	skill_equipped_changed.emit()
