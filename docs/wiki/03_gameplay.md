# Core gameplay systems

## The player's bug

A character file (`content/characters/<id>.lua`) gives a bug its name and texts, sprite and 3D `model`, `stats` (on top of the stat defaults), `radius` and `scale`, `tags` (lineage, item synergies, music band), a `playstyle`, and three moves:

- **`attack`** (left mouse / J / RB, or automatic with Auto Attack on): fires on its cooldown at the aim. With Auto Attack it picks the nearest enemy.
- **`secondary`**, the special (right mouse / K / B): a stronger move on a longer cooldown. Some are held (silk walls, the mantis snatch), aimed by dragging, or charged.
- **`dash`** (Space / Shift / A): every bug's is its own: horn charges, flights, blocks, burrows, grapples, stamina modes.

Each move is `{ type = "<file in content/attacks or content/dashes>", ...params }`. The type file holds the code; the character holds the numbers. So the same move type can be tuned per bug, skill tree nodes can change params by name (`attack = { damage = { mul = 0.12 } }`), and the Bug Creator can mix any move onto any body. The wiki volume lists every type and its params.

**Aiming.** Aim Mode = Mouse aims at the pointer (projected back into world space); the right stick always aims; otherwise moves aim where the bug faces or at the nearest enemy.

**Stamina** (`src/game/stamina.lua`). One pool per bug, shown as the green bar under health, shared by everything dash-like:

- *pressed dashes* cost one charge (`max / charges`); notches on the bar mark charges;
- *hold modes* (tiger beetle run, flights) burn stamina per second while Shift is held;
- *blocks* (lobster, hermit crab, vinegaroon) cost a bit to raise, drain while held and per blocked hit, and **break** when the pool runs dry (locked out until Shift is let go).

Refill starts a moment after the last spend; Dash Cooldown speeds it up. **Dash tech** (`src/game/dashtech.lua`): a kill during a pressed dash refunds half its cost, and dashing again within 0.45 s of the last one ending is 15% faster per link, up to three.

**Statuses on the player.** `stun` (can't act), `blind` (vision shrinks; bald-faced hornets), `gum` (mason bee mud, nasute glue), slows from honey and resin, poison, `latched` driver ants (dash to shake them off), held by a tarantula hawk (mash to struggle). The hissing roach is `immune` to debuffs.

**Bug rules** (`src/config/bugrules.lua`, `src/game/bugrules.lua`): a few bugs bend how items work for them, through hooks on the inventory's triggers (`onEat`, `procChance`, `procRepeats`, `stats`, `start`). Dung Beetle grows from eaten items, Hermit Crab gets an extra bag row but slows per filled cell, Orb Weaver's procs fire twice on webbed ants, Hissing Roach heals double from eating, Scorpion's poison items proc more.

## Enemies and their AI

An enemy file gives stats (`hp`, `speed`, `damage`, `radius`, `mass`, `xp`, `biteRate`), a `family`, a `sprite`, `spawn` rules (`minWave`, `weight`, `groupSize`), a **`behavior`** id with `behaviorParams`, colours for gibs and splats, `tags`, and text (`description`, `lore`, `tip`). Flags add mechanics: `solid`, `shield` (soaks hits for ants behind it), `venom`, `light`, `onDeath`, `noElites`, `noStun`, `boss`.

**Behaviours** (`content/behaviors/*.lua`) are the AI. `update(e, world, dt, params)` sets the desired velocity `e.mx, e.my`; the world integrates movement, separation and knockback. Optional hooks: `init`, `onHit` (react to a hit; returns a damage multiplier), `draw` (telegraphs, shown with Attack Warnings on) and `drawUnder` (things in the world, always drawn). Shared helpers in `src/game/ai.lua`: `AI.toPlayer`, `AI.goTo`, jumps (`startJump` / `updateJump`), `AI.hover`, `AI.sting`, `AI.group` (whole-swarm coordination, e.g. warrior wasps all diving at once), `AI.nearestOther`.

**The swarm look.** Ants spawned together by a stream are linked into a follow-the-leader **column** (`content/behaviors/column.lua`): each ant walks to where the one ahead was a moment ago, so columns snake in from the edge. Within engage range the column breaks into a **ring** that orbits and tightens around you. Ants pack tightly (`personalSpace`), walk with a stop-and-go gait, and share a dark **swarm underlay** (`swarmShade`) so a horde reads as one flowing mass.

**Bites.** Every ant touching you bites on its own `biteRate` timer, and there are no invulnerability frames, so damage scales with the crowd. The HUD warns "SWARMED ×N" and the screen edges turn red.

**Fighting back.** Hitting an ant while it winds up or charges (bullet, soldier, big-headed, bulldog, desert, trap-jaw, Dracula ants) staggers it out of the attack, and a hit during its dash is a counter for +50% damage. Attacks swat acid globs and pebbles back at the ants, faster.

**Engine hooks the behaviours use.** `e.hidden` (burrowed: no damage, targeting, bites or drawing), `e.alpha` (near-invisible cuckoo bees), `e.heldBy` (carried by another enemy or grabbed by you), `player:stun / blind / gum`, hazard zones with `damage`, `pull`, `update` and `draw`, curving projectiles, `world.recentDeaths` (react to kills nearby).

**Elites** (`content/elites`, `src/game/elites.lua`). From wave 2 any ant can roll an affix (Aggressive, Gilded, Armored, Venomous, Volatile, Zombified via jewel wasps): health / damage / speed / mass / scale multipliers, tint and glow, a coloured ground aura, a `safeColor` for the colourblind palette, and effects (armour, venom, bonus XP, death bursts). A species can give an affix its own twist (`elites = { aggressive = { params = {...} } }`). Gilded elites add a card to the next item choice.

**Queens** (`behavior = "queen"`): one per species, keep their distance and lay broods of their own kind until they die. Every queen arrives ringed by a **royal guard** (armored brood); she takes 30% damage until the guard is dead. At half health she enrages (faster, a brood rushes in). The last crowned queen of the final wave is **the Empress**, with two phases. On the middle wave of each act (3, 8, 13) the first elite is a named **champion** ("Cinder, Worker Ant": 3× health, the boss bar, 40 XP and 12 nectar).

## Grabs, throws and props

`src/game/grab.lua` holds and throws ants for grab moves (stag beetle, mantis, jumping spider, dragonfly, emperor scorpion, vinegaroon, rhino horn, whip scorpion). A held ant stops thinking; whoever holds it sets its position. A thrown ant flies along an arc, bowling over every ant it passes, and crashes down. `Grab.collect` lets the same moves pick up **props**: pebbles, twigs and acorns pop off the ground when hit, bounce, squash, chip, spin when struck off-centre, scatter in blasts, knock into each other like marbles, and flatten every ant they roll over while fast (`src/game/props.lua`).

## Items and the bag

`src/game/inventory.lua`. The bag is a **10×3 grid** (one more row every 15 waves survived) of **shaped items**: bars, L's, T's, S's, crosses, blocks, defined by `shape` rows or a `size` rectangle, turnable in quarter turns. **There is nothing to equip: everything in the bag counts**, copies stack, and the only limit is fitting shapes in, so bigger items are stronger for the room they take.

An item file has `name`, `description` / `effect` text, `rarity`, `category`, `tags`, `price`, `stats` (flat adds) and `statsMult` (multipliers), and `procs`:

```lua
procs = { { trigger = "onKill", chance = 0.1, cooldown = 1,
            effect = function(ctx, stacks, state) ... end } }
```

**Triggers:** `onHit`, `onKill`, `onHurt`, `onDash`, `onDodge`, `onBlock`, `onAttack`, `onSpecial`, `onWaveStart`, `onEat` (can raise the HP a meal heals) and `onTick` (every frame). Any system can fire a new trigger name with `inventory:trigger(name, ctx)`; the bug rule, the skill tree and level-up perks see every trigger too. `src/game/itemfx.lua` has helpers for timed effects: every-N-seconds timers, timed buffs, poison patches, trails, orbiting critters, guards and per-item state.

**Chances never reach 100%.** Luck, the proc snowball and extra copies stack hyperbolically (`Inventory.stackChance`). A proc whose effect doesn't grow with copies can set `chanceStack` to fire more often per copy instead. **Proc snowball:** every wave raises all proc chances (+7% a wave, up to ×2.2) and from wave 8 procs can set off one more link of procs.

**Eating** an item removes it and heals by rarity (common 8, uncommon 14, rare 22, legendary 35, molted 50 HP; +25% per extra cell). Cursed items can't be eaten, only scrapped.

**Rarities** (`src/config/rarities.lua`): common, uncommon (from wave 1), rare (wave 3), legendary (wave 6), cursed (wave 3, purple: a big upside with a real cost), molted (never dealt). **Categories** (`src/config/categories.lua`) answer "what is it for": Attack, Elemental, Guard, Mend, Move, Control, Fortune, Cursed. The bag sorts by category, fills each item with its category colour and outlines it in its rarity colour.

**Item icons** are not hand-drawn: `tools/make_item_icons.py` models each item from lit 3D shapes with real materials (gloss, grain, translucency), lit by a warm low sun and cool dusk ambient, at 28 px per cell, then reduces it to a small palette.

{{IMG:item_icons_sheet.png|Item icons modelled in 3D and reduced to a small palette}}

## Parasites (`src/game/parasites.lua`, numbers in `src/config/parasites.lua`)

Ten items of rarity **parasite** (`parasite = true` in `content/items`) live **in your bug instead of the bag**: Flu halves your health and doubles your damage, Cordyceps Puppeteer walks for you, Head Lice breed every wave... Each is a big change to how you play with a real cost.

- They take no bag space and never touch the grid, so nothing can eat, scrap, sell, sort, molt or clone them, but they count like bag items for stats, procs and the HUD item row (`Inventory:recount` adds them in).
- One copy each, a few different ones at most.
- **Void-style feeding**: a parasite can say `feeds = { ids, stats }`. When it gets in, every copy of those items in the bag is devoured and each adds `stats` for good.
- Optional `steer(player, wx, wy, mag, dt, item)` bends your walking; `item.level` is a number a parasite grows (lice, botfly larva), saved with the run.
- **The only cure** is a **Green Mushroom** (`content/props/green_mushroom.lua`): a rare sprout that shows up while you carry one. Walking into it purges every parasite at once.
- A mode or Custom Waves set can turn parasites off with the `parasites` run rule.

## Molting and set bonuses (`src/game/molting.lua`)

Both are about which items **touch** in the bag (share a cell side).

- **Molting** (`content/molts`): when every piece of a recipe touches as one group, the group molts into the recipe's item after the next **queen wave** is cleared (Ember Gland + Bombardier Gland → Magma Gland). Seams between pieces glow teal; a line over the bag says what will molt. Records > Recipes is the recipe book.
- **Tag sets**: three items sharing a tag, all touching in one group, give the tag's set bonus (Warpath +8% Damage, Bulwark +5 Armor...); five give it twice. The bag draws the group's seams in the tag colour.

## Level-ups and skill points

`src/game/levelups.lua`, `src/game/skills.lua`. Kills give XP (`World:grantXP`). The curve is fast: the first level is about ten kills and a 15-wave run reaches about level 35. Each level plays a chime, half a second of slow motion and a ring of light, and opens **three cards right there, mid-wave** (setting: or at the wave's reward bloom).

Cards come from `content/levelcards` in five families: **stat** (small boosts), **pact** (big boost with a cost), **growth** (grows every wave), **perk** (a lasting proc effect that ranks up) and **instant** (happens now). Each card rolls a rarity that multiplies its numbers: common ×1, uncommon ×1.33, rare ×1.66, legendary ×2; Luck tilts the odds.

Every level gives one **skill point**, and **skipping** the pick banks an **extra** one. So every level is a choice between a boost now and a bigger step down the tree. Other systems grant picks with `LevelUps.grant(world, n, { source, minRarity, now })` (brood cells, routes).

{{IMG:selftest_levelup_families.png|Level-up cards: perk, pact, growth and instant families, each with a rolled rarity}}

**Skill trees** (`content/skilltrees/<bug>.lua`): four branches. Three are the bug's own (attack, special, dash/body), each with five tiers: a 3-rank stat node, an upgrade, an either/or **fork**, a stronger upgrade, and a **capstone** that changes how the move plays (echoes, fans of copies, every-Nth empowered strikes, thrown ants that explode, procs). The fourth is a **kin branch** shared by the bug's lineage (`content/skillbranches`: Beetle, Spider, Arachnid, Tidepool, Myriapod, Insect Kin), topped by the tree's own **signature** node. Nodes are plain data: `attack = { damage = { mul = 0.12 } }`, `echo = { move, delay, mult }`, `empower = { every, mods, text }`, `procs = {...}`, `stats = {...}`. A whole tree costs about 45 points, more than the levels of a normal run give, so every run builds differently.

{{IMG:selftest_skilltree.png|The SKILLS tab: three own branches, the kin branch, forks marked OR}}

## Combat feel and rewards (`src/game/rewards.lua`, numbers in `src/config/rewards.lua`)

- **Frenzy meter**: kills fill it (elites and queens more). Full, it unleashes the bug's super move from `content/frenzies` (Quake: a shockwave across the screen; Thunderstorm for flyers). You can't be hurt while it runs, the game slows for a moment, and a short buff follows.
- **Kill streaks**: every 50 kills in one combo (the combo breaks after 2.5 s without a kill) gives a random short buff from `content/streaks`; Carnage needs 150.
- **Hitstop and slow motion are rare on purpose**: the multi-kill hitstop needs 15 kills in one frame and then waits 4 s; slow motion needs 30 and waits 10 s. Heavy hits use `World:hitStop(t)`, which respects the Hit Stop setting.
- **Deaths**: a hit sprays hemolymph along the blow, leaves a wet pool, flings body bits that land and stay, and knocks the body away to darken and fade on the decal layer.
- **Nectar beads**: every kill spills beads worth the ant's XP; inside Pickup Range they drift in faster and faster; close beads merge into bigger ones so a massacre stays readable. At a wave clear every bead flies to you with a chime that climbs note by note.
- **Ground pickups** (`content/pickups`): Nectar Magnet (pull the whole floor), Royal Jelly (frenzy full), Frost Dew (the swarm freezes for 2 s; rare, from wave 4, never again for 60 s).
