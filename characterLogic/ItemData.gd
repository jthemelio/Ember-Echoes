extends Resource
class_name ItemData

# Core Identity
var instance_id: String = ""   
var item_id: String = ""       
var display_name: String = ""

# Categorization
var item_class: String = ""    
var item_type: String = ""          
var quality: String = ""       
var level_req: int = 0

# Requirements
var str_req: int = 0
var dex_req: int = 0
var agi_req: int = 0 

# Economy
var price: int = 0

# Universal Stat Dictionary
var stats: Dictionary = {
	"MinAtk": 0, "MaxAtk": 0, "MagicAtk": 0,
	"Def": 0, "MagicDef": 0, "LifeBonus": 0,
	"Speed": 0, "MaxDura": 0, "Dodge": 0 # Added Dodge
}

# Instance Data (Plus levels and Sockets)
var plus_level: int = 0
var current_dura: int = 0
var sockets: int = 0
var amount: int = 1

func get_stat(stat_name: String) -> int:
	return stats.get(stat_name, 0)
