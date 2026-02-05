extends Node

var class_data = {}
var promotion_reqs = {}
var stat_map = {
	"Strength": "Str",
	"Agility": "Agi",
	"Vitality": "Vit",
	"Spirit": "Spi"
}

func initialize_from_playfab(data: Dictionary):
	class_data = data.get("Classes", {})
	promotion_reqs = data.get("PromotionRequirements", {})
	
func calculate_base_stats(stats: Dictionary) -> Dictionary:
	var strength = stats.get("Strength", 0)
	var agility = stats.get("Agility", 0)
	var vitality = stats.get("Vitality", 0)
	var spirit = stats.get("Spirit", 0)
	
	var base_hp = (strength * 3) + (agility * 3) + (vitality * 24) + (spirit * 3)
	var base_mp = spirit * 5
	
	return {
		"HP": base_hp,
		"MP": base_mp
	}

func apply_multipliers(base_values: Dictionary, char_class: String, level: int) -> Dictionary:
	var final_hp = base_values.HP
	var final_mp = base_values.MP
	
	# Twin-Soul logic
	if char_class == "Twin-Soul":
		var multiplier = 1.0
		if level >= 110: multiplier = 1.15
		elif level >= 100: multiplier = 1.12
		elif level >= 70: multiplier = 1.10
		elif level >= 40: multiplier = 1.08
		elif level >= 15: multiplier = 1.05
		final_hp = int(final_hp * multiplier)
		
	# (Wuxia, Spiritmender, and Emberlord)
	elif char_class in ["Wuxia", "Spiritmender", "Emberlord"]:
		var multiplier = 1.0
		if level >= 110: multiplier = 6.0
		elif level >= 100: multiplier = 5.0
		elif level >= 70: multiplier = 4.0
		elif level >= 40: multiplier = 3.0
		final_mp = int(final_mp * multiplier)
		
	return {"MaxHP": final_hp, "MaxMP": final_mp}

func get_smart_allocated_stats(char_class: String, level: int) -> Dictionary:
	# 1. Setup Caps: Only Wuxia and Spiritmender cap at 110
	var cap = 110 if char_class in ["Wuxia", "Spiritmender"] else 120
	var effective_lvl = clamp(level, 1, cap)
	
	# 2. FETCH FROM CLOUD instead of hardcoded maps
	# .get() provides a safety backup if the class name is missing
	var start = class_data.get(char_class, {"Str": 0, "Agi": 0, "Vit": 0, "Spi": 0})
	var target = promotion_reqs.get(char_class, {"Str": 0, "Agi": 0, "Vit": 0, "Spi": 0})
	
	var current_stats = {}
	
	# 3. Smart Spread Calculation using Cloud Data
	for stat in ["Str", "Agi", "Vit", "Spi"]:
		var total_growth = target[stat] - start[stat]
		var growth_per_level = float(total_growth) / (cap - 1)
		current_stats[stat] = start[stat] + int(growth_per_level * (effective_lvl - 1))
		
	return current_stats
	
func sync_calculated_stats(char_id: String, hp: int, mp: int):
	var request = {
		"CharacterId": char_id,
		"Data": {
			"MaxHP": str(hp),
			"MaxMP": str(mp)
		}
	}
	# We use UpdateCharacterInternalData because this is a specific character slot
	PlayFabManager.client.UpdateCharacterInternalData(request,
		func(result): print("Cloud Stats Updated for Character: ", char_id),
		func(error): print("Sync Error: ", error.message)
	)
