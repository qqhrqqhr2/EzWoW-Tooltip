--===========================================================================
-- EzWoW - Tooltip
-- Core/Base.lua : Core Tooltip Registry, Class/Race Badges, Color Engine & Line Helpers
--===========================================================================
local addonName, ns = ...
local type, pairs, ipairs, tonumber, tostring, select, pcall = type, pairs, ipairs, tonumber, tostring, select, pcall

local TooltipEngine = ns.TooltipEngine or {}
ns.TooltipEngine = TooltipEngine
local PlatformBridge = ns.compat

local TooltipEngine = {}
_G.EzWoW_Tooltip = TooltipEngine
_G.EzWoW_Tooltip = TooltipEngine
ns.addon = TooltipEngine

TooltipEngine.compat = PlatformBridge
TooltipEngine.events = ns.events
TooltipEngine.MEDIA  = "Interface\\AddOns\\" .. (addonName or "EzWoW-Tooltip") .. "\\Media\\"

TooltipEngine.L = setmetatable({}, {
    __index = function(_, key)
        return key
    end,
})

TooltipEngine.PALETTE = {
    panel   = { 18 / 255, 24 / 255, 31 / 255 },    
    panel2  = { 29 / 255, 40 / 255, 49 / 255 },    
    border  = { 52 / 255, 76 / 255, 91 / 255 },    
    accent  = { 174 / 255, 226 / 255, 106 / 255 }, 
    text    = { 237 / 255, 244 / 255, 247 / 255 }, 
    muted   = { 167 / 255, 185 / 255, 197 / 255 }, 
    warn    = { 231 / 255, 124 / 255, 112 / 255 }, 
    off     = { 99 / 255, 114 / 255, 123 / 255 },  
}

TooltipEngine.tooltips = {}

function TooltipEngine.TrackTooltip(tipFrame)
    if not tipFrame then return end
    for _, existing in ipairs(TooltipEngine.tooltips) do
        if existing == tipFrame then return end
    end
    TooltipEngine.tooltips[#TooltipEngine.tooltips + 1] = tipFrame
end

local DEFAULT_TOOLTIP_NAMES = {
    "GameTooltip",
    "ItemRefTooltip",
    "ShoppingTooltip1",
    "ShoppingTooltip2",
    "ItemRefShoppingTooltip1",
    "ItemRefShoppingTooltip2",
    "WorldMapTooltip",
    "NamePlateTooltip",
}
for _, globalName in ipairs(DEFAULT_TOOLTIP_NAMES) do
    TooltipEngine.TrackTooltip(_G[globalName])
end

function TooltipEngine.composeMediaBadge(assetName, iconSize, cropInset)
    local margin = cropInset or 2
    local maxCoord = 64 - margin
    return ("|T%s%s:%d:%d:0:0:64:64:%d:%d:%d:%d|t"):format(
        TooltipEngine.MEDIA, assetName, iconSize, iconSize, margin, maxCoord, margin, maxCoord
    )
end

TooltipEngine.icons = {
    Alliance   = TooltipEngine.composeMediaBadge("FactionAlliance", 16),
    Horde      = TooltipEngine.composeMediaBadge("FactionHorde", 16),
    Neutral    = TooltipEngine.composeMediaBadge("FactionNeutral", 16, 4),
    pvp        = TooltipEngine.composeMediaBadge("BadgePvP", 15, 4),
    questboss  = TooltipEngine.composeMediaBadge("BadgeQuest", 16, 4),
    friend     = TooltipEngine.composeMediaBadge("BadgeFriend", 15, 4),
    bnetfriend = TooltipEngine.composeMediaBadge("BadgeBNet", 15, 4),
    TANK       = TooltipEngine.composeMediaBadge("RoleTank", 15, 4),
    HEALER     = TooltipEngine.composeMediaBadge("RoleHealer", 15, 4),
    DAMAGER    = TooltipEngine.composeMediaBadge("RoleDamager", 15, 4),
}

TooltipEngine.bgs = {
    solid   = "Interface\\Buttons\\WHITE8X8",
    gradual = "Interface\\Buttons\\GreyscaleRamp64",
    dark    = "Interface\\DialogFrame\\UI-DialogBox-Background-Dark",
    alpha   = "Interface\\Tooltips\\UI-Tooltip-Background",
    rock    = "Interface\\FrameGeneral\\UI-Background-Rock",
    marble  = "Interface\\FrameGeneral\\UI-Background-Marble",
}

local SUPPORTED_CLASS_ICONS = {
    WARRIOR = true, PALADIN = true, HUNTER = true, ROGUE = true, PRIEST = true,
    DEATHKNIGHT = true, SHAMAN = true, MAGE = true, WARLOCK = true, MONK = true,
    DRUID = true, DEMONHUNTER = true, EVOKER = true,
}
TooltipEngine.CUSTOM_CLASSES = SUPPORTED_CLASS_ICONS

local SUPPORTED_RACE_ICONS = {
    HUMAN = "Human", DWARF = "Dwarf", NIGHTELF = "NightElf", GNOME = "Gnome",
    ORC = "Orc", SCOURGE = "Scourge", UNDEAD = "Undead", TAUREN = "Tauren", TROLL = "Troll",
    SKYBORNE = "Skyborne", SKYBORNEALLIANCE = "Skyborne", SKYBORNEHORDE = "Skyborne",
    HIGHORDER = "Skyborne", HIGHORDERSKYBORNE = "Skyborne", WINDSHAPER = "Skyborne",
    WINDSHAPERSKYBORNE = "Skyborne",
}
TooltipEngine.CUSTOM_RACES = SUPPORTED_RACE_ICONS

function TooltipEngine:GetClassIcon(classToken)
    if type(classToken) ~= "string" then return nil end
    local upperToken = classToken:upper()
    if SUPPORTED_CLASS_ICONS[upperToken] then
        return TooltipEngine.composeMediaBadge("Class_" .. upperToken, 16)
    end
    local tcoords = _G.CLASS_ICON_TCOORDS and _G.CLASS_ICON_TCOORDS[upperToken]
    if tcoords then
        return ("|TInterface\\TargetingFrame\\UI-Classes-Circles:15:15:0:0:256:256:%d:%d:%d:%d|t"):format(
            tcoords[1] * 256, tcoords[2] * 256, tcoords[3] * 256, tcoords[4] * 256
        )
    end
    return nil
end

function TooltipEngine:GetRaceIcon(raceToken)
    if type(raceToken) ~= "string" then return nil end
    local cleanKey = (raceToken:gsub("[%s_%-]", "")):upper()
    local fileSuffix = SUPPORTED_RACE_ICONS[cleanKey]
    if fileSuffix then
        return TooltipEngine.composeMediaBadge("Race_" .. fileSuffix, 16)
    end
    return nil
end

function TooltipEngine.clampUnitRange(numVal)
    local nodeEntry = tonumber(numVal) or 1
    if nodeEntry < 0 then return 0 elseif nodeEntry > 1 then return 1 end
    return nodeEntry
end

function TooltipEngine.safecolor(r, g, b, a)
    return TooltipEngine.clampUnitRange(r), TooltipEngine.clampUnitRange(g), TooltipEngine.clampUnitRange(b), TooltipEngine.clampUnitRange(a)
end

function TooltipEngine:GetHexColor(r, g, b)
    if type(r) == "table" then
        if r.r then
            r, g, b = r.r, r.g, r.b
        else
            r, g, b = r[1], r[2], r[3]
        end
    end
    return ("%02x%02x%02x"):format(
        TooltipEngine.clampUnitRange(r) * 255, TooltipEngine.clampUnitRange(g) * 255, TooltipEngine.clampUnitRange(b) * 255
    )
end

function TooltipEngine:GetRGBColor(hexStr)
    if type(hexStr) ~= "string" or not hexStr:match("^%x%x%x%x%x%x$") then
        return 1, 1, 1
    end
    return tonumber(hexStr:sub(1, 2), 16) / 255,
           tonumber(hexStr:sub(3, 4), 16) / 255,
           tonumber(hexStr:sub(5, 6), 16) / 255
end

function TooltipEngine:Paint(labelStr, r, g, b)
    if not labelStr then return nil end
    return "|cff" .. self:GetHexColor(r, g, b) .. labelStr .. "|r"
end

function TooltipEngine.LineRegions(tipFrame, lineIdx)
    local baseName = tipFrame and tipFrame:GetName()
    if not baseName then return nil, nil end
    return _G[baseName .. "TextLeft" .. lineIdx], _G[baseName .. "TextRight" .. lineIdx]
end

function TooltipEngine:FindLine(tipFrame, searchPattern)
    if not tipFrame or not tipFrame.NumLines then return nil end
    for entryIndex = 2, tipFrame:NumLines() do
        local leftRegion, rightRegion = TooltipEngine.LineRegions(tipFrame, entryIndex)
        local rawText = leftRegion and PlatformBridge.nosecret(leftRegion:GetText())
        if type(rawText) == "string" and rawText:find(searchPattern) then
            return leftRegion, entryIndex, rightRegion
        end
    end
    return nil
end

function TooltipEngine:HideLine(tipFrame, searchPattern)
    local leftRegion = self:FindLine(tipFrame, searchPattern)
    if leftRegion then
        leftRegion:SetText(nil)
    end
end

function TooltipEngine:HideLines(tipFrame, startRow, endRow)
    local maxRow = math.min(endRow or tipFrame:NumLines(), tipFrame:NumLines())
    for entryIndex = startRow, maxRow do
        local leftRegion = TooltipEngine.LineRegions(tipFrame, entryIndex)
        if leftRegion then
            leftRegion:SetText(nil)
        end
    end
end

function TooltipEngine:GetLine(tipFrame, targetRow)
    while tipFrame:NumLines() < targetRow do
        tipFrame:AddLine(" ")
    end
    return TooltipEngine.LineRegions(tipFrame, targetRow)
end

function TooltipEngine:IsUnitRestricted(unitToken)
    if not unitToken or PlatformBridge.issecret(unitToken) then return true end
    if PlatformBridge.anysecret(UnitName(unitToken)) or PlatformBridge.anysecret(UnitClass(unitToken)) or PlatformBridge.anysecret(UnitRace(unitToken)) then
        return true
    end
    return PlatformBridge.anysecret(
        UnitSex(unitToken),
        UnitGUID(unitToken),
        UnitPVPName(unitToken),
        UnitCreatureType(unitToken),
        UnitIsPlayer(unitToken),
        UnitLevel(unitToken),
        UnitReaction(unitToken, "player")
    )
end

function TooltipEngine.DeepCopy(inputVal)
    if type(inputVal) ~= "table" then return inputVal end
    local cloned = {}
    for entryKey, entryValue in pairs(inputVal) do
        cloned[TooltipEngine.DeepCopy(entryKey)] = TooltipEngine.DeepCopy(entryValue)
    end
    return cloned
end

function TooltipEngine:MergeVariable(schemaTable, destTable)
    if type(destTable) ~= "table" then destTable = {} end
    if type(schemaTable) ~= "table" then return destTable end
    for entryKey, defaultVal in pairs(schemaTable) do
        local existingVal = destTable[entryKey]
        if existingVal == nil then
            destTable[entryKey] = TooltipEngine.DeepCopy(defaultVal)
        elseif type(existingVal) == "table" and type(defaultVal) == "table" then
            self:MergeVariable(defaultVal, existingVal)
        end
    end
    return destTable
end
