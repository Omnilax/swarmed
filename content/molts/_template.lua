-- TEMPLATE. Copy to content/molts/my_molt.lua. A molting recipe: when every item in `from` is in
-- the bag and they all touch (one connected group, sides touching, not corners), they molt into
-- `into` once a queen wave is cleared (src/game/molting.lua). The new item takes the place of
-- the old ones. While they touch, the bag draws their seams glowing; the Records > Recipes page
-- lists every recipe, and shows the result once you have molted it.
-- `into` is normally an item with rarity = "molted" (never dealt in item choices).
return {
    from = { "ember_gland", "bombardier_gland" },   -- 2 or 3 item ids (an id may repeat)
    into = "magma_gland",
    -- hint = "Fire meets fire.",                    -- a line for the recipe book
}
