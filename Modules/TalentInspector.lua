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

local TALENT_PREFIX_PATTERN = "^|cffAEE26A★|r"
local CACHE_TTL = 120

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
    local tIcon = (customIcons and customIcons[primary]) or select(2, TalentTreeInspector.resolveTreeInfo(class, primary))
    return format("%s|cffEDF4F7%s|r |cffAEE26A(%d/%d/%d)|r", TalentTreeInspector.composeIcon(tIcon), tName, pts1, pts2, pts3), true
end

-----------------------------------------------------------------------------
-- Extract Classic Talent Tabs
-----------------------------------------------------------------------------
function TalentTreeInspector.extractClassicTalentTabs(class, isInspect)
    if not GetNumTalentTabs or not GetTalentTabInfo then return nil end
    local isCallOk, numTabs = pcall(GetNumTalentTabs, isInspect)
    if not isCallOk or type(numTabs) ~= "number" or numTabs < 1 then return nil end
    local pts = { 0, 0, 0 }
    local names, icons = {}, {}
    for tabWidget = 1, math.min(numTabs, 3) do
        local queryToken, a1Val, a2Val, a3Val, a4Val, a5Val = pcall(GetTalentTabInfo, tabWidget, isInspect)
        if queryToken and a1Val ~= nil then
            local displayName, icon, spent
            if type(a1Val) == "number" then
                displayName, icon, spent = a2Val, a4Val, tonumber(a5Val) or 0
            else
                displayName, icon, spent = a1Val, a2Val, tonumber(a3Val) or 0
            end
            if spent == 0 and GetNumTalents and GetTalentInfo then
                local nok, nTalents = pcall(GetNumTalents, tabWidget, isInspect)
                if nok and type(nTalents) == "number" then
                    for index = 1, nTalents do
                        local iok, r1Val, _, _, _, r5Val = pcall(GetTalentInfo, tabWidget, index, isInspect)
                        if iok then
                            if type(r1Val) == "table" then
                                spent = spent + (tonumber(r1Val.rank) or 0)
                            else
                                spent = spent + (tonumber(r5Val) or 0)
                            end
                        end
                    end
                end
            end
            pts[tabWidget] = spent
            names[tabWidget] = displayName
            icons[tabWidget] = icon
        end
    end
    local grandTotal = pts[1] + pts[2] + pts[3]
    if grandTotal > 0 or not isInspect then
        return TalentTreeInspector.composeTreeSummary(class, pts[1], pts[2], pts[3], names, icons)
    end
    return nil
end

-----------------------------------------------------------------------------
-- Extract Single Trait Config
-----------------------------------------------------------------------------
function TalentTreeInspector.extractSingleTraitConfig(configID, class, isInspect)
    if not configID then return nil end
    local isCallOk, configInfo = pcall(C_Traits.GetConfigInfo, configID)
    if not isCallOk or not configInfo or not configInfo.treeIDs or #configInfo.treeIDs == 0 then
        return nil
    end

    local function resolveNodeRanksSpent(nodeID, apiInfo)
        if not apiInfo or not apiInfo.isVisible then return 0 end
        if apiInfo.type and Enum and Enum.TraitNodeType and apiInfo.type == Enum.TraitNodeType.SubTreeSelection then
            return 0
        end
        if apiInfo.isFree then return 0 end
        local purchased = tonumber(apiInfo.ranksPurchased) or 0
        if purchased > 0 then return purchased end

        local candidateRank = 0
        local committed = apiInfo.entryIDsWithCommittedRanks
        if committed and #committed > 0 then
            candidateRank = tonumber(apiInfo.activeRank) or tonumber(apiInfo.currentRank) or 0
        elseif isInspect then
            candidateRank = tonumber(apiInfo.currentRank)
                or tonumber(apiInfo.activeRank)
                or (apiInfo.activeEntry and tonumber(apiInfo.activeEntry.rank))
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

    if #configInfo.treeIDs >= 3 then
        local pts = { 0, 0, 0 }
        local anyNode = false
        for tiVal = 1, 3 do
            local nok, nodeList2 = pcall(C_Traits.GetTreeNodes, configInfo.treeIDs[tiVal])
            if nok and type(nodeList2) == "table" then
                for _, nodeID in ipairs(nodeList2) do
                    local iok, apiInfo = pcall(C_Traits.GetNodeInfo, configID, nodeID)
                    if iok and apiInfo and apiInfo.isVisible then
                        anyNode = true
                        pts[tiVal] = pts[tiVal] + resolveNodeRanksSpent(nodeID, apiInfo)
                    end
                end
            end
        end
        if anyNode and (pts[1] + pts[2] + pts[3] > 0 or not isInspect) then
            return TalentTreeInspector.composeTreeSummary(class, pts[1], pts[2], pts[3])
        end
    end

    local treeID = configInfo.treeIDs[1]
    local nok, nodeIDs = pcall(C_Traits.GetTreeNodes, treeID)
    if not nok or type(nodeIDs) ~= "table" or #nodeIDs == 0 then return nil end

    local nodeList = {}
    local xSet, xsVal = {}, {}
    for _, nodeID in ipairs(nodeIDs) do
        local iok, apiInfo = pcall(C_Traits.GetNodeInfo, configID, nodeID)
        if iok and apiInfo and apiInfo.isVisible and not apiInfo.subTreeID then
            local coordX = tonumber(apiInfo.posX) or 0
            if coordX > 0 then
                local spent = resolveNodeRanksSpent(nodeID, apiInfo)
                nodeList[#nodeList + 1] = { x = coordX, spent = spent }
                if not xSet[coordX] then
                    xSet[coordX] = true
                    xsVal[#xsVal + 1] = coordX
                end
            end
        end
    end

    if #nodeList == 0 then return nil end
    table.sort(xsVal)

    local split1, split2
    if #xsVal >= 6 then
        local gaps = {}
        local minGap = math.huge
        for index = 1, #xsVal - 1 do
            local greenVal = xsVal[index + 1] - xsVal[index]
            gaps[#gaps + 1] = { idx = index, gap = greenVal }
            if greenVal > 0 and greenVal < minGap then minGap = greenVal end
        end
        table.sort(gaps, function(a, b) return a.gap > b.gap end)
        if gaps[1] and gaps[2] and gaps[2].gap > minGap * 1.15 then
            local i1Val = math.min(gaps[1].idx, gaps[2].idx)
            local i2Val = math.max(gaps[1].idx, gaps[2].idx)
            split1 = xsVal[i1Val]
            split2 = xsVal[i2Val]
        end
    end
    if not split1 or not split2 then
        if #xsVal >= 3 then
            split1 = xsVal[math.max(1, math.floor(#xsVal / 3))]
            split2 = xsVal[math.max(2, math.floor(2 * #xsVal / 3))]
        else
            local minX, maxX = xsVal[1], xsVal[#xsVal]
            local span = math.max(1, maxX - minX)
            split1 = minX + span / 3
            split2 = minX + 2 * span / 3
        end
    end

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

    local grandTotal = pts[1] + pts[2] + pts[3]
    if grandTotal > 0 or not isInspect then
        return TalentTreeInspector.composeTreeSummary(class, pts[1], pts[2], pts[3])
    end
    return nil
end

function TalentTreeInspector.extractTraitsTalentTree(class, isInspect)
    if not C_Traits or not C_Traits.GetConfigInfo or not C_Traits.GetTreeNodes or not C_Traits.GetNodeInfo then
        return nil
    end
    if not isInspect then
        local configID = C_ClassTalents and C_ClassTalents.GetActiveConfigID and C_ClassTalents.GetActiveConfigID()
        return TalentTreeInspector.extractSingleTraitConfig(configID, class, false)
    end
    
    local tcVal = Constants and Constants.TraitConsts
    local candidates = {
        tcVal and tcVal.INSPECT_TRAIT_CONFIG_ID or -1,
        (C_ClassTalents and C_ClassTalents.GetInspectConfigID and C_ClassTalents.GetInspectConfigID()) or nil,
        tcVal and tcVal.VIEW_TRAIT_CONFIG_ID or -3,
        -2,
    }
    local visitedMap = {}
    for _, cid in ipairs(candidates) do
        if cid and not visitedMap[cid] then
            visitedMap[cid] = true
            local extractSafeTooltipText, hasFinal = TalentTreeInspector.extractSingleTraitConfig(cid, class, true)
            if extractSafeTooltipText then return extractSafeTooltipText, hasFinal end
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
        local auraSecret = false
        if C_Secrets and C_Secrets.ShouldAurasBeSecret then
            local sok, sec = pcall(C_Secrets.ShouldAurasBeSecret)
            if sok and sec then auraSecret = true end
        end
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

function TalentTreeInspector.determineUnitForGUID(guid)
    if not guid or issecret(guid) then return nil end
    if nosecret(UnitGUID("player")) == guid then return "player" end
    if GameTooltip and GameTooltip.GetUnit then
        local isCallOk, _, unitRef = pcall(GameTooltip.GetUnit, GameTooltip)
        if isCallOk and unitRef and not issecret(unitRef) and UnitExists(unitRef) and nosecret(UnitGUID(unitRef)) == guid then
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

function TalentTreeInspector.resolveUnitTalentText(unit, guid, isInspectReady)
    if not unit or not UnitExists(unit) or not nosecret(UnitIsPlayer(unit)) then return nil end
    local class = nosecret(select(2, UnitClass(unit)))
    if not class then return nil end

    local hasSelf = nosecret(UnitIsUnit(unit, "player"))
    if hasSelf then
        local extractSafeTooltipText = TalentTreeInspector.extractClassicTalentTabs(class, false)
            or TalentTreeInspector.extractTraitsTalentTree(class, false)
            or TalentTreeInspector.extractSpecAndGearFallback("player", class, false, true)
        if extractSafeTooltipText and guid then
            talentCache[guid] = { text = extractSafeTooltipText, time = GetTime(), final = true }
        end
        return extractSafeTooltipText
    end

    local currentTime = GetTime()
    local cached = guid and talentCache[guid]
    if cached and cached.final and (currentTime - cached.time) < CACHE_TTL and not isInspectReady then
        return cached.text
    end

    if isInspectReady then
        local extractSafeTooltipText, hasFinal = TalentTreeInspector.extractClassicTalentTabs(class, true)
        if not extractSafeTooltipText then
            extractSafeTooltipText, hasFinal = TalentTreeInspector.extractTraitsTalentTree(class, true)
        end
        if not extractSafeTooltipText then
            extractSafeTooltipText, hasFinal = TalentTreeInspector.extractSpecAndGearFallback(unit, class, true, true)
        end
        if extractSafeTooltipText and guid then
            talentCache[guid] = { text = extractSafeTooltipText, time = currentTime, final = hasFinal and true or false }
            return extractSafeTooltipText
        end
    end

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
    local fullText = format("|cffAEE26A★|r |cffA7B9C5%s:|r %s", formatLocalizedLabel, display)
    if addon.InsertOrUpdateTooltipLine then
        addon:InsertOrUpdateTooltipLine(tip, TALENT_PREFIX_PATTERN, fullText)
    else
        local line = addon:FindLine(tip, TALENT_PREFIX_PATTERN)
        if line then
            line:SetText(fullText)
        else
            tip:AddLine(fullText)
        end
    end
end

function TalentTreeInspector.trySendInspect(guid, attempt)
    attempt = (attempt or 0) + 1
    if pendingGUID ~= guid then return end
    if shownGUID ~= guid or not GameTooltip:IsShown() then
        pendingGUID = nil
        return
    end
    if not (addon.db and addon.db.unit and addon.db.unit.player and addon.db.unit.player.showTalent ~= false) then
        pendingGUID = nil
        return
    end
    local cached = talentCache[guid]
    if cached and cached.final and (GetTime() - cached.time) < CACHE_TTL then
        pendingGUID = nil
        return
    end
    if InCombatLockdown() then
        pendingGUID = nil
        return
    end
    if InspectFrame and InspectFrame:IsShown() then
        pendingGUID = nil
        return
    end
    if PlayerSpellsFrame and PlayerSpellsFrame.IsInspecting and PlayerSpellsFrame:IsInspecting() then
        pendingGUID = nil
        return
    end
    local unit = TalentTreeInspector.determineUnitForGUID(guid)
    if unit and UnitExists(unit) then
        
        local extractSafeTooltipText = TalentTreeInspector.resolveUnitTalentText(unit, guid, true)
        if extractSafeTooltipText and talentCache[guid] and talentCache[guid].final then
            pendingGUID = nil
            TalentTreeInspector.commitTalentLineToTooltip(GameTooltip, extractSafeTooltipText)
            pcall(GameTooltip.Show, GameTooltip)
            return
        end
    end
    local elapsedSinceLast = GetTime() - lastInspectTime
    if elapsedSinceLast < 1.1 and attempt <= 3 then
        C_Timer.After(1.15 - elapsedSinceLast, function()
            TalentTreeInspector.trySendInspect(guid, attempt)
        end)
        return
    end
    pendingGUID = nil
    if unit and UnitExists(unit) and CanInspect and CanInspect(unit) then
        lastInspectTime = GetTime()
        pcall(NotifyInspect, unit)
    end
end

function TalentTreeInspector.requestInspectIfNeeded(guid)
    if not guid or pendingGUID == guid then return end
    pendingGUID = guid
    C_Timer.After(0.25, function()
        TalentTreeInspector.trySendInspect(guid, 0)
    end)
end

if NotifyInspect then
    hooksecurefunc("NotifyInspect", function()
        lastInspectTime = GetTime()
    end)
end

local eventFrame = CreateFrame("Frame")
eventFrame:RegisterEvent("INSPECT_READY")
eventFrame:RegisterEvent("PLAYER_TALENT_UPDATE")
eventFrame:RegisterEvent("PLAYER_SPECIALIZATION_CHANGED")
eventFrame:RegisterEvent("TRAIT_CONFIG_UPDATED")
eventFrame:RegisterEvent("ACTIVE_COMBAT_CONFIG_CHANGED")
eventFrame:SetScript("OnEvent", function(self, event, arg1)
    if event == "INSPECT_READY" then
        local guid = nosecret(arg1)
        if not guid then return end
        local unit = TalentTreeInspector.determineUnitForGUID(guid)
        if not unit then return end
        local extractSafeTooltipText = TalentTreeInspector.resolveUnitTalentText(unit, guid, true)
        if (extractSafeTooltipText and shownGUID == guid and GameTooltip:IsShown()
            and addon.db and addon.db.unit and addon.db.unit.player and addon.db.unit.player.showTalent ~= false) then
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
    if not addon.db or not addon.db.unit or not addon.db.unit.player or addon.db.unit.player.showTalent == false then
        return
    end
    if not unit or addon:IsUnitRestricted(unit) or not nosecret(UnitIsPlayer(unit)) then return end
    local guid = nosecret(UnitGUID(unit))
    shownGUID = guid
    local extractSafeTooltipText = TalentTreeInspector.resolveUnitTalentText(unit, guid, false)
    TalentTreeInspector.commitTalentLineToTooltip(tip, extractSafeTooltipText)
    if guid and not nosecret(UnitIsUnit(unit, "player")) then
        local cached = talentCache[guid]
        if not cached or not cached.final or (GetTime() - cached.time) >= CACHE_TTL then
            TalentTreeInspector.requestInspectIfNeeded(guid)
        end
    end
end)
