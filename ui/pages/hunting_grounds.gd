# hunting_grounds.gd — View layer for the Idle / Hunting Grounds tab.
# Pure MVC view: reads state from IdleCombatManager and GameManager, writes nothing back.
extends VBoxContainer

# Runtime reference to IdleCombatManager (avoids compile-time autoload resolution issues)
@onready var icm: Node = get_node("/root/IdleCombatManager")

# ─── Section 1: Idle Activity ───
@onready var fighting_btn: Button = $ScrollContainer/ContentVBox/IdleActivityPanel/Margin/VBox/ModeSwitcher/FightingBtn
@onready var mining_btn: Button = $ScrollContainer/ContentVBox/IdleActivityPanel/Margin/VBox/ModeSwitcher/MiningBtn

# ─── Section 2: Zone Selection ───
@onready var zone_dropdown: OptionButton = $ScrollContainer/ContentVBox/ZonePanel/Margin/VBox/ZoneDropdown
@onready var creature_dropdown: OptionButton = $ScrollContainer/ContentVBox/ZonePanel/Margin/VBox/CreatureDropdown
@onready var change_zone_btn: Button = $ScrollContainer/ContentVBox/ZonePanel/Margin/VBox/ChangeZoneBtn

# ─── Section 3: Combat Status ───
@onready var zone_info_label: Label = $ScrollContainer/ContentVBox/CombatPanel/Margin/VBox/ZoneInfoLabel
@onready var player_hp_value: Label = $ScrollContainer/ContentVBox/CombatPanel/Margin/VBox/PlayerHPRow/PlayerHPValue
@onready var player_hp_bar: ProgressBar = $ScrollContainer/ContentVBox/CombatPanel/Margin/VBox/PlayerHPBar
@onready var attack_speed_bar: ProgressBar = $ScrollContainer/ContentVBox/CombatPanel/Margin/VBox/AttackSpeedBar
@onready var hunt_progress_label: Label = $ScrollContainer/ContentVBox/CombatPanel/Margin/VBox/HuntProgressLabel

# Summon buttons
@onready var summon_1_btn: Button = $ScrollContainer/ContentVBox/CombatPanel/Margin/VBox/SummonRow/Summon1Btn
@onready var summon_5_btn: Button = $ScrollContainer/ContentVBox/CombatPanel/Margin/VBox/SummonRow/Summon5Btn
@onready var summon_10_btn: Button = $ScrollContainer/ContentVBox/CombatPanel/Margin/VBox/SummonRow/Summon10Btn
@onready var summon_25_btn: Button = $ScrollContainer/ContentVBox/CombatPanel/Margin/VBox/SummonRow/Summon25Btn
@onready var queue_count_label: Label = $ScrollContainer/ContentVBox/CombatPanel/Margin/VBox/SummonRow/QueueCountLabel

# Primary target
@onready var mob_name_label: Label = $ScrollContainer/ContentVBox/CombatPanel/Margin/VBox/MobNameRow/MobNameLabel
@onready var mob_hp_value: Label = $ScrollContainer/ContentVBox/CombatPanel/Margin/VBox/MobNameRow/MobHPValue
@onready var mob_hp_bar: ProgressBar = $ScrollContainer/ContentVBox/CombatPanel/Margin/VBox/MobHPBar
@onready var queue_grid: GridContainer = $ScrollContainer/ContentVBox/CombatPanel/Margin/VBox/QueueGrid

# Level / XP
@onready var level_label: Label = $ScrollContainer/ContentVBox/CombatPanel/Margin/VBox/LevelRow/LevelLabel
@onready var level_percent: Label = $ScrollContainer/ContentVBox/CombatPanel/Margin/VBox/LevelRow/LevelPercent
@onready var xp_bar: ProgressBar = $ScrollContainer/ContentVBox/CombatPanel/Margin/VBox/XPBar
@onready var xp_label: Label = $ScrollContainer/ContentVBox/CombatPanel/Margin/VBox/XPLabel

# Footer
@onready var status_label: Label = $ScrollContainer/ContentVBox/CombatPanel/Margin/VBox/FooterRow/StatusLabel
@onready var kills_label: Label = $ScrollContainer/ContentVBox/CombatPanel/Margin/VBox/FooterRow/KillsLabel

# ─── Section 4: Inventory ───
@onready var bag_title: Label = $ScrollContainer/ContentVBox/InventoryPanel/Margin/VBox/BagTitle
@onready var bag_grid: GridContainer = $ScrollContainer/ContentVBox/InventoryPanel/Margin/VBox/BagGrid
@onready var warehouse_title: Label = $ScrollContainer/ContentVBox/InventoryPanel/Margin/VBox/WarehouseTitle
@onready var warehouse_grid: GridContainer = $ScrollContainer/ContentVBox/InventoryPanel/Margin/VBox/WarehouseGrid

# Colors for rare mobs
const RARE_COLOR := Color(1.0, 0.84, 0.0)   # Gold
const NORMAL_COLOR := Color(1.0, 1.0, 1.0)   # White
const BOSS_COLOR := Color(0.8, 0.2, 0.2)     # Red


func _ready() -> void:
	# ── Populate zone dropdown ──
	_populate_zone_dropdown()
	_populate_creature_dropdown()

	# ── Connect UI buttons ──
	fighting_btn.toggled.connect(_on_fighting_toggled)
	mining_btn.toggled.connect(_on_mining_toggled)
	change_zone_btn.pressed.connect(_on_change_zone_pressed)
	zone_dropdown.item_selected.connect(_on_zone_selected)
	summon_1_btn.pressed.connect(_on_summon.bind(1))
	summon_5_btn.pressed.connect(_on_summon.bind(5))
	summon_10_btn.pressed.connect(_on_summon.bind(10))
	summon_25_btn.pressed.connect(_on_summon.bind(25))

	# ── Connect IdleCombatManager signals ──
	icm.combat_tick_updated.connect(_on_combat_tick)
	icm.mob_slain.connect(_on_mob_slain)
	icm.hunt_completed.connect(_on_hunt_completed)
	icm.player_died.connect(_on_player_died)
	icm.xp_gained.connect(_on_xp_gained)
	icm.zone_changed.connect(_on_zone_changed)

	# ── Connect LootManager for inventory refresh ──
	var loot_mgr = get_node_or_null("/root/LootManager")
	if loot_mgr:
		loot_mgr.loot_dropped.connect(_on_loot_dropped)

	# ── Kick off combat on first load ──
	icm.start_combat()

	# ── Initial UI sync ──
	_refresh_all_ui()

func _process(_delta: float) -> void:
	if icm.combat_active:
		# Thin attack speed bar below HP: fills up as cooldown approaches 0
		var cd = icm._attack_cooldown
		var interval = icm.attack_interval
		attack_speed_bar.max_value = interval
		attack_speed_bar.value = interval - cd

# ─── Dropdown Helpers ───

func _populate_zone_dropdown() -> void:
	zone_dropdown.clear()
	for zone_name in icm.get_zone_names():
		zone_dropdown.add_item(zone_name)
	var idx = icm.get_zone_names().find(icm.current_zone)
	if idx >= 0:
		zone_dropdown.select(idx)

func _populate_creature_dropdown() -> void:
	creature_dropdown.clear()
	var creatures = icm.get_creature_names(icm.current_zone)
	for c in creatures:
		creature_dropdown.add_item(c)
	var idx = creatures.find(icm.current_creature)
	if idx >= 0:
		creature_dropdown.select(idx)

# ─── Button Handlers ───

func _on_fighting_toggled(pressed: bool) -> void:
	if pressed:
		icm.set_mode_fighting(true)
		status_label.text = "In Combat"

func _on_mining_toggled(pressed: bool) -> void:
	if pressed:
		icm.set_mode_fighting(false)
		status_label.text = "Mining (idle)"

func _on_zone_selected(index: int) -> void:
	# Populate creatures for the SELECTED zone, not the current combat zone
	var selected_zone = zone_dropdown.get_item_text(index)
	creature_dropdown.clear()
	var creatures = icm.get_creature_names(selected_zone)
	for c in creatures:
		creature_dropdown.add_item(c)
	if creatures.size() > 0:
		creature_dropdown.select(0)

func _on_summon(count: int) -> void:
	icm.summon_monsters(count)

func _on_change_zone_pressed() -> void:
	var zone_name = zone_dropdown.get_item_text(zone_dropdown.selected)
	var creature_name = creature_dropdown.get_item_text(creature_dropdown.selected)
	icm.change_zone(zone_name, creature_name)
	icm.start_combat()

# ─── Signal Handlers ───

func _on_combat_tick() -> void:
	_refresh_combat_ui()

func _on_mob_slain(_mob_data: Dictionary) -> void:
	_refresh_combat_ui()

func _on_hunt_completed() -> void:
	_refresh_combat_ui()

func _on_player_died() -> void:
	_refresh_combat_ui()

func _on_xp_gained(_amount: int) -> void:
	_refresh_xp_ui()

func _on_zone_changed() -> void:
	_populate_creature_dropdown()
	_refresh_combat_ui()

func _on_loot_dropped(_item: ItemData) -> void:
	_refresh_inventory_ui()

# ─── UI Refresh ───

func _refresh_all_ui() -> void:
	_refresh_combat_ui()
	_refresh_xp_ui()
	_refresh_inventory_ui()

func _refresh_combat_ui() -> void:

	# Zone info
	zone_info_label.text = "Currently fighting in %s" % icm.current_zone

	# Player HP
	player_hp_value.text = "%d / %d" % [icm.player_hp, icm.player_max_hp]
	player_hp_bar.max_value = max(1, icm.player_max_hp)
	player_hp_bar.value = icm.player_hp

	# Hunt progress (just above primary target)
	hunt_progress_label.text = "Current Hunt (%d/%d)" % [icm.kills_this_hunt, icm.hunt_target]

	# Queue count
	queue_count_label.text = "Queue: %d/%d" % [icm.monster_queue.size(), icm.MAX_QUEUE_SIZE]

	# Primary target (first in queue)
	var primary = icm.get_primary_target()
	if primary.is_empty():
		mob_name_label.text = "No target"
		mob_hp_value.text = "0 / 0"
		mob_hp_bar.value = 0
		mob_name_label.modulate = NORMAL_COLOR
	else:
		mob_name_label.text = primary.get("name", "?")
		if primary.get("is_rare", false):
			mob_name_label.text += " (Rare)"
			mob_name_label.modulate = RARE_COLOR
		elif primary.get("is_boss", false):
			mob_name_label.text += " (Boss)"
			mob_name_label.modulate = BOSS_COLOR
		else:
			mob_name_label.modulate = NORMAL_COLOR

		var hp = primary.get("hp", 0)
		var max_hp = primary.get("max_hp", 1)
		mob_hp_value.text = "%d / %d" % [hp, max_hp]
		mob_hp_bar.max_value = max(1, max_hp)
		mob_hp_bar.value = hp

	# Monster queue (skip index 0, that's the primary target)
	_refresh_queue_grid()

	# Footer
	if icm.combat_active:
		status_label.text = "In Combat"
	else:
		status_label.text = "Idle"
	kills_label.text = "Kills: %d  Deaths: %d" % [icm.total_kills, icm.total_deaths]

func _refresh_queue_grid() -> void:
	# Clear old entries
	for child in queue_grid.get_children():
		child.queue_free()

	# Skip index 0 (primary target), show up to 24 remaining
	# Each mob gets a VBox with: name label + mini HP bar
	for i in range(1, icm.monster_queue.size()):
		var mob = icm.monster_queue[i]
		var mob_name = mob.get("name", "?")
		var hp = mob.get("hp", 0)
		var max_hp = mob.get("max_hp", 1)

		var entry = VBoxContainer.new()
		entry.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		entry.add_theme_constant_override("separation", 2)

		# Name + HP label
		var name_label = Label.new()
		if mob.get("is_rare", false):
			name_label.text = "%s (Rare) %d/%d" % [mob_name, hp, max_hp]
			name_label.modulate = RARE_COLOR
		elif mob.get("is_boss", false):
			name_label.text = "%s (Boss) %d/%d" % [mob_name, hp, max_hp]
			name_label.modulate = BOSS_COLOR
		else:
			name_label.text = "%s %d/%d" % [mob_name, hp, max_hp]
		name_label.add_theme_font_size_override("font_size", 11)
		entry.add_child(name_label)

		# Mini HP bar
		var hp_bar = ProgressBar.new()
		hp_bar.custom_minimum_size = Vector2(0, 8)
		hp_bar.max_value = max(1, max_hp)
		hp_bar.value = hp
		hp_bar.show_percentage = false
		hp_bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		entry.add_child(hp_bar)

		queue_grid.add_child(entry)

func _refresh_xp_ui() -> void:
	var level = GameManager.active_character_level
	level_label.text = "Level %d" % level
	xp_bar.max_value = max(1, icm.xp_to_next_level)
	xp_bar.value = icm.current_xp
	var pct = 0.0
	if icm.xp_to_next_level > 0:
		pct = (float(icm.current_xp) / icm.xp_to_next_level) * 100.0
	level_percent.text = "%.2f%%" % pct
	xp_label.text = "%d / %d XP" % [icm.current_xp, icm.xp_to_next_level]

func _refresh_inventory_ui() -> void:
	var inv = GameManager.active_user_inventory
	var bag_count = min(inv.size(), 40)
	var warehouse_count = max(0, inv.size() - 40)
	bag_title.text = "Main Bag (%d/40)" % bag_count
	warehouse_title.text = "Warehouse (%d/40)" % warehouse_count

	if bag_grid and bag_grid.is_inside_tree():
		bag_grid.refresh_grid()
	if warehouse_grid and warehouse_grid.is_inside_tree():
		warehouse_grid.refresh_grid()
