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

function ConnectPanel:getDuration()
    if self.character:isTimedActionInstant() then
        return 1
    end
    --base time in minutes at level 3, ~1/3 at level 10
    return SandboxVars.ISA.ConnectPanelMin * (1 - 0.095 * (self.character:getPerkLevel(Perks.Electricity) - 3)) * 2 * getGameTime():getMinutesPerDay()
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

function ConnectPanel:perform()
    self.character:stopOrTriggerSound(self.sound)

    ISBaseTimedAction.perform(self)
end

function ConnectPanel:complete()
    local data = self.panel:getModData()
    data.connectDelta = 100
    self.panel:transmitModData()

    local pb = self.powerbank
    local instance = PBSystem.instance
    if not (pb and instance) then return end

    instance:sendCommand(self.character, "connectPanel", {
        pb = { x = pb.x, y = pb.y, z = pb.z },
        panel = { x = self.panel:getX(), y = self.panel:getY(), z = self.panel:getZ() },
    })
end

ISA.ConnectPanel = ConnectPanel
