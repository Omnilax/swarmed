# The engine

Swarmed has no third-party engine or library besides LÖVE itself. Everything (the content system, the renderer's batching, the synthesised audio, the Discord pipe) is in the repository. This chapter walks through it in the order the game uses it: boot, the frame loop, the world, then each subsystem.

## Boot sequence (`main.lua`)

`love.load(args)` turns the launch arguments into a set of flags and then, in order:

1. **Settings** load from `settings.lua` in the save folder (`src/core/settings.lua`, validated against `src/config/settings_schema.lua`). `--dev` forces Developer Mode on.
2. **Screen** sets up the low-resolution world canvas (960×540 by default, Settings > Video > Pixel Resolution) and its scaling to the window (`src/core/screen.lua`).
3. **Input** binds actions to keys, mouse buttons, gamepad buttons and touch (`src/core/input.lua`, `src/core/touch.lua`).
4. **Content.load()** fills every registry from `content/` and cross-checks references (below).
5. **Records** load, and cosmetic rewards from earned achievements are re-applied.
6. **Test guards.** Under `--selftest`, `--profile` and `--balance`, saves are switched off (records, prefs, run save, custom bugs go to a separate folder), every lock is open (unless `--locked`), hints, Gentle Start and act travel are off. Tests never touch the player's save.
7. **Music** starts rendering its stems (a slice per frame, cached as WAV files in `music/`). **Presence** (Discord) starts if possible.
8. **Sprites.build** bakes every sprite into one texture atlas (about 2048×14,000 px, ~19,000 pieces, ~2 s).
9. **Custom bugs** from the Bug Creator load after the atlas (their own art is built as small separate images).
10. The first **state** is pushed: the title menu, or the sandbox / roster / animation viewer / icon maker / profiler / balance bot / selftest depending on the flags.

`love.run` is the default LÖVE loop plus an optional frame cap when VSync is off. `love.update` and `love.draw` forward to the state stack; `Feedback.update` (music, hints, markers) and the selftest runner hook in beside it. F12 saves a screenshot, a dropped `.lua` file goes to the Bug Creator, and closing the window mid-run saves the run so it can be resumed.

## The state stack (`src/core/state.lua`)

Every screen is a state object with optional methods (`enter`, `leave`, `resume`, `update`, `draw`, input callbacks, `resize`, `focus`). `State.switch` replaces the stack, `State.push` / `State.pop` layer screens. A state with `transparent = true` (pause, bag, level-up, item choice) draws the state below it, dimmed to about 70% black. Every full-screen change fades in from the background colour, so screens never pop.

The arena itself is `src/states/game.lua`, which owns one **World** in `"run"` mode (a real run) or `"sandbox"` mode (developer playground, also used for the title-screen demo, the bug select preview and the Bug Creator test arena).

## Content and registries (`src/content.lua`, `src/core/registry.lua`)

A **Registry** holds one kind of content: `byId`, an ordered `list`, a schema (`required` fields, `defaults`, an optional `validate(def)`). `loadDirectory("content/<kind>")` loads every `.lua` file that does not start with `_`; a file returns one definition (its id defaults to the file name) or a list of them. `order` fields sort lists for menus.

Load order matters only where one kind reads another while validating: sprites, behaviours, attacks, dashes, elites, enemies, characters, skill branches, skill trees, items, stages, bosses, events, props, mechanics, wave modifiers, modes, weather, skins, decor, frenzies, streaks, goals, routes, level cards, pickups, artifacts, molts, then achievements last (several achievement files generate entries from the other registries, one per bug, family, elite and mode).

After everything is loaded, `crossCheck()` verifies every reference: an enemy's sprite and behaviour, a character's sprite, model parts, attack, special, dash and starting items, every item's icon, every stage's mechanic, props and fauna keys, every mode's enemy lists and scripted waves, every molt recipe. One bad id stops the game at start-up with a list of every problem, so broken content never reaches a run.

**To add a new kind of content:** add a Registry in `src/content.lua`, add it to `Content.order`, make the folder with a `_template.lua`. **To add a piece of content:** add one file.

## The frame (`World:update`)

`src/game/world.lua` (about 1,700 lines) is one arena run: player, enemies, effects, camera and the spatial hash. Each frame:

1. **Time.** `dt` is scaled by the world's time scale, the Game Speed setting, Hold To Inspect and the reward slow motion. During **hitstop** only the camera updates.
2. **Atmosphere.** Lighting, shading and ambience tick; a pending Highlight Shot is captured.
3. **Deaths become visible.** Last frame's kills (`recentDeaths`) are handed to behaviours that react to deaths nearby (big-headed majors rallying, Africanized bees getting angrier).
4. **Spatial hash** is cleared and refilled with every enemy (cheaper than tracking moves when hundreds move every frame; cell arrays are reused so there is no garbage).
5. **Deferred calls** queued during last frame run.
6. **Player, spawner, enemies** update, then beads, grabs, hazards, the director (events, encounters, mechanics, weather effects), bosses, the reward flow, the economy (shop restock) and the Final Swarm.
7. **Solids** push the player out of solid enemies.
8. **The dead are removed**, keeping the enemy array packed (swap with last), and returned to the pool.
9. **Particles and weather** update; landed particles become splats on the decal layer; corpses fade.
10. **Hitstop check.** If enough enemies died this frame (15 by default) and the cooldown allows, the world freezes for a beat and shakes. The run's biggest multi-kill can be saved as a picture.
11. Effects, floating texts, the decal fade, the stain budget (40 per second) and the combo timer tick. Rewards (frenzy, streaks, goals, routes) update last.

Nothing in a wave waits on anything but living enemies: events, hazards and gambles all end with the wave.

## Coordinates and projection (`src/core/iso.lua`)

The world is a flat square plane (x, y) plus a height z. **All gameplay (movement, collisions, ranges, hitboxes) happens in world space**; only drawing projects. The projection is 2:1 isometric:

```
screen x = x - y
screen y = (x + y) / 2 - z
depth    = x + y          (drawn back to front by this)
```

`Iso.toWorld` and `Iso.screenDirToWorld` turn the mouse and the right stick back into world directions for aiming.

## Entities

- **Enemies** (`src/game/enemy.lua`) are plain tables recycled through a pool, so spawning and killing hundreds a minute makes almost no garbage. An enemy carries its `def` (the content file), its `behavior` and per-instance state `e.st`, velocity, knockback velocity, flash/squash timers, status timers (stun, slow, poison, corrode, freeze), `hidden` (burrowed: untouchable, undrawn), `alpha`, `heldBy` (grabbed) and an optional `elite` affix.
- **The player** (`src/game/player.lua`) holds the character def, a **stat block**, the inventory, the attack / special / dash with their params (after skill tree mods), stamina, statuses (`stun`, `blind`, `gum`) and the 3D model pose.
- **Props** (`src/game/props.lua`) are neither: pebbles, twigs, acorns, cocoons, allies, the merchant, brood cells, reward blooms, map gambles. They never enter the enemy list, so they never hold a wave up.
- **Hazards** (`src/game/hazards.lua`) are what enemies leave or throw: ground zones (honey, acid, sand pits, with `damage`, `slow`, `heal`, `pull` and custom `update` / `draw`) and projectiles (acid spit, pebbles, curving shots with `turn`, `onHitPlayer`). Player attacks can swat projectiles back.
- **The event bus** (`src/core/events.lua`): each run owns one; `enemy_died`, `player_hurt`, `wave_started`, `wave_cleared`, `item_taken`, `item_eaten`, `run_won`, `player_died`, `species_seen`, `nectar_changed`... Items, achievements, records and the HUD listen without the emitter knowing about them.

## Stats (`src/game/stats.lua`, `src/config/stats.lua`)

A stat block holds base values plus modifiers from named sources (an item, a buff, a level-up card, a skill node, a keepsake). The final value is:

```
final = (base + sum of adds) × (1 + sum of multipliers), clamped to the stat's min / max
```

Some stats have a soft cap (Dodge: past 30% each point counts for less, never 60%). Fifteen stats exist (Max HP, HP Regen, Armor, Dodge, Speed, Damage, Attack Speed, Area, Knockback, Crit Chance, Crit Damage, Luck, Life Steal, Pickup Range, Dash Cooldown). Adding a stat to the config makes it usable by every item, card and bug, and its `info(value)` function explains the number in tooltips.

## Combat (`src/game/combat.lua`)

Attacks and procs never touch enemy health directly; they call `Combat.damage(world, enemy, base, opts)`, so crits, knockback, procs, numbers and kills stay consistent. The order of a hit:

1. Burrowed (`hidden`) enemies can't be hit; a grabbed prop only chips.
2. `damage = base × (1 + Damage%) × coefficient`.
3. **Crit** roll on Crit Chance; a crit multiplies by Crit Damage.
4. **Shield ants** (turtle ants) standing between the player and the target soak most of the hit.
5. **Elite armour** (Armored: 40% less), **corrosion** (vinegaroon acid: more), **poison amp** items, a **queen behind her royal guard** (30% of the hit).
6. The behaviour's `onHit(e, world, opts, dmg)` may multiply it (counter-hits on charging ants, velvet ants ignoring hits under 8, hover wasps dodging).
7. Damage is rounded (at least 1), logged to the run stats by source, and applied. Flash, squash, knockback (scaled by the Knockback stat and divided by mass), poison, slow, stun and corrosion from `opts`.
8. If it kills: the kill pipeline (nectar beads, splats, gibs, body knocked away, combo, frenzy, `onKill` procs, records).

Procs may trigger procs, up to a depth that grows from 2 to 3 in late waves (`Combat.MAX_PROC_DEPTH = 3` is the hard cap).

**Damage to the player** goes through `Player:hurt`: dodge roll, then armour as `15 / (15 + armor)` (negative armour increases damage), block / guard multipliers, at least 0.5 per hit. There are **no invulnerability frames after a hit**: only dashes, blocks, dodge and the frenzy move avoid damage. Raw environmental damage (events, stage hazards) skips player stats and procs (`src/game/envfx.lua`).

## Rendering

The renderer is built so the draw-call count stays around 40 whether there are 250 or 1,500 enemies.

- **One atlas** (`src/gfx/sprites.lua`). Every sprite is a text grid (one character per pixel, a palette of letters, facing right). At load, each is rasterised and **baked in 32 rotations** into one texture, along with shadows, particles, health bars and glow blobs. LÖVE batches consecutive draws from one texture, so the whole horde is a handful of calls.
- **3D-looking bugs.** Playable bugs have a `model`: a body sprite drawn as a **stack of layers** (darker and narrower at the bottom so it reads as a raised shell) over **jointed legs** drawn from a rig of hip, knee and foot points. Feet stay planted while the body moves over them, then lift and swing (tripod gait), kicking up dust. Centipedes and millipedes are `kind = "chain"` models: segments follow the head's path. The body bobs with each step, lunges over planted legs when attacking, recoils when hit and breathes when idle.
- **Attack animations** (`src/gfx/anim.lua`, clips in `src/config/anims.lua`): keyframed clips move the body (lunge, twist, rear, squash) and swing extra 3D limbs (scorpion tail, lobster claws, mantis scythes, stag jaws, spider fangs). Looked up as `"<bug>.<slot>"`, then by the move's type, so a new bug reusing a move still animates.
- **The floor** (`src/gfx/ground.lua`) is pre-rendered once per stage into a canvas (one draw call): per-pixel concrete, lawn, grass blades, cracks, leaves, pebbles from the stage palette. Splats paint onto a persistent **decal canvas** that fades.
- **Draw order** (from `World:draw`): ground → wet ground, horde tracks, decor → hazard zones → burrow mounds, landing shadows, nest holes → route tunnels → director ground layers (puddles, pits, lane warnings) → beads → swarm underlay (soft dark blobs that merge a crowd into one mass), elite auras → shadows (one batch) → props → behaviour `drawUnder` (silk strands) → move effects → telegraphs (with Attack Warnings on) → corpses → threat outlines and rim light → every actor depth-sorted (the enemy array is kept sorted in place by near-linear insertion sort) → particles → air layers (stage hazards, weather) → lighting.
- **Lighting.** A light map is drawn (the player, effects, glowing particles, enemies with a `light` field, night lantern, warning lights) and multiplied over the scene from an ambient colour set by the time of day (`src/game/daylight.lua`). The Bold style adds a highlight roll-off; Glare Guard keeps additive effects from blowing out. A post shader (`src/core/screen.lua`) does brightness, colour filters, colour grade and heat haze.
- **Particles** (`src/gfx/particles.lua`) are pooled pixels with height and bounce, drawn from the atlas; glowing ones get a soft additive halo. Spawns scale down as the pool fills.
- **Painted pictures** (`src/gfx/paint.lua`): anything in the world that isn't an atlas sprite (props, map gambles, the antlion and its pit, the sparrow and anteater in `src/gfx/beasts.lua`) is painted once at runtime in Lua with lit blobs, strokes and a soft outline, then cached.
- **UI** draws at the window's resolution on top of the scaled world canvas, through `src/ui/theme.lua`.

## Performance rules

- Pool everything that is made per frame (enemies, particles, query results). No new tables per spawn: particle colours and options are module constants.
- Rebuild the spatial hash each frame rather than tracking moves.
- Cap what can pile up: stains per second, bodies in the air, glowing-particle lights, hitstop cooldown.
- When hundreds die at once only the first ~40 leave stains and remains.
- `love . --profile --crowd --nojit --cpudraw` benchmarks a fixed horde phone-like (no JIT); `--gclines` lists the lines that allocate the most. `love . --selftest` prints update / draw timings at 250 / 500 / 1,000 / 1,500 enemies.

## Audio (`src/core/audio.lua`, `src/core/music.lua`)

**There are no sound files.** Every effect is synthesised at start-up into SoundData, played through volume buses with voice limits (and positional panning, `Audio.place`).

The **music** is one 8-bar loop in D minor rendered as six stems (pad, arp, bass, drums, lead, queen brass) that always play in sync. The game only changes each stem's volume, so the score follows the fight without ever skipping a beat: calm between waves, bass and drums in a wave, the lead when a big crowd is on you, toms and brass while a queen is out, a slowed fade when you fall. Each **body plan** (spiders and arachnids, beetles, crustaceans, myriapods, flyers, other insects) has its own band that swaps the arp, lead and drums for its own versions, and every bug has a **riff** generated from its id. Stems are cached as WAV files in the save folder; bump `CACHE` after changing the score. `src/game/feedback.lua` plays big-moment sounds (wave horn, clear chime, queen arrival, victory, defeat, low-health heartbeat); `src/game/soundscape.lua` adds ambient sounds and in-key stingers.

## Input (`src/core/input.lua`, `src/core/touch.lua`)

Game code asks about **actions** ("was dash pressed?"), never raw keys, so rebinding and controllers work everywhere. `Input.lastDevice` tells the UI which key caps or pad icons to show (`Theme.glyph`, `Theme.rich` turns `{dash}` in any text into the right key). On touch screens the controls appear by themselves: a floating stick on the left, Special (drag to aim), Dash, Attack, Frenzy, BAG and pause on the right; menus take taps and drags. Touch writes into the same Input (`virtualDown`, `virtualMove`, `virtualAim`, `press`), so game code needs nothing special.

## Saving (`love.filesystem` save folder)

| File | Holds | Code |
| --- | --- | --- |
| `settings.lua` | every setting and key binding | `src/core/settings.lua` |
| `records.lua` | lifetime stats, run history, achievements, amber, unlock progress, daily / weekly bests | `src/game/records.lua`, `amber.lua`, `daily.lua` |
| `prefs.lua` | last bug and mode, favourites, sort, practice setup, artifacts on, keepsake, item pool | `src/game/prefs.lua` |
| `run.lua` | a saved run to resume (bug, mode, map, act route, waves, bag layout, skills, economy, blessings...) | `src/game/runsave.lua` |
| `cosmetics.lua` | chosen location, map decor, skin per bug | `src/game/cosmetics.lua` |
| `tutorial.lua` | which first-run hints were shown | `src/game/tutorial.lua` |
| `customwaves.lua` | wave sets from the wave builder | `src/game/customwaves.lua` |
| `custom_bugs/<id>.lua` | Bug Creator bugs (one script each) | `src/game/custombugs.lua` |
| `music/` | cached music stems | `src/core/music.lua` |
| `playtest_log.csv`, `highlights/` | developer playtest log, highlight screenshots | `src/game/playlog.lua`, `world.lua` |

Saves are Lua tables written as text, so they can be read and fixed by hand. Test runs (`--selftest`, `--profile`, `--balance`) never write them.

## Randomness and seeds

A run has a seed (`world.seed`; `Game.new{ seed = n }` replays it). The species order, wave modifiers, the act route and the daily / weekly runs come from it, which is what makes **run codes** (`swarmed1.<bug>.<map>.<mode>.d<danger>.<seed>.<artifacts>`) and the daily run work. Everything uses `love.math.random` for this reason, even though it is slower on the interpreter.

## Platforms

- **Desktop**: LÖVE 11.4+ with LuaJIT. Discord status talks to the Discord app's local pipe through the FFI.
- **Web**: love.js, plain Lua 5.1. No `goto`, no LuaJIT-only libraries, no FFI (Discord switches itself off).
- **Phones**: the web build, or `swarmed.love` opened in LÖVE for Android. Touch controls, left-handed layout, HUD and button sizes adapt.
