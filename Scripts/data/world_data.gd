class_name WorldData
extends Resource

# A world (level). Its background is drawn in code (Scenery.background).

@export var id := ""
@export var name := ""
## Coins needed to travel here.
@export var cost := 0.0
## The items you can find here.
@export var items: Array[ItemData] = []
