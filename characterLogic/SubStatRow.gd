extends HBoxContainer

@export var display_name: String = "HP"
@export var current_val: String = "0"
@export var max_val: String = "0"

@onready var label_node = $StatName
@onready var value_node = $StatValue

func _ready():
	# Apply the text from the Inspector
	label_node.text = display_name
	value_node.text = current_val + " / " + max_val

# Call this later from your GameManager logic
func update_hp(current: String, total: String):
	value_node.text = current + " / " + total
