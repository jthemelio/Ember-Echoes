extends Button

# Ensure this path matches your new node hierarchy
@onready var inventory_grid = $"../InventoryGrid"

func _pressed():
	# Standardized pool using your updated quality tiers
	var test_pool = [
		{
			"ItemInstanceId": "bow_test",
			"ItemId": "Sprout_Bow_Normal", 
			"DisplayName": "Sprout Bow",
			"ItemClass": "Weapon",
			"CustomData": {
				"Type": "Bow", 
				"Quality": "Normal", 
				"MinAtk": "10", 
				"MaxAtk": "13",
				"MaxDura": "40" # Added this so Dura doesn't show 0/0
			}
		},
		{
			"ItemInstanceId": "blade_test",
			"ItemId": "Sliver_Blade_Infused", 
			"DisplayName": "Infused Sliver Blade",
			"ItemClass": "Weapon",
			"CustomData": {
				"Type": "Blade", 
				"Quality": "Infused", 
				"MinAtk": "8", 
				"MaxAtk": "12", 
				"PlusLevel": "5",
				"MaxDura": "50"
			}
		}
	]
	
	# Add a random item to the global inventory
	var random_item = test_pool[randi() % test_pool.size()]
	GameManager.active_user_inventory.append(random_item)
	
	# Redraw the grid to show the new item
	inventory_grid.refresh_grid()
