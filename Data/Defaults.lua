-- EzWoW - Tooltip : default settings
-- Key names match earlier releases so saved settings keep working.

local addon = EzWoW_Tooltip
local PANEL_BG = { 18/255, 24/255, 31/255, 0.92 }

local function anchor(position, extra)
    local t = {
        position = position,
        hiddenInCombat = false,
        returnInCombat = false,
        returnOnUnitFrame = false,
        p = "BOTTOMRIGHT",
    }
    for k, v in pairs(extra or {}) do t[k] = v end
    return t
end

addon.db = {
    version = 3.0,

    general = {
        language          = "auto",     -- auto | koKR | enUS | deDE | frFR | esES | ruRU | zhCN | zhTW
        scale             = 1,
        mask              = true,       -- glossy top highlight
        bgfile            = "solid",
        background        = { PANEL_BG[1], PANEL_BG[2], PANEL_BG[3], PANEL_BG[4] },
        borderSize        = 1,
        borderCorner      = "angular",  -- angular | default
        borderColor       = { 52/255, 76/255, 91/255, 1 },
        statusbarHeight   = 8,
        statusbarPosition = "bottom",   -- bottom | top
        statusbarOffsetX  = 0,
        statusbarOffsetY  = 0,
        statusbarFontSize = 10,
        statusbarFontFlag = "THINOUTLINE",
        statusbarText     = true,
        statusbarColor    = "auto",     -- auto (class/reaction) | default
        statusbarTexture  = "Interface\\AddOns\\EzWoW-Tooltip\\Media\\StatusBar",
        anchor            = anchor("cursor", { cursorDir = "topRight", returnInCombat = true }),
        alwaysShowIdInfo  = true,
        fadeOut           = false,
        skinMoreFrames    = true,
        hideIssueReport   = true,
        headerFont        = "default",
        headerFontSize    = "default",
        headerFontFlag    = "default",
        bodyFont          = "default",
        bodyFontSize      = "default",
        bodyFontFlag      = "default",
        SavedVariablesPerCharacter = false,
    },

    unit = {
        player = {
            coloredBorder     = "class",    -- class | default
            background        = { colorfunc = "default", alpha = PANEL_BG[4] },
            anchor            = anchor("inherit"),
            showTarget        = true,
            showTargetBy      = true,
            showModel         = true,
            showTalent        = true,
            showItemLevel     = true,
            showGearScore     = true,
            showMount         = true,
            showSpeed         = true,
            showRoleAndScore  = true,
            showCastAndThreat = true,
            hideCompletionist = true,
            grayForDead       = false,
        },
        npc = {
            coloredBorder     = "reaction", -- reaction | default
            background        = { colorfunc = "default", alpha = PANEL_BG[4] },
            anchor            = anchor("inherit"),
            showTarget        = true,
            showTargetBy      = true,
            showModel         = true,
            showSpeed         = true,
            showCastAndThreat = true,
            showNpcTracking   = true,
            grayForDead       = false,
        },
    },

    item = {
        coloredItemBorder    = true,
        showItemIcon         = true,
        showBagCount         = true,
        showItemDetails      = true,
        showCollectionStatus = true,
        showSourceInfo       = true,
        showAuctionPrice     = true,
        showDualName         = true,
        autoSellJunk         = true,
        autoRepair           = true,
    },

    spell = {
        borderColor    = { 174/255, 226/255, 106/255, 1 },
        background     = { PANEL_BG[1], PANEL_BG[2], PANEL_BG[3], PANEL_BG[4] },
        showIcon       = true,
        showAuraCaster = true,
    },

    quest = {
        coloredQuestBorder = true,
    },

    variables = {},
}

addon.defaultDB = addon.DeepCopy(addon.db)
