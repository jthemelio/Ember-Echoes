# consumables_shop.gd — Displays consumable items (arrows for Marksman, potions, etc.)
extends VBoxContainer

@onready var gold_label: Label = $ScrollContainer/ContentVBox/ShopHeader/Margin/VBox/GoldRow/GoldValue
@onready var item_grid: GridContainer = $ScrollContainer/ContentVBox/ShopHeader/Margin/VBox/ItemGrid

# Items shown by class
const CLASS_CONSUMABLE_TYPES: Dictionary = {
	"Marksman": ["Arrow"],
	# Future: add potions, scrolls, etc. for all classes
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
	var allowed_types = CLASS_CONSUMABLE_TYPES.get(player_class, [])

	if allowed_types.is_empty():
		# Show a "nothing available" message for non-archer classes
		var lbl = Label.new()
		lbl.text = "No consumables available for your class."
		lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		lbl.autowrap_mode = TextServer.AUTOWRAP_WORD
		item_grid.add_child(lbl)
		return

	# Filter catalog: Normal quality, matching consumable types
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
	var amount = int(cd.get("Amount", 1))
	var min_atk = int(cd.get("MinAtk", 0))
	var max_atk = int(cd.get("MaxAtk", 0))

	var slot = VBoxContainer.new()
	slot.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	slot.add_theme_constant_override("separation", 2)

	var btn = Button.new()
	btn.custom_minimum_size = Vector2(0, 70)
	btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL

	var player_level = GameManager.active_character_level
	if player_level < level_req:
		btn.modulate = Color(0.6, 0.6, 0.6, 1.0)

	var max_stack = amount * 5
	btn.text = "%s (x%d)\nLv%d  ATK +%d  Stack: %d\n%dg" % [display_name, amount, level_req, min_atk, max_stack, price]
	btn.pressed.connect(_on_buy_pressed.bind(item_id, display_name, price, amount))
	slot.add_child(btn)

	item_grid.add_child(slot)

func _on_buy_pressed(item_id: String, display_name: String, price: int, amount: int) -> void:
	var gold = GameManager.active_user_currencies.get("GD", 0)
	if gold < price:
		print("Consumables: Not enough gold for %s (need %d, have %d)" % [display_name, price, gold])
		return

	print("Consumables: Purchasing %s for %d gold" % [display_name, price])
	PlayFabManager.client.execute_cloud_script("purchaseShopItem", {
		"characterId": GameManager.active_character_id,
		"itemId": item_id,
		"price": price
	}, func(result):
		var data = result.get("data", {})
		var fn_result = data.get("FunctionResult", {})

		var logs = data.get("Logs", [])
		for log_entry in logs:
			print("Consumables [CloudScript %s]: %s %s" % [
				log_entry.get("Level", ""),
				log_entry.get("Message", ""),
				log_entry.get("Data", "")
			])

		if fn_result is Dictionary and fn_result.get("success", false):
			print("Consumables: Purchase successful! Gold remaining: %s" % fn_result.get("goldRemaining", "?"))
			GameManager.active_user_currencies["GD"] = fn_result.get("goldRemaining", gold - price)
			_refresh_gold()

			# Stack purchased arrows into inventory (5 packs per slot max)
			var bid = ItemDatabase.extract_base_id(item_id)
			var quality = "Normal"
			var max_per_slot = ItemDatabase.get_max_stack_amount(bid, quality)  # 5 * base_amount
			var remaining = amount  # arrows from this purchase (1 pack)

			# Try to add to an existing slot of the same arrow type
			for inv_item in GameManager.active_user_inventory:
				if remaining <= 0:
					break
				if inv_item.get("bid", "") == bid and inv_item.get("q", "") == quality:
					var current_amt = int(inv_item.get("amt", 0))
					if current_amt < max_per_slot:
						var space = max_per_slot - current_amt
						var add = mini(space, remaining)
						inv_item["amt"] = current_amt + add
						remaining -= add

			# If there's leftover, create new stack slot(s)
			while remaining > 0:
				var stack_amt = mini(remaining, max_per_slot)
				var stack = ItemDatabase.create_instance_dict(item_id, quality, stack_amt)
				stack["dura"] = 0
				GameManager.active_user_inventory.append(stack)
				remaining -= stack_amt

			GameManager.inventory_changed.emit()
			GameManager.sync_inventory_to_server()
		else:
			var error_msg = ""
			if fn_result is Dictionary:
				error_msg = fn_result.get("error", "Unknown")
			else:
				error_msg = "FunctionResult was null/invalid"
			print("Consumables: Purchase failed -- %s" % error_msg)
	)
