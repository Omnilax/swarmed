# Appendix: Bug Creator API reference (docs/BUG_API.md)

This is the complete, exact reference for custom bug scripts in Swarmed. It is written so that
another AI (or a person who likes reference manuals) can write a working bug in one go without
reading the engine. The friendlier guide is `docs/CUSTOM_BUGS.md`. When the two disagree, the
code wins, then this file. The code lives in:

| File | What it holds |
|---|---|
| `src/game/custombugs.lua` | Loads a script in the sandbox, checks every field (`CustomBugs.build`), saves and loads `custom_bugs/*.lua`, share codes. |
| `src/game/scriptmoves.lua` | The `me` toolkit (hits, shots, pools, grabs...), `SM.run` (every call into script code), events, helpers. |
| `src/game/bugapi.lua` | Round 4: the wide read / write API, resources (ammo), abilities, stances, traits, events like `onLevelUp`, `onHud` / `onDraw`. |
| `src/game/bugextras.lua` | Forms, molt, **evolution**, pets, statuses, ultimate, sound pack, challenges. |
| `src/game/hitshapes.lua` | Shapes behind `me.hit`. |
| `src/game/moveblocks.lua` | Moves made of blocks, and combos. |
| `src/game/bugtraits.lua` | No-code passives, glow / trails, movement styles, music. |
| `content/characters/_example_gunner_beetle.lua` | A worked example using every round 4 system. |
| `content/characters/_example_velvet_worm.lua`, `_example_stick_insect.lua`, `content/bugtemplates/*.lua` | More worked examples. |
| `src/debug/selftest_creator4.lua` | The test for everything in this file: `love . --selftest --creator4`. |

---

## 1. How a script becomes a bug

1. The script is Lua 5.1 text (LuaJIT in LÖVE 11; the web build is plain Lua 5.1, so **no
   `goto`, no `//`, no bit operators `& | ~`, no integer division, no `utf8` library**).
2. It runs once, in a sandbox, and must `return { ... }`: one table describing the bug.
3. `CustomBugs.build` checks every field. Wrong types become **errors** (the bug won't save) and
   out-of-range numbers or unknown names become **warnings** (fixed up and shown in the editor).
4. Saving runs a 150-frame trial fight. If a move or hook throws, the save is refused with the
   error, so most mistakes are caught before play.
5. In a run, the engine calls the functions in the table (moves, hooks, abilities...) through
   `SM.run`. Each call gets **`me`**, the toolkit, as its first argument.

A script never sees engine tables. Everything goes through `me` and every number passed to `me`
is clamped into a safe range. (Unless the player turns on Full Lua Access; see section 12.)

### The sandbox at load time

Available while the script runs: `math` (no `randomseed`), `string` (no `dump`; `rep` capped at
100 000 characters), `table`, `pairs`, `ipairs`, `next`, `select`, `type`, `unpack`, `tostring`,
`tonumber`, `error`, `assert`, `rawequal`, `rawget`, `print` (shows under the editor, 50 lines),
plus these helpers:

| Helper | Gives |
|---|---|
| `bug("tarantula")` | A copy of a built-in bug's data (`name`, `stats`, `attack`, `secondary`, `dash`, `tags`...) with `look` set to it. |
| `bugs`, `attacks`, `dashes`, `items`, `statIds` | Arrays of every id. |

Not available: `require`, `load`, `loadstring`, `dofile`, `io`, `os`, `debug`, `love`,
`setmetatable`, `getmetatable`, `coroutine`. Budget: about a million VM steps and 32 MB to build
the table; 256 KB of source.

### Functions inside the table

Functions survive into the bug (moves, hooks, abilities, stances, traits, evolution `onEvolve`,
skill procs). They keep their upvalues, so module-level `local` constants and helper functions
written above the `return` work as normal. **Upvalues are shared by every run of the bug**: keep
per-run state in `me.state`, not in upvalues.

Each call has a budget of 200 000 VM steps and 16 MB (10x with Full Lua Access). A function that
errors or runs out of budget is switched off for the rest of the session and the error shows in
the Bug Creator ("Move error last run: ...") and in the console as `[scriptmoves] <id>: ...`.

---

## 2. The top-level table

Every field is optional except `name`.

| Field | Type | Meaning |
|---|---|---|
| `name` | string ≤ 28 | Shown everywhere. The id is `custom_<slug(name)>` unless `id` is given. |
| `id` | string | Optional stable id (slugged, prefixed `custom_`). |
| `description`, `lore`, `tip` | string | Text for bug select. `tip` may use `{attack}`, `{secondary}`, `{dash}` key glyphs. |
| `look` | built-in bug id | Borrow that bug's sprite, model and animations. Default `rhino_beetle`. |
| `art` | table | The bug's own pixel art (section 9). Replaces `look`. |
| `scale` | 0.5 .. 2 | Size. The hitbox follows unless `radius` (3 .. 22) is given. |
| `playstyle` | id | `brawler`, `ranged`, `control`, `tank`, `summoner`... (affects preset tree, bug select filter). |
| `stats` | `{ statId = number }` | Base stats (section 8). |
| `attack`, `secondary`, `dash` | move | Section 3. `secondary = false` = no special. |
| `rules` | built-in bug id | Borrow that bug's item rule. |
| `skillTree` | id / `"preset:<id>"` / table | Section 10. |
| `startingItems` | array of item ids | 4 at most. |
| `tags` | array of strings | 8 at most. |
| `colors` | `{ hue, saturation, brightness, tint = "#rrggbb", keepWhite }` | Recolour. |
| `immune` | bool | Ignores slows and weather. |
| `hooks` | `{ onX = function }` | Event code (section 5). |
| `traits` | array | Named sets of hooks: code passives (section 6.4). |
| `resources` | table | Ammo, rage, heat... (section 6.1). |
| `abilities` | array | Extra buttons (section 6.2). |
| `stances` | array | Modes the bug switches between (section 6.3). `stanceSwitch = "key"` (default, the Stance key cycles) or `"code"`. `stanceStart` = index. |
| `evolution` | array | Stages it grows through (section 7). |
| `forms`, `formSwitch`, `formName` | | Whole alternate versions on Shift (section 7.3). |
| `molt` | table | One-time change at a wave / kill count (section 7.3). |
| `pets`, `statuses`, `ultimate`, `hitFx`, `soundPack`, `card`, `challenges` | | See `docs/CUSTOM_BUGS.md`. |
| `anims`, `poses`, `sounds` | | Own animations and synthesised sounds. |
| `passives`, `effects`, `movement`, `music` | | No-code traits (`src/game/bugtraits.lua`). `movement = { slide = 0..0.95 (no grip), glide = 0..1 (knocks and `me.knock` pushes coast on) }`. |
| `lowHp` | 0.01 .. 0.99 | Health share that fires `onLowHp` (default 0.3). |
| `spreeGap` | seconds | Gap without a kill that ends a spree (default 3). |
| `spreeEvery` | count | `onSpree` fires every this many spree kills (default 5). |

---

## 3. Moves

A move is a built-in id (`attack = "mantis"` borrows that bug's attack), `{ from = id, ...tweaks }`,
`{ type = "<attack type>", ...params }`, blocks / combos (see the guide), or **code**:

| A move with | Engine type | Works like |
|---|---|---|
| `fire = function(me)` | `scripted` | Attack / special: runs when pressed, or on its cooldown with auto-attack. |
| `hold = function(me, dt, charge)`, `release = function(me, charge)`, `charge = seconds` | `scripted_charge` | Hold to charge (attack / special). `charge` 0..1. |
| `start = function(me)`, `tick = function(me, dt)` | dash `scripted` | Pressed dash; spends a stamina charge (`charges`). Optional `free = function(me)`: return true and this press costs nothing (e.g. pressing again to cancel a move that is still going). |
| `hold = function(me, dt, held)` | dash `scripted_hold` | Runs every frame; `held` = dash key down. Blocks, sprints, aim modes. |
| `mode = true`, `enter(me)`, `tick(me, dt)`, `exit(me, dry)`, `speed`, `stamina` | dash `scripted_mode` | A stamina mode on the dash key. |

Common params: `name`, `cooldown` (0.03 .. 60), `range` (auto-attack reach), `damage` (0 .. 500),
`charges`. Any extra field is kept and readable in the move's code as `me.params.<field>`.

Inside a move, `me.aimX / me.aimY` is the direction it was used in. For the special that is the
cursor (mouse) or the aim stick. `me.cooldown(s)` overrides this use's cooldown.

---

## 4. The `me` toolkit

`me` is one table per player, built once. Plain fields are refreshed before **every** call;
functions are fixed. Angles are radians in **world** space (x right, y down on the ground plane,
before the isometric view). A unit vector `(cos a, sin a)` points along angle `a`.

### 4.1 Fields (read them, don't write them)

| Field | Type | Meaning |
|---|---|---|
| `x`, `y` | number | Position (world pixels). The arena is `0 .. world size` (about 1400). |
| `vx`, `vy`, `speedNow` | number | Velocity this frame and its length (px/s). |
| `aimX`, `aimY`, `angle` | number | Aim of this call (unit vector, radians). |
| `facing`, `facingX`, `facingY` | number | Where the body faces (smoothed; snaps on attacks). |
| `moveX`, `moveY` | number | Dash calls: the dash direction. Elsewhere = aim. |
| `moving` | bool | Walking input held. |
| `dashing` | bool | Mid dash. |
| `holdMode` | bool | A stamina mode is on. |
| `blocking` | bool | A block is up (`me.block` or a block dash). |
| `flying`, `z` | bool, number | Lifted (`me.fly`), height. |
| `radius`, `scale` | number | Hitbox radius, draw scale (changes with evolution). |
| `hp`, `maxHp`, `hpFrac` | number | Health. |
| `level`, `xp` | number | Skill level and XP this run. |
| `wave` | number | Current wave number (`me.waveInfo()` has more). |
| `time` | number | Seconds into the run (game time). |
| `kills` | number | Kills credited to this bug this run (its hooks saw them). |
| `spree` | number | Kills in the current spree (ends after `spreeGap` s without one). |
| `combo` | number | The world's combo counter (all kills, breaks after 2.5 s). |
| `nectar` | number | Nectar held. |
| `formIndex` | number | Current form (1 = base). |
| `stage` | number | Evolution stage (0 = not evolved). |
| `stanceIndex`, `stanceName` | number, string/nil | Current stance. |
| `dead` | bool | |
| `mode` | string | `"run"`, `"sandbox"`, `"menu"`... |
| `params` | table | This move's table (extra fields too). |
| `state` | table | **Yours.** Kept for the whole run, shared by every function of the bug. |
| `engine` | table/nil | Only with Full Lua Access (section 12). |

### 4.2 Reading the game (functions)

| Call | Returns |
|---|---|
| `me.stat(id)` | The current value of a stat (`"maxHp"`, `"damage"`...) with every item and buff, or nil for an unknown id. |
| `me.angleTo(x, y)`, `me.distTo(x, y)` | Angle / distance from the bug. |
| `me.isFacing(x, y, tol)` | true if (x, y) is within `tol` radians (default 0.5) of the facing. |
| `me.cursor()` | `x, y` of the mouse in the world (pad / touch: 100 px ahead along the aim). |
| `me.facingCursor(tol)` | `me.isFacing(me.cursor())`. |
| `me.moveVsFacing()` | 0 = walking forwards .. π = walking backwards (0 when still). |
| `me.moveInput()` | `x, y` of the walk input as a world direction (0, 0 when still). |
| `me.killsIn(seconds)` | Kills in the last N seconds (last 256 kills remembered). |
| `me.cooldowns()` | `{ attack, secondary, [1..n] = ability cooldowns }` seconds left. |
| `me.items()` | `{ itemId = count }` in the bag. `me.hasItem(id)` = count. |
| `me.rank(id)` | Ranks bought in a node of this bug's own skill tree (the node `id` as written in the script); 0 = none. Lets a node change what a move's code does. |
| `me.status()` | `{ poisoned, slowed, stunned, blinded, gummed, cloaked, dead, iframes }`. |
| `me.waveInfo()` | `{ number, phase = "wave"/"break", time, left, alive, final, boss, breakTime }`. |
| `me.run()` | `{ kills, combo, bestCombo, nectar, nectarEarned, xp, time, mode, frenzy (0..1), frenzyActive, stage, daylight }`. |
| `me.count(r)`, `me.nearest(r)` | Ants within r; `x, y` of the nearest (or nothing). |
| `me.enemies(r)` | Up to 40 `{ x, y, hp, maxHp, id, boss, queen, elite, flying, poisoned, slowed }`. |
| `me.enemiesNear{ radius, max, x, y, filter }` | Nearest first, up to `max` (60, at most 400): `{ x, y, vx, vy, hp, maxHp, id, name, boss, elite, queen, flying, held, hazard, dist, angle, poisoned, slowed, stunned, uid }`. `filter(e)` returns true to keep. A number works as the radius. |
| `me.props(r)`, `me.propsNear(r)` | Props near the bug. `propsNear`: `{ x, y, id, size, dist, angle, pushable, held, mass }`, nearest first. |
| `me.pickupsNear(r)` | Nectar beads and ground pickups `{ x, y, value, id }`. |
| `me.res(name)` / `me.ammo(name)` | `cur, max` of a resource (nil if the bug has none by that name). |
| `me.reloading(name)` | true while it reloads. |
| `me.stance()` | `name, index` of the current stance. |
| `me.formNow()`, `me.pets()`, `me.stamina()`, `me.holding()`, `me.held()` | Form, pet count, stamina 0..1, holding an ant / prop, and what is held `{ id, prop, hp, maxHp, x, y }`. |

### 4.3 Input

These answer false in the title-screen demo. In tests and move previews, `world.pilot` drives them.

| Call | Returns |
|---|---|
| `me.action(id)` | A game action is held: `attack`, `secondary`, `dash`, `ability`, `stance`, `frenzy`, `move_up`... (rebinding respected). |
| `me.actionPressed(id)` | Pressed this frame. |
| `me.keyDown(key)` | A raw key held: LÖVE key names (`"1"`, `"e"`, `"lctrl"`, `"space"`) or `"mouse1"`..`"mouse5"`. |
| `me.keyPressed(key)` | Went down since the last frame (call it every frame you care about). |

### 4.4 Hitting, shooting, the ground

Every damaging call goes through the bug's stats and items (damage %, area %, crits, lifesteal,
procs). Damage in a call is 0 .. 1000.

| Call | What it does |
|---|---|
| `me.hit{ shape, ... }` | The one hit call: shapes `circle`, `arc`/`cone`, `ring`, `box`, `line`, `poly`; `windup`, `active`, `rehit`, `follow`, `sweep`, `sweet`, `kb`, `stagger`, `hitstop`, `shake`, `onHit(me, ev)`... (full table in `docs/CUSTOM_BUGS.md`, "Hitboxes and feel"). Returns ants hit. |
| `me.hitArc`, `hitCircle`, `hitLine`, `hitBox`, `hitRing` | `me.hit` with a fixed shape. |
| `me.hitNearest{ radius, damage }`, `me.chain{ damage, jumps, range, radius }` | Single target; jumping lightning. |
| `me.shoot{ speed, range, damage, size, pierce, arc, burst, pool, turn, color }` | A projectile (30 per call). |
| `me.push{ radius, strength, x, y, ahead }`, `me.pull{...}` | Shove ants away / in. |
| `me.pool{ radius, life, dps, slow, pull, x, y, ahead, color }` | A ground puddle (12 live). |
| `me.wall{ length, ahead, life, strength, hold, damage }` | A sticky wall across the aim. |
| `me.summon{ count, life, damage, speed, bites, size, poison, color }` | Helpers that hunt (60 live). |
| `me.statusArea{ status, radius, x, y }` | One of the bug's own `statuses` on ants around a point. |
| `me.kickProps{ radius, strength, x, y, ahead }` | Knock props flying. |

Hit extras everywhere: `knockback` (0..900), `poison = { dps, s }`, `slow = { mul, s }`,
`corrode = { mul, s }`, `stun = s`, `status = "<own status>"`, `crit`, `noCrit`, `color`, `turn`.

### 4.5 Grab, block, dash, parry

| Call | What it does |
|---|---|
| `me.grab(radius)` | Lifts the nearest liftable ant **or prop** (not bosses, queens or hazards). true if it got one. Fires nothing by itself; call `me.emit("onGrab")` if you want an event. |
| `me.holding()`, `me.held()` | Holding something; what it is. |
| `me.throw{ distance, damage, landDamage, landRadius, height }` | Hurls it along the aim. |
| `me.drop()` | Lets go without throwing. |
| `me.block(on, shove)` | While on, every hit is blocked and the attacker shoved. `onBlock` fires per blocked hit. |
| `me.parry(seconds)` | The next hit within the window does nothing and fires `onParry(me, { damage, x, y })`. |
| `me.lunge(distance, turn)` | Dash along the aim (0..400). |
| `me.jump(height)` | During a dash: hop (≥ 6 can't be hit). |
| `me.shield(s)`, `me.cloak(s)`, `me.fly(on, h)`, `me.root(s)`, `me.speed(mul, s)` | Invulnerable, camouflage, lift off, stand still, speed multiplier. |
| `me.stamina()`, `me.useStamina(amount)` | Stamina 0..1; spend (1 = a full bar). |

### 4.6 Changing the bug

| Call | What it does |
|---|---|
| `me.heal(n)`, `me.setHp(n)`, `me.damage(n)` | Heal; set health (0.5 .. max); hurt the bug itself (goes through armor, dodge, block, parry, `onHurt`). |
| `me.buff(stat, add, mult, seconds, key)` | Stat change. `mult` 0.2 = +20%. `seconds` 0 / nil = until `me.unbuff(key)`. Same key replaces. |
| `me.unbuff(key)` | Removes a buff by key (default key = the stat id). |
| `me.teleport(x, y)` | Moves the bug (kept inside the arena). |
| `me.knock(dx, dy, force)` | Shoves the bug itself (recoil, jumps). Big bugs move less. |
| `me.face(x, y)` | Turn to face a point (also changes this call's aim). |
| `me.revive(frac)` | From `onDeath`: come back at `frac` of max health (default 0.25). |
| `me.form(n)`, `me.stance(n or name)`, `me.evolve(n)` | Switch form, switch stance, evolve (default: next stage). |
| `me.addPet(i)` | Hatch one more of `pets[i]`. |
| `me.giveItem(id, n)`, `me.addNectar(n)`, `me.addXP(n)`, `me.magnet()`, `me.frenzy(amount)` | Items, nectar, XP, pull every bead in, fill (or drain, negative) the frenzy meter (1 = full). |
| `me.cooldown(s)`, `me.resetCooldown("attack" / "secondary" / abilityIndex)` | This use's cooldown; clear one. |

### 4.7 Resources

| Call | What it does |
|---|---|
| `me.res(name)` | `cur, max`. |
| `me.spend(name, n)` | Takes `n` (default 1). false (nothing spent) if there isn't enough or it is reloading. Empty fires `onEmpty` and starts an auto reload when the resource has `reload`. |
| `me.gain(name, n)` | Adds (negative removes), kept between `min` and `max`. |
| `me.setRes(name, value, newMax)` | Sets it (and its max). |
| `me.reload(name, seconds)` | Starts a reload (default its `reload` time): refills to max when done, fires `onReload`. |

### 4.8 Timing, looks, sound, events

| Call | What it does |
|---|---|
| `me.after(s, function(me) end)` | Later (32 waiting). |
| `me.anim(name)` | One of the bug's own animations. |
| `me.sound(name, pitch, volume)` | Own sounds or `hit swing special zap boom dash chime drop kill pickup equip bell hurt`. |
| `me.ring{...}`, `me.particles{...}`, `me.shake(a)`, `me.say(text, color)`, `me.hitstop(s)` | Effects. |
| `me.showHitboxes(on)` | Draw every hitbox. |
| `me.emit("onName", data)` | Runs the bug's own `hooks.onName` (and traits' / stance's) with a copy of `data`; returns the first hook's return value. Any `on<Capital>` name works. |

---

## 5. Events (hooks)

`hooks = { onX = function(me, ev) ... end }`. Every hook also runs in every **trait** that has it
and in the **current stance** if it has it (in that order: hooks, traits, stance). `ev` is a
fresh plain table every time.

| Hook | When | `ev` fields |
|---|---|---|
| `onStart(me)` | First frame of the run. | none |
| `onTick(me, dt)` | Every frame. **Second argument is `dt`, not ev.** | |
| `onHit` | The bug's damage landed on an ant. | `x, y, damage, crit, boss, hp, maxHp, id, elite, killed, move` |
| `onKill` | An ant died to the bug. | same as onHit |
| `onHurt` | The bug lost health. | `damage, fromX, fromY` |
| `onDodge`, `onBlock` | A hit was dodged / blocked. | `damage` (block) |
| `onParry` | A hit landed inside `me.parry`'s window (and did nothing). | `damage, x, y` |
| `onAttack`, `onSpecial` | The attack / special was used. | `move` |
| `onDash`, `onDashEnd` | A dash started / ended. | |
| `onWaveStart`, `onWaveEnd` | A wave began / was cleared. | `wave` |
| `onLevelUp` | The bug gained a level (once per level). | `level` |
| `onEvolve` | It evolved. | `stage, name` |
| `onStanceChange` | The stance changed. | `from, to, index` |
| `onFormChange` | (reserved: call it with `me.emit`) | |
| `onSpree` | Every `spreeEvery` kills in a spree. | `count` |
| `onSpreeEnd` | A spree ended. | `count` |
| `onCombo` | The world combo passed a multiple of 10. | `combo` |
| `onLowHp` | Health dropped to `lowHp` share or below (once per dip). | `hp, maxHp` |
| `onDeath` | Health hit 0. **Return true** (25% health) **or call `me.revive(frac)`** to live. | `wave` |
| `onRevive` | It came back from `onDeath`. | `hp` |
| `onNectar` | Nectar went up. | `amount, total` |
| `onBossSpawn` | A queen / boss appeared. | `x, y, hp, maxHp, id` |
| `onAbility` | An ability fired. | `name, index` |
| `onReload`, `onEmpty` | A resource finished reloading / ran empty. | `name` |
| `onEat` | The bug ate an item. | |
| `onHud(me, ui)` | Every frame the HUD draws (section 11). | |
| `onDraw(me, gfx)` | Every frame the world draws (section 11). | |
| `on<Anything>` | Only when your code calls `me.emit`. | your data |

Depth: hits made by hooks set off more hooks at most 3 deep, and events made by the round 4
systems nest at most 4 deep, so nothing loops forever.

---

## 6. Round 4 systems

### 6.1 Resources (ammo, rage, heat, charge...)

```lua
resources = {
    ammo = { max = 6, reload = 1.1, color = "#e8b048", label = "Ammo" },
    rage = { max = 100, start = 0, regen = -4, show = "bar", color = "#e05030" },
},
```

| Field | Default | Meaning |
|---|---|---|
| `max` | 10 | Most it holds. |
| `start` | max | Value at the start of the run. |
| `min` | 0 | Least it holds. |
| `regen` | 0 | Per second (negative drains). |
| `regenDelay` | 0 | Seconds after a `spend` before it regens again. |
| `reload` | nil | Seconds a reload takes. With it, running empty reloads by itself (`autoReload = false` stops that). |
| `color`, `label` | | Look on the HUD. |
| `show` | `"pips"` (≤ 12 max) else `"bar"` | `false` hides it. |

8 resources at most. Read and change them with section 4.7. Abilities can `cost` them.

### 6.2 Abilities (extra buttons)

```lua
abilities = {
    { name = "Reload", key = "ability", cooldown = 0.3, fire = function(me) me.reload("ammo", 0.6) end },
    { name = "Parry", key = "g", cooldown = 2, cost = { stamina = 0.25 }, fire = function(me) me.parry(0.35) end },
    { name = "Laser", key = "mouse4", hold = function(me, dt, t) ... end, release = function(me, t) ... end },
},
```

| Field | Meaning |
|---|---|
| `key` | `"ability"` (F, rebindable in Controls), `"stance"` (R), a game action (`"attack"`...), a LÖVE key name, or `"mouse1"`..`"mouse5"`. The first ability defaults to `"ability"`. |
| `cooldown` | Seconds (0 .. 600), starts on press. |
| `cost` | `{ stamina = share, hp = n, nectar = n, <resource> = n }`. All must be affordable or nothing happens. |
| `fire(me)` | On press. |
| `hold(me, dt, t)` | Every frame while held after a successful press (`t` = seconds held). |
| `release(me, t)` | On letting go. |
| `name`, `color`, `desc` | HUD look. |

Inside these calls `me.params` is the ability's table. 6 abilities at most. They show on the HUD
with their key and a cooldown line.

### 6.3 Stances

```lua
stances = {
    { name = "Gun", color = "#e8b048", speed = 0.95 },
    { name = "Brawl", stats = { armor = 4, damage = 15 }, damageTaken = 0.8, say = "Fists up!",
      onEnter = function(me) end, onExit = function(me) end, onTick = function(me, dt) end,
      onKill = function(me, ev) end },        -- any hook, only while in this stance
    { name = "Turret", attack = { type = "scripted", fire = function(me) ... end }, speed = 0 },
},
stanceSwitch = "key",     -- the Stance key (R) cycles; "code" = only me.stance(...)
```

| Field | Meaning |
|---|---|
| `stats` | Stat bonus while in the stance (as modifiers, items stack on top). |
| `speed` | Walk speed multiplier (0 .. 5). |
| `damageTaken` | Multiplier on hits taken (0 .. 10). |
| `attack`, `secondary`, `dash`, `art`, `look`, `anims`, `colors` | Optional: its own moves / body. Leaving the stance goes back to the bug's current version (evolution stage, molt). |
| `onEnter`, `onExit`, `onTick`, `on<Event>` | Code for this stance only. |
| `name`, `say`, `color` | Text and colour when switching. |

The bug starts in `stanceStart` (default 1) without a banner. Code checks `me.stanceName` to
branch a shared move ("one attack, two behaviours") instead of swapping moves.

### 6.4 Traits (code passives)

```lua
traits = {
    { name = "Bloodlust", desc = "Every 5 kills in a spree: +12 rage.", onSpree = function(me, ev) me.gain("rage", 12) end },
    { name = "Last Stand", onDeath = function(me) if not me.state.saved then me.state.saved = true me.revive(0.4) end end },
},
```

Each trait is any set of `on<Event>` functions that runs next to `hooks`. Up to 12. Use them to
keep passives separate and named (the Creator lists them).

---

## 7. Evolution, forms and the molt

### 7.1 Evolution

```lua
evolution = {
    { level = 3, name = "Horned", say = "Horns!", stats = { damage = 10 },
      addLimbs = { { u = 6, v = 0, side = 1, segs = { { 4, 0, -0.5 }, { 3, 0, -0.6 } }, width = 2, color = "c" } } },
    { level = 6, name = "Clawed", stats = { maxHp = 30 }, scale = 1.15,
      addLimbs = { { u = 4, v = 3, segs = { { 4, 0.7, 0 }, { 3, -0.5, 0 } }, tip = "pincer" } } },
    { kills = 500, name = "Cannon", secondary = { type = "scripted", fire = function(me) ... end },
      onEvolve = function(me, ev) me.say("BOOM") end },
    { name = "Secret", art = { ... } },        -- no level / kills / wave: only me.evolve()
},
```

* A stage happens at `level` (skill level), `kills` (this bug's kills) or `wave`, whichever it
  names. With none it only happens through `me.evolve(n)`. Stages go in order and only forwards.
* Stages **add up**: `stats` sum over every stage reached; `addLimbs` adds limbs to the art
  (the bug needs its own `art`); any other field (`attack`, `secondary`, `dash`, `art`, `look`,
  `scale`, `colors`, `hooks`, `anims`, `passives`...) replaces the value from earlier stages.
  A stage with its own `art` starts from that art's limbs.
* Evolving: a banner with the stage name, a burst, `say` text, `onEvolve(me, { stage, name })` on
  the stage, then the `onEvolve` hook. Health is not refilled (call `me.heal`).
* 12 stages at most. Read the current one in `me.stage`.

### 7.2 Limbs (for `addLimbs` and `art.limbs`)

`{ u, v, z, side, segs = { { length, yaw, pitch }, ... }, width, color, tip, flap, sway }`.
`u` forward, `v` sideways, `z` height of the attach point (pixels); no `side` = a mirrored pair,
`side = 1 / -1` = one side. `segs` are joints (radians, each relative to the one before).
`tip`: `pincer`, `crusher`, `blade`, `sting`, `fang`, `club`. `width` 1..4. `color` a palette
letter or `#rrggbb`. `flap` / `sway` make them move by themselves. 12 limbs at most.

### 7.3 Forms and the molt

`forms = { { name, attack, secondary, stats, colors, look, art, say } }`: whole other versions
switched on Shift (`formSwitch = "hold"` / `"tap"`) or by code (`"code"` + `me.form(n)`).
`molt = { wave or kills, name, ...version fields }`: becomes that version once, for good.
With evolution, form 1 is the current evolution stage.

---

## 8. Stats

Base stats are clamped to: `maxHp` 5..500, `hpRegen` 0..10, `armor` -10..30, `dodge` 0..60,
`moveSpeed` 30..300, `damage` -80..150 (%), `attackSpeed` -60..150 (%), `area` -60..150 (%),
`knockback` -80..200 (%), `critChance` 0..80, `critDamage` 100..400, `luck` -80..150,
`lifesteal` 0..25, `pickupRange` 5..250, `dashCooldown` 0.2..8. Buffs from code (`me.buff`)
and stage / stance bonuses add on top, as items do.

---

## 9. Art

See `docs/CUSTOM_BUGS.md` "Your own art": `art = { palette = { letter = "#rrggbb[aa]" }, body =
{ rows } or frames, legs = { { hipU, hipV, kneeU, kneeV, footU, footV } }, legColor, height, lift,
kneeUp, stride, limbs, chain, wings, antennae }`. Drawn top-down facing right.

---

## 10. Skill trees

`skillTree = "preset:<id>"`, a built-in bug id, or an own tree (`branches` with `nodes`; node
`procs` may hold code `effect(me, ev, rank)` / `condition(me, ev, rank)`). See the guide.
An own tree may also have `signature = { id, name, desc, ... }`: one node of the same shape that
tops the kin branch (the 4th branch, shared by the bug's lineage), like the built-in bugs have.
Nodes that change a move's code are read with `me.rank("<node id>")`
(content/scripted/water_strider.lua does this for most of its tree).

---

## 11. Drawing: `onHud` and `onDraw`

```lua
hooks = {
    onHud = function(me, ui)
        -- screen pixels. ui.w, ui.h = window size, ui.top = first free row under the bug's HUD,
        -- ui.u(n) = n scaled to the HUD size setting
        ui.text("SPREE x" .. me.spree, ui.u(20), ui.top, "#ffd060", 18)
        ui.bar(ui.u(20), ui.top + ui.u(22), ui.u(120), ui.u(6), me.hpFrac, "#60ff60")
        ui.rect(x, y, w, h, color, alpha, line)   ui.circle(x, y, r, color, alpha, line)
    end,
    onDraw = function(me, gfx)
        -- world positions, drawn over the floor
        local x, y = me.cursor()
        gfx.line(me.x, me.y, x, y, "#ffffff", 0.3, 1)    -- color, alpha, width
        gfx.circle(me.x, me.y, 30, "#ff0000", 0.2, true)  -- radius, color, alpha, outline only
        gfx.text("here", x, y, "#ffffff")
    end,
},
```

400 HUD and 300 world shapes per frame. Colours are `"#rrggbb"` or `{ r, g, b }` (0..1).
The bug's resources, abilities and stance are drawn automatically under the stamina bar.

---

## 12. Full Lua Access (no limits)

Settings > Developer > **Full Lua Access (custom bugs)**, off by default. When on:

* `me.engine = { player, world, require, love, _G }`: the real engine tables. Anything the game
  can do, a script can do: read `me.engine.player.inventory`, spawn enemies with
  `me.engine.world:spawnEnemy(...)`, require any module.
* Each call gets 10x the step budget and 128 MB.
* There is no safety net: a script can crash the game, break a run, or read and write the save
  folder. Only for scripts you wrote or trust. Bugs that use `me.engine` should check
  `if me.engine then ... end` so they still work for players who leave it off.

Useful engine entry points (all in `src/`): `game/world.lua` (`spawnEnemy`, `killEnemy`,
`queryEnemies`, `addFx`, `floatText`, `giveItem`, `grantXP`, `addNectar`), `game/player.lua`
(`hurt`, `heal`, `knock`, `lunge`, `stats`), `game/combat.lua` (`damage`, `area`, `collect`),
`game/stamina.lua`, `game/grab.lua`, `game/props.lua`, `core/audio.lua`.

---

## 13. Order of things every frame

`Player:update` (for a custom bug):
1. stamina, dash input (`start` / `hold` / mode), movement, aim;
2. special, then attack (`fire` / `hold` / `release`);
3. delayed calls (`me.after`);
4. `SM.tick`: no-code traits, live hitboxes, pets / statuses / molt / **evolution check**, speed
   timers, `onStart` (once), `hooks.onTick`, then `BugAPI.tick`: starting stance, resources
   regen / reload, **abilities**, the stance key, stance `onTick`, traits `onTick`, spree end,
   `onCombo`, `onLowHp`, `onLevelUp`, `onWaveEnd`, `onNectar`, `onBossSpawn`, parry timer; then the
   held ant and helpers.

Events from the game (`onHit`, `onKill`, `onHurt`...) run when they happen, inside the move or hit
that caused them. `Player:hurt` asks the parry window first, then multiplies by the stance's
`damageTaken`, then blocks / dodge / armor; `onDeath` runs before the bug dies.

---

## 14. Recipes

```lua
-- Charge while walking backwards
attack = { type = "scripted", fire = function(me)
    local back = me.moveVsFacing() > 2.3
    me.hit({ shape = "arc", radius = 50, degrees = 120, damage = back and 18 or 9 })
end },

-- Aim at the cursor only when the mouse is in front
onTick = function(me, dt)
    if me.facingCursor(0.4) then me.buff("critChance", 20, 0, 0.1, "eyes") end
end,

-- A kill-streak transformation
onSpree = function(me, ev) if ev.count >= 25 and me.stage == 0 then me.evolve(1) end end,

-- A heat gauge: shooting heats, overheating locks the gun
resources = { heat = { max = 100, start = 0, regen = -30, show = "bar", color = "#ff6020" } },
attack = { type = "scripted", cooldown = 0.08, fire = function(me)
    local heat = me.res("heat")
    if me.state.locked then if heat < 20 then me.state.locked = false end return end
    me.gain("heat", 9)
    if heat > 95 then me.state.locked = true me.say("OVERHEAT") return end
    me.shoot({ speed = 500, range = 200, damage = 4 })
end },

-- Pick up a pebble with an ability and throw it with the next press
abilities = { { name = "Grab / Throw", key = "ability", cooldown = 0.2, fire = function(me)
    if me.holding() then me.throw({ distance = 160, landDamage = 25 }) else me.grab(40) end
end } },

-- Make your own event
hooks = {
    onKill = function(me, ev) if ev.boss then me.emit("onBigKill", ev) end end,
    onBigKill = function(me, ev) me.heal(40) me.say("Feast!") end,
},
```

---

## 15. Limits that stay

* Everything a script passes to `me` is clamped (radii, counts, damage ≤ 1000, speeds) so the game
  can't be broken by a typo. Full Lua Access lifts the sandbox, not these clamps on `me` calls.
* 32 delayed calls, 12 pools, 60 helpers, 30 shots per call, 3 extra forms, 12 evolution stages,
  6 stances, 6 abilities, 8 resources, 12 traits, 16 anims, 16 sounds.
* Custom bugs don't count for "play every bug" achievements or the daily run.

## 16. Testing a bug

* Bug Creator > your bug > **Test Arena**: dummies, spawn buttons, a DPS meter, hitboxes.
* Errors show in the Creator panel and the console (`[scriptmoves] custom_<id>: <move>: line N: ...`).
* `print(...)` at load time shows under the editor.
* Engine tests: `love . --selftest --creator4` (this API), `--creator`, `--creator2`.
