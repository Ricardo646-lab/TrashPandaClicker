class_name ItemData
extends Resource

# An item the raccoon can dig up. Its picture is drawn in code (Art.item_shapes),
# found by id.

@export var id := ""
@export var name := ""
@export_enum("Common", "Rare", "Epic", "Legendary") var rarity := 0
