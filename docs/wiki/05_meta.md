# Between runs: progression, menus and the Bug Creator

## Teaching the game

- **Gentle Start** (`src/game/onramp.lua`, numbers and card text in `src/config/onramp.lua`). A new player meets the systems a piece at a time. First run: no elites before wave 4, treasure ant and the nectar shop from wave 3. Mini-goals, wave twists, garden events and map gambles join in run 2; route tunnels and big visitors in run 3; until run 4 a wave has at most one event and never one beside a visitor; act travel from run 2. The first time each system shows up, a short "NEW" card explains it, and from then on it is never held back again. Saves with 6+ runs count as having met everything. Systems ask `OnRamp.allows(world, id, wave)` before they appear.
- **Tutorial** (main menu until finished once): a guided fight in a hidden mode run by `src/game/lessons.lua`. The colony's own waves are off; 14 lessons each bring in what they need (move, attack, dash, special, the swarm, nectar, a level-up, an item choice, the bag, the shop, frenzy, an elite, a queen). Nobody can fall in it and it isn't recorded.
- **First-run hints** (`src/game/tutorial.lua`): move, attack, dash, special, swarmed, items, skill points, queens; each once.
- **Field Guide** (main menu and pause): one short page per system (`src/config/guide.lua`), a set-bonus page from the tag config, and the bug and item catalogues. Pages for systems Gentle Start hasn't shown yet read "? ? ?".
- **New species cards and first sightings**: the wave that introduces a species names it with its description and tip; anything else seen for the first time (broods, escorts, hatchlings) gets a smaller card on the left.

{{IMG:new_card.png|A Gentle Start NEW card the first time a system appears}}

## Meta progression

The rule: **between-run progress buys new things to find, never raw power.**

- **Amber** (`src/game/amber.lua`, `src/config/amber.lua`): the currency kept between runs. Every real run pays some when it ends, won or lost: 2 a wave cleared, 4 a queen, 1 per 10 elites, 1 per 200 KOs, 20 for a win (custom waves pay half). Veterans get a one-time head start.
- **The Burrow** (`src/states/burrow.lua`): shelves of **item packs** (their items stay out of every choice and the shop until bought), **maps**, **modes**, **artifacts** and **keepsakes**. Press once to look, twice to buy, with a fanfare. API: `Amber.owns / itemOpen / stageOpen / modeOpen / buy / next`.
- **Artifacts** (`content/artifacts`, `src/game/artifacts.lua`): Risk of Rain 2-style run rules, bought once, switched on or off in mode select. They can change the game params before the world is made (Metamorphosis picks the bug) and the world after (`world.danger` multipliers, stat mods, the frenzy meter). Glass Carapace, Teeming, Giants, Royal Guard, Twin Queens, Heatwave, Mixed Colony, Frenzy Tide, Metamorphosis.
- **Keepsakes** (`src/config/keepsakes.lua`): one small trade a bug carries into a run, never a straight gain (Snail Shell: more health, slower; Wasp Sting: more damage, less health...).
- **Unlocks** (`src/config/unlocks.lua`): eight bugs open from the start; each other bug opens through an in-run goal ("Clear wave 5 as the Rhino Beetle", "Kill 25 ants mid-dash in one run"). Some items are locked the same way. Goals are achievements in the Unlocks category, so progress shows in Records and an "Unlocked" card pops mid-run. **Unlock Everything** (Settings > Gameplay) opens bugs, items, danger levels and skins; locked things show hints.
- **Danger levels** (`src/config/danger.lua`): per bug, Danger 0-5, each adding one rule (more elites, less healing, faster ants, tougher ants, bigger groups and an extra crowned queen). Winning at a level opens the next; the highest won shows as mastery stars.
- **Item Pool**: no longer a setting. The main game always offers every unlocked item; a Custom Waves set can switch items out of its own choices (`itemsOff`, at least 12 stay in).
- **Records and achievements** (`src/game/records.lua`, `content/achievements`): lifetime totals, a page per bug, the last 50 runs with their bags, kills per species and family, 123 achievements (a `value(profile, run)` and a `goal`, checked twice a second). Several files generate entries from other content, so new bugs and modes get achievements automatically. Some unlock cosmetics.
- **Cosmetics** (`src/game/cosmetics.lua`): the starting location, map decor (`content/decor`) and a skin per bug (`content/skins`: hue, saturation, brightness, tint, light).

{{IMG:burrow.png|The Burrow: item packs, maps and modes bought with amber}}

## Run summary and accessibility

- **Run summary** (results, victory and pause): damage by source (items, attacks, specials, dashes, thrown ants, poison, all attributed by `src/game/runstats.lua`), kills by species, a dealt / taken graph per wave, the closest achievements and the run's seed.
- **Death recap**: what killed you and your last 5 hits taken.
- **HUD Detail** Full or Clean; **HUD Size** (default 75%); enemies-left counter and wave progress; next-wave preview; off-screen markers for queens and elites; combined damage numbers; enemy health bars (off / elites & queens / when damaged / always).
- **Colourblind-Safe Colours**: elites use Okabe-Ito `safeColor`s; ground hazards are coloured by what they do (harmful orange, slowing blue, healing yellow). **High-Contrast Warnings**: mounds, nest holes, shadows, landing rings and wind-ups get dark outlines and thicker rings (`src/ui/palette.lua`).
- **Visibility** (Lighting tab): background dim, actors pop, see-through silhouettes, threat outlines, horde depth, danger compass, clear space, low-health pulse, Glare Guard. **Hold To Inspect** (V / Left Alt) slows the run and labels the enemies near the pointer.
- **Comfort**: Game Speed, screen shake, hitstop and slow-motion switches, flashing limits, Photo Mode, pause on focus loss or controller unplug.

## The screens

| Screen | File | Notes |
| --- | --- | --- |
| Title | `src/states/menu.lua` | Live demo fight behind it. Resume, Play Again, Play, Burrow, Bug Creator, Field Guide, Records, Cosmetics, Settings. |
| Mode select | `src/states/modeselect.lua` | Map row, keepsake, artifacts; modes grouped (Your run / Modes / Challenges / More); daily, weekly, run codes, practice, custom waves. |
| Bug select | `src/states/charselect.lua` | Portrait grid grouped by family with family tabs, favourites, sort and playstyle filter, danger picker, live move preview. |
| Arena | `src/states/game.lua` + `src/ui/hud.lua`, `src/ui/runhud.lua` | The run. |
| Inventory window | `src/states/bagtabs.lua` | BAG (`inventory.lua`), SKILLS (`skilltree.lua`), SHOP (`shop.lua`). Pauses the run. |
| Level-up, item choice, brood cell, cloning | `levelup.lua`, `itemchoice.lua`, `broodcell.lua`, `duplicate.lua` | Overlays. |
| Pause | `src/states/pause.lua` | Every stat (hover for meaning) and every bag item's full effect; Photo Mode, Field Guide, Save & Quit. |
| Results | `gameover.lua`, `victory.lua`, `runsummary.lua` | Amber paid, run code, keep going, Final Swarm. |
| Settings | `src/states/settings.lua` | Generated from the schema; tab presets; live preview beside Video / Lighting / Camera. |
| Burrow, Records, Cosmetics, Field Guide, Practice, Item Pool, Artifacts, Loadout, Wave builder | `src/states/*.lua` | |
| Bug Creator | `creator.lua`, `bugmixer.lua`, `codeeditor.lua`, `painter.lua`, `blockeditor.lua`, `rating.lua` | Below. |

## The Bug Creator

Main menu > **Bug Creator** makes new playable bugs. A custom bug is an ordinary character definition with `custom = true`, registered in `Content.characters`, so bug select, records and runs need nothing special. Each is one Lua script in the save folder (`custom_bugs/<id>.lua`; ids always start with `custom_`, so a custom bug can never replace a built-in one). The full field-by-field reference is `docs/CUSTOM_BUGS.md`, reproduced at the end of the Reference volume.

- **Mix Parts** (`bugmixer.lua`): one bug's body, another's attack, special and dash, plus size, colours, stats, an item rule and a skill tree, with a live preview. **Build from blocks** makes a move with no code: a list of blocks (lunge, wait, swing, slam, thrust, shockwave, sweep, shoot, lob, puddle, push, pull, wall, heal, shield, speed, vanish, afflict, ring, shake, hitstop, sound...), and more steps make a combo. The mixer also sets the ultimate, hit look and sounds, a status effect, pets, a molt and the title card.
- **Write a Script** (`codeeditor.lua`): a small sandboxed Lua script. Moves can be written in code against the `me` toolkit (`src/game/scriptmoves.lua`: `me.hitArc`, `me.hitLine`, `me.hitCircle`, `me.lunge`, `me.after`, `me.state`, `me.hit` hitboxes with wind-up, sweep and feel...): press, hold-to-charge, hold, and stamina-mode moves, code on game events, own animations, sounds and skill tree.
- **Paint a Bug** (`painter.lua`): a pixel grid with pen, fill, picker and mirror, a body-part kit (7 heads, 6 middles, 6 backs), draggable leg joints, add-on limbs (claws, blades, tails, horns, feelers, wings).
- **Template Gallery** (`content/bugtemplates`): ten ready bugs (tank, summoner, sniper, trickster, berserker, bomber, vampire, shapeshifter, pet master, glass cannon). Examples: Stick Insect, Velvet Worm.
- **Test Arena** (training dummies, hitboxes, DPS meter), **Rate It** (`src/game/bugrating.lua`: the bug plays the same short fight as three built-in bugs; 100 = as strong as them), challenges, **share codes** (`SWARMED-BUG:...` on one line).
- **Safety**: scripts run in a sandbox (no files, `love`, `require`, `load`, `os`, `io`, `debug` or metatables), with an instruction budget (about a million steps to build, a budget per call after) and 32 MB; bytecode is refused; every number that comes out is clamped (damage ≤ 500, cooldowns ≥ 0.03 s, counts ≤ 40).

{{IMG:mixer_passives_looks.png|Bug Creator: the mixer with passives and looks}}

## Game icon and Discord status

- **Icon** (`assets/icon/`): a bombardier beetle ringed by worker ants, painted with the game's own models by `love . --makeicon` (`src/debug/iconmaker.lua`). `conf.lua` uses `icon_256.png` for the window; the web build uses it for the tab and phone home screen; `swarmed.ico` / `swarmed.icns` are for shortcuts and packaged builds (`tools/make_icons.py`).
- **Discord "now playing"** (`src/core/discord.lua`, `src/game/presence.lua`): talks to the Discord desktop app's local pipe directly through LuaJIT's FFI, with no DLLs. About once a second it looks at the screen stack and builds a status (bug, wave, mode, danger, run time; menus, the Bug Creator and the sandbox get their own lines). It switches itself off on the web, on phones, in tests, when Discord isn't running, or with Settings > Interface > Discord Status off. It needs the Application ID of a "Swarmed" app from the Discord Developer Portal in `src/config/discord.lua` (or `SWARMED_DISCORD_APP_ID`). Test without Discord: `python3 tools/fake_discord.py`.
