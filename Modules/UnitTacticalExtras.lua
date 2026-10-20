--===========================================================================
-- EzWoW - Tooltip
-- Modules/UnitTacticalExtras.lua : Unit Mount, Move Speed, Cast Bar, Threat & NPC Role Enricher
--===========================================================================
local _, ns = ...
local type, pairs, ipairs, tonumber, tostring, select, pcall = type, pairs, ipairs, tonumber, tostring, select, pcall
local UnitTacticalOverlay = ns.UnitTacticalOverlay or {}
ns.UnitTacticalOverlay = UnitTacticalOverlay
local EventDispatcher = ns.events
local addon = EzWoW_Tooltip
local compat = select(2, ...).compat
local issecret = compat.issecret
local nosecret = compat.nosecret
local format = string.format
local resolveActiveLocale = addon.GetActiveLocale
local resolveExtraLocaleText = addon.EL
local composeIcon = addon.FormatIcon
local cleanColors = addon.StripColors
local determineQuestName = addon.ResolveQuestName
local hasQuestCompleted = addon.IsQuestCompleted
local appendDualNameToTitle = addon.AppendDualNameToTitle
local verifyItemCollectionStatus = addon.CheckItemCollectionStatus
local composeDurationShort = addon.FormatDurationShort
local resolveZoneCollectionSummary = addon.GetZoneCollectionSummary

local translationHelper = addon.TACTICAL_TAGS
local ILVL_PREFIX_TAG     = translationHelper.ILVL_PREFIX_TAG
local MOUNT_PREFIX_TAG    = translationHelper.MOUNT_PREFIX_TAG
local SPEED_PREFIX_TAG    = translationHelper.SPEED_PREFIX_TAG
local SCORE_PREFIX_TAG    = translationHelper.SCORE_PREFIX_TAG
local CAST_PREFIX_TAG     = translationHelper.CAST_PREFIX_TAG
local THREAT_PREFIX_TAG   = translationHelper.THREAT_PREFIX_TAG
local NPC_ALIVE_TAG       = translationHelper.NPC_ALIVE_TAG
local NPC_TRACK_TAG       = translationHelper.NPC_TRACK_TAG
local NPC_NOTABLE_TAG     = translationHelper.NPC_NOTABLE_TAG
local ILVL_PATTERN        = translationHelper.ILVL_PATTERN
local MOUNT_PATTERN       = translationHelper.MOUNT_PATTERN
local SPEED_PATTERN       = translationHelper.SPEED_PATTERN
local SCORE_PATTERN       = translationHelper.SCORE_PATTERN
local CAST_PATTERN        = translationHelper.CAST_PATTERN
local THREAT_PATTERN      = translationHelper.THREAT_PATTERN
local NPC_ALIVE_PATTERN   = translationHelper.NPC_ALIVE_PATTERN
local NPC_TRACK_PATTERN   = translationHelper.NPC_TRACK_PATTERN
local NPC_NOTABLE_PATTERN = translationHelper.NPC_NOTABLE_PATTERN

local ilvlCache = {}
local ILVL_TTL = 120
local EQUIP_SLOTS = { 1, 2, 3, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15, 16, 17, 18 }
local lastInspectReqTime = 0
local lastInspectReqGUID = nil
local pendingInspectTimer = false

function UnitTacticalOverlay.determineUnitByGUID(guid)
    if not guid or issecret(guid) then return nil end
    if UnitGUID("player") == guid then return "player" end
    if _G.UnitTokenFromGUID then
        local isCallOk, queryToken = pcall(_G.UnitTokenFromGUID, guid)
        queryToken = isCallOk and nosecret(queryToken)
        if queryToken and UnitExists(queryToken) then return queryToken end
    end
    for _, queryToken in ipairs({ "mouseover", "target", "focus" }) do
        if UnitExists(queryToken) and nosecret(UnitGUID(queryToken)) == guid then
            return queryToken
        end
    end
    if IsInRaid and IsInRaid() then
        for index = 1, (GetNumGroupMembers and GetNumGroupMembers() or 0) do
            local queryToken = "raid" .. index
            if UnitExists(queryToken) and nosecret(UnitGUID(queryToken)) == guid then return queryToken end
        end
    elseif IsInGroup and IsInGroup() then
        for index = 1, (GetNumSubgroupMembers and GetNumSubgroupMembers() or 0) do
            local queryToken = "party" .. index
            if UnitExists(queryToken) and nosecret(UnitGUID(queryToken)) == guid then return queryToken end
        end
    end
    return nil
end

function UnitTacticalOverlay.evaluateEquippedIlvlFromSlots(unit)
    if not GetInventoryItemLink then return nil end
    local grandTotal, totalCount = 0, 0
    for _, slot in ipairs(EQUIP_SLOTS) do
        local okLink, rawLink = pcall(GetInventoryItemLink, unit, slot)
        local link = okLink and nosecret(rawLink) or nil
        if link then
            local ilvl
            if C_Item and C_Item.GetDetailedItemLevelInfo then
                local isCallOk, entryValue = pcall(C_Item.GetDetailedItemLevelInfo, link)
                if isCallOk and entryValue then ilvl = nosecret(entryValue) end
            elseif GetDetailedItemLevelInfo then
                local isCallOk, entryValue = pcall(GetDetailedItemLevelInfo, link)
                if isCallOk and entryValue then ilvl = nosecret(entryValue) end
            end
            if not ilvl and compat.GetItemInfo then
                local isCallOk, _, _, _, entryValue = pcall(compat.GetItemInfo, link)
                if isCallOk and entryValue then ilvl = nosecret(entryValue) end
            end
            if ilvl and type(ilvl) == "number" and ilvl > 0 then
                grandTotal = grandTotal + ilvl
                totalCount = totalCount + 1
            end
        end
    end
    if totalCount >= 1 then
        return math.floor((grandTotal / totalCount) * 10 + 0.5) / 10
    end
    return nil
end

function UnitTacticalOverlay.tryRequestInspectForTooltip(unit, guid)
    if not NotifyInspect or not CanInspect or InCombatLockdown() then return end
    if InspectFrame and InspectFrame:IsShown() then return end
    if PlayerSpellsFrame and PlayerSpellsFrame.IsInspecting and PlayerSpellsFrame:IsInspecting() then return end
    local okCan, canInsp = pcall(CanInspect, unit)
    if not okCan or not nosecret(canInsp) then return end
    local okConn, hasConn = pcall(UnitIsConnected, unit)
    if okConn and nosecret(hasConn) == false then return end

    local currentTime = GetTime()
    if guid == lastInspectReqGUID and (currentTime - lastInspectReqTime) < 15.0 then return end
    if (currentTime - lastInspectReqTime) >= 1.2 then
        lastInspectReqTime = currentTime
        lastInspectReqGUID = guid
        pcall(NotifyInspect, unit)
    elseif not pendingInspectTimer and C_Timer and C_Timer.After then
        pendingInspectTimer = true
        local targetGuid = guid
        C_Timer.After(0.4, function()
            pendingInspectTimer = false
            if not GameTooltip:IsShown() or InCombatLockdown() then return end
            if InspectFrame and InspectFrame:IsShown() then return end
            local unitRef = UnitTacticalOverlay.determineUnitByGUID(targetGuid)
            if unitRef and UnitExists(unitRef) then
                local okC, canC = pcall(CanInspect, unitRef)
                if okC and nosecret(canC) then
                    lastInspectReqTime = GetTime()
                    lastInspectReqGUID = targetGuid
                    pcall(NotifyInspect, unitRef)
                end
            end
        end)
    end
end

function UnitTacticalOverlay.extractUnitItemLevel(unit, guid, isInspectReady)
    if not unit or not UnitExists(unit) or not nosecret(UnitIsPlayer(unit)) then return nil end
    if nosecret(UnitIsUnit(unit, "player")) then
        local slotAvg = UnitTacticalOverlay.evaluateEquippedIlvlFromSlots("player")
        if slotAvg and slotAvg > 0 then
            return slotAvg
        end
        if GetAverageItemLevel then
            local isCallOk, _, equipped = pcall(GetAverageItemLevel)
            if isCallOk and equipped and not issecret(equipped) and equipped > 0 then
                return math.floor(equipped * 10 + 0.5) / 10
            end
        end
        return nil
    end

    local currentTime = GetTime()
    local cached = guid and ilvlCache[guid]
    if cached and (currentTime - cached.time) < ILVL_TTL and not isInspectReady then
        return cached.ilvl
    end

    local rawValue = UnitTacticalOverlay.evaluateEquippedIlvlFromSlots(unit)
    if not rawValue and C_PaperDollInfo and C_PaperDollInfo.GetInspectItemLevel then
        local isCallOk, entryValue = pcall(C_PaperDollInfo.GetInspectItemLevel, unit)
        entryValue = isCallOk and nosecret(entryValue)
        if entryValue and type(entryValue) == "number" and entryValue > 0 then
            rawValue = math.floor(entryValue * 10 + 0.5) / 10
        end
    end
    if rawValue and rawValue > 0 and guid then
        ilvlCache[guid] = { ilvl = rawValue, time = currentTime }
        return rawValue
    end

    if not isInspectReady then
        UnitTacticalOverlay.tryRequestInspectForTooltip(unit, guid)
    end
    return cached and cached.ilvl or nil
end

function addon:FormatPlayerIlvlAndGearScore(unit, ilvlVal)
    local numIlvl = tonumber(ilvlVal)
    if not numIlvl or numIlvl <= 0 then return nil end
    local pCfg = self.db and self.db.unit and self.db.unit.player
    local showGS = not pCfg or pCfg.showGearScore ~= false
    local score = (showGS and unit and self.CalculateUnitAverageItemLevel) and self:CalculateUnitAverageItemLevel(unit) or nil
    if score and score > 0 then
        local gsHex = (self.GetGearScoreColorHex and self:GetGearScoreColorHex(score)) or "EDF4F7"
        return format("%s|cffA7B9C5%s:|r |cffEDF4F7%.1f|r|cff%s(%d)|r", ILVL_PREFIX_TAG, resolveExtraLocaleText("ilvl"), numIlvl, gsHex, score)
    end
    return format("%s|cffA7B9C5%s:|r |cffEDF4F7%.1f|r", ILVL_PREFIX_TAG, resolveExtraLocaleText("ilvl"), numIlvl)
end

-----------------------------------------------------------------------------
-- Prepare Mount Spell Map
-----------------------------------------------------------------------------
local mountSpellMap = nil
function UnitTacticalOverlay.prepareMountSpellMap()
    if mountSpellMap then return mountSpellMap end
    mountSpellMap = {}
    if not C_MountJournal or not C_MountJournal.GetMountIDs then return mountSpellMap end
    local isCallOk, ids = pcall(C_MountJournal.GetMountIDs)
    if not isCallOk or type(ids) ~= "table" then return mountSpellMap end
    for _, mID in ipairs(ids) do
        local iok, displayName, spellID, iconTex, _, _, _, _, _, _, _, hasCollected = pcall(C_MountJournal.GetMountInfoByID, mID)
        if iok and spellID then
            mountSpellMap[spellID] = { name = displayName, icon = iconTex, isCollected = hasCollected }
        end
    end
    return mountSpellMap
end

function UnitTacticalOverlay.extractUnitMount(unit)
    if InCombatLockdown() or not C_UnitAuras or not C_UnitAuras.GetAuraDataByIndex then return nil end
    if C_Secrets and C_Secrets.ShouldAurasBeSecret then
        local isCallOk, sec = pcall(C_Secrets.ShouldAurasBeSecret)
        if isCallOk and sec then return nil end
    end
    for index = 1, 40 do
        local isCallOk, aura = pcall(C_UnitAuras.GetAuraDataByIndex, unit, index, "HELPFUL")
        if not isCallOk or not aura then break end
        local spellIDVal = nosecret(aura.spellId)
        if spellIDVal then
            if C_MountJournal and C_MountJournal.GetMountFromSpell then
                local mok, mID = pcall(C_MountJournal.GetMountFromSpell, spellIDVal)
                mID = mok and nosecret(mID)
                if mID and mID > 0 and C_MountJournal.GetMountInfoByID then
                    local iok, mName, _, mIcon, _, _, _, _, _, _, _, hasCollected = pcall(C_MountJournal.GetMountInfoByID, mID)
                    if iok and mName then
                        local badge = hasCollected
                            and format(" |cffAEE26A[%s]|r", resolveExtraLocaleText("collected"))
                            or format(" |cffEA837E[%s]|r", resolveExtraLocaleText("uncollected"))
                        return format("%s|cffEDF4F7%s|r%s", composeIcon(mIcon or nosecret(aura.icon)), mName, badge)
                    end
                end
            end
            local map = UnitTacticalOverlay.prepareMountSpellMap()
            local mInfo = map and map[spellIDVal]
            if mInfo and mInfo.name then
                local badge = mInfo.isCollected
                    and format(" |cffAEE26A[%s]|r", resolveExtraLocaleText("collected"))
                    or format(" |cffEA837E[%s]|r", resolveExtraLocaleText("uncollected"))
                return format("%s|cffEDF4F7%s|r%s", composeIcon(mInfo.icon or nosecret(aura.icon)), mInfo.name, badge)
            end
        end
    end
    return nil
end

-----------------------------------------------------------------------------
-- Extract Unit Move Speed
-----------------------------------------------------------------------------
function UnitTacticalOverlay.extractUnitMoveSpeed(unit)
    if not GetUnitSpeed or not unit or not UnitExists(unit) then return nil end
    local isCallOk, speed = pcall(GetUnitSpeed, unit)
    speed = isCallOk and nosecret(speed)
    if not speed or type(speed) ~= "number" or speed <= 0 then return nil end
    local pct = math.floor((speed / 7) * 100 + 0.5)
    if pct <= 0 then return nil end
    local colorRGB = (pct > 100) and "AEE26A" or ((pct < 100) and "EA837E" or "E8E7A8")
    return format("|cff%s%d%%|r", colorRGB, pct)
end

function UnitTacticalOverlay.extractUnitPvPAndScore(unit)
    local parts = {}
    if UnitPVPRank and GetPVPRankInfo then
        local isCallOk, rank = pcall(UnitPVPRank, unit)
        rank = isCallOk and nosecret(rank)
        if rank and type(rank) == "number" and rank >= 5 then
            local rok, rName, rNum = pcall(GetPVPRankInfo, rank, unit)
            if rok and rName and rName ~= "" then
                local rIcon = (rNum and rNum > 0)
                    and format("|TInterface\\PvPRankBadges\\PvPRank%02d:14:14:0:0|t ", rNum)
                    or ""
                parts[#parts + 1] = format("%s|cffEDF4F7%s|r |cffAEE26A(R%d)|r", rIcon, rName, rNum or (rank - 4))
            end
        end
    end
    if C_PlayerInfo and C_PlayerInfo.GetPlayerMythicPlusRatingSummary then
        local isCallOk, apiInfo = pcall(C_PlayerInfo.GetPlayerMythicPlusRatingSummary, unit)
        local score = isCallOk and apiInfo and nosecret(apiInfo.currentSeasonScore)
        if score and type(score) == "number" and score > 0 then
            parts[#parts + 1] = format("|cffF1BD57M+ %d|r", score)
        end
    end
    if #parts > 0 then
        return table.concat(parts, "  ·  ")
    end
    return nil
end

function UnitTacticalOverlay.extractUnitCasting(unit)
    if not unit or not UnitExists(unit) then return nil end
    local displayName, extractSafeTooltipText, texture
    if UnitCastingInfo then
        local isCallOk, nodeEntry, resolvedValue, textureRegion = pcall(UnitCastingInfo, unit)
        if isCallOk then displayName, extractSafeTooltipText, texture = nosecret(nodeEntry), nosecret(resolvedValue), nosecret(textureRegion) end
    end
    if not displayName and UnitChannelInfo then
        local isCallOk, nodeEntry, resolvedValue, textureRegion = pcall(UnitChannelInfo, unit)
        if isCallOk then displayName, extractSafeTooltipText, texture = nosecret(nodeEntry), nosecret(resolvedValue), nosecret(textureRegion) end
    end
    local display = extractSafeTooltipText or displayName
    if display and display ~= "" then
        return format("%s|cffF1BD57%s|r", composeIcon(texture), display)
    end
    return nil
end

function UnitTacticalOverlay.extractUnitThreat(unit)
    if not UnitDetailedThreatSituation or not unit or not UnitExists(unit) or nosecret(UnitIsPlayer(unit)) then
        return nil
    end
    if C_Secrets and C_Secrets.ShouldUnitThreatValuesBeSecret then
        local isCallOk, sec = pcall(C_Secrets.ShouldUnitThreatValuesBeSecret, unit)
        if isCallOk and sec then return nil end
    end
    local isCallOk, hasTanking, statusRegion, scaledPct = pcall(UnitDetailedThreatSituation, "player", unit)
    scaledPct = isCallOk and nosecret(scaledPct)
    if not scaledPct or type(scaledPct) ~= "number" or scaledPct <= 0 then return nil end
    local hasTank = nosecret(hasTanking)
    local stateEntry = nosecret(statusRegion) or 0
    local colorRGB = (stateEntry >= 3 or hasTank) and "EA837E" or ((stateEntry == 2) and "F1BD57" or "AEE26A")
    local suffix = hasTank and format(" |cffEA837E[%s]|r", resolveExtraLocaleText("tanking")) or ""
    return format("|cff%s%d%%|r%s", colorRGB, math.floor(scaledPct + 0.5), suffix)
end

function UnitTacticalOverlay.extractNpcTrackingInfo(guid)
    if not guid or type(guid) ~= "string" then return nil, nil, nil, nil, nil end
    local unitType, _, _, _, zoneUID, npcIDStr, spawnUID = strsplit("-", guid)
    if unitType ~= "Creature" and unitType ~= "Vehicle" then
        return nil, nil, nil, nil, nil
    end
    local npcID = tonumber(npcIDStr)
    local aliveLine, trackLine, notableLine, zoneColLine, hasDungeonLoc

    local aliveParts = {}
    if spawnUID and #spawnUID >= 5 and GetServerTime and bit and bit.band then
        local isCallOk, serverTime = pcall(GetServerTime)
        local spawnHex = tonumber(spawnUID:sub(5), 16)
        if isCallOk and serverTime and spawnHex and spawnHex > 0 then
            local spawnEpoch = (serverTime - (serverTime % 8388608)) + bit.band(spawnHex, 0x7fffff)
            if spawnEpoch > serverTime then
                spawnEpoch = spawnEpoch - 8388607
            end
            local aliveSec = serverTime - spawnEpoch
            if aliveSec >= 0 and aliveSec < 8388607 then
                local durTxt = composeDurationShort(aliveSec)
                if durTxt then
                    aliveParts[#aliveParts + 1] = format("|cffEDF4F7%s|r", durTxt)
                end
            end
        end
    end
    if zoneUID and zoneUID ~= "" and zoneUID ~= "0" then
        aliveParts[#aliveParts + 1] = format("|cff8398A6%s #%s|r", resolveExtraLocaleText("layer"), zoneUID)
    end
    if #aliveParts > 0 then
        aliveLine = table.concat(aliveParts, "  ·  ")
    end

    local rawNpc = npcID and addon.NpcSourceDB and addon.NpcSourceDB[npcID]
    local npcLocKey = nil
    if rawNpc and rawNpc ~= "" then
        local locPart, itemsPart, questsPart = strsplit("|", rawNpc)
        npcLocKey = tonumber((strsplit(":", locPart or "")))
        local trackParts = {}
        local notableNames = {}
        local hasShift = IsShiftKeyDown()
        local maxNotable = hasShift and 5 or 2

        if itemsPart and itemsPart ~= "" then
            local totalCol, doneCol, totalEntries = 0, 0, 0
            for entryStr in itemsPart:gmatch("([^,]+)") do
                local idStr, rateStr = strsplit(":", entryStr)
                local itemIDVal = tonumber(idStr)
                if itemIDVal and itemIDVal > 0 then
                    totalEntries = totalEntries + 1
                    local hasCollected = verifyItemCollectionStatus(itemIDVal, nil, true)
                    if hasCollected ~= nil then
                        totalCol = totalCol + 1
                        if hasCollected then
                            doneCol = doneCol + 1
                        end
                    end
                    if #notableNames < maxNotable and compat.GetItemInfo then
                        local isCallOk, iName, _, iQuality, _, _, _, _, _, _, iTex = pcall(compat.GetItemInfo, itemIDVal)
                        if isCallOk and iName and iName ~= "" then
                            local qHex = (iQuality and ITEM_QUALITY_COLORS and ITEM_QUALITY_COLORS[iQuality] and ITEM_QUALITY_COLORS[iQuality].hex) or "|cffEDF4F7"
                            local rateTxt = (rateStr and rateStr ~= "") and format(" |cff8398A6(%s%%)|r", rateStr) or ""
                            local colMark = (hasCollected == true) and " |cffAEE26A✓|r" or ((hasCollected == false) and " |cffEA837E!|r" or "")
                            notableNames[#notableNames + 1] = format("%s%s[%s]|r%s%s", composeIcon(iTex), qHex, nosecret(iName), rateTxt, colMark)
                        elseif C_Item and C_Item.RequestLoadItemDataByID then
                            pcall(C_Item.RequestLoadItemDataByID, itemIDVal)
                        end
                    end
                end
            end
            if totalCol > 0 then
                local colColor = (doneCol == totalCol) and "AEE26A" or ((doneCol > 0) and "F1BD57" or "EA837E")
                trackParts[#trackParts + 1] = format("|cff%s" .. resolveExtraLocaleText("npcDropsFmt") .. "|r", colColor, doneCol, totalCol)
            end
            if #notableNames > 0 then
                local extraCnt = totalEntries - #notableNames
                local moreTxt = (extraCnt > 0 and not hasShift) and format(" |cff8398A6(+%d Shift)|r", extraCnt) or ((extraCnt > 0) and format(" |cff8398A6(+%d)|r", extraCnt) or "")
                notableLine = table.concat(notableNames, "  ") .. moreTxt
            end
        end

        if questsPart and questsPart ~= "" then
            local totalQ, doneQ = 0, 0
            for qStr in questsPart:gmatch("(%d+)") do
                local questIDVal = tonumber(qStr)
                if questIDVal and questIDVal > 0 then
                    totalQ = totalQ + 1
                    if hasQuestCompleted(questIDVal) then
                        doneQ = doneQ + 1
                    end
                end
            end
            if totalQ > 0 then
                local qColor = (doneQ == totalQ) and "AEE26A" or "F1BD57"
                trackParts[#trackParts + 1] = format("|cff%s" .. resolveExtraLocaleText("npcQuestsFmt") .. "|r", qColor, doneQ, totalQ)
            end
        end

        if #trackParts > 0 then
            trackLine = table.concat(trackParts, "  ·  ")
        end
    end

    if (not npcLocKey or npcLocKey == 0) and C_Map and C_Map.GetBestMapForUnit then
        local okM, mID = pcall(C_Map.GetBestMapForUnit, "player")
        if okM and mID and mID > 0 then npcLocKey = nosecret(mID) end
    end
    if npcLocKey and npcLocKey ~= 0 and (npcLocKey < 0 or IsShiftKeyDown() or trackLine) then
        hasDungeonLoc = (npcLocKey < 0)
        zoneColLine = resolveZoneCollectionSummary(npcLocKey)
    end

    return aliveLine, trackLine, notableLine, zoneColLine, hasDungeonLoc
end

-----------------------------------------------------------------------------
-- Refresh Unit Extras
-----------------------------------------------------------------------------
function UnitTacticalOverlay.refreshUnitExtras(tip, unit, isInspectReady)
    if not tip or tip ~= GameTooltip then return end
    if not unit then
        local isCallOk, _, unitRef = pcall(tip.GetUnit, tip)
        if isCallOk and unitRef and not issecret(unitRef) and UnitExists(unitRef) then unit = unitRef end
    end
    if not unit or not UnitExists(unit) or addon:IsUnitRestricted(unit) then return end

    local hasPlayer = nosecret(UnitIsPlayer(unit))
    local guid = nosecret(UnitGUID(unit))
    local pCfg = addon.db and addon.db.unit and addon.db.unit.player
    local nCfg = addon.db and addon.db.unit and addon.db.unit.npc

    if hasPlayer then
        addon:StripMatchingTooltipLine(tip, NPC_ALIVE_PATTERN)
        addon:StripMatchingTooltipLine(tip, NPC_TRACK_PATTERN)
        addon:StripMatchingTooltipLine(tip, NPC_NOTABLE_PATTERN)
        addon:StripMatchingTooltipLine(tip, "^|cff4BC8E8◆|r|cff000115|r ")

        if not pCfg or pCfg.showItemLevel ~= false then
            local ilvl = UnitTacticalOverlay.extractUnitItemLevel(unit, guid, isInspectReady)
            if ilvl then
                local ilvlLineText = addon:FormatPlayerIlvlAndGearScore(unit, ilvl)
                if ilvlLineText then
                    addon:InsertOrUpdateTooltipLine(tip, ILVL_PATTERN, ilvlLineText)
                end
            end
        else
            addon:StripMatchingTooltipLine(tip, ILVL_PATTERN)
        end

        if not pCfg or pCfg.showMount ~= false then
            local mountText = UnitTacticalOverlay.extractUnitMount(unit)
            if mountText then
                addon:InsertOrUpdateTooltipLine(tip, MOUNT_PATTERN,
                    format("%s|cffA7B9C5%s:|r %s", MOUNT_PREFIX_TAG, resolveExtraLocaleText("mount"), mountText))
            else
                addon:StripMatchingTooltipLine(tip, MOUNT_PATTERN)
            end
        else
            addon:StripMatchingTooltipLine(tip, MOUNT_PATTERN)
        end

        if not pCfg or pCfg.showRoleAndScore ~= false then
            local scoreText = UnitTacticalOverlay.extractUnitPvPAndScore(unit)
            if scoreText then
                addon:InsertOrUpdateTooltipLine(tip, SCORE_PATTERN,
                    format("%s|cffA7B9C5%s:|r %s", SCORE_PREFIX_TAG, resolveExtraLocaleText("pvpRank"), scoreText))
            else
                addon:StripMatchingTooltipLine(tip, SCORE_PATTERN)
            end
        else
            addon:StripMatchingTooltipLine(tip, SCORE_PATTERN)
        end
    else
        
        if guid and type(guid) == "string" then
            local npcIDStr = select(6, strsplit("-", guid))
            appendDualNameToTitle(tip, "npc", tonumber(npcIDStr))
        end

        if not nCfg or nCfg.showNpcTracking ~= false then
            local aliveLine, trackLine, notableLine, zoneColLine, hasDungeonLoc = UnitTacticalOverlay.extractNpcTrackingInfo(guid)
            if aliveLine then
                addon:InsertOrUpdateTooltipLine(tip, NPC_ALIVE_PATTERN,
                    format("%s|cffA7B9C5%s:|r %s", NPC_ALIVE_TAG, resolveExtraLocaleText("npcAlive"), aliveLine))
            else
                addon:StripMatchingTooltipLine(tip, NPC_ALIVE_PATTERN)
            end
            if trackLine then
                addon:InsertOrUpdateTooltipLine(tip, NPC_TRACK_PATTERN,
                    format("%s|cffA7B9C5%s:|r %s", NPC_TRACK_TAG, resolveExtraLocaleText("npcTrack"), trackLine))
            else
                addon:StripMatchingTooltipLine(tip, NPC_TRACK_PATTERN)
            end
            if notableLine then
                addon:InsertOrUpdateTooltipLine(tip, NPC_NOTABLE_PATTERN,
                    format("%s|cffA7B9C5%s:|r %s", NPC_NOTABLE_TAG, resolveExtraLocaleText("npcNotable"), notableLine))
            else
                addon:StripMatchingTooltipLine(tip, NPC_NOTABLE_PATTERN)
            end
            if zoneColLine then
                local zLabel = hasDungeonLoc and resolveExtraLocaleText("instCollect") or resolveExtraLocaleText("zoneCollect")
                addon:InsertOrUpdateTooltipLine(tip, "^|cff4BC8E8◆|r|cff000115|r ",
                    format("|cff4BC8E8◆|r|cff000115|r |cffA7B9C5%s:|r %s", zLabel, zoneColLine))
            else
                addon:StripMatchingTooltipLine(tip, "^|cff4BC8E8◆|r|cff000115|r ")
            end
        else
            addon:StripMatchingTooltipLine(tip, NPC_ALIVE_PATTERN)
            addon:StripMatchingTooltipLine(tip, NPC_TRACK_PATTERN)
            addon:StripMatchingTooltipLine(tip, NPC_NOTABLE_PATTERN)
            addon:StripMatchingTooltipLine(tip, "^|cff4BC8E8◆|r|cff000115|r ")
        end
    end

    local presentSpeed = hasPlayer and (not pCfg or pCfg.showSpeed ~= false) or (not hasPlayer and (not nCfg or nCfg.showSpeed ~= false))
    if presentSpeed then
        local speedText = UnitTacticalOverlay.extractUnitMoveSpeed(unit)
        if speedText then
            addon:InsertOrUpdateTooltipLine(tip, SPEED_PATTERN,
                format("%s|cffA7B9C5%s:|r %s", SPEED_PREFIX_TAG, resolveExtraLocaleText("speed"), speedText))
        else
            addon:StripMatchingTooltipLine(tip, SPEED_PATTERN)
        end
    else
        addon:StripMatchingTooltipLine(tip, SPEED_PATTERN)
    end

    local presentCast = hasPlayer and (not pCfg or pCfg.showCastAndThreat ~= false) or (not hasPlayer and (not nCfg or nCfg.showCastAndThreat ~= false))
    if presentCast then
        local castText = UnitTacticalOverlay.extractUnitCasting(unit)
        if castText then
            addon:InsertOrUpdateTooltipLine(tip, CAST_PATTERN,
                format("%s|cffA7B9C5%s:|r %s", CAST_PREFIX_TAG, resolveExtraLocaleText("casting"), castText))
        else
            addon:StripMatchingTooltipLine(tip, CAST_PATTERN)
        end
        if not hasPlayer then
            local threatText = UnitTacticalOverlay.extractUnitThreat(unit)
            if threatText then
                addon:InsertOrUpdateTooltipLine(tip, THREAT_PATTERN,
                    format("%s|cffA7B9C5%s:|r %s", THREAT_PREFIX_TAG, resolveExtraLocaleText("threat"), threatText))
            else
                addon:StripMatchingTooltipLine(tip, THREAT_PATTERN)
            end
        end
    else
        addon:StripMatchingTooltipLine(tip, CAST_PATTERN)
        addon:StripMatchingTooltipLine(tip, THREAT_PATTERN)
    end

    addon.SanitizeUnitTooltipTextLines(tip)
end

EventDispatcher:attachTrigger("tooltip:unit", function(self, tip, unit)
    UnitTacticalOverlay.refreshUnitExtras(tip, unit, false)
end)

local inspectFrame = CreateFrame("Frame")
inspectFrame:RegisterEvent("INSPECT_READY")
inspectFrame:SetScript("OnEvent", function(self, event, arg1)
    local guid = nosecret(arg1)
    if guid then
        local rUnit = UnitTacticalOverlay.determineUnitByGUID(guid)
        if rUnit and UnitExists(rUnit) then
            UnitTacticalOverlay.extractUnitItemLevel(rUnit, guid, true)
        end
    end
    if not GameTooltip:IsShown() then return end
    local isCallOk, _, unit = pcall(GameTooltip.GetUnit, GameTooltip)
    if isCallOk and unit and not issecret(unit) and UnitExists(unit) then
        local uGuid = nosecret(UnitGUID(unit))
        if not guid or uGuid == guid then
            UnitTacticalOverlay.refreshUnitExtras(GameTooltip, unit, true)
            pcall(GameTooltip.Show, GameTooltip)
        end
    end
end)

GameTooltip:HookScript("OnUpdate", function(self, elapsed)
    self._eztExtrasElapsed = (self._eztExtrasElapsed or 0) + elapsed
    if self._eztExtrasElapsed < 0.35 then return end
    self._eztExtrasElapsed = 0
    if not self.ezWoWTooltipUnitRows then return end
    local isCallOk, _, unit = pcall(self.GetUnit, self)
    if not isCallOk or not unit or issecret(unit) or not UnitExists(unit) then return end
    -- Only refresh dynamic live lines (speed, casting, threat) on periodic tick to avoid layout churn
    local hasPlayer = nosecret(UnitIsPlayer(unit))
    local pCfg = addon.db and addon.db.unit and addon.db.unit.player
    local nCfg = addon.db and addon.db.unit and addon.db.unit.npc
    local changed = false
    local presentSpeed = hasPlayer and (not pCfg or pCfg.showSpeed ~= false) or (not hasPlayer and (not nCfg or nCfg.showSpeed ~= false))
    if presentSpeed then
        local speedText = UnitTacticalOverlay.extractUnitMoveSpeed(unit)
        if speedText then
            local _, ch = addon:InsertOrUpdateTooltipLine(self, SPEED_PATTERN,
                format("%s|cffA7B9C5%s:|r %s", SPEED_PREFIX_TAG, resolveExtraLocaleText("speed"), speedText))
            if ch then changed = true end
        elseif addon:StripMatchingTooltipLine(self, SPEED_PATTERN) then
            changed = true
        end
    end
    local presentCast = hasPlayer and (not pCfg or pCfg.showCastAndThreat ~= false) or (not hasPlayer and (not nCfg or nCfg.showCastAndThreat ~= false))
    if presentCast then
        local castText = UnitTacticalOverlay.extractUnitCasting(unit)
        if castText then
            local _, ch = addon:InsertOrUpdateTooltipLine(self, CAST_PATTERN,
                format("%s|cffA7B9C5%s:|r %s", CAST_PREFIX_TAG, resolveExtraLocaleText("casting"), castText))
            if ch then changed = true end
        elseif addon:StripMatchingTooltipLine(self, CAST_PATTERN) then
            changed = true
        end
        if not hasPlayer then
            local threatText = UnitTacticalOverlay.extractUnitThreat(unit)
            if threatText then
                local _, ch = addon:InsertOrUpdateTooltipLine(self, THREAT_PATTERN,
                    format("%s|cffA7B9C5%s:|r %s", THREAT_PREFIX_TAG, resolveExtraLocaleText("threat"), threatText))
                if ch then changed = true end
            elseif addon:StripMatchingTooltipLine(self, THREAT_PATTERN) then
                changed = true
            end
        end
    end
    if changed then
        addon.SanitizeUnitTooltipTextLines(self)
        if self:IsShown() then pcall(self.Show, self) end
    end
end)
