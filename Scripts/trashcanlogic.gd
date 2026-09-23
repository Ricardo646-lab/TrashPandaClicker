extends Node2D

var coins: int = 0

# _ready is called automatically once when the game starts
func _ready():
	# Create a new empty bitmap mask
	var click_mask = BitMap.new()
	
	# Scan the image to find the non-transparent pixels
	click_mask.create_from_image_alpha($TrashcanButton.texture_normal.get_image())
	
	# Apply the generated mask to the button's click mask property
	$TrashcanButton.texture_click_mask = click_mask

func _on_trashcan_button_pressed():
	# Increase the coin count by 1 per click
	coins += 1
	
	# Update the text of the CoinCounter label with the new amount
	$CoinDisplay/CoinCounter.text = str(coins)
