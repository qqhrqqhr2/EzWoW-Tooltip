--===========================================================================
-- EzWoW - Tooltip
-- Modules/SourceAndCollection.lua : Item Drop Source, Recipe, Reagent & Zone Collection Enricher
--===========================================================================
local _, ns = ...
local type, pairs, ipairs, tonumber, tostring, select, pcall = type, pairs, ipairs, tonumber, tostring, select, pcall
local DropSourceInspector = ns.DropSourceInspector or {}
ns.DropSourceInspector = DropSourceInspector
local EventDispatcher = ns.events
local addon = EzWoW_Tooltip
local compat = select(2, ...).compat
local issecret = compat.issecret
local nosecret = compat.nosecret
local format = string.format
local resolveActiveLocale = addon.GetActiveLocale
local resolveExtraLocaleText = addon.EL
local composeIcon = addon.FormatIcon

-----------------------------------------------------------------------------
-- Insert Or Update Tooltip Line
-----------------------------------------------------------------------------
function addon:InsertOrUpdateTooltipLine(tip, prefixPattern, fullText)
    if not tip or not fullText then return nil, false end
    local existing = self:FindLine(tip, prefixPattern)
    if existing then
        if nosecret(existing:GetText()) ~= fullText then
            existing:SetText(fullText)
            existing:Show()
            return existing, true
        end
        return existing, false
    end
    local displayName = tip:GetName()
    if displayName then
        local startRow = (tip.ezWoWTooltipUnitRows or 2) + 1
        for index = startRow, tip:NumLines() do
            local left = _G[displayName .. "TextLeft" .. index]
            local right = _G[displayName .. "TextRight" .. index]
            local lText = left and nosecret(left:GetText())
            local rText = right and nosecret(right:GetText())
            if left and (not lText or lText == "" or lText == " ") and (not rText or rText == "" or rText == " ") then
                left:SetText(fullText)
                left:Show()
                if right then
                    right:SetText(nil)
                    right:Hide()
                end
                return left
            end
        end
    end
    tip:AddLine(fullText)
end

function addon:StripMatchingTooltipLine(tip, prefixPattern)
    if not tip then return false end
    local line, _, right = self:FindLine(tip, prefixPattern)
    if line then
        line:SetText(nil)
        if right then
            right:SetText(nil)
            right:Hide()
        end
        return true
    end
    return false
end

local ILVL_PREFIX_TAG      = "|cff4BC8E8◆|r|cff000101|r "
local MOUNT_PREFIX_TAG     = "|cff4BC8E8◆|r|cff000102|r "
local SPEED_PREFIX_TAG     = "|cff4BC8E8◆|r|cff000103|r "
local SCORE_PREFIX_TAG     = "|cff4BC8E8◆|r|cff000104|r "
local CAST_PREFIX_TAG      = "|cff4BC8E8◆|r|cff000105|r "
local THREAT_PREFIX_TAG    = "|cff4BC8E8◆|r|cff000106|r "
local NPC_ALIVE_TAG        = "|cff4BC8E8◆|r|cff00010b|r "
local NPC_TRACK_TAG        = "|cff4BC8E8◆|r|cff00010c|r "
local NPC_NOTABLE_TAG      = "|cff4BC8E8◆|r|cff00010d|r "

local ILVL_PATTERN         = "^|cff4BC8E8◆|r|cff000101|r "
local MOUNT_PATTERN        = "^|cff4BC8E8◆|r|cff000102|r "
local SPEED_PATTERN        = "^|cff4BC8E8◆|r|cff000103|r "
local SCORE_PATTERN        = "^|cff4BC8E8◆|r|cff000104|r "
local CAST_PATTERN         = "^|cff4BC8E8◆|r|cff000105|r "
local THREAT_PATTERN       = "^|cff4BC8E8◆|r|cff000106|r "
local NPC_ALIVE_PATTERN    = "^|cff4BC8E8◆|r|cff00010b|r "
local NPC_TRACK_PATTERN    = "^|cff4BC8E8◆|r|cff00010c|r "
local NPC_NOTABLE_PATTERN  = "^|cff4BC8E8◆|r|cff00010d|r "

function DropSourceInspector.cleanColors(text)
    if not text then return "" end
    return strtrim((text:gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", "")))
end

function DropSourceInspector.hasForeignIlvlLabel(plainLeft)
    if not plainLeft or plainLeft == "" then return false end
    local lower = string.lower(plainLeft)
    return plainLeft:find("아이템 레벨", 1, true)
        or lower:find("^item level")
        or lower:find("^gegenstandsstufe")
        or lower:find("^niveau d'objet")
        or lower:find("^nivel de objeto")
        or plainLeft:find("Уровень предмет", 1, true)
        or plainLeft:find("物品等级", 1, true)
        or plainLeft:find("物品等級", 1, true)
end

function DropSourceInspector.hasForeignCompletionistLine(plainLeft, plainRight)
    if not plainLeft then return false end
    if plainLeft:find("Completionist", 1, true) or plainLeft:find("완벽주의자", 1, true) or plainLeft:find("完美主义", 1, true) or plainLeft:find("完美主義", 1, true) then
        return true
    end
    if plainRight and plainRight:match("^%d+%s*/%s*%d+%s*%([%d%.]+%%%)$") then
        return true
    end
    return false
end

function addon.SanitizeUnitTooltipTextLines(tip)
    if not tip or tip._eztNormalizing then return end
    local displayName = tip:GetName()
    if not displayName then return end
    tip._eztNormalizing = true

    local playerCfg = addon.db and addon.db.unit and addon.db.unit.player
    local presentIlvl = not playerCfg or (playerCfg.showItemLevel ~= false)
    local dismissComp = not playerCfg or (playerCfg.hideCompletionist ~= false)

    local numLines = tip:NumLines() or 0
    local ourIlvlLine = addon:FindLine(tip, ILVL_PATTERN)

    for index = 2, numLines do
        local left = _G[displayName .. "TextLeft" .. index]
        local right = _G[displayName .. "TextRight" .. index]
        local lText = left and nosecret(left:GetText())
        local rText = right and right:IsShown() and nosecret(right:GetText())

        if lText and lText ~= "" then
            local plainL = DropSourceInspector.cleanColors(lText)
            local plainR = rText and DropSourceInspector.cleanColors(rText) or nil

            if dismissComp and DropSourceInspector.hasForeignCompletionistLine(plainL, plainR) then
                left:SetText(nil)
                if right then right:SetText(nil); right:Hide() end

            elseif not lText:find(ILVL_PATTERN) and DropSourceInspector.hasForeignIlvlLabel(plainL) then
                if not presentIlvl then
                    left:SetText(nil)
                    if right then right:SetText(nil); right:Hide() end
                else
                    local rawNum = tonumber((plainR and plainR:match("(%d+%.?%d*)")) or plainL:match("(%d+%.?%d*)"))
                    if ourIlvlLine and ourIlvlLine ~= left then
                        -- Keep our own decimal ilvl + (GearScore) line and remove the duplicate native line
                        left:SetText(nil)
                    elseif rawNum and rawNum > 0 then
                        local _, tipUnit = tip:GetUnit()
                        local formatted = (addon.FormatPlayerIlvlAndGearScore and addon:FormatPlayerIlvlAndGearScore(tipUnit, rawNum))
                            or format("%s|cffA7B9C5%s:|r |cffEDF4F7%.1f|r", ILVL_PREFIX_TAG, resolveExtraLocaleText("ilvl"), rawNum)
                        left:SetText(formatted)
                        ourIlvlLine = left
                    end
                    if right then right:SetText(nil); right:Hide() end
                end

            elseif rText and rText ~= "" and rText ~= " " then
                if plainL == "Mount:" or plainL == "탈것:" then
                    if addon:FindLine(tip, MOUNT_PATTERN) then
                        left:SetText(nil)
                    else
                        left:SetText(format("%s|cffA7B9C5%s:|r |cffEDF4F7%s|r", MOUNT_PREFIX_TAG, resolveExtraLocaleText("mount"), rText))
                    end
                    right:SetText(nil); right:Hide()
                elseif plainL == "M+ Score:" or plainL == "쐐기 점수:" then
                    if addon:FindLine(tip, SCORE_PATTERN) then
                        left:SetText(nil)
                    else
                        left:SetText(format("%s|cffA7B9C5%s:|r %s", SCORE_PREFIX_TAG, resolveExtraLocaleText("mythicScore"), rText))
                    end
                    right:SetText(nil); right:Hide()
                else
                    left:SetText(format("%s  %s", lText, rText))
                    right:SetText(nil); right:Hide()
                end
            end
        end
    end

    local writeIdx = 2
    for extractIdx = 2, numLines do
        local rLeft = _G[displayName .. "TextLeft" .. extractIdx]
        local rRight = _G[displayName .. "TextRight" .. extractIdx]
        local lText = rLeft and nosecret(rLeft:GetText())
        local rText = rRight and rRight:IsShown() and nosecret(rRight:GetText())
        local containsContent = (lText and lText ~= "" and lText ~= " ") or (rText and rText ~= "" and rText ~= " ")
        if containsContent then
            if writeIdx ~= extractIdx then
                local wLeft = _G[displayName .. "TextLeft" .. writeIdx]
                local wRight = _G[displayName .. "TextRight" .. writeIdx]
                if wLeft and rLeft then
                    local lrVal, lgVal, lbVal = rLeft:GetTextColor()
                    wLeft:SetText(lText)
                    wLeft:SetTextColor(lrVal or 1, lgVal or 1, lbVal or 1)
                    wLeft:Show()
                    rLeft:SetText(nil)
                end
                if wRight then
                    if rText and rText ~= "" then
                        local rrVal, rgVal, rbVal = rRight:GetTextColor()
                        wRight:SetText(rText)
                        wRight:SetTextColor(rrVal or 1, rgVal or 1, rbVal or 1)
                        wRight:Show()
                    else
                        wRight:SetText(nil)
                        wRight:Hide()
                    end
                end
                if rRight then
                    rRight:SetText(nil)
                    rRight:Hide()
                end
            end
            writeIdx = writeIdx + 1
        else
            if rLeft then rLeft:SetText(nil) end
            if rRight then rRight:SetText(nil); rRight:Hide() end
        end
    end

    tip._eztNormalizing = nil
end

local npcNameCache = {}
local questNameCache = {}
local mapNameCache = {}

local SKILL_TO_SPELL = {
    [129] = 3273,  
    [164] = 2018,  
    [165] = 2108,  
    [171] = 2259,  
    [182] = 2366,  
    [185] = 2550,  
    [186] = 2575,  
    [197] = 3908,  
    [202] = 4036,  
    [333] = 7411,  
    [356] = 7620,  
    [393] = 8613,  
    [633] = 1809,  
    [9787] = 9787, 
    [9788] = 9788, 
    [10656] = 10656,
    [10658] = 10658,
    [10660] = 10660,
    [17039] = 17039,
    [17040] = 17040,
    [17041] = 17041,
    [20219] = 20219,
    [20222] = 20222,
}

local PROF_FALLBACK_KO = {
    [129] = "응급치료", [164] = "대장기술", [165] = "가죽세공", [171] = "연금술",
    [182] = "약초채집", [185] = "요리", [186] = "채광", [197] = "재봉술",
    [202] = "기계공학", [333] = "마법부여", [356] = "낚시", [393] = "무두질",
}

local HOLIDAY_NAMES_KO = {
    [-37]  = "다크문 축제",
    [-559] = "어린이 주간",
    [-574] = "겨울맞이 축제",
    [-576] = "할로윈 축제",
    [-577] = "추수절",
    [-579] = "온누리에 사랑을",
    [-580] = "달의 축제",
    [-582] = "한여름 불꽃축제",
    [-583] = "귀족의 정원",
    [-588] = "가시덤불 골짜기 낚시왕 대회",
}

local HOLIDAY_NAMES_EN = {
    [-37]  = "Darkmoon Faire",
    [-559] = "Children's Week",
    [-574] = "Feast of Winter Veil",
    [-576] = "Hallow's End",
    [-577] = "Harvest Festival",
    [-579] = "Love is in the Air",
    [-580] = "Lunar Festival",
    [-582] = "Midsummer Fire Festival",
    [-583] = "Noblegarden",
    [-588] = "Stranglethorn Fishing Extravaganza",
}

local npcScanTip

function DropSourceInspector.determineLocationName(locID)
    locID = tonumber(locID)
    if not locID or locID == 0 then return nil end
    if mapNameCache[locID] then return mapNameCache[locID] end

    local displayName, databaseFallback
    if locID < 0 then
        local instID = -locID
        local instEntry = addon.InstanceMapDB and addon.InstanceMapDB[instID]
        if not displayName and EJ_GetInstanceInfo then
            local isCallOk, nodeEntry = pcall(EJ_GetInstanceInfo, instID)
            if isCallOk and nodeEntry and nodeEntry ~= "" then displayName = nosecret(nodeEntry) end
        end
        if not displayName and instEntry then
            local mapID, areaID, koName, enName = instEntry[1], instEntry[2], instEntry[3], instEntry[4]
            if mapID and mapID > 0 and C_Map and C_Map.GetMapInfo then
                local isCallOk, apiInfo = pcall(C_Map.GetMapInfo, mapID)
                if isCallOk and apiInfo and apiInfo.name and apiInfo.name ~= "" then
                    displayName = nosecret(apiInfo.name)
                end
            end
            if not displayName and areaID and areaID > 0 and C_Map and C_Map.GetAreaInfo then
                local isCallOk, aName = pcall(C_Map.GetAreaInfo, areaID)
                if isCallOk and aName and aName ~= "" then
                    displayName = nosecret(aName)
                end
            end
            if not displayName then
                local knownName = resolveActiveLocale() == "koKR" and koName or enName
                databaseFallback = (knownName and knownName ~= "" and knownName) or nil
            end
        end
    else
        if C_Map and C_Map.GetMapInfo then
            local isCallOk, apiInfo = pcall(C_Map.GetMapInfo, locID)
            if isCallOk and apiInfo and apiInfo.name and apiInfo.name ~= "" then
                displayName = nosecret(apiInfo.name)
            end
        end
        if not displayName and C_Map and C_Map.GetAreaInfo then
            local isCallOk, aName = pcall(C_Map.GetAreaInfo, locID)
            if isCallOk and aName and aName ~= "" then
                displayName = nosecret(aName)
            end
        end
    end

    if displayName and displayName ~= "" then
        mapNameCache[locID] = displayName
        return displayName
    end
    return databaseFallback
end

function DropSourceInspector.hasValidResolvedName(text)
    if not text or type(text) ~= "string" or text == "" or text == UNKNOWN then return false end
    if text:find("Retrieving", 1, true) or text:find("불러오는", 1, true) or text:find("^NPC #") then return false end
    return true
end

local queryItemCountAPI = (C_Item and C_Item.GetItemCount) or GetItemCount

function DropSourceInspector.determineNpcName(npcID)
    npcID = tonumber(npcID)
    if not npcID or npcID <= 0 then return nil end
    if npcNameCache[npcID] then return npcNameCache[npcID] end

    local unitLink = format("unit:Creature-0-0-0-0-%d-0000000000", npcID)
    if C_TooltipInfo and C_TooltipInfo.GetHyperlink then
        local isCallOk, payloadData = pcall(C_TooltipInfo.GetHyperlink, unitLink)
        if isCallOk and payloadData and payloadData.lines and payloadData.lines[1] then
            local leftText = nosecret(payloadData.lines[1].leftText)
            if DropSourceInspector.hasValidResolvedName(leftText) then
                npcNameCache[npcID] = leftText
                return leftText
            end
        end
    end

    if not npcScanTip then
        npcScanTip = CreateFrame("GameTooltip", "EzWoWTooltipNPCHarvester", UIParent, "GameTooltipTemplate")
    end
    local okScan = pcall(function()
        npcScanTip:SetOwner(UIParent, "ANCHOR_NONE")
        npcScanTip:SetHyperlink(unitLink)
    end)
    if okScan then
        local line1 = _G["EzWoWTooltipNPCHarvesterTextLeft1"]
        local titleStr = line1 and nosecret(line1:GetText())
        npcScanTip:Hide()
        if DropSourceInspector.hasValidResolvedName(titleStr) then
            npcNameCache[npcID] = titleStr
            return titleStr
        end
    end

    if resolveActiveLocale() == "koKR" and addon.NpcNameDB_koKR and addon.NpcNameDB_koKR[npcID] then
        return addon.NpcNameDB_koKR[npcID]
    end
    if addon.NpcNameDB_enUS and addon.NpcNameDB_enUS[npcID] then
        return addon.NpcNameDB_enUS[npcID]
    end
    return format("NPC #%d", npcID)
end

function DropSourceInspector.determineObjectName(objID)
    objID = tonumber(objID)
    if not objID or objID <= 0 then return nil end
    local userPref = resolveActiveLocale()
    if userPref == "koKR" and addon.ObjectNameDB_koKR and addon.ObjectNameDB_koKR[objID] then
        return addon.ObjectNameDB_koKR[objID]
    end
    if addon.ObjectNameDB_enUS and addon.ObjectNameDB_enUS[objID] then
        return addon.ObjectNameDB_enUS[objID]
    end
    if addon.ObjectNameDB_koKR and addon.ObjectNameDB_koKR[objID] then
        return addon.ObjectNameDB_koKR[objID]
    end
    return format("Object #%d", objID)
end

function DropSourceInspector.determineQuestName(questID)
    questID = tonumber(questID)
    if not questID or questID <= 0 then return nil end
    if questNameCache[questID] then return questNameCache[questID] end

    local titleStr
    if C_QuestLog and C_QuestLog.GetTitleForQuestID then
        local isCallOk, resolvedValue = pcall(C_QuestLog.GetTitleForQuestID, questID)
        if isCallOk and resolvedValue and resolvedValue ~= "" then titleStr = nosecret(resolvedValue) end
    end
    if not titleStr and QuestUtils_GetQuestName then
        local isCallOk, resolvedValue = pcall(QuestUtils_GetQuestName, questID)
        if isCallOk and resolvedValue and resolvedValue ~= "" then titleStr = nosecret(resolvedValue) end
    end
    if not titleStr and C_TooltipInfo and C_TooltipInfo.GetHyperlink then
        local isCallOk, payloadData = pcall(C_TooltipInfo.GetHyperlink, "quest:" .. questID)
        if isCallOk and payloadData and payloadData.lines and payloadData.lines[1] then
            local resolvedValue = nosecret(payloadData.lines[1].leftText)
            if resolvedValue and resolvedValue ~= "" and not resolvedValue:find("Retrieving", 1, true) then
                titleStr = resolvedValue
            end
        end
    end
    if titleStr and titleStr ~= "" then
        questNameCache[questID] = titleStr
        return titleStr
    end
    -- Do not cache database fallbacks: the client may load its title later.
    return (resolveActiveLocale() == "koKR" and addon.QuestNameDB_koKR and addon.QuestNameDB_koKR[questID])
        or (addon.QuestNameDB_enUS and addon.QuestNameDB_enUS[questID])
        or format("#%d", questID)
end

function DropSourceInspector.determineReagentName(itemID)
    itemID = tonumber(itemID)
    if not itemID or itemID <= 0 then return nil end
    if compat.GetItemInfo then
        local isCallOk, iName = pcall(compat.GetItemInfo, itemID)
        if isCallOk and iName and iName ~= "" then return nosecret(iName) end
    end
    if C_Item and C_Item.RequestLoadItemDataByID then
        pcall(C_Item.RequestLoadItemDataByID, itemID)
    end
    return (resolveActiveLocale() == "koKR" and addon.ReagentNameDB_koKR and addon.ReagentNameDB_koKR[itemID])
        or (addon.ReagentNameDB_enUS and addon.ReagentNameDB_enUS[itemID])
        or format("#%d", itemID)
end

function DropSourceInspector.determineProfessionName(profID)
    profID = tonumber(profID)
    if not profID or profID <= 0 then return nil end
    local spellID = SKILL_TO_SPELL[profID] or profID
    if C_Spell and C_Spell.GetSpellName then
        local isCallOk, displayName = pcall(C_Spell.GetSpellName, spellID)
        if isCallOk and displayName and displayName ~= "" then return nosecret(displayName) end
    end
    if GetSpellInfo then
        local isCallOk, displayName = pcall(GetSpellInfo, spellID)
        if isCallOk and displayName and displayName ~= "" then return nosecret(displayName) end
    end
    return PROF_FALLBACK_KO[profID] or format("Skill #%d", profID)
end

function DropSourceInspector.hasQuestCompleted(questID)
    questID = tonumber(questID)
    if not questID or questID <= 0 then return false end
    if C_QuestLog and C_QuestLog.IsQuestFlaggedCompleted then
        local isCallOk, done = pcall(C_QuestLog.IsQuestFlaggedCompleted, questID)
        if isCallOk and nosecret(done) then return true end
    elseif IsQuestFlaggedCompleted then
        local isCallOk, done = pcall(IsQuestFlaggedCompleted, questID)
        if isCallOk and nosecret(done) then return true end
    end
    return false
end

function DropSourceInspector.hasRecipeSpellLearned(spellID)
    spellID = tonumber(spellID)
    if not spellID or spellID <= 0 then return false end
    if IsPlayerSpell then
        local isCallOk, entryKey = pcall(IsPlayerSpell, spellID)
        if isCallOk and nosecret(entryKey) then return true end
    end
    if IsSpellKnown then
        local isCallOk, entryKey = pcall(IsSpellKnown, spellID)
        if isCallOk and nosecret(entryKey) then return true end
    end
    if C_SpellBook and C_SpellBook.IsSpellKnown then
        local isCallOk, entryKey = pcall(C_SpellBook.IsSpellKnown, spellID)
        if isCallOk and nosecret(entryKey) then return true end
    end
    if C_TradeSkillUI and C_TradeSkillUI.GetRecipeInfo then
        local isCallOk, apiInfo = pcall(C_TradeSkillUI.GetRecipeInfo, spellID)
        if isCallOk and apiInfo and nosecret(apiInfo.learned) then return true end
    end
    return false
end

-----------------------------------------------------------------------------
-- Title Case English
-----------------------------------------------------------------------------
local dualTitleReverse
local emfEnIndex

function DropSourceInspector.titleCaseEnglish(s)
    if not s or s == "" then return s end
    local small = { a=true, an=true, the=true, of=true, ["in"]=true, on=true, to=true, ["for"]=true, ["and"]=true, by=true, with=true, from=true, at=true }
    local entryIndex = 0
    return (s:gsub("([%w']+)", function(w)
        entryIndex = entryIndex + 1
        local lwVal = w:lower()
        if entryIndex > 1 and small[lwVal] then return lwVal end
        return lwVal:sub(1, 1):upper() .. lwVal:sub(2)
    end))
end

function DropSourceInspector.resolveDualTitleReverse()
    if dualTitleReverse then return dualTitleReverse end
    dualTitleReverse = {}
    if addon.DualNameTitleDB then
        for enLower, koStr in pairs(addon.DualNameTitleDB) do
            if koStr and koStr ~= "" and not dualTitleReverse[koStr] then
                dualTitleReverse[koStr] = DropSourceInspector.titleCaseEnglish(enLower)
            end
        end
    end
    return dualTitleReverse
end

function DropSourceInspector.resolveEmfEnglishName(kind, id)
    if not id or not _G.EzWoWMapFinderData then return nil end
    if not emfEnIndex then
        emfEnIndex = { item = {}, npc = {}, quest = {}, object = {} }
        for _, recordItem in ipairs(_G.EzWoWMapFinderData) do
            if recordItem and recordItem.id and recordItem.kind and recordItem.names and recordItem.names.enUS and emfEnIndex[recordItem.kind] then
                emfEnIndex[recordItem.kind][recordItem.id] = recordItem.names.enUS
            end
        end
    end
    return emfEnIndex[kind] and emfEnIndex[kind][id]
end

function DropSourceInspector.containsHangul(s)
    return s and s:find("[\234-\237][\128-\191][\128-\191]") ~= nil
end

function DropSourceInspector.appendDualNameToTitle(tip, kind, id)
    local iCfg = addon.db and addon.db.item
    if iCfg and iCfg.showDualName == false then return end
    if not tip then return end
    local line1 = addon:GetLine(tip, 1)
    if not line1 then return end
    local rawTitle = nosecret(line1:GetText())
    if not rawTitle or rawTitle == "" then return end
    if rawTitle:find("|cff9EB0BC(", 1, true) then return end

    local clean = rawTitle
        :gsub("|T.-|t%s*", "")
        :gsub("|c%x%x%x%x%x%x%x%x", "")
        :gsub("|r", "")
        :gsub("%s*%[×%d+%]$", "")
        :gsub("^%s+", "")
        :gsub("%s+$", "")
    if clean == "" then return end

    id = tonumber(id)
    local koName, enName
    local emfKo = _G.EzWoWMapFinderTranslations and _G.EzWoWMapFinderTranslations.koKR

    if kind == "item" and id then
        koName = (addon.ReagentNameDB_koKR and addon.ReagentNameDB_koKR[id]) or (emfKo and emfKo.item and emfKo.item[id])
        enName = (addon.ReagentNameDB_enUS and addon.ReagentNameDB_enUS[id]) or DropSourceInspector.resolveEmfEnglishName("item", id)
    elseif kind == "spell" and id then
        koName = addon.SpellNameDB_koKR and addon.SpellNameDB_koKR[id]
        enName = addon.SpellNameDB_enUS and addon.SpellNameDB_enUS[id]
    elseif kind == "npc" and id then
        koName = (addon.NpcNameDB_koKR and addon.NpcNameDB_koKR[id]) or (emfKo and emfKo.npc and emfKo.npc[id])
        enName = (addon.NpcNameDB_enUS and addon.NpcNameDB_enUS[id]) or DropSourceInspector.resolveEmfEnglishName("npc", id)
    elseif kind == "quest" and id then
        koName = (addon.QuestNameDB_koKR and addon.QuestNameDB_koKR[id]) or (emfKo and emfKo.quest and emfKo.quest[id])
        enName = (addon.QuestNameDB_enUS and addon.QuestNameDB_enUS[id]) or DropSourceInspector.resolveEmfEnglishName("quest", id)
    end

    if not koName and addon.DualNameTitleDB then
        koName = addon.DualNameTitleDB[clean:lower()]
    end
    if not enName then
        local rev = DropSourceInspector.resolveDualTitleReverse()
        enName = rev and rev[clean]
    end

    local altName = DropSourceInspector.containsHangul(clean) and enName or koName
    if altName and altName ~= "" and altName:lower() ~= clean:lower() and not rawTitle:find(altName, 1, true) then
        line1:SetText(format("%s |cff9EB0BC(%s)|r", rawTitle, altName))
    end
end

-----------------------------------------------------------------------------
-- Verify Item Collection Status
-----------------------------------------------------------------------------
function DropSourceInspector.verifyItemCollectionStatus(itemID, itemLink, isZoneCheck)
    if not itemID then return nil, nil end
    local linkOrID = itemLink or itemID

    local mountSpell = addon.MountItemDB and addon.MountItemDB[itemID]
    local mountID = (C_MountJournal and C_MountJournal.GetMountFromItem) and select(2, pcall(C_MountJournal.GetMountFromItem, itemID))
    if not mountID and mountSpell and C_MountJournal and C_MountJournal.GetMountFromSpell then
        local isCallOk, mID = pcall(C_MountJournal.GetMountFromSpell, mountSpell)
        if isCallOk then mountID = nosecret(mID) end
    end
    if mountID and mountID > 0 and C_MountJournal and C_MountJournal.GetMountInfoByID then
        local isCallOk, _, _, _, _, _, _, _, _, _, _, hasCollected = pcall(C_MountJournal.GetMountInfoByID, mountID)
        if isCallOk then
            local columnIndex = nosecret(hasCollected)
            return columnIndex and true or false, columnIndex and format("|cffAEE26A[%s]|r", resolveExtraLocaleText("mountDone")) or format("|cffEA837E[%s]|r", resolveExtraLocaleText("mountMiss"))
        end
    end

    local hasToy2 = (addon.ToyItemDB and addon.ToyItemDB[itemID]) or (C_ToyBox and C_ToyBox.GetToyInfo and select(2, pcall(C_ToyBox.GetToyInfo, itemID)) ~= nil)
    if hasToy2 and PlayerHasToy then
        local isCallOk, containsToy = pcall(PlayerHasToy, itemID)
        if isCallOk then
            local columnIndex = nosecret(containsToy)
            return columnIndex and true or false, columnIndex and format("|cffAEE26A[%s]|r", resolveExtraLocaleText("toyDone")) or format("|cffEA837E[%s]|r", resolveExtraLocaleText("toyMiss"))
        end
    end

    local speciesID = addon.PetItemDB and addon.PetItemDB[itemID]
    if not speciesID and C_PetJournal and C_PetJournal.GetPetInfoByItemID then
        local isCallOk, _, _, _, _, _, _, _, _, _, _, _, _, spID = pcall(C_PetJournal.GetPetInfoByItemID, itemID)
        if isCallOk and spID then speciesID = nosecret(spID) end
    end
    if speciesID and speciesID > 0 and C_PetJournal and C_PetJournal.GetNumCollectedInfo then
        local isCallOk, numCollected, limit = pcall(C_PetJournal.GetNumCollectedInfo, speciesID)
        if isCallOk and numCollected ~= nil then
            local nCol = tonumber(nosecret(numCollected)) or 0
            local nLim = tonumber(nosecret(limit)) or 3
            if nCol > 0 then
                return true, format("|cffAEE26A[" .. resolveExtraLocaleText("petDone") .. "]|r", nCol, nLim)
            else
                return false, format("|cffEA837E[%s]|r", resolveExtraLocaleText("petMiss"))
            end
        end
    end

    local recipeSpell = addon.RecipeItemDB and addon.RecipeItemDB[itemID]
    if recipeSpell and recipeSpell > 0 then
        local learned = DropSourceInspector.hasRecipeSpellLearned(recipeSpell)
        return learned, learned and format("|cffAEE26A[%s]|r", resolveExtraLocaleText("recipeDone")) or format("|cffEA837E[%s]|r", resolveExtraLocaleText("recipeMiss"))
    end

    local craftedRaw = addon.CraftedItemDB and addon.CraftedItemDB[itemID]
    local craftedSpellID = craftedRaw and tonumber((strsplit("|", craftedRaw))) or nil
    local craftedBadge, craftedLearned
    if craftedSpellID and craftedSpellID > 0 then
        craftedLearned = DropSourceInspector.hasRecipeSpellLearned(craftedSpellID)
        craftedBadge = craftedLearned
            and format("|cffAEE26A[%s]|r", resolveExtraLocaleText("recipeDone"))
            or format("|cffEA837E[%s]|r", resolveExtraLocaleText("recipeMiss"))
    end

    if C_TransmogCollection then
        local appearanceID, sourceID
        if C_TransmogCollection.GetItemInfo then
            local isCallOk, aID, sID = pcall(C_TransmogCollection.GetItemInfo, linkOrID)
            if isCallOk then
                appearanceID, sourceID = nosecret(aID), nosecret(sID)
            end
            if not sourceID and itemLink and itemLink ~= itemID then
                local ok2, aID2, sID2 = pcall(C_TransmogCollection.GetItemInfo, itemID)
                if ok2 then
                    appearanceID, sourceID = nosecret(aID2), nosecret(sID2)
                end
            end
        end
        if sourceID and sourceID > 0 then
            local exactCollected = false
            if C_TransmogCollection.PlayerHasTransmogItemModifiedAppearance then
                local isCallOk, has = pcall(C_TransmogCollection.PlayerHasTransmogItemModifiedAppearance, sourceID)
                if isCallOk and nosecret(has) then exactCollected = true end
            end
            if not exactCollected and C_TransmogCollection.GetSourceInfo then
                local isCallOk, apiInfo = pcall(C_TransmogCollection.GetSourceInfo, sourceID)
                if isCallOk and apiInfo and nosecret(apiInfo.isCollected) then exactCollected = true end
            end
            if exactCollected then
                local tmogTxt = format("|cffAEE26A[%s]|r", resolveExtraLocaleText("tmogDone"))
                return true, tmogTxt
            end

            local sharedCollected = false
            if appearanceID and appearanceID > 0 and C_TransmogCollection.GetAllAppearanceSources then
                local isCallOk, sources = pcall(C_TransmogCollection.GetAllAppearanceSources, appearanceID)
                if isCallOk and type(sources) == "table" then
                    for _, altSourceID in ipairs(sources) do
                        local okS, containsAlt = pcall(C_TransmogCollection.PlayerHasTransmogItemModifiedAppearance, altSourceID)
                        if okS and nosecret(containsAlt) then
                            sharedCollected = true
                            break
                        end
                    end
                end
            end
            if not sharedCollected and C_TransmogCollection.PlayerHasTransmogByItemInfo then
                local isCallOk, has = pcall(C_TransmogCollection.PlayerHasTransmogByItemInfo, linkOrID)
                if isCallOk and nosecret(has) then sharedCollected = true end
            end
            if sharedCollected then
                local tmogTxt = format("|cff4BC8E8[%s]|r", resolveExtraLocaleText("tmogShared"))
                return true, tmogTxt
            end
            local tmogMissTxt = format("|cffEA837E[%s]|r", resolveExtraLocaleText("tmogMiss"))
            return false, tmogMissTxt
        end
    end

    local hasEquippable = false
    if compat.GetItemInfoInstant then
        local okI, _, _, _, equipLoc = pcall(compat.GetItemInfoInstant, linkOrID)
        equipLoc = okI and nosecret(equipLoc)
        if equipLoc and equipLoc ~= "" and equipLoc ~= "INVTYPE_NON_EQUIP" and equipLoc ~= "INVTYPE_BAG" then
            hasEquippable = true
        end
    end
    if hasEquippable or isZoneCheck then
        local hasEq = false
        if C_Item and C_Item.IsEquippedItemByID then
            local okE, eqVal = pcall(C_Item.IsEquippedItemByID, itemID)
            if okE and nosecret(eqVal) then hasEq = true end
        elseif IsEquippedItem then
            local okE, eqVal = pcall(IsEquippedItem, itemID)
            if okE and nosecret(eqVal) then hasEq = true end
        end
        if hasEq then
            return true, format("|cffAEE26A[%s]|r", resolveExtraLocaleText("itemEquipped"))
        end
        local totalOwned = 0
        if queryItemCountAPI then
            local okC, itemCount = pcall(queryItemCountAPI, itemID, true)
            totalOwned = (okC and tonumber(nosecret(itemCount))) or 0
        end
        if totalOwned > 0 then
            return true, format("|cffAEE26A[" .. resolveExtraLocaleText("itemOwned") .. "]|r", totalOwned)
        end
        if hasEquippable or isZoneCheck then
            return false, format("|cffEA837E[%s]|r", resolveExtraLocaleText("itemMissing"))
        end
    end

    if craftedBadge and isZoneCheck then
        return craftedLearned, craftedBadge
    end

    return nil, nil
end

addon.FACTION_FALLBACK_KO = {
    [59] = "토륨 대장조합", [87] = "붉은해적단", [270] = "잔달라 부족",
    [509] = "아라소르 연맹", [510] = "포세이큰 파멸단", [529] = "은빛여명회",
    [576] = "나무구렁 요새", [609] = "세나리온 의회", [729] = "서리늑대 부족",
    [730] = "스톰파이크 경비대", [749] = "히드락시안 물의 군주",
    [889] = "전쟁노래 정찰대", [890] = "은빛날개 파수대",
    [909] = "다크문 유랑단", [910] = "노즈도르무 혈족",
}

function DropSourceInspector.determineFactionAndStanding(factionID, standingID)
    local facName
    if C_Reputation and C_Reputation.GetFactionDataByID then
        local isCallOk, payloadData = pcall(C_Reputation.GetFactionDataByID, factionID)
        if isCallOk and payloadData and payloadData.name and payloadData.name ~= "" then
            facName = nosecret(payloadData.name)
        end
    elseif GetFactionInfoByID then
        local isCallOk, displayName = pcall(GetFactionInfoByID, factionID)
        if isCallOk and displayName and displayName ~= "" then
            facName = nosecret(displayName)
        end
    end
    if not facName or facName == "" then
        facName = (addon.FACTION_FALLBACK_KO and addon.FACTION_FALLBACK_KO[factionID]) or format("Faction #%d", factionID)
    end
    local standLabel = (standingID and standingID > 0 and _G["FACTION_STANDING_LABEL" .. standingID]) or nil
    if not standLabel or standLabel == "" then
        if standingID == 5 then standLabel = "우호적"
        elseif standingID == 6 then standLabel = "매우 우호적"
        elseif standingID == 7 then standLabel = "확고한 동맹"
        elseif standingID == 8 then standLabel = "확고한 동맹"
        end
    end
    return facName, standLabel
end

function DropSourceInspector.composeSingleSourceRecord(recordItem)
    if not recordItem or recordItem == "" then return nil, nil end
    local kind, locStr, subStr, extraStr, coordStr = strsplit(":", recordItem)
    local locID = tonumber(locStr) or 0
    local subID = tonumber(subStr) or 0
    local extraID = tonumber(extraStr) or 0
    local coordTxt = (coordStr and coordStr ~= "") and format(" |cff8398A6(%s)|r", coordStr) or ""

    if kind == "D" then
        local instName = DropSourceInspector.determineLocationName(-locID) or format("Instance #%d", locID)
        local targetName = (subID > 0 and DropSourceInspector.determineNpcName(subID)) or (extraID > 0 and DropSourceInspector.determineObjectName(extraID)) or nil
        if targetName then
            return format("|cffC9A4EF[%s]|r |cffEDF4F7%s|r |cff8398A6>|r |cffF1BD57%s|r%s", resolveExtraLocaleText("srcDungeon"), instName, targetName, coordTxt), -locID
        end
        return format("|cffC9A4EF[%s]|r |cffEDF4F7%s|r%s", resolveExtraLocaleText("srcDungeon"), instName, coordTxt), -locID

    elseif kind == "DN" then
        local zName = (locStr and locStr ~= "") and locStr or resolveExtraLocaleText("srcMob")
        local bName = (extraID > 0 and DropSourceInspector.determineNpcName(extraID)) or ((subStr and subStr ~= "") and subStr) or nil
        if bName and bName ~= "" and not bName:find("^NPC #") then
            return format("|cffC9A4EF[%s]|r |cffEDF4F7%s|r |cff8398A6>|r |cffF1BD57%s|r%s", resolveExtraLocaleText("srcMob"), zName, bName, coordTxt), nil
        end
        return format("|cffC9A4EF[%s]|r |cffEDF4F7%s|r%s", resolveExtraLocaleText("srcMob"), zName, coordTxt), nil

    elseif kind == "G" then
        local profName = DropSourceInspector.determineProfessionName(locID) or resolveExtraLocaleText("srcGather")
        local skillTxt = (subID > 0) and format(" (%d)", subID) or ""
        local locName = (extraID > 0) and DropSourceInspector.determineLocationName(extraID) or nil
        local desc = (coordStr and coordStr ~= "") and coordStr or nil
        if desc and locName then
            return format("|cffAEE26A[%s]|r |cffEDF4F7%s%s|r |cff8398A6·|r |cffF1BD57%s|r |cff8398A6(%s)|r", resolveExtraLocaleText("srcGather"), profName, skillTxt, desc, locName), (extraID > 0 and extraID or nil)
        elseif desc then
            return format("|cffAEE26A[%s]|r |cffEDF4F7%s%s|r |cff8398A6·|r |cffF1BD57%s|r", resolveExtraLocaleText("srcGather"), profName, skillTxt, desc), nil
        elseif locName then
            return format("|cffAEE26A[%s]|r |cffEDF4F7%s%s|r |cff8398A6·|r |cffF1BD57%s|r", resolveExtraLocaleText("srcGather"), profName, skillTxt, locName), (extraID > 0 and extraID or nil)
        end
        return format("|cffAEE26A[%s]|r |cffEDF4F7%s%s|r", resolveExtraLocaleText("srcGather"), profName, skillTxt), nil

    elseif kind == "FS" then
        local locName = DropSourceInspector.determineLocationName(locID) or resolveExtraLocaleText("srcFishing")
        local hasKo = (resolveActiveLocale() == "koKR")
        local skillTxt = (subID > 0) and (hasKo and format("숙련 %d", subID) or format((addon.EXTRA_LOCALE and addon.EXTRA_LOCALE[resolveActiveLocale()] and addon.EXTRA_LOCALE[resolveActiveLocale()].srcSkillFmt) or "Skill %d", subID)) or nil
        local rateTxt = (coordStr and coordStr ~= "") and coordStr or nil
        local meta = (rateTxt and skillTxt) and (rateTxt .. " · " .. skillTxt) or (rateTxt or skillTxt)
        local metaStr = meta and format(" |cff8398A6(%s)|r", meta) or ""
        return format("|cff4BC8E8[%s]|r |cffEDF4F7%s|r%s", resolveExtraLocaleText("srcFishing"), locName, metaStr), (locID > 0 and locID or nil)

    elseif kind == "F" then
        local facName, standName = DropSourceInspector.determineFactionAndStanding(locID, subID)
        if standName then
            return format("|cffAEE26A[%s]|r |cffEDF4F7%s|r |cff8398A6·|r |cffF1BD57%s|r", resolveExtraLocaleText("srcFaction"), facName, standName), nil
        end
        return format("|cffAEE26A[%s]|r |cffEDF4F7%s|r", resolveExtraLocaleText("srcFaction"), facName), nil

    elseif kind == "TK" then
        local tokName = (locID > 0) and DropSourceInspector.determineReagentName(locID) or resolveExtraLocaleText("srcToken")
        local instName = (subID > 0) and DropSourceInspector.determineLocationName(-subID) or nil
        local bossName = (extraID > 0) and DropSourceInspector.determineNpcName(extraID) or nil
        if instName and bossName then
            return format("|cffC9A4EF[%s]|r |cffEDF4F7%s|r |cff8398A6>|r |cffF1BD57%s|r |cff8398A6·|r |cff4BC8E8%s|r%s", resolveExtraLocaleText("srcToken"), instName, bossName, tokName, coordTxt), -subID
        elseif instName then
            return format("|cffC9A4EF[%s]|r |cffEDF4F7%s|r |cff8398A6·|r |cff4BC8E8%s|r%s", resolveExtraLocaleText("srcToken"), instName, tokName, coordTxt), -subID
        end
        return format("|cffC9A4EF[%s]|r |cff4BC8E8%s|r%s", resolveExtraLocaleText("srcToken"), tokName, coordTxt), nil

    elseif kind == "Q" or kind == "QI" then
        local tagLabel = (kind == "Q") and resolveExtraLocaleText("srcQuest") or resolveExtraLocaleText("srcQuestObj")
        local locName = DropSourceInspector.determineLocationName(locID)
        local qTitle = DropSourceInspector.determineQuestName(subID)
        local qDone = DropSourceInspector.hasQuestCompleted(subID)
        local qBadge = qDone and format(" |cffAEE26A[%s]|r", resolveExtraLocaleText("collected")) or ""
        local parts = {}
        if locName then parts[#parts + 1] = format("|cffEDF4F7%s|r", locName) end
        if qTitle then parts[#parts + 1] = format("|cffF1BD57%s|r", qTitle) end
        if kind == "QI" and extraID > 0 then
            local mobOrObj = DropSourceInspector.determineNpcName(extraID)
            if mobOrObj and not mobOrObj:find("^NPC #") then
                parts[#parts + 1] = format("|cffA7B9C5%s|r", mobOrObj)
            end
        end
        return format("|cffF1BD57[%s]|r %s%s%s", tagLabel, table.concat(parts, " |cff8398A6>|r "), coordTxt, qBadge), (locID ~= 0 and locID or nil)

    elseif kind == "V" then
        local locName = DropSourceInspector.determineLocationName(locID)
        local npcName = (subID > 0) and DropSourceInspector.determineNpcName(subID) or nil
        local body = (locName and npcName) and format("|cffEDF4F7%s|r |cff8398A6>|r |cffAEE26A%s|r", locName, npcName)
            or format("|cffEDF4F7%s|r", locName or npcName or resolveExtraLocaleText("srcVendor"))
        return format("|cffAEE26A[%s]|r %s%s", resolveExtraLocaleText("srcVendor"), body, coordTxt), (locID ~= 0 and locID or nil)

    elseif kind == "VN" then
        local zName = (locStr and locStr ~= "") and locStr or nil
        local vName = (extraID > 0 and DropSourceInspector.determineNpcName(extraID)) or ((subStr and subStr ~= "") and subStr) or nil
        if vName and vName:find("^NPC #") and subStr and subStr ~= "" then vName = subStr end
        local body = (zName and vName) and format("|cffEDF4F7%s|r |cff8398A6>|r |cffAEE26A%s|r", zName, vName)
            or format("|cffEDF4F7%s|r", zName or vName or resolveExtraLocaleText("srcVendor"))
        return format("|cffAEE26A[%s]|r %s", resolveExtraLocaleText("srcVendor"), body), nil

    elseif kind == "M" then
        local locName = DropSourceInspector.determineLocationName(locID)
        local npcName = (subID > 0) and DropSourceInspector.determineNpcName(subID) or nil
        local body = (locName and npcName) and format("|cffEDF4F7%s|r |cff8398A6>|r |cffEA837E%s|r", locName, npcName)
            or format("|cffEDF4F7%s|r", locName or npcName or resolveExtraLocaleText("srcMob"))
        return format("|cffEA837E[%s]|r %s%s", resolveExtraLocaleText("srcMob"), body, coordTxt), (locID ~= 0 and locID or nil)

    elseif kind == "O" then
        local locName = DropSourceInspector.determineLocationName(locID)
        local objName = (subID > 0) and DropSourceInspector.determineObjectName(subID) or nil
        local body = (locName and objName) and format("|cffEDF4F7%s|r |cff8398A6>|r |cff4BC8E8%s|r", locName, objName)
            or format("|cffEDF4F7%s|r", locName or objName or resolveExtraLocaleText("srcObject"))
        return format("|cff4BC8E8[%s]|r %s%s", resolveExtraLocaleText("srcObject"), body, coordTxt), (locID ~= 0 and locID or nil)

    elseif kind == "P" then
        local profName = DropSourceInspector.determineProfessionName(locID) or resolveExtraLocaleText("srcProf")
        local skillTxt = (subID > 0) and format(" (%d)", subID) or ""
        local locName = (extraID > 0) and DropSourceInspector.determineLocationName(extraID) or nil
        if locName then
            return format("|cff4BC8E8[%s]|r |cffEDF4F7%s%s|r |cff8398A6· %s|r", resolveExtraLocaleText("srcProf"), profName, skillTxt, locName), (extraID > 0 and extraID or nil)
        end
        return format("|cff4BC8E8[%s]|r |cffEDF4F7%s%s|r", resolveExtraLocaleText("srcProf"), profName, skillTxt), nil

    elseif kind == "PVP" then
        local locName = (locID > 0 and DropSourceInspector.determineLocationName(locID)) or ((coordStr and coordStr ~= "") and coordStr) or resolveExtraLocaleText("srcPvP")
        local cTxt = (locID > 0) and coordTxt or ""
        return format("|cffEA837E[%s]|r |cffEDF4F7%s|r%s", resolveExtraLocaleText("srcPvP"), locName, cTxt), nil

    elseif kind == "H" then
        local userPref = resolveActiveLocale()
        local hName = (userPref == "koKR" and HOLIDAY_NAMES_KO[locID]) or HOLIDAY_NAMES_EN[locID] or resolveExtraLocaleText("srcHoliday")
        local mapName = (extraID > 0) and DropSourceInspector.determineLocationName(extraID) or nil
        if mapName then
            return format("|cff4BC8E8[%s]|r |cffEDF4F7%s|r |cff8398A6>|r |cffA7B9C5%s|r%s", resolveExtraLocaleText("srcHoliday"), hName, mapName, coordTxt), nil
        end
        return format("|cff4BC8E8[%s]|r |cffEDF4F7%s|r%s", resolveExtraLocaleText("srcHoliday"), hName, coordTxt), nil

    elseif kind == "W" then
        return format("|cffA7B9C5[%s]|r", resolveExtraLocaleText("srcWorld")), nil
    end
    return nil, nil
end

function DropSourceInspector.determineFactionRecipeSource(rSrc)
    if not rSrc or rSrc == "" then return nil end
    local aPart, hPart = rSrc:match("^@A:(.-)~@H:(.+)$")
    if aPart and hPart then
        local fac = UnitFactionGroup and nosecret(UnitFactionGroup("player"))
        if fac == "Alliance" then
            return aPart
        elseif fac == "Horde" then
            return hPart
        end
        return aPart .. " / " .. hPart
    end
    return rSrc:gsub("@A:", "|cff4BC8E8[A]|r "):gsub("@H:", "|cffEA837E[H]|r "):gsub("@A ", "|cff4BC8E8[A]|r "):gsub("@H ", "|cffEA837E[H]|r ")
end

function DropSourceInspector.composeCraftedExtras(rawCraft)
    if not rawCraft or rawCraft == "" then return nil, nil, nil, false end
    local spellStr, profStr, skillStr, catKo, catEn, reagStr, srcKo, srcEn = strsplit("|", rawCraft)
    local spellID = tonumber(spellStr) or 0
    local profID = tonumber(profStr) or 0
    local skillLvl = tonumber(skillStr) or 0
    local userPref = resolveActiveLocale()
    local hasLearned = (spellID > 0) and DropSourceInspector.hasRecipeSpellLearned(spellID) or false
    local learnBadge = (spellID > 0)
        and (hasLearned and format(" |cffAEE26A[%s]|r", resolveExtraLocaleText("recipeDone")) or format(" |cffEA837E[%s]|r", resolveExtraLocaleText("recipeMiss")))
        or ""

    local profName = DropSourceInspector.determineProfessionName(profID) or resolveExtraLocaleText("srcProf")
    local skillTxt = (skillLvl > 0) and format(" (%d)", skillLvl) or ""
    local catName = (userPref == "koKR") and ((catKo ~= "" and catKo) or catEn) or ((catEn ~= "" and catEn) or catKo)
    local profLine
    if catName and catName ~= "" then
        profLine = format("|cff4BC8E8[%s]|r |cffEDF4F7%s%s|r |cff8398A6· %s|r%s", resolveExtraLocaleText("srcProf"), profName, skillTxt, catName, learnBadge)
    else
        profLine = format("|cff4BC8E8[%s]|r |cffEDF4F7%s%s|r%s", resolveExtraLocaleText("srcProf"), profName, skillTxt, learnBadge)
    end

    local rSrc = (userPref == "koKR") and ((srcKo and srcKo ~= "" and srcKo) or srcEn) or ((srcEn and srcEn ~= "" and srcEn) or srcKo)
    rSrc = DropSourceInspector.determineFactionRecipeSource(rSrc)
    local recipeSrcLine
    if rSrc and rSrc ~= "" then
        recipeSrcLine = format("|cffF1BD57%s|r", rSrc)
    end

    local reagLine
    if reagStr and reagStr ~= "" then
        local rParts = {}
        for pairStr in reagStr:gmatch("([^,]+)") do
            local ridStr, needStr = strsplit(":", pairStr)
            local rid = tonumber(ridStr)
            local need = tonumber(needStr) or 1
            if rid and rid > 0 and #rParts < 5 then
                local rName = DropSourceInspector.determineReagentName(rid)
                local have = 0
                if queryItemCountAPI then
                    local okC, themeColor = pcall(queryItemCountAPI, rid, true)
                    have = (okC and tonumber(nosecret(themeColor))) or 0
                end
                local cntCol = (have >= need) and "AEE26A" or "EA837E"
                rParts[#rParts + 1] = format("|cffEDF4F7%s|r |cff%s%d/%d|r", rName, cntCol, have, need)
            end
        end
        if #rParts > 0 then
            reagLine = table.concat(rParts, " |cff8398A6·|r ")
        end
    end

    return profLine, recipeSrcLine, reagLine, hasLearned
end

function DropSourceInspector.composeReagentUsage(itemID)
    local raw = addon.ReagentUsageDB and addon.ReagentUsageDB[itemID]
    if not raw or raw == "" then return nil end
    local parts = {}
    for pairStr in raw:gmatch("([^,]+)") do
        local pidStr, cntStr = strsplit(":", pairStr)
        local profIDVal = tonumber(pidStr)
        local itemCount = tonumber(cntStr) or 0
        if profIDVal and profIDVal > 0 and itemCount > 0 and #parts < 4 then
            local pName = DropSourceInspector.determineProfessionName(profIDVal) or ("#" .. profIDVal)
            parts[#parts + 1] = format("|cffEDF4F7" .. resolveExtraLocaleText("recipesFmt") .. "|r", pName, itemCount)
        end
    end
    if #parts > 0 then
        return table.concat(parts, " |cff8398A6·|r ")
    end
    return nil
end

function DropSourceInspector.composeItemSources(itemID, itemLink)
    local outputList = {}
    local primaryLocKey = nil
    local craftedRaw = addon.CraftedItemDB and addon.CraftedItemDB[itemID]
    local profLine, recipeSrcLine, reagLine, hasLearned
    if craftedRaw then
        profLine, recipeSrcLine, reagLine, hasLearned = DropSourceInspector.composeCraftedExtras(craftedRaw)
        if profLine then
            outputList[#outputList + 1] = profLine
        end
        if hasLearned and not IsShiftKeyDown() then
            recipeSrcLine = nil
            reagLine = nil
        end
    end

    local raw = addon.ItemSourceDB and addon.ItemSourceDB[itemID]
    if raw and raw ~= "" then
        
        if raw:find("^FS:") and raw:find(";FS:") then
            local fsParts = {}
            local hasKo = (resolveActiveLocale() == "koKR")
            for recordItem in raw:gmatch("([^;]+)") do
                local _, locStr, subStr, _, coordStr = strsplit(":", recordItem)
                local locID = tonumber(locStr) or 0
                local subID = tonumber(subStr) or 0
                local locName = DropSourceInspector.determineLocationName(locID)
                if locName then
                    if not primaryLocKey and locID > 0 then primaryLocKey = locID end
                    local skillTxt = (subID > 0) and (hasKo and format("숙련 %d", subID) or format((addon.EXTRA_LOCALE and addon.EXTRA_LOCALE[resolveActiveLocale()] and addon.EXTRA_LOCALE[resolveActiveLocale()].srcSkillFmt) or "Skill %d", subID)) or nil
                    local rateTxt = (coordStr and coordStr ~= "") and coordStr or nil
                    local meta = (rateTxt and skillTxt) and (rateTxt .. " · " .. skillTxt) or (rateTxt or skillTxt)
                    fsParts[#fsParts + 1] = format("|cffEDF4F7%s|r%s", locName, meta and format(" |cff8398A6(%s)|r", meta) or "")
                end
            end
            if #fsParts > 0 then
                outputList[#outputList + 1] = format("|cff4BC8E8[%s]|r %s", resolveExtraLocaleText("srcFishing"), table.concat(fsParts, " |cff8398A6/|r "))
            end
        elseif raw:find("^G:") and raw:find(";G:") then
            local gZones = {}
            local gProfID, gSkill = 0, 0
            for recordItem in raw:gmatch("([^;]+)") do
                local kind, locStr, subStr, extraStr, coordStr = strsplit(":", recordItem)
                if kind == "G" then
                    gProfID = tonumber(locStr) or gProfID
                    gSkill = tonumber(subStr) or gSkill
                    local zID = tonumber(extraStr) or 0
                    local zName = (zID > 0 and DropSourceInspector.determineLocationName(zID)) or ((coordStr and coordStr ~= "") and coordStr) or nil
                    if zName then gZones[#gZones + 1] = zName end
                end
            end
            if gProfID > 0 and #gZones > 0 then
                local profName = DropSourceInspector.determineProfessionName(gProfID) or resolveExtraLocaleText("srcGather")
                local skillTxt = (gSkill > 0) and format(" (%d)", gSkill) or ""
                outputList[#outputList + 1] = format("|cffAEE26A[%s]|r |cffEDF4F7%s%s|r |cff8398A6·|r |cffF1BD57%s|r", resolveExtraLocaleText("srcGather"), profName, skillTxt, table.concat(gZones, ", "))
            end
        else
            for recordItem in raw:gmatch("([^;]+)") do
                if #outputList < 2 and not (profLine and recordItem:find("^P:")) then
                    local fmtRec, locKey = DropSourceInspector.composeSingleSourceRecord(recordItem)
                    if locKey and not primaryLocKey then primaryLocKey = locKey end
                    if fmtRec and fmtRec ~= outputList[1] then
                        outputList[#outputList + 1] = fmtRec
                    end
                end
            end
        end
    end

    if #outputList == 0 and C_TransmogCollection and C_TransmogCollection.GetItemInfo and C_TransmogCollection.GetAppearanceSourceDrops then
        local isCallOk, _, sourceID = pcall(C_TransmogCollection.GetItemInfo, itemLink or itemID)
        sourceID = isCallOk and nosecret(sourceID)
        if sourceID and sourceID > 0 then
            local dok, drops = pcall(C_TransmogCollection.GetAppearanceSourceDrops, sourceID)
            if dok and type(drops) == "table" and drops[1] then
                local dataEntry = drops[1]
                local inst = nosecret(dataEntry.instance)
                local enc = nosecret(dataEntry.encounter)
                if inst and enc then
                    outputList[#outputList + 1] = format("|cffC9A4EF[%s]|r |cffEDF4F7%s|r |cff8398A6>|r |cffF1BD57%s|r", resolveExtraLocaleText("srcDungeon"), inst, enc)
                elseif inst or enc then
                    outputList[#outputList + 1] = format("|cffC9A4EF[%s]|r |cffEDF4F7%s|r", resolveExtraLocaleText("srcDungeon"), inst or enc)
                end
            end
        end
    end
    return outputList, recipeSrcLine, reagLine, primaryLocKey
end

function DropSourceInspector.composeDurationShort(sec)
    if not sec or sec < 0 then return nil end
    local dataEntry = math.floor(sec / 86400)
    local headerBar = math.floor((sec % 86400) / 3600)
    local matchRef = math.floor((sec % 3600) / 60)
    local s = math.floor(sec % 60)
    if dataEntry > 0 then
        return format("%dd %dh %dm", dataEntry, headerBar, matchRef)
    elseif headerBar > 0 then
        return format("%dh %dm %ds", headerBar, matchRef, s)
    elseif matchRef > 0 then
        return format("%dm %ds", matchRef, s)
    else
        return format("%ds", s)
    end
end

addon._zcCache = {}

function DropSourceInspector.resolveZoneCollectionSummary(locKey)
    locKey = tonumber(locKey)
    if not locKey or locKey == 0 then return nil, nil end
    local rawZ = addon.ZoneCollectDB and addon.ZoneCollectDB[locKey]
    if not rawZ or rawZ == "" then return nil, nil end

    local currentTime = GetTime and GetTime() or 0
    local cached = addon._zcCache[locKey]
    if cached and (currentTime - cached.time) < 2.5 then
        return cached.summary, cached.missing
    end

    local locName = DropSourceInspector.determineLocationName(locKey)
    if not locName or locName == "" then return nil, nil end

    local itemsPart, recipesPart, questsPart = strsplit("|", rawZ)
    local totalItems, doneItems = 0, 0
    local totalRec, doneRec = 0, 0
    local totalQ, doneQ = 0, 0
    local missList = {}

    if itemsPart and itemsPart ~= "" then
        for idStr in itemsPart:gmatch("(%d+)") do
            local itemIDVal = tonumber(idStr)
            if itemIDVal and itemIDVal > 0 then
                totalItems = totalItems + 1
                local hasCol = DropSourceInspector.verifyItemCollectionStatus(itemIDVal, nil, true)
                if hasCol == true then
                    doneItems = doneItems + 1
                elseif #missList < 3 and compat.GetItemInfo then
                    local isCallOk, iName, _, iQuality = pcall(compat.GetItemInfo, itemIDVal)
                    if isCallOk and iName and iName ~= "" then
                        local qHex = (iQuality and ITEM_QUALITY_COLORS and ITEM_QUALITY_COLORS[iQuality] and ITEM_QUALITY_COLORS[iQuality].hex) or "|cffEDF4F7"
                        missList[#missList + 1] = format("%s[%s]|r", qHex, nosecret(iName))
                    elseif C_Item and C_Item.RequestLoadItemDataByID then
                        pcall(C_Item.RequestLoadItemDataByID, itemIDVal)
                    end
                end
            end
        end
    end

    if recipesPart and recipesPart ~= "" then
        for pairStr in recipesPart:gmatch("([^,]+)") do
            local rItemStr, rSpellStr = strsplit(":", pairStr)
            local rItemID = tonumber(rItemStr) or 0
            local rSpellID = tonumber(rSpellStr) or 0
            if rSpellID > 0 then
                totalRec = totalRec + 1
                if DropSourceInspector.hasRecipeSpellLearned(rSpellID) then
                    doneRec = doneRec + 1
                elseif #missList < 3 then
                    local rName
                    if rItemID > 0 and compat.GetItemInfo then
                        local isCallOk, nodeEntry = pcall(compat.GetItemInfo, rItemID)
                        if isCallOk and nodeEntry and nodeEntry ~= "" then rName = nosecret(nodeEntry) end
                    end
                    if not rName and C_Spell and C_Spell.GetSpellName then
                        local isCallOk, nodeEntry = pcall(C_Spell.GetSpellName, rSpellID)
                        if isCallOk and nodeEntry and nodeEntry ~= "" then rName = nosecret(nodeEntry) end
                    end
                    if rName then
                        missList[#missList + 1] = format("|cff4BC8E8[%s]|r", rName)
                    end
                end
            end
        end
    end

    if questsPart and questsPart ~= "" then
        for qStr in questsPart:gmatch("(%d+)") do
            local questIDVal = tonumber(qStr)
            if questIDVal and questIDVal > 0 then
                totalQ = totalQ + 1
                if DropSourceInspector.hasQuestCompleted(questIDVal) then
                    doneQ = doneQ + 1
                elseif #missList < 3 then
                    local qTitle = DropSourceInspector.determineQuestName(questIDVal)
                    if qTitle and not qTitle:find("^#") then
                        missList[#missList + 1] = format("|cffF1BD57[%s]|r", qTitle)
                    end
                end
            end
        end
    end

    local grandTotal = totalItems + totalRec + totalQ
    if grandTotal <= 0 then return nil, nil end
    local grandDone = doneItems + doneRec + doneQ
    local pct = math.floor((grandDone / grandTotal) * 100 + 0.5)
    local pctCol = (pct == 100) and "AEE26A" or ((pct >= 50) and "F1BD57" or "4BC8E8")

    local parts = {}
    if totalItems > 0 then parts[#parts + 1] = format(resolveExtraLocaleText("zcItemsFmt"), doneItems, totalItems) end
    if totalRec > 0 then parts[#parts + 1] = format(resolveExtraLocaleText("zcRecipesFmt"), doneRec, totalRec) end
    if totalQ > 0 then parts[#parts + 1] = format(resolveExtraLocaleText("zcQuestsFmt"), doneQ, totalQ) end

    local summary = format("|cffEDF4F7%s|r |cff%s%d%%|r |cff8398A6(%s)|r", locName, pctCol, pct, table.concat(parts, " · "))
    local missing
    if grandDone < grandTotal and #missList > 0 then
        local rem = (grandTotal - grandDone) - #missList
        local remTxt = (rem > 0) and format(" |cff8398A6(+%d)|r", rem) or ""
        missing = table.concat(missList, " |cff8398A6·|r ") .. remTxt
    end

    addon._zcCache[locKey] = { time = currentTime, summary = summary, missing = missing }
    return summary, missing
end

addon.TACTICAL_TAGS = {
    ILVL_PREFIX_TAG     = ILVL_PREFIX_TAG,
    MOUNT_PREFIX_TAG    = MOUNT_PREFIX_TAG,
    SPEED_PREFIX_TAG    = SPEED_PREFIX_TAG,
    SCORE_PREFIX_TAG    = SCORE_PREFIX_TAG,
    CAST_PREFIX_TAG     = CAST_PREFIX_TAG,
    THREAT_PREFIX_TAG   = THREAT_PREFIX_TAG,
    NPC_ALIVE_TAG       = NPC_ALIVE_TAG,
    NPC_TRACK_TAG       = NPC_TRACK_TAG,
    NPC_NOTABLE_TAG     = NPC_NOTABLE_TAG,
    ILVL_PATTERN        = ILVL_PATTERN,
    MOUNT_PATTERN       = MOUNT_PATTERN,
    SPEED_PATTERN       = SPEED_PATTERN,
    SCORE_PATTERN       = SCORE_PATTERN,
    CAST_PATTERN        = CAST_PATTERN,
    THREAT_PATTERN      = THREAT_PATTERN,
    NPC_ALIVE_PATTERN   = NPC_ALIVE_PATTERN,
    NPC_TRACK_PATTERN   = NPC_TRACK_PATTERN,
    NPC_NOTABLE_PATTERN = NPC_NOTABLE_PATTERN,
}

addon.StripColors = DropSourceInspector.cleanColors
addon.IsForeignIlvlLabel = DropSourceInspector.hasForeignIlvlLabel
addon.FormatCraftedExtras = DropSourceInspector.composeCraftedExtras
addon.ResolveLocationName = DropSourceInspector.determineLocationName
addon.ResolveNpcName = DropSourceInspector.determineNpcName
addon.ResolveObjectName = DropSourceInspector.determineObjectName
addon.ResolveQuestName = DropSourceInspector.determineQuestName
addon.ResolveReagentName = DropSourceInspector.determineReagentName
addon.ResolveProfessionName = DropSourceInspector.determineProfessionName
addon.IsQuestCompleted = DropSourceInspector.hasQuestCompleted
addon.IsRecipeSpellLearned = DropSourceInspector.hasRecipeSpellLearned
addon.AppendDualNameToTitle = DropSourceInspector.appendDualNameToTitle
addon.CheckItemCollectionStatus = DropSourceInspector.verifyItemCollectionStatus
addon.FormatReagentUsage = DropSourceInspector.composeReagentUsage
addon.FormatItemSources = DropSourceInspector.composeItemSources
addon.QueryItemCountSafe = queryItemCountAPI
addon.FormatDurationShort = DropSourceInspector.composeDurationShort
addon.GetZoneCollectionSummary = DropSourceInspector.resolveZoneCollectionSummary
