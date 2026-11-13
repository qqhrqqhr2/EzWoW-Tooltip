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
    if not tex or tex == "" or not tip then return end
    local tipName = tip.GetName and tip:GetName()
    if type(tipName) ~= "string" or issecret(tipName) then return end
    local line1 = _G[tipName .. "TextLeft1"]
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
    link = link or select(2, platformHelper.GetTooltipItem(tip))
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

platformHelper.AddTooltipPostCall("Item", "OnTooltipSetItem", function(tip, data)
    if not addon.IsDecoratableTooltip(tip) then return end
    local _, link = platformHelper.GetTooltipItem(tip, data)
    if link then
        bus:trigger("tooltip:item", tip, link)
    end
end)

if EmbeddedItemTooltip_OnTooltipSetItem then
    hooksecurefunc("EmbeddedItemTooltip_OnTooltipSetItem", function(sub)
        local parentFrame = sub:GetParent()
        if not parentFrame or not addon.IsDecoratableTooltip(parentFrame) then return end
        local _, link = platformHelper.GetTooltipItem(parentFrame)
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

function EntryIdentifierAppender.onSpellTooltip(tip, spellId)
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
        spellId = nosecret(spellId) or select(2, platformHelper.GetTooltipSpell(tip))
        local tex = GetSpellTexture(spellId)
        EntryIdentifierAppender.prefixTitleIcon(tip, tex)
    end
end

platformHelper.AddTooltipPostCall("Spell", "OnTooltipSetSpell", function(tip, data)
    if not addon.IsDecoratableTooltip(tip) then return end
    local _, spellId = platformHelper.GetTooltipSpell(tip, data)
    bus:trigger("tooltip:spell", tip, spellId)
end)

bus:attachTrigger("tooltip:spell", function(_, tip, spellId)
    EntryIdentifierAppender.onSpellTooltip(tip, spellId)
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

    -- only without the UnitAura tooltip data type; otherwise onAuraTooltip adds these lines
    local hasAuraPostCall = _G.TooltipDataProcessor and _G.Enum and _G.Enum.TooltipDataType and _G.Enum.TooltipDataType.UnitAura
    if GameTooltip.SetUnitAura and not hasAuraPostCall then
        hooksecurefunc(GameTooltip, "SetUnitAura", function(tip, unit, index, filter)
            local spellID = platformHelper.GetUnitAuraSpellAndIcon(unit, index, filter)
            if EntryIdentifierAppender.appendMountLines(tip, spellID) then
                addon.AttributeTooltip(tip)
                tip:Show()
            end
        end)
    end
end

-- returns true when lines were added
function EntryIdentifierAppender.appendMountLines(tip, spellID)
    spellID = tonumber(nosecret(spellID))
    local entry = spellID and mountBySpell[spellID]
    if not tip or not entry or not C_MountJournal then return false end
    local okExtra, _, desc, sourceVal = pcall(C_MountJournal.GetMountInfoExtraByID, entry.id)
    if not okExtra then return false end
    -- read at hover time: the login cache goes stale after learning a mount
    local collected = entry.collected
    local okInfo, _, _, _, _, _, _, _, _, _, _, hasCollected = pcall(C_MountJournal.GetMountInfoByID, entry.id)
    if okInfo then collected = hasCollected end
    tip:AddLine(" ")
    if sourceVal and sourceVal ~= "" then
        tip:AddLine(sourceVal, 1, 1, 1)
    end
    if collected then
        tip:AddLine(COLLECTED or "Collected", 0.1, 1, 0.1)
    end
    if desc and desc ~= "" then
        tip:AddLine(desc, 1, 0.82, 0, true)
    end
    return true
end

-----------------------------------------------------------------------------
-- Want Idrow
-----------------------------------------------------------------------------

local ID_LABELS = {
    item        = ID or "ID",
    spell       = STAT_CATEGORY_SPELL or "Spell",
    quest       = QUESTS_LABEL or "Quest",
    achievement = ACHIEVEMENT_BUTTON or "Achievement",
    npc         = "NPC",
}

function EntryIdentifierAppender.wantIDRow()
    return addon.db.general.alwaysShowIdInfo
        or IsShiftKeyDown()
        or IsControlKeyDown()
        or IsAltKeyDown()
end

-- true only when this exact ID row is already on the tooltip (a price or
-- stat line that happens to contain the same number does not count)
function EntryIdentifierAppender.hasIDRow(tip, rowText)
    local tipName = tip and tip.GetName and nosecret(tip:GetName())
    if type(tipName) ~= "string" or not tip.NumLines then return false end
    for lineIdx = 2, tip:NumLines() do
        local left = _G[tipName .. "TextLeft" .. lineIdx]
        if left and nosecret(left:GetText()) == rowText then return true end
    end
    return false
end

function EntryIdentifierAppender.appendIDRow(tip, kind, rawId)
    rawId = nosecret(rawId)
    if not rawId or rawId == "" or not EntryIdentifierAppender.wantIDRow() then return end
    local formatLocalizedLabel = rawget(addon.L, kind .. ".id") or ID_LABELS[kind] or ID or "ID"
    local extractSafeTooltipText = format("%s: |cffffffff%s|r", formatLocalizedLabel, tostring(rawId))
    if EntryIdentifierAppender.hasIDRow(tip, extractSafeTooltipText) then return end
    tip:AddLine(extractSafeTooltipText, 1, 0.82, 0)
    addon.AttributeTooltip(tip)
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

bus:attachTrigger("tooltip:spell", function(_, tip, spellId)
    spellId = spellId or select(2, platformHelper.GetTooltipSpell(tip))
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
    if not GameTooltip[method] then return end
    local defaultFilter = (method == "SetUnitDebuff") and "HARMFUL" or "HELPFUL"
    hooksecurefunc(GameTooltip, method, function(tip, unit, index, filter)
        local spellId, tex = platformHelper.GetUnitAuraSpellAndIcon(unit, index, nosecret(filter) or defaultFilter)
        if spellId then
            EntryIdentifierAppender.appendIDRow(tip, "spell", spellId)
        end
        if addon.db.spell.showIcon then
            EntryIdentifierAppender.prefixTitleIcon(tip, tex)
        end
    end)
end

EntryIdentifierAppender.bindAuraIDs("SetUnitAura")
EntryIdentifierAppender.bindAuraIDs("SetUnitBuff")
EntryIdentifierAppender.bindAuraIDs("SetUnitDebuff")

-- called from the UnitAura post-call (AuraCasterAndPTR.lua), which also covers
-- the Set*ByAuraInstanceID methods; uses no aura API, so it works in combat
function EntryIdentifierAppender.onAuraTooltip(tip, spellId)
    spellId = tonumber(nosecret(spellId))
    if not tip or not spellId then return end
    if addon.db.spell.showIcon then
        EntryIdentifierAppender.prefixTitleIcon(tip, GetSpellTexture(spellId))
    end
    if EntryIdentifierAppender.appendMountLines(tip, spellId) then
        addon.AttributeTooltip(tip)
        if tip:IsShown() then tip:Show() end
    end
    EntryIdentifierAppender.appendIDRow(tip, "spell", spellId)
end

bus:attachTrigger("tooltip:unit:post", function(_, tip, unit)
    if not tip or not unit or nosecret(UnitIsPlayer(unit)) then return end
    local guid = nosecret(UnitGUID(unit))
    if type(guid) ~= "string" then return end
    local kind, npcId = guid:match("^(%a+)%-[^%-]*%-[^%-]*%-[^%-]*%-[^%-]*%-(%d+)")
    if kind == "Creature" or kind == "Vehicle" then
        EntryIdentifierAppender.appendIDRow(tip, "npc", npcId)
    end
end)

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
