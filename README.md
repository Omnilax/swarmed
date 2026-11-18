# Swarmed

A cute, crunchy isometric arena roguelite in LÖVE2D: you play an arthropod holding off endless
hordes of ants. Warriors-style crowd clearing, Brotato-style stat builds, Risk of Rain-style procs.

## Run it

Install [LÖVE 11.4+](https://love2d.org), then from this folder:

```
love .                # normal
love . --sandbox      # straight into the sandbox
love . --selftest     # automated smoke test + horde benchmark, then quits
love . --selftest --specials    # just every bug's attack, special and dash (quick)
love . --selftest --inventory   # just the inventory checks
love . --selftest --hymenoptera # just the bee, wasp and hornet mechanics
love . --roster       # model viewer: every bug walking in place
love . --anims        # attack animation viewer (--shot saves anims_<id>.png contact sheets)
love . --selftest --animtest    # just the attack animation checks
love . --selftest --polish      # just music, event sounds, hints and off-screen markers
love . --selftest --arttour     # pictures of every bug, prop and the antlion for an art check
love . --selftest --entries     # just the ways into the arena (burrows, drops, nest holes, rings)
love . --selftest --runinfo     # just the HUD run info, run summary, death recap and palettes
love . --selftest --happenings  # just mid-wave events, boss encounters, stages, weather effects, props
love . --selftest --props       # rocks and sticks: hit physics, blasts, collisions, every grab attack on them
love . --selftest --hazards     # the sparrow and anteater hazards hunting a run, a screenshot per attack
love . --selftest --gambles     # just map gambles: dewdrop shrine, challenge bell, gamble flower
love . --profile      # scripted massacre; prints where frame time goes, then quits
love . --profile --crowd --nojit --cpudraw   # repeatable crowd benchmark, phone-like (no JIT), Lua cost only
```

The UI font is Pixelify Sans (SIL Open Font License, `assets/fonts`); Settings > Interface > Font
switches to a smooth one.

The title screen runs a live demo fight in the background. **Bug Catalogue** on the main menu
lists every enemy with a preview, stats, lore and a tip (filled in from `content/enemies`).

## Play on a phone

`bash tools/build_web.sh` builds the browser version (love.js) into `../web/`, plus
`../swarmed-web.zip` and `../swarmed.love`. Needs Node.js. Then any of:

- **Same Wi-Fi:** `bash tools/serve_web.sh` and open the address it prints on the phone.
- **Anywhere:** upload `swarmed-web.zip` to itch.io as an HTML game (it can stay unlisted).
- **Android app:** install *LÖVE for Android* from the Play Store and open `swarmed.love` with it.

On a touch screen the controls appear by themselves: the left thumb moves (floating stick), the
right side has **Special** (drag off it to aim, let go to fire; a tap auto-aims), **Dash**, and
**Attack** when Auto Attack is off, plus **BAG** and pause. In the bag, tap an item to pick it up
and tap again to put it down; TURN and EAT act on the held item. Menus take taps, and a drag
scrolls. On a list with a preview (bugs, item cards) the first tap looks and the second picks.
Size, opacity, stick and aim style are in Settings > Controls. `love . --touch` shows the touch
controls on a PC (the mouse presses them). `love . --selftest --touchtest` checks them.

The web build runs plain Lua 5.1, not LuaJIT: no `goto`, and no LuaJIT-only libraries.

## Controls

| Action | Keyboard / mouse | Controller |
| --- | --- | --- |
| Move | WASD / arrows | Left stick / d-pad |
| Dash (each bug has its own) | Space / Left Shift | A / LB |
| Attack (when Auto Attack is off) | Left mouse / J | RB / X |
| Special attack | Right mouse / K | B |
| Aim (when Aim Mode = Mouse) | Mouse | Right stick (always) |
| Inventory / Shop | Tab / I | Y |
| Next wave now (or send the rest of a wave in early) | E / N | Back |
| Unleash Frenzy (when the meter is full) | Q / C | Right or left stick click |
| Pause | Esc / P | Start |
| Quick restart (pause / defeat screen) | R | Y |
| Favourite a bug (bug select) | F | X |

All bindings can be changed in Settings > Controls. With a controller in use, prompts and key
hints show its buttons as icons (`Theme.glyph`); any prompt can name an action as `{dash}` and
`Theme.rich` draws the right key cap, mouse button, pad icon or touch button for it.

## Menus and quality of life

- **Resume** on the title screen picks up a run left with Pause > Save & Quit. Runs also save
  themselves at every wave clear and when the game is closed (`src/game/runsave.lua`). A run
  saved mid-wave plays that wave again. Abandon Run, defeat and End Run delete the save.
- **Play Again** on the title screen starts the last bug and mode in one press. Pause and the
  defeat screen restart the same setup; the defeat screen can also go straight to bug select.
- **Bug select** sorts (speed, health, size, armour, playstyle, name) and filters (playstyle,
  favourites) from `src/config/playstyles.lua`; favourites are pinned on top. A live preview
  shows the highlighted bug's special and dash (`src/ui/movepreview.lua`).
- Each bug has a `playstyle` and a one-time `tip` (content/characters), shown in its first run.
- **Practice** (title screen): pick a bug, mode, starting wave and one species (or a boss, or
  "Mixed"), optionally with the items and skill points a real run would have, and invincibility.
  Practice never counts toward records and is never saved (`src/states/practice.lua`).
- Settings > Video starts with **Preset** (Performance / Balanced / Pretty,
  `src/config/settings_presets.lua`). Settings > Controls has **Touch Layout** (left handed
  mirrors the touch controls) and **Touch Button Size**.
- The game pauses when it loses focus, is minimised or the controller in use is unplugged.
- What the menus remember (last bug and mode, favourites, sort, practice setup) is in `prefs.lua`
  in the save folder (`src/game/prefs.lua`). Test all of it with `love . --selftest --qol`.

## Frenzy, streaks and combat rewards

All of this lives in `src/game/rewards.lua` (one per run, `world.rewards`) and its helpers, with
the numbers in `src/config/rewards.lua` (a game mode can override them with `rewards = {...}`).

- **Frenzy meter** (right side, under the KO counter): every kill fills it (elites and queens
  more). When it is full, press Q (or tap FRENZY) to unleash the bug's super move from
  `content/frenzies`: Quake (a shockwave across the whole screen) by default, Thunderstorm for
  flyers. You can't be hurt while it runs, the game slows for a moment, and a short attack-speed
  and speed buff follows. Settings > Gameplay > Auto Frenzy sets it off by itself.
- **Kill streaks**: every 50 kills in one combo gives a short random buff from `content/streaks`
  (Bloodrush, Rage, Flurry, Fortune; Carnage from a 150 combo).
- **Big moments**: on top of the hitstop, a huge multi-kill, a queen falling and the frenzy move
  get slow motion (Settings > Gameplay > Slow Motion) and a quick camera zoom punch.
  Freezes are kept rare: the multi-kill hitstop needs 15 kills in one frame and then waits 4 s,
  the slow-mo needs 30 and waits 10 s, and heavy hits use `World:hitStop(t)`, which respects the
  Hit Stop setting and scales by `feel.stopScale`. All the numbers are in `src/config/rewards.lua`.
- **Mini-goals**: from wave 2, some waves come with an optional side task from `content/goals`:
  stop the courier ant before it crosses the arena, guard the aphid (some ants go for it),
  reach a combo, or get a burst of KOs in a few seconds. Success pays bonus XP and frenzy.
- **Treasure ant**: from wave 3, sometimes a gilded ant pops out mid-wave and runs. Catch it within
  14 s for a pile of XP and half a frenzy meter; otherwise it burrows away (no KO, no reward).
- **Route gates**: after a wave, two tunnels open beside you. Walk into the safe one (fewer ants,
  no elites) or the hard one (more ants, more elites or tougher ants) to start the next wave that
  way; clearing a hard route pays XP, frenzy or a rarer best card in the next item choice. Ignore
  them for a normal wave. Needs a break between waves; never before the final wave.
- **Proc snowball**: every wave raises all item proc chances (+7% a wave, up to x2.2), and from
  wave 8 procs can set off one more link of procs, so late runs fill the screen with chains.

Test: `love . --selftest --combat`.

## Nectar beads and pickups

- **Nectar beads**: every kill spills golden beads worth the ant's XP (a gilded elite's holds its
  bonus too). Walk near them: inside your **Pickup Range** they drift in faster and faster, and
  each one gives skill XP and **nectar**, the run's currency (the gold counter next to your HP).
  Beads that land close together merge into a bigger bead, so a massacre stays readable and fast.
- **Wave-end magnet**: when a wave is cleared every bead left on the floor flies to you, with a
  chime that climbs note by note. Nothing is ever lost.
- **Pickups** (glowing tokens, never items): a rare **Nectar Magnet** from any ant pulls in the
  whole floor; elites sometimes drop **Royal Jelly** (frenzy meter full) or, rarely, **Frost Dew**
  (the swarm freezes solid for 2 s: no moving, no biting; only from wave 4, the least likely elite
  pickup, and never again for 60 s after a freeze or while one is lying around). Uncollected pickups blink, then fade.
- Settings > Gameplay > **Auto Collect Nectar**: beads and pickups fly to you from anywhere.
- Console: `nectar [n]`, `pickup <id>`. Numbers: `src/config/nectar.lua`.
- For code that spends nectar (shop, shrines), the API is at the top of `src/game/nectar.lua`:
  `world.nectar`, `World:addNectar`, `World:spendNectar`, `World:canAffordNectar`, event `nectar_changed`.

Test: `love . --selftest --nectar`.

## Nectar shop, interest, scrapper and cursed items

- **Shop**: the SHOP tab of the inventory window (Tab, then E / RB or click the tab; screen
  `src/states/shop.lua`). It is open the whole run (the window pauses the game). 3 items and 1 stat
  boost for nectar, two presses to buy. The stock **restocks every minute of play**; the HUD shows
  the clock under the nectar count and "NEW STOCK" until you look. Items with `shopSpeed` restock it
  faster (Forager's Leaf +25%, Honeypot Ant +40%, they add up; never under 15 s). LOCK keeps an
  offer through restocks; REROLL costs nectar and gets dearer until the next restock. Prices rise
  every wave. A bought item that doesn't fit opens the BAG tab holding it.
- **Savings interest**: the moment a wave is cleared, banked nectar earns 10% (capped, the cap grows each wave).
- **Scrapper**: SCRAP in the bag's header (drop or click a held item on it, G, pad right stick
  click, or the SCRAP touch button) turns an item into nectar. Rare or better items also give back a
  free-pick reroll.
- **Cursed items** (purple, from wave 3): a big upside with a real cost, written in purple on the
  card. They can't be eaten, only scrapped (for nothing). Hungry Tapeworm, Glass Wings, Fool's Gold
  Scarab, Queen's Pheromone, Bullet Ant Venom, Parasitoid Egg.
- **Hyperbolic stacking**: Luck, the proc snowball and extra copies never push a chance to 100%
  (`Inventory.stackChance`). A proc whose effect doesn't grow with copies can set `chanceStack` to
  fire more often per copy instead. The bag tooltip shows each item's chance right now. Dodge has a
  soft cap: past 30% each point counts for less and it never reaches 60% (stat `soft = { knee, cap }`).
- Numbers: `src/config/shop.lua` (a mode can override with `shop = { ... }`, or `shop = false`).
  Code: `src/game/economy.lua`. The balance bot pays interest and shops too.

Test: `love . --selftest --economy`.

## Inventory

Press **I** (or **B**) for the inventory, modelled on FATE: a small 10x3 bag (one more row every 15 waves) where items come in shapes (bars,
L's, T's, S's, crosses, blocks). There is nothing to equip: **everything in the bag affects your
bug**, copies of an item stack, and the only limit is puzzling the shapes in, so bigger items are
stronger for the room they take. Left click picks up and puts down (swapping with one item
underneath), right click or the mouse wheel turns the held item a quarter (R / LB on keys and
pad), and right click an item (F / X) to **eat** it: it's gone and heals you by its rarity
(common 8, uncommon 14, rare 22, legendary 35 HP, `eat` in `src/config/rarities.lua`), +25% per
extra cell. Ants don't drop items: after **every wave you choose 1 of 3 random items** (a boss
wave guarantees a rare or better; each gilded elite you killed adds a 4th/5th card). If the pick
doesn't fit, the bag opens holding it so you can make room or eat something. **Item choice helpers**: REROLL (R / pad X) redraws every unlocked card (3 per run, +1 per
queen slain), LOCK (L / pad RB, free) keeps a card for the next item choice, and BAN (X / Del /
pad Y, press twice, 2 per run) removes an item from the run. Numbers live in
`src/config/itemchoice.lua`; a mode can override them with `itemChoice = { ... }`. Cards show the
item's tags (lit, with a count, when bag items share them; colours in `src/config/tags.lua`) and
a stat preview such as "Speed 120 » 138". In the bag, **SORT** (T / pad L3) packs items tidily,
dragging an item out of the case eats it, and pointing at a stat explains its number (each
stat's `info` in `src/config/stats.lua`). The pause screen lists every stat and every item's
full effect. Test: `love . --selftest --choiceqol`. Bag size lives in
`src/config/equipment.lua`; an item's `shape` (or `size`), `icon` and `effect` text in its file;
icons are modelled by `tools/make_item_icons.py` (needs numpy) with a small renderer in `tools/icon_render.py`: each item is built from lit 3D shapes with real materials (gloss, grain, translucency), lit by a warm low sun and cool dusk ambient, at 28 px per cell, then reduced to a small palette. `render_fit` zooms each drawing so it fills its cells, and the sun side gets a thin lit edge so dark items still stand out in the dark bag. `python3 tools/make_item_icons.py --preview out.png [ids]` renders a contact sheet.

**Item categories.** Every item has one `category` saying what it is FOR (`src/config/categories.lua`):
Attack, Elemental, Guard, Mend, Move, Control, Fortune, Cursed. Tags are the many themes an item
shares for set bonuses; the category is the one big answer. In the bag an item's fill is its
category colour (its outline is its rarity) with a small category badge (Interface > Item Category
Badges), SORT lines the bag up by category (Interface > Bag Sort Order: category, rarity or size;
it falls back to packing by size when the bag is too full), the shop lines its new offers up by
category, cards and tooltips show a category chip, and the Item Catalogue groups by category or
rarity (G). An item without `category` gets a guess from its rarity and tags. Test:
`love . --selftest --itemorg`.

There are 67 items, drawn from Risk of Rain, Isaac and Brotato and themed on things a bug finds
in the dirt: microbes (tardigrade, nematode, amoeba, rotifer, bacterial bloom, slime mold, gut
flora), fungi (cordyceps, fly agaric, puffball, lichen, mycelium), bug parts, plants (venus
flytrap, burdock burr, dandelion, pine cone, nettle, aloe...) and finds (amber, quartz,
fulgurite, trilobite fossil, honeycomb, snail shell). Proc triggers: `onHit`, `onKill`,
`onHurt`, `onDash`, `onDodge`, `onWaveStart`, `onEat` (can raise the HP a meal heals) and
`onTick` (every frame). `src/game/itemfx.lua` has the helpers for timed effects: every-N-seconds
timers, timed buffs, poison patches on the ground, orbiting critters and per-item state.
`love . --selftest --items` fires every item's procs in a live fight.

## Molting, tag sets, brood cells and the aphid matriarch

**Molting.** Some items molt into a stronger one when they **touch in the bag** (sides, not
corners): Ember Gland + Bombardier Gland become a Magma Gland, Dew Drop + Honeydew a Nectar Pearl,
and so on (13 recipes in `content/molts`, a few take three pieces). Nothing happens straight
away: the molt comes when a **queen wave is cleared**, and the new item takes the old ones' place.
Molted items (rarity "Molted", `src/config/rarities.lua`) are never dealt in item choices. In the
bag, the seams between pieces that will molt **glow** (pulsing teal; dim for two pieces of a
three-piece recipe), a line over the case says what molts after the next queen, and an item's
tooltip lists what it molts with. **Records > Recipes** is the recipe book: every recipe's pieces,
with the result shown once you have molted it.

**Tag sets.** Three items sharing a tag, all touching in one group, give the tag's set bonus
(Warpath +8% Damage for offense, Bulwark +5 Armor for defense...); five give it twice. The bag
draws the group's seams in the tag's colour and lists active sets over the case. Bonuses are the
`set` field of each tag in `src/config/tags.lua`; thresholds in `src/config/molting.lua`.

**Brood cell chests.** A slain queen drops a royal brood cell, a caught treasure ant a plain one.
Walk into it (or clear the wave: it opens by itself) and a fanfare rolls **1, 3 or 5 level-up
cards** (queen odds 50/38/12, treasure 74/22/4; Luck shifts them up). The cards go to the level-up
card picks (`src/game/levelups.lua` `grant`); without that system each card is 25 XP.

**The aphid matriarch** (`content/events/aphid_matriarch.lua`) is a rare map event from wave 5
(only when your bag has two items of one rarity). Walk into her, pick an item to clone, then feed
her another item of the same rarity (press it twice): she gives birth to a copy and leaves.

Numbers: `src/config/molting.lua`. Code: `src/game/molting.lua`, `src/game/duplicate.lua`,
`src/states/broodcell.lua`, `src/states/duplicate.lua`. Molted item icons:
`tools/make_molt_icons.py` (writes `content/sprites/molts.lua`). Test: `love . --selftest --molts`.

## Game modes

Play opens the mode select, then the bug select. Modes are files in `content/modes/` (schema in
`content/modes/_template.lua`), so a new mode is a new file. Shipped modes:

- **Larvae** (beginner): smaller, weaker waves, long breaks, a new species every other wave, no elites.
- **Colony** (standard): every family, 15 waves, queen every 5th.
- **Swarm** (hard): more columns from more sides, tougher ants, short breaks, elites twice as often.
- **Anthill**, **Hive**, **Mound**: ants only, bees/wasps/hornets only, termites only. Hive has no
  queens yet, so its boss waves bring the mode's `bossPool` (giant hornet, tarantula hawk, European hornet).
- **Champions**: small groups, every enemy is an elite.
- **Endless**: pick starting items on a point budget (`src/states/loadout.lua`), then no waves and no
  breaks; the level climbs every 40 s with a new species, a queen every 5 levels, an item choice every 3.
- **Gauntlet**: ten hand-made scripted waves, the same every run (`waves` in `content/modes/gauntlet.lua`).
- **Royal Court** (boss rush): a queen every wave for ten waves, a new species each wave too.
- **Blitz**: a short run, eight huge waves with no breaks, two new species a wave, faster level-ups.
- **Mayhem**: one or two wave modifiers on every wave from the first, extra mid-wave events, and a
  boss encounter or stage hazard every third wave.
- **Custom Waves**: opens the wave builder (`src/states/wavebuilder.lua`) instead of going straight to
  the bug select. Make sets of waves: for each wave, up to six groups (species and how many), a queen,
  up to three wave modifiers, up to four events and a boss encounter / stage hazard; per set, enemy
  health, damage, growth per wave and elites. Sets save to `customwaves.lua` in the save folder
  (`src/game/customwaves.lua`). Copy Set puts a set on the clipboard as a Lua table and Paste Set reads
  one back (it runs with no globals and a step limit, so pasted text can only be data); the same table
  works as a mode file's `waves`. Clearing the last wave wins; Keep Going loops the set, tougher.
  Custom wins count for the mode's own record only (no bug wins, danger mastery or achievements).

- **Daily Run** (bottom of the mode list): today's date seeds the bug, the stage, the species order
  and every wave modifier, so everyone gets the same run that day (Colony rules). The best result
  per day is kept in the records save (`src/game/daily.lua`).

A mode can override any stage wave setting (`spawn`), restrict enemies (`families`, `enemies`,
`exclude`), scale enemy health and damage, change elite odds, and set `finalWave` (false = no end).
Scripted modes (`waves = {...}`) send exactly what each wave lists instead of the usual one-new-species
rhythm. `love . --selftest --modes` plays six waves of each mode and checks who came;
`love . --selftest --customwaves` checks the builder, pasting, a custom run's exact counts and the scripted modes.

## Characters

Twelve playable bugs, each with its own attack, right-click special (`content/attacks`) and
Shift dash (`content/dashes`):

| Bug | Attack | Special (right click) | Dash (Shift) |
| --- | --- | --- | --- |
| Rhino Beetle | wide horn sweep that sends ants flying | horn pierce through a whole line | horn charge: scoops ants onto the horn and heaves them onto the crowd |
| Wolf Spider | venom bursts all around | spiderlings pour off its back and hunt ants down | long dash |
| Bombardier Beetle | boiling spray cone that pierces lines | grenade: lobbed boiling bomb | blast: explodes and flies the other way |
| Tiger Beetle | sprint strike through the crowd | rampage: a string of sprint cuts | very long, fast dash |
| Stag Beetle | heavy antler-jaw swings | grabs the biggest ant, swings it round as a club, hurls it | clumsy flight: steer it through the air, crash-land with a thud |
| Scorpion | pincer snaps, then a tail sting | venom sting | tail flick: springs backwards, stinging the spot it left |
| Lobster | crusher claw slam shockwave | tail spin | no dash: hold to block all damage, shuffle slowly |
| Centipede | blur of fast venom-claw jabs | tail stab: hooked rear pincers stab backwards | ramming dash |
| Jumping Spider | pounces onto the nearest ant | dragline yank: reels an ant in and bites it | safety line: leap where you point, press again to zip back |
| Tarantula | flicks irritating hairs | fang slam: rears up and crashes down, stunning | ramming dash |
| Orb Weaver | silk balls that burst into webs | hold to draw sticky silk walls that hold ants back | web grapple: swing in with momentum, let go to fly |
| Mantis | twin scything slashes | snatch up to 3 ants: hold to munch (heals), let go to fling | flutter hop, two in a row |

Their 3D models (stacked body + jointed legs) come from `tools/make_bug_sprites.py`; new bodies use
the generic `critter()` builder there (body blobs, leg points, decorations). The generator also
writes each bug's leg joints (`rig`), and the game draws real 3D legs from them: feet stay planted
while the body moves over them, then lift and swing the way the bug is walking (tripod gait).
The centipede is a `kind = "chain"` model: segments follow the head's path with a wave of legs.
`love . --roster` shows every model walking in place.

Every bug has a dash of its own. The last seven to get one (round 16): assassin bug **ambush**
(dart in, beak into the first ant, heal, spring back), emperor scorpion **claw wall** (hold:
front hits glance off, ants ahead bulldozed), hissing roach **scurry** (3 charges, startles,
speed burst after), plus the rhino, stag, scorpion and jumping spider dashes above.
`love . --selftest --dashes` checks all seven.

All dashes share one **stamina** pool (`src/game/stamina.lua`), shown as the green bar under
health. A pressed dash costs one charge's worth (notches mark them), hold-Shift modes burn it
per second, and blocks (lobster, hermit crab, vinegaroon) drain it while held, cost a bit to
raise and per hit, and break when it runs dry (locked out until Shift is let go). Dash Cooldown
items speed up the refill.

Attack animations (`src/gfx/anim.lua`, clips in `src/config/anims.lua`): when a bug attacks,
uses its special or dashes, a keyframed clip moves the body over its planted legs (lunge,
twist, rear up, squash, front legs reaching) and can swing extra jointed limbs drawn in 3D: the
scorpion's tail arcing over to sting, lobster claws raised and slammed, mantis scythes, stag
jaws scissoring, spider fangs. A character can carry its own clips as
`anims = { attack = ..., secondary = ..., dash = ... }`; otherwise the library is checked for
`"<character id>.<slot>"`, then for the move's type id, so a new bug reusing a move still gets a
body animation. Clips can hold a pose while a move is held (blocking, carrying, charging).
`love . --anims` previews every clip.

Specials are attacks in `content/attacks` like any other; ones with a held part (silk walls,
the mantis snatch) also have `update(player, world, dt, params, held, pointerX, pointerY)` and
can `draw`. `src/game/grab.lua` holds and throws ants for grab specials.

## Bug Creator (custom bugs)

Main menu > **Bug Creator** makes your own playable bugs: **Mix Parts** (one bug's body, another's
attack, special and dash, plus size, colour, stats, an item rule and a skill tree, with a live
preview) or **Write a Script** (a bug is a small sandboxed Lua script; start from
`content/characters/_custom_blueprint.lua`). Scripts can be pasted in, dropped on the window,
copied out to share, and live in the save folder's `custom_bugs/`. A script can make a completely
new bug: its own pixel art, legs, claws and tails or a segmented body, moves written in code
(press, hold-to-charge, hold, stamina modes), code on game events, its own animations, sounds and
skill tree (examples: Stick Insect, Velvet Worm). Every field, move type and
safety limit is in **[docs/CUSTOM_BUGS.md](docs/CUSTOM_BUGS.md)**. Test: `love . --selftest --creator`.

## Skill trees

Every bug has its own skill tree (`content/skilltrees/<character>.lua`, schema in `_template.lua`,
engine `src/game/skills.lua`). Kills give XP and every level opens a level-up card pick; the cards
are stat boosts only, and **skipping** a pick is what banks a **skill point** (so each level is a
boost now or a step down the tree). Spend points in the bag's **SKILLS** tab (Tab, then E / RB, or
tap the tab). A tree has four branches:

- three of the bug's own (attack, special, dash/body), each with a one-line blurb under its name and
  five tiers: a 3-rank stat node, an upgrade, an either/or fork, a stronger upgrade and a capstone
  that changes how a move plays (echoes, fans of extra copies, every-Nth empowered strikes, thrown
  ants that land as explosions, procs on kills and hits...);
- a fourth **kin** branch shared by the bug's lineage (`content/skillbranches`: Beetle, Spider,
  Arachnid, Tidepool, Myriapod and Insect Kin, matched by character tags and priority), topped by the
  tree's own **signature** node (`signature = {...}` in the tree file), the bug's own trick.

A whole tree costs ~45 points, more than a run that skipped every pick could earn, so every run
builds the bug differently. The screen shows points spent per branch, what a locked node needs and
which fork side a node would close. The sandbox's Player tab has **+5 skill points** and **Reset
skill tree**; `love . --selftest --skills` buys every node of every tree (both fork sides) and
fights with it.

## Wave rewards: the reward bloom

A cleared wave's rewards are a moment in the arena, not a pile of screens (`src/game/rewardflow.lua`,
prop `content/props/reward_bloom.lua`, numbers `src/config/bloom.lua`):

1. A glowing **reward bloom** sprouts next to your bug, labelled with what is inside ("an item";
   with Level-Up Cards: At Wave End, also "2 level-ups"). Walk into it to open it. Next Wave (E) brings it to you, and left alone it rolls to you
   after 5 s. The break before the next wave waits for it.
2. It bursts and the item choice opens (with At Wave End level-ups, a **steps strip** at the top,
   LEVEL 7 > LEVEL 8 > ITEM, shows where you are and what is left).
3. What you took **flies out of the bloom into your bug**, and a card on the left of the screen says
   what you got and what it does (NEW ITEM, LEVEL CARD, SKIPPED, BOUGHT...). Shop buys and level-ups
   outside the bloom use the same cards.

Setting **Wave Rewards: Open at Once** skips the walk. Test: `love . --selftest --rewards`.

## Inventory window

**Tab** (or I, pad Y, the BAG touch button, or Pause > Inventory & Shop) opens one window with three
tabs: **BAG**, **SKILLS** and **SHOP** (`src/states/bagtabs.lua`). E / Q (pad RB / LB) or a click
switches tabs; Tab, Esc or pad B closes it. The sandbox panel moved to F2.

## Level-up cards

Each level is a pick of 3 cards (`src/game/levelups.lua`, screen `src/states/levelup.lua`, numbers
in `src/config/levelups.lua`): global stat cards (`content/levelcards`, e.g. +6% Speed, +1 Armor). Stat cards roll a rarity,
common x1 / uncommon x1.33 / rare x1.66 / legendary x2, and Luck makes the rarer rolls likelier.
The XP curve is fast: the first level is ~10 kills and a 15-wave run reaches about level 35.
Levels play a chime, half a second of slow motion and a ring of light; the cards open right
there, mid-wave, so each level's reward is picked the moment you earn it (setting **Level-Up Cards:
At Wave End** saves them for the wave's reward bloom instead). The skill tree is never on the cards:
**Skip (+1 skill point)** under the cards takes none of them and banks a point for the SKILLS tab,
the only way to earn skill points. Setting
**Level-Ups: Skill Points** brings back the old way (every level is a point). Other systems grant
picks with `require("src.game.levelups").grant(world, n, { source = "chest", minRarity = "rare", now = true })`.
Sandbox Player tab: **Level-up card pick**. Test: `love . --selftest --levelups`.

## Gentle Start (new players)

A new player meets the game a piece at a time (`src/game/onramp.lua`, numbers and card text in
`src/config/onramp.lua`). In the first run: no elites before wave 4, the treasure ant from wave 3,
and the nectar shop (with the nectar counter) from wave 3. Mini-goals, wave twists, garden events
and map gambles join in run 2, route tunnels and big visitors in run 3, and until run 4 a wave has
at most one event and never one beside a visitor. The first time each system shows up, a short
"NEW" card explains it; from then on it is never held back again. Saves with 6+ runs count as
met everything. Practice, the daily run, custom waves and modes with `onramp = false` skip it.
Setting: Gameplay > **Gentle Start**. Systems ask `OnRamp.allows(world, id, wave)`.

**Playtest Log** (Developer): one CSV line per cleared wave and at the end of a run (time, damage
taken, KOs, level, items, nectar) in `playtest_log.csv` in the save folder (`src/game/playlog.lua`).

Test: `love . --selftest --gentle`.

## Tutorial and Field Guide

- **Tutorial** (main menu; "Tutorial (start here)" until it is finished once): a guided fight
  in `content/modes/tutorial.lua` (a hidden mode) run by `src/game/lessons.lua`. The colony's
  own waves are off; 14 lessons each bring in what they need and move on when done: move,
  attack, dash, special, the swarm, nectar, a level-up, an item choice, the bag, the shop,
  frenzy, an elite, a queen. A panel at the top shows the current lesson. Nobody can fall in
  it, it isn't tracked or saved, and it ends back on the title screen.
- **Field Guide** (main menu and pause): one short page for every system
  (`src/config/guide.lua`), a set-bonus page written from `src/config/tags.lua`, and the bug
  and item catalogues. Pages for systems Gentle Start hasn't shown yet read "? ? ?" until met.

Test: `love . --selftest --tutorial`.

## Amber and the Burrow

**Amber** is the currency kept between runs (`src/game/amber.lua`, numbers and stock in
`src/config/amber.lua`, kept in the records save). Every run that got going pays some when it
ends, won or lost: 2 a wave cleared, 4 a queen, 1 per 10 elites, 1 per 200 KOs, 20 for a win
(Custom Waves pay half). The defeat and victory screens show what the run paid and how much more
the next unlock needs. A save that already had 6+ runs gets a one-time head start (5 a run, up to 250).

**The Burrow** (main menu, `src/states/burrow.lua`) spends it on new things to find, never on raw
power: item packs (their items stay out of every item choice and the shop until bought), maps
(Cosmetics > Location), modes (shown as locked in mode select until bought; a mode played before
amber stays open) and, from the next step, artifacts. Press once to look, twice to buy. Unlock
Everything opens it all. API: `Amber.owns/itemOpen/stageOpen/modeOpen/buy/next/runLine`.

The main menu is shorter: the bug and item catalogues live in the Field Guide, Practice moved
into mode select, and the Tutorial button shows until the tutorial is finished once (then it is
in the Field Guide).

Test: `love . --selftest --amber`.

## Artifacts

Run rules for any mode, like Risk of Rain 2's (`content/artifacts`, schema in `_template.lua`,
`src/game/artifacts.lua`). Each is bought once in the Burrow (its own shelf, made from the
content folder), then switched on or off in mode select > **Artifacts** (kept in prefs). They
stay on for every run until switched off; the first wave's banner names them; a saved run keeps
its own list; the daily run, practice and the tutorial ignore them. An artifact can change the
Game params before the world is made (`params`, Metamorphosis picks the bug) and the world after
(`apply`: `world.danger` multipliers, player stat modifiers, the frenzy meter...).

Glass Carapace, Teeming, Giants, Royal Guard, Twin Queens (a second queen every queen wave,
`danger.twinQueens`), Heatwave, Mixed Colony, Frenzy Tide, Metamorphosis.

Test: `love . --selftest --artifacts`.

## Maps and their wildlife

Every stage can have its own `fauna` (content/stages): how much more often each species or
family turns up there (`desert_ant = 5`, `termite = 2`, `bee = 0.15`; 0 = never, `other` = the
rest, the id beats the family) and `first`, the species that opens wave 1. Favoured species are
also met sooner in the run (`Spawner:faunaMul`, `Pacing.shuffleOrder`). A mode's own families
still apply on top. Content checks every fauna key at start-up.

New maps (bought in the Burrow): **Dune Field** (desert, honeypot and pebble ants, velvet ants,
sand wasps, harvester termites), **Rainforest Floor** (army, driver and bullet ants, leafcutters,
orchid and stingless bees), **Rotting Log** (termites, wood ants, carpenter bees) and
**Wildflower Meadow** (bees, wasps and hornets). The old maps got a lighter touch of fauna too
(Sandstone Wash leans desert, Mossy Flagstones woodland, the lawn fire ants...).

Mode select opens on a **Map** row (left and right to change, any open map) with the map's
description and who lives there.

Test: `love . --selftest --maps`.

## One currency, a cleaner HUD

A run has one currency, nectar. The merchant beetle sells for nectar too, a fifth under shop
price (each later sale 25% more), instead of its own count of KOs.

Settings > Interface > **HUD Detail**: Full (the default) or Clean. Clean keeps health, stamina,
XP, the frenzy meter and how many enemies are left, and hides the run timer, KO counter, KO
milestones and the next-wave preview. With Enemies Left on, the line under the wave title no
longer repeats the count.

Test: `love . --selftest --flow`.

## Three acts per run

A 15-wave run is three acts of five waves, each on its own map (src/game/acts.lua). The route
is planned when the run starts: act 1 is the map you picked, acts 2 and 3 are other maps you
have open, so every map bought in the Burrow can turn up mid-run (seeded: the same seed takes the
same route). After the queen of waves 5 and 10, her rewards and the shop, the break line says
where the colony goes next; starting the next wave carries the whole run there (through a run
save, as if resumed), with an "Act 2 of 3" card and a breather.

Not in practice, the daily run, endless, custom or scripted waves, or modes with `acts = false`.
Gentle Start holds it back until the second run. Settings > Gameplay > **Travel Between Acts**
off keeps a run on one map.

The victory screen closes the story with the maps the run crossed ("From Backyard Patio to Dune
Field to Mossy Flagstones. The Empress has fallen."); a mode can set its own `ending`.

Test: `love . --selftest --acts`.

## Queens, the Empress and champions

src/game/bosses.lua, numbers and names in src/config/bosses.lua.

- **Title cards**: a queen walking in gets a card across the lower screen with her name and an
  epithet for the map ("Desert Queen, the Sun-Baked").
- **Phases**: at half health a queen enrages: faster, and her brood rushes in around her.
- **The Empress**: the last crowned queen of the final wave, with her own card and two phases
  (two thirds and one third health).
- **Named champions**: on the middle wave of each act (3, 8, 13) the first elite is a champion
  with a name ("Cinder, Worker Ant"), three times the health and the boss bar while no queen is
  about. She pays 40 XP and 12 nectar. Held back with elites by Gentle Start.

Test: `love . --selftest --bosses`.

## Keepsakes

One small trade your bug carries into a run (src/config/keepsakes.lua, src/game/keepsakes.lua).
Bought with amber on the Burrow's Keepsakes shelf, then picked on the **Keepsake** row in mode
select (the row shows once you own one). Each trades one thing for another, never a straight
gain: Snail Shell (more health, slower), Wasp Sting (more damage, less health), Dragonfly Wing
(faster, less damage), Honey Jar (30 nectar to start, less nectar earned), Old Map (more XP, less
nectar), Pill Bug Plate (bites hurt less, slower attacks). A saved run keeps its keepsake; the
daily run, practice and the tutorial take none.

## Weekly challenge

Mode select > **Weekly Challenge**: a new one every Monday (src/game/daily.lua `Daily.weekInfo`).
The week's seed picks the bug, the map and two artifacts, which are on whether you own them or
not, so it is a taste of rules you may not have bought yet. Colony rules, no keepsake, one map
all run. Your best is kept with the daily results under the week's key ("2026-W46").

Test: `love . --selftest --keepsakes`.

## Run codes

Game over and victory have **Copy Run Code**: a line like
`swarmed1.rhino_beetle.dune_field.colony.d2.mi4r7153.giants` (bug, first map, mode, danger,
seed, artifacts). Mode select > **Play a Run Code** reads it from the clipboard and starts the same
run. The bug must be unlocked; the code's artifacts are on whether you own them or not; keepsakes
are left out. Practice, custom waves and the tutorial have no code (src/game/runcode.lua).

Test: `love . --selftest --runcode`.

## Sealed cocoons

From wave 4, an item choice sometimes (15%) deals one card as a **Sealed Cocoon**: rare or
better, but its name, shape and stats stay hidden until you take it (`Choices.seal`,
`Choices.SEALED` in src/game/choices.lua). Locked cards are never sealed.

## Records and achievements

**Records** on the main menu keeps the save (`records.lua` in the save folder, `src/game/records.lua`):
lifetime totals and a page per bug (runs, wins, best wave, kills), the last 50 runs (bug, mode,
wave, time, KOs, most-squashed species, the bag it ended with), kills per species and family,
and achievements. Only real runs count (not the sandbox or the title screen demo); a run is
saved at every wave clear and when it ends (falling, quitting, or closing the game).

Achievements are data in `content/achievements` (schema in `_template.lua`): a `value(profile,
run)` and a `goal`, checked twice a second during a run. Several files generate their entries
from other content (one per bug, family, elite affix and game mode), so new bugs and modes get
achievements on their own. Unlocks slide in at the top right. Run events it listens to:
`enemy_died`, `player_hurt`, `wave_started`, `wave_cleared`, `run_won`, `item_taken`,
`item_eaten`, `player_died`. `love . --selftest --records` checks it all without touching the save.

## Unlocks, danger levels and mastery

- **Unlocks.** Eight bugs are open from the start (`src/config/unlocks.lua` `starters`); the other
  18 each open through an in-run goal ("Clear wave 5 as the Rhino Beetle", "Kill 25 ants mid-dash
  in one run"...). A few items are locked the same way and stay out of item choices until then.
  Goals are achievements in the Records screen's **Unlocks** category (`content/achievements/unlocks.lua`),
  so progress shows there and an "Unlocked" card pops up mid-run. Bugs already played before
  unlocks existed stay open. Settings > Gameplay > **Unlock Everything** opens it all.
- **Item pool.** Settings > Gameplay > **Item Pool...** switches items in or out of the item
  choices (at least 12 stay in). Saved in `prefs.lua`.
- **Bug rules.** Some bugs bend how items work for them (`src/config/bugrules.lua`, run by
  `src/game/bugrules.lua`): Dung Beetle gets stronger from eaten items, Hermit Crab starts with an
  extra bag row but slows per filled cell, Orb Weaver's procs fire twice on webbed ants, Hissing
  Roach heals double from eating, Scorpion's poison items proc more. Shown on bug select.
- **Danger levels.** Left/Right on a bug in bug select picks Danger 0-5 (`src/config/danger.lua`):
  each level adds one rule (more elites, less healing, faster ants, tougher ants, bigger groups and
  an extra crowned queen). Winning at a level opens the next one for that bug; the highest level
  won shows as mastery stars and is kept in Records (`characters[id].danger`).
- **Dash tech.** A kill during a pressed dash (or just after) refunds half its stamina; dashing
  again within 0.45 s of the last one ending is 15% faster per link, up to 3 (`src/game/dashtech.lua`,
  Settings > Gameplay > Dash Tech).
- **Final Swarm.** After the wave-15 win, the victory screen offers a last stand: 60 seconds of
  every species met pouring in from every side, lots of elites and a crowned queen halfway
  (`src/game/finalswarm.lua`). Live through it and the run ends with "Swarm survived".
- Test: `love . --selftest --mastery` (also in the full run). `--locked` keeps the locks on for a
  selftest or `--balance` run (they normally open everything).

## Run info, summary and accessibility

- **Enemies left**: a counter under the KO count with everything still to beat this wave
  (alive + on the way) and a bar of how much of the wave is done (Interface > Enemies Left).
- **Next wave preview**: during a break, a card under the banner names the next wave: queen or
  final wave, the new species and the wave's modifiers. It reads `Spawner:preview()`, which takes
  modifiers from `Spawner:modifiersFor(n)` or `spawner.nextModifiers` (anything with `name`,
  optional `description` and `color`).
- **First sightings**: the first time a species shows up that the wave banner didn't introduce
  (queens, broods, escorts, hatchlings), a card on the left gives its name and its `tip` (else the
  first sentence of its `description`). Interface > First Sighting Popups: first time ever (kept
  in the save as `seen`), every run, or off.
- **Death recap**: the results screen names what killed you and lists your last 5 hits taken
  (quick bites from one kind of ant fold into one line). Hazards remember the enemy that made them.
- **Run summary** (results, victory and pause screens): damage by source, kills by species, a
  damage dealt / taken graph per wave, the achievements closest to unlocking, and the run's seed
  (`world.seed`; `Game.new{ seed = n }` replays it). Damage sources are worked out in
  `src/game/runstats.lua`: item procs count for the item, attacks, specials and dashes for their
  names, and projectiles, pools, thrown ants and poison for whatever made them. Content can name
  its own with `source = "..."` in `Combat.damage` opts.
- **Numbers and bars**: Gameplay > Combine Damage Numbers adds quick hits on one enemy into one
  counting number; Enemy Health Bars has Off / Elites & Queens / When Damaged / Always.
- **Colourblind-Safe Colours** (Accessibility): elites use their `safeColor` (Okabe-Ito, set in
  content/elites) and enemy ground hazards are coloured by what they do (harmful orange, slowing
  blue, healing yellow). **High-Contrast Warnings**: mounds, nest holes, drop shadows, landing
  rings and attack wind-ups get dark outlines and bright, thicker rings (`src/ui/palette.lua`).
- The Records screen shows a progress bar under every achievement still to do.

## Music, sounds and hints

All audio is synthesised in code, so there are no sound files to ship. `src/core/music.lua` is
one 8-bar loop in D minor split into six stems (pad, arp, bass, drums, lead, queen brass) that
always play in sync; the game only turns each stem up or down, so the music follows the fight:
calm between waves, bass and drums in a wave, the lead melody when a big crowd is on you, toms
and brass while a queen is out, and a slowed-down fade when you fall. Stems are rendered a slice
per frame at start-up and cached as .wav files in the save folder (`music/`); change the score,
then bump `CACHE` so they render again. Sound effects live in `src/core/audio.lua`.

The music also changes with the bug you play. Each body plan (spiders and other arachnids,
beetles, crustaceans, centipedes and millipedes, flyers, other insects) has its own band: while
you play, the shared arp, lead and drums are swapped for that band's versions of the same song
(spiders: half-time drums and a cold glassy lead with a creeping grace note; beetles: double
kicks, organ stabs and brass; crustaceans: a clave groove on wood blocks and marimba rolls;
myriapods: four on the floor under a 16th-note rattle; flyers: brushes and a breathy flute;
other insects: claps, bells and a buzzing reed), plus a signature stem. On top of that every
bug has its own riff, made from its id (so it never changes and no two bugs share one) on its
band's instrument; it is loudest between waves and on the character select, which previews the
bug's band, riff and key. A character file can pick its band with `music = "chug"` or
`music = { theme = "chug", key = -2 }`. Band and riff stems render the first time a bug is
picked and are cached like the rest.

`src/game/feedback.lua` plays the big-moment sounds (wave horn, wave cleared chime, a queen's
arrival, victory, defeat, a heartbeat under 30% health), draws arrows at the screen edge for
queens and elites out of view (setting **Off-screen Markers**), and runs the first-run hints in
`src/game/tutorial.lua` (move, attack, dash, special, swarmed, items, skill points, queens; each
shows once; setting **Tutorial Hints**, and turning it back on shows them all again).
`love . --selftest --polish` checks it all.

## Events, hazards, encounters and stages

`src/game/director.lua` runs everything in a wave besides the ants walking in. It never holds a
wave up: a wave still ends only when every enemy is dead, and events still going end with it.

- **Mid-wave events** (`content/events`, setting **Mid-Wave Events**: Often / Normal / Off): from
  wave 2, a wave gets 0-2 (more on Often), 6-24 s in. Honeydew rain (sweet puddles: ants stop to
  feed, you heal), an anteater's tongue licking down a red lane, a boot stomp (a shadow that
  follows you, then flattens everything under it), a flood (water from one side: wading, a current,
  small ants drown), colony war (a red rival colony fights yours), dew drops rolling across in
  lines, falling acorns (they stay as things to roll), a lawnmower lane, web cocoons (break one to
  free a bug that fights beside you for 20 s) and the merchant beetle (it takes nectar, a fifth under
  shop price; walk into it to buy, the item goes straight into the bag). A stage's
  `events = { id = weight }` and a mode's `eventWeights` / `events = false` change the odds.
- **Boss encounters** (`content/bosses`, setting **Boss Encounters**): every 5th wave except the
  final one, something big joins the queen. Bugs are fights: the antlion (a sand pit that drags
  everything to its jaws, throws sand) is a real enemy (`content/enemies/predators.lua`,
  `encounter = true`, drawn by `drawBody`), so the wave lasts until it falls; hazards don't hurt it.
  Animals far too big to fight are **stage hazards** (`hazard = true`): no enemy, nothing to hit,
  they don't hold the wave up. They only come from wave 10, arrive 8 s in, never share a wave with
  mid-wave events, and hunt for 24 s at most (or until the wave is cleared), then leave (bonus XP),
  and everything they do kills ants and hurts you alike. The HUD shows their name and what they are
  doing instead of a health bar, and they speed up the longer the wave lasts.
  - **Sparrow**: soars overhead as a shadow, swoops down a lane across the whole arena (sometimes
    straight back again), lands on a marked spot, hops after you pecking at marked circles, then
    takes off with a wing beat that blasts everything away.
  - **Giant Anteater**: lies at an arena edge with its head and forelegs reaching in. Tongue
    flicks down red lanes (you get dragged toward the snout), a tongue sweep across a whole fan,
    a claw rake (three gouges), and it shuffles along the edge after you or comes in at another
    side.
  Their pictures are painted in code (`src/gfx/beasts.lua`: feathers, streaks, coarse fur, the
  anteater's shoulder stripe) and drawn at full size. A mode can say `encounters = false`.
- **Stage mechanics** (`content/mechanics`): Puddled Patio (a puddle that rises through each wave),
  Overgrown Lawn (the long grass closes in during a wave), Dappled Garden (drifting sun patches
  speed everyone up, shade slows ants). Pick them in Cosmetics > Location like the other stages.
- **Weather effects** (setting **Weather Effects**): a spell's `effects` in `content/weather`.
  Wind and storms push everyone downwind (lighter bugs more), rain slows the fight (ants most),
  the new heatwave speeds it up. A banner says what changed when a spell settles in.
- **Props** (`content/props`, `src/game/props.lua`): pebbles and twigs lie about every stage
  (`props = { pebble = 6, twig = 3 }`). Walk into one to roll it, dash or attack to launch it; while
  it moves fast it flattens every ant it rolls over. Props are not enemies.
  Hits are physical: a struck pebble pops off the ground and bounces (harder moves bat it
  further), squashes, flashes and chips; a twig hit near one end spins; blasts scatter them; and
  a rolling pebble knocks a resting one on like a marble. **Grab attacks work on them too**
  (`Grab.collect` in `src/game/grab.lua`): the mantis snatches and flings them, the stag beetle
  clubs with a twig, the dragonfly bombs with an acorn, the emperor scorpion slams one, the
  vinegaroon acid-bombs one, the jumping spider reels one in, the rhino scoops one onto its horn
  and the whip scorpion cracks one back. A thrown prop crashes down and rolls on through the
  crowd. Test: `love . --selftest --props`.
- **Nest holes** can be sealed: hit one three times or dash over it, and the groups still waiting
  in it never come out.
- **Map gambles** (`src/game/gambles.lua`, numbers in `src/config/gambles.lua`, setting **Map
  Gambles**: Often / Normal / Off): from wave 2 a risky spot may pop up during a wave. A
  **dewdrop shrine** fills while you stand in its ring (and calls ants in while it does); when full,
  walk into one of three blessings, a permanent stat boost. A **challenge bell** rings when hit and
  calls a tough pack with elites: kill them all in time for XP, frenzy and a rarer best card in the
  next item choice. A **gamble flower** takes nectar for a spin: items, blessings, nectar back or
  x3, XP, a heal... or nothing, ants, or a curse (a small permanent minus). A few spins, then it
  wilts. Unused gambles leave when the next wave starts; blessings and curses are kept in run
  saves. Any prop with a `gamble = { weight, minWave, allowed }` field joins the pool. Console:
  `gamble <id>`.

Everything that changes movement goes through `world.env` (player / enemy speed, drift, the
player's inset from the walls, and a per-spot speed `field`). Raw hazard damage that skips player
stats and procs is in `src/game/envfx.lua`, with the shared warning-lane and shadow drawing.
Dev console: `event <id>`, `encounter <id>` (`encounter off` sends a hazard away), `prop <id> [n]`. `love . --selftest --happenings`
checks it all.

## Enemies and damage

Every enemy has a `family` (`src/config/families.lua`: ants, bees, wasps, hornets, termites, predators).
The catalogue and sandbox group enemies by family.

Bees, wasps and hornets (33 species, each with its own behaviour in `content/behaviors/bee_*`,
`wasp_*`, `hornet_*`; sprites from `tools/make_hymenoptera_sprites.py` -> `content/sprites/hymenoptera.lua`):
- Bees: honey (stings once, stinger keeps pumping venom, alarm speeds the cloud), Africanized
  (angrier with every bee that dies), bumble (pinball body-slams), carpenter (hovers in your face,
  solid), leafcutter (curving leaf discs), mason (mud that sets and sticks you), sweat (drink while
  you run, slow your dash recharge), cuckoo (near-invisible, glints then stings), stingless (resin
  slows your attacks, stacks), fire (darts; dies into acid), mining (tunnels under you, untouchable,
  bursts out), orchid (perfume clouds make ants faster), wool carder (patrols a lane), giant honey
  (curtain that shimmers a wave of stings), Japanese honey (heat ball that cooks you; dash breaks it).
- Wasps: yellowjacket (eats kills, grows), paper (builds a nest that releases wasps), cicada killer
  (carries an ant and drops it on you), jewel (stings ants into the Zombified elite), ichneumon (eggs
  in you hatch into grubs), cuckoo (curls into an armoured ball), sand (pits that drag you in),
  warrior (ring, drum, all dive at once), hover (dodges just before your hit), bald-faced (venom jet
  blinds you), mud dauber (builds a cage of mud pipes), tarantula hawk (paralyses and drags; mash to
  struggle), velvet ant (hits under 8 damage glance off).
- Hornets: Asian giant (marks you, calls a raid), European (spirals in on your light at night),
  Asian (intercepts your dashes), Oriental (soaks sunlight, blazing charge with a fire trail),
  lesser banded (cone of venom mist).
Engine hooks they added: `e.hidden` (burrowed: no damage, targeting, bites or drawing), `e.alpha`,
`e.heldBy`, `player:stun/blind/gum`, hazard zones with `damage`, `pull`, `update` and `draw`,
curving shots (`turn`) and `onHitPlayer`, behaviour `onHit(e, world, opts, dmg)`, and `AI.hover`,
`AI.sting`, `AI.group` (whole-swarm coordination), `AI.nearestOther`.
`love . --selftest --hymenoptera` checks the tricky mechanics.


Every ant touching you bites on its own timer (`biteRate`), and there is no invulnerability after
a hit (only dashing and dodge avoid damage), so the more ants on you, the more you take. The HUD
warns "SWARMED xN" and the screen edges turn red.

Species: worker, fire, soldier, crazy, leafcutter (solid wall ring), trap-jaw (snap and leap back),
bullet (fast charge), green (acid spray), army (relentless march), honeypot (healing, slowing
honey), exploding (self-destructs), Indian jumping (hops), turtle (shield head protects ants behind
it, escorted by workers) and wood (flanks behind you). Every 5th wave is a boss wave with a queen of
one of the species you've met, who keeps laying broods of her own kind until she dies.

Ten more real-world species: flying ants (circle overhead and dive), weaver ants (pairs sweep a
sticky silk strand across you; dash through it to snip it), bulldog ants (watch you and rush when
you turn your back; venomous), driver ants (latch on and slow you; dash to shake them off), Dracula
ants (shockwave snap that hurls you back; drink other ants' blood to heal), Matabele ants (carry
their wounded out of the fight and heal them), pharaoh ants (tiny swarms that scatter and regroup),
big-headed ants (majors ram you away and come running when their minors are attacked), desert ants
(zigzag, then sprint; faster in daylight) and pebble ants (lob pebbles onto a marked spot that daze
you). Each has a queen.

Fighting back: hitting an ant while it winds up or dashes (bullet, soldier, big-headed, bulldog,
desert, trap-jaw, Dracula) staggers it out of the attack, and charging ants are easier to hit. A hit
during the dash counts as a counter for +50% damage. Your attacks also swat acid globs and pebbles
back, faster and harder, to hit the ants instead.

Elites (Risk of Rain style): from wave 2, any ant can spawn as an elite: Aggressive (red, faster,
attacks sooner and further), Gilded (shiny gold, tough, +1 card in the next item choice), Armored (ignores
40% of each hit), Venomous (poisonous bites) or Volatile (bursts into acid on death). They are
tinted, bigger, glow and stand on a coloured aura. Affixes are files in `content/elites`, and a
species can give an affix its own twist with `elites = { aggressive = { params = {...} } }`
(the red green ant sprays a wider, faster, longer-range fan). Settings > Gameplay > Elite Ants.

Time of day: Settings > Video > Time of Day picks a day/night cycle (default, Day Length sets how
long) or a fixed Day, Sunset, Evening or Night. Colours live in `src/game/daylight.lua` and a stage
can override them with `ambients`.

Enemy behaviours live in `content/behaviors` (helpers in `src/game/ai.lua`); honey, acid and pebbles
are in `src/game/hazards.lua`. A behaviour can also define `onHit` (react to being hit), `draw`
(warnings, shown with Attack Warnings on) and `drawUnder` (things in the world, always drawn).

## Developer mode

On by default while we build (Settings > Developer). It adds:

- **Sandbox** on the main menu, a tabbed panel (keys 1-5, F2 hides it) for testing everything:
  - *Spawn*: any ant (normal, a chosen elite or a random one) in any amount, with a health
    multiplier (one-hit to x1000 training dummies); march a real column in from the edge; every
    elite of one species; every species at once; any queen; middle click spawns at the cursor.
  - *Items*: the **Item Catalogue** (C), quick give/take, one of every item, a bigger bag
    (10x7, 14x9), and an item choice (or a queen's rare prize) on demand.
  - *Player*: swap characters (items carry over), god mode, heal, take 10 damage (fires `onHurt`
    items, never kills), fresh start, and every stat on a slider.
  - *Waves*: start any wave (catches up on the species it would have introduced), next wave, stop,
    keep going, item choice after waves on/off.
  - *World*: time of day, time scale, hitboxes, spatial grid, perf overlay, plus a **DPS meter**
    and a **proc log** (bottom left: which items just fired, and on what).
- **Spawn Catalogue** (V in the sandbox, or the catalogue rows on the Spawn and Player tabs):
  every enemy, queen and playable bug as a wall of pictures (tabs Enemies / Queens / Characters,
  family filter F, search /). Pick one and set variant, amount and health with the chips beside it,
  then *Spawn here*, *March in*, *All elites*, *Play as*, or *Place*: the catalogue closes and every
  click or tap on the arena drops that bug there until *Done* (or right click). Works by touch.
- **Item Catalogue** (main menu, or C in the sandbox): every item as a wall of icons grouped by
  category or by rarity (G switches), with rarity tabs (Q / E), a kind filter (K: tags and proc triggers), name search (/) and full details.
  In the sandbox it gives items (click a picked item again, Enter, Shift for 5) and takes them back
  (right click / Delete). `love . --selftest --sandboxkit` checks both.
- **Console** with `` ` ``: `help`, `spawn fire_ant 200`, `give ember_gland 3`, `stat damage 50`,
  `wave 10`, `god`, `timescale 0.3`, `list items`, ...
- **Hotkeys** (F1 shows them): F3 perf overlay, F4 hitboxes, F5 grid, F6 god, F7 time scale,
  F8 spawn 100, F9 kill all, F10 sandbox.

## How content works

Everything you'd want to add more of is a file in `content/`. Each file returns a table, its id is the
file name, and it is picked up automatically: no engine code to touch, no lists to update.
Files starting with `_` are ignored, and every folder has a commented `_template.lua` to copy.

| Folder | What | Used by |
| --- | --- | --- |
| `content/enemies` | stats, sprite, AI behaviour, spawn rules | runs, sandbox, console |
| `content/behaviors` | enemy AI (`update`, optional `draw`, `drawUnder`, `onHit`) | enemies |
| `content/elites` | elite affixes: multipliers, tint, venom, armour, loot, death effects | runs, sandbox |
| `content/characters` | playable bugs: stats, attack, starting items | character select |
| `content/attacks` | attack patterns (`fire`) | characters |
| `content/skilltrees` | per-character skill trees: nodes mod stats, move params, echoes, procs | bag SKILLS tab |
| `content/skillbranches` | kin branches: the 4th skill tree branch shared by a lineage, matched by tags | bag SKILLS tab |
| `content/items` | stat changes and procs (`onHit`, `onKill`, `onHurt`, `onDash`, `onWaveStart`) | shop (step 2), sandbox |
| `content/stages` | arena size, yard palette, path/fence/dirt look, spawn pacing | runs |
| `content/sprites` | text-grid pixel art | everything |
| `content/frenzies` | super moves for a full frenzy meter (`start`, `update`, `draw`, `buff`) | frenzy meter |
| `content/streaks` | kill-streak buffs (stats for a few seconds) | 50-kill combos |
| `content/goals` | optional mini-goals for a wave (`start`, `update`, `on` events, `finish`, `reward`) | runs |
| `content/routes` | safe / hard route gates between waves (ant, elite, health multipliers, `reward`) | runs |
| `content/pickups` | ground pickups (`source` elite / kill, `weight`, `allowed`, `collect`) | nectar beads |
| `content/wavemods` | wave modifiers (Swarm, Ambush, Shield Wall...): multipliers, formation, ambush | wave banner, next-wave preview |
| `content/molts` | molting recipes: `from` (2-3 item ids that must touch), `into` (a molted item), `hint` | bag after a queen wave, Records > Recipes |
| `content/events` | mid-wave events and moving hazards (`start`, `update`, `field`, `drawGround`...) | src/game/director.lua |
| `content/bosses` | boss encounters every 5th wave: a bug from content/enemies to fight, or a stage hazard (`hazard = true`) | src/game/director.lua, src/gfx/beasts.lua |
| `content/mechanics` | stage rules a stage turns on with `mechanic = { type = ... }` | src/game/director.lua |
| `content/props` | pebbles, twigs, acorns, cocoons, freed allies, the merchant | src/game/props.lua |

Other single places to extend:

- `src/config/stats.lua` lists every player stat. Add one and items/characters can use it.
- `src/config/settings_schema.lua` lists every setting. Add one and it appears in the settings
  screen, saves and loads.
- `src/config/rarities.lua` holds the item rarity tiers.
- `src/debug/commands.lua` holds the console commands.

Look: a 960x540 pixel canvas by default (Settings > Video > Pixel Resolution), per-pixel generated
ground (concrete patio, lawn, grass blades), dusk lighting from a light map (player, effects, glowing
sparks, and enemies with a `light` field), and swarm ants that pack tightly (`personalSpace`) and
share a dark underlay (`swarmShade`) so a horde reads as one mass.

Formations: ants spawned together by a stream are linked into a follow-the-leader column (the
`column` behaviour). Each ant walks to where the one ahead was a moment ago, so columns snake in
from the lawn. Near the player the column breaks into a ring that orbits and tightens. Ants walk
with a stop-and-go gait and their legs animate at their real speed.

Waves teach the colony **one species at a time**: wave 1 is plain workers, and each wave after
that introduces exactly one new species (order: `spawn.minWave`, then the most common first).
The newcomer walks in first, alone, under a "NEW SPECIES" card with its description and tip; the
rest of the wave mixes it with species you've already met (only those). Every 5th wave a queen
comes instead. Ants pour in from several points around the arena at once (2 in wave 1, up to 6),
later waves send pincer pairs from opposite sides, and stray packs keep slipping in from other
edges while the wave runs. Clear it, choose an item, short breather, next wave. Tune per stage in
`stage.spawn` (`introEvery`, `entries`, `trickle`, ...; see `content/stages/_template.lua`).

Pacing (`src/game/pacing.lua`, tuning in the Spawner `DEFAULTS`, switches in Settings > Gameplay):
- **Species order** is shuffled each run (workers stay first): roughly by `minWave`, with a random
  spread, so bees, wasps and termites can turn up early. "Species Order: Always the Same" restores it.
- **Big early waves**: waves 1-3 send 2.2x / 1.8x / 1.4x the ants at 45% / 60% / 80% health.
- **Wave modifiers** (`content/wavemods`, from wave 3, never on queen or final waves): Swarm,
  Armored, Frenzied, Elite Pack, Ambush (half the wave bursts up in a ring around you), Shield Wall
  (groups step out in ranks at once), Pincer (every column splits to opposite sides), Undermined.
  They are rolled ahead from the run's seed (`Spawner:modifiersFor(n)`), shown on the wave banner.
- **Overlapping waves**: when a normal wave is down to its last 15% you pick your item and the next
  wave marches straight in while the stragglers are still about (not with Next Wave = When I Press).
- **Straggler call**: with 5 or fewer ants left, any far away burrow and pop up near you.
- **Par time and heat**: each wave has a par time from its size (shown counting down). Under par
  pays bonus XP; past it the ants speed up and hit harder (up to +35% / +25% after 40 s).
- **Live pressure**: while you stay healthy and untouched, packs come quicker and bigger and ants a
  little faster; taking damage eases it off.
- **Early call**: starting a wave before its countdown ends, or sending a wave's rest in with E,
  pays bonus XP at the clear, more for each wave in a row you call early.
- **Royal guard**: every queen arrives ringed by guards (her brood, armored); she takes 30% damage
  until they are dead ("BREAK THE ROYAL GUARD").
`love . --selftest --pacing` checks all of these.

Player 3D look: characters can have a `model` (isometric legs + body parts made by
`tools/make_bug_sprites.py`). Legs walk on the ground and the body is drawn as a stack of layers,
darker and narrower at the bottom, so it reads as a raised shell. The legs have an 8-frame walk
that follows your real speed; the body bobs with each step, lunges forward over planted legs when
attacking, recoils when hit, breathes when idle, and dashing leaves fading afterimages. Feet step
properly: each foot stays planted while the body moves over it, then lifts (tucked in, catching the
light), swings forward and plants again, kicking up a little dust and leaving faint prints.

Deaths: a hit sprays hemolymph along the blow, leaves a wet pool on the floor, flings body bits
that land and stay, and the body itself is knocked away, darkens and is left as faded remains.
Everything is painted onto a decal layer that fades away (Settings > Video > Splats Fade After,
10 s by default). When hundreds die at once only the first ~40 leave stains and remains (the
budget refills each second), so mass kills don't carpet the floor.

Sprites are simple top-down text grids (one character per pixel), facing right. The game bakes
32 rotations of each at load so bugs turn to face where they move while staying crisp.
`tools/make_bug_sprites.py` builds `content/sprites/bugs.lua` from shape recipes (ellipses for
body segments, lines for legs), and `python3 tools/preview_sprites.py out.png content/sprites/bugs.lua`
previews any sprite file (needs `luajit` and Pillow).

## Art style guide

Everything in the world shares one look: small pixels with rich per-pixel detail, shaded like
the bug sprites. Each material is a 4-5 colour ramp (dark .. light), the light comes from the
upper left, a little noise keeps big areas from looking flat, and every shape gets the soft,
slightly see-through dark outline. Colours sit in the dusky, natural range of the cast: real
animals' colours, but not candy-bright (`tools/tone_palette.py` pulled the loudest crustaceans
and the centipede back in line).

- **Bugs** are text-grid sprites from the `tools/make_*_sprites.py` generators, baked into the
  atlas in 32 turns.
- **Anything else in the world** (props, the antlion and its pit, map gambles) is painted in Lua
  at runtime with `src/gfx/paint.lua` (`Paint.pic`, `p:blob`, `p:stroke`, `p:outline`,
  `Paint.get` caches it) and drawn with `Paint.draw`; the prop pictures live in
  `src/gfx/propart.lua`. Don't draw world objects with flat `love.graphics.ellipse` /
  `polygon` fills: those read as a different game. Flat primitives are fine for effects (glows,
  rings, arcs, telegraphs) and shadows.
- `love . --selftest --arttour` saves `selftest_art_*.png` (catalogue walls, a line-up of each
  family, every prop, the antlion) so the whole cast can be checked side by side.

## Performance notes

- All sprites, shadows, particles and health bars come from one generated texture atlas, so
  LÖVE batches them: the draw call count stays around 40 whether there are 250 or 1500 enemies.
- Enemies are pooled tables; the spatial hash is rebuilt each frame with no garbage.
- The floor is pre-rendered once; bug splats paint onto a persistent decal canvas.
- `love . --selftest` prints update/draw timings at 250/500/1000/1500 enemies.
- The enemy array is kept depth-sorted in place (near-linear insertion sort instead of a full sort).
- Splats are a few tinted blob stamps from the atlas; particle spawns scale down as the pool fills;
  bodies in the air are capped; glowing-particle lights are capped; hit stop has a cooldown so
  constant mass kills don't feel like stutter.

## UI style guide

Every screen should look like part of the same game. The shared pieces live in `src/ui/theme.lua`;
use them instead of drawing your own. Check by eye with `love . --selftest --uitour`, which saves
`selftest_ui_<screen>.png` for every screen into the save folder.

- **Palette**: `Theme.colors` only. Warm dark chitin panels, cream `text`, `dim` for secondary
  lines, amber `focus` for whatever is selected or important, leaf-green `accent` for section
  labels, `good` / `bad` for numbers that went up or down. No new blues or purples for chrome
  (rarity colours and the XP bar are the exceptions).
- **Type**: use the named sizes, `Theme.font("title")`, `"heading"`, `"body"`, `"label"`,
  `"small"`. Nothing is drawn below `Theme.MIN_TEXT` (14): if text doesn't fit, cut words, don't
  shrink it. Bold is for names and card titles, not whole paragraphs.
- **HUD size**: everything is drawn at `Theme.TEXT_SCALE` (90%) of its named size, and the
  in-run HUD (`Game:draw`) sits inside `Theme.pushZoom(Theme.hudZoom())`, which scales text and
  `Theme.u` together (Settings "HUD Size", default 75%). New HUD pieces drawn from `Hud.draw`
  get it for free; keep them small and at the screen edges so the fight stays visible
  (`love . --selftest --hudsize`).
- **Screen titles**: `Theme.title("Bug catalogue")` (top-left) or `Theme.title("Settings", w)`
  (centred). Short, one or two words, no colons.
- **Panels**: `Theme.panel(x, y, w, h, rivets)`: the bevelled plate the bag uses. Square corners,
  no rounded boxes or glows. Rivets only on big panels.
- **Key hints**: `Theme.footer({ { "Esc", "Back" }, ... })` draws key caps along the bottom.
  One word per action, at most five hints, and swap the keys when `Input.lastDevice` is
  "gamepad" or "touch". Never write hint sentences like "Q / E: switch tab  ·  Esc: back".
- **Menus**: `src/ui/menu.lua`. Title-screen style lists pass `plain = true` (no row boxes).
- **Separators**: a middle dot with two spaces each side (`"Sweep  ·  9 dmg"`), never `|`.
- **Less is more**: no debug numbers, ids or console commands on player-facing screens unless
  `Settings.get("devMode")` is on. Pass-through info (wave banners, new-species cards) hides while
  a menu is open: `Hud.draw(game, covered)`.
- **Transitions**: the state stack fades every non-transparent screen in; overlays
  (`transparent = true`) dim the game behind them to about 70% black.

## Layout

```
main.lua, conf.lua      boot + LÖVE callbacks
src/core/               registry, settings, input, audio, screen, state stack, iso, spatial hash
src/config/             stats, settings schema, rarities
src/game/               world, player, enemy, combat, inventory, stats, spawner, camera
src/gfx/                sprite atlas, particles, ground
src/ui/                 theme, menu widget, HUD
src/states/             main menu, character select, settings, game, pause, game over
src/debug/              dev tools, console commands, sandbox panel, selftest
content/                all game content (see above)
docs/PLAN.md            roadmap
```
