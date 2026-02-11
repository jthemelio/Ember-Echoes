# weaponsmith_shop.gd — Displays Normal quality weapons filtered by player class
extends VBoxContainer

@onready var gold_label: Label = $ScrollContainer/ContentVBox/ShopHeader/Margin/VBox/GoldRow/GoldValue
@onready var item_grid: GridContainer = $ScrollContainer/ContentVBox/ShopHeader/Margin/VBox/ItemGrid

# Class-specific weapon types
const WEAPON_TYPES: Dictionary = {
	"Marksman": ["Bow"],
	"Twin-Soul": ["Blade"],
	"Wuxia": ["Wand"],
	"Juggernaut": ["Blade"],
	"Spiritmender": ["Wand"],
	"Emberlord": ["Wand"]
}

var _shop_items: Array = []

func _ready() -> void:
	_refresh_gold()
	_populate_shop()

func _refresh_gold() -> void:
	var gold = GameManager.active_user_currencies.get("GD", 0)
	gold_label.text = str(gold)

func _populate_shop() -> void:
	for child in item_grid.get_children():
		child.queue_free()
	_shop_items.clear()

	var loot_mgr = get_node_or_null("/root/LootManager")
	if not loot_mgr:
		return

	var player_class = GameManager.active_character_class
	var allowed_types = WEAPON_TYPES.get(player_class, ["Blade"])

	# Filter catalog: Normal quality, matching weapon types
	for item in loot_mgr._all_items:
		var cd = item.get("CustomData", {})
		var quality = cd.get("Quality", "")
		var item_type = cd.get("Type", "")

		if quality != "Normal":
			continue
		if item_type not in allowed_types:
			continue

		_shop_items.append(item)

	# Sort by level requirement
	_shop_items.sort_custom(func(a, b):
		var a_lvl = int(a.get("CustomData", {}).get("LevelReq", 0))
		var b_lvl = int(b.get("CustomData", {}).get("LevelReq", 0))
		return a_lvl < b_lvl
	)

	for item in _shop_items:
		_create_shop_slot(item)

func _create_shop_slot(item: Dictionary) -> void:
	var cd = item.get("CustomData", {})
	var display_name = item.get("DisplayName", "Unknown")
	var level_req = int(cd.get("LevelReq", 0))
	var price = int(cd.get("Price", 0))
	var item_id = item.get("ItemId", "")
	var min_atk = int(cd.get("MinAtk", 0))
	var max_atk = int(cd.get("MaxAtk", 0))
	var speed = int(cd.get("Speed", 0))

	var slot = VBoxContainer.new()
	slot.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	slot.add_theme_constant_override("separation", 2)

	var btn = Button.new()
	btn.custom_minimum_size = Vector2(0, 70)
	btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL

	var player_level = GameManager.active_character_level
	if player_level < level_req:
		btn.modulate = Color(0.6, 0.6, 0.6, 1.0)

	btn.text = "%s\nLv%d  Atk %d-%d  Spd %d\n%dg" % [display_name, level_req, min_atk, max_atk, speed, price]
	btn.pressed.connect(_on_buy_pressed.bind(item_id, display_name, price))
	slot.add_child(btn)

	item_grid.add_child(slot)

func _on_buy_pressed(item_id: String, display_name: String, price: int) -> void:
	var gold = GameManager.active_user_currencies.get("GD", 0)
	if gold < price:
		print("Weaponsmith: Not enough gold for %s (need %d, have %d)" % [display_name, price, gold])
		return

	print("Weaponsmith: Purchasing %s for %d gold" % [display_name, price])
	PlayFabManager.client.execute_cloud_script("purchaseShopItem", {
		"characterId": GameManager.active_character_id,
		"itemId": item_id,
		"price": price
	}, func(result):
		var data = result.get("data", {})
		var fn_result = data.get("FunctionResult", {})

		var logs = data.get("Logs", [])
		for log_entry in logs:
			print("Weaponsmith [CloudScript %s]: %s %s" % [
				log_entry.get("Level", ""),
				log_entry.get("Message", ""),
				log_entry.get("Data", "")
			])

		if fn_result is Dictionary and fn_result.get("success", false):
			print("Weaponsmith: Purchase successful! Gold remaining: %s" % fn_result.get("goldRemaining", "?"))
			GameManager.active_user_currencies["GD"] = fn_result.get("goldRemaining", gold - price)
			_refresh_gold()

			# Add the compact instance dict returned by CloudScript to local bag
			var new_item = fn_result.get("item", {})
			if new_item is Dictionary and new_item.has("uid"):
				GameManager.active_user_inventory.append(new_item)
				GameManager.inventory_changed.emit()
			else:
				# Fallback: create locally
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
			print("Weaponsmith: Purchase failed -- %s" % error_msg)
	)
