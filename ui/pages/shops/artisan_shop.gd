# artisan_shop.gd — Drag-and-drop upgrade system
extends MarginContainer

const InventorySlotScene = preload("res://ui/components/InventorySlot.tscn")

# ─── UI References ───
@onready var item_picker_grid: GridContainer = $ScrollContent/ContentVBox/ItemPickerPanel/Margin/VBox/ItemPickerGrid
@onready var material_grid: GridContainer = $ScrollContent/ContentVBox/MaterialPalette/Margin/VBox/MaterialGrid

# Ignis composition panel
@onready var ignis_grid: GridContainer = $ScrollContent/ContentVBox/IgnisCompose/Margin/VBox/IgnisGrid
@onready var compose_message: Label = $ScrollContent/ContentVBox/IgnisCompose/Margin/VBox/ComposeMessage

# Scroll conversion panel
@onready var scroll_grid: GridContainer = $ScrollContent/ContentVBox/ScrollConvert/Margin/VBox/ScrollGrid
@onready var convert_message: Label = $ScrollContent/ContentVBox/ScrollConvert/Margin/VBox/ConvertMessage

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
@onready var clear_btn: Button = $ScrollContent/ContentVBox/UpgradePanel/Margin/VBox/ClearBtn
@onready var result_message: Label = $ScrollContent/ContentVBox/UpgradePanel/Margin/VBox/ResultMessageLabel

# ─── State ───
var _selected_instance: Dictionary = {}  # The compact instance dict being upgraded
var _selected_source: String = ""        # "bag" or equipment slot name
var _selected_bag_index: int = -1        # Index in active_user_inventory (if from bag)
var _dragged_material_bid: String = ""   # bid of the material in the material slot
var _preview_item: ItemData = null       # Preview of the upgraded result

# Auto-detected upgrade mode based on the dragged material
enum UpgradeMode { NONE, LEVEL, QUALITY, IGNIS }
var _auto_mode: int = UpgradeMode.NONE

# ─── Material → Mode Mapping ───
const MATERIAL_MODE_MAP = {
	"Comet": UpgradeMode.LEVEL,
	"Wyrm_Sphere": UpgradeMode.QUALITY,
	"ignis_plus_1": UpgradeMode.IGNIS,
	"ignis_plus_2": UpgradeMode.IGNIS,
	"ignis_plus_3": UpgradeMode.IGNIS,
	"ignis_plus_4": UpgradeMode.IGNIS,
	"ignis_plus_5": UpgradeMode.IGNIS,
	"ignis_plus_6": UpgradeMode.IGNIS,
}

const MATERIAL_DISPLAY_NAMES = {
	"Comet": "Comet",
	"Wyrm_Sphere": "Wyrm Sphere",
	"ignis_plus_1": "+1 Ignis",
	"ignis_plus_2": "+2 Ignis",
	"ignis_plus_3": "+3 Ignis",
	"ignis_plus_4": "+4 Ignis",
	"ignis_plus_5": "+5 Ignis",
	"ignis_plus_6": "+6 Ignis",
}

const MATERIAL_COLORS = {
	"Comet": Color(0.4, 0.7, 1.0),
	"Wyrm_Sphere": Color(0.7, 0.3, 0.9),
	"ignis_plus_1": Color(1.0, 0.6, 0.2),
	"ignis_plus_2": Color(1.0, 0.5, 0.1),
	"ignis_plus_3": Color(1.0, 0.4, 0.05),
	"ignis_plus_4": Color(1.0, 0.3, 0.0),
	"ignis_plus_5": Color(0.9, 0.2, 0.0),
	"ignis_plus_6": Color(0.8, 0.1, 0.0),
}

# ─── Quality Colors ───
const QUALITY_COLORS = {
	"Normal": Color.WHITE,
	"Tempered": Color(0.910, 0.788, 0.608),   # Warm bronze
	"Infused": Color(0.784, 0.816, 0.863),     # Silver
	"Brilliant": Color(0.659, 0.847, 0.941),   # Baby blue
	"Radiant": Color(0.941, 0.722, 0.478),     # Orange
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
	# Desktop responsive: adapt grid columns
	_adapt_for_desktop()

	# Upgrade button
	upgrade_btn.pressed.connect(_on_upgrade_pressed)
	clear_btn.pressed.connect(_on_clear_material)

	# Listen for inventory changes to refresh
	GameManager.inventory_changed.connect(_refresh_picker)
	GameManager.inventory_changed.connect(_refresh_material_palette)
	GameManager.inventory_changed.connect(_refresh_ignis_compose)
	GameManager.inventory_changed.connect(_refresh_scroll_convert)
	GameManager.equipment_changed.connect(_refresh_picker)

	_refresh_picker()
	_refresh_material_palette()
	_refresh_upgrade_panel()
	_refresh_ignis_compose()
	_refresh_scroll_convert()

	# Keep picker slots square
	item_picker_grid.resized.connect(_enforce_square_picker_slots)
	call_deferred("_enforce_square_picker_slots")

func _enforce_square_picker_slots() -> void:
	if item_picker_grid.columns <= 0:
		return
	var grid_w := item_picker_grid.size.x
	var max_w := ScreenHelper.get_content_width() - 48.0
	if grid_w <= 0.0 or grid_w > max_w:
		grid_w = max_w
	if grid_w <= 0.0:
		return
	var sep := item_picker_grid.get_theme_constant("h_separation")
	var cell_w := (grid_w - sep * (item_picker_grid.columns - 1)) / float(item_picker_grid.columns)
	if cell_w <= 0.0:
		return
	for slot in item_picker_grid.get_children():
		slot.custom_minimum_size = Vector2(cell_w, cell_w)

func _adapt_for_desktop() -> void:
	if not ScreenHelper.is_desktop():
		return
	if item_picker_grid:
		item_picker_grid.columns = ScreenHelper.grid_columns(5, 6)
	if material_grid:
		material_grid.columns = ScreenHelper.grid_columns(4, 5)
	if ignis_grid:
		ignis_grid.columns = ScreenHelper.grid_columns(3, 4)
	if scroll_grid:
		scroll_grid.columns = ScreenHelper.grid_columns(2, 3)

# ═══════════════════════════════════════════
# Item Picker
# ═══════════════════════════════════════════

func _refresh_picker() -> void:
	for child in item_picker_grid.get_children():
		child.queue_free()

	# Equipped items first
	for slot_name in GameManager.equipped_items:
		var inst = GameManager.equipped_items[slot_name]
		if inst == null:
			continue
		var item_data = ItemDatabase.resolve_instance(inst)
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
		if item_data == null:
			continue
		if item_data.item_type in ["Arrow", "Material", "Item"]:
			continue
		var slot = _create_picker_slot(item_data, inst, "bag", i)
		item_picker_grid.add_child(slot)

func _create_picker_slot(item_data: ItemData, inst: Dictionary, source: String, bag_idx: int) -> PanelContainer:
	var slot = InventorySlotScene.instantiate()
	slot.suppress_tooltip = true  # Disable tooltip — clicking selects the item for upgrade
	slot.call_deferred("set_item", item_data)

	# Highlight selected
	if not _selected_instance.is_empty() and inst.get("uid", "") == _selected_instance.get("uid", "____"):
		slot.call_deferred("set", "modulate", Color(1.0, 1.0, 0.5, 1.0))

	slot.gui_input.connect(_on_picker_slot_input.bind(inst, source, bag_idx))
	return slot

func _on_picker_slot_input(event: InputEvent, inst: Dictionary, source: String, bag_idx: int) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		_selected_instance = inst
		_selected_source = source
		_selected_bag_index = bag_idx
		_dragged_material_bid = ""
		_auto_mode = UpgradeMode.NONE
		result_message.text = ""
		_refresh_picker()
		_refresh_upgrade_panel()

# ═══════════════════════════════════════════
# Material Palette (draggable material tiles)
# ═══════════════════════════════════════════

# All material bids to show in the palette
const PALETTE_MATERIALS: Array = [
	"Comet", "Wyrm_Sphere",
	"ignis_plus_1", "ignis_plus_2", "ignis_plus_3",
	"ignis_plus_4", "ignis_plus_5", "ignis_plus_6",
]

func _refresh_material_palette() -> void:
	for child in material_grid.get_children():
		child.queue_free()

	for mat_bid in PALETTE_MATERIALS:
		var count = GameManager.get_material_count(mat_bid)
		if count <= 0:
			continue
		var tile = _create_material_tile(mat_bid, count)
		# Highlight the currently selected material
		if mat_bid == _dragged_material_bid:
			tile.modulate = Color(1.0, 1.0, 0.6, 1.0)
		material_grid.add_child(tile)

func _create_material_tile(mat_bid: String, count: int) -> PanelContainer:
	var tile = PanelContainer.new()
	tile.mouse_filter = Control.MOUSE_FILTER_PASS
	tile.custom_minimum_size = Vector2(72, 60)

	var style = StyleBoxFlat.new()
	style.bg_color = MATERIAL_COLORS.get(mat_bid, Color(0.4, 0.4, 0.4))
	style.corner_radius_top_left = 6
	style.corner_radius_top_right = 6
	style.corner_radius_bottom_left = 6
	style.corner_radius_bottom_right = 6
	style.content_margin_left = 4
	style.content_margin_right = 4
	style.content_margin_top = 4
	style.content_margin_bottom = 4
	tile.add_theme_stylebox_override("panel", style)

	var vbox = VBoxContainer.new()
	vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL

	var name_lbl = Label.new()
	name_lbl.text = MATERIAL_DISPLAY_NAMES.get(mat_bid, mat_bid)
	name_lbl.add_theme_font_size_override("font_size", 10)
	name_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	vbox.add_child(name_lbl)

	var count_lbl = Label.new()
	count_lbl.text = "x%d" % count
	count_lbl.add_theme_font_size_override("font_size", 11)
	count_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	count_lbl.add_theme_color_override("font_color", Color(1, 1, 1, 0.8))
	vbox.add_child(count_lbl)

	tile.add_child(vbox)

	# Store the bid as metadata for drag-and-drop
	tile.set_meta("material_bid", mat_bid)

	# Click to select (primary method — works on both desktop and mobile)
	tile.gui_input.connect(_on_material_tile_clicked.bind(mat_bid))

	# Enable dragging as an alternative method
	tile.set_script(_MaterialTileDragScript)
	return tile

func _on_material_tile_clicked(event: InputEvent, mat_bid: String) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		_dragged_material_bid = mat_bid
		_auto_mode = MATERIAL_MODE_MAP.get(mat_bid, UpgradeMode.NONE)
		result_message.text = ""
		_refresh_upgrade_panel()

# ═══════════════════════════════════════════
# Drag-and-Drop: Material Tile → Material Slot
# ═══════════════════════════════════════════

# Small script assigned to each draggable material tile
var _MaterialTileDragScript: GDScript = preload("res://ui/pages/shops/material_tile_drag.gd")

# Called by material_drop_slot.gd when something is dropped on MaterialSlot
func _drop_material(_at_position: Vector2, data: Variant) -> void:
	if data is Dictionary and data.has("material_bid"):
		_dragged_material_bid = data["material_bid"]
		_auto_mode = MATERIAL_MODE_MAP.get(_dragged_material_bid, UpgradeMode.NONE)
		result_message.text = ""
		_refresh_upgrade_panel()

func _enter_tree() -> void:
	# Set reference so the drop slot script can call back to us
	call_deferred("_setup_drop_target")

func _setup_drop_target() -> void:
	material_slot.set_meta("_artisan", self)

# ═══════════════════════════════════════════
# Upgrade Panel Refresh
# ═══════════════════════════════════════════

func _refresh_upgrade_panel() -> void:
	_preview_item = null
	clear_btn.visible = not _dragged_material_bid.is_empty()

	if _selected_instance.is_empty():
		source_label.text = "Source"
		source_label.visible = true
		material_label.text = "Drop\nHere"
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

	# No material dropped yet?
	if _dragged_material_bid.is_empty() or _auto_mode == UpgradeMode.NONE:
		material_label.text = "Drag\nmaterial"
		material_label.add_theme_font_size_override("font_size", 10)
		_update_slot_color(material_slot, Color(0.5, 0.5, 0.5))
		result_label.text = "?"
		_update_slot_color(result_slot, Color(0.3, 0.3, 0.3))
		info_label.text = "Drag a material onto the upgrade slot."
		success_label.text = ""
		upgrade_btn.disabled = true
		return

	# Material was dropped — show it
	var mat_name = MATERIAL_DISPLAY_NAMES.get(_dragged_material_bid, _dragged_material_bid)
	material_label.text = "%s\nx1" % mat_name
	material_label.add_theme_font_size_override("font_size", 10)
	_update_slot_color(material_slot, MATERIAL_COLORS.get(_dragged_material_bid, Color(0.5, 0.5, 0.5)))

	# Mode-specific preview
	match _auto_mode:
		UpgradeMode.LEVEL:
			_refresh_level_preview(item_data)
		UpgradeMode.QUALITY:
			_refresh_quality_preview(item_data)
		UpgradeMode.IGNIS:
			_refresh_ignis_preview(item_data)

func _refresh_level_preview(item_data: ItemData) -> void:
	var can_upgrade = ItemDatabase.can_level_upgrade(_selected_instance)
	if not can_upgrade:
		info_label.text = "%s is already at max level." % item_data.display_name
		success_label.text = ""
		result_label.text = "Max"
		upgrade_btn.disabled = true
		_update_slot_color(result_slot, Color(0.3, 0.3, 0.3))
		return

	_preview_item = ItemDatabase.preview_level_upgrade(_selected_instance)
	if _preview_item:
		result_label.text = _preview_item.display_name
		result_label.add_theme_font_size_override("font_size", 10)
		var rq_color = QUALITY_COLORS.get(_preview_item.quality.capitalize(), Color.WHITE)
		_update_slot_color(result_slot, rq_color)
	else:
		result_label.text = "?"
		_update_slot_color(result_slot, Color(0.3, 0.3, 0.3))

	var chance = _get_level_success_chance(item_data.level_req)
	success_label.text = "Success Rate: %d%%" % int(chance * 100)
	info_label.text = "Upgrade %s (Lv%d) to Lv%d. Uses 1 Comet." % [
		item_data.display_name, item_data.level_req,
		_preview_item.level_req if _preview_item else 0
	]
	upgrade_btn.disabled = false
	upgrade_btn.text = "Upgrade Level"

func _refresh_quality_preview(item_data: ItemData) -> void:
	var can_upgrade = ItemDatabase.can_quality_upgrade(_selected_instance)
	if not can_upgrade:
		info_label.text = "%s is already Radiant quality." % item_data.display_name
		success_label.text = ""
		result_label.text = "Max"
		upgrade_btn.disabled = true
		_update_slot_color(result_slot, Color(0.3, 0.3, 0.3))
		return

	_preview_item = ItemDatabase.preview_quality_upgrade(_selected_instance)
	if _preview_item:
		result_label.text = _preview_item.display_name
		result_label.add_theme_font_size_override("font_size", 10)
		var rq_color = QUALITY_COLORS.get(_preview_item.quality.capitalize(), Color.WHITE)
		_update_slot_color(result_slot, rq_color)
	else:
		result_label.text = "?"
		_update_slot_color(result_slot, Color(0.3, 0.3, 0.3))

	var next_q = ItemDatabase.get_next_quality(item_data.quality)
	var chance = _get_quality_success_chance(next_q)
	success_label.text = "Success Rate: %d%%" % int(chance * 100)
	info_label.text = "Upgrade %s from %s to %s. Uses 1 Wyrm Sphere." % [
		item_data.display_name, item_data.quality, next_q
	]
	upgrade_btn.disabled = false
	upgrade_btn.text = "Upgrade Quality"

func _refresh_ignis_preview(item_data: ItemData) -> void:
	var current_plus = int(_selected_instance.get("plus", 0))
	# Determine what ignis level is being applied
	var ignis_level = _get_ignis_level(_dragged_material_bid)
	var new_plus = current_plus + ignis_level

	if current_plus >= 15:
		info_label.text = "%s is already at max Ignis+ level." % item_data.display_name
		success_label.text = ""
		result_label.text = "Max"
		upgrade_btn.disabled = true
		_update_slot_color(result_slot, Color(0.3, 0.3, 0.3))
		return

	result_label.text = "%s\n+%d" % [item_data.display_name, new_plus]
	result_label.add_theme_font_size_override("font_size", 10)
	var rq_color = QUALITY_COLORS.get(item_data.quality.capitalize(), Color.WHITE)
	_update_slot_color(result_slot, rq_color)

	success_label.text = "Guaranteed"
	info_label.text = "Apply %s to %s. Current +%d → +%d." % [
		MATERIAL_DISPLAY_NAMES.get(_dragged_material_bid, "Ignis"),
		item_data.display_name, current_plus, new_plus
	]
	upgrade_btn.disabled = false
	upgrade_btn.text = "Apply Ignis"

func _get_ignis_level(bid: String) -> int:
	match bid:
		"ignis_plus_1": return 1
		"ignis_plus_2": return 2
		"ignis_plus_3": return 3
		"ignis_plus_4": return 4
		"ignis_plus_5": return 5
		"ignis_plus_6": return 6
	return 0

# ═══════════════════════════════════════════
# Clear Material
# ═══════════════════════════════════════════

func _on_clear_material() -> void:
	_dragged_material_bid = ""
	_auto_mode = UpgradeMode.NONE
	result_message.text = ""
	_refresh_upgrade_panel()

# ═══════════════════════════════════════════
# Upgrade Execution
# ═══════════════════════════════════════════

func _on_upgrade_pressed() -> void:
	if _selected_instance.is_empty() or _dragged_material_bid.is_empty():
		return

	match _auto_mode:
		UpgradeMode.LEVEL:
			_execute_level_upgrade()
		UpgradeMode.QUALITY:
			_execute_quality_upgrade()
		UpgradeMode.IGNIS:
			_execute_ignis_upgrade()

func _execute_level_upgrade() -> void:
	if not ItemDatabase.can_level_upgrade(_selected_instance):
		return

	# Consume 1 Comet from inventory
	if not GameManager.consume_material("Comet"):
		result_message.text = "No Comets available!"
		result_message.add_theme_color_override("font_color", Color(1.0, 0.3, 0.3))
		return

	var item_data = ItemDatabase.resolve_instance(_selected_instance)
	var chance = _get_level_success_chance(item_data.level_req)
	var roll = randf()

	if roll <= chance:
		var next_bid = ItemDatabase.get_next_level_base_id(_selected_instance.get("bid", ""))
		_selected_instance["bid"] = next_bid
		var new_item = ItemDatabase.resolve_instance(_selected_instance)
		_selected_instance["dura"] = new_item.stats.get("MaxDura", 0)

		if randf() < (1.0 / 400.0):
			var skt = _selected_instance.get("skt", [])
			skt.append(null)
			_selected_instance["skt"] = skt
			result_message.text = "SUCCESS! Upgraded to %s + gained a socket!" % new_item.display_name
		else:
			result_message.text = "SUCCESS! Upgraded to %s" % new_item.display_name
		result_message.add_theme_color_override("font_color", Color(0.3, 1.0, 0.3))
	else:
		result_message.text = "FAILED. The Comet was consumed."
		result_message.add_theme_color_override("font_color", Color(1.0, 0.3, 0.3))

	_dragged_material_bid = ""
	_auto_mode = UpgradeMode.NONE
	_finalize_upgrade()

func _execute_quality_upgrade() -> void:
	if not ItemDatabase.can_quality_upgrade(_selected_instance):
		return

	if not GameManager.consume_material("Wyrm_Sphere"):
		result_message.text = "No Wyrm Spheres available!"
		result_message.add_theme_color_override("font_color", Color(1.0, 0.3, 0.3))
		return

	var item_data = ItemDatabase.resolve_instance(_selected_instance)
	var next_q = ItemDatabase.get_next_quality(item_data.quality)
	var chance = _get_quality_success_chance(next_q)
	var roll = randf()

	if roll <= chance:
		_selected_instance["q"] = next_q
		var new_item = ItemDatabase.resolve_instance(_selected_instance)
		_selected_instance["dura"] = new_item.stats.get("MaxDura", 0)

		if randf() < (1.0 / 100.0):
			var skt = _selected_instance.get("skt", [])
			skt.append(null)
			_selected_instance["skt"] = skt
			result_message.text = "SUCCESS! Upgraded to %s + gained a socket!" % new_item.display_name
		else:
			result_message.text = "SUCCESS! Upgraded to %s" % new_item.display_name
		result_message.add_theme_color_override("font_color", Color(0.3, 1.0, 0.3))
	else:
		result_message.text = "FAILED. The Wyrm Sphere was consumed."
		result_message.add_theme_color_override("font_color", Color(1.0, 0.3, 0.3))

	_dragged_material_bid = ""
	_auto_mode = UpgradeMode.NONE
	_finalize_upgrade()

func _execute_ignis_upgrade() -> void:
	var ignis_level = _get_ignis_level(_dragged_material_bid)
	if ignis_level <= 0:
		return

	# Consume 1 of the ignis material
	if not GameManager.consume_material(_dragged_material_bid):
		result_message.text = "No %s available!" % MATERIAL_DISPLAY_NAMES.get(_dragged_material_bid, "Ignis")
		result_message.add_theme_color_override("font_color", Color(1.0, 0.3, 0.3))
		return

	var current_plus = int(_selected_instance.get("plus", 0))
	_selected_instance["plus"] = current_plus + ignis_level
	result_message.text = "SUCCESS! Applied %s. Now +%d" % [
		MATERIAL_DISPLAY_NAMES.get(_dragged_material_bid, "Ignis"),
		_selected_instance["plus"]
	]
	result_message.add_theme_color_override("font_color", Color(1.0, 0.7, 0.2))

	_dragged_material_bid = ""
	_auto_mode = UpgradeMode.NONE
	_finalize_upgrade()

func _finalize_upgrade() -> void:
	GameManager.equipment_changed.emit()
	GameManager.inventory_changed.emit()
	GameManager.sync_inventory_to_server()
	_refresh_picker()
	_refresh_material_palette()
	_refresh_upgrade_panel()

# ═══════════════════════════════════════════
# Ignis Composition: 3x +N → 1x +(N+1)
# ═══════════════════════════════════════════

const IGNIS_TIERS: Array = [
	"ignis_plus_1", "ignis_plus_2", "ignis_plus_3",
	"ignis_plus_4", "ignis_plus_5"
]  # +5 can compose into +6 (max composable input)

func _refresh_ignis_compose() -> void:
	for child in ignis_grid.get_children():
		child.queue_free()
	compose_message.text = ""

	for tier_bid in IGNIS_TIERS:
		var count = GameManager.get_material_count(tier_bid)
		var tier_name = MATERIAL_DISPLAY_NAMES.get(tier_bid, tier_bid)
		var can_compose = count >= 3

		var btn = Button.new()
		btn.custom_minimum_size = Vector2(0, 44)
		btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		btn.text = "%s (%d)" % [tier_name, count]
		btn.disabled = not can_compose
		btn.pressed.connect(_on_compose_ignis.bind(tier_bid))

		if can_compose:
			btn.tooltip_text = "Combine 3x %s into 1x %s" % [
				tier_name, MATERIAL_DISPLAY_NAMES.get(_next_ignis(tier_bid), "?")
			]

		ignis_grid.add_child(btn)

func _next_ignis(bid: String) -> String:
	var idx = IGNIS_TIERS.find(bid)
	if idx >= 0 and idx < IGNIS_TIERS.size() - 1:
		return IGNIS_TIERS[idx + 1]
	elif bid == "ignis_plus_5":
		return "ignis_plus_6"
	return ""

func _on_compose_ignis(tier_bid: String) -> void:
	var next_bid = _next_ignis(tier_bid)
	if next_bid.is_empty():
		compose_message.text = "Cannot compose this tier further."
		compose_message.add_theme_color_override("font_color", Color(1.0, 0.3, 0.3))
		return

	if not GameManager.consume_material(tier_bid, 3):
		compose_message.text = "Not enough materials (need 3)."
		compose_message.add_theme_color_override("font_color", Color(1.0, 0.3, 0.3))
		return

	# Add 1x of the next tier
	var instance = {
		"uid": "m_%s" % str(randi()),
		"bid": next_bid,
		"q": "Normal",
		"plus": 0,
		"skt": [],
		"ench": {},
		"dura": 0
	}
	GameManager.add_to_bag(instance)

	compose_message.text = "Composed 3x %s into 1x %s!" % [
		MATERIAL_DISPLAY_NAMES.get(tier_bid, tier_bid),
		MATERIAL_DISPLAY_NAMES.get(next_bid, next_bid)
	]
	compose_message.add_theme_color_override("font_color", Color(1.0, 0.7, 0.2))

	GameManager.inventory_changed.emit()
	GameManager.sync_inventory_to_server()

# ═══════════════════════════════════════════
# Scroll Conversion: 10 singles ↔ 1 scroll
# ═══════════════════════════════════════════

const SCROLL_PAIRS: Array = [
	{"single": "Comet", "scroll": "Comet_Scroll", "name": "Comet"},
	{"single": "Wyrm_Sphere", "scroll": "Wyrm_Sphere_Scroll", "name": "Wyrm Sphere"},
]

func _refresh_scroll_convert() -> void:
	for child in scroll_grid.get_children():
		child.queue_free()
	convert_message.text = ""

	for pair in SCROLL_PAIRS:
		var single_count = GameManager.get_material_count(pair["single"])
		var scroll_count = GameManager.get_material_count(pair["scroll"])

		# Compress button: 10 singles → 1 scroll
		var compress_btn = Button.new()
		compress_btn.custom_minimum_size = Vector2(0, 44)
		compress_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		compress_btn.text = "10 %s → 1 Scroll (%d)" % [pair["name"], single_count]
		compress_btn.disabled = single_count < 10
		compress_btn.pressed.connect(_on_compress_scroll.bind(pair["single"], pair["scroll"], pair["name"]))
		scroll_grid.add_child(compress_btn)

		# Expand button: 1 scroll → 10 singles
		var expand_btn = Button.new()
		expand_btn.custom_minimum_size = Vector2(0, 44)
		expand_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		expand_btn.text = "1 Scroll → 10 %s (%d)" % [pair["name"], scroll_count]
		expand_btn.disabled = scroll_count < 1
		expand_btn.pressed.connect(_on_expand_scroll.bind(pair["single"], pair["scroll"], pair["name"]))
		scroll_grid.add_child(expand_btn)

func _on_compress_scroll(single_bid: String, scroll_bid: String, mat_name: String) -> void:
	if not GameManager.consume_material(single_bid, 10):
		convert_message.text = "Not enough %ss (need 10)." % mat_name
		convert_message.add_theme_color_override("font_color", Color(1.0, 0.3, 0.3))
		return

	var instance = {
		"uid": "m_%s" % str(randi()),
		"bid": scroll_bid,
		"q": "Normal",
		"plus": 0,
		"skt": [],
		"ench": {},
		"dura": 0
	}
	GameManager.add_to_bag(instance)

	convert_message.text = "Compressed 10 %ss into 1 %s Scroll!" % [mat_name, mat_name]
	convert_message.add_theme_color_override("font_color", Color(0.3, 1.0, 0.3))

	GameManager.inventory_changed.emit()
	GameManager.sync_inventory_to_server()

func _on_expand_scroll(single_bid: String, scroll_bid: String, mat_name: String) -> void:
	if not GameManager.consume_material(scroll_bid):
		convert_message.text = "No %s Scroll available." % mat_name
		convert_message.add_theme_color_override("font_color", Color(1.0, 0.3, 0.3))
		return

	for i in range(10):
		var instance = {
			"uid": "m_%s" % str(randi()),
			"bid": single_bid,
			"q": "Normal",
			"plus": 0,
			"skt": [],
			"ench": {},
			"dura": 0
		}
		GameManager.add_to_bag(instance)

	convert_message.text = "Expanded 1 %s Scroll into 10 %ss!" % [mat_name, mat_name]
	convert_message.add_theme_color_override("font_color", Color(0.3, 1.0, 0.3))

	GameManager.inventory_changed.emit()
	GameManager.sync_inventory_to_server()

# ─── Utility ───

func _update_slot_color(slot: PanelContainer, color: Color) -> void:
	slot.self_modulate = color
