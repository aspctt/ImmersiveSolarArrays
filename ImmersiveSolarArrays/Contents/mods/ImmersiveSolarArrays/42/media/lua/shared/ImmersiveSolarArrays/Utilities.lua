---@class ImmersiveSolarArrays
---@field PBSystem_Server PowerbankSystem_Server
local ISA = {}

local _gameTime
local _season

ISA.patchClassMetaMethod = function(class, methodName, createPatch)
    local metatable = __classmetatables[class]
    if not metatable then
        error("Unable to find metatable for class "..tostring(class))
    end
    local metatable__index = metatable.__index
    if not metatable__index then
        error("Unable to find __index in metatable for class "..tostring(class))
    end
    local originalMethod = metatable__index[methodName]
    metatable__index[methodName] = createPatch(originalMethod)
end

function ISA.queueFunction(eventName,fn)
    local event = Events[eventName]
    if not event then return print("Tried to queue to invalid event") end
    local function queueFn(...)
        event.Remove(queueFn)
        return fn(...)
    end
    event.Add(queueFn)
end

do
    local delayedProcess = ISBaseObject:derive("ISA delayedProcess")
    local meta = {__index=delayedProcess}

    function delayedProcess:new(obj)
        obj = obj or {}
        obj.event = obj.event or Events.OnTick
        setmetatable(obj,meta)
        return obj
    end

    function delayedProcess:start()
        self.event.Add(self.process)
    end

    function delayedProcess:stop()
        self.data = nil
        return self.event.Remove(self.process)
    end

    function delayedProcess.process() end

    ISA.delayedProcess = delayedProcess
end

---Compares the current time to dusk and dawn.
---
---Both halves arrive on events, and the status window can be opened before the season
---one has fired, so this answers daytime rather than erroring when it does not know.
---@return boolean
function ISA.isDayTime()
    if not (_gameTime and _season) then return true end
    local time = _gameTime:getTimeOfDay()
    return time > _season:getDawn() and time < _season:getDusk()
end

Events.OnGameTimeLoaded.Add(function ()
    _gameTime = getGameTime()
end)

Events.OnInitSeasons.Add(function (season)
    _season = season
end)

return ISA
