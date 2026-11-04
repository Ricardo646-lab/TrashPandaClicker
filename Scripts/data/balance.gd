class_name Balance
extends Resource

# All balance numbers of the game in one place (Data/balance.tres).
# Tune here in the Inspector; no code changes needed.

@export var rarities: Array[RarityData] = []
@export var worlds: Array[WorldData] = []
@export var helpers: Array[HelperData] = []
@export var upgrades: Array[UpgradeData] = []

@export_group("Worlds")
## Every world multiplies all income by this.
@export var world_mult := 2.0

@export_group("Helpers")
## Each helper you buy makes the next one this much more expensive.
@export var helper_growth := 1.15
## A helper unlocks once you own this many of the one before it.
@export var helper_unlock := 5
## At these counts a helper's output doubles.
@export var milestones := PackedInt32Array([10, 25, 50, 100, 150, 200, 250, 300, 400, 500, 600, 700, 800, 900, 1000])

@export_group("Long term")
## Every different item in the album gives this much extra income.
@export var album_bonus := 0.03
## Golden Caps = cube root of (all coins ever / cap_divisor).
@export var cap_divisor := 1.0e9
## Every Golden Cap gives this much extra income, forever.
@export var cap_bonus := 0.1
## Prestige becomes available from this world on (0 = Backyard).
@export var prestige_world := 3
