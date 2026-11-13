--===========================================================================
-- EzWoW - Tooltip
-- Modules/ItemAndQuestExtras.lua : Item Stack/Price/Level & Quest Metadata Tooltip Enricher
--===========================================================================
local _, ns = ...
local type, pairs, ipairs, tonumber, tostring, select, pcall = type, pairs, ipairs, tonumber, tostring, select, pcall
local ItemQuestEnricher = ns.ItemQuestEnricher or {}
ns.ItemQuestEnricher = ItemQuestEnricher
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
local hasForeignIlvlLabel = addon.IsForeignIlvlLabel
local composeCraftedExtras = addon.FormatCraftedExtras
local determineReagentName = addon.ResolveReagentName
local determineLocationName = addon.ResolveLocationName
local determineNpcName = addon.ResolveNpcName
local determineObjectName = addon.ResolveObjectName
local determineQuestName = addon.ResolveQuestName
local hasQuestCompleted = addon.IsQuestCompleted
local appendDualNameToTitle = addon.AppendDualNameToTitle
local verifyItemCollectionStatus = addon.CheckItemCollectionStatus
local composeReagentUsage = addon.FormatReagentUsage
local composeItemSources = addon.FormatItemSources
-- EzWoW - Bags reads this flag: when set, its price trend is appended to the auction price line here.
addon.appendsBagsTrend = true
local function bagsPriceTrend(itemID)
    local bags = _G.EzWoW_Bags
    if type(bags) ~= "table" or type(bags.PriceTrendText) ~= "function" then return nil end
    local ok, text = pcall(bags.PriceTrendText, itemID)
    return ok and type(text) == "string" and text ~= "" and text or nil
end
local queryItemCountAPI = addon.QueryItemCountSafe
local resolveZoneCollectionSummary = addon.GetZoneCollectionSummary

local lineTag = compat.LineTag
local ITEM_TAGS = {
    BAG_COUNT  = lineTag("000107"),
    MAX_STACK  = lineTag("000108"),
    SELL_PRICE = lineTag("000109"),
    ITEM_ILVL  = lineTag("00010a"),
    COLLECT    = lineTag("00010e"),
    SOURCE1    = lineTag("00010f"),
    SOURCE2    = lineTag("000110", true),
    QUEST_SRC  = lineTag("000111"),
    REC_SRC    = lineTag("000112", true),
    REAGENTS   = lineTag("000113", true),
    USED_IN    = lineTag("000114", true),
    ZONE_COL   = lineTag("000115"),
    ZONE_MISS  = lineTag("000116", true),
    TOKEN_RWD  = lineTag("000117", true),
    AH_PRICE   = lineTag("000118"),
    SEEN_SRC   = lineTag("000119"),
    GEAR_INFO  = lineTag("00011a"),
    REC_MORE   = lineTag("00011b", true),
}

-- EzWoW-BestGearFinder's item lines (best-in-slot marks, gear sources) are
-- drawn here too, so all of it is one block
do
    local function claim()
        local bgf = _G.EzWoW_BestGearFinder
        if type(bgf) == "table" then bgf.tooltipLinesBy = "EzWoW-Tooltip" end
    end
    claim()
    -- (it may load after this addon)
    local f = CreateFrame("Frame")
    pcall(f.RegisterEvent, f, "PLAYER_LOGIN")
    f:SetScript("OnEvent", claim)
end

-- The recipe source: one line, or one line per source under each other (the
-- first with the label, the rest with a ring marker)
local function addRecipeSourceLines(tip, recipeSrcLine)
    if type(recipeSrcLine) == "string" then
        tip:AddLine(format("%s|cff8398A6%s:|r %s", ITEM_TAGS.REC_SRC, resolveExtraLocaleText("recipeSource"), recipeSrcLine))
    elseif type(recipeSrcLine) == "table" then
        for i, text in ipairs(recipeSrcLine) do
            if i == 1 then
                tip:AddLine(format("%s|cff8398A6%s:|r %s", ITEM_TAGS.REC_SRC, resolveExtraLocaleText("recipeSource"), text))
            else
                tip:AddLine(ITEM_TAGS.REC_MORE .. "    " .. text)
            end
        end
    end
end

-- Shops and drops EzWoW users saw in the game (Libs/EzWoWShare) are drawn
-- here, in this block, instead of under it
do
    local share = _G.EzWoW_Share
    if type(share) == "table" then
        share.itemLinesBy = "EzWoW-Tooltip"
        -- the lines follow this addon's language setting
        if type(share.SetLanguageSource) == "function" then
            share.SetLanguageSource("EzWoW-Tooltip", addon.GetActiveLocale)
        end
    end
end

-----------------------------------------------------------------------------
-- Lines another EzWoW addon already shows on the same tooltip
-----------------------------------------------------------------------------
-- EzWoW-BestGearFinder (option "item sources in tooltips") lists where a piece of gear drops,
-- which quest or vendor gives it and, for crafted gear, its reagents and where the recipe is
-- learned. When it does, our source lines for that item would repeat it.
-- Returns: sources covered, craft reagents/recipe source covered.
function ItemQuestEnricher.bestGearCoversSource(tip, itemID)
    local bgf = _G.EzWoW_BestGearFinder
    if type(bgf) ~= "table" or type(bgf.CoversItemSource) ~= "function" then return false, false end
    local ok, covers, coversCraft = pcall(bgf.CoversItemSource, bgf, tip, itemID)
    if not ok then return false, false end
    return covers and true or false, (covers and coversCraft) and true or false
end

-- EzWoW-ProfessionRecipes adds "used in N recipes" (option "recipes that use an item") and the
-- learned / can-learn status on recipe items.
function ItemQuestEnricher.professionRecipesCovers(kind, tip, itemID)
    local pr = _G.EzWoW_ProfessionRecipes
    if type(pr) ~= "table" then return false end
    local fn = (kind == "usedIn" and pr.CoversReagentUsage) or (kind == "recipe" and pr.CoversRecipeStatus) or nil
    if type(fn) ~= "function" then
        -- older versions without the check: they always showed "used in" while loaded
        return kind == "usedIn" and _G.EzWoWProfessionRecipesFrame ~= nil
    end
    local ok, covers = pcall(fn, tip, itemID)
    return ok and covers and true or false
end

function ItemQuestEnricher.composeRelativeAge(ts)
    ts = tonumber(ts)
    if not ts or ts <= 0 then return "" end
    local currentTime = time and time() or 0
    if currentTime <= 0 or currentTime < ts then return "" end
    local diff = currentTime - ts
    if diff < 60 then
        return format(" |cff8398A6· %s|r", resolveExtraLocaleText("ageNow"))
    elseif diff < 3600 then
        return format(" |cff8398A6· " .. resolveExtraLocaleText("ageMin") .. "|r", math.floor(diff / 60))
    elseif diff < 86400 then
        return format(" |cff8398A6· " .. resolveExtraLocaleText("ageHour") .. "|r", math.floor(diff / 3600))
    else
        return format(" |cff8398A6· " .. resolveExtraLocaleText("ageDay") .. "|r", math.floor(diff / 86400))
    end
end

local COIN_GOLD_ICON   = "|TInterface\\MoneyFrame\\UI-GoldIcon:12:12:0:0|t"
local COIN_SILVER_ICON = "|TInterface\\MoneyFrame\\UI-SilverIcon:12:12:0:0|t"
local COIN_COPPER_ICON = "|TInterface\\MoneyFrame\\UI-CopperIcon:12:12:0:0|t"

function addon.FormatCopperAsCoinIcons(copper)
    copper = math.floor(tonumber(copper) or 0)
    if copper <= 0 then return nil end
    local greenVal = math.floor(copper / 10000)
    local stateFlag = math.floor((copper % 10000) / 100)
    local themeColor = copper % 100
    local parts = {}
    if greenVal > 0 then
        local gStr = (BreakUpLargeNumbers and BreakUpLargeNumbers(greenVal)) or tostring(greenVal)
        parts[#parts + 1] = format("|cffFFD100%s|r %s", gStr, COIN_GOLD_ICON)
    end
    if stateFlag > 0 or (greenVal > 0 and themeColor > 0) then
        parts[#parts + 1] = format("|cffE6E6E6%d|r %s", stateFlag, COIN_SILVER_ICON)
    end
    if themeColor > 0 or #parts == 0 then
        parts[#parts + 1] = format("|cffEDA55F%d|r %s", themeColor, COIN_COPPER_ICON)
    end
    return table.concat(parts, " ")
end

function ItemQuestEnricher.resolveHoveredSlotStackCount(fallbackBagCount)
    local focus = compat.GetMouseFocus and compat.GetMouseFocus()
    if focus and not issecret(focus) then
        local themeColor = focus.count
        if type(themeColor) == "number" and not issecret(themeColor) and themeColor > 1 then
            return themeColor
        end
        if focus.GetCount and type(focus.GetCount) == "function" then
            local isCallOk, fcVal = pcall(focus.GetCount, focus)
            fcVal = isCallOk and tonumber(nosecret(fcVal))
            if fcVal and fcVal > 1 then return fcVal end
        end
    end
    if fallbackBagCount and fallbackBagCount > 1 then
        return fallbackBagCount
    end
    return 1
end

function ItemQuestEnricher.inspectExistingItemTooltipState(tip)
    local containsBagCount, containsSellPrice, containsUsedIn, containsItemLevel = false, false, false, false
    if tip.shownMoneyFrames and tip.shownMoneyFrames > 0 then
        containsSellPrice = true
    end
    local tipName = tip.GetName and tip:GetName()
    if tipName and tip.NumLines then
        for index = 1, tip:NumLines() do
            local left = _G[tipName .. "TextLeft" .. index]
            local right = _G[tipName .. "TextRight" .. index]
            local lText = left and nosecret(left:GetText())
            local rText = right and nosecret(right:GetText())
            if type(lText) == "string" and lText ~= "" then
                local plainL = cleanColors(lText)
                if hasForeignIlvlLabel(plainL) then
                    containsItemLevel = true
                end
                if lText:find("상점가", 1, true) or lText:find("판매 가격", 1, true) or lText:find("Sell Price", 1, true) then
                    containsSellPrice = true
                end
                if lText:find("제조법 재료", 1, true) or lText:find("Reagent for", 1, true) then
                    containsUsedIn = true
                end
                if lText:find("수량:", 1, true) or lText:find("보유 수량", 1, true) then
                    containsBagCount = true
                end
            end
            if type(rText) == "string" and rText ~= "" then
                if rText:find("수량:", 1, true) or rText:find("가방:", 1, true) or rText:find("Bags:", 1, true) then
                    containsBagCount = true
                end
            end
        end
    end
    return containsBagCount, containsSellPrice, containsUsedIn, containsItemLevel
end

function ItemQuestEnricher.extractItemTooltipLevel(itemID, link)
    local targetKey = link or itemID
    if not targetKey then return nil end
    local ilvl, equipLoc, classID
    if C_Item and C_Item.GetDetailedItemLevelInfo then
        local isCallOk, entryValue = pcall(C_Item.GetDetailedItemLevelInfo, targetKey)
        if isCallOk and entryValue then ilvl = tonumber(nosecret(entryValue)) end
    elseif GetDetailedItemLevelInfo then
        local isCallOk, entryValue = pcall(GetDetailedItemLevelInfo, targetKey)
        if isCallOk and entryValue then ilvl = tonumber(nosecret(entryValue)) end
    end
    if compat.GetItemInfo then
        local isCallOk, _, _, _, baseIlvl, _, _, _, eqLoc, _, _, clsID = pcall(compat.GetItemInfo, targetKey)
        if isCallOk then
            if not ilvl then ilvl = tonumber(nosecret(baseIlvl)) end
            equipLoc = nosecret(eqLoc)
            classID = tonumber(nosecret(clsID))
        end
    end
    if not equipLoc and compat.GetItemInfoInstant then
        local isCallOk, _, _, _, eqLoc, _, clsID = pcall(compat.GetItemInfoInstant, targetKey)
        if isCallOk then
            equipLoc = nosecret(eqLoc)
            classID = classID or tonumber(nosecret(clsID))
        end
    end
    if not ilvl or ilvl <= 0 then return nil end
    local hasEquippable = (type(equipLoc) == "string" and equipLoc ~= "" and equipLoc ~= "INVTYPE_NON_EQUIP")
        or (classID == 2 or classID == 4)
    if hasEquippable or ilvl > 1 then
        return math.floor(ilvl + 0.5)
    end
    return nil
end

EventDispatcher:attachTrigger("tooltip:item", function(self, tip, link)
    if not tip or not link or issecret(link) then return end
    if addon.RemoveDebugTelemetryTooltipLines then
        addon.RemoveDebugTelemetryTooltipLines(tip)
    end
    local iCfg = addon.db and addon.db.item
    local itemID = tonumber(string.match(link, "item:(%d+)")) or tonumber(link)
    if not itemID and compat.GetItemInfoInstant then
        local isCallOk, entityID = pcall(compat.GetItemInfoInstant, link)
        if isCallOk and entityID then itemID = tonumber(nosecret(entityID)) end
    end

    appendDualNameToTitle(tip, "item", itemID)
    local linesBefore = tip:NumLines() or 0

    local containsBagCount, containsSellPrice, containsUsedIn, containsItemLevel = ItemQuestEnricher.inspectExistingItemTooltipState(tip)
    local hasShift = IsShiftKeyDown()
    local statusText
    local ownedBagCount = 0

    if not containsItemLevel and (not iCfg or iCfg.showItemDetails ~= false) then
        if not addon:FindLine(tip, "^" .. ITEM_TAGS.ITEM_ILVL) then
            local itemIlvl = ItemQuestEnricher.extractItemTooltipLevel(itemID, link)
            if itemIlvl then
                tip:AddLine(format("%s|cffA7B9C5%s:|r |cffFFD100%d|r", ITEM_TAGS.ITEM_ILVL, resolveExtraLocaleText("ilvl"), itemIlvl))
            end
        end
    end

    if itemID and (not iCfg or iCfg.showCollectionStatus ~= false) then
        if not addon:FindLine(tip, "^" .. ITEM_TAGS.COLLECT) then
            _, statusText = verifyItemCollectionStatus(itemID, link, false)
            -- a recipe item's learned state is already shown by EzWoW-ProfessionRecipes
            if statusText and addon.RecipeItemDB and addon.RecipeItemDB[itemID]
                and ItemQuestEnricher.professionRecipesCovers("recipe", tip, itemID) then
                statusText = nil
            end
            if statusText then
                tip:AddLine(format("%s|cffA7B9C5%s:|r %s", ITEM_TAGS.COLLECT, resolveExtraLocaleText("collection"), statusText))
            end
        end
    end

    -- shops and drops seen in the game (shared records)
    if itemID and not addon:FindLine(tip, "^" .. ITEM_TAGS.SEEN_SRC) then
        local share = _G.EzWoW_Share
        if type(share) == "table" and type(share.ItemSourceLines) == "function" then
            local okLines, lines = pcall(share.ItemSourceLines, itemID)
            -- EzWoW-BestGearFinder lists where this gear comes from: no second list
            local okBgf, bgfSources = pcall(ItemQuestEnricher.bestGearCoversSource, tip, itemID)
            bgfSources = okBgf and bgfSources
            for index, row in ipairs(okLines and type(lines) == "table" and lines or {}) do
                if bgfSources then row = nil end
                if type(row) == "table" and type(row[1]) == "string" and type(row[2]) == "string" then
                    tip:AddLine(format("%s|cffA7B9C5%s:|r |cffEDF4F7%s|r", ITEM_TAGS.SEEN_SRC, row[1], row[2]))
                    -- an opened list (Shift) goes down under it
                    for _, line in ipairs(type(row[3]) == "table" and row[3] or {}) do
                        if type(line) == "string" then
                            tip:AddLine(ITEM_TAGS.REC_MORE .. "    |cffEDF4F7" .. line .. "|r")
                        end
                    end
                end
            end
        end
    end

    -- EzWoW-BestGearFinder: best-in-slot marks, and where gear comes from when
    -- this addon knows no source for it
    if itemID and not addon:FindLine(tip, "^" .. ITEM_TAGS.GEAR_INFO) then
        local bgf = _G.EzWoW_BestGearFinder
        if type(bgf) == "table" and type(bgf.ItemTooltipLines) == "function" then
            local okGear, gearLines = pcall(bgf.ItemTooltipLines, bgf, tip, itemID)
            for _, row in ipairs(okGear and type(gearLines) == "table" and gearLines or {}) do
                if type(row) == "table" and type(row[1]) == "string" then
                    tip:AddLine(ITEM_TAGS.GEAR_INFO .. row[1], tonumber(row[2]) or 1, tonumber(row[3]) or 1, tonumber(row[4]) or 1, true)
                end
            end
        end
    end

    if itemID and (not iCfg or iCfg.showSourceInfo ~= false) then
        if not addon:FindLine(tip, "^" .. ITEM_TAGS.SOURCE1) then
            local sources, recipeSrcLine, reagLine, primaryLocKey = composeItemSources(itemID, link)
            local bgfSources, bgfCraft = ItemQuestEnricher.bestGearCoversSource(tip, itemID)
            if bgfSources then sources = {} end
            if bgfCraft then recipeSrcLine, reagLine = nil, nil end
            if sources[1] then
                tip:AddLine(format("%s|cffA7B9C5%s:|r %s", ITEM_TAGS.SOURCE1, resolveExtraLocaleText("source"), sources[1]))
            end
            if sources[2] and not addon:FindLine(tip, "^" .. ITEM_TAGS.SOURCE2) then
                tip:AddLine(format("%s|cff8398A6%s:|r %s", ITEM_TAGS.SOURCE2, resolveExtraLocaleText("source2"), sources[2]))
            end
            if recipeSrcLine and not addon:FindLine(tip, "^" .. ITEM_TAGS.REC_SRC) then
                addRecipeSourceLines(tip, recipeSrcLine)
            end
            if reagLine and not addon:FindLine(tip, "^" .. ITEM_TAGS.REAGENTS) then
                tip:AddLine(format("%s|cff8398A6%s:|r %s", ITEM_TAGS.REAGENTS, resolveExtraLocaleText("reagents"), reagLine))
            end
            local rawTokRwd = addon.TokenRewardDB and addon.TokenRewardDB[itemID]
            if rawTokRwd and rawTokRwd ~= "" and not addon:FindLine(tip, "^" .. ITEM_TAGS.TOKEN_RWD) then
                local rwdParts = {}
                local rwdTotal = 0
                local rwdMax = hasShift and 8 or 4
                for rStr in rawTokRwd:gmatch("([^,]+)") do
                    local rid = tonumber(rStr)
                    if rid and rid > 0 then
                        rwdTotal = rwdTotal + 1
                        if #rwdParts < rwdMax then
                            local rName = determineReagentName(rid)
                            local hasCol = verifyItemCollectionStatus(rid, nil, true)
                            local colMark = hasCol and (" " .. compat.CheckIcon()) or ""
                            rwdParts[#rwdParts + 1] = format("|cffEDF4F7%s|r%s", rName, colMark)
                        end
                    end
                end
                if #rwdParts > 0 then
                    local moreTxt = (rwdTotal > #rwdParts) and format(" |cff8398A6(+%d)|r", rwdTotal - #rwdParts) or ""
                    tip:AddLine(format("%s|cff8398A6%s:|r %s%s", ITEM_TAGS.TOKEN_RWD, resolveExtraLocaleText("tokenReward"), table.concat(rwdParts, " |cff8398A6·|r "), moreTxt))
                end
            end
            
            -- the dungeon's collection line (Shift only opens the "+N more" lists)
            if primaryLocKey and primaryLocKey < 0 and not addon:FindLine(tip, "^" .. ITEM_TAGS.ZONE_COL) then
                local zSummary, zMissing = resolveZoneCollectionSummary(primaryLocKey)
                if zSummary then
                    local zLabel = (primaryLocKey < 0) and resolveExtraLocaleText("instCollect") or resolveExtraLocaleText("zoneCollect")
                    tip:AddLine(format("%s|cffA7B9C5%s:|r %s", ITEM_TAGS.ZONE_COL, zLabel, zSummary))
                end
            end
        end
        if not containsUsedIn and not ItemQuestEnricher.professionRecipesCovers("usedIn", tip, itemID)
            and not addon:FindLine(tip, "^" .. ITEM_TAGS.USED_IN) then
            local usedInLine = composeReagentUsage(itemID)
            if usedInLine then
                tip:AddLine(format("%s|cff8398A6%s:|r %s", ITEM_TAGS.USED_IN, resolveExtraLocaleText("usedIn"), usedInLine))
            end
        end
    end

    if queryItemCountAPI then
        local targetKey = itemID or link
        local ok1, bagCount = pcall(queryItemCountAPI, targetKey, false)
        local ok2, totalCount = pcall(queryItemCountAPI, targetKey, true)
        bagCount = ok1 and tonumber(nosecret(bagCount)) or 0
        totalCount = ok2 and tonumber(nosecret(totalCount)) or bagCount
        ownedBagCount = bagCount
        if not containsBagCount and (not iCfg or iCfg.showBagCount ~= false) then
            if not (statusText and (statusText:find("보유", 1, true) or statusText:find("Owned", 1, true))) then
                if totalCount > 0 and not addon:FindLine(tip, "^" .. ITEM_TAGS.BAG_COUNT) then
                    local bankCount = math.max(0, totalCount - bagCount)
                    local countStr
                    if bankCount > 0 then
                        countStr = format(resolveExtraLocaleText("bagFmt"), totalCount, bagCount, bankCount)
                    else
                        countStr = format(resolveExtraLocaleText("bagOnlyFmt"), bagCount)
                    end
                    tip:AddLine(format("%s|cffA7B9C5%s:|r |cffEDF4F7%s|r", ITEM_TAGS.BAG_COUNT, resolveExtraLocaleText("bagCount"), countStr))
                end
            end
        end
    end

    local itemBindType, itemClassID
    if compat.GetItemInfo then
        local isCallOk, _, _, _, _, _, _, itemStackCount, _, _, _, itemSellPrice, classID, _, bindType = pcall(compat.GetItemInfo, itemID or link)
        if isCallOk then
            itemBindType = tonumber(nosecret(bindType))
            itemClassID = tonumber(nosecret(classID))
            if not iCfg or iCfg.showItemDetails ~= false then
                local stack = tonumber(nosecret(itemStackCount)) or 0
                local price = tonumber(nosecret(itemSellPrice)) or 0
                if price > 0 and not containsSellPrice and not addon:FindLine(tip, "^" .. ITEM_TAGS.SELL_PRICE) then
                    local moneyStr = addon.FormatCopperAsCoinIcons and addon.FormatCopperAsCoinIcons(price)
                    if moneyStr and moneyStr ~= "" then
                        tip:AddLine(format("%s|cffA7B9C5%s:|r %s", ITEM_TAGS.SELL_PRICE, resolveExtraLocaleText("sellPrice"), moneyStr))
                    end
                end
            end
        end
    end

    if itemID and (not iCfg or iCfg.showAuctionPrice ~= false) and not addon:FindLine(tip, "^" .. ITEM_TAGS.AH_PRICE) then
        local prices = EzWoW_TooltipDB and EzWoW_TooltipDB.auctionPrices
        local rawEntry = prices and (prices[itemID] or prices[tostring(itemID)])
        local unitPrice = type(rawEntry) == "table" and tonumber(rawEntry.buyout or rawEntry.p) or tonumber(rawEntry)
        if unitPrice and unitPrice > 0 then
            local unitMoney = addon.FormatCopperAsCoinIcons(unitPrice)
            if unitMoney and unitMoney ~= "" then
                local stackQty = ItemQuestEnricher.resolveHoveredSlotStackCount(ownedBagCount)
                local priceStr = unitMoney
                if stackQty and stackQty > 1 then
                    local stackMoney = addon.FormatCopperAsCoinIcons(unitPrice * stackQty)
                    if stackMoney and stackMoney ~= "" then
                        priceStr = format("%s |cff8398A6(×%d: %s)|r", unitMoney, stackQty, stackMoney)
                    end
                end
                local times = EzWoW_TooltipDB and EzWoW_TooltipDB.auctionTimes
                local seenTs = (type(rawEntry) == "table" and tonumber(rawEntry.seen or rawEntry.t))
                    or (times and tonumber(times[itemID] or times[tostring(itemID)]))
                    or (EzWoW_TooltipDB and tonumber(EzWoW_TooltipDB.auctionLastScan))
                local ageTxt = ItemQuestEnricher.composeRelativeAge(seenTs)
                local trendTxt = bagsPriceTrend(itemID)
                if trendTxt then priceStr = priceStr .. "  " .. trendTxt end
                tip:AddLine(format("%s|cffA7B9C5%s:|r %s%s", ITEM_TAGS.AH_PRICE, resolveExtraLocaleText("auctionPrice"), priceStr, ageTxt))
            end
        elseif itemBindType ~= 1 and itemBindType ~= 4 and itemClassID ~= 12 then
            local lastScan = EzWoW_TooltipDB and tonumber(EzWoW_TooltipDB.auctionLastScan)
            local hasKo = (resolveActiveLocale() == "koKR")
            if lastScan and lastScan > 0 then
                local extraNo = addon.EXTRA_LOCALE and addon.EXTRA_LOCALE[resolveActiveLocale()]
                local noListingTxt = hasKo and "|cff8398A6등록된 매물 없음|r" or ("|cff8398A6" .. ((extraNo and extraNo.ahNoListing) or "No active listings") .. "|r")
                tip:AddLine(format("%s|cffA7B9C5%s:|r %s%s", ITEM_TAGS.AH_PRICE, resolveExtraLocaleText("auctionPrice"), noListingTxt, ItemQuestEnricher.composeRelativeAge(lastScan)))
            else
                local extraScan = addon.EXTRA_LOCALE and addon.EXTRA_LOCALE[resolveActiveLocale()]
                local needScanTxt = hasKo and "|cff8398A6미수집 (경매장 방문 시 자동 수집)|r" or ("|cff8398A6" .. ((extraScan and extraScan.ahNotScanned) or "Not scanned yet (open AH to collect)") .. "|r")
                tip:AddLine(format("%s|cffA7B9C5%s:|r %s", ITEM_TAGS.AH_PRICE, resolveExtraLocaleText("auctionPrice"), needScanTxt))
            end
        end
    end

    if (tip:NumLines() or 0) > linesBefore then
        addon.AttributeTooltip(tip)
    end
    if addon.RemoveDebugTelemetryTooltipLines then
        addon.RemoveDebugTelemetryTooltipLines(tip)
    end
    if tip:IsShown() then
        pcall(tip.Show, tip)
    end
end)

EventDispatcher:attachTrigger("tooltip:spell", function(self, tip, spellID)
    spellID = tonumber(nosecret(spellID)) or (tip and tonumber(nosecret(select(2, compat.GetTooltipSpell(tip)))))
    if not tip then return end
    appendDualNameToTitle(tip, "spell", spellID)
    if not spellID or spellID <= 0 then
        if addon.RemoveDebugTelemetryTooltipLines then addon.RemoveDebugTelemetryTooltipLines(tip) end
        return
    end
    local rawRecipe = addon.RecipeSpellDB and addon.RecipeSpellDB[spellID]
    if not rawRecipe or rawRecipe == "" then
        if addon.RemoveDebugTelemetryTooltipLines then addon.RemoveDebugTelemetryTooltipLines(tip) end
        if tip:IsShown() then pcall(tip.Show, tip) end
        return
    end
    local iCfg = addon.db and addon.db.item

    local linesBefore = tip:NumLines() or 0
    if not iCfg or iCfg.showSourceInfo ~= false then
        local profLine, recipeSrcLine, reagLine = composeCraftedExtras(rawRecipe)
        if profLine and not addon:FindLine(tip, "^" .. ITEM_TAGS.SOURCE1) then
            tip:AddLine(format("%s|cffA7B9C5%s:|r %s", ITEM_TAGS.SOURCE1, resolveExtraLocaleText("source"), profLine))
        end
        if recipeSrcLine and not addon:FindLine(tip, "^" .. ITEM_TAGS.REC_SRC) then
            addRecipeSourceLines(tip, recipeSrcLine)
        end
        if reagLine and not addon:FindLine(tip, "^" .. ITEM_TAGS.REAGENTS) then
            tip:AddLine(format("%s|cff8398A6%s:|r %s", ITEM_TAGS.REAGENTS, resolveExtraLocaleText("reagents"), reagLine))
        end
    end
    if (tip:NumLines() or 0) > linesBefore then
        addon.AttributeTooltip(tip)
    end
    if addon.RemoveDebugTelemetryTooltipLines then
        addon.RemoveDebugTelemetryTooltipLines(tip)
    end
    if tip:IsShown() then
        pcall(tip.Show, tip)
    end
end)

-- The item data post-call usually fires inside SetItemByID/SetItemKey already; remember that
-- per tooltip fill so the hooks below only fire "tooltip:item" when it did not.
local itemSignalSeen = {}
local itemSignalTracked = {}   -- tooltips whose fills can be told apart (cleared between fills)
EventDispatcher:attachTrigger("tooltip:item", function(self, tip)
    if tip and itemSignalTracked[tip] then itemSignalSeen[tip] = true end
end)

for _, tipFrame in ipairs({ GameTooltip, ItemRefTooltip }) do
    if tipFrame then
        if tipFrame.HookScript and tipFrame.HasScript and tipFrame:HasScript("OnTooltipCleared")
            and _G.TooltipDataProcessor then
            itemSignalTracked[tipFrame] = true
            tipFrame:HookScript("OnTooltipCleared", function(self) itemSignalSeen[self] = nil end)
            tipFrame:HookScript("OnHide", function(self) itemSignalSeen[self] = nil end)
        end
        if tipFrame.SetItemByID then
            hooksecurefunc(tipFrame, "SetItemByID", function(self, itemID)
                if itemSignalSeen[self] then return end
                itemID = tonumber(nosecret(itemID))
                if itemID and itemID > 0 then
                    EventDispatcher:trigger("tooltip:item", self, "item:" .. tostring(itemID))
                end
            end)
        end
        if tipFrame.SetItemKey then
            hooksecurefunc(tipFrame, "SetItemKey", function(self, itemID)
                if itemSignalSeen[self] then return end
                itemID = tonumber(nosecret(itemID))
                if itemID and itemID > 0 then
                    EventDispatcher:trigger("tooltip:item", self, "item:" .. tostring(itemID))
                end
            end)
        end
        if tipFrame.SetSpellByID then
            hooksecurefunc(tipFrame, "SetSpellByID", function(self, spellID)
                spellID = tonumber(nosecret(spellID))
                if spellID and spellID > 0 then
                    EventDispatcher:trigger("tooltip:spell", self, spellID)
                end
            end)
        end
    end
end

-----------------------------------------------------------------------------
-- Append Quest Tooltip Info
-----------------------------------------------------------------------------
function ItemQuestEnricher.appendQuestTooltipInfo(tip, link)
    if not tip or not link or issecret(link) then return end
    local questIDVal = tonumber(string.match(link, "quest:(%d+)"))
    if not questIDVal or questIDVal <= 0 then return end
    appendDualNameToTitle(tip, "quest", questIDVal)
    local iCfg = addon.db and addon.db.item
    if iCfg and iCfg.showSourceInfo == false then return end
    if addon:FindLine(tip, "^" .. ITEM_TAGS.QUEST_SRC) then return end

    local done = hasQuestCompleted(questIDVal)
    local statusBadge = done and format("|cffAEE26A[%s]|r", resolveExtraLocaleText("questDone")) or format("|cffF1BD57[%s]|r", resolveExtraLocaleText("questMiss"))
    local rawQ = addon.QuestSourceDB and addon.QuestSourceDB[questIDVal]
    if rawQ and rawQ ~= "" then
        local locStr, qgStr, _, coordStr = strsplit(":", rawQ)
        local locName = determineLocationName(tonumber(locStr))
        local qgID = tonumber(qgStr) or 0
        local qgName = (qgID > 0) and determineNpcName(qgID) or nil
        local coordTxt = (coordStr and coordStr ~= "") and format(" |cff8398A6(%s)|r", coordStr) or ""
        local parts = {}
        if locName then parts[#parts + 1] = format("|cffEDF4F7%s|r", locName) end
        if qgName then parts[#parts + 1] = format("|cffF1BD57%s|r", qgName) end
        local locBody = (#parts > 0) and (table.concat(parts, " |cff8398A6>|r ") .. coordTxt .. "  ") or ""
        tip:AddLine(format("%s|cffA7B9C5%s:|r %s%s", ITEM_TAGS.QUEST_SRC, resolveExtraLocaleText("source"), locBody, statusBadge))
    else
        tip:AddLine(format("%s|cffA7B9C5%s:|r %s", ITEM_TAGS.QUEST_SRC, resolveExtraLocaleText("collection"), statusBadge))
    end
    addon.AttributeTooltip(tip)
    if addon.RemoveDebugTelemetryTooltipLines then
        addon.RemoveDebugTelemetryTooltipLines(tip)
    end
    if tip:IsShown() then
        pcall(tip.Show, tip)
    end
end

hooksecurefunc(ItemRefTooltip, "SetHyperlink", ItemQuestEnricher.appendQuestTooltipInfo)
hooksecurefunc(GameTooltip, "SetHyperlink", ItemQuestEnricher.appendQuestTooltipInfo)

addon.FormatRelativeAge = ItemQuestEnricher.composeRelativeAge

-----------------------------------------------------------------------------
-- Compare with equipped gear without Shift
-----------------------------------------------------------------------------
-- The client's own "always compare items" setting drives the comparison tooltips of every
-- item tooltip (bags, chat links, addon windows), so no tooltip code is replaced. The setting
-- is only turned back off if this addon was the one that turned it on.
local COMPARE_CVAR = "alwaysCompareItems"
local compareSyncPending = false

-- One time: this option used to live in EzWoW-BestGearFinder. Keep a choice made there.
function ItemQuestEnricher.migrateEquipCompare()
    local store = EzWoW_TooltipDB
    if type(store) ~= "table" or store.migratedEquipCompare then return end
    store.migratedEquipCompare = true
    local old = _G.EzWoW_BestGearFinderDB
    if type(old) == "table" and old.showEquipCompare == false then
        if type(store.item) == "table" then store.item.showEquipCompare = false end
        local iCfg = addon.db and addon.db.item
        if iCfg then iCfg.showEquipCompare = false end
    end
end

function ItemQuestEnricher.syncEquipCompare()
    -- saved variables of every addon are only loaded at login
    if IsLoggedIn and not IsLoggedIn() then return end
    if InCombatLockdown and InCombatLockdown() then compareSyncPending = true; return end
    compareSyncPending = false
    ItemQuestEnricher.migrateEquipCompare()
    local iCfg = addon.db and addon.db.item
    local store = EzWoW_TooltipDB
    if not iCfg or type(store) ~= "table" then return end
    local getCVar = (C_CVar and C_CVar.GetCVar) or _G.GetCVar
    local setCVar = (C_CVar and C_CVar.SetCVar) or _G.SetCVar
    if type(getCVar) ~= "function" or type(setCVar) ~= "function" then return end
    local ok, current = pcall(getCVar, COMPARE_CVAR)
    if not ok or current == nil or issecret(current) then return end
    -- the first test build had this on by default: put it back to Shift once
    if not store.equipCompareDefaultOff then
        store.equipCompareDefaultOff = true
        iCfg.showEquipCompare = false
    end
    if iCfg.showEquipCompare == true then
        if current ~= "1" then
            pcall(setCVar, COMPARE_CVAR, "1")
            store.equipCompareCVarSet = true
        end
    elseif store.equipCompareCVarSet then
        if current ~= "0" then pcall(setCVar, COMPARE_CVAR, "0") end
        store.equipCompareCVarSet = nil
    end
end
addon.SyncEquipCompare = ItemQuestEnricher.syncEquipCompare

EventDispatcher:attachTrigger("EZWOW_TOOLTIP_GENERAL_INIT", ItemQuestEnricher.syncEquipCompare)
EventDispatcher:attachEvent("PLAYER_LOGIN", ItemQuestEnricher.syncEquipCompare)
EventDispatcher:attachEvent("PLAYER_ENTERING_WORLD", ItemQuestEnricher.syncEquipCompare)
EventDispatcher:attachEvent("PLAYER_REGEN_ENABLED", function()
    if compareSyncPending then ItemQuestEnricher.syncEquipCompare() end
end)
