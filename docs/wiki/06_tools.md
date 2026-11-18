# Tools, tests and how to add things

## Developer mode

On by default while the game is being built (Settings > Developer). It adds:

- **Sandbox** (main menu, or `love . --sandbox`): a tabbed panel (keys 1-5, F2 hides it). *Spawn*: any enemy, normal or elite, in any amount, with a health multiplier from one-hit to ×1000 dummies; march a real column in; every elite of a species; every species at once; any queen. *Items*: the Item Catalogue, give / take, one of every item, bigger bags, an item choice on demand. *Player*: swap bugs (items carry over), god mode, heal, take damage, every stat on a slider, +5 skill points, reset tree, level-up card pick. *Waves*: start any wave, next, stop, keep going. *World*: time of day, time scale, hitboxes, spatial grid, perf overlay, a **DPS meter** and a **proc log**.
- **Spawn Catalogue** (V in the sandbox): every enemy, queen and bug as a wall of pictures; spawn, march in, all elites, play as, or **Place** (every click drops that bug).
- **Item Catalogue**: every item as a wall of icons by category or rarity, with filters and search; gives and takes items in the sandbox.
- **Console** (`` ` ``): `help`, `spawn fire_ant 200`, `give ember_gland 3`, `stat damage 50`, `wave 10`, `god`, `timescale 0.3`, `event flood`, `encounter sparrow`, `prop pebble 5`, `gamble shrine`, `nectar 500`, `pickup frost_dew`, `list items`... (full list in the Reference volume).
- **Hotkeys** (F1 lists them): F3 perf overlay, F4 hitboxes, F5 grid, F6 god, F7 time scale, F8 spawn 100, F9 kill all, F10 sandbox, F12 screenshot.
- **Playtest Log**: one CSV line per cleared wave and at the end of a run.

{{IMG:art_cat_enemies0.png|The Spawn Catalogue: every enemy as a picture wall, with variant, amount and health chips}}

## Automated tests

`love . --selftest` walks through every screen, takes screenshots into the save folder, stress tests the horde and prints timings, then quits. It runs headless in the cloud under `xvfb-run`. Each part also runs on its own with `love . --selftest --<part>`:

| Part | Checks |
| --- | --- |
| `specials`, `dashes`, `animtest`, `batch1`, `rework2`, `rework3`, `stability` | every bug's moves, animations, crash hunt, per-bug frame cost |
| `inventory`, `items`, `itemorg`, `choiceqol`, `molts`, `economy`, `nectar`, `rewards`, `levelups`, `skills` | the bag, every item proc in a live fight, categories, choice helpers, molting and sets, shop, beads, reward bloom, cards, every skill node |
| `hymenoptera`, `termites`, `entries`, `pacing`, `happenings`, `hazards`, `props`, `gambles`, `bosses`, `finalwave`, `combat` | enemy mechanics, ways in, pacing pieces, events / encounters / mechanics / weather, stage hazards with a screenshot per attack, prop physics, gambles, queens / Empress / champions, the run's end, frenzy / streaks / goals / routes |
| `modes`, `customwaves`, `acts`, `maps`, `gentle`, `tutorial`, `amber`, `artifacts`, `keepsakes`, `runcode`, `mastery`, `records` | every mode's first waves, the wave builder, act travel, map fauna, Gentle Start, lessons, the Burrow, meta progression, unlocks and danger, records |
| `qol`, `charselect`, `uitour`, `hudsize`, `runinfo`, `flow`, `touchtest`, `polish`, `visuals`, `cosmetics`, `discord`, `creator`, `creator2` | menus and controls, bug select, every screen's look, HUD, music / hints / markers, lighting looks, cosmetics, Discord, the Bug Creator |
| `arttour` | catalogue walls, a line-up of each family, every prop and the antlion, for an art check |

Two rules learned the hard way: **run LÖVE processes one at a time** (selftests are timing-sensitive; parallel runs get fewer frames and flake), and in tests **loop until a condition holds** (with a cap) instead of stepping a fixed number of frames, because level-ups and big kills trigger slow motion.

Other tools: `love . --profile` (scripted massacre, frame time breakdown, hottest lines), `love . --balance` (a crude bot plays real runs with several bugs and reports time, HP and KOs per wave), `love . --roster` (every model walking), `love . --anims` (animation clips, `--shot` saves contact sheets), `love . --touch` (touch controls on a PC).

## Art pipeline (`tools/`)

| Tool | Makes |
| --- | --- |
| `make_bug_sprites.py` | playable bugs and ants: shape recipes (ellipses for segments, lines for legs, a generic `critter()` builder) → text-grid sprites in `content/sprites/bugs.lua` plus each bug's leg rig |
| `make_batch1_sprites.py`, `make_batch2_sprites.py`, `make_hymenoptera_sprites.py`, `make_termite_sprites.py` | the later casts |
| `tone_palette.py` | pulls loud palettes back into the dusky range |
| `make_item_icons.py` + `icon_render.py` | item icons modelled from lit 3D shapes with materials, reduced to a small palette (`--preview out.png [ids]` for a contact sheet) |
| `make_molt_icons.py` | molted item icons |
| `preview_sprites.py` | contact sheet of any sprite file (needs luajit and Pillow) |
| `make_icons.py` | the game icon in every size and format |
| `build_web.sh`, `serve_web.sh` | love.js build (`../web`, `swarmed-web.zip`, `swarmed.love`) and a local server for phones |

Sprite files are plain text grids, so they can also be hand-edited.

## Recipes: adding content

Every recipe is "copy the folder's `_template.lua`, change it, run the game". Content is cross-checked at start-up, so a typo in an id stops the game with a clear list.

**A new enemy.** Add `content/enemies/<id>.lua` with name, texts, `sprite`, stats, `family` (from `src/config/families.lua`), `spawn = { weight, minWave, groupSize }`, `behavior` + `behaviorParams`. It joins the introduction order, the catalogues, the sandbox and the achievements automatically. For a new kind of AI add `content/behaviors/<id>.lua` with `update` (and `init`, `onHit`, `draw`, `drawUnder` as needed). Give it a queen (`behavior = "queen"`, `brood = "<id>"`, `boss = true`, `spawn.weight = 0`) so queen waves can use it.

**A new playable bug.** Make its sprite and model with a generator, add `content/characters/<id>.lua` (stats, attack / secondary / dash with params, tags, playstyle, tip), a skill tree in `content/skilltrees/<id>.lua` (three branches of five tiers plus a `signature`; the kin branch attaches itself by tags), an unlock goal in `src/config/unlocks.lua`, optional animation clips in `src/config/anims.lua`, and a bug rule if it bends items. Music band and riff come from its tags and id.

**A new move.** Add `content/attacks/<id>.lua` (`fire(player, world, aimX, aimY, params)`, optional `update` for held parts and `draw`) or `content/dashes/<id>.lua` (`start`, or `hold = true` + `update`, or a stamina mode). Always deal damage through `Combat.damage` and spend stamina through `Stamina`.

**A new item.** Add `content/items/<id>.lua` with `rarity`, `category`, `tags`, `shape` or `size`, `stats` / `statsMult`, `procs`, `description`. Model its icon in `make_item_icons.py`. Add a molt recipe in `content/molts` if it should molt.

**A new map.** Add `content/stages/<id>.lua` with a palette, size, ground look (cracks, joints, grass, leaves), `spawn` pacing, `fauna`, `props`, `events`, `weather`, an optional `mechanic`, and sell it in `src/config/amber.lua`.

**A new event / hazard / prop / weather / wave modifier / mode / card / artifact / achievement.** One file in the matching folder. Events have `start`, `update`, optional `field`, `drawGround`, `drawAir`, `finish`; a stage hazard is a `content/bosses` file with `hazard = true` and its own painted picture in `src/gfx/beasts.lua`; a prop with `gamble = {...}` joins the map gambles.

**A new stat or setting.** One row in `src/config/stats.lua` or `src/config/settings_schema.lua`; the settings screen, saves and tooltips follow.

**A new console command.** One table in `src/debug/commands.lua`.
