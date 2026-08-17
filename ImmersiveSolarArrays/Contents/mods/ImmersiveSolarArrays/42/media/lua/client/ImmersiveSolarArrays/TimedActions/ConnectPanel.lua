--[[
    Wiring a solar panel to a battery bank.

    Client, because the only thing that queues it is the world context menu, and because
    it now reports the result with a command rather than reaching into the server system.
    The build 41 version called ISA.PBSystem_Server directly, which is nil on a
    multiplayer client, so connecting a panel there did nothing but throw.

    Progress is remembered on the panel, so a job interrupted at 60% resumes at 60%.
--]]

require "TimedActions/ISBaseTimedAction"
---@class ImmersiveSolarArrays
local ISA = require "ImmersiveSolarArrays/Utilities"
local PBSystem = require "ImmersiveSolarArrays/PowerBank/PowerBankSystem_Client"

local ConnectPanel = ISBaseTimedAction:derive("ISA_ConnectPanel")

function ConnectPanel:new(character, panel, luaPb)
    local o = {}
    setmetatable(o, self)
    self.__index = self
    o.character = character
    o.panel = panel
    o.powerbank = luaPb
    o.stopOnWalk = true
    o.stopOnRun = true
    o.stopOnAim = false
    o.maxTime = o:getDuration()
    return o
end

function ConnectPanel:isValid()
    return self.panel:getObjectIndex() ~= -1
end

--- One in-game minute, expressed in the units maxTime is counted in.
---
--- A timed action advances by GameTime.getMultiplier() per frame, which is about one at
--- 60fps and scales with fast forward but not with the day length. So maxTime is frames,
--- and converting from in-game minutes has to bring the day length in by hand.
---
--- One in-game day is minutesPerDay real minutes, which is minutesPerDay * 3600 frames,
--- and holds 1440 in-game minutes. That leaves 2.5 frames per in-game minute for every
--- real minute of day length.
local FRAMES_PER_INGAME_MINUTE_PER_DAYLENGTH = 2.5

--- Full time at Electrical 3, about a third of it at 10, about a quarter longer at 0.
local function skillFactor(level)
    return 1 - 0.095 * (level - 3)
end

function ConnectPanel:getDuration()
    if self.character:isTimedActionInstant() then
        return 1
    end

    -- Day length is read rather than assumed, so the job takes the same number of
    -- in-game minutes whether a day is fifteen real minutes or three real hours.
    local minutesPerDay = getGameTime():getMinutesPerDay()
    if not minutesPerDay or minutesPerDay <= 0 then minutesPerDay = 60 end

    local minutes = SandboxVars.ISA.ConnectPanelMin * skillFactor(self.character:getPerkLevel(Perks.Electricity))
    return minutes * FRAMES_PER_INGAME_MINUTE_PER_DAYLENGTH * minutesPerDay
end

function ConnectPanel:start()
    self:setActionAnim("Loot")
    self.character:SetVariable("LootPosition", "Low")
    self.character:reportEvent("EventLootItem")
    self.sound = self.character:playSound("GeneratorConnect")

    local data = self.panel:getModData()
    local prevDelta = data["connectDelta"]
    if not prevDelta then prevDelta = 0 elseif prevDelta > 90 then prevDelta = 90 end
    data["connectDelta"] = prevDelta
    self:setCurrentTime(self.maxTime * prevDelta / 100)
end

function ConnectPanel:waitToStart()
    self.character:faceThisObject(self.panel)
    return self.character:shouldBeTurning()
end

function ConnectPanel:update()
    self.character:faceThisObject(self.panel)
end

function ConnectPanel:stop()
    self.character:stopOrTriggerSound(self.sound)

    -- Bank the work done so far, so an interrupted job is not started over.
    local delta = math.floor(self:getJobDelta() * 100)
    local data = self.panel:getModData()
    if delta > (data.connectDelta or 0) and self.panel:getObjectIndex() ~= -1 then
        data.connectDelta = delta
        self.panel:transmitModData()
    end

    ISBaseTimedAction.stop(self)
end

--- The job finished, so tell the server to wire the panel up.
---
--- This belongs in perform rather than complete. The engine skips the Lua complete
--- entirely on a multiplayer client, because in multiplayer the server runs its own copy
--- of the action and its complete is the authoritative one. This action only exists
--- under client/, so the server has no copy to run, and the work was being dropped on
--- the floor: the bar filled, the job ended, and the panel was never connected.
--- perform is called on whoever is doing the action, in both singleplayer and
--- multiplayer, and runs just before complete would.
function ConnectPanel:perform()
    self.character:stopOrTriggerSound(self.sound)

    local data = self.panel:getModData()
    data.connectDelta = 100
    self.panel:transmitModData()

    local pb = self.powerbank
    local instance = PBSystem.instance
    if pb and instance then
        instance:sendCommand(self.character, "connectPanel", {
            pb = { x = pb.x, y = pb.y, z = pb.z },
            panel = { x = self.panel:getX(), y = self.panel:getY(), z = self.panel:getZ() },
        })
    end

    -- needed to remove from queue / start next.
    ISBaseTimedAction.perform(self)
end

ISA.ConnectPanel = ConnectPanel
