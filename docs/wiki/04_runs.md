# Runs, waves and the arena

## Run structure

A standard run (Colony mode) is **15 waves in three acts of five**, each act on its own map (`src/game/acts.lua`). Act 1 is the map you picked; acts 2 and 3 are other maps you own, planned from the run's seed. After the queen of waves 5 and 10, her rewards and the shop, starting the next wave carries the whole run to the next map (through a run save, as if resumed) with an "Act 2 of 3" card and a breather.

- **Every 5th wave** is a queen wave. Clearing it heals fully, molts touching items, and pays a royal brood cell.
- **Wave 15** is the final boss wave: crowned queens (2 by default, at 1.6× health) one after another, then the **Empress** with two phases. Clearing it **wins the run**.
- After a win the player can **Keep Going** (the bag grows a row, waves keep getting harder, every 15th wave is another final wave) or take on the **Final Swarm**: 60 seconds of every species met pouring in from every side with lots of elites and a crowned queen halfway (`src/game/finalswarm.lua`).
- A run ends when the bug falls, when the player ends it at victory, or with Abandon Run. Every real run pays **amber** for the Burrow.

{{IMG:empress.png|The Empress: the final crowned queen, with her title card and boss bar}}

Acts are off in practice, the daily run, endless, custom or scripted waves, modes with `acts = false`, before a player's second run, and in modes whose `travelActs` run rule is off.

## The wave director (`src/game/spawner.lua`)

Waves **teach the colony one species at a time**. Wave 1 is plain workers; each later wave introduces exactly one new species, which walks in **first and alone** under a "NEW SPECIES" card with its description and tip, before the rest of the wave mixes it with species already met. Every fifth wave a queen of a species you've met comes instead.

- **Introduction order**: by `spawn.minWave`, then the most common first, then **shuffled a little per run** (minWave × 0.6 plus a random spread, workers always first) so bees, wasps and termites can turn up early. A map's `fauna` favours some species (they come sooner and more often) and can name the one that opens wave 1. A mode's `families`, `enemies` and `exclude` restrict who comes.
- **Groups and entries**: each wave sends `groups` (3, +1 a wave) groups of 14 to 22 ants, growing 15% a wave, from 2 entry points in wave 1 up to 6, with pincer pairs from opposite sides later. Stray packs **trickle** in from other edges while the wave runs. Up to 900 alive at once.
- **Ways in** (`src/game/entries.lua`): most groups march from the edge, but some **burrow** up near you (the soil heaves first), **flyers drop** from the sky (a shadow grows where they land), **nest holes** open in the floor and pour out the wave's groups (hit a hole three times or dash over it to seal it), and **burrow rings** surround you. Every way is telegraphed and never opens on the player.
- **Healing**: clearing a wave heals 20% of max HP; a queen wave heals fully.
- **Scripted waves**: a mode with a `waves` list (Gauntlet, Custom Waves) sends exactly what each wave names instead.

### Pacing (`src/game/pacing.lua`)

| Piece | What it does |
| --- | --- |
| Big early waves | Waves 1-3 send 2.2× / 1.8× / 1.4× the ants at 45% / 60% / 80% health: lots to mow down from the first second. |
| Wave modifiers | From wave 3 (55% chance, sometimes two from wave 9), never on queen or final waves: Swarm, Armored, Frenzied, Elite Pack, Ambush (half the wave bursts up in a ring around you), Shield Wall (ranks step out at once), Pincer, Undermined. Rolled ahead from the seed so the HUD can preview them. |
| Overlapping waves | When a normal wave is down to its last 15%, you pick your item and the next wave marches in while the stragglers are still about. |
| Straggler call | With 5 or fewer ants left, any far away burrow up near you. The last 6 also rush 1.5× faster. |
| Par time and heat | Each wave has a par time from its size. Under par pays bonus XP; past it the ants speed up and hit harder (up to +35% / +25% after 40 s). |
| Live pressure | While you stay healthy and untouched, packs come quicker and bigger and ants a little faster; taking damage eases it off. |
| Early call | Starting a wave before its countdown ends, or sending a wave's rest in with Next Wave, pays bonus XP, more for each wave in a row. |
| Royal guard | Every queen arrives ringed by armored brood; she takes 30% damage until they are dead ("BREAK THE ROYAL GUARD"). |

Tuning lives in the Spawner `DEFAULTS`; a stage's `spawn` and a mode's `spawn` override any of it, and any piece can be set to `false`.

## The arena director (`src/game/director.lua`)

Everything in a wave besides the ants walking in. It **never holds a wave up**: a wave ends only when every enemy is dead, and events still going end with it.

- **Mid-wave events** (`content/events`, run rule Often / Normal / Off): from wave 2, 0-2 per wave, 6-24 s in. Honeydew rain (sweet puddles: ants stop to feed, you heal), an anteater's tongue licking down a red lane, a boot stomp (a shadow that follows you, then flattens everything), a flood (wading, a current, small ants drown), colony war (a red rival colony fights yours), rolling dew drops, falling acorns (they stay as things to roll), a lawnmower lane, web cocoons (break one to free a bug that fights beside you for 20 s), the merchant beetle (sells items for nectar) and the aphid matriarch (clones an item). A map's `events = { id = weight }` and a mode's `eventWeights` / `events = false` change the odds.
- **Boss encounters** (`content/bosses`, every 5th wave except the last): bugs are fights (the **antlion** digs a sand pit that drags everything to its jaws and flicks sand; the wave lasts until it falls). Animals far too big to fight are **stage hazards** (`hazard = true`): the **sparrow** and the **giant anteater**. They have no HP and nothing to hit, they come only from wave 10, arrive 8 s in, never share a wave with events, hunt for 24 s at most, speed up the longer the wave lasts, and everything they do **kills ants and hurts you alike**. Lead the swarm into them. They leave with bonus XP.
- **Stage mechanics** (`content/mechanics`): Puddled Patio's rising puddle, Overgrown Lawn's long grass closing in, Dappled Garden's drifting sun patches (speed everyone up; shade slows ants).
- **Weather** (`content/weather`, `src/game/weather.lua`): passing spells of rain, fog, wind, pollen, storms, heatwave. Wind pushes everyone downwind (lighter bugs more), rain slows the fight (ants most), heat speeds it up. A banner says what changed.
- **Map gambles** (`src/game/gambles.lua`): from wave 2 a risky spot may pop up: a **dewdrop shrine** (stand in its ring while it fills and calls ants in; then walk into one of three permanent blessings), a **challenge bell** (ring it, kill the tough pack it calls in time for a rare reward), a **gamble flower** (spin for nectar: items, blessings, nectar ×3, XP, a heal... or nothing, ants, or a small permanent curse).

{{IMG:hz_sparrow_swoop.png|The sparrow stage hazard swooping down a lane, scattering the horde}}

{{IMG:hz_anteater_flick.png|The giant anteater flicking its tongue down a red lane}}

Everything that changes movement goes through `world.env` (player / enemy speed, drift, the player's inset from the walls, a per-spot speed field). Raw environmental damage and the shared warning-lane drawing are in `src/game/envfx.lua`.

## Side tasks in a wave

- **Mini-goals** (`content/goals`, from wave 2): stop the courier ant before it crosses, guard the aphid, reach a combo, get a burst of KOs. Success pays XP and frenzy; failing costs nothing.
- **Treasure ant** (from wave 3): a gilded ant pops out and runs. Catch it within 14 s for a pile of XP, half a frenzy meter and a brood cell; otherwise it burrows away.
- **Route gates** (`content/routes`, `src/game/routes.lua`): after a wave two tunnels open beside you. Walk into the safe one (fewer ants, no elites) or the hard one (more ants, more elites or tougher ants; pays XP, frenzy or a rarer item card). Ignore both for a normal wave.
- **Brood cells**: a slain queen drops a royal brood cell, a caught treasure ant a plain one. Walking in (or clearing the wave) rolls **1, 3 or 5 level-up cards** with a fanfare (queen odds 50/38/12, treasure 74/22/4).

## Wave rewards (`src/game/rewardflow.lua`)

A cleared wave's rewards are a moment in the arena, not a pile of screens:

1. Every bead flies to you. A glowing **reward bloom** sprouts next to your bug, labelled with what is inside. Walk into it (or press Next Wave, or wait 5 s and it rolls to you).
2. It bursts and the **item choice** opens: pick 1 of 3 items. A boss wave guarantees rare or better; each gilded elite killed adds a card. With Level-Up Cards: At Wave End, a steps strip shows the level-ups first.
3. What you took flies out of the bloom into your bug, and a gain card on the left says what you got.

**Item choice helpers** (`src/game/choices.lua`): REROLL redraws every unlocked card (3 per run, +1 per queen), LOCK keeps a card for the next choice, BAN removes an item from the run (2 per run). Cards show tags (lit when the bag shares them) and a stat preview ("Speed 120 » 138"). From wave 4, 15% of choices deal a **Sealed Cocoon**: rare or better, but hidden until taken. If the pick doesn't fit, the bag opens holding it.

{{IMG:sealed_cocoon.png|An item choice with a Sealed Cocoon card}}

## Nectar economy (`src/game/economy.lua`, numbers in `src/config/shop.lua`)

Nectar is the run's only currency.

- **Shop**: the SHOP tab of the inventory window, open the whole run (the game pauses). 3 items and 1 stat boost; two presses to buy. **Restocks every minute of play** (faster with `shopSpeed` items, never under 15 s). LOCK keeps an offer; REROLL costs nectar and gets dearer until the restock. Prices rise every wave (base: common 60, uncommon 100, rare 170, legendary 300, cursed 90).
- **Interest**: the moment a wave is cleared, banked nectar earns 10% (capped; the cap grows each wave).
- **Scrapper**: SCRAP in the bag turns an item into 40% of its price in nectar; rare or better also gives back a reroll.
- **Merchant beetle**: an event that sells for nectar a fifth under shop price.

## Run rules (`src/game/rules.lua`)

Switches that change how the game itself plays (spawns, difficulty, pacing, events, gambles) are **not settings**. The main game always plays with the defaults, so everyone plays the same game; Settings keeps comfort options only (auto attack, aim, health bars, hit stop...). Only a run's mode changes them: a Custom Waves set's `rules` table (picked in the wave builder) or a mode file's `rules = { key = value }`.

`Rules.get(key)` reads the value for the current run, `Rules.begin(tbl)` starts a run with its mode's rules, `Rules.set(key, v)` is a developer / selftest override. Rules offered in the wave builder: Map Gambles (often / normal / off), Parasites, Level-Ups (cards or skill points), Overlapping Waves, Wave Heat, Mini-Goals, Route Gates, Weather Effects and Dash Tech. Main-game-only rules: mid-wave events, boss encounters, wave modifiers, species order, elite frequency, difficulty and travel acts.

## Game modes (`content/modes`)

| Mode | Shape |
| --- | --- |
| Larvae | Beginner: smaller, weaker waves, long breaks, a new species every other wave, no elites. |
| Colony | Standard: every family, 15 waves, queen every 5th. |
| Swarm | Hard: more columns from more sides, tougher ants, short breaks, elites twice as often. |
| Anthill / Hive / Mound | Ants only / bees, wasps and hornets only (boss pool instead of queens) / termites only. |
| Champions | Small groups, every enemy is an elite. |
| Endless | Pick starting items on a point budget; no waves and no breaks; the level climbs every 40 s. |
| Gauntlet | Ten hand-made scripted waves, the same every run. |
| Royal Court | Boss rush: a queen every wave for ten waves. |
| Blitz | Eight huge waves with no breaks, two new species a wave, faster level-ups. |
| Mayhem | Wave modifiers on every wave, extra events, a boss or hazard every third wave. |
| Custom Waves | The wave builder: sets of hand-made waves (groups, queen, modifiers, events, encounter), shareable as a Lua table on the clipboard (pasted text runs with no globals and a step limit, so it can only be data). |
| Tutorial | Hidden: 14 guided lessons (`src/game/lessons.lua`). |

Plus the **Daily Run** (today's date seeds the bug, map, species order and every modifier), the **Weekly Challenge** (a new seed every Monday picks the bug, map and two artifacts), **Practice** (pick a bug, mode, wave and species; never recorded) and **Run Codes** (copy a finished run's code, play the same run on another machine).

A mode can override any stage wave setting (`spawn`), restrict enemies, scale enemy health and damage (`enemyHp`, `enemyDamage`, `hpPerWave`), change elite odds, set `finalWave` (false = never ends), and override the reward, shop, nectar, item choice and level-up numbers (`rewards`, `shop`, `nectar`, `itemChoice`, `levelUps`), or switch systems off (`encounters`, `events`, `gambles`, `onramp`, `acts`).

## Run saves (`src/game/runsave.lua`)

A run saves itself at every wave clear, on Pause > Save & Quit, and when the window closes. The save is a snapshot of what makes it *your* run: bug, mode, map, act route, waves cleared, time, KOs, HP, the bag (every item where you put it and how it's turned), skills, level-ups, economy, blessings and curses, artifacts and keepsake. A run saved mid-wave plays that wave again. Abandon, defeat and End Run delete it. Act travel uses the same save to carry the run to the next map.
