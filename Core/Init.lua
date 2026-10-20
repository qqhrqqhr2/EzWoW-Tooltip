--===========================================================================
-- EzWoW - Tooltip
-- Core/Init.lua : SavedVariables Migration, Per-Character Profile & Settings Loader
--===========================================================================
local addonName, ns = ...
local type, pairs, ipairs, tonumber, tostring, select, pcall = type, pairs, ipairs, tonumber, tostring, select, pcall

local CoreBootstrap = ns.CoreBootstrap or {}
ns.CoreBootstrap = CoreBootstrap
local TooltipEngine = EzWoW_Tooltip
local EventDispatcher = ns.events

local DEFAULT_STATUSBAR_TEX = TooltipEngine.MEDIA .. "StatusBar"

function CoreBootstrap.determineSavedTable(primaryGlobal, legacyGlobal)
    local priTbl = _G[primaryGlobal]
    local legTbl = _G[legacyGlobal]
    local activeTbl
    if type(priTbl) == "table" and next(priTbl) ~= nil then
        activeTbl = priTbl
    elseif type(legTbl) == "table" then
        activeTbl = legTbl
    else
        activeTbl = {}
    end
    _G[primaryGlobal] = activeTbl
    _G[legacyGlobal]  = activeTbl
    return activeTbl
end

function CoreBootstrap.sanitizeSavedConfig(configTbl)
    local gen = configTbl and configTbl.general
    if type(gen) ~= "table" then return end

    local barTex = gen.statusbarTexture
    if type(barTex) == "string" then
        if barTex:find("\\EzWoW_Tooltip\\", 1, true) then
            gen.statusbarTexture = (barTex:gsub("\\EzWoW_Tooltip\\", "\\" .. (addonName or "EzWoW-Tooltip") .. "\\"))
        elseif not barTex:find("\\", 1, true) then
            gen.statusbarTexture = DEFAULT_STATUSBAR_TEX
        end
    end
    if type(gen.scale) == "string" then
        gen.scale = tonumber(gen.scale) or 1
    end
    if gen.borderCorner ~= "angular" and gen.borderCorner ~= "default" then
        gen.borderCorner = "angular"
    end
end

local hasLoaded = false

function TooltipEngine:LoadSettings()
    local globalDB = CoreBootstrap.determineSavedTable("EzWoW_TooltipDB", "EzWoW_TooltipDB")
    _G.EzWoW_TooltipDB = globalDB
    _G.EzWoW_TooltipDB   = globalDB

    CoreBootstrap.sanitizeSavedConfig(globalDB)
    self:MergeVariable(self.defaultDB, globalDB)
    globalDB.version = self.defaultDB.version

    local charDB = CoreBootstrap.determineSavedTable("EzWoW_TooltipPerCharDB", "EzWoW_TooltipPerCharDB")
    if globalDB.general.SavedVariablesPerCharacter then
        CoreBootstrap.sanitizeSavedConfig(charDB)
        self.db = self:MergeVariable(self.DeepCopy(globalDB), charDB)
    else
        self.db = globalDB
    end

    hasLoaded = true
    EventDispatcher:trigger("tooltip:variables:loaded")
    EventDispatcher:trigger("EZWOW_TOOLTIP_GENERAL_INIT")
end

EventDispatcher:attachEvent("ADDON_LOADED", function(_, loadedName)
    if loadedName == addonName then
        TooltipEngine:LoadSettings()
    end
end)

EventDispatcher:attachEvent("VARIABLES_LOADED", function()
    if not hasLoaded then
        TooltipEngine:LoadSettings()
    end
end)
