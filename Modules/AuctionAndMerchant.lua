--===========================================================================
-- EzWoW - Tooltip
-- Modules/AuctionAndMerchant.lua : Auction House Price Scanner, Cache & Merchant Price Hook
--===========================================================================
local _, ns = ...
local type, pairs, ipairs, tonumber, tostring, select, pcall = type, pairs, ipairs, tonumber, tostring, select, pcall
local AuctionPriceScanner = ns.AuctionPriceScanner or {}
ns.AuctionPriceScanner = AuctionPriceScanner
local EventDispatcher = ns.events
local addon = EzWoW_Tooltip
local compat = select(2, ...).compat
local issecret = compat.issecret
local nosecret = compat.nosecret
local format = string.format
local resolveActiveLocale = addon.GetActiveLocale
local resolveExtraLocaleText = addon.EL
local composeRelativeAge = addon.FormatRelativeAge

local ahScanState = {
    scanning          = false,
    waiting           = false,
    awaitingLegacy    = false,
    awaitingReplicate = false,
    mode              = nil, 
    index             = 1,
    total             = 0,
    minMap            = nil,
    pendingIndices    = nil,
    retryCount        = 0,
    btn               = nil,
    session           = 0,
    scannedSession    = 0,
    lastReqTime       = 0,
}

function AuctionPriceScanner.prepareAuctionStorage()
    EzWoW_TooltipDB = EzWoW_TooltipDB or {}
    if type(EzWoW_TooltipDB.auctionPrices) ~= "table" then
        EzWoW_TooltipDB.auctionPrices = {}
    end
    if type(EzWoW_TooltipDB.auctionTimes) ~= "table" then
        EzWoW_TooltipDB.auctionTimes = {}
    end
    return EzWoW_TooltipDB.auctionPrices, EzWoW_TooltipDB.auctionTimes
end

function addon:CountCachedAuctionPrices()
    local prices = EzWoW_TooltipDB and EzWoW_TooltipDB.auctionPrices
    if type(prices) ~= "table" then return 0 end
    local totalCount2 = 0
    for _, entryValue in pairs(prices) do
        if entryValue then totalCount2 = totalCount2 + 1 end
    end
    return totalCount2
end

function AuctionPriceScanner.notifyAuctionMessage(msg, showBanner)
    if not msg or msg == "" then return end
    print("|cffAEE26AEzWoW - Tooltip:|r " .. msg)
    if showBanner and UIErrorsFrame and UIErrorsFrame.AddMessage then
        pcall(UIErrorsFrame.AddMessage, UIErrorsFrame, "|cffAEE26A[EzWoW - Tooltip]|r " .. msg, 0.682, 0.886, 0.416, 1.0)
    end
end

function AuctionPriceScanner.refreshAhButtonLabel()
    local actionBtn = ahScanState.btn
    if actionBtn and actionBtn.label then
        if ahScanState.scanning then
            if ahScanState.total > 0 and ahScanState.index > 1 then
                local pct = math.min(99, math.floor((ahScanState.index / ahScanState.total) * 100))
                actionBtn.label:SetText(format(resolveExtraLocaleText("ahScanning"), pct))
            else
                actionBtn.label:SetText(resolveExtraLocaleText("ahScanStart"))
            end
        elseif ahScanState.waiting or ahScanState.awaitingLegacy or ahScanState.awaitingReplicate then
            actionBtn.label:SetText(resolveExtraLocaleText("ahScanStart"))
        else
            actionBtn.label:SetText(resolveExtraLocaleText("ahScanBtn"))
        end
    end
    if _G.EzWoWTooltipConfig and _G.EzWoWTooltipConfig:IsShown() and _G.EzWoWTooltipConfig.updateLabels then
        _G.EzWoWTooltipConfig.updateLabels()
    end
end

function AuctionPriceScanner.commitSessionMinPrices(minMap)
    if not minMap then return 0 end
    local prices, times = AuctionPriceScanner.prepareAuctionStorage()
    local currentTime = (GetServerTime and GetServerTime()) or (time and time()) or 0
    local updated = 0
    for itemID, unitPrice in pairs(minMap) do
        if itemID and itemID > 0 and unitPrice and unitPrice > 0 then
            prices[itemID] = unitPrice
            times[itemID] = currentTime
            updated = updated + 1
        end
    end
    if updated > 0 then
        EzWoW_TooltipDB.auctionLastScan = currentTime
    end
    return updated
end

function AuctionPriceScanner.requestItemCacheLoad(itemID)
    if not itemID or itemID <= 0 then return end
    if C_Item and C_Item.RequestLoadItemDataByID then
        pcall(C_Item.RequestLoadItemDataByID, itemID)
    elseif compat.GetItemInfo then
        pcall(compat.GetItemInfo, itemID)
    end
end

function AuctionPriceScanner.extractLegacyAuctionEntry(index, minMap, allowLinkLookup)
    if not GetAuctionItemInfo then return true end
    local displayName, _, totalCount2, _, _, _, r7Val, r8Val, r9Val, r10, r11, _, _, _, _, _, r17, containsAllInfo = GetAuctionItemInfo("list", index)
    local minBid, buyoutPrice, bidAmount, itemID
    if type(r7Val) == "number" and type(r17) ~= "number" then
        
        minBid = r7Val
        buyoutPrice = r9Val
        bidAmount = r10
        itemID = tonumber(r17)
    else
        
        minBid = r8Val
        buyoutPrice = r10
        bidAmount = r11
        itemID = tonumber(r17)
    end
    if (not itemID or itemID <= 0) and allowLinkLookup and GetAuctionItemLink then
        local link = GetAuctionItemLink("list", index)
        if link then
            itemID = tonumber(string.match(link, "item:(%d+)"))
        end
    end
    if not itemID or itemID <= 0 then return true end

    totalCount2 = tonumber(totalCount2) or 0
    buyoutPrice = tonumber(buyoutPrice) or 0
    local effectiveBid = tonumber(bidAmount)
    if not effectiveBid or effectiveBid <= 0 then
        effectiveBid = tonumber(minBid) or 0
    end
    local rawTotal = (buyoutPrice > 0) and buyoutPrice or effectiveBid

    if (not displayName or containsAllInfo == false) and (totalCount2 <= 0 or not rawTotal or rawTotal <= 0) then
        AuctionPriceScanner.requestItemCacheLoad(itemID)
        return false
    end

    if totalCount2 <= 0 then totalCount2 = 1 end
    if not rawTotal or rawTotal <= 0 then return true end

    local unitPrice = math.max(1, math.floor(rawTotal / totalCount2))

    local prev = minMap[itemID]
    if not prev or unitPrice < prev then
        minMap[itemID] = unitPrice
    end
    return true
end

function AuctionPriceScanner.extractReplicateAuctionEntry(index, minMap)
    if not C_AuctionHouse or not C_AuctionHouse.GetReplicateItemInfo then return true end
    local displayName, _, totalCount2, _, _, _, _, minBid, _, buyoutPrice, bidAmount, _, _, _, _, _, itemID, containsAllInfo = C_AuctionHouse.GetReplicateItemInfo(index)
    itemID = tonumber(itemID)
    if not itemID or itemID <= 0 then return true end

    totalCount2 = tonumber(totalCount2) or 0
    buyoutPrice = tonumber(buyoutPrice) or 0
    local effectiveBid = tonumber(bidAmount)
    if not effectiveBid or effectiveBid <= 0 then
        effectiveBid = tonumber(minBid) or 0
    end
    local rawTotal = (buyoutPrice > 0) and buyoutPrice or effectiveBid

    if (not displayName or containsAllInfo == false) and (totalCount2 <= 0 or not rawTotal or rawTotal <= 0) then
        AuctionPriceScanner.requestItemCacheLoad(itemID)
        return false
    end

    if totalCount2 <= 0 then totalCount2 = 1 end
    if not rawTotal or rawTotal <= 0 then return true end

    local unitPrice = math.max(1, math.floor(rawTotal / totalCount2))

    local prev = minMap[itemID]
    if not prev or unitPrice < prev then
        minMap[itemID] = unitPrice
    end
    return true
end

function AuctionPriceScanner.finishChunkedScan()
    local scannedListings = ahScanState.total or 0
    ahScanState.scanning = false
    ahScanState.waiting = false
    ahScanState.awaitingLegacy = false
    ahScanState.awaitingReplicate = false
    local updated = AuctionPriceScanner.commitSessionMinPrices(ahScanState.minMap)
    ahScanState.minMap = nil
    ahScanState.pendingIndices = nil
    ahScanState.retryCount = 0
    AuctionPriceScanner.refreshAhButtonLabel()
    if updated > 0 then
        if resolveActiveLocale() == "koKR" and scannedListings > updated then
            AuctionPriceScanner.notifyAuctionMessage(format("경매장 시세 수집 완료 (전체 매물 %d건 · 고유 아이템 %d종 최저가 저장됨)", scannedListings, updated), true)
        else
            AuctionPriceScanner.notifyAuctionMessage(format(resolveExtraLocaleText("ahScanDone"), updated), true)
        end
    end
end

function AuctionPriceScanner.retryPendingAuctionEntries(session)
    if not ahScanState.scanning or ahScanState.session ~= session then return end
    local pending = ahScanState.pendingIndices
    if not pending or #pending == 0 then
        AuctionPriceScanner.finishChunkedScan()
        return
    end
    local stillPending = {}
    if ahScanState.mode == "legacy" then
        for _, entryIndex in ipairs(pending) do
            if not AuctionPriceScanner.extractLegacyAuctionEntry(entryIndex, ahScanState.minMap, false) then
                stillPending[#stillPending + 1] = entryIndex
            end
        end
    elseif ahScanState.mode == "replicate" then
        for _, entryIndex in ipairs(pending) do
            if not AuctionPriceScanner.extractReplicateAuctionEntry(entryIndex - 1, ahScanState.minMap) then
                stillPending[#stillPending + 1] = entryIndex
            end
        end
    end
    ahScanState.pendingIndices = stillPending
    ahScanState.retryCount = (ahScanState.retryCount or 0) + 1
    if #stillPending > 0 and ahScanState.retryCount < 4 and C_Timer and C_Timer.After then
        C_Timer.After(0.5, function()
            AuctionPriceScanner.retryPendingAuctionEntries(session)
        end)
    else
        AuctionPriceScanner.finishChunkedScan()
    end
end

local ahWorkerFrame = CreateFrame("Frame")
ahWorkerFrame:Hide()
ahWorkerFrame:SetScript("OnUpdate", function(self)
    if not ahScanState.scanning or ahScanState.total <= 0 then
        self:Hide()
        return
    end
    local batchEnd = math.min(ahScanState.index + 600 - 1, ahScanState.total)
    local pending = ahScanState.pendingIndices
    if ahScanState.mode == "legacy" then
        for indexEntry = ahScanState.index, batchEnd do
            if not AuctionPriceScanner.extractLegacyAuctionEntry(indexEntry, ahScanState.minMap, false) and pending then
                pending[#pending + 1] = indexEntry
            end
        end
    elseif ahScanState.mode == "replicate" then
        for indexEntry = ahScanState.index, batchEnd do
            if not AuctionPriceScanner.extractReplicateAuctionEntry(indexEntry - 1, ahScanState.minMap) and pending then
                pending[#pending + 1] = indexEntry
            end
        end
    end
    ahScanState.index = batchEnd + 1
    AuctionPriceScanner.refreshAhButtonLabel()

    if ahScanState.index > ahScanState.total then
        self:Hide()
        if pending and #pending > 0 and C_Timer and C_Timer.After then
            local session = ahScanState.session
            C_Timer.After(0.5, function()
                AuctionPriceScanner.retryPendingAuctionEntries(session)
            end)
        else
            AuctionPriceScanner.finishChunkedScan()
        end
    end
end)

function AuctionPriceScanner.startChunkedScan(mode, totalCount)
    if ahScanState.scanning and ahScanState.mode == mode and ahWorkerFrame:IsShown() then
        return
    end
    ahScanState.scanning = true
    ahScanState.waiting = false
    ahScanState.awaitingLegacy = false
    ahScanState.awaitingReplicate = false
    ahScanState.mode = mode
    ahScanState.index = 1
    ahScanState.total = totalCount
    ahScanState.minMap = {}
    ahScanState.pendingIndices = {}
    ahScanState.retryCount = 0
    AuctionPriceScanner.refreshAhButtonLabel()
    ahWorkerFrame:Show()
end

function AuctionPriceScanner.inspectVisibleLegacyPage(announce)
    if not GetNumAuctionItems then return 0 end
    local batch = GetNumAuctionItems("list") or 0
    
    if batch <= 0 or batch > 100 then return 0 end
    local minMap = {}
    for indexEntry = 1, batch do
        AuctionPriceScanner.extractLegacyAuctionEntry(indexEntry, minMap, true)
    end
    local updated = AuctionPriceScanner.commitSessionMinPrices(minMap)
    if announce and updated > 0 then
        AuctionPriceScanner.notifyAuctionMessage(format(resolveExtraLocaleText("ahScanPage"), updated), true)
    end
    AuctionPriceScanner.refreshAhButtonLabel()
    return updated
end

function AuctionPriceScanner.inspectModernBrowseResults(announce)
    if not C_AuctionHouse or not C_AuctionHouse.GetBrowseResults then return 0 end
    local isCallOk, results = pcall(C_AuctionHouse.GetBrowseResults)
    if not isCallOk or type(results) ~= "table" or #results == 0 then return 0 end
    local minMap = {}
    for _, entry in ipairs(results) do
        local itemID = entry and entry.itemKey and tonumber(entry.itemKey.itemID)
        local minPrice = entry and tonumber(entry.minPrice)
        if itemID and itemID > 0 and minPrice and minPrice > 0 then
            local prev = minMap[itemID]
            if not prev or minPrice < prev then
                minMap[itemID] = minPrice
            end
        end
    end
    local updated = AuctionPriceScanner.commitSessionMinPrices(minMap)
    if announce and updated > 0 then
        AuctionPriceScanner.notifyAuctionMessage(format(resolveExtraLocaleText("ahScanDone"), updated), true)
    end
    AuctionPriceScanner.refreshAhButtonLabel()
    return updated
end

function AuctionPriceScanner.hasAuctionWindowOpen()
    if _G.AuctionHouseFrame and _G.AuctionHouseFrame:IsShown() then return true, "modern" end
    if _G.AuctionFrame and _G.AuctionFrame:IsShown() then return true, "legacy" end
    if C_AuctionHouse and C_AuctionHouse.ReplicateItems and (not IsUsingLegacyAuctionClient or not IsUsingLegacyAuctionClient()) then
        return ahScanState.isOpen, "modern"
    end
    if QueryAuctionItems then
        return ahScanState.isOpen, "legacy"
    end
    return false, nil
end

function addon:BeginAuctionHousePriceScan(isAuto)
    if ahScanState.scanning and ahWorkerFrame:IsShown() then return end
    if isAuto and ahScanState.scannedSession == ahScanState.session then return end

    local hasOpen, uiKind = AuctionPriceScanner.hasAuctionWindowOpen()
    if not hasOpen then
        if not isAuto then
            AuctionPriceScanner.notifyAuctionMessage(resolveExtraLocaleText("ahScanOpen"), false)
        end
        return
    end

    local currentTime = (GetServerTime and GetServerTime()) or (time and time()) or 0

    if uiKind == "modern" and C_AuctionHouse then
        AuctionPriceScanner.inspectModernBrowseResults(false)

        if C_AuctionHouse.ReplicateItems and C_AuctionHouse.GetNumReplicateItems then
            local ready = true
            if C_AuctionHouse.IsThrottledMessageSystemReady then
                local isCallOk, rowEntry = pcall(C_AuctionHouse.IsThrottledMessageSystemReady)
                if isCallOk and rowEntry == false then ready = false end
            end

            if not ready then
                if not ahScanState.waiting then
                    ahScanState.waiting = true
                    AuctionPriceScanner.refreshAhButtonLabel()
                    AuctionPriceScanner.notifyAuctionMessage(resolveExtraLocaleText("ahScanStart"), true)
                end
                local session = ahScanState.session
                if C_Timer and C_Timer.After then
                    C_Timer.After(0.5, function()
                        if ahScanState.session == session and ahScanState.isOpen and not ahScanState.scanning and ahScanState.scannedSession ~= session then
                            addon:BeginAuctionHousePriceScan(true)
                        end
                    end)
                end
                return
            end

            ahScanState.scannedSession = ahScanState.session

            local cachedTotal = C_AuctionHouse.GetNumReplicateItems() or 0
            if currentTime - ahScanState.lastReqTime < 900 and cachedTotal > 0 then
                AuctionPriceScanner.notifyAuctionMessage(resolveExtraLocaleText("ahScanStart"), true)
                AuctionPriceScanner.startChunkedScan("replicate", cachedTotal)
                return
            end

            ahScanState.lastReqTime = currentTime
            ahScanState.waiting = false
            ahScanState.awaitingReplicate = true
            ahScanState.mode = "replicate"
            ahScanState.index = 1
            ahScanState.total = 0
            ahScanState.minMap = {}
            AuctionPriceScanner.refreshAhButtonLabel()
            AuctionPriceScanner.notifyAuctionMessage(resolveExtraLocaleText("ahScanStart"), true)
            pcall(C_AuctionHouse.ReplicateItems)

            local session = ahScanState.session
            if C_Timer and C_Timer.After then
                C_Timer.After(2.5, function()
                    if ahScanState.session == session and ahScanState.awaitingReplicate and not ahScanState.scanning then
                        ahScanState.awaitingReplicate = false
                        local numRep = C_AuctionHouse.GetNumReplicateItems and C_AuctionHouse.GetNumReplicateItems() or 0
                        if numRep > 0 then
                            AuctionPriceScanner.startChunkedScan("replicate", numRep)
                        else
                            AuctionPriceScanner.refreshAhButtonLabel()
                            if C_AuctionHouse.SendBrowseQuery then
                                pcall(C_AuctionHouse.SendBrowseQuery, { searchString = "", sorts = {}, filters = {} })
                            end
                        end
                    end
                end)
            end
            return
        end

        ahScanState.scannedSession = ahScanState.session
        AuctionPriceScanner.inspectModernBrowseResults(true)
        return
    end

    if QueryAuctionItems then
        local canQuery, canQueryAll = false, false
        if CanSendAuctionQuery then
            canQuery, canQueryAll = CanSendAuctionQuery("list")
        end

        if canQueryAll then
            if ITEM_QUALITY_COLORS and not ITEM_QUALITY_COLORS[-1] then
                ITEM_QUALITY_COLORS[-1] = { r = 0, g = 0, b = 0 }
            end
            ahScanState.scannedSession = ahScanState.session
            ahScanState.lastReqTime = currentTime
            ahScanState.waiting = false
            ahScanState.awaitingLegacy = true
            ahScanState.mode = "legacy"
            ahScanState.index = 1
            ahScanState.total = 0
            ahScanState.minMap = {}
            AuctionPriceScanner.refreshAhButtonLabel()
            AuctionPriceScanner.notifyAuctionMessage(resolveExtraLocaleText("ahScanStart"), true)
            pcall(QueryAuctionItems, "", nil, nil, 0, nil, nil, true, false, nil)
            return
        elseif canQuery then
            ahScanState.scannedSession = ahScanState.session
            local visibleCount = GetNumAuctionItems and GetNumAuctionItems("list") or 0
            if visibleCount > 0 and visibleCount <= 100 then
                AuctionPriceScanner.notifyAuctionMessage(resolveExtraLocaleText("ahScanStart"), true)
                AuctionPriceScanner.inspectVisibleLegacyPage(true)
            elseif visibleCount > 100 then
                AuctionPriceScanner.notifyAuctionMessage(resolveExtraLocaleText("ahScanStart"), true)
                AuctionPriceScanner.startChunkedScan("legacy", visibleCount)
            else
                AuctionPriceScanner.notifyAuctionMessage(resolveExtraLocaleText("ahScanStart"), true)
                ahScanState.autoPageQuery = true
                pcall(QueryAuctionItems, "", nil, nil, 0, 0, 0, false, false, nil)
            end
            return
        else
            
            if not ahScanState.waiting then
                ahScanState.waiting = true
                AuctionPriceScanner.refreshAhButtonLabel()
                AuctionPriceScanner.notifyAuctionMessage(resolveExtraLocaleText("ahScanStart"), true)
            end
            local session = ahScanState.session
            if C_Timer and C_Timer.After then
                C_Timer.After(0.5, function()
                    if ahScanState.session == session and ahScanState.isOpen and not ahScanState.scanning and ahScanState.scannedSession ~= session then
                        addon:BeginAuctionHousePriceScan(true)
                    end
                end)
            end
            return
        end
    end
end

function AuctionPriceScanner.prepareAuctionScanButton()
    local parentFrame = (_G.AuctionHouseFrame and _G.AuctionHouseFrame:IsShown() and _G.AuctionHouseFrame)
        or (_G.AuctionFrame and _G.AuctionFrame:IsShown() and _G.AuctionFrame)
        or _G.AuctionHouseFrame or _G.AuctionFrame
    if not parentFrame then return end

    if not ahScanState.btn then
        local actionBtn = CreateFrame("Button", "EzWoWTooltipAHScanButton", parentFrame, BackdropTemplateMixin and "BackdropTemplate" or nil)
        actionBtn:SetSize(164, 22)
        if actionBtn.SetBackdrop then
            ns.UIKit:ApplyBackdrop(actionBtn)
            actionBtn:SetBackdropColor(0.071, 0.094, 0.122, 0.96)
            actionBtn:SetBackdropBorderColor(0.682, 0.886, 0.416, 1.0)
        end
        local lbl = actionBtn:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        lbl:SetPoint("CENTER")
        lbl:SetTextColor(0.682, 0.886, 0.416, 1.0)
        actionBtn.label = lbl

        actionBtn:SetScript("OnEnter", function(self)
            if self.SetBackdropColor then
                self:SetBackdropColor(0.14, 0.22, 0.17, 1.0)
            end
            GameTooltip:SetOwner(self, "ANCHOR_BOTTOMRIGHT")
            GameTooltip:ClearLines()
            GameTooltip:AddLine(resolveExtraLocaleText("ahTipTitle"), 0.682, 0.886, 0.416)
            GameTooltip:AddLine(resolveExtraLocaleText("ahTipDesc"), 0.929, 0.957, 0.969, true)
            GameTooltip:AddLine(resolveExtraLocaleText("ahTipPassive"), 0.655, 0.725, 0.773, true)
            local itemCount = addon:CountCachedAuctionPrices()
            local age = composeRelativeAge(EzWoW_TooltipDB and EzWoW_TooltipDB.auctionLastScan)
            GameTooltip:AddLine(format(resolveExtraLocaleText("ahTipCount"), itemCount) .. age, 0.294, 0.784, 0.910)
            GameTooltip:Show()
        end)
        actionBtn:SetScript("OnLeave", function(self)
            if self.SetBackdropColor then
                self:SetBackdropColor(0.071, 0.094, 0.122, 0.96)
            end
            GameTooltip:Hide()
        end)
        actionBtn:SetScript("OnClick", function()
            addon:BeginAuctionHousePriceScan(false)
        end)
        ahScanState.btn = actionBtn
    end

    local actionBtn = ahScanState.btn
    actionBtn:SetParent(parentFrame)
    actionBtn:ClearAllPoints()
    if parentFrame == _G.AuctionHouseFrame then
        actionBtn:SetPoint("TOPRIGHT", parentFrame, "TOPRIGHT", -34, -3)
    else
        actionBtn:SetPoint("TOPRIGHT", parentFrame, "TOPRIGHT", -38, -14)
    end
    actionBtn:SetFrameLevel((parentFrame:GetFrameLevel() or 1) + 10)
    AuctionPriceScanner.refreshAhButtonLabel()
    actionBtn:Show()
end

function AuctionPriceScanner.handleMerchantShow()
    if IsShiftKeyDown and IsShiftKeyDown() then return end
    local iCfg = addon.db and addon.db.item

    if not iCfg or iCfg.autoSellJunk ~= false then
        local soldCount = 0
        local soldCopper = 0
        local maxBags = NUM_BAG_SLOTS or 4
        for bag = 0, maxBags do
            local numSlots = (C_Container and C_Container.GetContainerNumSlots and C_Container.GetContainerNumSlots(bag))
                or (GetContainerNumSlots and GetContainerNumSlots(bag)) or 0
            for slot = 1, numSlots do
                local link, totalCount2, quality, locked
                if C_Container and C_Container.GetContainerItemInfo then
                    local apiInfo = C_Container.GetContainerItemInfo(bag, slot)
                    if apiInfo then
                        link = apiInfo.hyperlink
                        totalCount2 = apiInfo.stackCount or 1
                        quality = apiInfo.quality
                        locked = apiInfo.isLocked
                    end
                elseif GetContainerItemInfo then
                    local _, itemCountEntry, hasLocked, itemQuality, _, _, itemLink = GetContainerItemInfo(bag, slot)
                    link = itemLink
                    totalCount2 = itemCountEntry or 1
                    quality = itemQuality
                    locked = hasLocked
                end
                if link and not locked then
                    local _, _, priorityQueue, _, _, _, _, _, _, _, sellPrice = GetItemInfo(link)
                    quality = quality or priorityQueue
                    if quality == 0 and sellPrice and sellPrice > 0 then
                        if C_Container and C_Container.UseContainerItem then
                            pcall(C_Container.UseContainerItem, bag, slot)
                        elseif UseContainerItem then
                            pcall(UseContainerItem, bag, slot)
                        end
                        soldCount = soldCount + (totalCount2 or 1)
                        soldCopper = soldCopper + (sellPrice * (totalCount2 or 1))
                    end
                end
            end
        end
        if soldCount > 0 and soldCopper > 0 then
            print("|cffAEE26AEzWoW - Tooltip:|r " .. format(resolveExtraLocaleText("autoSellDone"), soldCount, addon.FormatCopperAsCoinIcons(soldCopper) or tostring(soldCopper)))
        end
    end

    if not iCfg or iCfg.autoRepair ~= false then
        if CanMerchantRepair and CanMerchantRepair() and GetRepairAllCost and RepairAllItems then
            local cost, canRepair = GetRepairAllCost()
            if canRepair and cost and cost > 0 then
                local money = GetMoney and GetMoney() or 0
                if money >= cost then
                    pcall(RepairAllItems)
                    print("|cffAEE26AEzWoW - Tooltip:|r " .. format(resolveExtraLocaleText("autoRepairDone"), addon.FormatCopperAsCoinIcons(cost) or tostring(cost)))
                else
                    print("|cffAEE26AEzWoW - Tooltip:|r |cffE77C70" .. resolveExtraLocaleText("autoRepairNoGold") .. "|r")
                end
            end
        end
    end
end

local extraEventsFrame = CreateFrame("Frame")
for _, eventFrame in ipairs({
    "VARIABLES_LOADED",
    "PLAYER_LOGIN",
    "PLAYER_ENTERING_WORLD",
    "ADDON_LOADED",
    "MERCHANT_SHOW",
    "AUCTION_HOUSE_SHOW",
    "AUCTION_HOUSE_CLOSED",
    "AUCTION_HOUSE_THROTTLED_SYSTEM_READY",
    "AUCTION_ITEM_LIST_UPDATE",
    "REPLICATE_ITEM_LIST_UPDATE",
    "AUCTION_HOUSE_BROWSE_RESULTS_UPDATED",
    "AUCTION_HOUSE_BROWSE_RESULTS_ADDED",
    "COMMODITY_SEARCH_RESULTS_UPDATED",
    "ITEM_SEARCH_RESULTS_UPDATED",
}) do
    pcall(extraEventsFrame.RegisterEvent, extraEventsFrame, eventFrame)
end

extraEventsFrame:SetScript("OnEvent", function(self, event, arg1)
    if event == "VARIABLES_LOADED" or event == "PLAYER_LOGIN" or event == "PLAYER_ENTERING_WORLD" then
        AuctionPriceScanner.prepareAuctionStorage()
        addon:UpdateIssueReportState()
        if C_Timer and C_Timer.After then
            C_Timer.After(0.2, function() addon:UpdateIssueReportState() end)
            C_Timer.After(1.0, function() addon:UpdateIssueReportState() end)
        end
    elseif event == "ADDON_LOADED" then
        addon:UpdateIssueReportState()
        if arg1 == "Blizzard_AuctionUI" or arg1 == "Blizzard_AuctionHouseUI" then
            AuctionPriceScanner.prepareAuctionScanButton()
        end
    elseif event == "MERCHANT_SHOW" then
        AuctionPriceScanner.handleMerchantShow()
    elseif event == "AUCTION_HOUSE_SHOW" then
        ahScanState.isOpen = true
        ahScanState.session = ahScanState.session + 1
        ahScanState.waiting = false
        ahScanState.awaitingLegacy = false
        ahScanState.awaitingReplicate = false
        AuctionPriceScanner.prepareAuctionScanButton()
        local iCfg = addon.db and addon.db.item
        if not iCfg or iCfg.showAuctionPrice ~= false then
            local session = ahScanState.session
            if C_Timer and C_Timer.After then
                C_Timer.After(0.2, function()
                    if ahScanState.isOpen and ahScanState.session == session and ahScanState.scannedSession ~= session then
                        addon:BeginAuctionHousePriceScan(true)
                    end
                end)
            else
                addon:BeginAuctionHousePriceScan(true)
            end
        end
    elseif event == "AUCTION_HOUSE_CLOSED" then
        ahScanState.isOpen = false
        ahScanState.session = ahScanState.session + 1
        ahScanState.scanning = false
        ahScanState.waiting = false
        ahScanState.awaitingLegacy = false
        ahScanState.awaitingReplicate = false
        ahWorkerFrame:Hide()
        AuctionPriceScanner.refreshAhButtonLabel()
    elseif event == "AUCTION_HOUSE_THROTTLED_SYSTEM_READY" then
        if ahScanState.isOpen and ahScanState.waiting and not ahScanState.scanning and ahScanState.scannedSession ~= ahScanState.session then
            addon:BeginAuctionHousePriceScan(true)
        end
    elseif event == "AUCTION_ITEM_LIST_UPDATE" then
        local grandTotal = GetNumAuctionItems and GetNumAuctionItems("list") or 0
        if grandTotal > 0 then
            if ahScanState.awaitingLegacy then
                ahScanState.awaitingLegacy = false
                AuctionPriceScanner.startChunkedScan("legacy", grandTotal)
            elseif not ahScanState.scanning and grandTotal <= 100 then
                local announce = ahScanState.autoPageQuery and true or false
                ahScanState.autoPageQuery = false
                AuctionPriceScanner.inspectVisibleLegacyPage(announce)
            end
        end
    elseif event == "REPLICATE_ITEM_LIST_UPDATE" then
        if ahScanState.awaitingReplicate then
            local grandTotal = C_AuctionHouse and C_AuctionHouse.GetNumReplicateItems and C_AuctionHouse.GetNumReplicateItems() or 0
            ahScanState.awaitingReplicate = false
            if grandTotal > 0 then
                AuctionPriceScanner.startChunkedScan("replicate", grandTotal)
            else
                AuctionPriceScanner.refreshAhButtonLabel()
            end
        end
    elseif event == "AUCTION_HOUSE_BROWSE_RESULTS_UPDATED" or event == "AUCTION_HOUSE_BROWSE_RESULTS_ADDED" then
        AuctionPriceScanner.inspectModernBrowseResults(false)
    elseif event == "COMMODITY_SEARCH_RESULTS_UPDATED" then
        local itemID = tonumber(arg1)
        if itemID and itemID > 0 and C_AuctionHouse and C_AuctionHouse.GetNumCommoditySearchResults then
            local numericVal = C_AuctionHouse.GetNumCommoditySearchResults(itemID) or 0
            if numericVal > 0 then
                local apiInfo = C_AuctionHouse.GetCommoditySearchResultInfo(itemID, 1)
                if apiInfo and apiInfo.unitPrice and apiInfo.unitPrice > 0 then
                    AuctionPriceScanner.commitSessionMinPrices({ [itemID] = apiInfo.unitPrice })
                end
            end
        end
    elseif event == "ITEM_SEARCH_RESULTS_UPDATED" then
        local itemKey = arg1
        local itemID = type(itemKey) == "table" and tonumber(itemKey.itemID)
        if itemID and itemID > 0 and C_AuctionHouse and C_AuctionHouse.GetNumItemSearchResults then
            local numericVal = C_AuctionHouse.GetNumItemSearchResults(itemKey) or 0
            local minUnit
            for indexEntry = 1, numericVal do
                local apiInfo = C_AuctionHouse.GetItemSearchResultInfo(itemKey, indexEntry)
                local price = apiInfo and (tonumber(apiInfo.buyoutAmount) or tonumber(apiInfo.minBid))
                if price and price > 0 and (not minUnit or price < minUnit) then
                    minUnit = price
                end
            end
            if minUnit then
                AuctionPriceScanner.commitSessionMinPrices({ [itemID] = minUnit })
            end
        end
    end
end)
