# The Swarmed Design Bible (PDFs)

The same knowledge lives in two places:

- **In the game**: Field Guide > Wiki (`src/states/wiki.lua`, pages written live by `src/game/wiki.lua`).
  Its Design section is the chapters in `docs/wiki/*.md`, baked into `src/config/wiki_notes.lua` by
  `python3 tools/make_wiki_notes.py` (builds leave `docs/` and `.md` files out, so the game can't read them).
- **As PDFs**: seven volumes and a combined book, built by the files in this folder.

After editing a chapter in `docs/wiki/`, run `python3 tools/make_wiki_notes.py` so the game shows it too.

## Rebuilding the PDFs

Everything is written to a work folder, `../swarmed-wiki` next to the game (set `WIKI_WORK` to change it).

1. Dump the game's content and pictures (data.json plus every bug, enemy and item picture):

       DOCDUMP_OUT=$WIKI_WORK/out xvfb-run -a love . --docdump --selftest

2. Optional screenshots (map shots, cover brawls, art tour, hazards). Run one at a time, then copy the
   `selftest_*.png` files from the LÖVE save folder into `$WIKI_WORK/shots/` without the `selftest_` prefix:

       xvfb-run -a love . --selftest --docshots
       xvfb-run -a love . --selftest --arttour
       xvfb-run -a love . --selftest --hazards

3. `pip install markdown pypdf`, then `tools/wiki/build.sh` (needs Node with Playwright and Chromium).
   It renders twice: once with hidden markers to find each heading's page, once with page numbers, then
   joins the volumes into `00_swarmed-design-bible-complete.pdf`.

Hand-written chapters: `docs/wiki/*.md` (plus `docs/CUSTOM_BUGS.md` as an appendix). `{{IMG:file.png|caption}}`
places a picture from `$WIKI_WORK/shots/` (the in-game wiki skips it). Generated volumes come from `gen.py`,
which reads the dump and the comment block at the top of each content file.
