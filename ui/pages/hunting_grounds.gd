# hunting_grounds.gd — View layer for the Idle / Hunting Grounds tab.
# Pure MVC view: reads state from IdleCombatManager and GameManager, writes nothing back.
extends MarginContainer

# Runtime reference to IdleCombatManager (avoids compile-time autoload resolution issues)
@onready var icm: Node = get_node("/root/IdleCombatManager")

# ─── Section 1: Idle Activity ───
@onready var fighting_btn: Button = $ScrollContent/ContentVBox/IdleActivityPanel/Margin/VBox/ModeSwitcher/FightingBtn
@onready var mining_btn: Button = $ScrollContent/ContentVBox/IdleActivityPanel/Margin/VBox/ModeSwitcher/MiningBtn

# ─── Section 2: Zone Selection ───
@onready var zone_dropdown: OptionButton = $ScrollContent/ContentVBox/ZonePanel/Margin/VBox/ZoneDropdown
@onready var creature_dropdown: OptionButton = $ScrollContent/ContentVBox/ZonePanel/Margin/VBox/CreatureDropdown
@onready var change_zone_btn: Button = $ScrollContent/ContentVBox/ZonePanel/Margin/VBox/ChangeZoneBtn

# ─── Section 3: Combat Status ───
@onready var zone_info_label: Label = $ScrollContent/ContentVBox/CombatPanel/Margin/VBox/ZoneInfoLabel
@onready var player_hp_value: Label = $ScrollContent/ContentVBox/CombatPanel/Margin/VBox/PlayerHPRow/PlayerHPValue
@onready var player_hp_bar: ProgressBar = $ScrollContent/ContentVBox/CombatPanel/Margin/VBox/PlayerHPBar
@onready var attack_speed_bar: ProgressBar = $ScrollContent/ContentVBox/CombatPanel/Margin/VBox/AttackSpeedBar
@onready var hunt_progress_label: Label = $ScrollContent/ContentVBox/CombatPanel/Margin/VBox/HuntProgressLabel
@onready var spawn_timer_bar: ProgressBar = $ScrollContent/ContentVBox/CombatPanel/Margin/VBox/SpawnTimerBar

# Summon row (Skill + Qty dropdown + Summon btn)
@onready var skill_btn: Button = $ScrollContent/ContentVBox/CombatPanel/Margin/VBox/SummonRow/SkillBtn
@onready var summon_qty_dropdown: OptionButton = $ScrollContent/ContentVBox/CombatPanel/Margin/VBox/SummonRow/SummonQtyDropdown
@onready var summon_btn: Button = $ScrollContent/ContentVBox/CombatPanel/Margin/VBox/SummonRow/SummonBtn
@onready var queue_count_label: Label = $ScrollContent/ContentVBox/CombatPanel/Margin/VBox/SummonRow/QueueCountLabel

# Primary target
@onready var mob_name_label: Label = $ScrollContent/ContentVBox/CombatPanel/Margin/VBox/MobNameRow/MobNameLabel
@onready var mob_hp_value: Label = $ScrollContent/ContentVBox/CombatPanel/Margin/VBox/MobNameRow/MobHPValue
@onready var mob_hp_bar: ProgressBar = $ScrollContent/ContentVBox/CombatPanel/Margin/VBox/MobHPBar
@onready var queue_grid: GridContainer = $ScrollContent/ContentVBox/CombatPanel/Margin/VBox/QueueGrid

# Level / XP
@onready var level_label: Label = $ScrollContent/ContentVBox/CombatPanel/Margin/VBox/LevelRow/LevelLabel
@onready var level_percent: Label = $ScrollContent/ContentVBox/CombatPanel/Margin/VBox/LevelRow/LevelPercent
@onready var xp_bar: ProgressBar = $ScrollContent/ContentVBox/CombatPanel/Margin/VBox/XPBar
@onready var xp_label: Label = $ScrollContent/ContentVBox/CombatPanel/Margin/VBox/XPLabel

# Footer -- Monster kill tracker
@onready var kill_tracker_label: Label = $ScrollContent/ContentVBox/CombatPanel/Margin/VBox/FooterRow/KillTrackerLabel

# ─── Section 4: Inventory ───
@onready var bag_title: Label = $ScrollContent/ContentVBox/InventoryPanel/Margin/VBox/BagTitle
@onready var bag_grid: GridContainer = $ScrollContent/ContentVBox/InventoryPanel/Margin/VBox/BagGrid
@onready var warehouse_title: Label = $ScrollContent/ContentVBox/InventoryPanel/Margin/VBox/WarehouseTitle
@onready var warehouse_grid: GridContainer = $ScrollContent/ContentVBox/InventoryPanel/Margin/VBox/WarehouseGrid

# Bag buttons
@onready var select_bag_btn: Button = $ScrollContent/ContentVBox/InventoryPanel/Margin/VBox/BagButtonRow/SelectBagBtn
@onready var sell_bag_btn: Button = $ScrollContent/ContentVBox/InventoryPanel/Margin/VBox/BagButtonRow/SellBagBtn
@onready var move_bag_btn: Button = $ScrollContent/ContentVBox/InventoryPanel/Margin/VBox/BagButtonRow/MoveBagBtn
@onready var cancel_bag_btn: Button = $ScrollContent/ContentVBox/InventoryPanel/Margin/VBox/BagButtonRow/CancelBagBtn

# Quality filter buttons
@onready var filter_all_btn: Button = $ScrollContent/ContentVBox/InventoryPanel/Margin/VBox/QualityFilterRow/FilterAllBtn
@onready var filter_normal_btn: Button = $ScrollContent/ContentVBox/InventoryPanel/Margin/VBox/QualityFilterRow/FilterNormalBtn
@onready var filter_tempered_btn: Button = $ScrollContent/ContentVBox/InventoryPanel/Margin/VBox/QualityFilterRow/FilterTemperedBtn
@onready var filter_infused_btn: Button = $ScrollContent/ContentVBox/InventoryPanel/Margin/VBox/QualityFilterRow/FilterInfusedBtn
@onready var filter_brilliant_btn: Button = $ScrollContent/ContentVBox/InventoryPanel/Margin/VBox/QualityFilterRow/FilterBrilliantBtn
@onready var filter_radiant_btn: Button = $ScrollContent/ContentVBox/InventoryPanel/Margin/VBox/QualityFilterRow/FilterRadiantBtn

# Select/sell state
var _select_mode: bool = false
var _selected_indices: Array = []  # Bag indices of selected items

# Colors for rare mobs
const RARE_COLOR := Color(1.0, 0.84, 0.0)   # Gold
const NORMAL_COLOR := Color(1.0, 1.0, 1.0)   # White
const BOSS_COLOR := Color(0.8, 0.2, 0.2)     # Red

# Smooth attack bar tween
var _attack_bar_tween: Tween = null
var _last_attack_interval: float = 0.0

# Smooth spawn timer bar tween
var _spawn_bar_tween: Tween = null

func _ready() -> void:
	# ── Populate zone dropdown ──
	_populate_zone_dropdown()
	_populate_creature_dropdown()

	# ── Connect UI buttons ──
	fighting_btn.toggled.connect(_on_fighting_toggled)
	mining_btn.toggled.connect(_on_mining_toggled)
	change_zone_btn.pressed.connect(_on_change_zone_pressed)
	zone_dropdown.item_selected.connect(_on_zone_selected)
	# Populate quantity dropdown
	for qty in [1, 5, 10, 25, 50, 100]:
		summon_qty_dropdown.add_item(str(qty))
	summon_qty_dropdown.selected = 0  # Default to 1

	summon_btn.pressed.connect(_on_summon_pressed)
	skill_btn.pressed.connect(_on_skill_pressed)

	# ── Connect IdleCombatManager signals ──
	icm.combat_tick_updated.connect(_on_combat_tick)
	icm.mob_slain.connect(_on_mob_slain)
	icm.hunt_completed.connect(_on_hunt_completed)
	icm.player_died.connect(_on_player_died)
	icm.player_respawned.connect(_on_player_respawned)
	icm.xp_gained.connect(_on_xp_gained)
	icm.mob_spawned.connect(_on_mob_spawned)
	icm.zone_changed.connect(_on_zone_changed)
	icm.out_of_arrows.connect(_on_out_of_arrows)

	# ── Connect LootManager for inventory refresh ──
	var loot_mgr = get_node_or_null("/root/LootManager")
	if loot_mgr:
		loot_mgr.loot_dropped.connect(_on_loot_dropped)

	# ── Connect GameManager inventory_changed (e.g. shop purchases, equip/unequip) ──
	GameManager.inventory_changed.connect(_on_inventory_changed)

	# ── Bag select/sell/move/filter buttons ──
	select_bag_btn.pressed.connect(_on_select_pressed)
	sell_bag_btn.pressed.connect(_on_sell_pressed)
	move_bag_btn.pressed.connect(_on_move_pressed)
	cancel_bag_btn.pressed.connect(_on_cancel_select)

	# Quality filter buttons -- colored blocks matching the tier border colors
	_setup_filter_button(filter_all_btn, "", Color.WHITE)
	_setup_filter_button(filter_normal_btn, "Normal", Color(0.55, 0.55, 0.58))
	_setup_filter_button(filter_tempered_btn, "Tempered", Color(0.910, 0.788, 0.608))
	_setup_filter_button(filter_infused_btn, "Infused", Color(0.784, 0.816, 0.863))
	_setup_filter_button(filter_brilliant_btn, "Brilliant", Color(0.659, 0.847, 0.941))
	_setup_filter_button(filter_radiant_btn, "Radiant", Color(0.941, 0.722, 0.478))

	# ── Kick off combat on first load ──
	icm.start_combat()

	# ── Desktop responsive: adapt grid columns and sizing ──
	_adapt_for_desktop()

	# ── Initial UI sync ──
	_refresh_all_ui()
	_restart_attack_bar_tween()
	_restart_spawn_bar_tween()

func _adapt_for_desktop() -> void:
	if not ScreenHelper.is_desktop():
		return
	# Inventory grids: 5 -> 6 columns on desktop (800px content width)
	if bag_grid:
		bag_grid.columns = ScreenHelper.grid_columns(5, 6)
	if warehouse_grid:
		warehouse_grid.columns = ScreenHelper.grid_columns(5, 6)
	# Queue grid: 2 -> 3 columns
	if queue_grid:
		queue_grid.columns = ScreenHelper.grid_columns(2, 3)
	# Scale filter buttons
	var s = ScreenHelper.get_ui_scale()
	for btn in [filter_all_btn, filter_normal_btn, filter_tempered_btn, filter_infused_btn, filter_brilliant_btn, filter_radiant_btn]:
		if btn and btn.custom_minimum_size != Vector2.ZERO:
			btn.custom_minimum_size = Vector2(btn.custom_minimum_size.x * s, btn.custom_minimum_size.y * s)
	# Scale summon row elements
	for btn in [skill_btn, summon_btn]:
		if btn:
			btn.custom_minimum_size.y = ScreenHelper.scaled_min_height(btn.custom_minimum_size.y) if btn.custom_minimum_size.y > 0 else 0

func _process(_delta: float) -> void:
	pass  # Attack bar is tween-driven, no per-frame update needed

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

func _on_mining_toggled(pressed: bool) -> void:
	if pressed:
		icm.set_mode_fighting(false)

func _on_zone_selected(index: int) -> void:
	# Populate creatures for the SELECTED zone, not the current combat zone
	var selected_zone = zone_dropdown.get_item_text(index)
	creature_dropdown.clear()
	var creatures = icm.get_creature_names(selected_zone)
	for c in creatures:
		creature_dropdown.add_item(c)
	if creatures.size() > 0:
		creature_dropdown.select(0)

func _on_summon_pressed() -> void:
	var idx = summon_qty_dropdown.selected
	if idx < 0:
		return
	var qty_text = summon_qty_dropdown.get_item_text(idx)
	var count = int(qty_text)
	if count > 0:
		icm.summon_monsters(count)

func _on_skill_pressed() -> void:
	var sm = get_node_or_null("/root/SkillManager")
	if sm and sm.has_method("try_use_skill"):
		sm.try_use_skill()
	else:
		GlobalUI.show_floating_text("No skill equipped", Color(0.8, 0.8, 0.8))

func _on_change_zone_pressed() -> void:
	var zone_name = zone_dropdown.get_item_text(zone_dropdown.selected)
	var creature_name = creature_dropdown.get_item_text(creature_dropdown.selected)
	icm.change_zone(zone_name, creature_name)
	icm.start_combat()

# ─── Signal Handlers ───

func _on_combat_tick() -> void:
	_refresh_combat_ui()
	_ensure_attack_bar_tween()

func _on_mob_slain(_mob_data: Dictionary) -> void:
	_refresh_combat_ui()

func _on_hunt_completed() -> void:
	_refresh_combat_ui()

func _on_player_died() -> void:
	# Kill the attack bar tween during death
	if _attack_bar_tween:
		_attack_bar_tween.kill()
		_attack_bar_tween = null
	attack_speed_bar.value = 0
	_stop_spawn_bar_tween()
	_refresh_combat_ui()

func _on_player_respawned() -> void:
	_refresh_combat_ui()
	_restart_attack_bar_tween()
	_restart_spawn_bar_tween()

func _on_out_of_arrows() -> void:
	GlobalUI.show_floating_text("Out of arrows!", Color(1, 0.3, 0.3))
	_refresh_combat_ui()

func _on_xp_gained(_amount: int) -> void:
	_refresh_xp_ui()

func _on_mob_spawned() -> void:
	_restart_spawn_bar_tween()

func _on_zone_changed() -> void:
	_populate_creature_dropdown()
	_refresh_combat_ui()
	_restart_spawn_bar_tween()

func _on_loot_dropped(_item: ItemData) -> void:
	_refresh_inventory_ui()

func _on_inventory_changed() -> void:
	_refresh_inventory_ui()

# ─── Attack Bar Tween (smooth animation) ───

func _ensure_attack_bar_tween() -> void:
	# Only create/restart the tween if we don't already have one running,
	# or if the attack_interval changed (e.g. new weapon equipped).
	if icm.is_dead or not icm.combat_active:
		return
	if _attack_bar_tween and _attack_bar_tween.is_running() and _last_attack_interval == icm.attack_interval:
		return
	_restart_attack_bar_tween()

func _restart_attack_bar_tween() -> void:
	if _attack_bar_tween:
		_attack_bar_tween.kill()
		_attack_bar_tween = null
	# Don't animate the attack bar if combat isn't running
	if not icm.combat_active or icm.is_dead:
		attack_speed_bar.value = 0.0
		return
	_last_attack_interval = icm.attack_interval
	attack_speed_bar.max_value = 1.0
	attack_speed_bar.value = 0.0
	_attack_bar_tween = create_tween().set_loops()
	_attack_bar_tween.tween_property(attack_speed_bar, "value", 1.0, icm.attack_interval).from(0.0).set_trans(Tween.TRANS_LINEAR)

func _restart_spawn_bar_tween() -> void:
	if _spawn_bar_tween:
		_spawn_bar_tween.kill()
		_spawn_bar_tween = null
	# Don't animate spawn bar if combat isn't running
	if not icm.combat_active or icm.is_dead:
		spawn_timer_bar.value = 0.0
		return
	spawn_timer_bar.max_value = 1.0
	spawn_timer_bar.value = 0.0
	_spawn_bar_tween = create_tween().set_loops()
	_spawn_bar_tween.tween_property(spawn_timer_bar, "value", 1.0, icm.SPAWN_INTERVAL).from(0.0).set_trans(Tween.TRANS_LINEAR)

func _stop_spawn_bar_tween() -> void:
	if _spawn_bar_tween:
		_spawn_bar_tween.kill()
		_spawn_bar_tween = null
	spawn_timer_bar.value = 0

# ─── UI Refresh ───

func _refresh_all_ui() -> void:
	_refresh_combat_ui()
	_refresh_xp_ui()
	_refresh_inventory_ui()

func _refresh_combat_ui() -> void:
	# Update skill button label
	var equipped_skill = SkillManager.get_equipped_skill()
	if equipped_skill.is_empty():
		skill_btn.text = "Skill"
		skill_btn.disabled = true
	else:
		skill_btn.text = equipped_skill.get("name", "Skill")
		skill_btn.disabled = false

	# Zone info
	zone_info_label.text = "Currently fighting in %s" % icm.current_zone

	# Player HP
	player_hp_value.text = "%d / %d" % [icm.player_hp, icm.player_max_hp]
	player_hp_bar.max_value = max(1, icm.player_max_hp)
	player_hp_bar.value = icm.player_hp

	# Hunt progress (just above primary target)
	hunt_progress_label.text = "Current Hunt (%d/%d)" % [icm.kills_this_hunt, icm.hunt_target]

	# Queue count
	queue_count_label.text = "Q:%d/%d" % [icm.monster_queue.size(), icm.MAX_QUEUE_SIZE]

	# Death state: show respawn timer
	if icm.is_dead:
		mob_name_label.text = "Respawning..."
		mob_name_label.modulate = Color(0.8, 0.2, 0.2)
		mob_hp_value.text = "%.1fs" % icm._death_timer
		mob_hp_bar.value = 0
		hunt_progress_label.text = "You died! Respawning in %.1fs" % icm._death_timer
		_refresh_queue_grid()
		_refresh_kill_tracker()
		return

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

	# Footer -- Monster kill achievement tracker
	_refresh_kill_tracker()

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

const KILL_TIERS := [100, 500, 1000, 2000, 5000]

func _refresh_kill_tracker() -> void:
	var ach_mgr = get_node_or_null("/root/AchievementManager")
	var creature = icm.current_creature
	var kills := 0
	if ach_mgr and creature != "":
		kills = ach_mgr.get_monster_kills(creature)

	# Find current tier
	var tier := 0
	var next_target := KILL_TIERS[0]
	for i in range(KILL_TIERS.size()):
		if kills >= KILL_TIERS[i]:
			tier = i + 1
			if i + 1 < KILL_TIERS.size():
				next_target = KILL_TIERS[i + 1]
			else:
				next_target = KILL_TIERS[KILL_TIERS.size() - 1]
		else:
			next_target = KILL_TIERS[i]
			break

	if tier >= KILL_TIERS.size():
		kill_tracker_label.text = "%s Kills: %d (MAX)" % [creature, kills]
	else:
		kill_tracker_label.text = "%s Kills: %d / %d  (Tier %d)" % [creature, kills, next_target, tier + 1]

# ─── Quality Filter Buttons ───

func _setup_filter_button(btn: Button, quality: String, color: Color) -> void:
	# Style: solid colored background, no text (except "All")
	if quality != "":
		btn.text = ""
		btn.custom_minimum_size = Vector2(30, 30)
	# Create a colored StyleBoxFlat for the button
	var style = StyleBoxFlat.new()
	style.bg_color = color
	style.set_corner_radius_all(4)
	style.content_margin_left = 4
	style.content_margin_right = 4
	style.content_margin_top = 2
	style.content_margin_bottom = 2
	btn.add_theme_stylebox_override("normal", style)
	# Slightly brighter for hover
	var hover_style = style.duplicate()
	hover_style.bg_color = color.lightened(0.2)
	btn.add_theme_stylebox_override("hover", hover_style)
	# Dimmer for pressed/disabled (active filter)
	var pressed_style = style.duplicate()
	pressed_style.bg_color = color.darkened(0.3)
	pressed_style.border_color = Color.WHITE
	pressed_style.set_border_width_all(2)
	btn.add_theme_stylebox_override("pressed", pressed_style)
	btn.add_theme_stylebox_override("disabled", pressed_style)
	btn.pressed.connect(_on_filter_pressed.bind(quality))

func _on_filter_pressed(quality: String) -> void:
	if bag_grid:
		bag_grid.quality_filter = quality
		bag_grid.refresh_grid()
		# Highlight matching items when a quality filter is active
		_apply_filter_highlights(quality)
	# Update visual state of filter buttons
	filter_all_btn.disabled = (quality == "")
	filter_normal_btn.disabled = (quality == "Normal")
	filter_tempered_btn.disabled = (quality == "Tempered")
	filter_infused_btn.disabled = (quality == "Infused")
	filter_brilliant_btn.disabled = (quality == "Brilliant")
	filter_radiant_btn.disabled = (quality == "Radiant")

func _apply_filter_highlights(quality: String) -> void:
	if not bag_grid:
		return
	for slot in bag_grid.get_children():
		if quality == "" or slot.item_data == null:
			# No filter or empty slot: reset to normal
			slot.modulate = Color(1.0, 1.0, 1.0, 1.0)
		elif slot.item_data.quality == quality:
			# Matching quality: highlight like select mode
			slot.modulate = Color(1.0, 1.0, 0.5, 1.0)
		else:
			# Non-matching: dim it
			slot.modulate = Color(0.5, 0.5, 0.5, 0.6)

# ─── Select / Sell Mode ───

func _on_select_pressed() -> void:
	_select_mode = true
	_selected_indices.clear()
	select_bag_btn.visible = false
	sell_bag_btn.visible = true
	sell_bag_btn.text = "Sell (0)"
	move_bag_btn.visible = true
	move_bag_btn.text = "Move (0)"
	cancel_bag_btn.visible = true
	_set_slots_select_mode(true)

func _on_cancel_select() -> void:
	_select_mode = false
	_selected_indices.clear()
	select_bag_btn.visible = true
	sell_bag_btn.visible = false
	move_bag_btn.visible = false
	cancel_bag_btn.visible = false
	_set_slots_select_mode(false)
	_clear_selection_highlights()

func _on_sell_pressed() -> void:
	if _selected_indices.is_empty():
		return

	var inv = GameManager.active_user_inventory
	var gold_earned := 0
	var echo_earned := 0
	var items_to_remove: Array = []

	# Process selected items (collect data first, remove after)
	for idx in _selected_indices:
		if idx >= inv.size():
			continue
		var entry = inv[idx]
		var item_data: ItemData = null
		if entry is Dictionary and entry.has("uid"):
			item_data = ItemDatabase.resolve_instance(entry)
		elif entry is ItemData:
			item_data = entry
		if item_data == null:
			continue

		if item_data.quality == "Normal":
			gold_earned += max(1, item_data.price)
		else:
			# Non-Normal quality: award Echo Points based on quality tier
			match item_data.quality:
				"Tempered": echo_earned += 1
				"Infused": echo_earned += 2
				"Brilliant": echo_earned += 3
				"Radiant": echo_earned += 4
				_: echo_earned += 1
		items_to_remove.append(idx)

	# Remove items from bag (reverse order to preserve indices)
	items_to_remove.sort()
	items_to_remove.reverse()
	for idx in items_to_remove:
		if idx < inv.size():
			inv.remove_at(idx)

	# Award currencies locally
	if gold_earned > 0:
		GameManager.active_user_currencies["GD"] = GameManager.active_user_currencies.get("GD", 0) + gold_earned
	if echo_earned > 0:
		GameManager.active_user_currencies["ET"] = GameManager.active_user_currencies.get("ET", 0) + echo_earned

	print("Sold %d items: +%d gold, +%d echo tokens" % [items_to_remove.size(), gold_earned, echo_earned])

	# Floating feedback for sell
	if gold_earned > 0:
		GlobalUI.show_floating_text("+%sg" % GameManager.format_gold(gold_earned), Color(1, 0.84, 0))
	if echo_earned > 0:
		GlobalUI.show_floating_text("+%d Echo" % echo_earned, Color(0.6, 0.4, 1.0))

	# Send sell request to PlayFab
	var sell_uids: Array = []
	for idx in _selected_indices:
		# We already removed them, but we stored indices before removal
		# Use the items_to_remove + entry data captured before
		pass
	# Simple approach: just sync inventory state
	GameManager.sync_inventory_to_server()

	# Exit select mode
	_on_cancel_select()
	GameManager.inventory_changed.emit()
	_refresh_inventory_ui()

func _on_move_pressed() -> void:
	if _selected_indices.is_empty():
		return

	var inv = GameManager.active_user_inventory
	# Warehouse is items at index 40+. Max 40 warehouse slots.
	var warehouse_count = max(0, inv.size() - 40)
	var warehouse_space = 40 - warehouse_count

	if warehouse_space <= 0:
		print("Warehouse is full (40/40)")
		return

	# Collect items to move (cap at available warehouse space)
	_selected_indices.sort()
	var moved := 0
	var indices_to_move: Array = []
	for idx in _selected_indices:
		if moved >= warehouse_space:
			break
		if idx >= inv.size() or idx >= 40:
			continue  # Only move bag items (0-39)
		indices_to_move.append(idx)
		moved += 1

	if indices_to_move.is_empty():
		return

	# Move items: null out bag slots (DON'T remove_at, which shifts warehouse items)
	var items_to_move: Array = []
	for idx in indices_to_move:
		items_to_move.append(inv[idx])
		inv[idx] = null  # Clear the bag slot, warehouse stays in place

	# Ensure inventory has at least 40 entries (bag region) before warehouse
	while inv.size() < 40:
		inv.append(null)
	# Append moved items to warehouse region (index 40+)
	for item in items_to_move:
		inv.append(item)

	print("Moved %d items to warehouse" % items_to_move.size())
	GameManager.sync_inventory_to_server()

	# Exit select mode
	_on_cancel_select()
	GameManager.inventory_changed.emit()
	_refresh_inventory_ui()

func _set_slots_select_mode(enabled: bool) -> void:
	if not bag_grid:
		return
	var all_slots = bag_grid.get_children()
	for i in range(all_slots.size()):
		var slot = all_slots[i]
		slot.select_mode = enabled
		slot.is_selected = false
		slot.modulate = Color(1.0, 1.0, 1.0, 1.0)
		# Connect slot_tapped if not already connected
		if enabled and not slot.slot_tapped.is_connected(_on_slot_tapped):
			slot.slot_tapped.connect(_on_slot_tapped)

func _clear_selection_highlights() -> void:
	if not bag_grid:
		return
	for slot in bag_grid.get_children():
		slot.is_selected = false
		slot.modulate = Color(1.0, 1.0, 1.0, 1.0)

func _on_slot_tapped(slot: PanelContainer) -> void:
	if not _select_mode:
		return
	var all_slots = bag_grid.get_children()
	var slot_index = all_slots.find(slot)
	if slot_index < 0:
		return

	if slot.item_data == null:
		return  # Can't select empty slots

	if _selected_indices.has(slot_index):
		_selected_indices.erase(slot_index)
		slot.is_selected = false
		slot.modulate = Color(1.0, 1.0, 1.0, 1.0)
	else:
		_selected_indices.append(slot_index)
		slot.is_selected = true
		slot.modulate = Color(1.0, 1.0, 0.5, 1.0)  # Yellow highlight

	sell_bag_btn.text = "Sell (%d)" % _selected_indices.size()
	move_bag_btn.text = "Move (%d)" % _selected_indices.size()

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
