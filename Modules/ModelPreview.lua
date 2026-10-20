--===========================================================================
-- EzWoW - Tooltip
-- Modules/ModelPreview.lua : 3D Player & Creature Model Preview Frame on Unit Tooltips
--===========================================================================
local _, ns = ...
local type, pairs, ipairs, tonumber, tostring, select, pcall = type, pairs, ipairs, tonumber, tostring, select, pcall

local UnitModelPreviewer = ns.UnitModelPreviewer or {}
ns.UnitModelPreviewer = UnitModelPreviewer
local TooltipEngine = EzWoW_Tooltip
local PlatformBridge = ns.compat
local EventDispatcher = ns.events
local nosecret = PlatformBridge.nosecret

local MIN_PREVIEW_WIDTH  = 72
local MAX_PREVIEW_WIDTH  = 84
local EDGE_INSET_LEFT    = 2
local EDGE_INSET_TOP     = 3
local EDGE_INSET_BOTTOM  = 2
local TEXT_GAP_PADDING   = 8

local previewContainer = nil
local playerModelWidget = nil
local activeOwnerTooltip = nil
local activeModelGUID = nil
local activeBoxWidth = nil
local inLayoutSync = false

local function CountVisibleTooltipLines(tipFrame)
    if not tipFrame or not tipFrame.NumLines then return 0 end
    local baseName = tipFrame:GetName()
    local total = tipFrame:NumLines() or 0
    if not baseName then return total end
    local count = 0
    for i = 1, total do
        local left = _G[baseName .. "TextLeft" .. i]
        local txt = left and left:IsShown() and nosecret(left:GetText())
        if txt and txt ~= "" and txt ~= " " then
            count = count + 1
        end
    end
    return math.max(count, tipFrame.ezWoWTooltipUnitRows or 0)
end

local function AlignTooltipTextColumn(tipFrame, xOffset)
    if not tipFrame then return end
    local baseName = tipFrame.GetName and tipFrame:GetName()
    if not baseName then return end
    local numLines = (tipFrame.NumLines and tipFrame:NumLines()) or 0
    local maxScan = math.max(numLines, 30)
    local prevLeft = nil
    for i = 1, maxScan do
        local left = _G[baseName .. "TextLeft" .. i]
        if not left then break end
        local _, _, _, _, yOfs = left:GetPoint(1)
        left:ClearAllPoints()
        if i == 1 or not prevLeft then
            left:SetPoint("TOPLEFT", tipFrame, "TOPLEFT", xOffset, yOfs or -10)
        else
            left:SetPoint("TOPLEFT", prevLeft, "BOTTOMLEFT", 0, yOfs or -2)
        end
        prevLeft = left
    end
end

function UnitModelPreviewer.refreshTooltipPadding(tipFrame, padWidth)
    if not tipFrame then return end
    padWidth = padWidth or 0
    if tipFrame.SetMinimumWidth then
        pcall(tipFrame.SetMinimumWidth, tipFrame, 0)
    end
    if tipFrame.SetPadding then
        pcall(tipFrame.SetPadding, tipFrame, padWidth, 0)
    end
end

function UnitModelPreviewer.preparePreviewWidgets()
    if previewContainer then return end
    previewContainer = CreateFrame("Frame", nil, GameTooltip)
    previewContainer:SetFrameLevel(GameTooltip:GetFrameLevel() + 2)
    previewContainer:Hide()

    local backdropTex = previewContainer:CreateTexture(nil, "BACKGROUND")
    backdropTex:SetAllPoints(previewContainer)
    backdropTex:SetColorTexture(0.03, 0.05, 0.07, 0.45)

    local rightRule = previewContainer:CreateTexture(nil, "BORDER")
    rightRule:SetWidth(1)
    rightRule:SetPoint("TOPRIGHT", previewContainer, "TOPRIGHT", 0, 0)
    rightRule:SetPoint("BOTTOMRIGHT", previewContainer, "BOTTOMRIGHT", 0, 0)
    rightRule:SetColorTexture(0.32, 0.45, 0.52, 0.60)
    previewContainer.rightRule = rightRule

    playerModelWidget = CreateFrame("PlayerModel", nil, previewContainer)
    playerModelWidget:SetPoint("TOPLEFT", previewContainer, "TOPLEFT", 1, -1)
    playerModelWidget:SetPoint("BOTTOMRIGHT", previewContainer, "BOTTOMRIGHT", -1, 1)

    if GameTooltip and type(GameTooltip.Show) == "function" then
        hooksecurefunc(GameTooltip, "Show", function(tipFrame)
            if inLayoutSync then return end
            if tipFrame == activeOwnerTooltip and previewContainer and previewContainer:IsShown() then
                UnitModelPreviewer.layoutPreviewInTooltip(tipFrame)
            end
        end)
    end
end

function UnitModelPreviewer.layoutPreviewInTooltip(tipFrame)
    if not previewContainer or not previewContainer:IsShown() or not tipFrame then return end
    if inLayoutSync then return end

    local lineCount = CountVisibleTooltipLines(tipFrame)
    local estimatedH = lineCount * 18 + 20
    local actualH = tipFrame:GetHeight() or 0
    local fullH = math.max(actualH, estimatedH, 104)
    local targetW = math.max(MIN_PREVIEW_WIDTH, math.min(MAX_PREVIEW_WIDTH, math.floor(fullH * 0.65 + 0.5)))

    if activeBoxWidth and targetW < activeBoxWidth then
        targetW = activeBoxWidth
    else
        activeBoxWidth = targetW
    end

    local padW = targetW + TEXT_GAP_PADDING

    inLayoutSync = true
    -- 1. Reset lines to standard x=10 first so C++ GameTooltip:Show() computes clean width/height
    AlignTooltipTextColumn(tipFrame, 10)
    UnitModelPreviewer.refreshTooltipPadding(tipFrame, padW)
    if tipFrame:IsShown() then
        pcall(tipFrame.Show, tipFrame)
    end

    -- 2. Anchor 3D preview container flush to the far left of the tooltip from top to bottom
    previewContainer:ClearAllPoints()
    previewContainer:SetPoint("TOPLEFT", tipFrame, "TOPLEFT", EDGE_INSET_LEFT, -EDGE_INSET_TOP)
    previewContainer:SetPoint("BOTTOMLEFT", tipFrame, "BOTTOMLEFT", EDGE_INSET_LEFT, EDGE_INSET_BOTTOM)
    previewContainer:SetWidth(targetW)

    -- 3. Shift all tooltip text lines (1..N) into a single aligned column to the right of the 3D model
    AlignTooltipTextColumn(tipFrame, EDGE_INSET_LEFT + targetW + TEXT_GAP_PADDING)
    inLayoutSync = false
end

function UnitModelPreviewer.dismissPreviewWidget()
    activeModelGUID = nil
    activeBoxWidth = nil
    if previewContainer and previewContainer:IsShown() then
        previewContainer:Hide()
        if playerModelWidget and playerModelWidget.ClearModel then
            pcall(playerModelWidget.ClearModel, playerModelWidget)
        end
    end
    local tipFrame = activeOwnerTooltip or GameTooltip
    if tipFrame then
        inLayoutSync = true
        AlignTooltipTextColumn(tipFrame, 10)
        UnitModelPreviewer.refreshTooltipPadding(tipFrame, 0)
        inLayoutSync = false
    end
    activeOwnerTooltip = nil
end

function UnitModelPreviewer.hasModelPreviewEnabledForUnit(unitToken)
    if not TooltipEngine.db or TooltipEngine:IsUnitRestricted(unitToken) then
        return false
    end
    if not nosecret(UnitIsVisible(unitToken)) then
        return false
    end
    local unitGroup = nosecret(UnitIsPlayer(unitToken)) and TooltipEngine.db.unit.player or TooltipEngine.db.unit.npc
    return unitGroup and unitGroup.showModel and true or false
end

EventDispatcher:attachTrigger("tooltip:unit", function(_, tipFrame, unitToken)
    if tipFrame ~= GameTooltip then return end
    if not UnitModelPreviewer.hasModelPreviewEnabledForUnit(unitToken) then
        UnitModelPreviewer.dismissPreviewWidget()
        return
    end
    UnitModelPreviewer.preparePreviewWidgets()
    local guid = nosecret(UnitGUID(unitToken))
    local sameUnitShown = previewContainer:IsShown() and activeOwnerTooltip == tipFrame and guid and guid == activeModelGUID
    if not sameUnitShown then
        activeBoxWidth = nil
        local isCallOk = pcall(playerModelWidget.SetUnit, playerModelWidget, unitToken)
        if not isCallOk then
            UnitModelPreviewer.dismissPreviewWidget()
            return
        end
        if playerModelWidget.SetPortraitZoom then pcall(playerModelWidget.SetPortraitZoom, playerModelWidget, 0) end
        if playerModelWidget.SetCamDistanceScale then pcall(playerModelWidget.SetCamDistanceScale, playerModelWidget, 1.05) end
        if playerModelWidget.SetFacing then pcall(playerModelWidget.SetFacing, playerModelWidget, -0.35) end
        activeModelGUID = guid
        previewContainer:Show()
    end
    activeOwnerTooltip = tipFrame
    -- Keep lines at x=10 during tooltip:unit so subsequent Show() measures cleanly before shifting
    AlignTooltipTextColumn(tipFrame, 10)
    local padW = (activeBoxWidth or 76) + TEXT_GAP_PADDING
    UnitModelPreviewer.refreshTooltipPadding(tipFrame, padW)
end)

EventDispatcher:attachTrigger("tooltip:unit:post, tooltip:show, tooltip:layout", function(_, tipFrame)
    if tipFrame == activeOwnerTooltip then
        UnitModelPreviewer.layoutPreviewInTooltip(tipFrame)
    end
end)

EventDispatcher:attachTrigger("tooltip:cleared, tooltip:hide, tooltip:item, tooltip:spell, tooltip:quest", function(_, tipFrame)
    if tipFrame == GameTooltip then
        UnitModelPreviewer.dismissPreviewWidget()
    end
end)
