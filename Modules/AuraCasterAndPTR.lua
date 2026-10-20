--===========================================================================
-- EzWoW - Tooltip
-- Modules/AuraCasterAndPTR.lua : Buff/Debuff Caster Resolver & Telemetry Line Cleaner
--===========================================================================
local _, ns = ...
local type, pairs, ipairs, tonumber, tostring, select, pcall = type, pairs, ipairs, tonumber, tostring, select, pcall
local AuraCasterTracker = ns.AuraCasterTracker or {}
ns.AuraCasterTracker = AuraCasterTracker
local EventDispatcher = ns.events
local addon = EzWoW_Tooltip
local compat = select(2, ...).compat
local issecret = compat.issecret
local nosecret = compat.nosecret
local format = string.format
local resolveActiveLocale = addon.GetActiveLocale
local resolveExtraLocaleText = addon.EL
local cleanColors = addon.StripColors
local appendDualNameToTitle = addon.AppendDualNameToTitle

-----------------------------------------------------------------------------
-- Synchronize Aura Caster Cvar
-----------------------------------------------------------------------------
local CASTER_TAG = "|cff4BC8E8◆|r|cff00010a|r "

function addon.SynchronizeAuraCasterCVar()
    local sCfg = (addon.db and addon.db.spell) or (EzWoW_TooltipDB and EzWoW_TooltipDB.spell)
    local onVal = not (sCfg and sCfg.showAuraCaster == false)
    local rawValue = onVal and "1" or "0"
    if C_CVar and C_CVar.SetCVar then
        pcall(C_CVar.SetCVar, "tooltipShowAuraCasterNames", rawValue)
    elseif SetCVar then
        pcall(SetCVar, "tooltipShowAuraCasterNames", rawValue)
    end
end

EventDispatcher:attachTrigger("EZWOW_TOOLTIP_GENERAL_INIT", addon.SynchronizeAuraCasterCVar)
EventDispatcher:attachEvent("PLAYER_ENTERING_WORLD", addon.SynchronizeAuraCasterCVar)
addon.SynchronizeAuraCasterCVar()

local AURA_SPELL_CLASS_LIST = {
    PRIEST = {
        
        1243, 1244, 1245, 2791, 10937, 10938, 25389, 48161,
        21562, 21564, 25392, 48162,
        
        14752, 14818, 14819, 27841, 25312, 48073,
        27681, 32999, 48074,
        
        976, 10957, 10958, 25433, 48169,
        27683, 39374, 48170,
        
        6346, 10060, 552, 1706, 14893, 15357, 15359,
        
        17, 592, 600, 3747, 6065, 6066, 10898, 10899, 10900, 10901, 25217, 25218, 48065, 48066,
        
        139, 6074, 6075, 6076, 6077, 6078, 10927, 10928, 10929, 25315, 25221, 25222, 48067, 48068,
    },
    MAGE = {
        
        1459, 1460, 1461, 10156, 10157, 27126, 42995,
        23028, 27127, 43002,
        
        604, 8450, 8451, 10173, 10174, 33944, 43015,
        1008, 8455, 10169, 10170, 27130, 33946, 43017,
        130, 54646,
    },
    DRUID = {
        
        1126, 5232, 6756, 5234, 8907, 9884, 9885, 26990, 48469,
        21849, 21850, 26991, 48470,
        
        467, 782, 1075, 8914, 9756, 9910, 26992, 53307,
        
        774, 1058, 1430, 2090, 2091, 3627, 8910, 9839, 9840, 9841, 25299, 26981, 26982, 48440, 48441,
        8936, 8938, 8939, 8940, 8941, 9750, 9856, 9857, 9858, 26980, 48442, 48443,
        2893, 29166, 17007, 24932, 24907,
    },
    PALADIN = {
        
        19740, 19834, 19835, 19836, 19837, 19838, 25291, 27140, 48931, 48932,
        25782, 25916, 27141, 48933, 48934,
        
        19742, 19850, 19852, 19853, 19854, 25290, 27142, 48935, 48936,
        25894, 25918, 27143, 48937, 48938,
        
        20217, 25898,
        1038, 25895,
        20911, 20912, 20913, 20914, 27168, 25899, 27169,
        19977, 19978, 19979, 27144, 25890, 27145,
        1022, 5599, 10278, 1044, 6940, 20729,
        
        465, 10290, 643, 10291, 1032, 10292, 10293, 27149, 48942,
        7294, 10298, 10299, 10300, 10301, 27150, 54043,
        19746, 19876, 19895, 19896, 19888, 19897, 19898, 19891, 19899, 19900, 20218, 32223,
    },
    WARLOCK = {
        
        5697, 132, 2970, 11743,
        20707, 20762, 20763, 20764, 20765, 27239, 47883,
        6307, 7804, 7805, 11766, 11767, 27268, 47982, 19480,
    },
    SHAMAN = {
        
        974, 32593, 32594, 49283, 49284, 131, 546,
    },
    WARRIOR = {
        
        6673, 5242, 6192, 11549, 11550, 11551, 25289, 2048, 47436,
        469, 47439, 47440,
    },
    HUNTER = {
        
        19506, 20905, 20906, 13159, 20043, 20190, 27045, 49071,
    },
}

local AURA_SPELL_CLASS = {}
local AURA_SPELL_NAME_CLASS = {}
for classFile, idList in pairs(AURA_SPELL_CLASS_LIST) do
    for _, entityID in ipairs(idList) do
        AURA_SPELL_CLASS[entityID] = classFile
    end
end

local spellNameClassInitialized = false
function AuraCasterTracker.prepareSpellNameClassMap()
    if spellNameClassInitialized then return end
    spellNameClassInitialized = true
    for entityID, classFile in pairs(AURA_SPELL_CLASS) do
        local displayName
        if C_Spell and C_Spell.GetSpellName then
            local isCallOk, nodeEntry = pcall(C_Spell.GetSpellName, entityID)
            if isCallOk and nodeEntry then displayName = nosecret(nodeEntry) end
        elseif GetSpellInfo then
            local isCallOk, nodeEntry = pcall(GetSpellInfo, entityID)
            if isCallOk and nodeEntry then displayName = nosecret(nodeEntry) end
        end
        if type(displayName) == "string" and displayName ~= "" then
            AURA_SPELL_NAME_CLASS[displayName] = classFile
        end
    end
end

local sessionAuraCasters = {
    byInstance = {},
    bySpellId = {},
    bySpellName = {},
}
local recentFriendlyCasts = {
    bySpellId = {},
    bySpellName = {},
}

function AuraCasterTracker.resolvePersistentCasterTable()
    if not EzWoW_TooltipDB then return nil end
    if type(EzWoW_TooltipDB.auraCasters) ~= "table" then
        EzWoW_TooltipDB.auraCasters = {}
    end
    return EzWoW_TooltipDB.auraCasters
end

function AuraCasterTracker.persistAuraCasterRecord(spellId, spellName, auraInstanceID, expirationTime, casterName, casterClass, isPlayer)
    casterName = nosecret(casterName)
    if type(casterName) ~= "string" or casterName == "" then return end
    casterClass = nosecret(casterClass)
    spellId = tonumber(nosecret(spellId))
    spellName = nosecret(spellName)
    auraInstanceID = nosecret(auraInstanceID)
    expirationTime = tonumber(nosecret(expirationTime)) or 0

    local recordItem = {
        name = casterName,
        class = casterClass,
        isPlayer = (isPlayer ~= false),
        exp = math.floor(expirationTime + 0.5),
        ts = (time and time()) or 0,
    }
    if auraInstanceID then
        sessionAuraCasters.byInstance[auraInstanceID] = recordItem
    end
    if spellId and spellId > 0 then
        sessionAuraCasters.bySpellId[spellId] = recordItem
    end
    if type(spellName) == "string" and spellName ~= "" then
        sessionAuraCasters.bySpellName[spellName] = recordItem
    end

    local dbTbl = AuraCasterTracker.resolvePersistentCasterTable()
    if dbTbl then
        if spellId and spellId > 0 then
            dbTbl["id:" .. tostring(spellId)] = recordItem
        end
        if type(spellName) == "string" and spellName ~= "" then
            dbTbl["nm:" .. spellName] = recordItem
        end
    end
end

function AuraCasterTracker.extractUnitNameAndClass(unit)
    unit = nosecret(unit)
    if type(unit) ~= "string" or unit == "" then return nil end
    local okExists, exists = pcall(UnitExists, unit)
    if not okExists or not nosecret(exists) then return nil end

    local okName, displayName = pcall(compat.UnitNameAndRealm, unit)
    displayName = okName and nosecret(displayName)
    if not displayName or displayName == "" then
        local okU, uName = pcall(UnitName, unit)
        displayName = okU and nosecret(uName)
    end
    if not displayName or displayName == "" then return nil end

    local okPlayer, isPlayer = pcall(UnitIsPlayer, unit)
    isPlayer = (okPlayer and nosecret(isPlayer)) and true or false
    local class
    if isPlayer then
        local okClass, _, classToken = pcall(UnitClass, unit)
        class = okClass and nosecret(classToken) or nil
    end
    return displayName, class, isPlayer
end

function AuraCasterTracker.locateNearbyFriendlyPlayerByClass(targetClass)
    if not targetClass then return nil end
    local candidateTokens = { "mouseover", "target", "focus", "party1", "party2", "party3", "party4" }
    for _, queryToken in ipairs(candidateTokens) do
        local okE, exVal = pcall(UnitExists, queryToken)
        if okE and nosecret(exVal) then
            local okP, hasP = pcall(UnitIsPlayer, queryToken)
            local okF, hasF = pcall(UnitIsFriend, "player", queryToken)
            local okU, hasMe = pcall(UnitIsUnit, queryToken, "player")
            if okP and nosecret(hasP) and okF and nosecret(hasF) and not (okU and nosecret(hasMe)) then
                local okC, _, classToken = pcall(UnitClass, queryToken)
                if okC and nosecret(classToken) == targetClass then
                    local nmVal, cFile, hasPl = AuraCasterTracker.extractUnitNameAndClass(queryToken)
                    if nmVal then
                        return nmVal, cFile, hasPl
                    end
                end
            end
        end
    end
    return nil
end

function AuraCasterTracker.inspectAndCachePlayerAuras()
    AuraCasterTracker.prepareSpellNameClassMap()
    if not C_UnitAuras or not C_UnitAuras.GetAuraDataByIndex then return end
    local currentTime = (GetTime and GetTime()) or 0

    for _, filter in ipairs({ "HELPFUL", "HARMFUL" }) do
        for indexEntry = 1, 40 do
            local isCallOk, aura = pcall(C_UnitAuras.GetAuraDataByIndex, "player", indexEntry, filter)
            if not isCallOk or not aura then break end

            local spellId = tonumber(nosecret(aura.spellId))
            local spellName = nosecret(aura.name)
            local auraInstanceID = nosecret(aura.auraInstanceID)
            local expTime = tonumber(nosecret(aura.expirationTime)) or 0
            local dur = tonumber(nosecret(aura.duration)) or 0
            local srcUnit = nosecret(aura.sourceUnit)

            if srcUnit and srcUnit ~= "" then
                local nmVal, classToken, hasPl = AuraCasterTracker.extractUnitNameAndClass(srcUnit)
                if nmVal then
                    AuraCasterTracker.persistAuraCasterRecord(spellId, spellName, auraInstanceID, expTime, nmVal, classToken, hasPl)
                end
            else
                
                local existing = (auraInstanceID and sessionAuraCasters.byInstance[auraInstanceID])
                    or (spellId and sessionAuraCasters.bySpellId[spellId])
                    or (spellName and sessionAuraCasters.bySpellName[spellName])

                if not existing or (expTime > 0 and existing.exp and math.abs(existing.exp - expTime) > 5) then
                    local rcVal = (spellId and recentFriendlyCasts.bySpellId[spellId])
                        or (spellName and recentFriendlyCasts.bySpellName[spellName])
                    if rcVal and rcVal.name and (currentTime - (rcVal.time or 0)) <= 5.0 then
                        AuraCasterTracker.persistAuraCasterRecord(spellId, spellName, auraInstanceID, expTime, rcVal.name, rcVal.class, true)
                    elseif dur > 0 and expTime > 0 and (expTime - currentTime) >= (dur - 3.5) then
                        
                        local buffClass = (spellId and AURA_SPELL_CLASS[spellId]) or (spellName and AURA_SPELL_NAME_CLASS[spellName])
                        if buffClass then
                            local nmVal, classToken, hasPl = AuraCasterTracker.locateNearbyFriendlyPlayerByClass(buffClass)
                            if nmVal then
                                AuraCasterTracker.persistAuraCasterRecord(spellId, spellName, auraInstanceID, expTime, nmVal, classToken, hasPl)
                            end
                        end
                    end
                elseif existing and auraInstanceID and not sessionAuraCasters.byInstance[auraInstanceID] then
                    sessionAuraCasters.byInstance[auraInstanceID] = existing
                end
            end
        end
    end
end

function AuraCasterTracker.lookupCachedAuraCaster(auraInstanceID, spellId, spellName, expirationTime)
    auraInstanceID = nosecret(auraInstanceID)
    spellId = tonumber(nosecret(spellId))
    spellName = nosecret(spellName)
    expirationTime = tonumber(nosecret(expirationTime)) or 0

    if auraInstanceID and sessionAuraCasters.byInstance[auraInstanceID] then
        return sessionAuraCasters.byInstance[auraInstanceID]
    end
    if spellId and sessionAuraCasters.bySpellId[spellId] then
        return sessionAuraCasters.bySpellId[spellId]
    end
    if spellName and sessionAuraCasters.bySpellName[spellName] then
        return sessionAuraCasters.bySpellName[spellName]
    end

    local dbTbl = AuraCasterTracker.resolvePersistentCasterTable()
    if dbTbl then
        local nowTs = (time and time()) or 0
        local recordItem = (spellId and dbTbl["id:" .. tostring(spellId)]) or (spellName and dbTbl["nm:" .. spellName])
        if recordItem and recordItem.name then
            if not recordItem.ts or (nowTs - recordItem.ts) <= 7200 then
                return recordItem
            end
        end
    end
    return nil
end

local casterTrackFrame = CreateFrame("Frame")
for _, eventFrame in ipairs({
    "PLAYER_ENTERING_WORLD",
    "UNIT_AURA",
    "PLAYER_TARGET_CHANGED",
    "UPDATE_MOUSEOVER_UNIT",
    "GROUP_ROSTER_UPDATE",
    "UNIT_SPELLCAST_SUCCEEDED",
}) do
    pcall(casterTrackFrame.RegisterEvent, casterTrackFrame, eventFrame)
end

casterTrackFrame:SetScript("OnEvent", function(_, event, arg1, arg2, arg3)
    if event == "UNIT_SPELLCAST_SUCCEEDED" then
        local unit = nosecret(arg1)
        local spellId = tonumber(nosecret(arg3))
        if unit and unit ~= "player" and spellId and spellId > 0 then
            local okP, hasP = pcall(UnitIsPlayer, unit)
            local okF, hasF = pcall(UnitIsFriend, "player", unit)
            if okP and nosecret(hasP) and okF and nosecret(hasF) then
                local nmVal, classToken = AuraCasterTracker.extractUnitNameAndClass(unit)
                if nmVal then
                    local currentTime = (GetTime and GetTime()) or 0
                    local castRec = { name = nmVal, class = classToken, isPlayer = true, time = currentTime }
                    recentFriendlyCasts.bySpellId[spellId] = castRec
                    if C_Spell and C_Spell.GetSpellName then
                        local okN, sName = pcall(C_Spell.GetSpellName, spellId)
                        sName = okN and nosecret(sName)
                        if sName and sName ~= "" then
                            recentFriendlyCasts.bySpellName[sName] = castRec
                        end
                    end
                    AuraCasterTracker.inspectAndCachePlayerAuras()
                end
            end
        end
    elseif event == "UNIT_AURA" then
        local unit = nosecret(arg1)
        if not unit or unit == "player" then
            AuraCasterTracker.inspectAndCachePlayerAuras()
        end
    else
        if event == "PLAYER_ENTERING_WORLD" and addon.SynchronizeAuraCasterCVar then
            addon.SynchronizeAuraCasterCVar()
        end
        AuraCasterTracker.inspectAndCachePlayerAuras()
    end
end)

function AuraCasterTracker.paintAuraCasterLineOnTooltip(tip, displayCaster, plainCasterName)
    if not tip or not displayCaster or displayCaster == "" then return end
    local sCfg = addon.db and addon.db.spell
    if sCfg and sCfg.showAuraCaster == false then return end
    if addon:FindLine(tip, "^" .. CASTER_TAG) then return end

    local casterLabel = resolveExtraLocaleText("caster")
    local fullLine = format("%s|cffA7B9C5%s:|r %s", CASTER_TAG, casterLabel, displayCaster)

    local tipName = tip.GetName and nosecret(tip:GetName())
    local okNum, numLines = false, 0
    if tip.NumLines then okNum, numLines = pcall(tip.NumLines, tip) end
    numLines = (okNum and tonumber(nosecret(numLines))) or 0
    if tipName and numLines >= 2 then
        local prefixLoc = casterLabel .. ":"
        for indexEntry = 2, numLines do
            local left = _G[tipName .. "TextLeft" .. indexEntry]
            local lText = left and nosecret(left:GetText())
            if type(lText) == "string" and #lText < 90 then
                if plainCasterName and plainCasterName ~= "" and strfind(lText, plainCasterName, 1, true) then
                    pcall(left.SetText, left, fullLine)
                    if addon.RemoveDebugTelemetryTooltipLines then addon.RemoveDebugTelemetryTooltipLines(tip) end
                    if tip:IsShown() then pcall(tip.Show, tip) end
                    return
                elseif strfind(lText, prefixLoc, 1, true) == 1 or strfind(lText, "시전자:", 1, true) == 1 or strfind(lText, "Caster:", 1, true) == 1 then
                    
                    return
                end
            end
        end
    end

    pcall(tip.AddLine, tip, fullLine)
    if addon.RemoveDebugTelemetryTooltipLines then
        addon.RemoveDebugTelemetryTooltipLines(tip)
    end
    if tip:IsShown() then
        pcall(tip.Show, tip)
    end
end

function AuraCasterTracker.composeCasterDisplay(displayName, class, isPlayer, sourceUnit)
    if not displayName or displayName == "" then return nil end
    if isPlayer or class then
        local colorCode = (class and select(4, GetClassColor(class))) or "ffedf4f7"
        local cIcon = (class and addon:GetClassIcon(class)) or ""
        return format("%s|c%s%s|r", cIcon ~= "" and (cIcon .. " ") or "", colorCode, displayName)
    elseif sourceUnit then
        local okColor, rowEntry, greenVal, buttonWidget = pcall(GameTooltip_UnitColor, sourceUnit)
        local hex = (okColor and rowEntry) and addon:GetHexColor(rowEntry, greenVal, buttonWidget) or "edf4f7"
        return format("|cff%s%s|r", hex, displayName)
    else
        return format("|cffedf4f7%s|r", displayName)
    end
end

function AuraCasterTracker.appendAuraCaster(tip, sourceUnit)
    sourceUnit = nosecret(sourceUnit)
    if not tip or type(sourceUnit) ~= "string" or sourceUnit == "" then return false end
    local displayName, class, isPlayer = AuraCasterTracker.extractUnitNameAndClass(sourceUnit)
    if not displayName then return false end
    local displayCaster = AuraCasterTracker.composeCasterDisplay(displayName, class, isPlayer, sourceUnit)
    AuraCasterTracker.paintAuraCasterLineOnTooltip(tip, displayCaster, displayName)
    return true
end

function AuraCasterTracker.hasSafeFrame(f)
    if not f or issecret(f) then return false end
    if f.IsForbidden then
        local isCallOk, forbidden = pcall(f.IsForbidden, f)
        if not isCallOk or forbidden then return false end
    end
    return true
end

function AuraCasterTracker.determineAndAppendAuraCaster(tip, unit, index, filter, auraInstanceID, spellID)
    if not tip then return end
    local sCfg = addon.db and addon.db.spell
    if sCfg and sCfg.showAuraCaster == false then return end
    if addon:FindLine(tip, "^" .. CASTER_TAG) then return end

    AuraCasterTracker.prepareSpellNameClassMap()
    unit = nosecret(unit)
    index = tonumber(nosecret(index))
    filter = nosecret(filter)
    auraInstanceID = nosecret(auraInstanceID)
    spellID = tonumber(nosecret(spellID))

    local okOwner, ownerFrame = false, nil
    if tip.GetOwner then okOwner, ownerFrame = pcall(tip.GetOwner, tip) end
    if okOwner and AuraCasterTracker.hasSafeFrame(ownerFrame) then
        if not unit then
            unit = nosecret(ownerFrame.unit)
                or (ownerFrame.buttonInfo and nosecret(ownerFrame.buttonInfo.unit))
                or (ownerFrame.GetAttribute and nosecret(ownerFrame:GetAttribute("unit")))
        end
        if not index then
            index = tonumber(
                (ownerFrame.buttonInfo and nosecret(ownerFrame.buttonInfo.index))
                or (ownerFrame.GetID and nosecret(ownerFrame:GetID()))
            )
        end
        if not filter then
            local bType = ownerFrame.buttonType and nosecret(ownerFrame.buttonType)
            filter = (ownerFrame.GetFilter and nosecret(ownerFrame:GetFilter()))
                or (ownerFrame.filter and nosecret(ownerFrame.filter))
                or ((bType == "DEBUFF" or bType == "HARMFUL") and "HARMFUL")
                or nil
        end
        if not auraInstanceID then
            auraInstanceID = nosecret(ownerFrame.auraInstanceID)
                or (ownerFrame.buttonInfo and nosecret(ownerFrame.buttonInfo.auraInstanceID))
        end
    end

    local tipName = tip.GetName and tip:GetName()
    local titleLeft = tipName and _G[tipName .. "TextLeft1"]
    local rawTitle = titleLeft and nosecret(titleLeft:GetText())
    local cleanTitle = (type(rawTitle) == "string") and gsub(rawTitle, "%s*|cff8398A6%(.-%)|r%s*$", "") or nil

    local resolvedUnit = unit
    local resolvedFilter = filter
    local resolvedAura = nil
    local candidateUnits = unit and { unit, "player", "target", "focus", "pet" } or { "player", "target", "focus", "pet" }

    if auraInstanceID and C_UnitAuras and C_UnitAuras.GetAuraDataByAuraInstanceID then
        for _, unitRef in ipairs(candidateUnits) do
            local isCallOk, alphaVal = pcall(C_UnitAuras.GetAuraDataByAuraInstanceID, unitRef, auraInstanceID)
            if isCallOk and alphaVal then
                resolvedAura = alphaVal
                resolvedUnit = unitRef
                break
            end
        end
    end

    if not resolvedAura and unit and index and C_UnitAuras and C_UnitAuras.GetAuraDataByIndex then
        local tryFilters = filter and { filter } or { "HELPFUL", "HARMFUL" }
        for _, f in ipairs(tryFilters) do
            local isCallOk, alphaVal = pcall(C_UnitAuras.GetAuraDataByIndex, unit, index, f)
            if isCallOk and alphaVal then
                local aSpellId = tonumber(nosecret(alphaVal.spellId))
                if not spellID or not aSpellId or aSpellId == spellID then
                    resolvedAura = alphaVal
                    resolvedUnit = unit
                    resolvedFilter = f
                    break
                end
            end
        end
    end

    if not resolvedAura and C_UnitAuras and C_UnitAuras.GetAuraDataByIndex and (spellID or cleanTitle) then
        for _, unitRef in ipairs(candidateUnits) do
            for _, f in ipairs({ "HELPFUL", "HARMFUL" }) do
                for indexEntry = 1, 40 do
                    local isCallOk, alphaVal = pcall(C_UnitAuras.GetAuraDataByIndex, unitRef, indexEntry, f)
                    if not isCallOk or not alphaVal then break end
                    local aSpellId = tonumber(nosecret(alphaVal.spellId))
                    local aName = nosecret(alphaVal.name)
                    if (spellID and aSpellId == spellID) or (cleanTitle and aName == cleanTitle) then
                        resolvedAura = alphaVal
                        resolvedUnit = unitRef
                        resolvedFilter = f
                        break
                    end
                end
                if resolvedAura then break end
            end
            if resolvedAura then break end
        end
    end

    local sourceUnit
    if resolvedAura then
        sourceUnit = nosecret(resolvedAura.sourceUnit)
        spellID = spellID or tonumber(nosecret(resolvedAura.spellId))
        cleanTitle = cleanTitle or nosecret(resolvedAura.name)
        auraInstanceID = auraInstanceID or nosecret(resolvedAura.auraInstanceID)
    elseif unit and index and UnitAura then
        local isCallOk, displayName, _, _, _, _, _, v7Val, v8Val, _, uSpellId = pcall(UnitAura, unit, index, filter or "HELPFUL")
        if isCallOk then
            v7Val, v8Val = nosecret(v7Val), nosecret(v8Val)
            sourceUnit = (type(v7Val) == "string" and v7Val) or (type(v8Val) == "string" and v8Val) or nil
            spellID = spellID or tonumber(nosecret(uSpellId))
            cleanTitle = cleanTitle or nosecret(displayName)
        end
    end

    if sourceUnit and sourceUnit ~= "" then
        local nmVal, classToken, hasPl = AuraCasterTracker.extractUnitNameAndClass(sourceUnit)
        if nmVal then
            local expTime = resolvedAura and tonumber(nosecret(resolvedAura.expirationTime)) or 0
            if resolvedUnit == "player" then
                AuraCasterTracker.persistAuraCasterRecord(spellID, cleanTitle, auraInstanceID, expTime, nmVal, classToken, hasPl)
            end
            local displayCaster = AuraCasterTracker.composeCasterDisplay(nmVal, classToken, hasPl, sourceUnit)
            AuraCasterTracker.paintAuraCasterLineOnTooltip(tip, displayCaster, nmVal)
            return
        end
    end

    local expTime = resolvedAura and tonumber(nosecret(resolvedAura.expirationTime)) or 0
    local cached = AuraCasterTracker.lookupCachedAuraCaster(auraInstanceID, spellID, cleanTitle, expTime)
    if cached and cached.name then
        local displayCaster = AuraCasterTracker.composeCasterDisplay(cached.name, cached.class, cached.isPlayer, nil)
        AuraCasterTracker.paintAuraCasterLineOnTooltip(tip, displayCaster, cached.name)
        return
    end

    local inferredClass = (spellID and AURA_SPELL_CLASS[spellID]) or (cleanTitle and AURA_SPELL_NAME_CLASS[cleanTitle])
    if inferredClass then
        
        local nearName, nearClass, nearIsPl = AuraCasterTracker.locateNearbyFriendlyPlayerByClass(inferredClass)
        if nearName then
            AuraCasterTracker.persistAuraCasterRecord(spellID, cleanTitle, auraInstanceID, expTime, nearName, nearClass, nearIsPl)
            local displayCaster = AuraCasterTracker.composeCasterDisplay(nearName, nearClass, nearIsPl, nil)
            AuraCasterTracker.paintAuraCasterLineOnTooltip(tip, displayCaster, nearName)
            return
        end

        local locClassName = (LOCALIZED_CLASS_NAMES_MALE and LOCALIZED_CLASS_NAMES_MALE[inferredClass])
            or (LOCALIZED_CLASS_NAMES_FEMALE and LOCALIZED_CLASS_NAMES_FEMALE[inferredClass])
            or inferredClass
        local colorCode = select(4, GetClassColor(inferredClass)) or "ffedf4f7"
        local cIcon = addon:GetClassIcon(inferredClass) or ""
        local coloredClass = format("%s|c%s%s|r", cIcon ~= "" and (cIcon .. " ") or "", colorCode, locClassName)
        AuraCasterTracker.paintAuraCasterLineOnTooltip(tip, format(resolveExtraLocaleText("otherPlayer"), coloredClass), nil)
        return
    end

    if (not resolvedUnit or resolvedUnit == "player") and resolvedAura and resolvedFilter ~= "HARMFUL" then
        local dur = tonumber(nosecret(resolvedAura.duration)) or 0
        if dur > 0 then
            AuraCasterTracker.paintAuraCasterLineOnTooltip(tip, format("|cffedf4f7%s|r", resolveExtraLocaleText("otherPlayerOnly")), nil)
        end
    end
end

compat.AddTooltipPostCall("UnitAura", nil, function(self, data)
    if self ~= GameTooltip or not data then return end
    local spellID = nosecret(data.id)
    appendDualNameToTitle(self, "spell", spellID)
    AuraCasterTracker.determineAndAppendAuraCaster(
        self,
        nosecret(data.unit),
        nosecret(data.index),
        nosecret(data.filter),
        nosecret(data.auraInstanceID),
        spellID
    )
end)

for _, method in ipairs({ "SetUnitAura", "SetUnitBuff", "SetUnitDebuff" }) do
    if GameTooltip[method] then
        local defaultFilter = (method == "SetUnitDebuff") and "HARMFUL" or "HELPFUL"
        hooksecurefunc(GameTooltip, method, function(self, unit, index, filter)
            unit = nosecret(unit)
            index = nosecret(index)
            filter = nosecret(filter) or defaultFilter
            if not unit or not index then return end
            AuraCasterTracker.determineAndAppendAuraCaster(self, unit, index, filter, nil, nil)
        end)
    end
end

if C_UnitAuras and C_UnitAuras.GetAuraDataByAuraInstanceID then
    for _, method in ipairs({ "SetUnitBuffByAuraInstanceID", "SetUnitDebuffByAuraInstanceID", "SetUnitAuraByAuraInstanceID" }) do
        if GameTooltip[method] then
            local defaultFilter = (method == "SetUnitDebuffByAuraInstanceID") and "HARMFUL" or nil
            hooksecurefunc(GameTooltip, method, function(self, unit, auraInstanceID)
                unit = nosecret(unit)
                auraInstanceID = nosecret(auraInstanceID)
                if not unit or not auraInstanceID then return end
                AuraCasterTracker.determineAndAppendAuraCaster(self, unit, nil, defaultFilter, auraInstanceID, nil)
            end)
        end
    end
end

EventDispatcher:attachTrigger("tooltip:spell", function(self, tip, spellID)
    if not tip or tip ~= GameTooltip then return end
    local okOwner, ownerFrame = false, nil
    if tip.GetOwner then okOwner, ownerFrame = pcall(tip.GetOwner, tip) end
    if not okOwner or not AuraCasterTracker.hasSafeFrame(ownerFrame) then
        
        if spellID and AURA_SPELL_CLASS[tonumber(nosecret(spellID))] then
            AuraCasterTracker.determineAndAppendAuraCaster(tip, "player", nil, "HELPFUL", nil, spellID)
        end
        return
    end
    local hasAuraOwner = nosecret(ownerFrame.auraInstanceID)
        or nosecret(ownerFrame.buttonInfo)
        or (ownerFrame.GetFilter and nosecret(ownerFrame:GetFilter()))
    if not hasAuraOwner then
        local anchorTarget = ownerFrame.GetParent and ownerFrame:GetParent()
        local pName = AuraCasterTracker.hasSafeFrame(anchorTarget) and anchorTarget.GetName and nosecret(anchorTarget:GetName())
        local oName = ownerFrame.GetName and nosecret(ownerFrame:GetName())
        if type(oName) == "string" and (strfind(oName, "BuffButton", 1, true) or strfind(oName, "DebuffButton", 1, true) or strfind(oName, "AuraButton", 1, true)) then
            hasAuraOwner = true
        elseif type(pName) == "string" and (strfind(pName, "BuffFrame", 1, true) or strfind(pName, "DebuffFrame", 1, true) or strfind(pName, "AuraContainer", 1, true) or strfind(pName, "AuraFrame", 1, true)) then
            hasAuraOwner = true
        end
    end
    if hasAuraOwner then
        AuraCasterTracker.determineAndAppendAuraCaster(tip, nil, nil, nil, nil, spellID)
    end
end)

-----------------------------------------------------------------------------
-- Should Hide Issue Report
-----------------------------------------------------------------------------
function AuraCasterTracker.shouldHideIssueReport()
    if addon.db and addon.db.general and addon.db.general.hideIssueReport == false then
        return false
    end
    if EzWoW_TooltipDB and EzWoW_TooltipDB.general and EzWoW_TooltipDB.general.hideIssueReport == false then
        return false
    end
    return true
end

function AuraCasterTracker.hasPtrBugShortcutLine(plainText)
    if not plainText or plainText == "" then return false end
    local lower = string.lower(plainText)
    if (lower:find("to submit an issue", 1, true)
        or lower:find("submit an issue for this", 1, true)
        or lower:find("to submit a bug", 1, true)
        or lower:find("issue report", 1, true)
        or lower:find("bug report", 1, true)
        or lower:match("^press .+ to submit")) then
        return true
    end
    if ((plainText:find("이슈", 1, true) or plainText:find("버그", 1, true) or plainText:find("오류", 1, true))
        and (plainText:find("제보", 1, true) or plainText:find("신고", 1, true))) then
        return true
    end
    return false
end

function addon:UpdateIssueReportState()
    local BugReportInterceptor = _G["PTR_IssueReporter"]
    if type(BugReportInterceptor) ~= "table" then return end

    if not BugReportInterceptor._eztTooltipHooked and type(BugReportInterceptor.SetCurrentTooltipReport) == "function" then
        BugReportInterceptor._eztTooltipHooked = true
        local origSetCurrentTooltipReport = BugReportInterceptor.SetCurrentTooltipReport
        BugReportInterceptor.SetCurrentTooltipReport = function(...)
            local registered = origSetCurrentTooltipReport(...)
            if AuraCasterTracker.shouldHideIssueReport() then
                return false
            end
            return registered
        end
    end

    if not BugReportInterceptor._eztShowHooked and type(BugReportInterceptor.Hide) == "function" then
        BugReportInterceptor._eztShowHooked = true
        hooksecurefunc(BugReportInterceptor, "Show", function(selfReporter)
            if AuraCasterTracker.shouldHideIssueReport() then
                selfReporter:Hide()
            end
        end)
        if BugReportInterceptor.HookScript then
            pcall(BugReportInterceptor.HookScript, BugReportInterceptor, "OnShow", function(selfReporter)
                if AuraCasterTracker.shouldHideIssueReport() then
                    selfReporter:Hide()
                end
            end)
        end
    end

    if type(BugReportInterceptor.Hide) == "function" then
        if AuraCasterTracker.shouldHideIssueReport() then
            BugReportInterceptor:Hide()
        else
            BugReportInterceptor:Show()
        end
    end
end

function addon.RemoveDebugTelemetryTooltipLines(tip)
    addon:UpdateIssueReportState()
    if not tip or not AuraCasterTracker.shouldHideIssueReport() then
        return
    end
    local tipName = tip.GetName and tip:GetName()
    if not tipName or not tip.NumLines then return end
    local nodeEntry = tip:NumLines() or 0
    local changed = false
    for indexEntry = nodeEntry, 2, -1 do
        local left = _G[tipName .. "TextLeft" .. indexEntry]
        local lText = left and nosecret(left:GetText())
        if lText and lText ~= "" then
            local plain = cleanColors(lText)
            if AuraCasterTracker.hasPtrBugShortcutLine(plain) then
                left:SetText(nil)
                left:Hide()
                changed = true
                local prev = _G[tipName .. "TextLeft" .. (indexEntry - 1)]
                local prevTxt = prev and nosecret(prev:GetText())
                if prev and (not prevTxt or prevTxt == "" or prevTxt == " ") then
                    prev:SetText(nil)
                    prev:Hide()
                end
            end
        end
    end
    if changed and tip:IsShown() then
        pcall(tip.Show, tip)
    end
end

EventDispatcher:attachTrigger("tooltip:show", function(self, tip)
    addon.RemoveDebugTelemetryTooltipLines(tip)
end)

for _, tipFrame in ipairs({ GameTooltip, ItemRefTooltip }) do
    if tipFrame and tipFrame.HookScript then
        tipFrame:HookScript("OnShow", function(self)
            addon.RemoveDebugTelemetryTooltipLines(self)
        end)
    end
end

if TooltipDataProcessor and TooltipDataProcessor.AddTooltipPostCall and TooltipDataProcessor.AllTypes then
    pcall(TooltipDataProcessor.AddTooltipPostCall, TooltipDataProcessor.AllTypes, function(tip)
        addon.RemoveDebugTelemetryTooltipLines(tip)
    end)
end

addon:UpdateIssueReportState()
