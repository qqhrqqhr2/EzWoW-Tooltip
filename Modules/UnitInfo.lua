--===========================================================================
-- EzWoW - Tooltip
-- Modules/UnitInfo.lua : Unit Name, Guild, Target-of-Target, Role & GearScore Builder
--===========================================================================
local _, ns = ...

local UnitProfileFormatter = ns.UnitProfileFormatter or {}
ns.UnitProfileFormatter = UnitProfileFormatter
local addon = EzWoW_Tooltip
local platformHelper = ns.compat
local bus = ns.events
local nosecret, issecret = platformHelper.nosecret, platformHelper.issecret
local lineRegions = addon.LineRegions

local TEXT_HEX = "edf4f7"
local MUTED_HEX = "a7b9c5"

local TAG_TARGET   = "|cff4BC8E8◆|r|cff000121|r "
local TAG_TARGETBY = "|cff4BC8E8◆|r|cff000122|r "
local TAG_GEAR     = "|cff4BC8E8◆|r|cff000120|r "
local PAT_TARGET, PAT_TARGETBY, PAT_GEAR = "^" .. TAG_TARGET, "^" .. TAG_TARGETBY, "^" .. TAG_GEAR

local LABELS = {
    enUS = { gear = "Gear Score", targetBy = "Targeted by" },
    koKR = { gear = "장비 점수", targetBy = "대상 지정" },
    deDE = { gear = "Ausrüstungswertung", targetBy = "Anvisiert von" },
    frFR = { gear = "Score d'équipement", targetBy = "Ciblé par" },
    esES = { gear = "Puntuación de equipo", targetBy = "Objetivo de" },
    ruRU = { gear = "Рейтинг экипировки", targetBy = "Цель для" },
    zhCN = { gear = "装备评分", targetBy = "被选为目标" },
    zhTW = { gear = "裝備評分", targetBy = "被選為目標" },
}

function UnitProfileFormatter.locale()
    local userPref = addon.db and addon.db.general and addon.db.general.language
    if not userPref or userPref == "auto" then userPref = GetLocale and GetLocale() or "enUS" end
    if userPref == "esMX" then userPref = "esES" end
    return LABELS[userPref] and userPref or "enUS"
end

function UnitProfileFormatter.formatLocalizedLabel(key)
    return (LABELS[UnitProfileFormatter.locale()] or LABELS.enUS)[key] or LABELS.enUS[key]
end

function UnitProfileFormatter.hex(r, g, b) return addon:GetHexColor(r, g, b) end
function UnitProfileFormatter.paint(text, hexColor) return text and ("|cff" .. hexColor .. text .. "|r") or nil end

function UnitProfileFormatter.classColor(classFile)
    local colors = _G.CUSTOM_CLASS_COLORS or _G.RAID_CLASS_COLORS
    local themeColor = classFile and colors and colors[classFile]
    if themeColor then return themeColor.r, themeColor.g, themeColor.b end
    return 1, 1, 1
end

function UnitProfileFormatter.reactionColor(reaction)
    local themeColor = _G.FACTION_BAR_COLORS and _G.FACTION_BAR_COLORS[reaction or 4]
    if themeColor then return themeColor.r, themeColor.g, themeColor.b end
    return 1, 0.82, 0
end

function UnitProfileFormatter.levelColor(level)
    if not level or level < 0 then return 1, 0.1, 0.1 end
    local themeColor = _G.GetCreatureDifficultyColor and _G.GetCreatureDifficultyColor(level)
    if themeColor then return themeColor.r, themeColor.g, themeColor.b end
    return 1, 1, 1
end

function UnitProfileFormatter.plain(text)
    if type(text) ~= "string" then return text end
    return (text:gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", ""))
end

function UnitProfileFormatter.join(parts)
    local outputList = {}
    for index = 1, #parts do
        if parts[index] and parts[index] ~= "" then outputList[#outputList + 1] = parts[index] end
    end
    return table.concat(outputList, " ")
end

function UnitProfileFormatter.extractLines(tip)
    local lineList = {}
    for index = 1, tip:NumLines() do
        local left, right = lineRegions(tip, index)
        if not left then return end
        local leftText = left:GetText()
        if issecret(leftText) then return end 
        local entry = { left = leftText, leftColor = { left:GetTextColor() } }
        if right and right:IsShown() then
            local rightText = right:GetText()
            if issecret(rightText) then return end
            entry.right = rightText
            entry.rightColor = { right:GetTextColor() }
        end
        lineList[index] = entry
    end
    return lineList
end

function UnitProfileFormatter.startsWith(text, prefix)
    return type(text) == "string" and prefix and prefix ~= "" and text:sub(1, #prefix) == prefix
end

function UnitProfileFormatter.locateLevelLine(lineList, info)
    local levelWord = _G.LEVEL
    for index = 2, #lineList do
        local text = UnitProfileFormatter.plain(lineList[index].left)
        if UnitProfileFormatter.startsWith(text, levelWord) then return index end
        if text and info.levelText and text:find(info.levelText, 1, true)
            and ((info.className and text:find(info.className, 1, true))
              or (info.creature and text:find(info.creature, 1, true))) then
            return index
        end
    end
end

function UnitProfileFormatter.titleParts(name, pvpName)
    if not name or not pvpName or name == pvpName then return end
    local coordPos = pvpName:find(name, 1, true)
    if not coordPos then return end
    local titleStr = pvpName:sub(1, coordPos - 1) .. pvpName:sub(coordPos + #name)
    titleStr = titleStr:gsub(",", ""):gsub("，", "")
    titleStr = strtrim(titleStr)
    if titleStr == "" then return end
    return titleStr, coordPos > 1 
end

function UnitProfileFormatter.groupZone(unit)
    if not IsInGroup() then return end
    if not (nosecret(UnitInParty(unit)) or nosecret(UnitInRaid(unit))) then return end
    local first, second = UnitName(unit)
    first, second = nosecret(first), nosecret(second)
    if not first then return end
    local alt = platformHelper.hasSurnames and nosecret((platformHelper.UnitNameAndRealm(unit)))
        or (second and second ~= "" and (first .. "-" .. second)) or nil
    for index = 1, GetNumGroupMembers() do
        local rosterName, _, _, _, _, _, zone = GetRaidRosterInfo(index)
        if rosterName and (rosterName == first or rosterName == alt) then return zone end
    end
end

function UnitProfileFormatter.friendBadge(unit)
    local guid = nosecret(UnitGUID(unit))
    if not guid then return end
    if _G.C_FriendList and _G.C_FriendList.IsFriend and nosecret(_G.C_FriendList.IsFriend(guid)) then
        return addon.icons.friend
    end
    local bnet = _G.C_BattleNet and _G.C_BattleNet.GetAccountInfoByGUID
    if bnet and guid ~= UnitGUID("player") then
        local info = bnet(guid)
        if info and info.isFriend then return addon.icons.bnetfriend end
    end
end

function UnitProfileFormatter.collect(unit)
    local info = { unit = unit }
    info.isPlayer = nosecret(UnitIsPlayer(unit)) and true or false
    info.firstName = nosecret((UnitName(unit)))
    info.name, info.realm = platformHelper.UnitNameAndRealm(unit)
    info.name, info.realm = nosecret(info.name), nosecret(info.realm)
    info.level = nosecret(UnitLevel(unit)) or 0
    info.levelText = info.level >= 0 and tostring(info.level) or "??"
    info.className, info.classFile = UnitClass(unit)
    info.raceName, info.raceFile = UnitRace(unit)
    info.factionGroup, info.factionName = UnitFactionGroup(unit)
    info.reaction = nosecret(UnitReaction(unit, "player"))
    info.classification = nosecret(UnitClassification(unit))
    info.creature = nosecret(UnitCreatureType(unit))
    info.dead = nosecret(UnitIsDeadOrGhost(unit)) and true or false
    if info.isPlayer then
        info.guild, info.guildRank = GetGuildInfo(unit)
        info.title, info.titleAfter = UnitProfileFormatter.titleParts(info.name, nosecret(UnitPVPName(unit)))
        if not info.title and info.firstName and info.firstName ~= info.name then
            info.title, info.titleAfter = UnitProfileFormatter.titleParts(info.firstName, nosecret(UnitPVPName(unit)))
        end
        info.afk = nosecret(UnitIsAFK(unit))
        info.dnd = nosecret(UnitIsDND(unit))
        info.offline = not nosecret(UnitIsConnected(unit))
        info.zone = UnitProfileFormatter.groupZone(unit)
        local role = _G.UnitGroupRolesAssigned and nosecret(_G.UnitGroupRolesAssigned(unit))
        info.role = (role and role ~= "NONE") and role or nil
    end
    return info
end

function UnitProfileFormatter.playerRows(info, lineList, levelIdx)
    local unit = info.unit
    local rowWidgets = {}
    local crVal, collapsedGroups, checkWidget = UnitProfileFormatter.classColor(info.classFile)
    local raid = GetRaidTargetIndex and nosecret(GetRaidTargetIndex(unit))
    local raidIcon = raid and _G.ICON_LIST and _G.ICON_LIST[raid] and (_G.ICON_LIST[raid] .. "0|t")

    local rawDisplayName = nosecret(UnitPVPName(unit)) or info.name or info.firstName or UnitProfileFormatter.plain(lineList[1].left) or ""
    rawDisplayName = strtrim((rawDisplayName:gsub("^%s*<[^>]+>%s*", ""):gsub("%s*<[^>]+>%s*$", "")))
    if rawDisplayName == "" then
        rawDisplayName = info.firstName or info.name or UnitProfileFormatter.plain(lineList[1].left) or ""
    end
    local name = UnitProfileFormatter.paint(rawDisplayName, UnitProfileFormatter.hex(crVal, collapsedGroups, checkWidget))
    rowWidgets[1] = UnitProfileFormatter.join({
        UnitProfileFormatter.friendBadge(unit), raidIcon,
        info.role and addon.icons[info.role],
        nosecret(UnitIsPVPFreeForAll(unit)) and addon.icons.pvp or nil,
        info.factionGroup and addon.icons[info.factionGroup],
        addon:GetClassIcon(info.classFile),
        name,
        info.realm and info.realm ~= "" and UnitProfileFormatter.paint("· " .. info.realm, "4bc8e8") or nil,
        info.afk and UnitProfileFormatter.paint("[" .. (_G.AFK or "AFK") .. "]", "f1bd57") or nil,
        info.dnd and UnitProfileFormatter.paint("[" .. (_G.DND or "DND") .. "]", "ea837e") or nil,
        info.offline and UnitProfileFormatter.paint("[" .. (_G.FRIENDS_LIST_OFFLINE or "Offline") .. "]", "8899a6") or nil,
    })

    if info.guild then
        rowWidgets[#rowWidgets + 1] = UnitProfileFormatter.join({ "|cffAEE26A◆|r", UnitProfileFormatter.paint("<" .. info.guild .. ">", "c9a4ef"),
            info.guildRank and UnitProfileFormatter.paint("· " .. info.guildRank, MUTED_HEX) or nil })
    end

    local factionHex = "e5b200"
    if info.factionGroup ~= "Neutral" then
        factionHex = (info.factionGroup == UnitFactionGroup("player")) and "00cc33" or "dd3300"
    end
    rowWidgets[#rowWidgets + 1] = UnitProfileFormatter.join({
        UnitProfileFormatter.paint("Lv." .. info.levelText, UnitProfileFormatter.hex(UnitProfileFormatter.levelColor(info.level))),
        addon:GetRaceIcon(info.raceFile),
        info.raceName and UnitProfileFormatter.paint(info.raceName, TEXT_HEX) or nil,
        info.className and UnitProfileFormatter.paint(info.className, UnitProfileFormatter.hex(crVal, collapsedGroups, checkWidget)) or nil,
        info.factionName and UnitProfileFormatter.paint("[" .. info.factionName .. "]", factionHex) or nil,
    })

    if info.zone then
        rowWidgets[#rowWidgets + 1] = UnitProfileFormatter.join({ "|cff4BC8E8◆|r", UnitProfileFormatter.paint(info.zone, MUTED_HEX) })
    end
    return rowWidgets
end

function UnitProfileFormatter.npcRows(info, lineList, levelIdx)
    local unit = info.unit
    local rowWidgets = {}
    local raid = GetRaidTargetIndex and nosecret(GetRaidTargetIndex(unit))
    local raidIcon = raid and _G.ICON_LIST and _G.ICON_LIST[raid] and (_G.ICON_LIST[raid] .. "0|t")
    local quest = _G.UnitIsQuestBoss and nosecret(_G.UnitIsQuestBoss(unit)) and addon.icons.questboss or nil
    local ncVal = lineList[1].leftColor
    rowWidgets[1] = UnitProfileFormatter.join({ raidIcon, quest, UnitProfileFormatter.paint(info.name or UnitProfileFormatter.plain(lineList[1].left), UnitProfileFormatter.hex(ncVal[1], ncVal[2], ncVal[3])) })

    if levelIdx and levelIdx >= 3 and lineList[2] and lineList[2].left and lineList[2].left ~= "" then
        rowWidgets[#rowWidgets + 1] = UnitProfileFormatter.join({ "|cffAEE26A◇|r", UnitProfileFormatter.paint("<" .. UnitProfileFormatter.plain(lineList[2].left) .. ">", "7adad4") })
    end

    local classification = info.classification
    local tag
    if info.level < 0 or classification == "worldboss" then
        tag = UnitProfileFormatter.paint("[★ " .. (_G.BOSS or "Boss") .. "]", "ea837e")
    elseif classification == "rareelite" or classification == "rare" then
        tag = UnitProfileFormatter.paint("[◆ " .. (_G.GARRISON_MISSION_RARE or _G.ITEM_QUALITY3_DESC or "Rare") .. "]", "c9a4ef")
    elseif classification == "elite" then
        tag = UnitProfileFormatter.paint("[☆ " .. (_G.ELITE or "Elite") .. "]", "f1bd57")
    end
    local srVal, sgVal, sbVal = UnitSelectionColor(unit)
    local reactionLabel = info.reaction and _G["FACTION_STANDING_LABEL" .. info.reaction]
    rowWidgets[#rowWidgets + 1] = UnitProfileFormatter.join({
        UnitProfileFormatter.paint("Lv." .. info.levelText, UnitProfileFormatter.hex(UnitProfileFormatter.levelColor(info.level))),
        tag,
        info.creature and UnitProfileFormatter.paint("· " .. info.creature, UnitProfileFormatter.hex(nosecret(srVal) or 1, nosecret(sgVal) or 1, nosecret(sbVal) or 1)) or nil,
        reactionLabel and UnitProfileFormatter.paint("[" .. reactionLabel .. "]", UnitProfileFormatter.hex(UnitProfileFormatter.reactionColor(info.reaction))) or nil,
    })
    return rowWidgets
end

function UnitProfileFormatter.writeLines(tip, rowWidgets, kept, gray)
    local grandTotal = #rowWidgets + #kept
    while tip:NumLines() < grandTotal do tip:AddLine(" ") end
    local translationMap, tgVal, tbVal = addon:GetRGBColor(TEXT_HEX)
    for index = 1, tip:NumLines() do
        local left, right = lineRegions(tip, index)
        if index <= #rowWidgets then
            left:SetText(gray and ("|cff999999" .. UnitProfileFormatter.plain(rowWidgets[index]) .. "|r") or rowWidgets[index])
            left:SetTextColor(translationMap, tgVal, tbVal)
            left:Show()
            if right then right:SetText(nil); right:Hide() end
        elseif index <= grandTotal then
            local line = kept[index - #rowWidgets]
            left:SetText(line.left)
            left:SetTextColor(unpack(line.leftColor))
            left:Show()
            if right then
                if line.right then
                    right:SetText(line.right)
                    right:SetTextColor(unpack(line.rightColor))
                    right:Show()
                else
                    right:SetText(nil); right:Hide()
                end
            end
        else
            left:SetText(nil)
            if right then right:SetText(nil); right:Hide() end
        end
    end
    tip.ezWoWTooltipUnitRows = #rowWidgets
end

function UnitProfileFormatter.recolorCard(tip, info, cfg)
    local general = addon.db.general
    local backdropTex = general.background
    local opacityVal = (cfg.background and tonumber(cfg.background.alpha)) or backdropTex[4]
    if info.dead and cfg.grayForDead then
        addon:ApplyTooltipBorderColor(tip, 0.6, 0.6, 0.6, 1)
        addon:ApplyTooltipBackgroundColor(tip, 0.1, 0.1, 0.1, opacityVal)
        return
    end
    addon:ApplyTooltipBackgroundColor(tip, backdropTex[1], backdropTex[2], backdropTex[3], opacityVal)
    if info.isPlayer and cfg.coloredBorder == "class" then
        local r, g, b = UnitProfileFormatter.classColor(info.classFile)
        addon:ApplyTooltipBorderColor(tip, r, g, b, 1)
    elseif not info.isPlayer and cfg.coloredBorder == "reaction" then
        local r, g, b = UnitProfileFormatter.reactionColor(info.reaction)
        addon:ApplyTooltipBorderColor(tip, r, g, b, 1)
    end
end

function UnitProfileFormatter.unitLabel(unit)
    if nosecret(UnitIsUnit(unit, "player")) then
        return UnitProfileFormatter.paint(">> " .. (_G.YOU or "You") .. " <<", "ea837e")
    end
    local name = nosecret((UnitName(unit)))
    if not name then return end
    if nosecret(UnitIsPlayer(unit)) then
        local _, classFile = UnitClass(unit)
        return UnitProfileFormatter.paint(name, UnitProfileFormatter.hex(UnitProfileFormatter.classColor(classFile)))
    end
    return UnitProfileFormatter.paint(name, UnitProfileFormatter.hex(UnitProfileFormatter.reactionColor(nosecret(UnitReaction(unit, "player")))))
end

function UnitProfileFormatter.targetText(unit)
    local targetKey = unit .. "target"
    if not nosecret(UnitExists(targetKey)) then return end
    local who = UnitProfileFormatter.unitLabel(targetKey)
    if not who then return end
    return TAG_TARGET .. UnitProfileFormatter.paint((_G.TARGET or "Target") .. ":", MUTED_HEX) .. " " .. who
end

function UnitProfileFormatter.targetedByText(unit)
    local names, totalCount = {}, 0
    local function check(member)
        if nosecret(UnitExists(member)) and nosecret(UnitIsUnit(member .. "target", unit)) then
            totalCount = totalCount + 1
            if #names < 4 then
                local who = UnitProfileFormatter.unitLabel(member)
                if who then names[#names + 1] = who end
            end
        end
    end
    if IsInRaid() then
        for index = 1, GetNumGroupMembers() do check("raid" .. index) end
    elseif IsInGroup() then
        check("player")
        for index = 1, 4 do check("party" .. index) end
    end
    if totalCount == 0 then return end
    local caption = (addon.L and rawget(addon.L, "TargetBy")) or UnitProfileFormatter.formatLocalizedLabel("targetBy")
    local itemList = table.concat(names, ", ")
    if totalCount > #names then itemList = itemList .. UnitProfileFormatter.paint(" +" .. (totalCount - #names), MUTED_HEX) end
    return TAG_TARGETBY .. UnitProfileFormatter.paint(caption .. " (" .. totalCount .. "):", MUTED_HEX) .. " " .. itemList
end

function UnitProfileFormatter.refreshTargetLines(tip, unit, cfg)
    local changed = false
    local function put(pattern, text)
        local line = addon:FindLine(tip, pattern)
        if text then
            if not line or nosecret(line:GetText()) ~= text then
                addon:InsertOrUpdateTooltipLine(tip, pattern, text)
                changed = true
            end
        elseif line then
            addon:StripMatchingTooltipLine(tip, pattern)
            changed = true
        end
    end
    put(PAT_TARGET, cfg.showTarget and UnitProfileFormatter.targetText(unit) or nil)
    put(PAT_TARGETBY, cfg.showTargetBy and UnitProfileFormatter.targetedByText(unit) or nil)
    return changed
end

local SLOT_WEIGHT = {
    [1] = 1.0,  [3] = 0.75, [5] = 1.0,  [7] = 1.0,                
    [6] = 0.75, [8] = 0.75, [10] = 0.75,                          
    [2] = 0.55, [9] = 0.55, [11] = 0.55, [12] = 0.55,             
    [13] = 0.55, [14] = 0.55, [15] = 0.55,                        
    [16] = 1.0, [17] = 1.0, [18] = 0.35,                          
}
local QUALITY_FACTOR = { [0] = 0.4, [1] = 0.6, [2] = 0.85, [3] = 1.0, [4] = 1.15, [5] = 1.3, [6] = 1.3, [7] = 1.0 }
local SCORE_TIERS = {
    { 400, "9d9d9d" }, { 700, "ffffff" }, { 950, "1eff00" }, { 1150, "0070dd" }, { 1400, "a335ee" },
}
local MIN_SLOTS_FOR_OTHERS = 8

function UnitProfileFormatter.itemLevelOf(link)
    local detailed = _G.C_Item and _G.C_Item.GetDetailedItemLevelInfo
    local level = detailed and detailed(link)
    if not level and platformHelper.GetItemInfo then level = select(4, platformHelper.GetItemInfo(link)) end
    return tonumber(level)
end

function addon:CalculateUnitAverageItemLevel(unit)
    local hasSelf = nosecret(UnitIsUnit(unit, "player"))
    local grandTotal, slots, waiting = 0, 0, false
    local mainHandTwoHanded, offHandUsed = false, false
    local entryList = {}
    for slot, weight in pairs(SLOT_WEIGHT) do
        local link = GetInventoryItemLink(unit, slot)
        link = nosecret(link)
        if link then
            local _, _, quality, _, _, _, _, _, equipLoc = platformHelper.GetItemInfo(link)
            local level = UnitProfileFormatter.itemLevelOf(link)
            if not quality or not level then
                waiting = true
            else
                entryList[slot] = { weight = weight, level = level, quality = quality }
                if slot == 16 and equipLoc == "INVTYPE_2HWEAPON" then mainHandTwoHanded = true end
                if slot == 17 then offHandUsed = true end
            end
        end
    end
    for slot, recordEntry in pairs(entryList) do
        local weight = recordEntry.weight
        if slot == 16 and mainHandTwoHanded and not offHandUsed then weight = 2.0 end
        grandTotal = grandTotal + weight * recordEntry.level * (QUALITY_FACTOR[recordEntry.quality] or 1)
        slots = slots + 1
    end
    if waiting then return nil, true end
    if slots == 0 or (not hasSelf and slots < MIN_SLOTS_FOR_OTHERS) then return nil end
    return math.floor(grandTotal + 0.5)
end

function UnitProfileFormatter.scoreColor(score)
    for _, tier in ipairs(SCORE_TIERS) do
        if score < tier[1] then return tier[2] end
    end
    return "ff8000"
end

function addon:GetGearScoreColorHex(score)
    return UnitProfileFormatter.scoreColor(tonumber(score) or 0)
end

local inspectAsked = {}
function UnitProfileFormatter.refreshGearLine(tip, unit, cfg)
    -- Standalone gear score line is disabled; gear score is displayed inline on the Item Level line: 아이템 레벨: 34.0(414)
    addon:StripMatchingTooltipLine(tip, PAT_GEAR)
    if not cfg or not cfg.showGearScore then return end
    local score = addon:CalculateUnitAverageItemLevel(unit)
    if score then return end
    local talentsOff = addon.db.unit.player.showTalent == false
    local guid = nosecret(UnitGUID(unit))
    if talentsOff and guid and not inspectAsked[guid] and not InCombatLockdown()
        and _G.CanInspect and _G.CanInspect(unit) and _G.NotifyInspect then
        inspectAsked[guid] = true
        pcall(_G.NotifyInspect, unit)
    end
end

function UnitProfileFormatter.dumpTooltip(tip, caption)
    print(("|cffAEE26AEzWoW - Tooltip|r debug (%s): %d lines"):format(caption, tip:NumLines()))
    for index = 1, tip:NumLines() do
        local left, right = lineRegions(tip, index)
        local function show(v)
            if v == nil then return "nil" end
            if issecret(v) then return "<protected>" end
            return (tostring(v):gsub("|", "||"))
        end
        print(("  %d: [%s] [%s]"):format(index, show(left and left:GetText()), show(right and right:GetText())))
    end
end

local current = { tip = nil, unit = nil }

function addon:PopulateUnitTooltipCard(tip, unit)
    if not self.db or not unit or self:IsUnitRestricted(unit) then return end
    local lineList = UnitProfileFormatter.extractLines(tip)
    if not lineList or not lineList[1] or not lineList[1].left then return end

    local info = UnitProfileFormatter.collect(unit)
    local cfg = info.isPlayer and self.db.unit.player or self.db.unit.npc
    local levelIdx = UnitProfileFormatter.locateLevelLine(lineList, info)

    local drop = { [1] = true }
    if levelIdx then drop[levelIdx] = true end
    for index = 2, #lineList do
        local text = UnitProfileFormatter.plain(lineList[index].left)
        if text then
            local trimmed = strtrim(text)
            if info.isPlayer and info.guild and trimmed:find(info.guild, 1, true) then drop[index] = true end
            if info.isPlayer and info.className and trimmed == info.className then drop[index] = true end
            if info.isPlayer and info.raceName and trimmed == info.raceName then drop[index] = true end
            if info.isPlayer and info.raceName and info.className and trimmed == (info.raceName .. " " .. info.className) then drop[index] = true end
            if info.factionName and trimmed == info.factionName then drop[index] = true end
            if _G.PVP and trimmed == _G.PVP then drop[index] = true end
        end
    end
    if not info.isPlayer and levelIdx and levelIdx >= 3 then drop[2] = true end

    local rowWidgets = info.isPlayer and UnitProfileFormatter.playerRows(info, lineList, levelIdx) or UnitProfileFormatter.npcRows(info, lineList, levelIdx)
    local kept = {}
    for index = 2, #lineList do
        if not drop[index] then kept[#kept + 1] = lineList[index] end
    end

    UnitProfileFormatter.writeLines(tip, rowWidgets, kept, info.dead and cfg.grayForDead)
    UnitProfileFormatter.recolorCard(tip, info, cfg)
    UnitProfileFormatter.refreshTargetLines(tip, unit, cfg)
    if info.isPlayer then UnitProfileFormatter.refreshGearLine(tip, unit, cfg) else self:StripMatchingTooltipLine(tip, PAT_GEAR) end

    current.tip, current.unit = tip, unit
end

function addon:InsertOrUpdateTooltipLine(tip, pattern, text)
    if not tip or not text then return end
    local existing = self:FindLine(tip, pattern)
    if existing then
        existing:SetText(text)
        existing:Show()
        return existing
    end
    local first = (tip.ezWoWTooltipUnitRows or 1) + 1
    for index = first, tip:NumLines() do
        local left, right = lineRegions(tip, index)
        local leftPos = left and nosecret(left:GetText())
        local r = right and nosecret(right:GetText())
        if left and (not leftPos or leftPos == "" or leftPos == " ") and (not r or r == "" or r == " ") then
            left:SetText(text)
            left:Show()
            if right then right:SetText(nil); right:Hide() end
            return left
        end
    end
    tip:AddLine(text)
end

function addon:StripMatchingTooltipLine(tip, pattern)
    if not tip then return end
    local left, _, right = self:FindLine(tip, pattern)
    if left then
        left:SetText(nil)
        if right then right:SetText(nil); right:Hide() end
    end
end

bus:attachTrigger("tooltip:unit", function(_, tip, unit) addon:PopulateUnitTooltipCard(tip, unit) end)

bus:attachTrigger("tooltip:cleared, tooltip:hide", function(_, tip)
    tip.ezWoWTooltipUnitRows = nil
    if current.tip == tip then current.tip, current.unit = nil, nil end
end)

platformHelper.AddTooltipPostCall("Unit", "OnTooltipSetUnit", function(tip)
    if not tip or not tip.ezCard or (tip.IsForbidden and tip:IsForbidden()) or not tip.GetUnit then return end
    tip.ezWoWTooltipUnitRows = nil
    local _, unit = tip:GetUnit()
    if not unit or addon:IsUnitRestricted(unit) then return end
    local debug = addon.debugNextUnit and tip == GameTooltip
    if debug then
        addon.debugNextUnit = false
        UnitProfileFormatter.dumpTooltip(tip, "game")
    end
    bus:trigger("tooltip:unit", tip, unit)
    bus:trigger("tooltip:unit:post", tip, unit)
    if debug then
        UnitProfileFormatter.dumpTooltip(tip, "EzWoW")
        bus:after(0.5, function() UnitProfileFormatter.dumpTooltip(tip, "0.5s later") end)
    end
    if tip:IsShown() then tip:Show() end
    bus:trigger("tooltip:layout", tip)
end)

local elapsedSince = 0
GameTooltip:HookScript("OnUpdate", function(tip, elapsed)
    elapsedSince = elapsedSince + (elapsed or 0)
    if elapsedSince < 0.3 then return end
    elapsedSince = 0
    if current.tip ~= tip or not tip.ezWoWTooltipUnitRows or not addon.db then return end
    local unit = current.unit
    if not unit or not nosecret(UnitExists(unit)) or addon:IsUnitRestricted(unit) then return end
    local cfg = nosecret(UnitIsPlayer(unit)) and addon.db.unit.player or addon.db.unit.npc
    if UnitProfileFormatter.refreshTargetLines(tip, unit, cfg) then tip:Show() end
end)

bus:attachEvent("INSPECT_READY", function(_, guid)
    guid = nosecret(guid)
    local tip, unit = current.tip, current.unit
    if not tip or not unit or not tip:IsShown() or not addon.db then return end
    if guid and nosecret(UnitGUID(unit)) ~= guid then return end
    if not nosecret(UnitIsPlayer(unit)) then return end
    UnitProfileFormatter.refreshGearLine(tip, unit, addon.db.unit.player)
    tip:Show()
end)
