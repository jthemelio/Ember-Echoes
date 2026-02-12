# artisan_shop.gd — Upgrade items by level, quality, or Ignis+
extends MarginContainer

const InventorySlotScene = preload("res://ui/components/InventorySlot.tscn")

# ─── UI References ───
@onready var item_picker_grid: GridContainer = $ScrollContent/ContentVBox/ItemPickerPanel/Margin/VBox/ItemPickerGrid
@onready var level_btn: Button = $ScrollContent/ContentVBox/UpgradeModeBar/LevelUpgradeBtn
@onready var quality_btn: Button = $ScrollContent/ContentVBox/UpgradeModeBar/QualityUpgradeBtn
@onready var ignis_btn: Button = $ScrollContent/ContentVBox/UpgradeModeBar/IgnisPlusBtn

# Upgrade panel
@onready var source_slot: PanelContainer = $ScrollContent/ContentVBox/UpgradePanel/Margin/VBox/SlotRow/SourceSlot
@onready var source_label: Label = $ScrollContent/ContentVBox/UpgradePanel/Margin/VBox/SlotRow/SourceSlot/SourceLabel
@onready var material_slot: PanelContainer = $ScrollContent/ContentVBox/UpgradePanel/Margin/VBox/SlotRow/MaterialSlot
@onready var material_label: Label = $ScrollContent/ContentVBox/UpgradePanel/Margin/VBox/SlotRow/MaterialSlot/MaterialLabel
@onready var result_slot: PanelContainer = $ScrollContent/ContentVBox/UpgradePanel/Margin/VBox/SlotRow/ResultSlot
@onready var result_label: Label = $ScrollContent/ContentVBox/UpgradePanel/Margin/VBox/SlotRow/ResultSlot/ResultLabel
@onready var info_label: Label = $ScrollContent/ContentVBox/UpgradePanel/Margin/VBox/InfoLabel
@onready var success_label: Label = $ScrollContent/ContentVBox/UpgradePanel/Margin/VBox/SuccessLabel
@onready var upgrade_btn: Button = $ScrollContent/ContentVBox/UpgradePanel/Margin/VBox/UpgradeBtn
@onready var result_message: Label = $ScrollContent/ContentVBox/UpgradePanel/Margin/VBox/ResultMessageLabel

# Material popup
@onready var material_popup: PanelContainer = $ScrollContent/ContentVBox/MaterialPopup
@onready var popup_title: Label = $ScrollContent/ContentVBox/MaterialPopup/Margin/VBox/PopupTitle
@onready var popup_icon_label: Label = $ScrollContent/ContentVBox/MaterialPopup/Margin/VBox/MaterialRow/MaterialIcon/IconLabel
@onready var popup_count_label: Label = $ScrollContent/ContentVBox/MaterialPopup/Margin/VBox/MaterialRow/MaterialCount
@onready var select_material_btn: Button = $ScrollContent/ContentVBox/MaterialPopup/Margin/VBox/BtnRow/SelectMaterialBtn
@onready var cancel_material_btn: Button = $ScrollContent/ContentVBox/MaterialPopup/Margin/VBox/BtnRow/CancelMaterialBtn

# ─── State ───
enum UpgradeMode { LEVEL, QUALITY, IGNIS }
var _mode: int = UpgradeMode.LEVEL
var _selected_instance: Dictionary = {}  # The compact instance dict being upgraded
var _selected_source: String = ""        # "bag" or equipment slot name
var _selected_bag_index: int = -1        # Index in active_user_inventory (if from bag)
var _material_ready: bool = false        # Whether material has been "loaded" into the slot
var _preview_item: ItemData = null       # Preview of the upgraded result

# ─── Quality Colors ───
const QUALITY_COLORS = {
	"Normal": Color.WHITE,
	"Tempered": Color(0.0, 1.0, 0.0),
	"Infused": Color(0.0, 0.5, 1.0),
	"Brilliant": Color(0.6, 0.2, 0.8),
	"Radiant": Color(1.0, 0.8, 0.0),
}

# ─── Success Chance Tables ───

func _get_level_success_chance(level_req: int) -> float:
	if level_req <= 15: return 1.0
	if level_req <= 30: return 0.80
	if level_req <= 50: return 0.60
	if level_req <= 70: return 0.40
	if level_req <= 100: return 0.25
	return 0.10

func _get_quality_success_chance(target_quality: String) -> float:
	match target_quality:
		"Tempered": return 0.80
		"Infused": return 0.50
		"Brilliant": return 0.20
		"Radiant": return 0.05
	return 0.0

# ─── Lifecycle ───

func _ready() -> void:
	# Mode buttons
	level_btn.pressed.connect(_on_mode_pressed.bind(UpgradeMode.LEVEL))
	quality_btn.pressed.connect(_on_mode_pressed.bind(UpgradeMode.QUALITY))
	ignis_btn.pressed.connect(_on_mode_pressed.bind(UpgradeMode.IGNIS))

	# Material slot tap
	material_slot.gui_input.connect(_on_material_slot_input)

	# Popup buttons
	select_material_btn.pressed.connect(_on_select_material)
	cancel_material_btn.pressed.connect(_on_cancel_material)

	# Upgrade button
	upgrade_btn.pressed.connect(_on_upgrade_pressed)

	# Listen for inventory changes to refresh picker
	GameManager.inventory_changed.connect(_refresh_picker)
	GameManager.equipment_changed.connect(_refresh_picker)

	_refresh_picker()
	_refresh_upgrade_panel()

# ─── Item Picker ───

func _refresh_picker() -> void:
	# Clear existing slots
	for child in item_picker_grid.get_children():
		child.queue_free()

	# Collect all upgradeable items: equipped + bag
	# Equipped items first
	for slot_name in GameManager.equipped_items:
		var inst = GameManager.equipped_items[slot_name]
		if inst == null:
			continue
		var item_data = ItemDatabase.resolve_instance(inst)
		# Skip arrows, materials, and non-equipment
		if item_data.item_type in ["Arrow", "Material", "Item"]:
			continue
		var slot = _create_picker_slot(item_data, inst, slot_name, -1)
		item_picker_grid.add_child(slot)

	# Bag items
	for i in range(GameManager.active_user_inventory.size()):
		var inst = GameManager.active_user_inventory[i]
		if not inst is Dictionary:
			continue
		var item_data = ItemDatabase.resolve_instance(inst)
		if item_data.item_type in ["Arrow", "Material", "Item"]:
			continue
		var slot = _create_picker_slot(item_data, inst, "bag", i)
		item_picker_grid.add_child(slot)

func _create_picker_slot(item_data: ItemData, inst: Dictionary, source: String, bag_idx: int) -> PanelContainer:
	var slot = InventorySlotScene.instantiate()
	# We need to defer set_item until slot is in tree
	slot.call_deferred("set_item", item_data)

	# Highlight if this is the currently selected item
	if not _selected_instance.is_empty() and inst.get("uid", "") == _selected_instance.get("uid", "____"):
		slot.call_deferred("set", "modulate", Color(1.0, 1.0, 0.5, 1.0))

	# Connect tap
	slot.gui_input.connect(_on_picker_slot_input.bind(inst, source, bag_idx))
	return slot

func _on_picker_slot_input(event: InputEvent, inst: Dictionary, source: String, bag_idx: int) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		_selected_instance = inst
		_selected_source = source
		_selected_bag_index = bag_idx
		_material_ready = false
		result_message.text = ""
		_refresh_picker()
		_refresh_upgrade_panel()

# ─── Mode Switching ───

func _on_mode_pressed(mode: int) -> void:
	_mode = mode
	_material_ready = false
	result_message.text = ""

	# Update toggle visual
	level_btn.button_pressed = (mode == UpgradeMode.LEVEL)
	quality_btn.button_pressed = (mode == UpgradeMode.QUALITY)
	ignis_btn.button_pressed = (mode == UpgradeMode.IGNIS)

	_refresh_upgrade_panel()

# ─── Upgrade Panel Refresh ───

func _refresh_upgrade_panel() -> void:
	_preview_item = null

	if _selected_instance.is_empty():
		source_label.text = "Source"
		source_label.visible = true
		material_label.text = "Material"
		material_label.visible = true
		result_label.text = "Result"
		result_label.visible = true
		info_label.text = "Select an item from the grid above."
		success_label.text = ""
		upgrade_btn.disabled = true
		_update_slot_color(source_slot, Color(0.3, 0.3, 0.3))
		_update_slot_color(material_slot, Color(0.3, 0.3, 0.3))
		_update_slot_color(result_slot, Color(0.3, 0.3, 0.3))
		return

	var item_data = ItemDatabase.resolve_instance(_selected_instance)

	# Source slot
	source_label.text = item_data.display_name
	source_label.add_theme_font_size_override("font_size", 10)
	source_label.visible = true
	var q_color = QUALITY_COLORS.get(item_data.quality.capitalize(), Color.WHITE)
	_update_slot_color(source_slot, q_color)

	# Mode-specific logic
	match _mode:
		UpgradeMode.LEVEL:
			_refresh_level_upgrade(item_data)
		UpgradeMode.QUALITY:
			_refresh_quality_upgrade(item_data)
		UpgradeMode.IGNIS:
			_refresh_ignis_upgrade(item_data)

func _refresh_level_upgrade(item_data: ItemData) -> void:
	var can_upgrade = ItemDatabase.can_level_upgrade(_selected_instance)
	if not can_upgrade:
		info_label.text = "%s is already at max level." % item_data.display_name
		success_label.text = ""
		material_label.text = "---"
		result_label.text = "Max"
		upgrade_btn.disabled = true
		_update_slot_color(material_slot, Color(0.3, 0.3, 0.3))
		_update_slot_color(result_slot, Color(0.3, 0.3, 0.3))
		return

	# Material slot
	if _material_ready:
		material_label.text = "Comet\nx1"
		material_label.add_theme_font_size_override("font_size", 10)
		_update_slot_color(material_slot, Color(0.4, 0.7, 1.0))
	else:
		material_label.text = "Tap to\nadd"
		material_label.add_theme_font_size_override("font_size", 10)
		_update_slot_color(material_slot, Color(0.5, 0.5, 0.5))

	# Preview result
	_preview_item = ItemDatabase.preview_level_upgrade(_selected_instance)
	if _preview_item:
		result_label.text = _preview_item.display_name
		result_label.add_theme_font_size_override("font_size", 10)
		var rq_color = QUALITY_COLORS.get(_preview_item.quality.capitalize(), Color.WHITE)
		_update_slot_color(result_slot, rq_color)
	else:
		result_label.text = "?"
		_update_slot_color(result_slot, Color(0.3, 0.3, 0.3))

	# Success rate
	var chance = _get_level_success_chance(item_data.level_req)
	success_label.text = "Success Rate: %d%%" % int(chance * 100)
	info_label.text = "Upgrade %s (Lv%d) to Lv%d. Requires 1 Comet." % [
		item_data.display_name, item_data.level_req,
		_preview_item.level_req if _preview_item else 0
	]

	upgrade_btn.disabled = not _material_ready
	upgrade_btn.text = "Upgrade Level"

func _refresh_quality_upgrade(item_data: ItemData) -> void:
	var can_upgrade = ItemDatabase.can_quality_upgrade(_selected_instance)
	if not can_upgrade:
		info_label.text = "%s is already Radiant quality." % item_data.display_name
		success_label.text = ""
		material_label.text = "---"
		result_label.text = "Max"
		upgrade_btn.disabled = true
		_update_slot_color(material_slot, Color(0.3, 0.3, 0.3))
		_update_slot_color(result_slot, Color(0.3, 0.3, 0.3))
		return

	# Material slot
	if _material_ready:
		material_label.text = "Wyrm\nSphere x1"
		material_label.add_theme_font_size_override("font_size", 9)
		_update_slot_color(material_slot, Color(0.7, 0.3, 0.9))
	else:
		material_label.text = "Tap to\nadd"
		material_label.add_theme_font_size_override("font_size", 10)
		_update_slot_color(material_slot, Color(0.5, 0.5, 0.5))

	# Preview result
	_preview_item = ItemDatabase.preview_quality_upgrade(_selected_instance)
	if _preview_item:
		result_label.text = _preview_item.display_name
		result_label.add_theme_font_size_override("font_size", 10)
		var rq_color = QUALITY_COLORS.get(_preview_item.quality.capitalize(), Color.WHITE)
		_update_slot_color(result_slot, rq_color)
	else:
		result_label.text = "?"
		_update_slot_color(result_slot, Color(0.3, 0.3, 0.3))

	# Success rate
	var next_q = ItemDatabase.get_next_quality(item_data.quality)
	var chance = _get_quality_success_chance(next_q)
	success_label.text = "Success Rate: %d%%" % int(chance * 100)
	info_label.text = "Upgrade %s from %s to %s. Requires 1 Wyrm Sphere." % [
		item_data.display_name, item_data.quality, next_q
	]

	upgrade_btn.disabled = not _material_ready
	upgrade_btn.text = "Upgrade Quality"

func _refresh_ignis_upgrade(_item_data: ItemData) -> void:
	info_label.text = "Ignis+ upgrades coming soon! These will be available via Lady Luck."
	success_label.text = ""
	material_label.text = "---"
	result_label.text = "---"
	upgrade_btn.disabled = true
	upgrade_btn.text = "Coming Soon"
	_update_slot_color(material_slot, Color(0.3, 0.3, 0.3))
	_update_slot_color(result_slot, Color(0.3, 0.3, 0.3))

# ─── Material Popup ───

func _on_material_slot_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		if _selected_instance.is_empty():
			return
		if _mode == UpgradeMode.IGNIS:
			return
		_show_material_popup()

func _show_material_popup() -> void:
	var currency_code = "CM" if _mode == UpgradeMode.LEVEL else "WS"
	var mat_name = "Comet" if _mode == UpgradeMode.LEVEL else "Wyrm Sphere"
	var total = GameManager.get_total_material_count(currency_code)

	popup_title.text = "Select %s" % mat_name
	popup_icon_label.text = mat_name
	popup_count_label.text = "x%d" % total

	if total > 0:
		select_material_btn.disabled = false
		select_material_btn.text = "Use 1 %s" % mat_name
	else:
		select_material_btn.disabled = true
		select_material_btn.text = "None Available"

	material_popup.visible = true

func _on_select_material() -> void:
	_material_ready = true
	material_popup.visible = false
	_refresh_upgrade_panel()

func _on_cancel_material() -> void:
	material_popup.visible = false

# ─── Upgrade Execution ───

func _on_upgrade_pressed() -> void:
	if _selected_instance.is_empty() or not _material_ready:
		return

	match _mode:
		UpgradeMode.LEVEL:
			_execute_level_upgrade()
		UpgradeMode.QUALITY:
			_execute_quality_upgrade()

func _execute_level_upgrade() -> void:
	if not ItemDatabase.can_level_upgrade(_selected_instance):
		return

	# Consume 1 Comet
	if not GameManager.consume_material("CM"):
		result_message.text = "No Comets available!"
		result_message.add_theme_color_override("font_color", Color(1.0, 0.3, 0.3))
		return

	var item_data = ItemDatabase.resolve_instance(_selected_instance)
	var chance = _get_level_success_chance(item_data.level_req)
	var roll = randf()

	if roll <= chance:
		# SUCCESS
		var next_bid = ItemDatabase.get_next_level_base_id(_selected_instance.get("bid", ""))
		_selected_instance["bid"] = next_bid

		# Reset durability to new template's max
		var new_item = ItemDatabase.resolve_instance(_selected_instance)
		_selected_instance["dura"] = new_item.stats.get("MaxDura", 0)

		# 1/400 chance to gain a socket
		if randf() < (1.0 / 400.0):
			var skt = _selected_instance.get("skt", [])
			skt.append(null)
			_selected_instance["skt"] = skt
			result_message.text = "SUCCESS! Upgraded to %s + gained a socket!" % new_item.display_name
		else:
			result_message.text = "SUCCESS! Upgraded to %s" % new_item.display_name
		result_message.add_theme_color_override("font_color", Color(0.3, 1.0, 0.3))
	else:
		# FAILURE
		result_message.text = "FAILED. The Comet was consumed."
		result_message.add_theme_color_override("font_color", Color(1.0, 0.3, 0.3))

	_material_ready = false
	_finalize_upgrade()

func _execute_quality_upgrade() -> void:
	if not ItemDatabase.can_quality_upgrade(_selected_instance):
		return

	# Consume 1 Wyrm Sphere
	if not GameManager.consume_material("WS"):
		result_message.text = "No Wyrm Spheres available!"
		result_message.add_theme_color_override("font_color", Color(1.0, 0.3, 0.3))
		return

	var item_data = ItemDatabase.resolve_instance(_selected_instance)
	var next_q = ItemDatabase.get_next_quality(item_data.quality)
	var chance = _get_quality_success_chance(next_q)
	var roll = randf()

	if roll <= chance:
		# SUCCESS
		_selected_instance["q"] = next_q

		# Reset durability to new template's max
		var new_item = ItemDatabase.resolve_instance(_selected_instance)
		_selected_instance["dura"] = new_item.stats.get("MaxDura", 0)

		# 1/100 chance to gain a socket
		if randf() < (1.0 / 100.0):
			var skt = _selected_instance.get("skt", [])
			skt.append(null)
			_selected_instance["skt"] = skt
			result_message.text = "SUCCESS! Upgraded to %s + gained a socket!" % new_item.display_name
		else:
			result_message.text = "SUCCESS! Upgraded to %s" % new_item.display_name
		result_message.add_theme_color_override("font_color", Color(0.3, 1.0, 0.3))
	else:
		# FAILURE
		result_message.text = "FAILED. The Wyrm Sphere was consumed."
		result_message.add_theme_color_override("font_color", Color(1.0, 0.3, 0.3))

	_material_ready = false
	_finalize_upgrade()

func _finalize_upgrade() -> void:
	# Call server to validate/deduct currency
	var currency_code = "CM" if _mode == UpgradeMode.LEVEL else "WS"
	var upgrade_type = "level" if _mode == UpgradeMode.LEVEL else "quality"
	PlayFabManager.client.execute_cloud_script("artisanUpgrade", {
		"upgradeType": upgrade_type,
		"currencyCode": currency_code,
		"amount": 1
	}, func(result):
		var fn_result = result.get("data", {}).get("FunctionResult", {})
		if fn_result is Dictionary and fn_result.get("success", false):
			# Update local currency if server deducted
			if fn_result.has("newBalance"):
				GameManager.active_user_currencies[currency_code] = fn_result["newBalance"]
			print("Artisan: Server confirmed upgrade (%s)" % upgrade_type)
		else:
			print("Artisan: Server upgrade validation issue (sync will reconcile)")
	)

	# Emit signals and sync inventory
	GameManager.equipment_changed.emit()
	GameManager.inventory_changed.emit()
	GameManager.sync_inventory_to_server()

	# Refresh UI
	_refresh_picker()
	_refresh_upgrade_panel()

# ─── Utility ───

func _update_slot_color(slot: PanelContainer, color: Color) -> void:
	slot.self_modulate = color
