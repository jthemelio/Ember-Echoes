# settings.gd — Settings tab with Account, Appearance, and Changelog sections.
# Builds UI programmatically for full styling control matching the warm-card design.
extends MarginContainer

# ── Style constants (warm cream / terracotta palette) ──
const CARD_BG := Color("#FFFFFF")
const CARD_BORDER := Color("#E8E3DE")
const CARD_RADIUS := 12
const PRIMARY_COLOR := Color("#C4593C")
const PRIMARY_HOVER := Color("#A84830")
const PRIMARY_PRESSED := Color("#8E3D28")
const TEXT_COLOR := Color("#2D2D2D")
const SUBTITLE_COLOR := Color("#8E8E8E")
const SECTION_TITLE_SIZE := 18
const BODY_SIZE := 14

# ── Node references (set during _build_ui) ──
var _afk_toggle: CheckButton
var _changelog_container: VBoxContainer
var _changelog_vbox: VBoxContainer
var _logged_in_label: Label

# ── Sprite preview ──
var _sprite_rect: TextureRect
var _sprite_atlas: AtlasTexture
var _sprite_frame: int = 0
var _sprite_timer: Timer
var _sprite_frame_count: int = 4  # walk frames in top row

func _ready() -> void:
	add_theme_constant_override("margin_left", 16)
	add_theme_constant_override("margin_right", 16)
	add_theme_constant_override("margin_top", 12)
	add_theme_constant_override("margin_bottom", 12)
	size_flags_horizontal = Control.SIZE_EXPAND_FILL
	size_flags_vertical = Control.SIZE_EXPAND_FILL
	_build_ui()
	GameManager.changelog_updated.connect(_rebuild_changelog)

# ═══════════════════════════════════════════════════
#                    UI BUILDERS
# ═══════════════════════════════════════════════════

func _build_ui() -> void:
	var scroll = ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_SHOW_NEVER
	scroll.scroll_vertical_custom_step = 40
	add_child(scroll)

	var content = VBoxContainer.new()
	content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	content.add_theme_constant_override("separation", 16)
	scroll.add_child(content)

	_add_header(content)
	_add_account_card(content)
	_add_appearance_card(content)
	_add_updates_card(content)
	_add_debug_card(content)  # DEBUG: Remove before release
	_add_sprite_preview_card(content)  # DEBUG: Sprite sheet preview

	# ── Changelog (hidden until "View Changelog" is pressed) ──
	_changelog_container = VBoxContainer.new()
	_changelog_container.visible = false
	_changelog_container.add_theme_constant_override("separation", 4)
	content.add_child(_changelog_container)

	var cl_card = _make_card()
	_changelog_container.add_child(cl_card)

	var cl_inner = VBoxContainer.new()
	cl_inner.add_theme_constant_override("separation", 2)
	cl_card.add_child(cl_inner)

	var cl_title = _make_section_title("Change Log")
	cl_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	cl_inner.add_child(cl_title)

	_changelog_vbox = VBoxContainer.new()
	_changelog_vbox.add_theme_constant_override("separation", 2)
	cl_inner.add_child(_changelog_vbox)
	_rebuild_changelog()

func _add_header(parent: VBoxContainer) -> void:
	var header_vbox = VBoxContainer.new()
	header_vbox.add_theme_constant_override("separation", 2)
	parent.add_child(header_vbox)

	var title = Label.new()
	title.text = "Settings"
	title.add_theme_font_size_override("font_size", 24)
	title.add_theme_color_override("font_color", TEXT_COLOR)
	header_vbox.add_child(title)

	var subtitle = Label.new()
	subtitle.text = "Manage your game and account settings."
	subtitle.add_theme_font_size_override("font_size", 13)
	subtitle.add_theme_color_override("font_color", SUBTITLE_COLOR)
	header_vbox.add_child(subtitle)

func _add_account_card(parent: VBoxContainer) -> void:
	var card = _make_card()
	parent.add_child(card)

	var vbox = VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 10)
	card.add_child(vbox)

	vbox.add_child(_make_section_title("Account"))

	var change_btn = Button.new()
	change_btn.text = "Change Character"
	change_btn.custom_minimum_size = Vector2(0, 44)
	_style_primary_btn(change_btn)
	change_btn.pressed.connect(_on_change_character)
	vbox.add_child(change_btn)

	var logout_btn = Button.new()
	logout_btn.text = "Logout"
	logout_btn.custom_minimum_size = Vector2(0, 40)
	_style_secondary_btn(logout_btn)
	logout_btn.pressed.connect(_on_logout)
	vbox.add_child(logout_btn)

	_logged_in_label = Label.new()
	_logged_in_label.text = "Logged in as %s" % GameManager.active_character_name
	_logged_in_label.add_theme_font_size_override("font_size", 12)
	_logged_in_label.add_theme_color_override("font_color", SUBTITLE_COLOR)
	_logged_in_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(_logged_in_label)

func _add_appearance_card(parent: VBoxContainer) -> void:
	var card = _make_card()
	parent.add_child(card)

	var vbox = VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 14)
	card.add_child(vbox)

	vbox.add_child(_make_section_title("Appearance"))

	# ── Dark/Light Mode Row ──
	var dark_row = HBoxContainer.new()
	dark_row.add_theme_constant_override("separation", 8)
	vbox.add_child(dark_row)

	var dark_label = Label.new()
	dark_label.text = "Toggle light and dark mode."
	dark_label.add_theme_font_size_override("font_size", BODY_SIZE)
	dark_label.add_theme_color_override("font_color", TEXT_COLOR)
	dark_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	dark_row.add_child(dark_label)

	var dark_btn = Button.new()
	dark_btn.text = "☀"
	dark_btn.custom_minimum_size = Vector2(42, 42)
	_style_icon_btn(dark_btn)
	dark_btn.pressed.connect(func(): print("Dark mode toggle — coming soon!"))
	dark_row.add_child(dark_btn)

	# ── AFK Summary Row ──
	var afk_row = HBoxContainer.new()
	afk_row.add_theme_constant_override("separation", 8)
	vbox.add_child(afk_row)

	var afk_labels = VBoxContainer.new()
	afk_labels.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	afk_labels.add_theme_constant_override("separation", 2)
	afk_row.add_child(afk_labels)

	var afk_title = Label.new()
	afk_title.text = "Show AFK Summary"
	afk_title.add_theme_font_size_override("font_size", BODY_SIZE)
	afk_title.add_theme_color_override("font_color", TEXT_COLOR)
	afk_labels.add_child(afk_title)

	var afk_desc = Label.new()
	afk_desc.text = "Display gains when returning to the game."
	afk_desc.add_theme_font_size_override("font_size", 11)
	afk_desc.add_theme_color_override("font_color", SUBTITLE_COLOR)
	afk_desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	afk_labels.add_child(afk_desc)

	_afk_toggle = CheckButton.new()
	_afk_toggle.button_pressed = GameManager.show_afk_summary
	_afk_toggle.toggled.connect(_on_afk_toggled)
	afk_row.add_child(_afk_toggle)

func _add_updates_card(parent: VBoxContainer) -> void:
	var card = _make_card()
	parent.add_child(card)

	var vbox = VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 10)
	card.add_child(vbox)

	vbox.add_child(_make_section_title("Game Updates"))

	var desc = Label.new()
	desc.text = "View a history of all game updates and changes."
	desc.add_theme_font_size_override("font_size", BODY_SIZE)
	desc.add_theme_color_override("font_color", SUBTITLE_COLOR)
	desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	vbox.add_child(desc)

	var view_btn = Button.new()
	view_btn.text = "View Changelog"
	view_btn.custom_minimum_size = Vector2(0, 40)
	_style_secondary_btn(view_btn)
	view_btn.pressed.connect(_on_view_changelog)
	vbox.add_child(view_btn)

# ═══════════════════════════════════════════════════
#          DEBUG — Remove before release
# ═══════════════════════════════════════════════════

func _add_debug_card(parent: VBoxContainer) -> void:
	var card = _make_card()
	parent.add_child(card)

	var vbox = VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 10)
	card.add_child(vbox)

	vbox.add_child(_make_section_title("Debug / Testing"))

	var comet_btn = Button.new()
	comet_btn.text = "Test Comet Effect"
	comet_btn.custom_minimum_size = Vector2(0, 40)
	_style_secondary_btn(comet_btn)
	comet_btn.pressed.connect(func(): GlobalUI.show_comet_effect("Comet"))
	vbox.add_child(comet_btn)

	var wyrm_btn = Button.new()
	wyrm_btn.text = "Test Wyrm Sphere Effect"
	wyrm_btn.custom_minimum_size = Vector2(0, 40)
	_style_secondary_btn(wyrm_btn)
	wyrm_btn.pressed.connect(func(): GlobalUI.show_comet_effect("Wyrm Sphere", true))
	vbox.add_child(wyrm_btn)

func _add_sprite_preview_card(parent: VBoxContainer) -> void:
	var card = _make_card()
	parent.add_child(card)

	var vbox = VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 10)
	card.add_child(vbox)

	vbox.add_child(_make_section_title("Sprite Preview"))

	var desc = Label.new()
	desc.text = "Peacock walk cycle (4 frames from sprite sheet)"
	desc.add_theme_font_size_override("font_size", 12)
	desc.add_theme_color_override("font_color", SUBTITLE_COLOR)
	vbox.add_child(desc)

	# Load the sprite sheet texture
	var sheet_tex = load("res://assets/mobs/peacock_sheet.png") as Texture2D
	if sheet_tex == null:
		var err_lbl = Label.new()
		err_lbl.text = "Could not load peacock_sheet.png"
		err_lbl.add_theme_color_override("font_color", Color.RED)
		vbox.add_child(err_lbl)
		return

	# Calculate frame size: 4 columns, 2 rows
	var sheet_w = sheet_tex.get_width()
	var sheet_h = sheet_tex.get_height()
	var frame_w = sheet_w / 4.0
	var frame_h = sheet_h / 2.0

	# Create AtlasTexture for frame slicing
	_sprite_atlas = AtlasTexture.new()
	_sprite_atlas.atlas = sheet_tex
	_sprite_atlas.region = Rect2(0, 0, frame_w, frame_h)

	# Center the sprite in a box with a dark background
	var bg_panel = PanelContainer.new()
	var bg_style = StyleBoxFlat.new()
	bg_style.bg_color = Color(0.12, 0.12, 0.14)
	bg_style.set_corner_radius_all(8)
	bg_style.content_margin_left = 16
	bg_style.content_margin_right = 16
	bg_style.content_margin_top = 16
	bg_style.content_margin_bottom = 16
	bg_panel.add_theme_stylebox_override("panel", bg_style)
	vbox.add_child(bg_panel)

	var center = CenterContainer.new()
	bg_panel.add_child(center)

	_sprite_rect = TextureRect.new()
	_sprite_rect.texture = _sprite_atlas
	_sprite_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_sprite_rect.custom_minimum_size = Vector2(128, 128)
	_sprite_rect.expand_mode = TextureRect.EXPAND_FIT_WIDTH_PROPORTIONAL
	center.add_child(_sprite_rect)

	# Animation timer — cycle walk frames at 6 FPS
	_sprite_timer = Timer.new()
	_sprite_timer.wait_time = 1.0 / 6.0
	_sprite_timer.one_shot = false
	_sprite_timer.timeout.connect(_on_sprite_timer)
	add_child(_sprite_timer)
	_sprite_timer.start()

func _on_sprite_timer() -> void:
	if _sprite_atlas == null:
		return
	_sprite_frame = (_sprite_frame + 1) % _sprite_frame_count
	var frame_w = _sprite_atlas.atlas.get_width() / 4.0
	var frame_h = _sprite_atlas.atlas.get_height() / 2.0
	_sprite_atlas.region = Rect2(_sprite_frame * frame_w, 0, frame_w, frame_h)

# ═══════════════════════════════════════════════════
#               CARD / STYLE HELPERS
# ═══════════════════════════════════════════════════

func _make_card() -> PanelContainer:
	var card = PanelContainer.new()
	card.mouse_filter = Control.MOUSE_FILTER_PASS
	var style = StyleBoxFlat.new()
	style.bg_color = CARD_BG
	style.set_corner_radius_all(CARD_RADIUS)
	style.content_margin_left = 16
	style.content_margin_right = 16
	style.content_margin_top = 16
	style.content_margin_bottom = 16
	style.border_color = CARD_BORDER
	style.set_border_width_all(1)
	style.shadow_color = Color(0, 0, 0, 0.05)
	style.shadow_size = 4
	style.shadow_offset = Vector2(0, 2)
	card.add_theme_stylebox_override("panel", style)
	return card

func _make_section_title(text: String) -> Label:
	var lbl = Label.new()
	lbl.text = text
	lbl.add_theme_font_size_override("font_size", SECTION_TITLE_SIZE)
	lbl.add_theme_color_override("font_color", TEXT_COLOR)
	return lbl

func _style_primary_btn(btn: Button) -> void:
	var normal = StyleBoxFlat.new()
	normal.bg_color = PRIMARY_COLOR
	normal.set_corner_radius_all(8)
	normal.content_margin_left = 16
	normal.content_margin_right = 16
	normal.content_margin_top = 10
	normal.content_margin_bottom = 10
	btn.add_theme_stylebox_override("normal", normal)
	var hover = normal.duplicate()
	hover.bg_color = PRIMARY_HOVER
	btn.add_theme_stylebox_override("hover", hover)
	var pressed = normal.duplicate()
	pressed.bg_color = PRIMARY_PRESSED
	btn.add_theme_stylebox_override("pressed", pressed)
	btn.add_theme_color_override("font_color", Color.WHITE)
	btn.add_theme_color_override("font_hover_color", Color.WHITE)
	btn.add_theme_color_override("font_pressed_color", Color.WHITE)

func _style_secondary_btn(btn: Button) -> void:
	var normal = StyleBoxFlat.new()
	normal.bg_color = Color.WHITE
	normal.set_corner_radius_all(8)
	normal.content_margin_left = 16
	normal.content_margin_right = 16
	normal.content_margin_top = 10
	normal.content_margin_bottom = 10
	normal.border_color = Color("#D0CBC6")
	normal.set_border_width_all(1)
	btn.add_theme_stylebox_override("normal", normal)
	var hover = normal.duplicate()
	hover.bg_color = Color("#F8F5F2")
	btn.add_theme_stylebox_override("hover", hover)
	var pressed = normal.duplicate()
	pressed.bg_color = Color("#EEEBE8")
	btn.add_theme_stylebox_override("pressed", pressed)
	btn.add_theme_color_override("font_color", TEXT_COLOR)
	btn.add_theme_color_override("font_hover_color", TEXT_COLOR)
	btn.add_theme_color_override("font_pressed_color", TEXT_COLOR)

func _style_icon_btn(btn: Button) -> void:
	var normal = StyleBoxFlat.new()
	normal.bg_color = Color("#F5F0EB")
	normal.set_corner_radius_all(20)
	normal.content_margin_left = 8
	normal.content_margin_right = 8
	normal.content_margin_top = 8
	normal.content_margin_bottom = 8
	normal.border_color = Color("#E8E3DE")
	normal.set_border_width_all(1)
	btn.add_theme_stylebox_override("normal", normal)
	var hover = normal.duplicate()
	hover.bg_color = Color("#ECE7E2")
	btn.add_theme_stylebox_override("hover", hover)
	btn.add_theme_color_override("font_color", TEXT_COLOR)

# ═══════════════════════════════════════════════════
#               CHANGELOG DISPLAY
# ═══════════════════════════════════════════════════

const VERSION_COLOR := Color(0.4, 0.8, 1.0)
const TITLE_COLOR := Color(1.0, 0.9, 0.4)

func _rebuild_changelog() -> void:
	if _changelog_vbox == null:
		return
	for child in _changelog_vbox.get_children():
		child.queue_free()

	var entries = GameManager.changelog_entries
	if entries.is_empty():
		var empty = Label.new()
		empty.text = "No changelog entries yet."
		empty.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		empty.add_theme_color_override("font_color", SUBTITLE_COLOR)
		_changelog_vbox.add_child(empty)
		return

	for entry in entries:
		_add_changelog_entry(entry)

func _add_changelog_entry(entry: Dictionary) -> void:
	var version = entry.get("v", "?")
	var date = entry.get("date", "")
	var title = entry.get("title", "Update")
	var changes = entry.get("changes", [])

	var sep = HSeparator.new()
	sep.add_theme_constant_override("separation", 8)
	_changelog_vbox.add_child(sep)

	var header = Label.new()
	header.text = "v%s  —  %s" % [version, date]
	header.add_theme_color_override("font_color", VERSION_COLOR)
	header.add_theme_font_size_override("font_size", 14)
	_changelog_vbox.add_child(header)

	var title_lbl = Label.new()
	title_lbl.text = title
	title_lbl.add_theme_color_override("font_color", TITLE_COLOR)
	title_lbl.add_theme_font_size_override("font_size", 16)
	_changelog_vbox.add_child(title_lbl)

	var spacer = Control.new()
	spacer.custom_minimum_size = Vector2(0, 4)
	_changelog_vbox.add_child(spacer)

	for change_text in changes:
		var bullet = Label.new()
		bullet.text = "  •  %s" % change_text
		bullet.add_theme_font_size_override("font_size", 13)
		bullet.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		_changelog_vbox.add_child(bullet)

# ═══════════════════════════════════════════════════
#               BUTTON HANDLERS
# ═══════════════════════════════════════════════════

func _on_change_character() -> void:
	var icm = get_node_or_null("/root/IdleCombatManager")
	if icm:
		icm.stop_combat()
	GameManager.sync_inventory_to_server()
	# Force-save any dirty achievement data before switching
	var ach_mgr = get_node_or_null("/root/AchievementManager")
	if ach_mgr:
		ach_mgr.force_save()
	get_tree().change_scene_to_file("res://ui/character_creation/character_selection.tscn")

func _on_logout() -> void:
	var icm = get_node_or_null("/root/IdleCombatManager")
	if icm:
		icm.stop_combat()
	# Force-save any dirty achievement data before logging out
	var ach_mgr = get_node_or_null("/root/AchievementManager")
	if ach_mgr:
		ach_mgr.force_save()
	PlayFabManager.forget_login()
	get_tree().change_scene_to_file("res://ui/login/entry_page.tscn")

func _on_afk_toggled(enabled: bool) -> void:
	GameManager.show_afk_summary = enabled

func _on_view_changelog() -> void:
	if _changelog_container:
		_changelog_container.visible = not _changelog_container.visible
