-- Discord "now playing" status (src/core/discord.lua, src/game/presence.lua).
--
-- appId: the Application ID of the "Swarmed" app in the Discord Developer Portal
-- (https://discord.com/developers/applications > New Application > name it Swarmed > copy the
-- Application ID from General Information). Discord shows "Playing <app name>" from it.
-- Leave it empty and the status stays off quietly.
--
-- largeImage: the big picture on the status card. Discord takes either an https link to a
-- picture or the name of an image uploaded under Rich Presence > Art Assets of that app.
return {
    appId = "",
    largeImage = "https://raw.githubusercontent.com/Omnilax/swarmed/main/assets/icon/icon_512.png",
    largeText = "Swarmed",
    -- Discord drops updates sent faster than 5 per 20 s, so changes wait at least this long
    minInterval = 4,
    -- how often to look for Discord again when it isn't running (seconds)
    retryInterval = 20,
}
