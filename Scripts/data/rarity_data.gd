class_name RarityData
extends Resource

# One rarity tier (common, rare, epic, legendary).

## Text shown when you find one ("RARE!"). Empty for common items.
@export var name := ""
@export var color := Color.WHITE
## Coins multiplier for a find of this rarity.
@export var mult := 1.0
## Relative chance. Lucky Tail multiplies this for every tier above common.
@export var weight := 1.0
