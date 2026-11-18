-- Amber: the currency that stays between runs (src/game/amber.lua). Every real run pays some,
-- won or lost, and it is spent in the Burrow (src/states/burrow.lua) on new things to find:
-- item packs, maps, modes and artifacts. It never buys raw power.
return {
    -- what a run pays when it ends
    earn = {
        perWave = 2,          -- each wave cleared
        perQueen = 4,         -- each queen slain
        perElites = 10,       -- 1 per this many elites
        perKills = 200,       -- 1 per this many KOs
        win = 20,             -- clearing the final wave
        minimum = 1,          -- any run that cleared a wave pays at least this
        customMul = 0.5,      -- Custom Waves pay half
    },
    -- a save that already had this many runs when amber arrived gets a head start
    -- (startPerRun a run, up to startCap) so veterans aren't starting from nothing
    startPerRun = 5, startCap = 250, veteranRuns = 6,

    -- What the Burrow sells, by shelf. kind: items (a pack that adds items to the item pool),
    -- stage (a map for Cosmetics > Location), mode (a game mode), artifact (src/config/artifacts.lua).
    shelves = {
        { id = "items", name = "Item packs", list = {
            { id = "pack_thorns", name = "Thorns and Shells", cost = 25, kind = "items",
                description = "Hard little things off the garden floor: spines that hit back and shells that turn bites.",
                items = { "cactus_spine", "rose_thorn", "scarab_shell", "walnut_shell" } },
            { id = "pack_fungus", name = "Fungal Finds", cost = 30, kind = "items",
                description = "Toadstools, lichen and threads of mycelium from under the leaf litter.",
                items = { "fly_agaric", "lichen", "mycelium", "puffball" } },
            { id = "pack_charms", name = "Swarm Charms", cost = 35, kind = "items",
                description = "Tricks borrowed from other colonies: gnat clouds, silk, alarm scents and a honeypot ant.",
                items = { "gnat_swarm", "silk_bundle", "alarm_pheromone", "honeypot_ant" } },
            { id = "pack_microbes", name = "Microbe Culture", cost = 40, kind = "items",
                description = "Tiny life with big effects: amoebas, rotifers, nematodes and blooms of bacteria.",
                items = { "gut_flora", "rotifer", "amoeba", "nematode", "bacterial_bloom", "slime_mold" } },
            { id = "pack_sparks", name = "Sparks and Embers", cost = 45, kind = "items",
                description = "Things that burn, pop and crackle. Two of them molt into something worse.",
                items = { "quartz_crystal", "static_antenna", "pine_cone", "bombardier_gland", "ember_gland" } },
            { id = "pack_cursed", name = "Cursed Relics", cost = 50, kind = "items",
                description = "Purple finds with a big upside and a real cost. Once bought, they can turn up from wave 3.",
                items = { "glass_wings", "parasitoid_egg", "bullet_ant_venom", "hungry_tapeworm", "fools_gold_scarab", "queens_pheromone" } },
        } },
        { id = "maps", name = "Maps", list = {
            { id = "stage_dappled_garden", cost = 40, kind = "stage", stage = "dappled_garden" },
            { id = "stage_puddle_patio", cost = 40, kind = "stage", stage = "puddle_patio" },
            { id = "stage_forest_floor", cost = 50, kind = "stage", stage = "forest_floor" },
            { id = "stage_sandstone_wash", cost = 50, kind = "stage", stage = "sandstone_wash" },
            { id = "stage_dune_field", cost = 60, kind = "stage", stage = "dune_field" },
            { id = "stage_rotting_log", cost = 60, kind = "stage", stage = "rotting_log" },
            { id = "stage_wildflower_meadow", cost = 65, kind = "stage", stage = "wildflower_meadow" },
            { id = "stage_rainforest_floor", cost = 75, kind = "stage", stage = "rainforest_floor" },
        } },
        { id = "modes", name = "Modes", list = {
            { id = "mode_hive", cost = 40, kind = "mode", mode = "hive" },
            { id = "mode_mound", cost = 40, kind = "mode", mode = "mound" },
            { id = "mode_swarm", cost = 45, kind = "mode", mode = "swarm" },
            { id = "mode_blitz", cost = 50, kind = "mode", mode = "blitz" },
            { id = "mode_endless", cost = 50, kind = "mode", mode = "endless" },
            { id = "mode_champions", cost = 70, kind = "mode", mode = "champions" },
            { id = "mode_gauntlet", cost = 70, kind = "mode", mode = "gauntlet" },
            { id = "mode_royalcourt", cost = 80, kind = "mode", mode = "royalcourt" },
            { id = "mode_mayhem", cost = 100, kind = "mode", mode = "mayhem" },
        } },
    },
}
