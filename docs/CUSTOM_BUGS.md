# Making your own bugs

Swarmed has a **Bug Creator** (main menu > Bug Creator). It makes custom playable bugs in two ways:

* **Mix Parts** – pick a body from one bug, the attack of another, the special and dash of others,
  then set the size, colour, stats, an item rule and a skill tree. A live preview shows the bug
  fighting while you change it.
* **Write a Script** – a bug is a small Lua script. Start from the blueprint (every field
  explained), or press **Edit as Code** in the mixer to carry on from a mix.

Custom bugs join the bug select screen with the others (Show: **Custom Bugs**). They are just for
fun: they don't count towards the play-every-bug achievements and never come up as the daily bug.

> This is a first version. The plan is to grow it: custom models and colours per part, moves
> written in code, sharing codes. Ideas welcome.

## Sharing a bug

Every custom bug is one `.lua` file, so sharing one means sharing that text.

| To... | Do this |
|---|---|
| Give someone your bug | Bug Creator > your bug > **Copy Code**, then paste it in a message. |
| Add a bug someone gave you | Copy their script, then Bug Creator > **Paste a Script**. On a computer you can also drop the `.lua` file onto the game window. |
| Edit files by hand | Bug Creator > **Open the Bug Folder** (desktop). Each bug is `custom_bugs/<id>.lua` in the save folder; press **Reload Bug Files** after changing them. |
| Write a bug in your own editor | Bug Creator > **Copy the Blueprint**, or open [`content/characters/_custom_blueprint.lua`](../content/characters/_custom_blueprint.lua). |

On the web build the clipboard only works inside the game, so type the script into the editor or
import it on the desktop version. The script editor works with an on-screen keyboard on phones.

## The script editor

Typing, arrows, Home / End, Page Up / Down, Tab, Enter keeps the indent. **Ctrl+S** save,
**F5** (or Ctrl+Enter) check, **Ctrl+V** paste, **Ctrl+C** copy the whole script, **Ctrl+Z** undo,
**Esc** back. The script is checked as you type: problems show under the text and the line they
are on turns red. Saving runs a short test fight with the bug, so a move with broken numbers is
caught there instead of in the middle of a run.

## The blueprint

```lua
return {
    name = "Spike Beetle",                 -- the only field you must set (28 letters at most)
    description = "...",  lore = "...",  tip = "Slash with {attack} ...",

    look = "rhino_beetle",                 -- body, model and animations of a built-in bug
    scale = 1.1,                           -- 0.7 .. 1.6, the hitbox follows (or set radius = 4..16)
    colors = { hue = 140, saturation = 1.2 },   -- like a skin: hue, saturation, brightness, tint
    playstyle = "brawler",                 -- tank | brawler | speedster | ranged | control

    stats = { maxHp = 70, armor = 3, moveSpeed = 110, critChance = 10 },

    attack = { from = "mantis", damage = 12 },   -- left click
    secondary = { type = "venomsting", damage = 16, cooldown = 2, range = 80, width = 6 },   -- right click
    dash = "wolf_spider",                  -- Shift

    rules = "dung_beetle",                 -- borrow a bug's item rule
    skillTree = "rhino_beetle",            -- borrow a bug's skill tree
    immune = true,                         -- no debuffs, like the hissing roach
    startingItems = { "honeydew" },        -- up to four item ids
    tags = { "beetle" },                   -- item synergies
}
```

Every field except `name` is optional: anything left out comes from the `look` bug (its moves,
playstyle and size) or from the game's defaults (stats).

### Moves

`attack`, `secondary` and `dash` each take one of three forms:

| Form | Meaning |
|---|---|
| `"mantis"` | Copy that bug's move exactly. |
| `{ from = "mantis", damage = 20 }` | Copy it, then change some of its numbers. A changed value must be the same kind (number, table...) as the original. |
| `{ type = "arc", damage = 8, cooldown = 0.8, radius = 40, arc = 2.4 }` | Build it yourself from a move type (tables below). |

`secondary = false` gives no special. `dash = false` gives a plain dash.

Copying is the easy way in: start with `{ from = "..." }` and change one number at a time. The
examples in the tables below are the exact params the built-in bugs use, so they are a good place
to see what a move type understands.

### Stats

| Stat | Allowed | Default | | Stat | Allowed | Default |
|---|---|---|---|---|---|---|
| `maxHp` | 10 .. 250 | 50 | | `attackSpeed` | -50 .. 60 % | 0 |
| `hpRegen` | 0 .. 5 /s | 0 | | `area` | -50 .. 60 % | 0 |
| `armor` | -5 .. 15 | 0 | | `knockback` | -50 .. 120 % | 0 |
| `dodge` | 0 .. 40 % | 0 | | `critChance` | 0 .. 40 % | 5 |
| `moveSpeed` | 40 .. 240 | 100 | | `critDamage` | 100 .. 300 % | 150 |
| `damage` | -50 .. 60 % | 0 | | `luck` | -50 .. 60 % | 0 |
| `lifesteal` | 0 .. 10 % | 0 | | `pickupRange` | 10 .. 150 | 40 |
| `dashCooldown` | 0.3 .. 5 s | 1.2 | | | | |

Numbers outside the range are moved back inside it, and the Creator says so in a note.

### Safety limits

Scripts can't harm the game or your computer:

* They run in a **sandbox**: `math`, `string`, `table`, `pairs`, `ipairs`, `print`... work; files,
  `love`, `require`, `load`, `os`, `io`, `debug` and metatables don't exist.
* A script gets a budget of about two million steps and 64 MB to build its table, so a loop that
  never ends stops with an error instead of freezing the game. Compiled bytecode is refused.
* Only **data** comes out. Functions in the returned table are dropped, every field is checked,
  and numbers are kept in sane ranges (move damage at most 200, cooldowns at least 0.05 s,
  projectile and hit counts at most 24).
* Custom bugs can't replace a built-in bug: their ids always start with `custom_`.

### Helpers inside a script

| Helper | Gives |
|---|---|
| `bug("tarantula")` | A copy of a built-in bug's data (`name`, `stats`, `attack`, `secondary`, `dash`, `tags`...) with `look` set to it. Change it and return it. |
| `bugs`, `attacks`, `dashes`, `items`, `statIds` | Lists of every id. |
| `print(...)` | Shows a line under the editor (handy while experimenting). |

```lua
-- a glass cannon tarantula
local b = bug("tarantula")
b.name = "Glass Tarantula"
b.stats.maxHp = 30
b.stats.damage = 40
b.colors = { hue = 200, saturation = 0.3, brightness = 1.4 }
return b
```

```lua
-- a different attack every time the game starts
local moves = { "mantis", "scorpion", "crab" }
return { name = "Lucky Bug", look = "crab", attack = moves[math.random(#moves)] }
```

## Reference

### Built-in bugs (for `look`, `from`, `rules`, `skillTree`)

| Bug id | Name | Attack | Special | Dash |
|---|---|---|---|---|
| `assassin_bug` | Assassin Bug | `rostrum` | `shove` | `stealth` |
| `bombardier_beetle` | Bombardier Beetle | `spray` | `grenade` | `blast` |
| `camel_spider` | Camel Spider | `jawpierce` | `frenzy` | `burrow` |
| `centipede` | Centipede | `jabs` | `tailstab` | `flip` |
| `crab` | Crab | `clawsnip` | `snipsplit` | `scuttle` |
| `dragonfly` | Dragonfly | `dragonstrike` | `dragongrab` | `wingflight` |
| `dung_beetle` | Dung Beetle | `dungbash` | `dungthrow` | `dungride` |
| `emperor_scorpion` | Emperor Scorpion | `crushclaws` | `grabstab` | `clawwall` |
| `hermit_crab` | Hermit Crab | `hermitpinch` | `anemone` | `shell` |
| `hissing_roach` | Hissing Roach | `headbutt` | `hiss` | `scurry` |
| `jumping_spider` | Jumping Spider | `pounce` | `dragline` | `safetyline` |
| `lobster` | Lobster | `clawsnap` | `spin` | `block` |
| `mantis` | Mantis | `slashes` | `snatch` | `leafsway` |
| `mantis_shrimp` | Mantis Shrimp | `clubpunch` | `flurry` | `recoilpunch` |
| `millipede` | Millipede | `glandspray` | `coil` | `ballroll` |
| `orb_weaver` | Orb Weaver | `web` | `silkwall` | `grapple` |
| `pistol_shrimp` | Pistol Shrimp | `waterjet` | `snapshot` | `cloak` |
| `rhino_beetle` | Rhino Beetle | `arc` | `pierce` | `horncharge` |
| `scorpion` | Scorpion | `pinchsting` | `venomsting` | `tailflick` |
| `stag_beetle` | Stag Beetle | `arc` | `clubthrow` | `clumsyflight` |
| `stink_bug` | Stink Bug | `stinkcloud` | `acidpool` | `stinkshield` |
| `tarantula` | Tarantula | `fangslam` | `hairflick` | `leapslam` |
| `tiger_beetle` | Tiger Beetle | `chargedash` | `lunge` | `run` |
| `vinegaroon` | Vinegaroon | `acidsquirt` | `acidbomb` | `acidskip` |
| `whip_scorpion` | Whip Scorpion | `palpstrike` | `palpstrike` | `feelerpull` |
| `wolf_spider` | Wolf Spider | `nova` | `spiderlings` | `shadowdash` |

### Attack types (`attack`, `secondary`)

| Type | Name | Example (from a built-in bug) |
|---|---|---|
| `acidbomb` | Acid Bomb | `{ type = "acidbomb", damage = 14, cooldown = 3, reach = 42, soak = 1.5, distance = 125, pool = 42, poolLife = 4, corrode = { 1.4, 3 } }` |
| `acidpool` | Acid Pool | `{ type = "acidpool", damage = 10, cooldown = 3, range = 130, radius = 34, life = 6, max = 3 }` |
| `acidsquirt` | Acid Squirt | `{ type = "acidsquirt", damage = 4, cooldown = 0.32, range = 105, drops = 3, spread = 0.25, corrode = { 1.35, 3 }, burn = { 2, 2 }, cloudEvery = 5, cloudRadius = 26 }` |
| `anemone` | Sea Anemone | `{ type = "anemone", damage = 3.5, cooldown = 5, range = 110, radius = 24, life = 7, rate = 2.2, slow = { 0.35, 0.8 }, max = 2 }` |
| `arc` | Sweep | `{ type = "arc", damage = 9, cooldown = 0.75, radius = 46, arc = 2.6, knockback = 160, color = { 0.6, 0.95, 1 } }` |
| `chargedash` | Charge Dash | `{ type = "chargedash", damage = 14, cooldown = 0.55, charge = 0.75, distance = 50, maxDistance = 150, width = 9, maxMult = 3, knockback = 160, guard = 0.35, crawl = 0.45, color = { 0.6, 1, 0.7 } }` |
| `chargepunch` | Charge Punch | (not used by a built-in bug yet) |
| `clawsnap` | Claw Snap | `{ type = "clawsnap", damage = 10, cooldown = 0.35, charge = 1.1, radius = 16, maxRadius = 40, offset = 26, maxMult = 3.5, knockback = 220, color = { 1, 0.6, 0.45 } }` |
| `clawsnip` | Claw Snips | `{ type = "clawsnip", damage = 7, cooldown = 0.32, radius = 21, offset = 24, spread = 9, color = { 1, 0.6, 0.45 } }` |
| `clubpunch` | Club Punch | `{ type = "clubpunch", damage = 13, cooldown = 0.32, reach = 36, bubble = 0.5, radius = 28, knockback = 260, color = { 1, 0.45, 0.4 } }` |
| `clubthrow` | Swing & Hurl | `{ type = "clubthrow", damage = 26, cooldown = 2.6, reach = 36, swing = 0.45, arm = 22, distance = 130, radius = 34 }` |
| `coil` | Coil | `{ type = "coil", damage = 40, cooldown = 4, guard = 0.15, radius = 85, ooze = 3, time = 2, max = 3.5 }` |
| `crushclaws` | Crushing Claws | `{ type = "crushclaws", damage = 13, cooldown = 0.7, radius = 20, offset = 26, spread = 9, execute = 1.6, knockback = 120, poison = { 4, 3 }, color = { 0.6, 0.7, 1 } }` |
| `dragline` | Dragline Yank | `{ type = "dragline", damage = 16, cooldown = 1.8, range = 140, poison = { 8, 4 }, color = { 0.6, 1, 0.9 } }` |
| `dragongrab` | Seize | `{ type = "dragongrab", cooldown = 1, reach = 34, bomb = 26, radius = 34, groundMult = 0.6, squeeze = 0, color = { 0.5, 0.85, 1 } }` |
| `dragonstrike` | Sweep / Dive Lunge | `{ type = "dragonstrike", damage = 13, cooldown = 0.45, gust = 46, arc = 3.4, gustMult = 0.9, reach = 70, lungeSpeed = 1.7, knockback = 90, color = { 0.5, 0.85, 1 } }` |
| `dungbash` | Ball Bash | `{ type = "dungbash", damage = 11, cooldown = 0.55, perSize = 0.16, killGrow = 0.45, knockback = 140, sizeSlow = 1 }` |
| `dungthrow` | Ball Hurl | `{ type = "dungthrow", damage = 16, cooldown = 1.2, perSize = 0.24, speed = 340, burstSize = 9, minSize = 4, maxSize = 20, grow = 0.011, knockback = 180, slowMax = 0.45, sizeCooldown = 0.12 }` |
| `fangslam` | Fang Slam | `{ type = "fangslam", damage = 17, cooldown = 0.95, radius = 36, offset = 16, windup = 0.22, stun = 0.8, knockback = 180, color = { 1, 0.6, 0.3 } }` |
| `flurry` | Flurry | `{ type = "flurry", damage = 5, cooldown = 3, punches = 10, time = 0.7, reach = 28, finisher = 3, color = { 1, 0.5, 0.4 } }` |
| `frenzy` | Frenzy | `{ type = "frenzy", damage = 11, cooldown = 3, hops = 5, range = 70, radius = 18, bleed = { 4, 3 }, color = { 1, 0.85, 0.55 } }` |
| `glandspray` | Gland Spray | `{ type = "glandspray", damage = 6, cooldown = 0.5, radius = 14, every = 2, poison = { 5, 3 }, reach = 20 }` |
| `grabstab` | Grab & Stab | `{ type = "grabstab", damage = 8, cooldown = 3, reach = 46, stabs = 6, minStabs = 3, stabTime = 0.2, splash = 16, poison = { 8, 4 }, slam = 22, color = { 0.75, 1, 0.4 } }` |
| `grenade` | Chemical Grenade | `{ type = "grenade", damage = 30, cooldown = 2.2, range = 150, radius = 42 }` |
| `hairflick` | Hair Flick | `{ type = "hairflick", cooldown = 0, damage = 0.6, rate = 0.09, range = 130, spread = 0.22, speed = 300, slow = { 0.6, 1.2 }, color = { 1, 0.6, 0.3 } }` |
| `headbutt` | Headbutt | `{ type = "headbutt", damage = 9, cooldown = 0.38, reach = 28, arc = 1.7, knockback = 180, heavyEvery = 4, color = { 1, 0.75, 0.45 } }` |
| `hermitpinch` | Hermit Pinches | `{ type = "hermitpinch", damage = 7, cooldown = 0.38, radius = 20, bigRadius = 29, bigMult = 2.4, offset = 22, color = { 1, 0.6, 0.75 } }` |
| `hiss` | Hiss | `{ type = "hiss", damage = 3, cooldown = 4, radius = 50, maxRadius = 115, stun = 0.8, maxStun = 2.6, charge = 1 }` |
| `jabs` | Venom Jabs | `{ type = "jabs", damage = 3, cooldown = 0.13, reach = 30, width = 5, poison = { 2, 2 }, color = { 0.9, 1, 0.5 } }` |
| `jawpierce` | Jaw Pierce | `{ type = "jawpierce", damage = 7, cooldown = 0.36, reach = 40, width = 6, thrusts = 2, gap = 0.08, bleed = { 2, 3 }, knockback = 40, color = { 1, 0.88, 0.65 } }` |
| `jawsaw` | Jaw Saw | (not used by a built-in bug yet) |
| `liquefy` | Liquefy | (not used by a built-in bug yet) |
| `lunge` | Sprint Strike | `{ type = "lunge", damage = 11, cooldown = 1.1, distance = 60, width = 8, knockback = 110, color = { 0.6, 1, 0.7 } }` |
| `nova` | Nova | `{ type = "nova", damage = 6, cooldown = 0.6, radius = 38, knockback = 80, color = { 0.65, 1, 0.5 } }` |
| `palpstrike` | Palp Strike | `{ type = "palpstrike", hand = "left", feelers = true, damage = 10, cooldown = 0.5, reach = 76, arc = 1.9, color = { 1, 0.85, 0.6 } }` |
| `pierce` | Horn Pierce | `{ type = "pierce", damage = 26, cooldown = 2.5, range = 95, width = 7, knockback = 260, color = { 0.6, 0.95, 1 } }` |
| `pinchsting` | Pinch & Sting | `{ type = "pinchsting", damage = 8, cooldown = 0.4, radius = 34, stingRange = 85, stingMult = 2.5, knockback = 60, poison = { 3, 3 }, stingPoison = { 8, 4 }, color = { 1, 0.85, 0.5 } }` |
| `pounce` | Pounce | `{ type = "pounce", damage = 14, cooldown = 0.75, distance = 80, radius = 26, knockback = 130, color = { 0.6, 1, 0.9 } }` |
| `rampage` | Rampage | (not used by a built-in bug yet) |
| `rostrum` | Rostrum Stab | `{ type = "rostrum", damage = 7, cooldown = 0.3, reach = 34, width = 4, pierce = 1, leech = 0.2, color = { 1, 0.35, 0.3 } }` |
| `shove` | Shove | `{ type = "shove", damage = 4, cooldown = 1.4, radius = 40, arc = 1.7, knockback = 380, stun = 0.3 }` |
| `silkwall` | Silk Wall | `{ type = "silkwall", damage = 2, cooldown = 1.2, range = 120, length = 130, duration = 8, strength = 40, hold = 2.5, max = 3 }` |
| `slam` | Claw Slam | (not used by a built-in bug yet) |
| `slashes` | Twin Scythes | `{ type = "slashes", damage = 8, cooldown = 0.65, radius = 44, arc = 1.8, gap = 0.09, knockback = 80, color = { 0.75, 1, 0.5 } }` |
| `snapshot` | Snap Shot | `{ type = "snapshot", damage = 50, cooldown = 2, aim = 0.5, range = 300, width = 5, radius = 28, cloakMult = 2 }` |
| `snatch` | Snatch | `{ type = "snatch", damage = 16, cooldown = 3, reach = 52, grabs = 3, bite = 6, heal = 2, munch = 1.6, distance = 110 }` |
| `snipsplit` | Snip in Two | `{ type = "snipsplit", damage = 12, cooldown = 0.55, reach = 46, lift = 0.1, halves = 100, bossDamage = 16 }` |
| `spiderlings` | Spiderling Swarm | `{ type = "spiderlings", damage = 4, cooldown = 3, count = 8, bites = 3, speed = 170, life = 4, poison = { 4, 3 } }` |
| `spin` | Spin | `{ type = "spin", damage = 12, cooldown = 3, radius = 50, turns = 3, turnTime = 0.13, knockback = 220, color = { 1, 0.6, 0.45 } }` |
| `spray` | Boiling Spray | `{ type = "spray", damage = 4, cooldown = 0.55, range = 95, drops = 7, spread = 0.6, pierce = 2, color = { 1, 0.92, 0.6 } }` |
| `stinkcloud` | Stink Cloud | `{ type = "stinkcloud", damage = 5, cooldown = 0.7, range = 40, radius = 22, life = 2.6, drift = 14, max = 8, weaken = 1.25, choke = 0.7 }` |
| `tailstab` | Tail Stab | `{ type = "tailstab", damage = 18, cooldown = 1.6, range = 60, width = 7, knockback = 140, poison = { 8, 4 }, color = { 0.75, 1, 0.3 } }` |
| `venomchain` | Venom Chain | (not used by a built-in bug yet) |
| `venomsting` | Venom Strike | `{ type = "venomsting", damage = 14, cooldown = 2, range = 75, width = 6, poison = { 10, 4 }, color = { 0.8, 1, 0.4 } }` |
| `waterjet` | Water Jet | `{ type = "waterjet", damage = 4, cooldown = 0.2, range = 135, spread = 0.1, popEvery = 6, popRadius = 14, color = { 0.6, 0.85, 1 } }` |
| `web` | Web Shot | `{ type = "web", damage = 8, cooldown = 0.9, range = 100, radius = 30, slow = 0.3, duration = 4, color = { 1, 1, 0.95 } }` |

### Dash types (`dash`)

| Type | Name | Example (from a built-in bug) |
|---|---|---|
| `acidguard` | Acid Guard | (not used by a built-in bug yet) |
| `acidskip` | Acid Skip | `{ type = "acidskip", distance = 70, speed = 1.1, window = 0.7, damage = 5, radius = 26, corrode = { 1.4, 3 } }` |
| `ambush` | Ambush | (not used by a built-in bug yet) |
| `ballroll` | Ball Roll | `{ type = "ballroll", stamina = 2.5, regen = 1, speed = 1.8, damage = 5, knockback = 170, guard = 0.5 }` |
| `blast` | Blast-off | `{ type = "blast", damage = 18, radius = 38, distance = 110 }` |
| `block` | Block | `{ type = "block", slow = 0.35, shove = 90 }` |
| `burrow` | Burrow | `{ type = "burrow", stamina = 2, regen = 0.8, speed = 1.25, damage = 16, radius = 40 }` |
| `clawwall` | Claw Wall | `{ type = "clawwall", stamina = 3, regen = 1, speed = 0.6, guard = 1.1, ram = 3, push = 160, releaseRadius = 46, releaseShove = 320 }` |
| `cloak` | Cloak | `{ type = "cloak", time = 2.2, speed = 1.3, distance = 40 }` |
| `clumsyflight` | Clumsy Flight | `{ type = "clumsyflight", distance = 95, speed = 0.5, hop = 14, turn = 4, damage = 8, radius = 34, knockback = 240 }` |
| `dash` | Dash | (not used by a built-in bug yet) |
| `dungride` | Ball Ride | `{ type = "dungride", stamina = 2.2, regen = 0.9, speed = 1.5, damage = 6, knockback = 190, minBall = 1 }` |
| `feelerpull` | Antenna Whip | `{ type = "feelerpull", range = 140, speed = 1.6, charges = 2, damage = 8, crack = 14, radius = 26 }` |
| `flip` | Flip | `{ type = "flip", damage = 14, radius = 36, knockback = 260, distance = 30, slow = 0.85 }` |
| `grapple` | Web Grapple | `{ type = "grapple", range = 160, speed = 1.1 }` |
| `horncharge` | Horn Charge | `{ type = "horncharge", distance = 75, carry = 3, ram = 10, knockback = 220, toss = 70, tossDamage = 12 }` |
| `leafsway` | Leaf Sway | `{ type = "leafsway", charges = 2, distance = 58, speed = 1.2, primed = 1.0 }` |
| `leapslam` | Leap Slam | `{ type = "leapslam", distance = 80, speed = 0.85, hop = 16, damage = 14, radius = 36, stun = 0.6, knockback = 200 }` |
| `recoilpunch` | Recoil Punch | `{ type = "recoilpunch", damage = 24, reach = 36, distance = 90, charge = 0.8, maxMult = 3, launchMult = 1.2 }` |
| `run` | Run | `{ type = "run", stamina = 2.4, regen = 1, speed = 1.6, ram = 3, knockback = 130 }` |
| `safetyline` | Safety Line | `{ type = "safetyline", distance = 125, hop = 18, speed = 1.1, line = 2.5, zip = 1.7 }` |
| `scurry` | Scurry | `{ type = "scurry", distance = 60, speed = 1.3, charges = 3, startle = 0.4, burst = 1.35, burstTime = 0.6 }` |
| `scuttle` | Sideways Scuttle | `{ type = "scuttle", distance = 80, speed = 1.3, charges = 2, ram = 5, knockback = 140 }` |
| `shadowdash` | Shadow Dash | `{ type = "shadowdash", distance = 90, speed = 1.3, hide = 1.4 }` |
| `shell` | Shell Guard | `{ type = "shell", slow = 0.7, thorns = 4, shove = 70 }` |
| `sidestep` | Sidestep | (not used by a built-in bug yet) |
| `stealth` | Stealth | `{ type = "stealth", stamina = 4, regen = 0.8, speed = 1.15, bonus = 2.5, strikeCost = 0.3 }` |
| `stinkshield` | Stink Shield | `{ type = "stinkshield", time = 1.6, radius = 30, damage = 6 }` |
| `tailflick` | Tail Flick | `{ type = "tailflick", distance = 70, hop = 6, sting = 14, reach = 70, poison = { 6, 3 } }` |
| `tumble` | Tumble | (not used by a built-in bug yet) |
| `wingflight` | Take Wing | `{ type = "wingflight", stamina = 5, regen = 2.5, minStart = 0.15, speed = 1, groundSpeed = 0, height = 12, downdraft = 8, radius = 40 }` |


### Item rules (`rules`)

`dung_beetle` (Recycler), `hermit_crab` (Roomy Shell), `orb_weaver` (Web Tension),
`hissing_roach` (Scavenger) and `scorpion` (Venom Sac). Details in [`src/config/bugrules.lua`](../src/config/bugrules.lua). The bug select screen shows what
each one does.

### Items (`startingItems`)

`acorn_cap` (Acorn Cap), `alarm_pheromone` (Alarm Pheromone), `aloe_leaf` (Aloe Leaf), `amber` (Amber), `amoeba` (Amoeba), `bacterial_bloom` (Bacterial Bloom), `bombardier_gland` (Bombardier Gland), `bullet_ant_venom` (Bullet Ant Venom), `burdock_burr` (Burdock Burr), `cactus_spine` (Cactus Spine), `chili_pepper` (Chili Pepper), `chitin_plate` (Chitin Plate), `cicada_shell` (Cicada Shell), `click_beetle_hinge` (Click Beetle Hinge), `cockroach_heart` (Cockroach Heart), `coffee_bean` (Coffee Bean), `cordyceps` (Cordyceps), `dandelion_puff` (Dandelion Puff), `dew_drop` (Dew Drop), `dragonfly_wings` (Dragonfly Wings), `dung_ball` (Dung Ball), `earthworm` (Earthworm), `ember_gland` (Ember Gland), `feather` (Feather), `firefly_lantern` (Firefly Lantern), `fly_agaric` (Fly Agaric), `fools_gold_scarab` (Fool's Gold Scarab), `foragers_leaf` (Forager's Leaf), `four_leaf_clover` (Four-Leaf Clover), `fulgurite` (Fulgurite), `glass_mandible` (Glass Mandible), `glass_wings` (Glass Wings), `gnat_swarm` (Gnat Swarm), `grasshopper_legs` (Grasshopper Legs), `gut_flora` (Gut Flora), `honeycomb` (Honeycomb), `honeydew` (Honeydew), `honeypot_ant` (Honeypot Ant), `hornet_stinger` (Hornet Stinger), `hungry_tapeworm` (Hungry Tapeworm), `leech` (Leech), `lichen` (Lichen), `mantis_forelimb` (Mantis Forelimb), `maple_seed` (Maple Seed), `mosquito_proboscis` (Mosquito Proboscis), `moss_clump` (Moss Clump), `moth_wing` (Moth Wing), `mycelium` (Mycelium Thread), `nematode` (Nematode), `nettle_leaf` (Nettle Leaf), `parasitoid_egg` (Parasitoid Egg), `pine_cone` (Pine Cone), `pine_needle` (Pine Needle), `puffball` (Puffball), `quartz_crystal` (Quartz Crystal), `queens_pheromone` (Queen's Pheromone), `rhino_horn` (Rhino Horn), `rose_thorn` (Rose Thorn), `rotifer` (Rotifer), `royal_jelly` (Royal Jelly), `salt_crystal` (Salt Crystal), `scarab_shell` (Scarab Shell), `silk_bundle` (Silk Bundle), `slime_mold` (Slime Mold), `snail_shell` (Snail Shell), `spider_fang` (Spider Fang), `static_antenna` (Static Antenna), `strider_legs` (Water Strider Legs), `sugar_cube` (Sugar Cube), `tardigrade` (Tardigrade), `termite_mandible` (Termite Mandible), `trilobite` (Trilobite Fossil), `venus_flytrap` (Venus Flytrap), `walnut_shell` (Walnut Shell), `woodlouse_shell` (Woodlouse Shell)

## For developers

* Loader and sandbox: [`src/game/custombugs.lua`](../src/game/custombugs.lua) (`CustomBugs.run`,
  `.build`, `.save`, `.loadAll`, `.toSource`, `.trial`).
* Screens: [`src/states/creator.lua`](../src/states/creator.lua) (hub),
  [`src/states/bugmixer.lua`](../src/states/bugmixer.lua) (mix parts),
  [`src/states/codeeditor.lua`](../src/states/codeeditor.lua) (script editor).
* A custom bug is an ordinary character def with `custom = true`, registered in
  `Content.characters` (so bug select, records and runs need nothing special). Borrowed rules and
  trees go through `BugRules.of` and `Skills.treeFor`; colours through `Cosmetics.skinFor`.
* A custom bug script is almost a `content/characters` file. To turn one into a built-in bug,
  replace `look` / `from` with the real `sprite`, `model` and move params.
* Test: `love . --selftest --creator`.
