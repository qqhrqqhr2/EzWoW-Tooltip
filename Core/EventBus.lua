--===========================================================================
-- EzWoW - Tooltip
-- Core/EventBus.lua : Custom Signal Bus & WoW Frame Event Dispatcher
--===========================================================================
local _, ns = ...
local type, pairs, ipairs, tonumber, tostring, select, pcall = type, pairs, ipairs, tonumber, tostring, select, pcall

local EventDispatcher = ns.EventDispatcher or {}
ns.EventDispatcher = EventDispatcher

local EventDispatcher = {}
ns.events = EventDispatcher

local signalSubscribers = {}
local eventSubscribers  = {}
local eventDriverFrame  = CreateFrame("Frame")

function EventDispatcher.dispatchError(errMsg)
    local resolveCurErr = _G.geterrorhandler and _G.geterrorhandler()
    if type(resolveCurErr) == "function" then
        resolveCurErr(errMsg)
    else
        print(errMsg)
    end
end

function EventDispatcher.iterateTokens(tokenStr, callback)
    for token in string.gmatch(tokenStr or "", "[^,%s]+") do
        callback(token)
    end
end

function EventDispatcher.registerSubscriber(mapTable, keySpec, callback)
    EventDispatcher.iterateTokens(keySpec, function(key)
        local bucket = mapTable[key]
        if not bucket then
            bucket = {}
            mapTable[key] = bucket
        end
        bucket[#bucket + 1] = callback
    end)
end

function EventDispatcher.unregisterSubscriber(mapTable, keySpec, callback)
    EventDispatcher.iterateTokens(keySpec, function(key)
        local bucket = mapTable[key]
        if not bucket then return end
        for entryIndex = #bucket, 1, -1 do
            if bucket[entryIndex] == callback then
                table.remove(bucket, entryIndex)
            end
        end
    end)
end

function EventDispatcher.invokeSubscribers(bucket, ...)
    if not bucket or #bucket == 0 then return end
    local copy = {}
    for entryIndex = 1, #bucket do
        copy[entryIndex] = bucket[entryIndex]
    end
    for entryIndex = 1, #copy do
        local isCallOk, errorObj = pcall(copy[entryIndex], EventDispatcher, ...)
        if not isCallOk then
            EventDispatcher.dispatchError(errorObj)
        end
    end
end

function EventDispatcher:attachTrigger(signalNames, callback)
    EventDispatcher.registerSubscriber(signalSubscribers, signalNames, callback)
end

function EventDispatcher:detachTrigger(signalNames, callback)
    EventDispatcher.unregisterSubscriber(signalSubscribers, signalNames, callback)
end

function EventDispatcher:trigger(signalName, ...)
    EventDispatcher.invokeSubscribers(signalSubscribers[signalName], ...)
end

function EventDispatcher:attachEvent(eventNames, callback)
    EventDispatcher.iterateTokens(eventNames, function(evName)
        if not eventSubscribers[evName] then
            eventSubscribers[evName] = {}
            pcall(eventDriverFrame.RegisterEvent, eventDriverFrame, evName)
        end
    end)
    EventDispatcher.registerSubscriber(eventSubscribers, eventNames, callback)
end

function EventDispatcher:detachEvent(eventNames, callback)
    EventDispatcher.unregisterSubscriber(eventSubscribers, eventNames, callback)
end

eventDriverFrame:SetScript("OnEvent", function(_, evName, ...)
    EventDispatcher.invokeSubscribers(eventSubscribers[evName], ...)
end)

function EventDispatcher:after(delaySec, callback)
    if _G.C_Timer and type(_G.C_Timer.After) == "function" then
        _G.C_Timer.After(delaySec, callback)
    else
        callback()
    end
end
