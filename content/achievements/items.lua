-- Items and the bag.
local list = {}
local function add(a) a.category = "Items"; list[#list + 1] = a; a.order = #list end

add({ id = "take_100", name = "Hoarder", description = "Take 100 items.", goal = 100, value = function(p) return p.itemsTaken end })
add({ id = "eat_1", name = "Peckish", description = "Eat an item.", value = function(p) return p.itemsEaten end })
add({ id = "eat_50", name = "Bottomless", description = "Eat 50 items.", goal = 50, value = function(p) return p.itemsEaten end })
add({ id = "eat_run8", name = "Gourmand", description = "Eat 8 items in one run.", goal = 8,
    value = function(p, run) return run and run.itemsEaten or 0 end })
add({ id = "bag_full", name = "Perfect Fit", description = "Fill every cell of your bag.", hidden = true,
    value = function(p, run)
        if not run then return false end
        local inv = run.world.player.inventory
        return inv:usedCells() >= inv.cols * inv.rows
    end })
add({ id = "molt_1", name = "Fresh Skin", description = "Molt two items into one after a queen wave.", value = function(p) return p.moltCount or 0 end })
add({ id = "molt_book", name = "Metamorphosis", description = "Discover 8 molting recipes.", goal = 8,
    value = function(p) local n = 0 for _ in pairs(p.molts or {}) do n = n + 1 end return n end })
add({ id = "chest_10", name = "Brood Raider", description = "Open 10 brood cells.", goal = 10, value = function(p) return p.chestsOpened or 0 end })
add({ id = "dup_1", name = "Seeing Double", description = "Have the aphid matriarch copy an item.", value = function(p) return p.duplicated or 0 end })
return list
