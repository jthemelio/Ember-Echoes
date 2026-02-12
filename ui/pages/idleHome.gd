extends Node

const AfkRewardsPopupScene = preload("res://ui/components/AfkRewardsPopup.tscn")

# Reference the actual nodes in your PageContainer
@onready var page_container = $MainLayout/ContentArea/PageContainer
@onready var hero_tab = $MainLayout/ContentArea/PageContainer/HeroTab
@onready var hunting_tab = $MainLayout/ContentArea/PageContainer/HuntingTab

# Shop tabs
@onready var armorer_tab = $MainLayout/ContentArea/PageContainer/ArmorerTab
@onready var weaponsmith_tab = $MainLayout/ContentArea/PageContainer/WeaponsmithTab
@onready var consumables_tab = $MainLayout/ContentArea/PageContainer/ConsumablesTab
@onready var artisan_tab = $MainLayout/ContentArea/PageContainer/ArtisanTab
@onready var auction_tab = $MainLayout/ContentArea/PageContainer/AuctionTab
@onready var lady_luck_tab = $MainLayout/ContentArea/PageContainer/LadyLuckTab

# Achievements tab
@onready var achievements_tab = $MainLayout/ContentArea/PageContainer/AchievementsTab

# Shop popup
@onready var shop_popup: PanelContainer = $ShopPopup

func _ready() -> void:
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
	print("Settings tab pressed (not yet implemented)")

func _show_afk_popup(rewards: Dictionary) -> void:
	var popup = AfkRewardsPopupScene.instantiate()
	add_child(popup)
	popup.show_rewards(rewards)
