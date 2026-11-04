class_name UpgradeData
extends Resource

# A tap upgrade. What it does is coded in game_state.gd (by id).

@export var id := ""
@export var name := ""
## Price of level 1. Level n costs cost * growth^n.
@export var cost := 10.0
@export var growth := 1.2
## 0 means no maximum.
@export var max_level := 0
## Level the upgrade above it in the list needs before this one unlocks.
@export var unlock := 0
