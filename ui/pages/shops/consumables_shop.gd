# consumables_shop.gd — Displays consumable items (arrows for Marksman, potions, etc.)
extends MarginContainer

@onready var gold_label: Label = $ScrollContent/ContentVBox/ShopHeader/Margin/VBox/GoldRow/GoldValue
@onready var item_grid: GridContainer = $ScrollContent/ContentVBox/ShopHeader/Margin/VBox/ItemGrid

# Items shown by class
const CLASS_CONSUMABLE_TYPES: Dictionary = {
	"Marksman": ["Arrow"],
	# Future: add potions, scrolls, etc. for all classes
}

var _shop_items: Array = []
var _purchase_in_flight: bool = false  # Prevents rapid-fire purchases

func _ready() -> void:
	_adapt_for_desktop()
	_refresh_gold()
	_populate_shop()

func _adapt_for_desktop() -> void:
	if not ScreenHelper.is_desktop():
		return
	if item_grid:
		item_grid.columns = ScreenHelper.grid_columns(2, 3)

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
	var allowed_types = CLASS_CONSUMABLE_TYPES.get(player_class, [])

	if allowed_types.is_empty():
		# Show a "nothing available" message for non-archer classes
		var lbl = Label.new()
		lbl.text = "No consumables available for your class."
		lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		lbl.autowrap_mode = TextServer.AUTOWRAP_WORD
		item_grid.add_child(lbl)
		return

	# Filter full catalog (includes misc): Normal quality, matching consumable types
	for item in loot_mgr._full_catalog:
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
	var base_price = int(cd.get("Price", 0))
	var item_id = item.get("ItemId", "")
	var base_amount = int(cd.get("Amount", 1))

	var player_level = GameManager.active_character_level

	# ── Container for the row: info + qty buttons + buy button ──
	var row = VBoxContainer.new()
	row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_theme_constant_override("separation", 4)

	# Item name + level label
	var name_lbl = Label.new()
	name_lbl.text = "%s (x%d)  —  Lv%d" % [display_name, base_amount, level_req]
	name_lbl.add_theme_font_size_override("font_size", 13)
	if player_level < level_req:
		name_lbl.modulate = Color(0.6, 0.6, 0.6, 1.0)
	row.add_child(name_lbl)

	# Price + quantity row
	var buy_row = HBoxContainer.new()
	buy_row.add_theme_constant_override("separation", 6)
	row.add_child(buy_row)

	# Price label (updates when qty changes)
	var price_lbl = Label.new()
	price_lbl.text = GameManager.format_gold(base_price)
	price_lbl.add_theme_font_size_override("font_size", 13)
	price_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	buy_row.add_child(price_lbl)

	# Qty toggle buttons
	var qty_1_btn = Button.new()
	qty_1_btn.text = "x1"
	qty_1_btn.custom_minimum_size = Vector2(44, 34)
	buy_row.add_child(qty_1_btn)

	var qty_5_btn = Button.new()
	qty_5_btn.text = "x5"
	qty_5_btn.custom_minimum_size = Vector2(44, 34)
	buy_row.add_child(qty_5_btn)

	# Buy button
	var buy_btn = Button.new()
	buy_btn.text = "Buy"
	buy_btn.custom_minimum_size = Vector2(60, 34)
	buy_row.add_child(buy_btn)

	if player_level < level_req:
		buy_btn.disabled = true
		buy_row.modulate = Color(0.6, 0.6, 0.6, 1.0)

	# Track selected quantity per slot (default: 1)
	var state = {"qty": 1}

	# Style the active qty button
	var _style_qty = func():
		var active_style = StyleBoxFlat.new()
		active_style.bg_color = Color(0.76, 0.35, 0.24)
		active_style.set_corner_radius_all(6)
		active_style.content_margin_left = 6
		active_style.content_margin_right = 6
		active_style.content_margin_top = 4
		active_style.content_margin_bottom = 4
		if state["qty"] == 1:
			qty_1_btn.add_theme_stylebox_override("normal", active_style)
			qty_1_btn.add_theme_color_override("font_color", Color.WHITE)
			qty_5_btn.remove_theme_stylebox_override("normal")
			qty_5_btn.remove_theme_color_override("font_color")
		else:
			qty_5_btn.add_theme_stylebox_override("normal", active_style)
			qty_5_btn.add_theme_color_override("font_color", Color.WHITE)
			qty_1_btn.remove_theme_stylebox_override("normal")
			qty_1_btn.remove_theme_color_override("font_color")
		price_lbl.text = GameManager.format_gold(base_price * state["qty"])

	qty_1_btn.pressed.connect(func():
		state["qty"] = 1
		_style_qty.call()
	)
	qty_5_btn.pressed.connect(func():
		state["qty"] = 5
		_style_qty.call()
	)

	# Set initial style
	_style_qty.call()

	buy_btn.pressed.connect(func():
		var qty = state["qty"]
		_on_buy_pressed(item_id, display_name, base_price * qty, base_amount * qty)
	)

	item_grid.add_child(row)

func _on_buy_pressed(item_id: String, display_name: String, price: int, amount: int) -> void:
	# Prevent rapid-fire purchases (causes PlayFab rate-limit / concurrent errors)
	if _purchase_in_flight:
		print("Consumables: Purchase already in progress, please wait")
		return

	var gold = GameManager.active_user_currencies.get("GD", 0)
	if gold < price:
		print("Consumables: Not enough gold for %s (need %d, have %d)" % [display_name, price, gold])
		GlobalUI.show_floating_text("Not enough gold!", Color.RED)
		return

	_purchase_in_flight = true
	print("Consumables: Purchasing %s (x%d) for %d gold" % [display_name, amount, price])

	PlayFabManager.client.execute_cloud_script("purchaseShopItem", {
		"characterId": GameManager.active_character_id,
		"itemId": item_id,
		"price": price
	}, func(result):
		_purchase_in_flight = false

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
			GlobalUI.show_floating_text("Purchased %s!" % display_name, Color.WHITE)

			# Stack purchased arrows into bag (5 packs per slot max)
			var bid = ItemDatabase.extract_base_id(item_id)
			var quality = "Normal"
			var max_per_slot = ItemDatabase.get_max_stack_amount(bid, quality)  # 5 * base_amount
			var remaining = amount

			# Try to add to an existing slot of the same arrow type in bag
			for inv_item in GameManager.active_user_inventory:
				if remaining <= 0:
					break
				if inv_item is Dictionary and inv_item.get("bid", "") == bid and inv_item.get("q", "") == quality:
					var current_amt = int(inv_item.get("amt", 0))
					if current_amt < max_per_slot:
						var space = max_per_slot - current_amt
						var add = mini(space, remaining)
						inv_item["amt"] = current_amt + add
						remaining -= add

			# If there's leftover, create new stack slot(s) in bag
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
			print("Consumables: Purchase failed -- %s" % error_msg)
	)
