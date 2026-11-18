# What Swarmed is

**Swarmed** is a top-down (isometric) arena roguelite made in LÖVE2D (Lua). You play one arthropod (a beetle, spider, scorpion, crustacean, centipede, mantis, dragonfly and so on) holding off endless hordes of ants, and later bees, wasps, hornets and termites. A run is fifteen waves across three maps, ending with crowned queens and the Empress.

{{IMG:cover.png|A run in progress: a horde closing in, lit by the dusk lighting pass}}

## The pillars

These were set by Ozy at the start (26 October 2026) and every system since has been checked against them.

| Pillar | What it means in the game |
| --- | --- |
| **Warriors-style mass kills** | Hundreds of ants on screen, attacks that mow down lines and rings, bodies flying, hitstop and slow motion on big moments, a frenzy super move. |
| **Brotato-style builds** | Stats everywhere. Items, level-up cards, skill trees, keepsakes and artifacts all change stats or rules, so every run builds the bug differently. |
| **Risk of Rain 2-style procs** | Items fire effects on triggers (hit, kill, hurt, dash, dodge, wave start, eat, every frame). Procs can chain, and every wave makes them more likely. |
| **Cute, crunchy pixel art that stays fast** | Small pixels with rich shading, a dusky natural palette, real-world bugs. The renderer batches everything so 1,500 enemies still run. |
| **Easy controls** | Move, attack (or auto attack), special, dash. Everything else is optional. Works on keyboard, controller and touch. |
| **Being overwhelmed** | Every ant touching you bites on its own timer, with no invulnerability after a hit. The more ants on you, the more it hurts. |

## Design rules that run through everything

- **Data first.** Every enemy, bug, item, map, event, mode and achievement is a Lua file in `content/` that returns a table. Dropping a file in a folder adds it to the game. No lists to update, no engine code to touch. Each folder has a commented `_template.lua`.
- **One file is one idea.** A behaviour, an attack or a dash lives in one file with a header comment that explains it in plain words. That header is what this wiki quotes.
- **Teach one thing at a time.** Waves introduce one new species each. Gentle Start holds whole systems back over the first runs. Every new thing gets a short card the first time it appears.
- **Never make it feel unfair.** Wind-ups are telegraphed, hazards draw warning lanes, freezes are rare, stage hazards hurt the ants too, and nothing holds a wave up except living enemies.
- **No repeats.** Ozy dislikes moves or items that feel like copies of each other. Every bug's special and dash is its own, and new content is checked against what exists.
- **Comfort is a setting, the game is not.** Lighting looks, camera, HUD size, hints, slow motion, hitstop and so on each have their own switch, and presets set them in one press. Anything that changes how the game plays (events, gambles, parasites, pacing, difficulty) is a **run rule** that only a mode or a Custom Waves set can change, so the main game is the same for everyone.
- **Not "made by AI".** Ozy pushed back twice on things that looked generic (the old inventory, cluttered screens). The answer was one shared theme (`src/ui/theme.lua`), one art style, and less text.

## The game in numbers

| Content | Count |
| --- | --- |
| Playable bugs | 26 (8 open from the start) |
| Enemies | 94, in 6 families (ants, bees, wasps, hornets, termites, predators), including 24 queens and bosses |
| Enemy behaviours (AI files) | 69 |
| Items | 115 (13 of them only made by molting) |
| Level-up cards | 43 |
| Skill trees | 26, plus 7 kin branches |
| Maps | 10 (4 bought with amber) |
| Game modes | 14 |
| Mid-wave events / stage hazards and boss encounters | 11 / 3 |
| Achievements | 123 |
| Settings | 140+ |
| Lua code | about 53,000 lines in `src/`, plus content |

## How a run feels, start to finish

1. **Title screen.** A live demo fight plays behind the menu. Play opens mode select (map, mode, keepsake, artifacts), then the bug select grid.
2. **Wave 1.** Plain worker ants march in as snaking columns from two sides and break into a ring around you. You attack, dash and use your special. Kills spill nectar beads.
3. **Levelling.** XP fills fast (the first level is about ten kills). Each level opens three stat cards right away; skipping a pick banks a skill point instead.
4. **Wave clear.** Every bead flies to you. A reward bloom sprouts beside you; walk into it to pick one of three items. The bag is a shaped-item puzzle where everything counts.
5. **Waves 2 to 4.** One new species per wave, each introduced alone under a "NEW SPECIES" card. Wave modifiers, mini-goals, events, map gambles and route tunnels join over the first few runs.
6. **Wave 5.** A queen arrives with a royal guard; she lays broods until she dies. Clearing her wave can molt touching items into stronger ones. The run then travels to the next map (act 2).
7. **Waves 6 to 14.** Bees, wasps, termites, elites, named champions, stage hazards (a sparrow, a giant anteater), the shop, cursed items, proc chains filling the screen.
8. **Wave 15.** Crowned queens one after another, then the Empress. Win, then keep going (the bag grows a row) or take on the Final Swarm.
9. **After the run.** Amber is paid out for the Burrow (new maps, modes, item packs, artifacts, keepsakes), records and achievements update, unlock goals tick forward.

## How to run it

Install LÖVE 11.4 or newer, then from the game folder:

```
love .                      # play
love . --sandbox            # straight into the sandbox
love . --selftest           # automated smoke test + horde benchmark, then quits
love . --selftest --<part>  # one part of the test (see the Tools chapter)
love . --roster             # every bug's 3D model walking in place
love . --anims              # attack animation viewer
love . --profile            # scripted massacre, prints where frame time goes
love . --balance            # a bot plays runs with several bugs and reports how far each gets
love . --makeicon           # repaints the game icon from the game's own models
```

`bash tools/build_web.sh` builds the browser version (love.js) plus `swarmed.love`; the web build runs plain Lua 5.1, so the code avoids `goto` and LuaJIT-only libraries.

## Where the code lives

The repository is `github.com/Omnilax/swarmed`; the repo root is the game folder.

```
main.lua, conf.lua      boot, LÖVE callbacks, launch flags
src/core/               registry, settings, input, touch, audio, music, screen, state stack,
                        iso projection, spatial hash, event bus, Discord pipe
src/config/             tunable numbers and tables: stats, settings schema, rarities, tags,
                        categories, danger, unlocks, amber, keepsakes, rewards, shop, ...
src/game/               the simulation: world, player, enemies, combat, spawner, pacing,
                        director, items, skills, economy, rewards, saves, records, ...
src/gfx/                sprite atlas, 3D models and animation, particles, ground, lighting,
                        shading, painted pictures (paint, propart, beasts, antlion)
src/ui/                 theme, menu widget, HUD, run HUD, palette, inspect
src/states/             every screen (menu, mode select, bug select, game, bag, shop, ...)
src/debug/              developer console, sandbox, catalogues, selftests, profiler, bot
content/                all game content, one file per thing
tools/                  Python sprite/icon generators, web build scripts
docs/                   PLAN.md (roadmap), CUSTOM_BUGS.md (Bug Creator reference)
assets/                 fonts (Pixelify Sans), icon
```

## How this documentation is made

The wiki volumes (Playable Bugs, Enemies, Items, World, Reference) are **generated from the game itself**, not written by hand. A small dump step loads every content registry exactly as the game does, writes it out with the pictures of every bug, enemy and item icon, and reads the comment block at the top of each content file. So every entry here matches the code it came from, and the set can be rebuilt after any change. This volume and the Style Guide are written from the code, the README and the design history.

This edition documents the code on the parasites / run rules branch (PR 45, on top of PRs 41, 43 and 44). A few features described in the hand-written chapters come from pull requests that were still open beside it (37 new items, 38 bug select grid, 39 new level-up cards, 40 Unlock Everything, 42 game icon and Discord status); the generated wiki pages list only what is in this build.

The same pages are in the game: **Field Guide > Wiki** (`src/states/wiki.lua`) writes every bug, enemy, item, card, map, event, mode and progression page live from the content, and its Design section is these chapters (`docs/wiki/*.md`, turned into `src/config/wiki_notes.lua` by `tools/make_wiki_notes.py`).
