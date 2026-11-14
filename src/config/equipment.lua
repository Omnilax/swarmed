-- The bag (inventory screen, FATE style grid). Everything in the bag counts: there is nothing to
-- equip, copies of an item stack, and the only limit is fitting their shapes into the grid.
return {
    -- 10 x 3 = 30 cells; every 15 waves cleared adds a row (+10 cells, see Inventory:addRows).
    bag = { cols = 10, rows = 3 },
}
