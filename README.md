# TrashPandaClicker

A clicker game for Poki (Godot 4.7, GDScript). Tap the trash can: the raccoon digs out items (common, rare, epic, legendary) that are worth coins. Buy tap upgrades and helpers, travel to new worlds, collect every item in the album and start over with Golden Caps.

All art is drawn in code, so the project has no image files. All sounds and the music are also made in code (`Scripts/tools/sound_synth.gd`). They are baked once to `Sounds/*.wav`, so the game starts fast.

After changing a sound, bake again from the project folder:

```
godot --headless --path . -s res://Scripts/tools/bake_sounds.gd
```

Then open the editor so the new files get imported. `Sounds/music.wav` is set to loop in its import settings.

## Project structure

### Scenes (edit in the Godot editor)

| Scene | What it is |
|---|---|
| `Scenes/main.tscn` | The game: `Backdrop` (background and helpers), `World` (raccoon and trash can), `Fx` (effects) and `UI/HUD`. |
| `Scenes/ui/hud.tscn` | Coin counter, next-world bar, buttons, boosts, shop, popups, start screen. Move and resize the parts here (anchors). |
| `Scenes/ui/shop_overlay.tscn` | The shop that opens on top of the game. |
| `Scenes/ui/icon_button.tscn` | The round button. Set `icon`, `label` and `color` in the Inspector. |

### Data (tune in the Inspector, no code needed)

| File | What it holds |
|---|---|
| `Data/balance.tres` | General numbers (world multiplier, helper price growth, unlocks, milestones, album and prestige bonus) and the lists below. |
| `Data/worlds/*.tres` | Each world: name, travel cost and its items. |
| `Data/items/*.tres` | Each item: name and rarity. |
| `Data/helpers/*.tres` | Each helper: name, price and coins per second. |
| `Data/upgrades/*.tres` | Each tap upgrade: name, price, price growth, max level and unlock level. |
| `Data/rarities/*.tres` | Common/rare/epic/legendary: chance, coin multiplier and colour. |

The resource types are defined in `Scripts/data/`. The art for an item or helper is found by its `id` (see `art.gd` and `creatures.gd`), so a new item also needs a drawing there.

### Scripts

| File | What it does |
|---|---|
| `game_data.gd` | Loads `Data/balance.tres` and gives easy access to it. |
| `game_state.gd` | Autoload `Game`: coins, purchases, digging, boosts, save/load, offline income. |
| `sfx.gd` | Autoload `Sfx`: plays the baked sound effects and the music loop. |
| `poki.gd` | Autoload `Poki`: sends `gameplayStart` / `gameplayStop` to the Poki SDK. |
| `art.gd`, `creatures.gd`, `scenery.gd` | All drawings: items, icons, the raccoon, helpers, trash can and the six worlds. |
| `bake.gd` | Autoload `Bake`: draws all art once into a texture atlas (and each world background into one texture) when the game starts, so the game only draws textures. Drawing the vectors every frame was too slow on the web. A new item, helper or icon is baked automatically; a new icon id must be added to `Bake.ICONS`. |
| `backdrop.gd` | The background and the helper crew. Only redrawn when something changes. |
| `world_view.gd` | The play area: tapping, raccoon animation, rage meter, golden trash. |
| `fx.gd` | Effects: flying items, numbers, sparkles, coins, banners, shake. |
| `hud.gd`, `coin_counter.gd`, `boost_list.gd`, `world_bar.gd`, `icon_button.gd` | The HUD parts. |
| `shop.gd`, `shop_overlay.gd`, `popup.gd`, `start_screen.gd` | Shop, popups (album, prestige, welcome back) and the title screen. |
| `main.gd` | Connects game events to effects and sounds. |
| `tools/sound_synth.gd`, `tools/bake_sounds.gd` | The sound synthesizer and the script that bakes it to `Sounds/`. |
| `tools/balance_sim.gd` | Balance check: a bot plays the game and prints when each world is reached. Run: `godot --headless --path . -s res://Scripts/tools/balance_sim.gd -- 4` (4 = taps per second). |

The `Scripts/tools/` folder is not included in the Poki export.

## Poki

- `gameLoadingFinished` is sent by the HTML shell (`addons/poki-sdk/full-size.html`) when the engine has started.
- `gameplayStart` is sent after PLAY and whenever the shop or a popup closes; `gameplayStop` when they open.
- The game has no ads. Export with the `Poki` preset, which uses the Poki HTML shell.

## Game systems

- **Tap upgrades:** Sharp Claws (+tap), Big Paws (double finds), Lucky Tail (more rare items), Shiny Eyes (x10 crits), Gold Glove (taps earn a % of /s), Rage Mode.
- **Helpers (9):** they earn coins every second. Each one doubles its output at 10, 25, 50, 100... owned. They also appear in the world.
- **Worlds (6):** Backyard, Park, Pizza Street, Beach, Mall, Moon Base. Every world gives x2 income and has its own items.
- **Events:** golden trash (x7 frenzy / tap x10 / lucky coins), rage meter (tap fast for x3).
- **Long-term:** an album with 30 items (+3% each), and prestige with Golden Caps (+10% each, forever).
