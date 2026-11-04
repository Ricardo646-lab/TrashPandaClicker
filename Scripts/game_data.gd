class_name GameData
extends RefCounted

# Easy access to the balance data. All numbers live in Data/balance.tres
# and the files it points to (Data/worlds, Data/items, Data/helpers,
# Data/upgrades, Data/rarities). Open them in the Inspector to tune the
# game; no code changes needed. Costs grow per level: cost * growth^level.

const BALANCE_PATH := "res://Data/balance.tres"

static var balance: Balance = load(BALANCE_PATH)

static var rarities: Array[RarityData] = balance.rarities
static var worlds: Array[WorldData] = balance.worlds
static var helpers: Array[HelperData] = balance.helpers
static var upgrades: Array[UpgradeData] = balance.upgrades

static var world_mult: float = balance.world_mult
static var helper_growth: float = balance.helper_growth
static var helper_unlock: int = balance.helper_unlock
static var milestones: PackedInt32Array = balance.milestones
static var album_bonus: float = balance.album_bonus
static var cap_divisor: float = balance.cap_divisor
static var cap_bonus: float = balance.cap_bonus
static var prestige_world: int = balance.prestige_world


static func item(id: String) -> ItemData:
	for world in worlds:
		for it in world.items:
			if it.id == id:
				return it
	return null


static func item_rarity(id: String) -> int:
	var it := item(id)
	return it.rarity if it else 0


static func item_name(id: String) -> String:
	var it := item(id)
	return it.name if it else id


static func item_count() -> int:
	var count := 0
	for world in worlds:
		count += world.items.size()
	return count
