--===========================================================================
-- EzWoW - Tooltip
-- Core/Base.lua : Core Tooltip Registry, Class/Race Badges, Color Engine & Line Helpers
--===========================================================================
local addonName, ns = ...

-- The "EzWoW - ..." name line at the end of tooltip additions is drawn small.
-- Shared by the EzWoW addons: the first one loaded sets it up.
if not (_G.EzWoWTooltipTagSizer and (tonumber(_G.EzWoWTooltipTagSizer.version) or 0) >= 4) then
    local sizer = {}
    sizer.version = 4
    _G.EzWoWTooltipTagSizer = sizer
    local smallFont
    local original = setmetatable({}, { __mode = "k" })   -- font string -> its own font object
    local function tagFont()
        if not smallFont and CreateFont then
            smallFont = _G.EzWoWTooltipTagFont or CreateFont("EzWoWTooltipTagFont")
            smallFont:CopyFontObject(GameTooltipTextSmall or GameTooltipText)
            local path, _, flags = smallFont:GetFont()
            if path then smallFont:SetFont(path, 8, flags) end
        end
        return smallFont
    end
    local function isTag(text)
        if type(text) ~= "string" or (issecretvalue and issecretvalue(text)) then return false end
        return text:find("^EzWoW %- ") ~= nil
    end
    -- the size goes on the line itself too: a size another addon put on the
    -- line (a font addon) would stay over the font object otherwise
    local function setSize(fs, font)
        if not (font and font.GetFont and fs.SetFont) then return end
        local path, size, flags = font:GetFont()
        if path and size then fs:SetFont(path, size, flags or "") end
    end
    local function fit(fs, tag)
        if not fs then return end
        if tag then
            if not original[fs] then original[fs] = fs:GetFontObject() or GameTooltipText end
            if tagFont() then
                fs:SetFontObject(smallFont)
                setSize(fs, smallFont)
            end
            fs:SetTextColor(0.5, 0.5, 0.5)
        elseif original[fs] then
            fs:SetFontObject(original[fs])
            setSize(fs, original[fs])
            original[fs] = nil
        end
    end
    function sizer.Refit(tip)
        local name = tip and tip.GetName and tip:GetName()
        if type(name) ~= "string" then return end
        local ok, count = pcall(tip.NumLines, tip)
        if not ok or type(count) ~= "number" or (issecretvalue and issecretvalue(count)) then return end
        for i = 1, count do
            local right = _G[name .. "TextRight" .. i]
            if right then fit(right, isTag(right:GetText())) end
            -- line 1 is the tooltip's title: a left "EzWoW - ..." there stays big
            local left = _G[name .. "TextLeft" .. i]
            if left then fit(left, i > 1 and isTag(left:GetText())) end
        end
    end
    local function restore(tip)
        local name = tip and tip.GetName and tip:GetName()
        if type(name) ~= "string" then return end
        local rightPrefix, leftPrefix = name .. "TextRight", name .. "TextLeft"
        for fs, font in pairs(original) do
            local fsName = fs.GetName and fs:GetName()
            if type(fsName) == "string" and (fsName:find(rightPrefix, 1, true) == 1 or fsName:find(leftPrefix, 1, true) == 1) then
                fs:SetFontObject(font)
                setSize(fs, font)
                original[fs] = nil
            end
        end
    end
    for _, tip in ipairs({ GameTooltip, ItemRefTooltip, ShoppingTooltip1, ShoppingTooltip2 }) do
        if tip then
            pcall(hooksecurefunc, tip, "Show", function(self) pcall(sizer.Refit, self) end)
            pcall(tip.HookScript, tip, "OnTooltipCleared", function(self) pcall(restore, self) end)
        end
    end
end
local type, pairs, ipairs, tonumber, tostring, select, pcall = type, pairs, ipairs, tonumber, tostring, select, pcall

-- A tooltip drawn again in place (the game's refresh, e.g. on Shift) may not
-- show again: the name-line sizes are set once more after it
do
    local sizer = _G.EzWoWTooltipTagSizer
    for _, tip in ipairs({ GameTooltip, ItemRefTooltip, ShoppingTooltip1, ShoppingTooltip2 }) do
        if tip and type(tip.RefreshData) == "function" and sizer and sizer.Refit then
            pcall(hooksecurefunc, tip, "RefreshData", function(self) pcall(sizer.Refit, self) end)
        end
    end
end

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

-- Some features now belong to another EzWoW addon. While that addon is loaded it runs the
-- feature and this one stays out of the way. Ask at event time, not at file load: an addon
-- that loads after this one is not reported as loaded yet.
function TooltipEngine.IsOtherAddOnLoaded(name)
    local isLoaded = (C_AddOns and C_AddOns.IsAddOnLoaded) or _G.IsAddOnLoaded
    if type(isLoaded) ~= "function" or type(name) ~= "string" then return false end
    local ok, loadedOrLoading, loaded = pcall(isLoaded, name)
    return ok and (loadedOrLoading or loaded) and true or false
end

-- Tooltip post-calls fire for every tooltip, including hidden scanning
-- tooltips that other addons read lines from. Only decorate the tracked UI
-- tooltips, or other tooltips while they are actually anchored on screen.
function TooltipEngine.IsDecoratableTooltip(tipFrame)
    if type(tipFrame) ~= "table" then return false end
    if tipFrame.IsForbidden and tipFrame:IsForbidden() then return false end
    for _, existing in ipairs(TooltipEngine.tooltips) do
        if existing == tipFrame then return true end
    end
    local frameName = tipFrame.GetName and PlatformBridge.nosecret(tipFrame:GetName())
    if type(frameName) == "string" and frameName:lower():find("scan", 1, true) then return false end
    if type(tipFrame.IsVisible) ~= "function" or not tipFrame:IsVisible() then return false end
    if type(tipFrame.GetNumPoints) == "function" and tipFrame:GetNumPoints() == 0 then return false end
    if type(tipFrame.GetLeft) == "function" and not tipFrame:GetLeft() then return false end
    return true
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

-- Attribution line: every block of lines this addon adds to a game tooltip ends
-- with one muted, right-aligned line naming the addon. Added once per tooltip
-- display and kept as the last line with content: when more of our lines arrive
-- below it later, those rows move up one place (text and color only; anchors
-- and the vertical layout stay with the client).
TooltipEngine.ATTRIBUTION_TEXT = "EzWoW - Tooltip"
local ATTRIBUTION_R, ATTRIBUTION_G, ATTRIBUTION_B = 0.5, 0.5, 0.5
local attributedTooltips = PlatformBridge.weakTable()     -- tooltip -> carries the line this display
local attributionClearHooked = PlatformBridge.weakTable() -- tooltip -> OnTooltipCleared hooked
local unpackValues = unpack or table.unpack

function TooltipEngine.IsAttributionText(text)
    if text == nil or PlatformBridge.issecret(text) then return false end
    return text == TooltipEngine.ATTRIBUTION_TEXT
end

local function attributionRegions(tipFrame, tipName, lineIdx)
    return _G[tipName .. "TextLeft" .. lineIdx], _G[tipName .. "TextRight" .. lineIdx]
end

local function isFilledText(text)
    return type(text) == "string" and text ~= "" and text ~= " "
end

-- Plain copy of one line, or nil when any part of it is secret.
local function snapshotLine(tipFrame, tipName, lineIdx)
    local leftRegion, rightRegion = attributionRegions(tipFrame, tipName, lineIdx)
    if not leftRegion then return nil end
    local leftText = leftRegion:GetText()
    local lr, lg, lb, la = leftRegion:GetTextColor()
    if PlatformBridge.anysecret(leftText, lr, lg, lb, la) then return nil end
    local lineCopy = { leftText = leftText, leftColor = { lr or 1, lg or 1, lb or 1, la or 1 }, leftShown = leftRegion:IsShown() }
    if leftRegion.GetWordWrap then lineCopy.leftWrap = leftRegion:GetWordWrap() end
    if rightRegion then
        local rightText = rightRegion:GetText()
        local rr, rg, rb, ra = rightRegion:GetTextColor()
        if PlatformBridge.anysecret(rightText, rr, rg, rb, ra) then return nil end
        lineCopy.rightText = rightText
        lineCopy.rightColor = { rr or 1, rg or 1, rb or 1, ra or 1 }
        lineCopy.rightShown = rightRegion:IsShown()
    end
    lineCopy.filled = (lineCopy.leftShown and isFilledText(leftText))
        or (lineCopy.rightShown and isFilledText(lineCopy.rightText)) or false
    return lineCopy
end

local function writeLine(tipFrame, tipName, lineIdx, lineCopy)
    local leftRegion, rightRegion = attributionRegions(tipFrame, tipName, lineIdx)
    if not leftRegion then return end
    leftRegion:SetText(lineCopy.leftText)
    leftRegion:SetTextColor(unpackValues(lineCopy.leftColor))
    if lineCopy.leftWrap ~= nil and leftRegion.SetWordWrap then leftRegion:SetWordWrap(lineCopy.leftWrap) end
    if lineCopy.leftShown then leftRegion:Show() else leftRegion:Hide() end
    if rightRegion then
        rightRegion:SetText(lineCopy.rightText)
        if lineCopy.rightColor then rightRegion:SetTextColor(unpackValues(lineCopy.rightColor)) end
        if lineCopy.rightShown then rightRegion:Show() else rightRegion:Hide() end
    end
end

local ATTRIBUTION_LINE = {
    leftText = " ", leftColor = { 0, 0, 0, 1 }, leftShown = true, leftWrap = false,
    rightText = TooltipEngine.ATTRIBUTION_TEXT, rightColor = { ATTRIBUTION_R, ATTRIBUTION_G, ATTRIBUTION_B, 1 }, rightShown = true,
}

-- other EzWoW addons' lines on item and unit tooltips (Libs/EzWoWShare) share
-- this one name line at the bottom
_G.EzWoWTooltipAttribute = function(tipFrame)
    if TooltipEngine.AttributeTooltip then return TooltipEngine.AttributeTooltip(tipFrame) end
end

-- Call after adding lines to a tooltip (before its :Show()). Hidden scan tooltips are skipped.
function TooltipEngine.AttributeTooltip(tipFrame)
    if not TooltipEngine.IsDecoratableTooltip(tipFrame) then return end
    if type(tipFrame.NumLines) ~= "function" or type(tipFrame.AddDoubleLine) ~= "function" then return end
    if not attributionClearHooked[tipFrame] and tipFrame.HasScript and tipFrame:HasScript("OnTooltipCleared") then
        attributionClearHooked[tipFrame] = true
        tipFrame:HookScript("OnTooltipCleared", function(self) attributedTooltips[self] = nil end)
    end
    local okNum, numLines = pcall(tipFrame.NumLines, tipFrame)
    numLines = okNum and tonumber(PlatformBridge.nosecret(numLines)) or nil
    if not numLines or numLines < 1 then return end
    local tipName = tipFrame.GetName and PlatformBridge.nosecret(tipFrame:GetName())
    if type(tipName) ~= "string" then
        -- lines can't be read back: rely on the mark alone
        if attributedTooltips[tipFrame] then return end
        tipFrame:AddDoubleLine(" ", TooltipEngine.ATTRIBUTION_TEXT, 0, 0, 0, ATTRIBUTION_R, ATTRIBUTION_G, ATTRIBUTION_B)
        attributedTooltips[tipFrame] = true
        return
    end

    local tagIdx
    if attributedTooltips[tipFrame] then
        for lineIdx = numLines, 2, -1 do
            local _, rightRegion = attributionRegions(tipFrame, tipName, lineIdx)
            if rightRegion and TooltipEngine.IsAttributionText(rightRegion:GetText()) then
                tagIdx = lineIdx
                break
            end
        end
    end
    if not tagIdx then
        tipFrame:AddDoubleLine(" ", TooltipEngine.ATTRIBUTION_TEXT, 0, 0, 0, ATTRIBUTION_R, ATTRIBUTION_G, ATTRIBUTION_B)
        attributedTooltips[tipFrame] = true
        return
    end

    -- Lines added below the attribution line: move them up one row.
    local rowsBelow, lastFilled = {}, nil
    for lineIdx = tagIdx + 1, numLines do
        local lineCopy = snapshotLine(tipFrame, tipName, lineIdx)
        if not lineCopy then return end   -- unreadable line below: leave everything as it is
        rowsBelow[lineIdx] = lineCopy
        if lineCopy.filled then lastFilled = lineIdx end
    end
    if not lastFilled then return end
    for lineIdx = tagIdx, lastFilled - 1 do
        writeLine(tipFrame, tipName, lineIdx, rowsBelow[lineIdx + 1])
    end
    writeLine(tipFrame, tipName, lastFilled, ATTRIBUTION_LINE)
    -- the rows moved keep the font of the row they came to (the name line's
    -- small one): every row gets the size of what it holds now
    local sizer = _G.EzWoWTooltipTagSizer
    if sizer and sizer.Refit then pcall(sizer.Refit, tipFrame) end
    -- rows keep the size of the text they had: laid out again for the text
    -- they hold now (else a longer one is cut with "...")
    if tipFrame.IsShown and tipFrame:IsShown() and tipFrame.Show then pcall(tipFrame.Show, tipFrame) end
end

-- A group token ("party1") can be locked inside instances while the same person
-- read through "mouseover" / "target" / "focus" is not. Returns a readable token
-- for the same unit, or the original one.
function TooltipEngine:ReadableUnit(unitToken, tooltipData)
    if not self:IsUnitRestricted(unitToken) then return unitToken end
    local guid = tooltipData and PlatformBridge.nosecret(tooltipData.guid)
    if not guid and unitToken and not PlatformBridge.issecret(unitToken) then
        guid = PlatformBridge.nosecret(UnitGUID(unitToken))
    end
    for _, alt in ipairs({ "mouseover", "target", "focus" }) do
        if alt ~= unitToken and not self:IsUnitRestricted(alt) then
            local altGUID = PlatformBridge.nosecret(UnitGUID(alt))
            local same = guid and altGUID and altGUID == guid
            if not same and not guid and unitToken then
                local ok, isSame = pcall(UnitIsUnit, alt, unitToken)
                same = ok and PlatformBridge.nosecret(isSame) == true
            end
            if same then return alt end
        end
    end
    return unitToken
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
