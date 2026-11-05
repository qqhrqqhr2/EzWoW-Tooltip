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

-- Aura lookup by index: C_UnitAuras first, legacy UnitAura as fallback.
-- Returns spellId, icon (secret values are dropped).
function PlatformBridge.GetUnitAuraSpellAndIcon(unitToken, auraIndex, auraFilter)
    if unitToken == nil or auraIndex == nil then return nil end
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

function PlatformBridge.GetTooltipUnit(tipFrame, tooltipData)
    local isCallOk, unitName, unitToken = callTooltipMethod(tipFrame, "GetUnit")
    unitToken = isCallOk and PlatformBridge.nosecret(unitToken) or nil
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
