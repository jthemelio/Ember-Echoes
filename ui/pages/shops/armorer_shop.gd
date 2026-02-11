# armorer_shop.gd — Displays Normal quality armor filtered by player class
# Headgear, Body Armor, Boots, Rings, Necklaces
extends VBoxContainer

@onready var gold_label: Label = $ScrollContainer/ContentVBox/ShopHeader/Margin/VBox/GoldRow/GoldValue
@onready var item_grid: GridContainer = $ScrollContainer/ContentVBox/ShopHeader/Margin/VBox/ItemGrid

# Class-specific body armor types
const ARMOR_BODY: Dictionary = {
	"Marksman": "Coat", "Twin-Soul": "Armor", "Wuxia": "Vestment",
	"Juggernaut": "Armor", "Spiritmender": "Vestment", "Emberlord": "Vestment"
}

# Class-specific headgear types
const ARMOR_HEAD: Dictionary = {
	"Marksman": "Hat", "Twin-Soul": "Crown", "Wuxia": "Hat",
	"Juggernaut": "Helmet", "Spiritmender": "Hat", "Emberlord": "Hat"
}

# Universal armor types (all classes can use)
const UNIVERSAL_TYPES: Array = ["Boots", "Ring", "Necklace"]

var _shop_items: Array = []

func _ready() -> void:
	_refresh_gold()
	_populate_shop()

func _refresh_gold() -> void:
	var gold = GameManager.active_user_currencies.get("GD", 0)
	gold_label.text = str(gold)

func _populate_shop() -> void:
	# Clear existing items
	for child in item_grid.get_children():
		child.queue_free()
	_shop_items.clear()

	var loot_mgr = get_node_or_null("/root/LootManager")
	if not loot_mgr:
		return

	var player_class = GameManager.active_character_class
	var body_type = ARMOR_BODY.get(player_class, "Armor")
	var head_type = ARMOR_HEAD.get(player_class, "Hat")
	var allowed_types = [body_type, head_type] + UNIVERSAL_TYPES

	# Filter catalog: Normal quality, matching armor types
	for item in loot_mgr._all_items:
		var cd = item.get("CustomData", {})
		var quality = cd.get("Quality", "")
		var item_type = cd.get("Type", "")

		if quality != "Normal":
			continue
		if item_type not in allowed_types:
			continue

		# For class-specific armor, check ItemClass matches
		if item_type == body_type or item_type == head_type:
			var item_class = item.get("ItemClass", "")
			if item_class != player_class and item_class != "" and item_class != "Jewelry" and item_class != "Boots":
				if not (player_class == "Wuxia" and item_class == "Wuxie"):
					continue

		_shop_items.append(item)

	# Sort by level requirement
	_shop_items.sort_custom(func(a, b):
		var a_lvl = int(a.get("CustomData", {}).get("LevelReq", 0))
		var b_lvl = int(b.get("CustomData", {}).get("LevelReq", 0))
		return a_lvl < b_lvl
	)

	# Create grid entries
	for item in _shop_items:
		_create_shop_slot(item)

func _create_shop_slot(item: Dictionary) -> void:
	var cd = item.get("CustomData", {})
	var display_name = item.get("DisplayName", "Unknown")
	var item_type = cd.get("Type", "")
	var level_req = int(cd.get("LevelReq", 0))
	var price = int(cd.get("Price", 0))
	var item_id = item.get("ItemId", "")

	var slot = VBoxContainer.new()
	slot.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	slot.add_theme_constant_override("separation", 2)

	var btn = Button.new()
	btn.custom_minimum_size = Vector2(0, 60)
	btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL

	var player_level = GameManager.active_character_level
	if player_level < level_req:
		btn.modulate = Color(0.6, 0.6, 0.6, 1.0)

	btn.text = "%s\nLv%d  %s  %dg" % [display_name, level_req, item_type, price]
	btn.pressed.connect(_on_buy_pressed.bind(item_id, display_name, price))
	slot.add_child(btn)

	item_grid.add_child(slot)

func _on_buy_pressed(item_id: String, display_name: String, price: int) -> void:
	var gold = GameManager.active_user_currencies.get("GD", 0)
	if gold < price:
		print("Armorer: Not enough gold for %s (need %d, have %d)" % [display_name, price, gold])
		return

	print("Armorer: Purchasing %s for %d gold" % [display_name, price])
	PlayFabManager.client.execute_cloud_script("purchaseShopItem", {
		"characterId": GameManager.active_character_id,
		"itemId": item_id,
		"price": price
	}, func(result):
		var data = result.get("data", {})
		var fn_result = data.get("FunctionResult", {})

		# Log CloudScript messages
		var logs = data.get("Logs", [])
		for log_entry in logs:
			print("Armorer [CloudScript %s]: %s %s" % [
				log_entry.get("Level", ""),
				log_entry.get("Message", ""),
				log_entry.get("Data", "")
			])

		if fn_result is Dictionary and fn_result.get("success", false):
			print("Armorer: Purchase successful! Gold remaining: %s" % fn_result.get("goldRemaining", "?"))
			GameManager.active_user_currencies["GD"] = fn_result.get("goldRemaining", gold - price)
			_refresh_gold()

			# Add the compact instance dict returned by CloudScript to local bag
			var new_item = fn_result.get("item", {})
			if new_item is Dictionary and new_item.has("uid"):
				GameManager.active_user_inventory.append(new_item)
				GameManager.inventory_changed.emit()
			else:
				# Fallback: create locally if server didn't return the item
				var instance = ItemDatabase.create_instance_dict(item_id, "Normal")
				var item_data = ItemDatabase.resolve_instance(instance)
				if instance.get("dura", -1) == -1:
					instance["dura"] = item_data.stats.get("MaxDura", 0)
				GameManager.active_user_inventory.append(instance)
				GameManager.inventory_changed.emit()
		else:
			var error_msg = ""
			if fn_result is Dictionary:
				error_msg = fn_result.get("error", "Unknown")
			else:
				error_msg = "FunctionResult was null/invalid"
			print("Armorer: Purchase failed -- %s" % error_msg)
	)
