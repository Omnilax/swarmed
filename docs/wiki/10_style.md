# The look

## Art direction

Set by Ozy on the first day and refined twice: **cute, crunchy and a little serious.**

- **Noita-like pixels.** Small pixels with rich per-pixel detail on a 960×540 canvas by default. Every surface has texture: concrete with cracks and joints, lawn with individual blades, leaves with veins.
- **Real animals, shaded.** Bugs are fairly realistic top-down sprites (real species, real colours), shaded like little models, not flat cartoon shapes. Cute comes from their size, their walk and their squash and stretch, not from big eyes.
- **Dusk, with glowing lights.** The default world is a warm, dusky garden with lights that glow: fire ants, acid, sparks, the player's own light at night. Ozy did not want it always dark, so there is a full day/night cycle by default, and a rich day palette.
- **The horde is one mass.** Hundreds of ants should read as one flowing swarm, like a real ant raid: columns that snake in, a shared dark underlay, tight packing, stop-and-go gait.
- **Being overwhelmed, then cutting through.** Splats, bits and bodies fly on a big kill, then fade (10 s by default), so the floor tells the story of the fight without carpeting it.

{{IMG:art_fam_ant.png|The ant family lined up in the arena: one style, one light direction, one outline}}

## One art style for everything

The rule from the art unification pass: **everything in the world shares one look.**

- Each material is a **4-5 colour ramp** from dark to light.
- **Light comes from the upper left.**
- A little **noise** keeps big areas from looking flat.
- Every shape gets the **soft, slightly see-through dark outline** (`#rrggbbb0`).
- Colours sit in the **dusky, natural range** of the cast: real animals' colours, never candy-bright. `tools/tone_palette.py` pulled the loudest crustaceans and the centipede back in line.

How each kind of thing gets made:

| Thing | Made as | Where |
| --- | --- | --- |
| Bugs, ants, bees, termites | text-grid sprites from Python generators, baked into the atlas in 32 turns | `tools/make_*_sprites.py` → `content/sprites/*.lua` |
| Playable bugs in 3D | the same sprite stacked into a raised shell over jointed legs from a rig | `src/gfx/sprites.lua` `drawModel` |
| Props, map gambles, brood cells, the merchant | painted at runtime in Lua with `Paint.pic` (`p:blob`, `p:stroke`, `p:outline`), cached | `src/gfx/paint.lua`, `src/gfx/propart.lua` |
| The antlion and its sand pit | painted the same way | `src/gfx/antlion.lua` |
| Sparrow and giant anteater (stage hazards) | big painted pictures (feathers, fur strokes, lit shapes), drawn flat on the floor (flying, shadows) or upright (perched, standing) | `src/gfx/beasts.lua` |
| Item icons | modelled from lit 3D shapes with materials, reduced to a small palette | `tools/make_item_icons.py` |
| The floor | per-pixel generated once per stage from its palette | `src/gfx/ground.lua` |
| Effects (glows, rings, arcs, telegraphs) and shadows | flat LÖVE primitives (the only place they are allowed) | everywhere |

**Never draw world objects with flat `love.graphics.ellipse` / `polygon` fills**: they read as a different game. `love . --selftest --arttour` saves the whole cast side by side for an art check.

{{IMG:art_props.png|Props painted at runtime in the sprites' style}}

### Sprite format

Sprites are text: one character per pixel, `.` is transparent, facing right (the game rotates them). A palette maps letters to colours.

```lua
return {
    id = "my_bug", fps = 8,
    palette = { o = "#1a0f17b0", a = "#5c2a26", b = "#8a3f31" },
    frames = { { ".oo.", "oabo", "oaao", ".oo." }, { ".oo.", "obao", "oaao", ".oo." } },
}
```

The generators use shared letters: ramps `1..4` / `h` and `A..D` / `H` (dark to light, gloss), `o` soft outline, `l` legs, `e` eyes, `v` / `W` wings, `x..z` / `Z` shells. Any head goes with any middle and back in the Bug Painter's part kit because they share letters.

## Animation and feel

- **Walking**: an 8-frame leg cycle that follows the real speed; feet plant, lift (catching the light), swing and plant again with a little dust and faint prints. Ants' legs animate at their real speed with a stop-and-go gait.
- **Body language**: the body bobs with each step, lunges over planted legs on attack, recoils when hit, breathes when idle; dashes leave fading afterimages.
- **Attack clips** add jointed limbs per bug: the scorpion's tail arcs over to sting, lobster claws rise and slam, mantis scythes, stag jaws scissor, spider fangs strike.
- **Squash and stretch** on hits (enemies flash white for 0.09 s and squash), **knockback** by mass, **bodies knocked away** spinning and darkening.
- **Big moments, rarely**: hitstop for 15+ kills in a frame (then a 4 s cooldown), slow motion for 30+ (10 s cooldown), the frenzy move, a queen falling. Freezes were made rare on purpose after they felt like stutter.
- **Telegraphs** for everything that can hurt: wind-up poses, warning lanes, growing shadows, heaving soil, rings. Hazards and their warnings use the same shared drawing (`src/game/envfx.lua`).

## Lighting looks

The lighting update made every visual extra its own setting, with one-press **Looks** (`src/config/look_presets.lua`): **Standard** (bold lights with glare kept in check, shadows and rim light, a full day cycle), **Clarity** (everything that helps you read the fight), **Cinematic** (colour grade, sun rays, camera moves, heat haze), **Classic** (the look before the lighting update). Pieces: Bold light style with highlight roll-off, Glare Guard, warning / hazard / threat lights, night lantern, kill light pops, sun and contact shadows, rim light, cloud shadows, sun rays, wet ground, background dim, actors pop, see-through silhouettes, threat outlines, horde depth, danger compass, wind gusts, horde tracks, death styles, colour grade, heat haze, falling leaves, glowing night mushrooms, smart auto-zoom, horde framing, boss intro glance, wave clear zoom, directional shake, camera punch, foreground grass.

{{IMG:looks.png|The four looks side by side}}

# The interface

Every screen should look like part of the same game. The shared pieces live in `src/ui/theme.lua`; use them instead of drawing your own. `love . --selftest --uitour` saves every screen for a check by eye.

## Palette

Warm, dark chitin panels with cream text, amber for focus, leaf green for section labels. No new blues or purples for chrome (rarity colours and the XP bar are the exceptions).

<table>
<tr><th>Name</th><th>Colour</th><th>Use</th></tr>
<tr><td>bg</td><td><span class="sw" style="background:#110e0d"></span> #110e0d</td><td>screen background</td></tr>
<tr><td>panel</td><td><span class="sw" style="background:#1f1814"></span> #1f1814</td><td>bevelled chitin plates (like the bag)</td></tr>
<tr><td>panelHi / panelEdge</td><td><span class="sw" style="background:#4d3b2b"></span> <span class="sw" style="background:#0a0807"></span></td><td>bevel light (top, left) and dark (bottom, right)</td></tr>
<tr><td>text</td><td><span class="sw" style="background:#f2e8d4"></span> #f2e8d4</td><td>cream body text</td></tr>
<tr><td>dim</td><td><span class="sw" style="background:#998a7a"></span> #998a7a</td><td>secondary lines</td></tr>
<tr><td>focus</td><td><span class="sw" style="background:#fabd45"></span> #fabd45</td><td>whatever is selected or important</td></tr>
<tr><td>accent</td><td><span class="sw" style="background:#99cc80"></span> #99cc80</td><td>section labels</td></tr>
<tr><td>good / bad</td><td><span class="sw" style="background:#8ce073"></span> <span class="sw" style="background:#ff6b5c"></span></td><td>numbers that went up / down</td></tr>
<tr><td>hp</td><td><span class="sw" style="background:#e04745"></span> #e04745</td><td>health</td></tr>
</table>

## Type

Pixelify Sans (SIL Open Font License) by default, with a smooth font in Settings. Named sizes only: **logo** 84, **title** 48, **banner** 56, **heading** 26, **body** 18, **label** 16, **small** 14. **Nothing is ever drawn below 14** (`Theme.MIN_TEXT`): if text doesn't fit, cut words, don't shrink it. Everything is drawn at `Theme.TEXT_SCALE` (90%), and the in-run HUD sits inside a zoom set by HUD Size (default 75%). Bold is for names and card titles, not paragraphs.

## Layout rules

- **Screen titles**: `Theme.title("Bug catalogue")`. One or two words, no colons.
- **Panels**: `Theme.panel(x, y, w, h, rivets)`, the bevelled plate. Square corners, no rounded boxes or glows. Rivets only on big panels.
- **Key hints**: `Theme.footer({ { "Esc", "Back" }, ... })` draws key caps along the bottom. One word per action, at most five, swapped for pad icons or nothing on touch. Never hint sentences like "Q / E: switch tab".
- **Separators**: a middle dot with two spaces each side (`Sweep  ·  9 dmg`), never `|`.
- **Menus**: `src/ui/menu.lua`; title-style lists are `plain = true`; rows can carry a round chitin badge with a bug or item sprite (`Menu.sprite`), and title rows a `desc` shown under the list.
- **Less is more**: no debug numbers, ids or console commands on player-facing screens unless Developer Mode is on. Pass-through info (wave banners, new-species cards) hides while a menu is open.
- **HUD at the edges**: keep new HUD pieces small and at the screen edges so the fight stays visible.
- **Transitions**: full screens fade in; overlays dim the game behind to about 70% black.
- **Input-aware text**: write `{dash}`, `{attack}`, `{inventory}` in any prompt and `Theme.rich` draws the right key cap, mouse button, pad icon or touch button.

{{IMG:charselect_grid.png|Bug select: portrait grid grouped by family, chitin panels, amber focus}}

{{IMG:selftest_itemorg_bag.png|The bag: category fill, rarity outline, glowing molt seams}}

# Sound

- **All synthesised**: no sound files. Effects and music are generated in code at start-up, so the whole game is one small download and every sound can be tuned with numbers.
- **One song that follows the fight**: an 8-bar loop in D minor in six stems that never stop; only their volumes move. The music should swell with the crowd, never cut.
- **Every bug sounds like itself**: a band per body plan and a riff generated from the bug's id, loudest between waves and on bug select.
- **Sounds mark big moments, not every hit**: wave horn, clear chime, queen arrival, a bead chime that climbs note by note at the wave-end magnet, low-health heartbeat. Attack swishes are short and quiet so 500 kills don't turn into noise.

# Writing

The game's voice is plain and short. Read any `description`, `tip` or settings `desc`:

- **Say what it does, in the player's words.** "Tiny, quick and glowing with venom. Arrives in clouds." Not ids, not stat names from code.
- **Descriptions are one or two sentences**; `lore` is one real-world fact told simply; `tip` is one piece of advice ("Keep moving: they are quick but fragile.").
- **Numbers where they help**: "+15% spray damage per rank", "heals 15% of your Max HP (+15% per stack)".
- **No jargon on screen**, no "proc" in player text (it is "fires", "has a chance to").
- **Card and screen names are short**: "Bag & Shop", "Records", "Field Guide".
- **Comments in code are for people**: every content file starts with a comment that says, in plain words, what the thing is and how it plays, then lists its params. That is what made this wiki possible to generate.

# What Ozy likes and dislikes

Collected from feedback across the build, worth carrying into the spinoff:

- **Likes**: satisfying mass kills, glow and hitstop used well, bodies knocked away, being overwhelmed and fighting out of it, real bug species and real behaviours, unique moves for every bug, lots of settings, a sandbox and dev tools for everything, planning step by step and editing plans before work starts, work spread across threads.
- **Dislikes**: repeats and boring moves, anything that looks "made by AI" (generic panels, clutter, tiny text), freezes and stutter, things that feel run-ending and unfair (the stage hazards were softened for this), menus that bury the game, equipping (the whole bag counts instead).
