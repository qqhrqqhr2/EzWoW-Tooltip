--===========================================================================
-- EzWoW - Tooltip
-- Modules/ChatLinkHover.lua : Show Tooltips for Chat Links on Mouseover
--===========================================================================
local addonName, ns = ...
local type, pairs, ipairs, tonumber, tostring, select, pcall = type, pairs, ipairs, tonumber, tostring, select, pcall

local ChatLinkHover = ns.ChatLinkHover or {}
ns.ChatLinkHover = ChatLinkHover
local addon = EzWoW_Tooltip

-- Link types GameTooltip:SetHyperlink can render; anything else (player, url,
-- addon-defined links) keeps its normal click behaviour only.
local HOVER_LINK_TYPES = {
    item = true, spell = true, enchant = true, quest = true, achievement = true,
    talent = true, currency = true, glyph = true, instancelock = true, unit = true,
    mount = true, keystone = true, transmogappearance = true, transmogillusion = true,
}

local hookedFrames = {}
local shownFrom

function ChatLinkHover.isEnabled()
    local itemCfg = addon and addon.db and addon.db.item
    return not itemCfg or itemCfg.chatLinkHover ~= false
end

function ChatLinkHover.onEnter(chatFrame, link)
    if not ChatLinkHover.isEnabled() or type(link) ~= "string" then return end
    if _G.issecretvalue and _G.issecretvalue(link) then return end
    local linkType = link:match("^([^:]+)")
    if not HOVER_LINK_TYPES[linkType] then return end
    GameTooltip:SetOwner(chatFrame, "ANCHOR_CURSOR_RIGHT", 16, 0)
    if pcall(GameTooltip.SetHyperlink, GameTooltip, link) then
        GameTooltip:Show()
        shownFrom = chatFrame
    else
        GameTooltip:Hide()
    end
end

function ChatLinkHover.onLeave(chatFrame)
    if shownFrom and shownFrom == chatFrame then
        shownFrom = nil
        if GameTooltip:GetOwner() == chatFrame then GameTooltip:Hide() end
    end
end

function ChatLinkHover.bindFrame(chatFrame)
    if not chatFrame or hookedFrames[chatFrame] or not chatFrame.HookScript then return end
    hookedFrames[chatFrame] = true
    chatFrame:HookScript("OnHyperlinkEnter", ChatLinkHover.onEnter)
    chatFrame:HookScript("OnHyperlinkLeave", ChatLinkHover.onLeave)
end

function ChatLinkHover.bindAllFrames()
    for index = 1, (NUM_CHAT_WINDOWS or 10) do ChatLinkHover.bindFrame(_G["ChatFrame" .. index]) end
    for _, frameName in ipairs(CHAT_FRAMES or {}) do ChatLinkHover.bindFrame(_G[frameName]) end
end

local loginFrame = CreateFrame("Frame")
loginFrame:RegisterEvent("PLAYER_LOGIN")
loginFrame:SetScript("OnEvent", function(self)
    self:UnregisterEvent("PLAYER_LOGIN")
    ChatLinkHover.bindAllFrames()
    -- whisper pop-out windows are created later
    if _G.FCF_OpenTemporaryWindow then hooksecurefunc("FCF_OpenTemporaryWindow", ChatLinkHover.bindAllFrames) end
end)
