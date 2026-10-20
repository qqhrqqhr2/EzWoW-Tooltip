--===========================================================================
-- EzWoW - Tooltip
-- Modules/CardStyle.lua : EzWoW Style Tooltip Backdrop, Border, StatusBar & Font Renderer
--===========================================================================
local addonName, ns = ...
local type, pairs, ipairs, tonumber, tostring, select, pcall = type, pairs, ipairs, tonumber, tostring, select, pcall

local CardThemeRenderer = ns.CardThemeRenderer or {}
ns.CardThemeRenderer = CardThemeRenderer
local addon = EzWoW_Tooltip
local platformHelper = ns.compat
local bus = ns.events
local PAL = addon.PALETTE

local WHITE = "Interface\\Buttons\\WHITE8X8"
local HEADER_HEIGHT = 28
local BRACKET_LEN = 10

function CardThemeRenderer.savedDB() return addon.db and addon.db.general end

function CardThemeRenderer.assignShown(region, shown)
    if not region then return end
    if shown then region:Show() else region:Hide() end
end

function CardThemeRenderer.assignNativeVisible(tip, visible)
    local nine = tip.NineSlice
    if nine then
        nine:SetAlpha(visible and 1 or 0)
        CardThemeRenderer.assignShown(nine, visible)
        if nine.Center then CardThemeRenderer.assignShown(nine.Center, false) end
    elseif tip.SetBackdrop and not visible then
        tip:SetBackdrop(nil)
    end
end

function CardThemeRenderer.textureRegion(tip, layer, sub)
    local resolvedValue = tip:CreateTexture(nil, layer, nil, sub)
    resolvedValue:SetTexture(WHITE)
    return resolvedValue
end

function CardThemeRenderer.assembleCard(tip)
    local cardLayout = { bgColor = { PAL.panel[1], PAL.panel[2], PAL.panel[3], 0.92 }, bgFile = WHITE,
                   edgeColor = { PAL.border[1], PAL.border[2], PAL.border[3], 1 }, edgeSize = 1, mode = "angular" }

    cardLayout.fill = CardThemeRenderer.textureRegion(tip, "BACKGROUND", -8)
    cardLayout.fill:SetAllPoints(tip)

    cardLayout.band = tip:CreateTexture(nil, "BACKGROUND", nil, -7)
    cardLayout.band:SetTexture(addon.MEDIA .. "HeaderBg")
    cardLayout.band:SetVertexColor(0.26, 0.35, 0.28, 0.85)

    cardLayout.bandRule = CardThemeRenderer.textureRegion(tip, "BACKGROUND", -6)
    cardLayout.bandRule:SetHeight(1)
    cardLayout.bandRule:SetVertexColor(PAL.accent[1], PAL.accent[2], PAL.accent[3], 0.38)

    cardLayout.gloss = CardThemeRenderer.textureRegion(tip, "BACKGROUND", -5)
    cardLayout.gloss:SetBlendMode("ADD")
    if cardLayout.gloss.SetGradient and _G.CreateColor then
        cardLayout.gloss:SetGradient("VERTICAL", _G.CreateColor(0, 0, 0, 0), _G.CreateColor(1, 1, 1, 0.12))
    elseif cardLayout.gloss.SetGradientAlpha then
        cardLayout.gloss:SetGradientAlpha("VERTICAL", 0, 0, 0, 0, 1, 1, 1, 0.12)
    end

    cardLayout.edges = {}
    for _, side in ipairs({ "top", "bottom", "left", "right" }) do
        cardLayout.edges[side] = CardThemeRenderer.textureRegion(tip, "BORDER", 1)
    end

    cardLayout.topBar = CardThemeRenderer.textureRegion(tip, "BORDER", 2)
    cardLayout.topBar:SetHeight(2)
    cardLayout.topBar:SetVertexColor(PAL.accent[1], PAL.accent[2], PAL.accent[3], 0.95)

    cardLayout.brackets = {}
    for _, corner in ipairs({ "TOPLEFT", "TOPRIGHT", "BOTTOMLEFT", "BOTTOMRIGHT" }) do
        local horizontal, vertical = CardThemeRenderer.textureRegion(tip, "BORDER", 3), CardThemeRenderer.textureRegion(tip, "BORDER", 3)
        horizontal:SetSize(BRACKET_LEN, 2); horizontal:SetPoint(corner, tip, corner, 0, 0)
        vertical:SetSize(2, BRACKET_LEN);   vertical:SetPoint(corner, tip, corner, 0, 0)
        for _, piece in ipairs({ horizontal, vertical }) do
            piece:SetVertexColor(PAL.accent[1], PAL.accent[2], PAL.accent[3], 0.95)
            cardLayout.brackets[#cardLayout.brackets + 1] = piece
        end
    end
    return cardLayout
end

function CardThemeRenderer.layoutCard(tip, cardLayout)
    local recordEntry = cardLayout.edgeSize
    local edges = cardLayout.edges
    edges.top:ClearAllPoints();    edges.top:SetPoint("TOPLEFT", tip, "TOPLEFT");        edges.top:SetPoint("TOPRIGHT", tip, "TOPRIGHT");       edges.top:SetHeight(recordEntry)
    edges.bottom:ClearAllPoints(); edges.bottom:SetPoint("BOTTOMLEFT", tip, "BOTTOMLEFT"); edges.bottom:SetPoint("BOTTOMRIGHT", tip, "BOTTOMRIGHT"); edges.bottom:SetHeight(recordEntry)
    edges.left:ClearAllPoints();   edges.left:SetPoint("TOPLEFT", tip, "TOPLEFT");        edges.left:SetPoint("BOTTOMLEFT", tip, "BOTTOMLEFT");   edges.left:SetWidth(recordEntry)
    edges.right:ClearAllPoints();  edges.right:SetPoint("TOPRIGHT", tip, "TOPRIGHT");     edges.right:SetPoint("BOTTOMRIGHT", tip, "BOTTOMRIGHT"); edges.right:SetWidth(recordEntry)

    cardLayout.band:ClearAllPoints()
    cardLayout.band:SetPoint("TOPLEFT", tip, "TOPLEFT", recordEntry, -recordEntry)
    cardLayout.band:SetPoint("BOTTOMRIGHT", tip, "TOPRIGHT", -recordEntry, -HEADER_HEIGHT)
    cardLayout.bandRule:ClearAllPoints()
    cardLayout.bandRule:SetPoint("TOPLEFT", tip, "TOPLEFT", 6, -HEADER_HEIGHT)
    cardLayout.bandRule:SetPoint("TOPRIGHT", tip, "TOPRIGHT", -6, -HEADER_HEIGHT)
    cardLayout.gloss:ClearAllPoints()
    cardLayout.gloss:SetPoint("TOPLEFT", tip, "TOPLEFT", recordEntry, -recordEntry)
    cardLayout.gloss:SetPoint("BOTTOMRIGHT", tip, "TOPRIGHT", -recordEntry, -HEADER_HEIGHT)
    cardLayout.topBar:ClearAllPoints()
    cardLayout.topBar:SetPoint("TOPLEFT", tip, "TOPLEFT", recordEntry, -recordEntry)
    cardLayout.topBar:SetPoint("TOPRIGHT", tip, "TOPRIGHT", -recordEntry, -recordEntry)
end

function CardThemeRenderer.paintCard(tip, cardLayout)
    local themeColor = cardLayout.bgColor
    if cardLayout.bgFile == WHITE then
        cardLayout.fill:SetColorTexture(themeColor[1], themeColor[2], themeColor[3], themeColor[4] or 1)
    else
        cardLayout.fill:SetTexture(cardLayout.bgFile)
        cardLayout.fill:SetVertexColor(themeColor[1], themeColor[2], themeColor[3], themeColor[4] or 1)
    end

    local angular = cardLayout.mode ~= "default"
    local ecVal = cardLayout.edgeColor
    for _, edge in pairs(cardLayout.edges) do
        edge:SetVertexColor(ecVal[1], ecVal[2], ecVal[3], ecVal[4] or 1)
        CardThemeRenderer.assignShown(edge, angular)
    end
    for _, piece in ipairs(cardLayout.brackets) do CardThemeRenderer.assignShown(piece, angular) end
    CardThemeRenderer.assignShown(cardLayout.topBar, angular)
    CardThemeRenderer.assignShown(cardLayout.band, angular)
    CardThemeRenderer.assignShown(cardLayout.bandRule, angular)

    CardThemeRenderer.assignNativeVisible(tip, not angular)
    if not angular and tip.NineSlice and tip.NineSlice.SetBorderColor then
        tip.NineSlice:SetBorderColor(ecVal[1], ecVal[2], ecVal[3], ecVal[4] or 1)
    end
end

local bootstrapDone = {}

function CardThemeRenderer.skin(tip)
    if not tip or (tip.IsForbidden and tip:IsForbidden()) then return end
    if tip.ezCard then return tip.ezCard end
    local cardLayout = CardThemeRenderer.assembleCard(tip)
    tip.ezCard = cardLayout
    CardThemeRenderer.layoutCard(tip, cardLayout)
    CardThemeRenderer.paintCard(tip, cardLayout)

    if not bootstrapDone[tip] then
        bootstrapDone[tip] = true
        tip:HookScript("OnShow", function(self) bus:trigger("tooltip:show", self) end)
        tip:HookScript("OnHide", function(self) bus:trigger("tooltip:hide", self) end)
        if tip:HasScript("OnTooltipCleared") then
            tip:HookScript("OnTooltipCleared", function(self) bus:trigger("tooltip:cleared", self) end)
        end
        if tip:HasScript("OnTooltipSetQuest") then
            tip:HookScript("OnTooltipSetQuest", function(self) bus:trigger("tooltip:quest", self) end)
        end
    end
    addon.TrackTooltip(tip)
    bus:trigger("tooltip:init", tip)
    return cardLayout
end
addon.SkinTooltip = CardThemeRenderer.skin

function addon:ApplyTooltipBorderColor(tip, r, g, b, a)
    local cardLayout = CardThemeRenderer.skin(tip)
    if not cardLayout then return end
    cardLayout.edgeColor = { r or 1, g or 1, b or 1, a or 1 }
    CardThemeRenderer.paintCard(tip, cardLayout)
end

function addon:ApplyTooltipBackgroundColor(tip, r, g, b, a)
    local cardLayout = CardThemeRenderer.skin(tip)
    if not cardLayout then return end
    local previousVal = cardLayout.bgColor
    cardLayout.bgColor = { r or previousVal[1], g or previousVal[2], b or previousVal[3], a or previousVal[4] }
    CardThemeRenderer.paintCard(tip, cardLayout)
end

function addon:RestoreDefaultTooltipTheme(tip)
    local g = CardThemeRenderer.savedDB()
    if not g or not tip.ezCard then return end
    local bcVal, backdropTex = g.borderColor, g.background
    self:ApplyTooltipBorderColor(tip, bcVal[1], bcVal[2], bcVal[3], bcVal[4])
    self:ApplyTooltipBackgroundColor(tip, backdropTex[1], backdropTex[2], backdropTex[3], backdropTex[4])
end

bus:attachTrigger("tooltip.style.init", function(_, tip) CardThemeRenderer.skin(tip) end)

bus:attachTrigger("tooltip.scale", function(_, tip, scale)
    if tip then tip:SetScale(tonumber(scale) or 1) end
end)

bus:attachTrigger("tooltip.style.mask", function(_, tip, enabled)
    local cardLayout = CardThemeRenderer.skin(tip)
    if cardLayout then CardThemeRenderer.assignShown(cardLayout.gloss, enabled and true or false) end
end)

bus:attachTrigger("tooltip.style.background, tooltip.style.bg.color", function(_, tip, r, g, b, a)
    addon:ApplyTooltipBackgroundColor(tip, r, g, b, a)
end)

bus:attachTrigger("tooltip.style.bgfile", function(_, tip, key)
    local cardLayout = CardThemeRenderer.skin(tip)
    if not cardLayout then return end
    cardLayout.bgFile = addon.bgs[key] or (type(key) == "string" and key:find("\\", 1, true) and key) or WHITE
    CardThemeRenderer.paintCard(tip, cardLayout)
end)

bus:attachTrigger("tooltip.style.border.size", function(_, tip, size)
    local cardLayout = CardThemeRenderer.skin(tip)
    if not cardLayout then return end
    cardLayout.edgeSize = math.max(1, math.min(6, tonumber(size) or 1))
    CardThemeRenderer.layoutCard(tip, cardLayout)
end)

bus:attachTrigger("tooltip.style.border.corner", function(_, tip, mode)
    local cardLayout = CardThemeRenderer.skin(tip)
    if not cardLayout then return end
    cardLayout.mode = (mode == "default") and "default" or "angular"
    CardThemeRenderer.paintCard(tip, cardLayout)
end)

bus:attachTrigger("tooltip.style.border.color", function(_, tip, r, g, b, a)
    addon:ApplyTooltipBorderColor(tip, r, g, b, a)
end)

local fontDefaults = {}
function CardThemeRenderer.commitFont(object, face, size, flag)
    if not object or not object.GetFont then return end
    if not fontDefaults[object] then fontDefaults[object] = { object:GetFont() } end
    local base = fontDefaults[object]
    local newFace = (face ~= "default" and _G[face] and _G[face].GetFont and (_G[face]:GetFont())) or base[1]
    local newSize = (size ~= "default" and tonumber(size)) or base[2]
    local newFlag = (flag ~= "default" and platformHelper.FontFlag(flag)) or base[3]
    if newFace and newSize then object:SetFont(newFace, newSize, newFlag or "") end
end

bus:attachTrigger("tooltip.style.font.header", function(_, _, face, size, flag)
    CardThemeRenderer.commitFont(_G.GameTooltipHeaderText, face, size, flag)
end)
bus:attachTrigger("tooltip.style.font.body", function(_, _, face, size, flag)
    CardThemeRenderer.commitFont(_G.GameTooltipText, face, size, flag)
    CardThemeRenderer.commitFont(_G.GameTooltipTextSmall, face, size, flag)
end)

local statusBar = _G.GameTooltipStatusBar
local barParts

function CardThemeRenderer.tooltipUnit()
    if GameTooltip.GetUnit then
        local _, unit = GameTooltip:GetUnit()
        if unit and not platformHelper.issecret(unit) then return unit end
    end
    local focus = platformHelper.GetMouseFocus()
    local unit = focus and focus.unit
    if unit and not platformHelper.issecret(unit) then return unit end
    return "mouseover"
end

function CardThemeRenderer.composeNumber(v)
    if _G.AbbreviateLargeNumbers then return _G.AbbreviateLargeNumbers(v) end
    return v
end

function CardThemeRenderer.syncBarText()
    if not barParts then return end
    local g = CardThemeRenderer.savedDB()
    local extractSafeTooltipText = barParts.text
    if not g or not g.statusbarText or statusBar.forceHideText then extractSafeTooltipText:Hide() return end
    local unit = CardThemeRenderer.tooltipUnit()
    if not UnitExists(unit) then extractSafeTooltipText:SetText("") extractSafeTooltipText:Hide() return end
    extractSafeTooltipText:Show()
    local hpVal, maxHp = UnitHealth(unit), UnitHealthMax(unit)
    local dead = platformHelper.nosecret(UnitIsDeadOrGhost(unit))
    local isCallOk = pcall(function()
        if dead then
            extractSafeTooltipText:SetFormattedText("|cff999999%s|r  |cffEA837E[%s]|r", CardThemeRenderer.composeNumber(maxHp), _G.DEAD or "Dead")
        else
            extractSafeTooltipText:SetFormattedText("|cffAEE26AHP|r  %s / %s", CardThemeRenderer.composeNumber(hpVal), CardThemeRenderer.composeNumber(maxHp))
        end
    end)
    if not isCallOk then
        
        if not pcall(extractSafeTooltipText.SetFormattedText, extractSafeTooltipText, "|cffAEE26AHP|r  %d / %d", hpVal, maxHp) then extractSafeTooltipText:Hide() end
    end
end

function CardThemeRenderer.colorBar()
    local g = CardThemeRenderer.savedDB()
    if not g or g.statusbarColor ~= "auto" then return end
    local unit = CardThemeRenderer.tooltipUnit()
    if addon:IsUnitRestricted(unit) or not UnitExists(unit) then return end
    local r, ggVal, b
    if UnitIsPlayer(unit) then
        local _, classFile = UnitClass(unit)
        local colorRGB = classFile and _G.RAID_CLASS_COLORS and _G.RAID_CLASS_COLORS[classFile]
        if colorRGB then r, ggVal, b = colorRGB.r, colorRGB.g, colorRGB.b end
    else
        local reaction = UnitReaction(unit, "player")
        local colorRGB = reaction and _G.FACTION_BAR_COLORS and _G.FACTION_BAR_COLORS[reaction]
        if colorRGB then r, ggVal, b = colorRGB.r, colorRGB.g, colorRGB.b end
    end
    if r then statusBar:SetStatusBarColor(r, ggVal, b) end
end

function CardThemeRenderer.anchorBar()
    local g = CardThemeRenderer.savedDB()
    if not barParts or not g then return end
    local frameHeight = tonumber(g.statusbarHeight) or 8
    statusBar:ClearAllPoints()
    if frameHeight <= 0 then
        statusBar:SetAlpha(0)
        return
    end
    statusBar:SetAlpha(1)
    statusBar:SetHeight(frameHeight)
    local coordX, coordY = tonumber(g.statusbarOffsetX) or 0, tonumber(g.statusbarOffsetY) or 0
    if g.statusbarPosition == "top" then
        statusBar:SetPoint("BOTTOMLEFT", GameTooltip, "TOPLEFT", 1 + coordX, 2 + coordY)
        statusBar:SetPoint("BOTTOMRIGHT", GameTooltip, "TOPRIGHT", -1 + coordX, 2 + coordY)
    else
        statusBar:SetPoint("TOPLEFT", GameTooltip, "BOTTOMLEFT", 1 + coordX, -2 + coordY)
        statusBar:SetPoint("TOPRIGHT", GameTooltip, "BOTTOMRIGHT", -1 + coordX, -2 + coordY)
    end
end

function CardThemeRenderer.assembleBar()
    if barParts or not statusBar then return end
    barParts = {}
    barParts.back = statusBar:CreateTexture(nil, "BACKGROUND")
    barParts.back:SetAllPoints()
    barParts.back:SetColorTexture(0.04, 0.06, 0.08, 0.95)
    barParts.rule = statusBar:CreateTexture(nil, "BORDER")
    barParts.rule:SetPoint("TOPLEFT", statusBar, "TOPLEFT", 0, 1)
    barParts.rule:SetPoint("TOPRIGHT", statusBar, "TOPRIGHT", 0, 1)
    barParts.rule:SetHeight(1)
    barParts.rule:SetColorTexture(PAL.border[1], PAL.border[2], PAL.border[3], 1)
    barParts.text = statusBar:CreateFontString(nil, "OVERLAY")
    barParts.text:SetPoint("CENTER", statusBar, "CENTER", 0, 0)
    statusBar.TextString = barParts.text
    statusBar:HookScript("OnShow", function() CardThemeRenderer.colorBar(); CardThemeRenderer.syncBarText() end)
    statusBar:HookScript("OnValueChanged", function() CardThemeRenderer.colorBar(); CardThemeRenderer.syncBarText() end)
end

function CardThemeRenderer.styleBarText()
    local g = CardThemeRenderer.savedDB()
    if not barParts or not g then return end
    local face = _G.STANDARD_TEXT_FONT or "Fonts\\FRIZQT__.TTF"
    barParts.text:SetFont(face, tonumber(g.statusbarFontSize) or 10, platformHelper.FontFlag(g.statusbarFontFlag or "THINOUTLINE"))
end

bus:attachTrigger("tooltip.statusbar.height", function() CardThemeRenderer.assembleBar(); CardThemeRenderer.anchorBar() end)
bus:attachTrigger("tooltip.statusbar.position", function() CardThemeRenderer.assembleBar(); CardThemeRenderer.anchorBar() end)
bus:attachTrigger("tooltip.statusbar.text", function() CardThemeRenderer.assembleBar(); CardThemeRenderer.syncBarText() end)
bus:attachTrigger("tooltip.statusbar.font", function() CardThemeRenderer.assembleBar(); CardThemeRenderer.styleBarText() end)
bus:attachTrigger("tooltip.statusbar.texture", function(_, file)
    CardThemeRenderer.assembleBar()
    if statusBar then statusBar:SetStatusBarTexture(file or (addon.MEDIA .. "StatusBar")) end
end)

local EXTRA_FRAMES = {
    "EmbeddedItemTooltip", "FriendsTooltip", "ReputationParagonTooltip", "BattlePetTooltip",
    "FloatingBattlePetTooltip", "FloatingPetBattleAbilityTooltip", "QuickKeybindTooltip",
    "SettingsTooltip", "SmallTextTooltip", "GameSmallHeaderTooltip",
}

function CardThemeRenderer.skinExtraFrames()
    local g = CardThemeRenderer.savedDB()
    if not g or not g.skinMoreFrames then return end
    for _, frameName in ipairs(EXTRA_FRAMES) do
        local containerFrame = _G[frameName]
        if containerFrame and containerFrame.CreateTexture and not containerFrame.ezCard then
            addon.TrackTooltip(containerFrame)
        end
    end
end

function addon:ApplyTooltipCardStyle()
    local g = CardThemeRenderer.savedDB()
    if not g then return end
    CardThemeRenderer.skinExtraFrames()
    for _, tip in ipairs(self.tooltips) do
        CardThemeRenderer.skin(tip)
        bus:trigger("tooltip.scale", tip, g.scale)
        bus:trigger("tooltip.style.mask", tip, g.mask)
        bus:trigger("tooltip.style.bgfile", tip, g.bgfile)
        bus:trigger("tooltip.style.border.corner", tip, g.borderCorner)
        bus:trigger("tooltip.style.border.size", tip, g.borderSize)
        bus:trigger("tooltip.style.border.color", tip, unpack(g.borderColor))
        bus:trigger("tooltip.style.background", tip, unpack(g.background))
    end
    bus:trigger("tooltip.style.font.header", GameTooltip, g.headerFont, g.headerFontSize, g.headerFontFlag)
    bus:trigger("tooltip.style.font.body", GameTooltip, g.bodyFont, g.bodyFontSize, g.bodyFontFlag)
    bus:trigger("tooltip.statusbar.texture", g.statusbarTexture)
    bus:trigger("tooltip.statusbar.font", g.statusbarFont, g.statusbarFontSize, g.statusbarFontFlag)
    bus:trigger("tooltip.statusbar.height", g.statusbarHeight)
    bus:trigger("tooltip.statusbar.text", g.statusbarText)
end

bus:attachTrigger("EZWOW_TOOLTIP_GENERAL_INIT, tooltip:variables:loaded", function() addon:ApplyTooltipCardStyle() end)

bus:attachTrigger("tooltip:cleared", function(_, tip) addon:RestoreDefaultTooltipTheme(tip) end)

function CardThemeRenderer.reassert(tip)
    if tip and tip.ezCard then CardThemeRenderer.paintCard(tip, tip.ezCard) end
end
if _G.SharedTooltip_SetBackdropStyle then hooksecurefunc("SharedTooltip_SetBackdropStyle", CardThemeRenderer.reassert) end
if _G.GameTooltip_SetBackdropStyle then hooksecurefunc("GameTooltip_SetBackdropStyle", CardThemeRenderer.reassert) end

if GameTooltip.FadeOut then
    hooksecurefunc(GameTooltip, "FadeOut", function(self)
        local g = CardThemeRenderer.savedDB()
        if g and not g.fadeOut then self:Hide() end
    end)
end
