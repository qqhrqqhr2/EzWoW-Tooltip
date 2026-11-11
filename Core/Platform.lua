--===========================================================================
-- EzWoW - Tooltip
-- Core/Platform.lua : Client API Compatibility Layer & Secret-Value Sanitizers
--===========================================================================
local _, ns = ...
local type, pairs, ipairs, tonumber, tostring, select, pcall = type, pairs, ipairs, tonumber, tostring, select, pcall

local PlatformBridge = ns.PlatformBridge or {}
ns.PlatformBridge = PlatformBridge

local PlatformBridge = {}
ns.compat = PlatformBridge

local verifySecret = _G.issecretvalue or function()
    return false
end
PlatformBridge.issecret = verifySecret

function PlatformBridge.nosecret(val)
    if verifySecret(val) then
        return nil
    end
    return val
end

-- Our per-frame state is kept in weak-keyed side tables, never as fields on
-- Blizzard frames: a field written by addon code taints that frame for any
-- secure code that later reads it.
function PlatformBridge.weakTable()
    return setmetatable({}, { __mode = "k" })
end
PlatformBridge.tooltipCards = PlatformBridge.weakTable()     -- tooltip -> card style layout
PlatformBridge.tooltipUnitRows = PlatformBridge.weakTable()  -- tooltip -> number of unit info rows

function PlatformBridge.anysecret(...)
    local grandTotal = select("#", ...)
    for entryIndex = 1, grandTotal do
        if verifySecret((select(entryIndex, ...))) then
            return true
        end
    end
    return false
end

-- True when an inspect request for this unit is safe to send: not in combat,
-- no inspect window of the player's own open (a request would replace its
-- data), and the unit can be inspected (checked without secret values).
function PlatformBridge.CanRequestInspect(unitToken)
    if not unitToken or type(_G.NotifyInspect) ~= "function" or type(_G.CanInspect) ~= "function" then
        return false
    end
    if _G.InCombatLockdown and _G.InCombatLockdown() then return false end
    local inspectFrame = _G.InspectFrame
    if inspectFrame and inspectFrame.IsShown and inspectFrame:IsShown() then return false end
    local spellsFrame = _G.PlayerSpellsFrame
    if spellsFrame and type(spellsFrame.IsInspecting) == "function" then
        local okInspecting, inspecting = pcall(spellsFrame.IsInspecting, spellsFrame)
        if okInspecting and PlatformBridge.nosecret(inspecting) then return false end
    end
    local okCan, canInspect = pcall(_G.CanInspect, unitToken)
    if not okCan or not PlatformBridge.nosecret(canInspect) then return false end
    if type(_G.UnitIsConnected) == "function" then
        local okConn, connected = pcall(_G.UnitIsConnected, unitToken)
        if okConn and PlatformBridge.nosecret(connected) == false then return false end
    end
    return true
end

function PlatformBridge.GetMouseFocus()
    if type(_G.GetMouseFocus) == "function" then
        return _G.GetMouseFocus()
    end
    if type(_G.GetMouseFoci) == "function" then
        local foci = _G.GetMouseFoci()
        return foci and foci[1]
    end
    return nil
end

PlatformBridge.hasSurnames = (_G.NameUtil and type(_G.NameUtil.FormatUnitNameForDisplay) == "function") and true or false

function PlatformBridge.UnitNameAndRealm(unitToken)
    if PlatformBridge.hasSurnames then
        return _G.NameUtil.FormatUnitNameForDisplay(unitToken), nil
    end
    return UnitName(unitToken)
end

local itemAPI  = _G.C_Item
local spellAPI = _G.C_Spell
local addonAPI = _G.C_AddOns

-- Modern clients removed most legacy globals (GetItemInfo, UnitAura, ...).
-- Pick the first real function, and wrap it so a missing API, a nil argument
-- or a client-side usage error returns nil instead of raising.
local function firstFunction(...)
    for entryIndex = 1, select("#", ...) do
        local candidateFn = select(entryIndex, ...)
        if type(candidateFn) == "function" then
            return candidateFn
        end
    end
    return nil
end

local function passResults(isCallOk, ...)
    if isCallOk then
        return ...
    end
    return nil
end

local function safeLookup(apiFn)
    return function(firstArg, ...)
        if not apiFn or firstArg == nil then return nil end
        return passResults(pcall(apiFn, firstArg, ...))
    end
end

PlatformBridge.GetItemInfo         = safeLookup(firstFunction(itemAPI and itemAPI.GetItemInfo, _G.GetItemInfo))
PlatformBridge.GetItemInfoInstant  = safeLookup(firstFunction(itemAPI and itemAPI.GetItemInfoInstant, _G.GetItemInfoInstant))
PlatformBridge.GetItemQualityColor = safeLookup(firstFunction(itemAPI and itemAPI.GetItemQualityColor, _G.GetItemQualityColor))
PlatformBridge.IsAddOnLoaded       = safeLookup(firstFunction(addonAPI and addonAPI.IsAddOnLoaded, _G.IsAddOnLoaded))

local rawSpellTexture = safeLookup(firstFunction(spellAPI and spellAPI.GetSpellTexture, _G.GetSpellTexture))
PlatformBridge.GetSpellTexture = function(spellID)
    if spellID == nil then return nil end
    local iconTex = rawSpellTexture(spellID)
    if iconTex then return iconTex end
    if spellAPI and type(spellAPI.GetSpellInfo) == "function" then
        local isCallOk, spellInfo = pcall(spellAPI.GetSpellInfo, spellID)
        if isCallOk and type(spellInfo) == "table" then
            return spellInfo.iconID or spellInfo.originalIconID
        end
    end
    if type(_G.GetSpellInfo) == "function" then
        return passResults(pcall(function() return select(3, _G.GetSpellInfo(spellID)) end))
    end
    return nil
end

-- True when aura queries would fail for addon code (in combat, and in some
-- instances even out of combat). A failing call builds an error, which is the
-- expensive part, so every aura scan asks this first. Only the "restricted"
-- answer is cached, and only for the current frame.
local auraRestrictedAt = nil
function PlatformBridge.AurasRestricted()
    local frameTime = (type(_G.GetTime) == "function" and _G.GetTime()) or 0
    if auraRestrictedAt == frameTime then return true end
    local restricted = false
    local secretsAPI = _G.C_Secrets
    if secretsAPI and type(secretsAPI.ShouldAurasBeSecret) == "function" then
        local isCallOk, answer = pcall(secretsAPI.ShouldAurasBeSecret)
        restricted = (not isCallOk) or verifySecret(answer) or answer == true
    else
        local auraAPI = _G.C_UnitAuras
        if auraAPI and type(auraAPI.GetAuraDataByIndex) == "function" then
            restricted = not pcall(auraAPI.GetAuraDataByIndex, "player", 1, "HELPFUL")
        end
    end
    if restricted then auraRestrictedAt = frameTime end
    return restricted
end

-- Aura lookup by index: C_UnitAuras first, legacy UnitAura as fallback.
-- Returns spellId, icon (secret values are dropped).
function PlatformBridge.GetUnitAuraSpellAndIcon(unitToken, auraIndex, auraFilter)
    if unitToken == nil or auraIndex == nil then return nil end
    if PlatformBridge.AurasRestricted() then return nil end
    local auraAPI = _G.C_UnitAuras
    if auraAPI and type(auraAPI.GetAuraDataByIndex) == "function" then
        local isCallOk, auraData = pcall(auraAPI.GetAuraDataByIndex, unitToken, auraIndex, auraFilter)
        if isCallOk and type(auraData) == "table" then
            return PlatformBridge.nosecret(auraData.spellId), PlatformBridge.nosecret(auraData.icon)
        end
        return nil
    end
    if type(_G.UnitAura) == "function" then
        -- name, icon, count, dispelType, duration, expirationTime, source, isStealable, nameplateShowPersonal, spellId
        local isCallOk, _, auraIcon, _, _, _, _, _, _, _, auraSpellId = pcall(_G.UnitAura, unitToken, auraIndex, auraFilter)
        if isCallOk then
            return PlatformBridge.nosecret(auraSpellId), PlatformBridge.nosecret(auraIcon)
        end
    end
    return nil
end

-- Tooltip accessors. Not every tooltip has :GetItem/:GetSpell/:GetUnit any more
-- (comparison / shopping tooltips, addon tooltips), so fall back to TooltipUtil
-- and to the TooltipDataProcessor `data` table.
local function callTooltipMethod(tipFrame, methodName)
    if type(tipFrame) ~= "table" then return false end
    local methodFn = tipFrame[methodName]
    if type(methodFn) ~= "function" then return false end
    return pcall(methodFn, tipFrame)
end

local function callTooltipUtil(utilName, tipFrame)
    local utilTbl = _G.TooltipUtil
    if type(tipFrame) ~= "table" or type(utilTbl) ~= "table" or type(utilTbl[utilName]) ~= "function" then
        return false
    end
    return pcall(utilTbl[utilName], tipFrame)
end

local function resolveTooltipData(tipFrame, tooltipData, dataTypeKey)
    local infoTbl = tooltipData
    if type(infoTbl) ~= "table" and type(tipFrame) == "table" and type(tipFrame.GetPrimaryTooltipData) == "function" then
        local isCallOk, primaryData = pcall(tipFrame.GetPrimaryTooltipData, tipFrame)
        infoTbl = isCallOk and primaryData or nil
    end
    if type(infoTbl) ~= "table" then return nil end
    local enumTbl = _G.Enum and _G.Enum.TooltipDataType
    local wantedType = enumTbl and enumTbl[dataTypeKey]
    local dataType = PlatformBridge.nosecret(infoTbl.type)
    if wantedType and dataType ~= nil and dataType ~= wantedType then
        return nil
    end
    return infoTbl
end

function PlatformBridge.GetTooltipItem(tipFrame, tooltipData)
    local isCallOk, itemName, itemLink, itemID = callTooltipMethod(tipFrame, "GetItem")
    if isCallOk and PlatformBridge.nosecret(itemLink) then
        return itemName, itemLink, itemID
    end
    isCallOk, itemName, itemLink, itemID = callTooltipUtil("GetDisplayedItem", tipFrame)
    if isCallOk and PlatformBridge.nosecret(itemLink) then
        return itemName, itemLink, itemID
    end
    local infoTbl = resolveTooltipData(tipFrame, tooltipData, "Item")
    if not infoTbl then return nil end
    itemID = tonumber(PlatformBridge.nosecret(infoTbl.id))
    itemLink = PlatformBridge.nosecret(infoTbl.hyperlink)
    local itemGUID = PlatformBridge.nosecret(infoTbl.guid)
    if not itemLink and itemGUID and itemAPI and type(itemAPI.GetItemLinkByGUID) == "function" then
        local okGuid, guidLink = pcall(itemAPI.GetItemLinkByGUID, itemGUID)
        itemLink = okGuid and PlatformBridge.nosecret(guidLink) or nil
    end
    if not itemLink and itemID and itemID > 0 then
        itemLink = PlatformBridge.nosecret((select(2, PlatformBridge.GetItemInfo(itemID)))) or ("item:" .. itemID)
    end
    if type(itemLink) ~= "string" then return nil end
    return nil, itemLink, itemID
end

function PlatformBridge.GetTooltipSpell(tipFrame, tooltipData)
    local isCallOk, spellName, spellID = callTooltipMethod(tipFrame, "GetSpell")
    spellID = isCallOk and tonumber(PlatformBridge.nosecret(spellID)) or nil
    if spellID then return spellName, spellID end
    isCallOk, spellName, spellID = callTooltipUtil("GetDisplayedSpell", tipFrame)
    spellID = isCallOk and tonumber(PlatformBridge.nosecret(spellID)) or nil
    if spellID then return spellName, spellID end
    local infoTbl = resolveTooltipData(tipFrame, tooltipData, "Spell")
    spellID = infoTbl and tonumber(PlatformBridge.nosecret(infoTbl.id)) or nil
    if spellID then return nil, spellID end
    return nil
end

-- A unit token we build ourselves ("player", "partyN", "raidN", "target",
-- "focus") for a GUID. On group frames inside instances the tooltip's own token
-- (GetUnit / UnitTokenFromGUID) can come back locked while the GUID is readable;
-- a token built here never is.
local function readableGUID(unit)
    local ok, guid = pcall(UnitGUID, unit)
    if ok and guid and not PlatformBridge.issecret(guid) then return guid end
    return nil
end

function PlatformBridge.CleanTokenForGUID(guid)
    if not guid or PlatformBridge.issecret(guid) then return nil end
    if readableGUID("player") == guid then return "player" end
    if _G.IsInRaid and _G.IsInRaid() then
        local count = (_G.GetNumGroupMembers and _G.GetNumGroupMembers()) or 0
        if PlatformBridge.issecret(count) then count = 40 end
        for i = 1, math.min(count, 40) do
            if readableGUID("raid" .. i) == guid then return "raid" .. i end
        end
    else
        for i = 1, 4 do
            if readableGUID("party" .. i) == guid then return "party" .. i end
        end
    end
    for _, unit in ipairs({ "target", "focus", "mouseover", "pet" }) do
        if readableGUID(unit) == guid then return unit end
    end
    return nil
end

function PlatformBridge.GetTooltipUnit(tipFrame, tooltipData)
    local isCallOk, unitName, unitToken = callTooltipMethod(tipFrame, "GetUnit")
    unitToken = isCallOk and PlatformBridge.nosecret(unitToken) or nil
    -- The tooltip data's GUID is the authoritative identity. Rebuild a clean token
    -- for it first; the reported token is only used when it maps to the same GUID.
    do
        local unitData = resolveTooltipData(tipFrame, tooltipData, "Unit")
        local dataGUID = unitData and PlatformBridge.nosecret(unitData.guid)
        if dataGUID then
            if unitToken and readableGUID(unitToken) == dataGUID and unitToken ~= "mouseover" then
                return unitName, unitToken
            end
            local clean = PlatformBridge.CleanTokenForGUID(dataGUID)
            if clean then return unitName, clean end
        end
    end
    -- The tooltip data names the unit the tooltip was built for by GUID; a world
    -- unit's token is "mouseover", which may already point at another unit.
    if (not unitToken or unitToken == "mouseover") and type(_G.UnitTokenFromGUID) == "function" then
        local unitData = resolveTooltipData(tipFrame, tooltipData, "Unit")
        local dataGUID = unitData and PlatformBridge.nosecret(unitData.guid)
        if dataGUID then
            local okToken, guidToken = pcall(_G.UnitTokenFromGUID, dataGUID)
            guidToken = okToken and PlatformBridge.nosecret(guidToken) or nil
            if guidToken then return unitName, guidToken end
        end
    end
    if unitToken then return unitName, unitToken end
    isCallOk, unitName, unitToken = callTooltipUtil("GetDisplayedUnit", tipFrame)
    unitToken = isCallOk and PlatformBridge.nosecret(unitToken) or nil
    if unitToken then return unitName, unitToken end
    local infoTbl = resolveTooltipData(tipFrame, tooltipData, "Unit")
    local unitGUID = infoTbl and PlatformBridge.nosecret(infoTbl.guid)
    if unitGUID and type(_G.UnitTokenFromGUID) == "function" then
        local okToken, guidToken = pcall(_G.UnitTokenFromGUID, unitGUID)
        unitToken = okToken and PlatformBridge.nosecret(guidToken) or nil
        if unitToken then return nil, unitToken end
    end
    return nil
end

function PlatformBridge.GetQuestLevel(questID)
    local questIDVal = tonumber(questID)
    if not questIDVal then return 0 end

    local qLog = _G.C_QuestLog
    if qLog and type(qLog.GetLogIndexForQuestID) == "function" then
        local logIdx = qLog.GetLogIndexForQuestID(questIDVal)
        local qInfo = logIdx and qLog.GetInfo and qLog.GetInfo(logIdx)
        return (qInfo and qInfo.level) or 0
    end
    if type(_G.GetQuestLogIndexByID) == "function" then
        local logIdx = _G.GetQuestLogIndexByID(questIDVal)
        if logIdx and logIdx > 0 then
            return select(2, _G.GetQuestLogTitle(logIdx)) or 0
        end
    end
    return 0
end

function PlatformBridge.AddTooltipPostCall(dataTypeKey, legacyScriptName, handleSlashCommandInput)
    local proc = _G.TooltipDataProcessor
    local enumTbl = _G.Enum and _G.Enum.TooltipDataType
    local dataTypeID = enumTbl and enumTbl[dataTypeKey]

    if proc and type(proc.AddTooltipPostCall) == "function" and dataTypeID then
        proc.AddTooltipPostCall(dataTypeID, handleSlashCommandInput)
        return true
    end
    if legacyScriptName and GameTooltip and GameTooltip.HasScript and GameTooltip:HasScript(legacyScriptName) then
        GameTooltip:HookScript(legacyScriptName, function(tipFrame)
            handleSlashCommandInput(tipFrame)
        end)
    end
    return false
end

PlatformBridge.categories = {}

function PlatformBridge.AddOptionsCategory(windowFrame, parentPanel)
    local settingsAPI = _G.Settings
    if settingsAPI and type(settingsAPI.RegisterCanvasLayoutCategory) == "function" then
        local catObj
        if parentPanel and PlatformBridge.categories[parentPanel] then
            catObj = settingsAPI.RegisterCanvasLayoutSubcategory(PlatformBridge.categories[parentPanel], windowFrame, windowFrame.name)
        else
            catObj = settingsAPI.RegisterCanvasLayoutCategory(windowFrame, windowFrame.name)
            settingsAPI.RegisterAddOnCategory(catObj)
        end
        PlatformBridge.categories[windowFrame] = catObj
    elseif type(_G.InterfaceOptions_AddCategory) == "function" then
        _G.InterfaceOptions_AddCategory(windowFrame)
    end
end

function PlatformBridge.OpenOptionsCategory(windowFrame)
    local settingsAPI = _G.Settings
    local catObj = PlatformBridge.categories[windowFrame]
    if catObj and settingsAPI and type(settingsAPI.OpenToCategory) == "function" then
        settingsAPI.OpenToCategory(catObj:GetID())
    elseif type(_G.InterfaceOptionsFrame_OpenToCategory) == "function" then
        _G.InterfaceOptionsFrame_OpenToCategory(windowFrame)
    end
end

PlatformBridge.OptionsPanelWidth = (_G.InterfaceOptionsFramePanelContainer and _G.InterfaceOptionsFramePanelContainer:GetWidth()) or 620

function PlatformBridge.FontFlag(outlineFlag)
    if outlineFlag == "NONE" or outlineFlag == "NORMAL" then
        return ""
    end
    return outlineFlag
end

-----------------------------------------------------------------------------
-- Inline icons for tooltip lines
-- Symbol characters (diamonds, stars, arrows, check marks) are missing from
-- the Latin and Cyrillic game fonts and show as boxes there, so line markers
-- are small textures taken from client atlases instead. The markup is a plain
-- |T string (file ID and whole pixel numbers only): it holds no Lua pattern
-- characters, so a line prefix that contains it still works as a find()
-- pattern. When the atlas is missing on this client the icon is "".
-----------------------------------------------------------------------------
local iconMarkupCache = {}

function PlatformBridge.AtlasIcon(atlasName, iconHeight, tintHex)
    iconHeight = iconHeight or 10
    local cacheKey = format("%s:%d:%s", tostring(atlasName), iconHeight, tostring(tintHex))
    local cached = iconMarkupCache[cacheKey]
    if cached then return cached end
    local markup = ""
    local textureAPI = _G.C_Texture
    if textureAPI and type(textureAPI.GetAtlasInfo) == "function" then
        local okInfo, info = pcall(textureAPI.GetAtlasInfo, atlasName)
        if okInfo and type(info) == "table" and type(info.file) == "number" and info.file > 0 then
            local left, right = tonumber(info.leftTexCoord), tonumber(info.rightTexCoord)
            local top, bottom = tonumber(info.topTexCoord), tonumber(info.bottomTexCoord)
            local width, height = tonumber(info.width), tonumber(info.height)
            if left and right and top and bottom and width and height and right > left and bottom > top
                and width > 0 and height > 0 then
                local fileWidth = math.floor(width / (right - left) + 0.5)
                local fileHeight = math.floor(height / (bottom - top) + 0.5)
                local iconWidth = math.max(1, math.floor(iconHeight * width / height + 0.5))
                markup = format("|T%d:%d:%d:0:0:%d:%d:%d:%d:%d:%d", info.file, iconHeight, iconWidth,
                    fileWidth, fileHeight,
                    math.floor(left * fileWidth + 0.5), math.floor(right * fileWidth + 0.5),
                    math.floor(top * fileHeight + 0.5), math.floor(bottom * fileHeight + 0.5))
                if type(tintHex) == "string" and #tintHex == 6 then
                    markup = markup .. format(":%d:%d:%d", tonumber(tintHex:sub(1, 2), 16),
                        tonumber(tintHex:sub(3, 4), 16), tonumber(tintHex:sub(5, 6), 16))
                end
                markup = markup .. "|t"
            end
        end
    end
    iconMarkupCache[cacheKey] = markup
    return markup
end

-- Line marker: a filled dot for a main line, a ring for a line that belongs
-- to the one above it (tinted with the given colour, default the accent blue).
local BULLET_ATLAS = { filled = "WhiteCircle-RaidBlips", hollow = "WhiteDotCircle-RaidBlips" }
local BULLET_TINT = "4BC8E8"

function PlatformBridge.LineBullet(isHollow, tintHex)
    return PlatformBridge.AtlasIcon(isHollow and BULLET_ATLAS.hollow or BULLET_ATLAS.filled, 10, tintHex or BULLET_TINT)
end

-- Prefix of one of our tooltip lines: marker + an empty colour code that
-- names the line kind (invisible, used to find the line again).
function PlatformBridge.LineTag(kindHex, isHollow, tintHex)
    local bullet = PlatformBridge.LineBullet(isHollow, tintHex)
    local kindMark = "|cff" .. kindHex .. "|r"
    if bullet == "" then return kindMark end
    return bullet .. kindMark .. " "
end

-- Small check mark for "collected" / "learned" marks inside a line.
function PlatformBridge.CheckIcon()
    return PlatformBridge.AtlasIcon("groupfinder-icon-greencheckmark", 11)
end
