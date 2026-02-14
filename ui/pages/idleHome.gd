extends Control

const AfkRewardsPopupScene = preload("res://ui/components/AfkRewardsPopup.tscn")
const WhatsNewPopupScene = preload("res://ui/components/WhatsNewPopup.tscn")

# Reference the actual nodes in your PageContainer (tabs handle own padding/scroll)
@onready var main_layout: VBoxContainer = $MainLayout
@onready var _page_margin: MarginContainer = $MainLayout/PageMargin
@onready var page_container = $MainLayout/PageMargin/PageContainer
@onready var hero_tab = $MainLayout/PageMargin/PageContainer/HeroTab
@onready var hunting_tab = $MainLayout/PageMargin/PageContainer/HuntingTab

# Shop tabs
@onready var armorer_tab = $MainLayout/PageMargin/PageContainer/ArmorerTab
@onready var weaponsmith_tab = $MainLayout/PageMargin/PageContainer/WeaponsmithTab
@onready var consumables_tab = $MainLayout/PageMargin/PageContainer/ConsumablesTab
@onready var artisan_tab = $MainLayout/PageMargin/PageContainer/ArtisanTab
@onready var auction_tab = $MainLayout/PageMargin/PageContainer/AuctionTab
@onready var lady_luck_tab = $MainLayout/PageMargin/PageContainer/LadyLuckTab

# Achievements tab
@onready var achievements_tab = $MainLayout/PageMargin/PageContainer/AchievementsTab

# Settings tab
@onready var settings_tab = $MainLayout/PageMargin/PageContainer/SettingsTab

# Shop popup
@onready var shop_popup: PanelContainer = $ShopPopup

func _ready() -> void:
	# ── Apply global visual theme ──
	_apply_game_theme()

	# ── Desktop responsive layout (deferred so viewport size is stable) ──
	call_deferred("_adapt_layout")
	ScreenHelper.viewport_mode_changed.connect(_on_viewport_mode_changed)
	get_tree().root.size_changed.connect(_on_window_resized)

	# Start with the Hero tab visible
	_show_tab(hero_tab)

	# Wire up navbar buttons
	$MainLayout/NavBar/NavButtons/Shop.pressed.connect(_on_shop_button_pressed)
	$MainLayout/NavBar/NavButtons/Achieve.pressed.connect(_on_achieve_button_pressed)
	$MainLayout/NavBar/NavButtons/Settings.pressed.connect(_on_settings_button_pressed)

	# Wire up shop popup buttons
	$ShopPopup/Margin/VBox/ArmorerBtn.pressed.connect(_on_shop_sub_tab.bind(armorer_tab))
	$ShopPopup/Margin/VBox/WeaponsmithBtn.pressed.connect(_on_shop_sub_tab.bind(weaponsmith_tab))
	$ShopPopup/Margin/VBox/ConsumablesBtn.pressed.connect(_on_shop_sub_tab.bind(consumables_tab))
	$ShopPopup/Margin/VBox/ArtisanBtn.pressed.connect(_on_shop_sub_tab.bind(artisan_tab))
	$ShopPopup/Margin/VBox/AuctionBtn.pressed.connect(_on_shop_sub_tab.bind(auction_tab))
	$ShopPopup/Margin/VBox/LadyLuckBtn.pressed.connect(_on_shop_sub_tab.bind(lady_luck_tab))

	# Listen for AFK rewards
	var icm = get_node_or_null("/root/IdleCombatManager")
	if icm:
		icm.afk_rewards_ready.connect(_show_afk_popup)

	# Changelog: show "What's New" popup if there are unseen entries
	if GameManager.has_unseen_changelog():
		call_deferred("_show_whats_new_popup")

	# Changelog: listen for live updates (from periodic poll)
	GameManager.changelog_updated.connect(_on_changelog_updated)

# ═══════════════════════════════════════════════════
#              DESKTOP RESPONSIVE LAYOUT
# ═══════════════════════════════════════════════════

func _on_viewport_mode_changed(_is_desktop: bool) -> void:
	_adapt_layout()

func _on_window_resized() -> void:
	_adapt_layout()

func _adapt_layout() -> void:
	# Add a small base margin so content doesn't touch the canvas edges,
	# then add extra margin on desktop to constrain to MAX_CONTENT_WIDTH.
	if not _page_margin:
		return

	var base_margin := 8  # small padding so text never clips the edge
	var vp_w = ScreenHelper._vp_width()
	var max_w = ScreenHelper.MAX_CONTENT_WIDTH

	if vp_w > max_w:
		var margin = int((vp_w - max_w) / 2.0)
		_page_margin.add_theme_constant_override("margin_left", margin)
		_page_margin.add_theme_constant_override("margin_right", margin)
	else:
		_page_margin.add_theme_constant_override("margin_left", base_margin)
		_page_margin.add_theme_constant_override("margin_right", base_margin)

# ═══════════════════════════════════════════════════
#                  GLOBAL THEME
# ═══════════════════════════════════════════════════

func _apply_game_theme() -> void:
	# Warm cream background for the entire game
	RenderingServer.set_default_clear_color(Color("#F5F0EB"))

	var s := ScreenHelper.get_ui_scale()
	var game_theme = Theme.new()

	# ── PanelContainer -> white cards with rounded corners + subtle shadow ──
	var card_style = StyleBoxFlat.new()
	card_style.bg_color = Color.WHITE
	card_style.set_corner_radius_all(int(12 * s))
	card_style.border_color = Color("#E8E3DE")
	card_style.set_border_width_all(1)
	card_style.shadow_color = Color(0, 0, 0, 0.04)
	card_style.shadow_size = int(3 * s)
	card_style.shadow_offset = Vector2(0, 1)
	game_theme.set_stylebox("panel", "PanelContainer", card_style)

	# ── Label -> dark text by default ──
	game_theme.set_color("font_color", "Label", Color("#2D2D2D"))
	game_theme.set_font_size("font_size", "Label", ScreenHelper.scaled_font(14))

	# ── Button -> subtle rounded default (individual scenes can override for primary) ──
	var btn_margin_h = int(12 * s)
	var btn_margin_v = int(8 * s)
	var btn_normal = StyleBoxFlat.new()
	btn_normal.bg_color = Color("#ECECEC")
	btn_normal.set_corner_radius_all(int(8 * s))
	btn_normal.content_margin_left = btn_margin_h
	btn_normal.content_margin_right = btn_margin_h
	btn_normal.content_margin_top = btn_margin_v
	btn_normal.content_margin_bottom = btn_margin_v
	game_theme.set_stylebox("normal", "Button", btn_normal)
	var btn_hover = btn_normal.duplicate()
	btn_hover.bg_color = Color("#E0E0E0")
	game_theme.set_stylebox("hover", "Button", btn_hover)
	var btn_pressed = btn_normal.duplicate()
	btn_pressed.bg_color = Color("#D4D4D4")
	game_theme.set_stylebox("pressed", "Button", btn_pressed)
	var btn_disabled = btn_normal.duplicate()
	btn_disabled.bg_color = Color("#F0F0F0")
	game_theme.set_stylebox("disabled", "Button", btn_disabled)
	game_theme.set_color("font_color", "Button", Color("#2D2D2D"))
	game_theme.set_color("font_hover_color", "Button", Color("#1A1A1A"))
	game_theme.set_color("font_pressed_color", "Button", Color("#1A1A1A"))
	game_theme.set_color("font_disabled_color", "Button", Color("#AAAAAA"))
	game_theme.set_font_size("font_size", "Button", ScreenHelper.scaled_font(14))

	# ── ProgressBar -> terracotta fill on cream background ──
	var pb_bg = StyleBoxFlat.new()
	pb_bg.bg_color = Color("#E8E3DE")
	pb_bg.set_corner_radius_all(4)
	pb_bg.content_margin_top = 0
	pb_bg.content_margin_bottom = 0
	game_theme.set_stylebox("background", "ProgressBar", pb_bg)
	var pb_fill = StyleBoxFlat.new()
	pb_fill.bg_color = Color("#C4593C")
	pb_fill.set_corner_radius_all(4)
	pb_fill.content_margin_top = 0
	pb_fill.content_margin_bottom = 0
	game_theme.set_stylebox("fill", "ProgressBar", pb_fill)

	# ── OptionButton -> rounded dropdown ──
	var opt_normal = StyleBoxFlat.new()
	opt_normal.bg_color = Color.WHITE
	opt_normal.set_corner_radius_all(int(8 * s))
	opt_normal.border_color = Color("#D0CBC6")
	opt_normal.set_border_width_all(1)
	opt_normal.content_margin_left = btn_margin_h
	opt_normal.content_margin_right = btn_margin_h
	opt_normal.content_margin_top = btn_margin_v
	opt_normal.content_margin_bottom = btn_margin_v
	game_theme.set_stylebox("normal", "OptionButton", opt_normal)
	var opt_hover = opt_normal.duplicate()
	opt_hover.bg_color = Color("#F8F5F2")
	game_theme.set_stylebox("hover", "OptionButton", opt_hover)
	game_theme.set_font_size("font_size", "OptionButton", ScreenHelper.scaled_font(14))

	# ── HSeparator ──
	var sep_style = StyleBoxFlat.new()
	sep_style.bg_color = Color("#E8E3DE")
	sep_style.content_margin_top = 0
	sep_style.content_margin_bottom = 0
	game_theme.set_stylebox("separator", "HSeparator", sep_style)
	game_theme.set_constant("separation", "HSeparator", int(8 * s))

	# ── LineEdit ──
	game_theme.set_font_size("font_size", "LineEdit", ScreenHelper.scaled_font(13))

	# Apply to root — all children inherit this theme
	self.theme = game_theme

	# ── Override NavBar to be a flat bar (no rounded corners, top border only) ──
	var nav_bar: PanelContainer = $MainLayout/NavBar
	var nav_pad = int(8 * s)
	var nav_style = StyleBoxFlat.new()
	nav_style.bg_color = Color.WHITE
	nav_style.border_color = Color("#E8E3DE")
	nav_style.border_width_top = 1
	nav_style.content_margin_top = int(6 * s)
	nav_style.content_margin_bottom = int(6 * s)
	nav_style.content_margin_left = nav_pad
	nav_style.content_margin_right = nav_pad
	nav_bar.add_theme_stylebox_override("panel", nav_style)
	# Scale navbar height and button font
	nav_bar.custom_minimum_size.y = ScreenHelper.scaled_min_height(56)
	var nav_font = ScreenHelper.scaled_font(12)
	# Nav buttons: tighter horizontal padding so all 5 fit on narrow mobile screens
	var nav_btn_normal = btn_normal.duplicate()
	nav_btn_normal.content_margin_left = int(4 * s)
	nav_btn_normal.content_margin_right = int(4 * s)
	nav_btn_normal.content_margin_top = int(10 * s)
	nav_btn_normal.content_margin_bottom = int(10 * s)
	var nav_btn_hover = nav_btn_normal.duplicate()
	nav_btn_hover.bg_color = Color("#E0E0E0")
	var nav_btn_pressed = nav_btn_normal.duplicate()
	nav_btn_pressed.bg_color = Color("#D4D4D4")
	for btn in $MainLayout/NavBar/NavButtons.get_children():
		if btn is Button:
			btn.add_theme_font_size_override("font_size", nav_font)
			btn.add_theme_stylebox_override("normal", nav_btn_normal)
			btn.add_theme_stylebox_override("hover", nav_btn_hover)
			btn.add_theme_stylebox_override("pressed", nav_btn_pressed)

	# ── Style ShopPopup with more prominent shadow ──
	var popup_style = card_style.duplicate()
	popup_style.shadow_size = int(8 * s)
	popup_style.shadow_color = Color(0, 0, 0, 0.12)
	shop_popup.add_theme_stylebox_override("panel", popup_style)

func _adapt_shop_popup() -> void:
	pass  # ShopPopup uses anchor-based positioning, works fine at any width

func _show_tab(target_tab: Control):
	# Hide popup when switching tabs
	shop_popup.visible = false

	# 1. Hide every child in the container
	for child in page_container.get_children():
		child.hide()

	# 2. Show the target page
	target_tab.show()

	# 3. If it's the Hero Tab, refresh the stats from PlayFab data
	if target_tab == hero_tab:
		hero_tab.update_hero_ui()

func _on_hero_button_pressed() -> void:
	_show_tab(hero_tab)

func _on_idle_button_pressed() -> void:
	_show_tab(hunting_tab)

func _on_shop_button_pressed() -> void:
	# Toggle the shop popup visibility
	shop_popup.visible = not shop_popup.visible

func _on_shop_sub_tab(tab: Control) -> void:
	_show_tab(tab)

func _on_achieve_button_pressed() -> void:
	_show_tab(achievements_tab)

func _on_settings_button_pressed() -> void:
	_show_tab(settings_tab)

func _show_afk_popup(rewards: Dictionary) -> void:
	if not GameManager.show_afk_summary:
		return  # User has disabled AFK summary in Settings
	var popup = AfkRewardsPopupScene.instantiate()
	add_child(popup)
	popup.show_rewards(rewards)

# ─── Changelog / What's New ───

func _show_whats_new_popup() -> void:
	var unseen = GameManager.get_unseen_changelog_entries()
	if unseen.is_empty():
		return
	var popup = WhatsNewPopupScene.instantiate()
	add_child(popup)
	popup.show_unseen_entries(unseen)

func _on_changelog_updated() -> void:
	# A new changelog version was detected while the player is playing
	_show_whats_new_popup()
