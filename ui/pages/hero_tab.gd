extends MarginContainer

@onready var hp_row = $ScrollContent/ContentVBox/StatsCard/Margin/VBox/HPRow
@onready var str_row = $ScrollContent/ContentVBox/StatsCard/Margin/VBox/StrRow
@onready var agi_row = $ScrollContent/ContentVBox/StatsCard/Margin/VBox/AgiRow
@onready var vit_row = $ScrollContent/ContentVBox/StatsCard/Margin/VBox/VitRow
@onready var spi_row = $ScrollContent/ContentVBox/StatsCard/Margin/VBox/SpiRow
@onready var name_label = $ScrollContent/ContentVBox/ProfileCard/Margin/VBox/CharName

# ─── Equipment Slots (InventorySlot instances) ───
@onready var equip_slots: Dictionary = {
	"Headgear": $ScrollContent/ContentVBox/ProfileCard/Margin/VBox/Equipment/HeadgearSlot,
	"Armor": $ScrollContent/ContentVBox/ProfileCard/Margin/VBox/Equipment/ArmorSlot,
	"Ring": $ScrollContent/ContentVBox/ProfileCard/Margin/VBox/Equipment/RingSlot,
	"Necklace": $ScrollContent/ContentVBox/ProfileCard/Margin/VBox/Equipment/NecklaceSlot,
	"Boots": $ScrollContent/ContentVBox/ProfileCard/Margin/VBox/Equipment/BootsSlot,
	"Weapon": $ScrollContent/ContentVBox/ProfileCard/Margin/VBox/Equipment/WeaponSlot,
	"Offhand": $ScrollContent/ContentVBox/ProfileCard/Margin/VBox/Equipment/OffhandSlot,
	"Backpack": $ScrollContent/ContentVBox/ProfileCard/Margin/VBox/Equipment/BackpackSlot,
}

# Slot label names shown when empty
const SLOT_LABELS := {
	"Headgear": "Head",
	"Armor": "Armor",
	"Ring": "Ring",
	"Necklace": "Neck",
	"Boots": "Boots",
	"Weapon": "Weapon",
	"Offhand": "Offhand",
	"Backpack": "Pack",
}

# --- Currency & Material Labels ---
@onready var gold_label = $ScrollContent/ContentVBox/CurrenciesCard/Margin/VBox/VBoxContainer/Gold
@onready var echo_label = $ScrollContent/ContentVBox/CurrenciesCard/Margin/VBox/VBoxContainer/EchoToken
@onready var comet_label = $ScrollContent/ContentVBox/CurrenciesCard/Margin/VBox/VBoxContainer/Comets
@onready var wyrmsphere_label = $ScrollContent/ContentVBox/CurrenciesCard/Margin/VBox/VBoxContainer/WyrmSphere
@onready var ignis_labels = {
	"I1": $ScrollContent/ContentVBox/CurrenciesCard/Margin/VBox/VBoxContainer/Ignis1,
	"I2": $ScrollContent/ContentVBox/CurrenciesCard/Margin/VBox/VBoxContainer/Ignis2,
	"I3": $ScrollContent/ContentVBox/CurrenciesCard/Margin/VBox/VBoxContainer/Ignis3,
	"I4": $ScrollContent/ContentVBox/CurrenciesCard/Margin/VBox/VBoxContainer/Ignis4,
	"I5": $ScrollContent/ContentVBox/CurrenciesCard/Margin/VBox/VBoxContainer/Ignis5,
	"I6": $ScrollContent/ContentVBox/CurrenciesCard/Margin/VBox/VBoxContainer/Ignis6
}

# UI elements for bulk submission
@onready var points_box = $ScrollContent/ContentVBox/StatsCard/Margin/VBox/HBoxContainer
@onready var points_label = $ScrollContent/ContentVBox/StatsCard/Margin/VBox/HBoxContainer/PointsLabel
@onready var ok_button = $ScrollContent/ContentVBox/StatsCard/Margin/VBox/HBoxContainer/OkButton

var pending_stats = {"Strength": 0, "Agility": 0, "Vitality": 0, "Spirit": 0}
var total_pending_cost = 0

func _ready():
	# Connect stat row signals
	str_row.stat_increased.connect(_on_stat_increase_requested)
	agi_row.stat_increased.connect(_on_stat_increase_requested)
	vit_row.stat_increased.connect(_on_stat_increase_requested)
	spi_row.stat_increased.connect(_on_stat_increase_requested)
	
	str_row.stat_decreased.connect(_on_stat_decrease_requested)
	agi_row.stat_decreased.connect(_on_stat_decrease_requested)
	vit_row.stat_decreased.connect(_on_stat_decrease_requested)
	spi_row.stat_decreased.connect(_on_stat_decrease_requested)
	
	if ok_button and not ok_button.pressed.is_connected(_on_ok_button_pressed):
		ok_button.pressed.connect(_on_ok_button_pressed)
	
	GameManager.character_stats_updated.connect(update_hero_ui)
	GameManager.equipment_changed.connect(_refresh_equipment_slots)
	
	# Set equipment slot mode on each slot so right-click unequips
	for slot_name in equip_slots:
		var slot_node = equip_slots[slot_name]
		if slot_node:
			slot_node.equipment_slot_name = slot_name
	
	# Since GameManager now pre-fetches during login, we usually don't need to fetch here
	update_hero_ui()

func update_hero_ui():
	var invested = GameManager.active_character_stats
	var char_class = GameManager.active_character_class
	var level = GameManager.active_character_level
	var awaken_count = GameManager.active_character_awakening
	
	if name_label:
		name_label.text = GameManager.active_character_name

	# Refresh equipment slot visuals
	_refresh_equipment_slots()

	# Automated Currency Refresh
	for child in get_tree().get_nodes_in_group("currency_slots"):
		if child.has_method("update_display"):
			child.update_display()
	
	# --- Existing Stat Logic ---
	var base = StatCalculator.get_smart_allocated_stats(char_class, level)
	var total_str = int(base.get("Strength", 0) + invested.get("Strength", 0)) + pending_stats["Strength"]
	var total_agi = int(base.get("Agility", 0) + invested.get("Agility", 0)) + pending_stats["Agility"]
	var total_vit = int(base.get("Vitality", 0) + invested.get("Vitality", 0)) + pending_stats["Vitality"]
	var total_spi = int(base.get("Spirit", 0) + invested.get("Spirit", 0)) + pending_stats["Spirit"]
	
	var totals_dict = {"Strength": total_str, "Agility": total_agi, "Vitality": total_vit, "Spirit": total_spi}
	var base_vitals = StatCalculator.calculate_base_stats(totals_dict)
	var final_vitals = StatCalculator.apply_multipliers(base_vitals, char_class, level)
	
	var points_available = int(invested.get("AvailableAttributePoints", 0))
	var points_remaining = points_available - total_pending_cost
	var can_up = points_remaining > 0 and awaken_count > 0
	
	if points_box:
		points_box.visible = (points_remaining > 0 or total_pending_cost > 0)
		if points_label:
			points_label.text = "Available Points: " + str(points_remaining)
			
	if ok_button:
		ok_button.visible = total_pending_cost > 0
	
	if hp_row:
		var current_hp = int(invested.get("CurrentHP", final_vitals.MaxHP))
		hp_row.update_hp(str(current_hp), str(int(final_vitals.MaxHP)))
		
	if str_row: str_row.update_display("Strength", total_str, can_up, pending_stats["Strength"] > 0)
	if agi_row: agi_row.update_display("Agility", total_agi, can_up, pending_stats["Agility"] > 0)
	if vit_row: vit_row.update_display("Vitality", total_vit, can_up, pending_stats["Vitality"] > 0)
	if spi_row: spi_row.update_display("Spirit", total_spi, can_up, pending_stats["Spirit"] > 0)

# ─── Equipment Slot Population ───

func _refresh_equipment_slots() -> void:
	for slot_name in equip_slots:
		var slot_node = equip_slots[slot_name]
		if not slot_node or not is_instance_valid(slot_node):
			continue

		var item_data = GameManager.get_equipped_item_data(slot_name)
		if item_data:
			slot_node.set_item(item_data)
		else:
			# Empty slot -- show placeholder with slot label
			slot_node.set_item(null)
			# Set the count label to show slot name as a hint
			var count_lbl = slot_node.get_node_or_null("LabelsOverlay/CountLabel")
			if count_lbl:
				count_lbl.text = SLOT_LABELS.get(slot_name, slot_name)
				count_lbl.add_theme_font_size_override("font_size", 10)
				count_lbl.add_theme_color_override("font_color", Color(0.5, 0.5, 0.5))

func _on_stat_increase_requested(stat_name: String):
	var points_available = int(GameManager.active_character_stats.get("AvailableAttributePoints", 0))
	if total_pending_cost < points_available:
		pending_stats[stat_name] += 1
		total_pending_cost += 1
		update_hero_ui()

func _on_stat_decrease_requested(stat_name: String):
	if pending_stats[stat_name] > 0:
		pending_stats[stat_name] -= 1
		total_pending_cost -= 1
		update_hero_ui()

func _on_ok_button_pressed():
	if total_pending_cost <= 0: return
	
	var stats_to_send = pending_stats.duplicate()
	var char_id = GameManager.active_character_id
	
	# Optimistic local update
	GameManager.active_character_stats["AvailableAttributePoints"] -= total_pending_cost
	
	pending_stats = {"Strength": 0, "Agility": 0, "Vitality": 0, "Spirit": 0}
	total_pending_cost = 0
	update_hero_ui() 

	# FIX: Sending every variation of ID to satisfy the CloudScript
	var params = {
		"CharacterId": char_id,
		"characterId": char_id,
		"character_id": char_id,
		"statsToIncrease": stats_to_send
	}
	
	PlayFabManager.client.execute_cloud_script("bulkIncreaseAttributes", params, func(result):
		var data = {}
		if result.has("FunctionResult"):
			data = result.FunctionResult
		elif result.has("data") and result.data.has("FunctionResult"):
			data = result.data.FunctionResult
			
		if data.get("success", false):
			var server_stats = data.get("newStats", {})
			for stat_name in server_stats.keys():
				GameManager.active_character_stats[stat_name] = int(server_stats[stat_name])
			
			update_hero_ui()
			print("HeroTab: Sync complete. Points: ", GameManager.active_character_stats["AvailableAttributePoints"])
		else:
			fetch_character_stats_from_playfab()
			print("HeroTab: Server sync failed. If points revert, CharacterId is missing in CloudScript.")
	)

func fetch_character_stats_from_playfab():
	var char_id = GameManager.active_character_id
	PlayFabManager.client.get_character_statistics(char_id, func(result):
		var stats_dict = result.get("data", {}).get("CharacterStatistics", {})
		var new_stats = {"Strength": 0, "Agility": 0, "Vitality": 0, "Spirit": 0, "AvailableAttributePoints": 0}
		for key in stats_dict.keys():
			var val = stats_dict[key]
			if new_stats.has(key): new_stats[key] = int(val)
			elif key == "Level": GameManager.active_character_level = int(val)
			elif key == "AwakeningCount": GameManager.active_character_awakening = int(val)
		
		GameManager.active_character_stats = new_stats
		update_hero_ui()
	)

# deposit_material_to_bank removed — all materials are now inventory items only.
# No PlayFab currency deposit needed; materials stay in inventory and are
# counted directly via GameManager.get_material_count().
