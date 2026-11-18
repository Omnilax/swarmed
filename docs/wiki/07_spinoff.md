# Carrying it into a spinoff

This chapter is for starting the next game from this one: what can be lifted as an engine, what is Swarmed-specific, and what to watch out for.

## What is engine and what is game

| Layer | Files | Reuse |
| --- | --- | --- |
| **Core** | `src/core/*`: registry, state stack, settings, input + touch, screen + post shader, iso projection, spatial hash, event bus, audio buses, music stems, Discord pipe, util | Lift as-is. Nothing here knows about ants. |
| **Content system** | `src/content.lua` + `content/*/_template.lua` | Keep the pattern (one registry per kind, one file per thing, cross-check at load). Swap the kinds. |
| **Renderer** | `src/gfx/sprites.lua` (atlas, 32 rotations, 3D models with leg rigs, chain bodies), `anim.lua`, `particles.lua`, `ground.lua`, `paint.lua`, `lighting.lua`, `shading.lua`, `clarity.lua`, `ambience.lua`, `camfx.lua` | Lift. The "one atlas, batched horde" approach is what lets 1,500 enemies run. The painter is the way to add big non-sprite art in the same style. |
| **Simulation scaffold** | `src/game/world.lua`, `enemy.lua` (pool), `combat.lua`, `stats.lua`, `stamina.lua`, `grab.lua`, `hazards.lua`, `props.lua`, `envfx.lua`, `camera.lua`, `ai.lua` | Lift and trim. `World:update` order and `Combat.damage` are the backbone; the swarm-specific parts (columns, swarm shade, bite timers) are behaviours and flags, not hard-wired. |
| **Run systems** | spawner, pacing, entries, director, rewards (frenzy, streaks, goals, routes), rewardflow, choices, levelups, skills, inventory, molting, economy, nectar, gambles, acts, bosses | Each is one module with its numbers in `src/config/` and its pieces in `content/`. Keep the ones the spinoff needs; most can be switched off per mode already. |
| **Meta** | records, achievements, amber, unlocks, danger, artifacts, keepsakes, cosmetics, daily/weekly, run codes, run saves, onramp, lessons | Reusable as a set; change the numbers and content. |
| **Tools** | sandbox, catalogues, console, selftests, profiler, balance bot, sprite and icon generators, web build | Lift. These are why content could be added fast and safely. |
| **Swarmed-specific** | the 26 bugs, 94 enemies, 69 behaviours, 115 items, maps, events, hazards, modes, music score, texts | Content. The spinoff can keep any of it or start fresh in the same folders. |

## Principles worth keeping

1. **Content is data with code hooks.** Plain tables for numbers and text, small functions only where behaviour is needed (`update`, `fire`, `effect`, `start`). Templates document every field.
2. **Cross-check everything at load.** A typo should stop the game at start-up with a list, never crash mid-run.
3. **One damage path, one stamina path, one XP path.** `Combat.damage`, `Stamina.*`, `World:grantXP`. Run stats, procs, achievements and feel all hang off them.
4. **Every system has its numbers in one config file**, and a mode can override them.
5. **An event bus per run**, so new systems listen instead of being called.
6. **Every system has a selftest part and a sandbox handle.** Tests run headless and never touch the player's save.
7. **Seeded randomness** for anything a run code, daily run or replay must repeat.
8. **Settings for every optional extra**, with presets to set many at once.
9. **One art style, one UI theme, one voice.** Generators and painters, not hand-placed one-offs.

## Things to know before building on it

- **Open pull requests.** At the time of writing several PRs (36-45) are not merged into `main`. PRs 41, 43, 44 and 45 form one chain (this build); 36-40 and 42 sit beside it and need merging by hand (conflicts in menu, pause, mode select, player and selftest files). Merge them (or pick a base) before forking the code.
- **No CI.** Tests run by hand. A spinoff should add a GitHub Action that runs `luac5.1 -p` over every file (to catch Lua 5.1 breaks for the web build) and the selftest under xvfb.
- **Selftest timing.** Run LÖVE processes one at a time, and wait on conditions, not frame counts (slow motion changes how much game time a frame is). The full selftest has been flaky at times; the per-part runs are reliable.
- **Atlas size.** The atlas is about 2048×14,000 px. Desktop GPUs handle it; some phones cap textures at 8,192 or 16,384 px. A spinoff with more sprites should split it into pages or bake fewer rotations for small enemies.
- **Big files.** `world.lua` (1,700 lines), `custombugs.lua` (1,250), `charselect.lua` (1,160) and `selftest.lua` (1,180) carry a lot. They are the first candidates to split.
- **Web build limits.** Plain Lua 5.1: no `goto`, no FFI, no `bit` library assumptions, and performance is interpreter-speed. `love.math.random` is kept for seeded runs even though it is the slowest remaining hot call.
- **Discord** needs a real Application ID before it shows anything.
- **Audio is synthesised.** That keeps the download tiny but limits how rich the sound can get; `Audio` already allows swapping a sound's `data` for a file when real audio exists.
- **Balance.** The balance bot is much worse than a person; early waves were found too easy once and then reworked (big early waves, live pressure). Re-check with real playtests (the Playtest Log helps).

## A checklist for day one of the spinoff

1. Fork the repository at a merged commit; run `love . --selftest` and `love . --selftest --arttour` to confirm the base works.
2. Decide which run systems the new game keeps; switch the rest off in its modes and delete them once sure.
3. Replace `src/config/families.lua`, `bugfamilies.lua`, `stats.lua` and `tags.lua` with the new game's lists first: everything else hangs off them.
4. Write new `_template.lua` files for any new content kind, add the registry, then add content one file at a time with the sandbox open.
5. Keep the Style Guide's rules (ramps, light from the upper left, soft outlines, dusky palette, chitin UI, minimum text size) or write the new game's own version of that chapter before making art.
6. Add CI before the content grows.
