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

PlatformBridge.GetItemInfo         = _G.GetItemInfo or (itemAPI and itemAPI.GetItemInfo)
PlatformBridge.GetItemInfoInstant  = _G.GetItemInfoInstant or (itemAPI and itemAPI.GetItemInfoInstant)
PlatformBridge.GetItemQualityColor = _G.GetItemQualityColor or (itemAPI and itemAPI.GetItemQualityColor)
PlatformBridge.IsAddOnLoaded       = _G.IsAddOnLoaded or (addonAPI and addonAPI.IsAddOnLoaded)

PlatformBridge.GetSpellTexture = _G.GetSpellTexture or (spellAPI and spellAPI.GetSpellTexture) or function(spellID)
    if spellID and type(_G.GetSpellInfo) == "function" then
        return select(3, _G.GetSpellInfo(spellID))
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
