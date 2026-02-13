extends Control

signal reward_claimed

@onready var backdrop: ColorRect = $Backdrop
@onready var title_label: Label = $CenterContainer/Panel/Margin/VBox/TitleLabel
@onready var slot_center: CenterContainer = $CenterContainer/Panel/Margin/VBox/SlotCenter
@onready var reward_name_label: Label = $CenterContainer/Panel/Margin/VBox/RewardName
@onready var reward_desc: Label = $CenterContainer/Panel/Margin/VBox/RewardDesc
@onready var pet_bonus_label: Label = $CenterContainer/Panel/Margin/VBox/PetBonusLabel
@onready var claim_btn: Button = $CenterContainer/Panel/Margin/VBox/ClaimBtn

const InventorySlotScene = preload("res://ui/components/InventorySlot.tscn")
var _item_slot = null

func _ready() -> void:
	visible = false
	claim_btn.pressed.connect(_on_claim_pressed)
	# Backdrop does NOT dismiss — user must press Claim
	backdrop.mouse_filter = Control.MOUSE_FILTER_STOP

func show_reward(reward: Dictionary, lucky_pet) -> void:
	# Build a temporary ItemData so the InventorySlot can render it with quality effects
	var reward_id = reward.get("id", "")
	var reward_name = reward.get("name", "Unknown Reward")
	var quality = reward.get("quality", "Normal")

	# Create an inventory-style dict for ItemDatabase.resolve_instance
	var sockets = int(reward.get("sockets", 0))
	var skt_array: Array = []
	for i in range(sockets):
		skt_array.append(null)

	var instance = {
		"uid": "preview_%d" % randi(),
		"bid": reward_id,
		"q": quality,
		"plus": 0,
		"skt": skt_array,
		"ench": {},
		"dura": 0,
	}

	# For money bags, store the gold amount
	var gold_amount := 0
	if reward_id.begins_with("money_bag_"):
		const MONEY_BAG_GOLD: Dictionary = {
			"money_bag_1": 500,       "money_bag_2": 1500,
			"money_bag_3": 5000,      "money_bag_4": 15000,
			"money_bag_5": 50000,     "money_bag_6": 100000,
			"money_bag_7": 250000,    "money_bag_8": 500000,
			"money_bag_9": 1000000,   "money_bag_10": 5000000,
		}
		gold_amount = MONEY_BAG_GOLD.get(reward_id, 0)
		instance["gold"] = gold_amount

	# Resolve ItemData from catalog
	var item_data = ItemDatabase.resolve_instance(instance)

	# Clear any previous slot
	if _item_slot and is_instance_valid(_item_slot):
		_item_slot.queue_free()
		_item_slot = null

	# Instantiate an InventorySlot and add it
	_item_slot = InventorySlotScene.instantiate()
	slot_center.add_child(_item_slot)
	_item_slot.custom_minimum_size = Vector2(80, 80)
	if item_data:
		_item_slot.set_item(item_data)
	# Disable interaction on preview slot
	_item_slot.mouse_filter = Control.MOUSE_FILTER_IGNORE

	# Title
	title_label.text = "You Won!"
	title_label.add_theme_color_override("font_color", Color(1.0, 0.84, 0.0))

	# Reward name
	reward_name_label.text = reward_name

	# Description
	if reward_id.begins_with("money_bag_"):
		reward_desc.text = "%s gold bag — claim it!" % GameManager.format_gold(gold_amount)
		reward_name_label.add_theme_color_override("font_color", Color(1.0, 0.84, 0.0))
	elif reward.has("sockets") and int(reward.get("sockets", 0)) > 0:
		reward_desc.text = "%s quality with %d sockets!" % [quality, sockets]
		reward_name_label.add_theme_color_override("font_color", Color(0.6, 0.2, 0.8))
	elif quality != "Normal":
		reward_desc.text = "%s quality item!" % quality
		reward_name_label.add_theme_color_override("font_color", Color(0.8, 0.4, 1.0))
	elif reward_id.begins_with("ignis_") or reward_id.begins_with("comet_") or reward_id.begins_with("wyrm_"):
		reward_desc.text = "Upgrade material!"
		reward_name_label.add_theme_color_override("font_color", Color(0.4, 0.8, 1.0))
	else:
		reward_desc.text = "A rare item!"
		reward_name_label.add_theme_color_override("font_color", Color(0.8, 0.4, 1.0))

	# Pet bonus
	if lucky_pet != null and lucky_pet is String and lucky_pet != "":
		pet_bonus_label.visible = true
		pet_bonus_label.text = "BONUS: Lucky Pet '%s' obtained!" % lucky_pet
		pet_bonus_label.add_theme_color_override("font_color", Color(1.0, 0.4, 0.7))
	else:
		pet_bonus_label.visible = false

	visible = true

func _on_claim_pressed() -> void:
	visible = false
	reward_claimed.emit()
