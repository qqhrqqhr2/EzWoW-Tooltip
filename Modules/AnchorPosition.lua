--===========================================================================
-- EzWoW - Tooltip
-- Modules/AnchorPosition.lua : Dynamic Cursor Follow, Static Anchor & Corner Placement
--===========================================================================
local _, ns = ...
local type, pairs, ipairs, tonumber, tostring, select, pcall = type, pairs, ipairs, tonumber, tostring, select, pcall

local AnchorPlacementEngine = ns.AnchorPlacementEngine or {}
ns.AnchorPlacementEngine = AnchorPlacementEngine
local TooltipEngine = EzWoW_Tooltip
local PlatformBridge = ns.compat
local EventDispatcher = ns.events

local CURSOR_PRESETS = {
    topLeft      = { cp = "BOTTOMRIGHT", cx = -14, cy = 14 },
    topCenter    = { cp = "BOTTOM",      cx = 0,   cy = 22 },
    topRight     = { cp = "BOTTOMLEFT",  cx = 18,  cy = 14 },
    bottomLeft   = { cp = "TOPRIGHT",    cx = -14, cy = -22 },
    bottomCenter = { cp = "TOP",         cx = 0,   cy = -26 },
    bottomRight  = { cp = "TOPLEFT",     cx = 22,  cy = -22 },
}
TooltipEngine.CURSOR_DIRS = CURSOR_PRESETS

local LEGACY_ANCHOR_MAP = {
    BOTTOMRIGHT = "topLeft",
    BOTTOM      = "topCenter",
    BOTTOMLEFT  = "topRight",
    TOPRIGHT    = "bottomLeft",
    TOP         = "bottomCenter",
    TOPLEFT     = "bottomRight",
}

function TooltipEngine.ResolveCursorParams(anchorCfg)
    local dirKey = anchorCfg and anchorCfg.cursorDir
    if not CURSOR_PRESETS[dirKey or ""] then
        if anchorCfg and anchorCfg.position == "cursorRight" then
            dirKey = "bottomRight"
        else
            dirKey = LEGACY_ANCHOR_MAP[anchorCfg and anchorCfg.cp or ""] or "topRight"
        end
    end
    local activeCfg = CURSOR_PRESETS[dirKey]
    return activeCfg.cp, activeCfg.cx, activeCfg.cy, dirKey
end

local CORNER_ANCHOR_MAP = {
    defaultTopLeft     = "TOPLEFT",
    defaultBottomLeft  = "BOTTOMLEFT",
    defaultTopRight    = "TOPRIGHT",
    defaultBottomRight = "BOTTOMRIGHT",
}

local cursorDriver = CreateFrame("Frame")
cursorDriver:Hide()
local activeCursorTarget = nil

function AnchorPlacementEngine.refreshCursorTooltipPosition()
    if not activeCursorTarget then return end
    local tipFrame = activeCursorTarget.tip
    local posX, posY = GetCursorPosition()
    local effScale = tipFrame:GetEffectiveScale()
    if activeCursorTarget.lastX == posX and activeCursorTarget.lastY == posY and activeCursorTarget.lastScale == effScale then
        return
    end
    activeCursorTarget.lastX, activeCursorTarget.lastY, activeCursorTarget.lastScale = posX, posY, effScale
    tipFrame:ClearAllPoints()
    tipFrame:SetPoint(
        activeCursorTarget.point,
        UIParent,
        "BOTTOMLEFT",
        posX / effScale + activeCursorTarget.dx,
        posY / effScale + activeCursorTarget.dy
    )
end

cursorDriver:SetScript("OnUpdate", function()
    if not activeCursorTarget or not activeCursorTarget.tip:IsShown() then
        activeCursorTarget = nil
        cursorDriver:Hide()
        return
    end
    AnchorPlacementEngine.refreshCursorTooltipPosition()
end)

function AnchorPlacementEngine.releaseCursorTracking(tipFrame)
    if activeCursorTarget and (not tipFrame or activeCursorTarget.tip == tipFrame) then
        activeCursorTarget = nil
        cursorDriver:Hide()
    end
end

local internalOwnerLock = false
hooksecurefunc(GameTooltip, "SetOwner", function(tipFrame)
    if not internalOwnerLock then
        AnchorPlacementEngine.releaseCursorTracking(tipFrame)
    end
end)
EventDispatcher:attachTrigger("tooltip:hide", function(_, tipFrame)
    AnchorPlacementEngine.releaseCursorTracking(tipFrame)
end)

function AnchorPlacementEngine.bindTooltipToCursor(tipFrame, ownerFrame, anchorCfg)
    local anchorPoint, offsetX, offsetY = TooltipEngine.ResolveCursorParams(anchorCfg)
    internalOwnerLock = true
    tipFrame:SetOwner(ownerFrame or UIParent, "ANCHOR_NONE")
    internalOwnerLock = false
    activeCursorTarget = { tip = tipFrame, point = anchorPoint, dx = offsetX, dy = offsetY }
    AnchorPlacementEngine.refreshCursorTooltipPosition()
    cursorDriver:Show()
end

function AnchorPlacementEngine.commitStaticPlacement(tipFrame, anchorCfg)
    local anchorPoint = anchorCfg.p or "BOTTOMRIGHT"
    local posXEntry = tonumber(anchorCfg.x) or -((_G.CONTAINER_OFFSET_X or 0) + 13)
    local posYEntry = tonumber(anchorCfg.y) or (_G.CONTAINER_OFFSET_Y or 0)
    tipFrame:ClearAllPoints()
    tipFrame:SetPoint(anchorPoint, UIParent, anchorPoint, posXEntry, posYEntry)
end

function AnchorPlacementEngine.commitCornerPin(tipFrame, cornerPt)
    local _, relFrame = tipFrame:GetPoint(1)
    if PlatformBridge.issecret(relFrame) then return end
    relFrame = relFrame or _G.GameTooltipDefaultContainer or UIParent
    tipFrame:ClearAllPoints()
    tipFrame:SetPoint(cornerPt, relFrame, cornerPt, 0, 0)
end

local dismissInCombatActive = false
EventDispatcher:attachTrigger("tooltip:show", function(_, tipFrame)
    if dismissInCombatActive and tipFrame == GameTooltip then
        tipFrame:Hide()
    end
end)
EventDispatcher:attachTrigger("tooltip:hide", function(_, tipFrame)
    if tipFrame == GameTooltip then
        dismissInCombatActive = false
    end
end)

function AnchorPlacementEngine.determineHoveredUnitContext()
    local focusFrame = PlatformBridge.GetMouseFocus()
    local unitToken, hasUnitFrame
    if focusFrame and focusFrame.unit then
        unitToken, hasUnitFrame = focusFrame.unit, true
    elseif focusFrame and focusFrame.GetAttribute then
        unitToken = focusFrame:GetAttribute("unit")
    end
    if not unitToken or PlatformBridge.issecret(unitToken) then
        unitToken = "mouseover"
    end
    return unitToken, hasUnitFrame
end

function AnchorPlacementEngine.commitAnchorRule(tipFrame, ownerFrame, anchorCfg, hasUnitFrame, isFallbackPass)
    if not anchorCfg then return end
    local combatActive = InCombatLockdown()
    if anchorCfg.hiddenInCombat and combatActive then
        dismissInCombatActive = true
        tipFrame:Hide()
        return
    end
    if (anchorCfg.returnInCombat and combatActive) or (anchorCfg.returnOnUnitFrame and hasUnitFrame) then
        return
    end
    local posMode = anchorCfg.position
    if posMode == "inherit" then
        if not isFallbackPass then
            AnchorPlacementEngine.commitAnchorRule(tipFrame, ownerFrame, TooltipEngine.db.general.anchor, hasUnitFrame, true)
        end
    elseif posMode == "cursor" or posMode == "cursorRight" then
        AnchorPlacementEngine.bindTooltipToCursor(tipFrame, ownerFrame, anchorCfg)
    elseif posMode == "static" then
        AnchorPlacementEngine.commitStaticPlacement(tipFrame, anchorCfg)
    elseif CORNER_ANCHOR_MAP[posMode] then
        AnchorPlacementEngine.commitCornerPin(tipFrame, CORNER_ANCHOR_MAP[posMode])
    end
end

function TooltipEngine:PositionTooltip(tipFrame, ownerFrame)
    if tipFrame ~= GameTooltip or not self.db then return end
    AnchorPlacementEngine.releaseCursorTracking(tipFrame)
    dismissInCombatActive = false
    local unitToken, hasUnitFrame = AnchorPlacementEngine.determineHoveredUnitContext()
    local unitCfg = self.db.unit
    if PlatformBridge.nosecret(UnitIsPlayer(unitToken)) then
        AnchorPlacementEngine.commitAnchorRule(tipFrame, ownerFrame, unitCfg.player.anchor, hasUnitFrame, false)
    elseif PlatformBridge.nosecret(UnitExists(unitToken)) then
        AnchorPlacementEngine.commitAnchorRule(tipFrame, ownerFrame, unitCfg.npc.anchor, hasUnitFrame, false)
    else
        AnchorPlacementEngine.commitAnchorRule(tipFrame, ownerFrame, self.db.general.anchor, hasUnitFrame, true)
    end
end

hooksecurefunc("GameTooltip_SetDefaultAnchor", function(tipFrame, ownerFrame)
    TooltipEngine:PositionTooltip(tipFrame, ownerFrame)
    EventDispatcher:trigger("tooltip:anchor", tipFrame, ownerFrame)
end)
