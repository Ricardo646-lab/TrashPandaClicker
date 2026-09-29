extends Node2D

var coins = 0
var bonus_click_power = 0

var racoon: Area2D
var racoon_animation: AnimatedSprite2D

var time_since_last_click = 0.0
var is_digging = false
var wants_to_keep_digging = false

const DIG_TIMEOUT = 0.5

var drops = [
	{ "name": "Banana", "value": 1, "weight": 100.0, "amount_found": 0, "unlocked": true, "req_item": "", "req_amount": 0, "icon": "res://Sprites/BananaSprite.png" },
	{ "name": "Can", "value": 2, "weight": 25.0, "amount_found": 0, "unlocked": false, "req_item": "Banana", "req_amount": 250, "icon": "res://Sprites/CanSprite.png" },
	{ "name": "Pizza", "value": 5, "weight": 5.0, "amount_found": 0, "unlocked": false, "req_item": "Can", "req_amount": 150, "icon": "res://Sprites/PizzaSprite.png" },
	{ "name": "Donut", "value": 10, "weight": 1.0, "amount_found": 0, "unlocked": false, "req_item": "Pizza", "req_amount": 50, "icon": "res://Sprites/DonutSprite.png" },
	{ "name": "Phone", "value": 50, "weight": 0.2, "amount_found": 0, "unlocked": false, "req_item": "Donut", "req_amount": 20, "icon": "res://Sprites/PhoneSprite.png" },
	{ "name": "Ring", "value": 250, "weight": 0.05, "amount_found": 0, "unlocked": false, "req_item": "Phone", "req_amount": 5, "icon": "res://Sprites/RingSprite.png" }
]

func _ready():
	racoon = get_node("BackgroundLayer/TextureRect/RaccoonCenter/Racoon")
	racoon_animation = get_node("BackgroundLayer/TextureRect/RaccoonCenter/Racoon/AnimatedSprite2D")
	
	racoon.input_event.connect(_on_racoon_input_event)
	racoon_animation.animation_finished.connect(_on_animation_finished)
	
	racoon_animation.play("idle")
	update_unlock_ui()
	
	if has_node("/root/PokiSDK"):
		var poki_sdk = get_node("/root/PokiSDK")
		poki_sdk.call("gameplayStart")
		print("Poki SDK: gameplayStart successfully called.")
	else:
		print("Poki SDK not found (plugin is disabled or not installed).")

func _process(delta):
	if not is_digging:
		return
		
	time_since_last_click += delta
	if time_since_last_click >= DIG_TIMEOUT:
		wants_to_keep_digging = false
		if racoon_animation.animation == "dig_loop":
			racoon_animation.play("dig_end")

func _on_racoon_input_event(_viewport, event, _shape_idx):
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		_on_racoon_clicked()

func _on_racoon_clicked():
	_start_digging()
	var dropped_item = _get_random_drop()
	var items_gained = 1 + bonus_click_power
	dropped_item["amount_found"] += items_gained
	
	coins += dropped_item["value"]
	%CoinCounter.text = str(coins)
	
	_check_for_unlocks(dropped_item)
	update_unlock_ui()
	_add_recent_item(dropped_item)

func _start_digging():
	time_since_last_click = 0.0
	if not is_digging:
		is_digging = true
		wants_to_keep_digging = false
		racoon_animation.play("dig_start")
		return
		
	wants_to_keep_digging = true
	if racoon_animation.animation == "dig_end":
		racoon_animation.play("dig_start")

func _on_animation_finished():
	if racoon_animation.animation == "dig_start":
		if wants_to_keep_digging and time_since_last_click < DIG_TIMEOUT:
			racoon_animation.play("dig_loop")
		else:
			racoon_animation.play("dig_end")
		return
		
	if racoon_animation.animation == "dig_end":
		is_digging = false
		wants_to_keep_digging = false
		racoon_animation.play("idle")

func _get_random_drop():
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

func _check_for_unlocks(last_found_item):
	for item in drops:
		if not item["unlocked"] and item["req_item"] == last_found_item["name"]:
			if last_found_item["amount_found"] >= item["req_amount"]:
				item["unlocked"] = true
				print("Nieuw item unlocked: ", item["name"], "!")

func update_unlock_ui():
	var next_item = null
	for item in drops:
		if not item["unlocked"]:
			next_item = item
			break
			
	var unlock_label = %UnlockLabel
	var unlock_progress_bar = %UnlockProgressBar
	var next_item_icon = %NextItemIcon
	
	if next_item != null:
		var current_amount = 0
		for item in drops:
			if item["name"] == next_item["req_item"]:
				current_amount = item["amount_found"]
				break
				
		unlock_label.text = "Next item: " + next_item["name"] + "  (" + str(current_amount) + " / " + str(next_item["req_amount"]) + ")"
		unlock_progress_bar.max_value = next_item["req_amount"]
		unlock_progress_bar.value = current_amount
		unlock_progress_bar.visible = true
		
		next_item_icon.texture = load(next_item["icon"])
		next_item_icon.visible = true
	else:
		unlock_label.text = "All items unlocked!"
		unlock_progress_bar.visible = false
		next_item_icon.visible = false

func _add_recent_item(item):
	var recent_items_container = %RecentItemsContainer
	
	var item_box = VBoxContainer.new()
	
	var icon = TextureRect.new()
	icon.texture = load(item["icon"])
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.custom_minimum_size = Vector2(48, 48)
	
	var value_label = Label.new()
	value_label.text = "+" + str(item["value"])
	value_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	value_label.add_theme_font_size_override("font_size", 16)
	
	item_box.add_child(icon)
	item_box.add_child(value_label)
	
	recent_items_container.add_child(item_box)
	
	if recent_items_container.get_child_count() > 5:
		var oldest_item = recent_items_container.get_child(0)
		oldest_item.queue_free()

func try_spend_coins(amount: int) -> bool:
	if coins >= amount:
		coins -= amount
		%CoinCounter.text = str(coins)
		return true
	return false

func add_bonus_per_click(amount: int):
	bonus_click_power += amount
	print("New Bonus Per Click: +", bonus_click_power)

func get_coins() -> int:
	return coins