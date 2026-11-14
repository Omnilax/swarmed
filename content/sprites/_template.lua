-- TEMPLATE. Sprites are drawn as text: each character is a pixel, "." is transparent.
-- Face right; the game flips them. Every frame should be the same size.
-- Preview with:  python3 tools/preview_sprites.py out.png content/sprites/my_bug.lua
return {
    id = "my_bug",
    fps = 8,
    palette = { o = "#1a0f17", a = "#5c2a26", b = "#8a3f31" },
    frames = {
        { ".oo.", "oabo", "oaao", ".oo." },
        { ".oo.", "obao", "oaao", ".oo." },
    },
}
