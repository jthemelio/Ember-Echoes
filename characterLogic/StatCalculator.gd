extends Node

var class_data = {}
var promotion_reqs = {}
var promotion_multipliers = {} # Added to match your JSON

# Maps PlayFab Statistics (Full) to JSON keys (Short)
var stat_map = {
	"Strength": "Str",
	"Agility": "Agi",
	"Vitality": "Vit",
	"Spirit": "Spi"
}

func initialize_from_playfab(data: Dictionary):
	class_data = data.get("Classes", {})
	promotion_reqs = data.get("PromotionRequirements", {})
	promotion_multipliers = data.get("PromotionMultipliers", {}) # Load from Title Data

func calculate_base_stats(stats: Dictionary) -> Dictionary:
	# Pulls using full names from your character statistics
	var str_val = stats.get("Strength", 0)
	var agi_val = stats.get("Agility", 0)
	var vit_val = stats.get("Vitality", 0)
	var spi_val = stats.get("Spirit", 0)
	
	var base_hp = (str_val * 3) + (agi_val * 3) + (vit_val * 24) + (spi_val * 3)
	var base_mp = spi_val * 5
	
	return {"HP": base_hp, "MP": base_mp}

func apply_multipliers(base_values: Dictionary, char_class: String, level: int) -> Dictionary:
	var final_hp = base_values.HP
	var final_mp = base_values.MP
	
	# Fetch multipliers from your Title Data JSON logic
	var class_mults = promotion_multipliers.get(char_class, {})
	var best_mult = 1.0
	
	# Find the highest level tier the player has reached
	for tier_lvl in class_mults.keys():
		if level >= int(tier_lvl):
			best_mult = float(class_mults[tier_lvl])
	
	# Apply based on class type (HP for Twin-Soul, MP for others)
	if char_class == "Twin-Soul":
		final_hp = int(final_hp * best_mult)
	elif char_class in ["Wuxia", "Spiritmender", "Emberlord"]:
		final_mp = int(final_mp * best_mult)
		
	return {"MaxHP": final_hp, "MaxMP": final_mp}

func get_smart_allocated_stats(char_class: String, level: int) -> Dictionary:
	var cap = 110 if char_class in ["Wuxia", "Spiritmender"] else 120
	var effective_lvl = clamp(level, 1, cap)
	
	var start = class_data.get(char_class, {"Str": 0, "Agi": 0, "Vit": 0, "Spi": 0})
	var target = promotion_reqs.get(char_class, {"Str": 0, "Agi": 0, "Vit": 0, "Spi": 0})
	
	var current_stats = {}
	
	for full_name in stat_map.keys():
		var short_key = stat_map[full_name]
		var total_growth = target.get(short_key, 0) - start.get(short_key, 0)
		var growth_per_level = float(total_growth) / (cap - 1)
		
		# Stores result as "Strength", "Agility", etc.
		current_stats[full_name] = start.get(short_key, 0) + int(growth_per_level * (effective_lvl - 1))
		
	return current_stats

func sync_calculated_stats(char_id: String, hp: int, mp: int):
	var internal_data = {
		"MaxHP": str(hp),
		"MaxMP": str(mp)
	}
	# Updates the Character Internal Data on PlayFab
	PlayFabManager.client.update_character_internal_data(
		char_id, 
		internal_data, 
		func(result): print("Cloud Internal Stats Updated!")
	)
