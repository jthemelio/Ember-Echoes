# achievements.gd — Achievements page with Account/Character toggle.
# Sub-tabs: Hunt Kills (with 5-tier progression per monster), Pets (account-wide drops).
extends MarginContainer

# ─── Tab toggle (Account / Character) ───
@onready var account_btn: Button = $ScrollContent/ContentVBox/HeaderPanel/Margin/VBox/TabSwitcher/AccountBtn
@onready var character_btn: Button = $ScrollContent/ContentVBox/HeaderPanel/Margin/VBox/TabSwitcher/CharacterBtn

# ─── Sub-tab buttons (underneath header, inside the Account or Character section) ───
@onready var sub_tab_row: HBoxContainer = $ScrollContent/ContentVBox/SubTabPanel/Margin/SubTabRow
@onready var hunt_kills_btn: Button = $ScrollContent/ContentVBox/SubTabPanel/Margin/SubTabRow/HuntKillsBtn
@onready var pets_btn: Button = $ScrollContent/ContentVBox/SubTabPanel/Margin/SubTabRow/PetsBtn

# ─── Content area ───
@onready var content_panel: PanelContainer = $ScrollContent/ContentVBox/ContentPanel
@onready var content_vbox: VBoxContainer = $ScrollContent/ContentVBox/ContentPanel/Margin/ContentVBox

# State
var _current_scope: String = "account"   # "account" or "character"
var _current_sub_tab: String = "hunt_kills"

# Colors
const TIER_COMPLETE_COLOR := Color(0.4, 1.0, 0.4)    # Green
const TIER_CLAIMABLE_COLOR := Color(1.0, 0.84, 0.0)  # Gold
const TIER_LOCKED_COLOR := Color(0.5, 0.5, 0.5)      # Grey
const PET_OBTAINED_COLOR := Color(0.6, 0.4, 1.0)     # Purple
const PET_MISSING_COLOR := Color(0.35, 0.35, 0.35)    # Dark grey

func _ready():
	# Wire tab buttons
	account_btn.pressed.connect(_on_account_pressed)
	character_btn.pressed.connect(_on_character_pressed)
	hunt_kills_btn.pressed.connect(_on_hunt_kills_pressed)
	pets_btn.pressed.connect(_on_pets_pressed)

	# Listen for achievement updates
	var ach_mgr = get_node_or_null("/root/AchievementManager")
	if ach_mgr:
		ach_mgr.kill_achievement_updated.connect(_on_kill_updated)
		ach_mgr.pet_obtained.connect(_on_pet_obtained)

	# Default: Account -> Hunt Kills
	_current_scope = "account"
	_current_sub_tab = "hunt_kills"
	_update_tab_buttons()
	_refresh_content()

# ─── Tab Switching ───

func _on_account_pressed() -> void:
	_current_scope = "account"
	# Show Hunt Kills and Pets sub-tabs
	pets_btn.visible = true
	_update_tab_buttons()
	_refresh_content()

func _on_character_pressed() -> void:
	_current_scope = "character"
	# Character tab could have different sub-tabs in future; for now same
	pets_btn.visible = false
	_current_sub_tab = "hunt_kills"
	_update_tab_buttons()
	_refresh_content()

func _on_hunt_kills_pressed() -> void:
	_current_sub_tab = "hunt_kills"
	_update_tab_buttons()
	_refresh_content()

func _on_pets_pressed() -> void:
	_current_sub_tab = "pets"
	_update_tab_buttons()
	_refresh_content()

func _update_tab_buttons() -> void:
	# Highlight active scope button
	account_btn.disabled = (_current_scope == "account")
	character_btn.disabled = (_current_scope == "character")
	hunt_kills_btn.disabled = (_current_sub_tab == "hunt_kills")
	pets_btn.disabled = (_current_sub_tab == "pets")

# ─── Signal handlers ───

func _on_kill_updated(_monster_id: String, _kills: int) -> void:
	if _current_sub_tab == "hunt_kills":
		_refresh_content()

func _on_pet_obtained(_pet_name: String) -> void:
	if _current_sub_tab == "pets":
		_refresh_content()

# ─── Content Rendering ───

func _refresh_content() -> void:
	# Clear old content
	for child in content_vbox.get_children():
		child.queue_free()

	if _current_sub_tab == "hunt_kills":
		_build_hunt_kills_view()
	elif _current_sub_tab == "pets":
		_build_pets_view()

func _build_hunt_kills_view() -> void:
	var ach_mgr = get_node_or_null("/root/AchievementManager")
	if not ach_mgr:
		var err = Label.new()
		err.text = "Achievement system not available"
		content_vbox.add_child(err)
		return

	var all_monsters = ach_mgr.get_all_monsters()
	if all_monsters.is_empty():
		var empty_label = Label.new()
		empty_label.text = "No zone data loaded yet. Start hunting first!"
		empty_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		content_vbox.add_child(empty_label)
		return

	# Group monsters by zone
	var zones_dict: Dictionary = {}
	for mob in all_monsters:
		var zone_name = mob.get("zone", "Unknown")
		if not zones_dict.has(zone_name):
			zones_dict[zone_name] = []
		zones_dict[zone_name].append(mob)

	for zone_name in zones_dict:
		# Zone header
		var zone_header = Label.new()
		zone_header.text = zone_name
		zone_header.add_theme_font_size_override("font_size", ScreenHelper.scaled_font(18))
		zone_header.add_theme_color_override("font_color", Color(1.0, 0.84, 0.0))
		content_vbox.add_child(zone_header)

		# Separator
		var sep = HSeparator.new()
		content_vbox.add_child(sep)

		# Each monster in this zone
		for mob in zones_dict[zone_name]:
			var mob_name = mob.get("name", "?")
			_build_monster_entry(mob_name, ach_mgr)

		# Space between zones
		var spacer = Control.new()
		spacer.custom_minimum_size = Vector2(0, 12)
		content_vbox.add_child(spacer)

func _build_monster_entry(mob_name: String, ach_mgr: Node) -> void:
	var kills = ach_mgr.get_monster_kills(mob_name)
	var claimed = ach_mgr.get_claimed_tiers(mob_name)

	# Monster panel
	var panel = PanelContainer.new()
	panel.mouse_filter = Control.MOUSE_FILTER_PASS
	content_vbox.add_child(panel)

	var margin = MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 12)
	margin.add_theme_constant_override("margin_top", 8)
	margin.add_theme_constant_override("margin_right", 12)
	margin.add_theme_constant_override("margin_bottom", 8)
	panel.add_child(margin)

	var vbox = VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 6)
	margin.add_child(vbox)

	# Row 1: Monster name + total kills
	var header_row = HBoxContainer.new()
	vbox.add_child(header_row)

	var name_label = Label.new()
	name_label.text = mob_name
	name_label.add_theme_font_size_override("font_size", 16)
	name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header_row.add_child(name_label)

	var kills_label = Label.new()
	kills_label.text = "%d kills" % kills
	kills_label.add_theme_font_size_override("font_size", 14)
	kills_label.add_theme_color_override("font_color", Color(0.7, 0.7, 0.7))
	kills_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	header_row.add_child(kills_label)

	# Row 2: 5 tier boxes in a row
	var tier_row = HBoxContainer.new()
	tier_row.add_theme_constant_override("separation", 6)
	vbox.add_child(tier_row)

	for i in range(AchievementManager.KILL_TIERS.size()):
		var target = AchievementManager.KILL_TIERS[i]
		var is_complete = kills >= target
		var is_claimed = claimed.has(i)
		var is_claimable = is_complete and not is_claimed

		var tier_vbox = VBoxContainer.new()
		tier_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		tier_vbox.add_theme_constant_override("separation", 2)
		tier_row.add_child(tier_vbox)

		# Tier target label
		var tier_label = Label.new()
		tier_label.text = "%d" % target
		tier_label.add_theme_font_size_override("font_size", 11)
		tier_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		if is_claimed:
			tier_label.add_theme_color_override("font_color", TIER_COMPLETE_COLOR)
		elif is_claimable:
			tier_label.add_theme_color_override("font_color", TIER_CLAIMABLE_COLOR)
		else:
			tier_label.add_theme_color_override("font_color", TIER_LOCKED_COLOR)
		tier_vbox.add_child(tier_label)

		# Progress bar for this tier
		var progress = ProgressBar.new()
		progress.custom_minimum_size = Vector2(0, 6)
		progress.max_value = target
		progress.value = min(kills, target)
		progress.show_percentage = false
		progress.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		tier_vbox.add_child(progress)

		# Reward label (what this tier grants)
		var reward_name = AchievementManager.TIER_REWARD_NAMES[i] if i < AchievementManager.TIER_REWARD_NAMES.size() else "Wyrm Sphere"
		var reward_lbl = Label.new()
		reward_lbl.text = reward_name
		reward_lbl.add_theme_font_size_override("font_size", 9)
		reward_lbl.add_theme_color_override("font_color", Color(0.5, 0.7, 0.9))
		reward_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		tier_vbox.add_child(reward_lbl)

		# Claim button or status
		if is_claimable:
			var claim_btn = Button.new()
			claim_btn.text = "Claim"
			claim_btn.custom_minimum_size = Vector2(0, 28)
			claim_btn.add_theme_font_size_override("font_size", 11)
			claim_btn.pressed.connect(_on_claim_pressed.bind(mob_name, i))
			tier_vbox.add_child(claim_btn)
		elif is_claimed:
			var done_label = Label.new()
			done_label.text = "Claimed"
			done_label.add_theme_font_size_override("font_size", 10)
			done_label.add_theme_color_override("font_color", TIER_COMPLETE_COLOR)
			done_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			tier_vbox.add_child(done_label)
		elif _is_current_tier(kills, i):
			# Only show "xx left" for the tier currently in progress
			var remaining = target - kills
			var rem_label = Label.new()
			rem_label.text = "%d left" % remaining
			rem_label.add_theme_font_size_override("font_size", 10)
			rem_label.add_theme_color_override("font_color", TIER_LOCKED_COLOR)
			rem_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			tier_vbox.add_child(rem_label)

func _is_current_tier(kills: int, tier_index: int) -> bool:
	## Returns true if this tier is the one currently being worked towards
	if tier_index == 0:
		return kills < AchievementManager.KILL_TIERS[0]
	# Current tier = first tier where kills < target AND kills >= previous target
	return kills >= AchievementManager.KILL_TIERS[tier_index - 1] and kills < AchievementManager.KILL_TIERS[tier_index]

func _on_claim_pressed(monster_name: String, tier_index: int) -> void:
	var ach_mgr = get_node_or_null("/root/AchievementManager")
	if ach_mgr:
		ach_mgr.claim_tier(monster_name, tier_index)
		_refresh_content()

func _build_pets_view() -> void:
	var ach_mgr = get_node_or_null("/root/AchievementManager")
	if not ach_mgr:
		return

	# Title
	var title = Label.new()
	title.text = "Pet Collection"
	title.add_theme_font_size_override("font_size", 18)
	content_vbox.add_child(title)

	var desc = Label.new()
	desc.text = "Rare pets can drop from any monster you hunt. Drop rate: 1 in 4,000 kills."
	desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	desc.add_theme_font_size_override("font_size", 13)
	desc.add_theme_color_override("font_color", Color(0.7, 0.7, 0.7))
	content_vbox.add_child(desc)

	var spacer = Control.new()
	spacer.custom_minimum_size = Vector2(0, 8)
	content_vbox.add_child(spacer)

	# Grid of all possible pets
	var pet_grid = GridContainer.new()
	pet_grid.columns = ScreenHelper.grid_columns(3, 4)
	pet_grid.add_theme_constant_override("h_separation", 8)
	pet_grid.add_theme_constant_override("v_separation", 8)
	pet_grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	content_vbox.add_child(pet_grid)

	var all_monsters = ach_mgr.get_all_monsters()
	for mob in all_monsters:
		var mob_name = mob.get("name", "?")
		var pet_name = "Baby " + mob_name
		var obtained = ach_mgr.pets_obtained.has(pet_name)

		var pet_panel = PanelContainer.new()
		pet_panel.mouse_filter = Control.MOUSE_FILTER_PASS
		pet_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		pet_grid.add_child(pet_panel)

		var pet_margin = MarginContainer.new()
		pet_margin.add_theme_constant_override("margin_left", 6)
		pet_margin.add_theme_constant_override("margin_top", 6)
		pet_margin.add_theme_constant_override("margin_right", 6)
		pet_margin.add_theme_constant_override("margin_bottom", 6)
		pet_panel.add_child(pet_margin)

		var pet_vbox = VBoxContainer.new()
		pet_vbox.add_theme_constant_override("separation", 2)
		pet_margin.add_child(pet_vbox)

		var pet_label = Label.new()
		pet_label.text = pet_name
		pet_label.add_theme_font_size_override("font_size", 12)
		pet_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		pet_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		if obtained:
			pet_label.add_theme_color_override("font_color", PET_OBTAINED_COLOR)
		else:
			pet_label.add_theme_color_override("font_color", PET_MISSING_COLOR)
		pet_vbox.add_child(pet_label)

		var status_label = Label.new()
		if obtained:
			status_label.text = "Obtained!"
			status_label.add_theme_color_override("font_color", PET_OBTAINED_COLOR)
		else:
			# Show kills for this monster
			var kc = ach_mgr.get_monster_kills(mob_name)
			status_label.text = "%d kills" % kc
			status_label.add_theme_color_override("font_color", PET_MISSING_COLOR)
		status_label.add_theme_font_size_override("font_size", 10)
		status_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		pet_vbox.add_child(status_label)
