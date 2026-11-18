-- Queens, the Empress and named champions (src/game/bosses.lua).
return {
    -- A queen's fight changes as she is hurt: at each share of health left she enrages (faster,
    -- calls her brood around her). The last queen of the final wave is the Empress, with one
    -- more phase.
    queenPhases = { 0.5 },
    empressPhases = { 0.66, 0.33 },
    enrage = { speed = 1.2, brood = 5, broodPerPhase = 2, ring = 60 },

    -- the title card as a queen walks in
    card = { time = 3.2 },
    -- "<Queen name>, <epithet>": picked by the map she rules (any map not listed uses `any`)
    epithets = {
        any = { "Mother of the Mound", "She Who Swarms", "Keeper of the Brood", "the Many-Legged" },
        backyard = { "Queen of the Backyard", "Under the Paving" },
        mown_lawn = { "Queen of the Lawn", "Beneath the Grass" },
        dune_field = { "Queen of the Dunes", "the Sun-Baked" },
        sandstone_wash = { "Queen of the Wash", "the Dry Creek's Own" },
        rainforest_floor = { "Queen of the Canopy Floor", "the Rain-Born" },
        rotting_log = { "Queen of the Rot", "Heart of the Log" },
        wildflower_meadow = { "Queen of the Meadow", "Mistress of the Blooms" },
        forest_floor = { "Queen of the Leaf Litter" },
        dappled_garden = { "Queen of the Garden" },
        puddle_patio = { "Queen of the Patio" },
    },

    -- Named champions: on these waves of each act (3rd wave of five), the first elite to show up
    -- is a champion with a name, more health and her own bar. Beating one pays bonus XP and nectar.
    championWaves = { 3, 8, 13 },
    champion = { hpMul = 3, scale = 1.2, xp = 40, nectar = 12 },
    championNames = {
        "Old Mandible", "Grist", "Splinter", "Ninefoot", "Sawjaw", "Ironback", "Hookleg", "Bramble",
        "the Widow-Maker", "Dustcoat", "Long Antenna", "Grub-Eater", "Cinder", "Thorn", "Red Rusk",
        "Six-Scar", "Quickbite", "Mossback", "Pinch", "Hollowhead",
    },
}
