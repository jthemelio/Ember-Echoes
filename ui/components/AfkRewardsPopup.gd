# AfkRewardsPopup.gd — "Welcome Back!" popup shown after AFK period
# Displays offline rewards: kills, XP, gold, loot items.
extends PanelContainer

@onready var title_label: Label = $Margin/VBox/TitleLabel
@onready var time_label: Label = $Margin/VBox/TimeLabel
@onready var kills_label: Label = $Margin/VBox/KillsLabel
@onready var xp_label: Label = $Margin/VBox/XPLabel
@onready var gold_label: Label = $Margin/VBox/GoldLabel
@onready var loot_label: Label = $Margin/VBox/LootLabel
@onready var claim_btn: Button = $Margin/VBox/ClaimBtn

var _rewards: Dictionary = {}

func _ready() -> void:
	claim_btn.pressed.connect(_on_claim_pressed)

func show_rewards(rewards: Dictionary) -> void:
	_rewards = rewards
	var elapsed = rewards.get("elapsed_seconds", 0)
	var hours = elapsed / 3600
	var minutes = (elapsed % 3600) / 60
	var seconds = elapsed % 60

	title_label.text = "Welcome Back!"

	if hours > 0:
		time_label.text = "You were away for %dh %dm %ds" % [hours, minutes, seconds]
	elif minutes > 0:
		time_label.text = "You were away for %dm %ds" % [minutes, seconds]
	else:
		time_label.text = "You were away for %ds" % seconds

	var total_kills = rewards.get("total_kills", 0)
	var rare_kills = rewards.get("rare_kills", 0)
	if rare_kills > 0:
		kills_label.text = "Monsters slain: %d (%d rare)" % [total_kills, rare_kills]
	else:
		kills_label.text = "Monsters slain: %d" % total_kills

	xp_label.text = "XP earned: %d" % rewards.get("total_xp", 0)
	gold_label.text = "Gold earned: %s" % GameManager.format_gold(int(rewards.get("total_gold", 0)))

	var loot_items = rewards.get("loot_items", [])
	if loot_items.size() > 0:
		loot_label.text = "Items found: %d" % loot_items.size()
	else:
		loot_label.text = "No items found"

	visible = true

func _on_claim_pressed() -> void:
	visible = false
	queue_free()
