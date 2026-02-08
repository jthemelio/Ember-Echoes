extends ScrollContainer

@onready var hp_row = $ScrollWrapper/S1_Profile_Equipment_Stats/Stats/HPRow
@onready var str_row = $ScrollWrapper/S1_Profile_Equipment_Stats/Stats/StrRow
@onready var agi_row = $ScrollWrapper/S1_Profile_Equipment_Stats/Stats/AgiRow
@onready var vit_row = $ScrollWrapper/S1_Profile_Equipment_Stats/Stats/VitRow
@onready var spi_row = $ScrollWrapper/S1_Profile_Equipment_Stats/Stats/SpiRow

func _ready():
	# Connect signals from each row to the new function
	str_row.stat_increased.connect(_on_stat_increased)
	agi_row.stat_increased.connect(_on_stat_increased)
	vit_row.stat_increased.connect(_on_stat_increased)
	spi_row.stat_increased.connect(_on_stat_increased)
	
	update_hero_ui()

func update_hero_ui():
	var char_class = GameManager.active_character_class
	var level = GameManager.active_character_level
	var invested = GameManager.active_character_stats # From PlayFab
	
	# 1. Get "Smart Growth" Base Stats from your Calculator
	var base = StatCalculator.get_smart_allocated_stats(char_class, level)
	
	# 2. Calculate Totals (Base JSON + Invested PlayFab)
	var total_str = base.get("Strength", 0) + invested.get("Strength", 0)
	var total_agi = base.get("Agility", 0) + invested.get("Agility", 0)
	var total_vit = base.get("Vitality", 0) + invested.get("Vitality", 0)
	var total_spi = base.get("Spirit", 0) + invested.get("Spirit", 0)
	
	# 3. Calculate Derived Vitals (HP/MP)
	var totals_dict = {
		"Strength": total_str,
		"Agility": total_agi,
		"Vitality": total_vit,
		"Spirit": total_spi
	}
	var base_vitals = StatCalculator.calculate_base_stats(totals_dict)
	var final_vitals = StatCalculator.apply_multipliers(base_vitals, char_class, level)
	
	# 4. Push to UI Rows
	var points = invested.get("AvailableAttributePoints", 0)
	var can_up = points > 0
	
	if hp_row:
		var current_hp = invested.get("CurrentHP", final_vitals.MaxHP)
		hp_row.update_hp(str(current_hp), str(final_vitals.MaxHP))
		
	if str_row: str_row.update_display("Strength", total_str, can_up)
	if agi_row: agi_row.update_display("Agility", total_agi, can_up)
	if vit_row: vit_row.update_display("Vitality", total_vit, can_up)
	if spi_row: spi_row.update_display("Spirit", total_spi, can_up)


func _on_stat_increased(stat_name: String):
	var current_stat_val = GameManager.active_character_stats.get(stat_name, 0)
	var current_points = GameManager.active_character_stats.get("AvailableAttributePoints", 0)
	
	if current_points <= 0: return

	# Format the update as an ARRAY of dictionaries for the API 
	var updates_array = [
		{"StatisticName": stat_name, "Value": current_stat_val + 1},
		{"StatisticName": "AvailableAttributePoints", "Value": current_points - 1}
	]
	
	PlayFabManager.client.update_character_statistics(
		GameManager.active_character_id,
		updates_array, # Pass the array here 
		func(_result): # Added underscore to fix warning 
			print(stat_name, " increased successfully!")
			GameManager.active_character_stats[stat_name] = current_stat_val + 1
			GameManager.active_character_stats["AvailableAttributePoints"] = current_points - 1
			update_hero_ui()
	)
