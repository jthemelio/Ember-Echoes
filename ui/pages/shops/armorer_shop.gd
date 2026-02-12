# armorer_shop.gd — Displays Normal quality armor filtered by player class
# Headgear, Body Armor, Boots, Rings, Necklaces
extends MarginContainer

@onready var gold_label: Label = $ScrollContent/ContentVBox/ShopHeader/Margin/VBox/GoldRow/GoldValue
@onready var item_grid: GridContainer = $ScrollContent/ContentVBox/ShopHeader/Margin/VBox/ItemGrid

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
var _purchase_in_flight: bool = false  # Prevents rapid-fire purchases

func _ready() -> void:
	_refresh_gold()
	_populate_shop()

func _refresh_gold() -> void:
	var gold = int(GameManager.active_user_currencies.get("GD", 0))
	gold_label.text = GameManager.format_gold(gold)

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

	# Group by type and create entries with subheadings
	var groups: Dictionary = {}  # Type -> Array of items
	for item in _shop_items:
		var t = item.get("CustomData", {}).get("Type", "Other")
		if not groups.has(t):
			groups[t] = []
		groups[t].append(item)

	# Display order for armor types
	var type_order = [head_type, body_type, "Boots", "Ring", "Necklace"]
	for type_name in type_order:
		if not groups.has(type_name):
			continue
		_create_type_heading(type_name)
		for item in groups[type_name]:
			_create_shop_slot(item)

func _create_type_heading(type_name: String) -> void:
	var heading = Label.new()
	heading.text = type_name + "s"
	heading.add_theme_font_size_override("font_size", 16)
	heading.add_theme_color_override("font_color", Color(0.9, 0.8, 0.5))
	heading.mouse_filter = Control.MOUSE_FILTER_IGNORE
	heading.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	item_grid.add_child(heading)
	# Fill remaining column in the grid with empty spacer
	var spacer = Control.new()
	spacer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	item_grid.add_child(spacer)

func _create_shop_slot(item: Dictionary) -> void:
	var cd = item.get("CustomData", {})
	var display_name = item.get("DisplayName", "Unknown")
	var level_req = int(cd.get("LevelReq", 0))
	var price = int(cd.get("Price", 0))
	var item_id = item.get("ItemId", "")

	var btn = Button.new()
	btn.custom_minimum_size = Vector2(0, 48)
	btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	btn.clip_text = true

	var player_level = GameManager.active_character_level
	if player_level < level_req:
		btn.modulate = Color(0.6, 0.6, 0.6, 1.0)

	btn.text = "%s\nLv%d - %sg" % [display_name, level_req, GameManager.format_gold(price)]
	btn.pressed.connect(_on_buy_pressed.bind(item_id, display_name, price))

	item_grid.add_child(btn)

func _on_buy_pressed(item_id: String, display_name: String, price: int) -> void:
	if _purchase_in_flight:
		print("Armorer: Purchase already in progress, please wait")
		return
	var gold = GameManager.active_user_currencies.get("GD", 0)
	if gold < price:
		print("Armorer: Not enough gold for %s (need %d, have %d)" % [display_name, price, gold])
		return

	_purchase_in_flight = true
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

		_purchase_in_flight = false

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
