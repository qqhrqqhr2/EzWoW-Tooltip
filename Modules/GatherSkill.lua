--===========================================================================
-- EzWoW - Tooltip
-- Modules/GatherSkill.lua : Required Gathering Skill on Herb, Ore & Skinnable Tooltips
--===========================================================================
local _, ns = ...
local type, pairs, ipairs, tonumber, tostring, select, pcall = type, pairs, ipairs, tonumber, tostring, select, pcall

local GatherSkill = ns.GatherSkill or {}
ns.GatherSkill = GatherSkill
local EventDispatcher = ns.events
local addon = EzWoW_Tooltip
local compat = ns.compat
local nosecret = compat.nosecret
local format = string.format

local HERBALISM, MINING, SKINNING = 182, 186, 393

-- Apprentice spell of each skill line: its name is the skill's name in the
-- client language when the player has not learned it.
local SKILL_SPELL = { [HERBALISM] = 2366, [MINING] = 2575, [SKINNING] = 8613 }
local SKILL_LOCALE_KEY = { [HERBALISM] = "gatherHerbalism", [MINING] = "gatherMining", [SKINNING] = "gatherSkinning" }

-----------------------------------------------------------------------------
-- Node data. World objects carry no ID on their tooltip, so a node is found
-- by its name: the English and Korean node names below, plus (for herbs) the
-- herb item's name in the client language, which is the node's name in most
-- languages.
-----------------------------------------------------------------------------

-- Herb item ID = { required skill, node name (enUS), node name (koKR) }
local HERB_NODES = {
    [2447]  = { 1,   "Peacebloom",          "평온초" },
    [765]   = { 1,   "Silverleaf",          "은엽수 덤불" },
    [2449]  = { 15,  "Earthroot",           "뱀뿌리" },
    [785]   = { 50,  "Mageroyal",           "마법초" },
    [2450]  = { 70,  "Briarthorn",          "찔레가시" },
    [3820]  = { 85,  "Stranglekelp",        "갈래물풀" },
    [2453]  = { 100, "Bruiseweed",          "생채기풀" },
    [3355]  = { 115, "Wild Steelbloom",     "야생 철쭉" },
    [3369]  = { 120, "Grave Moss",          "무덤이끼" },
    [3356]  = { 125, "Kingsblood",          "왕꽃잎풀" },
    [3357]  = { 150, "Liferoot",            "생명의 뿌리" },
    [3818]  = { 160, "Fadeleaf",            "미명초잎" },
    [3821]  = { 170, "Goldthorn",           "황금가시" },
    [3358]  = { 185, "Khadgar's Whisker",   "카드가의 수염" },
    [3819]  = { 195, "Wintersbite",         "용 송곳니" },
    [4625]  = { 205, "Firebloom",           "화염초" },
    [8831]  = { 210, "Purple Lotus",        "보라 연꽃" },
    [8836]  = { 220, "Arthas' Tears",       "아서스의 눈물" },
    [8838]  = { 230, "Sungrass",            "태양풀" },
    [8839]  = { 235, "Blindweed",           "실명초" },
    [8845]  = { 245, "Ghost Mushroom",      "유령버섯" },
    [8846]  = { 250, "Gromsblood",          "그롬의 피" },
    [13464] = { 260, "Golden Sansam",       "황금 산삼" },
    [13463] = { 270, "Dreamfoil",           "꿈풀" },
    [13465] = { 280, "Mountain Silversage", "은초롱이" },
    [13466] = { 285, "Plaguebloom",         "슬픔이끼" },
    [13467] = { 290, "Icecap",              "얼음송이" },
    [13468] = { 300, "Black Lotus",         "검은 연꽃" },
}

-- { required skill, node name (enUS), node name (koKR) or false }
-- Variants such as ooze-covered veins are also found by their base name at
-- the end of the node name (see lookupNode).
local ORE_NODES = {
    { 1,   "Copper Vein",                     "구리 광맥" },
    { 65,  "Tin Vein",                        "주석 광맥" },
    { 65,  "Incendicite Mineral Vein",        "발연 광맥" },
    { 75,  "Silver Vein",                     "은 광맥" },
    { 75,  "Lesser Bloodstone Deposit",       "저급 혈석 광맥" },
    { 125, "Iron Deposit",                    "철 광맥" },
    { 150, "Indurium Mineral Vein",           "인듀리움 광맥" },
    { 155, "Gold Vein",                       "금 광맥" },
    { 175, "Mithril Deposit",                 "미스릴 광맥" },
    { 230, "Truesilver Deposit",              "진은 광맥" },
    { 230, "Dark Iron Deposit",               "검은무쇠 광맥" },
    { 245, "Small Thorium Vein",              "작은 토륨 광맥" },
    { 275, "Rich Thorium Vein",               "풍부한 토륨 광맥" },
    { 75,  "Ooze Covered Silver Vein",        false },
    { 155, "Ooze Covered Gold Vein",          false },
    { 175, "Ooze Covered Mithril Deposit",    false },
    { 230, "Ooze Covered Truesilver Deposit", false },
    { 245, "Ooze Covered Thorium Vein",       false },
    { 275, "Ooze Covered Rich Thorium Vein",  false },
    { 275, "Hakkari Thorium Vein",            false },
}

-----------------------------------------------------------------------------
-- Name table: node name -> { skill line, required skill }
-----------------------------------------------------------------------------
local nodeByName
local pendingHerbItems = {}
local lookupMemo, lookupMemoCount, LOOKUP_MEMO_MAX = {}, 0, 400
local itemLoadFrame = CreateFrame("Frame")

function GatherSkill.forgetLookups()
    wipe(lookupMemo)
    lookupMemoCount = 0
end

function GatherSkill.addHerbItemName(itemID)
    local itemAPI = _G.C_Item
    if not itemAPI or type(itemAPI.GetItemNameByID) ~= "function" then return true end
    local isCallOk, itemName = pcall(itemAPI.GetItemNameByID, itemID)
    itemName = isCallOk and nosecret(itemName) or nil
    if type(itemName) ~= "string" or itemName == "" then return false end
    if not nodeByName[itemName] then
        nodeByName[itemName] = { HERBALISM, HERB_NODES[itemID][1] }
    end
    return true
end

function GatherSkill.buildNodeTable()
    nodeByName = {}
    for _, oreEntry in ipairs(ORE_NODES) do
        local nodeInfo = { MINING, oreEntry[1] }
        nodeByName[oreEntry[2]] = nodeInfo
        if oreEntry[3] then nodeByName[oreEntry[3]] = nodeInfo end
    end
    for _, herbEntry in pairs(HERB_NODES) do
        local nodeInfo = { HERBALISM, herbEntry[1] }
        nodeByName[herbEntry[2]] = nodeInfo
        nodeByName[herbEntry[3]] = nodeInfo
    end
    local itemAPI = _G.C_Item
    for itemID in pairs(HERB_NODES) do
        if not GatherSkill.addHerbItemName(itemID) then
            pendingHerbItems[itemID] = true
            if itemAPI and type(itemAPI.RequestLoadItemDataByID) == "function" then
                pcall(itemAPI.RequestLoadItemDataByID, itemID)
            end
        end
    end
    if next(pendingHerbItems) then
        pcall(itemLoadFrame.RegisterEvent, itemLoadFrame, "ITEM_DATA_LOAD_RESULT")
    end
end

itemLoadFrame:SetScript("OnEvent", function(self, _, itemID, success)
    itemID = nosecret(itemID)
    if not itemID or not pendingHerbItems[itemID] then return end
    if nosecret(success) and nodeByName then
        GatherSkill.addHerbItemName(itemID)
        GatherSkill.forgetLookups()
    end
    pendingHerbItems[itemID] = nil
    if not next(pendingHerbItems) then self:UnregisterEvent("ITEM_DATA_LOAD_RESULT") end
end)

-- Plain node name: texture/atlas markup and colour codes removed, trimmed.
function GatherSkill.cleanName(rawText)
    local plainText = rawText:gsub("|T.-|t", ""):gsub("|A.-|a", ""):gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", "")
    return (plainText:match("^%s*(.-)%s*$"))
end

-- Exact name first; then, for ore variants ("Ooze Covered Silver Vein"), the
-- longest run of trailing words that is a known vein name.
function GatherSkill.lookupNode(nodeName)
    if not nodeByName then GatherSkill.buildNodeTable() end
    local memoHit = lookupMemo[nodeName]
    if memoHit ~= nil then return memoHit or nil end
    local nodeInfo = nodeByName[nodeName]
    if not nodeInfo then
        local remainder = nodeName:match("^%S+%s+(.+)$")
        while remainder do
            local candidate = nodeByName[remainder]
            if candidate and candidate[1] == MINING then
                nodeInfo = candidate
                break
            end
            remainder = remainder:match("^%S+%s+(.+)$")
        end
    end
    if lookupMemoCount >= LOOKUP_MEMO_MAX then GatherSkill.forgetLookups() end
    lookupMemo[nodeName] = nodeInfo or false
    lookupMemoCount = lookupMemoCount + 1
    return nodeInfo
end

-----------------------------------------------------------------------------
-- Player skill
-----------------------------------------------------------------------------
local skillCache, skillCacheTime = nil, 0
local SKILL_CACHE_SECONDS = 10

function GatherSkill.forgetSkills()
    skillCache = nil
end

function GatherSkill.readSkills()
    local foundSkills = {}
    if type(_G.GetProfessions) == "function" and type(_G.GetProfessionInfo) == "function" then
        local profIndices = { pcall(_G.GetProfessions) }
        if profIndices[1] then
            for slotIndex = 2, 6 do
                local profIndex = nosecret(profIndices[slotIndex])
                if profIndex then
                    local isCallOk, profName, _, profRank, _, _, _, profLine = pcall(_G.GetProfessionInfo, profIndex)
                    profLine, profRank, profName = nosecret(profLine), nosecret(profRank), nosecret(profName)
                    if isCallOk and SKILL_SPELL[profLine] and type(profRank) == "number" then
                        foundSkills[profLine] = { rank = profRank, name = profName }
                    end
                end
            end
        end
    end
    -- Older skill list: matched by the skill's name.
    if type(_G.GetNumSkillLines) == "function" and type(_G.GetSkillLineInfo) == "function" then
        local okCount, lineCount = pcall(_G.GetNumSkillLines)
        lineCount = okCount and nosecret(lineCount) or 0
        for skillLine in pairs(SKILL_SPELL) do
            if not foundSkills[skillLine] then
                local wantedName = GatherSkill.skillName(skillLine)
                for lineIndex = 1, lineCount do
                    local isCallOk, lineName, isHeader, _, lineRank = pcall(_G.GetSkillLineInfo, lineIndex)
                    lineName, lineRank = nosecret(lineName), nosecret(lineRank)
                    if isCallOk and not isHeader and lineName == wantedName and type(lineRank) == "number" then
                        foundSkills[skillLine] = { rank = lineRank, name = lineName }
                        break
                    end
                end
            end
        end
    end
    return foundSkills
end

function GatherSkill.currentSkills()
    local nowTime = (type(_G.GetTime) == "function" and _G.GetTime()) or 0
    if not skillCache or nowTime - skillCacheTime > SKILL_CACHE_SECONDS then
        skillCache = GatherSkill.readSkills()
        skillCacheTime = nowTime
    end
    return skillCache
end

local skillNameCache = {}
function GatherSkill.skillName(skillLine)
    local cachedName = skillNameCache[skillLine]
    if cachedName then return cachedName end
    local resolvedName
    local tradeAPI = _G.C_TradeSkillUI
    if tradeAPI and type(tradeAPI.GetTradeSkillDisplayName) == "function" then
        local isCallOk, displayName = pcall(tradeAPI.GetTradeSkillDisplayName, skillLine)
        displayName = isCallOk and nosecret(displayName) or nil
        if type(displayName) == "string" and displayName ~= "" then resolvedName = displayName end
    end
    if not resolvedName then
        local spellAPI = _G.C_Spell
        if spellAPI and type(spellAPI.GetSpellName) == "function" then
            local isCallOk, spellName = pcall(spellAPI.GetSpellName, SKILL_SPELL[skillLine])
            spellName = isCallOk and nosecret(spellName) or nil
            if type(spellName) == "string" and spellName ~= "" then resolvedName = spellName end
        end
    end
    if resolvedName then
        skillNameCache[skillLine] = resolvedName
        return resolvedName
    end
    return addon.EL(SKILL_LOCALE_KEY[skillLine])
end

-- Classic difficulty colours: red below the requirement, then orange,
-- yellow, green and grey at +25 / +50 / +100.
function GatherSkill.skillColor(playerSkill, requiredSkill)
    if not playerSkill or playerSkill < requiredSkill then return "ff2020" end
    local overBy = playerSkill - requiredSkill
    if overBy < 25 then return "ff8040" end
    if overBy < 50 then return "ffff00" end
    if overBy < 100 then return "40bf40" end
    return "808080"
end

function GatherSkill.composeLine(skillLine, requiredSkill, nodeLabel)
    local skillInfo = GatherSkill.currentSkills()[skillLine]
    local displayName = (skillInfo and type(skillInfo.name) == "string" and skillInfo.name ~= "" and skillInfo.name) or GatherSkill.skillName(skillLine)
    local lineText
    if skillInfo then
        lineText = format(addon.EL("gatherReqFmt"), displayName, requiredSkill, skillInfo.rank)
    else
        lineText = format(addon.EL("gatherReqNoSkillFmt"), displayName, requiredSkill)
    end
    if nodeLabel then lineText = nodeLabel .. ": " .. lineText end
    return "|cff" .. GatherSkill.skillColor(skillInfo and skillInfo.rank, requiredSkill) .. lineText .. "|r"
end

-- Skinning requirement by creature level (classic rule).
function GatherSkill.skinningRequirement(unitLevel)
    if unitLevel < 10 then return 1 end
    if unitLevel <= 20 then return math.max(1, (unitLevel - 10) * 10) end
    return unitLevel * 5
end

-----------------------------------------------------------------------------
-- Tooltip hooks
-----------------------------------------------------------------------------
function GatherSkill.isEnabled()
    local generalCfg = addon.db and addon.db.general
    return generalCfg ~= nil and generalCfg.showGatherSkill ~= false
end

-- Left texts of the tooltip: from the tooltip data when present, else from
-- the tooltip's own lines.
function GatherSkill.collectLeftTexts(tipFrame, tooltipData)
    local textList = {}
    local dataLines = type(tooltipData) == "table" and nosecret(tooltipData.lines)
    if type(dataLines) == "table" then
        for _, lineData in ipairs(dataLines) do
            local leftText = type(lineData) == "table" and nosecret(lineData.leftText)
            if type(leftText) == "string" then textList[#textList + 1] = leftText end
        end
        if #textList > 0 then return textList end
    end
    if type(tipFrame.NumLines) ~= "function" then return textList end
    for lineIndex = 1, tipFrame:NumLines() do
        local leftRegion = addon.LineRegions(tipFrame, lineIndex)
        local leftText = leftRegion and nosecret(leftRegion:GetText())
        if type(leftText) == "string" then textList[#textList + 1] = leftText end
    end
    return textList
end

function GatherSkill.onObjectTooltip(tipFrame, tooltipData)
    if not GatherSkill.isEnabled() or not addon.IsDecoratableTooltip(tipFrame) then return end
    local leftTexts = GatherSkill.collectLeftTexts(tipFrame, tooltipData)
    local titleText = leftTexts[1]
    if not titleText then return end
    local nodeInfo = GatherSkill.lookupNode(GatherSkill.cleanName(titleText))
    if not nodeInfo then return end
    tipFrame:AddLine(GatherSkill.composeLine(nodeInfo[1], nodeInfo[2]))
    tipFrame:Show()
end

-- The minimap tooltip lists every tracked node under the cursor, one name
-- per line (several names can share one text, split by line breaks).
function GatherSkill.onMinimapTooltip(tipFrame, tooltipData)
    if not GatherSkill.isEnabled() or not addon.IsDecoratableTooltip(tipFrame) then return end
    local foundNodes, seenNames = {}, {}
    for _, leftText in ipairs(GatherSkill.collectLeftTexts(tipFrame, tooltipData)) do
        local splitText = leftText:gsub("|n", "\n") .. "\n"
        for namePart in splitText:gmatch("(.-)\n") do
            local nodeName = GatherSkill.cleanName(namePart)
            if nodeName ~= "" and not seenNames[nodeName] then
                seenNames[nodeName] = true
                local nodeInfo = GatherSkill.lookupNode(nodeName)
                if nodeInfo then foundNodes[#foundNodes + 1] = { nodeName, nodeInfo } end
            end
        end
    end
    if #foundNodes == 0 then return end
    local labelEach = #foundNodes > 1
    for _, foundEntry in ipairs(foundNodes) do
        tipFrame:AddLine(GatherSkill.composeLine(foundEntry[2][1], foundEntry[2][2], labelEach and foundEntry[1] or nil))
    end
    tipFrame:Show()
end

-- Dead creatures that can be skinned carry the game's "Skinnable" line.
function GatherSkill.onUnitTooltip(tipFrame, tooltipData)
    if not GatherSkill.isEnabled() or not addon.IsDecoratableTooltip(tipFrame) then return end
    local skinnableText = nosecret(_G.UNIT_SKINNABLE_LEATHER)
    if type(skinnableText) ~= "string" or skinnableText == "" then return end
    local isSkinnable = false
    for _, leftText in ipairs(GatherSkill.collectLeftTexts(tipFrame, tooltipData)) do
        if GatherSkill.cleanName(leftText) == skinnableText then
            isSkinnable = true
            break
        end
    end
    if not isSkinnable then return end
    local _, unitToken = compat.GetTooltipUnit(tipFrame, tooltipData)
    if not unitToken or type(_G.UnitLevel) ~= "function" then return end
    local isCallOk, unitLevel = pcall(_G.UnitLevel, unitToken)
    unitLevel = isCallOk and nosecret(unitLevel) or nil
    if type(unitLevel) ~= "number" or unitLevel <= 0 then return end
    tipFrame:AddLine(GatherSkill.composeLine(SKINNING, GatherSkill.skinningRequirement(unitLevel)))
    tipFrame:Show()
    EventDispatcher:trigger("tooltip:layout", tipFrame)
end

compat.AddTooltipPostCall("Object", nil, GatherSkill.onObjectTooltip)
compat.AddTooltipPostCall("MinimapMouseover", nil, GatherSkill.onMinimapTooltip)
compat.AddTooltipPostCall("Unit", nil, GatherSkill.onUnitTooltip)

EventDispatcher:attachEvent("SKILL_LINES_CHANGED, CHAT_MSG_SKILL, LEARNED_SPELL_IN_TAB, PLAYER_ENTERING_WORLD", function()
    GatherSkill.forgetSkills()
end)
