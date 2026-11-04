class_name HelperData
extends Resource

# A helper that earns coins every second. Its picture is drawn in code
# (Creatures.helper_shapes), found by id.

@export var id := ""
@export var name := ""
## Price of the first one. Each next one costs Balance.helper_growth times more.
@export var cost := 10.0
## Coins per second for one helper (before milestones and multipliers).
@export var cps := 1.0
