extends Node2D

var coins: int = 0

var drops = [
	{"name": "Banana", "value": 1, "weight": 50.0, "amount_found": 0, "unlocked": true, "req_item": "", "req_amount": 0, "icon": "res://Sprites/BananaSprite.png"},
	{"name": "Can", "value": 2, "weight": 30.0, "amount_found": 0, "unlocked": false, "req_item": "Banana", "req_amount": 100, "icon": "res://Sprites/CanSprite.png"},
	{"name": "Pizza", "value": 5, "weight": 12.0, "amount_found": 0, "unlocked": false, "req_item": "Can", "req_amount": 50, "icon": "res://Sprites/PizzaSprite.png"},
	{"name": "Donut", "value": 10, "weight": 5.0, "amount_found": 0, "unlocked": false, "req_item": "Pizza", "req_amount": 10, "icon": "res://Sprites/DonutSprite.png"},
	{"name": "Phone", "value": 50, "weight": 2.5, "amount_found": 0, "unlocked": false, "req_item": "Donut", "req_amount": 5, "icon": "res://Sprites/PhoneSprite.png"},
	{"name": "Ring", "value": 250, "weight": 0.5, "amount_found": 0, "unlocked": false, "req_item": "Phone", "req_amount": 2, "icon": "res://Sprites/RingSprite.png"}
]

func _ready():
	randomize()
	var click_mask = BitMap.new()
	click_mask.create_from_image_alpha($TrashcanButton.texture_normal.get_image())
	$TrashcanButton.texture_click_mask = click_mask
	update_unlock_ui()

func _on_trashcan_button_pressed():
	var dropped_item = get_random_drop()
	
	coins += dropped_item["value"]
	$CoinDisplay/CoinCounter.text = str(coins)
	dropped_item["amount_found"] += 1
	
	check_for_unlocks(dropped_item)
	update_unlock_ui()
	add_recent_item(dropped_item)

func get_random_drop() -> Dictionary:
	var available_drops = []
	var total_weight = 0.0
	for item in drops:
		if item["unlocked"]:
			available_drops.append(item)
			total_weight += item["weight"]
	var roll = randf_range(0.0, total_weight)
	var cumulative_chance = 0.0
	for item in available_drops:
		cumulative_chance += item["weight"]
		if roll <= cumulative_chance:
			return item
	return available_drops[0]

func check_for_unlocks(last_found_item: Dictionary):
	for item in drops:
		if not item["unlocked"] and item["req_item"] == last_found_item["name"]:
			if last_found_item["amount_found"] >= item["req_amount"]:
				item["unlocked"] = true

func update_unlock_ui():
	var next_item = null
	for item in drops:
		if not item["unlocked"]:
			next_item = item
			break
			
	if next_item != null:
		var current_amount = 0
		for item in drops:
			if item["name"] == next_item["req_item"]:
				current_amount = item["amount_found"]
				break
				
		%UnlockLabel.text = "Next item: " + next_item["name"] + "  (" + str(current_amount) + " / " + str(next_item["req_amount"]) + ")"
		%UnlockProgressBar.max_value = next_item["req_amount"]
		%UnlockProgressBar.value = current_amount
		%UnlockProgressBar.visible = true
		
		# Laad het plaatje in
		%NextItemIcon.texture = load(next_item["icon"])
		%NextItemIcon.visible = true
	else:
		%UnlockLabel.text = "All items unlocked!"
		%UnlockProgressBar.visible = false
		%NextItemIcon.visible = false

func add_recent_item(item: Dictionary):
	var item_box = VBoxContainer.new()
	
	var icon = TextureRect.new()
	icon.texture = load(item["icon"])
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.custom_minimum_size = Vector2(48, 48)
	
	var value_label = Label.new()
	value_label.text = "+" + str(item["value"])
	value_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	
	item_box.add_child(icon)
	item_box.add_child(value_label)
	
	%RecentItemsContainer.add_child(item_box)
	
	if %RecentItemsContainer.get_child_count() > 5:
		var oldest_item = %RecentItemsContainer.get_child(0)
		oldest_item.queue_free()
