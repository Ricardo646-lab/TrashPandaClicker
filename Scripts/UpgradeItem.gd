extends PanelContainer

@export var base_cost: int = 100
@export var cost_multiplier: float = 1.5

var _current_cost: int
var _level: int = 0

var _level_label: Label
var _buy_button: Button
var _main_game = null

var _green_normal_style: StyleBoxFlat
var _green_hover_style: StyleBoxFlat
var _red_style: StyleBoxFlat

func _ready():
	_current_cost = base_cost
	
	_level_label = get_node("ItemRow/LevelLabel")
	_buy_button = get_node("ItemRow/BuyButton")
	
	_main_game = _find_trashcan_main(get_tree().root)
	
	_buy_button.pressed.connect(_on_buy_button_pressed)
	
	_setup_styles()
	_update_ui()

func _setup_styles():
	_green_normal_style = StyleBoxFlat.new()
	_green_normal_style.bg_color = Color("#4CAF50")
	_green_normal_style.set_corner_radius_all(6)
	
	_green_hover_style = StyleBoxFlat.new()
	_green_hover_style.bg_color = Color("#2E7D32")
	_green_hover_style.set_corner_radius_all(6)
	
	_red_style = StyleBoxFlat.new()
	_red_style.bg_color = Color("#E53935")
	_red_style.set_corner_radius_all(6)

func _process(_delta):
	_update_affordability()

func _update_affordability():
	if _main_game == null:
		return
		
	var can_afford = _main_game.get_coins() >= _current_cost
	_buy_button.add_theme_color_override("font_color", Color.WHITE)
	
	if can_afford:
		_buy_button.add_theme_stylebox_override("normal", _green_normal_style)
		_buy_button.add_theme_stylebox_override("hover", _green_hover_style)
		_buy_button.add_theme_stylebox_override("pressed", _green_hover_style)
	else:
		_buy_button.add_theme_stylebox_override("normal", _red_style)
		_buy_button.add_theme_stylebox_override("hover", _red_style)
		_buy_button.add_theme_stylebox_override("pressed", _red_style)

func _on_buy_button_pressed():
	if _main_game == null:
		_main_game = _find_trashcan_main(get_tree().root)
		
	if _main_game == null:
		return
		
	if _main_game.try_spend_coins(_current_cost):
		_level += 1
		_current_cost = int(_current_cost * cost_multiplier)
		_main_game.add_bonus_per_click(1)
		_update_ui()

func _update_ui():
	_level_label.text = "Lv. " + str(_level)
	_buy_button.text = str(_current_cost)

func _find_trashcan_main(start_node):
	if start_node.has_method("try_spend_coins"):
		return start_node
		
	for child in start_node.get_children():
		var found = _find_trashcan_main(child)
		if found != null:
			return found
			
	return null