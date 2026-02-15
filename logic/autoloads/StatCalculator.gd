extends Node

var class_data = {}
var promotion_reqs = {}
var promotion_multipliers = {}

var stat_map = {
	"Strength": "Str",
	"Agility": "Agi",
	"Vitality": "Vit",
	"Spirit": "Spi"
}

func initialize_from_playfab(data: Dictionary):
	class_data = data.get("Classes", {})
	promotion_reqs = data.get("PromotionRequirements", {})
	promotion_multipliers = data.get("PromotionMultipliers", {})

func calculate_base_stats(stats: Dictionary) -> Dictionary:
	var str_val = stats.get("Strength", 0)
	var agi_val = stats.get("Agility", 0)
	var vit_val = stats.get("Vitality", 0)
	var spi_val = stats.get("Spirit", 0)
	
	# Formula based on classic Conquer attributes
	var base_hp = (str_val * 3) + (agi_val * 3) + (vit_val * 24) + (spi_val * 3)
	var base_mp = spi_val * 5
	
	return {"HP": base_hp, "MP": base_mp}

func apply_multipliers(base_values: Dictionary, char_class: String, level: int) -> Dictionary:
	var final_hp = base_values.HP
	var final_mp = base_values.MP
	var class_mults = promotion_multipliers.get(char_class, {})
	var best_mult = 1.0
	
	for tier_lvl in class_mults.keys():
		if level >= int(tier_lvl):
			best_mult = float(class_mults[tier_lvl])
	
	if char_class == "Twin-Soul":
		final_hp = int(final_hp * best_mult)
	elif char_class in ["Wuxia", "Spiritmender", "Emberlord"]:
		final_mp = int(final_mp * best_mult)
		
	return {"MaxHP": final_hp, "MaxMP": final_mp}

# --- NEW COMBAT LOGIC ---

func calculate_combat_details(stats: Dictionary, gear_data: Dictionary = {}) -> Dictionary:
	# 1. Attributes
	var str_val = stats.get("Strength", 0)
	var vit_val = stats.get("Vitality", 0)
	var agi_val = stats.get("Agility", 0)
	var spi_val = stats.get("Spirit", 0)
	
	# 2. Base Calculation (Attributes only)
	var base_atk = str_val * 1.0     
	var base_def = vit_val * 0.0     
	
	# 3. Gear Calculation (Weapons and Rings only)
	var total_gear_atk = gear_data.get("WeaponAtk", 0) + gear_data.get("RingAtk", 0)
	var total_gear_def = gear_data.get("ArmorDef", 0) + gear_data.get("ShieldDef", 0)

	# 4. Plus Bonuses (Strictly the +1, +2, etc. upgrades)
	var plus_atk = gear_data.get("P-Atk", 0)
	var plus_def = gear_data.get("P-Def", 0)

	return {
		"BaseAtk": int(base_atk),
		"GearAtk": total_gear_atk,
		# Total Physical Attack is JUST Base + Gear
		"TotalAtk": int(base_atk) + total_gear_atk, 
		"P-Atk": plus_atk, 
		
		"BaseDef": int(base_def),
		"GearDef": total_gear_def,
		# Total Physical Defense is JUST Base + Gear
		"TotalDef": int(base_def) + total_gear_def,
		"P-Def": plus_def,
		
		"M-Atk": int(spi_val * 1.0),
		"Accuracy": agi_val + gear_data.get("WeaponAccuracy", 0),
		"TotalDodge": gear_data.get("BootDodge", 0) + gear_data.get("PlusDodge", 0)
	}

# Physical Damage = max(1, (Random(MinAtk, MaxAtk) - Defense) * (1 - TotalReduction))
func get_physical_hit(min_atk: int, max_atk: int, p_atk: int, target_def: int, target_p_def: int, reduction: float = 0.0) -> int:
	var total_atk = randi_range(min_atk, max_atk) + p_atk
	var total_def = target_def + target_p_def
	
	var damage = (total_atk - total_def) * (1.0 - reduction)
	return int(max(1, damage))

# Magic Damage = (MagicAttack - MagicDefense) * SkillMultiplier
func get_magic_hit(m_atk: int, m_def: int, skill_mult: float = 1.0) -> int:
	var damage = (m_atk - m_def) * skill_mult
	return int(max(1, damage))

# --- END COMBAT LOGIC ---

## Classes that never allocate Spirit and front-load Agility to meet blade Dex reqs.
const MELEE_CLASSES := ["Twin-Soul", "Juggernaut"]
const MELEE_AGI_CAP := 28  # Highest Dex req on any blade

## Returns a Dictionary mapping stat names to point counts for a single level-up.
## `current_total_stats` is the character's current combined stats (class_base + invested).
## For Twin-Soul / Juggernaut: pumps Agility until MELEE_AGI_CAP, then Str/Vit only.
## For other classes: distributes proportionally based on the class growth curve.
func get_level_up_allocation(char_class: String, points: int = 5, current_total_stats: Dictionary = {}) -> Dictionary:
	# ── Melee priority path (Twin-Soul & Juggernaut) ──
	if char_class in MELEE_CLASSES:
		var current_agi = int(current_total_stats.get("Agility", 0))
		var alloc = {"Strength": 0, "Agility": 0, "Vitality": 0, "Spirit": 0}
		var pts_left = points

		# Phase 1: Agility until cap
		if current_agi < MELEE_AGI_CAP:
			var agi_needed = MELEE_AGI_CAP - current_agi
			var agi_pts = mini(pts_left, agi_needed)
			alloc["Agility"] = agi_pts
			pts_left -= agi_pts

		# Phase 2: remaining points split between Str and Vit (no Spirit)
		if pts_left > 0:
			var str_share = ceili(pts_left / 2.0)  # Str gets the extra if odd
			alloc["Strength"] += str_share
			alloc["Vitality"] += pts_left - str_share

		return alloc

	# ── Default growth-ratio path (all other classes) ──
	var start = class_data.get(char_class, {"Str": 0, "Agi": 0, "Vit": 0, "Spi": 0})
	var target = promotion_reqs.get(char_class, {"Str": 0, "Agi": 0, "Vit": 0, "Spi": 0})

	# Calculate growth weight for each stat
	var growths: Dictionary = {}
	var total_growth: float = 0.0
	for full_name in stat_map.keys():
		var short_key = stat_map[full_name]
		var g = max(0, target.get(short_key, 0) - start.get(short_key, 0))
		growths[full_name] = g
		total_growth += g

	# Fallback: equal-ish distribution if data is missing / all zeros
	if total_growth == 0:
		return {"Strength": 2, "Agility": 1, "Vitality": 1, "Spirit": 1}

	# Largest-remainder method for fair integer rounding
	var alloc: Dictionary = {}
	var remainders: Dictionary = {}
	var allocated_total: int = 0
	for stat_name in growths.keys():
		var exact = (growths[stat_name] / total_growth) * points
		alloc[stat_name] = int(exact)
		remainders[stat_name] = exact - int(exact)
		allocated_total += int(exact)

	# Give leftover points to the stats with the highest fractional remainders
	var remaining = points - allocated_total
	while remaining > 0:
		var best_stat := ""
		var best_rem := -1.0
		for stat_name in remainders.keys():
			if remainders[stat_name] > best_rem:
				best_rem = remainders[stat_name]
				best_stat = stat_name
		alloc[best_stat] += 1
		remainders[best_stat] = -1.0  # consumed
		remaining -= 1

	return alloc

func get_smart_allocated_stats(char_class: String, level: int) -> Dictionary:
	# This handles auto-growth for the CURRENT life (Level 15 to 120)
	var cap = 110 if char_class in ["Wuxia", "Spiritmender"] else 120
	
	# Since players drop to Level 15 on Awakening, we clamp between 1 and cap
	var effective_lvl = clamp(level, 1, cap)
	
	var start = class_data.get(char_class, {"Str": 0, "Agi": 0, "Vit": 0, "Spi": 0})
	var target = promotion_reqs.get(char_class, {"Str": 0, "Agi": 0, "Vit": 0, "Spi": 0})
	
	var current_stats = {}
	
	for full_name in stat_map.keys():
		var short_key = stat_map[full_name]
		var total_growth = target.get(short_key, 0) - start.get(short_key, 0)
		var growth_per_level = float(total_growth) / (cap - 1)
		
		# For an Awakened character at Lvl 15, this returns Level 15 base stats.
		# They then add their carry-over Bonus Points manually.
		current_stats[full_name] = start.get(short_key, 0) + int(growth_per_level * (effective_lvl - 1))
		
	return current_stats
