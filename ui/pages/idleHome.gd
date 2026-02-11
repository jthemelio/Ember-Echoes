extends Node

const AfkRewardsPopupScene = preload("res://ui/components/AfkRewardsPopup.tscn")

# Reference the actual nodes in your PageContainer
@onready var page_container = $MainLayout/ContentArea/PageContainer
@onready var hero_tab = $MainLayout/ContentArea/PageContainer/HeroTab
@onready var hunting_tab = $MainLayout/ContentArea/PageContainer/HuntingTab

func _ready() -> void:
	# Start with the Hero tab visible
	_show_tab(hero_tab)

	# Wire up navbar buttons that aren't connected via signals in the .tscn
	$MainLayout/NavBar/NavButtons/Shop.pressed.connect(_on_shop_button_pressed)
	$MainLayout/NavBar/NavButtons/Achieve.pressed.connect(_on_achieve_button_pressed)
	$MainLayout/NavBar/NavButtons/Settings.pressed.connect(_on_settings_button_pressed)

	# Listen for AFK rewards
	IdleCombatManager.afk_rewards_ready.connect(_show_afk_popup)

func _show_tab(target_tab: Control):
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
	print("Shop tab pressed (not yet implemented)")

func _on_achieve_button_pressed() -> void:
	print("Achievements tab pressed (not yet implemented)")

func _on_settings_button_pressed() -> void:
	print("Settings tab pressed (not yet implemented)")

func _show_afk_popup(rewards: Dictionary) -> void:
	var popup = AfkRewardsPopupScene.instantiate()
	add_child(popup)
	popup.show_rewards(rewards)
