-- Enemy families. Every enemy has a `family` (default "ant"); the catalogue and sandbox group
-- enemies by it, in this order. Add a family here before adding its first enemy, e.g. bees,
-- wasps and termites, which are planned next.
--   id, label (plural, used as a heading), single (one of them)
return {
    { id = "ant", label = "Ants", single = "Ant" },
    { id = "bee", label = "Bees", single = "Bee" },
    { id = "wasp", label = "Wasps", single = "Wasp" },
    { id = "hornet", label = "Hornets", single = "Hornet" },
    { id = "termite", label = "Termites", single = "Termite" },
    { id = "crustacean", label = "Crustaceans", single = "Crustacean" },   -- shrimp, krill, plankton (water maps)
}
