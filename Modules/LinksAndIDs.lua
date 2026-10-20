--===========================================================================
-- EzWoW - Tooltip
-- Modules/LinksAndIDs.lua : Spell, Item & Aura Icon Prefix and Entry ID Appender
--===========================================================================
local addonName, ns = ...
local type, pairs, ipairs, tonumber, tostring, select, pcall = type, pairs, ipairs, tonumber, tostring, select, pcall

local EntryIdentifierAppender = ns.EntryIdentifierAppender or {}
ns.EntryIdentifierAppender = EntryIdentifierAppender
local platformHelper = ns.compat
local bus = ns.events
local addon = EzWoW_Tooltip

local issecret, nosecret, anysecret = platformHelper.issecret, platformHelper.nosecret, platformHelper.anysecret
local GetItemInfo, GetItemInfoInstant = platformHelper.GetItemInfo, platformHelper.GetItemInfoInstant
local GetItemQualityColor = platformHelper.GetItemQualityColor
local GetSpellTexture = platformHelper.GetSpellTexture
local resolveQuestLevel = platformHelper.GetQuestLevel
local format = string.format

-----------------------------------------------------------------------------
-- Prefix Title Icon
-----------------------------------------------------------------------------

function EntryIdentifierAppender.prefixTitleIcon(tip, tex)
    tex = nosecret(tex)
    if not tex or tex == "" then return end
    local line1 = _G[tip:GetName() .. "TextLeft1"]
    local extractSafeTooltipText = line1 and nosecret(line1:GetText())
    if not extractSafeTooltipText or extractSafeTooltipText == "" then return end
    local tag = format("|T%s:16:16:0:0:32:32:2:30:2:30|t ", tostring(tex))
    if not extractSafeTooltipText:find("^|T") then
        line1:SetFormattedText("%s%s", tag, extractSafeTooltipText)
    end
end

-----------------------------------------------------------------------------
-- Extract Item Quality
-----------------------------------------------------------------------------

function EntryIdentifierAppender.extractItemQuality(link)
    link = nosecret(link)
    if not link then return nil, nil end
    local _, _, quality, _, _, _, _, _, _, tex = GetItemInfo(link)
    if not tex then
        tex = select(5, GetItemInfoInstant(link))
    end
    if not quality then
        local hex = link:match("|c([%x]+)|H")
        if hex and #hex >= 8 then
            local rgb = hex:sub(3):lower()
            for priorityQueue = 0, 8 do
                local _, _, _, qHex = GetItemQualityColor(priorityQueue)
                if qHex and qHex:lower():find(rgb, 1, true) then
                    quality = priorityQueue
                    break
                end
            end
        end
    end
    return quality, tex
end

function EntryIdentifierAppender.onItemTooltip(tip, link)
    link = link or select(2, tip:GetItem())
    if not link or issecret(link) then return end
    local quality, tex = EntryIdentifierAppender.extractItemQuality(link)

    if addon.db.item.coloredItemBorder then
        quality = nosecret(quality)
        if quality and quality >= 0 then
            local rowEntry, greenVal, buttonWidget = GetItemQualityColor(quality)
            bus:trigger("tooltip.style.border.color", tip, rowEntry, greenVal, buttonWidget)
        else
            bus:trigger("tooltip.style.border.color", tip, unpack(addon.db.general.borderColor))
        end
    end

    if addon.db.item.showItemIcon and tex then
        EntryIdentifierAppender.prefixTitleIcon(tip, tex)
    end
end

platformHelper.AddTooltipPostCall("Item", "OnTooltipSetItem", function(tip)
    local _, link = tip:GetItem()
    if link then
        bus:trigger("tooltip:item", tip, link)
    end
end)

if EmbeddedItemTooltip_OnTooltipSetItem then
    hooksecurefunc("EmbeddedItemTooltip_OnTooltipSetItem", function(sub)
        local parentFrame = sub:GetParent()
        if not parentFrame then return end
        local _, link = parentFrame:GetItem()
        if link then
            bus:trigger("tooltip:item", parentFrame, link)
        end
    end)
end

bus:attachTrigger("tooltip:item", function(_, tip, link)
    EntryIdentifierAppender.onItemTooltip(tip, link)
end)

-----------------------------------------------------------------------------
-- On Spell Tooltip
-----------------------------------------------------------------------------

function EntryIdentifierAppender.onSpellTooltip(tip)
    local activeCfg = addon.db.spell
    if activeCfg.background then
        local themeColor = activeCfg.background
        bus:trigger("tooltip.style.bg.color", tip, themeColor[1], themeColor[2], themeColor[3], themeColor[4])
    end
    if activeCfg.borderColor then
        local themeColor = activeCfg.borderColor
        bus:trigger("tooltip.style.border.color", tip, themeColor[1], themeColor[2], themeColor[3], themeColor[4])
    end
    if activeCfg.showIcon then
        local _, spellId = tip:GetSpell()
        local tex = GetSpellTexture(nosecret(spellId))
        EntryIdentifierAppender.prefixTitleIcon(tip, tex)
    end
end

platformHelper.AddTooltipPostCall("Spell", "OnTooltipSetSpell", function(tip)
    bus:trigger("tooltip:spell", tip)
end)

bus:attachTrigger("tooltip:spell", function(_, tip)
    EntryIdentifierAppender.onSpellTooltip(tip)
end)

if ItemRefTooltip and ItemRefTooltip.SetHyperlink then
    hooksecurefunc(ItemRefTooltip, "SetHyperlink", function(tip, link)
        link = nosecret(link)
        if not link or not addon.db.quest.coloredQuestBorder then return end
        local schema, entityID, level = link:match("|?H?(%a+):(%d+):([%-%d]+)")
        if schema and schema:lower() == "quest" then
            level = tonumber(level)
            if not level or level < 0 then
                level = resolveQuestLevel(tonumber(entityID))
            end
            local colorRGB = GetQuestDifficultyColor(level and level > 0 and level or UnitLevel("player"))
            if colorRGB then
                bus:trigger("tooltip.style.border.color", tip, colorRGB.r, colorRGB.g, colorRGB.b)
            end
        end
    end)
end

local mountBySpell = {}

if C_MountJournal and C_MountJournal.GetMountIDs then
    bus:attachEvent("PLAYER_LOGIN", function()
        for _, mountID in ipairs(C_MountJournal.GetMountIDs()) do
            local _, spellID, _, _, _, _, _, _, _, _, hasCollected = C_MountJournal.GetMountInfoByID(mountID)
            if spellID then
                mountBySpell[spellID] = { id = mountID, collected = hasCollected }
            end
        end
    end)

    hooksecurefunc(GameTooltip, "SetUnitAura", function(tip, ...)
        if not UnitAura then return end
        local spellID = select(10, UnitAura(...))
        local entry = mountBySpell[nosecret(spellID)]
        if not entry then return end
        local _, desc, sourceVal = C_MountJournal.GetMountInfoExtraByID(entry.id)
        tip:AddLine(" ")
        if sourceVal and sourceVal ~= "" then
            tip:AddLine(sourceVal, 1, 1, 1)
        end
        if entry.collected then
            tip:AddLine(COLLECTED or "Collected", 0.1, 1, 0.1)
        end
        if desc and desc ~= "" then
            tip:AddLine(desc, 1, 0.82, 0, true)
        end
        tip:Show()
    end)
end

-----------------------------------------------------------------------------
-- Want Idrow
-----------------------------------------------------------------------------

local ID_LABELS = {
    item        = ID or "ID",
    spell       = STAT_CATEGORY_SPELL or "Spell",
    quest       = QUESTS_LABEL or "Quest",
    achievement = ACHIEVEMENT_BUTTON or "Achievement",
}

function EntryIdentifierAppender.wantIDRow()
    return addon.db.general.alwaysShowIdInfo
        or IsShiftKeyDown()
        or IsControlKeyDown()
        or IsAltKeyDown()
end

function EntryIdentifierAppender.appendIDRow(tip, kind, rawId)
    rawId = nosecret(rawId)
    if not rawId or rawId == "" or not EntryIdentifierAppender.wantIDRow() then return end
    local formatLocalizedLabel = addon.L[kind .. ".id"] or ID_LABELS[kind] or ID or "ID"
    local extractSafeTooltipText = format("%s: |cffffffff%s|r", formatLocalizedLabel, tostring(rawId))
    if addon:FindLine(tip, tostring(rawId)) then return end
    tip:AddLine(extractSafeTooltipText, 1, 0.82, 0)
    tip:Show()
end

function EntryIdentifierAppender.appendLinkID(tip, link)
    link = nosecret(link)
    if not link then return end
    local kind, entityID = link:match("|?H?(%a+):(%d+)")
    if kind and entityID then
        EntryIdentifierAppender.appendIDRow(tip, kind:lower(), entityID)
    end
end

bus:attachTrigger("tooltip:item", function(_, tip, link)
    EntryIdentifierAppender.appendLinkID(tip, link)
end)

bus:attachTrigger("tooltip:spell", function(_, tip)
    local _, spellId = tip:GetSpell()
    EntryIdentifierAppender.appendIDRow(tip, "spell", spellId)
end)

if GameTooltip.SetRecipeResultItem then
    hooksecurefunc(GameTooltip, "SetRecipeResultItem", function(tip, recipeId)
        EntryIdentifierAppender.appendIDRow(tip, "spell", recipeId)
    end)
end

if GameTooltip.SetRecipeRankInfo then
    hooksecurefunc(GameTooltip, "SetRecipeRankInfo", function(tip, recipeId)
        EntryIdentifierAppender.appendIDRow(tip, "spell", recipeId)
    end)
end

if GameTooltip.SetArtifactPowerByID and C_ArtifactUI and C_ArtifactUI.GetPowerInfo then
    hooksecurefunc(GameTooltip, "SetArtifactPowerByID", function(tip, powerId)
        local apiInfo = C_ArtifactUI.GetPowerInfo(powerId)
        if apiInfo and apiInfo.spellID then
            EntryIdentifierAppender.appendIDRow(tip, "spell", apiInfo.spellID)
        end
    end)
end

function EntryIdentifierAppender.bindAuraIDs(method)
    if not GameTooltip[method] or not UnitAura then return end
    hooksecurefunc(GameTooltip, method, function(tip, ...)
        local spellId = select(10, UnitAura(...))
        if spellId then
            EntryIdentifierAppender.appendIDRow(tip, "spell", spellId)
        end
        if addon.db.spell.showIcon then
            local tex = select(3, UnitAura(...))
            EntryIdentifierAppender.prefixTitleIcon(tip, tex)
        end
    end)
end

EntryIdentifierAppender.bindAuraIDs("SetUnitAura")
EntryIdentifierAppender.bindAuraIDs("SetUnitBuff")
EntryIdentifierAppender.bindAuraIDs("SetUnitDebuff")

if QuestMapLogTitleButton_OnEnter then
    hooksecurefunc("QuestMapLogTitleButton_OnEnter", function(btn)
        if btn and btn.questID then
            EntryIdentifierAppender.appendIDRow(GameTooltip, "quest", btn.questID)
        end
    end)
end

if ItemRefTooltip and ItemRefTooltip.SetHyperlink then
    hooksecurefunc(ItemRefTooltip, "SetHyperlink", function(tip, link)
        EntryIdentifierAppender.appendLinkID(tip, link)
    end)
end
