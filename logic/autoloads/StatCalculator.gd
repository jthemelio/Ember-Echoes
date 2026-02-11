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
