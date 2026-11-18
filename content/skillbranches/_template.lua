-- TEMPLATE. Copy to content/skillbranches/<id>.lua to add a KIN branch: the 4th branch of the
-- skill tree, shared by every bug of one lineage (beetles, spiders, crustaceans...).
-- Engine: Skills.attachKin in src/game/skills.lua.
--
-- Which bugs get it: a bug gets the kin branch that shares one of its character `tags` with the
-- highest `priority` (beetles are also "insect", so the beetle branch has a higher priority than
-- the insect one). A branch with no tags fits every bug (a fallback, keep its priority low).
-- A tree can name one by id (`kin = "<id>"`) or opt out (`kin = false`).
--
-- On top of the kin nodes, every tree adds its own SIGNATURE node (`signature = { ... }` in
-- content/skilltrees/<bug>.lua): one tier above the highest kin node, 3 points by default. So
-- the kin branch reads: shared lineage perks at the bottom, the bug's own trick at the top.
--
-- Nodes use the exact same schema as tree nodes (content/skilltrees/_template.lua). Keep ids
-- unique across all trees (prefix them kin_<lineage>_), and stick to things every bug of the
-- lineage can use: stats and procs, not params of one bug's moves.
local fx = require("src.game.skills").fx

return {
    name = "My Kin",                -- branch title
    blurb = "One short line on what the lineage is about.",
    color = { 0.8, 0.8, 0.6 },
    tags = { "my_tag" },            -- character tags that get this branch
    priority = 10,
    nodes = {
        { id = "kin_my_hide", tier = 1, ranks = 2, name = "Tough Hide", desc = "+8 max HP per rank.",
          stats = { maxHp = 8 } },
        -- tier 2 fork (col -1 / 1), tier 3, tier 4 fork ... the signature lands on tier 5
    },
}
