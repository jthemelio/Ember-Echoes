# lady_luck_shop.gd — Lady Luck gacha: pay first, pick chest, all 9 reveal
extends MarginContainer

# ─── Constants ───
const ECHO_COST: int = 50
const CHEST_COUNT: int = 9
const FLIP_DELAY: float = 0.15  # Seconds between each chest flip

# ─── Chest styling ───
const CHEST_LOCKED_COLOR  := Color(0.30, 0.30, 0.35)  # Before payment
const CHEST_READY_COLOR   := Color(0.40, 0.35, 0.50)  # After payment, pick one
const CHEST_CHOSEN_COLOR  := Color(0.85, 0.65, 0.15)  # The chest YOU picked (gold)
const CHEST_OTHER_COLOR   := Color(0.45, 0.45, 0.50)  # Other chests after reveal
const CHEST_REVEAL_COLOR  := Color(0.55, 0.55, 0.60)  # During flip animation

# ─── State Machine ───
enum Phase { IDLE, PAYING, PICKING, REVEALING, DONE }
var _phase: int = Phase.IDLE

# ─── UI References ───
@onready var ticket_value: Label = $ScrollContent/ContentVBox/BalanceCard/Margin/VBox/TicketRow/TicketValue
@onready var echo_value: Label = $ScrollContent/ContentVBox/BalanceCard/Margin/VBox/EchoRow/EchoValue
@onready var timer_value: Label = $ScrollContent/ContentVBox/BalanceCard/Margin/VBox/TimerRow/TimerValue
@onready var chest_grid: GridContainer = $ScrollContent/ContentVBox/ChestCard/Margin/VBox/ChestGrid
@onready var chest_label: Label = $ScrollContent/ContentVBox/ChestCard/Margin/VBox/ChestLabel
@onready var free_roll_btn: Button = $ScrollContent/ContentVBox/PaymentCard/Margin/VBox/FreeRollBtn
@onready var ticket_btn: Button = $ScrollContent/ContentVBox/PaymentCard/Margin/VBox/TicketBtn
@onready var echo_btn: Button = $ScrollContent/ContentVBox/PaymentCard/Margin/VBox/EchoBtn
@onready var result_card: PanelContainer = $ScrollContent/ContentVBox/ResultCard
@onready var result_title: Label = $ScrollContent/ContentVBox/ResultCard/Margin/VBox/ResultTitle
@onready var reward_name_label: Label = $ScrollContent/ContentVBox/ResultCard/Margin/VBox/RewardName
@onready var reward_desc: Label = $ScrollContent/ContentVBox/ResultCard/Margin/VBox/RewardDesc
@onready var pet_bonus_label: Label = $ScrollContent/ContentVBox/ResultCard/Margin/VBox/PetBonusLabel
@onready var roll_again_btn: Button = $ScrollContent/ContentVBox/ResultCard/Margin/VBox/RollAgainBtn

# ─── State ───
var _free_roll_available: bool = false
var _ms_until_free: float = 0.0
var _lt_balance: int = 0
var _et_balance: int = 0
var _status_loaded: bool = false
var _has_pending: bool = false  # Server has unclaimed roll

var _pending_rewards: Array = []  # Array of 9 reward dicts (populated after claim)
var _chosen_index: int = -1

# ─── Lifecycle ───

func _ready() -> void:
	free_roll_btn.pressed.connect(_on_free_roll_pressed)
	ticket_btn.pressed.connect(_on_ticket_pressed)
	echo_btn.pressed.connect(_on_echo_pressed)
	roll_again_btn.pressed.connect(_on_roll_again_pressed)

	for i in range(chest_grid.get_child_count()):
		var chest = chest_grid.get_child(i)
		chest.gui_input.connect(_on_chest_input.bind(i))

	_set_phase(Phase.IDLE)
	_fetch_status()

func _process(delta: float) -> void:
	if not _status_loaded or _free_roll_available:
		return
	_ms_until_free -= delta * 1000.0
	if _ms_until_free <= 0:
		_ms_until_free = 0
		_free_roll_available = true
		_update_buttons()
	_update_timer_display()

# ─── Phase Management ───

func _set_phase(new_phase: int) -> void:
	_phase = new_phase
	match _phase:
		Phase.IDLE:
			_reset_chests_locked()
			chest_label.text = "Pay to reveal 9 chests"
			result_card.visible = false
		Phase.PAYING:
			chest_label.text = "Processing payment..."
		Phase.PICKING:
			_set_chests_ready()
			chest_label.text = "Pick a chest!"
		Phase.REVEALING:
			chest_label.text = "Revealing..."
		Phase.DONE:
			pass  # Result card handles display
	_update_buttons()

# ─── Server Communication ───

func _fetch_status() -> void:
	PlayFabManager.client.execute_cloud_script("getLadyLuckStatus", {}, func(result):
		var fn = result.get("data", {}).get("FunctionResult", {})
		if fn is Dictionary and fn.get("success", false):
			_free_roll_available = fn.get("freeRollAvailable", false)
			_ms_until_free = float(fn.get("msUntilFree", 0))
			_lt_balance = int(fn.get("lotteryTickets", 0))
			var currencies = fn.get("currencies", {})
			_et_balance = int(currencies.get("ET", 0))
			for key in currencies:
				GameManager.active_user_currencies[key] = int(currencies[key])
			_has_pending = fn.get("hasPending", false)
		else:
			print("LadyLuck: Failed to fetch status, using defaults")
			_free_roll_available = true
			_lt_balance = 0
			_et_balance = int(GameManager.active_user_currencies.get("ET", 0))

		_status_loaded = true
		_update_balances()
		_update_timer_display()

		# If there is a pending unclaimed roll, go straight to picking
		if _has_pending:
			_set_phase(Phase.PICKING)
		else:
			_set_phase(Phase.IDLE)
	)

func _pay(payment_method: String) -> void:
	if _phase != Phase.IDLE:
		return
	_set_phase(Phase.PAYING)

	var params = {"paymentMethod": payment_method}
	PlayFabManager.client.execute_cloud_script("ladyLuckRoll", params, func(result):
		var fn = result.get("data", {}).get("FunctionResult", {})

		if not fn is Dictionary or not fn.get("success", false):
			var error = "Payment failed"
			if fn is Dictionary:
				error = fn.get("error", "Unknown error")
			chest_label.text = error
			_set_phase(Phase.IDLE)
			return

		# Update balances from response
		_free_roll_available = fn.get("freeRollAvailable", false)
		_ms_until_free = float(fn.get("msUntilFree", 0))
		_lt_balance = int(fn.get("lotteryTickets", 0))
		var currencies = fn.get("currencies", {})
		_et_balance = int(currencies.get("ET", 0))
		for key in currencies:
			GameManager.active_user_currencies[key] = int(currencies[key])
		_update_balances()
		_update_timer_display()

		# Payment succeeded — 9 rewards stored on server, move to picking
		_set_phase(Phase.PICKING)
	)

func _claim(chosen_idx: int) -> void:
	if _phase != Phase.PICKING:
		return
	_chosen_index = chosen_idx
	_set_phase(Phase.REVEALING)

	# Highlight the chosen chest immediately
	_style_chest(chest_grid.get_child(chosen_idx), CHEST_CHOSEN_COLOR)
	var chosen_lbl = chest_grid.get_child(chosen_idx).get_child(0) as Label
	if chosen_lbl:
		chosen_lbl.text = "..."

	var params = {"chosenIndex": chosen_idx}
	PlayFabManager.client.execute_cloud_script("ladyLuckClaim", params, func(result):
		var fn = result.get("data", {}).get("FunctionResult", {})

		if not fn is Dictionary or not fn.get("success", false):
			var error = "Claim failed"
			if fn is Dictionary:
				error = fn.get("error", "Unknown error")
			chest_label.text = error
			_set_phase(Phase.IDLE)
			return

		# Parse server response
		_pending_rewards = fn.get("rewards", [])
		var chosen_reward = fn.get("chosenReward", {})

		# Update balances
		_free_roll_available = fn.get("freeRollAvailable", false)
		_ms_until_free = float(fn.get("msUntilFree", 0))
		_lt_balance = int(fn.get("lotteryTickets", 0))
		var currencies = fn.get("currencies", {})
		_et_balance = int(currencies.get("ET", 0))
		for key in currencies:
			GameManager.active_user_currencies[key] = int(currencies[key])
		_update_balances()
		_update_timer_display()

		# Process the chosen reward (grant items/equipment locally)
		_process_reward(chosen_reward)

		# Lucky pet
		var lucky_pet = fn.get("luckyPet", null)
		if lucky_pet != null and lucky_pet is String and lucky_pet != "":
			var ach_mgr = get_node_or_null("/root/AchievementManager")
			if ach_mgr and not ach_mgr.pets_obtained.has(lucky_pet):
				ach_mgr.pets_obtained[lucky_pet] = true
				ach_mgr.pet_obtained.emit(lucky_pet)
				print("LadyLuck: LUCKY PET! %s" % lucky_pet)

		# Animate the flip reveal
		_animate_reveal(chosen_reward, lucky_pet)
	)

# ─── Flip Animation ───

func _animate_reveal(chosen_reward: Dictionary, lucky_pet) -> void:
	# Flip each chest one by one with a short delay
	for i in range(CHEST_COUNT):
		if i < _pending_rewards.size():
			var timer = get_tree().create_timer(FLIP_DELAY * i)
			timer.timeout.connect(_flip_chest.bind(i))

	# After all chests flip, show the result card
	var total_delay = FLIP_DELAY * CHEST_COUNT + 0.3
	var final_timer = get_tree().create_timer(total_delay)
	final_timer.timeout.connect(_on_reveal_complete.bind(chosen_reward, lucky_pet))

func _flip_chest(index: int) -> void:
	if index >= _pending_rewards.size():
		return
	var reward = _pending_rewards[index]
	var chest = chest_grid.get_child(index)
	var lbl = chest.get_child(0) as Label
	if not lbl:
		return

	# Set the label to a short reward name
	lbl.text = _short_name(reward)
	lbl.add_theme_font_size_override("font_size", 10)
	lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART

	if index == _chosen_index:
		_style_chest(chest, CHEST_CHOSEN_COLOR)
	else:
		_style_chest(chest, CHEST_OTHER_COLOR)

func _on_reveal_complete(chosen_reward: Dictionary, lucky_pet) -> void:
	_set_phase(Phase.DONE)
	_show_result(chosen_reward, lucky_pet)

# ─── Reward Processing ───
# Gold amounts for money bag items (looked up by id)
const MONEY_BAG_GOLD: Dictionary = {
	"money_bag_1": 500,       "money_bag_2": 1500,
	"money_bag_3": 5000,      "money_bag_4": 15000,
	"money_bag_5": 50000,     "money_bag_6": 100000,
	"money_bag_7": 250000,    "money_bag_8": 500000,
	"money_bag_9": 1000000,   "money_bag_10": 5000000,
}

func _process_reward(reward: Dictionary) -> void:
	var reward_id = reward.get("id", "")

	# All rewards are type:"item" now — handle by id category
	if reward_id.begins_with("money_bag_"):
		# Money bags → add as inventory item (player must right-click to claim gold)
		var gold_amount = MONEY_BAG_GOLD.get(reward_id, 0)
		var bag_instance = {
			"uid": _generate_uid(),
			"bid": reward_id,
			"q": "Normal",
			"plus": 0,
			"skt": [],
			"ench": {},
			"dura": 0,
			"gold": gold_amount,  # Gold amount stored for claiming
		}
		GameManager.active_user_inventory.append(bag_instance)
		GameManager.inventory_changed.emit()
		GameManager.sync_inventory_to_server()
		print("LadyLuck: Won %s (%d gold) — added to inventory" % [reward.get("name", ""), gold_amount])
		return

	# Build inventory instance for all other items
	var quality = reward.get("quality", "Normal")
	var sockets = int(reward.get("sockets", 0))
	var skt_array: Array = []
	for i in range(sockets):
		skt_array.append(null)

	var instance = {
		"uid": _generate_uid(),
		"bid": reward_id,
		"q": quality,
		"plus": 0,
		"skt": skt_array,
		"ench": {},
		"dura": 0
	}

	# Equipment (has sockets/level) — resolve durability
	if sockets > 0 or reward.has("level"):
		instance["dura"] = 100
		var item_data = ItemDatabase.resolve_instance(instance)
		if item_data:
			instance["dura"] = item_data.stats.get("MaxDura", 100)

	GameManager.active_user_inventory.append(instance)
	GameManager.inventory_changed.emit()
	GameManager.sync_inventory_to_server()
	print("LadyLuck: Won item %s (q:%s skt:%d)" % [reward.get("name", reward_id), quality, sockets])

# ─── Result Display ───

func _show_result(reward: Dictionary, lucky_pet) -> void:
	result_card.visible = true
	var reward_id = reward.get("id", "")
	var r_name = reward.get("name", "Unknown Reward")

	result_title.text = "You Won!"
	result_title.add_theme_color_override("font_color", Color(1.0, 0.84, 0.0))
	reward_name_label.text = r_name

	# Determine display based on the reward id / properties
	if reward_id.begins_with("money_bag_"):
		var gold = MONEY_BAG_GOLD.get(reward_id, 0)
		reward_desc.text = "%s gold bag added to your inventory! Right-click to claim." % _format_number(gold)
		reward_name_label.add_theme_color_override("font_color", Color(1.0, 0.84, 0.0))
	elif reward.has("sockets") and int(reward.get("sockets", 0)) > 0:
		var quality = reward.get("quality", "Normal")
		var sockets = int(reward.get("sockets", 0))
		reward_desc.text = "%s quality with %d sockets! Added to your inventory." % [quality, sockets]
		reward_name_label.add_theme_color_override("font_color", Color(0.6, 0.2, 0.8))
	elif reward.has("quality") and reward.get("quality", "") != "Normal":
		reward_desc.text = "%s quality item added to your inventory!" % reward.get("quality", "")
		reward_name_label.add_theme_color_override("font_color", Color(0.8, 0.4, 1.0))
	elif reward_id.begins_with("ignis_") or reward_id.begins_with("comet_") or reward_id.begins_with("wyrm_"):
		reward_desc.text = "Upgrade material added to your collection!"
		reward_name_label.add_theme_color_override("font_color", Color(0.4, 0.8, 1.0))
	else:
		reward_desc.text = "A rare item has been added to your inventory!"
		reward_name_label.add_theme_color_override("font_color", Color(0.8, 0.4, 1.0))

	if lucky_pet != null and lucky_pet is String and lucky_pet != "":
		pet_bonus_label.visible = true
		pet_bonus_label.text = "BONUS: Lucky Pet '%s' obtained!" % lucky_pet
		pet_bonus_label.add_theme_color_override("font_color", Color(1.0, 0.4, 0.7))
	else:
		pet_bonus_label.visible = false

# ─── Chest Interaction ───

func _on_chest_input(event: InputEvent, chest_index: int) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		if _phase == Phase.PICKING:
			_claim(chest_index)

# ─── Button Handlers ───

func _on_free_roll_pressed() -> void:
	_pay("free")

func _on_ticket_pressed() -> void:
	_pay("ticket")

func _on_echo_pressed() -> void:
	_pay("echo")

func _on_roll_again_pressed() -> void:
	_pending_rewards.clear()
	_chosen_index = -1
	_has_pending = false
	_set_phase(Phase.IDLE)

# ─── UI Updates ───

func _update_balances() -> void:
	ticket_value.text = str(_lt_balance)
	echo_value.text = str(_et_balance)

func _update_timer_display() -> void:
	if _free_roll_available:
		timer_value.text = "Available!"
		timer_value.add_theme_color_override("font_color", Color(0.3, 1.0, 0.3))
	else:
		var total_sec = int(_ms_until_free / 1000.0)
		var minutes = total_sec / 60
		var seconds = total_sec % 60
		timer_value.text = "%02d:%02d" % [minutes, seconds]
		timer_value.remove_theme_color_override("font_color")

func _update_buttons() -> void:
	# Payment buttons only active during IDLE phase
	var can_pay = _phase == Phase.IDLE and _status_loaded

	free_roll_btn.disabled = not (can_pay and _free_roll_available)
	free_roll_btn.text = "Free Roll" if _free_roll_available else "Free Roll (Cooldown)"

	ticket_btn.disabled = not (can_pay and _lt_balance > 0)
	ticket_btn.text = "Use Lottery Ticket (1 LT)" if _lt_balance > 0 else "No Lottery Tickets"

	echo_btn.disabled = not (can_pay and _et_balance >= ECHO_COST)
	echo_btn.text = "Use Echo Points (%d ET)" % ECHO_COST

# ─── Chest Styling Helpers ───

func _reset_chests_locked() -> void:
	for i in range(chest_grid.get_child_count()):
		var chest = chest_grid.get_child(i)
		_style_chest(chest, CHEST_LOCKED_COLOR)
		var lbl = chest.get_child(0) as Label
		if lbl:
			lbl.text = "?"
			lbl.remove_theme_font_size_override("font_size")

func _set_chests_ready() -> void:
	for i in range(chest_grid.get_child_count()):
		var chest = chest_grid.get_child(i)
		_style_chest(chest, CHEST_READY_COLOR)
		var lbl = chest.get_child(0) as Label
		if lbl:
			lbl.text = "?"
			lbl.remove_theme_font_size_override("font_size")

func _style_chest(chest: PanelContainer, color: Color) -> void:
	var style = StyleBoxFlat.new()
	style.bg_color = color
	style.set_corner_radius_all(8)
	style.content_margin_left = 4
	style.content_margin_right = 4
	style.content_margin_top = 4
	style.content_margin_bottom = 4
	chest.add_theme_stylebox_override("panel", style)

# ─── Helpers ───

func _short_name(reward: Dictionary) -> String:
	var n = reward.get("name", "???")
	# Truncate long names to fit in the chest cell
	if n.length() > 18:
		return n.substr(0, 16) + ".."
	return n

func _generate_uid() -> String:
	return "ll_%d_%d" % [Time.get_unix_time_from_system(), randi() % 99999]

func _format_number(n: int) -> String:
	return GameManager.format_gold(n)

func _currency_display_name(code: String) -> String:
	match code:
		"CM": return "Comets"
		"WS": return "Wyrm Spheres"
		"I1": return "+1 Ignis"
		"I2": return "+2 Ignis"
		"I3": return "+3 Ignis"
		"GD": return "Gold"
		"ET": return "Echo Points"
		"LT": return "Lottery Tickets"
		_: return code
