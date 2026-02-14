# weaponsmith_shop.gd — Displays Normal quality weapons filtered by player class
extends MarginContainer

const InventorySlotScene = preload("res://ui/components/InventorySlot.tscn")

@onready var gold_label: Label = $ScrollContent/ContentVBox/ShopHeader/Margin/VBox/GoldRow/GoldValue
@onready var item_grid: GridContainer = $ScrollContent/ContentVBox/ShopHeader/Margin/VBox/ItemGrid

# Class-specific weapon types
const WEAPON_TYPES: Dictionary = {
	"Marksman": ["Bow", "Arrow"],
	"Twin-Soul": ["Blade"],
	"Wuxia": ["Wand"],
	"Juggernaut": ["Blade"],
	"Spiritmender": ["Wand"],
	"Emberlord": ["Wand"]
}

var _shop_items: Array = []
var _purchase_in_flight: bool = false  # Prevents rapid-fire purchases

func _ready() -> void:
	_adapt_for_desktop()
	_refresh_gold()
	_populate_shop()

func _adapt_for_desktop() -> void:
	if item_grid:
		item_grid.columns = ScreenHelper.grid_columns(4, 5)

func _refresh_gold() -> void:
	var gold = int(GameManager.active_user_currencies.get("GD", 0))
	gold_label.text = GameManager.format_gold(gold)

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

	# Group by type with subheadings
	var groups: Dictionary = {}
	for item in _shop_items:
		var t = item.get("CustomData", {}).get("Type", "Other")
		if not groups.has(t):
			groups[t] = []
		groups[t].append(item)

	# Display weapons first, then arrows
	var type_order = allowed_types.duplicate()
	for type_name in type_order:
		if not groups.has(type_name):
			continue
		_create_type_heading(type_name)
		for item in groups[type_name]:
			_create_shop_slot(item)
		# Pad to fill the row so next heading starts on a new line
		var remainder = item_grid.get_child_count() % item_grid.columns
		if remainder != 0:
			for _p in range(item_grid.columns - remainder):
				var pad = Control.new()
				pad.mouse_filter = Control.MOUSE_FILTER_IGNORE
				pad.size_flags_horizontal = Control.SIZE_EXPAND_FILL
				item_grid.add_child(pad)

func _create_type_heading(type_name: String) -> void:
	var heading = Label.new()
	heading.text = type_name + "s" if type_name != "Arrow" else "Arrows"
	heading.add_theme_font_size_override("font_size", 16)
	heading.add_theme_color_override("font_color", Color(0.9, 0.8, 0.5))
	heading.mouse_filter = Control.MOUSE_FILTER_IGNORE
	heading.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	item_grid.add_child(heading)
	# Fill remaining columns in the row with spacers
	for i in range(item_grid.columns - 1):
		var spacer = Control.new()
		spacer.mouse_filter = Control.MOUSE_FILTER_IGNORE
		spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		item_grid.add_child(spacer)

func _create_shop_slot(item: Dictionary) -> void:
	var cd = item.get("CustomData", {})
	var display_name = item.get("DisplayName", "Unknown")
	var level_req = int(cd.get("LevelReq", 0))
	var price = int(cd.get("Price", 0))
	var item_id = item.get("ItemId", "")
	var item_type = cd.get("Type", "")
	var amount = int(cd.get("Amount", 1))

	# Create an InventorySlot with the item resolved
	var slot = InventorySlotScene.instantiate()
	slot.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	slot.size_flags_vertical = Control.SIZE_FILL
	slot.suppress_tooltip = true  # We handle click ourselves

	var inst_amount = amount if item_type == "Arrow" else 1
	var instance = ItemDatabase.create_instance_dict(item_id, "Normal", inst_amount)
	var item_data = ItemDatabase.resolve_instance(instance)
	item_grid.add_child(slot)  # Must be in tree before set_item
	slot.set_item(item_data)

	# Dim if player can't use yet
	var player_level = GameManager.active_character_level
	if player_level < level_req:
		slot.modulate = Color(0.6, 0.6, 0.6, 1.0)

	# Overlay a small price label at the bottom
	var price_label = Label.new()
	price_label.text = GameManager.format_gold(price)
	price_label.add_theme_font_size_override("font_size", 9)
	price_label.add_theme_color_override("font_color", Color(1.0, 0.9, 0.5))
	price_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	price_label.vertical_alignment = VERTICAL_ALIGNMENT_BOTTOM
	price_label.anchors_preset = Control.PRESET_BOTTOM_WIDE
	price_label.grow_vertical = Control.GROW_DIRECTION_BEGIN
	price_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	slot.add_child(price_label)

	# Connect click to show tooltip with Buy button
	if item_type == "Arrow":
		slot.gui_input.connect(_on_shop_slot_input.bind(slot, item_data, item_id, display_name, price, Callable(self, "_on_buy_arrow_pressed").bind(item_id, display_name, price, amount)))
	else:
		slot.gui_input.connect(_on_shop_slot_input.bind(slot, item_data, item_id, display_name, price, Callable(self, "_on_buy_pressed").bind(item_id, display_name, price)))

func _on_shop_slot_input(event: InputEvent, slot: Control, data: ItemData, item_id: String, display_name: String, price: int, buy_callback: Callable) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		if data == null:
			return
		var tooltip = GlobalUI.equipment_tooltip
		if tooltip:
			tooltip._shop_buy_callback = buy_callback
		GlobalUI.show_tooltip(data, "shop:%d" % price)

func _on_buy_pressed(item_id: String, display_name: String, price: int) -> void:
	if _purchase_in_flight:
		print("Weaponsmith: Purchase already in progress, please wait")
		return
	var gold = GameManager.active_user_currencies.get("GD", 0)
	if gold < price:
		print("Weaponsmith: Not enough gold for %s (need %d, have %d)" % [display_name, price, gold])
		return

	_purchase_in_flight = true
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

		_purchase_in_flight = false

		if fn_result is Dictionary and fn_result.get("success", false):
			print("Weaponsmith: Purchase successful! Gold remaining: %s" % fn_result.get("goldRemaining", "?"))
			GameManager.active_user_currencies["GD"] = fn_result.get("goldRemaining", gold - price)
			_refresh_gold()
			GlobalUI.show_floating_text("Purchased %s!" % display_name, Color.WHITE)

			# Add the compact instance dict returned by CloudScript to local bag
			var new_item = fn_result.get("item", {})
			if new_item is Dictionary and new_item.has("uid"):
				GameManager.add_to_bag(new_item)
				GameManager.inventory_changed.emit()
			else:
				# Fallback: create locally
				var instance = ItemDatabase.create_instance_dict(item_id, "Normal")
				var item_data = ItemDatabase.resolve_instance(instance)
				if instance.get("dura", -1) == -1:
					instance["dura"] = item_data.stats.get("MaxDura", 0)
				GameManager.add_to_bag(instance)
				GameManager.inventory_changed.emit()
		else:
			var error_msg = ""
			if fn_result is Dictionary:
				error_msg = fn_result.get("error", "Unknown")
			else:
				error_msg = "FunctionResult was null/invalid"
			print("Weaponsmith: Purchase failed -- %s" % error_msg)
	)

func _on_buy_arrow_pressed(item_id: String, display_name: String, price: int, amount: int) -> void:
	if _purchase_in_flight:
		print("Weaponsmith: Purchase already in progress, please wait")
		return
	var gold = GameManager.active_user_currencies.get("GD", 0)
	if gold < price:
		print("Weaponsmith: Not enough gold for %s (need %d, have %d)" % [display_name, price, gold])
		return

	_purchase_in_flight = true
	print("Weaponsmith: Purchasing arrows %s for %d gold" % [display_name, price])
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

		_purchase_in_flight = false

		if fn_result is Dictionary and fn_result.get("success", false):
			print("Weaponsmith: Arrow purchase successful! Gold remaining: %s" % fn_result.get("goldRemaining", "?"))
			GameManager.active_user_currencies["GD"] = fn_result.get("goldRemaining", gold - price)
			_refresh_gold()
			GlobalUI.show_floating_text("Purchased %s!" % display_name, Color.WHITE)

			# Stack arrows into inventory (5 packs per slot max)
			var bid = ItemDatabase.extract_base_id(item_id)
			var quality = "Normal"
			var max_per_slot = ItemDatabase.get_max_stack_amount(bid, quality)
			var remaining = amount

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

			while remaining > 0:
				var stack_amt = mini(remaining, max_per_slot)
				var stack = ItemDatabase.create_instance_dict(item_id, quality, stack_amt)
				stack["dura"] = 0
				GameManager.add_to_bag(stack)
				remaining -= stack_amt

			GameManager.inventory_changed.emit()
			GameManager.sync_inventory_to_server()
		else:
			var error_msg = ""
			if fn_result is Dictionary:
				error_msg = fn_result.get("error", "Unknown")
			else:
				error_msg = "FunctionResult was null/invalid"
			print("Weaponsmith: Arrow purchase failed -- %s" % error_msg)
	)
