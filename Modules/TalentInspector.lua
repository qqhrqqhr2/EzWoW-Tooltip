--===========================================================================
-- EzWoW - Tooltip
-- Modules/TalentInspector.lua : Inspect Talent Tree Spec & Point Distribution Analyzer
--===========================================================================
local _, ns = ...
local type, pairs, ipairs, tonumber, tostring, select, pcall = type, pairs, ipairs, tonumber, tostring, select, pcall
local TalentTreeInspector = ns.TalentTreeInspector or {}
ns.TalentTreeInspector = TalentTreeInspector
local EventDispatcher = ns.events

local addon = EzWoW_Tooltip
local compat = select(2, ...).compat
local nosecret = compat.nosecret
local issecret = compat.issecret

local TALENT_TAG = compat.LineTag("000123", false, "AEE26A")
local TALENT_PREFIX_PATTERN = "^" .. TALENT_TAG
local CACHE_TTL = 120
-- own talents: short reuse so tooltip refreshes do not re-read the whole tree
local SELF_CACHE_TTL = 2

local FOREVER_CLASS_SPECS = {
    [1482] = true, [1484] = true, [1485] = true, [1486] = true, [1487] = true,
    [1488] = true, [1489] = true, [1490] = true, [1491] = true, [1493] = true,
}

local CLASS_TREES = {
    WARRIOR = {
        icons = { 132355, 132347, 132341 },
        koKR  = { "무기", "분노", "방어" },
        enUS  = { "Arms", "Fury", "Protection" },
        deDE  = { "Waffen", "Furor", "Schutz" },
        frFR  = { "Armes", "Fureur", "Protection" },
        esES  = { "Armas", "Furia", "Protección" },
        ruRU  = { "Оружие", "Неистовство", "Защита" },
        zhCN  = { "武器", "狂怒", "防护" },
        zhTW  = { "武器", "狂怒", "防護" },
    },
    PALADIN = {
        icons = { 135920, 135893, 135873 },
        koKR  = { "신성", "보호", "징벌" },
        enUS  = { "Holy", "Protection", "Retribution" },
        deDE  = { "Heilig", "Schutz", "Vergeltung" },
        frFR  = { "Sacré", "Protection", "Vindicte" },
        esES  = { "Sagrado", "Protección", "Reprensión" },
        ruRU  = { "Свет", "Защита", "Воздаяние" },
        zhCN  = { "神圣", "防护", "惩戒" },
        zhTW  = { "神聖", "防護", "懲戒" },
    },
    HUNTER = {
        icons = { 132164, 132222, 132215 },
        koKR  = { "야수", "사격", "생존" },
        enUS  = { "Beast Mastery", "Marksmanship", "Survival" },
        deDE  = { "Tierherrschaft", "Treffsicherheit", "Überleben" },
        frFR  = { "Maîtrise des bêtes", "Précision", "Survie" },
        esES  = { "Bestias", "Puntería", "Supervivencia" },
        ruRU  = { "Повелитель зверей", "Стрельба", "Выживание" },
        zhCN  = { "野兽控制", "射击", "生存" },
        zhTW  = { "野獸控制", "射擊", "生存" },
    },
    ROGUE = {
        icons = { 132292, 132090, 132320 },
        koKR  = { "암살", "전투", "잠행" },
        enUS  = { "Assassination", "Combat", "Subtlety" },
        deDE  = { "Meucheln", "Kampf", "Täuschung" },
        frFR  = { "Assassinat", "Combat", "Finesse" },
        esES  = { "Asesinato", "Combate", "Sutileza" },
        ruRU  = { "Ликвидация", "Бой", "Скрытность" },
        zhCN  = { "奇袭", "战斗", "敏锐" },
        zhTW  = { "刺殺", "戰鬥", "敏銳" },
    },
    PRIEST = {
        icons = { 135940, 135920, 136207 },
        koKR  = { "수양", "신성", "암흑" },
        enUS  = { "Discipline", "Holy", "Shadow" },
        deDE  = { "Disziplin", "Heilig", "Schatten" },
        frFR  = { "Discipline", "Sacré", "Ombre" },
        esES  = { "Disciplina", "Sagrado", "Sombra" },
        ruRU  = { "Послушание", "Свет", "Тьма" },
        zhCN  = { "戒律", "神圣", "暗影" },
        zhTW  = { "戒律", "神聖", "暗影" },
    },
    SHAMAN = {
        icons = { 136048, 136051, 136052 },
        koKR  = { "정기", "고양", "복원" },
        enUS  = { "Elemental", "Enhancement", "Restoration" },
        deDE  = { "Elementar", "Verstärkung", "Wiederherstellung" },
        frFR  = { "Élémentaire", "Amélioration", "Restauration" },
        esES  = { "Elemental", "Mejora", "Restauración" },
        ruRU  = { "Стихии", "Совершенствование", "Исцеление" },
        zhCN  = { "元素", "增强", "恢复" },
        zhTW  = { "元素", "增強", "恢復" },
    },
    MAGE = {
        icons = { 135932, 135810, 135846 },
        koKR  = { "비전", "화염", "냉기" },
        enUS  = { "Arcane", "Fire", "Frost" },
        deDE  = { "Arkan", "Feuer", "Frost" },
        frFR  = { "Arcanes", "Feu", "Givre" },
        esES  = { "Arcano", "Fuego", "Escarcha" },
        ruRU  = { "Тайная магия", "Огонь", "Лед" },
        zhCN  = { "奥术", "火焰", "冰霜" },
        zhTW  = { "秘法", "火焰", "冰霜" },
    },
    WARLOCK = {
        icons = { 136145, 136172, 136186 },
        koKR  = { "고통", "악마", "파괴" },
        enUS  = { "Affliction", "Demonology", "Destruction" },
        deDE  = { "Gebrechen", "Dämonologie", "Zerstörung" },
        frFR  = { "Affliction", "Démonologie", "Destruction" },
        esES  = { "Aflicción", "Demonología", "Destrucción" },
        ruRU  = { "Колдовство", "Демонология", "Разрушение" },
        zhCN  = { "痛苦", "恶魔学识", "毁灭" },
        zhTW  = { "痛苦", "惡魔學識", "毀滅" },
    },
    DRUID = {
        icons = { 136096, 132276, 136041 },
        koKR  = { "조화", "야성", "회복" },
        enUS  = { "Balance", "Feral", "Restoration" },
        deDE  = { "Gleichgewicht", "Wildheit", "Wiederherstellung" },
        frFR  = { "Équilibre", "Farouche", "Restauration" },
        esES  = { "Equilibrio", "Feral", "Restauración" },
        ruRU  = { "Баланс", "Сила зверя", "Исцеление" },
        zhCN  = { "平衡", "野性", "恢复" },
        zhTW  = { "平衡", "野性", "恢復" },
    },
    DEATHKNIGHT = {
        icons = { 135770, 135773, 135775 },
        koKR  = { "혈기", "냉기", "부정" },
        enUS  = { "Blood", "Frost", "Unholy" },
    },
    MONK = {
        icons = { 608951, 608952, 608953 },
        koKR  = { "양조", "운무", "풍운" },
        enUS  = { "Brewmaster", "Mistweaver", "Windwalker" },
    },
    DEMONHUNTER = {
        icons = { 1247264, 1247265, 1247264 },
        koKR  = { "파멸", "복수", "파멸" },
        enUS  = { "Havoc", "Vengeance", "Havoc" },
    },
    EVOKER = {
        icons = { 4511811, 4511812, 5198700 },
        koKR  = { "황폐", "보존", "증강" },
        enUS  = { "Devastation", "Preservation", "Augmentation" },
    },
}

local AURA_SPEC_MAP = {
    
    [15473] = { class = "PRIEST", tree = 3 }, 
    [15286] = { class = "PRIEST", tree = 3 }, 
    [10060] = { class = "PRIEST", tree = 1 }, 
    
    [24858] = { class = "DRUID",  tree = 1 }, 
    [5487]  = { class = "DRUID",  tree = 2 }, 
    [9634]  = { class = "DRUID",  tree = 2 }, 
    [768]   = { class = "DRUID",  tree = 2 }, 
    [17007] = { class = "DRUID",  tree = 2 }, 
    
    [19506] = { class = "HUNTER", tree = 2 }, 
    [19574] = { class = "HUNTER", tree = 1 }, 
    
    [20375] = { class = "PALADIN", tree = 3 }, 
    [20218] = { class = "PALADIN", tree = 3 }, 
    [20925] = { class = "PALADIN", tree = 2 }, 
    [25780] = { class = "PALADIN", tree = 2 }, 
    
    [11426] = { class = "MAGE",   tree = 3 }, 
    [11129] = { class = "MAGE",   tree = 2 }, 
    [12042] = { class = "MAGE",   tree = 1 }, 
    
    [19028] = { class = "WARLOCK", tree = 2 }, 
    
    [71]    = { class = "WARRIOR", tree = 3 }, 
    [2458]  = { class = "WARRIOR", tree = 2 }, 
    [2457]  = { class = "WARRIOR", tree = 1 }, 
    [12292] = { class = "WARRIOR", tree = 2 }, 
    
    [16166] = { class = "SHAMAN", tree = 1 }, 
    [30802] = { class = "SHAMAN", tree = 2 }, 
}

local AURA_ICON_SPEC_MAP = {
    PALADIN = {
        [135873] = 3, 
        [135920] = 3, 
        [132347] = 3, 
        [135880] = 2, 
        [135962] = 2, 
        [135893] = 2, 
        [135993] = 2, 
        [135933] = 1, 
        [135915] = 1, 
    },
    DRUID = {
        [136036] = 1, 
        [132276] = 2, 
        [132115] = 2, 
        [136112] = 2, 
        [132145] = 3, 
    },
    PRIEST = {
        [136200] = 3, 
        [136230] = 3, 
        [135939] = 1, 
        [135898] = 1, 
    },
    WARRIOR = {
        [132341] = 3, 
        [132275] = 2, 
        [132349] = 1, 
    },
    HUNTER = {
        [132329] = 2, 
        [132127] = 1, 
    },
    MAGE = {
        [135988] = 3, 
        [135843] = 3, 
        [135826] = 2, 
        [136048] = 1, 
        [135991] = 1, 
    },
    WARLOCK = {
        [136160] = 2, 
    },
    SHAMAN = {
        [136115] = 1, 
        [136097] = 3, 
    },
    ROGUE = {
        [132350] = 2, 
        [136206] = 2, 
    },
}

function TalentTreeInspector.activeLang()
    local userPref = addon.db and addon.db.general and addon.db.general.language or "auto"
    if userPref and userPref ~= "auto" then return userPref end
    local localeTbl = GetLocale and GetLocale() or "enUS"
    if localeTbl == "esMX" then localeTbl = "esES" end
    return localeTbl
end

function TalentTreeInspector.resolveTreeInfo(class, idx)
    local apiInfo = class and CLASS_TREES[class]
    if not apiInfo then return nil, nil end
    local langCode = TalentTreeInspector.activeLang()
    local names = apiInfo[langCode] or apiInfo.enUS
    return names and names[idx], apiInfo.icons and apiInfo.icons[idx]
end

function TalentTreeInspector.composeIcon(icon)
    if not icon then return "" end
    return format("|T%s:14:14:0:0:64:64:4:60:4:60|t ", tostring(icon))
end

function TalentTreeInspector.composeTreeSummary(class, pts1, pts2, pts3, customNames, customIcons)
    pts1, pts2, pts3 = tonumber(pts1) or 0, tonumber(pts2) or 0, tonumber(pts3) or 0
    local grandTotal = pts1 + pts2 + pts3
    if grandTotal <= 0 then
        local noTalent = (addon.L and addon.L.NoTalent) or "특성 없음"
        return format("|cff8899A6%s (0/0/0)|r", noTalent), false
    end
    local primary = 1
    if pts2 > pts1 and pts2 >= pts3 then
        primary = 2
    elseif pts3 > pts1 and pts3 > pts2 then
        primary = 3
    end
    local tName = (customNames and customNames[primary]) or select(1, TalentTreeInspector.resolveTreeInfo(class, primary)) or ""
    TalentTreeInspector.lastPrimaryName = tName ~= "" and tName or nil
    local tIcon = (customIcons and customIcons[primary]) or select(2, TalentTreeInspector.resolveTreeInfo(class, primary))
    return format("%s|cffEDF4F7%s|r |cffAEE26A(%d/%d/%d)|r", TalentTreeInspector.composeIcon(tIcon), tName, pts1, pts2, pts3), true
end

-----------------------------------------------------------------------------
-- Talent point limits
-- One point per level from level 10 (51 at level 60). A count above what the
-- unit's level allows was read from the wrong data and is never shown.
-----------------------------------------------------------------------------
local MAX_TALENT_POINTS = 51

function TalentTreeInspector.maxPointsFor(unit)
    local level = unit and nosecret(UnitLevel(unit))
    if type(level) == "number" and level > 0 then
        return math.max(0, math.min(MAX_TALENT_POINTS, level - 9))
    end
    return MAX_TALENT_POINTS
end

function TalentTreeInspector.isPlausibleTotal(total, unit)
    return type(total) == "number" and total > 0 and total <= TalentTreeInspector.maxPointsFor(unit)
end

-----------------------------------------------------------------------------
-- Extract Classic Talent Tabs (GetTalentTabInfo; clients without trait trees)
-- Returns the summary text plus the three point counts.
-----------------------------------------------------------------------------
function TalentTreeInspector.readClassicTalentTabs(isInspect)
    if type(GetNumTalentTabs) ~= "function" or type(GetTalentTabInfo) ~= "function" then return nil end
    local isCallOk, numTabs = pcall(GetNumTalentTabs, isInspect)
    numTabs = isCallOk and nosecret(numTabs)
    if type(numTabs) ~= "number" or numTabs < 1 then return nil end
    local pts = { 0, 0, 0 }
    local names, icons = {}, {}
    for tabIndex = 1, math.min(numTabs, 3) do
        local queryOk, a1Val, a2Val, a3Val, a4Val, a5Val = pcall(GetTalentTabInfo, tabIndex, isInspect)
        if queryOk and a1Val ~= nil and not compat.anysecret(a1Val, a2Val, a3Val, a4Val, a5Val) then
            local displayName, icon, spent
            if type(a1Val) == "number" then
                displayName, icon, spent = a2Val, a4Val, tonumber(a5Val) or 0
            else
                displayName, icon, spent = a1Val, a2Val, tonumber(a3Val) or 0
            end
            if spent == 0 and type(GetNumTalents) == "function" and type(GetTalentInfo) == "function" then
                local nok, nTalents = pcall(GetNumTalents, tabIndex, isInspect)
                if nok and type(nTalents) == "number" then
                    for index = 1, nTalents do
                        local iok, r1Val, _, _, _, r5Val = pcall(GetTalentInfo, tabIndex, index, isInspect)
                        if iok then
                            if type(r1Val) == "table" then
                                spent = spent + (tonumber(nosecret(r1Val.rank)) or 0)
                            else
                                spent = spent + (tonumber(nosecret(r5Val)) or 0)
                            end
                        end
                    end
                end
            end
            pts[tabIndex] = spent
            names[tabIndex] = type(displayName) == "string" and displayName or nil
            icons[tabIndex] = icon
        end
    end
    return pts, names, icons
end

function TalentTreeInspector.extractClassicTalentTabs(class, isInspect, unit)
    local pts, names, icons = TalentTreeInspector.readClassicTalentTabs(isInspect)
    if not pts then return nil end
    local grandTotal = pts[1] + pts[2] + pts[3]
    if isInspect then
        if not TalentTreeInspector.isPlausibleTotal(grandTotal, unit) then return nil end
        -- Some clients answer an inspect query with the player's own talents:
        -- the same three numbers as our own are not taken as the other unit's.
        local own = TalentTreeInspector.readClassicTalentTabs(false)
        if own and own[1] == pts[1] and own[2] == pts[2] and own[3] == pts[3] then return nil end
    elseif grandTotal > TalentTreeInspector.maxPointsFor("player") then
        return nil
    end
    return TalentTreeInspector.composeTreeSummary(class, pts[1], pts[2], pts[3], names, icons)
end

-----------------------------------------------------------------------------
-- Extract Single Trait Config
-- On this client each class has one trait tree that holds its three talent
-- trees side by side (four columns each, a wide gap between the trees).
-----------------------------------------------------------------------------
function TalentTreeInspector.resolveNodeRanksSpent(configID, nodeID, apiInfo, isInspect)
    if not apiInfo or not nosecret(apiInfo.isVisible) then return 0 end
    if apiInfo.type and Enum and Enum.TraitNodeType and apiInfo.type == Enum.TraitNodeType.SubTreeSelection then
        return 0
    end
    if nosecret(apiInfo.isFree) then return 0 end
    local purchased = tonumber(nosecret(apiInfo.ranksPurchased))
    if purchased then return math.max(0, purchased) end

    local candidateRank = 0
    local committed = apiInfo.entryIDsWithCommittedRanks
    if type(committed) == "table" and #committed > 0 then
        candidateRank = tonumber(nosecret(apiInfo.activeRank)) or tonumber(nosecret(apiInfo.currentRank)) or 0
    elseif isInspect then
        candidateRank = tonumber(nosecret(apiInfo.currentRank))
            or tonumber(nosecret(apiInfo.activeRank))
            or (type(apiInfo.activeEntry) == "table" and tonumber(nosecret(apiInfo.activeEntry.rank)))
            or 0
    end
    if candidateRank > 0 then
        if C_Traits.GetNodeCost then
            local cok, costs = pcall(C_Traits.GetNodeCost, configID, nodeID)
            if cok and type(costs) == "table" and #costs == 0 then
                return 0
            end
        end
        return candidateRank
    end
    return 0
end

-- Column positions -> the three trees. The gaps between trees are several
-- times the gap between columns; the first two such gaps from the left split
-- the trees, and anything further right (a misplaced node) counts as the
-- third tree.
function TalentTreeInspector.splitColumnsIntoTrees(xsVal)
    if #xsVal < 3 then
        local minX, maxX = xsVal[1], xsVal[#xsVal]
        local span = math.max(1, maxX - minX)
        return minX + span / 3, minX + 2 * span / 3
    end
    local gaps = {}
    for index = 1, #xsVal - 1 do
        gaps[#gaps + 1] = xsVal[index + 1] - xsVal[index]
    end
    local sortedGaps = {}
    for index = 1, #gaps do sortedGaps[index] = gaps[index] end
    table.sort(sortedGaps)
    local typicalGap = sortedGaps[math.max(1, math.floor((#sortedGaps + 1) / 2))]
    local splits = {}
    if typicalGap and typicalGap > 0 then
        for index = 1, #gaps do
            if gaps[index] >= typicalGap * 2.5 then
                splits[#splits + 1] = xsVal[index]
                if #splits == 2 then break end
            end
        end
    end
    if #splits == 2 then return splits[1], splits[2] end
    return xsVal[math.max(1, math.floor(#xsVal / 3))], xsVal[math.max(2, math.floor(2 * #xsVal / 3))]
end

function TalentTreeInspector.countTreePoints(configID, treeID, isInspect)
    local nok, nodeIDs = pcall(C_Traits.GetTreeNodes, treeID)
    if not nok or type(nodeIDs) ~= "table" or #nodeIDs == 0 then return nil end
    local nodeList = {}
    local xSet, xsVal = {}, {}
    for _, nodeID in ipairs(nodeIDs) do
        local iok, apiInfo = pcall(C_Traits.GetNodeInfo, configID, nodeID)
        if iok and type(apiInfo) == "table" and nosecret(apiInfo.isVisible) and not apiInfo.subTreeID then
            local coordX = tonumber(nosecret(apiInfo.posX)) or 0
            if coordX > 0 then
                nodeList[#nodeList + 1] = { x = coordX, spent = TalentTreeInspector.resolveNodeRanksSpent(configID, nodeID, apiInfo, isInspect) }
                if not xSet[coordX] then
                    xSet[coordX] = true
                    xsVal[#xsVal + 1] = coordX
                end
            end
        end
    end
    if #nodeList == 0 then return nil end
    table.sort(xsVal)
    local split1, split2 = TalentTreeInspector.splitColumnsIntoTrees(xsVal)
    local pts = { 0, 0, 0 }
    for _, nodeEntry in ipairs(nodeList) do
        if nodeEntry.x <= split1 then
            pts[1] = pts[1] + nodeEntry.spent
        elseif nodeEntry.x <= split2 then
            pts[2] = pts[2] + nodeEntry.spent
        else
            pts[3] = pts[3] + nodeEntry.spent
        end
    end
    return pts, #nodeList
end

function TalentTreeInspector.extractSingleTraitConfig(configID, class, isInspect, unit)
    if not configID or not C_Traits then return nil end
    local isCallOk, configInfo = pcall(C_Traits.GetConfigInfo, configID)
    if not isCallOk or type(configInfo) ~= "table" or type(configInfo.treeIDs) ~= "table" or #configInfo.treeIDs == 0 then
        return nil
    end

    local pts
    -- the class tree is the largest tree of the config
    local bestCount = 0
    for _, treeID in ipairs(configInfo.treeIDs) do
        local treePts, nodeCount = TalentTreeInspector.countTreePoints(configID, treeID, isInspect)
        if treePts and nodeCount > bestCount then
            pts, bestCount = treePts, nodeCount
        end
    end
    if not pts then return nil end

    local grandTotal = pts[1] + pts[2] + pts[3]
    if isInspect then
        if not TalentTreeInspector.isPlausibleTotal(grandTotal, unit) then return nil end
    elseif grandTotal > TalentTreeInspector.maxPointsFor("player") then
        return nil
    end
    return TalentTreeInspector.composeTreeSummary(class, pts[1], pts[2], pts[3])
end

-- For other EzWoW addons: the name of the player's main talent tree ("Feral"),
-- or nil when no points are spent or the tree can't be read.
function addon.GetPlayerTalentTreeName()
    local _, class = UnitClass("player")
    TalentTreeInspector.lastPrimaryName = nil
    local ok = pcall(TalentTreeInspector.extractTraitsTalentTree, class, false)
    if not ok then return nil end
    return TalentTreeInspector.lastPrimaryName
end

function TalentTreeInspector.extractTraitsTalentTree(class, isInspect, unit)
    if not C_Traits or not C_Traits.GetConfigInfo or not C_Traits.GetTreeNodes or not C_Traits.GetNodeInfo then
        return nil
    end
    if not isInspect then
        local okID, configID = false, nil
        if C_ClassTalents and C_ClassTalents.GetActiveConfigID then
            okID, configID = pcall(C_ClassTalents.GetActiveConfigID)
        end
        return TalentTreeInspector.extractSingleTraitConfig(okID and nosecret(configID) or nil, class, false, "player")
    end

    -- the inspected unit's talents (read only after INSPECT_READY for it)
    local tcVal = Constants and Constants.TraitConsts
    local candidates = { (tcVal and tcVal.INSPECT_TRAIT_CONFIG_ID) or -1 }
    if C_ClassTalents and C_ClassTalents.GetInspectConfigID then
        local okID, inspectID = pcall(C_ClassTalents.GetInspectConfigID)
        if okID and nosecret(inspectID) then candidates[#candidates + 1] = inspectID end
    end
    local visitedMap = {}
    for _, cid in ipairs(candidates) do
        if cid and not visitedMap[cid] then
            visitedMap[cid] = true
            local summaryText, hasFinal = TalentTreeInspector.extractSingleTraitConfig(cid, class, true, unit)
            if summaryText then return summaryText, hasFinal end
        end
    end
    return nil
end

-----------------------------------------------------------------------------
-- Extract Spec And Gear Fallback
-----------------------------------------------------------------------------
function TalentTreeInspector.extractSpecAndGearFallback(unit, class, isInspect, hasInspectData)
    
    local specID
    if not isInspect then
        local idx = C_SpecializationInfo and C_SpecializationInfo.GetSpecialization and C_SpecializationInfo.GetSpecialization()
            or (GetSpecialization and GetSpecialization())
        if idx and idx > 0 then
            specID = C_SpecializationInfo and C_SpecializationInfo.GetSpecializationInfo and C_SpecializationInfo.GetSpecializationInfo(idx)
                or (GetSpecializationInfo and GetSpecializationInfo(idx))
        end
    else
        local ok1, s1Val = false, nil
        if GetInspectSpecialization then ok1, s1Val = pcall(GetInspectSpecialization, unit) end
        local ok2, s2Val = false, nil
        if C_SpecializationInfo and C_SpecializationInfo.GetInspectSpecialization then
            ok2, s2Val = pcall(C_SpecializationInfo.GetInspectSpecialization, unit)
        end
        specID = (ok1 and nosecret(s1Val)) or (ok2 and nosecret(s2Val))
    end
    if specID and type(specID) == "number" and specID > 0 and not FOREVER_CLASS_SPECS[specID] and GetSpecializationInfoByID then
        local isCallOk, _, sName, _, sIcon = pcall(GetSpecializationInfoByID, specID)
        if isCallOk and sName and sName ~= "" then
            return format("%s|cffEDF4F7%s|r", TalentTreeInspector.composeIcon(sIcon), sName), true
        end
    end

    if not InCombatLockdown() and C_UnitAuras and C_UnitAuras.GetAuraDataByIndex then
        local auraSecret = compat.AurasRestricted()
        if not auraSecret then
            local iconMap = AURA_ICON_SPEC_MAP[class]
            local matchedTree
            for index = 1, 40 do
                local isCallOk, aura = pcall(C_UnitAuras.GetAuraDataByIndex, unit, index, "HELPFUL")
                if not isCallOk or not aura then break end
                local spellIDVal = nosecret(aura.spellId)
                local match = spellIDVal and AURA_SPEC_MAP[spellIDVal]
                if match and match.class == class then
                    matchedTree = match.tree
                    break
                end
                if iconMap and not matchedTree then
                    local icon = nosecret(aura.icon)
                    if icon and iconMap[icon] then
                        matchedTree = iconMap[icon]
                    end
                end
            end
            if matchedTree then
                local tName, tIcon = TalentTreeInspector.resolveTreeInfo(class, matchedTree)
                if tName then
                    return format("%s|cffEDF4F7%s|r", TalentTreeInspector.composeIcon(tIcon), tName), false
                end
            end
        end
    end

    local role = nosecret(UnitGroupRolesAssigned and UnitGroupRolesAssigned(unit))
    local mhItem = hasInspectData and (
        (GetInventoryItemID and nosecret(GetInventoryItemID(unit, 16)))
        or (GetInventoryItemLink and nosecret(GetInventoryItemLink(unit, 16)))
    )
    local ohItem = hasInspectData and (
        (GetInventoryItemID and nosecret(GetInventoryItemID(unit, 17)))
        or (GetInventoryItemLink and nosecret(GetInventoryItemLink(unit, 17)))
    )

    if not mhItem and not ohItem and (not role or role == "NONE") then
        return nil
    end

    local mhEquipLoc, mhClassID, mhSubClassID
    local ohEquipLoc, ohClassID
    if mhItem and compat.GetItemInfoInstant then
        local isCallOk, _, _, _, eqLoc, _, cID, scID = pcall(compat.GetItemInfoInstant, mhItem)
        if isCallOk then mhEquipLoc, mhClassID, mhSubClassID = eqLoc, cID, scID end
    end
    if ohItem and compat.GetItemInfoInstant then
        local isCallOk, _, _, _, eqLoc, _, cID = pcall(compat.GetItemInfoInstant, ohItem)
        if isCallOk then ohEquipLoc, ohClassID = eqLoc, cID end
    end

    local containsShield = (ohEquipLoc == "INVTYPE_SHIELD")
    local hasDualWield = (ohClassID == 2) or (ohEquipLoc == "INVTYPE_WEAPON" or ohEquipLoc == "INVTYPE_WEAPONOFFHAND")
    local hasTwoHand = (mhEquipLoc == "INVTYPE_2HWEAPON")

    local treeIdx
    if class == "WARRIOR" then
        if containsShield or role == "TANK" then treeIdx = 3
        elseif hasDualWield then treeIdx = 2
        else treeIdx = 1 end
    elseif class == "PALADIN" then
        if hasTwoHand then treeIdx = 3
        elseif role == "TANK" or containsShield then treeIdx = 2
        elseif role == "HEALER" then treeIdx = 1
        else treeIdx = 3 end
    elseif class == "ROGUE" then
        if mhSubClassID == 15 then treeIdx = 1 
        else treeIdx = 2 end                     
    elseif class == "SHAMAN" then
        if hasTwoHand or hasDualWield then treeIdx = 2
        elseif role == "HEALER" then treeIdx = 3
        else treeIdx = 1 end
    elseif class == "DRUID" then
        if role == "TANK" then treeIdx = 2
        elseif role == "HEALER" then treeIdx = 3
        else treeIdx = 1 end
    elseif class == "PRIEST" then
        if role == "DAMAGER" then treeIdx = 3
        else treeIdx = 2 end
    elseif class == "HUNTER" then
        if UnitExists(unit .. "pet") then treeIdx = 1
        else treeIdx = 2 end
    elseif class == "MAGE" then
        treeIdx = 3
    elseif class == "WARLOCK" then
        treeIdx = 1
    end

    if treeIdx then
        local tName, tIcon = TalentTreeInspector.resolveTreeInfo(class, treeIdx)
        if tName then
            return format("%s|cffEDF4F7%s|r", TalentTreeInspector.composeIcon(tIcon), tName), (mhItem or ohItem) and true or false
        end
    end
    return nil
end

-----------------------------------------------------------------------------
-- Determine Unit For Guid
-----------------------------------------------------------------------------
local talentCache = {}
local shownGUID = nil
local pendingGUID = nil
local lastInspectTime = 0
-- Whose inspect data the client holds: the unit of the last inspect request
-- (ours or anyone's) and the unit INSPECT_READY last arrived for. Inspect
-- data is read only when both are the unit asked about, so another unit's
-- talents (or our own) are never shown for it.
local inspectRequestGUID = nil
local inspectReadyGUID = nil

function TalentTreeInspector.determineUnitForGUID(guid)
    if not guid or issecret(guid) then return nil end
    if nosecret(UnitGUID("player")) == guid then return "player" end
    if GameTooltip then
        local _, unitRef = compat.GetTooltipUnit(GameTooltip)
        if unitRef and not issecret(unitRef) and UnitExists(unitRef) and nosecret(UnitGUID(unitRef)) == guid then
            return unitRef
        end
    end
    for _, tkVal in ipairs({ "target", "focus", "mouseover" }) do
        if UnitExists(tkVal) and nosecret(UnitGUID(tkVal)) == guid then
            return tkVal
        end
    end
    if IsInRaid() then
        for index = 1, GetNumGroupMembers() do
            local unitRef = "raid" .. index
            if UnitExists(unitRef) and nosecret(UnitGUID(unitRef)) == guid then return unitRef end
        end
    elseif IsInGroup() then
        for index = 1, GetNumSubgroupMembers() do
            local unitRef = "party" .. index
            if UnitExists(unitRef) and nosecret(UnitGUID(unitRef)) == guid then return unitRef end
        end
    end
    if UnitTokenFromGUID then
        local unitRef = nosecret(UnitTokenFromGUID(guid))
        if unitRef and UnitExists(unitRef) then return unitRef end
    end
    return nil
end

function TalentTreeInspector.hasInspectDataFor(guid)
    return guid ~= nil and inspectReadyGUID == guid and inspectRequestGUID == guid
end

function TalentTreeInspector.resolveUnitTalentText(unit, guid, isInspectReady)
    if not unit or not UnitExists(unit) or not nosecret(UnitIsPlayer(unit)) then return nil end
    local class = nosecret(select(2, UnitClass(unit)))
    if not class then return nil end

    local hasSelf = nosecret(UnitIsUnit(unit, "player"))
    if hasSelf then
        local now = GetTime()
        local selfCached = guid and talentCache[guid]
        if selfCached and selfCached.self and (now - selfCached.time) < SELF_CACHE_TTL then
            return selfCached.text
        end
        local extractSafeTooltipText = TalentTreeInspector.extractTraitsTalentTree(class, false)
            or TalentTreeInspector.extractClassicTalentTabs(class, false, "player")
            or TalentTreeInspector.extractSpecAndGearFallback("player", class, false, true)
        if extractSafeTooltipText and guid then
            talentCache[guid] = { text = extractSafeTooltipText, time = now, final = true, self = true }
        end
        return extractSafeTooltipText
    end

    local currentTime = GetTime()
    local cached = guid and talentCache[guid]
    if cached and cached.final and (currentTime - cached.time) < CACHE_TTL and not isInspectReady then
        return cached.text
    end

    if isInspectReady and TalentTreeInspector.hasInspectDataFor(guid) then
        local extractSafeTooltipText, hasFinal = TalentTreeInspector.extractTraitsTalentTree(class, true, unit)
        if not extractSafeTooltipText then
            extractSafeTooltipText, hasFinal = TalentTreeInspector.extractClassicTalentTabs(class, true, unit)
        end
        if not extractSafeTooltipText then
            extractSafeTooltipText, hasFinal = TalentTreeInspector.extractSpecAndGearFallback(unit, class, true, true)
        end
        if extractSafeTooltipText and guid then
            talentCache[guid] = { text = extractSafeTooltipText, time = currentTime, final = hasFinal and true or false }
            return extractSafeTooltipText
        end
    end

    -- no inspect data for this unit yet: a guess from auras / gear (no numbers)
    if cached and cached.final then return cached.text end
    local quickText = TalentTreeInspector.extractSpecAndGearFallback(unit, class, true, false)
    if quickText and guid and not cached then
        talentCache[guid] = { text = quickText, time = currentTime, final = false }
    end
    return (guid and talentCache[guid] and talentCache[guid].text) or quickText
end

function TalentTreeInspector.commitTalentLineToTooltip(tip, extractSafeTooltipText)
    if not tip then return end
    local display = (extractSafeTooltipText and extractSafeTooltipText ~= "") and extractSafeTooltipText or "|cff8398A6...|r"
    local formatLocalizedLabel = (addon.L and addon.L.Talent) or "특성"
    local fullText = TALENT_TAG .. format("|cffA7B9C5%s:|r %s", formatLocalizedLabel, display)
    if addon.InsertOrUpdateTooltipLine then
        addon:InsertOrUpdateTooltipLine(tip, TALENT_PREFIX_PATTERN, fullText)
    else
        local line = addon:FindLine(tip, TALENT_PREFIX_PATTERN)
        if line then
            line:SetText(fullText)
        else
            tip:AddLine(fullText)
        end
        addon.AttributeTooltip(tip)
    end
end

function TalentTreeInspector.isTalentLineWanted()
    return addon.db and addon.db.unit and addon.db.unit.player and addon.db.unit.player.showTalent ~= false
end

function TalentTreeInspector.trySendInspect(guid, attempt)
    attempt = (attempt or 0) + 1
    if pendingGUID ~= guid then return end
    if shownGUID ~= guid or not GameTooltip:IsShown() or not TalentTreeInspector.isTalentLineWanted() then
        pendingGUID = nil
        return
    end
    local cached = talentCache[guid]
    if cached and cached.final and (GetTime() - cached.time) < CACHE_TTL then
        pendingGUID = nil
        return
    end
    local unit = TalentTreeInspector.determineUnitForGUID(guid)
    if not unit or not UnitExists(unit) then
        pendingGUID = nil
        return
    end
    -- the client still holds this unit's inspect data: no new request
    if TalentTreeInspector.hasInspectDataFor(guid) then
        local extractSafeTooltipText = TalentTreeInspector.resolveUnitTalentText(unit, guid, true)
        if extractSafeTooltipText and talentCache[guid] and talentCache[guid].final then
            pendingGUID = nil
            TalentTreeInspector.commitTalentLineToTooltip(GameTooltip, extractSafeTooltipText)
            pcall(GameTooltip.Show, GameTooltip)
            return
        end
    end
    if not compat.CanRequestInspect(unit) then
        pendingGUID = nil
        return
    end
    -- at most one request a little over every second (the server drops faster ones)
    local elapsedSinceLast = GetTime() - lastInspectTime
    if elapsedSinceLast < 1.1 then
        if attempt <= 3 then
            C_Timer.After(1.15 - elapsedSinceLast, function()
                TalentTreeInspector.trySendInspect(guid, attempt)
            end)
        else
            pendingGUID = nil
        end
        return
    end
    pendingGUID = nil
    pcall(NotifyInspect, unit)
end

function TalentTreeInspector.requestInspectIfNeeded(guid)
    if not guid or pendingGUID == guid then return end
    pendingGUID = guid
    C_Timer.After(0.25, function()
        TalentTreeInspector.trySendInspect(guid, 0)
    end)
end

-- Every inspect request (ours, the inspect window's, other addons') changes
-- whose data the client will hold.
if type(NotifyInspect) == "function" then
    hooksecurefunc("NotifyInspect", function(unit)
        lastInspectTime = GetTime()
        local okGUID, requestGUID = pcall(UnitGUID, unit)
        requestGUID = okGUID and nosecret(requestGUID) or nil
        if requestGUID ~= inspectReadyGUID then inspectReadyGUID = nil end
        inspectRequestGUID = requestGUID
    end)
end
if type(ClearInspectPlayer) == "function" then
    hooksecurefunc("ClearInspectPlayer", function()
        inspectReadyGUID = nil
        inspectRequestGUID = nil
    end)
end

local eventFrame = CreateFrame("Frame")
for _, eventName in ipairs({ "INSPECT_READY", "PLAYER_TALENT_UPDATE", "PLAYER_SPECIALIZATION_CHANGED", "TRAIT_CONFIG_UPDATED", "ACTIVE_COMBAT_CONFIG_CHANGED", "PLAYER_LEVEL_UP", "CHARACTER_POINTS_CHANGED" }) do
    pcall(eventFrame.RegisterEvent, eventFrame, eventName)
end
eventFrame:SetScript("OnEvent", function(self, event, arg1)
    if event == "INSPECT_READY" then
        local guid = nosecret(arg1)
        if not guid then return end
        if inspectRequestGUID and inspectRequestGUID ~= guid then
            -- an answer for an older request: a newer one is on its way
            return
        end
        inspectRequestGUID = guid
        inspectReadyGUID = guid
        if shownGUID ~= guid or not GameTooltip:IsShown() or not TalentTreeInspector.isTalentLineWanted() then
            -- not on the tooltip now: forget the old result, read it when shown again
            local cached = talentCache[guid]
            if cached and not cached.final then talentCache[guid] = nil end
            return
        end
        local unit = TalentTreeInspector.determineUnitForGUID(guid)
        if not unit then return end
        local extractSafeTooltipText = TalentTreeInspector.resolveUnitTalentText(unit, guid, true)
        if extractSafeTooltipText then
            TalentTreeInspector.commitTalentLineToTooltip(GameTooltip, extractSafeTooltipText)
            pcall(GameTooltip.Show, GameTooltip)
        end
    else
        local pGuid = nosecret(UnitGUID("player"))
        if pGuid then talentCache[pGuid] = nil end
    end
end)

EventDispatcher:attachTrigger("tooltip:hide", function(self, tip)
    if tip == GameTooltip then
        shownGUID = nil
        pendingGUID = nil
    end
end)

EventDispatcher:attachTrigger("tooltip:unit", function(self, tip, unit)
    if tip ~= GameTooltip then return end
    if not TalentTreeInspector.isTalentLineWanted() then return end
    if not unit or addon:IsUnitRestricted(unit) or not nosecret(UnitIsPlayer(unit)) then return end
    local guid = nosecret(UnitGUID(unit))
    shownGUID = guid
    local isSelf = nosecret(UnitIsUnit(unit, "player"))
    local extractSafeTooltipText = TalentTreeInspector.resolveUnitTalentText(unit, guid, not isSelf and TalentTreeInspector.hasInspectDataFor(guid))
    TalentTreeInspector.commitTalentLineToTooltip(tip, extractSafeTooltipText)
    if guid and not isSelf then
        local cached = talentCache[guid]
        if not cached or not cached.final or (GetTime() - cached.time) >= CACHE_TTL then
            TalentTreeInspector.requestInspectIfNeeded(guid)
        end
    end
end)
