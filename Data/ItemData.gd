extends Resource
class_name ItemData

# Core Identity
@export var instance_id: String = ""
@export var item_id: String = ""
@export var display_name: String = ""

# Categorization
@export var item_class: String = ""
@export var item_type: String = ""
@export var quality: String = "Normal"
@export var level_req: int = 0

# Requirements
@export var str_req: int = 0
@export var dex_req: int = 0
@export var agi_req: int = 0

# Economy
@export var price: int = 0

# Universal Stat Dictionary (drives tooltip and combat calculations)
var stats: Dictionary = {
	"MinAtk": 0, "MaxAtk": 0, "MagicAtk": 0,
	"Def": 0, "MagicDef": 0, "LifeBonus": 0,
	"Speed": 0, "MaxDura": 0, "Dodge": 0
}

# Instance Data
@export var plus_level: int = 0
@export var current_dura: int = 0
@export var sockets: int = 0
@export var amount: int = 1

# Instance Modifications (new: Internal Data inventory system)
var socket_gems: Array = []        # e.g. [null, "FireGem"] -- null = empty socket
var enchantments: Dictionary = {}  # e.g. {"HP": 50, "DmgReduce": 5}

func get_stat(stat_name: String) -> int:
	return stats.get(stat_name, 0)
